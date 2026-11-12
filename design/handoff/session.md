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

- Second pass, merged and pushed: 154b5f4 look (blue sunset halo, twilight, lit windows: WAITS FOR RAVINDU'S
  APPROVAL, `design/handoff/sky-diff.md`; revert that one commit to undo), 0e28435 alive pass (breathing chest on the
  sound's clock, look-at, lean and settle, lower-third framing, slope pitch, doors_test; shared gust, telltale mast,
  solar trackers, dish nod, status lights, contact shadow + dust rim, devil visible). Factory: halo/twilight tokens,
  `keep` kit role, clean quit with sound. All 8 suites 0 failed, feel-probe 0 failed (my own runs).

## 12 Nov afternoon (Ravindu napping, unsigned commits): running and queued
- Merged and pushed: a943762 (rover glass/cabin/rocks/shadows/stream, flicker fixes + coplanar-check, CLAMOR on
  models, dust coat everywhere incl. suit, player look/carry/fade fixes), INVENTORY.md, performance research +
  factory skills frame-budget, surface-weathering. Web build served by `node ../../tools/serve-web.mjs .`.
- Weakest device is Ravindu's Galaxy A16 (low preset ~20 fps on 12 Nov); teammates iPhone 16/17 at the event.
- Profile (tests/profile_run.gd, data in the scratchpad): GPU 14.3 ms on high maximized (4x MSAA 6.4 ms, terrain
  5.2), trail map 4 MB upload per print, first-use shader compiles (web 2-3 s per switch), contact map 12 ms per bag.
- RUNNING: perf lane (trail map on GPU, shader warm-up, contact map spot update, terrain diet, presets with a
  per-knob runtime API for a settings screen, physics steps 3); assets lane (PIP alive in sandbox/pip.gd, CLAMOR
  shoulder patch, Phobos + Deimos, stars + Milky Way + Earth in sky.gdshader from the Yale BSC / NASA SVS).
- NEXT WAVE: UI + audio lane: in-game graphics settings screen built from the perf lane's knob list (+ music/SFX
  volume), and music: picks in assets-cache/music/README.md "Picked by Ravindu" (ours for first step, airlock,
  discovery, mission lost; Kilua Boy Sunset Walk cut for sunset; Exploration Theme + Lifewave 2k for a title),
  a Music bus heard clear, rare triggers (first exit, sky to sunset, airlock sealed). Then: APK build (Android
  preset; SDK, JDK 17, debug keystore ready), EXE once Ravindu installs Windows templates.

## Next, in order (older list)
1. Ravindu: approve or reject the sky diff; listen to the mix (outside cutoff 900 Hz, boot thud are guesses);
   look at carry and drive poses; the telltale barely moves (real Phoenix curve): exaggerate it? (needs his yes).
2. Open: CONTRACTS.md says yaw from north but the rig's sun azimuth turns from +Z (pick one); "Texture leaked"
   error after a sky switch (fails capture-view runs that switch sky); `new-project.mjs --sync` deletes the
   project's `addons/forge/sky.gdshader.uid` (restore with git checkout); suit breathing is synthesised.
3. S3 phone step: web build on the iPhone (`serve-web.mjs`), low preset; "rp_child is null" in the web build;
   web-check.mjs says "engine never started" after the first error (tool bug).
4. Next soul items from design/research/alive.md: rover body roll and sound polish, radio squelch chirps, a rare
   music motif, a camera hint toward the devil or the base at dusk.
5. Gates: S1-S3 `/code-review medium` and lessons boxes.

## Machine rules
- CPU: agent jobs on cores 2-7 (0-1 for the desktop), at most two lanes, `nice` + `taskset`, `LP_NUM_THREADS`.
- After a merge that changes play, restart Ravindu's open game window. Push after every commit.
