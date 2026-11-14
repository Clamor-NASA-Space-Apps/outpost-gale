# Report: the opening trap is fixed (14 Nov 2026, 17:00)

For the coordinating session. Answers `design/handoff/opening-trap-14nov.md`.

## Result
- **Fixed, and Ravindu confirmed it in play.** He played the Linux build exported from this commit (16:49) and
  said "yes it's fixed": the hero wakes facing the hatch and walks out.
- **Commit `4b5d901`** on a detached HEAD in the worktree `tooling/projects/og-trap` (off `9492222`,
  wip/opening-sunrise). Not pushed. A second commit adds this report.

## Cause
`world.gd` `_item()` added each mover (the rover, PIP, the bags, the samples) to the tree and set its position
after. A body moved after it is in the physics space stays where it entered, the world origin, until the first
physics step. HAB 1 stands on the origin.

The real boot (`ui/boot.gd`) adds the sandbox inside a `_process`, and the deferred `start_opening` runs at the end
of that same frame. So `hero:airlock` put the hero inside HAB 1 before any physics step. On the first tick he
overlapped the rover's stale body and was pushed from (0, 0.35) to (1.14, 0.38). From there the straight walk to
(0, 6.5) runs through the wall beside the hatch: he turns to it (the window) and pushes into it for good.

Measured on the first tick after boot: `World/rover node=(10, -0.28, 8) server=(0, 0, 0)`, overlapping the hero.

## Why three fixes and every test missed it
- Every test starts the opening three frames after the build (`frames(3)`), and the repro script started it from
  `_initialize`, where a physics tick comes first. None of them ran the first tick with the hero in HAB 1.
- It was never a display, GPU or input problem. It reproduces headless with no input, as long as the game boots
  through `ui/boot.tscn`.
- Ruled out by measurement: the warm-up's camera, the room profile, the hatch's collision, and the kid's keys. Six
  runs through the real boot (no input, W, D, S, a D nudge mid-walk, look then W, all as physical key events) end on
  the same spot outdoors. `Input.action_release` in `_auto_walk` clears a held key's state each tick.
- Not explained: why `35c87b5` was healthy. Its `world.gd` and its deferred start are the same, so the stale rover
  was there too. I did not run the probe on that commit.

## What changed (`4b5d901`)
| File | Change |
|---|---|
| `world/world.gd` | `_item()` sets position and yaw before `add_child` (two lines moved, a comment) |
| `sandbox/sandbox.gd` | your cover change, unchanged: the beats wait while the cover is up |
| `data/beats.json` | your `max_s` removal on walk_out kept; `outside` is `["look"]` again, so beats_test passes |
| `tests/opening_live_test.gd` | rewritten: boots through `ui/boot.tscn`, holds a real W key |
| `AGENTS.md` | one gotcha: position before `add_child`; test a start through `boot.tscn` |
| `design/handoff/opening-trap-14nov.md` | section 0, Resolved |

## Checks
| Check | Result |
|---|---|
| beats_test, cine_test, sols_test, run, indoor_test, doors_test, world_test, pip_test (headless, on the fix) | 0 failed each |
| opening_live_test, headless, on the fix | 0 failed |
| opening_live_test, headless, on `f6f005f` | 5 failed (beat already `hatch` at cover lift, hero 1.14 m off the spot, 32 deg off the hatch, never outdoors, cannot walk) |
| Ravindu plays the exported Linux build | fixed |
| opening_live_test on xvfb, on the fix and on `f6f005f` | started 16:58, still running when this was written; results in the scratchpad file `xvfb.txt` (below) |
| settings_test | not run (the known old failure) |

The handoff's "done" item 1 asks for the xvfb run. Until it reports, that item is open; items 2 and 3 are met.

## To merge
1. In the main checkout, discard the uncommitted copies of `data/beats.json`, `sandbox/sandbox.gd` and
   `tests/opening_live_test.gd` (and its `.uid`): `4b5d901` holds them, with `outside` look-only and the test
   rewritten. Otherwise the merge conflicts.
2. `git merge 4b5d901` (or cherry-pick) onto wip/opening-sunrise, then build and push as usual.
3. Remove my worktrees when done: `og-trap` (the fix, holds `build/linux/`) and `og-trap-base` (`f6f005f` plus the
   test, for the failing run). Wait for the xvfb run to end first: it runs in both.

## Loose ends
- **Abort at exit.** A test script that boots through `boot.tscn` prints its "N failed" line and then the engine
  aborts (exit code 134, a crash in a mutex lock during teardown). Cause not traced. Read the "N failed" line, not
  the exit code. The exported game itself exited cleanly.
- **A held W is dropped when the automatic walk ends.** `_stop_walk` releases the move actions, which also clears a
  key the kid is still holding, so they must press again. Not a trap. The test presses again at `walk_to_me`.
- **Suggested line for `skills/guided-tutorial` row 9** (the factory repo, not edited by me): "boot through the
  game's main scene; instancing the root and waiting a few frames hides the first physics tick".
- Still open from the handoff, untouched: the HUD clock 06:30 against the look clock 05:47, and the wake hour.

## Where things are
- Scratchpad: `/tmp/claude-1000/-home-ravindu644-Documents-NASA-Space-apps-tooling-projects-junior-astronaut-mission-trainer/844c3536-52ac-415e-97c9-5f20dc5059d3/scratchpad/`
  - `boot_log.gd`: boots through `boot.tscn` and logs the hero, the camera and the beat each tick (`-- mode=none|w|d|s|d_tap|look_w secs=35`).
  - `boot_probe.gd`: lists what the physics space holds at the hero on the first ticks, and every stale body.
  - `h_none.log`, `h_probe.log`: the trap before the fix. `fix1_*.log`, `h_probe2.log`: after.
  - `suite.txt`, `t_*.log`: the test list. `xvfb.txt`, `x_live_*.log`: the xvfb run.
- The played build: `tooling/projects/og-trap/build/linux/outpost-gale.x86_64`.
