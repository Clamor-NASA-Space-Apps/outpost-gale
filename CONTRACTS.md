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
| 9 | 256 | rock: a solid rock's extra bit (with 2 or 3), and any static no taller than `rover.climb` over its item's underside (a build pad, a gland box; `world.gd _solidify()`): what a rover wheel rolls onto | rover wheel casts |

## Input actions (registered in code by `player/controls.gd`, keys and touch feed the same actions)
`move_forward` W/Up, `move_back` S/Down, `move_left` A/Left, `move_right` D/Right, `hurry` Shift,
`jump` Space, `interact` E, `look_left/right/up/down` (stick and keys J L I K), `debug_sky` B,
`debug_teleport` T, `debug_quality` G, `fullscreen` F. Never a browser-owned key (Ctrl+W/T/N, F5, F11, F12, Alt+arrows), except `settings` on Esc: in a browser the first Esc frees the captured mouse, the second opens the settings screen.
Mouse look while captured (`screen_relative`); touch look by finger index, never `relative` (character-body).

## How the parts plug together
The composition root is `sandbox/sandbox.gd`. It calls only these:
- `world.build(design) -> void`, `world.height_at(x, z) -> float`, `world.restyle(design)` (sky state or quality),
  `world.landmark(name) -> {pos: Vector3, yaw: float}`.
- `player.place(pos: Vector3, yaw_deg: float)`, `player.enter(vehicle: Node3D)`, `player.exit()`,
  `player.state() -> Dictionary` (the `player`, `cam`, `heroScreen`, `interaction`, `carry`, `vehicle` keys below).
