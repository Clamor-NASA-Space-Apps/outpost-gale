# Lane B handoff (base structures): done 12 Nov 2026, after the reboot

All ten recipes are rebuilt against the current DESIGN.md (with the `plant` role) and pass
`style-check` together: "OK DESIGN.md + 14 model(s)". `godot --import` exits 0 and `check_godot_project.py`
reports 0 errors, 0 warnings in 180 files. Rows are in `ASSETS.md`. Nothing is committed.

Since the pause:
- Habitat: tanks and cradles on the back (north in world.json) and the roof hatch, lid, rings and vents are
  `-convcol`. The mid band and roof band were solid discs across the room (a plate at knee height inside, a
  lowered ceiling): now they are rings.
- Lettuce uses `plant`. Seam boxes on the oxygen maker and water recycler were renamed `front_seam` so that a search
  for `panel_*` nodes finds only the solar panels.
- In Godot: the habitat has 16 static bodies, the greenhouse 8, and the others 1 or 2. Pivots: habitat `door` at (0.51, 0.28, -2.56),
  greenhouse `door` and `slot_1..8`, solar `panel_1..4` at 1.48 m, dish `dish` at 1.95 m.

Doubts still open: see the report (opaque greenhouse panes, no collision on moving parts, lettuce at pack size,
my own `flat_label` in Exo 2 because `shapes.label()` has no font option).

## Sweep fix (after the reboot)
`tests/sweep_test.gd` found drawn faces outside the collision on the habitat (utility box and conduits on its
west side), the lander (ladder) and the shelter (sign 8 cm in front of the bags). Fix at the root: `base_kit.done()`
now joins every part that has no collision suffix and does not move (`door`, `dish`, `panel_*`) into one
`detail-col` node, so what is drawn is what is hit. Lettuce opts out (`solid=False`). All ten rebuilt (no
previews, geometry unchanged), style-check OK on 14 models, `--import` 0, sweep "0 failed" (hab1, lander and
shelter: ok from 8 headings).
