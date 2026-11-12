# Single-axis trackers: excerpts (saved 12 Nov 2026)

Used by `world/machines.gd` (`_track`) and `data/world.json` `machines.tracker.rows` for the solar wings.

## Sandia PVPMC, "Single Axis Tracking"
https://pvpmc.sandia.gov/modeling-steps/1-weather-design-inputs/array-orientation/single-axis-tracki (read with WebFetch)
- "usually orientated North-South with the modules facing toward the East in the morning"
- "It is common for the maximum allowed angle to be 45 degrees from horizontal."
- "Some tracking systems use "backtracking" to avoid row-to-row shading."
- "GCR is generally defined as the ratio of the PV array surface area to the total facility ground area"

## pvlib-python 0.11.0, `pvlib/tracking.py` (saved beside this file: `pvlib_tracking.py`)
- `singleaxis(..., max_angle=90, backtrack=True, gcr=2.0/7.0, ...)`
- gcr: "A tracker system with modules 2 meters wide, centered on the tracking axis, with 6 meters between the tracking
  axes has a gcr of 2/6=0.333."
- The backtracking correction, flat ground (cross_axis_tilt 0), lines 149 to 167:
  `temp = abs(cos(wid) / gcr)`; where `temp < 1`, `tracker_theta = wid - sign(wid) * arccos(temp)`, citing
  Anderson and Mikofski, "Slope-Aware Backtracking for Single-Axis Trackers", NREL/TP-5K00-76626, July 2020, eq. 14
  (https://www.nrel.gov/docs/fy20osti/76626.pdf; the host did not resolve from this machine, so the formula is taken
  from pvlib's implementation of it). "in the middle of the day, arccos(temp) is out of range because there's no
  row-to-row shade to avoid, & backtracking is unnecessary".

## What the game takes
- Wings run north and south and turn about their long axis (the torque tube), limit 45 degrees (Sandia, "common").
- Rows 7.5 m apart for a 2.5 m wing: gcr 1/3, pvlib's own example ratio. With backtracking no row shades the next
  at any sun angle; the pitch only sets how much the rows backtrack.
- Our rig's suns (DESIGN*.md): day elevation 12, azimuth 345 from +Z: true tracking 50.6 degrees, no backtracking
  (cos 50.6 / (1/3) = 1.9), clamped to 45. Sunset elevation 4, azimuth 270: true 86.0 degrees, backtracked to 8.1.
  Night and storm: stowed flat (world.json weather `stow`).
