# Art direction and asset brief

Written 12 Nov 2026 by the workspace session, for the factory session that builds the look and the assets. Read this file, `../AGENTS.md`, `refs/README.md` and the workspace `AGENTS.md` (two folders above `tooling/`) before anything else.

## 1. The job, and where it stops
The organisers told the team that the art direction and the assets may be prepared before the hackathon: every key 3D model, the world and the map. The story, the rules and the game itself are built at the hackathon (14 and 15 Nov 2026, about 15 hours of agent time).

**This session delivers the look and every asset, ready to assemble:**
1. A confirmed reference board (`refs/README.md`).
2. A short style study (`research.md`, section 6).
3. Three variants in `godot/preview`, Ravindu's pick, and an approved `DESIGN.md`.
4. Every model in `models/`, passing `style-check`.
5. The world: terrain, far backdrop, sky and fog presets.
6. The HUD kit: theme, icons, fonts, components.
7. A look-dev scene and a HUD gallery scene, checked on a phone.
8. `ASSETS.md`, the manifest, and the credits.

**Out of scope until 14 Nov:** the story and script, `sim/` rules, events, the player controller and follow camera, game flow, and win or lose logic. A scene may show assets, play animation clips in place and run a fixed camera path. It must not play the game.

Time: what is left of 12 Nov, plus 13 Nov. Work in priority order (section 7) so that a cut lands on P3, never on P1.

## 2. Recommended direction: "faceted dusk"
Ravindu asked for *Journey* (2012) as the vibe, a red-yellow Mars, a cyberpunk HUD, and nothing that looks like AI slop or a basic engine demo. The factory rule still holds: **you show three variants and Ravindu picks.** This is the direction those variants should explore, with the reasons for it.

**The look in one line:** faceted, flat-shaded rock and machines, carried by atmosphere: a low sun, haze that dissolves the distance into the sky, glow on bright sand, a warm palette that is almost one hue, and one cool accent (cyan or teal) that means "on", "you can use this" and "HUD".

**Why it fits the time and the tools we have:**
- **The assets on disk are already this style.** Kenney's Space Kit is low-poly in flat colours (2 to 876 triangles per model). A realistic look would need painted PBR textures for every model. An agent cannot author those, and the research found that photo-textured models beside flat kit models clash (`research/godot-build/README.md`, section 5, decision 2). Ravindu's *Journey* ask settles that decision on the stylised side.
- **The look lives in numbers.** Palette, fog distance, sun angle, glow and bevel are DESIGN.md tokens. An agent tunes numbers well and paints badly, so put the effort where the agent is strong.
- **The web renderer can draw all of it.** Godot's Compatibility renderer has fog by distance and height, glow, sky shaders, one shadowed sun and GPU particles. It cannot do volumetric light shafts, screen-space reflections or real-time bounce light (`research/godot-build/engine-limits.md`). Haze plus flat shading needs none of those.
- **Small download, phone-friendly.** Flat colours need almost no textures. The engine alone is about 10 MB compressed, and the game data budget is 15 MB.
- **Real in shape, stylised in surface.** Use real Gale terrain heights, real sizes, real colours (`research/godot-build/movement-and-look.md`, section 5), and the real mountain. *Journey* pulls the player toward a far mountain. Gale has one: Mount Sharp, about 5 km high, in the middle of the crater. Keep it on the horizon of every frame.
- **Characters:** a stylised, visored astronaut with authored clips looks alive. A realistic one with the same clips looks wrong. Visors also mean no faces (workspace rule 8, and `plan.md` asks for "cartoon astronauts with visors").

**Suggested axes for the three variants** (yours to change after the study):
- **A: Journey dusk.** Strong haze, a low gold sun, a bleached sky near the sun, a palette that is almost one hue, a cream suit with a teal accent. The most mood.
- **B: Toy outpost.** Chunky bevelled plastic machines with big labels (refs 3, 5, 12), cleaner midday light, lighter fog, a stronger cyan. The easiest for a 7-year-old to read.
- **C: Concept-art lite.** Smooth shading, the palette of NASA concept art (refs 1 and 3), white hulls with hazard trim, grey rock under red dust (that is real: drilled Gale rock is grey), and detail patterns on the `high` preset. The closest to real.

