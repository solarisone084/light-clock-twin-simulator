function run = loadRunLog(filename)
%loadRunLog -- read back a run that saveRunLog wrote
%
%   run = loadRunLog('runs/standard_run.csv')
%
%returns a struct holding the whole saved run, ready to plot next to a new one:
%   run.file, run.saved      where it came from and when it was saved
%   run.c, run.L             the globals the run used
%   run.t                    nrows x 1 lab times
%   run.x, run.tau, run.ticks, run.beta, run.gamma, run.Lc
%                            nrows x ntwins, one COLUMN per twin, so
%                            plot(run.x, run.t) draws every worldline at once
%   run.twins                1 x ntwins struct array: .name, .L0, .X0, .color,
%                            .beta, .dur -- enough to rebuild each one:
%                               tw = Twin(s.name, s.beta, s.dur, 'L0', s.L0, ...
%                                         'X0', s.X0, 'Color', s.color);
%
%the file is checked as it is read: the right kind of file, every setting
%present, and a table whose size matches what the settings promise. a file
%that was cut short or edited badly is refused, not half-loaded.
%
%error identifiers: lightclock:badFilename, lightclock:fileNotFound,
%                   lightclock:badFile

    PER_TWIN = {'x', 'tau', 'ticks', 'beta', 'gamma', 'Lc'};    %same order saveRunLog writes

    if isstring(filename) && isscalar(filename), filename = char(filename); end
    if ~ischar(filename) || ~isrow(filename) || isempty(strtrim(filename))
        error('lightclock:badFilename', 'loadRunLog: filename must be non-empty text.');
    end

    fid = fopen(filename, 'r');
    if fid == -1
        error('lightclock:fileNotFound', ...
            'loadRunLog: can''t open "%s". check the name and the folder.', filename);
    end
    txt = fread(fid, '*char').';
    fclose(fid);

    %---- split into lines, then into settings (% lines) and table rows
    lines  = strtrim(regexp(txt, '\r?\n', 'split'));
    lines  = lines(~cellfun('isempty', lines));
    is_hdr = strncmp(lines, '%', 1);

    if isempty(lines) || ~strcmp(lines{1}, '% light-clock run log')
        fail(filename, 'this is not a light-clock run log (the first line doesn''t say so).');
    end

    %every "% key = value" line goes into two matching lists
    keys = {};
    vals = {};
    for kk = find(is_hdr)
        body = lines{kk}(2:end);
        eq   = find(body == '=', 1);
        if isempty(eq), continue; end           %a summary line, not a setting
        keys{end+1} = lower(strtrim(body(1:eq-1)));
        vals{end+1} = strtrim(body(eq+1:end));
    end

    if getNums(keys, vals, 'format', 1, filename) ~= 1
        fail(filename, 'this run log was written in a newer format than this program reads.');
    end

    run.file  = filename;
    run.saved = getText(keys, vals, 'saved', filename);
    run.c     = getNums(keys, vals, 'c', 1, filename);
    run.L     = getNums(keys, vals, 'l', 1, filename);
    n         = getNums(keys, vals, 'ntwins', 1, filename);
    nrow      = getNums(keys, vals, 'nrows', 1, filename);

    if n < 1 || n ~= round(n) || nrow < 1 || nrow ~= round(nrow) || run.c <= 0 || run.L <= 0
        fail(filename, 'the settings are damaged (c, L, ntwins and nrows must be positive).');
    end

    %---- per-twin settings
    for i = 1:n
        pre = sprintf('twin%d.', i);
        s.name  = getText(keys, vals, [pre 'name'], filename);
        s.L0    = getNums(keys, vals, [pre 'l0'], 1, filename);
        s.X0    = getNums(keys, vals, [pre 'x0'], 1, filename);
        s.color = getNums(keys, vals, [pre 'color'], 3, filename);
        s.beta  = getNums(keys, vals, [pre 'beta'], [], filename);
        s.dur   = getNums(keys, vals, [pre 'dur'], numel(s.beta), filename);
        run.twins(i) = s;
    end

    %---- the table. join the rows and read every number in one sscanf. it
    %stops at the first thing that isn't a number, so a damaged row shows up
    %as a wrong count
    ncol = 1 + numel(PER_TWIN) * n;
    nums = sscanf(strjoin(lines(~is_hdr), ','), '%f,');
    if numel(nums) ~= nrow * ncol
        fail(filename, sprintf(['the event log should hold %d rows of %d numbers (%d in all) ' ...
             'but %d could be read. the file was cut short or edited.'], ...
             nrow, ncol, nrow * ncol, numel(nums)));
    end
    if any(~isfinite(nums))
        fail(filename, 'the event log contains NaN or Inf.');
    end
    tbl = reshape(nums, ncol, nrow).';      %sscanf reads row by row; reshape fills by column

    %column 1 is t. after that the columns repeat x, tau, ... once per twin,
    %so each quantity is every 6th column, picked out for all twins together
    run.t = tbl(:, 1);
    for kk = 1:numel(PER_TWIN)
        run.(PER_TWIN{kk}) = tbl(:, 1 + kk : numel(PER_TWIN) : end);
    end

end

%----------------------------------------------------------------------
function txt = getText(keys, vals, key, filename)
%the text of one setting. it has to be there
    at = find(strcmp(keys, key), 1);
    if isempty(at)
        fail(filename, sprintf('the setting "%s" is missing.', key));
    end
    txt = vals{at};
end

function nums = getNums(keys, vals, key, count, filename)
%one setting as a row of numbers. count = how many there must be, [] = any (at least 1)
    txt = getText(keys, vals, key, filename);
    [nums, got, ~, next] = sscanf(txt, '%f');
    nums = nums.';
    if got < 1 || next <= numel(txt) || any(~isfinite(nums)) || (~isempty(count) && got ~= count)
        fail(filename, sprintf('the setting "%s" is damaged (got "%s").', key, txt));
    end
end

function fail(filename, msg)
    error('lightclock:badFile', '%s: %s', filename, msg);
end
