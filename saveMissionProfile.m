function saveMissionProfile(filename, Profile)
%saveMissionProfile -- write a mission profile to a text file
%
%   saveMissionProfile('missions/my_trip.txt', Profile)
%
%writes the format loadMissionProfile reads, so a mission typed in at the
%console can be saved and run again later:
%
%   Profile2 = loadMissionProfile(filename);     %same legs and settings back
%
%Profile is checked by validateProfile first, so a bad profile never reaches
%the disk. settings that are empty (not given) are left out of the file.
%an existing file of the same name is replaced -- ask the user before
%calling this if that matters.
%
%error identifiers: lightclock:badFilename, lightclock:fileNotWritable
%                   (+ validateProfile's)

    if isstring(filename) && isscalar(filename), filename = char(filename); end
    if ~ischar(filename) || ~isrow(filename) || isempty(strtrim(filename))
        error('lightclock:badFilename', 'saveMissionProfile: filename must be non-empty text.');
    end

    [Profile, comes_home] = validateProfile(Profile);

    %a % starts a comment in the file, so a name can't contain one
    if any(Profile.name == '%') || any(Profile.name == newline)
        error('lightclock:badProfile', ...
            'saveMissionProfile: the mission name can''t contain a %% sign or a line break.');
    end

    [fid, why] = fopen(filename, 'w');
    if fid == -1
        error('lightclock:fileNotWritable', ...
            'saveMissionProfile: can''t write "%s" (%s).', filename, why);
    end
    closer = onCleanup(@() fclose(fid));

    fprintf(fid, '%% light-clock mission profile\n');
    fprintf(fid, '%% saved %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    if ~comes_home
        fprintf(fid, '%% note: this trip does not end where it started (no reunion)\n');
    end
    fprintf(fid, '\n');

    fprintf(fid, 'name   = %s\n', Profile.name);
    if ~isempty(Profile.L),      fprintf(fid, 'L      = %.15g\n', Profile.L);      end
    if ~isempty(Profile.L0),     fprintf(fid, 'L0     = %.15g\n', Profile.L0);     end
    if ~isempty(Profile.frames), fprintf(fid, 'frames = %d\n',    Profile.frames); end

    %all the legs in one fprintf: it walks down the 2 x nlegs array a column
    %(= one leg) at a time, reusing the format for each
    fprintf(fid, '\n%% one leg per line: beta (v/c), then duration (lab-frame time)\n');
    fprintf(fid, '%8.15g   %.15g\n', [Profile.beta; Profile.dur]);

end
