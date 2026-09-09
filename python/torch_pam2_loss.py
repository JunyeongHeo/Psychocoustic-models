"""Differentiable PyTorch psychoacoustic losses driven by a PAM-2 threshold.

Framework choice
----------------
This reference is written in **PyTorch**. It mirrors the two psychoacoustic
loss terms used by the ``cocosci/pam-nac`` neural codec --- ``smr_loss`` and
``nmr_max_mean_loss`` --- which are implemented there in TensorFlow. The port
below is idiomatic PyTorch (``torch.stft``, ``torch.log10``, ``torch.relu``,
autograd) and imports **only** ``torch`` plus the Python standard library, so
it can be dropped into any PyTorch training loop.

Non-differentiable vs differentiable boundary
---------------------------------------------
The MPEG-1 psychoacoustic model 2 (PAM-2) global masking threshold is produced
by a **non-differentiable** procedure: local-maximum / tonality selection,
unpredictability estimation, spreading, ATH flooring and pre-echo control (see
the companion MATLAB ``matlab/pam2_threshold.m``, or an equivalent NumPy port).
That procedure is discrete and is therefore run **offline, once, before /
outside of training**. Its output --- the per-frame global masking threshold
``gms`` (in dB) --- is passed into the loss functions as a plain tensor.

Everything inside these loss functions is **differentiable** with respect to
the decoded signal: the STFT, the per-frame log-PSD, the priority weighting and
the NMR ratio all flow gradients back to ``decoded_sig``. To make the boundary
explicit, ``gms`` is treated as a **constant**: ``.detach()`` is applied to it
inside every loss function so no gradient is ever routed into the precomputed
(non-differentiable) threshold. In short:

    PAM-2 threshold precompute  ->  NON-differentiable, offline, gms constant
    STFT log-PSD loss on frames ->  differentiable w.r.t. decoded_sig

References
----------
* cocosci, ``pam-nac``: https://github.com/cocosci/pam-nac
  (Python PAM-1 masker + TensorFlow neural-codec losses; this file mirrors its
  ``smr_loss`` and ``nmr_max_mean_loss`` from
  ``neural-codec/loss_terms_and_measures.py``).
* K. Zhen, M. S. Lee, J. Sung, S. Beack, M. Kim, "Psychoacoustic Calibration
  of Loss Functions for Efficient End-to-End Neural Audio Coding," IEEE Signal
  Processing Letters, 2020.
  https://saige.sice.indiana.edu/wp-content/uploads/spl2020_kzhen.pdf
* ISO/IEC 11172-3 (MPEG-1 Audio), Annex D, Psychoacoustic Model 2.
"""

import torch

# Full-scale reference level (dB). Mirrors pam-nac's log_psd_to_psd, where the
# tf_psd normalisation makes a full-scale tone sit at ~96 dB.
REF_LEVEL_DB = 96.0

# Small constant for numerical stability inside log10 / division.
EPS = 1e-7


def log_psd_to_psd(log_psd):
    """Convert a log (dB) PSD back to a linear power-spectral-density.

    Mirrors pam-nac's ``log_psd_to_psd``:
    ``10 ** ((log_psd - 96) / 10)``.
    """
    return torch.pow(10.0, (log_psd - REF_LEVEL_DB) / 10.0)


def stft_psd(sig, n_fft, hop):
    """Differentiable per-frame log-PSD (dB) of a batched signal.

    Computes ``P = 20 * log10(|STFT| / n_fft)`` using ``torch.stft`` with
    ``return_complex=True``. This is the differentiable STFT path: gradients
    flow from ``P`` back into ``sig``.

    Parameters
    ----------
    sig : torch.Tensor
        Real signal of shape ``[batch, samples]``.
    n_fft : int
        FFT / window length.
    hop : int
        Hop (frame step) in samples.

    Returns
    -------
    torch.Tensor
        Log-PSD in dB of shape ``[batch, frames, freq]`` where
        ``freq == n_fft // 2 + 1``.
    """
    window = torch.hann_window(n_fft, device=sig.device, dtype=sig.dtype)
    spec = torch.stft(
        sig,
        n_fft=n_fft,
        hop_length=hop,
        win_length=n_fft,
        window=window,
        center=True,
        return_complex=True,
    )
    # spec: [batch, freq, frames] -> magnitude -> [batch, frames, freq]
    mag = spec.abs().transpose(-1, -2)
    return 20.0 * torch.log10(mag / n_fft + EPS)


