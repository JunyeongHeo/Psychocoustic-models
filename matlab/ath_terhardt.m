function Tq = ath_terhardt(f)
% ATH_TERHARDT  Absolute Threshold of Hearing (Terhardt approximation).
%   Tq = ATH_TERHARDT(f) returns the absolute threshold of hearing in
%   dB SPL for the frequency (vector) f given in Hz.
%
%   This implements the Terhardt formula used in the accompanying document
%   (equation "eq:ath"):
%
%       Tq(f) = 3.64*(f/1000).^(-0.8)
%             - 6.5*exp(-0.6*(f/1000 - 3.3).^2)
%             + 1e-3*(f/1000).^4        [dB SPL]
%
%   The three terms model, respectively, the low-frequency rise, the
%   sensitivity dip around 2-5 kHz, and the high-frequency rise.
%
%   Base MATLAB / GNU Octave compatible (no toolboxes required).
%
%   Example:
%       f  = logspace(log10(20), log10(20000), 500);
%       Tq = ath_terhardt(f);
%       semilogx(f, Tq); grid on;
%
%   References
%   ----------
%     * E. Terhardt, "Calculating virtual pitch," Hearing Research, vol. 1,
%       no. 2, pp. 155-182, 1979 (see eq:ath in main.tex).
%     * T. Painter and A. Spanias, "Perceptual Coding of Digital Audio,"
%       Proceedings of the IEEE, vol. 88, no. 4, 2000.
%     * ISO/IEC 11172-3 (MPEG-1 Audio).

    % Work in kHz for numerical convenience; use element-wise operators so
    % that f can be a scalar or a vector.
    fk = f / 1000;

    Tq = 3.64 * fk.^(-0.8) ...
       - 6.5  * exp(-0.6 * (fk - 3.3).^2) ...
       + 1e-3 * fk.^4;
end
