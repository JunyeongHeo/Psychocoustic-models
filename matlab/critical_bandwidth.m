function bw = critical_bandwidth(f)
% CRITICAL_BANDWIDTH  Critical bandwidth (Hz) around frequency f (Hz).
%   bw = CRITICAL_BANDWIDTH(f) returns the critical bandwidth in Hz for the
%   frequency (vector) f, using the approximation from the accompanying
%   document (equation "eq:cbw"):
%
%       BWc(f) = 25 + 75*(1 + 1.4*(f/1000).^2).^0.69   [Hz]
%
%   It is roughly constant (~100 Hz) below 500 Hz and grows about linearly
%   with frequency above that.
%
%   Base MATLAB / GNU Octave compatible (no toolboxes required).

    bw = 25 + 75 * (1 + 1.4 * (f / 1000).^2).^0.69;
end
