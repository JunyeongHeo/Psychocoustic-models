% pam2_demo.m
% -----------------------------------------------------------------------------
% MPEG-1 psychoacoustic model 2 (PAM-2) demo driver
% (base MATLAB / GNU Octave compatible).
%
% This script synthesises a short sequence of consecutive analysis frames
% (a 1 kHz tone plus mild broadband noise, with a slight change between frames
% so that the magnitude/phase prediction of model 2 is meaningful), runs
% PAM2_THRESHOLD over the frames while maintaining a 2-frame history, prints the
% per-partition tonality index, masking threshold, and SMR to the console, and
% optionally saves a PNG. Plotting is guarded so the script also runs headless.
%
% Pipeline exercised (ISO/IEC 11172-3 Annex D, psychoacoustic model 2):
%   Hann-windowed FFT -> magnitude/phase -> unpredictability c(w)
%   -> Bark partitions -> spreading convolution -> cb(b)
%   -> tonality t(b) = -0.43*ln(cb) - 0.299 (clamped [0,1])
%   -> required SNR(b) = t*TMN + (1-t)*NMT (TMN = 18 dB, NMT = 6 dB)
%   -> nb(b) = en(b)*10^(-SNR/10) -> ATH flooring -> pre-echo min -> SMR(b).
%
% The numeric constants (TMN = 18 dB, NMT = 6 dB, tonality coefficients -0.43
% and -0.299, clamp [0,1]) match the accompanying document and the helper
% functions pam2_unpredictability.m / pam2_threshold.m.
%
% Only base functions are used (fft, cos, sin, atan2, sqrt, log, log10, abs,
% max, min, sum, fprintf). The Hann window is built manually. No toolboxes.
%
% References
% ----------
%   * ISO/IEC 11172-3 (MPEG-1 Audio), Annex D, Psychoacoustic Model 2.
%   * M. Bosi and R. E. Goldberg, "Introduction to Digital Audio Coding and
%     Standards," Kluwer Academic Publishers.
%   * T. Painter and A. Spanias, "Perceptual Coding of Digital Audio,"
%     Proceedings of the IEEE, vol. 88, no. 4, pp. 451-515, 2000.
%   * cocosci, pam-nac, https://github.com/cocosci/pam-nac
%   * K. Zhen et al., "Psychoacoustic Calibration of Loss Functions for
%     Efficient End-to-End Neural Audio Coding," IEEE SPL, 2020,
%     https://saige.sice.indiana.edu/wp-content/uploads/spl2020_kzhen.pdf
% -----------------------------------------------------------------------------

% Make the helper functions on this directory visible even if launched
% from elsewhere.
this_dir = fileparts(mfilename('fullpath'));
if ~isempty(this_dir)
    addpath(this_dir);
end

% Detect whether we can safely open figures (headless-friendly).
can_plot = true;
try
    hfig_test = figure('Visible', 'off');
    close(hfig_test);
catch
    can_plot = false;
    fprintf('[info] Plotting backend unavailable; running without figures.\n');
end

% =============================================================================
% 1. Synthesise a few consecutive frames: 1 kHz tone + noise, slight change
% =============================================================================
fs      = 44100;        % sampling rate (Hz)
N       = 2048;         % FFT frame length
n_frame = 4;            % number of consecutive frames
f0      = 1000;         % tone frequency (Hz)

% Seed the RNG for reproducibility (Octave-style; ignore on newer MATLAB).
try
    rand('seed', 2020);
    randn('seed', 2020);
catch
end

% Build the frames as columns of X_frames. Each frame is a 1 kHz tone whose
% amplitude drifts slightly plus fresh broadband noise, so the linear
% magnitude/phase prediction across frames is neither perfect nor useless.
X_frames = zeros(N, n_frame);
for k = 1:n_frame
    n0  = (k - 1) * N;                       % continuous phase across frames
    idx = (n0:n0 + N - 1)';
    amp = 1.0 - 0.05 * (k - 1);              % slight amplitude change
    tone  = amp * sin(2 * pi * f0 * idx / fs);
    noise = 0.01 * randn(N, 1);
    X_frames(:, k) = tone + noise;
end

% =============================================================================
% 2. Run PAM2_THRESHOLD over the frames with a 2-frame history
% =============================================================================
% Frames 1 and 2 seed the history; thresholds are computed from frame 3 on.
thr_prev = [];
last_info = [];
last_thr  = [];
last_smr  = [];
for k = 3:n_frame
    x   = X_frames(:, k);
    xm1 = X_frames(:, k - 1);
    xm2 = X_frames(:, k - 2);

    [thr, smr, info] = pam2_threshold(x, xm1, xm2, fs, thr_prev);
    thr_prev = thr;             % carry forward for pre-echo control

    fprintf('\n=== Frame %d: per-partition PAM-2 results ===\n', k);
    fprintf('  %-14s %-10s %-14s %-10s\n', ...
            'Bark centre', 'tonality', 'thr (dB)', 'SMR (dB)');
    for b = 1:numel(thr)
        if info.e(b) > 0
            fprintf('  %10.2f   %8.3f   %10.2f   %8.2f\n', ...
                    info.z_centre(b), info.tonality(b), ...
                    10 * log10(thr(b) + eps), smr(b));
        end
    end

    last_info = info;
    last_thr  = thr;
    last_smr  = smr;
end

% =============================================================================
% 3. Optional plot (guarded for headless environments)
% =============================================================================
if can_plot && ~isempty(last_info)
    active = last_info.e > 0;
    zc     = last_info.z_centre(active);
    hf = figure('Visible', 'off');
    plot(zc, last_info.tonality(active), 'b-o', 'LineWidth', 1.2); hold on;
    plot(zc, last_smr(active) / max(1, max(abs(last_smr(active)))), ...
         'r-s', 'LineWidth', 1.0);
    grid on;
    xlabel('Partition Bark centre (Bark)');
    ylabel('Tonality index / normalised SMR');
    title('PAM-2 per-partition tonality and SMR (last frame)');
    legend('Tonality t(b)', 'SMR (normalised)', 'Location', 'northeast');
    print(hf, fullfile(this_dir, 'fig_pam2.png'), '-dpng');
    close(hf);
    fprintf('\n[ok] Saved fig_pam2.png\n');
end

fprintf('\nDone. (PAM-2 thresholds computed for frames 3..%d.)\n', n_frame);
