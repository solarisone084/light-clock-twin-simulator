function [line_pts, ct_earth] = simultaneityLine(event, beta, x_range)
%simultaneityLine -- the traveler's "now" line through a given event
%
%   [line_pts, ct_earth] = simultaneityLine(event, beta, x_range)
%
%   event    = 1 x 2 [ct x], the traveler's current event
%   beta     = traveler's current velocity (v/c)
%   x_range  = vector of x values to draw the line across
%   line_pts = 2 x n array, row 1 = x, row 2 = ct (ready for plot())
%   ct_earth = where the line crosses Earth's worldline (x = 0), i.e. the
%              time on Earth's clock that the traveler considers "right now"
%
%every event on the line has the same t' (same time in the traveler's frame).
%from the Lorentz transform, ct' = gamma*(ct - beta*x) = constant, so on a
%(x, ct) diagram the line has slope beta and passes through the event:
%   ct = ct_event + beta*(x - x_event)
%
%at a turnaround, beta flips sign, the slope flips, and ct_earth jumps --
%that jump is the resolution of the twin paradox.
%
%error identifiers: lightclock:badEvents, lightclock:badRange, lightclock:badBeta (+ gammaFactor's)

    if ~isnumeric(event) || ~isreal(event) || numel(event) ~= 2 || any(~isfinite(event))
        error('lightclock:badEvents', ...
            'simultaneityLine: event must be a single real, finite [ct x] pair.');
    end

    if ~isnumeric(x_range) || ~isreal(x_range) || isempty(x_range) || ~isvector(x_range) ...
            || any(~isfinite(x_range))
        error('lightclock:badRange', ...
            'simultaneityLine: x_range must be a real, finite, non-empty vector.');
    end

    if ~isscalar(beta)
        error('lightclock:badBeta', ...
            'simultaneityLine: beta must be a single value.');
    end

    %the formula itself doesn't need gamma, but |beta| >= 1 isn't a frame
    %anyone can be in, so let gammaFactor reject it
    gammaFactor(beta);

    ct_e = event(1);
    x_e  = event(2);

    x_row  = x_range(:).';                  %force to a row
    ct_row = ct_e + beta * (x_row - x_e);

    line_pts = [x_row; ct_row];
    ct_earth = ct_e - beta * x_e;           %same formula at x = 0

end
