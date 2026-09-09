% demo_psychoacoustic.m
% -----------------------------------------------------------------------------
% Simple psychoacoustic-model demo driver (base MATLAB / GNU Octave compatible).
%
% This script ties together the helper functions shipped in this directory and
% reproduces, in code, the core quantities discussed in the accompanying
% LaTeX document:
%
%   ath_terhardt.m        Absolute Threshold of Hearing   (eq:ath)
%   hz2bark.m             Hz -> Bark scale conversion      (eq:bark)
%   critical_bandwidth.m  Critical bandwidth               (eq:cbw)
%   spreading_function.m  Schroeder two-slope spreading    (eq:spread)
%
% What it does:
%   1. Plots the ATH curve over the audible range.
%   2. Plots the spreading function SF(dz) over a Bark-distance range.
%   3. Builds a synthetic test signal: a 1 kHz tone plus white noise.
%   4. Takes one Hann-windowed FFT frame and converts it to dB SPL using the
%      MPEG-1 power-normalization PN = 90.302 dB (consistent with eq:psd).
%   5. Finds the dominant tonal peak, sketches a global masking threshold via
%      the spreading function, and prints a simple per-band SMR sketch.
%
% Only base functions are used (fft, log10, atan, sqrt, plot, semilogx, ...).
% No special toolboxes are required. The Hann window is built manually so that
% the Signal Processing Toolbox is not needed.
%
% Plotting is guarded so the script also runs headless: figures are created
% invisible and saved to PNG via print. If plotting is unavailable the script
% still completes and prints its numeric results.
% -----------------------------------------------------------------------------

% Make the helper functions on this directory visible even if the script is
% launched from elsewhere.
this_dir = fileparts(mfilename('fullpath'));
if ~isempty(this_dir)
    addpath(this_dir);
end

% Detect whether we can safely open figures (headless-friendly).
can_plot = true;
try
    % Create an invisible figure; if the graphics backend is unavailable this
    % throws and we fall back to a no-plot run.
    hfig_test = figure('Visible', 'off');
    close(hfig_test);
catch
    can_plot = false;
    fprintf('[info] Plotting backend unavailable; running without figures.\n');
end

% =============================================================================
% 1. Absolute Threshold of Hearing (eq:ath)
% =============================================================================
f_axis = logspace(log10(20), log10(20000), 512);   % 20 Hz .. 20 kHz, log grid
Tq     = ath_terhardt(f_axis);                      % dB SPL

if can_plot
    hf = figure('Visible', 'off');
    semilogx(f_axis, Tq, 'b', 'LineWidth', 1.5);
    grid on;
    xlabel('Frequency (Hz, log axis)');
    ylabel('Sound pressure level (dB SPL)');
    title('Absolute Threshold of Hearing (Terhardt)');
    axis([20 20000 -10 90]);
    print(hf, fullfile(this_dir, 'fig_ath.png'), '-dpng');
    close(hf);
    fprintf('[ok] Saved fig_ath.png\n');
end

% =============================================================================
% 2. Spreading function SF(dz) (eq:spread)
% =============================================================================
dz = -6:0.05:6;                 % Bark-axis distance
sf = spreading_function(dz);    % dB

if can_plot
    hf = figure('Visible', 'off');
    plot(dz, sf, 'b', 'LineWidth', 1.5);
    grid on;
    xlabel('Bark-axis distance \Deltaz (Bark)');
    ylabel('Spreading function SF(\Deltaz) (dB)');
    title('Schroeder two-slope spreading function');
    axis([-6 6 -40 5]);
    print(hf, fullfile(this_dir, 'fig_spread.png'), '-dpng');
    close(hf);
    fprintf('[ok] Saved fig_spread.png\n');
end

% =============================================================================
% 3. Synthetic test signal: 1 kHz tone + white noise
% =============================================================================
fs   = 44100;          % sampling rate (Hz)
N    = 2048;           % FFT frame length
n    = (0:N-1)';       % sample index (column vector)
f0   = 1000;           % tone frequency (Hz)

