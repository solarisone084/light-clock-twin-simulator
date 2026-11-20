%graphics_demo.m
%
%loads a mission file and animates it. change the two settings below to pick
%the mission and how much of the picture to show:
%   'primer'      the light clocks alone, full window: time dilation and
%                 length contraction with nothing else on screen
%   'standard'    all four panels, with only the main story on the map
%   'turnaround'  the same, stopped at the turnaround to talk over
%   'everything'  all four panels and every optional layer
%then draws the still summary plot.

clear all;
global c L
c = 1;          %years and light-years

mission = 'standard.txt';
view    = 'standard';

here = fileparts(mfilename('fullpath'));
P    = loadMissionProfile(fullfile(here, 'missions', mission));
L    = P.L;

%Earth is neutral gray because it is the reference; red and blue are kept
%for the Doppler shift, so neither twin uses them
earth = Twin.stationary('Earth', sum(P.dur), 'L0', P.L0, 'Color', [0.20 0.255 0.30]);
trav  = Twin('Traveler', P.beta, P.dur,      'L0', P.L0, 'Color', [0.79 0.52 0.00]);
twins = [earth trav];

opts = struct('frames', P.frames);
switch view
    case 'primer'
        opts.panels = {'clocks'};
    case 'standard'
        %the defaults
        opts.showCone = true;
    case 'turnaround'
        opts.stopAt = trav.leg_beg_t(2);        %lab time the second leg starts
    case 'everything'
        opts.showCone = true;
        opts.showRays = true;
    otherwise
        error('demo:badView', 'view must be ''primer'', ''standard'', ''turnaround'' or ''everything''.');
end

out = animateMission(twins, opts);
fprintf('\n%s: %s aged %.2f, %s aged %.2f\n', P.name, earth.Name, earth.tau, trav.Name, trav.tau);
fprintf('flashes received: %s %d, %s %d\n', earth.Name, sum(~isnan(out.signals.toHome.t_rx)), ...
        trav.Name, sum(~isnan(out.signals.toObs.t_rx)));

drawSummaryPlot(twins);
