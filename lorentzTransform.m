function events_prime = lorentzTransform(events, beta)
%lorentzTransform -- boosts a list of spacetime events into a frame moving at beta
%
%   events       = N x 2 array, one event per row, columns [ct x]
%   beta         = speed of the new frame relative to the old one (v/c)
%   events_prime = N x 2 array, same events, columns [ct' x']
%
%   lorentzTransform([10 6], 0.6) -> [8 0]
%   (the event at ct=10, x=6 sits ON a clock moving at 0.6c that left the
%   origin at t=0, so in that clock's frame it's at x'=0 and ct'=10/gamma=8)
%
%the whole list gets boosted in ONE matrix multiply, no loop over events.
%
%error identifiers: lightclock:badEvents, lightclock:badBeta (+ gammaFactor's)

    %events has to be a real numeric N x 2 array
    if ~isnumeric(events) || ~isreal(events) || isempty(events) ...
            || ~ismatrix(events) || size(events, 2) ~= 2
        error('lightclock:badEvents', ...
            'lorentzTransform: events must be a real N x 2 array with columns [ct x].');
    end

    if any(~isfinite(events(:)))
        error('lightclock:badEvents', ...
            'lorentzTransform: events contains NaN or Inf.');
    end

    %one boost at a time -- a vector of betas would mean a different matrix
    %for each event, which is a different job
    if ~isscalar(beta)
        error('lightclock:badBeta', ...
            'lorentzTransform: beta must be a single value (one frame per call).');
    end

    g = gammaFactor(beta);   %also does the |beta| < 1 check

    %the 2x2 boost matrix:
    %   ct' = g*( ct - beta*x )
    %   x'  = g*( x  - beta*ct )
    Lam = g * [ 1     -beta ;
               -beta   1    ];

    %events is N x 2, so each ROW is an event. (Lam * events.') boosts every
    %column at once, then the outer transpose puts it back to N x 2.
    %(2x2)*(2xN) = 2xN, transposed = Nx2
    events_prime = (Lam * events.').';

end
