function h = drawSignalPanel(mode, varargin)
%drawSignalPanel -- panel 3: the flashes each twin actually receives
%
%   h = drawSignalPanel('create', ax, twins, opts)   %once, before the loop
%   h = drawSignalPanel('update', h, twins)          %every frame
%
%each twin sends the other a flash at regular intervals of its OWN time (a
%birthday card, if the interval is a year). this panel has one row per twin,
%laid out along that twin's own clock, with a mark for every flash at the
%moment it ARRIVES. nothing here is calculated or inferred by the twins --
%it is only what each one sees.
%
%what the audience should take from it:
%   - red marks are spread out (moving apart), blue marks are bunched up
%     (closing in). that is the Doppler effect, same as a passing siren
%   - count the marks. the number each twin has received at the end is the
%     OTHER twin's age, and the two counts are not the same
%   - the traveler switches from red to blue halfway through its trip. the
%     stay-at-home twin doesn't see the switch until much later, because the
%     news has to cross the distance. that is the whole asymmetry
%
%   opts.home, opts.observer = which two twins
%   opts.signals             = struct with .toHome and .toObs from computeSignals
%   opts.timeUnit            = text for the axis label
%
%error identifiers: lightclock:badMode (+ Twin's, dopplerColor's)

    INK   = [0.10 0.10 0.10];
    ROW_Y = [2 1];          %home's row on top, observer's below

    switch lower(mode)
        case 'create'
            [ax, twins, opts] = varargin{:};
            cla(ax);
            hold(ax, 'on');

            recv = [twins(opts.home), twins(opts.observer)];
            send = [twins(opts.observer), twins(opts.home)];
            S    = {opts.signals.toHome, opts.signals.toObs};

            h.ax       = ax;
            h.recv     = [opts.home, opts.observer];
            h.sendName = {send.Name};

            for r = 1:2
                got = ~isnan(S{r}.t_rx);
                h.t_rx{r}   = S{r}.t_rx(got);       %lab time each flash arrives (decides WHEN to show it)
                h.tau_rx{r} = S{r}.tau_rx(got);     %receiver's clock then       (decides WHERE to draw it)
                h.rgb{r}    = zeros(0, 3);
                if any(got), h.rgb{r} = dopplerColor(S{r}.beta(got)); end

                plot(ax, [0 recv(r).tau_total], ROW_Y(r) * [1 1], '-', 'Color', [0.85 0.85 0.83], 'LineWidth', 2);
                h.marks(r) = scatter(ax, NaN, NaN, 620, [0 0 0], '|', 'LineWidth', 2.5);
                h.cursor(r) = plot(ax, 0, ROW_Y(r) + 0.36, 'v', 'MarkerSize', 9, ...
                                   'MarkerFaceColor', recv(r).Color, 'MarkerEdgeColor', 'none');
                h.count(r) = text(ax, 0, ROW_Y(r) - 0.30, '', 'Color', INK, 'VerticalAlignment', 'top');
            end

            xlim(ax, [0, 1.03 * max([recv.tau_total])]);
            ylim(ax, [0.25, 2.65]);
            set(ax, 'YTick', [1 2], 'YTickLabel', {recv(2).Name, recv(1).Name}, 'TickLength', [0 0], 'Box', 'on');
            xlabel(ax, sprintf('time on the receiver''s own clock (%s)', opts.timeUnit));
            title(ax, 'What each twin actually sees', ...
                  sprintf('Each sends a flash every %g %s of its own time', opts.signals.every, opts.timeUnit));

            %color key, from stand-in marks
            key(1) = plot(ax, NaN, NaN, 's', 'MarkerSize', 9, 'MarkerEdgeColor', 'none', 'MarkerFaceColor', dopplerColor(0.6));
            key(2) = plot(ax, NaN, NaN, 's', 'MarkerSize', 9, 'MarkerEdgeColor', 'none', 'MarkerFaceColor', dopplerColor(-0.6));
            legend(ax, key, {'moving apart: flashes arrive spread out', 'closing in: flashes arrive bunched up'}, ...
                   'Location', 'southoutside', 'Box', 'off', 'AutoUpdate', 'off');

            h = drawSignalPanel('update', h, twins);

        case 'update'
            [h, twins] = varargin{:};
            for r = 1:2
                tw   = twins(h.recv(r));
                seen = h.t_rx{r} <= tw.t + 1e-9 * max(1, tw.T_total);
                n    = sum(seen);

                if n > 0
                    set(h.marks(r), 'XData', h.tau_rx{r}(seen), 'YData', ROW_Y(r) * ones(1, n), ...
                                    'CData', h.rgb{r}(seen, :));
                else
                    set(h.marks(r), 'XData', NaN, 'YData', NaN, 'CData', [0 0 0]);
                end
                set(h.cursor(r), 'XData', tw.tau);
                set(h.count(r), 'String', sprintf('%d flashes received from %s', n, h.sendName{r}));
            end

        otherwise
            error('lightclock:badMode', 'drawSignalPanel: mode must be ''create'' or ''update''.');
    end

end
