function rgb = dopplerColor(beta)
%dopplerColor -- the color that stands for a Doppler shift: red when the
%source and receiver are moving apart, blue when they are closing in
%
%   rgb = dopplerColor(0.6)          -> red
%   rgb = dopplerColor(-0.6)         -> blue
%   rgb = dopplerColor([0.6 0 -0.3]) -> 3 x 3, one RGB row per speed
%
%   beta = relative speed (v/c), same sign convention as dopplerFactor:
%          POSITIVE = moving apart. any shape; one row of rgb comes back
%          for each element.
%
%the hue says which way, the strength says how much: the color starts at
%gray for beta = 0 and reaches full red or blue once the Doppler factor k
%is 2 (or 1/2), i.e. signals arriving at half (or double) the rate they
%were sent. shared by the photons, the signal ticks and the light rays, so
%red and blue mean the same thing in every panel.
%
%error identifiers: dopplerFactor's (lightclock:badBeta, lightclock:betaOutOfRange)

    RED     = [0.82 0.20 0.18];
    BLUE    = [0.16 0.44 0.86];
    NEUTRAL = [0.45 0.45 0.45];

    k = dopplerFactor(beta(:));             %it checks beta; column, one row per speed

    strength = min(1, abs(log2(k)));        %0 at k = 1, 1 at k = 2 or 1/2 and beyond
    pure     = repmat(RED, numel(k), 1);
    pure(k < 1, :) = repmat(BLUE, sum(k < 1), 1);

    rgb = NEUTRAL + strength .* (pure - NEUTRAL);   %every row blended at once

end
