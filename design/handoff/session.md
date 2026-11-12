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

## Night of 12 Nov (Ravindu asleep, remote): merged and pushed
- b4df8b4 lane B: doorways 2.2 x 1.2 m, door leaf on the room side (black line gone), weight: items rest in the dust by
  sink rows (Viking/Curiosity sources), tilt to the ground, rocks part buried, height_at on the drawn triangle.
- e5bb149 lane A + sound lane: suited hero live (clips, contact-frame footsteps, collider from hero.width), damped
  camera with a lead, audio/ sound bed (web build: no bus effects, muffle baked into *_out.ogg; buses fade).
- Factory: skills living-atmosphere (new), third-person-camera rule 14 additions. Research: design/research/alive.md.
- Open from the web-check: game data 47 MB (Ravindu: size no constraint), engine error "rp_child is null" (probably the
  reflection probe in the web build), web-check.mjs reports "engine never started" after the first error (tool bug).

## Next, in order
1. Running now: lane A pass 2 (breathing chest on audio.breath_phase, head look-at, lean and settle, lower-third
   framing + slope pitch, player.act(), hero.sink row, tests/doors_test.gd); lane B pass 2 (world.gust() shared,
   dust streaks, wind gauge mast, panels track the sun, dish nods, blinking lights, lit windows, contact darkening,
   blue sunset halo + long twilight as a DESIGN.sunset.md diff in design/handoff/sky-diff.md for Ravindu to approve).
2. Ravindu: approve the sky diff; listen to the sound mix (outside cutoff 900 Hz and boot thud are guesses); look at
   carry and drive poses. Suit breathing is synthesised: a real recording (adult, helmet or bucket) would be better.
3. S3 phone step: web build on the iPhone (`serve-web.mjs`), low preset; fix rp_child.
4. Gates: S1-S3 `/code-review medium` and lessons boxes.

## Machine rules
- CPU: agent jobs on cores 2-7 (0-1 for the desktop), at most two lanes, `nice` + `taskset`, `LP_NUM_THREADS`.
- After a merge that changes play, restart Ravindu's open game window. Push after every commit.