- The camera belongs to `player/` and follows the hero, or the vehicle the hero drives.
- An interactable is any node in group `interactable` with `prompt() -> String`, `can_use(hero) -> bool`,
  `use(hero) -> void`, `thing` (what moves) and `shape` (the thing's collision box in its own space). `use()` does
  one physical thing and changes no game state (hard rule 1: no meters, no resources before 14 Nov).
- The target (`sandbox/interactions.gd _pick()`, skills/character-body "Using things"): in reach when the nearest
  point of the shape is within `interact.reach` of the body's axis (height counted past the feet or head only), from
  either side; an open door or curtain counts at its shut pose too, so it closes from both sides; a wall (layer 2)
  between the hands and every spot of it hides it. Of those, the shape nearest the heading within `cone_deg`. The current
  target is favoured by `stick_deg`. `tests/doors_test.gd` holds the standing grid. The rover's shape is its rear
  hatch (the model's `hatch*` parts), not its hull: it is boarded there only (`tests/interact_test.gd` hatch()).
- A vehicle is in group `vehicle` with `drive(input: Vector2, hurry: bool, delta: float)` (input.x steer, right
  positive; input.y throttle, forward positive), `seat() -> Transform3D` (global), `exit_point() -> Vector3` (global),
  `speed() -> float`. The sandbox root calls `player.exit()` on `interact` while driving.
- `player.restyle(design)`: the sandbox calls it with `world.restyle()` on a sky or quality switch.
- Every use happens at once, with no clip (14 Nov): a door swings (unless the hero stands in its swing: then it stays
  as it is), a bag is in the hands (`player.carried`, held by `player.gd _carry()`) and is set down in front on free
  floor, the hero is in the rover (hidden) or out beside its hatch. Only a seat plays clips (sit down, stand up).
- `player.attention`: a `Node3D` or null, the thing the helmet turns toward; the interactions set it to their target.
- The player reads `breath_phase` (0 to 1) from any sibling that has it (the audio node), so the chest rises on the
  breath you hear.
- `player.footstep(pos: Vector3, yaw_deg: float, foot: String)` signal; the root connects it to `world.mark()` and
  `world.puff()`. `world.mark(pos, yaw_deg, kind, width := 0.3, strength := 1.0)`: `foot_l`, `foot_r` or `wheel`,
  `strength` its depth (a rover's grows with speed).
- A vehicle may have `top` (m/s): the camera then sits lower and closer, and looks further ahead, as the real
  speed nears it (`tuning.json` camera `rush_*`).
- The mouse cursor: captured only by a left click that reaches the 3D view (`player/follow_cam.gd`); every HUD
  control, the settings screen and the cover stop clicks (`MOUSE_FILTER_STOP`). Shown again by Esc (the settings),
  the cover, and a lost window focus. `tests/cursor_test.gd` (under xvfb-run) walks it.
- `world.puff(pos: Vector3, vel: Vector3, strength: float, kind := "foot")`: ground-contact dust at the real contact
  frame (skills/ground-contact-fx): `vel` is the foot's or wheel rim's world velocity at contact, `kind` `foot` or
  `wheel`.
- Section 1 ships stand-ins with these methods (a capsule hero, box prefabs), so every check runs before a
  lane lands.

## Test hooks
`Forge.register(sandbox)`. `render_game_to_text()` returns:
`player.{pos, speed, onFloor, gait, inside, room}`, `cam.{inside, dist, first}`, `heroScreen` (0 when the hero is hidden), `interaction.{target, prompt}`,
`vehicle.{driving, speed}`, `carry`, `sky.{state, phase, hour, sun_el, sun_az, keys, light_el, lamps_on, coat, bursts,
probe_redraws}` (The sky clock, below), `quality`, `fps`.
`set_view(name)`: `default` (the play camera), `base`, `hero`, `horizon`, `west`, `storm`, `airlock`, `rover`, `greenhouse`,
`hab_in` (inside HAB 1: the life-support wall and bunks), `hab_desk` (inside HAB 1: galley, Veggie, desk and map),
`hab_room`, `greenhouse_room`, `shelter_room` (the play camera in first person, the hero placed in from the door looking in).
`place(pos, yaw_deg)`: the hero, through `player.place()`.

## Prefabs (`data/world.json` `prefabs`: id -> model file; a missing file loads a labelled stand-in box)
`habitat`, `battery_bank`, `oxygen_maker`, `water_recycler`, `greenhouse`, `storm_shelter`,
`dish`, `build_pad`, `lander`, `rover`, `curiosity`, `cargo_bag`, `pip`, `lamp`, `beacon`, `telltale`, `charger` (the rover's charging post), `veggie` (HAB 1's
plant unit), `solar_wing`, `reactor` (fission surface power, in the north-east corner; layout in `design/research/layout.md`), `gale_map` (the wall map in HAB 1),
`mont_mercou` (the butte), `lettuce_1` to `lettuce_4`, `rock_*`. (`water_recycler` stays registered but is not placed:
water is recycled indoors, in HAB 1's racks.)
- `plants`: `{item id: [slot entry, ...]}`, filling the model's `slot_N` nodes in order. An entry is a lettuce growth
  stage (1 to 4) or a prefab id, which goes in at its own size (HAB 1: `veggie`, `gale_map`).
- `cables`: power lines laid on the ground (`world.gd _lay_cables()`): polylines of [x, z] draped on `height_at()` every
  `step` m, `width` and `height` m, one DESIGN.md `role`; rocks keep off them as off paths. One merged mesh, no collision.
  `ends` (one per line): `"item:node"`, the empty in the device's model the line plugs into (`port_1` when left out);
  the line's first and last points move onto it. A device's model carries each port as an empty named `port*` inside a
  ground gland box (`forge/base_kit.py port()`), which the world sets onto the ground (`world.gd _glands()`).
- `charger`: the rover's charging post: the plug (`plug`) sits in the rover's `port_charge` while the rover stands in
  its bay, else in the post's `holster`; `charge_light` shows while plugged in; `world.charging()`. Motion and light only.
Groups: `floor` (anything walkable on top), `wall` (blocks), `thin` (layer 3), `interactable`, `vehicle`, `carriable`.

## Graphics settings (quality knobs; owner: `addons/forge/house_style.gd`, presets in DESIGN.md `quality`)
- `Forge.HouseStyle.set_quality(root, design, level, overrides := {})`: a preset (`phone`, `older`, `laptop`,
  `gaming`, `max`, weakest first, named for the hardware they suit) with any knobs on top (`{"msaa": 4, "shadows": 0}`). Then `sandbox._restyle()` (the world reads `trail`, `particles`,
  `ground`), then `sandbox._warm()`: a knob marked `recompile` compiles shaders, which the web build cannot cache,
  so the cover goes up while they compile. The sandbox's `G` key does all three through `sandbox.set_graphics()`,
  which puts the cover up and waits two frames before `set_quality` (it can stall for seconds), so the knobs land a
  few frames after the call: read them after `busy()` goes false.
- `Forge.HouseStyle.knobs(design) -> {name: {values, default, recompile, game, value, preset}}`: the list a settings
  screen is built from. `value` is in force, `preset` is the preset's own. `HouseStyle.KNOBS` holds the table.
- Knobs: `msaa` 0/2/4/8; `pixels` 3D budget in Mpx (0 = none), `scale` a cap under it; `shadows` 0/1/2/4 splits
  (recompile), `shadowMap`, `shadowRange`, `shadowFilter` (recompile), `normalBias`; `glow` (recompile); `fog`,
  `ssao` (recompile); `aniso` 0 to 4; `detail` off/code/texture (recompile); `lamps` nearest lit, -1 all
  (recompile); `vsync`, `maxFps` (set only when given, and back to the default once given before); game knobs `trail` (print map px), `particles` (dust
  share), `ground` flat/cheap/full (recompile). No FXAA or SMAA: Compatibility has neither (renderers.rst).
- Defaults: `HouseStyle.default_quality(design)`, the preset DESIGN.md marks `start: phone` on a phone browser (`phone`,
  the A16), `start: desktop` elsewhere (`laptop`). A level saved before 13 Nov maps low, medium, high to phone,
  laptop, gaming (`ui/settings.gd` OLD).
- The settings screen shows the presets as cards and, under Advanced, six bundles (`ui/settings.gd` ADVANCED:
  anti-aliasing, resolution, shadows, effects, V-Sync, frame cap). The presets are built from those bundles, so
  each row names the preset's choice; only the knobs a bundle sets are saved as the player's own.
- `sandbox.busy() -> bool`: true while the cover is up (Forge waits for it before a picture).

## Which inits await
None. `world.build()` is synchronous (it loads everything it needs before returning); the player is placed after it.
The main scene is `ui/boot.tscn`: natively it draws the splash and a bar at once, loads `models/`, `textures/` and
`data/` images on the main thread, a slice each frame, then adds `sandbox.tscn`, whose build finds them in memory. A tool run and the web
build go straight to the sandbox; tests load `sandbox.tscn` themselves. The Master bus is silent until the first
cover lifts (`audio.lift()`, a 1 s fade).

## Settings, music and PIP (12 Nov 2026)
- `sandbox.set_graphics(level, overrides, restyle := true, warm := true)`: the one way to change graphics (G key and
  `ui/settings.gd`); `sandbox.overrides` holds the player's per-knob choices (saved to `user://settings.cfg`, with the
  `Show FPS` switch, `sandbox.fps_label.visible`). G steps to the next preset, plain, and does not save.
- `audio.music(name) -> bool` (rare cues on the Music bus: first_step, airlock_sealed, sunset, discovery, mission_lost),
  `audio.sky(name)`, `audio.set_volume(which, v)`. `render_game_to_text()` gains `audio.music` (the cue playing).
- PIP (`sandbox/pip.gd`) wanders the base; `render_game_to_text()` gains a `pip` key (its position, goal, mode).

## More life (12 Nov 2026)
- The rover's drawn body rides a damped spring (`sandbox/rover.gd`): every drawn part but the wheels sits under a
  `sprung` node, whose transform is `rover.lean` (body space). The physics body, its collision and the camera's
  target stay on the wheels' plane; `seat()` includes `lean`, so the driver rides with the cab.
- `audio.radio(who)`: a wordless call on the suit radio (`base`, `pip`), rare (`tuning.json` `audio.radio`) and only
  when no cue or event sound is playing. PIP asks for it by emitting `sound("radio_pip", pos)`. `render_game_to_text()`
  `audio` gains `radio.{who, at}`. `audio.music("quiet")`: the rare quiet-moment motif (`audio.motif`).
- `follow_cam.glance: Array[Vector3]`: far points the view may turn toward, slowly and a few degrees, while the
  player leaves the look alone and the hero stands on foot. `audio.gd` fills it in the sunset sky with the habitat
  (and the dust devil when one is out); it is empty otherwise.

## The end of the ground (12 Nov 2026)
- The real ground is the 400 m patch (`data/terrain.json`); past it only the backdrop is drawn, with no collision.
  `world.bound(margin := 0.0) -> Rect2` (x, z) is where anything that moves may go (`data/world.json` `bound.half`),
  `world.past(pos, margin := 0.0) -> float` how far a point is past it. Inside it the drawn ground, its collision and
  `height_at()` are one surface (`tests/edge_test.gd`).
- `player.bound: Rect2`, set by the root from `world.bound()`: near its edge the hero's outward speed is held to what
  its braking stops in, so it slows and stops on the line. The rover brakes for the line as for a wall (`blocked`
  `"edge"`), with its centre kept `bound.reach` in for the hatch.
- The safety net (`sandbox.gd _physics_process()`): the hero, the rover, PIP and any bag resting on the ground found
  more than `bound.below` under the ground, or past the line, go back on top at the nearest spot inside; the hero
  behind a short fade (`bound.fade_s`) when that is further than `bound.fade_over`. `sandbox.rescued` counts it (a
  walk or a drive that needs it is a bug).
- Reflection probes: `HouseStyle.warm()` redraws every probe from `at` after its variants, under the sky in force
  (the probe's ambient setters do not redraw it in Compatibility): `at` must stand inside every probe. Render layer 2
  holds the ground, the rocks and every dust emitter, also those made in play (`dust.layers`): the probe draws them
  and does not shade them (`reflection_mask` 1), so dust is lit as the ground it rose from.

## Rooms and the interior camera (12 Nov; first person indoors again since 15 Nov 2026)
- `data/world.json` `rooms`: per item id, its floor plan in its own space (`{circle: [x, z, r]}`, `{rect: [x0, z0, x1,
  z1]}`). The root hands them to `player.rooms` (`{id: {node, areas}}`). `player.room` is the room the body is in: in
  once the whole body is past the plan's edge, out once it is wholly outside (the hero's radius either way), so a
  doorway never flips it (`tests/indoor_test.gd`).
- In a room the view is first person (Ravindu, 15 Nov 2026; third person indoors was tried on 14 Nov). The player sets
  `follow_cam.room` (bool); `follow_cam.first` eases 0 to 1 over `camera.fp_ease_s` and the lens goes from the follow
  position into `follow_cam.eye` (the visor's middle, riding the drawn body over a sill), level after a teleport,
  pitch within `camera.fp_pitch_min/max`. Every turn there is the player's: no recentre, no glance. The hero is not
  drawn from its own eye and fades back in over `camera.fp_reveal_s` outside; `follow_cam.show_body` draws it for a
  cut another camera films. E picks what the view's centre rests on, else the nearest thing to it inside
  `interact.aim_deg` (`sandbox/interactions.gd _pick()`).
- Outdoors the arm and its feelers cast a sphere of `camera.clear` (the lens stands that far from every solid), and
  the feelers (`camera.feelers`, `feel_slack`, `feel_rate`) slide the lens in before the arm's own cut; thin things
  block only over the last `camera.thin_tail` m before the lens (`tests/camera_test.gd`). Concave colliders collide
  from both sides (`world.gd _layer()`), so a one-sided glass shell stops a cast from inside.
- Outdoors the hero fades only by the lens's gap to its drawn box (`camera.fade_near`, `fade_far`).
## Room light and the toilet curtain (13 Nov 2026)
- Each room in `data/world.json` `probe.rooms.<id>` has its own reflection probe (`interior` false for a glass dome)
  and an optional `light` (`at`, `range`, `share`, `color`: a DESIGN.md colour name, else `lighting.room`'s). It is an
  unshadowed OmniLight3D on in every sky (DESIGN.md `lighting.room`), lighting render layer 4 only (`world.gd ROOMS`:
  swept interior meshes, a door's room side `interior`, the toilet `curtain`), and in the lamp pool, so a preset's
  `lamps` limit holds.
- Interactable `curtain` (HAB 1's toilet): closed at start, E gathers it along its rail to
  `tuning.json interact.curtain_gather` of its width over `move_s` and back; motion and the sound `curtain` only.

## The sky clock (13 Nov 2026)
- `world/sky_clock.gd` (the sandbox's `clock`) owns one local solar hour at Gale. The sun runs its real path
  (`HouseStyle.sun_at(DESIGN.night.md celestial, hour)`), and the look blends the four designs by the sun's elevation:
  day at and above DESIGN.md's 12 degrees, sunset at DESIGN.sunset.md's 4, night at DESIGN.night.md's `celestial.hour`
  (19:30, -18 degrees), the storm laid over the lit keys. Knobs: `tuning.json sky` (`day_minutes` 20, `night_speed` 3,
  `start_hour` 6.5, and the rest).
- **It drives the look only**: no sol counter is shown or kept, nothing scored, no dust lowering power (hard rule 1).
- **The 14 Nov hook**: set `clock.driven = true` and call `clock.set_hour(h)` from the sim every frame (h in hours,
  values past 24 run on into later sols); the sim then owns time, skips and sleeping. `clock.phase_changed(state)`
  fires when the leading design changes (`design`, `design.sunset`, `design.night`, `design.storm`): the audio's sunset
  cue listens to it. `clock.storm_on` starts or ends a storm (it builds and clears over `storm_build_h` game hours);
  `clock.coat` is the settled dust (DESIGN.md `weathering.amount` clear, DESIGN.storm.md's after a storm), the value
  the rules may tie to panel power on 14 Nov. `clock.paused` stops it (the sandbox sets it while the settings or the
  cover are up). `clock.hour()`, `clock.phase()`, `clock.report()`.
- Debug key `debug_sky` (B): a few seconds of time-lapse to the next phase, dawn, noon, dusk, night, then a storm at
  noon, then the storm off and on to dawn (its coat stays). `sandbox._sky(i)` jumps straight to SKIES key `i`'s own look
  (noon, the sunset's sun, the night's hour, a noon storm) behind the cover, for tests and the tools' `sky=` args.
- The tools pin the hour (any `--forge-job` run, so pictures repeat); `hour=H` as a game argument, or a view named
  `<view>@H` (`base@18.6`), pins it at H.
- The rig is built once (DESIGN.md's materials, DESIGN.night.md's lamp and night sky at `timeScale` 1, its stars turned
  by the clock's own Mars seconds). The sky's changing values are global shader uniforms (`HouseStyle.set_look()`;
  `forge_sky_light_dir` is the light in force, for any surface that answers it), the light turns with the sun every
  frame (`sun_step_deg` 0; above 0 it steps), the outdoor probes redraw when the blend has moved `probe_step`, and the
  world's lamps (group `world_lamp`) fade on below `lamps_on_deg` of sun and off above `lamps_off_deg`.
- The work lights' glowing faces (the shared `light` role: lamp heads, the pad's corner lights) fade with the lamps,
  to a glimmer by day; blinking status lights (machines.gd `light_flash`) and PIP's bar wear their own copies and
  keep their full glow. The rover's lights belong to its lane: give them their own material copy, or they dim by day.
- `forge_sky_light_dir` (global) is the light in force, for a surface that answers it. The sun's shadow split is sized for the lower of the light's elevation and the
  leading design's (`HouseStyle._fit_split()`, meta `split_el`), never smaller than the approved look's.
- A storm coats the trackers' panels at `coat_rise_h`; a tilt sheds one over `shed_s`, and it gathers dust again only
  at that rate.
- `world.dust.switch(emitter, on, instant)` turns the devil or the storm front on or off (instant: whole at once
  behind a cover; in play it grows).
- `world.instanced(mi) -> [MultiMeshInstance3D, index]`: where a moving mesh is drawn; every MultiMesh carries custom
  data, whose red is the copy's share of the coat on a role drawn with `HouseStyle.role(..., each = true)` (the
  trackers' panels: a storm coats them all, a tilt by hand sheds one, `interactions.used` -> `clock.used`).
  `machines.aim(sun)` turns the trackers to the clock's sun (zero lies them flat).

## Actions, sounds and the charger (13 Nov 2026, night)
- `player.sit(on)`, `player.seated`, `player.cut` (standing up: `{left}`, else empty). `follow_cam.show_body` holds
  the body drawn while seated. `player.model.point(clip, "hand" | "seat_hip" | "wheel") -> Vector3` in the hero's own
  space, to place a stand point from a spot.
- Use spots (`data/world.json` `uses`: item id -> rows `{kind, prompt, box: [x0,y0,z0,x1,y1,z1], stand: [x, z, yaw_deg],
  clip, sound}` in the item's own space): one Interactable of kind `spot` per row, its `thing` an empty node at the
  item's origin, its `shape` the box, `row` the row, `stand()` the global stand point. E plays the sound, sets each
  step's end state (a `keep` prop keeps it, others go back) and emits `used(kind)` at once; `clip` is no longer played.
- `audio.used(name, pos)` plays the `SOUNDS` table's files for `name` (`audio.gd`); an unknown name or a missing file
  is an error. `audio.music(name, force := false)` (`force` fades the playing cue and skips the gap), `stop_music()`,
  `bed(name)` (`eva`, `habitat`: phrases with long rests), `duck(on)` (world sound down `audio.duck_db`, music not),
  `wake()` (the next door opened plays `dawn`). `render_game_to_text()` gains `audio.bed`.
- Cables (`world.json cables`): `ends` names each line's two `item:port_*` nodes (forge/base_kit.py `port()`); `world.gd`
  moves the line's ends onto them. `charger` plugs the parked rover in at its post (`world.charging()`): motion and light
  only, no game state.

- `graded.prefabs` (world.json): items of these prefabs have their footprint (standin size) laid level before the ground
  is built (`terrain.gd _grade()`), so a pad on a slope is neither buried nor torn by the ground.

## Use spots (data/world.json `uses`, sandbox/interactions.gd)
A row: `kind` (the action id the rules know, sim/sim.json `uses`), `prompt`, `clip` (data/clips.json), `sound` (played at
the start through `world.sound`), and optionally `on` (the item part it stands at), `face`, `grip`, `seat`, `props`
(made in code or a GLB, placed in the item's space but outside its node), `steps` (verbs `appear`, `take`, `turn`,
`glow`, `puff`), `needs`, `hold_s`, `favour_deg` (a pick bonus so a nearby door keeps its prompt).
`used(kind, pos)` is emitted once, when the clip runs to its end; a move key that cuts it short emits nothing and puts
the props back. sandbox.gd passes only the ids the rules know to `sim.use()`.


## The Sol 1 tutorial (14 Nov 2026)
- `beats` (cine/beats.gd) signals: `line(line_id, opts{keys, fact})` -> `hud.say`; `task(id)` -> `hud.set_tasks(beats.tasks())`;
  `objective(target)` ("pip", a landmark, an item id, "" clears) -> the HUD waypoint; `shot(name)` -> `cine.shot`;
  `close_door(item)` is news only (beats shuts it through `interactions.set_door`). The root answers with
  `beats.notify("shot_done:<name>" | "dismissed" | "map_open" | "map_closed")`.
- `cine.shot(name, args := {})` (data/cine.json `shots`: dawn_reveal, focus_pip, look_around) and `signal shot_done(name)`,
  once per call, even when refused. The cinematics' state var is `cine.beat` (state() still says "shot").
- `interactions.set_door(item_id, open)`: swings a door by its own path, waiting for a clear swing; never pushes the hero.
- `player.allow(actions: Array)`: `[]` allows all, `["none"]` none; families "move" and "look". Esc and settings always work.