The astronaut must never be red or orange: it vanishes on Mars. *Journey*'s red cloak works because its world is gold. Our hero needs a cool accent.

## 3. What makes it not look like slop (checkable)
Ref 8 is the trap: noon light, no fog, default colours, grey HUD boxes. Turn each item below into a check on a capture-view screenshot where you can.
1. **Sky and fog from tokens, never engine defaults.** Distance fades into the sky colour, and the far rim and Mount Sharp sit at 40 to 70% fog.
2. **Low sun.** Long shadows. Elevation is a token. Noon is the exception (an event), not the default.
3. **Shadows are never black.** The ambient lifts shade toward a cool tone. Measure a shadow pixel: the factory gotcha about ACES black points applies.
4. **Colour discipline.** At most about 8 palette colours. The cool accent covers a small part of the frame and only marks things that are on, usable or HUD.
5. **A value structure.** Turn a frame to greyscale: the hero, the base and the sky must separate into clear light and dark groups. The hero reads in a 64 px thumbnail.
6. **Everything grounded.** Contact shadows or ambient occlusion. Nothing floats, and nothing has a visible seam with the ground.
7. **Something always moves.** Dust drifting on the wind, blinking beacons, solar panels turned to the sun, the idle clip breathing, PIP wobbling. A still frame of the game should still feel windy.
8. **Labels on machines** (refs 3 and 12): short real words ("HAB 1", "O₂", "WATER", "POWER") as `Label3D` or forge geometry. They help wayfinding for kids and cost no textures.
9. **The HUD is designed, not boxed.** See section 5.

## 4. The world
- **Terrain: real Gale shape, faceted.** Two candidate sources, both public. Pick after looking:
  1. `assets-cache/nasa-3d/curiosity-landing-site.stl` (on disk, 2.8 MB). Check its extent and resolution first.
  2. USGS copy of HiRISE `DTEEC_023957_1755_024023_1755_U01`, 1.01 m per pixel, 171 MB as a cloud-optimized GeoTIFF. Crop a few km. Network is slow: ask Ravindu before the download, and download once.
  The visible ground is a generated mesh in chunks with flat normals. Collision comes from the same heights (`HeightMapShape3D`). Keep the height data as a file in `data/` so the game can query it.
- **Play area:** about 300 × 300 m around the base is a suggestion. At about 1 m/s walking (Apollo), that is minutes to cross. Agree the size with Ravindu.
- **Far backdrop:** Mount Sharp and the crater rim (30 to 40 km away, so they sit low on the horizon) as a low ring mesh or a painted-geometry backdrop. A coarser elevation source is needed for this: research it.
- **Sky and light presets:** day in `DESIGN.md`. Sunset (blue-grey around the sun), night and dust storm (cherry red, dim, never black) each as `DESIGN.<state>.md` with the same roles and only colours and light changed, the way factory themes work. The game blends between them at runtime, and that blending is hackathon code. If the factory needs a generic change to support this, make it in `tooling/` with no game content, and say so.
- **Effects** (engine particles and shaders; the values are art direction): a footstep and wheel dust puff that drifts and thins (not an arc: see movement-and-look §4), wind streaks, a dust devil, a storm front, and sand glints in the *Journey* style if the study shows Compatibility can afford them.

