# The hero's suit and how it moves 🧑‍🚀

Researched 12 Nov 2026 after Ravindu's playtest: the hero "feels like a toy/alien: a thin guy who freely walks on Mars who looks like he came from cyberpunk, I cannot see any life support", and "his jumping and walking motions look weird". The generic rules this produced are in `tooling/skills/suited-locomotion/SKILL.md`. This file holds the facts, the asset options and the recommendation for this hero.

Saved sources: `design/research/pages/suit/` (`agent-1/` suits, `agent-2/` gait, `agent-3/` assets and licences, `footsteps/` engine docs). Every ✅ below was found in the saved file with `kwic.py`. ⚠️ means read off a graph, reported only, or our own arithmetic. ❌ means not found and left out.

> **TL;DR.** A real planetary suit is a white, bulky, 1 m wide shell with a fridge-sized backpack, a bubble helmet and a gold sun visor, and it weighs 64 to 177 kg. People in one walk slowly (70 to 90 steps a minute), with wide feet, nearly straight knees (about 25 degrees of bend, not 60) and arms held forward; they take two or three steps to stop, and jump small, with both feet, tipping backwards. Our hero has none of that: no backpack, a slim body, a stock city walk played slow and a sprint clip with 121 degrees of knee bend. **Recommendation:** rig NASA's own Astronaut model (already on disk, near T-pose, backpack, gold visor, 6.4k triangles) with the CC0 Universal Animation Library skeleton, then make a suited walk, lope and hop from those clips in Blender.

---

## 1. What a real suit looks like and weighs 🎒

**Kid version:** a spacesuit is a tiny spaceship you wear. The box on the back is what keeps you alive.