def smr_priority_loss(orig_sig, decoded_sig, gms, n_fft, hop):
    """SMR-priority-weighted spectral MSE (mirrors pam-nac ``smr_loss``).

    Priority weighting emphasises frequency bins whose signal power rises above
    the masking threshold (the audible bins), so the loss preferentially
    reduces spectral error where the ear actually hears it.

        priority = log10( 10 ** (0.1 * ori_psd) / 10 ** (0.1 * gms) + 1 )
        loss     = mean( (ori_psd - dec_psd) ** 2 * priority )

    ``gms`` is the precomputed PAM-2 global masking threshold (dB); it is
    ``.detach()``-ed here so it is treated as a constant.
    """
    gms = gms.detach()  # non-differentiable, precomputed threshold
    ori_psd = stft_psd(orig_sig, n_fft, hop)
    dec_psd = stft_psd(decoded_sig, n_fft, hop)
    priority = torch.log10(
        (10.0 ** (0.1 * ori_psd)) / (10.0 ** (0.1 * gms)) + 1.0
    )
    return torch.mean((ori_psd - dec_psd) ** 2 * priority)


def nmr_max_loss(orig_sig, decoded_sig, gms, n_fft, hop):
    """NMR max-lower-bound loss (mirrors pam-nac ``nmr_max_mean_loss``).

    Penalises only the error-signal PSD that exceeds the masking threshold
    (i.e. becomes audible noise), taking the worst (maximum) bin per frame:

        diff_psd = stft_psd(decoded - orig)
        loss     = mean_frames( max_k ReLU(
                       log_psd_to_psd(diff_psd) / log_psd_to_psd(gms) - 1 ) )

    ``gms`` is the precomputed PAM-2 global masking threshold (dB), detached.
    """
    gms = gms.detach()  # non-differentiable, precomputed threshold
    diff_psd = stft_psd(decoded_sig - orig_sig, n_fft, hop)
    gms_psd = log_psd_to_psd(gms)
    ratio = torch.relu(log_psd_to_psd(diff_psd) / gms_psd - 1.0)
    # max over frequency bins (worst bin), mean over frames and batch.
    per_frame_max = torch.amax(ratio, dim=-1)
    return torch.mean(per_frame_max)


if __name__ == "__main__":
    # Small, fast smoke test on random tensors. The PAM-2 threshold `gms` would
    # normally come from the offline MATLAB pam2_threshold (or a NumPy port);
    # here we just use a random constant tensor of the matching shape.
    torch.manual_seed(0)

    batch, samples = 2, 4096
    n_fft, hop = 512, 256

    orig = torch.randn(batch, samples)
    decoded = torch.randn(batch, samples)

    # Derive the [batch, frames, freq] shape produced by stft_psd from a dummy
    # forward pass so the gms tensor matches exactly.
    with torch.no_grad():
        probe = stft_psd(orig, n_fft, hop)
    gms = torch.rand_like(probe) * 96.0  # precomputed PAM-2 threshold (dB)

    smr = smr_priority_loss(orig, decoded, gms, n_fft, hop)
    nmr = nmr_max_loss(orig, decoded, gms, n_fft, hop)

    print("stft_psd shape [batch, frames, freq]:", tuple(probe.shape))
    print("smr_priority_loss:", smr.item())
    print("nmr_max_loss:", nmr.item())

    for name, value in (("smr", smr), ("nmr", nmr)):
        assert torch.isfinite(value), f"{name} loss is not finite"
        assert value.item() >= 0.0, f"{name} loss is negative"
    print("OK: both losses are finite and non-negative.")
