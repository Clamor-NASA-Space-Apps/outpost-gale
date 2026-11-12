# CONTRACTS.md

What parallel lanes would otherwise guess differently. A lane reads this file, `DESIGN.md` and its own folder.
Change it only through the session that merges the lanes.

## Space
- Metres. +X east, -Z north, +Y up. The patch centre (0, 0, 0) is 200 m west of Bradbury Landing.
- Yaw in degrees clockwise from north: `rotation.y = -deg_to_rad(yaw)`. A model's front faces -Z at yaw 0.
- Ground height: `world.height_at(x, z)` only (it reads `data/terrain.json`, the one height source).

## Collision layers (owner: `world/`)
| Layer | Bit | What | Who looks for it |
|---|---|---|---|
| 1 | 1 | ground (terrain heightmap) | hero, rover, camera, rays |
| 2 | 2 | statics: buildings, machines, rocks, the lander | hero, rover, camera |
| 3 | 4 | thin statics: masts, poles, cables, lamp posts (narrower than the hero) | hero, rover. **Not the camera** |
| 4 | 8 | hero body | rover |
| 5 | 16 | vehicles (the rover, as an `AnimatableBody3D`) | hero, camera |
| 6 | 32 | interaction areas (`Area3D`, never blocks) | the hero's interaction finder |
| 7 | 64 | carriables (cargo bags) | hero, rover, camera |
| 9 | 256 | rock: a solid rock's extra bit (with 2 or 3), what a rover wheel rolls onto | rover wheel casts |

## Input actions (registered in code by `player/controls.gd`, keys and touch feed the same actions)
`move_forward` W/Up, `move_back` S/Down, `move_left` A/Left, `move_right` D/Right, `hurry` Shift,
`jump` Space, `interact` E, `look_left/right/up/down` (stick and keys J L I K), `debug_sky` B,
`debug_teleport` T, `debug_quality` G. Never a browser-owned key (Ctrl+W/T/N, F5, F11, F12, Alt+arrows), except `settings` on Esc: in a browser the first Esc frees the captured mouse, the second opens the settings screen.
Mouse look while captured (`screen_relative`); touch look by finger index, never `relative` (character-body).

## How the parts plug together
The composition root is `sandbox/sandbox.gd`. It calls only these:
- `world.build(design) -> void`, `world.height_at(x, z) -> float`, `world.restyle(design)` (sky state or quality),
  `world.landmark(name) -> {pos: Vector3, yaw: float}`.
- `player.place(pos: Vector3, yaw_deg: float)`, `player.enter(vehicle: Node3D)`, `player.exit()`,
  `player.state() -> Dictionary` (the `player`, `cam`, `heroScreen`, `interaction`, `carry`, `vehicle` keys below).
- The camera belongs to `player/` and follows the hero, or the vehicle the hero drives.
- An interactable is any node in group `interactable` with `prompt() -> String`, `can_use(hero) -> bool`,
  `use(hero) -> void`. Its `Area3D` (layer 6) sits in front of the thing. `use()` does one physical thing and
  changes no game state (hard rule 1: no meters, no resources before 14 Nov).
- A vehicle is in group `vehicle` with `drive(input: Vector2, hurry: bool, delta: float)` (input.x steer, right
  positive; input.y throttle, forward positive), `seat() -> Transform3D` (global), `exit_point() -> Vector3` (global),
  `speed() -> float`. The sandbox root calls `player.exit()` on `interact` while driving.
- `player.restyle(design)`: the sandbox calls it with `world.restyle()` on a sky or quality switch.
- `player.act()`: the hero reaches (the interact clip); the interactions call it from `use()`, only when something is used.
- `player.attention`: a `Node3D` or null, the thing the helmet turns toward; the interactions set it to their target.
- The player reads `breath_phase` (0 to 1) from any sibling that has it (the audio node), so the chest rises on the
  breath you hear.
- `player.footstep(pos: Vector3, yaw_deg: float, foot: String)` signal; the root connects it to `world.mark()` and
  `world.puff()`. `world.mark(pos, yaw_deg, kind, width := 0.3)`: `foot_l`, `foot_r` or `wheel`.
