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

## RESUME HERE (13 Nov 2026, about 07:15; power cut 08:30 to 17:30 at Ravindu's)
**What is left, in one list: `design/handoff/whats-left.md`.**
Everything is committed and pushed: game `wip/polish-stripes` (and `main` if the merge line below says so), factory
`godot` d8153ec. Builds of 737e67a (Windows, Linux, web zip) are in `~/outpost-gale-builds` (served on :8000).
- **Merged tonight** (lanes C, F, G, H, I, J, K, L, M, plus audio D and hero clips A from `design/plans/next-lanes.md`):
  sky clock (20 min sol, continuous sun, lamps and work lights by sun elevation, per-panel dust shed by a tilt),
  new layout (reactor, lander, old arrays gone), cables end in gland boxes on every device, rover charging post,
  pads graded level (Ravindu approved) and drivable, PIP tracks soft, rover lights at night with crew aboard,
  Mont Mercou foot tapered, toilet sign, greenhouse rack feet and grow-light feeds, storm shelter interior,
  13 hero use clips with `player.perform()`/`sit()`, one SOUNDS table, dawn/sleep/storm cues, bed phrases,
  loading shell and splash (new layout), Gaming preset 4 shadow splits (Ravindu approved).
- **Gate (13 Nov ~07:00):** every suite 0 failed (day_test needs `--fixed-fps 60`, as its header says; the gate first
  ran it without and got 10 false failures); style-check 4 DESIGN files + 34 models OK; check_godot_project 0 errors.
  Sweep: see the merge commit. Not run tonight: web-check, feel-probe on the full sheet, `/code-review medium`.
- **Ravindu decided (13 Nov ~07:00):** Mount Sharp stays as the real sun lights it (front-lit at noon, pale); toilet
  is the curtain only, nothing simulated; sleep follows real practice: cards "Night" and "Nap 20 min", a night ends at
  a fixed 06:30 wake indoors (factcheck rows 187 to 208, next-lanes.md section 3).
- **Open, for Ravindu:**
  1. A `paver` role for the pads (rock colour with the dust or gravel photo): the cliff photo reads wrong lying flat.
  2. Listen: curtain, rover hatch, dawn/sleep/storm cues, pour/sip/crinkle/leaf (synthesised, never heard).
  3. Ground speckle at low sun: lane F ruled out normals and shadows; next is SPECULAR 0 on the ground photos.
  4. Dust devil first whirl: a 169 ms compile left on a cold cache (the 98 ms preprocess is fixed).
  5. Draw calls inside the shelter up to 212 (looking west through the wall at the base).
- **Next lanes** (`design/plans/next-lanes.md`, after Ravindu's playtest): B props and use spots (uses rows in
  world.json, turn/take/appear/glow verbs, split moving parts), C cine and sleep (sleep picker, drone time-lapse,
  wake indoors), then a gate. Hero clips and audio for them are already in.
- **Since 07:00 (all on main or wip, see git log):** sleep picker card (ui gallery, not wired), first use spot (drink at
  HAB 1's galley), code-review fixes (sunset cue only at dusk, storm cue once, perform/sit lock, charger guard), greenhouse
  and shelter sites graded (ground came through their floors), `paver` pads (approved), shadow splits blended (a step in
  straight shadow edges ~6 m ahead of the hero with 4 splits), Settings High = 4 splits, boot/fullscreen lane Q (see its
  commit if it landed: boot scene with threaded load, preset switch behind the cover, silence until the cover lifts,
  full screen by default, landscape on phones).
- **Open, shadows (top for the next session):** (a) a step in straight shadow edges about 6 m ahead of the camera, by
  the hero: the first of the Gaming preset's 4 splits ends there (house_style `_fit_split`: split_1 = fit * 0.4); shots
  `design/handoff/shots/shadow_step_*.png`. Splits now blend (`blend_splits_wrong.png` looked wrong only because the
  panels had tilted); confirm the step is gone, else push split_1 out past the hero.
  (b) tall thin spikes from straight-edged objects' shadows (`shadow_spike.png`). Diagnosis (13 Nov 07:58, reasoned, not
  yet proven by a capture): a low sun. A shadow texel stretches by 1/sin(elevation) on level ground (6x at 10 deg, 11x at
  5 deg), `_fit_split` grows the near split as the sun drops (1.8/tan(el)), and normal bias scales with the texel, so
  edges near the sun's direction stair-step and corners throw one-texel slivers. It began with the sky clock (the sun
  was fixed at 40 deg). Fix to try first: the shadow-casting light never goes below about 15 deg (clamp `to.y` in
  `set_look()`; the sky disc stays real), or fade `shadow_opacity` below about 8 deg; also cap `fit` near 0.35 and scale
  normal bias down at low sun. Prove with greenhouse captures at 8.4 h and 12 h, before and after.
  (c) `hero_lit_in_shadow.png` is not a bug: proven the hero receives shadows; with a low sun the wing shadow is a thin
  layer near the ground, so legs are shadowed and the chest is in sun.
