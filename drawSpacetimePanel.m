function h = drawSpacetimePanel(mode, varargin)
%drawSpacetimePanel -- panel 2: a map of the trip, position across, time up
%
%   h = drawSpacetimePanel('create', ax, twins, opts)   %once, before the loop
%   h = drawSpacetimePanel('update', h, twins)          %every frame, AFTER update(twins)
%
%what the audience should take from this panel:
%   - each twin traces a line; the stay-at-home twin's goes straight up
%   - the dashed line is everything the traveler calls "right now". where
%     it crosses the other twin's line is that twin's age "right now"
%   - when the traveler turns around, the dashed line swings, and its
%     crossing point jumps up the other twin's line. the highlighted stretch
%     is the jump: that is where the missing years are
%
%the twins draw their own lines (Twin.drawWorldline). this function owns the
%axes, the wording, and the layers that need two twins. each layer is
%switched by a field of opts, so the diagram can be as bare as the talk needs:
%   opts.showNowLine  the dashed "right now" line and the jump   (the main story)
%   opts.showCone     shade everything the observer could have seen so far
%   opts.showRays     draw each flash from computeSignals as a line of light
%
%   opts.home, opts.observer = which twins: the "now" line belongs to
%                              twins(opts.observer) and is read off twins(opts.home)
%   opts.signals             = struct with .toHome and .toObs from computeSignals
%   opts.timeUnit, opts.lengthUnit = text for the axis labels
%
%uses global c.
%error identifiers: lightclock:badMode (+ Twin's)

    global c

    INK  = [0.10 0.10 0.10];
    GRAY = [0.72 0.72 0.70];

    switch lower(mode)
        case 'create'
            [ax, twins, opts] = varargin{:};
            cla(ax);
            hold(ax, 'on');
            home = twins(opts.home);
            obs  = twins(opts.observer);
            xl   = Twin.xLimits(twins);

            h.ax       = ax;
            h.home     = opts.home;
            h.observer = opts.observer;
            h.xl       = xl;
            h.pad      = 0.03 * diff(xl);       %gap between a marker and its label
            h.timeUnit = opts.timeUnit;
            h.cone     = [];
            h.rays     = {};
            h.now      = [];

            %---- layers, back to front. whatever is created first sits underneath
            if opts.showCone
                h.cone = patch(ax, [0 0 0], [0 0 0], [0.98 0.78 0.20], ...
                               'FaceAlpha', 0.20, 'EdgeColor', 'none');
            end

            if opts.showRays
                %one line object per flash, two points each: where it left,
                %and how far it has got (update moves the second point)
                S_all = {opts.signals.toHome, opts.signals.toObs};
                to    = [home, obs];
                for d = 1:2
                    S   = S_all{d};
                    n   = numel(S.t_e);
                    rgb = repmat(GRAY, n, 1);               %gray = never arrives
                    got = ~isnan(S.t_rx);
                    if any(got), rgb(got, :) = dopplerColor(S.beta(got)); end

                    %which way the light goes: toward where it lands, or for
                    %one that never lands, toward where the receiver was
                    heading = sign(S.x_rx - S.x_e);
                    if any(~got)
                        heading(~got) = sign(positionAt(to(d), S.t_e(~got)) - S.x_e(~got));
                    end

                    h.rays{d}    = gobjects(1, n);
                    for kk = 1:n
                        h.rays{d}(kk) = plot(ax, NaN(1, 2), NaN(1, 2), '-', 'Color', rgb(kk, :), 'LineWidth', 1);
                    end
                    h.rayS{d}    = S;
                    h.rayDir{d}  = heading;
                end
            end

            h.cursor = plot(ax, xl, [0 0], '-', 'Color', GRAY, 'LineWidth', 1);     %shared time cursor

            drawWorldline(twins, ax);

            if opts.showNowLine
                h.now      = plot(ax, xl, [0 0], '--', 'Color', obs.Color, 'LineWidth', 1.5);
                h.nowDot   = plot(ax, NaN, NaN, 'o', 'MarkerSize', 10, 'LineWidth', 2, ...
                                  'MarkerEdgeColor', obs.Color, 'MarkerFaceColor', 'w');
                h.nowText  = text(ax, 0, 0, '', 'Color', INK, 'Visible', 'off', ...
                                  'BackgroundColor', 'w', 'Margin', 1);
                h.jumpDone = false(1, obs.Profile.nlegs);       %one flag per leg start
            end

            %---- wording
            if opts.showNowLine
                sub = sprintf('Dashed line = everything %s calls "right now"', obs.Name);
            else
                sub = 'A line that leans more is a twin moving faster';
            end
            title(ax, 'Map of the trip: position across, time up', sub);
            xlabel(ax, sprintf('position (%s)', opts.lengthUnit));
            if all(home.Profile.beta == 0)
                ylabel(ax, sprintf('time on %s''s clock (%s)', home.Name, opts.timeUnit));
            else
                ylabel(ax, sprintf('lab-frame time (%s)', opts.timeUnit));
            end
            grid(ax, 'on');
            set(ax, 'GridColor', [0.6 0.6 0.58], 'GridAlpha', 0.25, 'Layer', 'bottom');

            %---- legend, from stand-in lines so each entry looks like its layer
            key   = gobjects(1, 0);
            names = {};
            for i = 1:numel(twins)
                key(end+1)   = plot(ax, NaN, NaN, '-', 'Color', twins(i).Color, 'LineWidth', 3);
                names{end+1} = twins(i).Name;
            end
            if opts.showNowLine
                key(end+1)   = plot(ax, NaN, NaN, '--', 'Color', obs.Color, 'LineWidth', 1.5);
                names{end+1} = sprintf('%s''s "right now"', obs.Name);
            end
            if opts.showCone
                key(end+1)   = plot(ax, NaN, NaN, 's', 'MarkerSize', 11, 'MarkerEdgeColor', 'none', ...
                                    'MarkerFaceColor', [0.99 0.92 0.70]);
                names{end+1} = sprintf('what %s has seen so far', obs.Name);
            end
            legend(ax, key, names, 'Location', 'southeast', 'AutoUpdate', 'off');

            h = drawSpacetimePanel('update', h, twins);

        case 'update'
            [h, twins] = varargin{:};
            home = twins(h.home);
            obs  = twins(h.observer);
            t    = obs.t;
            tol  = 1e-9 * max(1, obs.T_total);

            set(h.cursor, 'YData', [t t]);

            if ~isempty(h.cone)
                %everything inside this triangle is close enough, and long
                %enough ago, for its light to have reached the observer by now
                set(h.cone, 'XData', [obs.x, obs.x - c*t, obs.x + c*t], 'YData', [t 0 0]);
            end

            for d = 1:numel(h.rays)
                S      = h.rayS{d};
                t_head = min(t, S.t_rx);                    %min skips NaN: unreceived flashes keep going
                x_head = S.x_e + h.rayDir{d} * c .* (t_head - S.t_e);
                sent   = S.t_e <= t + tol;
                x_head(~sent) = NaN;                        %not sent yet: nothing to draw
                set(h.rays{d}, {'XData'}, num2cell([S.x_e; x_head].', 2), ...
                               {'YData'}, num2cell([S.t_e; t_head].', 2));
            end

            if ~isempty(h.now)
                %at the very end there is no "next" leg, so use the last one
                side = 'after';
                if t >= obs.T_total - tol, side = 'before'; end

                pts = nowLine(obs, h.xl, side);             %row 1 = x, row 2 = ct
                set(h.now, 'XData', pts(1, :), 'YData', pts(2, :) / c);

                [t_home, tau_home] = nowOn(obs, home, side);
                if isnan(t_home)
                    set([h.nowDot, h.nowText], 'Visible', 'off');
                else
                    %label below a line that rises to the right, above one
                    %that falls -- unless that would push it off the top
                    where = 'top';
                    if betaAt(obs, t, side) < 0 && t_home < 0.9 * home.T_total, where = 'bottom'; end
                    x_home = positionAt(home, t_home);
                    set(h.nowDot,  'XData', x_home, 'YData', t_home, 'Visible', 'on');
                    set(h.nowText, 'Position', [x_home + h.pad, t_home, 0], 'VerticalAlignment', where, ...
                        'Visible', 'on', 'String', sprintf('%s''s clock: %.1f %s', ...
                        home.Name, tau_home, h.timeUnit));
                end

                %a velocity change swings the line. mark the stretch of the
                %other twin's line it sweeps across, once, the moment it happens
                k = obs.leg;
                if k > 1 && ~h.jumpDone(k) && abs(t - obs.leg_beg_t(k)) <= tol
                    h.jumpDone(k) = true;
                    [t0, tau0] = nowOn(obs, home, 'before');
                    [t1, tau1] = nowOn(obs, home, 'after');
                    if ~isnan(t0) && ~isnan(t1) && abs(t1 - t0) > tol
                        tt = linspace(t0, t1, 30);
                        plot(h.ax, positionAt(home, tt), tt, '-', 'Color', [obs.Color 0.35], 'LineWidth', 10);
                        text(h.ax, positionAt(home, (t0 + t1)/2) + h.pad, (t0 + t1)/2, ...
                             sprintf('"now" jumps %.1f %s', tau1 - tau0, h.timeUnit), ...
                             'Color', INK, 'FontWeight', 'bold', 'BackgroundColor', 'w', 'Margin', 1);
                        uistack([h.nowDot, h.nowText], 'top');
                    end
                end
            end

        otherwise
            error('lightclock:badMode', 'drawSpacetimePanel: mode must be ''create'' or ''update''.');
    end

end
