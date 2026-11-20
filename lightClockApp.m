function app = lightClockApp()
%lightClockApp -- the main program: a control window for the light-clock
%twin-paradox simulation
%
%   lightClockApp           %open the control window
%   app = lightClockApp     %also return its handles (for scripted testing)
%
%the window is laid out top to bottom in the order you use it:
%   1. Mission     pick a mission file, or load one from anywhere. the files
%                  in missions/ are read at startup and standard.txt is loaded
%   2. Travel legs one row per leg: speed (v/c) and duration. edit the table,
%                  or select a row and drag the slider. the lines underneath
%                  update as you go: what that speed does to a clock and a
%                  ship, and what the whole mission will add up to
%   3. Settings    mirror separation, ship length, time steps, animation length
%   4. Show        which of the four panels to draw, and which extra layers
%   5. buttons     Run / Pause / Stop, then what to do with a finished run:
%                  save it, plot the summary, compare it with a saved one
%the line at the bottom says what just happened, or what was wrong with an
%input and how to fix it.
%
%every button goes through guard(), so a bad input shows a message in the
%window and nothing crashes. errors with a 'lightclock:' identifier are
%input problems and are reported as-is; anything else is a bug, and its
%full report is also printed to the command window.
%
%sets the globals c and L (c = 1: years and light-years).

    global c L
    c = 1; %using natural units here

    %red and blue are kept for the Doppler shift, so neither twin uses them
    EARTH_COLOR = [0.20 0.255 0.30];
    TRAV_COLOR  = [0.79 0.52 0.00];
    MAX_LEGS    = 20;
    PANEL_KEYS  = {'clocks', 'spacetime', 'signals', 'hud'};
    PANEL_NAMES = {'Light clocks', 'Trip map', 'Flashes', 'Readout'};
    LAYER_KEYS  = {'showNowLine', 'showCone', 'showRays'};
    LAYER_NAMES = {'"Right now" line', 'Light cone', 'Light rays'};
    LAYER_ON    = [true false false];

    here        = fileparts(mfilename('fullpath'));
    mission_dir = fullfile(here, 'missions');
    run_dir     = fullfile(here, 'runs');

    %everything the callbacks share. nested functions below read and change it
    S.legs    = [0.6 10; -0.6 10];  %one row per leg: [beta, duration]
    S.row     = 1;                  %the leg the slider is attached to
    S.twins   = [];                 %the twins from the last run
    S.animFig = [];                 %the animation window
    S.running = false;
    S.paused  = false;
    S.stop    = false;

    ui = buildWindow();
    guard(@startUp);

    if nargout > 0
        app.ui          = ui;
        app.loadMission = @(file) guard(@() loadMission(file));
        app.saveMission = @(file) guard(@() saveMission(file));
        app.saveRun     = @(file) guard(@() saveRun(file));
        app.compare     = @(file) guard(@() compareWith(file));
        app.twins       = @lastTwins;
    end

    
    %building the window
    
    function ui = buildWindow()
        ui.fig = uifigure('Name', 'Light-clock twin paradox: mission control', ...
                          'Position', [40 60 500 800], 'CloseRequestFcn', @(~, ~) onClose());
        main = uigridlayout(ui.fig, [6 1]);
        main.RowHeight  = {'fit', '1x', 'fit', 'fit', 'fit', 54};
        main.Scrollable = 'on';

        %1. mission
        p = uipanel(main, 'Title', '1. Mission', 'FontWeight', 'bold');
        g = uigridlayout(p, [2 3]);
        g.ColumnWidth = {90, '1x', 100};
        g.RowHeight   = {'fit', 'fit'};
        uilabel(g, 'Text', 'Mission file');
        ui.mission = uidropdown(g, 'Items', {'(none)'}, ...
                                'ValueChangedFcn', @(src, ~) guard(@() loadMission(src.Value)));
        uibutton(g, 'Text', 'Browse...', 'ButtonPushedFcn', @(~, ~) guard(@onBrowse));
        uilabel(g, 'Text', 'Name');
        ui.name = uieditfield(g, 'text', 'Value', 'mission');
        uibutton(g, 'Text', 'Save as...', 'ButtonPushedFcn', @(~, ~) guard(@onSaveMission));

        %2. legs
        p = uipanel(main, 'Title', '2. Travel legs (one row per leg, in order)', 'FontWeight', 'bold');
        g = uigridlayout(p, [5 3]);
        g.RowHeight   = {'1x', 'fit', 'fit', 'fit', 'fit'};
        g.ColumnWidth = {'1x', '1x', '1x'};
        ui.table = uitable(g, 'Data', S.legs, 'ColumnEditable', true, 'RowName', 'numbered', ...
                           'ColumnName', {'speed (v/c), + is away', 'duration (yr, Earth time)'}, ...
                           'ColumnFormat', {'numeric', 'numeric'}, 'SelectionType', 'row', ...
                           'CellEditCallback', @(~, evt) guard(@() onCellEdit(evt)), ...
                           'SelectionChangedFcn', @(~, evt) guard(@() onSelect(evt.Selection)));
        ui.table.Layout.Column = [1 3];
        uibutton(g, 'Text', 'Add leg',     'ButtonPushedFcn', @(~, ~) guard(@onAddLeg));
        uibutton(g, 'Text', 'Remove leg',  'ButtonPushedFcn', @(~, ~) guard(@onRemoveLeg));
        uibutton(g, 'Text', 'Return home', 'ButtonPushedFcn', @(~, ~) guard(@onReturnHome), ...
                 'Tooltip', 'Add a leg that brings the traveler back to Earth');
        ui.sliderLabel = uilabel(g, 'Text', 'Speed of leg 1');
        ui.slider = uislider(g, 'Limits', [-0.99 0.99], 'MajorTicks', -0.9:0.3:0.9, ...
                             'ValueChangingFcn', @(~, evt) guard(@() onSlide(evt.Value)), ...
                             'ValueChangedFcn',  @(src, ~) guard(@() onSlide(src.Value)));
        ui.slider.Layout.Column = [2 3];
        ui.effect = uilabel(g, 'Text', '', 'WordWrap', 'on');
        ui.effect.Layout.Column = [1 3];
        ui.forecast = uilabel(g, 'Text', '', 'WordWrap', 'on', 'FontWeight', 'bold');
        ui.forecast.Layout.Column = [1 3];

        %3. settings. numeric fields refuse anything outside their limits
        %on their own, so these four can't hold a bad value
        p = uipanel(main, 'Title', '3. Settings', 'FontWeight', 'bold');
        g = uigridlayout(p, [2 4]);
        g.ColumnWidth = {'fit', '1x', 'fit', '1x'};
        g.RowHeight   = {'fit', 'fit'};
        uilabel(g, 'Text', 'Mirror gap L (ly)');
        ui.L = uieditfield(g, 'numeric', 'Value', 0.5, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                           'UpperLimitInclusive', 'off', 'ValueChangedFcn', @(~, ~) guard(@refresh), ...
                           'Tooltip', 'Distance between the mirrors. 0.5 gives one tick per year');
        uilabel(g, 'Text', 'Ship rest length');
        ui.L0 = uieditfield(g, 'numeric', 'Value', 100, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                            'UpperLimitInclusive', 'off', 'Tooltip', 'Any unit. Only the ratio to the moving length matters');
        uilabel(g, 'Text', 'Time steps');
        ui.frames = uieditfield(g, 'numeric', 'Value', 500, 'Limits', [1 1e6], ...
                                'RoundFractionalValues', 'on', 'ValueDisplayFormat', '%d', ...
                                'Tooltip', 'More steps = smoother. The answers do not depend on it');
        uilabel(g, 'Text', 'Animation (s)');
        ui.duration = uieditfield(g, 'numeric', 'Value', 20, 'Limits', [0 600], ...
                                  'Tooltip', 'Seconds the animation should take. 0 = as fast as possible');

        %4. what to show. one loop builds each row of checkboxes
        p = uipanel(main, 'Title', '4. Show', 'FontWeight', 'bold');
        g = uigridlayout(p, [2 4]);
        g.RowHeight = {'fit', 'fit'};
        for kk = 1:numel(PANEL_KEYS)
            ui.panel(kk) = uicheckbox(g, 'Text', PANEL_NAMES{kk}, 'Value', true);
        end
        for kk = 1:numel(LAYER_KEYS)
            ui.layer(kk) = uicheckbox(g, 'Text', LAYER_NAMES{kk}, 'Value', LAYER_ON(kk));
        end

        %5. buttons
        g = uigridlayout(main, [2 3]);
        g.RowHeight = {34, 'fit'};
        g.Padding   = [0 0 0 0];
        ui.run   = uibutton(g, 'Text', 'Run', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) guard(@onRun));
        ui.pause = uibutton(g, 'Text', 'Pause', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) guard(@onPause));
        ui.stopB = uibutton(g, 'Text', 'Stop',  'Enable', 'off', 'ButtonPushedFcn', @(~, ~) guard(@onStop));
        uibutton(g, 'Text', 'Summary plot', 'ButtonPushedFcn', @(~, ~) guard(@onSummary));
        ui.saveRun = uibutton(g, 'Text', 'Save run...', 'Enable', 'off', ...
                              'ButtonPushedFcn', @(~, ~) guard(@onSaveRun));
        ui.compare = uibutton(g, 'Text', 'Compare with saved...', 'Enable', 'off', ...
                              'ButtonPushedFcn', @(~, ~) guard(@onCompare));

        %the message line
        ui.status = uilabel(main, 'Text', '', 'WordWrap', 'on', 'VerticalAlignment', 'top');
    end

    
    %startup: read the mission files (data from a file during initialization)
    
    function startUp()
        found = dir(fullfile(mission_dir, '*.txt'));
        if isempty(found)
            refresh();
            say(sprintf('No mission files found in %s. Using the built-in out-and-back trip.', mission_dir), true);
            return;
        end
        ui.mission.Items     = {found.name};
        ui.mission.ItemsData = fullfile({found.folder}, {found.name});

        first = find(strcmp({found.name}, 'standard.txt'), 1);
        if isempty(first), first = 1; end
        ui.mission.Value = ui.mission.ItemsData{first};
        loadMission(ui.mission.Value);
    end

    
    %mission files
    
    function loadMission(file)
        [P, comes_home] = loadMissionProfile(file);

        ui.name.Value = P.name;
        %a setting the file leaves out keeps whatever the window already has
        if ~isempty(P.L),      ui.L.Value      = P.L;      end
        if ~isempty(P.L0),     ui.L0.Value     = P.L0;     end
        if ~isempty(P.frames), ui.frames.Value = P.frames; end
        S.row = 1;
        setLegs([P.beta.', P.dur.']);

        note = '';
        if ~comes_home, note = ' Note: this trip does not come home, so there is no reunion.'; end
        say(sprintf('Loaded "%s" (%d legs).%s', P.name, P.nlegs, note), false);
    end

    function onBrowse()
        [name, folder] = uigetfile({'*.txt', 'Mission files (*.txt)'; '*.*', 'All files'}, ...
                                   'Load a mission file', mission_dir);
        figure(ui.fig);
        if isequal(name, 0), return; end            %cancelled
        file = fullfile(folder, name);
        loadMission(file);
        listMission(file);
    end

    function listMission(file)
        %make sure the dropdown lists this file, and shows it as the choice
        if ~iscell(ui.mission.ItemsData) || ~any(strcmp(ui.mission.ItemsData, file))
            [~, base, ext] = fileparts(file);
            if iscell(ui.mission.ItemsData) && ~isempty(ui.mission.ItemsData)
                ui.mission.Items     = [ui.mission.Items,     {[base ext]}];
                ui.mission.ItemsData = [ui.mission.ItemsData, {file}];
            else
                ui.mission.Items     = {[base ext]};
                ui.mission.ItemsData = {file};
            end
        end
        ui.mission.Value = file;
    end

    function onSaveMission()
        P = currentProfile();
        suggestion = fullfile(mission_dir, [regexprep(lower(P.name), '[^a-z0-9]+', '_') '.txt']);
        [name, folder] = uiputfile({'*.txt', 'Mission files (*.txt)'}, 'Save this mission', suggestion);
        figure(ui.fig);
        if isequal(name, 0), return; end
        saveMission(fullfile(folder, name));        %uiputfile has already asked about replacing a file
    end

    function saveMission(file)
        saveMissionProfile(file, currentProfile());
        listMission(file);
        say(sprintf('Mission saved to %s', file), false);
    end

    
    %the legs: table, slider, and the lines underneath
    
    function setLegs(legs)
        S.legs = legs;
        S.row  = min(max(S.row, 1), size(legs, 1));
        ui.table.Data = legs;
        refresh();
    end

    function refresh()
        %bring everything that is worked out FROM the inputs up to date
        b = S.legs(S.row, 1);
        ui.table.Selection  = S.row;
        ui.sliderLabel.Text = sprintf('Speed of leg %d', S.row);
        ui.slider.Value     = b;

        pct = 100 / gammaFactor(b);
        ui.effect.Text = sprintf(['At %.2f of light speed (gamma = %.3f): a moving clock ticks at %.0f%% ' ...
                                  'of normal, and a moving ship measures %.0f%% of its rest length.'], ...
                                 abs(b), gammaFactor(b), pct, pct);

        %what the mission will add up to, from the closed form. the animation
        %then has to arrive at the same numbers by counting ticks
        beta = S.legs(:, 1).';
        dur  = S.legs(:, 2).';
        [~, comes_home] = validateProfile(struct('beta', beta, 'dur', dur));
        earth_age = sum(dur);
        trav_age  = sum(dur ./ gammaFactor(beta));
        if comes_home
            ending = sprintf('The traveler comes home %.2f yr younger.', earth_age - trav_age);
        else
            ending = sprintf('The trip ends %.2f light-years from Earth: no reunion.', abs(sum(beta .* dur)) * c);
        end
        ui.forecast.Text = sprintf('Forecast: Earth ages %.2f yr, the traveler %.2f yr. %s', ...
                                   earth_age, trav_age, ending);
    end

    function onCellEdit(evt)
        r   = evt.Indices(1);
        col = evt.Indices(2);
        val = evt.NewData;

        %refuse a bad cell, put the old value back, and say what is allowed
        problem = '';
        switch col
            case 1
                if ~isnumeric(val) || ~isscalar(val) || ~isfinite(val) || abs(val) >= 1
                    problem = 'A speed must be a number between -1 and 1 (a fraction of light speed).';
                end
            case 2
                if ~isnumeric(val) || ~isscalar(val) || ~isfinite(val) || val <= 0
                    problem = 'A duration must be a positive number of years.';
                end
        end
        if ~isempty(problem)
            ui.table.Data = S.legs;
            say(sprintf('Leg %d not changed. %s', r, problem), true);
            return;
        end

        S.legs(r, col) = val;
        S.row = r;
        refresh();
        say(sprintf('Leg %d updated.', r), false);
    end

    function onSelect(rows)
        if isempty(rows), return; end
        S.row = rows(1);
        refresh();
    end

    function onSlide(value)
        b = max(-0.99, min(0.99, round(value, 2)));     %two decimals is as fine as a slider gets
        S.legs(S.row, 1) = b;
        ui.table.Data = S.legs;
        refresh();
    end

    function onAddLeg()
        if size(S.legs, 1) >= MAX_LEGS
            say(sprintf('A mission can have at most %d legs.', MAX_LEGS), true);
            return;
        end
        S.row = size(S.legs, 1) + 1;
        setLegs([S.legs; 0 1]);             %a parked year: harmless until edited
        say(sprintf('Leg %d added: parked for 1 yr. Edit its speed and duration.', S.row), false);
    end

    function onRemoveLeg()
        if size(S.legs, 1) <= 1
            say('A mission needs at least one leg.', true);
            return;
        end
        gone = S.row;
        legs = S.legs;
        legs(gone, :) = [];
        setLegs(legs);
        say(sprintf('Leg %d removed.', gone), false);
    end

    function onReturnHome()
        %add the one leg that brings the traveler back: same speed as the
        %last leg that moved, for however long the distance takes
        beta = S.legs(:, 1);
        dur  = S.legs(:, 2);
        x    = sum(beta .* dur) * c;
        if abs(x) < 1e-9 * max(1, sum(abs(beta .* dur)) * c)
            say('The trip already ends at Earth.', false);
            return;
        end
        if size(S.legs, 1) >= MAX_LEGS
            say(sprintf('A mission can have at most %d legs.', MAX_LEGS), true);
            return;
        end
        moving = abs(beta(beta ~= 0));
        speed  = moving(end);
        S.row  = size(S.legs, 1) + 1;
        setLegs([S.legs; -sign(x) * speed, abs(x) / (speed * c)]);
        say(sprintf('Leg %d added: back to Earth at %.2fc.', S.row, speed), false);
    end

    
    %from the window to a profile, and from a profile to twins
    
    function P = currentProfile()
        P = validateProfile(struct('beta', S.legs(:, 1).', 'dur', S.legs(:, 2).', ...
                                   'name', strtrim(ui.name.Value), 'L', ui.L.Value, ...
                                   'L0', ui.L0.Value, 'frames', ui.frames.Value));
    end

    function twins = buildTwins(P)
        L = P.L;                    %the Twin class reads the clock size from the global
        earth = Twin.stationary('Earth', sum(P.dur), 'L0', P.L0, 'Color', EARTH_COLOR);
        trav  = Twin('Traveler', P.beta, P.dur,      'L0', P.L0, 'Color', TRAV_COLOR);
        twins = [earth trav];
    end

    
    %running
    
    function onRun()
        if S.running, return; end

        [P, comes_home] = validateProfile(currentProfile());
        shown = PANEL_KEYS(logical([ui.panel.Value]));
        if isempty(shown)
            say('Nothing to draw: tick at least one panel under "Show".', true);
            return;
        end
        if ~comes_home
            answer = uiconfirm(ui.fig, ['This trip does not end at Earth, so the twins never meet again ' ...
                               'and "who is older" has no single answer. Run it anyway?'], ...
                               'No reunion', 'Options', {'Run anyway', 'Cancel'}, 'DefaultOption', 2, ...
                               'CancelOption', 2);
            if ~strcmp(answer, 'Run anyway'), return; end
        end

        twins = buildTwins(P);
        opts  = struct('frames', P.frames, 'duration', ui.duration.Value, 'keepGoing', @keepGoing);
        opts.panels = shown;
        for kk = 1:numel(LAYER_KEYS)
            opts.(LAYER_KEYS{kk}) = ui.layer(kk).Value;
        end
        if isempty(S.animFig) || ~isgraphics(S.animFig)
            S.animFig = figure('Name', 'Light-clock twin paradox', 'Color', 'w', 'Position', [560 60 1360 765]);
        end
        opts.fig = S.animFig;
        figure(S.animFig);

        setRunning(true);
        say(sprintf('Running "%s"...', P.name), false);
        try
            animateMission(twins, opts);
        catch err
            setRunning(false);
            rethrow(err);
        end
        setRunning(false);
        if ~isvalid(ui.fig), return; end        %the control window was closed mid-run

        S.twins = twins;
        set([ui.saveRun, ui.compare], 'Enable', 'on');
        earth = twins(1);
        trav  = twins(2);
        if trav.t >= trav.T_total * (1 - 1e-9)
            say(sprintf('Done. Earth aged %.2f yr (%d ticks), the traveler %.2f yr (%d ticks).', ...
                        earth.tau, earth.ticks, trav.tau, trav.ticks), false);
        else
            say(sprintf('Stopped at %.2f of %.2f yr. Earth has aged %.2f yr, the traveler %.2f yr.', ...
                        trav.t, trav.T_total, earth.tau, trav.tau), false);
        end
    end

    function go = keepGoing()
        %animateMission asks this before every step. while paused, wait here
        while S.paused && ~S.stop
            pause(0.05);
        end
        go = ~S.stop;
    end

    function setRunning(now_running)
        S.running = now_running;
        S.paused  = false;
        S.stop    = false;
        if ~isvalid(ui.fig), return; end
        onoff = {'off', 'on'};
        ui.run.Enable   = onoff{~now_running + 1};
        ui.pause.Enable = onoff{now_running + 1};
        ui.stopB.Enable = onoff{now_running + 1};
        ui.pause.Text   = 'Pause';
    end

    function onPause()
        if ~S.running, return; end
        S.paused = ~S.paused;
        if S.paused
            ui.pause.Text = 'Resume';
            say('Paused.', false);
        else
            ui.pause.Text = 'Pause';
            say('Running...', false);
        end
    end

    function onStop()
        if S.running, S.stop = true; end
    end

    function onClose()
        S.stop = true;              %lets a run in progress wind up cleanly
        delete(ui.fig);
    end

    
    %after a run
    
    function onSummary()
        drawSummaryPlot(buildTwins(currentProfile()));
        say('Summary plot drawn for the mission as it is now set up.', false);
    end

    function onSaveRun()
        requireRun();
        if ~exist(run_dir, 'dir'), mkdir(run_dir); end
        suggestion = fullfile(run_dir, [regexprep(lower(strtrim(ui.name.Value)), '[^a-z0-9]+', '_') '_run.csv']);
        [name, folder] = uiputfile({'*.csv', 'Run logs (*.csv)'}, 'Save this run', suggestion);
        figure(ui.fig);
        if isequal(name, 0), return; end
        saveRun(fullfile(folder, name));
    end

    function saveRun(file)
        requireRun();
        saveRunLog(file, S.twins);
        say(sprintf('Run saved to %s (%d rows).', file, S.twins(1).n_hist), false);
    end

    function onCompare()
        requireRun();
        [name, folder] = uigetfile({'*.csv', 'Run logs (*.csv)'}, 'Pick a saved run to compare with', run_dir);
        figure(ui.fig);
        if isequal(name, 0), return; end
        compareWith(fullfile(folder, name));
    end

    function compareWith(file)
        requireRun();
        run = loadRunLog(file);
        drawComparePlot(S.twins, run);
        say(sprintf('Comparing this run with %s (saved %s).', file, run.saved), false);
    end

    function twins = lastTwins()
        twins = S.twins;
    end

    function requireRun()
        if isempty(S.twins)
            error('lightclock:noRun', 'Run a mission first: there is nothing to save or compare yet.');
        end
    end

    
    %messages and error handling
    
    function say(msg, is_problem)
        if ~isvalid(ui.fig), return; end
        ui.status.Text = msg;
        if is_problem
            ui.status.FontColor = [0.72 0.11 0.11];
        else
            ui.status.FontColor = [0.10 0.10 0.10];
        end
    end

    function guard(action)
        %every callback runs inside this. an input problem (one of our own
        %'lightclock:' errors) becomes a message in the window. anything
        %else is a bug: say so, and print the full report for whoever fixes it
        try
            action();
        catch err
            if strncmp(err.identifier, 'lightclock:', 11)
                say(err.message, true);
            else
                say(['Something unexpected went wrong: ' err.message ...
                     ' (details are in the command window)'], true);
                fprintf(2, '%s\n', getReport(err));
            end
        end
    end

end
