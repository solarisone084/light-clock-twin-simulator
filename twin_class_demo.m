%twin_class_demo.m
%
%sample use of the Twin class, plus the validation checks it makes possible:
%  1. the standard twin paradox, rebuilt as two Twin objects, must match the
%     old driver (Earth 20 yr, traveler 16 yr, turnaround jump 7.2 yr)
%  2. the same mission seen from a moving lab frame -- worldlines change,
%     proper times must not
%  3. three twins, none at rest, legs that don't line up
%  4. a step that straddles a velocity change is refused
%set show_animation = false to skip the figure.

clear all;
global c L L0
c  = 1;         %years and light-years
L  = 0.5;       %one tick per year of each clock's own time
L0 = 100;

show_animation = true;

near   = @(got, want) all(abs(got(:) - want(:)) <= 1e-9 * max(1, max(abs(want(:)))));
word   = {'FAIL', 'PASS'};
report = @(ok, msg) fprintf('  %s  %s\n', word{ok+1}, msg);

%% 1. the standard case, as objects ---------------------------------------
fprintf('\n#### 1. Earth + traveler ####\n');
earth = Twin.stationary('Earth', 20, 'L0', L0, 'Color', [0 0.447 0.741]);
trav  = Twin('Traveler', [0.6 -0.6], [10 10], 'L0', L0, 'Color', [0.85 0.325 0.098]);
twins = [earth trav];

if show_animation
    fig  = figure('Name', 'Twin class demo', 'Color', 'w');
    axC  = subplot(1, 2, 1);
    axST = subplot(1, 2, 2);
    draw(twins, axC, axST);
end

tgrid = Twin.timeGrid(twins, 200);
reset(twins, numel(tgrid) - 1);
for kk = 2:numel(tgrid)
    t_prev = tgrid(kk-1);
    advanceTo(twins, tgrid(kk));

    %print the "now on Earth" jump at every velocity change
    if any(abs(tgrid(kk) - trav.leg_beg_t(2:end)) < 1e-12)
        [~, before] = nowOn(trav, earth, 'before');
        [~, after]  = nowOn(trav, earth, 'after');
        fprintf('  t = %.2f: traveler''s "now" on Earth jumps %.3f -> %.3f yr (%+.3f)\n', ...
                trav.t, before, after, after - before);
        jump = after - before;
    end

    if show_animation && isgraphics(fig)
        update(twins);
        drawnow limitrate;
    end
end

fprintf('  Earth %.4f yr (%d ticks), traveler %.4f yr (%d ticks)\n', ...
        earth.tau, earth.ticks, trav.tau, trav.ticks);
report(near([earth.tau trav.tau], [20 16]),              'ages match the old driver (20, 16)');
report(near(jump, 7.2),                                  'turnaround jump = 7.2 yr');
report(near(trav.tau, properTimeAt(trav, trav.t)),       'stepped tau = closed-form properTimeAt');
report(near(trav.x,   positionAt(trav, trav.t)),         'stepped x = closed-form positionAt');
trips = c * [earth.tau trav.tau] / (2*L);       %a clock ending exactly on a tick
report(all([earth.ticks trav.ticks] >= floor(trips - 1e-9) & ...    %may land either side
           [earth.ticks trav.ticks] <= floor(trips + 1e-9)),  'tick counts match proper times');
report(near(relativeBetaAt(trav, earth, 5), -0.6),       'traveler sees Earth at -0.6c on leg 1');

%% 2. same mission, lab frame moving at 0.6c ------------------------------
fprintf('\n#### 2. boosted to u = 0.6 (the traveler''s outbound frame) ####\n');
bt = Twin.boost(twins, 0.6);
for i = 1:numel(bt)
    fprintf('  %-9s beta = %s   dur = %s\n', bt(i).Name, ...
            mat2str(bt(i).Profile.beta, 4), mat2str(bt(i).Profile.dur, 4));
end
tg = Twin.timeGrid(bt, 200);
reset(bt, numel(tg) - 1);
for kk = 2:numel(tg)
    advanceTo(bt, tg(kk));
end
report(near([bt.tau], [20 16]), sprintf('proper times unchanged: %.4f, %.4f', bt(1).tau, bt(2).tau));
report(abs(bt(1).Profile.beta) > 0 && bt(2).Profile.beta(1) == 0, ...
       '"Earth" moves, traveler is at rest on leg 1');

%% 3. nobody at rest, legs that don't line up ------------------------------
fprintf('\n#### 3. three twins, none stationary ####\n');
A = Twin('A', [ 0.5 -0.5],     [10 10]);
B = Twin('B', [-0.5  0.5],     [10 10]);
C = Twin('C', [ 0.8  0  -0.8], [ 5 10  5]);
grp = [A B C];
reunite = Twin.checkGroup(grp);
tg = Twin.timeGrid(grp, 100);
reset(grp, numel(tg) - 1);
for kk = 2:numel(tg)
    advanceTo(grp, tg(kk));
end
fprintf('  ages: A %.4f, B %.4f, C %.4f\n', A.tau, B.tau, C.tau);
report(reunite,                                      'all three reunite');
report(near(A.tau, B.tau),                           'mirror-image trips age the same');
report(near(C.tau, 10/gammaFactor(0.8) + 10),        'C = 10/gamma(0.8) + 10 parked = 16');
report(near([A.x B.x C.x], [0 0 0]),                 'all back at x = 0');

%% 4. a hand-made step across a velocity change is refused ---------------
fprintf('\n#### 4. error handling ####\n');
reset(twins);
try
    advanceTo(twins, 12);       %straddles the traveler's turnaround at t = 10
    report(false, 'step across the turnaround should have been refused');
catch err
    report(strcmp(err.identifier, 'lightclock:stepCrossesLeg'), ['refused: ' err.identifier]);
end
try
    Twin('bad', [0.6 1.2], [10 10]);
    report(false, 'beta = 1.2 should have been refused');
catch err
    report(strcmp(err.identifier, 'lightclock:betaOutOfRange'), ['refused: ' err.identifier]);
end
fprintf('\n');
