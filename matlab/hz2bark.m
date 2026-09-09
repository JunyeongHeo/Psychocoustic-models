function z = hz2bark(f)
% HZ2BARK  Convert frequency in Hz to the Bark (critical-band) scale.
%   z = HZ2BARK(f) returns the Bark value(s) for the frequency (vector) f
%   given in Hz, using the Zwicker approximation from the accompanying
%   document (equation "eq:bark"):
%
%       z(f) = 13*atan(0.00076*f) + 3.5*atan((f/7500).^2)   [Bark]
%
%   The full audible range maps to roughly 24 Bark.
%
%   Base MATLAB / GNU Octave compatible (no toolboxes required).
%
%   Example:
%       z = hz2bark([100 1000 4000]);
%
%   References
%   ----------
%     * E. Zwicker and H. Fastl, "Psychoacoustics: Facts and Models," Springer
%       (Zwicker Bark-scale approximation; see eq:bark in main.tex).
%     * ISO/IEC 11172-3 (MPEG-1 Audio).

    % Element-wise operators keep this valid for scalar or vector input.
    z = 13 * atan(0.00076 * f) ...
      + 3.5 * atan((f / 7500).^2);
end
