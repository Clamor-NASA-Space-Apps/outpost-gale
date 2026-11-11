# Roadmap: look, assets and sandbox (12 and 13 Nov 2026)

Plan: `~/.claude/plans/iterative-singing-toast.md` (approved 12 Nov). Done criteria: `design/BRIEF.md` §8.
No story, no `sim/` rules, no meters, no sol clock, no win or lose before 14 Nov.

## Look (before the sections)
- [x] Reference board confirmed with Ravindu (`design/refs/README.md`)
- [x] Style study (`design/research/look.md`), sizes (`sizes.md`), assets (`assets.md`)
- [x] Three variants in the engine on real terrain; Ravindu picked A with realistic surfaces
- [x] `DESIGN.md` written, style-check passes, committed
- [x] Real Gale ground: HiRISE patch, 1 m normal map, MOLA skyline (`tools/terrain.py`, `world/terrain.gd`)
- [x] HUD icon set (`ui/icons/`)
- [x] `data/reality.json`: movement and size rows, plan-time probe passes

## S1: checks first, look locked (12 Nov morning)
- [x] `CONTRACTS.md`, `data/world.json`, `data/tuning.json`
- [x] `sandbox/sandbox.tscn` with stand-ins (capsule hero, labelled boxes) and the Forge hooks
- [x] `tests/run.gd`: ground collision equals `height_at()`, no game-state keys, every item placed
- [x] feel-probe fails on every measured row (4) and errors on none
- [x] PBR texture sets and scanned rocks downloaded, credited (`design/research/textures.md`)
- [x] Texture sets in the DESIGN.md roles and the terrain shader; look scene recaptured
- [x] Ravindu re-approves the look in the engine (12 Nov, asked for soft Sahara / The Martian dust: moon_02 dust, ripples, gravel patches, footprints and tracks)
- [ ] checks pass
- [ ] /code-review medium
- [ ] lessons

## S2: lanes in parallel (12 Nov day)
- [x] A `player/`: controller (walk 1.0, hurry 1.6, stop 1.5, hop 0.18, step 0.3), camera, touch, Quaternius clips
- [x] B `models/` structures: habitat with airlock door, solar array with tilting panels, machines, greenhouse + lettuce, shelter, dish, pad, lander
- [x] C `models/` vehicles and props: pressurised rover, Curiosity (no insignia), PIP, cargo bags, rocks, lamps, beacons
- [x] D `ui/`: theme from `design.json`, fonts, every BRIEF §5 component in `hud_gallery.tscn` at phone and laptop sizes
- [x] E `world/`: prefab loader with collision from meshes, sunset/night/storm states, rock scatter, dust effects, reflection probe
- [x] user playtest (desktop, five minutes)
- [ ] checks pass
- [ ] /code-review medium
- [ ] lessons

## S3: interactions and the phone (13 Nov)
- [x] Airlock door opens (walking in waits on the 2.2 m doorway); camera indoors not yet checked
- [x] Tilt a solar panel; pick up and put down a cargo bag
- [x] Get in, drive and get out of the rover; camera behind it
- [x] Dust under feet and wheels; debug sky, teleport, quality keys; fps counter
- [ ] First web build on Ravindu's iPhone (`serve-web.mjs`)
- [ ] user playtest (iPhone, five minutes)
- [ ] checks pass
- [ ] /code-review medium
- [ ] lessons

## S4: the gate (13 Nov evening)
- [ ] Sweeps: static, walk into every prop, never under the floor
- [ ] Films of every gait and the hop; captures default, base, hero, horizon, storm, airlock, rover at full size
- [ ] `style-check DESIGN.md models/*.glb`, `check_godot_project.py`, `web-check`
- [ ] `ASSETS.md` and `assets-cache/CREDITS.md` complete
- [ ] user playtest (iPhone, low preset, five minutes): style holds, frame rate fine, nothing snags
- [ ] checks pass
- [ ] /code-review medium
- [ ] lessons (including: one of the three variants must carry photo texture sets)