- `world.puff(pos: Vector3, vel: Vector3, strength: float, kind := "foot")`: ground-contact dust at the real contact
  frame (skills/ground-contact-fx): `vel` is the foot's or wheel rim's world velocity at contact, `kind` `foot` or
  `wheel`.
- Section 1 ships stand-ins with these methods (a capsule hero, box prefabs), so every check runs before a
  lane lands.

## Test hooks
`Forge.register(sandbox)`. `render_game_to_text()` returns:
`player.{pos, speed, onFloor, gait, inside}`, `cam.{inside, dist}`, `heroScreen`, `interaction.{target, prompt}`,
`vehicle.{driving, speed}`, `carry`, `sky`, `quality`, `fps`.
`set_view(name)`: `default` (the play camera), `base`, `hero`, `horizon`, `storm`, `airlock`, `rover`.
`place(pos, yaw_deg)`: the hero, through `player.place()`.

## Prefabs (`data/world.json` `prefabs`: id -> model file; a missing file loads a labelled stand-in box)
`habitat`, `solar_array`, `battery_bank`, `oxygen_maker`, `water_recycler`, `greenhouse`, `storm_shelter`,
`dish`, `build_pad`, `lander`, `rover`, `curiosity`, `cargo_bag`, `pip`, `lamp`, `beacon`, `rock_*`.
Groups: `floor` (anything walkable on top), `wall` (blocks), `thin` (layer 3), `interactable`, `vehicle`, `carriable`.

## Graphics settings (quality knobs; owner: `addons/forge/house_style.gd`, presets in DESIGN.md `quality`)
- `Forge.HouseStyle.set_quality(root, design, level, overrides := {})`: a preset (`low`, `medium`, `high`) with
  any knobs on top (`{"msaa": 4, "shadows": 0}`). Then `sandbox._restyle()` (the world reads `trail`, `particles`,
  `ground`), then `sandbox._warm()`: a knob marked `recompile` compiles shaders, which the web build cannot cache,
  so the cover goes up while they compile. The sandbox's `G` key does all three.
- `Forge.HouseStyle.knobs(design) -> {name: {values, default, recompile, game, value, preset}}`: the list a settings
  screen is built from. `value` is in force, `preset` is the preset's own. `HouseStyle.KNOBS` holds the table.
- Knobs: `msaa` 0/2/4/8; `pixels` 3D budget in Mpx (0 = none), `scale` a cap under it; `shadows` 0/1/2/4 splits
  (recompile), `shadowMap`, `shadowRange`, `shadowFilter` (recompile), `normalBias`; `glow` (recompile); `fog`,
  `ssao` (recompile); `aniso` 0 to 4; `detail` off/code/texture (recompile); `lamps` nearest lit, -1 all
  (recompile); `vsync`, `maxFps` (set only when given); game knobs `trail` (print map px), `particles` (dust
  share), `ground` flat/cheap/full (recompile). No FXAA or SMAA: Compatibility has neither (renderers.rst).
- Defaults: `HouseStyle.default_quality()`, `low` on a phone browser (the A16), `high` elsewhere.
- `sandbox.busy() -> bool`: true while the cover is up (Forge waits for it before a picture).

## Which inits await
None. `world.build()` is synchronous (it loads everything it needs before returning); the player is placed after it.

## Settings, music and PIP (12 Nov 2026)
- `sandbox.set_graphics(level, overrides, restyle := true, warm := true)`: the one way to change graphics (G key and
  `ui/settings.gd`); `sandbox.overrides` holds the player's per-knob choices (saved to `user://settings.cfg`). G resets
  to a plain preset and does not save.
- `audio.music(name) -> bool` (rare cues on the Music bus: first_step, airlock_sealed, sunset, discovery, mission_lost),
  `audio.sky(name)`, `audio.set_volume(which, v)`. `render_game_to_text()` gains `audio.music` (the cue playing).
- PIP (`sandbox/pip.gd`) wanders the base; `render_game_to_text()` gains a `pip` key (its position, goal, mode).
