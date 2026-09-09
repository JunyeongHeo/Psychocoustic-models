function c = pam2_unpredictability(r, phi, r1, phi1, r2, phi2)
% PAM2_UNPREDICTABILITY  MPEG-1 psychoacoustic model 2 unpredictability measure.
%   c = PAM2_UNPREDICTABILITY(r, phi, r1, phi1, r2, phi2) returns the
%   unpredictability measure c(w) in [0,1] for the current analysis frame,
%   given the current magnitude/phase spectra (r, phi) and the magnitude/phase
%   spectra of the previous two frames (r1, phi1 at t-1; r2, phi2 at t-2).
%
%   The model predicts the current magnitude and phase by linear extrapolation
%   of the previous two frames:
%
%       r_pred   = 2*r1   - r2
%       phi_pred = 2*phi1 - phi2
%
%   The unpredictability is the Euclidean distance between the actual and the
%   predicted point in the complex plane, normalised by the sum of the actual
%   and predicted magnitudes:
%
%       c(w) = || (r*cos(phi), r*sin(phi)) - (r_pred*cos(phi_pred), r_pred*sin(phi_pred)) ||
%              --------------------------------------------------------------------------
%                                        r + |r_pred|
%
%   A small eps is added to the denominator to avoid division by zero, and the
%   result is clamped to [0,1]. Values near 0 mean the component is highly
%   predictable (tone-like); values near 1 mean it is unpredictable (noise-like).
%   This continuous measure replaces the discrete tonal/non-tonal decision of
%   psychoacoustic model 1.
%
%   All inputs are vectors of the same length; all operations are element-wise,
%   so the function is base-MATLAB / GNU Octave compatible (no toolboxes).
%
%   Example:
%       c = pam2_unpredictability(r, phi, r1, phi1, r2, phi2);
%
%   References
%   ----------
%     * ISO/IEC 11172-3 (MPEG-1 Audio), Annex D, Psychoacoustic Model 2.
%     * M. Bosi and R. E. Goldberg, "Introduction to Digital Audio Coding and
%       Standards," Kluwer Academic Publishers.
%     * T. Painter and A. Spanias, "Perceptual Coding of Digital Audio,"
%       Proceedings of the IEEE, vol. 88, no. 4, pp. 451-515, 2000.
%     * cocosci, pam-nac (Python psychoacoustic model 1 + neural-codec losses),
%       https://github.com/cocosci/pam-nac
%     * K. Zhen et al., "Psychoacoustic Calibration of Loss Functions for
%       Efficient End-to-End Neural Audio Coding," IEEE SPL, 2020,
%       https://saige.sice.indiana.edu/wp-content/uploads/spl2020_kzhen.pdf

    % Linear prediction of magnitude and phase from the previous two frames.
    r_pred   = 2 * r1   - r2;
    phi_pred = 2 * phi1 - phi2;

    % Real/imaginary components of the actual and predicted spectral points.
    re_act  = r      .* cos(phi);
    im_act  = r      .* sin(phi);
    re_pred = r_pred .* cos(phi_pred);
    im_pred = r_pred .* sin(phi_pred);

    % Euclidean distance in the complex plane, normalised by the magnitudes.
    dist = sqrt((re_act - re_pred).^2 + (im_act - im_pred).^2);
    c    = dist ./ (r + abs(r_pred) + eps);

    % Clamp to [0,1]: 0 = perfectly predictable (tonal), 1 = unpredictable.
    c = max(0, min(1, c));
end
