function S = computeSignals(sender, receiver, every)
%computeSignals -- the flashes one twin sends another: when each one leaves,
%when it arrives, and how Doppler-shifted it is
%
%   S = computeSignals(trav, earth, 1)     %traveler flashes once a year, Earth watches
%
%   sender, receiver = Twin objects
%   every            = the sender's OWN (proper) time between flashes
%
%the sender flashes when its own clock reads every, 2*every, 3*every, ...
%S holds one entry per flash, all row vectors of the same length:
%   S.tau_e   sender's clock when the flash leaves
%   S.t_e     lab time it leaves          S.x_e   where it leaves from
%   S.t_rx    lab time it arrives         S.x_rx  where it arrives
%   S.tau_rx  RECEIVER's clock when it arrives
%   S.beta    how fast the two were moving apart (+) or closing in (-)
%   S.k       Doppler factor: the receiver gets flashes k times farther apart
%             than they were sent
%a flash still on its way when the mission ends has NaN for the arrival fields.
%
%this is the picture behind countDopplerSignals: that function adds up the
%rates, this one follows every individual flash. the number of flashes that
%arrive is the sender's age (in units of 'every'), with no simultaneity used.
%
%error identifiers: lightclock:badTwin, lightclock:badTime (+ dopplerFactor's)

    if ~isa(sender, 'Twin') || ~isa(receiver, 'Twin') || ~isscalar(sender) || ~isscalar(receiver)
        error('lightclock:badTwin', 'computeSignals: sender and receiver must each be one Twin.');
    end
    if ~isnumeric(every) || ~isreal(every) || ~isscalar(every) || ~isfinite(every) || every <= 0
        error('lightclock:badTime', ...
            'computeSignals: the time between flashes must be a single positive number.');
    end

    %---- leaving. the 1e-9 lets a flash due exactly at the end still count
    n       = floor(sender.tau_total / every + 1e-9);
    S.every = every;
    S.tau_e = min((1:n) * every, sender.tau_total);
    S.t_e   = labTimeAt(sender, S.tau_e);
    S.x_e   = zeros(1, n);
    S.t_rx  = NaN(1, n);   S.x_rx = NaN(1, n);   S.tau_rx = NaN(1, n);
    S.beta  = NaN(1, n);   S.k    = NaN(1, n);
    if n == 0, return; end
    S.x_e   = positionAt(sender, S.t_e);

    %---- arriving, every flash at once
    [S.t_rx, S.tau_rx] = flashArrival(receiver, S.t_e, S.x_e);
    got = ~isnan(S.t_rx);
    if ~any(got), return; end
    S.x_rx(got) = positionAt(receiver, S.t_rx(got));

    %---- Doppler shift. the sender's velocity when the flash left, measured
    %by the receiver when it arrived (velocity addition). 'before' = the leg
    %each twin was finishing, so a flash sent AT a turnaround belongs to the
    %leg it closes
    b_s   = betaAt(sender,   S.t_e(got),  'before');
    b_r   = betaAt(receiver, S.t_rx(got), 'before');
    b_rel = (b_s - b_r) ./ (1 - b_s .* b_r);

    %moving apart = the sender heading away from where its light is going.
    %if the flash didn't have to travel at all, the two are meeting, which
    %is the end of an approach
    heading = sign(S.x_rx(got) - S.x_e(got));
    apart   = -heading .* b_rel;
    apart(heading == 0) = -abs(b_rel(heading == 0));

    S.beta(got) = apart;
    S.k(got)    = dopplerFactor(apart);

end
