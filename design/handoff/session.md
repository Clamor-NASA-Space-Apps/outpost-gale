# Session handoff: paused for a laptop restart (12 Nov 2026, about 02:10)

Why: the CPU was stuck at 400 MHz on every core while cool (62 to 66 C) and with every software limit
normal (max 4.5 GHz, turbo on, RAPL 15/28 W, no new thermal throttle events). Likely BD PROCHOT asserted
by the MSI embedded controller (charger path or firmware). A full restart was Ravindu's fix.

## Where things stand
- Plan: `~/.claude/plans/iterative-singing-toast.md` (approved). Checklist: `roadmap.md` (ticked to date).
- Committed (git log): refs confirmed; DESIGN.md = variant A with realistic photo sets; real Gale ground
  (HiRISE patch + 1 m normal map + MOLA skyline); soft dust ground (moon_02, ripples, gravel patches,
  footprints and wheel tracks via `terrain.mark()`); section 1 (CONTRACTS.md, world.json, tuning.json,
  stand-in sandbox, tests/run.gd, probe wired); lane C models; lane D HUD kit.
- In the working tree, NOT committed (lanes paused mid-work, each wrote `design/handoff/lane-<X>.md`):
  - lane A `player/` (controller, camera, touch, hero model): player/*, models/character_astronaut.glb
  - lane B structures: forge/building_*.py, forge/base_kit.py, forge/pad_build.py, forge/prop_battery_bank.py,
    prop_oxygen_maker.py, prop_water_recycler.py, prop_lettuce.py and their models/*
  - lane E world: world/world.gd, world/rocks.gd, world/dust.gd, data/world.json, DESIGN.sunset/night/storm.md
    and design.*.json, tests/world_test.gd

## Resume steps (after `claude --resume` in tooling/)
1. Check the clock is back: `awk '{s+=$1} END {print s/NR/1000 " MHz"}' /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq`.
2. Read the three lane handoffs; resume each lane agent with its note (or a fresh agent briefed from it).
3. Run lanes one or two at a time, not five: five Godot/Blender jobs at once put the load near 30.
4. Then: merge A, B, E after re-running their checks (tests/run.gd, player_test, world_test, feel-probe,
   style-check, check_godot_project.py, capture-view), sandbox playtest by Ravindu, S3 interactions.

## First fixes after the restart (raised by the lanes at the pause)
- reality.json measured rows start at `at: [0,0,0]`, inside the habitat: move them to open ground (lane A
  measured all four passing at [0,0,16]: walk 1.0, hurry 1.6, stop 1.51, hop 0.171). The probe measures
  the hop from `at[1]`, so `at` must sit where the ground is near 0.
- CONTRACTS.md: pin `drive(input)` axes (lane A sends x = steer right +, y = throttle forward +, `seat()` global);
  add `player.restyle(design)`; add a sheet row for the steepest walkable slope; move the hop's FEEL numbers
  from `player/hero_model.gd` into tuning.json.
- world_test fails only on lane B's habitat: a tank and cradle with no collision, and the roof collision
  looks inward-facing at a vent and a ring. Lane E's checks ran in a scratch copy: rerun in the real project.
- Draw calls were 221 at the base view before lane E's merge and probe fix (budget 150): cut them.
- Lettuce has no green role (it uses teal `accent`): ask Ravindu about a `plant` role. Greenhouse panes are
  opaque (glass has no transparency). Dust devil speed 3 m/s has no source.

## Open items noted on the way
- Wheel tracks may read as raised berms rather than dents: judge in play, flip the trail normal sign if so.
- `forge/lineup.py` should skip the `terrain_` class (the backdrop shrinks the lineup to nothing).
- Lane C's `forge/shapes.py` helpers (prism, label, settle, tyre, bar) could move into tooling `lib.py`.
- Curiosity keeps NASA textures (decided exception); 7 x 1K WebP, resize to 512 if the iPhone is short.
- Factory lesson for later: one of the three style variants must carry photo texture sets.
- tooling/AGENTS.md is 174 lines (cap ~150): prune at the lessons step.
