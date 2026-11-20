function out = animateMission(twins, opts)
%animateMission -- run a mission and animate it in up to four panels
%
%   out = animateMission(twins)             %everything at its default
%   out = animateMission(twins, opts)       %opts = struct of the options below
%
%   twins = array of two or more Twin objects that share a mission length,
%           e.g. [earth trav]. they are reset, then stepped to the end.
%
%options (any you leave out take the default):
%   frames      500     time steps across the mission
%   panels      all     which panels to show, a cell array chosen from
%                       'clocks', 'spacetime', 'signals', 'hud'. the layout
%                       refits to whatever is asked for, so {'clocks'} gives
%                       the light clocks the whole window
%   showNowLine true    spacetime panel: the observer's "right now" line
%   showCone    false   spacetime panel: shade what the observer has seen
%   showRays    false   spacetime panel: draw each flash as a line of light
%   duration    20      seconds the whole animation should take. 0 = as fast
%                       as the computer can draw
%   holdAtTurn  1.5     extra seconds to hold still when the observer changes
%                       velocity, so the audience can see the "now" line swing
%   stopAt      Inf     lab time to stop at and leave on screen, e.g. the
%                       turnaround, to talk over a frozen picture
%   home        1       index of the stay-at-home twin
%   observer    2       index of the twin whose point of view is drawn
%   signalEvery []      proper time between flashes. [] = pick a round number
%                       that gives about 25 flashes or fewer
%   timeUnit    'yr'    text for time axes and readouts
%   lengthUnit  'light-years'   text for position axes
%   fig         []      a figure to draw in. [] = make a new one
%   keepGoing   []      a function called before every step, with no inputs,
%                       that returns true to carry on or false to stop here.
%                       it may take as long as it likes before answering,
%                       which is how the app's Pause button works
%
%   out.fig, out.ax, out.handles = the figure, the axes and each panel's handles
%   out.signals                  = the flashes (see computeSignals)
%   out.tgrid                    = the lab times that were stepped through
%
%closing the window partway does not stop the run: the physics finishes
%without drawing, so the twins always end in a state that can be saved.
%
%error identifiers: lightclock:badOption, lightclock:badTwin (+ Twin's)

    if nargin < 2, opts = struct(); end
    if ~isa(twins, 'Twin') || numel(twins) < 2
        error('lightclock:badTwin', 'animateMission: needs at least two Twin objects.');
    end
    opts = fillOptions(opts, numel(twins));

    %the four panels, in drawing order, and the function that owns each one
    PANELS = {'clocks', 'spacetime', 'signals', 'hud'};
    drawer = struct('clocks', @drawClockPanel, 'spacetime', @drawSpacetimePanel, ...
                    'signals', @drawSignalPanel, 'hud', @drawHudPanel);
    shown  = PANELS(ismember(PANELS, opts.panels));

    %---- the physics side: time steps, a clean start, and the flashes
    tgrid = Twin.timeGrid(twins, opts.frames);
    reset(twins, numel(tgrid) - 1);
    T    = tgrid(end);
    tol  = 1e-9 * max(1, T);
    home = twins(opts.home);
    obs  = twins(opts.observer);

    every = opts.signalEvery;
    if isempty(every)
        %smallest of 1, 2, 5, 10, 20, 50, ... that keeps it to about 25 flashes
        raw   = max(home.tau_total, obs.tau_total) / 25;
        steps = 10 .^ floor(log10(raw)) * [1 2 5 10];
        every = max(1, steps(find(steps >= raw, 1)));
        if raw < 0.04, every = steps(find(steps >= raw, 1)); end     %a mission shorter than one unit
    end
    opts.signals.every  = every;
    opts.signals.toHome = computeSignals(obs,  home, every);
    opts.signals.toObs  = computeSignals(home, obs,  every);

    %---- the figure
    fig = opts.fig;
    if isempty(fig)
        fig = figure('Name', 'Light-clock twin paradox', 'Color', 'w', ...
                     'Position', [60 60 1360 765]);
    else
        clf(fig);
    end
    set(fig, 'DefaultAxesFontSize', 13, 'DefaultTextFontSize', 13);
    ax = layoutPanels(fig, shown);

    H = struct();
    for kk = 1:numel(shown)
        p     = shown{kk};
        H.(p) = drawer.(p)('create', ax.(p), twins, opts);
    end
    drawnow;

    %---- the loop
    stopwatch = tic;
    held      = 0;                              %seconds spent holding at turns so far
    turn_t    = obs.leg_beg_t(2:end);           %lab times the observer changes velocity

    for kk = 2:numel(tgrid)
        if tgrid(kk) > opts.stopAt + tol, break; end
        if ~isempty(opts.keepGoing)
            asked = tic;
            go    = opts.keepGoing();
            held  = held + toc(asked);          %time spent paused doesn't count against the animation
            if ~go, break; end
        end
        advanceTo(twins, tgrid(kk));

        if ~isgraphics(fig), continue; end      %window closed: keep computing, stop drawing

        %the clock panel goes first: it sets the photon tints that update() draws
        if isfield(H, 'clocks'), H.clocks = drawClockPanel('update', H.clocks, twins); end
        update(twins);
        for jj = 1:numel(shown)
            p = shown{jj};
            if ~strcmp(p, 'clocks'), H.(p) = drawer.(p)('update', H.(p), twins); end
        end

        if opts.duration <= 0
            drawnow limitrate;
        else
            %keep animation time in step with mission time: this frame is
            %due when the same fraction of 'duration' has gone by
            wait = held + opts.duration * tgrid(kk) / T - toc(stopwatch);
            if wait > 0, pause(wait); else, drawnow limitrate; end

            if opts.holdAtTurn > 0 && any(abs(tgrid(kk) - turn_t) <= tol)
                pause(opts.holdAtTurn);
                held = held + opts.holdAtTurn;
            end
        end
    end
    if isgraphics(fig), drawnow; end

    out.fig     = fig;
    out.ax      = ax;
    out.handles = H;
    out.signals = opts.signals;
    out.tgrid   = tgrid;

end

%----------------------------------------------------------------------
function opts = fillOptions(opts, ntwins)
%fill in defaults and check every option, from one table:
%   name, default, test the value must pass, what to say if it doesn't
    if ~isstruct(opts) || ~isscalar(opts)
        error('lightclock:badOption', 'animateMission: opts must be a struct.');
    end

    PANELS  = {'clocks', 'spacetime', 'signals', 'hud'};
    isflag  = @(v) (islogical(v) || isnumeric(v)) && isscalar(v);
    isnum   = @(v) isnumeric(v) && isreal(v) && isscalar(v) && ~isnan(v);
    iswhole = @(v) isnum(v) && isfinite(v) && v == round(v);
    istext  = @(v) ischar(v) && (isrow(v) || isempty(v));

    table = {
      'frames',      500,           @(v) iswhole(v) && v >= 1 && v <= 1e6,   'a whole number from 1 to 1000000'
      'panels',      PANELS,        @(v) iscellstr(v) && ~isempty(v) && all(ismember(v, PANELS)), ...
                                                                             'a cell array chosen from ''clocks'', ''spacetime'', ''signals'', ''hud'''
      'showNowLine', true,          isflag,                                  'true or false'
      'showCone',    false,         isflag,                                  'true or false'
      'showRays',    false,         isflag,                                  'true or false'
      'duration',    20,            @(v) isnum(v) && isfinite(v) && v >= 0,  'a number of seconds, 0 or more'
      'holdAtTurn',  1.5,           @(v) isnum(v) && isfinite(v) && v >= 0,  'a number of seconds, 0 or more'
      'stopAt',      Inf,           @(v) isnum(v) && v > 0,                  'a positive lab time'
      'home',        1,             @(v) iswhole(v) && v >= 1 && v <= ntwins, sprintf('a twin number from 1 to %d', ntwins)
      'observer',    2,             @(v) iswhole(v) && v >= 1 && v <= ntwins, sprintf('a twin number from 1 to %d', ntwins)
      'signalEvery', [],            @(v) isempty(v) || (isnum(v) && isfinite(v) && v > 0), 'a positive time, or [] to choose automatically'
      'timeUnit',    'yr',          istext,                                  'text'
      'lengthUnit',  'light-years', istext,                                  'text'
      'fig',         [],            @(v) isempty(v) || (isscalar(v) && isgraphics(v, 'figure')), 'an open figure, or []'
      'keepGoing',   [],            @(v) isempty(v) || isa(v, 'function_handle'), 'a function handle, or []'
    };

    given   = fieldnames(opts);
    unknown = setdiff(given, table(:, 1));
    if ~isempty(unknown)
        error('lightclock:badOption', 'animateMission: unknown option ''%s''. options are: %s.', ...
              unknown{1}, strjoin(table(:, 1).', ', '));
    end

    for kk = 1:size(table, 1)
        name = table{kk, 1};
        if ~isfield(opts, name)
            opts.(name) = table{kk, 2};
        elseif ~table{kk, 3}(opts.(name))
            error('lightclock:badOption', 'animateMission: option ''%s'' must be %s.', name, table{kk, 4});
        end
    end

    if opts.home == opts.observer
        error('lightclock:badOption', 'animateMission: home and observer must be different twins.');
    end
end

%----------------------------------------------------------------------
function ax = layoutPanels(fig, shown)
%one axes per panel that was asked for, [] for the rest. two columns:
%clocks over spacetime on the left (they share the position axis), the
%readout over the signals on the right. a column with nothing in it gives
%its space to the other, and a panel alone in its column gets all of it
    columns = {{'clocks', 'spacetime'}, {'hud', 'signals'}};
    heights = {[0.40 0.60], [0.46 0.54]};
    widths  = [0.60 0.40];

    ax = struct('clocks', [], 'spacetime', [], 'signals', [], 'hud', []);

    used   = cellfun(@(names) any(ismember(names, shown)), columns);
    widths = widths .* used / sum(widths(used));        %unused columns shrink to nothing

    left = 0;
    for cc = 1:numel(columns)
        keep = ismember(columns{cc}, shown);
        hh   = heights{cc} .* keep / max(sum(heights{cc}(keep)), eps);
        top  = 1;
        for rr = find(keep)
            ax.(columns{cc}{rr}) = axes(fig, 'OuterPosition', [left, top - hh(rr), widths(cc), hh(rr)]);
            top = top - hh(rr);
        end
        left = left + widths(cc);
    end
end
