# AGENTS.md: Outpost Gale (Junior Astronaut Mission Trainer)

`CLAUDE.md` holds one line, `@AGENTS.md`, which loads this file (a real file, not a symlink, so it works on Windows). Three files apply here, and each adds to the ones above it:
1. the workspace `AGENTS.md`, two folders above `tooling/`: hard rules, verified facts, team, dates;
2. `tooling/AGENTS.md`: the factory workflow, design language, code rules and tools;
3. this file: what only this game needs.

## What it is
A third-person Godot 4.7 web game for kids aged 7 to 12, for NASA Space Apps 2026 (Colombo, 14 and 15 Nov 2026). You are the commander of a small base in Gale crater on Mars for 30 sols. Three meters (Power, Life support, Crew health), and every choice costs something. Working title: **Outpost Gale**. The full proposal is in `plan.md`, "The game", at the workspace root. The Docmost page "Game design and story" holds the team's decisions. Where they differ, Docmost wins.

## Phase now: everything, story drafted (13 Nov)
The organisers allowed assets (12 Nov) and then the game itself (13 Nov) to be prepared at home. **Everything is built now: systems in `sim/`, meters, the sol clock, PIP's guiding, use spots, cinematics' machinery. The story is drafted now too (`design/story.md`, team-reviewed, fact-checked); at the event we wire it into the flow, playtest and submit** (workspace hard rule 1). A system that needs a story value takes it from `data/` (placeholder until the story fixes it), and a test proves it alone. The asset brief stays `design/BRIEF.md`; the day design is `design/typical-day.md`.

## Files
| Path | What |
|---|---|
| `design/BRIEF.md` | Art direction, asset list, done criteria for this phase |
| `design/refs/` | Ravindu's reference images (gitignored: third-party) and `README.md` with take and avoid notes |
| `design/variants/` | The three candidate styles |
| `design/research.md` | The style study, every claim with a status |
| `DESIGN.md` | The approved look. The only file with colour values (with any `DESIGN.<state>.md`) |
| `models/` | Every GLB the game uses, class-prefixed, passing style-check |
| `data/` | Terrain heights, `reality.json` (sizes, walking, hop, rover), `world.json` later |
| `sandbox/` | The walkable test world: every asset on the terrain, the controller, camera, interactions, debug keys |
| `player/` | Third-person controller and camera, free of Mars content |
| `ui/` | HUD theme, icons, fonts, the gallery scene |
| `forge/` | This game's Blender recipes |
| `ASSETS.md` | Manifest: every asset's file, source, licence, triangles, status |

## Rules for this game
- **Real in shape, stylised in surface.** Real Gale terrain, real sizes (sourced in `data/reality.json`), real colours (`research/godot-build/movement-and-look.md` at the workspace root).
- **The right rover in the right crater.** Curiosity is at Gale. Perseverance and Ingenuity are at Jezero, so they never appear at our base.
- **The astronaut is never red or orange.** It disappears against Mars. A cool accent marks the hero, "on", "usable" and the HUD.
- **Visors, never faces.** It's in the plan, and the workspace rule on minors makes it safe.
- **No NASA insignia** on any model or texture, including the ones inside NASA's own GLBs.
- **References never ship.** `design/` holds a `.gdignore`, and `design/refs/` holds a `.gitignore` that lets in only `README.md`.
- **Credits as you go.** Every downloaded asset goes into `ASSETS.md` and `assets-cache/CREDITS.md` with its licence, when it lands, not at the end. Quaternius packs: keep the zip's licence file and the saved pack page (see the licence trap in `research/godot-build/assets.md` §3).
- **Kid UX** (workspace rule): icons first, at most 8 words per card, touch targets of at least 48 px, colour never the only signal, no flashing faster than 3 times a second.
- **Downloads:** ask Ravindu before anything over a few MB, and download once, before 14 Nov. The venue network may be slow.

## Choke points (besides the factory's)
- `DESIGN.md` and `DESIGN.<state>.md`: every colour and light value.
- `ui/theme.tres`: built from `design.json`. Each HUD component takes its style from it.
- `data/terrain*`: one height source for the mesh, the collision and later the game's height queries.

## Git
Its own repo. Commits signed off (`git commit -s`), prefixed by area, ending with the workspace's `Co-Authored-By` trailer (AI use must be disclosed). Remotes: `origin` = GitHub `Clamor-NASA-Space-Apps/outpost-gale` (private), `gitea` = the old Gitea mirror; branch `main`. **Push after every commit, to both** (Ravindu, 12 Nov 2026).
- **Actions** (`.github/workflows/build.yml`) builds web, Linux and Windows on every push. The web build lands at `https://clamor-nasa-space-apps.github.io/<branch>/` (`main` is `sandbox`), and the desktop builds at the release `build-<branch>`. A web file over 95 MB fails the run (Pages is a git push, and git refuses files over 100 MB).
- **Teammates** work on their own branch, in their own folder (the intro and outro: `cine/intro/`, `cine/outro/`), and open a pull request into `main`. Each branch gets its own preview link.

## Gotchas
(Add one line per thing that took more than two tries, with its why.)
- `Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS` report the worst of the last second, not this frame
  (4.7.2): time a frame with `Time.get_ticks_usec()` hooks (tests/profile_run.gd), never with those monitors.
- "Texture with GL ID ... leaked" at exit after a run with the sandbox is known (engine-side, profile of 12 Nov);
  read the errors before it, not it.
- Natively the Godot and Mesa shader caches hide compile hitches after the first run: profile cold with
  `MESA_SHADER_CACHE_DISABLE=true` and the app's `user://shader_cache` moved away, or in the web build.
- Runs of exactly 1000 ms frames showed up twice in native profiles on 12 Nov, in different phases, with process,
  physics and render all under 2 ms on them: outside the game (the window or the desktop), so rerun before chasing them.
- Hero recipe: small separate pieces (a patch, lettering) joined into the suit before `ARMATURE_AUTO` made the heat
  solve fail (2,889 unweighted vertices, a crumpled sleeve in play): join them after skin() and make them rigid.
- `feel-probe --film` draws every row of the run under xvfb, and the sandbox timed out at 300 s: film one row with
  `--only <id> --film <id>`, and check pass/fail headless without `--film`.
- A script set on an item after it entered the tree (interactions.gd puts rover.gd on the rover's body) never gets
  `_ready`, so `_process` and `_physics_process` do not run until `setup()` turns them on (the rover's lights stayed dark).
- rover.gd and pip.gd find wheels with `find_children("wheel_*")`: never name a helper node `wheel_*` (a MultiMesh
  copy named so became a seventh wheel; world_test caught it).
- Anything made during play (a dust stream, a spawned prop) must take the render layer its family uses (ground and
  dust are layer 2, which the reflection probe does not shade): wheel grit made late on layer 1 glowed at night.
- `frames(1)` in a test waits one physics step, not a `_process`: after a heavy frame (a sky switch) several physics
  steps run first, so await `process_frame` twice before reading what `_process` sets (audio_test, 12 Nov).
- At `_ready` the physics space still holds bodies at the transforms they were added with (items at the origin):
  build anything that queries physics (PIP's route graph) on the first physics tick (pip_test, 13 Nov).
- The look runs on `world/sky_clock.gd`: the hour moves in tests, so a test that needs a sky jumps the clock
  (`game._sky(i)`, `clock.jump()`) and pins it if it must hold; tool runs pin it themselves. A jump re-aims the
  trackers, and their servo sounds keep the audio busy for a second: wait before testing a quiet moment (life_test).
