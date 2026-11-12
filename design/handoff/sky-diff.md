# Sky and look changes for Ravindu to approve (12 Nov 2026, lane B)

Nothing here is merged as approved: a look change is a DESIGN.md edit the user signs off (factory rule). Each
change is shown as `diff -u old new`. The old files are what was on `main` at commit 5479f46.

## What changes and why
1. **Sunset: the blue halo round the sun.** Mars sunsets are blue near the Sun (NASA; your field guide, "Sky and
   light"). Before, the haze round the sun used the sun's own pale colour at a fixed strength. Now it has its own
   colour (`halo.color`, a clear blue), size (16 degrees) and strength (1.0). The fog's sun glow (`fog.sun`) drops
   from 0.9 to 0.35: at 0.9 it painted the sun's pale colour over the halo and the blue did not show.
2. **Sunset and night: a long twilight.** High dust keeps lighting the sky after sunset (field guide). A glow
   along the western horizon (`twilight`): pale blue-grey at sunset, a faint deep blue at night where the sun
   went down. The night sky had no sun disc, so it now uses the house sky shader too, for the glow alone.
3. **Sunset and night: lit windows.** The glass role gets `lit`: panes glow warm, each on or off by itself and
   changing every 90 s. About 60% of panes at sunset and 85% at night. This also lights the lander's windows,
   the machines' screens and, as one pane, the greenhouse dome (its glass is one piece). See the night capture.
4. **Every sky file: Curiosity's own textures kept on purpose.** A kit entry `keep` for its photo textures (no
   colour change: they were already kept, with a warning) and `internals` mapped to `body`, the role it was
   already falling back to. With this, style-check passes on all 29 models.

The factory's sky shader gained the two tokens (`halo`, `twilight`), documented in `tooling/examples/DESIGN.md`.
A file without them looks as before.

## DESIGN.sunset.md
```diff
--- DESIGN.sunset.md (before)	2026-11-12 07:14:26.224575484 +0530
+++ DESIGN.sunset.md	2026-11-12 07:35:56.334787651 +0530
@@ -77,7 +77,7 @@
   trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
   accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
   metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
-  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5 }
+  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, lit: { color: "#ffbe72", emissive: 1.5, share: 0.6, period: 90 } }
   rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
   dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
   hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
@@ -111,13 +111,17 @@
   azimuth: 270
   exposure: 1.1
   sunDisc: 1.6
+  halo: { color: "#3a6ad0", size: 16, strength: 1.0 }
+  twilight: { color: "#8aa2cc", height: 8, strength: 0.5 }
   toneMapping: aces
-  fog: { color: "{colors.horizon}", near: 25, far: 4200, sky: 0.25, curve: 1.6, density: 0.7, sun: 0.9 }
+  fog: { color: "{colors.horizon}", near: 25, far: 4200, sky: 0.25, curve: 1.6, density: 0.7, sun: 0.35 }
 quality:
   low: { msaa: 0, scale: 0.75, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off }
   medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code }
   high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture }
 kit:
+  "^(tex_0[1-5]|wheels|parts_AO)$": keep
+  "^internals$": body
   "^terrain$": dust
   "metalDark": metal
   "metalRed": hazard
```

## DESIGN.night.md
```diff
--- DESIGN.night.md (before)	2026-11-12 07:14:26.226018670 +0530
+++ DESIGN.night.md	2026-11-12 07:34:04.052045947 +0530
@@ -77,7 +77,7 @@
   trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
   accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
   metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
-  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5 }
+  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, lit: { color: "#ffbe72", emissive: 1.5, share: 0.85, period: 90 } }
   rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
   dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
   hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
@@ -111,6 +111,7 @@
   azimuth: 120
   exposure: 1.2
   sunDisc: 0
+  twilight: { color: "#3c4a7a", azimuth: 270, height: 10, strength: 0.4 }
   toneMapping: aces
   fog: { color: "{colors.horizon}", near: 20, far: 2600, sky: 0.15, curve: 1.4, density: 0.75, sun: 0 }
   lamp: { color: "#dff6f0", intensity: 14, distance: 14 }
@@ -119,6 +120,8 @@
   medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code }
   high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture }
 kit:
+  "^(tex_0[1-5]|wheels|parts_AO)$": keep
+  "^internals$": body
   "^terrain$": dust
   "metalDark": metal
   "metalRed": hazard
```

## DESIGN.md
```diff
--- DESIGN.md (before)	2026-11-12 07:25:27.057312732 +0530
+++ DESIGN.md	2026-11-12 07:25:27.098241729 +0530
@@ -118,6 +118,8 @@
   medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code }
   high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture }
 kit:
+  "^(tex_0[1-5]|wheels|parts_AO)$": keep
+  "^internals$": body
   "^terrain$": dust
   "metalDark": metal
   "metalRed": hazard
```

## DESIGN.storm.md
```diff
--- DESIGN.storm.md (before)	2026-11-12 07:25:27.064888255 +0530
+++ DESIGN.storm.md	2026-11-12 07:25:27.149391829 +0530
@@ -118,6 +118,8 @@
   medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code }
   high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture }
 kit:
+  "^(tex_0[1-5]|wheels|parts_AO)$": keep
+  "^internals$": body
   "^terrain$": dust
   "metalDark": metal
   "metalRed": hazard
```

## Captures to judge it by
- Sunset, looking west from the base: `design/handoff/captures/sunset-west.png`
- Night, the habitat with lit windows: `design/handoff/captures/night-habitat.png`
