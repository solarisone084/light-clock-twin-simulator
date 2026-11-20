function [Profile, comes_home] = validateProfile(Profile)
%validateProfile -- check a mission profile and return it in standard form
%
%   Profile = validateProfile(Profile)
%   [Profile, comes_home] = validateProfile(Profile)
%
%a mission profile is a struct. two fields are required:
%   .beta   = vector of leg velocities (v/c), each with |beta| < 1
%   .dur    = vector of leg durations in lab-frame time, each > 0
%the rest are optional. a missing one comes back as [] ("not given, use the
%program's default"), so callers can always test isempty(Profile.L):
%   .name   = label for printouts and plots (default 'mission')
%   .L      = mirror separation of the light clocks
%   .L0     = ship rest length
%   .frames = number of time steps across the mission, 1 to 1000000
%
%what comes back: .beta and .dur as double ROW vectors, .nlegs filled in,
%and every optional field present. it is the same shape whether the profile
%was typed at the console or read by loadMissionProfile.
%
%   comes_home = true if the legs add up to zero displacement, i.e. the
%                trip ends where it started. a one-way trip is still a legal
%                profile -- there just won't be a reunion to compare ages at.
%
%error identifiers: lightclock:badProfile (+ gammaFactor's for a bad beta,
%                   contractedLength's for a bad L0)

    if ~isstruct(Profile) || ~isscalar(Profile) || ~isfield(Profile, 'beta') || ~isfield(Profile, 'dur')
        error('lightclock:badProfile', ...
            'validateProfile: Profile must be a single struct with fields .beta and .dur.');
    end

    beta = Profile.beta;
    dur  = Profile.dur;

    %---- the legs
    if ~isnumeric(beta) || ~isreal(beta) || isempty(beta) || ~isvector(beta)
        error('lightclock:badProfile', ...
            'validateProfile: .beta must be a real, non-empty vector (one velocity per leg).');
    end
    if ~isnumeric(dur) || ~isreal(dur) || ~isvector(dur) || numel(dur) ~= numel(beta)
        error('lightclock:badProfile', ...
            'validateProfile: .dur must be a real vector with one duration per leg (%d).', numel(beta));
    end
    if any(~isfinite(dur)) || any(dur <= 0)
        error('lightclock:badProfile', ...
            'validateProfile: every leg duration must be a positive, finite number.');
    end
    gammaFactor(beta);          %rejects NaN and |beta| >= 1 with its own message

    Profile.beta  = double(beta(:).');
    Profile.dur   = double(dur(:).');
    Profile.nlegs = numel(beta);

    %---- optional fields. make sure each one exists, then check the ones given
    optional = {'name', 'L', 'L0', 'frames'};
    for kk = 1:numel(optional)
        if ~isfield(Profile, optional{kk})
            Profile.(optional{kk}) = [];
        end
    end

    if isempty(Profile.name)
        Profile.name = 'mission';
    end
    if isstring(Profile.name) && isscalar(Profile.name)
        Profile.name = char(Profile.name);
    end
    if ~ischar(Profile.name) || ~isrow(Profile.name) || isempty(strtrim(Profile.name))
        error('lightclock:badProfile', 'validateProfile: .name must be non-empty text.');
    end
    Profile.name = strtrim(Profile.name);

    if ~isempty(Profile.L)
        val = Profile.L;
        if ~isnumeric(val) || ~isreal(val) || ~isscalar(val) || ~isfinite(val) || val <= 0
            error('lightclock:badProfile', ...
                'validateProfile: mirror separation L must be a single positive, finite number.');
        end
        Profile.L = double(val);
    end

    if ~isempty(Profile.L0)
        contractedLength(Profile.L0, 0);       %it owns the L0 check
        Profile.L0 = double(Profile.L0);
    end

    if ~isempty(Profile.frames)
        val = Profile.frames;
        if ~isnumeric(val) || ~isreal(val) || ~isscalar(val) || ~isfinite(val) ...
                || val ~= round(val) || val < 1 || val > 1e6
            error('lightclock:badProfile', ...
                'validateProfile: frames must be a whole number from 1 to 1000000.');
        end
        Profile.frames = double(val);
    end

    %---- does the trip end where it started? (c cancels out of this test)
    reach      = Profile.beta .* Profile.dur;
    comes_home = abs(sum(reach)) < 1e-9 * max(1, sum(abs(reach)));

end
