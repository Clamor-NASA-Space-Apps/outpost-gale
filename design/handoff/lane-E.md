# Lane E (world) handoff, 12 Nov 2026, paused for the laptop restart

Nothing committed. All files are on disk as left. Scratch copy for testing (with the committed terrain.gd and
a stub `mark()`, because the working terrain.gd did not compile while it was being rewritten):
`/tmp/claude-1000/-home-ravindu644-Documents-NASA-Space-apps-tooling/d10120dd-6233-49a1-8d98-3cc7bd666f89/scratchpad/proj`
(a reboot may clear /tmp; it is only a copy). The sky-state capture script is `skies.mjs` in the same scratchpad.

## 1. Finished and verified (headless, in the scratch copy)
- **Sky states:** `DESIGN.sunset.md`, `DESIGN.night.md`, `DESIGN.storm.md` and `design.{sunset,night,storm}.json`.
  Made by a script from the current `DESIGN.md` (same materials, geometry, quality, kit; only `sky`, `horizon`,
  `ground`, `shade`, the `lighting` block, name, description and prose differ). Regenerated after DESIGN.md got
  the gravel and ripple keys. All three pass `style-check`. Night has `lighting.lamp`. Not yet looked at in a picture.
- **Collision (world/world.gd):** a model that carries bodies (-col) keeps only those; one with none gets
  `create_trimesh_collision()` on every still mesh; moving parts (`data/world.json` `moving`: door, panel_*,
  dish, wheel_*) with no body get a convex hull on an AnimatableBody3D. Bodies narrower than `hero.width`
  (reality.json) go to layer 3 + group `thin`, else layer 2 + `wall`; `floor` when no higher than `hero.step`.
  Movers (`kinds`: rover, pip as vehicle on layer 5; cargo_bag as carriable on layer 7) are one AnimatableBody3D
  at the item's node with a convex hull. Still meshes merge into one mesh per material (`merged`), each part's
  node stays. Items sit on the lowest ground under their footprint. Stand-ins keep their label.
- **Rocks (world/rocks.gd):** seeded scatter from `scatter` in world.json; pebbles from `models/rock_small_*`,
  solid rocks (0.5 to 2.2 m, convex bodies, layer by width) from the other `rock_*` models; stand-in lumpy
  spheres when none exist. None on items, pads (footprints + margin) or `paths`. `spots` lists every rock (a
  headless MultiMesh reads back identity).
- **Dust (world/dust.gd):** `puff(pos, strength)` (drifts downwind, thins in 3 s), streaks around the camera,
  a dust devil circling 160 m out (day only), a storm front (storm only). Per state in world.json `weather`,
  keyed by the DESIGN name; wind `toward_deg` 60, speed 4 (6 in the storm) from movement-and-look section 4.
- **Probe:** one ReflectionProbe over the base, rebuilt on every restyle; `reflection_mask = 1`, and terrain and
  rocks are on render layer 2, because the probe lit the ground as a bright square around the base.
- **world.mark() forwarder: added**, `mark(pos, yaw_deg, kind, width := 0.3)` calls `terrain.mark(...)`.
- data/world.json: greenhouse moved to (-14, -6) (the horizon camera was inside it), landmark to (-7, -6, 270).

## 2. Half-done
- `tests/world_test.gd` exists and runs (collision on 2/3, resting, static sweep with a self-proof, rocks off
  pads and paths, each sky with a Logger for errors and a no-leftovers check). Not yet run on the real terrain.
- Pictures: no capture of the new world has finished. The machine was at load 33, and capture-view hit its
  300 s limit twice (c3, c4), with no result. Draw calls of the new world are not measured.
- Draw-call cutting is not done (see 4).

## 3. Last check results
- `tests/run.gd` (scratch copy): 0 failed.
- `tests/world_test.gd` (scratch copy): 1 failed: `2 drawn faces nothing stops: hab1/merged at (-0.5, 0.8, -2.9)`
  and `(1.4, 2.7, -0.4)`. These are lane B's habitat: `tank1` and `cradle0_5` stick out 0.5 m on the north side
  with no body (need `-col`), and `vent0` / `roof_ring1_85` on the roof are not stopped by the roof body (the
  roof's triangle shape may face inward). Every other check passed, including all four sky states.
- Draw calls, last measured (12 Nov ~01:45, stand-ins, before merge and before the probe mask): base 221,
  horizon 222, storm 222; primitives ~380k. Before lane E's work: base 99, horizon 101.
- Model warnings (lane C): Curiosity's textured materials `tex_01..05`, `parts_AO`, `wheels` are kept as is
  and `internals` falls to `body`: they need `kit` entries in DESIGN.md.

## 4. Next steps
1. When the working terrain.gd compiles, `godot --headless --path . --import`, then `tests/run.gd` and
   `tests/world_test.gd` in the project itself (not the copy).
2. One capture at a time on a quiet machine: `node ../../tools/capture-view.mjs . captures/laneE --views
   base,horizon,storm --scale 0.5`, then `node <scratchpad>/skies.mjs . captures/laneE` (sunset, night at the
   horizon view). Open every PNG; tune the three DESIGN.<state>.md light blocks by eye, regenerate the json.
3. Bring the base view under 150 draw calls: big rocks without shadows, fewer pebble shapes or cells, check
   the merged surface counts per item (habitat had 56 surfaces before merging).
4. Look at puffs in a picture (`emit_particle` with `emitting = false` is untested on Compatibility); if
   nothing shows, emit with `emitting = true` and `amount_ratio` or a small pool of one-shot emitters.
5. Report to the coordinator: the habitat parts above, the Curiosity kit entries, the dust devil speed (3 m/s,
   no source), and whether the sandbox should get `sunset` and `night` views.
