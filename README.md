[![Author](https://img.shields.io/badge/author-solarisone084-green)](https://github.com/solarisone084)
[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://github.com/solarisone084/light-clock-twin-simulator/blob/main/LICENSE)
[![Top language](https://img.shields.io/github/languages/top/solarisone084/light-clock-twin-simulator)](https://github.com/solarisone084/light-clock-twin-simulator/search?l=matlab)
[![MATLAB](https://img.shields.io/badge/MATLAB-no%20toolboxes%20needed-orange)](#requirements)
[![Last commit](https://img.shields.io/github/last-commit/solarisone084/light-clock-twin-simulator)](https://github.com/solarisone084/light-clock-twin-simulator/commits/main)

# Light-Clock Twin Simulator

An interactive simulation of special relativity built around light clocks and the twin paradox. Each twin carries a light clock and a ship. You plan a mission out of travel legs, then watch it unfold in four synchronized panels: the light clocks ticking, a spacetime diagram, the light signals the twins send each other (with Doppler shift), and a heads-up display of the running numbers. Time dilation, length contraction, the relativity of simultaneity and the Doppler effect all come from the same picture.

This project was originally completed as a final project for a scientific programming course. Development continues as a teaching tool.

## App Controls
<img width="75%" alt="App Controls" src="https://github.com/user-attachments/assets/2a396e67-9f32-4836-9bd5-f0c07a17c6d8" />



## Simulation Window (Default Settings)
<img width="75%" alt="Simulation Window" src="https://github.com/user-attachments/assets/578334ab-7691-42d5-bbf4-ff1cc195859d" />



## Status

This repository currently holds the **original MATLAB version**. A port to a free, open-source platform (TBD) is planned, so nothing proprietary will be needed to run it. The MATLAB version stays here as the reference implementation that the port is checked against. So, you're free to download or fork this version and use it if you want. I'm just not likely to update it.

## Requirements

- MATLAB (no add-on toolboxes needed)

## Getting started

From this folder in MATLAB:

```matlab
lightClockApp
```

This opens the mission-control window. Every mission in `missions/` is read at startup, and `standard.txt` is loaded by default. From the window you can:

1. **Mission**: pick a mission file, or load one from anywhere.
2. **Travel legs**: edit each leg's speed (v/c) and duration in the table, or select a row and drag the slider. The lines underneath show what that speed does to a clock and a ship, and what the whole mission adds up to.
3. **Settings**: mirror separation, ship length, time steps, animation length.
4. **Show**: choose which of the four panels to draw and which extra layers to add.
5. **Run / Pause / Stop**, then save the run, plot a summary, or compare it with a saved run.

## Mission files

Missions are plain text files, made to be written by hand:

```text
% the textbook twin paradox: out at 0.6c for 10 years, back at 0.6c for 10.
% Earth ages 20 years, the traveler 16.
% times in years, distances in light-years (c = 1).

name   = Standard out-and-back
L      = 0.5        % mirror separation: one tick per year of a clock's own time
L0     = 100        % ship rest length
frames = 500

% beta   duration
  0.6    10
 -0.6    10
```

- Anything after `%` is a comment.
- A line with `=` is a setting (`name`, `L`, `L0`, `frames`). All are optional, in any order.
- Any other line is one travel leg: velocity as a fraction of c, then duration in lab-frame time.
- A mistake in the file is reported with the file name and line number.

Included missions: `standard`, `fast_trip`, `one_way`, `park_and_return`, `uneven_legs` and `ludicrous_speed`.

## Demos and checks

| Script | What it does |
|---|---|
| `graphics_demo.m` | Loads a mission and animates it in preset views (light clocks alone, all panels, stopped at the turnaround, everything on). |
| `twin_class_demo.m` | Rebuilds the standard twin paradox from `Twin` objects and checks it (Earth 20 yr, traveler 16 yr, a 7.2 yr jump in the traveler's "now" at the turnaround). Also checks that proper times don't change when viewed from a moving lab frame, and runs three twins, none at rest. |
| `file_io_demo.m` | Checks that every mission file loads and gives the closed-form ages, that missions and run logs survive a save/load round trip, and that broken files are rejected with the right error and line number. |

## How the code is organized

| File | Role |
|---|---|
| `lightClockApp.m` | The main program: the mission-control window |
| `Twin.m` | One twin: mission profile, light clock, recorded history, and its own graphics |
| `animateMission.m` | Runs a mission and animates it in up to four panels |
| `drawClockPanel.m`, `drawSpacetimePanel.m`, `drawSignalPanel.m`, `drawHudPanel.m` | The four panels |
| `drawSummaryPlot.m`, `drawComparePlot.m` | Still plots of a finished run, and a comparison between two runs |
| `gammaFactor.m`, `lorentzTransform.m`, `dopplerFactor.m`, `contractedLength.m`, `simultaneityLine.m`, `computeSignals.m`, `getFlightPhase.m` | The physics |
| `dopplerColor.m` | Maps a Doppler factor to a red or blue color |
| `loadMissionProfile.m`, `saveMissionProfile.m`, `validateProfile.m` | Mission files |
| `loadRunLog.m`, `saveRunLog.m` | Run logs (`runs/`) |

Units: c = 1, with time in years and distance in light-years.

`light_clock_talk.pdf` is the slide deck from the project's original presentation.

## License

Copyright (C) 2026 solarisone084

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version. See [`LICENSE`](LICENSE) for the full text.
