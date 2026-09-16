"""PyTorch reference for conditioning a CNN audio encoder on psychoacoustic info.

Framework choice
----------------
This reference is written in **PyTorch** and imports **only** ``torch`` (plus
``torch.nn``), so it can be dropped into any PyTorch training loop. It provides
two building blocks for injecting a psychoacoustic conditioning signal (a
per-frame masking-threshold / SMR curve) into a 1D-CNN encoder such as the one
used by the ``cocosci/pam-nac`` neural audio codec:

  (a) ``FiLM`` --- a feature-wise linear modulation layer that predicts a
      per-channel scale ``gamma`` and shift ``beta`` from a conditioning
      vector and modulates a CNN feature map as ``gamma * h + beta``.
  (b) ``ChannelConcatConditioning`` --- resamples/broadcasts a per-frame
      masking-threshold curve onto the encoder input time grid and concatenates
      it as extra input channels of a 1D CNN.

Relation to pam-nac
-------------------
In pam-nac the encoder is a 1D-CNN autoencoder on raw waveform frames
(frame_length=512, channels-last <b, s, 1>): a wide conv (kernel 55) ->
narrow-narrow-wide dilated residual bottleneck blocks -> stride-2 downsampling
conv (kernel 9) -> bottleneck -> 1-channel tanh, mapping <b, s, 1> to
<b, s/2, 1>. Crucially, pam-nac feeds the precomputed global masking threshold
ONLY at the LOSS level (the ``mat`` placeholder into ``smr_loss`` /
``nmr_max_mean_loss``); the encoder itself is NOT conditioned on psychoacoustic
quantities. The blocks below are a reference for going beyond that baseline:
conditioning the encoder input (b) and its intermediate features (a). The
threshold curve is precomputed offline and non-differentiable, so it is treated
as a constant conditioning input (``.detach()`` at the call site).

References
----------
* cocosci, ``pam-nac``: https://github.com/cocosci/pam-nac
  (1D-CNN neural audio codec; psychoacoustic threshold used only at loss level).
* E. Perez, F. Strub, H. de Vries, V. Dumoulin, A. Courville, "FiLM: Visual
  Reasoning with a General Conditioning Layer," AAAI 2018.
"""

import torch
import torch.nn as nn


class FiLM(nn.Module):
    """Feature-wise Linear Modulation (Perez et al., AAAI 2018).

    Predicts per-channel scale ``gamma`` and shift ``beta`` from a conditioning
    vector and applies ``gamma * h + beta`` to a 1D-CNN feature map.

    Parameters
    ----------
    cond_dim : int
        Dimension of the conditioning vector (e.g. a threshold embedding).
    num_features : int
        Number of feature-map channels ``C`` to modulate.
    hidden : int
        Hidden width of the small MLP that predicts (gamma, beta).
    """

    def __init__(self, cond_dim, num_features, hidden=32):
        super().__init__()
        self.num_features = num_features
        self.generator = nn.Sequential(
            nn.Linear(cond_dim, hidden),
            nn.ReLU(),
            nn.Linear(hidden, 2 * num_features),
        )

    def forward(self, h, cond):
        """Modulate feature map ``h`` with conditioning vector ``cond``.

        Parameters
        ----------
        h : torch.Tensor
            Feature map of shape ``[batch, C, T]`` (channels-first 1D CNN).
        cond : torch.Tensor
            Conditioning vector of shape ``[batch, cond_dim]``.

        Returns
        -------
        torch.Tensor
            Modulated feature map, same shape as ``h``.
        """
        gamma_beta = self.generator(cond)                 # [batch, 2C]
        gamma, beta = gamma_beta.chunk(2, dim=-1)          # each [batch, C]
        # Broadcast over the time axis: [batch, C, 1].
        gamma = gamma.unsqueeze(-1)
        beta = beta.unsqueeze(-1)
        # Center gamma at 1 so an untrained FiLM starts near identity.
        return (1.0 + gamma) * h + beta


class ChannelConcatConditioning(nn.Module):
    """Concatenate a per-frame masking-threshold curve as extra input channels.

    The masking threshold is a per-frame / per-band curve on a coarse grid; it
    is resampled (linear interpolation) to the encoder input length and
    optionally standardized, then concatenated to the waveform/feature channels
    of a 1D CNN input.

    Parameters
    ----------
    normalize : bool
        If True, standardize the (dB-scale) threshold per example to zero mean
        and unit variance before concatenation (thresholds span a wide range).
    """

    def __init__(self, normalize=True):
        super().__init__()
        self.normalize = normalize

    def forward(self, x, threshold):
        """Concatenate a resampled threshold curve onto a 1D-CNN input.

        Parameters
        ----------
        x : torch.Tensor
            Encoder input of shape ``[batch, C_in, T]`` (channels-first).
        threshold : torch.Tensor
            Precomputed masking threshold (dB), shape ``[batch, T_thr]`` or
            ``[batch, C_thr, T_thr]``. Treated as a constant conditioning input.

        Returns
        -------
        torch.Tensor
            Input with the threshold channel(s) appended: ``[batch, C_in+C_thr, T]``.
        """
        threshold = threshold.detach()          # precomputed, non-differentiable
        if threshold.dim() == 2:
            threshold = threshold.unsqueeze(1)   # [batch, 1, T_thr]

        target_t = x.shape[-1]
        if threshold.shape[-1] != target_t:
            # Resample the threshold curve onto the input time grid.
            threshold = nn.functional.interpolate(
                threshold, size=target_t, mode="linear", align_corners=False
            )

        if self.normalize:
            mean = threshold.mean(dim=-1, keepdim=True)
            std = threshold.std(dim=-1, keepdim=True) + 1e-5
            threshold = (threshold - mean) / std

        return torch.cat([x, threshold], dim=1)


if __name__ == "__main__":
    # Small, fast smoke test on random tensors. The masking threshold would
    # normally come from the offline PAM-1/PAM-2 precompute; here we use random
    # constant tensors of the matching shapes.
    torch.manual_seed(0)

    batch, c_in, t = 2, 1, 512          # <b, 1, s>: raw-waveform 1D-CNN input
    c_feat, t_feat = 16, 256            # a downsampled intermediate feature map
    cond_dim = 8                        # threshold-embedding dimension
    t_thr = 40                          # coarse per-frame/per-band threshold

    # (b) Channel-concatenation conditioning on the encoder input.
    concat = ChannelConcatConditioning(normalize=True)
    x = torch.randn(batch, c_in, t)
    threshold = torch.rand(batch, t_thr) * 96.0     # dB-scale threshold curve
    x_cond = concat(x, threshold)
    print("channel-concat input shape [b, C_in+C_thr, T]:", tuple(x_cond.shape))
    assert x_cond.shape == (batch, c_in + 1, t)
    assert torch.isfinite(x_cond).all()

    # (a) FiLM modulation of an intermediate feature map.
    film = FiLM(cond_dim=cond_dim, num_features=c_feat)
    h = torch.randn(batch, c_feat, t_feat)
    cond_vec = torch.randn(batch, cond_dim)         # e.g. a threshold embedding
    h_mod = film(h, cond_vec)
    print("FiLM output shape [b, C, T]:", tuple(h_mod.shape))
    assert h_mod.shape == h.shape
    assert torch.isfinite(h_mod).all()

    print("OK: channel-concat and FiLM produce finite, correctly shaped tensors.")
