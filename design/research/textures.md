# Textures, scanned rocks and NASA models 🪨

Checked 12 Nov 2026. Every file sits in `assets-cache/` at the workspace root, not in this project. Credits are in `assets-cache/CREDITS.md`. Pictures: `asset-previews/textures-rocks-nasa-contact.png` (every chosen albedo, rock and NASA model), `asset-previews/hdu-parts-1-2-at-scale-0.01.png` and `asset-previews/nasa-insignia-curiosity-tex05-hdu01.png`.

> [!TIP]
> **TL;DR.**
> - Nine CC0 PBR sets at 2K: dust (also at 4K), ripples, layered rock, plain grey rock, gravel, hull panels, bare metal, rubber and suit fabric.
> - Five CC0 scanned rocks. Each has a 3,000-triangle copy next to it.
> - Curiosity comes from science.nasa.gov as a GLB without Draco (51,305 triangles, in metres).
> - The habitat GLBs are re-saved without Draco. Their mesh units are centimetres.
> - **Logos:**
>   - Curiosity's `tex_05` and HDU part 1's texture both carry the NASA meatball and other insignia. Paint them out before either ships.
>   - The base station's texture never existed, so that model is a plain grey drum.

Every set was chosen by structure, not hue: the game divides each photo by its own average colour. I opened a flat preview of every candidate before choosing.

## 1. PBR texture sets 🎨

All are JPG at 2048 × 2048. "Tile" is the real-world width of one repeat, where the source gives it.