## 5. The HUD: cyberpunk, kid-readable
Ravindu wants a cyberpunk HUD, not a web-page HUD. **The frame:** the HUD is the helmet visor's display. That justifies the style inside the world, and the edges of the screen can carry the visor's curve and tint.
- **Built from Godot Control nodes and a Theme** whose colours come from `design.json`. Angled panels (`StyleBoxFlat` skew and corner settings), thin glowing strokes, corner brackets, a `canvas_item` shader for scanlines and edge glow. No plain grey rectangles.
- **Colours:** amber or orange as the primary (it belongs on Mars), the cool accent for live and interactive things, red for danger. Colour is never the only signal: every state also has an icon or a shape (workspace Kid UX rule).
- **Readability beats style.** Kids aged 7 to 12. Icons first, at most 8 words per card, touch targets of at least 48 px, large text. A techno display font for headings and numbers, and a plain reading font for sentences: `@fontsource-variable/lexend` is already in the npm cache. Any font must be OFL or similar and downloaded once.
- **No fast flashing.** No glitch strobes. An alert pulses slowly, at no more than 3 flashes a second.
- **The kit** (a static gallery scene with mock values; no game logic):
  - the 3 meters: Power, Life support, Crew health;
  - the sol counter and clock;
  - an event card with 2 choice buttons, each showing its cost;
  - a "Real NASA fact" card with a source line;
  - a LIVE / ARCHIVED + date data badge (workspace rule 4);
  - an "Ask Earth" delay countdown;
  - an alert toast;
  - the mission-lost frame;
  - the replay chain (X → Y → Z);
  - the Mission Log card;
  - the credits screen;
  - touch controls (move stick and action buttons) for phones.
  Show it at phone and laptop sizes.
- **Icons:** one SVG set in one stroke style: power, battery, sun, O₂, water, food, radiation, health, storm, shelter, greenhouse, heater, dish or Earth, science, PIP. Draw them yourself in SVG, or use a CC0 or MIT set with the licence saved.

## 6. The style study first (`research.md`), short
Follow the method in `~/Documents/Prompts/deep-research.md` (sources saved, every claim ✅ / ⚠️ / ❌), scoped to these questions and written as one file, not Docmost. Two or three background agents are fine. Save pages to `design/research/pages/`.
1. **How does *Journey* get its look, and which parts can our renderer draw?** Lead to verify: John Edwards' GDC 2013 talk on sand rendering in *Journey* (sand normals, glitter, specular, haze). Map each technique to a Compatibility feature, or to "no".
2. **Flat shading in Godot 4.7 Compatibility:** split normals against a shader, the cost on phones, and how the house style's `shading: flat` already does it.
3. **Sky, fog, glow and tonemapping in Compatibility:** a procedural sky or a sky shader, depth fog and height fog, glow, and which tonemappers 4.7 offers there.
4. **The astronaut:** download the Quaternius "Astronaut" (CC0, about 5,324 triangles, clip list unknown) and list its clips. The fallback is a Kenney Mini Character (on disk, 32 clips) with a helmet and backpack on its bones. Read the licence trap in `research/godot-build/assets.md` §3 first.
5. **HUD readability for children:** minimum text size and contrast from a game accessibility source. Only claims you saw.
6. **Real sizes** for every model below: habitat module, crewed rover, Curiosity, lander, solar panel, dish. Use NASA sources and put them in `data/reality.json` size rows.

## 7. The asset list
Every model goes through `Forge.HouseStyle.apply()`. File names start with their class (`building_`, `vehicle_`, `rock_`; anything else is `prop`). Flat pieces get a class whose height starts at 0. "Assemble, don't model": real data, then a CC0 kit, then engine built-ins, then forge recipes.

