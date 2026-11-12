---
version: alpha
name: "Outpost Gale storm"
description: "Dust storm at Gale (the June 2018 storm: opacity 8.5, the sky six to eight times thicker, light turned cherry red): dim red light from all around, a pale sun disc, fog that closes in to a few hundred metres, never black."
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
  visor: "#b8913c"
  sky: "#6a3a2c"
  horizon: "#7e4a3a"
  ground: "#3e1e16"
  shade: "#7c5248"
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
  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0, weathering: 0.6 }
  metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, weathering: 0.35 }
  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 }, weathering: 0 }
  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } }, weathering: 0 }
  hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5, weathering: 0 }
  suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0, weathering: 0 }
  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1, weathering: 0 }
weathering: { color: "{colors.dust}", amount: 0.85, side: 0.65, crevice: 0.6, noise: 1.2, texture: "textures/dust_albedo.jpg", textureSize: 1.5, clean: "^panel_[0-9]+$|^(floor|vest_floor|floor_mat|dashboard)(-col)?$" }
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
  sunColor: "#c8907a"
  sun: 0.45
  ambient: 1.1
  elevation: 22
  azimuth: 330
  exposure: 0.95
  sunDisc: 2.4
  toneMapping: aces
  fog: { color: "{colors.horizon}", near: 2, far: 120, sky: 0.6, curve: 0.5, density: 0.95, sun: 0.2 }
quality:
  low: { msaa: 0, scale: 0.75, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off }
  medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 4, normalBias: 6, glow: 0.4, detail: code }
  high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture }
kit:
  "^(tex_0[1-5]|wheels|parts_AO)$": keep
  "^internals$": body
  "^terrain$": dust
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

# DESIGN.storm.md

A sky state of `DESIGN.md`: the same roles, geometry, quality presets and kit, only the light changes
(the factory's theme rule). `node ../../tools/design-tokens.mjs DESIGN.storm.md design.storm.json` makes its
token file; the sandbox's sky key loads it.

## Overview

A dust storm at Gale, after the June 2018 global storm: dust opacity 8.5, the sky six to eight
times thicker with haze, the light "cherry red" (NASA; `research/godot-build/movement-and-look.md` §5).
Almost no direct sunlight: the sun is a pale disc, shadows are faint, and the light comes from all around.
The fog closes in to a few hundred metres. Dim, never black: the base must always read.

## Colors

Model colours are the ones in `DESIGN.md`: the light, not the paint, changes the look. Only `sky`,
`horizon`, `ground` and `shade` differ, and they feed the light rig and fog only.
