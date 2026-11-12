# Night sky: stars, Milky Way, Earth, Phobos and Deimos (12 Nov 2026)

A look change for Ravindu to approve: the night sky (DESIGN.night.md) now shows the real sky over Gale on the
hackathon date, 14 Nov 2026, at 19:30 local solar time. Day, sunset and storm are unchanged (no `celestial` key:
the storm's dust hides everything, and by day the sky is too bright). To undo: delete the `celestial:` block from
DESIGN.night.md and run `node ../../tools/design-tokens.mjs DESIGN.night.md design.night.json`.

## What you see
- **Stars** from the Yale Bright Star Catalogue (9,096 stars). The 1,627 down to magnitude 5 are drawn by the
  shader itself, one or two pixels sharp at any screen size, coloured by their B-V; the fainter ones come from a
  2048 x 1024 map. Same constellations as from Earth.
- **The Milky Way** from NASA SVS Deep Star Maps 2020, in its real place.
- **The sky turns about Mars's own pole** (RA 317.68, Dec 52.89, near Deneb in Cygnus), so stars rise in the east
  and set in the west. **Time factor: 10** (one Mars hour every 6 real minutes; the sky turns 0.04 degrees a second).
- **Earth** as the bright bluish evening star low in the west-northwest (11.9 degrees up at the start, setting
  within about 10 real minutes), with Venus (also an evening star then) near it, and Saturn higher.
- **Phobos** as a small grey disc, its true size (about 12 arc minutes, a third of the full Moon), lit by the
  real sun: a half Moon high in the west at the start, rising toward overhead and filling out, moving visibly
  against the stars (it crosses the sky in 4.2 Mars hours, about 25 real minutes at factor 10). About 13 minutes
  in, it slides into Mars's shadow and goes dark, as the real one does on most orbits. Its night side is faintly
  lit by Mars itself.
- **Deimos** as a faint star-like point, moving slowly the other way (it rises in the east).
- **Dust**: everything dims toward the horizon by the dust's optical depth (tau 0.5, Curiosity's median for the
  clear season), so few stars show near the skyline.
- The sky clock restarts when the sky state switches (key B), so night always opens on this scene.

## Pictures (`design/handoff/night-sky/`)
| File | What |
|---|---|
| `night-base.png` | the base under the night sky, looking west-northwest |
| `turning-0s.png`, `turning-30s.png` | the same view 30 s apart: the stars have moved |
| `phobos-0s.png`, `phobos-60s.png` | Phobos 3 degrees across the frame, 60 s apart: it moved and its lit part grew |
| `stars-sharp-4x.png` | a crop of the 960 x 540 frame at 4x, nearest neighbour: bright stars are 2 to 3 px cores |
| `earth.png` | Earth (centre) over the western skyline, 20 degree field |

## Tokens and sources (`lighting.celestial`)
| Token | Value | Source |
|---|---|---|
| `pole` | 317.681, 52.887 | IAU WGCCRE 2009 (Archinal et al. 2011); NAIF pck00011 (2015 report) evaluates to 317.681, 52.886 at J2000. `design/research/pages/night-sky/naif-pck00011.tpc` |
| `latitude` | -4.59 | Bradbury Landing 4.5895 S (MARDI, Planetary Society briefing, ⚠️ secondary) |
| `radius` | 3389.5 km | NSSDC Mars fact sheet |
| `day` | 88,642.4 s | sidereal rotation 24.6229 h, NSSDC |
| `sun` | 288.17, -23.95 | computed for 2026-11-14 with JPL "Approximate Positions of the Planets", Table 1 (`node ../../tools/sky-stars.mjs ... --date 2026-11-14 --from Mars`) |
| `hour` | 19.5 | design choice: the sun is 22.9 degrees down (full night by the US Naval Observatory twilight definitions), Earth still 12 degrees up. Curiosity photographed Earth "about 80 minutes after sunset" (PIA17936) |
| `timeScale` | 10 | design choice, so Phobos visibly moves |
| `tau` | 0.5 | Gale 880 nm optical depth, clear season median 0.49 (Lemmon 2024 dataset); storm 2018 peak 8.5 (Guzewich 2019) |
| `planets` | Earth 327.44/-15.14, Venus 314.21/-19.93, Jupiter 148.02/13.31, Saturn 3.65/-1.29 | the same JPL computation; Earth 37.9 degrees east of the sun = an evening star. Magnitudes (Earth -2.3, Venus -2.7, Jupiter -2.8, Saturn +0.9) are ⚠️ estimates: each planet's absolute magnitude plus distance and a Lambert phase curve |
| `moons` | Phobos 11.08 km, 9,375 km, 27,554 s; Deimos 6.2 km, 23,457 km, 109,075 s | JPL SSD satellite physical and orbital parameters (`design/research/pages/moons/`) |
| moon `color` | #8c8780, brightness 6 | geometric albedo 0.071 and 0.068 (JPL SSD, archived table): dark grey. Brightness is art direction, set so Phobos reads at night |
| `stars.brightness`, `milkyWay`, `milkyColor` | 2.0, 0.6, #dfe3f0 | art direction |

