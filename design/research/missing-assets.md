# Outpost Gale: missing 3D assets, researched

Written 12 Nov 2026 for the asset sessions before the hackathon (14 and 15 Nov 2026). Research only: no code, no models. Compared against [INVENTORY.md](../../INVENTORY.md), [ASSETS.md](../../ASSETS.md), `models/` and `data/world.json` as they stood on 12 Nov 2026.

**Crew on the surface: 2.** NASA's current plan for the first Mars landing sends 4 crew to Mars orbit, and "Two of the four crew would descend to the surface, living and working out of a pressurized rover for the 30-sol exploration" while the other two stay in orbit as a relay (NASA SAC21 study, NTRS 20210026448, 2022 ✅; same plan in ICES-2023-265, NTRS 20230002103 p.7: "At a minimum, a crew of two will utilize a PR-type habitat" ✅; and the 2021 ascent vehicle paper: "a reduction in crew capacity from four to two", NTRS 20210026439 ✅). Every size below is for **2 crew**; a **4 crew** column is kept beside it only so the team can compare. The 4-person crew model is dropped from the asset list.

Status marks: ✅ seen in the source (quote given or saved page named), ⚠️ reported only or our inference, ❌ looked for and not found. "Our maths" means a number we computed; its inputs are named. Saved pages: `pages/missing/` (new, this study), `pages/sizes/` (earlier study), and the workspace `research/junior-astronaut/pages/` (written `ws:` below). JPL pages block curl, so JPL facts here come from science.nasa.gov or nasa.gov copies of the same text.

## 1. TL;DR 🧭