| Part | Fact | Source | Status |
|---|---|---|---|
| Backpack (PLSS, "portable life support system") | envelope "as much as 0.75 m x 0.56 m x 0.254 m" | NTRS 20150009500 (`sizes.md`) | ✅ |
| Backpack mass | Apollo 110 lb, ISS EMU 141 lb, Artemis prototype xEMU about 209 lb dry plus 16.3 lb of oxygen and water | Ogilvie 2026, NTRS 20260003038, `agent-1/ntrs-20260003038-mars-mass.txt` | ✅ |
| Whole suit mass | xEMU 391 lb (177 kg); Mark III 64 kg (120 kg as tested with its backpack mock-up); ISS EMU about 319 lb (145 kg); Apollo A7L suit alone 19.7 kg | same; NASA fact sheet 2019 (`nasa-fs-2019-emu.txt`); Biomedical Results of Apollo (`ntrs-19760005607.txt`) | ✅ (the xEMU paper gives three slightly different totals) |
| Mars suit target | "230 lbm is recommended as a starting maximum Mars suit mass" (104 kg) | Ogilvie 2026 | ✅ |
| Chest unit | the "Display and Control Unit" mounts "on the front of the HUT", about 7.6 lb; the EMU's DCM "Provides Caution & Warning System messages, EMU parameters, and EMU controls" | Ogilvie 2026; NTRS 20140009556 | ✅ (size ❌) |
| Torso | a hard upper torso (HUT); new suits are "rear entry": you climb in through the back, and the backpack is the door | NASA spacesuit basics; Z-2 abstract NTRS 20150022144; xEMU slide NTRS 20200001257 | ✅ |
| Joints | Z-2: "2-bearing rolling convolute shoulder", "waist bearing", "2 bearing soft hip thigh", "boots with ankle bearings" | NTRS 20150022144 | ✅ |
| Helmet | Apollo: a polycarbonate bubble on a neck ring, about 23 x 23 x 25 cm outside (Armstrong's). Artemis: "elliptical shape that provides a better view of the ground", "HD Video and Lights" | NASM helmet pages; NASA basics; NTRS 20200001257 | ✅ (bubble diameter ❌) |
| Sun visor | "The sun visor has a special gold coating that works like the astronaut's sunglasses"; Axiom's AxEMU: "Gold coating" on a "two-part deployable visor" | NASA basics; Axiom 2025 | ✅ |
| Size | a suited person is about 1 m wide (99th percentile); Armstrong's A7L on its mannequin is 170 x 82 x 28 cm; the EMU fits people from 1.52 to 1.88 m tall | NTRS 20090032975; NASM A19730040000; NASA fact sheet | ✅ |
| Colour | "The white outer layer reflects heat from the sunlight"; Axiom: a Moon suit "must be white to reflect heat" (its dark cover is "for display purposes only") | NASA basics; Axiom 2023 | ✅ |
| Telling crew apart | "Some suits are plain white and some have stripes"; Apollo commander's red stripes, "first used during the Apollo 13 mission"; ISS today: "crew member 1, wearing the suit with red stripes ... crew member 2, wearing the unmarked suit"; Hubble crews used solid, broken and "barber pole" stripes | NASA basics; NASM Cernan; NASA blog 1 Sep 2026; NASA SVS 13566 | ✅ |
| Where stripes sat on Apollo (arms, legs, helmet) | only Wikipedia | | ❌ |

**For our hero:** white suit, a cool accent band where real crews wear their stripes (our rule: never red or orange), a gold visor down, a backpack about 0.7 x 0.55 x 0.25 m, a chest box, rings at the joints, about 0.9 to 1 m wide.

---

## 2. How people move in a suit 🚶

**Kid version:** in a stiff, heavy suit you take slow, short, wide steps and keep your knees nearly straight. Stopping takes a few steps.

| Measure | Value | Condition | Source | Status |
|---|---|---|---|---|
| Normal walk on Earth | 115 to 120 steps/min, stride 1.5 to 1.7 m | unsuited adults | Pirker 2017 | ✅ |
| Normal knee bend in swing | about 60 degrees | unsuited | gait teaching slides (Newcastle) | ⚠️ weak source |
| Suited walk at 1 g | 88.8 steps/min (unsuited 98.7), step 0.595 m (0.631), stride 1.243 m, 1.06 m/s, feet 0.190 m apart while walking (0.081), 0.355 m standing (0.263), "lower clearance heights" | Mark III, one subject | Cullinane 2017 | ✅ |
| Suited cadence on the Moon | "about 35" strides/min rising to "better than 40" (70 to 80+ steps/min); fastest "105 steps/min" carrying a load | Apollo 16 | NTRS 19730008098 | ✅ |
| Suited stride on the Moon | walking "in excess of 4 feet", hopping "less than 3 feet"; 3.4 to 4.6 ft on long traverses. Apollo 15 measured "about 30 inches" for the two-step stride | Apollo 16 and 15 | NTRS 19730008098, 19730008096 | ✅ (the two missions disagree) |
| Feet apart | "spread apart 10 to 15 inches" (0.25 to 0.38 m) | Apollo 15 | NTRS 19730008096 | ✅ |
| Knee bend in a suit | peaks near 20 to 28 degrees in swing, 5 to 20 at contact | Mark III at 29.6 kPa, lunar gravity, 10 to 30% slope | Norcross 2010, Fig. 26 | ⚠️ read from the graph (I opened the figure) |
| Why so stiff | pressure "made it challenging to fully buckle the knee joint, even when standing on one leg" | Apollo | Carr and McGee 2009 | ✅ |
| Arms | "The elbow joint center is consistently in front of the body" | xEMU tests | NTRS 20240005868 | ✅ |
| Walk to run | suited crews left the walk at Froude 0.36 ± 0.11 (unsuited about 0.5). For a 0.9 m leg on Mars: 1.10 m/s | Apollo, 38 gait events | Carr and McGee 2009 | ✅ number, ⚠️ our Mars arithmetic |
| Gaits | "flat-footed walk, lope, skip" and a "two-footed, kangaroo hop", the hop "used only in play or downhill" | Apollo | ALSJ lunar gaits | ✅ |
| Flight in a walk | "some 'floating,' or times at which both feet were off the ground" | Apollo 15 | NTRS 19730008096 | ✅ |
| Lower gravity | at the same speed, duty factor about 10% lower and relative stride 16% shorter (0.25 to 1 g); on Mars-level gravity "the step period was longer" | unsuited | Donelan and Kram 1997; Lacquaniti 2017 | ✅ |
| Stopping, turning | "two or three steps to come comfortably to a stable stationary position"; "a couple of steps" to change direction | Apollo 11 | ALSJ | ✅ |
| Picking things up | hop, bend the knees, grab, get up, "all done in one continuous motion"; a good pick-up leaned about 25 degrees; six falls on Apollo 16 | Apollo 16 | NTRS 19730008098 | ✅ |
| Getting up | "on all fours, leaning forward, pushing back with his hands ... to his knees and then to his feet" | Apollo 16 | same | ✅ |
| The jump | Young "bends his knees slightly, springs about a half meter", 1.45 s in the air, about 1.17 m/s take-off, 0.42 m peak | Apollo 16, Moon | ALSJ | ✅ |
| The same jump on Mars | 1.17 m/s gives 0.18 m and 0.63 s in the air | arithmetic, `h = v²/2g`, `t = 2v/g` | | ⚠️ ours |
| Tipping back | "tendency to tip over backwards on a high jump"; Duke "landed on his PLSS" | Apollo | ALSJ | ✅ |
| A measured suited walk in Mars gravity (cadence, stride) | only in figures of NASA's 2008 Mark III test ("extremely limited on Mars") | | NTRS 20080014853 | ❌ numbers |

---

## 3. What is wrong with the hero now (measured 12 Nov) 🔧

Measured with a headless Godot script over `models/character_astronaut.glb` (the script read the clips the same way `hero_model.gd` does).

1. **The look.** Slim armour, an opaque face plate, no backpack, copper trim. Nothing says life support.
2. **The walk is a city walk.** `Walk` (1.333 s) was made for 1.29 m/s at 1.5 steps/s with a 1.73 m stride and 72 degrees of knee bend. At our 1.0 m/s it plays at 0.78 speed, so 1.16 steps/s: the same city walk in slow motion.
3. **Hurry blends in a sprint.** `Run` (0.792 s) was made for 2.75 m/s, with 121 degrees of knee bend and a 0.54 m foot lift. At 1.6 m/s it is about a fifth of the pose.
4. **No body bob.** The `Body` bone's height moves by 0.001 in either clip, so the hero glides.
5. **The blend lets the feet drift.** `hero_model.gd` sets `gait.sync = true`, which in 4.7 is `SYNC_MODE_INDEPENDENT` ("equivalent to the previous sync = true behavior"): the 1.333 s walk and 0.792 s run run out of phase, so in a blend neither clip's feet plant. `SYNC_MODE_CYCLIC_MUTABLE` keeps them in step (class reference, `footsteps/godot47-class-animationnodeblendspace1d.rst`).
6. **Footprints come early.** `player.gd` `_steps()` marks a step when the lower foot changes. In `Walk` that swap happens while the new foot is still 0.05 m up, 0.19 to 0.25 s before it lands (longer at the slowed 1.0 m/s); in `Run`, 0.14 m up and 0.14 to 0.17 s early.
7. **The hop** is the idle pose with the legs folded by code: no arm swing, no lean, no landing.

---

## 4. Asset options 📦

| Option | Licence | Triangles | Rig and clips | Verdict |
|---|---|---|---|---|
| **NASA "Astronaut"** (science.nasa.gov 3D resources, "Source DigitalSpace Corporation"); already on disk: `assets-cache/nasa-3d/astronaut.glb` | NASA: 3D model files "generally are not subject to copyright"; logos "are not in the public domain"; repo README: "free and without copyright" ✅ | 6,381 | none. Near T-pose (arms about 10 degrees down), one body with the backpack plus 14 visor and helmet parts | **Best route.** White EMU shape, backpack, gold visor, no face. Draco: re-save with `--compress false`. 74 units tall: scale to 1.89 m. Its 1024 px texture holds a NASA logo, US flags, a mission patch and a red stripe: paint them out, the stripe becomes our cool band. Third-party source ("DigitalSpace") is unmarked as copyrighted, so ⚠️, credit both |
| NASA "Z2 Spacesuit" | same NASA terms | 30,904; 3 x 4096 px textures; 16 MB | none; statue pose (arms bent) | Good Mars-suit shape (bubble helmet, rear hatch) but bent pose, NASA logo on the hatch, black visor. Rigid parts only. Second choice |
| NASA "Mark III Spacesuit" | same | 69,202 | none; arms reaching forward | Grey, NASA logo, too heavy for a phone. No |
| Sketchfab "astronaut" by Antropik (`482bf876...`) | CC Attribution ✅ (API) | 19,584 | 5 clips, rig details behind login | Most realistic CC model: white suit, gold visor. NASA logo and flag in the texture. Needs a login to download. Backup to the NASA model |
| Sketchfab LasquetiSpice "Animated Astronaut" and its 15 copies | CC-BY label | 58,312 | 4 clips | Avoid: the earliest copy says "Cool astronaut I found!", origin unknown |
| Other Sketchfab CC models (IvanPetrov, Mrhigh, LCDM, HatchXR, shofiq) | CC-BY | 8.6k to 134k | | Face behind the visor, too heavy, cartoon, or a relabelled Quaternius. No |
| Sketchfab CC0 suits | | | | ❌ none exist (API search) |
| Quaternius "Humanoid Rig" Spacesuit | CC0 (pack page) | | unknown | Google Drive still answers "Quota exceeded". Same slim sci-fi suit anyway. Skip |
| **Quaternius Universal Animation Library 1 and 2, Standard** | "License CC0" on the pack pages ✅ | mannequin | 65-bone Unreal-style skeleton (`pelvis, spine_01..03, thigh_l, calf_l, foot_l, ball_l` ...), 43 clips each: `Walk_Loop` (1.333 s), `Jog_Fwd_Loop`, `Jump_Start`, `Jump_Loop`, `Jump_Land`, `Interact`, `Push_Loop`, `Sitting_*`, `Driving_Loop`, `Crouch_*`, `PickUp_Table`, `Fixing_Kneeling`; UAL2 adds `Walk_Carry_Loop`, `ClimbUp_1m`, `Farm_*` | **Use for clips.** Covers every gap (jump, carry, sit, drive, kneel). No tired or heavy walk in Standard. Not our current skeleton: rig the new mesh to it instead of retargeting. 15 and 17 MB zips; the GLBs (7.6 and 8.1 MB) sit in the session scratchpad, not in the project |
| Mixamo | Adobe: "Any type of free distribution of character or animation raw files" is not allowed ✅ | | | Clips may ship inside a game but not as files in a public repo. No |
| CMU motion capture | "may be copied, modified, or redistributed without permission" ✅ | | ASF/AMC; subject 17 trials 8 and 9 "muscular, heavyset person's walk" | A heavy-walk reference, needs conversion and retargeting. Reference only |
| Bandai Namco motion dataset | CC BY-NC 4.0 | | has "tired" styles | NonCommercial: no |
| A CC0 or CC-BY low-gravity or astronaut walk clip | | | | ❌ not found |
| Kenney Mini Characters | CC0 | 771 | 7 bones | Chibi. No |

**Rigging the NASA statue headless (tested by the asset agent in Blender 5.2):** automatic weights fail on the raw import ("Bone Heat Weighting: failed to find solution", every vertex unweighted) because the file splits every triangle along its seams. After Merge by Distance (height x 1e-5) the Astronaut came out with 1.1% of vertices unweighted (Z2: 11.1%). The leftovers and the rigid helmet and visor parts get bound whole to one bone (Head). Bending was not yet rendered. Script: the scratchpad's `scripts/autorig.py`.

**The fallback: dress the current Quaternius model.** A forge backpack (box, 0.7 x 0.55 x 0.25 m, bevelled) and a chest box on `BoneAttachment3D`s at `Chest`, a bubble helmet with a gold visor over `Head`, the copper re-mapped to the band colour in DESIGN.md `kit`. Thicker limbs by bone scale do not work cleanly: a bone's scale passes to its children, so a fat upper arm makes a giant hand. Cost: about 2 to 3 hours, and it still leaves the slim armour plates, the face plate under the bubble and the same unsuited clips. It fixes the look only halfway and the motion not at all.

---

## 5. Recommendation for this hero ✅

### Model route
1. **Mesh:** `assets-cache/nasa-3d/astronaut.glb`, re-saved without Draco, scaled to 1.89 m, merged by distance, texture repainted (logo, flags, patch gone; the red stripe becomes the accent band from DESIGN.md). A forge recipe does all of it headless.
2. **Rig:** the UAL skeleton fitted to the mesh's T-pose (move the joints to the suit's shoulders, hips, knees), automatic weights, helmet, visor and backpack weighted 1.0 to their bone. Then every UAL clip plays on it with no retargeting. `player.gd` `RIG` changes names only (`pelvis`, `thigh_l`, `calf_l`, `foot_l` ...).
3. **Fallback if the weights bend badly at the shoulders or hips:** rigid parts per bone (the suit is stiff anyway), or the dressed Quaternius model above for this phase only.
4. Downloads: the UAL zips are 15 and 17 MB, so Ravindu says yes before they go into `assets-cache/` (project rule), with `ASSETS.md` and `CREDITS.md` rows the same day.

