function gamma = gammaFactor(beta)
%gammaFactor -- Lorentz factor for a speed (or vector of speeds) beta = v/c
%
%   gamma = gammaFactor(0.6)          -> 1.25
%   gamma = gammaFactor([0 0.6 0.8])  -> [1 1.25 1.6667]
%
%errors out (instead of returning a fake value) if beta can't be a real speed.
%error identifiers: lightclock:badBeta, lightclock:betaOutOfRange

    %type check -- has to be a real number (or numbers) before anything else
    if ~isnumeric(beta) || ~isreal(beta) || isempty(beta)
        error('lightclock:badBeta', ...
            'gammaFactor: beta must be a real, non-empty numeric value.');
    end

    %NaN gets its own check because abs(NaN) >= 1 is FALSE, so NaN would
    %slip straight past the range check below
    if any(isnan(beta(:)))
        error('lightclock:badBeta', ...
            'gammaFactor: beta is NaN (probably a non-numeric input upstream).');
    end

    %physics check -- at |beta| = 1 gamma divides by zero, past it gamma is
    %complex. neither one is a speed a clock can actually have
    if any(abs(beta(:)) >= 1)
        error('lightclock:betaOutOfRange', ...
            'gammaFactor: |beta| must be less than 1. Got |beta| = %g.', max(abs(beta(:))));
    end

    gamma = 1 ./ sqrt(1 - beta.^2);   %element-wise, so vectors work too

end
