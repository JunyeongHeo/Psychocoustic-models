function sf = spreading_function(dz)
% SPREADING_FUNCTION  Schroeder two-slope masking spreading function.
%   sf = SPREADING_FUNCTION(dz) returns the masking attenuation in dB at a
%   Bark-axis distance dz = z_maskee - z_masker (dz may be a vector), using
%   the Schroeder two-slope form from the accompanying document
%   (equation "eq:spread"):
%
%       SF(dz) = 15.81 + 7.5*(dz + 0.474)
%              - 17.5*sqrt(1 + (dz + 0.474).^2)   [dB]
%
%   The function is asymmetric: it decays gently toward higher frequencies
%   (dz > 0) and steeply toward lower frequencies (dz < 0).
%
%   Base MATLAB / GNU Octave compatible (no toolboxes required).
%
%   Example:
%       dz = -6:0.1:6;
%       sf = spreading_function(dz);
%       plot(dz, sf); grid on;
%
%   References
%   ----------
%     * T. Painter and A. Spanias, "Perceptual Coding of Digital Audio,"
%       Proceedings of the IEEE, vol. 88, no. 4, 2000 (Schroeder two-slope
%       spreading function; see eq:spread in main.tex).
%     * ISO/IEC 11172-3 (MPEG-1 Audio).

    % Element-wise operators keep this valid for scalar or vector input.
    sf = 15.81 + 7.5 * (dz + 0.474) ...
       - 17.5 * sqrt(1 + (dz + 0.474).^2);
end