### Clips (made in Blender from UAL, measured, then filmed from the side)
| Clip | From | Changes |
|---|---|---|
| `idle` | `Idle_Loop` | arms a little out and forward, weight even on wide feet |
| `walk` (suited walk, 1.0 m/s) | `Walk_Loop` | knee peak capped near 28 degrees, stance 0.25 m, arms forward and out, foot lift lowered, hips rise and fall, stride cut so 1.0 m/s comes at 1.5 steps/s (stride about 1.33 m) |
| `lope` (hurry, 1.6 m/s) | `Jog_Fwd_Loop` | a long, slow lope with a short flight: about 1.75 steps/s, knee near 30 to 35 degrees, no sprint arms |
| `hop_start`, `hop_air`, `hop_land` | `Jump_Start`, `Jump_Loop`, `Jump_Land` | shallow crouch ("bends his knees slightly"), both feet, arms swing forward, a little forward lean, air clip stretched to the arc's time (`contextual-traversal` rule 9) |
| `carry`, `sit`, `drive`, `kneel`, `interact` | `Walk_Carry_Loop`, `Sitting_*`, `Driving_Loop`, `Fixing_Kneeling`, `Interact` | knee and lean limits as above; picking up is kneel or hop-kneel, never a waist bend |
| `get_up` (only if falls are added) | `LayToIdle` | via hands and knees |

