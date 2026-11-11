# AGENTS.md: Outpost Gale (Junior Astronaut Mission Trainer)

`CLAUDE.md` is a symlink to this file. Three files apply here, and each adds to the ones above it:
1. the workspace `AGENTS.md`, two folders above `tooling/`: hard rules, verified facts, team, dates;
2. `tooling/AGENTS.md`: the factory workflow, design language, code rules and tools;
3. this file: what only this game needs.

## What it is
A third-person Godot 4.7 web game for kids aged 7 to 12, for NASA Space Apps 2026 (Colombo, 14 and 15 Nov 2026). You are the commander of a small base in Gale crater on Mars for 30 sols. Three meters (Power, Life support, Crew health), and every choice costs something. Working title: **Outpost Gale**. The full proposal is in `plan.md`, "The game", at the workspace root. The Docmost page "Game design and story" holds the team's decisions. Where they differ, Docmost wins.

## Phase now: look, assets and sandbox (12 and 13 Nov)
The organisers allowed the art direction and every asset to be prepared before the event: models, the world, the map and the HUD look. We also build a **sandbox**: the assets in a small world where a third-person astronaut walks, drives and interacts, so the physics and control problems are solved at home. **The story, the `sim/` rules (meters, resources), events, the sol clock, game flow and win or lose wait until 14 Nov.** In the sandbox an interaction does one physical thing and changes no game state. The brief for this phase is `design/BRIEF.md`.

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
Its own repo. Commits signed off (`git commit -s`), prefixed by area, ending with the workspace's `Co-Authored-By` trailer (AI use must be disclosed). Remote `origin`: `git@100.108.184.127:ravindu644/junior-astronaut-mission-trainer.git` (Gitea), branch `main`. **Push after every commit** (Ravindu, 12 Nov 2026).

## Gotchas
(Add one line per thing that took more than two tries, with its why.)
