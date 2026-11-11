# Reference board

Ravindu collected these 13 images on 12 Nov 2026. The "take" and "avoid" notes below are **Claude's reading, not yet confirmed**. In the factory interview, confirm each row with Ravindu (one `AskUserQuestion` round, several images per question) and correct this file before writing any variant.

The images are third-party screenshots and renders, so they are gitignored. Only this file is committed. They must never ship in the game or appear in the submission.

Palettes come from `node ../../../../tools/ref-palette.mjs . --colors 6` (run from this folder). The AVIF files need converting first: `ffmpeg -i 7.avif 7.jpg`.

| # | What it is | Take | Avoid |
|---|---|---|---|
| 1.webp | Painted concept of a Mars base: a row of cylinder habitats, two suited astronauts, a rover, an orange sky | The layout of a believable base (modules in a row, crates, a rover parked beside it). The whole frame graded one warm hue, and far hills dissolving into haze | Painted texture detail. We can't author it, and it clashes with kit models |
| 2.jpg | Space shooter: an orange nebula, asteroids, a lit ship | Warm gold air with small **cyan and green emissive** accents, and glow on hot spots | Noisy rock clutter and the space setting |
| 3.jpg | Stock render: "HABITAT 01" module, tube corridors, a robot rover, an astronaut in an orange suit | **Big labels and numbers on the modules** (wayfinding a kid can read), white hulls with dark and hazard trim, pipes joining modules | The jagged alpine peaks: Gale's rim is worn down and Mount Sharp is a broad mound. Also the orange suit, which disappears against orange ground |
| 4.jpg | A Godot showcase scene (credit on screen: Jaanus Jaggo, Perfoon): a hangar, a ship, green crates in warm sun | Warm key light against cool dark shade, and **one saturated accent that marks what you can use** (the green crates pop) | Light shafts and bounce light: they need Godot's Forward+ renderer, and the web build has only Compatibility. The jungle |
| 5.jpg | The same Godot showcase: an orange and cream arcade cabinet, chunky props | **Chunky, bevelled, plastic-looking hard surfaces** in two tones, and printed labels and decals | The dark interior |
| 5.jpeg | Stylised third-person game: a girl in a red canyon, a giant creature, a pale sky | A stylised hero who reads against warm rock through **complementary colours** (teal and pink on orange). Faceted rock masses, and a pale, washed-out sky | The fantasy creature. And the face: our astronauts wear visors |
| 6.jpg | Stylised shooter in a blue-sky valley | Clean low-poly shapes with soft gradients, crisp shadows and clear silhouettes. The orange lattice tower | The blue sky, the green grass and the guns |
| 7.avif | Low-poly truck at sunset in rain | **Plain models made cinematic by atmosphere:** a low sun disc, warm haze, fog swallowing the distance, rows of lamp posts | The wet-road reflections (no screen-space reflections in the web build) and the rain |
| 8.avif | Low-poly survival game: grass, autumn trees, an axe, grey HUD boxes | Probably the **"avoid" example** (confirm). Flat noon light, no fog, saturated default colours, and a HUD of grey rectangles: the "basic engine game" look | All of it, unless Ravindu says otherwise |
| 9.avif | Looks like *Lonely Mountains: Downhill*: a rider on a faceted canyon trail | **Faceted terrain that still looks lovely**: flat-shaded planes, long soft shadows, warm orange rock, a little tilt-shift depth | The trees and the greenery |
| 10.jpg | *Journey* (2012): the red-cloaked traveller, ruined pillars, a bright sun, a far mountain | **The target mood.** A monochrome warm palette. A bleached sky near the sun. Distance fading into the sky colour. Big simple silhouettes. One saturated figure. **A far mountain that pulls you forward** (Gale has one: Mount Sharp, about 5 km high, in the middle of the crater) | Ruins and the desert-pilgrim story. And the red figure: a red astronaut vanishes on Mars, so ours needs a cool accent |
| 11.jpg | A low-poly desert rock kit shown on a blue background (mesas, hoodoos, arches, craters, pebbles) | **The rock vocabulary**: mesas, stacked layers, boulders, small craters, pebble scatter, all faceted, in 3 or 4 tones of one red | The arches and hoodoos as heroes: Gale has layered mudstone and sandstone, not Utah arches |
| 12.jpg | Looks like *Astroneer*: a dome base, a hex solar panel, faceted orange terrain, cyan lights | **The closest game to ours.** Faceted Mars ground, chunky readable machines, cyan emissive for "on", and yellow trim on interactive parts | Its cartoon proportions, if taken too far |

## What the board says, in one paragraph (Claude's reading)
A warm, nearly monochrome Mars of faceted rock and sand. Atmosphere does the work: a low sun, haze that dissolves the distance into the sky, and glow on the bright parts. Chunky bevelled machines with big labels. One cool accent colour (cyan or teal) for "on", "interactive" and the HUD. Nothing realistic in texture, everything real in shape, colour and scale. Refs 10 (*Journey*), 12 (*Astroneer*) and 9 carry the most weight. Ref 8 is the trap to avoid.
