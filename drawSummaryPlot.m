function fig = drawSummaryPlot(twins, fig)
%drawSummaryPlot -- a still picture: one curve that is both effects at once
%
%   fig = drawSummaryPlot(twins)          %new figure
%   fig = drawSummaryPlot(twins, fig)     %draw in an existing one
%
%plots 1/gamma against speed, from rest up to nearly the speed of light.
%that one curve is BOTH how fast a moving clock ticks and how long a moving
%ship measures, each as a percentage of its at-rest value. every leg of every
%twin's mission is marked on it, so the mission's own numbers can be read
%off the general rule.
%
%error identifiers: lightclock:badTwin, lightclock:badOption (+ gammaFactor's)

    if ~isa(twins, 'Twin') || isempty(twins)
        error('lightclock:badTwin', 'drawSummaryPlot: expected one or more Twin objects.');
    end
    if nargin < 2
        fig = figure('Name', 'Time dilation and length contraction', 'Color', 'w', ...
                     'Position', [120 120 900 560]);
    elseif ~isscalar(fig) || ~isgraphics(fig, 'figure')
        error('lightclock:badOption', 'drawSummaryPlot: fig must be an open figure.');
    else
        clf(fig);
    end
    set(fig, 'DefaultAxesFontSize', 13, 'DefaultTextFontSize', 13);
    ax = axes(fig);
    hold(ax, 'on');

    %the rule: the whole curve in one line of array math
    beta = linspace(0, 0.999, 400);
    plot(ax, beta, 100 ./ gammaFactor(beta), '-', 'Color', [0.35 0.35 0.34], 'LineWidth', 2);

    %this mission: one marker per distinct speed each twin flies at
    for i = 1:numel(twins)
        tw    = twins(i);
        speed = unique(abs(tw.Profile.beta));
        pct   = 100 ./ gammaFactor(speed);
        plot(ax, speed, pct, 'o', 'MarkerSize', 11, 'MarkerFaceColor', tw.Color, ...
             'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
        for kk = 1:numel(speed)
            text(ax, speed(kk), pct(kk), sprintf('   %s at %.2fc: %.0f%%', tw.Name, speed(kk), pct(kk)), ...
                 'Color', [0.1 0.1 0.1], 'VerticalAlignment', 'bottom');
        end
    end

    xlim(ax, [0 1]);
    ylim(ax, [0 108]);
    grid(ax, 'on');
    set(ax, 'GridColor', [0.6 0.6 0.58], 'GridAlpha', 0.25, 'Box', 'on');
    xlabel(ax, 'speed, as a fraction of the speed of light');
    ylabel(ax, 'percent of the at-rest value');
    title(ax, 'One curve, two effects', ...
          'How fast a moving clock ticks, and how long a moving ship measures');

end
