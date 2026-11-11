# Lane E (world) handoff, 12 Nov 2026 (after the restart)

Nothing committed. Everything runs in the real project now.

## Done and checked
- Sky states: `DESIGN.{sunset,night,storm}.md` and their `design.*.json`. Storm tuned after a capture (less
  saturated, fog 2 to 120 m, curve 0.5). All pass style-check. Captured at the horizon view (sunset also facing the sun).
- Collision: authored bodies kept, triangle bodies otherwise, convex hulls on moving parts
  (`moving`: `^(door|dish)$|^(panel|wheel)_[0-9]+$`), layers 2/3 by hero width, movers on 5/7 with
  `sync_to_physics = false` (they sat at the origin before).
- Draw calls: still meshes of static items merged per material per 64 m cell (`cell_x_z`), items keep their
  meshes hidden; pebbles are lumpy spheres (70 triangles) in 3 MultiMeshes, solid rocks baked in one mesh;
  no shadows from items under 0.6 m, vehicle wheels, or terrain chunks.
- The probe: one for the world's life (freeing it leaked), ambient from the rig's colour (it made shaded faces
  pure black).
- Puffs: a pool of 8 one-shot emitters (Compatibility cannot emit by hand), paler than the ground.
- `world.mark()` forwards to `terrain.mark()` with `width`.

## Last results
- tests/run.gd 0 failed; tests/world_test.gd 0 failed (sweep skips faces above any reach: hero + hop, rover roof, plus a step).
- Draw calls: base 195, horizon 209, storm 206, default (spawn) 202, sunset west 103.

## Open
- Base view is over 150. What is left: solar panels (8 panels x 3 materials, about 70 calls with shadows),
  the hero (13 surfaces with shadows, lane A), rover wheels and bags. Needs a call from the coordinator.
- "Texture leaked" at exit after the `storm` view (256 px with mips, two of them): not the probe; likely the
  Sky that `apply_lighting()` makes on every switch (tooling).
