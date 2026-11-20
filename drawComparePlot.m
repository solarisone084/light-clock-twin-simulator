function fig = drawComparePlot(twins, run, fig)
%drawComparePlot -- this run against one loaded from a file
%
%   fig = drawComparePlot(twins, run)         %new figure
%   fig = drawComparePlot(twins, run, fig)    %draw in an existing one
%
%   twins = Twin objects that have just been run (their recorded history is used)
%   run   = a saved run, from loadRunLog
%
%plots every twin's age against lab time: solid lines for this run, dashed
%for the saved one, with the final age written at the end of each line. a
%twin at rest climbs at 45 degrees; the faster a twin moves, the shallower
%its line, so two missions can be compared at a glance.
%
%error identifiers: lightclock:badTwin, lightclock:badRun, lightclock:badOption

    if ~isa(twins, 'Twin') || isempty(twins)
        error('lightclock:badTwin', 'drawComparePlot: expected one or more Twin objects.');
    end
    needed = {'t', 'tau', 'twins', 'file'};
    if ~isstruct(run) || ~isscalar(run) || ~all(isfield(run, needed))
        error('lightclock:badRun', 'drawComparePlot: run must be the struct loadRunLog returns.');
    end
    if nargin < 3
        fig = figure('Name', 'Compare runs', 'Color', 'w', 'Position', [140 140 900 560]);
    elseif ~isscalar(fig) || ~isgraphics(fig, 'figure')
        error('lightclock:badOption', 'drawComparePlot: fig must be an open figure.');
    else
        clf(fig);
    end
    set(fig, 'DefaultAxesFontSize', 13, 'DefaultTextFontSize', 13);
    ax = axes(fig);
    hold(ax, 'on');
    INK = [0.1 0.1 0.1];

    key   = gobjects(1, 0);
    names = {};

    %---- the saved run first, so this run is drawn on top of it
    for i = 1:numel(run.twins)
        key(end+1)   = plot(ax, run.t, run.tau(:, i), '--', 'Color', run.twins(i).color, 'LineWidth', 2);
        names{end+1} = sprintf('%s (saved)', run.twins(i).name);
        text(ax, run.t(end), run.tau(end, i), sprintf('  %.2f', run.tau(end, i)), ...
             'Color', INK, 'VerticalAlignment', 'top');
    end

    %---- this run
    for i = 1:numel(twins)
        hst = history(twins(i));
        key(end+1)   = plot(ax, hst.t, hst.tau, '-', 'Color', twins(i).Color, 'LineWidth', 2.5);
        names{end+1} = sprintf('%s (this run)', twins(i).Name);
        text(ax, hst.t(end), hst.tau(end), sprintf('  %.2f', hst.tau(end)), ...
             'Color', INK, 'VerticalAlignment', 'bottom', 'FontWeight', 'bold');
    end

    %room on the right for the final-age labels
    t_max = max([run.t(end), max([twins.t])]);
    xlim(ax, [0, 1.10 * t_max]);
    grid(ax, 'on');
    set(ax, 'GridColor', [0.6 0.6 0.58], 'GridAlpha', 0.25, 'Box', 'on');
    xlabel(ax, 'lab-frame time');
    ylabel(ax, 'age (time on each twin''s own clock)');
    [~, base, ext] = fileparts(run.file);
    title(ax, 'How each twin aged: this run against a saved one', ...
          sprintf('saved run: %s%s, %s', base, ext, run.saved), 'Interpreter', 'none');
    legend(ax, key, names, 'Location', 'northwest', 'Interpreter', 'none');

end
