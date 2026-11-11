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
1. Merge H if its renders and films pass the suited-locomotion checks; else the fallback in `design/research/suit.md`.
2. Lane A (player): switch to the new rig and clip names (`idle`, `walk`, `lope`, `hop_*`...), footsteps from
   `data/clips.json` contact times (prints appeared 0.2 s early), `SYNC_MODE_CYCLIC_MUTABLE` on the gait blend,
   gait bands from `hero.froude.walk_run` 0.36, carry and drive poses. Until then world_test fails on the
   missing `Idle` clip (the old player code against H's new model).
3. Lane B: doorways to the new rows `hatch.height` 2.2 and `hatch.width` 1.2 (habitat airlock, shelter, greenhouse):
   the hero could not enter. Find the black flickering line on the open habitat door (Ravindu's screenshot).
4. Agent F: a test that walks the hero through every door into every enterable building.
5. Then S3's phone step: web build on Ravindu's iPhone (`serve-web.mjs`), low preset, five minutes.
6. Lessons for the factory: doors sized from the hero's collider, not the real hatch; a test walks through every
   door; the variant lesson and the research skills are already in.

## Machine rules
- CPU: agent jobs on cores 2-7 (0-1 for the desktop), at most two lanes, `nice` + `taskset`, `LP_NUM_THREADS`.
- After a merge that changes play, restart Ravindu's open game window. Push after every commit.
