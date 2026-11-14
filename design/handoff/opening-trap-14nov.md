# The opening traps the hero inside HAB 1 (14 Nov 2026)

A handoff for the agent that finds and fixes this. Written by the coordinating session after three failed fixes.
Read this file, then `AGENTS.md` (this repo), `../../AGENTS.md` (the factory) and `../../skills/guided-tutorial/SKILL.md`.

## 0. Resolved (14 Nov, evening)

**Cause.** `world.gd` `_item()` added each mover (the rover, PIP, the bags, the samples) to the tree and positioned
it after. A body moved after it is in the physics space stays where it entered, the world origin, until the first
physics step. HAB 1 stands on the origin. The real boot (`ui/boot.gd`) adds the sandbox inside a `_process`, and the
deferred `start_opening` runs at the end of that same frame, so `hero:airlock` put the hero inside HAB 1 before any
physics step. On the first tick he overlapped the rover's stale body and was pushed from (0, 0.35) to (1.14, 0.38).
From there the straight walk to (0, 6.5) runs through the wall beside the hatch: he turns to it (the window) and
pushes into it for good. Every test starts the opening three frames after the build, and the repro script started it
from `_initialize`, where a physics tick comes first, so none of them saw the first tick.

**Not the cause.** The warm-up's camera, the room profile, the hatch's collision and the kid's keys: a physical key
held through the walk does not move it off its line (`Input.action_release` in `_auto_walk` clears a held key's state
each tick; six input scenarios through the real boot end on the same spot outdoors).

**Fix.** `_item()` positions the item before `add_child`. The coordinator's cover change stays (the beats wait
behind the cover, walk_out has no `max_s`); `outside` allows `["look"]` again, as beats_test expects, because the
hero is always out when it starts now.

**Test.** `tests/opening_live_test.gd` boots through `ui/boot.tscn`, headless or on xvfb. At the first playable frame:
the beat is still `wake`, the hero is on the airlock spot facing the hatch; then, with a real W key held, he is
outdoors when `outside` starts, and walks on the kid's key at `walk_to_me`.

## 1. TL;DR

When a person starts the game, the Sol 1 opening is supposed to walk the hero out of HAB 1 through its hatch. In the
real build he never gets out:

- he starts **facing a window, not the hatch** (Ravindu, 14 Nov, after the latest build);
- pressing forward does not take him through the hatch;
- the beats move on regardless: the hatch closes, PIP says hello from outside, and the 360 look-around is meant to
  play outdoors while the hero is still stuck inside.

**Every headless test passes**, including a bot that walks out with real input. The bug shows only in the real game
(exported build, real window, real GPU, a person on mouse and keyboard). Three fixes went in today and none of them
fixed it.

**Last healthy commit: `35c87b5`** (wip/opening-sunrise). Its game code equals `250f011` plus a docs file. A prebuilt
binary of the same opening (`f5ef2c5`, which adds only a perf tool and tests) is at
`~/outpost-gale-builds/old/f5ef2c5/`. That build had the "drone shot" opening: the hero walked out on his own and a
cine camera filmed the dawn and a 360. Ravindu never got stuck in it.

**First broken commit: `edf4201`**, "third person indoors". Ravindu reported the trap on that build (it also locked
looking and turning). The commits after it (`7f92211`, `f6f005f`) changed the opening again but did not fix it.

## 2. What the player sees

### 2a. Recording of `f6f005f` (15:53, 57 s)
`/home/ravindu644/Videos/Screencasts/Screencast From 2026-11-14 15-53-05.mp4` (1920x1080, 60 fps). Frames at 1 fps:
`/tmp/claude-1000/-home-ravindu644-Documents-NASA-Space-apps-tooling/d10120dd-6233-49a1-8d98-3cc7bd666f89/scratchpad/rec1/f_001.png` to `f_057.png`;
contact sheets `s1.png`, `s2.png` and `s3.png` in the same folder.

| Time | What happens |
|---|---|
| 0 to 15 s | Loading cover ("Loading the base", then "Building the base 0% to 96%") |
| 15 to 16 s | The cover fades. The view is inside HAB 1, close to the round window beside the hatch |
| 16 to 35 s | The camera swings around the room (ceiling, the water panel, the bench, a frame that is all white wall). The hero is mostly out of frame or faded to see-through at the lens. Ravindu is moving the mouse and pressing keys |
| 36 to 40 s | The hero is at the inner door, facing the open hatch |
| 41 to 56 s | The hero stands **in the hatch opening and never steps out**. The task list still says "Step outside". PIP's lines "Hello! Outside the air is very thin" and then "Good morning, Commander. I'm PIP" play: the beats think the walk-out is over |

