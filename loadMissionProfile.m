function [Profile, comes_home] = loadMissionProfile(filename)
%loadMissionProfile -- read a mission profile from a text file
%
%   Profile = loadMissionProfile('missions/standard.txt')
%   [Profile, comes_home] = loadMissionProfile(filename)
%
%the file is plain text, made to be written by hand:
%
%       % anything after a percent sign is a comment
%       name   = Standard out-and-back
%       L      = 0.5
%       L0     = 100
%       frames = 500
%       % beta   duration
%         0.6    10
%        -0.6    10
%
%   - a line with an = sign is a setting. name, L, L0 and frames are the
%     settings, all optional, in any order, upper or lower case.
%   - any other line is one travel leg: velocity (v/c) then duration, in
%     lab-frame time, separated by spaces, tabs or a comma. at least one.
%   - blank lines are skipped.
%
%returns the same struct validateProfile does (.beta, .dur, .nlegs, .name,
%.L, .L0, .frames). a setting the file leaves out comes back as [], and
%.name falls back to the file's own name.
%
%every problem is reported with the file name and, where there is one, the
%LINE NUMBER, so a typo in a long mission file is easy to find.
%
%error identifiers: lightclock:badFilename, lightclock:fileNotFound,
%                   lightclock:badFile

    if isstring(filename) && isscalar(filename), filename = char(filename); end
    if ~ischar(filename) || ~isrow(filename) || isempty(strtrim(filename))
        error('lightclock:badFilename', 'loadMissionProfile: filename must be non-empty text.');
    end

    fid = fopen(filename, 'r');
    if fid == -1
        error('lightclock:fileNotFound', ...
            'loadMissionProfile: can''t open "%s". check the name and the folder.', filename);
    end
    closer = onCleanup(@() fclose(fid));    %closes the file however we leave, error or not

    [~, base] = fileparts(filename);
    Profile   = struct('beta', [], 'dur', [], 'name', base, 'L', [], 'L0', [], 'frames', []);
    seen      = {};         %settings already read, to catch one given twice
    line_no   = 0;

    while true
        raw = fgetl(fid);
        if ~ischar(raw), break; end         %fgetl returns -1 at the end of the file
        line_no = line_no + 1;

        %drop the comment, then the surrounding blanks
        cut = find(raw == '%', 1);
        if ~isempty(cut), raw = raw(1:cut-1); end
        txt = strtrim(raw);
        if isempty(txt), continue; end

        if any(txt == '=')
            %---- a setting: key = value
            eq  = find(txt == '=', 1);
            key = lower(strtrim(txt(1:eq-1)));
            val = strtrim(txt(eq+1:end));

            if any(strcmp(key, seen))
                fail(filename, line_no, sprintf('"%s" is set twice.', key));
            end
            seen{end+1} = key;
            if isempty(val)
                fail(filename, line_no, sprintf('"%s" has no value after the = sign.', key));
            end

            switch key
                case 'name'
                    Profile.name = val;
                case {'l', 'l0', 'frames'}
                    num = str2double(val);
                    if isnan(num)
                        fail(filename, line_no, sprintf('"%s" needs a number, got "%s".', key, val));
                    end
                    switch key
                        case 'l',      Profile.L      = num;
                        case 'l0',     Profile.L0     = num;
                        case 'frames', Profile.frames = num;
                    end
                otherwise
                    fail(filename, line_no, ...
                        sprintf('unknown setting "%s" (use name, L, L0 or frames).', key));
            end

        else
            %---- a leg: beta duration
            txt = strrep(txt, ',', ' ');
            [nums, count, ~, next] = sscanf(txt, '%f');
            if count ~= 2 || next <= numel(txt)
                %too few numbers, too many, or something that isn't a number
                fail(filename, line_no, ...
                    sprintf('expected a leg as "beta duration" (two numbers), got "%s".', txt));
            end
            b = nums(1);
            d = nums(2);
            if ~isfinite(b) || abs(b) >= 1
                fail(filename, line_no, sprintf('beta must be between -1 and 1, got %g.', b));
            end
            if ~isfinite(d) || d <= 0
                fail(filename, line_no, sprintf('duration must be a positive number, got %g.', d));
            end
            Profile.beta(end+1) = b;
            Profile.dur(end+1)  = d;
        end
    end

    if isempty(Profile.beta)
        fail(filename, 0, 'no travel legs found. a mission needs at least one "beta duration" line.');
    end

    %the legs are known good by now. this checks the settings' VALUES (L > 0,
    %frames a whole number, ...) and fills in .nlegs
    try
        [Profile, comes_home] = validateProfile(Profile);
    catch err
        if ~strncmp(err.identifier, 'lightclock:', 11), rethrow(err); end
        fail(filename, 0, regexprep(err.message, '^\w+: ', ''));
    end

end

%----------------------------------------------------------------------
function fail(filename, line_no, msg)
%every complaint about the file's contents leaves through here, so they all
%read the same way. line_no = 0 means the problem isn't on one line
    if line_no > 0
        error('lightclock:badFile', '%s, line %d: %s', filename, line_no, msg);
    else
        error('lightclock:badFile', '%s: %s', filename, msg);
    end
end
