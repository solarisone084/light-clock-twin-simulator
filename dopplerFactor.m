function k = dopplerFactor(beta)
%dopplerFactor -- relativistic Doppler factor k for a relative speed beta = v/c
%
%   k = dopplerFactor(0.6)    -> 2    (receding: signals arrive 2x farther apart)
%   k = dopplerFactor(-0.6)   -> 0.5  (approaching: signals arrive 2x closer together)
%
%sign convention: POSITIVE beta = source and receiver moving APART.
%if a source emits once per unit of its own proper time, the receiver gets
%one signal every k units of its own proper time, i.e. at a rate of 1/k.
%note that dopplerFactor(b) * dopplerFactor(-b) = 1 always.
%
%error identifiers: lightclock:badBeta, lightclock:betaOutOfRange

    %same checks as gammaFactor. they're repeated here rather than borrowed
    %from gammaFactor so the error message names the function that was
    %actually called
    if ~isnumeric(beta) || ~isreal(beta) || isempty(beta)
        error('lightclock:badBeta', ...
            'dopplerFactor: beta must be a real, non-empty numeric value.');
    end

    if any(isnan(beta(:)))
        error('lightclock:badBeta', ...
            'dopplerFactor: beta is NaN (probably a non-numeric input upstream).');
    end

    %at beta = 1 the denominator is zero, at beta = -1 k is zero (infinite
    %blueshift). both are light-speed cases, so both are out
    if any(abs(beta(:)) >= 1)
        error('lightclock:betaOutOfRange', ...
            'dopplerFactor: |beta| must be less than 1. Got |beta| = %g.', max(abs(beta(:))));
    end

    k = sqrt((1 + beta) ./ (1 - beta));   %element-wise

end
