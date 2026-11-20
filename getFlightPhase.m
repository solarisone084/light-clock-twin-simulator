function phase = getFlightPhase(Profile, leg, first_step)
%getFlightPhase -- names what the traveler is doing on a given leg
%
%   phase = getFlightPhase(Profile, leg, first_step)
%
%   Profile    = mission struct with fields .beta (vector) and .dur (vector)
%   leg        = which leg we're on
%   first_step = true if this is the very first time step of that leg
%
%   returns one of:
%     'outbound'    beta > 0   (moving in +x, away from Earth on a normal trip)
%     'inbound'     beta < 0   (moving in -x, back toward Earth)
%     'coast'       beta = 0   (parked, not moving relative to Earth)
%     'turnaround'  first step of a leg whose direction is opposite the last
%                   leg that was actually moving. this is the instant the
%                   traveler's line of simultaneity swings.
%
%note: outbound/inbound go by the SIGN of beta, so this assumes the trip
%heads out in +x. a trip that heads out in -x will be labeled backwards.
%
%error identifiers: lightclock:badProfile, lightclock:badLeg

    if ~isstruct(Profile) || ~isfield(Profile, 'beta') || ~isfield(Profile, 'dur')
        error('lightclock:badProfile', ...
            'getFlightPhase: Profile must be a struct with fields .beta and .dur.');
    end

    nlegs = numel(Profile.beta);

    if ~isnumeric(leg) || ~isscalar(leg) || leg ~= round(leg) || leg < 1 || leg > nlegs
        error('lightclock:badLeg', ...
            'getFlightPhase: leg must be a whole number from 1 to %d.', nlegs);
    end

    b = Profile.beta(leg);

    %turnaround check: only on the first step of a leg, and only if the
    %direction actually flipped. coast legs (beta = 0) are skipped when
    %looking backward, so out -> park -> back still counts as a turnaround
    if first_step && leg > 1 && b ~= 0
        prev = Profile.beta(1:leg-1);
        prev = prev(prev ~= 0);         %only the legs that were moving
        if ~isempty(prev) && sign(prev(end)) == -sign(b)
            phase = 'turnaround';
            return;
        end
    end

    if b > 0
        phase = 'outbound';
    elseif b < 0
        phase = 'inbound';
    else
        phase = 'coast';
    end

end
