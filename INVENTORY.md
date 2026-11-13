# Outpost Gale: what we have, what is missing

Written 12 Nov 2026 (two days before the hackathon) from the files on disk. **Other lanes are changing the rover, the dust coat and the hero today**, so those rows show the last commit (`77104c6`) plus the uncommitted work in progress (70 files changed in the working tree: rover, habitat, greenhouse, lander, solar array, machines, lamp, dust, terrain shader, camera, hero). Re-check them after the lanes merge. Licences and sources per asset are not repeated here: see [ASSETS.md](ASSETS.md) and `assets-cache/CREDITS.md` at the workspace root.

Read-only sources: [AGENTS.md](AGENTS.md), [CONTRACTS.md](CONTRACTS.md), [DESIGN.md](DESIGN.md) and its three sky files, [design/BRIEF.md](design/BRIEF.md), [roadmap.md](roadmap.md), [design/handoff/session.md](design/handoff/session.md), [design/research/alive.md](design/research/alive.md), the `data/` files, and the code folders.

## 1. TL;DR

| Kind | Count | Where |
|---|---|---|
| 3D models (GLB) | 29 (7.4 MB with Curiosity's WebP textures) | `models/` |
| Blender recipes | 25 | `forge/` |
| Hero clips | 10 (hero has 65 bones) | `data/clips.json` |
| Sky states | 4 (day, sunset, night, storm) | `DESIGN*.md` |
| Colour roles | 12 (plus HUD colours) | `DESIGN.md` |
| Photo texture sets | 8 sets, 6.3 MB (body, metal, trim, suit, rock, dust, gravel, ripple) | `textures/` |
| Sounds (Ogg) | 41 files, 732 KB (about 20 distinct sounds, each clear plus muffled) | `audio/` |
| Reality rows | 46, no pair rows | `data/reality.json` |
| HUD components | 15 scenes, 23 icons, 2 fonts, 1 gallery (6 pages, laptop and phone) | `ui/` |
| Sandbox interactions | 4 (airlock door, solar panel tilt, cargo bag, rover) | `sandbox/` |
| Test suites | 10 files under `tests/` (8 headless suites, 2 capture fixtures) | `tests/` |
| Code | about 3,900 lines of GDScript and shaders in `world/ player/ sandbox/ ui/ audio/` | |
| Terrain | 400 x 400 m real HiRISE patch at 2 m, 1 m normal map, MOLA skyline | `data/terrain.json` |

Where the roadmap stands: look, S2 lanes and most of S3 are done. Not done: the S3 phone step, every gate box (checks, `/code-review medium`, lessons) for S1 to S3, and all of S4.

**Top 10 gaps** (details and owners in section 11):
1. The game has never run on a phone. No iPhone playtest, a web-only engine error (`rp_child is null`), 47 MB game data, 195 draw calls against a budget of 150 (models, world, player: yes, before 14 Nov).
2. ~~Sky look approval~~ Ravindu approved the sunset/night look (blue halo, twilight, lit windows) on 13 Nov 2026 morning playtest. (Next gaps renumber from here.)
3. All S4 gate work is open: sweeps, gait films, the seven capture views at full size, `web-check`, complete credits (all lanes: yes).
4. No crewmate model (P1 in the brief). Hero in a second accent is the cheap answer (models: yes).
5. PIP is only a static model: no wobble, blink or eye life (models/world: yes, a physical idle only).
6. The HUD kit is not in the sandbox. The sandbox shows an fps label and a plain prompt, and the phone touch buttons use their own plain theme, not the kit's touch scenes (ui/player: yes).
7. Sound has holes: no alarm, no radio squelch, no music motif, no rover roll or panel clunk polish; the muffle cutoff is a guess; the suit fan is our own synthesis (audio: yes).
8. Missing world pieces from the brief: layered mudstone outcrop, dune ripples as shape, cables, crates, antenna mast, cinematic Earth/Mars/ship pieces, a heater (icon exists, no model) (models/world: yes).
9. Body parts without collision or checks: solar panels and the dish have none, the camera inside the habitat is "not yet checked", the rover has no body roll (player/world: yes).
10. Paperwork has drifted: ASSETS.md has no rows for the terrain backdrop, textures, fonts or icons, and a few rows are stale; CONTRACTS.md and the rig disagree on sun azimuth (all: yes, docs only).

## 2. 3D models

All in `models/`. Triangles and licence per file: [ASSETS.md](ASSETS.md). "Moving parts" are named nodes the code turns. Every model except Curiosity passes `style-check` (Curiosity keeps NASA's own textures on purpose, a decided exception in DESIGN.md).

| File | What it is | Real-world thing | Moving parts | Status |
|---|---|---|---|---|
| `building_habitat.glb` | 5 m drum on a 0.40 m raised floor (deck plates), ramp, 1.2 x 2.2 m hatch, portholes through the wall, "HAB 1" lettering, mast, tanks; fitted for 2 crew round an open middle: 2 stacked sleep stations after the ISS crew quarters with 12 water bags (CWC, the storm shelter), galley, toilet, air and water racks (ISS rack faces), air valve panel, workstation with the Gale map, 2 spare suits on stands (`prop_suit_stand.glb` in slots), ceiling lights | NASA Habitat Demonstration Unit (8 wedges); ISS crew quarters and racks | `door` (swings in) | done, first-person refit 13 Nov |
| `building_greenhouse.glb` | 6.8 m geodesic dome, vestibule, 2 floor-standing grow racks (3 tiers, magenta LED bars under each shelf, microgreens) either side of an aisle, 16 lettuce slots | Mars greenhouse (forged, not the Quaternius dome: it has no doorway) | `door` | done, WIP edit today |
| `building_dish.glb` | 3 m parabolic dish on a pedestal | base high-gain antenna | `dish` (nods) | done. No dish collision |
| `building_storm_shelter.glb` | Stacked cargo bags, 3.0 x 2.42 x 2.81 m, one doorway | NASA Orion storm shelter (bags of food and water) | none | done. 12.5k triangles, the heaviest |
| `building_lander.glb` | Crewed lander, 6 m footprint, 7.45 m tall, ladder | generic crewed lander (ending vehicle is an open team decision) | none | done, WIP edit today |
| `pad_build.glb` | 6 x 6 m paver pad with corner lamps | build plot | none | done |
| `prop_battery_bank.glb` | Cabinet, POWER sign, status light | battery bank | status light blinks | done, WIP edit today |
| `prop_oxygen_maker.glb` | Gas bottle skid by the airlock: 3 O2 (2 + spare) and 1 N2, line into HAB 1 | tanked gas of NASA's 30-sol plan, ISS tanks by the airlock | status light | re-forged 13 Nov |
| `prop_veggie.glb` | Veggie unit: magenta light cap, 6 pillows: red romaine, radish, microgreens, a wilted plant | NASA Veggie (ISS) | none | done 13 Nov, in HAB 1's galley |
| `prop_gale_map.glb` | 0.56 m table map of Gale and Mount Sharp, pin at the base (approximate) | LPG-3D model from NASA/JPL-Caltech/MSSS (CC BY-NC) | none | done 13 Nov, on HAB 1's desk |
| `building_reactor.glb` | 10 kWe fission unit, radiator mast, flashing beacon, 190 m out, cable to HAB 1 | NASA Fission Surface Power | `beacon` blinks | done 13 Nov |
| `building_solar_wing.glb` | Fixed 40 m solar wing; 6 rows = 600 m2 | DRA 5.0 solar wing | none | done 13 Nov |
| `rock_mont_mercou.glb` | Mont Mercou outcrop, baked photo colour, landmark `mercou` | the real outcrop at Gale (LPG-3D, CC BY-NC) | none | done 13 Nov |
| `prop_water_recycler.glb` | Water processor, tanks, filters | ISS water recovery | status light | done; moved indoors as a rack, the outdoor one stays until tuning.json `machines` drops `water` |
| `prop_lettuce_1..4.glb` | Four growth stages | Veggie lettuce (Quaternius crops) | none (scaled by game) | done |
| `prop_cargo_bag.glb` | Cargo Transfer Bag 0.5 x 0.42 x 0.27 m | NASA CTB | carried | done |
| `prop_lamp.glb` | 3 m work-light mast | field floodlight | none | done, WIP edit today |
| `prop_beacon.glb` | 1.2 m marker post, hazard bands | path marker | cap blinks | done |
| `prop_telltale.glb` | 2.2 m mast and hanging tube | Phoenix wind telltale (2008) | `tell` leans downwind | done |
| `vehicle_rover.glb` | Pressurised rover, 6 pivoting wheel pairs, hollow cabin, ROVER 1 | NASA Space Exploration Vehicle | `wheel_1..6`, driven | done, being reworked today |
| `vehicle_pip.glb` | 0.8 m helper rover, lights only | invented (PIP) | `head`, `eye_l/r`, `status_bar`, `wheel_1..4` exist but nothing animates them | model done, **no behaviour** |
| `vehicle_curiosity.glb` | Curiosity, insignia painted out | Curiosity at Gale (the right rover) | none | done, landmark at 80, 95 |
| `rock_small_a/b`, `rock_boulder_a/b`, `rock_slab_a/b` | Six scanned rocks, 0.25 to 2.0 m | Poly Haven scans (grey rock) | none | done |
| `terrain_backdrop.glb` | Mount Sharp and the crater rim ring | MOLA data | none | done, **no ASSETS.md row** |
| `character_suited.glb` | The hero, EMU-style suit, gold visor, teal bands | NASA "Astronaut" model on the Quaternius UAL skeleton | 65 bones | done, WIP edit today |

**Hero clips** (`data/clips.json`, with foot touchdown phases): `idle` 4.0 s, `walk` 1.33 s at 1.0 m/s, `lope` 1.14 s at 1.6 m/s, `hop_start`/`hop_air`/`hop_land` (0.34, 0.63, 0.55 s), `interact` 1.6 s, `carry_idle`, `carry_walk`, `drive_sit`. Not present: turn in place, stop, land-hard, wave, fall, get up, a crouch to pick up, enter/exit rover motion (the hero is placed in the seat).

Forge recipes: one per model in `forge/` plus `base_kit.py`, `lib`-style helpers, `hero_astronaut.py`, `hero_rig.py`, `hero_clips.py`, `hero_films.py`, `shapes.py`, `rocks.py`.

## 3. World

All built from data by `world/world.gd` (612 lines). The scene is `data/world.json`.

| Part | What there is today |
|---|---|
| Terrain | Real Gale patch from HiRISE `DTEEC_018854_1755`, 201 x 201 samples at 2 m (400 m square), 1 m normal map, 100 m chunks the camera can cull. Collision from the same heights, `height_at()` is the single source. Centre is 200 m west of Bradbury Landing |
| Skyline | `terrain_backdrop.glb`: Mount Sharp and the rim (MOLA 128 ppd) |
| Base layout | 29 items laid out as a real outpost (`design/research/layout.md`, 13 Nov): habitat, gas skid, 3 battery banks (the power yard), 6 solar wings, reactor in the NE corner (135, -135), Mont Mercou, greenhouse, shelter, dish, 2 pads, rover in its charging bay, PIP, 3 bags, 2 lamps, beacon by the landing pad, telltale, lander in the NW corner (-135, -135), Curiosity at (80, 95); 8 cables from the reactor and the wings through the battery bank to every user |
| Landmarks | `spawn`, `base`, `airlock`, `solar`, `greenhouse`, `rover`, `lander`, `curiosity`, `edge` (teleport key T cycles them) |
| Rocks | 45 solid rocks (0.5 to 2.2 m, convex hulls) and 2,500 pebbles in 3 MultiMeshes. None on items, pads or 2.5 m walkways. Rocks part buried by `rock.embed` |
| Sky states | `design` (day, sun 12 degrees, gold), `design.sunset` (4 degrees, blue halo, twilight, 60% lit windows), `design.night` (no sun, lamps on, 85% windows), `design.storm` (fog 2 to 120 m, cherry red, dim). Switched by key B. Blending between them at runtime is hackathon work |
| Lighting | One sun with shadows (near split sized from the sun), cool ambient colour, ACES, depth fog in the horizon colour, one reflection probe over the base (80 x 30 x 80 m), lamps in the night state |
| Weather rows | per sky state: wind 4 m/s (storm 6), streak share, dust devil (day only), storm front (storm only), panel stow (night, storm) |
| Wind | One gusting wind: direction 60 degrees (a design choice, no measured Gale direction), slow noise at 0.05 Hz. `world.gust()` feeds dust streaks, the wind sound, the telltale |
| Dust devil | A far column wandering 135 m round the base at 3 m/s, daytime only |
| Machines on their own | Solar panels turn to the sun at 1.5 degrees/s within 30 degrees and lie flat at night and in a storm; the dish nods 6 degrees every 18 s; status lights and the beacon blink at 0.67 Hz; the telltale leans by the Phoenix curve. All hold still within 6 m of the hero |
| Weight | Every item rests in the dust by its `sink` row (soft ground 3 cm, lander legs 6 cm), tilts to the ground, rocks part buried |
| Collision | Built from the drawn meshes, so what is drawn is what is hit; layers in CONTRACTS.md |

## 4. Materials and style

**Look:** variant A "Journey dusk" with photo-real surfaces (Ravindu's pick on 12 Nov). The cool teal accent is the only cool colour. Size is not a constraint (home server); texture memory on iPhone is.

DESIGN.md roles, one line each:
- `body`: hulls and panels (MetalPlates009 photo set). `trim`: dark rubber trim, gloves, soles. `accent`: the teal "on / usable / hero" colour. `metal`: bare metal (Metal011). `glass`: 50% opaque panes, can light up pane by pane. `rock`: grey stone under the dust (cliff_side set). `dust`: the red coat on flat ground (moon_02 fine powder).
- `hazard`: warm yellow trim, never on the hero. `light`: glowing accent, emissive 2.5. `suit`: astronaut fabric (Fabric061). `plant`: lettuce green. `visor`: opaque gold EVA sun visor (so no face ever shows).
- Sky tokens `sky`, `horizon`, `ground`, `shade` feed the light rig only. HUD tokens `primary` (amber), `danger`, `surface*`, `on-*`.

| Thing | State |
|---|---|
| Photo sets | 8 sets in `textures/` (README lists sources). Imports with mipmaps and GPU compression (fixed 12 Nov) |
| Themes | `DESIGN.sunset.md`, `DESIGN.night.md`, `DESIGN.storm.md`: same roles and geometry, colours and light only. Each has a token file (`design.*.json`) |
| Quality presets | `low` (no MSAA, 0.75 scale, 1 shadow split 25 m, no glow, no detail), `medium` (MSAA 2, 2048 shadows, glow 0.4, code detail), `high` (MSAA 4, 4096 shadows, glow 0.5, photo textures). A phone starts on `low`; key G cycles |
| Shaders | `world/terrain.gdshader` (dust, ripples, gravel, rock by slope, 1 m macro normal, trail map for prints, 12 moving contact discs, contact AO); `world/dust.gdshader` (lit grit and haze quads); `player/hero.gdshader` (the hero's own role copies, boot dust, whole-body fade near the lens); `ui/visor.gdshader` (helmet edge, no TIME, no flicker); factory shaders `addons/forge/sky.gdshader` (gradient, sun disc, halo, twilight) and `surface.gdshader` (role detail, lit panes) |
| Budgets | Geometry budgets per class in DESIGN.md. Hero is 6,667 triangles (DESIGN.md prose still says 10.6k: stale) |

## 5. Effects

| Effect | How | State |
|---|---|---|
| Footstep dust | Grit in short ballistic arcs under Mars g (launched 30 to 60 degrees), plus a faint ankle-high haze drifting downwind for 2.5 s. Spawned at the clip's touchdown frame with the foot's velocity | done, being retuned today |
| Wheel dust | Steady stream: 48 grains and 20 haze quads, thrown back and low | done, WIP |
| Haze / streaks | Pale horizontal wind streaks around the camera, more in a gust | done |
| Dust devil | Far wandering column, day only | done, visible at 135 m |
| Storm front | Big slow dust clouds close around the camera, storm sky only | done |
| Footprints and tracks | Pressed into the dust by the trail map (64 m square following the camera, 3 cm per pixel); prints darken 4% | done |
| Contact shadows | Soft AO under feet, items, rocks and moving wheels, plus a faint dust rim (normal tilt) | done |
| Lit windows | Glass panes on or off by themselves, changing every 90 s, at sunset and night | done, approved 13 Nov |
| Blinking lights | `cap` and `beacon` nodes at 0.67 Hz, 25% duty (under the 3 flashes a second limit) | done |
| Cargo set-down grit | A small puff when a bag is put down | done |
| Sand glints (Journey style) | none | missing |
| Sun rays through clouds, rain-like effects | none (and not needed) | not planned |

## 6. Physics and feel

**Reality rows (46, all in `data/reality.json`, each with a real range and source; many are marked estimate):**

| Group | Ids |
|---|---|
| World | `world.gravity` 3.73 m/s2 |
| Movement | `hero.speed.walk` 1.0, `hero.speed.hurry` 1.6, `hero.stop` 1.5 m, `hero.jump.hop` 0.18 m, `hero.jump.time` 0.63 s, `hero.slope.max` 25 degrees, `hero.step` 0.3 m, `hero.cadence.walk/hurry`, `hero.stride.walk`, `hero.knee.swing`, `hero.stance.width`, `hero.froude.walk_run`, `hero.lean.max`, `hero.contact.height` |
| Hero body | `hero.height` 1.89, `hero.width` 0.95, `hero.leg`, `hero.reach.work` 1.1 |
| Doorways | `hatch.height` 2.2 and `hatch.width` 1.2 m (bigger than the real 1.83 x 1.02 on purpose, written down in `why`) |
| Sizes | `habitat.diameter/height`, `rover.length/height/wheel`, `curiosity.length/width/height/wheel`, `crate.length`, `dish.diameter`, `solar.wing.height`, `lettuce.width` |
| Sinking | `hero.sink` 1 cm, `ground.sink.soft` 3 cm, `ground.sink.foot` 6 cm, `rock.embed` 30% |
| Rover | `rover.speed.max` 2.8 m/s, `rover.accel` 0.6, `rover.brake` 1.2, `rover.turn` 20 deg/s, `rover.climb` 0.5 m, `rover.cabin.volume` 10.7 m3, `rover.cabin.height` 1.65 m |

Gaps in the sheet: `pairs` is empty (no chaser or hazard exists before 14 Nov, so that is correct for now); rover.accel, brake, turn, hero.slope.max, hero.leg and others are labelled estimates with no NASA number found.

**Collision layers** (CONTRACTS.md): 1 ground, 2 statics, 3 thin statics (masts, poles; the camera ignores them), 4 hero, 5 vehicles, 6 interaction areas, 7 carriables, plus bit 256 on rocks a wheel can roll onto. The rover is an `AnimatableBody3D`, not a `VehicleBody3D` (not proven under Jolt in the web build).

**Controller** (`player/player.gd`, a `CharacterBody3D` under Jolt): walk and hurry from the sheet's Froude number, gait switch with hysteresis, hop with anticipation and coyote/jump buffer, 0.3 m step, slope limit, collider radius from `hero.width`, inside-the-torso check, footsteps on clip contact frames, bag carry, driving, `act()` reach clip, `attention` target for the helmet.

**Hero life layers** (`player/hero_life.gd`): chest and shoulders rise on the breath you hear; lean into acceleration with a damped overshoot at a stop; waist and head look at the target or camera aim; arms swing out around a carried bag.

**Camera** (`player/follow_cam.gd`): critically damped spring pivot, lead on the lens, lower-third framing by an off-axis frustum, sphere spring arm that ignores thin things, a wall behind lifts the view before the hero fades, slope pitch from a ray 3 m ahead, auto-yaw from real travel, vehicle distance 9 m. Mouse look, touch look and stick look.

**Touch** (`player/touch.gd`): virtual stick, Hurry/Hop/Use buttons (96 px targets), look drag by finger index. Plain styling from `design.json`.

## 7. Sound

All in `audio/`, built by `audio/make.sh` from `assets-cache` downloads (ffmpeg), mixed by `audio/audio.gd`, numbers in `data/tuning.json` `audio`. A web build plays in Sample mode where bus effects do not run, so each sound has a clear copy (Habitat bus) and a muffled `_out` copy (Outside bus) and going in or out is a bus crossfade over 1 s. Buses: `Suit`, `Outside`, `Habitat`, `UI`. Audio unlocks on the first press. 3D sounds cut off at 8 m (NASA: Mars sound falters at 26 ft). Sources and licences: [ASSETS.md, Sound](ASSETS.md).

| Sound | Where it plays | Source |
|---|---|---|
| `suit_fan` | Always, on the Suit bus (quieter inside) | our own synthesis |
| `breath_in`, `breath_out` | Chest rhythm, 15 a minute at rest to 30 hard, rate follows speed | Freesound CC0 (Kodack) |
| `wind_out` | Outside loop, volume follows the shared gust | NASA Perseverance |
| `step_sand_*`, `step_rock_*`, `step_in_*` (l/r, 3 each) | Each foot at its clip contact; sand, rock (on layer 2 statics) or the habitat floor | Fantozzi, OpenGameArt |
| `hum` / `hum_out` | Habitat air handling inside; oxygen maker and water recycler outside | YCbCr generator loop |
| `door_open`, `hiss`, `door_close` | Airlock door (hiss before open, after close) | Freesound CC0 (NeoSpica, unfa), Kenney |
| `servo` | Solar panel tilt, and the base's own panels starting, within 8 m | our own synthesis + Kenney |
| `bag_lift`, `bag_drop` | Carry and put down | Fantozzi, rubberduck |
| `motor`, `wheels` | Rover loops, pitch follows speed (0.7 to 1.3) | our own synthesis; NASA Perseverance sol 16 |
| `chirp` | The suit acknowledges any interaction, no words | Kenney Interface Sounds |

Not present: alarm or warning tone, UI click sounds (for the HUD), radio squelch and suit blips, the music motif, rover body roll creak, strap creak on a carried bag, storm-specific wind and dust hiss, night ambience, any voice (narration is opt-in and decided at the event). Weak spots: the 900 Hz outside cutoff and the boot thud are guesses by ear, not sourced; the suit fan is synthesised because no real EVA recording was free to use. Note: ASSETS.md says 43 files, 41 are on disk.

## 8. Interactions and HUD

**Sandbox interactions** (`sandbox/interactions.gd`, `sandbox/rover.gd`). Each does one physical thing and changes no game state; the target is the nearest interactable within 1.6 m inside a 70 degree cone.

| Interaction | What happens | Sound |
|---|---|---|
| Airlock door (habitat, greenhouse, shelter doorways) | Door leaf swings 100 degrees in 0.6 s | hiss, door |
| Solar panel | Cycles through tilts of -30, -45, -60, -15 degrees; the tracker waits 20 s before re-aiming | servo |
| Cargo bag | Lift to the chest, carry, put down with a settle in the dust | lift, drop |
| Rover | Walk to the rear hatch, press E: seated, drive (2.8 m/s, pivots on the spot, climbs 0.5 m rocks, brakes before taller ones, tracks, dust, moving shadow), E to get out | motor, wheels |

Debug keys: **B** sky state, **T** teleport to the next landmark, **G** quality preset. An fps/quality/sky label sits top right. `render_game_to_text()` reports `player`, `cam`, `heroScreen`, `interaction`, `carry`, `vehicle`, `sky`, `quality`, `fps`, `view`, `audio`. Capture views: `default`, `base`, `hero`, `horizon`, `storm`, `airlock`, `rover`, `greenhouse`. All input is keys, gamepad or touch through the same actions.

**HUD kit** (`ui/`, the helmet visor display, colours only from `design.json` through `ui/theme.tres`):
- Components (`ui/components/*.tscn`, 15): meter (three meters, shape changes when low, not just colour), sol clock, event card (two choices each with a cost tag), fact card (source line), data badge (LIVE or ARCHIVED + date, icon and word), Ask Earth countdown (static), alert toast (slow pulse), mission-lost frame, replay chain, mission log, credits screen, visor overlay, status panel, touch stick, touch button.
- `ui/hud_gallery.tscn`: six pages (hud, comms, event, lost, log, credits), laptop and phone layouts (phone draws 1.4 times larger), mock values. Keys L (layout) and 1 to 6 (page).
- Icons (23 SVG, one stroke style): alert, archive, battery, clock, dish, earth, food, greenhouse, health, heater, hop, live, next, oxygen, pip, power, radiation, science, shelter, storm, sun, use, water.
- Fonts: Lexend (reading, OFL) and Exo 2 (headings, numbers, OFL). Licence texts saved beside them.
- Phone sizes follow a researched floor (`design/research/sizes.md`).

## 9. Tests and tools

Run from the project folder with `godot --headless --path . -s tests/<file>.gd` (do not run today: CPU is busy).

| Suite | What it proves |
|---|---|
| `tests/run.gd` | Ground collision equals `height_at()` to 6 cm over 200 random points; every `world.json` item is placed; `render_game_to_text()` holds no game-state key (rule 1) |
| `tests/world_test.gd` | Collision on every solid, everything rests on the ground by its sink row, machines move on their own, telltale leans, blink under 3 Hz, rocks off pads and paths, all four sky states switch with no errors and no leftovers (one rig, one probe, right lamps), dust step lifetimes |
| `tests/player_test.gd` | The drawn body against a pillar from 8 headings, no sinking, footsteps on contact frames, camera in a corner, step up, look turns, carry hands never inside the bag, fade near the lens, restyle, vehicle enter/exit, two thumbs at once on touch |
| `tests/interact_test.gd` | Each interaction does its one physical thing, rover over a rock |
| `tests/doors_test.gd` | The real hero walks into and out of the habitat, greenhouse and shelter through their doors |
| `tests/sweep_test.gd` | Walk into every static item from 8 headings: never inside a solid, never under the floor, no snag on open ground, with a self-check that a disabled collision is caught |
| `tests/audio_test.gd` | Buses, crossfade, breath, steps, one-shots react to the game |
| `tests/ui_test.gd` | Every gallery page, both layouts: touch targets at least 48 dp, text contrast, words per line, alert pulse rate, no colour literals in UI code |
| `tests/contact_fx.gd`, `tests/rover_views.gd` (+ `.tscn`) | Capture fixtures for dust and rover camera views, not pass/fail |

Tools: factory `../../tools/` (`capture-view`, `feel-probe`, `web-check`, `serve-web`, `style-check`, `design-tokens`, `kit-roles`, `coplanar-check`, `html-to-png`). Project: `tools/terrain.py` (HiRISE and MOLA to `data/terrain*`). Last recorded results (session.md, own runs): 8 suites 0 failed, feel-probe 0 failed, rover/dust runs in progress.

## 10. Downloaded but unused (`assets-cache/`)

| Pack | Size | Notes |
|---|---|---|
| `kenney/space-kit` | in 147 MB for all Kenney | 153 GLB (domes, corridors, generators, dishes, rockets). Unused: we forged instead. Candidate for the rocket/ship and the cinematic |
| `kenney/space-station-kit`, `car-kit`, `city-kit-*`, `mini-characters`, `blocky-characters` | | Not used. City and car kits belong to the old rehearsal |
| `quaternius/space-kit` | 65 MB for all Quaternius | 87 models incl. 3 astronauts, solar panels, geodesic dome, rovers, antenna, crates, spaceships, planets. Only licence proof used. Good source for a crewmate and the antenna mast |
| `quaternius/modular-men` Astronaut | | The first hero candidate; replaced by the NASA model |
| `nasa-3d` | 31 MB | Used: Astronaut (hero), Curiosity. Unused: `habitat-demo-unit-1/2`, `base-station` (re-saved in `fixed/`), `perseverance`, `ingenuity` (do not place at Gale), `earth.jpg`, `mars.jpg`, `moon.jpg` (cinematic), `curiosity-landing-site.stl` |
| `sounds/nasa-perseverance` | 51 MB for all sounds | Used: wind, sol 16 driving. Unused: SuperCam laser shots, Ingenuity flight, SCAM mic clip |
| other `sounds/` | | Unused: respirator loop (craigsmith), gas leak, steam hisses, snow footsteps, other rubberduck hits, Kenney sci-fi and interface sounds beyond three |
| `textures/Rock030`, `rocky_gravel`, `polyhaven/` six photos | | Rock030 and rocky_gravel unused; the six photos belong to the old city game |
| `terrain/` `.npy` and `.bin` | | Source heights for `tools/terrain.py` (used) |
| `fonts/exo-2` | | Used |
| `data-snapshots/` | | NOAA and Curiosity weather, not used by the sandbox (live data is a 14 Nov job) |

## 11. What is missing or weak

Compared against `design/BRIEF.md` (assets and section 8 done criteria), `roadmap.md` open boxes, `session.md` open items and `alive.md` section 10. "Owner" is the lane that fixes it. "Before 14 Nov" = assets and sandbox only.

### 11a. Doable before 14 Nov (assets, sandbox, tooling)

| # | Gap | Source of the gap | Owner | Cost guess |
|---|---|---|---|---|
| 1 | Web build on Ravindu's iPhone never run (S3 box); `low` preset not judged on a phone; fps, snags, texture memory unmeasured | roadmap S3, BRIEF 8 | player, world | 1 h plus play |
| 2 | Web-only engine error `rp_child is null` (reflection probe?); `web-check.mjs` says "engine never started" after the first error (tool bug); data 47 MB | session.md | world, factory tools | 1 to 2 h |
| 3 | Draw calls 195 at `base` against budget 150; budgets set for three.js need a team re-decision | lane-E, workspace AGENTS | world | decision plus 1 h |
| 4 | ~~Sky diff~~ approved by Ravindu, 13 Nov 2026 | session.md | world | done |
| 5 | Mix review: outside cutoff 900 Hz and boot thud are guesses; telltale barely moves (exaggerate? needs his yes) | session.md | audio, world | 30 min |
| 6 | "Texture leaked" error after a sky switch fails capture-view runs that switch sky; `new-project.mjs --sync` deletes `sky.gdshader.uid` | session.md | world, factory | 1 h |
| 7 | S4 gate undone: static/gait sweeps, films of every gait and the hop, seven captures at full size, `style-check`, `check_godot_project.py`, `web-check`; plus gate boxes for S1, S2, S3 (checks pass, `/code-review medium`, lessons) | roadmap | all | 3 to 4 h |
| 8 | No crewmate. Cheapest: the hero in a second teal/number accent (crew size 2 or 4 is an open team decision, so build a recolour that works for either) | BRIEF P1 | models | 1 h |
| 9 | PIP is a prop: no wobble, eye blink, status bar light or wheel turn. A physical idle (lights and a small wobble) fits before 14 Nov; its behaviour does not | BRIEF P2 | models, world | 1.5 h |
| 10 | HUD kit not in the sandbox: no visor overlay over the 3D view, touch buttons use a plain theme not the kit's `touch_stick`/`touch_button`, interaction prompt is a plain Label. Phone check of the gallery not done | BRIEF 5, 7 | ui, player | 2 h |
| 11 | No alarm or warning tone, no UI click sounds, no radio squelch or periodic suit chirps (alive.md #12), no music motif (alive.md #13, "does the team want a motif" is open) | alive.md | audio | 1 h (no music), 3 h with | 
| 12 | Rover: no body roll in turns or settle after a stop, no creak, no clunk polish (alive.md #11); being reworked today | alive.md, session.md | world, audio | 1.5 h after the lane merges |
| 13 | Camera hints toward a dust devil or the base at dusk (alive.md #14) and the optional idle drift (#15) | alive.md | player | 1 h each, optional |
| 14 | Missing world pieces from BRIEF section 7: layered mudstone outcrop, dark basalt dune ripples as shape (only a ripple normal map today), cables, crates beyond bags, antenna mast, sand glints | BRIEF P2 | models, world | 3 h |
| 15 | A heater (icon exists, no model); `science.svg`, `radiation.svg`, `storm.svg` icons have no matching prop | ui/icons | models | 1 h, optional |
| 16 | Cinematic pieces (Earth, Mars, cruise ship) are textures only; no ship model (Kenney or Quaternius spaceship candidates unused) | BRIEF P3 | models | 2 h |
| 17 | Solar panels and the dish have no collision; camera indoors "not checked"; no pick-up or push of other carriables beyond bags | roadmap S3, ASSETS | world, player | 1 h |
| 18 | Hero clip set is thin: no turn in place, stop, hard landing, crouch to pick up, enter/exit rover motion (hero pops to the seat) | clips.json | models, player | 2 to 3 h |
| 19 | Greenhouse lettuce stages show but nothing in the sandbox lets you plant or watch them (growth is a game rule); only a static stage layout exists | world.json plants | world | none now |
| 20 | Docs drift: ASSETS.md has no rows for `terrain_backdrop.glb`, textures, fonts, icons or terrain data, says greenhouse panes are opaque (they are 50% now), count of 43 sounds (41 on disk); DESIGN.md prose says hero 10.6k triangles (6,667); `assets-cache/CREDITS.md` completeness unchecked; CONTRACTS.md says yaw from north but the rig's sun azimuth turns from +Z | session.md, BRIEF 8 | all | 1 h |
| 21 | Ask the Colombo Local Lead to confirm the verbal asset permission in writing and save it in `research/junior-astronaut/` (workspace rule 1) | workspace AGENTS | Ravindu | one message |
| 22 | Suit breathing "is synthesised" per session.md although a Freesound recording is now used; clear the note | session.md | audio | 5 min |

### 11b. From 14 Nov (game rules and story; not allowed before the event)

| # | Gap | Notes |
|---|---|---|
| 1 | `sim/` rules: Power, Life support, Crew health meters, resources, 30-sol clock | everything in `ui/components` is a mock |
| 2 | Events, choices with costs, replay of the 3 choices that caused a loss, win and lose logic, mission-lost flow | PG: crew always safe |
| 3 | Story, script and intro (Earth to Mars cinematic uses the assets listed above) | |
| 4 | Real data in game: NOAA live space weather with LIVE or ARCHIVED labels, factchecked fact cards, "Ask Earth" delay as a real countdown (3 to 22 min) | rule 3 and 4 |
| 5 | Dust on solar panels cutting power, storm effects on panels and visibility, radiation shelter use, greenhouse growth over about 33 days | machines already move; their effect on meters is a rule |
| 6 | PIP behaviour (helper AI), crewmate behaviour, crew size decision (2 or 4), ending vehicle (resupply or ride home) | open team decisions |
| 7 | Build menu for the pads, sol-to-sol sky blending (day to sunset to night), storm events | blending between sky states is hackathon code |
| 8 | Credits page with the AI-use paragraph, final audio decision on narration (opt-in) and music | submission needs |
| 9 | Re-check the 2026 judging guide (lands 13 Nov), submission page, 30 s video | |
