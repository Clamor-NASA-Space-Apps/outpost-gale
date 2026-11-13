# Laying out the outpost: where each thing stands, and why

Written 13 Nov 2026 for Ravindu's ask: "clean up the old solar panels as we already have an array of solar panels. Place the objects in relevant places, finish up the wiring, and it's how the actual outpost is going to be placed."

Sources are saved in `pages/layout/` (new) and `pages/missing/` (the missing-assets study). Status: ✅ seen in the saved source (checked with `kwic.py`), ⚠️ reported only, or our own reasoning or maths, ❌ looked for and not found. The layout itself lives in `data/world.json` (`items`, `cables`, `paths`, `landmarks`, `pip`).

## TL;DR 🧭
- **Two things NASA keeps 1 km away: the reactor and the landing site.** Our ground is a 400 m square, so each goes as far out as the map allows, in opposite corners: the reactor 191 m north-east, the lander 191 m north-west, 270 m apart.
- **Everything people use daily sits round one yard south of HAB 1's airlock:** the greenhouse door, the storm shelter door, the gas bottles, the cargo bags and the rover's hatch are all a few steps apart.
- **Power has a direction a kid can follow:** sources (the reactor's long cable, the sun-tracking wing field) run into the battery bank east of HAB 1, and cables run out of it to each user: HAB 1, the greenhouse (through HAB 1), the dish, the work lights and the rover's charge lead.
- **The old four-panel arrays are gone.** The six 40 m wing rows (600 m²) replace them; two small arrays beside the field told the same story twice.
- **No cable crosses a path, the lander track or a doorway,** so nothing needs a cover ramp. `tests/world_test.gd` checks it, and that no cable runs through a solid.
- Kid version: "The dangerous things live far away. The things you need every day live close to the door. Follow the cables from the sun and the reactor to the batteries, then out to everything that uses power."

## 1. The rules, with sources 📏

| # | Rule | What the source says | Status | Source |
|---|---|---|---|---|
| 1 | The reactor stands about 1 km from the crew, behind a shadow shield aimed at them | "located 1 km away and connected via a 3 kVac power cable"; the shield limits radiation "to less than 5 rem/yr at the 1 km distant crew habitat boundary within a prescribed inclusion angle" (36° for "a hypothetical human outpost that is 1 km away") | ✅ | NTRS 20250000841 (`pages/missing/ntrs-20250000841-fsp-trades.txt`) |
| 2 | Same rule in the Mars campaign studies | "FSP is ~ 7,000 kg and must be operated >1 km from the Habitat" | ✅ | NTRS 20150006958, Rucker 2015 (`pages/layout/`) |
| 3 | The reactor's cable is reeled out on the surface by a rover | "the 1 km cable pre-connected to the reactor pallet. The utility rover would then drive the user interface pallet" 1 km away; mass line "Main 1 km Cable & Spool". That it then lies on the ground (not buried) is our reading | ✅ / ⚠️ | NTRS 20250000841 |
| 4 | Landings stay 1 km from anything on the surface, because engine plumes throw regolith | "the engine plumes will disturb regolith which has the potential to damage the vehicle and other assets nearby. To protect surface assets, landings must occur outside of a predefined keep out zone, currently assumed to be 1 km from any surface asset" | ✅ | NTRS 20160004402 (`pages/missing/`) |
| 5 | The landers themselves land about 1 km apart | "Landers ~1km apart (risky to land any closer)"; SAC21: "to avoid landing plume-induced damage of pre-deployed cargo, crew would land about one km from the other" landers | ✅ | NTRS 20150006958; NTRS 20210026448 |
| 6 | Keep-out distances are still open science; berms can shrink them | "No safe scientific or operational standoff distances have been defined for various landers"; berms are "constructed walls used to shield landed assets from ejecta" (lunar site plan, 2026) | ✅ | NTRS 20260002816 (`pages/layout/`) |
| 7 | Short cables; where a cable meets a vehicle route it gets a planned crossing | The lunar site plan's layout "minimizes cable run distances" and plans "berm cut-throughs: passages designed to allow mobility platforms and cabling through berms" and "ramps" | ✅ | NTRS 20260002816 |
| 8 | Gas bottles stand by the airlock | ISS: "The HPGTs are located near the airlock" (two oxygen, two nitrogen) | ✅ | NTRS 20200001084 (`pages/missing/`) |
| 9 | The crew's rover parks on the power grid to charge | Crew "connect the PR to the surface power grid to recharge batteries"; the rover "features suit ports" | ✅ | SAC21, NTRS 20210026448 |
| 10 | The storm shelter is a short walk from where the crew works | Orion's crew build a shelter "within an hour" of a solar storm warning (workspace facts table). A shelter by the airlock is our reading of that | ✅ / ⚠️ | NASA (Orion), workspace `factcheck.md` |
| 11 | Solar rows do not shade each other | Rows backtrack by their ground coverage ratio (already in `world.json` machines.tracker, `pages/tracker/`) | ✅ | Anderson and Mikofski 2020 (NREL) |
| 12 | Solar power is spread out and cable-hungry; fission is dust-proof | "fission power is more tolerant of dust, but the distributed solar power network is more tolerant to cable damage"; with fission the "Kilopower units remain together on/near the first lander" | ✅ | NTRS 20160011275, Rucker 2016 (`pages/layout/`) |
| 13 | The greenhouse is beside the habitat, door to door | NASA's CHAPEA habitat puts "food growing stations" inside the habitat (missing-assets study). A separate dome a few steps from the airlock is our choice | ⚠️ | `missing-assets.md` section 3 |
| 14 | The dish needs open sky toward Earth and the relay orbiters | Our reasoning: nothing tall between the dish and the sky it points at. No NASA layout rule found | ❌ / ⚠️ | ours |
| 15 | The solar field stays out of the base's long morning and evening shadows | Our maths: HAB 1 (3.6 m) with the sun 10° up casts a 20 m shadow; the field's nearest row is 22 m from HAB 1's wall | ⚠️ | ours |
| 16 | The battery bank sits between the sources and the users | Follows from rule 7 (short cables). Ours | ⚠️ | ours |

## 2. What it means on our 400 m patch 🗺️

The patch is 400 × 400 m (`data/terrain.json`), and anything that moves stays inside ±190 m (`bound.half`). Two things cap a far object at about 135 m from the centre on each axis (191 m on the diagonal, so the sweep can walk round it): the ground's contact shadows under every resting item are drawn only inside `play_half` (150 m, `world.gd _contacts`), and the collision sweep walks into items only inside it (`tests/sweep_test.gd`). The edge test also keeps the last 20 m of the patch and its corners clear (`tests/edge_test.gd`).

| Thing | Real distance | Ours | Why it is where it is |
|---|---|---|---|
| Reactor (10 kWe, KRUSTY prototype tested 2018, never flown) | ~1 km (rules 1, 2) | **191 m**, north-east corner of the play area (135, −135) | As far as the map allows. Its cable runs the whole diagonal to the battery bank |
| Lander | ≥1 km from any asset (rules 4, 5) | **191 m**, north-west corner of the play area (−135, −135), porch toward the base | The opposite corner from the reactor, 270 m from it, and away from the solar field (plume dust on panels). A rock-free rover track leads there; a marker light (`beacon1`) stands by the pad |
| Wing field (6 × 40 m rows) | next to the power yard (rules 7, 15, 16) | unchanged, south-east, nearest row 22 m from HAB 1's wall | Out of the base's shadows, header cable into the battery bank |
| Battery bank (3 cabinets) | between sources and users | unchanged, 14 to 16 m east of HAB 1, doors facing it | The hub every cable starts or ends at |
| Greenhouse | beside the habitat (rule 13) | moved from 15 m to 11 m west of HAB 1, door turned south onto the yard | Its door opens onto the airlock yard, 11 m from the airlock. Not straight at the spawn point: a walk from there meets the dome's side, not the closed door |
| Storm shelter | a short walk (rule 10) | unchanged, 7 m from the airlock, door facing it | |
| Gas bottles | by the airlock (rule 8) | unchanged, on HAB 1's wall next to the hatch | |
| Rover | parked on the grid (rule 9) | moved to a bay 10 m east of the airlock, nose south, hatch toward the yard, charge lead from the battery bank | Drives straight out south onto its track, crossing no cable |
| Dish | open sky (rule 14) | unchanged, 16 m north, behind HAB 1 from the yard | Nothing tall north of it |
| Build pads | room to grow | pad 1 moved west of the shelter, pad 2 east of the rover bay | Clear of the greenhouse and the rover's hatch |
| Telltale (wind) | open air | moved from HAB 1's wall to the open yard | A building beside it would shelter it from the wind (our reasoning) |
| Lamps | light the work | yard light between the airlock and the rover bay; north light by the dish path | Both on cables |

## 3. The wiring 🔌

Thirteen cables, all `trim`, 6 cm wide, laid on the ground (`world.gd _lay_cables`). Each one runs from a device's port to another's (`world.json cables.ends`): the port is an empty inside a gland box on the ground that the device's model carries, under a conduit up into the device (`forge/base_kit.py port()`), so the cable visibly plugs in. Before 13 Nov the cables stopped beside the boxes ("those wires aren't connected", playtest). Each battery cabinet has a port on each end.

1. **Reactor → battery3 (north end):** the 3 kVac line from the reactor deck's front, about 175 m.
2. **Wing field → battery3 (south end):** into wing 1's junction box, then box to box along the rows' north ends (five short links, the field's combiner chain; wing 6's far gland is capped).
3. **Battery → HAB 1:** into the east feed box (`port_e2`).
4. **HAB 1 → greenhouse:** from the west gland box under the utility conduits, round the north side to a gland on the dome's ring wall.
5. **Battery2 (north) → dish:** into a gland box beside the pedestal.
6. **Battery (north) → north light.**
7. **Battery2 (south) → the rover's charging post** (`prop_charger`), whose own 2.4 m lead plugs into the rover's charge socket while it stands in its bay (rule 9; `world.json charger`).
8. **HAB 1 (`port_e1`) → yard light.**

No line crosses a walkway, the lander track or a doorway (checked by `world_test`, with each end in its port), so no cover ramp is drawn. If a later route must cross one, rule 7 says it needs a cover or a cut-through: add it then.

## 4. Open questions ❓
- The dish's real siting rule (distance from buildings, horizon mask) was not found.
- Whether a Mars greenhouse would be a separate dome or racks inside the habitat (NASA's first stay has none at all).