- **Bucket list (each several hours):** the rest of props and use spots (pouch, cut camera, eat/plant/harvest/sample/
  valve/radio/dish/repair/brush rows, split moving parts, turn/take/appear/glow verbs); sleep cine (drone time-lapse,
  wake indoors at 06:30, wire the picker); ground speckle at low sun (SPECULAR 0 ruled out: albedo or shade() next);
  dust devil cold compile (169 ms); shelter draw calls (212 looking through a wall); A16 profiling; APK; jumping and
  climbing (contextual-traversal) if a mission needs high ground.
- Source SDK 2013 files in `design/research/pages/interaction/` are left uncommitted on purpose (third-party licence).

## Earlier resume point (12 Nov 2026, about 22:00, stopped for an SSD swap to the i5 laptop: this one throttled again)
Check `lscpu` first (memory laptop-cpu-budget): on the i5-1135G7 agents may use all 8 threads under nice, up to 3 lanes.
- `main` (game, d91b720) and `godot` (factory) are pushed and fully checked: base for 2 crew, more life, night grit,
  probe redraw, map boundary + safety net, presets, stripes. Factory since then: probe redraw in warm(), tests fail on
  any script or shader error (test.gd Logger), first-person rules in skills/third-person-camera.
- On branch `wip/polish-stripes` after d91b720, in the WIP commit "wip: first person indoors ...":
  1. Lane A, DONE and tested (indoor_test etc. 0 failed): first person inside HAB 1 and the greenhouse (rooms in
     data/world.json, doorway hysteresis, 0.4 s ease, body hidden, 0.2 s reveal when the lens is clear). Ravindu
     liked it ("much better").
  2. Lane B, STOPPED MID-WORK (untested): accurate interior. Brief items: real floor (sand showed through), window
     frames on the curve, berths after ISS crew quarters with pillow/sleeping bag/reading light, CWC water bags as a
     tidy padded wall, toilet cubicle with a sign and the UWMS seat visible, fabric (`suit` role) for soft goods and a
     painted panel for cabinets (a new role needs Ravindu's OK), remove the 2 spare suits (keep a donning corner),
     an interior reflection probe (visors reflected the outdoor base), greenhouse racks on the floor with lights on
     them and an aisle of at least 1.3 m, eye-height views hab_eye_n/e/s/w and gh_eye_a/b.
  3. Lane C, STOPPED MID-WORK (untested): the pale seam at the map edge, solar wings tracking the sun (single axis,
     clean swept panels, tidy rows, cables), Mont Mercou bedded with a skirt, the "screen tear" near the wings
     (likely coplanar faces or shadow shimmer), audio.gd reading player.room.
  Resume: `git diff d91b720..wip/polish-stripes`, then run every test (a parse error now fails a test), then restart
  lanes B and C with their briefs (this list) on the new machine. Merge to main only when all checks pass.
- Docmost: update the power page to 2 crew (Ravindu: keep it in the roadmap, don't change it yet).
- Known: draw calls base 185 (budget 150; the A16 decides); greenhouse aisle was 0.96 m for a 0.95 m hero.

## Earlier resume note (12 Nov 2026, about 15:40, stopped for a reboot: the laptop throttled)
Ravindu is moving this NVMe to his i5 11th gen laptop (NVIDIA MX330, never throttles). Check CPU core count there
and update the CPU rule (memory laptop-cpu-budget) before starting lanes.
- `main` (game) and `godot` (factory) are clean, pushed, and pass every check (last full run before e0e2ebf).
- In-progress, UNREVIEWED and UNTESTED, saved on branches: game `wip/polish-stripes`, factory `wip/device-presets`.
  Two lanes were stopped mid-work:
  1. Polish lane: five device presets (Phone, Older laptop, Laptop, Gaming PC, Max) with device icons
     (ui/icons/device_*.svg), a simple settings screen (preset cards, Show FPS, sound sliders, an Advanced fold with
     AA, resolution, shadows, effects, V-Sync, frame cap), the missing Save/Apply button bug, the cursor disappearing
     bug (tests/cursor_test.gd), rover accel 1.0 (top of its range) and speed felt (camera lower/closer, look ahead,
     motor pitch, dust and tracks with speed).
  2. Suit stripes: a new `stripe` role in dark orange (about #c2501a to #d2621e) for the suit's bands only; accent
     stays teal for HUD/usable; hero GLB re-export needed (forge/hero_astronaut.py). May not have started editing.
  Resume: `git diff main..wip/polish-stripes` to see what landed, then either finish on that branch with a fresh
  lane (brief from this list) or redo from main. Merge only after all tests/*.gd, feel-probe, style-check pass.
- Decisions today: sky look approved; Milky Way map kept (CC BY-NC, non-commercial hackathon); music picks in
  assets-cache/music/README.md; rover: options 1+2 (no boost); suit stripes dark orange; 4-person crew later.
- A16 now 35-45 fps steady on the low preset (was 20 with stutters).

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
