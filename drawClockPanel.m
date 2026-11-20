function h = drawClockPanel(mode, varargin)
%drawClockPanel -- panel 1: the light clocks and the ships
%
%   h = drawClockPanel('create', ax, twins, opts)   %once, before the loop
%   h = drawClockPanel('update', h, twins)          %every frame, BEFORE update(twins)
%
%what the audience should take from this panel, with nothing else explained:
%   - light bounces between two mirrors; one trip up and back is one tick
%   - the moving clock's light has to travel a slanted, longer path at the
%     same speed, so it ticks less often
%   - the moving ship is shorter than its dotted rest-length outline
%
%the twins draw themselves (Twin.drawClock). this function owns the axes,
%the wording, and the one thing that needs two twins: the Doppler tint of
%each photon, as twins(opts.home) would see that clock's light.
%
%   opts.home       = index of the twin the colors are relative to
%   opts.lengthUnit = text for the position axis, e.g. 'light-years'
%
%error identifiers: lightclock:badMode (+ Twin's)

    switch lower(mode)
        case 'create'
            [ax, twins, opts] = varargin{:};
            cla(ax);
            drawClock(twins, ax);

            title(ax, 'Light clocks: one bounce up and back = one tick', ...
                      'A moving clock''s light takes a longer, slanted path, so it ticks slower');
            xlabel(ax, sprintf('position (%s)', opts.lengthUnit));

            %the one thing in this panel that isn't obvious by looking
            text(ax, 0.99, 0.97, 'boxes: identical ships (dotted = length at rest)', ...
                 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                 'Color', [0.35 0.35 0.34], 'FontSize', 11);

            h.ax   = ax;
            h.home = opts.home;
            h = drawClockPanel('update', h, twins);

        case 'update'
            [h, twins] = varargin{:};
            home = twins(h.home);
            tol  = 1e-9 * max(1, home.T_total);

            for i = 1:numel(twins)
                tw = twins(i);
                if i == h.home
                    tw.PhotonColor = [];        %your own clock is never shifted
                    continue;
                end

                %at the very end there is no "next" leg, so look back instead
                side = 'after';
                if tw.t >= tw.T_total - tol, side = 'before'; end
                b_rel = relativeBetaAt(home, tw, tw.t, side);

                gap = tw.x - home.x;
                if abs(gap) > tol
                    apart = b_rel * sign(gap);      %moving the way it's already displaced = leaving
                elseif strcmp(side, 'after')
                    apart = abs(b_rel);             %side by side with the trip ahead: leaving
                else
                    apart = -abs(b_rel);            %side by side with the trip over: arriving
                end
                tw.PhotonColor = dopplerColor(apart);
            end

        otherwise
            error('lightclock:badMode', 'drawClockPanel: mode must be ''create'' or ''update''.');
    end

end