Checked by arithmetic (`design/research/pages/moons/`, the research report): Phobos 12.7 arc minutes overhead and
8.7 at the horizon, up to 81.6 degrees from Gale, 4.24 h horizon to horizon, rising in the west every 11.1 h;
Deimos about 2 arc minutes, up about 2.4 sols at a time. The shader computes Phobos's place from its orbit and our
spot on the surface, so these come out on their own.

## Cost
No extra draw call: it is all in `addons/forge/sky.gdshader`. Per sky pixel: one map sample, six star slots of
two texel fetches, four planets, two moons. Nothing is drawn into the reflection cubemap, and the sky turns on a
global shader clock, so the cubemap is not re-rendered while it turns (a material parameter changed each frame, or
`TIME`, would re-render it: the factory's AGENTS.md gotcha). Textures: 2048 x 1024 VRAM-compressed with mipmaps
(2.5 MB PNG on disk) and a 1536 x 64 lossless list (20 KB).

## Open
- **Licence:** the Milky Way map contains Gaia DR2 data, CC BY-NC 3.0 IGO: fine for a hackathon, but it is a
  non-commercial exception in an Apache-2.0 repo. The alternative is a band we draw ourselves from the galactic
  frame (RA 192.85948, Dec 27.12825 for its pole, sourced); say if you want it. The star catalogue states no licence
  (credited in CREDITS.md and ASSETS.md).
- The Milky Way is from the SVS 1024 x 512 preview (the full map is a 35 MB EXR, not downloaded): soft, but a glow.
- Phobos is drawn round (it is 27 x 22 x 18 km). Earth's Moon, a faint point next to Earth in Curiosity's photo,
  is not drawn.
- A faint 4 px grid shows in the darkest sky on a 4x zoom: the VRAM compression of the map. Invisible at 1x.

## The token change (`diff -u`, DESIGN.night.md; the `quality:` lines below it are the performance lane's)
```diff
--- DESIGN.night.md.before
+++ DESIGN.night.md
@@ -116,6 +116,24 @@
   toneMapping: aces
   fog: { color: "{colors.horizon}", near: 20, far: 2600, sky: 0.15, curve: 1.4, density: 0.75, sun: 0 }
   lamp: { color: "#dff6f0", intensity: 14, distance: 14 }
+  celestial:
+    pole: [317.681, 52.887]
+    latitude: -4.59
+    radius: 3389.5
+    day: 88642.4
+    sun: [288.17, -23.95]
+    hour: 19.5
+    timeScale: 10
+    tau: 0.5
+    stars: { map: textures/sky/stars.png, list: textures/sky/star_list.png, brightness: 2.0, milkyWay: 0.6, milkyColor: "#dfe3f0" }
+    planets:
+      - { name: Earth, ra: 327.44, dec: -15.14, mag: -2.3, color: "#a9c8ff" }
+      - { name: Venus, ra: 314.21, dec: -19.93, mag: -2.7, color: "#fff4dc" }
+      - { name: Jupiter, ra: 148.02, dec: 13.31, mag: -2.8, color: "#ffe8c8" }
+      - { name: Saturn, ra: 3.65, dec: -1.29, mag: 0.9, color: "#ffe0a0" }
+    moons:
+      - { name: Phobos, radius: 11.08, orbit: 9375, period: 27554, start: -25, color: "#8c8780", brightness: 6.0 }
+      - { name: Deimos, radius: 6.2, orbit: 23457, period: 109075, start: 20, color: "#8c8780", brightness: 6.0 }
 quality:
   low: { msaa: 0, pixels: 0.6, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off, aniso: 1, ground: flat, particles: 0.5, trail: 1024, lamps: 2 }
   medium: { msaa: 2, pixels: 1.0, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code, aniso: 2, ground: full, particles: 0.75, trail: 2048, lamps: 4 }
```
