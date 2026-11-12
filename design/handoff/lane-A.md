# Lane A (player): handoff

**12 Nov 2026, suited hero pass (newest first; older notes below are history).**
- `player/hero_model.gd`: `models/character_suited.glb` with `data/clips.json` (loops set in code). Gait blend walk/lope,
  `SYNC_MODE_CYCLIC_MUTABLE`, speeds measured from the feet (median stance speed: walk 0.999, lope 1.599 m/s). Footsteps
  fire on the clips' touchdown phases (the drawn ankle sits at its planted height on every event). Hop: the last
  `hop.anticipation` s of hop_start, hop_air, hop_land. carry_idle/carry_walk with the bag on spine_03, drive_sit with
  the drawn hips on `vehicle.seat()`, interact on the interact key. The Fold modifier is gone.
- `player/hero.gdshader`: the hero's own role copies: pixel dither fade + dust on the boots (tuning `hero`). The model
  sits `hero.sink` lower than the collider.
- `player/player.gd`: collider radius = `hero.width` / 2 (the drawn box made it 1.35 m round, wider than the 1.2 m
  hatches); `inside()` checks that torso cylinder. Gait bands from `hero.froude.walk_run`; gait `lope`.
- `player/follow_cam.gd`: critically damped spring with a limit, slower floor-following height, lead on the lens,
  yaw leash from the real velocity (third-person-camera rule 14 additions).
- Old `models/character_astronaut.glb` deleted; `forge/hero_astronaut.py` still writes that name (lane B/H to rename).

## History: paused 12 Nov 2026 for a reboot

**Update after the reboot: lane A is complete.**
- Contract items done: probe rows at [0,0,16], drive axes, `player.restyle(design)`, footstep kept, `floor_max_angle` from `hero.slope.max`, the hop feel moved to the tuning.json `hop` block.
- Checks:
  - `run.gd`: 0 failed.
  - `player_test.gd` (with footsteps and restyle): 0 failed.
  - feel-probe on the real sheet: 4 of 4 pass.
  - Films on `player/dev.tscn` (side view `hero`): looked at.
  - capture-view default and hero: exit 0, no errors.
- The notes below are the state before the reboot.

Scratch files live in the session scratchpad (`/tmp/claude-1000/-home-ravindu644-Documents-NASA-Space-apps-tooling/d10120dd-6233-49a1-8d98-3cc7bd666f89/scratchpad/`). A reboot may wipe them, but each one can be made again with the commands below. Nothing is committed.

## 1. Finished and verified
- `models/character_astronaut.glb` (+ `.import`): a copy of the Quaternius Astronaut, imported. It faces +Z (glTF). The clips are named `CharacterArmature|Idle/Walk/Run/...`.
- `player/hero_model.gd`:
  - `Forge.HouseStyle.apply`, then the model turned 180 degrees to face -Z and centred on the drawn body.
  - Drawn bounds come from CPU skinning of the idle pose: 0.59 x 1.85 x 0.63 m.
  - Clip ground speeds are measured at load from the foot bones at mid-stance: Walk 1.12 m/s, Run 2.87 m/s.
  - AnimationTree state machine idle/move/hop. `move` is a BlendSpace1D (walk, run) followed by a TimeScale `pace` beyond the clip speeds. Loops are set in code.
  - The hop is posed by the `Fold` SkeletonModifier3D (crouch, tuck, landing squash). It needs no jump clip.
  - `feet()` gives the drawn foot positions.
  - The feel constants live in `FEEL`. They belong in tuning.json and should move there at the merge.
- `player/follow_cam.gd`:
  - SpringArm3D sphere cast that leaves out the hero and thin layer 3. The Lens sits beside the arm: it cuts in at once, holds, then eases out.
  - It lifts over a wall (from a separate cast at the base pitch), takes distance from pitch, and follows through a damper with a limit. Its height follows the floor, so hops don't move it.
  - It recentres after `recentre_after` seconds.
  - Mouse capture on click (emulated clicks ignored), plus stick and key look.
  - It hides the hero below `fade_near`. `inside()` (a ray plus a sphere overlap) and `on_screen()`.
- `player/touch.gd`:
  - VirtualJoystick (dynamic) for the move actions.
  - Hurry, Hop and Use Buttons that send InputEventAction.
  - A look pad that turns by each finger's own last position (never `relative`).
  - StyleBoxFlat from design.json colours. It shows on a touchscreen or on the first touch.
