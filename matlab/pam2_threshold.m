function [thr, smr, info] = pam2_threshold(x, xm1, xm2, fs, thr_prev)
% PAM2_THRESHOLD  Per-partition masking threshold and SMR (MPEG-1 model 2).
%   [thr, smr, info] = PAM2_THRESHOLD(x, xm1, xm2, fs, thr_prev) computes the
%   per-partition masking threshold thr(b) (linear power) and the signal-to-mask
%   ratio smr(b) (dB) for the current PCM frame x, given the previous two frames
%   xm1 (t-1) and xm2 (t-2) and the sampling rate fs (Hz). The optional argument
%   thr_prev is the per-partition threshold of the previous frame; when supplied
%   it is used for simple pre-echo control (element-wise minimum of the current
%   and delayed thresholds).
%
%   The routine follows MPEG-1 psychoacoustic model 2 (ISO/IEC 11172-3 Annex D):
%
%     1. Hann-window each frame and take the FFT to obtain magnitude r(w) and
%        phase phi(w) (the Hann window is built manually, no toolbox needed).
%     2. Compute the unpredictability c(w) from the current and previous two
%        frames via PAM2_UNPREDICTABILITY.
%     3. Group the FFT lines into Bark-based threshold-calculation partitions b
%        (using HZ2BARK) and form the partition energy e(b) and the
%        energy-weighted unpredictability e(b)*c(b).
%     4. Convolve e(b) and e(b)*c(b) along the Bark axis with the spreading
%        function (SPREADING_FUNCTION, converted from dB to a linear weight) to
%        obtain ecb(b) and ct(b); then cb(b) = ct(b)/ecb(b) and the renormalised
%        spread energy en(b).
%     5. Tonality index  t(b) = -0.43*log(cb(b)) - 0.299, clamped to [0,1].
%     6. Required SNR     SNR(b) = t(b)*TMN + (1 - t(b))*NMT, with TMN = 18 dB,
%        NMT = 6 dB.
%     7. Power ratio      bc(b) = 10^(-SNR(b)/10); threshold  nb(b) = en(b)*bc(b).
%     8. ATH flooring     thr(b) = max(nb(b), ATH(b)), with ATH from ATH_TERHARDT
%        converted from dB SPL to the same linear power domain as en(b).
%     9. Pre-echo control thr(b) = min(thr(b), thr_prev(b)) when thr_prev given.
%    10. Per-partition SMR(b) = 10*log10(e(b)/thr(b)) in dB.
%
%   The numeric constants (TMN = 18 dB, NMT = 6 dB, tonality coefficients
%   -0.43 and -0.299, clamp [0,1]) are the commonly-cited ISO model-2 values and
%   are kept identical to the accompanying document and the other PAM-2 code.
%
%   All operations are element-wise and use only base functions (fft, cos, sin,
%   atan2, sqrt, log, log10, abs, max, min, sum), so the function is
%   base-MATLAB / GNU Octave compatible (no toolboxes required).
%
%   References
%   ----------
%     * ISO/IEC 11172-3 (MPEG-1 Audio), Annex D, Psychoacoustic Model 2.
%     * M. Bosi and R. E. Goldberg, "Introduction to Digital Audio Coding and
%       Standards," Kluwer Academic Publishers.
%     * T. Painter and A. Spanias, "Perceptual Coding of Digital Audio,"
%       Proceedings of the IEEE, vol. 88, no. 4, pp. 451-515, 2000.
%     * cocosci, pam-nac, https://github.com/cocosci/pam-nac
%     * K. Zhen et al., "Psychoacoustic Calibration of Loss Functions for
%       Efficient End-to-End Neural Audio Coding," IEEE SPL, 2020,
%       https://saige.sice.indiana.edu/wp-content/uploads/spl2020_kzhen.pdf

    % Make the helper functions on this directory visible even if the caller
    % runs from elsewhere.
    this_dir = fileparts(mfilename('fullpath'));
    if ~isempty(this_dir)
        addpath(this_dir);
    end

    if nargin < 5
        thr_prev = [];
    end

    % --- Model-2 constants (identical across prose, LaTeX, and code) ---
    TMN = 18;   % tone-masking-noise requirement (dB)
    NMT = 6;    % noise-masking-tone requirement (dB)

    % Force column vectors of equal length.
    x   = x(:);
    xm1 = xm1(:);
    xm2 = xm2(:);
    N   = numel(x);

    % --- 1. Hann-windowed FFT -> magnitude r(w) and phase phi(w) ---
    w = 0.5 - 0.5 * cos(2 * pi * (0:N-1)' / (N - 1));   % Hann window (no toolbox)
    [r,  phi ] = mag_phase(x   .* w);
    [r1, phi1] = mag_phase(xm1 .* w);
    [r2, phi2] = mag_phase(xm2 .* w);

    % One-sided spectrum: bins 0 .. N/2.
    half  = (N / 2) + 1;
    r     = r(1:half);    phi  = phi(1:half);
    r1    = r1(1:half);   phi1 = phi1(1:half);
    r2    = r2(1:half);   phi2 = phi2(1:half);
    f_bin = (0:half-1)' * fs / N;         % bin centre frequencies (Hz)

    % --- 2. Unpredictability measure c(w) ---
    c = pam2_unpredictability(r, phi, r1, phi1, r2, phi2);

    % --- 3. Group FFT lines into Bark-based partitions ---
    f_min   = 20;                          % audible lower edge (Hz)
    z_bin   = hz2bark(max(f_bin, f_min));  % Bark position of each bin (eq:bark)
    dz_part = 0.5;                          % partition width in Bark
    z_lo    = 0;
    z_hi    = ceil(max(z_bin) / dz_part) * dz_part;
    edges   = (z_lo:dz_part:z_hi)';
    nb_part = numel(edges) - 1;

    energy = r.^2;                          % line energy (power domain)
    e   = zeros(nb_part, 1);                % partition energy e(b)
    ec  = zeros(nb_part, 1);                % energy-weighted unpredictability
    zc  = zeros(nb_part, 1);                % partition Bark centre
    for b = 1:nb_part
        in_b = (z_bin >= edges(b)) & (z_bin < edges(b+1));
        if any(in_b)
            e(b)  = sum(energy(in_b));
            ec(b) = sum(energy(in_b) .* c(in_b));
            zc(b) = mean(z_bin(in_b));
        else
            zc(b) = 0.5 * (edges(b) + edges(b+1));
        end
    end

    % --- 4. Spread e(b) and e(b)*c(b) along the Bark axis ---
    % Build a spreading matrix S(bb,b) from the dB spreading function
    % (SPREADING_FUNCTION), converted to a linear weight 10^(SF/10).
    S = zeros(nb_part, nb_part);
    for b = 1:nb_part
        dz     = zc - zc(b);                       % Bark distance to partition b
        S(:, b) = 10.^(spreading_function(dz) / 10);
    end
    ecb = S * e;                                    % spread energy      ecb(b)
    ct  = S * ec;                                   % spread energy*c    ct(b)
    norm_b = sum(S, 2);                             % spreading normaliser
    cb  = ct ./ (ecb + eps);                        % normalised unpredictability
    en  = ecb ./ (norm_b + eps);                    % renormalised spread energy

    % --- 5. Tonality index t(b) = -0.43*ln(cb) - 0.299, clamped [0,1] ---
    t = -0.43 * log(cb + eps) - 0.299;
    t = max(0, min(1, t));

    % --- 6. Required SNR(b) = t*TMN + (1 - t)*NMT ---
    snr_req = t * TMN + (1 - t) * NMT;              % dB

    % --- 7. Power ratio bc(b) and partition threshold nb(b) ---
    bc = 10.^(-snr_req / 10);
    nb = en .* bc;                                  % nb(b) = en(b)*bc(b)

    % --- 8. ATH flooring: thr(b) = max(nb(b), ATH(b)) ---
    % Convert the Terhardt ATH (dB SPL, eq:ath) into the same linear power
    % domain as the partition energy. Use the partition centre frequency.
    f_part = bark2hz_centre(zc);
    ath_db = ath_terhardt(max(f_part, f_min));      % dB SPL
    ath_lin = 10.^(ath_db / 10);
    thr = max(nb, ath_lin);

    % --- 9. Pre-echo control: thr(b) = min(thr(b), thr_prev(b)) ---
    if ~isempty(thr_prev)
        thr_prev = thr_prev(:);
        m = min(numel(thr), numel(thr_prev));
        thr(1:m) = min(thr(1:m), thr_prev(1:m));
    end

    % --- 10. Per-partition SMR(b) = 10*log10(e(b)/thr(b)) ---
    smr = 10 * log10((e + eps) ./ (thr + eps));

    % Diagnostic information for callers/demos.
    info = struct('z_centre', zc, 'e', e, 'en', en, 'cb', cb, ...
                  'tonality', t, 'snr_req', snr_req, 'edges', edges);
end

% -----------------------------------------------------------------------------
function [mag, ph] = mag_phase(sig)
% Magnitude and phase spectra of a real signal via the FFT.
    X   = fft(sig);
    mag = abs(X);
    ph  = atan2(imag(X), real(X));
end

% -----------------------------------------------------------------------------
function f = bark2hz_centre(z)
% Approximate inverse Bark->Hz mapping for partition centre frequencies.
% Uses the Traunmueller-style closed form, adequate for ATH flooring only.
    f = 1960 * (z + 0.53) ./ (26.28 - z);
    f = max(f, 0);
end