Every gait clip starts on the left foot's touchdown, the blend space uses `SYNC_MODE_CYCLIC_MUTABLE`, and footsteps fire from a baked contact phase or the low-and-still test (skill section 4), never from the lower-foot swap.

### reality.json rows to add or change
| Row | Real range | Value | Source |
|---|---|---|---|
| `hero.cadence.walk` (new, steps/s) | 1.2 to 1.5 | 1.5 | Apollo 16 70 to 80+ steps/min; Cullinane 88.8 steps/min suited at 1 g |
| `hero.stride.walk` (new, m, two steps) | 1.04 to 1.4 | 1.33 | Apollo 16 3.4 to 4.6 ft; Cullinane 1.243 m. Value = 1.0 m/s / 1.5 x 2 |
| `hero.cadence.hurry` (new) | 1.5 to 1.75 | 1.75 | Apollo 16 fastest 105 steps/min; an estimate for Mars |
| `hero.knee.swing` (new, degrees, peak) | 20 to 30 | 28 | Norcross 2010 Fig. 26 (⚠️ graph); now 72 (walk) and 121 (run) |
| `hero.stance.width` (new, m, feet apart while walking) | 0.19 to 0.38 | 0.25 | Cullinane 2017; Apollo 15 |
| `hero.froude.walk_run` (new) | 0.25 to 0.47 | 0.36 | Carr and McGee 2009. `player.gd` now uses 0.4 and 0.6 (unsuited, Alexander and Jayes) for the gait bands: switch to this row |
| `hero.jump.time` (new, s in the air) | 0.5 to 0.63 | 0.63 | from `hero.jump.hop` and gravity: 2 x 1.17 / 3.73 |
| `hero.lean.max` (new, degrees) | 25 to 35 | 25 | Apollo 16 pick-ups |
| `hero.contact.height` (new, m, foot above floor when a step fires) | 0 to 0.02 | 0.02 | estimate: a foot that is down; a check, not a feel number |
| `hero.width` (change) | 0.8 to 1.0 | 0.95 | NTRS 20090032975; the NASA model's real breadth once scaled |
| `hero.speed.walk`, `hero.speed.hurry`, `hero.stop`, `hero.jump.hop` | | keep | still right |

---

## 6. Left out ❌ and open questions ❓
- Not found: xEMU or AxEMU backpack size, chest unit size, glove and boot sizes, Z-2 total mass, helmet bubble diameter, xEMU colour bands, a primary source for AxEMU helmet lights, suit knee torque, suited cadence and stride at Mars gravity, arm angle while walking.
- Left out: AxEMU "red trim" and "grey knee patches" (a press snippet only), where Apollo stripes sat (Wikipedia only).
- ❓ Does the team want the NASA-shaped suit (white, gold visor, backpack) even though the hero then looks like an ISS spacewalker rather than a new Mars suit? The Z-2 is the Mars-suit shape but needs much more work.
- ❓ Does a fall and get-up belong in the sandbox, or only later?