| P | Asset | Source to try first | Notes |
|---|---|---|---|
| 1 | Terrain chunks + height data | Gale elevation, section 4 | faceted, collision from the same heights |
| 1 | Far backdrop: Mount Sharp and rim | coarse elevation data | always visible |
| 1 | Astronaut, the hero (idle, walk, run, jump, interact clips) | Quaternius Astronaut, else Kenney Mini + helmet | visor, no face, cool accent |
| 1 | Crewmate(s) | same model, different accent or number | crew size is an open team decision (2 or 4) |
| 1 | Habitat (with airlock door) | Kenney Space Kit domes and corridors; NASA Habitat Demo Unit | "HAB 1" label |
| 1 | Solar array (panels that tilt) | Quaternius Ultimate Space Kit, else forge | panels as separate nodes so they can turn and get dusty |
| 1 | Battery bank, oxygen maker (MOXIE-style), water recycler | Kenney tanks and machines, else forge | readable at a glance: label and icon |
| 1 | Greenhouse + lettuce in growth stages | Quaternius geodesic dome; Quaternius crops (needs Blender conversion) or forge | lettuce takes about 33 days |
| 1 | Build pad (empty plot) | forge | flat class |
| 1 | Sky and light presets: day, sunset, night, storm | DESIGN.md and `DESIGN.<state>.md` | section 4 |
| 1 | HUD kit + icons + fonts | section 5 | gallery scene |
| 2 | Storm shelter | forge | real: built from bags of food and water (NASA Orion) |
| 2 | Comms dish | Kenney Space Kit | |
| 2 | PIP, the original helper rover | forge | small, expressive through lights and wobble, no face |
| 2 | Crewed rover | Kenney rover, else forge | NASA concept: crew of two, about 10 km/h |
| 2 | Lander (resupply ship or ascent vehicle) | Kenney rocket parts | the sol 30 ending is an open team decision |
| 2 | Rocks: 3 sizes, 2 or 3 variants; layered mudstone outcrop; pebble scatter; dark basalt dune ripples | ref 11 vocabulary; forge | grey rock, red dust coat |
| 2 | Cargo crates, cables, lamps, antenna mast, beacons | Kenney | |
| 2 | Dust effects (section 4) | engine particles | |
| 3 | Curiosity rover as a landmark | NASA 3D resources (not on disk) | **Curiosity is the rover at Gale. Perseverance and Ingenuity are at Jezero crater: do not place them at Gale.** |
| 3 | Cinematic pieces: Earth, Mars, cruise ship | `assets-cache/nasa-3d/*.jpg`, Kenney rocket parts | intro is hackathon work, these are only parts |
| 3 | Sounds: wind, rover, UI, alarm | Kenney sound packs (on disk); NASA Mars recordings (download, credit NASA/JPL-Caltech) | |

**NASA models:** five of six are Draco-compressed. Re-save each one with `gltf-transform optimize ... --compress false --texture-compress webp`. Check every NASA texture for insignia: no NASA logos (workspace rule 5).

## 8. Done means
- [ ] `refs/README.md` confirmed by Ravindu, image by image.
- [ ] `research.md` written, every claim with a status.
- [ ] Three variants shown in `godot/preview`. Ravindu picked or mixed. `DESIGN.md` lints with `style-check` and is committed.
- [ ] Every P1 and P2 model is in `models/`. `node ../../tools/style-check.mjs DESIGN.md models/*.glb` passes. One lineup render is compared with the chosen variant.
- [ ] `lookdev/lookdev.tscn`: the base laid out on the real terrain under each sky preset, the astronaut playing its clips in place, a fixed camera path, and capture-view presets (`default`, `base`, `hero`, `horizon`, `storm`).
- [ ] `ui/hud_gallery.tscn`: every HUD component, at phone and laptop sizes.
- [ ] `node ../../tools/web-check.mjs .` passes within budget. Ravindu opens the look-dev scene on the weakest team phone through `serve-web` on the `low` preset, and the style still holds.
- [ ] `ASSETS.md` lists every asset: file, source, licence, triangles, status. `assets-cache/CREDITS.md` has every download with its credit line.
- [ ] Commits in this repo, signed off, with the workspace's co-author trailer.

## 9. Ask Ravindu, don't guess
- The take and avoid notes on every reference image, and whether ref 8 is really the "avoid" example.
- The variant pick or mix.
- Which phone is the weakest, and the game data budget (15 MB was set for three.js).
- The size of the play area.
- Every download over a few MB (the HiRISE crop, the Quaternius packs, fonts).
- Crew size (2 or 4) and the ending vehicle (resupply ship or ride home): make assets that work for either, and flag where they don't.