| Role | Set | Licence | Maps | Normal | Tile | Why it fits Gale |
|---|---|---|---|---|---|---|
| dust | Poly Haven [`gravelly_sand`](https://polyhaven.com/a/gravelly_sand) (Dario Barresi) | CC0 | diff, nor_gl, rough, disp, ao; **2K and 4K** | OpenGL | 2.48 m | Fine, even grit with small scattered pebbles, like the dusty plains. No baked shadows or tracks. The 4K set is in the same folder. |
| dust, ripples | Poly Haven [`aerial_beach_01`](https://polyhaven.com/a/aerial_beach_01) (Rob Tuytel) | CC0 | diff, nor_gl, rough, disp, ao | OpenGL | 30 m | Regular wind ripples under flat light, for the dark basalt sand patches. It's a beach scan, but no water or shells show. |
| rock, layered | Poly Haven [`cliff_side`](https://polyhaven.com/a/cliff_side) | CC0 | diff, nor_gl, rough, disp, ao | OpenGL | 1.83 m | Horizontal strata broken into blocky slabs, like Gale's mudstone and sandstone layers. |
| rock, plain grey (alternative) | ambientCG [`Rock030`](https://ambientcg.com/a/Rock030) | CC0 1.0 | Color, NormalGL, NormalDX, Roughness, Displacement, AmbientOcclusion | both | not given | Even grey weathered rock with fine veining. This is the grey under the red dust. |
| gravel | Poly Haven [`rocky_gravel`](https://polyhaven.com/a/rocky_gravel) (Dario Barresi, Dimitrios Savva) | CC0 | diff, nor_gl, rough, disp, ao | OpenGL | 1.81 m | Dense small angular stones, a pebbly ground to blend in with noise. |
| body | ambientCG [`MetalPlates009`](https://ambientcg.com/a/MetalPlates009) | CC0 1.0 | Color, NormalGL, NormalDX, Roughness, Metalness, Displacement | both | not given | Large panels with seams and a light, even wear, like a hull. |
| metal | ambientCG [`Metal011`](https://ambientcg.com/a/Metal011) | CC0 1.0 | Color, NormalGL, NormalDX, Roughness, Metalness, Displacement | both | not given | Brushed steel with smudges and scuffs. |
| trim | ambientCG [`Rubber004`](https://ambientcg.com/a/Rubber004) | CC0 1.0 | Color, NormalGL, NormalDX, Roughness, Displacement | both | 0.75 m | Fine, even, dark rubber grain. |
| suit | ambientCG [`Fabric061`](https://ambientcg.com/a/Fabric061) | CC0 1.0 | Color, NormalGL, NormalDX, Roughness, Displacement, AmbientOcclusion | both | 0.40 m | A fine, even plain weave, like a canvas outer layer. |

**Files:**
- `assets-cache/textures/<id>/`.
- Poly Haven folders hold the maps plus `polyhaven-info.json` and `polyhaven-files.json`.
- ambientCG folders hold the zip, the unpacked maps and `ambientcg-api.json`. The zips also contain `.blend`, `.tres`, `.usdc` and `.mtlx` files. Those were never opened. Leave them alone or delete them.
- Licence pages are saved as `textures/polyhaven-license-page.html` ("Our assets are all licensed as CC0") and `textures/ambientcg-license-page.html` ("Creative Commons CC0 1.0 Universal License").

**Use the OpenGL normal maps:** `nor_gl` and `NormalGL`. Godot expects OpenGL, and the DX maps would light bumps upside down.

**Runners-up, not downloaded:**
- dust: `red_laterite_soil_stones`
- ripples: none
- rock: `dry_riverbed_rock`
- gravel: `rocks_ground_02`
- body: `MetalPlates003` (riveted), `MetalPlates004` (a grid of seams)
- metal: `Metal009`
- trim: `Plastic012B`
- suit: `Fabric036`, `Fabric048`

## 2. Scanned rocks 🪨

All are from Poly Haven and CC0. Each folder holds the original glTF with 2K maps (`2k/`, with diff, nor_gl, and arm = AO, roughness and metal) and `<id>_3k_tris.glb`.

The 3k copy was made with Blender 5.2, Decimate in collapse mode. UVs and materials are kept and the 2K maps are embedded. I checked each one against the original in a render (contact sheet). The outline holds and the normal map carries the fine detail.

| Rock | Triangles (original → copy) | Size in metres (w × d × h) | Look |
|---|---|---|---|
| [`moon_rock_02`](https://polyhaven.com/a/moon_rock_02) | 3,304 → 3,000 | 0.25 × 0.25 × 0.20 | A rounded block with a dust coat |
| [`moon_rock_01`](https://polyhaven.com/a/moon_rock_01) | 18,668 → 2,997 | 0.22 × 0.11 × 0.08 | A thin flat slab with sharp broken edges |
| [`moon_rock_04`](https://polyhaven.com/a/moon_rock_04) | 7,636 → 3,000 | 0.12 × 0.17 × 0.05 | A low angular plate |
| [`rock_07`](https://polyhaven.com/a/rock_07) | 14,844 → 3,000 | 0.17 × 0.32 × 0.14 | A blocky brick with square-cut faces |
| [`namaqualand_boulder_05`](https://polyhaven.com/a/namaqualand_boulder_05) | 89,618 → 3,000 | 1.36 × 0.74 × 0.53 | A flat boulder with laminated layers |

**How the counts were made:** triangles were counted in Blender. The Poly Haven API's "polycount" is a different number (6,194 for moon_rock_02, for example).

**Real sizes are small:** the moon rocks and rock_07 were scanned at hand size (8 to 32 cm). Gale's float rocks are mostly that small, but scale them up for anything boulder-sized.

## 3. NASA models 🚙

All are public domain under NASA media rules: no logos, no implied endorsement.

**How they were re-saved:** `gltf-transform optimize in out --compress false --texture-compress webp --join false --instance false --palette false --simplify false`, into `assets-cache/nasa-3d/fixed/`. I added `--simplify false` so the geometry stays as NASA made it.

| Model | Source | Triangles | Size | Materials and textures | Insignia |
|---|---|---|---|---|---|
| Curiosity, `fixed/curiosity.glb` (2.8 MB; the original is `curiosity/24584_Curiosity_static.glb`, 11.9 MB, with its page saved beside it) | https://science.nasa.gov/resource/curiosity-rover-3d-model/ ("Credit NASA/JPL-Caltech") | 51,305 in one mesh, 9 primitives | 2.78 m wide × 3.95 m long (arm included) × 2.22 m tall, already in metres. Press kit: 2.8 × 3.0 (no arm) × 2.1 m | wheels (colour + normal), tex_01 to tex_05, tex_03a (alpha blend), parts_AO, internals. Textures are 1024 px (tex_05 is 512) | See below |
| HDU part 1, the shell (`fixed/habitat-demo-unit-1.glb`, 104 KB) | NASA-3D-Resources | 2,264 | See the note on units | `lambert2SG`, one 1024 px texture `HDU_01` | See below |
| HDU part 2, the frame, ramps, stairs and inner walls (`fixed/habitat-demo-unit-2.glb`, 240 KB) | NASA-3D-Resources | 4,320 | See the note on units | `lambert3SG`, one 1024 px texture `HDU_02` | None seen (grey parts, a yellow railing atlas) |
| Base station (`fixed/base-station.glb`, 7 KB) | NASA-3D-Resources | 184 | 35.9 × 35.2 × 23.5, units unknown | One material, no texture and no UVs | None |

**Curiosity's insignia** are in `tex_05` (512 px). Four round medallions sit in the right-hand column, centred near x 463 and y 90, 193, 290 and 393, each with a radius of about 45 px:
- the Mars Science Laboratory mission patch
- the **JPL logo**
- a US flag
- the **NASA meatball**

The same texture has a "CURIOSITY" nameplate down the left edge (x 0 to 80, y 0 to 330). That's text, not an insignia. `tex_04` has a tiny engraved part label (top right), which can't be read at game scale. The other textures have no logos.

**HDU part 1's insignia** are in `HDU_01`. They all sit in the left strip, x 0 to 350 and y 0 to 670 of 1024:
- two large NASA meatballs
- a small meatball and a small US flag beside every "Segment A" to "Segment H" label
- two large US flags
- two X-Hab challenge logos
- two HDU mission patches

Paint over that strip (or recolour it to plain panel) before the model ships.

**HDU units:** the meshes are in **centimetres**. The two files have different node scales (0.312 and 0.538), so as shipped they don't line up. Set each root to 0.01 and they meet exactly (see `asset-previews/hdu-parts-1-2-at-scale-0.01.png`):
- The whole unit is about 13.2 × 8.5 m.
- It is 7.35 m tall, including the loft on top.
- The drum is 5.3 m across, and the inner walls are 5.0 m.

That matches NASA's "over 5 meters in diameter" (`sizes.md`). The 3.5 m shell height in `sizes.md` is without the loft.

**Base station:** NASA's own preview (`Base Station.png` in the repo) renders it magenta. The file points to a texture, `BASE_UV.JPG`, that was never published, and the GitHub tree has no such file. I stripped the dead image reference and re-saved it. It is an untextured 184-triangle drum, so not much use to us.

## Open questions ❓
- The real-world tile size of `MetalPlates009`, `Metal011` and `Rock030`. ambientCG lists 0 for these, so the scale has to be set by eye.
- Whether the WebP that gltf-transform writes at its default quality is sharp enough on Curiosity's decals. A first look at 1024 px was fine.
- These files still need a row in the project's `ASSETS.md` when the asset lane imports them.
