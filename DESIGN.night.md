---
version: alpha
name: "Outpost Gale night"
description: "Night at Gale: a dark blue-violet sky with no sun, a faint cool sky glow so nothing goes pure black, the base lamps on."
colors:
  primary: "#f0a640"
  on-primary: "#1a0f05"
  surface: "#160f0c"
  surface-container: "#251914"
  on-surface: "#f6ecdc"
  on-surface-variant: "#c9b8a2"
  outline-variant: "#5a4234"
  danger: "#ff4d4d"
  body: "#efe4d0"
  trim: "#4f4744"
  accent: "#2ed3c0"
  metal: "#9c948c"
  glass: "#5b7182"
  rock: "#86716a"
  dust: "#c98a5a"
  hazard: "#e7b440"
  light: "#8ef7ea"
  suit: "#e9e4da"
  plant: "#76a83c"
  sky: "#0e0d1f"
  horizon: "#26233d"
  ground: "#0c0a10"
  shade: "#4a4f86"
typography:
  headline:
    fontFamily: Lexend
    fontSize: 28px
    fontWeight: 700
    lineHeight: 36px
  body:
    fontFamily: Lexend
    fontSize: 18px
    fontWeight: 400
    lineHeight: 26px
  label:
    fontFamily: Lexend
    fontSize: 16px
    fontWeight: 600
    lineHeight: 22px
rounded:
  sm: 4px
  md: 8px
  full: 9999px
spacing:
  "1": 8px
  "2": 16px
  "3": 24px
  "4": 32px
components:
  button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    height: 48px
    padding: 0 24px
  card:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: 16px
  alert:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 8px 16px
materials:
  body: { color: "{colors.body}", roughness: 0.55, metalness: 0.1, detail: { texture: "textures/body_albedo.jpg", normal: "textures/body_normal.jpg", roughness: "textures/body_rough.jpg", textureSize: 2.0, strength: 0.8, pattern: grain, size: 2.0 } }
  trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
  metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5 }
  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
  hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5 }
  suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0 }
geometry:
  shading: smooth
  bevel: 0.03
  bevelSegments: 2
  human: 1.8
  door: 2.0
  budgets:
    prop: { tris: 4000, height: [0.1, 3] }
    building: { tris: 15000, height: [2, 12] }
    vehicle: { tris: 10000, height: [0.5, 5] }
    rock: { tris: 2000, height: [0.1, 8] }
    terrain: { tris: 60000, height: [0, 6000] }
    character: { tris: 12000, height: [1.5, 2.1] }
    pad: { tris: 2000, height: [0, 0.5] }
lighting:
  sky: "{colors.sky}"
  horizon: "{colors.horizon}"
  ground: "{colors.ground}"
  ambientColor: "{colors.shade}"
  sunColor: "#8f9ad0"
  sun: 0.25
  ambient: 0.55
  elevation: 35
  azimuth: 120
  exposure: 1.2
  sunDisc: 0
  toneMapping: aces
  fog: { color: "{colors.horizon}", near: 20, far: 2600, sky: 0.15, curve: 1.4, density: 0.75, sun: 0 }
  lamp: { color: "#dff6f0", intensity: 14, distance: 14 }
quality:
  low: { msaa: 0, scale: 0.75, shadows: 1, shadowMap: 1024, glow: 0, detail: off }
  medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, glow: 0.4, detail: code }
  high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, glow: 0.5, detail: texture }
kit:
  "metalDark": metal
  "metalRed": hazard
  "^metal$|_defaultMat": body
  "dark|grey|gray|trim": trim
  "^rock|stone|cliff": rock
  "dust|dirt|sand": dust
  "glass|window|screen|visor": glass
  "SciFi_Light_Accent": accent
  "SciFi_MainDark|Grey": trim
  "SciFi_Main|SciFi_Light": suit
  "light|lamp|emissive|glow|crystal": light
  "orange|red|stripe|yellow": hazard
  "teal|cyan|blue|accent": accent
---

# DESIGN.night.md

A sky state of `DESIGN.md`: the same roles, geometry, quality presets and kit, only the light changes
(the factory's theme rule). `node ../../tools/design-tokens.mjs DESIGN.night.md design.night.json` makes its
token file; the sandbox's sky key loads it.

## Overview

Night at Gale. No sun: a dark blue-violet sky, a faint cool glow from the sky and the stars that
keeps every surface above black (shapes always read), and the base lamps on. The lamps and beacons carry
the `light` role, and each one lights a pool from `lighting.lamp`. The far rim fades into the dark
horizon colour.

## Colors

Model colours are the ones in `DESIGN.md`: the light, not the paint, changes the look. Only `sky`,
`horizon`, `ground` and `shade` differ, and they feed the light rig and fog only.
