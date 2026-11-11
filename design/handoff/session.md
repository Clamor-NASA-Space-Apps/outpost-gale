# Session handoff: resting after the 12 Nov night session

Read this first when the work resumes. Plan: `~/.claude/plans/iterative-singing-toast.md`. Checklist: `roadmap.md`.
Everything committed is pushed: game repo `main` on origin, factory `tooling/` branch `godot` on origin.

## Where things stand (12 Nov 2026, about 05:00)
- Merged: look (variant A + photo sets, soft Mars dust ground with prints and tracks), real Gale terrain and
  skyline, every model (lanes B and C), HUD kit (lane D), world loader, sky states, rocks, dust (lane E),
  player body, camera and touch (lane A), sandbox interactions (door, panels, bags, rover), sweeps (agent F).
- Tests: run.gd, world_test, interact_test, player_test, ui_test, sweep_test (0 failed at the last merge of each).
- Research skills written into the factory from Ravindu's playtest: `ground-contact-fx`, `shadows-and-grounding`,
  `suited-locomotion` (all pushed). Shadow fix in the rig is in (near split sized from the sun). Dust rebuilt from
  the research, lit like the ground and a third as thick (last playtest: "too thick, bright in shadow": fixed).
- Agent H (hero asset) was the last one running: NASA's Astronaut GLB rigged to the Quaternius UAL skeleton,
  logos painted out, roles (suit, trim, metal, visor (gold, opaque), accent teal band), suited clips (idle, walk,
  lope, hop_start/air/land, interact, carry_idle/walk, drive_sit) and `data/clips.json` with foot contact times.
  Its files: `models/character_astronaut.glb`, `forge/hero_*.py`, `data/clips.json`,
  `design/research/asset-previews/hero/`. See the note at the end for how it ended.

## Next, in order
1. Agent H finished and passed (renders and films in `design/research/asset-previews/hero/`): the NASA-suit hero is
   committed as `models/character_suited.glb` (6,667 tris, 65 UAL bones, clips idle, walk, lope, hop_start/air/land,
   interact, carry_idle/walk, drive_sit at 30 fps; foot contacts in `data/clips.json`). The old Quaternius hero stays
   as `character_astronaut.glb` so `main` stays green until the player switches. Notes from H: bones use UAL names
   (pelvis, spine_01..03, Head, thigh_*, calf_*, foot_*); loops must be set in code (`loop` in clips.json); hop_start
   ends at take-off (0.34 s, maybe start it partway for kids); carry bag centre (0, 1.10, 0.46) on spine_03; seat hip
   (0, 0.523, -0.233); some rough skin shading on the thighs and the backpack's lower box to smooth later.
2. Lane A (player): switch MODEL to `res://models/character_suited.glb` and the new rig and clip names (`idle`, `walk`, `lope`, `hop_*`...), footsteps from
   `data/clips.json` contact times (prints appeared 0.2 s early), `SYNC_MODE_CYCLIC_MUTABLE` on the gait blend,
   gait bands from `hero.froude.walk_run` 0.36, the hop from hop_start/air/land, carry and drive poses; then delete
   the old `character_astronaut.glb`.
3. Lane B: doorways to the new rows `hatch.height` 2.2 and `hatch.width` 1.2 (habitat airlock, shelter, greenhouse):
   the hero could not enter. Find the black flickering line on the open habitat door (Ravindu's screenshot).
4. Agent F: a test that walks the hero through every door into every enterable building.
5. Then S3's phone step: web build on Ravindu's iPhone (`serve-web.mjs`), low preset, five minutes.
6. Lessons for the factory: doors sized from the hero's collider, not the real hatch; a test walks through every
   door; the variant lesson and the research skills are already in.

## Machine rules
- CPU: agent jobs on cores 2-7 (0-1 for the desktop), at most two lanes, `nice` + `taskset`, `LP_NUM_THREADS`.
- After a merge that changes play, restart Ravindu's open game window. Push after every commit.