% Full-scale-ish tone (amplitude 1.0) plus mild broadband noise.
tone  = 1.0 * sin(2 * pi * f0 * n / fs);
rng_seed = 12345;
% rand/randn are base functions; seed for reproducibility across runs.
try
    rand('seed', rng_seed);      % Octave-style seeding
    randn('seed', rng_seed);
catch
    % MATLAB newer syntax; ignore if unavailable.
end
noise = 0.01 * randn(N, 1);
x     = tone + noise;

% =============================================================================
% 4. Hann-windowed FFT frame -> dB SPL (eq:psd)
% =============================================================================
% Build the Hann window manually (avoids the Signal Processing Toolbox):
%   w[n] = 0.5 - 0.5*cos(2*pi*n/(N-1))
w  = 0.5 - 0.5 * cos(2 * pi * (0:N-1)' / (N - 1));

xw = x .* w;                 % windowed frame
X  = fft(xw);                % complex spectrum

% One-sided spectrum: keep bins 0 .. N/2.
half   = (N / 2) + 1;
Xh     = X(1:half);
k_axis = (0:half-1)';
f_bin  = k_axis * fs / N;    % bin centre frequencies (Hz)

% Power normalisation consistent with eq:psd:
%   P(k) = PN + 10*log10( 2*|X(k)|^2 / (N * sum(w.^2)) )   [dB SPL]
PN   = 90.302;               % MPEG-1 power-normalization term (dB)
wsum = sum(w.^2);
P    = PN + 10 * log10((2 * abs(Xh).^2) / (N * wsum) + eps);   % + eps: avoid log(0)

% Absolute threshold of hearing on the same frequency grid. The Terhardt ATH
% (eq:ath) is only meaningful in the audible range: at ~1 Hz its low-frequency
% term 3.64*(f/1000)^-0.8 explodes to ~900 dB, which would swamp the lowest
% Bark band. Restrict evaluation to bins at or above f_min and mask the
% sub-audible bins out of the threshold/SMR handling below.
f_min   = 20;                            % lower edge of the audible range (Hz)
audible = (f_bin >= f_min);              % logical mask over the FFT grid
Tq_bins = ath_terhardt(max(f_bin, f_min));   % evaluate ATH within audible range

% =============================================================================
% 5. Tonal peak, global masking threshold sketch, per-band SMR
% =============================================================================
% Find the dominant spectral peak within the audible range (ignore the DC bin
% and any sub-audible bins).
search_mask          = audible;
search_mask(1)       = false;             % never pick the DC bin
P_search             = P;
P_search(~search_mask) = -Inf;            % exclude out-of-range bins from the max
[peak_level, peak_idx] = max(P_search);
peak_freq = f_bin(peak_idx);
peak_bark = hz2bark(peak_freq);

% -------------------------------------------------------------------------
% Tonality decision: is the dominant peak tonal (narrow, sinusoid-like) or
% non-tonal (noise-like)? We use a simple, toolbox-free local-prominence
% test: compare the peak level to the average level of its neighbouring bins
% (excluding the peak itself). A tonal component stands well above its local
% background; a noise-like component does not. The threshold below is a
% pragmatic sketch value, not a standard-mandated criterion.
nb          = 4;                          % half-width of the local neighbourhood (bins)
lo          = max(peak_idx - nb, 2);
hi          = min(peak_idx + nb, length(P));
neigh_idx   = lo:hi;
neigh_idx(neigh_idx == peak_idx) = [];    % drop the peak bin itself
local_avg   = mean(P(neigh_idx));         % average neighbouring level (dB)
prominence  = peak_level - local_avg;     % how far the peak stands out (dB)
tonal_thresh = 7;                         % prominence threshold (dB) for tonality
is_tonal    = prominence >= tonal_thresh;

% Select the masking index according to the tonality decision:
%   tonal masker      -> av_tm (eq:avtm): -1.525 - 0.275*z - 4.5
%   non-tonal masker  -> av_nm (eq:avnm): -1.525 - 0.175*z - 0.5
if is_tonal
    av      = -1.525 - 0.275 * peak_bark - 4.5;   % tonal masking index (eq:avtm)
    av_kind = 'tonal (eq:avtm)';
else
    av      = -1.525 - 0.175 * peak_bark - 0.5;   % non-tonal masking index (eq:avnm)
    av_kind = 'non-tonal (eq:avnm)';
end

fprintf('\n--- Detected masker ---\n');
fprintf('  peak frequency : %8.1f Hz\n', peak_freq);
fprintf('  peak level     : %8.2f dB SPL\n', peak_level);
fprintf('  peak position  : %8.2f Bark\n', peak_bark);
fprintf('  local promin.  : %8.2f dB (>= %.1f => tonal)\n', prominence, tonal_thresh);
fprintf('  masker type    : %s\n', av_kind);

% Global masking threshold sketch: combine the ATH with the masker spread via
% the spreading function, in the power (energy) domain (cf. eq:global). The
% masking index "av" was chosen above by the tonality test (eq:avtm/eq:avnm).
%   individual threshold(i) = peak_level + av + SF(z_i - z_masker)
z_bins = hz2bark(max(f_bin, f_min));
T_ind  = peak_level + av + spreading_function(z_bins - peak_bark);

% Power-domain sum of ATH and the individual masking contribution.
T_glob = 10 * log10(10.^(Tq_bins / 10) + 10.^(T_ind / 10) + eps);
% Keep the sub-audible bins out of the printed/plotted threshold so they are
% not governed by the out-of-range ATH value near DC.
T_glob(~audible) = NaN;

if can_plot
    hf = figure('Visible', 'off');
    % Plot only the audible range so the near-DC ATH value does not distort
    % the vertical scale.
    fa = f_bin(audible);
    semilogx(fa, P(audible), 'Color', [0.6 0.6 0.6]); hold on;
    semilogx(fa, Tq_bins(audible), 'g', 'LineWidth', 1.2);
    semilogx(fa, T_glob(audible), 'r', 'LineWidth', 1.5);
    grid on;
    xlabel('Frequency (Hz, log axis)');
    ylabel('Level (dB SPL)');
    title('Spectrum, ATH, and global masking threshold sketch');
    legend('Signal PSD', 'ATH (eq:ath)', 'Global threshold (eq:global)', ...
           'Location', 'southwest');
    axis([20 fs/2 -20 100]);
    print(hf, fullfile(this_dir, 'fig_masking.png'), '-dpng');
    close(hf);
    fprintf('[ok] Saved fig_masking.png\n');
end

% Simple per-band SMR sketch over a handful of Bark bands (eq:smr):
%   SMR(band) = signal level(band) - min masking threshold(band)
fprintf('\n--- Per-band SMR sketch (eq:smr) ---\n');
fprintf('  %-14s %-12s %-14s %-10s\n', 'Bark band', 'f_lo (Hz)', 'Ls (dB SPL)', 'SMR (dB)');
band_edges_bark = 0:2:24;                 % coarse 2-Bark bands for the sketch
for b = 1:(length(band_edges_bark) - 1)
    zlo = band_edges_bark(b);
    zhi = band_edges_bark(b + 1);
    % Restrict each band to audible bins so the lowest band's numbers are not
    % dominated by the out-of-range ATH near DC.
    in_band = (z_bins >= zlo) & (z_bins < zhi) & audible;
    if any(in_band)
        Ls_band  = max(P(in_band));           % band signal level (max component)
        Tmin_band = min(T_glob(in_band));      % minimum masking threshold (eq:minmask)
        smr_band = Ls_band - Tmin_band;        % signal-to-mask ratio (eq:smr)
        f_lo     = min(f_bin(in_band));
        fprintf('  [%4.1f,%4.1f)   %10.1f   %10.2f   %8.2f\n', ...
                zlo, zhi, f_lo, Ls_band, smr_band);
    end
end

fprintf('\nDone. (Run figures pop up when executed interactively.)\n');
