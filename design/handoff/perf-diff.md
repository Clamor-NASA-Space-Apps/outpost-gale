# Performance lane: what changed in the look (12 Nov 2026)

Every visible change is a DESIGN.md `quality` knob. The four DESIGN files carry the same block (night, storm and
sunset copy it). Measured on the dev laptop (i3 13th gen, Intel UHD, window maximised: 1920 x 1008 real pixels).

## The preset block

```diff
--- DESIGN.md.before
+++ DESIGN.md
@@ -115,9 +115,9 @@
 quality:
-  low: { msaa: 0, scale: 0.75, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off }
-  medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code }
-  high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture }
+  low: { msaa: 0, pixels: 0.6, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off, aniso: 1, ground: flat, particles: 0.5, trail: 1024, lamps: 2 }
+  medium: { msaa: 2, pixels: 1.0, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code, aniso: 2, ground: full, particles: 0.75, trail: 2048, lamps: 4 }
+  high: { msaa: 2, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture, aniso: 2, ground: full, particles: 1, trail: 2048 }
```

`npx design.md diff` skips these keys (3D extension), so the plain diff above is the record.

## What you can see change, per preset
| Preset | Change | Why | Source |
|---|---|---|---|
| high | MSAA 4x to 2x: edges a little less smooth | 4x cost 6.4 ms of a 16.7 ms frame; 2x saves 3.1 ms | sweep, 12 Nov |
| high | nothing else | trail map, ground shader and warm-up give the same pixels | GPU read-back equals the CPU map; the shader skips only layers whose share is exactly 0 |
| medium | 3D picture capped at 1.0 Mpx (bilinear upscale above that) | 10.75 to 6.5 ms GPU on the laptop | sweep |
| medium | 75% of the dust grains, at most 4 lamps lit at night | particles and lamp passes | our choice |
| low | 0.6 Mpx 3D picture on any screen (was 75% of the window: 1.5 Mpx on a 2.6 Mpx phone) | Modern Warfare 2's 1024 x 600 (frame-budget A3); a phone is fill-bound | frame-budget skill |
| low | half the dust grains, a 32 m print square (was 64 m), at most 2 lamps lit, 2x anisotropy | cheaper; prints farther than 16 m away fade sooner | our choice |
| low | ground `flat`: the same look as before (low had no photo detail already), now without fetching the photos | GPU | shader `GROUND_FLAT` |

## Captures (high preset, before = HEAD 9b479de, after = this lane)
`captures/perf-before-<view>.png` and `captures/perf-after-<view>.png`, from `capture-view --views
default,base,airlock,horizon --advance 1500` (the tools' 1280 x 720 software GL, saved at half size). Mean
absolute difference per channel, out of 255: default 0.04, base 0.07, airlock 0.34, horizon 0.05. The largest
local differences are PIP (another lane's robot, which wanders) and edge pixels of the 4x to 2x MSAA change.

## Measured (laptop, maximised, high unless named)
| | before | after |
|---|---|---|
| GPU, spawn view: high / medium / low | 14.3 / 10.75 / 4.2 ms | 10.8 / 6.5 / 2.7 ms |
| ground's share of that (terrain hidden vs shown, same MSAA) | 5.2 ms | 4.2 ms (3.9 at the new high) |
| print upload | 4 MB, 1.0 ms CPU per print | changed 64 px tiles, 0.16 ms |
| bag picked up or put down | 12.7 ms | 3.3 ms |
| dropped frames (over 25 ms) walking / driving, vsync | 1.9% / 0.4% | 0.1 to 0.3% / 0.3% (cold shader cache) |
| web build, frames over 17.5 ms walking and running | 5 (883 ms worst) | 0 |
| web build, load (longest frame) | 10.2 s | 13.6 s: the warm-up compiles what play would have |
| web build, sky / quality switch | 2.0 / 2.8 s frozen in view | 3.4 / 4.9 s behind the cover |
