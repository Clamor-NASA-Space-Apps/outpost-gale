# Assets for the sandbox: what we downloaded and what it holds

Checked 12 Nov 2026. Every file below sits in `assets-cache/` at the workspace root, not in this project: the factory session imports the ones it picks. Credits are in `assets-cache/CREDITS.md`. Renders of each asset are in `design/research/asset-previews/`.

> **TL;DR.** The hero is the **Quaternius Astronaut**: closed visor, no face, 62 bones, 24 clips, loads in Godot 4.7 as it is. It has idle, walk, run and interact, but **no jump, no carry and no sit or drive clip**, and its accent colour is copper orange, which our rules forbid (recolour it). The Ultimate Space Kit has tiltable solar panels once split in Blender, a geodesic dome, three rovers with separate wheels, a crate and a dish. The crops pack has lettuce in four growth stages plus the picked head; we converted them to GLB. The HUD font is **Exo 2**.

## 1. The astronaut (Quaternius, Ultimate Modular Men Pack) 🧑‍🚀

File: `assets-cache/quaternius/modular-men/Astronaut.glb`, 1.9 MB, from Poly Pizza (https://poly.pizza/m/3hC2i0CTuO). No Draco, no meshopt, no extensions: Godot 4.7.2 loaded it with `GLTFDocument` (4 meshes, 62 bones, 24 clips), so no `gltf-transform` pass is needed.

| Property | Value |
|---|---|
| Triangles | 10,558 (Poly Pizza's "5.3k" counts faces, most of them quads) |
| Height | 1.89 m, feet at 0, already in metres |
| Meshes | 4 skinned parts on one skeleton: `SpaceSuit_Head`, `SpaceSuit_Body`, `SpaceSuit_Legs`, `SpaceSuit_Feet` (the pack is modular: parts swap with the other ten men) |
| Bones | 62 in `CharacterArmature`: `Root, Body, Hips, Abdomen, Torso, Chest, Neck, Head`, shoulder, upper arm, lower arm, wrist per side, 4 fingers with 4 bones and a thumb with 3 per hand (46 finger bones), upper leg, lower leg, foot and a pole target (`PT`) per side |
| Same skeleton as | `quaternius/people/worker.glb` and `business_man.glb` (all 62 bone names match, both have the same 24 clips), so clips can be shared between them |
| Textures | none: flat colours per material |
| Helmet | **closed.** A dark opaque visor plate, no face anywhere (see `asset-previews/astronaut-helmet-front.png`). Two breathing hoses curve from the cheeks, a ridge runs over the top |
| Look | a slim, armoured sci-fi suit, not a bulky NASA EVA suit. **No backpack** (no life-support pack on the back) |

Materials (base colour converted to sRGB hex; all metallic 0.4, roughness 0.42):

| Material | Colour | Where |
|---|---|---|
| `SciFi_Main` | `#3b4b49` dark teal grey | suit body, legs |
| `SciFi_MainDark` | `#2a3538` darker teal | back, legs, visor |
| `SciFi_Light` | `#a19893` warm light grey | armour plates |
| `SciFi_Light_Accent` | `#93542b` **copper orange** | trim, boots, helmet bands |
| `Grey` | `#383838` | small parts |

The accent breaks the rule "the astronaut is never red or orange". Five named materials make it a `kit` mapping in DESIGN.md, not a model edit.

### The 24 clips

| Clip (`CharacterArmature\|...`) | Length (s) | Note |
|---|---|---|
| `Idle` | 1.67 | standing loop |
| `Idle_Neutral` | 1.67 | standing loop (rendered: upright, arms at the sides); how it differs from `Idle` was not compared |
| `Walk` | 1.33 | |
| `Run` | 0.79 | |
| `Run_Back`, `Run_Left`, `Run_Right` | 0.83, 0.79, 0.79 | strafing |
| `Interact` | 1.25 | one arm reaches forward, as if pressing a button |
| `Wave` | 1.67 | one arm up |
| `Roll` | 1.33 | a forward roll on the ground, not a jump |
| `HitRecieve`, `HitRecieve_2` | 0.54, 0.54 | a flinch from a hit |
| `Death` | 1.04 | not rendered; PG "mission lost" probably does not want it |
| `Idle_Gun`, `Idle_Gun_Pointing`, `Idle_Gun_Shoot`, `Gun_Shoot`, `Run_Shoot` | 1.67, 1.67, 0.67, 0.58, 0.83 | weapon poses: not for this game |
| `Idle_Sword`, `Sword_Slash` | 1.67, 1.00 | weapon: not for this game |
| `Kick_Left`, `Kick_Right`, `Punch_Left`, `Punch_Right` | 0.92, 0.92, 0.83, 0.83 | fighting: not for this game |

## 2. The fallback: Kenney Mini Characters 🧸

On disk since 10 Nov (`assets-cache/kenney/mini-characters/Models/GLB format/`, CC0). Checked `character-male-a.glb`: 771 triangles, **0.67 m tall** (a big-headed chibi; scale about 2.7 times for an adult), 7 bones (`root, leg-left, leg-right, torso, arm-left, arm-right, head`: no knees, elbows or hands), one texture atlas (`colormap`). No helmet, no astronaut among the 20 people.

All 32 clips, length in seconds: `static` 0.1, `idle` 1.33, `walk` 0.67, `sprint` 0.5, `jump` 0.5, `fall` 0.33, `crouch` 0.17, `sit` 0.17, `drive` 0.17, `die` 0.33, `pick-up` 0.33, `emote-yes` 0.67, `emote-no` 0.67, `holding-right` 0.17, `holding-left` 0.17, `holding-both` 0.17, `holding-right-shoot` 0.2, `holding-left-shoot` 0.2, `holding-both-shoot` 0.2, `attack-melee-right` 0.42, `attack-melee-left` 0.42, `attack-kick-right` 0.53, `attack-kick-left` 0.53, `interact-right` 0.67, `interact-left` 0.67, `wheelchair-sit` 0.17, `wheelchair-look-left` 0.33, `wheelchair-look-right` 0.33, `wheelchair-move-forward` 0.5, `wheelchair-move-back` 0.5, `wheelchair-move-left` 0.5, `wheelchair-move-right` 0.5.

It covers every action the sandbox needs, but it needs a helmet and a backpack attached to its head and torso bones, and with 7 bones its motion is stiff next to the Quaternius rig.

## 3. Verdict: the hero is the Quaternius Astronaut ✅

It already has a visor and no face, real human proportions at 1.89 m, a full skeleton with fingers, and authored clips for the actions players do most. The Kenney character stays the fallback only if the missing clips below cannot be filled.

| Sandbox action | Quaternius clip | Kenney fallback clip | Gap and how to fill it |
|---|---|---|---|
| idle | `Idle` (or `Idle_Neutral`) | `idle` | none |
| walk | `Walk` | `walk` | none |
| run | `Run` | `sprint` | none |
| jump (a suited hop) | **none** (`Roll` is a ground roll) | `jump`, `fall` | retarget a jump from the Universal Animation Library (below), or a short code-posed crouch and rise (`character-life` skill: code fallback for a missing clip) |
| interact (press, wipe a panel) | `Interact` | `interact-right` | none |
| carry a crate | **none** | `holding-both`, `pick-up` | an upper-body pose on `Walk` and `Idle`: arms held forward, by a bone override or a one-frame pose |
| get in, drive, sit | **none** | `sit`, `drive` | a one-frame seated pose (Kenney's `sit` and `drive` are static too, 0.17 s) |
| extra | `Wave` (greet a crewmate or PIP), `HitRecieve` (stumble in a storm gust) | `emote-yes`, `emote-no` | |

**The cleanest way to fill the gaps:** Quaternius' Universal Animation Library (CC0, 120+ clips including sitting, pushing and jumps; saved pages in `research/godot-build/pages/agent-3/itch-ual*.html`). It uses a different, humanoid rig, so Godot's import retargeting (`BoneMap` to `SkeletonProfileHumanoid`) has to map both skeletons; the bone names here (`Hips, Abdomen, Torso, Chest, Neck, Head, UpperArm.L, LowerArm.L, Wrist.L, UpperLeg.L, LowerLeg.L, Foot.L`) map cleanly. Not downloaded: it comes from itch.io, which answered "429 Too Many Requests" on 12 Nov 2026, and its size is not stated. The pack's Google Drive also holds a **"Humanoid Rig" version of the Spacesuit** (`Humanoid Rig/Individual Characters/FBX/Spacesuit.fbx`), which may share that humanoid rig. Drive refused downloads that day (quota). Retry both before 14 Nov if the team wants authored jump and sit clips.

The Space Kit's own astronauts carry `Jump`, `Jump_Idle` and `Jump_Land` on a skeleton that shares 41 of its 43 bone names with ours, but they are cartoon animals about 3 m tall with a pistol, so their clips would need retargeting too.

## 4. Ultimate Space Kit (Quaternius) 🛰️

87 models in `assets-cache/quaternius/space-kit/glb/`, 12 MB, one GLB per Poly Pizza page (file names end in the Poly Pizza id). The pack's Drive folder lists 92: Poly Pizza lacks `Roof_Opening`, `Roof_VentL`, `Roof_VentR`, `Enemy_Small` and the red panda astronaut.

What holds for every model:
- **One material, `Atlas`, and one shared 512 px palette texture** (5 KB, the same file in every GLB). It is the Kenney 2.x kind of atlas, so `tools/kit-roles.mjs` maps its colours to DESIGN.md roles.
- No Draco or other extensions: Godot 4.7 loads them as they are (tested: dome, solar structure, rover).
- Real size in metres, Y up. The "Size" column below is width x height x depth in metres, from the node transforms.
- **Origins are not always on the ground:** `Solar_Panel` sits 3.6 m up and `Roof_Antenna` and `Roof_Radar` 4.1 m up (they are meant for roofs), and the pickups float. Re-origin them in Blender or with an offset node.

What the sandbox wants from it:

| Need | Model | Triangles | Size (m) | Separate parts? | Note |
|---|---|---|---|---|---|
| Solar array | `Solar_Panel_Structure` | 1,432 | 4.00 x 3.07 x 4.00 | **no, one mesh** | four panels on an angled base. Each panel is its own mesh island (cell grid and frame), apart from the base, so "separate by loose parts" in Blender gives four tiltable panels |
| Solar panel, single | `Solar_Panel_Ground` | 372 | 1.29 x 1.10 x 1.67 | no, one mesh | one panel on two legs; panel and legs are separate islands, so it splits the same way |
| Solar panel, roof pair | `Solar_Panel` (`SolarPanel_Roof`) | 812 | 2.73 x 1.70 x 1.73 | no, one mesh | two panels on four legs, origin 3.6 m up |
| Greenhouse shell | `Geodesic_Dome` | 1,432 | 8.53 x 5.28 x 8.53 | no | the panes are **opaque dark grey atlas colour**, not glass. Whether the inside is modelled was not checked |
| Habitat | `Base_Large`, `Building_L`, `House_Long`, `House_Cylinder`, `House_Single`, `House_Open`, `Connector` | 508 to 2,940 | 3.4 to 8.5 wide, about 4.3 high | no | in the renders the round doors look closed (not checked for openings); `House_Open` has an open end and `Connector` is an open tube |
| Rover | `Rover` (`Rover_1`), `Rover` (`Rover_2`), `Round_Rover` | 7,052 to 8,032 | 4.6 to 5.8 wide, 4.9 to 5.2 high | **yes: every wheel is its own node** (4, 6 or 4 wheels) | wheels can spin; the body has a dish and an antenna |
| Crate | `Pickup_Crate` | 1,348 | 0.87 x 0.86 x 0.90 | no | yellow and grey sci-fi crate; origin at its centre (0.43 m below to the floor) |
| Antenna, dish | `Roof_Antenna`, `Roof_Radar` | 492, 972 | 1.4 x 3.5 x 1.4, 1.6 x 2.7 x 1.7 | no | the radar is a dish on a mount; rotating it needs a split like the panels |
| Supports, ramp | `Metal_Support`, `House_Single_Support`, `Ramp`, `Stairs` | 192 to 540 | | no | |
| Rocks | `Rock` x4, `Rock_Large` x3 | 210 to 456 | 2.2 to 8.5 | no | orange-brown low-poly rocks |

Kit scale is game scale, not real scale: a rover 5 m tall is far bigger than a real crewed rover. Sizes come from `data/reality.json`, so most models get scaled there.

### Every model

| Model | Mesh nodes | Triangles | KB | Size (m, W x H x D) | Separate parts | Clips | File |
|---|---|---|---|---|---|---|---|
| Astronaut | Pistol, FernandoTheFlamingo | 7,938 | 685 | 4.65x3.24x1.27 | yes, 2 | 18 | `Astronaut__zbtPq4dOJL.glb` |
| Astronaut | Pistol, BarbaraTheBee | 8,562 | 738 | 4.65x3.22x1.21 | yes, 2 | 18 | `Astronaut__OgeSH89Nmx.glb` |
| Astronaut | Pistol, FinnTheFrog | 8,606 | 716 | 4.65x3.11x1.44 | yes, 2 | 18 | `Astronaut__0D54W8yfrA.glb` |
| Base_Large | Base_Large | 2,790 | 122 | 8.53x4.97x8.53 | no |  | `Base_Large__UyH95ZAeJ2.glb` |
| Building_L | Building_L | 2,940 | 107 | 7.80x4.31x7.79 | no |  | `Building_L__dsH7KEfuPP.glb` |
| Bullets_Pickup | Pickup_Bullets | 624 | 31 | 0.83x0.84x0.28 | no |  | `Bullets_Pickup__bTEYFxKHF9.glb` |
| Bush | Bush_2 | 1,500 | 57 | 1.82x1.60x0.62 | no |  | `Bush__tX1aT9IB1P.glb` |
| Bush | Bush_1 | 2,292 | 80 | 3.26x2.48x0.98 | no |  | `Bush__RfUP3gXj69.glb` |
| Bush | Bush_3 | 640 | 28 | 1.86x1.58x0.63 | no |  | `Bush__ZYHKojmtPW.glb` |
| Connector | Connector | 508 | 27 | 3.37x2.21x2.17 | no |  | `Connector__0OKxctiaBw.glb` |
| Enemy_Flying | Enemy_Flying | 3,820 | 200 | 1.26x3.71x1.24 | no | 8 | `Enemy_Flying__kzpT6fNmM5.glb` |
| Enemy_Large | Enemy | 4,724 | 429 | 4.65x3.81x1.34 | no | 14 | `Enemy_Large__UgBmRVnQ9h.glb` |
| Enemy_Small | Enemy_ExtraSmall | 1,572 | 100 | 0.92x1.68x0.92 | no | 8 | `Enemy_Small__4LjT020LQh.glb` |
| Geodesic_Dome | GeodesicDome | 1,432 | 79 | 8.53x5.28x8.53 | no |  | `Geodesic_Dome__T7Ge6maWq4.glb` |
| Grass | Grass_1 | 246 | 20 | 1.27x0.99x0.91 | no |  | `Grass__GyDYqHAByU.glb` |
| Grass | Grass_3 | 408 | 25 | 2.23x2.38x1.49 | no |  | `Grass__iw6l7gqcdQ.glb` |
| Grass | Grass_2 | 96 | 14 | 1.70x1.40x1.17 | no |  | `Grass__Db4UVcNWnF.glb` |
| House_Cylinder | House_Cylinder | 1,166 | 52 | 5.61x4.32x5.61 | no |  | `House_Cylinder__VQF43DYGQO.glb` |
| House_Long | House_Long | 2,228 | 84 | 3.99x4.31x7.79 | no |  | `House_Long__X8671Q8mNc.glb` |
| House_Open | House_Open | 1,156 | 45 | 3.99x4.00x3.61 | no |  | `House_Open__5UyIxT1CkJ.glb` |
| House_Pod | House_Cylinder, House_Long, House_Single_Support | 4,938 | 187 | 27.40x4.32x8.79 | yes, 3 |  | `House_Pod__npP0RG1MR3.glb` |
| House_Single | House_Single | 1,080 | 40 | 3.99x4.00x3.80 | no |  | `House_Single__w8v6HfZzpE.glb` |
| House_Single_Support | House_Single_Support | 464 | 30 | 3.58x0.87x3.58 | no |  | `House_Single_Support__jSJcajOhX4.glb` |
| Mech | RaeTheRedPanda | 4,008 | 410 | 2.70x3.09x1.92 | no | 17 | `Mech__D5wW2jDO42.glb` |
| Mech | FernandoTheFlamingo | 4,086 | 417 | 2.70x3.55x2.06 | no | 17 | `Mech__tLs9mFVCSU.glb` |
| Mech | FinnTheFrog | 5,846 | 657 | 3.38x3.06x1.99 | no | 17 | `Mech__o3Ps8z8ByP.glb` |
| Mech | BarbaraTheBee | 6,756 | 489 | 2.91x3.00x2.05 | no | 17 | `Mech__4UvIHxnoSR.glb` |
| Metal_Support | MetalSupport | 540 | 28 | 0.14x1.20x5.95 | no |  | `Metal_Support__ZyUjmgnTyw.glb` |
| Pickup_Crate | Pickup_Crate | 1,348 | 74 | 0.87x0.86x0.90 | no |  | `Pickup_Crate__1dh0EFL5gl.glb` |
| Pickup_Health | Pickup_Health | 684 | 42 | 0.97x1.00x0.44 | no |  | `Pickup_Health__ijqVDSeIM5.glb` |
| Pickup_Jar | Pickup_Jar | 308 | 21 | 0.69x1.02x0.69 | no |  | `Pickup_Jar__jhvntkgHU3.glb` |
| Pickup_Key_Card | Pickup_KeyCard | 256 | 19 | 1.04x0.67x0.09 | no |  | `Pickup_Key_Card__EDvCEBvs8k.glb` |
| Pickup_Sphere | Pickup_Sphere | 1,824 | 72 | 0.89x0.89x0.89 | no |  | `Pickup_Sphere__1xtAc12dmv.glb` |
| Pickup_Thunder | Pickup_Thunder | 228 | 16 | 0.97x0.86x0.88 | no |  | `Pickup_Thunder__fUfTnyvYdl.glb` |
| Planet | Planet_4 | 10,488 | 261 | 4.49x4.09x3.97 | no |  | `Planet__EC1Lk2IamI.glb` |
| Planet | Planet_1 | 10,688 | 276 | 3.79x3.93x3.82 | no |  | `Planet__B7xd3SZq0z.glb` |
| Planet | Planet_8 | 1,070 | 44 | 3.45x3.75x3.75 | no |  | `Planet__5zzi8WUMXj.glb` |
| Planet | Planet_2 | 10,880 | 276 | 3.81x3.83x3.85 | no |  | `Planet__rYguWNNPvA.glb` |
| Planet | Planet_5 | 1,320 | 49 | 4.23x4.52x4.03 | no |  | `Planet__VNIRoibtQv.glb` |
| Planet | Planet_6 | 1,598 | 57 | 3.76x3.75x3.76 | no |  | `Planet__IVnmauIgWX.glb` |
| Planet | Planet_9 | 1,864 | 64 | 3.82x3.75x3.81 | no |  | `Planet__pHZz4EMvVM.glb` |
| Planet | Planet_7 | 2,010 | 72 | 4.81x2.87x4.46 | no |  | `Planet__9g1aIbfR9Y.glb` |
| Planet | Planet_11 | 2,178 | 84 | 5.59x5.67x5.74 | no |  | `Planet__18Uxrb2dIc.glb` |
| Planet | Planet_3 | 2,400 | 71 | 3.66x3.68x3.41 | no |  | `Planet__4NxxeyYMPJ.glb` |
| Planet | Planet_10 | 2,586 | 87 | 5.74x4.68x5.74 | no |  | `Planet__hKZtOOMadH.glb` |
| Plant | Plant_3 | 1,608 | 72 | 2.12x2.98x1.44 | no |  | `Plant__VwXvoIpCHP.glb` |
| Plant | Plant_2 | 196 | 17 | 1.06x1.97x1.01 | no |  | `Plant__RptHDDjUGW.glb` |
| Plant | Plant_1 | 540 | 27 | 1.80x2.18x0.64 | no |  | `Plant__s0joFFrQoy.glb` |
| Ramp | Ramp | 192 | 18 | 1.87x1.39x3.11 | no |  | `Ramp__cS1JQReXZs.glb` |
| Rock | Rock_2 | 210 | 18 | 2.74x2.71x2.52 | no |  | `Rock__HtpdTh3Ld6.glb` |
| Rock | Rock_1 | 224 | 18 | 3.10x3.61x2.83 | no |  | `Rock__b7gRkv0cEa.glb` |
| Rock | Rock_3 | 224 | 18 | 3.30x3.83x3.01 | no |  | `Rock__34W5ymEePk.glb` |
| Rock | Rock_4 | 456 | 28 | 2.16x3.46x1.70 | no |  | `Rock__R2UjZAX3By.glb` |
| Rock_Large | Rock_Large_1 | 222 | 18 | 7.67x3.29x7.33 | no |  | `Rock_Large__54jZKTAt5p.glb` |
| Rock_Large | Rock_Large_2 | 432 | 29 | 8.54x8.21x7.62 | no |  | `Rock_Large__li0YBlBEMz.glb` |
| Rock_Large | Rock_Large_3 | 448 | 29 | 5.31x7.43x5.19 | no |  | `Rock_Large__d2VWOdthtR.glb` |
| Roof_Antenna | Roof_Antenna | 492 | 29 | 1.41x3.54x1.43 | no |  | `Roof_Antenna__Fbdg52kqJ6.glb` |
| Roof_Radar | Roof_Radar | 972 | 43 | 1.63x2.71x1.65 | no |  | `Roof_Radar__V7XQDxF8JC.glb` |
| Round_Rover | Wheel_1, Wheel_2, Wheel_3, Wheel_4, Rover_Round | 7,052 | 300 | 5.79x5.17x3.69 | yes, 5 |  | `Round_Rover__ejdkcNgMpr.glb` |
| Rover | Wheel_4.001, Wheel_5, Wheel_1.002, Wheel_4.002, Rover_1 | 7,346 | 324 | 4.58x4.88x5.16 | yes, 5 |  | `Rover__tzOLXetacM.glb` |
| Rover | Wheel_1.001, Wheel_2.001, Wheel_3.001, Wheel_6, Rover_2, Wheel_2.002, Wheel_3.002 | 8,032 | 353 | 4.58x4.88x6.56 | yes, 7 |  | `Rover__WRd1piJOfh.glb` |
| Solar_Panel | SolarPanel_Roof | 812 | 43 | 2.73x1.70x1.73 | no |  | `Solar_Panel__ah89Y79JdT.glb` |
| Solar_Panel_Ground | SolarPanel_Ground | 372 | 23 | 1.29x1.10x1.67 | no |  | `Solar_Panel_Ground__LbGiYP5iJu.glb` |
| Solar_Panel_Structure | SolarPanel_Structure | 1,432 | 65 | 4.00x3.07x4.00 | no |  | `Solar_Panel_Structure__snXloZEimW.glb` |
| Spaceship | Spaceship_RaeTheRedPanda | 1,614 | 105 | 9.95x2.35x11.17 | no |  | `Spaceship__uCeLfsdmNP.glb` |
| Spaceship | Spaceship_FernandoTheFlamingo | 2,814 | 158 | 11.14x2.53x8.66 | no |  | `Spaceship__Jqfed124pQ.glb` |
| Spaceship | Spaceship_FinnTheFrog | 3,376 | 184 | 11.62x3.06x4.11 | no |  | `Spaceship__VSxUAFhzbA.glb` |
| Spaceship | Spaceship_BarbaraTheBee | 6,208 | 259 | 7.34x5.70x4.96 | no |  | `Spaceship__u105mYHLHU.glb` |
| Stairs | Stairs | 256 | 21 | 1.87x1.39x3.11 | no |  | `Stairs__Rh9shsu2hx.glb` |
| Tree_Blob | Tree_Blob_3 | 1,892 | 65 | 2.80x3.42x2.77 | no |  | `Tree_Blob__0X3fUj0uUF.glb` |
| Tree_Blob | Tree_Blob_2 | 5,776 | 161 | 3.69x4.61x3.86 | no |  | `Tree_Blob__j0byyoIGOv.glb` |
| Tree_Blob | Tree_Blob_1 | 6,112 | 171 | 3.86x5.88x3.86 | no |  | `Tree_Blob__QHYRrAnKzW.glb` |
| Tree_Floating | Tree_Floating_1 | 2,428 | 85 | 2.09x4.61x0.83 | no |  | `Tree_Floating__FYbeHz28NN.glb` |
| Tree_Floating | Tree_Floating_2 | 4,032 | 138 | 2.63x5.87x0.84 | no |  | `Tree_Floating__sdtjU7iczl.glb` |
| Tree_Floating | Tree_Floating_3 | 4,064 | 138 | 3.87x5.21x0.84 | no |  | `Tree_Floating__tj2fePl8Eu.glb` |
| Tree_Lava | Tree_Lava_3 | 1,088 | 43 | 1.12x2.09x1.13 | no |  | `Tree_Lava__wkLmuxEbMW.glb` |
| Tree_Lava | Tree_Lava_2 | 1,174 | 44 | 1.23x3.08x1.15 | no |  | `Tree_Lava__sTYjmQObr1.glb` |
| Tree_Lava | Tree_Lava_1 | 1,281 | 48 | 1.20x3.24x1.20 | no |  | `Tree_Lava__9gRfmVKx9W.glb` |
| Tree_Light | Tree_Light_2 | 1,080 | 40 | 1.45x2.51x1.51 | no |  | `Tree_Light__0bVHWZZnNg.glb` |
| Tree_Light | Tree_Light_1 | 2,280 | 76 | 2.63x3.76x1.96 | no |  | `Tree_Light__om4BJAL82T.glb` |
| Tree_Spikes | Tree_Spikes_2 | 1,698 | 60 | 2.42x4.49x2.11 | no |  | `Tree_Spikes__YCCpJ6jvf4.glb` |
| Tree_Spikes | Tree_Spikes_1 | 2,548 | 81 | 4.05x5.15x4.05 | no |  | `Tree_Spikes__a6Vo1seJw9.glb` |
| Tree_Spiral | Tree_Spiral_3 | 1,278 | 55 | 4.22x4.05x2.54 | no |  | `Tree_Spiral__gI3kqnqg80.glb` |
| Tree_Spiral | Tree_Spiral_2 | 1,490 | 62 | 3.80x6.19x2.20 | no |  | `Tree_Spiral__kBomlgZ5xu.glb` |
| Tree_Spiral | Tree_Spiral_1 | 748 | 35 | 2.36x4.49x2.23 | no |  | `Tree_Spiral__poFJzEWCk8.glb` |
| Tree_Swirl | Tree_Swirl_2 | 1,112 | 42 | 3.07x5.15x1.15 | no |  | `Tree_Swirl__czV0Ck0h2G.glb` |
| Tree_Swirl | Tree_Swirl_1 | 2,010 | 72 | 4.61x7.35x1.68 | no |  | `Tree_Swirl__iLxXSXIx2t.glb` |

## 5. Lettuce (Quaternius Nature Crops Pack, the "Ultimate Crops" pack) 🥬

The pack page links a Google Drive folder that refused downloads (quota); the same pack (Jan 2020, 102 models, FBX, OBJ and Blend, no glTF) came from OpenGameArt, uploaded by quaternius, as a 13.4 MB zip: `assets-cache/quaternius/crops/nature_crops_pack_by_quaternius.zip`, unpacked FBX and OBJ beside it. Lettuce is the only leafy crop in it (the others: apple, bamboo, beet, berries, cactus, carrot, corn, flowers, grass, mushroom, orange, palm, pumpkin, rice, tomato, watermelon, wheat).

Converted with Blender 5.2 headless (FBX import, transforms applied, GLB export, no animation) into `assets-cache/quaternius/crops/glb/`. **Gotcha:** the FBX files carry a transparency factor that Blender imports as alpha 0, so the first GLBs were invisible (alpha mode MASK, alpha 0). The converter now forces alpha 1 and opaque; the GLBs are opaque and double-sided. Godot 4.7 loads them.

| Stage | File | Triangles | Size (m, W x H x D) | Looks like |
|---|---|---|---|---|
| 1 | `Lettuce_1.glb` | 88 | 0.28 x 0.11 x 0.29 | a two-leaf sprout |
| 2 | `Lettuce_2.glb` | 400 | 0.37 x 0.37 x 0.35 | a young head with open leaves |
| 3 | `Lettuce_3.glb` | 612 | 0.62 x 0.38 x 0.68 | a half-grown head |
| 4 | `Lettuce_4.glb` | 1,392 | 1.04 x 0.47 x 1.04 | full head with spread outer leaves |
| picked head | `Lettuce_Crop.glb` | 448 | 0.38 x 0.41 x 0.38 | the closed head, the thing you harvest |
| after harvest | `Lettuce_Harvested.glb` | 1,280 | 1.04 x 0.47 x 1.04 | the outer leaves left behind |

One material each, `DarkGreen`, a dull olive (`#6b7256` in the GLB). Recolour through a DESIGN.md role. Sizes are the pack's, in metres, and stylised (stage 4 is a metre wide); the real size goes in `data/reality.json` and the model is scaled to it. Stage timing (Veggie lettuce: 33 days) is game data for 14 Nov, not part of the asset.

## 6. The HUD font: Exo 2 🔢

Compared at the same size on a dark background (`asset-previews/font-compare-chakra-rajdhani-orbitron-exo2-saira.png`), with the test string `0123456789`, `0O 1lI 5S 8B 6b 2Z`, `Oxygen 47% Sol 17 Ill 101`:

| Font | 0 vs O | 1, l, I | 5/S, 8/B, 2/Z | Same-width digits (`tnum`) | Verdict |
|---|---|---|---|---|---|
| Chakra Petch | 0 a bit narrower, both square | **l and I identical** | clear | no | techno look, fails l/I |
| Rajdhani | similar | **l and I identical** | clear | no | condensed and thin at small sizes |
| Orbitron | slashed 0, clear | all three differ | **5 and S, 2 and Z nearly the same**, very wide | no | hard for young readers |
| **Exo 2** | 0 clearly narrower than O | 1 has a flag, **l has a tail**, I is a bar: all differ | clear | **yes** | **picked** |
| Saira | slashed 0 available (`zero`) | **l and I identical** | clear | yes | close second |

Why Exo 2: it is the only one of the five where 1, l and I are all different and 0 and O are told apart without a slash, its digits are plain shapes a 7-year-old reads, and it has tabular figures (`tnum`), so a meter value that changes every second does not jitter. It still reads as "space tech" with its squared curves. One variable file covers weights 100 to 900 (use 600 to 700 for numbers and headings). In Godot: a `FontVariation` on the TTF with `variation_opentype = {"wght": 650}` and the OpenType feature `tnum` on for numbers. Sentences stay in a plain reading font (Lexend is in the npm cache).

Files: `assets-cache/fonts/exo-2/Exo2[wght].ttf` (304 KB), `OFL.txt`, `METADATA.pb`, `upstream_info.md`, from `google/fonts` main (commit c30b221beb0c). SIL OFL 1.1, no Reserved Font Name. Italic left out.

## 7. Licences and doubts ⚠️

- **All three Quaternius packs are CC0 on their pack pages**, saved on 12 Nov 2026 in each folder as `pack-page-*.html`, and on every Poly Pizza model page ("Public Domain (CC0)"). The OpenGameArt crops page says "License(s): CC0".
- **The packs' own `License.txt` files** could not be downloaded (Google Drive "Quota exceeded" on every file, even 1 KB ones). Each folder holds Google Drive's own rendering of that file (`License.txt.drive-preview.png`), the Drive folder listing (`drive-folder-listing.tsv`) and `LICENSE-PROOF.txt` explaining the chain. Men and crops read "License: CC0 1.0 Universal". The Space Kit's file says "Ultimate *Platformer* Pack ... License: CC0 1.0 Universal": the author reused another pack's text. The CC0 line, the pack page and Poly Pizza all agree, so it is a typo, not a doubt.
- **The QAL** (`space-kit/quaternius-license.html`, v1.0, 28 Aug 2026) covers assets "released by Quaternius under this License", and its section 7 says changes "will not apply retroactively to Assets you've already obtained under an earlier version". These packs are still marked CC0 on their pages, so the QAL does not apply. Worst case, the QAL still allows shipping them inside the game; only putting the raw model files in a public repo would conflict with it.
- **Exo 2:** OFL 1.1 with no Reserved Font Name, so a subset or converted copy may keep the name.
- **Still to get, if wanted:** the Universal Animation Library and the Humanoid Rig Spacesuit (itch.io rate-limited, Drive quota), for authored jump, carry and sit clips.

## Open questions ❓
- Does the team accept a slim armoured suit with no backpack as "an astronaut", or should a backpack prop go on the `Chest` bone?
- Jump, carry and sit: retarget from the Universal Animation Library, or code-posed?
- The dome's panes are opaque: is a see-through greenhouse needed (a glass material on the pane faces), or is an opaque dome with a lit door enough?