- `player/player.gd`:
  - CharacterBody3D with a **cylinder** (radius = half-diagonal of the drawn box, 0.43 m) lifted by `hero.step`, plus a SeparationRayShape3D to the feet. A capsule climbed a 0.39 m step, which is why it is a cylinder.
  - Speed curve from the sheet:
    - brake = hurry^2 / (2 x stop);
    - turn rate = min(sqrt(g/leg), brake/v), and a reversal brakes first;
    - hop v = sqrt(2 g apex), with gravity applied on the take-off frame so the apex stays under the row.
  - Coyote and jump buffer come from tuning.json. Gait bands use Froude 0.4 and 0.6 for hysteresis.
  - `place`, `enter(vehicle)` and `exit()`. The hero hides and drops its collision while driving, and the camera follows the vehicle at `vehicle_distance`.
  - `state()` has the CONTRACTS keys.
  - It calls `Controls.register()` itself, because the joystick needs the actions in `_ready`.
  - **Footstep signal DONE** (coordinator request): `signal footstep(pos, yaw_deg, foot)`. A foot "foot_l"/"foot_r" plants when it becomes the lower drawn foot while moving on the floor, and both feet fire on landing. `pos` is the foot at floor height and `yaw` the heading. The player never calls the world.
- `player/dev.gd` + `player/dev.tscn`: a light fixture (flat ground, the light rig at quality low, the hero, Forge hooks) for films and probe rows (`scene`).
- `tests/player_test.gd` covers:
  - the gravity match;
  - a walk into a 2 m pillar from 8 headings, with `inside` empty on every frame and the hero reaching the pillar;
  - turning beside the pillar;
  - a corner with the camera behind the walls at 3 view angles, plus being pressed in (lens never inside);
  - a 0.27 m step climbed and a 0.39 m step blocked;
  - a stub vehicle enter and exit;
  - touch at both SHAPES: the stick plus a look drag moving in turn as `browser()` events, half a window turning 120 deg, pitch unchanged, the stick held, every button at least 96 px and holding its action.

## 2. Half done
- `tests/player_test.gd` `footsteps()` was **just added and has never run**. It checks: alternating feet over a 3 s walk, marks near the walker, and 2 marks on a hop landing. Its first run may need fixing.
- Films not yet looked at:
  - Sandbox films time out at 300 s on this CPU.
  - Fixture films (`--film` with the `scene` copy) were stopped half way for the reboot.

## 3. Last check results
- `godot --headless --path . -s tests/run.gd`: 0 failed (no player errors).
- `tests/player_test.gd` (before `footsteps()` was added, with the cylinder): **0 failed**.
- `feel-probe data/reality.json .` (the real sheet): **4 FAIL**: walk 0, hurry 0, stop 0.04, hop 0.434. Every measured row has `at: [0,0,0]`, the centre of `hab1` (world.json habitat at [0,0]), so the hero starts inside the habitat. **This is a data problem, not the player.**
- The same sheet with `at: [0,0,16]` in the sandbox, and with `scene: res://player/dev.tscn`: **all 4 PASS**: walk 1.0, hurry 1.6, stop 1.513, hop 0.171 (max 0.18).
- `capture-view`: not run yet.

## 4. Next steps
1. Run `godot --headless --path . -s tests/player_test.gd` and fix `footsteps()` if it fails (about 90 s of real time).
2. Films on the fixture, one row at a time:
   - make the sheet copy: `python3` set `scene` to `res://player/dev.tscn` on every measured row;
   - then `node ../../tools/feel-probe.mjs <copy> . --only <id> --film <id>` for hero.jump.hop, hero.speed.walk and hero.speed.hurry;
   - open each `<out>/<id>.png`: no sliding feet, the walk and the hurry read differently, a small two-foot hop.
3. `node ../../tools/capture-view.mjs . captures/laneA --views default,hero --scale 0.5` and open the PNGs. Check that the hero's back faces the default camera and the visor shows in the `hero` view.
4. Re-run `tests/run.gd` and the probe on the real sheet, then report.

## 5. Contract problems for the merging session
- **The reality.json probe rows' `at` is inside the habitat.** Suggest `at: [0, 0, 16]` (ground about 0.01 m, clear for 10 m north). Also, the probe's jump start is `row.at[1]`, not the placed height, so `at` must sit where the ground is near 0, or feel-probe should start from the first sample.
- The player has no `restyle(design)`: the hero keeps `design.json` colours when the sky state changes, and so do the touch styles.
- `vehicle.drive(input)`: the axes are not pinned. The player sends x = steer right +, y = throttle forward +. `seat()` is assumed global.
- Nobody calls `player.exit()` on the interact key while driving yet (sandbox or interaction lane).
- No sheet row for the steepest walkable slope: the engine default of 45 degrees stands, and the separation ray climbs any slope under it.
- Feel numbers that should move into tuning.json: `hero_model.gd` `FEEL` (xfade, anticipation, crouch, tuck, squash, fold_rate).
- Skipped:
  - camera whiskers;
  - tight-space and enclosed-space framing (no crawl gaps or containers yet);
  - a shorter hop on an early release (a 0.18 m hop leaves nothing to shorten);
  - pushing the lens out of a thin pole.
- I could not stop two orphaned engines from my earlier sandbox film runs (pids 92524 and 105636; permission denied). They end at their `--quit-after`. The reboot clears them.
