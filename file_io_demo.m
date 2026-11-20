%file_io_demo.m
%
%sample use of the file functions, plus the checks that they work:
%  1. every mission file in missions/ loads, runs, and gives the age the
%     closed form predicts
%  2. a profile saved with saveMissionProfile loads back identical
%  3. a finished run saved with saveRunLog loads back identical, and the
%     settings inside it are enough to run the same mission again
%  4. broken files are refused, with the right identifier and a line number
%writes runs/standard_run.csv (so there's a real log to open and look at).
%everything else it writes goes to a temporary folder that is removed after.

clear all;
global c L
c = 1;          %years and light-years
L = 0.5;        %replaced by each mission file's own L below

near   = @(got, want) isequal(size(got), size(want)) && ...
                      all(abs(got(:) - want(:)) <= 1e-9 * max(1, max(abs(want(:)))));
word   = {'FAIL', 'PASS'};
report = @(ok, msg) fprintf('  %s  %s\n', word{ok+1}, msg);

here    = fileparts(mfilename('fullpath'));
scratch = tempname;
mkdir(scratch);
tidy = onCleanup(@() rmdir(scratch, 's'));

%% 1. load and run every mission file --------------------------------------
fprintf('\n#### 1. mission files ####\n');
found = dir(fullfile(here, 'missions', '*.txt'));
report(~isempty(found), sprintf('found %d mission files in missions/', numel(found)));

fprintf('\n  %-22s %-24s legs  home   Earth    traveler\n', 'file', 'name');
all_ok = true;
for kk = 1:numel(found)
    [P, comes_home] = loadMissionProfile(fullfile(found(kk).folder, found(kk).name));
    L = P.L;

    earth = Twin.stationary('Earth', sum(P.dur), 'L0', P.L0);
    trav  = Twin('Traveler', P.beta, P.dur, 'L0', P.L0, 'Color', [0.85 0.325 0.098]);
    twins = [earth trav];

    tgrid = Twin.timeGrid(twins, P.frames);
    reset(twins, numel(tgrid) - 1);
    for step = 2:numel(tgrid)
        advanceTo(twins, tgrid(step));
    end

    yn = {'no', 'yes'};
    fprintf('  %-22s %-24s %3d   %-4s %8.4f  %8.4f\n', found(kk).name, P.name, P.nlegs, ...
            yn{comes_home + 1}, earth.tau, trav.tau);
    all_ok = all_ok && near(trav.tau, sum(P.dur ./ gammaFactor(P.beta))) && near(earth.tau, sum(P.dur));

    if strcmp(found(kk).name, 'standard.txt')
        std_twins = copy(twins);        %kept for section 3
        std_P     = P;
    end
end
fprintf('\n');
report(all_ok, 'every mission''s simulated ages match the closed form');
report(near([std_twins.tau], [20 16]), 'standard.txt gives the textbook 20 and 16 years');

%% 2. save a profile, load it back -----------------------------------------
fprintf('\n#### 2. mission profile round trip ####\n');
mine = struct('beta', [0.3 0.9 -0.45 0 -0.99], 'dur', [7 1/3 2.5 4 pi], 'name', 'made in code', ...
              'L', 0.25, 'L0', 42.5, 'frames', 120);
f = fullfile(scratch, 'mine.txt');
saveMissionProfile(f, mine);
back = loadMissionProfile(f);
report(near(back.beta, mine.beta) && near(back.dur, mine.dur), 'legs come back the same (5 legs, awkward numbers)');
report(strcmp(back.name, mine.name) && back.L == mine.L && back.L0 == mine.L0 && back.frames == mine.frames, ...
       'name, L, L0 and frames come back the same');

%settings left out of the struct are left out of the file, and load as []
saveMissionProfile(f, struct('beta', [0.6 -0.6], 'dur', [10 10]));
back = loadMissionProfile(f);
report(isempty(back.L) && isempty(back.L0) && isempty(back.frames) && back.nlegs == 2, ...
       'a profile with no settings saves and loads with the settings empty');

%% 3. save a run, load it back, run it again -------------------------------
fprintf('\n#### 3. run log round trip ####\n');
L = std_P.L;
if ~exist(fullfile(here, 'runs'), 'dir'), mkdir(fullfile(here, 'runs')); end
f = fullfile(here, 'runs', 'standard_run.csv');
saveRunLog(f, std_twins);
run = loadRunLog(f);
fprintf('  wrote %s: %d rows, %d twins, saved %s\n', f, numel(run.t), numel(run.twins), run.saved);

h1 = history(std_twins(1));
h2 = history(std_twins(2));
report(near(run.t, h1.t),                         'times match the twins'' history');
report(near(run.x,   [h1.x   h2.x]),              'positions match');
report(near(run.tau, [h1.tau h2.tau]),            'proper times match');
report(isequal(run.ticks, [h1.ticks h2.ticks]),   'tick counts match exactly');
report(near(run.Lc(:,2), std_P.L0 ./ run.gamma(:,2)), 'saved ship length = L0/gamma on every row');
report(run.c == c && run.L == L && strcmp(run.twins(2).name, std_twins(2).Name), 'settings match');

%rebuild the twins from nothing but the file, and fly the mission again
L = run.L;
again = Twin.empty(1, 0);
for i = 1:numel(run.twins)
    s = run.twins(i);
    again(i) = Twin(s.name, s.beta, s.dur, 'L0', s.L0, 'X0', s.X0, 'Color', s.color);
end
reset(again, numel(run.t) - 1);
for step = 2:numel(run.t)
    advanceTo(again, run.t(step));
end
report(near([again.tau], run.tau(end, :)) && isequal([again.ticks], run.ticks(end, :)), ...
       'twins rebuilt from the log reproduce the saved ages and ticks');

%% 4. broken files are refused ---------------------------------------------
fprintf('\n#### 4. error handling ####\n');
%what goes in the file                          identifier expected          the message must mention
bad = {
  sprintf('0.6 10\n-0.6 ten\n'),                'lightclock:badFile',        'line 2'
  sprintf('name = x\n0.6 10\n1.2 10\n'),        'lightclock:badFile',        'line 3'
  sprintf('0.6 10 5\n'),                        'lightclock:badFile',        'line 1'
  sprintf('0.6 -10\n'),                         'lightclock:badFile',        'duration'
  sprintf('speed = 3\n0.6 10\n'),               'lightclock:badFile',        'unknown setting'
  sprintf('L = 1\nL = 2\n0.6 10\n'),            'lightclock:badFile',        'set twice'
  sprintf('frames = 2.5\n0.6 10\n'),            'lightclock:badFile',        'whole number'
  sprintf('L = -1\n0.6 10\n'),                  'lightclock:badFile',        'positive'
  sprintf('%% only a comment\nname = empty\n'), 'lightclock:badFile',        'no travel legs'
};
f = fullfile(scratch, 'bad.txt');
for kk = 1:size(bad, 1)
    fid = fopen(f, 'w');
    fprintf(fid, '%s', bad{kk, 1});
    fclose(fid);
    try
        loadMissionProfile(f);
        report(false, sprintf('bad file %d should have been refused', kk));
    catch err
        report(strcmp(err.identifier, bad{kk, 2}) && contains(err.message, bad{kk, 3}), ...
               ['refused: ' strrep(err.message, [f ', '], '')]);
    end
end

%the other ways in: no such file, a bad struct, the wrong kind of file, a cut-off log
other = {
  @() loadMissionProfile(fullfile(scratch, 'nope.txt')),                 'lightclock:fileNotFound'
  @() loadMissionProfile(42),                                            'lightclock:badFilename'
  @() saveMissionProfile(f, struct('beta', [0.6 1], 'dur', [10 10])),    'lightclock:betaOutOfRange'
  @() saveMissionProfile(f, struct('beta', [0.6 0.5], 'dur', 10)),       'lightclock:badProfile'
  @() saveMissionProfile(fullfile(scratch, 'no', 'such', 'dir.txt'), mine), 'lightclock:fileNotWritable'
  @() loadRunLog(fullfile(here, 'missions', 'standard.txt')),            'lightclock:badFile'
  @() saveRunLog(f, 'not twins'),                                        'lightclock:badTwin'
};
for kk = 1:size(other, 1)
    try
        other{kk, 1}();
        report(false, sprintf('case %d should have been refused', kk));
    catch err
        report(strcmp(err.identifier, other{kk, 2}), ['refused: ' err.identifier]);
    end
end

%chop the last 200 characters off the good log: loadRunLog must notice
txt = fileread(fullfile(here, 'runs', 'standard_run.csv'));
fid = fopen(f, 'w');
fprintf(fid, '%s', txt(1:end-200));
fclose(fid);
try
    loadRunLog(f);
    report(false, 'a cut-off run log should have been refused');
catch err
    report(strcmp(err.identifier, 'lightclock:badFile') && contains(err.message, 'cut short'), ...
           'refused: a run log with its end cut off');
end
fprintf('\n');
