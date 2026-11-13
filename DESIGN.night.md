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
  deck: "#86827c"
  panel: "#dedad2"
  bedding: "#45607e"
  glass: "#5b7182"
  rock: "#86716a"
  dust: "#c98a5a"
  hazard: "#e7b440"
  stripe: "#d8691c"
  light: "#8ef7ea"
  suit: "#e9e4da"
  plant: "#76a83c"
  romaine: "#7e2a3a"
  grow: "#e04fd2"
  growlight: "#e889d6"
  visor: "#b8913c"
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
  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0, weathering: 0.6 }
  metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
  deck: { color: "{colors.deck}", roughness: 0.7, metalness: 0, weathering: 0, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.6, pattern: grain, size: 1.0 } }
  panel: { color: "{colors.panel}", roughness: 0.5, metalness: 0, weathering: 0 }
  bedding: { color: "{colors.bedding}", roughness: 0.9, metalness: 0, weathering: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.15, weathering: 0.35 }
  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 }, weathering: 0 }
  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } }, weathering: 0 }
  hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
  stripe: { color: "{colors.stripe}", roughness: 0.8, metalness: 0 }
  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5, weathering: 0 }
  suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0, weathering: 0 }
  romaine: { color: "{colors.romaine}", roughness: 0.6, metalness: 0, weathering: 0 }
  grow: { color: "{colors.grow}", roughness: 0.4, metalness: 0, emissive: 2.0, weathering: 0 }
  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1, weathering: 0 }
weathering: { color: "{colors.dust}", amount: 0.6, side: 0.45, crevice: 0.6, noise: 1.2, texture: "textures/dust_albedo.jpg", textureSize: 1.5, clean: "^panel_[0-9]+$|^(floor|vest_floor|floor_mat|dashboard|interior)(-col)?$" }
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
  twilight: { color: "#3c4a7a", azimuth: 270, height: 10, strength: 0.4 }
  toneMapping: aces
  fog: { color: "{colors.horizon}", near: 20, far: 2600, sky: 0.15, curve: 1.4, density: 0.75, sun: 0 }
  room: { color: "#f4efe6", intensity: 6, distance: 4.5 }
  lamp: { color: "#dff6f0", intensity: 14, distance: 14 }
  celestial:
    pole: [317.681, 52.887]
    latitude: -4.59
    radius: 3389.5
    day: 88642.4
    sun: [288.17, -23.95]
    hour: 19.5
    timeScale: 10
    tau: 0.5
    stars: { map: textures/sky/stars.png, list: textures/sky/star_list.png, brightness: 2.0, milkyWay: 0.6, milkyColor: "#dfe3f0" }
    planets:
      - { name: Earth, ra: 327.44, dec: -15.14, mag: -2.3, color: "#a9c8ff" }
      - { name: Venus, ra: 314.21, dec: -19.93, mag: -2.7, color: "#fff4dc" }
      - { name: Jupiter, ra: 148.02, dec: 13.31, mag: -2.8, color: "#ffe8c8" }
      - { name: Saturn, ra: 3.65, dec: -1.29, mag: 0.9, color: "#ffe0a0" }
    moons:
      - { name: Phobos, radius: 11.08, orbit: 9375, period: 27554, start: -25, color: "#8c8780", brightness: 6.0 }
      - { name: Deimos, radius: 6.2, orbit: 23457, period: 109075, start: 20, color: "#8c8780", brightness: 6.0 }
quality:
  phone: { start: phone, msaa: 0, pixels: 0.6, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off, aniso: 1, ground: flat, particles: 0.5, trail: 1024, lamps: 2 }
  older: { msaa: 0, pixels: 0.8, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off, aniso: 1, ground: cheap, particles: 0.5, trail: 1024, lamps: 2 }
  laptop: { start: desktop, msaa: 2, pixels: 1.4, shadows: 2, shadowMap: 2048, shadowRange: 60, shadowFilter: 3, normalBias: 6, glow: 0.4, detail: texture, aniso: 2, ground: full, particles: 0.75, trail: 2048, lamps: 4 }
  gaming: { msaa: 4, scale: 1, shadows: 4, shadowMap: 4096, shadowRange: 60, shadowFilter: 4, normalBias: 4, glow: 0.5, detail: texture, aniso: 3, ground: full, particles: 1, trail: 2048 }
  max: { msaa: 8, scale: 1, shadows: 4, shadowMap: 4096, shadowRange: 60, shadowFilter: 5, normalBias: 4, glow: 0.5, ssao: true, detail: texture, aniso: 4, ground: full, particles: 1, trail: 2048 }
kit:
  "^(tex_0[1-5]|wheels|parts_AO)$": keep
  "^(iss_panels|mercou_photo|gale_photo)$": keep
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

The greenhouse's room light is `{colors.growlight}` (data/world.json `probe.rooms`), as in DESIGN.md.
