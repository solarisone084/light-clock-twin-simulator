function Lc = contractedLength(L0, beta)
%contractedLength -- length of a rod as measured from a frame it moves through
%
%   Lc = contractedLength(5, 0.6)   -> 4   (5 / 1.25)
%   Lc = contractedLength(5, [0 0.6 0.8]) -> [5 4 3]
%
%L0 is the ships's rest length (measured in its own frame). only the component
%along the direction of motion contracts, which is the only one we draw.
%
%error identifiers: lightclock:badLength (here), plus whatever gammaFactor throws

    %L0 is a single physical length, so: real, positive, finite scalar
    if ~isnumeric(L0) || ~isreal(L0) || ~isscalar(L0) || ~isfinite(L0) || L0 <= 0
        error('lightclock:badLength', ...
            'contractedLength: rest length L0 must be a single positive, finite number.');
    end

    %beta is NOT checked here -- gammaFactor already does that, and its error
    %passes straight up through this function to whoever called it
    Lc = L0 ./ gammaFactor(beta);

end