The HUD clock reads 06:30 while the debug line reads `dawn 05:47`: the rules clock and the look clock are apart. That
is a known side issue, not this bug.

### 2b. Ravindu's description of the latest build (local, uncommitted fix on `f6f005f`, below)
"It didn't fix. I noticed that the hero is facing the window when the game begins, not the door. That's what keeps
preventing him from going through the door."

### 2c. The `edf4201` report (12:59 build)
"The player can't even go outside in the new build in the tutorial because his head is not in the door's direction.
Can't even turn around as we lock turning around. Because the user is stuck inside HAB1, the 360 rotation and
everything happens inside the hab itself, making a complete mess."

## 3. How the opening works

### 3a. Files
| File | Role |
|---|---|
| `data/beats.json` | `opening`: Sol 1's ordered beats. `starts.airlock`: where the hero wakes |
| `cine/beats.gd` | The beat runner. `_do()` runs commands, including `hero:` (place the hero, then `player.cam.snap(player.yaw)`) and `walk:` (the automatic walk). `_auto_walk()` presses the move actions each physics tick, steering in the camera's ground basis. `outdoors()` and `_leading_out` hold an outdoors-only beat until the hero is out |
| `cine/cine.gd`, `data/cine.json` | The shots: `step_out` (animation #1) and `look_around` (animation #2) |
| `sandbox/sandbox.gd` | The composition root. It places the hero at `world.json`'s start (line ~99), runs `_warm()` behind the loading cover (line ~159), and calls `beats.start_opening.call_deferred()` only when there is a current scene, that is when started through `ui/boot.tscn` (line ~559) |
| `player/player.gd` | `place(pos, yaw_deg)`, `allowed` and `may()`, the controller |
| `player/follow_cam.gd` | The third-person camera, with the **room profile** added in `edf4201`: a closer lens inside rooms, the lens kept in the room's plan, feelers. `snap()` turns it behind the hero |
| `sandbox/interactions.gd` | Doors: `open:hab1` and `close:hab1` |
| `ui/boot.gd` | Boot: the sandbox built in slices, its 3D drawn off for its first frame |

### 3b. The first beats now (`f6f005f`)
| Beat | do | allow | wait |
|---|---|---|---|
| wake | `clock:5.8`, `hero:airlock`, `ghost:off` | look | 2.5 s |
| hatch | `open:hab1` | (kept) | 1.5 s |
| walk_out | `walk:0,6.5`, `shot:step_out` | the walk sets `["move","look"]` | place (0, 6.5) r 0.6, max 20 s |
| turn_out | `walk:2.5,5.5`; PIP goes to (7.5, 6) | | `shot_done:step_out`, max 15 s |
| outside | `close:hab1` | look | 2.5 s |
| pip_hello | | | `pip_arrived`, max 12 s |
| look_shot | `shot:look_around` (outdoors only) | none while it plays | `shot_done:look_around` |

`starts.airlock` is `{item: hab1, at: [0, 0.3, -0.35], yaw: 0}`, in HAB 1's own space: the model's door is on its -Z
front.

### 3c. The same beats at the healthy `35c87b5`
| Beat | do | allow | wait |
|---|---|---|---|
| wake | `clock:5.8`, `hero:airlock`, `ghost:off` | **none** | 2.5 s |
| hatch | `open:hab1` | | 1.5 s |
| walk_out | `walk:0,6.0` | (none: the kid cannot fight the walk) | place, max 20 s |
| face_dawn | `walk:3.5,5.5` | | place, max 12 s |
| outside | `close:hab1`, `shot:dawn_reveal` | none | `shot_done:dawn_reveal` |

Differences that matter:
- **Input.** At the healthy commit the kid had no input until the hero was outside, so the automatic walk was the
  only thing pressing the move actions. Now the kid can look, and move, during the walk.
- **The camera.** Indoors used to be first person. Since `edf4201` it is the third-person room profile.
- **`hero:` now snaps the camera** behind the hero (`7f92211` / `f6f005f`).
- **The walk-out is a shot** (`step_out`) that follows the hero, instead of a plain walk followed by a cine shot outside.

Full diff of the opening: `git diff 35c87b5 f6f005f -- cine/ data/beats.json data/cine.json sandbox/ player/ ui/boot.gd`
(11 files, about 570 lines added). `player/follow_cam.gd` alone changed by about 220 lines.

## 4. What was tried

1. **`7f92211`, lane K, animation #1.** The automatic walk-out, followed by the `step_out` glide. Its beats_test passed
   end to end.
2. **`f6f005f`, lane K.** Looking is never locked. `hero:` also calls `player.cam.snap(player.yaw)` "so the view and
   the helmet face the way out". look_shot is outdoors only, with PIP leading out first. beats_test gained:
   - look input turns the view in every beat;
   - the hatch is in the camera frame at the first playable frame;
   - a bot turns 180° during the wake and still gets out.

   All passed. The recording in 2a is this build.
3. **Uncommitted, coordinator (in the main checkout's working tree right now).**
   - `sandbox/sandbox.gd` `_process`: `beats.process_mode = DISABLED while cover.visible`. The beats did run under the
     ~16 s loading cover: the new `tests/opening_live_test.gd` fails on `f6f005f` with "the opening waits behind the
     cover (walk_out)".
   - `data/beats.json`: walk_out lost its `max_s: 20`, and `outside` allows `["move","look"]`. **This breaks two
     beats_test checks** ("the touch stick stays hidden: the kid is not steering", "after the walk only looking is the
     kid's"), so revert or rework it.
   - `tests/opening_live_test.gd` (new): boots the sandbox, holds the cover up 5 s, then checks the hero is outdoors
     when `outside` starts and can walk after. It passes with the change.

   Ravindu played this build (`build/linux/outpost-gale.x86_64`, exported 16:05) and was **still trapped, facing the
   window**. So the cover was a real bug but not the trap.

## 5. Why the tests miss it

- `tests/beats_test.gd` **wires its own beats** ("what sandbox.gd adds ... the cinematics answer a shot at once
  here"). It never runs `sandbox.gd`'s real wiring, its real shots, or the cover.
- A headless run (`--headless`) has no window, so the warm-up's cameras and the cover's timing differ from play.
- The repro `scratchpad/repro/opening.gd` boots the real sandbox headless and logs each second. The hero walks
  (0, 0.27, 0.35) to (0, 0, 3.7) in 3 s and is outside at (2.6, 0.04, 5.2) by 15 s, with no input. **Headless never
  reproduces the trap.**
- No test reads the hero's facing or the camera's yaw against the hatch at the moment the cover lifts, in a real
  window.

## 6. Leads, most likely first (none verified)

1. **Something turns the hero or the camera after `hero:airlock`, and only in a rendered run.**
   - `sandbox._warm()` runs `Forge.HouseStyle.warm()`, which holds a camera inside the reflection probe and hands back
     "the camera this view chose" (`set_view`), and it runs after `place()` at line ~99.
   - `player.cam.snap()` runs while the cover is up. When the cover lifts, the follow camera's room profile clamps the
     lens to the room's plan and its feelers push it. It may settle facing the window beside the hatch: frame 16 of
     the recording looks at that window.
   - Check: log `player.yaw`, `player.body.rotation.y`, the camera's yaw and `beats.beat.id` every frame from boot to
     the end of walk_out, **in the real window** (not headless), and compare with the hatch bearing.
2. **The automatic walk steers in the camera's basis while the kid can turn the camera.** `_auto_walk()` computes the
   stick with `player.cam.ground_basis().inverse()`, then `Input.action_press()` on the same actions the keyboard
   uses.
   - A real key press or release (W, A, S, D) changes those actions between ticks.
   - The kid turning the mouse turns the basis.
   - In third person the hero turns toward the stick, so a camera facing the window gives a stick that walks into the
     wall beside the hatch.
   - The healthy commit blocked all input during the walk.
3. **Placement vs `hero_model` / `player.gd` facing changes in `edf4201`** (the step-down settle, the fall clip, the
   room profile). Confirm that `starts.airlock` still lands the hero facing -Z of HAB 1 with the current model.
4. **The hatch opening's collision since `edf4201`** ("backface collision" in `world/world.gd`). Even facing the
   right way, the hero might not fit or might catch on the sill. Frames 41 to 56 show him standing in the opening.

## 7. How to reproduce

- **The real binary** (what Ravindu plays): from the project,
  `godot --headless --path . --export-release Linux`, then `build/linux/outpost-gale.x86_64`.
- **The healthy one:** `~/outpost-gale-builds/old/f5ef2c5/` (or `git worktree add --detach ../og-x 35c87b5` and export).
- **A rendered run you can script:** `xvfb-run -a taskset -c 1,2,3,5,6,7 nice -n 10 timeout 900 godot --display-driver x11 --path . --fixed-fps 60 -s <script>`.
  Under xvfb the sandbox draws a few frames a second (software GL), but the warm-up, the cover and the cameras run as
  in play. Boot through `ui/boot.tscn` (or set the sandbox as `current_scene` before its `_ready`), so the opening
  starts the way it does for a player.
- **Repro logger:** `/tmp/claude-1000/-home-ravindu644-Documents-NASA-Space-apps-tooling/d10120dd-6233-49a1-8d98-3cc7bd666f89/scratchpad/repro/opening.gd`.
  Add the camera yaw and the hero yaw to its print line, and run it on xvfb rather than headless.

**Done means:**
1. A test that boots the way a player does, on a real display (xvfb), fails on `f6f005f` and passes on the fix.
2. beats_test, cine_test, sols_test, run, `tests/opening_live_test.gd`, indoor_test and doors_test are 0 failed (the
   one known old failure is settings_test "and says Saved").
3. Ravindu plays the exported Linux build and walks out of HAB 1.

## 8. The cinematography (what the opening must look like)

Two of Ravindu's reference videos set this (14 Nov morning). In order:

1. **Wake (05:48, blue pre-dawn).** Inside HAB 1, third person, the hero standing at the hatch **facing it**, the hatch
   ahead and centred in frame. The kid can look around but the hero stands still.
2. **The hatch opens** (1.5 s), with the airlock hiss.
3. **Animation #1, `step_out`: the walk-out.**
   - The hero walks out through the hatch on his own, at walk speed, as one continuous move.
   - The camera starts in the indoor third-person view and eases in close behind the hero. It follows on the hero's
     own line through the hatch, always pulled in front of anything between it and the hero's head: never inside a
     wall, never more than 0.25 m in a frame.
   - Outside, the hero turns a little right (`turn_out`, to about (2.5, 5.5)).
   - The shot ends on the play camera's live pose at a 66° heading (`land_bearing`). End frame (his image 89): HAB 1's
     open hatch on the left, the rover and the cargo bags ahead-right, PIP rolling in beside the rover (7.5, 6).
   - The start frame of his reference (image 90) was first person, which no longer exists indoors. The indoor
     third-person view replaces it.
4. **Outside.** The hatch closes behind him. PIP rolls up and waves: "Hello! Outside the air is very thin", then "Good
   morning, Commander. I'm PIP". The kid walks to PIP, then side steps and a back step.
5. **Animation #2, `look_around`: the 360 of Gale crater.**
   - Outdoors only (out of every room, at least 3 m from every door).
   - It uses **the play camera itself**, turned through `look()` as a mouse would. There is no cine camera, so the
     follow camera's own collision and framing apply.
   - It holds 2.5 s while the view tilts up 26°, so the camera sits low and the sky fills most of the frame.
   - Then it turns one full circle to the left in 20 s, at a steady 18° a second with eased ends, and tilts back. It
     ends exactly where it started.
   - What passes in order: HAB 1 slides in from the left; the hero, turned to face the camera with the storm shelter
     behind him (about 12 to 14 s in); the rover; then the start view.
   - The kid's input is locked only while it plays, and given back the frame it ends.
6. Then the play tutorial: try a jump (with the Earth ghost), hurry, lift a cargo bag, the map, follow PIP to the
   solar wings, the oxygen maker and the greenhouse, and the first choice.

**The healthy build's version, for comparison (`35c87b5`):** first person indoors, and no input at all until outside.
After the walk-out a cine camera played `dawn_reveal`: a wide drone-like shot that ran the clock so the sun broke
over the crater rim. Its `look_around` was also a cine camera orbit, the "drone shot" Ravindu remembers. Ravindu
preferred that build's feel; animation #1 and #2 replaced it on his request (his videos). The sunrise is gone from the
current opening, so it now stays pre-dawn until `clock:run`. The wake hour is an open question for Ravindu.

## 9. Rules for whoever fixes it

- Machine: someone plays on this laptop.
  - Engine runs use `taskset -c 1,2,3,5,6,7 nice -n 10`, headless or xvfb with `--display-driver x11`, never the real
    screen or GPU.
  - One heavy job at a time.
  - Never wrap xvfb-run in `timeout` (put the timeout inside).
  - End your jobs by PID. No `pgrep -f` loops.
- Work in a worktree off the wip tip (`git worktree add --detach ../og-<name> wip/opening-sunrise`), not the main
  checkout. Commit with `git commit -s --no-gpg-sign` and the workspace's Co-Authored-By trailer. Don't push; the
  coordinator merges, builds and pushes.
- Follow `skills/guided-tutorial`:
  - row 1: never lock look or turn outside a playing shot;
  - row 2: the start pose faces the way out, with the goal in frame;
  - row 3: a beat waits for its place;
  - row 8: a bot plays with real input;
  - row 9: the beats wait behind the cover, and one test boots as a player does.
- No em dashes. Typed GDScript.