- **The real first stay has no big base.** Two crew live 30 sols in a pressurised rover, next to three landers, powered by one 10 kWe fission reactor about 1 km away. No greenhouse, no oxygen maker, no water recycler: oxygen and water come in tanks, urine is stored, a small amine scrubber removes CO₂. Our base (habitat, greenhouse, solar arrays) is closer to what NASA plans for **later** missions. That is fine for a game, but say it in the game's fact cards and keep the parts that match the real plan prominent.
- **The outpost the user asked for fits in the habitat we already have.** HAB 1 (5 m drum, about 47 m³ we can live in, our maths) gives 2 crew more room than NASA's 30-sol rover and 81% of NASA's long-mission minimum. It is **empty inside**. Fitting it out (2 sleep stations, galley, toilet, life support wall, workstation, suit corner) is the biggest P1 job.
- **Life support is mostly missing as props**, and two existing props sit in the wrong place: the water recycler and the oxygen maker stand outside in −100 °C air. Real ones live inside, in racks the size of a fridge.
- **Power is 25 times short.** Our two solar arrays are 29 m². A 10 kW base on solar needs about 580 m² (NASA's DRA 5.0 method, our maths). The real plan uses fission instead. Both make a good trade-off card; we need a reactor model, a cable, and a lot more panels (instanced, not modelled one by one).
- **Food:** plants are a supplement, and only radishes and microgreens ripen inside 30 sols. Add a Veggie-style unit with the real magenta grow light, radish and microgreens, red romaine, mizuna, a wilted stage, and food packs. Tomatoes and peppers are P2 (85 to 120 days: they never ripen in our 30 sols).
- **Scenery:** the science goal at Gale is an ancient lake, and we have no lake rock. A layered mudstone outcrop is P1; dark dune band, ventifacts, conglomerate and Mount Sharp's layers are P2.
- **Biggest risks:** draw calls (195 already against 150) once an interior exists; the lander and greenhouse not matching the real plan; DESIGN.md has no magenta grow-light or red-leaf role (a DESIGN.md change needs Ravindu's approval); kit models (Kenney) are low-poly and clash with the approved realistic look.

## 2. The base the Docmost page needs 🚀

Answers to the team's power page (Sinhala, "බලශක්තිය, ජනනය සහ පරිභෝජනය"), sized for **2 crew** with 4 crew beside it.

### 2a. How much the crew needs for 30 sols (our maths)

30 sols = 30.8 Earth days (sol 24 h 39 min). Per-person daily rates from NASA BVAD 2022 (facts table and factcheck rows 110 to 124 ✅).

| Need | Rate per person per day | 2 crew, 30 sols | 4 crew, 30 sols | Note |
|---|---|---|---|---|
| Oxygen | 0.84 kg | **52 kg** | 104 kg | breathing only; suit refills and leaks add more (ICES-2023-265: the same tanks "recharge the EVA suits") |
| Water, no shower | 3.217 kg | **198 kg** | 397 kg | drink 2.0 + food 0.5 + exercise sweat 0.717 |
| Water, with shower | 4.48 kg (early planetary base) | **276 kg** | 552 kg | BVAD Table 4-20 |
| Packed food | 2.39 kg | **147 kg** | 295 kg | about 3,000 kcal |
| CO₂ breathed out | 1.085 kg | **67 kg** | 134 kg | what the scrubber must remove |

The team page's numbers (O₂ 3.4 kg/day for 4, 104 kg, water 397 / 552 kg, food 295 kg) match the 4-crew column. For the game, halve them.

### 2b. The lander and the ride home

**Plain answer:** NASA's first-stay plan lands 2 people, not 4. Our `building_lander.glb` (one 7.45 m crewed lander with a ladder) matches no NASA plan. The real surface has **three landers within 1 km** and a small two-stage rocket for 2 on top of one of them.

| Item | Real reference + size | Why kids need it | Have | How to make it | P | Tris |
|---|---|---|---|---|---|---|
| Mars Descent System (MDS), the lander body | Each lands "~25-ton payload" (SAC21 ✅). Lander body 9.1 m across for a 10 m fairing, 7.5 m for an 8.4 m fairing (NTRS 20170003405 ✅). It keeps its inflatable heat shield, the HIAD, "to landing", 16.7 m across when inflated; "eight 100 kN engines" behind doors in a rigid nose heat shield; legs fold out after the shield (NTRS 20160004402 ✅). Lands at 2.5 m/s. Deck height ❌ not found | "Everything you have came on three landers": the supply limit behind every trade-off | partial (`building_lander.glb` is a generic 7.45 m one) | Forge recipe: a 9 m wide drum-shaped descent stage, a flat deck, 4 to 6 legs, the deflated HIAD as a wrinkled ring skirt (`trim`), engine doors on the underside. One recipe, three deck loads | P1 | 8,000 |
| MDS 1: cargo lander | Brings "the MAV propellant, FSP, and a robotic surface mobility system" (SAC21 ✅) | Where the reactor came from | missing | Same descent stage, deck with tanks and an empty FSP cradle | P2 | 6,000 |
| MDS 2 + Mars Ascent Vehicle (MAV), the ride home | SAC21 MAV for 2 crew: crew cabin "a vertical cylinder 2.3 m in diameter and 2.9 m tall, with roughly 10.5 m3 of habitable volume", "1 m square hatch", two stages, four 10 klbf engines on stage 1 and one on stage 2, "relies on the EDL element to act as a launch platform" (NTRS 20210026439 ✅). Overall figure labels read 4.5 m and 7.2 m (⚠️ we read them as width and height; the text does not say). 4-crew version (2019): cabin 2.7 m × 3.8 m, 17.5 m³, stage 1 tanks 2.65 m × 4 m, stage 2 tanks 2 m × 2.9 m (NTRS 20190001229 ✅) | Sol 30's ending: the rocket home must be fuelled and ready; the crew is "not cleared to land on Mars until the oxygen tanks are confirmed full" (2019 paper ✅) | missing | Forge recipe on the MDS deck: 2.3 × 2.9 m cabin on two stacked stages, total about 7.2 m above the deck (⚠️). Separate GLB so the cinematic can lift it off | P1 | 6,000 |
| MDS 3: crew lander | Carries the crew, "a pressurized rover, a docking adapter, and crew consumables"; lands "within one kilometer" of the other two (SAC21 ✅); keep-out zone "1 km" because plumes throw regolith (NTRS 20160004402 ✅) | Why the landers are far from the base | missing | Same descent stage, empty rover cradle and ramp | P2 | 6,000 |
| Getting down: ladder, ramp or lift | First EVA "descending from the MDS deck to the surface" by "EVA alone"; off-loading "not yet defined" (SAC21 ✅). Crew board the MAV through "an inflatable tunnel" from the pressurised rover (2019 paper ✅). No NASA ladder or elevator design found ❌ | Contextual traversal test in the sandbox | partial (ladder on the current lander) | Ladder (Apollo-style) on one leg, plus a forge inflatable tunnel (soft tube, `suit` fabric) between rover hatch and MAV | P2 | 1,500 |
| Small Pressurized Logistics Container (SPLC) | Taken "from the lander deck for repositioning onto a PR suit port", refilled with trash and parked "next to the lander" (SAC21 ✅). Size ❌ | Restocking food and water is a real chore | missing | Forge: a 2 m pressurised can with a suitport ring, carried by the cargo robot | P2 | 1,500 |
| Robotic mobility system (cargo robot, cable layer) | Lands with the FSP; "robotically connect the crewed lander to the pre-deployed surface power grid" (SAC21 ✅); "a rover would approach the lander and connect a power cable ... within 24 hours" (NTRS 20160004402 ✅) | Who plugs in the reactor; a job for PIP's big cousin | missing | Reuse `vehicle_rover` wheels and chassis with a flat bed and a cable reel; or NASA RASSOR GLB (section 9) as a regolith digger | P3 | 5,000 |

### 2c. Tanks: oxygen and water

**Where real designs put them:** on the ISS the "High Pressure Gas Tanks (HPGTs) are located near the airlock", two oxygen and two nitrogen (NTRS 20200001084 ✅), outside the Quest airlock (⚠️ "outside" from secondary sources). In the first Mars stay, "the atmospheric pressure and metabolic O2 will be maintained by tanked high pressure gas" and "all necessary water will be provided as a consumable", restocked from the lander (ICES-2023-265 ✅). Water is the best storm wall: NASA's shelter study rated a "pre-integrated waterwall for two person crew quarters" top (RadWorks, NTRS 20170002287 ✅), and Orion's crew build a shelter "within an hour" from bags of food and water (facts table ✅). 5.3 cm of water halves a deep-space storm dose (facts table ✅).

| Item | Real reference + size | 2 crew | 4 crew | Have | How to make it | P | Tris |
|---|---|---|---|---|---|---|---|
| O₂ tanks | NORS tank: 36.3 kg O₂ at 6,000 psi (NTRS 20110012004 ✅). ISS HPGT: 37.89 in (0.96 m) across, 94.3 kg O₂ full, 544 kg empty (NTRS 20200001084 ✅). "one or two spare tanks are required" (same ✅) | 52 kg = 1.4 NORS tanks → **2 tanks + 1 spare** (our maths) | 104 kg = 2.9 → 3 + 2 spares | partial (one tank on `prop_oxygen_maker`) | Forge: a skid by the airlock with 3 white composite bottles (`body`), valves, gauges, an "O₂" label, plus 1 N₂ bottle. Repurpose `prop_oxygen_maker` into this (no MOXIE, no electrolysis in the 30-sol plan) | P1 | 2,500 |
| N₂ makeup tank | NORS N₂ tank 27.2 kg (✅); N₂ needed "due to losses from leakage and EVAs" (ICES-2023-265 ✅); amount ❌ | 1 | 2 | missing | Same recipe, different label | P1 | (in skid) |
| Water | 198 L is a cube 0.58 m on a side (our maths). As a 5.3 cm water wall it covers **3.7 m²** (our maths: 0.198 m³ ÷ 0.053 m) | 198 L; 3.7 m² of wall | 397 L; 7.5 m² | missing | Forge: soft water bags (CTB-sized, 0.5 × 0.42 × 0.25 m, about 50 L each ⚠️) lining the two sleep stations, plus one hard tank with a gauge in the galley | P1 | 1,500 |
| Urine and used-water store | "crew urine will not be recycled ... it must be stored" (ICES-2023-265 ✅) | tank | tank | missing | Forge: a small yellow-tagged tank under the toilet | P2 | 600 |

### 2d. CO₂ scrubber

| Option | Real reference | For 2 crew, 30 sols | Look and size | Have | P |
|---|---|---|---|---|---|
| Small amine scrubber (the real plan) | "A small CO2 scrubber, such as an amine type system ... would preclude the need for consumable cartridges"; LiOH "would most likely take up too much valuable cabin volume" (ICES-2023-265 ✅). Orion's CAMRAS: "plastic beads coated with an amine", regenerated by vacuum (NTRS 20130011191 ✅). ISS CDRA ~1,000 W (factcheck row 76 ⚠️) | Uses power (about 1 kW, ⚠️ from the ISS unit), no consumables. On Mars the CO₂ is dumped outside (factcheck row 100 ⚠️) | Fridge-sized box ⚠️ (secondary source); a vent pipe through the wall | missing | **P1** |
| LiOH canisters (Apollo style) | Canisters "are not regenerated so may only be used once" (NASA CO₂ brief, `ws:pages/co2/` ✅); Apollo 13's "mail box" (factcheck row 95 ✅) | No power. About **73 kg** of LiOH by ideal chemistry (our maths: 2 LiOH, 47.9 g, per CO₂, 44 g; 67 kg CO₂); 4 crew 146 kg. Real canisters need more ⚠️ | Rack of white cartridges, a spent-cartridge bag | missing | P2 (as the backup and a trade-off card: power vs mass) |

**Pick for the game:** model the amine scrubber as the main unit and a small LiOH canister rack as the emergency backup. That gives a real choice (power or stored mass) without inventing hardware.

### 2e. Water filtration: carried or recycled?

**Both sides:**
- **First stay (NASA's plan):** "All necessary water will be provided as a consumable and thus will not be recycled or regenerated. ... Used water will most likely be stored" (ICES-2023-265 ✅). 2 crew carry 198 kg.
- **Later stays and the ISS:** the Water Processor, Urine Processor and Brine Processor bring the ISS to 98% (factcheck rows 126 to 128 ✅). Powers: Water Processor 343 W processing, 163 W standby; Urine Processor 424 W, 108 W standby (factcheck row 128 ⚠️ pre-flight figures); Brine Processor technology 142 W (row 145 ⚠️ ground test). On the ISS these live in "two International Standard Payload Racks (ISPR) named WRS#1 and WRS#2" (NTRS 20220006163 ✅), part of "four refrigerator-sized racks" for all life support (NASA ECLSS fact sheet, `ws:pages/agent-oxygen/` ✅). One ISPR is about 2.0 × 1.05 × 0.86 m (⚠️ Wikipedia, citing the ISS User Guide).
- **The game trade-off:** carry 198 kg of water, or spend about 0.9 kW (our maths: 343 + 424 + 142 W while running) and two fridge-sized racks to recycle it. No MOXIE anywhere in the base (the team page already rules it out: 12 g/h at 300 W).

| Item | Real reference + size | Have | How to make it | P | Tris |
|---|---|---|---|---|---|
| Water recycler rack (WPA + UPA + BPA) | 2 ISPRs, about 2.0 × 1.05 × 0.86 m each ⚠️; ISS photos of the UPA (iss029e043447) and BPA on the team page | partial: `prop_water_recycler.glb` exists but stands **outside** at (4.5, −1.5), where water would freeze (Gale air down to −100 °C, facts ✅) | Re-forge as an indoor rack against the habitat wall (same parts: filters, tanks, gauge). Keep the outdoor one only as a heated "water tank farm" if the team wants it | P1 | 3,000 |
| Common Cabin Air Assembly (humidity) | Fan, condensing heat exchanger, water separator; "five CCAAs" in the US segment (factcheck row 146 ✅); power ❌ | missing | Forge: a ceiling-height duct box with a fan grille and a condensate line | P2 | 1,200 |

### 2f. Power: night, batteries, panels, cables

**The real plan uses fission, not solar:** lander 1 brings "a 10 kWe FSP unit" (SAC21 ✅). NASA's newer surface reactor study puts the crew habitat 1 km away so the dose there is "<5 rem/yr at 1 km", joined by "a 3 kVac power cable" (NTRS 20250000841 ✅). That 2025 design is 40 kWe and fits "4m dia. x 6m length" stowed, with a "140 m2" to "180 m2" main radiator (✅). The team page's "all energy stored in lithium batteries first" does not match NASA's solar plan either: DRA 5.0 used regenerative fuel cells for the night ("a 5-kWe RFC for nighttime power production", DRA 5.0 Addendum ✅); the rover does carry batteries and recharges them from the grid (SAC21 ✅).

| Number | 2 crew | 4 crew | Inputs (our maths unless marked) |
|---|---|---|---|
| Base load (day and night) | **up to 10 kW** | 12 kW | 2 crew: the FSP NASA chose (✅), an upper bound. 4 crew: DRA 5.0 habitat "12-kWe day/night load" (factcheck row 78 ✅; that habitat was for 6) |
| Night length to cover | 14 h | 14 h | NASA Glenn defines Mars "nighttime" as "the 13- to 15-hr period when array power output is below the daytime power requirement" (NTRS 20050194571 ✅) |
| Battery for one night on solar | **140 kWh** | 168 kWh | load × 14 h. On fission: only a small buffer |
| Energy per sol | 247 kWh | 296 kWh | load × 24.66 h |
| Clean solar yield at Mars | 658 Wh per m² per sol | same | InSight: two 2.2 m round panels (7.6 m²) made "roughly 5,000 watt-hours each Martian day" after landing (science.nasa.gov ✅); 5,000 ÷ 7.6 |
| Panel area, clean, no storage losses | 375 m² | 450 m² | energy per sol ÷ 658 Wh/m² |
| Panel area, NASA's method | **580 m²** | 696 m² | DRA 5.0: "5 kWe" per module with "290 m2" of array, 29% cells, "inclined 30 degrees", night storage and dust removal included (Addendum ✅) |
| Dust losses | | | InSight fell from 5,000 to "about 500 watt-hours each sol" by spring 2022 with no cleaning (✅); a regional storm cut it from 425 to 275 Wh/sol, 35% (nasa.gov 2022 ✅) |
| What we have | 29 m² ≈ 19 kWh/sol ≈ **0.8 kW** average | | 2 arrays × 4 panels × 1.45 × 2.5 m |
| Panels to add (our 1.45 × 2.5 m size) | about **160** panels (40 four-panel arrays) | 192 | 580 m² ÷ 3.6 m² |
| Cable runs | reactor to base 1 km (off our 400 m play patch); arrays to base about 25 m today | | FSP paper ✅; `world.json` |

| Item | Real reference + size | Why kids need it | Have | How to make it | P | Tris |
|---|---|---|---|---|---|---|
| Fission Surface Power unit | 10 kWe in the real plan (SAC21 ✅); "up to 10 kW for ≥10 years" (facts ✅); 2025 40 kWe design 4 m × 6 m stowed, 140 to 180 m² radiator panels, 1 km away (NTRS 20250000841 ✅) | The solar-or-nuclear trade-off: power at night and in storms vs 1 km away and a long cable | missing | Forge: reactor can on a lander deck with a cone shield toward the base, 4 to 6 tall radiator wings (`metal`), a "keep out" beacon. Place on the horizon at 1 km, a cable running off the patch edge toward it | **P1** | 4,000 |
| Solar field | DRA 5.0 wing "2.5 m high × 58 m long", 30° tilt (Addendum ✅) | Dust on panels, cleaning EVAs, storms | partial (2 arrays, 29 m²) | **Engine, not new models:** a `MultiMesh` of the existing panel mesh in rows, 1 draw call per material; optional one forge "long wing" segment 2.5 × 10 m | **P1** | 2,240 per array, instanced |
| Battery bank | 140 kWh for one night on solar (our maths) | Night and storm margin | have (`prop_battery_bank.glb`, 1.6 × 0.8 × 1.24 m) | Add 2 more cabinets by instancing; label "kWh" bars | P2 | (have) |
| Regenerative fuel cell skid | DRA 5.0 night storage (✅) | Real alternative to batteries | missing | Forge: H₂ and O₂ bottles and a fuel cell box on a skid | P3 | 2,000 |
| Power cables | 3 kVac cable to the reactor (✅); ISS-style PMAD ❌ for Mars | Wayfinding (follow the cable), something to plug in | missing | Engine: a mesh swept along a `Path3D` by code (SurfaceTool), laid on `height_at()`; sockets on each machine | **P1** | 200 per 10 m |
| Panel cleaning brush | InSight's "robotic arm trickled sand ... a gain of about 30 watt-hours" (nasa.gov ✅); DRA 5.0 "automated dust removal" (✅) | Wipe a dusty panel and see it brighten | missing | Forge: a long-handled soft brush; the dust coat on panels as a role parameter | P1 | 300 |

## 3. The outpost for 2 crew: habitat and its rooms 🏠

**What NASA says:** for 30 sols "two crew could comfortably live in a Pressurized Rover (PR), eliminating the need for a large, long-duration habitat" (SAC21 ✅). For long missions NASA's minimum is about 29 m³ of net habitable volume per person (BVAD Table 3-8: 115.83 m³ for 4 crew, 28.96 m³ each ✅), and the study behind it says the need grows with mission length up to 180 days (✅). NASA's CHAPEA analog for 4 crew for a year is 1,700 sq ft (158 m², our conversion), with "four private crew quarters", "dedicated workstations", a "dedicated medical station", "common lounge areas" and a "galley and food growing stations" (nasa.gov/chapea/habitat ✅), laid out "in a gradient of privacy" from quarters to work areas (ICON ✅).

**What that means for us (our maths):** HAB 1 is a 5 m drum (NASA HDU: 5 m wide, 3.5 m tall, "four rectangular hatches spaced at 90 degree intervals", a top hatch to a "future upper deck loft", NTRS 20110013501 ✅). Floor 19.6 m², about 47 m³ usable at 2.4 m. For **2 crew** that is about 81% of NASA's long-mission minimum (58 m³) and far more than the rover NASA plans to use, so **HAB 1 is enough**: fit it out, do not build new modules. For 4 crew, three HDU drums joined at their wall hatches (141 m³) would meet BVAD; listed only for comparison.

BVAD zone volumes (Table 3-8, 4 crew, m³ ✅) and what we fit into HAB 1 for 2:

| Zone | BVAD, 4 crew | Our 2-crew fit-out in HAB 1 |
|---|---|---|
| Sleep + relaxation, private work | 13.96 + 17.40 | 2 sleep stations about 1.0 × 0.9 × 2.2 m each (ISS crew quarters: "total deployed volume of CQ is ~2.1 m3", NTRS 20100017014 ✅) |
| Table, eating, group | 10.09 + 18.2 | one fold-down table, 2 seats |
| Food prep | 4.35 + 3.30 | galley bench: food warmer, water dispenser |
| Waste collection, cleansing | 2.36 + 4.35 | one toilet and wash cubicle |
| Exercise | 6.12 + 3.38 + 3.92 | one cycle; NASA crews "exercise" during re-adaptation (SAC21 ✅) |
| Medical | 5.80 + 1.20 | wall-mounted kit and a fold-out seat |
| Mission planning, computer | 3.42 + 3.40 | one workstation (comms console, "Ask Earth") |
| Temporary stowage | 6.00 | cargo bags on wall straps |
| Airlock | ISS crewlock "4.25 m3", room for 2 at once (BVAD ✅) | the existing hatch, plus a suit and dust corner, or suitports |

| Item | Real reference + size | Why kids need it | Have | How to make it | P | Tris |
|---|---|---|---|---|---|---|
| HAB 1 interior shell (floor, wall panels, ceiling, lights) | HDU interior: 8 wedge sections (NTRS 20110013501 ✅) | Somewhere to be inside; the camera indoors | partial (hollow drum, floor 0.28 m up) | Forge: 8 wall panel wedges, floor grating, ceiling light ring (`light` role), handholds 1.02 to 1.42 m up (sizes.md ✅) | **P1** | 4,000 |
| Sleep stations × 2, lined with water bags | ISS CQ 2.1 m³ (✅); water wall top-rated (RadWorks ✅) | Rest; the storm shelter is your own bed | missing | Forge: a cabin with a curtain, sleeping bag, laptop shelf, lamp; water-bag walls (2c) | **P1** | 2,000 each |
| Galley: table, food warmer, water dispenser, food packs | ISS food heated in a "suitcase-like food warmer"; no fridges (factcheck row 115 ✅) | Food is a meter; packs are counted | missing | Forge table and warmer; food pouches as small props in a CTB | **P1** | 2,500 |
| Toilet and wash cubicle | NASA UWMS: about 28 in (0.71 m) tall, "65% smaller" than the ISS toilet (⚠️ Air & Space, Space.com) | Water and urine trade-offs; kids ask | missing | Forge: cylinder seat, hose, privacy curtain; urine tank below (2c) | **P1** | 1,500 |
| Life support wall: CO₂ scrubber, water rack, air fan, O₂/N₂ valves | Sections 2c to 2e | The Life support meter has bodies to touch | missing (the two outside props are the wrong place) | Forge: 2 rack fronts (ISPR, 2.0 × 1.05 m) with gauges, status lights, filter doors | **P1** | 3,000 each |
| Workstation and comms console | "Mission Planning: Computer" 3.42 m³ (BVAD ✅) | "Ask Earth" delay, data badges | missing | Forge: desk, 2 screens (`glass` lit panes), headset | **P1** | 1,500 |
| Suit and dust corner (or suitports) | Suitports keep the suit "outside of the pressurized volume", pre-EVA under 30 min, and cut dust (NTRS 20120011640 ✅); dust is "likely toxic" (facts ✅); 2 suits | Dust and time trade-off; why there is an airlock | partial (suitports exist on the rover only) | Forge: 2 suit stands with the hero suit mesh posed and static, a brush, a dust mat; or 2 suitports on HAB 1's back wall | P1 | 2,000 + suit |
| Exercise cycle | BVAD 6.12 m³ for a cycle (✅) | Health meter; Mars gravity is 0.38 g | missing | Forge: a cycle frame and seat | P2 | 1,000 |
| Medical kit | BVAD 5.8 m³ medical care (✅) | Crew health | missing | Poly Haven `medical_box` (CC0) or forge | P2 | 1,000 |
| Fire extinguisher, smoke sensor | ❌ no Mars source found | Safety | missing | Poly Haven `korean_fire_extinguisher_01` (CC0), decimated | P3 | 1,000 |
| Exterior regolith cover on the hab | ~1 to 1.6 m of soil for <100 mSv/yr; thin soil barely helps (facts ✅) | Radiation shielding trade-off | missing | Forge: stacked regolith bags as a second skin on one side | P2 | 3,000 |
| Crewmate (1) | Crew of 2 (SAC21 ✅) | You are not alone; buddy EVA rule ("a minimum of two people", factcheck row 143 ✅) | missing | Hero mesh, second accent and number (INVENTORY 11a #8) | **P1** | 7,271 (shares the hero's) |

## 4. Life support you can see and touch 🫁

One line each, for the HUD's fact cards. Sizes and power are in sections 2c to 2e.

| Item | What it does, in one line | Real reference | Have | P |
|---|---|---|---|---|
| O₂ bottles by the airlock | Air to breathe, carried from Earth | NORS 36.3 kg (✅) | partial | P1 |
| N₂ bottle | Tops up the air we lose through leaks and the airlock | NORS 27.2 kg (✅) | missing | P1 |
| CO₂ scrubber (amine) | Pulls out the CO₂ we breathe out and dumps it outside | ICES-2023-265, CAMRAS (✅) | missing | P1 |
| LiOH canisters | Backup scrubber that needs no power but is used once | NASA CO₂ brief (✅) | missing | P2 |
| Water bags and tank | Drinking, food, sweat; and a wall against storms | BVAD, RadWorks (✅) | missing | P1 |
| Water recycler rack | Cleans urine and sweat back into drinking water | ISS WRS racks (✅) | partial, wrong place | P1 (move inside) |
| Air fan / humidity box | Moves air and catches the water we breathe out | CCAA (✅) | missing | P2 |
| Dust filter | Martian dust gets in anyway and must be filtered | ICES-2023-265: "it will inevitably find its way inside" (✅) | missing | P2 |
| Pressure and O₂ gauge panel | Shows pressure (habitat 57 kPa proposed, facts ✅) | BVAD (✅) | missing | P2 |
| Oxygen maker (electrolysis) | Splits water into O₂; 3.6 to 4 kW (facts ✅) | ISS OGA (✅) | have, but **not in the 30-sol plan** | drop or keep as a later-mission option |

## 5. Food and greenhouse 🥬

**What NASA grew** (Veggie fact sheet 2019 ✅ unless marked): 'Outredgeous' red romaine lettuce (33 days, VEG-01), 'Tokyo Bekana' Chinese cabbage, mizuna mustard, 'Waldmann's Green' lettuce, 'Red Russian' kale and 'Dragoon' lettuce, 'Wasabi' mustard and 'Extra Dwarf' pak choi, zinnia flowers ("a precursor for a tomato"); "eight different types of leafy greens"; "15 different types of plants". 'Red Robin' dwarf tomatoes in VEG-05, a "100-day planned duration" (nasa.gov 2023 ✅). NuMex 'Española Improved' chile peppers in the Advanced Plant Habitat, "about four months", "turn from green to red" (NASA PH-04 sheet ✅). Radishes in the APH "reach maturity in just 27 days" (factcheck row 120 ✅).

**What ripens in 30 sols:** only radishes (25 to 27 days) and microgreens (7 to 18 days) (factcheck rows 119 to 122). Lettuce takes 28 to 33. Plants are "less than 1% of the crew's food energy" (row 118 ✅): they are vitamins and morale, not air or calories. NASA's salad for 4 crew is "72 plants" on 1.62 m² (row 121 ✅), so 36 plants on 0.81 m² for 2 (our maths).

**The grow light:** Veggie uses "Red (630 nm), Blue (455 nm) and Green (530 nm)" LEDs at 100 to 500 µmol m⁻² s⁻¹ (NTRS 20160005059 ✅), "about 70 watts" (fact sheet ✅). Light recipes "Red-Rich and Blue-Rich" (✅); VEG-05 used "equal levels of red: blue" or "90:10" with "~10% green" (NTRS 20230008751 ✅). Red plus blue reads magenta-pink to the eye ⚠️ (photos; not a NASA sentence).

**Hardware:** Veggie "Baseplate Footprint: 29.2 cm x 36.8 cm", "Maximum Height: 47.0 cm empty", plants in "plant pillows" (Teflon-coated black Kevlar with white wicks), "six plant pillows" per crop (✅). APH: "the size of a large microwave oven and has more than 180 sensors" (PH-04 sheet ✅).

| Item | Real reference + size | Why kids need it | Have | How to make it | P | Tris |
|---|---|---|---|---|---|---|
| Veggie unit inside HAB 1 | 29.2 × 36.8 × 47 cm, magenta light, 6 pillows, 70 W | Power vs fresh food; the most real plant hardware | missing | Forge: baseplate, bellows, light cap, 6 black pillows with white wicks. Light cap emissive, plus one unshadowed `OmniLight3D` | **P1** | 1,200 |
| Grow rack (2 to 3 shelves) | 0.81 m² for 2 crew (our maths); CHAPEA "food growing stations" (✅) | Scale of a salad garden | partial (2 beds in the greenhouse) | Forge: 3 shelves 1.2 × 0.45 m with LED bars | P1 | 1,500 |
| Radish, 4 stages | 25 to 27 days | The one crop that ripens in 30 sols | missing | Quaternius `Beet_1..4` (CC0, on disk), recoloured red with a white tip | **P1** | 400 to 1,400 |
| Microgreens tray | 7 to 18 days | Fastest food | missing | Engine: a tray with a `MultiMesh` of tiny leaves | **P1** | 500 |
| Red romaine 'Outredgeous' | 33 days, the first crop eaten in space | Real crop, red leaves | partial (green lettuce only; NASA's was red, DESIGN.md picked green on 12 Nov) | Existing lettuce meshes with a red-leaf role. **Needs a DESIGN.md role** (Ravindu's approval) | P1 | (have) |
| Mizuna / pak choi / kale | Veggie crops | Variety, replay | missing | Recolour and rescale lettuce stages; a forge serrated-leaf rosette for kale | P2 | 600 each |
| Wilted stage | VEG-01 lost "two plants ... due to water stress" (✅) | Power or water cut shows on the plants | missing | Same meshes drooped (shape key or bent copy), browner role tint | **P1** | (have) |
| Cut-and-come-again stubs | VEG-03 "cut-and-come-again" (✅); 64 days (facts ✅) | Harvest without killing the plant | missing | Stage 2 lettuce mesh trimmed | P3 | 300 |
| Dwarf tomato 'Red Robin' | 100 days | Long crops do not fit a 30-sol stay | missing | Quaternius `Tomato_1..4` (CC0, on disk) | P2 | 400 to 1,500 |
| Chile pepper 'Española Improved' | about 4 months, green to red | Same | missing | Forge: pepper fruit on a tomato-stage stem | P3 | 800 |
| Zinnia | Flowered in Veggie (✅) | Morale | missing | Quaternius `Flower_1..4` (CC0, on disk) recoloured orange | P3 | 500 |
| APH box | Large microwave oven size, 180 sensors | Science plant chamber | missing | Forge box with a window and lit interior | P3 | 800 |
| Food packs and pantry | 2.39 kg/person/day; 147 kg for 2 (our maths); thermostabilized and rehydratable pouches (✅) | The food meter made visible | partial (cargo bags) | Forge: 3 pouch types in a CTB; Poly Haven `long_life_food` (CC0) as a reference | **P1** | 300 each |
| Greenhouse dome | Not in NASA's 30-sol plan; a later-mission idea | Game choice; say so in a fact card | have | keep | n/a | |

## 6. Scenery, sky and look 🏜️

| Item | Real reference + size | Why kids need it | Have | How to make it | P | Tris |
|---|---|---|---|---|---|---|
| Layered mudstone outcrop (ancient lake) | The science goal: the ancient lake "held all the ingredients necessary for life" (facts ✅). Murray formation mudstone with "fine-scale planar laminations", about 200 to 300 m thick (⚠️ secondary) | Why we are at Gale at all | missing | Forge: stacked thin slabs, 3 to 6 m long, 1 to 2 m tall, eroded edges, `rock` role with a layered detail | **P1** | 3,000 |
| Conglomerate outcrop (old streambed) | "Link" and "Hottah": streambed gravels about 50 and 100 m southeast of Bradbury Landing (⚠️ JPL release via secondary copies; JPL blocks curl) | Water once flowed right here | missing | Forge: a tilted slab with rounded pebbles half sunk in it | P2 | 2,500 |
| Ventifacts (wind-cut rocks) | Rocks "abraded by wind-blown sand into distinctive, flattened facets with crisp edges" (NASA blog sols 3417 to 3418 ✅); "gator-back" rocks damaged Curiosity's wheels (APOD 15 Apr 2022 ✅) | Wind is a force; driving risk | partial (6 rounded scans) | Forge: boolean-faceted variants of the existing rocks | P2 | 1,500 |
| Dark dune band (Bagnold) | "a band of dark sand dunes along the northwestern flank of Mars' Mount Sharp"; Namib Dune "about 13 feet (4 meters) high"; dunes move "up to about one yard or meter per Earth year" (NASA ✅) | Landmark between base and mountain | missing (normal map only) | Mid-distance mesh on the backdrop ring, dark basalt `rock`-tinted sand, one slip face | P2 | 4,000 |
| Big dune ripples as shape | "larger ripples, roughly 10 feet (3 meters) apart", a type "not seen on Earth" (PIA20755 ✅) | Something real that does not exist on Earth | partial (ripple normal map) | Terrain shader: a 3 m ripple displacement band on sand patches (no new model) | P2 | 0 |
| Mount Sharp's layers | Mount Sharp "5.5 kilometer high" (APOD ✅; the brief said about 5 km) | Always on the horizon | partial (backdrop has the shape) | Horizontal band detail in the backdrop material | P2 | 0 |
| Curiosity's wheel tracks | Curiosity is the Gale rover (project rule) | Story hook to the landmark | missing | Trail map stamps from the landmark outward. Leave out the wheel Morse-code pattern (it spells JPL ⚠️; keeps us clear of institutional marks) | P3 | 0 |
| Twilight clouds | CO₂-ice, iridescent clouds Curiosity saw at twilight, 17 Jan 2025 (⚠️ secondary reports) | Pretty, rare, real | missing | Sky shader layer in the sunset state only | P3 | 0 |
| Reactor and landers on the horizon | 1 km keep-out (✅) | The base is not alone; scale | missing | Sections 2b and 2f, placed 1 km out at backdrop LOD | P1 | (above) |
| Relay orbiter in the night sky | The 2 crew in orbit "serving as a communications relay" (SAC21 ✅) | Comms delay story | partial (night sky has Phobos and Deimos) | A moving dot in the night sky shader | P3 | 0 |

## 7. Physics and touch: what the sandbox should let you do 🖐️

Every one does one physical thing and changes no game state (BRIEF section 1).

| Interaction | Tests | Have | P |
|---|---|---|---|
| Bump into solar panels and the dish | collision on `panel_*` and `dish` (INVENTORY 11a #17) | missing | **P1** |
| Walk into HAB 1, move around the fit-out, camera indoors | narrow spaces, camera spring arm, hero fade (INVENTORY: indoor camera "not yet checked") | partial | **P1** |
| Wipe a dusty panel | reach, prompt, a dust parameter that fades on the panel role | missing (tilt only) | **P1** |
| Open a sleep-station curtain, lie in it | contextual traversal; a lying pose clip | missing | P2 |
| Sit at the galley table / workstation | sit clip exists only for the rover (`drive_sit`) | partial | P2 |
| Carry and stack bags into a shelter wall | carry exists; stacking with snapping and settling is new | partial | P2 |
| Swap an O₂ bottle, turn a valve | a two-hand pose, a small rotating part | missing | P2 |
| Plug a cable into a socket | a cable end that follows the hand, then snaps | missing | P2 |
| Pick up a rock sample, put it in a sample bag | small carriable, crouch clip (missing, INVENTORY #18) | missing | P2 |
| Climb the lander ladder, walk the inflatable tunnel | contextual traversal | partial (ladder geometry only) | P2 |
| Water a plant, pull a radish | small interact | missing | P3 |
| Push a tool cart | `RigidBody3D` on Jolt under 3.73 m/s² | missing | P3 |

## 8. What we already have, re-checked against the real plan 🔍

| Asset | Matches the real 30-sol plan? | Action |
|---|---|---|
| `building_habitat.glb` (HDU drum) | No fixed habitat in the plan (rover instead), but HDU is a real NASA surface habitat test unit | Keep; fit out for 2 (section 3); fact card says "later missions" |
| `vehicle_rover.glb` (SEV) | Yes: the real home is a pressurised rover with suitports | Keep; it is the closest match to NASA's plan |
| `prop_oxygen_maker.glb` (electrolysis, outside) | No: O₂ is tanked; no MOXIE | Re-forge as the O₂/N₂ bottle skid by the airlock |
| `prop_water_recycler.glb` (outside) | No for the first stay; and racks live indoors | Move indoors as a rack (trade-off option) |
| `building_solar_array.glb` × 2 | Plan uses fission; solar was DRA 5.0's option | Keep and multiply by instancing (solar vs fission card) |
| `building_storm_shelter.glb` (outside) | Partly: Orion builds the shelter from bags, inside the cabin; NASA rates water walls round crew quarters highest | Keep outside as a cargo-bag store; make the sleep stations the real shelter |
| `building_greenhouse.glb` | Not in the 30-sol plan | Keep as a game choice; the Veggie unit carries the real story |
| `building_lander.glb` | No: real plan is 3 MDS landers and a 2-crew MAV | Replace (section 2b) |
| `building_dish.glb` | DRA 5.0 wants a deployable 6 m X/Ka dish for Mars (Addendum ✅); ours is 3 m | Keep; optional scale-up |

## 9. Candidate free models for the biggest items 📦

Checked on 12 Nov 2026. None of these is non-commercial. Every NASA model must have its insignia painted out (workspace rule 5). The approved look is realistic PBR ("never low-poly again", Ravindu, 12 Nov 2026), so Kenney kits are **blockout only**.

| Model | Source and licence | Size | Use | Verdict |
|---|---|---|---|---|
| Habitat Demonstration Unit, parts 1 and 2 | NASA 3D Resources, on disk `assets-cache/nasa-3d/fixed/`; "free and without copyright" (repo README ✅) | 2,264 and 4,320 tris | Shell reference | Shell only, no interior; we already forged a better HAB 1 |
| Crew Lock Bag | NASA 3D Resources GitHub `3D Models/Crew Lock Bag/Crew Lock Bag.glb` (609 KB) ✅ | ⚠️ not inspected | Interior stowage | Good candidate |
| Orbital Replacement Unit | Same repo, 586 KB ✅ | ⚠️ | A rack part to swap | Candidate for life-support rack faces |
| RASSOR (regolith digging robot) | Same repo, 6.3 MB ✅ | ⚠️ | Regolith bags, berms, cargo robot | P3 candidate; decimate |
| Space Exploration Vehicle | Same repo, 22 MB ✅ | ⚠️ | Reference for our rover | Too heavy to ship; reference |
| Z2 Spacesuit | Same repo, 17 MB ✅ | ⚠️ | Suit stand reference | Reference only (crewmate reuses the hero) |
| Mars Reconnaissance Orbiter (A) | Same repo, 2.7 MB ✅ | ⚠️ | Cinematic relay orbiter | P3 |
| ISS (E) (Internal) | Same repo, 8 split 7z parts, about 304 MB ✅ | | ECLSS rack and galley reference | Over the "ask first" size: ask Ravindu before any download |
| InSight lander, Viking lander | Same repo ✅ | | Panel reference only | **Never place at Gale** (InSight is at Elysium Planitia, Viking elsewhere) ⚠️ |
| Kenney Space Station Kit | On disk, CC0 (License.txt ✅) | bed-single 0.5 × 0.35 × 1.0 m, 56 tris; table, chairs, computers, containers, pipes, doors | Room blockout | Toy scale and low-poly: blockout, then replace by forge |
| Quaternius Nature Crops | On disk, CC0 (pack page ✅) | Tomato, Beet, Carrot, Flower, Lettuce, Wheat, 4 stages each | Radish (from Beet), tomato, zinnia | **Use** (as lettuce already is) |
| Poly Haven props | CC0, API listing saved `pages/missing/polyhaven-models.json` ✅ | `medical_box` 3,718; `metal_toolbox` 14,228; `korean_fire_extinguisher_01` 9,913; `metal_office_desk` 6,898; `mounted_fluorescent_lights` 17,820; `long_life_food` 4,712; `plastic_broom` 18,736; `industrial_storage_cart` 18,902 (Poly Haven polycount) | Photo-real small props | Good match for the look; decimate to under 4,000 and map to roles |
| Veggie, APH, ECLSS racks, UWMS toilet, FSP reactor, MDS lander, MAV | No free model found ❌ (NASA 3D Resources list checked in full: 227 models) | | | Forge recipes (sections 2 to 5) |

## Decided by Ravindu (12 Nov 2026)
- Crew of 2 on the surface (NASA SAC21: "only two of the four Mars crew" explore the surface for 30 sols). The 4-crew column stays for comparison only.
- Home is HAB 1, fitted for 2 (fact card: NASA's plan lives in the pressurised rover).
- Power: solar and the 10 kW fission reactor together. The reactor is not flown yet: NASA's KRUSTY prototype ran 28 h at full power in Nevada (20 to 21 Mar 2018, https://www.nasa.gov/news-release/demonstration-proves-nuclear-fission-system-can-provide-space-exploration-power/), and Fission Surface Power targets a reactor at the launch pad in the early 2030s (https://www.nasa.gov/centers-and-facilities/glenn/nasas-fission-surface-power-project-energizes-lunar-exploration/). If the team wants only flown hardware, drop the reactor and keep solar.
- New colour roles approved: a magenta grow light (Veggie red and blue LEDs) and red romaine lettuce.

## 10. Risks and decisions for the team ⚠️

1. **Crew of 2 (decided).** Fact cards, the HUD crew icons, the shelter and food figures follow the 2-crew column. The other 2 crew are in orbit: a voice on the radio, no model.
2. **The real home is the rover.** Keep HAB 1 as the home and say in a fact card that NASA's first crew will live in the rover; or make the rover the home. Team decision.
3. **Solar or fission.** The real plan is fission at 1 km. Solar needs about 580 m² for 10 kW. Both are real NASA options (DRA 5.0 studied solar): a strong trade-off card, but it is a game rule, decided on 14 Nov.
4. **Draw calls.** 195 against a 150 budget before any interior. Load HAB 1's interior as its own scene when you step inside, and hide the outside; instance every repeated panel, bag and plant.
5. **DESIGN.md roles.** A magenta grow light and red-leaf lettuce need new roles; changing the look is Ravindu's call (`npx design.md diff`).
6. **Grow light cost.** One more lit light per Veggie unit; keep it unshadowed, one per room.
7. **Unsourced sizes** to fix if time allows: MDS deck height, MAV overall height (figure labels only), ISPR size (Wikipedia), UWMS size (press), amine scrubber size (secondary), habitat heating power (❌, as before).
8. **No NASA insignia** on any NASA GLB we import; no JPL Morse code in Curiosity's tracks.

## 11. Sources saved for this study 📚

`pages/missing/`: NTRS 20210026448 (SAC21 short stay), 20210026439 (MAV 2021, 2 crew), 20190001229 (MAV 2019, 4 crew), 20160004402 and 20170003405 (human Mars lander, HIAD), 20250000841 (Fission Surface Power trades, 2025), 20050194571 (Mars solar power system, Glenn), 20200001084 (oxygen storage tanks, HPGT sizes), 20170002287 and 20130014018 (RadWorks storm shelter, water wall), 20130011191 (Orion CAMRAS), 20220006163 and 20260004140 (ISS water status), 20100017014 (ISS crew quarters), 20160005059 (Veggie spec sheet), 20150021428 (exercise devices), 20230008751 (VEG-05 abstract); NASA Veggie fact sheet 2019; NASA Plant Habitat-04 sheet; nasa.gov CHAPEA habitat; ICON Mars Dune Alpha release (6 Aug 2021); science.nasa.gov: InSight solar panel (PIA22736), InSight power generation 2022, InSight power boost, InSight dust storm 2022, Namib Dune (PIA20281), Bagnold dunes migrate, two sizes of ripples (PIA20755), ventifacts (sols 3417 to 3418), APOD gator-back rocks; nasa.gov VEG-05 tomatoes (20 Apr 2023); NASA 3D Resources tree and README; Poly Haven model listing.

Already saved in the workspace and reused: ICES-2023-265 (NTRS 20230002103, `ws:pages/agent-power/`), DRA 5.0 (`ws:pages/agent-power/dra5-sp-2009-566.txt`), BVAD 2022 (`ws:pages/bvad.txt`, Table 3-8 at lines 2140 to 2164), NORS (NTRS 20110012004, `ws:pages/agent-oxygen/`), NASA ECLSS fact sheet (`ws:pages/agent-oxygen/`), NASA CO₂ brief (`ws:pages/co2/`), suitport (NTRS 20120011640, `ws:pages/agent-habitat/`); and `pages/sizes/` (DRA 5.0 Addendum excerpt, HDU NTRS 20110013501).

Not fetched (blocked or secondary only, marked ⚠️ above): JPL streambed release (JPL blocks curl), UWMS size, ISPR size, twilight clouds, Murray thickness, amine scrubber size.

## Open questions ❓
- MDS deck height and the overall MAV height, from a NASA drawing.
- How the first crew get from the lander deck to the ground (ladder, lift or crane).
- A NASA night-time power figure for a small 2-crew habitat or pressurised rover.
- Real size of an amine swing-bed scrubber and of the UWMS toilet from a NASA page.
