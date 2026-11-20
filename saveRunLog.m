function saveRunLog(filename, twins)
%saveRunLog -- write a finished run to a text file: settings, summary, event log
%
%   saveRunLog('runs/standard_run.csv', twins)
%
%   twins = array of Twin objects that were advanced TOGETHER (same time
%           steps), e.g. [earth trav] after the simulation loop
%
%the file has three parts:
%   1. settings, as "% key = value" lines: c, L, and for each twin its name,
%      L0, X0, color and mission legs -- everything needed to run it again
%   2. a results summary: each twin's final age and tick count, and how much
%      younger each one is than the first twin
%   3. the event log, one row per time step, comma-separated:
%         t, then for each twin:  x, tau, ticks, beta, gamma, Lc
%      (lab time, position, proper time, tick count, velocity, Lorentz
%      factor, contracted ship length)
%
%parts 1 and 2 are comment lines, so the file opens as a table in Excel or
%with readmatrix, and loadRunLog reads all of it back.
%an existing file of the same name is replaced.
%
%uses globals c and L (written into the settings).
%error identifiers: lightclock:badFilename, lightclock:badTwin,
%                   lightclock:outOfSync, lightclock:globalsNotSet,
%                   lightclock:fileNotWritable

    global c L

    PER_TWIN = {'x', 'tau', 'ticks', 'beta', 'gamma', 'Lc'};

    if isstring(filename) && isscalar(filename), filename = char(filename); end
    if ~ischar(filename) || ~isrow(filename) || isempty(strtrim(filename))
        error('lightclock:badFilename', 'saveRunLog: filename must be non-empty text.');
    end
    if ~isa(twins, 'Twin') || isempty(twins)
        error('lightclock:badTwin', 'saveRunLog: expected one or more Twin objects.');
    end
    if isempty(c) || isempty(L) || ~isscalar(c) || ~isscalar(L) || c <= 0 || L <= 0
        error('lightclock:globalsNotSet', ...
            'saveRunLog: globals c and L must be set to positive values first.');
    end

    %---- build the whole table in memory first, so nothing half-written
    %ends up on disk if the twins turn out not to match
    n     = numel(twins);
    h     = history(twins(1));
    t     = h.t;
    nrow  = numel(t);
    ncol  = 1 + numel(PER_TWIN) * n;
    tbl   = zeros(nrow, ncol);
    tbl(:, 1) = t;

    for i = 1:n
        tw = twins(i);
        h  = history(tw);
        if numel(h.t) ~= nrow || any(abs(h.t - t) > 1e-9 * max(1, max(abs(t))))
            error('lightclock:outOfSync', ...
                'saveRunLog: "%s" was not stepped together with "%s", so they can''t share a table.', ...
                tw.Name, twins(1).Name);
        end
        if any(tw.Name == newline)
            error('lightclock:badTwin', 'saveRunLog: a twin''s name can''t contain a line break.');
        end
        %gamma and Lc aren't stored in the history. they come from the beta
        %column, the whole run at once
        cols = 1 + numel(PER_TWIN) * (i-1) + (1:numel(PER_TWIN));
        tbl(:, cols) = [h.x, h.tau, h.ticks, h.beta, gammaFactor(h.beta), contractedLength(tw.L0, h.beta)];
    end

    [fid, why] = fopen(filename, 'w');
    if fid == -1
        error('lightclock:fileNotWritable', 'saveRunLog: can''t write "%s" (%s).', filename, why);
    end
    closer = onCleanup(@() fclose(fid));

    %---- 1. settings
    fprintf(fid, '%% light-clock run log\n');
    fprintf(fid, '%% format = 1\n');
    fprintf(fid, '%% saved = %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '%% c = %.15g\n', c);
    fprintf(fid, '%% L = %.15g\n', L);
    fprintf(fid, '%% ntwins = %d\n', n);
    fprintf(fid, '%% nrows = %d\n', nrow);
    for i = 1:n
        tw = twins(i);
        fprintf(fid, '%%\n');
        fprintf(fid, '%% twin%d.name = %s\n',  i, tw.Name);
        fprintf(fid, '%% twin%d.L0 = %.15g\n', i, tw.L0);
        fprintf(fid, '%% twin%d.X0 = %.15g\n', i, tw.X0);
        fprintf(fid, '%% twin%d.color = %s\n', i, strtrim(sprintf('%.15g ', tw.Color)));
        fprintf(fid, '%% twin%d.beta = %s\n',  i, strtrim(sprintf('%.15g ', tw.Profile.beta)));
        fprintf(fid, '%% twin%d.dur = %s\n',   i, strtrim(sprintf('%.15g ', tw.Profile.dur)));
    end

    %---- 2. summary (for a person to read; loadRunLog skips these lines)
    tau_end = [twins.tau];
    fprintf(fid, '%%\n%% results after %.6g of lab time, %d steps:\n', t(end), nrow - 1);
    for i = 1:n
        fprintf(fid, '%%   %-12s aged %.6f (%d ticks), final x %.6g', ...
                twins(i).Name, tau_end(i), twins(i).ticks, twins(i).x);
        if i > 1
            fprintf(fid, ', %.6f younger than %s', tau_end(1) - tau_end(i), twins(1).Name);
        end
        fprintf(fid, '\n');
    end

    %---- 3. event log. column names, then every row in ONE fprintf: the
    %format describes one row, and fprintf reuses it down the transposed table
    names = cell(1, ncol);
    names{1} = 't';
    for i = 1:n
        for kk = 1:numel(PER_TWIN)
            names{1 + numel(PER_TWIN)*(i-1) + kk} = sprintf('%s_%d', PER_TWIN{kk}, i);
        end
    end
    fprintf(fid, '%%\n%% columns = %s\n', strjoin(names, ','));

    row_fmt = [repmat('%.15g,', 1, ncol - 1), '%.15g\n'];
    fprintf(fid, row_fmt, tbl.');

end
