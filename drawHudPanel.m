function h = drawHudPanel(mode, varargin)
%drawHudPanel -- panel 4: the numbers, live
%
%   h = drawHudPanel('create', ax, twins, opts)   %once, before the loop
%   h = drawHudPanel('update', h, twins)          %every frame
%
%a small table with one column per twin, and a line or two underneath that
%says in words what is happening. every number here is also drawn somewhere
%in the other panels; this is where to look to read it exactly.
%
%"clock rate" and "ship length" are both shown as a percentage of their
%at-rest values on purpose: they are always the SAME percentage (1/gamma),
%which is the point of the whole project.
%
%   opts.home, opts.observer = which twins the sentence underneath is about
%   opts.showNowLine         = include the observer's "right now" reading
%   opts.timeUnit            = text after the ages
%
%error identifiers: lightclock:badMode (+ Twin's)

    INK    = [0.10 0.10 0.10];
    MUTED  = [0.35 0.35 0.34];
    LABELS = {'age', 'clock ticks', 'speed', 'clock rate', 'ship length', ['gamma (' char(947) ')']};

    switch lower(mode)
        case 'create'
            [ax, twins, opts] = varargin{:};
            cla(ax);
            hold(ax, 'on');
            axis(ax, [0 1 0 1]);
            axis(ax, 'off');
            n = numel(twins);

            h.ax       = ax;
            h.home     = opts.home;
            h.observer = opts.observer;
            h.showNow  = opts.showNowLine;
            h.timeUnit = opts.timeUnit;

            title(ax, 'Right now', 'Visible', 'on');
            set(findall(ax, 'Type', 'text'), 'FontSize', 15);
            set(ax, 'DefaultTextFontSize', 15);      %the readout is the one panel read from the back row
            col_x = 0.36 + (0:n-1) * 0.64 / n;          %left edge of each twin's column

            %header: a color chip and the name, so the color is never the only cue
            for i = 1:n
                plot(ax, col_x(i) + 0.015, 0.90, 's', 'MarkerSize', 11, ...
                     'MarkerFaceColor', twins(i).Color, 'MarkerEdgeColor', 'none');
                text(ax, col_x(i) + 0.05, 0.90, twins(i).Name, 'Color', INK, 'FontWeight', 'bold', ...
                     'Interpreter', 'none', 'VerticalAlignment', 'middle');
            end

            %one text object per column, one line per row. same font and same
            %number of lines, so the rows line up without any measuring
            text(ax, 0, 0.82, LABELS, 'Color', MUTED, 'VerticalAlignment', 'top', 'Interpreter', 'none');
            for i = 1:n
                h.col(i) = text(ax, col_x(i), 0.82, '', 'Color', INK, 'VerticalAlignment', 'top', ...
                                'Interpreter', 'none');
            end
            h.story = text(ax, 0, 0.0, '', 'Color', INK, 'VerticalAlignment', 'bottom', 'Interpreter', 'none');

            h = drawHudPanel('update', h, twins);

        case 'update'
            [h, twins] = varargin{:};

            for i = 1:numel(twins)
                tw   = twins(i);
                rate = 100 / tw.gamma;
                ship = sprintf('%.0f%%', 100 * tw.Lc / tw.L0);
                if numel(twins) <= 2                    %room for the actual length too
                    ship = sprintf('%s  (%.4g)', ship, tw.Lc);
                end
                set(h.col(i), 'String', { ...
                    sprintf('%.2f %s', tw.tau, h.timeUnit), ...
                    sprintf('%d', tw.ticks), ...
                    sprintf('%.2f c', abs(tw.beta)), ...
                    sprintf('%.0f%%', rate), ...
                    ship, ...
                    sprintf('%.3f', tw.gamma)});
            end

            %---- the sentence underneath
            home = twins(h.home);
            obs  = twins(h.observer);
            tol  = 1e-9 * max(1, obs.T_total);
            done = obs.t >= obs.T_total - tol;

            switch obs.phase
                case 'outbound',   doing = 'heading out';
                case 'inbound',    doing = 'heading back';
                case 'coast',      doing = 'parked';
                case 'turnaround', doing = 'turning around';
                otherwise,         doing = obs.phase;
            end
            if done, doing = 'trip over'; end
            story = {sprintf('%s: %s', obs.Name, doing)};

            if h.showNow
                side = 'after';
                if done, side = 'before'; end
                [~, tau_home] = nowOn(obs, home, side);
                if ~isnan(tau_home)
                    story{end+1} = sprintf('%s''s "now": %s''s clock reads %.2f %s', ...
                                           obs.Name, home.Name, tau_home, h.timeUnit);
                end
            end

            if done && abs(obs.x - home.x) <= tol * max(1, abs(home.x))
                gap = home.tau - obs.tau;
                if abs(gap) <= tol
                    story{end+1} = 'Reunion: both twins are the same age';
                elseif gap > 0
                    story{end+1} = sprintf('Reunion: %s is %.2f %s younger', obs.Name, gap, h.timeUnit);
                else
                    story{end+1} = sprintf('Reunion: %s is %.2f %s younger', home.Name, -gap, h.timeUnit);
                end
            end
            set(h.story, 'String', story);

        otherwise
            error('lightclock:badMode', 'drawHudPanel: mode must be ''create'' or ''update''.');
    end

end
