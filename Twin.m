classdef Twin < matlab.mixin.Copyable
%Twin -- one twin: mission profile, light clock, recorded history, and its own graphics
%
%   T = Twin(name, beta, dur)
%   T = Twin(name, beta, dur, 'L0', 100, 'Color', [0.85 0.33 0.10], 'X0', 0)
%   E = Twin.stationary('Earth', 20)            %beta = 0 for 20 years
%
%   name  = label used in printouts and on the plots
%   beta  = vector of leg velocities (v/c), each with |beta| < 1. sign is
%           measured in the LAB frame, not relative to any other twin
%   dur   = vector of leg durations in LAB-frame (coordinate) time
%   L0    = ship rest length (default 1, any unit -- only L0/gamma is drawn)
%   Color = 1x3 RGB in [0,1], used by every artist this twin draws
%   X0    = lab-frame position at t = 0 (default 0)
%
%"Earth" is not special here. it's a Twin whose profile is beta = 0, so the
%standard twin paradox is just two Twin objects, and a run where nobody is at
%rest in the lab frame is the same code with different numbers.
%
%handle class: methods change the twin in place (twin.reset(...), not
%twin = twin.reset(...)). b = a makes a second NAME for the same twin; use
%c = copy(a) for an independent one. copies don't share graphics.
%
%most methods work on an ARRAY of twins, e.g.
%   twins = [Twin.stationary('Earth', 20), Twin('Traveler', [0.6 -0.6], [10 10])];
%   reset(twins, n_steps);  advanceTo(twins, t);  update(twins);
%
%graphics: each twin owns its own artists (clock, photon, ship, worldline).
%   drawClock(twins, ax)      light clocks and ships, one lane per twin
%   drawWorldline(twins, ax)  worldlines on a position/time diagram
%   draw(twins, axC, axST)    both at once
%   update(twins)             move everything to match the current state
%the panel functions (drawClockPanel, drawSpacetimePanel, ...) own the axes
%and anything that involves two twins at once.
%
%the pure physics (gammaFactor, dopplerFactor, lorentzTransform,
%contractedLength, simultaneityLine, getFlightPhase) stays in its own
%functions. this class calls them; it doesn't replace them.
%
%uses globals c and L.
%error identifiers: lightclock:globalsNotSet, lightclock:badName,
%   lightclock:badProfile, lightclock:badOption, lightclock:badColor,
%   lightclock:badTime, lightclock:badSide, lightclock:badGroup,
%   lightclock:outOfSync, lightclock:badTimeStep, lightclock:stepCrossesLeg,
%   lightclock:badFrames, lightclock:badBoost, lightclock:badTwin,
%   lightclock:badAxes
%   (+ gammaFactor's, contractedLength's, getFlightPhase's)

    %------------------------------------------------------------------
    properties
        Name  = 'twin'
        Color = [0 0.447 0.741]
        PhotonColor = []    %color of the photon and its trail. [] = same as Color.
                            %drawClockPanel sets this to the Doppler tint
    end

    %set once by the constructor -- change the mission by making a new Twin
    properties (SetAccess = private)
        Profile             %struct: .beta, .dur, .nlegs, .name (same shape the driver uses)
        L0                  %ship rest length
        X0                  %lab position at t = 0

        %per-leg quantities, all legs at once (array math, computed once)
        gamma_vec           %Lorentz factor of each leg
        Lc_vec              %ship length the LAB frame measures on each leg
        leg_beg_t           %lab time each leg starts
        leg_end_t           %lab time each leg ends
        x_leg_start         %lab position at the start of each leg
        tau_leg_start       %proper time already elapsed when each leg starts
    end

    %the clock state -- one twin's column of the old state struct
    properties (SetAccess = private)
        t          = 0      %lab time this twin has been advanced to
        x          = 0      %lab position (accumulated step by step, NOT closed form)
        tau        = 0      %proper time (accumulated step by step, NOT closed form)
        ticks      = 0      %completed photon round trips
        photon_y   = 0      %photon height, 0 to L
        photon_dir = 1      %+1 going up, -1 going down

        hist                %step-by-step record, one row per recorded instant
        n_hist     = 0      %rows of hist actually filled
    end

    properties (Constant)
        HIST_COLS = {'t', 'x', 'tau', 'ticks', 'photon_y', 'beta'}

        %graphics. the clock panel is drawn in units of L, in lanes stacked
        %bottom to top, each LANE_H tall
        CLOCK_GFX   = {'hShipGhost', 'hShip', 'hMirrors', 'hPhotonTrail', 'hPhoton', 'hLabel'}
        ST_GFX      = {'hPlanned', 'hTrail', 'hNow'}
        LANE_H      = 2.3       %height of one twin's lane
        MIRROR_Y    = 0.6       %bottom mirror, measured from the bottom of the lane
        SHIP_Y      = [0.14 0.30]   %ship rectangle: bottom, height
        GHOST_PAD   = [0 -0.07 0 0.14]  %rest-length outline vs the ship: [x y w h] added
        TRAIL_TICKS = 2.5       %the photon trail lasts this many ticks of a clock at rest
    end

    %computed on demand from the state above, never stored
    properties (Dependent)
        T_total             %lab-frame length of the whole mission
        tau_total           %this twin's own (proper) time for the whole mission
        leg                 %leg the twin is on right now
        beta                %current velocity (v/c)
        gamma               %current Lorentz factor
        Lc                  %current contracted ship length
        phase               %'outbound' / 'inbound' / 'coast' / 'turnaround'
    end

    %graphics handles. Transient = not written out by save(), since a handle
    %to a figure that no longer exists is meaningless when loaded back
    properties (Transient, SetAccess = private)
        hShipGhost          %dotted outline of the ship at its REST length
        hShip               %the ship as the lab frame measures it: width x Lc/L0
        hMirrors            %the two mirrors of this twin's light clock
        hPhotonTrail        %the photon's recent path, fading out with age
        hPhoton             %the bouncing photon
        hLabel              %tick count above the clock
        hPlanned            %full planned worldline (faint)
        hTrail              %worldline traced so far, fading with age
        hNow                %current event on the spacetime diagram
        lane                %y of the bottom of this twin's lane in the clock panel
        mirror_hw           %half-width of the mirrors, in position units
        ship_w              %drawn width of the ship at rest, in position units
    end


    methods

        function obj = Twin(name, beta, dur, varargin)
            %MATLAB calls this with no arguments when it has to pad an object
            %array (e.g. twins(3) = ... with twins(2) never set). give it a
            %harmless stationary twin rather than a half-built one
            if nargin == 0
                name = 'twin';
                beta = 0;
                dur  = 1;
            elseif nargin < 3
                error('lightclock:badProfile', ...
                    'Twin: needs at least a name, a beta vector and a duration vector.');
            end

            [c, ~] = Twin.globals();

            %---- name
            if isstring(name) && isscalar(name), name = char(name); end
            if ~ischar(name) || isempty(strtrim(name))
                error('lightclock:badName', 'Twin: name must be non-empty text.');
            end

            %---- profile. checked with OUR identifiers, not MATLAB's property
            %validators, so the driver's isOurs() catches these as input errors
            if ~isnumeric(beta) || ~isreal(beta) || isempty(beta) || ~isvector(beta)
                error('lightclock:badProfile', ...
                    'Twin "%s": beta must be a real, non-empty vector.', name);
            end
            if ~isnumeric(dur) || ~isreal(dur) || ~isvector(dur) || numel(dur) ~= numel(beta)
                error('lightclock:badProfile', ...
                    'Twin "%s": dur must be a real vector the same length as beta (%d).', ...
                    name, numel(beta));
            end
            if any(~isfinite(dur)) || any(dur <= 0)
                error('lightclock:badProfile', ...
                    'Twin "%s": every leg duration must be a positive, finite number.', name);
            end
            beta = double(beta(:).');
            dur  = double(dur(:).');

            %---- options, name/value pairs
            L0    = 1;
            X0    = 0;
            color = [];
            if mod(numel(varargin), 2) ~= 0
                error('lightclock:badOption', ...
                    'Twin "%s": options come in name/value pairs.', name);
            end
            for kk = 1:2:numel(varargin)
                opt = varargin{kk};
                val = varargin{kk+1};
                if ~ischar(opt) && ~(isstring(opt) && isscalar(opt))
                    error('lightclock:badOption', 'Twin "%s": option names must be text.', name);
                end
                switch lower(char(opt))
                    case 'l0'
                        L0 = val;               %contractedLength checks it below
                    case 'x0'
                        if ~isnumeric(val) || ~isreal(val) || ~isscalar(val) || ~isfinite(val)
                            error('lightclock:badOption', ...
                                'Twin "%s": X0 must be a single real, finite number.', name);
                        end
                        X0 = double(val);
                    case 'color'
                        color = val;            %set.Color checks it below
                    otherwise
                        error('lightclock:badOption', ...
                            'Twin "%s": unknown option ''%s'' (use L0, X0 or Color).', name, char(opt));
                end
            end

            %---- per-leg quantities. gammaFactor rejects |beta| >= 1 and NaN,
            %contractedLength rejects a bad L0, so nothing is checked twice
            obj.gamma_vec = gammaFactor(beta);
            obj.Lc_vec    = contractedLength(L0, beta);

            obj.Name    = name;
            obj.L0      = L0;
            obj.X0      = X0;
            obj.Profile = struct('beta', beta, 'dur', dur, 'nlegs', numel(beta), 'name', name);
            if ~isempty(color), obj.Color = color; end

            obj.leg_end_t     = cumsum(dur);
            obj.leg_beg_t     = [0, obj.leg_end_t(1:end-1)];
            dx                = beta * c .* dur;
            obj.x_leg_start   = X0 + [0, cumsum(dx(1:end-1))];
            dtau              = dur ./ obj.gamma_vec;
            obj.tau_leg_start = [0, cumsum(dtau(1:end-1))];

            reset(obj, 0);
        end

        %property set/get
        function set.Color(obj, val)
            if ~isnumeric(val) || ~isreal(val) || numel(val) ~= 3 || any(~isfinite(val(:))) ...
                    || any(val(:) < 0) || any(val(:) > 1)
                error('lightclock:badColor', 'Twin: Color must be an RGB triple with values in [0, 1].');
            end
            obj.Color = double(val(:).');
        end

        function val = get.T_total(obj)
            val = obj.leg_end_t(end);
        end

        function val = get.tau_total(obj)
            val = obj.tau_leg_start(end) + obj.Profile.dur(end) / obj.gamma_vec(end);
        end

        function val = get.leg(obj)
            val = legAt(obj, obj.t, 'after');
        end

        function val = get.beta(obj)
            val = obj.Profile.beta(obj.leg);
        end

        function val = get.gamma(obj)
            val = obj.gamma_vec(obj.leg);
        end

        function val = get.Lc(obj)
            val = obj.Lc_vec(obj.leg);
        end

        function val = get.phase(obj)
            %getFlightPhase still makes the call. note "outbound" means +x in
            %the LAB frame -- relative to another twin, see relativeBetaAt
            k = obj.leg;
            first_step = abs(obj.t - obj.leg_beg_t(k)) <= Twin.tolFor(obj.T_total);
            val = getFlightPhase(obj.Profile, k, first_step);
        end

        %closed-form lookups
        %all of these take ANY array of lab times and answer for all of them
        %at once -- one call gives a whole worldline for plotting

        function k = legAt(obj, t, side)
            %legAt -- which leg is the twin on at lab time(s) t
            %   side = 'after' (default): at a leg boundary, the leg that STARTS there
            %   side = 'before':          at a leg boundary, the leg that ENDS there
            if nargin < 3, side = 'after'; end
            Twin.requireScalar(obj, 'legAt');
            tol = Twin.tolFor(obj.T_total);

            if ~isnumeric(t) || ~isreal(t) || isempty(t) || any(~isfinite(t(:)))
                error('lightclock:badTime', 'Twin "%s": times must be real and finite.', obj.Name);
            end
            if any(t(:) < -tol) || any(t(:) > obj.T_total + tol)
                error('lightclock:badTime', ...
                    'Twin "%s": time %g is outside the mission (0 to %g).', ...
                    obj.Name, t(find(t(:) < -tol | t(:) > obj.T_total + tol, 1)), obj.T_total);
            end

            %(nlegs x 1) compared against (1 x ntimes): every time against
            %every leg start in one shot, then count the starts already passed
            tr  = t(:).';
            beg = obj.leg_beg_t(:);
            switch lower(side)
                case 'after'
                    k = sum(tr >= beg - tol, 1);
                case 'before'
                    k = sum(tr > beg + tol, 1);
                otherwise
                    error('lightclock:badSide', 'legAt: side must be ''before'' or ''after''.');
            end
            k = min(max(k, 1), obj.Profile.nlegs);
            k = reshape(k, size(t));
        end

        function b = betaAt(obj, t, side)
            if nargin < 3, side = 'after'; end
            b = obj.Profile.beta(legAt(obj, t, side));
            b = reshape(b, size(t));
        end

        function xx = positionAt(obj, t)
            %exact lab position -- what the stepped x should agree with
            [c, ~] = Twin.globals();
            k  = legAt(obj, t);
            xx = obj.x_leg_start(k) + obj.Profile.beta(k) * c .* (t - obj.leg_beg_t(k));
            xx = reshape(xx, size(t));
        end

        function tt = properTimeAt(obj, t)
            %exact proper time -- what the stepped tau should agree with
            k  = legAt(obj, t);
            tt = obj.tau_leg_start(k) + (t - obj.leg_beg_t(k)) ./ obj.gamma_vec(k);
            tt = reshape(tt, size(t));
        end

        function t = labTimeAt(obj, tau)
            %labTimeAt -- the inverse of properTimeAt: the lab time at which
            %this twin's own clock reads tau. proper time is a straight line
            %in lab time on each leg, so it's one interpolation between the
            %leg corners, for any array of tau
            Twin.requireScalar(obj, 'labTimeAt');
            if isempty(tau), t = zeros(size(tau)); return; end
            tol = Twin.tolFor(obj.tau_total);
            if ~isnumeric(tau) || ~isreal(tau) || any(~isfinite(tau(:))) ...
                    || any(tau(:) < -tol) || any(tau(:) > obj.tau_total + tol)
                error('lightclock:badTime', ...
                    'Twin "%s": proper times must be between 0 and %g.', obj.Name, obj.tau_total);
            end
            tau = min(max(tau, 0), obj.tau_total);
            t   = interp1([obj.tau_leg_start, obj.tau_total], [obj.leg_beg_t, obj.T_total], tau);
        end

        function [xx, yy, tt] = photonPath(obj, ta, tb)
            %photonPath -- the exact path of this twin's photon between lab
            %times ta and tb, as the LAB frame sees it: a zigzag, because the
            %clock moves sideways while the photon goes up and down.
            %   xx = lab position, yy = height between the mirrors (0 to L),
            %   tt = lab time of each point
            %the corners are computed, not sampled: one point for every mirror
            %hit and every velocity change, so the zigzag is sharp at any
            %frame rate
            Twin.requireScalar(obj, 'photonPath');
            [c, L] = Twin.globals();
            if ~isnumeric(ta) || ~isnumeric(tb) || ~isscalar(ta) || ~isscalar(tb) || ~(tb >= ta)
                error('lightclock:badTime', 'photonPath: needs two lab times, ta <= tb.');
            end

            tau    = properTimeAt(obj, [ta tb]);
            hits   = (ceil(tau(1)*c/L) : floor(tau(2)*c/L)) * L / c;   %proper times of the mirror hits
            hits   = hits(hits >= 0 & hits <= obj.tau_total);
            turns  = obj.leg_beg_t(obj.leg_beg_t > ta & obj.leg_beg_t < tb);
            tt     = unique([ta, labTimeAt(obj, hits), turns, tb]);
            tt     = min(max(tt, ta), tb);

            xx = positionAt(obj, tt);
            p  = mod(c * properTimeAt(obj, tt), 2*L);      %distance since the last tick, 0 to 2L
            yy = L - abs(p - L);                            %up for the first L, back down for the second
        end

        function [t_rx, tau_rx] = flashArrival(receiver, t_e, x_e)
            %flashArrival -- when does a flash of light reach this twin?
            %   t_e, x_e = lab time and position of each flash (same size;
            %              any number of flashes at once)
            %   t_rx     = lab time each flash arrives
            %   tau_rx   = what this twin's own clock reads when it does
            %both are NaN for a flash still in flight when the mission ends.
            %
            %on leg j the twin is at   x = xs_j + b_j*c*(t - ts_j)
            %light going in direction n (+1 or -1) is at  x = x_e + n*c*(t - t_e)
            %set them equal:  t = (xs_j - b_j*c*ts_j - x_e + n*c*t_e) / (c*(n - b_j))
            %|b_j| < 1, so that never divides by zero. every flash is tried
            %against every leg in both directions at once (flashes down,
            %legs across), and the earliest answer that lands inside its leg wins
            Twin.requireScalar(receiver, 'flashArrival');
            [c, ~] = Twin.globals();
            if ~isnumeric(t_e) || ~isnumeric(x_e) || ~isreal(t_e) || ~isreal(x_e) ...
                    || ~isequal(size(t_e), size(x_e)) || any(~isfinite(t_e(:))) || any(~isfinite(x_e(:)))
                error('lightclock:badTime', ...
                    'flashArrival: t_e and x_e must be real, finite arrays of the same size.');
            end

            te  = t_e(:);
            xe  = x_e(:);
            b   = receiver.Profile.beta;
            ts  = receiver.leg_beg_t;
            tf  = receiver.leg_end_t;
            xs  = receiver.x_leg_start;
            tol = Twin.tolFor(receiver.T_total);

            cand = zeros(numel(te), 0);
            for n = [1 -1]
                t  = (xs - b*c.*ts - xe + n*c*te) ./ (c * (n - b));
                ok = t >= ts - tol & t <= tf + tol & t >= te - tol;
                t(~ok) = Inf;
                cand = [cand, t];
            end
            t_first = min(cand, [], 2);
            got     = isfinite(t_first);

            t_rx   = NaN(size(t_e));
            tau_rx = NaN(size(t_e));
            if any(got)
                t_rx(got)   = min(max(t_first(got), te(got)), receiver.T_total);
                tau_rx(got) = properTimeAt(receiver, t_rx(got));
            end
        end

        function ev = worldline(obj)
            %worldline -- the corners of the worldline as an N x 2 [ct x]
            %array, ready for lorentzTransform or plot(ev(:,2), ev(:,1))
            Twin.requireScalar(obj, 'worldline');
            [c, ~] = Twin.globals();
            x_end = obj.x_leg_start(end) + obj.Profile.beta(end) * c * obj.Profile.dur(end);
            ev = [c * [0, obj.leg_end_t].', [obj.x_leg_start, x_end].'];
        end

        %two-twin questions
        function br = relativeBetaAt(observer, other, t, side)
            %relativeBetaAt -- velocity of OTHER as measured by OBSERVER (v/c),
            %by relativistic velocity addition. positive = other moving in +x
            %in the observer's frame. with observer = Earth this is just other's beta
            if nargin < 4, side = 'after'; end
            Twin.requireScalar(observer, 'relativeBetaAt');
            Twin.requireScalar(other, 'relativeBetaAt');
            bo = betaAt(observer, t, side);
            bx = betaAt(other, t, side);
            br = (bx - bo) ./ (1 - bo .* bx);
        end

        function [t_other, tau_other] = nowOn(observer, other, side)
            %nowOn -- the generalized ct_earth. where the observer's current
            %line of simultaneity crosses OTHER's worldline:
            %   t_other   = lab time of that event
            %   tau_other = what other's clock reads there, i.e. how old the
            %               observer thinks the other twin is "right now"
            %side = 'before'/'after' picks the frame at a velocity change, so
            %   nowOn(a, b, 'after') - nowOn(a, b, 'before') is the jump.
            %returns NaN if "now" falls before or after other's mission.
            %
            %other's worldline is straight on each leg, so it's one linear
            %solve per leg, all legs at once:
            %   now line:  ct = ct_e + b_o*(x - x_e)
            %   leg j:     x  = xs_j + b_j*c*(t - ts_j)
            %   =>  t = (c*t_e + b_o*(xs_j - b_j*c*ts_j - x_e)) / (c*(1 - b_o*b_j))
            if nargin < 3, side = 'after'; end
            Twin.requireScalar(observer, 'nowOn');
            Twin.requireScalar(other, 'nowOn');
            [c, ~] = Twin.globals();

            t_e = observer.t;
            x_e = observer.x;
            b_o = betaAt(observer, t_e, side);
            gammaFactor(b_o);                  %same frame check simultaneityLine does

            b  = other.Profile.beta;
            ts = other.leg_beg_t;
            te = other.leg_end_t;
            xs = other.x_leg_start;

            t_cand = (c*t_e + b_o * (xs - b*c.*ts - x_e)) ./ (c * (1 - b_o * b));

            tol = Twin.tolFor(other.T_total);
            j   = find(t_cand >= ts - tol & t_cand <= te + tol, 1);
            if isempty(j)
                t_other   = NaN;
                tau_other = NaN;
            else
                t_other   = min(max(t_cand(j), 0), other.T_total);
                tau_other = properTimeAt(other, t_other);
            end
        end

        function line_pts = nowLine(obj, x_range, side)
            %nowLine -- points for drawing this twin's line of simultaneity
            %through its current event (thin wrapper on simultaneityLine)
            if nargin < 3, side = 'after'; end
            Twin.requireScalar(obj, 'nowLine');
            [c, ~] = Twin.globals();
            line_pts = simultaneityLine([c*obj.t, obj.x], betaAt(obj, obj.t, side), x_range);
        end

        %simulation
        function reset(twins, n_steps)
            %reset -- back to t = 0, photon on the bottom mirror, and room for
            %n_steps more rows of history (it grows if you go past that)
            if nargin < 2, n_steps = 0; end
            if ~isnumeric(n_steps) || ~isscalar(n_steps) || n_steps < 0 || n_steps ~= round(n_steps)
                error('lightclock:badFrames', 'reset: n_steps must be a whole number >= 0.');
            end
            for i = 1:numel(twins)
                tw = twins(i);
                tw.t          = 0;
                tw.x          = tw.X0;
                tw.tau        = 0;
                tw.ticks      = 0;
                tw.photon_y   = 0;
                tw.photon_dir = 1;
                tw.hist       = zeros(n_steps + 1, numel(Twin.HIST_COLS));
                tw.n_hist     = 0;
                record(tw);
            end
        end

        function advance(twins, dt)
            %advance -- move every twin forward by lab time dt
            if isempty(twins)
                error('lightclock:badTwin', 'advance: no twins given.');
            end
            if ~isnumeric(dt) || ~isreal(dt) || ~isscalar(dt) || ~isfinite(dt) || dt <= 0
                error('lightclock:badTimeStep', 'advance: dt must be a single positive, finite number.');
            end
            advanceTo(twins, twins(1).t + dt);
        end

        function advanceTo(twins, t1)
            %advanceTo -- move every twin forward to lab time t1, together.
            %
            %proper time and position are ACCUMULATED here (dtau = dt/gamma,
            %dx = v*dt), never looked up from the closed form, so comparing
            %them with properTimeAt/positionAt afterward is a real test.
            %
            %a step may not straddle a velocity change -- that would use the
            %wrong gamma for part of it. Twin.timeGrid builds steps that
            %never do; a hand-made grid that does gets lightclock:stepCrossesLeg.
            if isempty(twins)
                error('lightclock:badTwin', 'advanceTo: no twins given.');
            end
            [c, L] = Twin.globals();

            t_all = [twins.t];
            T_all = [twins.T_total];
            tol   = Twin.tolFor(max(T_all));
            if max(t_all) - min(t_all) > tol
                error('lightclock:outOfSync', ...
                    'advanceTo: twins are at different times (%g to %g). reset them together.', ...
                    min(t_all), max(t_all));
            end
            t0 = t_all(1);

            if ~isnumeric(t1) || ~isreal(t1) || ~isscalar(t1) || ~isfinite(t1)
                error('lightclock:badTimeStep', 'advanceTo: target time must be a single finite number.');
            end
            if t1 <= t0
                error('lightclock:badTimeStep', 'advanceTo: target t = %g is not after the current t = %g.', t1, t0);
            end
            if t1 > min(T_all) + tol
                error('lightclock:badTimeStep', ...
                    'advanceTo: t = %g is past the end of a mission (%g).', t1, min(T_all));
            end
            dt = t1 - t0;

            %---- per twin: which leg, and how much proper time passes
            n    = numel(twins);
            v    = zeros(1, n);
            dtau = zeros(1, n);
            for i = 1:n
                tw = twins(i);
                k0 = legAt(tw, t0, 'after');
                k1 = legAt(tw, t1, 'before');
                if k0 ~= k1
                    error('lightclock:stepCrossesLeg', ...
                        ['advanceTo: the step %g -> %g crosses a velocity change for "%s" ' ...
                         '(at t = %g). build the steps with Twin.timeGrid.'], ...
                        t0, t1, tw.Name, tw.leg_end_t(k0));
                end
                v(i)    = tw.Profile.beta(k0) * c;
                dtau(i) = dt / tw.gamma_vec(k0);
            end

            %---- photons, all twins at once. same unfolded-round-trip math as
            %advanceLightClock: p = distance since the last tick, 0 to 2L
            y   = [twins.photon_y];
            dir = [twins.photon_dir];
            tk  = [twins.ticks];

            p        = y;
            down     = dir < 0;
            p(down)  = 2*L - y(down);

            p_new    = p + c * dtau;
            tk       = tk + floor(p_new / (2*L));
            p        = mod(p_new, 2*L);

            down     = p > L;
            y        = p;
            y(down)  = 2*L - p(down);
            dir      = ones(1, n);
            dir(down) = -1;

            %---- write back and log
            for i = 1:n
                tw = twins(i);
                tw.t          = t1;
                tw.x          = tw.x + v(i) * dt;
                tw.tau        = tw.tau + dtau(i);
                tw.ticks      = tk(i);
                tw.photon_y   = y(i);
                tw.photon_dir = dir(i);
                record(tw);
            end
        end

        function h = history(obj)
            %history -- the recorded run as a struct of column vectors,
            %h.t, h.x, h.tau, h.ticks, h.photon_y, h.beta
            Twin.requireScalar(obj, 'history');
            rows = obj.hist(1:obj.n_hist, :);
            for kk = 1:numel(Twin.HIST_COLS)
                h.(Twin.HIST_COLS{kk}) = rows(:, kk);
            end
        end

        %graphics
        function draw(twins, axClock, axST)
            %draw -- create every twin's artists ONCE. after this, update()
            %only moves them; nothing gets re-plotted per frame.
            %   axClock = axes for the light clocks and ships ([] to skip)
            %   axST    = axes for the position/time diagram  ([] to skip)
            if ~isempty(axClock), drawClock(twins, axClock); end
            if ~isempty(axST),    drawWorldline(twins, axST); end
        end

        function drawClock(twins, ax)
            %drawClock -- light clocks and ships. across is real lab-frame
            %position, so a moving clock really moves and its photon leaves a
            %slanted path behind it. each twin gets its own lane (first twin
            %on top) so two twins at the same place don't cover each other.
            %up/down is in units of L: every clock is drawn 1 tall.
            %
            %the ship is drawn far bigger than life (a 100 m ship is nothing
            %next to a light-year). only its width RELATIVE to the dotted
            %rest-length outline means anything: that ratio is Lc/L0.
            Twin.requireAxes(ax, 'drawClock');
            n  = numel(twins);
            xl = Twin.xLimits(twins);
            hw = 0.030 * diff(xl);
            W  = 0.160 * diff(xl);
            hold(ax, 'on');

            for i = 1:n
                tw = twins(i);
                deleteGraphics(tw, Twin.CLOCK_GFX);
                tw.lane      = (n - i) * Twin.LANE_H;
                tw.mirror_hw = hw;
                tw.ship_w    = W;
                col = tw.Color;
                ym  = tw.lane + Twin.MIRROR_Y;
                box = [tw.x - W/2, tw.lane + Twin.SHIP_Y(1), W, Twin.SHIP_Y(2)];

                %the outline is a little taller than the ship so it shows
                %around it even when the ship is at its full rest length
                tw.hShipGhost   = rectangle(ax, 'Position', box + Twin.GHOST_PAD, 'FaceColor', 'none', ...
                                            'EdgeColor', [0.40 0.40 0.40], 'LineStyle', ':', 'LineWidth', 1);
                tw.hShip        = rectangle(ax, 'Position', box, 'FaceColor', col, 'EdgeColor', 'none');
                tw.hMirrors     = plot(ax, tw.x + hw*[-1 1 NaN -1 1], ym + [0 0 NaN 1 1], ...
                                       '-', 'Color', col, 'LineWidth', 4);
                %a patch, not a line, because only a patch can fade along its length
                tw.hPhotonTrail = patch(ax, 'Vertices', [tw.x, ym], 'Faces', [1 1], ...
                                        'FaceColor', 'none', 'EdgeColor', col, 'LineWidth', 2, ...
                                        'EdgeAlpha', 'interp', 'FaceVertexAlphaData', 1, ...
                                        'AlphaDataMapping', 'none');
                tw.hPhoton      = plot(ax, tw.x, ym, 'o', 'MarkerSize', 9, ...
                                       'MarkerFaceColor', col, 'MarkerEdgeColor', 'w', 'LineWidth', 1);
                tw.hLabel       = text(ax, tw.x, ym + 1.10, '', 'HorizontalAlignment', 'center', ...
                                       'VerticalAlignment', 'bottom', 'Color', [0.1 0.1 0.1]);
            end

            %lane dividers and names. lanes run bottom to top, twins top to bottom
            for k = 1:n-1
                plot(ax, xl, k * Twin.LANE_H * [1 1], '-', 'Color', [0.88 0.88 0.86]);
            end
            xlim(ax, xl);
            ylim(ax, [0, n * Twin.LANE_H]);
            set(ax, 'YTick', ((1:n) - 0.5) * Twin.LANE_H, 'YTickLabel', fliplr({twins.Name}), ...
                    'TickLength', [0 0], 'Box', 'on');

            update(twins);
        end

        function drawWorldline(twins, ax)
            %drawWorldline -- each twin's path on a position/time diagram:
            %position across, LAB time up. the planned path is a faint dotted
            %line; the part already traveled is drawn over it by update()
            Twin.requireAxes(ax, 'drawWorldline');
            [c, ~] = Twin.globals();
            hold(ax, 'on');

            for i = 1:numel(twins)
                tw = twins(i);
                deleteGraphics(tw, Twin.ST_GFX);
                col = tw.Color;
                ev  = worldline(tw);

                tw.hPlanned = plot(ax, ev(:,2), ev(:,1) / c, ':', 'Color', col, 'LineWidth', 1);
                tw.hTrail   = patch(ax, 'Vertices', [tw.x, tw.t], 'Faces', [1 1], ...
                                    'FaceColor', 'none', 'EdgeColor', col, 'LineWidth', 3, ...
                                    'EdgeAlpha', 'interp', 'FaceVertexAlphaData', 1, ...
                                    'AlphaDataMapping', 'none');
                tw.hNow     = plot(ax, tw.x, tw.t, 'o', 'MarkerSize', 9, 'MarkerFaceColor', col, ...
                                   'MarkerEdgeColor', 'w', 'LineWidth', 1);
            end

            xlim(ax, Twin.xLimits(twins));
            ylim(ax, [0, max([twins.T_total])]);
            set(ax, 'Box', 'on');

            update(twins);
        end

        function update(twins)
            %update -- move every artist to match the current state. only
            %sets data on artists that already exist: nothing is re-plotted
            [c, L] = Twin.globals();
            trail_T = Twin.TRAIL_TICKS * 2 * L / c;     %lab time the photon trail lasts

            for i = 1:numel(twins)
                tw = twins(i);

                %---- light clock and ship (skipped if never drawn, or closed)
                if ~isempty(tw.hPhoton) && isgraphics(tw.hPhoton)
                    ym  = tw.lane + Twin.MIRROR_Y;
                    W   = tw.ship_w;
                    w   = W * tw.Lc / tw.L0;
                    col = tw.PhotonColor;
                    if isempty(col), col = tw.Color; end

                    %the photon's recent path: exact zigzag, newest end solid
                    ta = max(0, tw.t - trail_T);
                    if tw.t > ta
                        [px, py, pt] = photonPath(tw, ta, tw.t);
                    else
                        px = tw.x;  py = tw.photon_y;  pt = tw.t;
                    end
                    m = numel(px);
                    set(tw.hPhotonTrail, 'Vertices', [px(:), ym + py(:) / L], ...
                        'Faces', [1:m, m:-1:1], ...         %out and back: an open line, not a closed shape
                        'FaceVertexAlphaData', max(0, 1 - (tw.t - pt(:)) / trail_T), 'EdgeColor', col);

                    set(tw.hPhoton,    'XData', tw.x, 'YData', ym + tw.photon_y / L, 'MarkerFaceColor', col);
                    set(tw.hMirrors,   'XData', tw.x + tw.mirror_hw * [-1 1 NaN -1 1]);
                    set(tw.hShipGhost, 'Position', [tw.x - W/2, tw.lane + Twin.SHIP_Y(1), W, Twin.SHIP_Y(2)] ...
                                                   + Twin.GHOST_PAD);
                    set(tw.hShip,      'Position', [tw.x - w/2, tw.lane + Twin.SHIP_Y(1), w, Twin.SHIP_Y(2)]);
                    set(tw.hLabel,     'Position', [tw.x, ym + 1.10, 0], ...
                                       'String', sprintf('%d ticks', tw.ticks));
                end

                %---- worldline so far, fading toward the past
                if ~isempty(tw.hNow) && isgraphics(tw.hNow)
                    rows = tw.hist(1:tw.n_hist, :);
                    m    = tw.n_hist;
                    set(tw.hTrail, 'Vertices', rows(:, [2 1]), 'Faces', [1:m, m:-1:1], ...
                        'FaceVertexAlphaData', linspace(0.35, 1, m).');
                    set(tw.hNow, 'XData', tw.x, 'YData', tw.t);
                end
            end
        end

        function deleteGraphics(twins, which)
            %deleteGraphics -- remove these twins' artists. which = cell array
            %of handle property names (default: all of them)
            if nargin < 2, which = [Twin.CLOCK_GFX, Twin.ST_GFX]; end
            for i = 1:numel(twins)
                tw = twins(i);
                for kk = 1:numel(which)
                    h = tw.(which{kk});
                    if ~isempty(h) && all(isgraphics(h))
                        delete(h);
                    end
                    tw.(which{kk}) = [];
                end
            end
        end
    end


    methods (Access = protected)
        function cp = copyElement(obj)
            %copy() gets the physics and history but NOT the artists --
            %otherwise two twins would fight over the same line objects
            cp = copyElement@matlab.mixin.Copyable(obj);
            gfx = [Twin.CLOCK_GFX, Twin.ST_GFX, {'lane', 'mirror_hw', 'ship_w'}];
            for kk = 1:numel(gfx)
                cp.(gfx{kk}) = [];
            end
        end
    end

    methods (Access = private)
        function record(obj)
            obj.n_hist = obj.n_hist + 1;
            obj.hist(obj.n_hist, :) = [obj.t, obj.x, obj.tau, obj.ticks, obj.photon_y, ...
                                       betaAt(obj, obj.t, 'after')];
        end
    end


    methods (Static)
        function tw = stationary(name, T, varargin)
            %stationary -- a twin parked at its start position for lab time T
            tw = Twin(name, 0, T, varargin{:});
        end

        function tw = fromProfile(Profile, varargin)
            %fromProfile -- build a twin from the struct your driver (or a
            %future loadMissionProfile) produces: fields .beta, .dur, .name
            if ~isstruct(Profile) || ~isscalar(Profile) || ~isfield(Profile, 'beta') || ~isfield(Profile, 'dur')
                error('lightclock:badProfile', 'fromProfile: Profile must be a struct with .beta and .dur.');
            end
            name = 'twin';
            if isfield(Profile, 'name'), name = Profile.name; end
            tw = Twin(name, Profile.beta, Profile.dur, varargin{:});
        end

        function reunite = checkGroup(twins)
            %checkGroup -- twins that run together must share a lab-frame
            %mission length. returns true if they all END at the same place
            %(a reunion), which is what makes the age comparison meaningful
            if isempty(twins) || ~isa(twins, 'Twin')
                error('lightclock:badTwin', 'checkGroup: expected one or more Twin objects.');
            end
            T_all = [twins.T_total];
            tol   = Twin.tolFor(max(T_all));
            if max(T_all) - min(T_all) > tol
                error('lightclock:badGroup', ...
                    'checkGroup: missions must last the same lab time (got %g to %g).', ...
                    min(T_all), max(T_all));
            end
            x_end = zeros(1, numel(twins));
            for i = 1:numel(twins)
                ev = worldline(twins(i));
                x_end(i) = ev(end, 2);
            end
            reunite = max(x_end) - min(x_end) <= 1e-9 * max(1, max(abs(x_end)));
        end

        function tgrid = timeGrid(twins, n_frames)
            %timeGrid -- about n_frames lab-time steps across the mission,
            %with EVERY twin's velocity changes landing exactly on a step.
            %the union of all the twins' breakpoints is what makes this work
            %when their legs don't line up
            Twin.checkGroup(twins);
            if ~isnumeric(n_frames) || ~isscalar(n_frames) || ~isfinite(n_frames) ...
                    || n_frames < 1 || n_frames ~= round(n_frames)
                error('lightclock:badFrames', 'timeGrid: n_frames must be a whole number >= 1.');
            end

            T   = twins(1).T_total;
            tol = Twin.tolFor(T);

            bp = sort([0, twins.leg_end_t]);
            bp = bp([true, diff(bp) > tol]);         %merge round-off duplicates
            bp(end) = T;

            dt    = T / n_frames;
            m     = max(1, round(diff(bp) / dt));    %steps in each piece
            tgrid = zeros(1, sum(m) + 1);
            pos   = 1;
            for kk = 1:numel(m)
                seg = linspace(bp(kk), bp(kk+1), m(kk) + 1);
                tgrid(pos + (1:m(kk))) = seg(2:end);
                pos = pos + m(kk);
            end
        end

        function xl = xLimits(twins)
            %xLimits -- position range that fits every twin's whole trip, with
            %room at the sides. the clock panel and the position/time diagram
            %both use it, so the same place lines up in both
            if isempty(twins) || ~isa(twins, 'Twin')
                error('lightclock:badTwin', 'xLimits: expected one or more Twin objects.');
            end
            lo =  Inf;
            hi = -Inf;
            for i = 1:numel(twins)
                ev = worldline(twins(i));
                lo = min(lo, min(ev(:, 2)));
                hi = max(hi, max(ev(:, 2)));
            end
            span = hi - lo;
            if span <= 0, span = 1; end         %nobody goes anywhere
            xl = [lo - 0.16 * span, hi + 0.16 * span];
        end

        function boosted = boost(twins, u)
            %boost -- the same twins, described from a lab frame moving at u.
            %every worldline corner goes through lorentzTransform in one
            %call per twin, then legs are rebuilt from the new corners.
            %proper times must come out the same: that's the validation test.
            %needs every twin to start at the origin, so they all still
            %start at t' = 0 in the new frame
            [c, ~] = Twin.globals();
            n = numel(twins);
            boosted = Twin.empty(1, 0);
            for i = 1:n
                tw = twins(i);
                ev = lorentzTransform(worldline(tw), u);
                if abs(ev(1, 1)) > Twin.tolFor(tw.T_total)
                    error('lightclock:badBoost', ...
                        'boost: "%s" does not start at the origin, so it would not start at t'' = 0.', tw.Name);
                end
                d_ct = diff(ev(:, 1)).';
                d_x  = diff(ev(:, 2)).';
                boosted(i) = Twin(tw.Name, d_x ./ d_ct, d_ct / c, ...
                                  'L0', tw.L0, 'X0', ev(1, 2), 'Color', tw.Color);
            end
        end
    end

    methods (Static, Access = private)
        function [c_out, L_out] = globals()
            %the one place this class reads the globals (c, L by design --
            %see the proposal). everything else gets them from here
            global c L
            if isempty(c) || isempty(L) || ~isscalar(c) || ~isscalar(L) || c <= 0 || L <= 0
                error('lightclock:globalsNotSet', ...
                    'Twin: globals c and L must be set to positive values first.');
            end
            c_out = c;
            L_out = L;
        end

        function tol = tolFor(T)
            tol = 1e-9 * max(1, T);
        end

        function requireAxes(ax, fname)
            if isempty(ax) || ~isscalar(ax) || ~isgraphics(ax, 'axes')
                error('lightclock:badAxes', '%s: needs one existing axes to draw in.', fname);
            end
        end

        function requireScalar(obj, fname)
            if ~isscalar(obj)
                error('lightclock:badTwin', '%s: call this on one twin at a time.', fname);
            end
        end
    end
end
