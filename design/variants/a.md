---
version: alpha
name: "Outpost Gale A: Journey dusk"
description: "Faceted flat-shaded rock and machines carried by atmosphere: a low gold sun, a bleached sky near it, haze that dissolves the distance, a palette that is almost one hue, and one teal accent for on, usable and HUD."
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
  glass: "#1d2a3a"
  rock: "#86716a"
  dust: "#c98a5a"
  hazard: "#e7b440"
  light: "#8ef7ea"
  sky: "#c27d4c"
  horizon: "#f6d9a6"
  ground: "#9a5f3d"
  shade: "#7d86ad"
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
  body: { color: "{colors.body}", roughness: 0.6, metalness: 0 }
  trim: { color: "{colors.trim}", roughness: 0.65, metalness: 0 }
  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
  metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1 }
  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0 }
  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { pattern: grain, size: 0.6, strength: 0.35 } }
  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { pattern: grain, size: 1.5, strength: 0.25 } }
  hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5 }
geometry:
  shading: flat
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
lighting:
  sky: "{colors.sky}"
  horizon: "{colors.horizon}"
  ground: "{colors.ground}"
  ambientColor: "{colors.shade}"
  sunColor: "#ffd9a0"
  sun: 2.6
  ambient: 0.9
  elevation: 12
  azimuth: 145
  exposure: 1.0
  sunDisc: 1.2
  toneMapping: aces
  fog: { color: "{colors.horizon}", near: 25, far: 5200, sky: 0.25, curve: 0.8 }
quality:
  low: { msaa: 0, scale: 0.75, shadows: 1, shadowMap: 1024, glow: 0, detail: off }
  medium: { msaa: 2, scale: 1, shadows: 2, shadowMap: 2048, glow: 0.4, detail: code }
  high: { msaa: 4, scale: 1, shadows: 2, shadowMap: 4096, glow: 0.5, detail: code }
kit:
  "metalDark": metal
  "metalRed": hazard
  "^metal$|_defaultMat": body
  "dark|grey|gray|trim": trim
  "rockDark": rock
  "rock|stone|dirt|sand": dust
  "glass|window|screen|visor": glass
  "light|lamp|emissive|glow|crystal": light
  "orange|red|stripe|yellow": hazard
  "teal|cyan|blue|accent": accent
---

# DESIGN.md

The most mood. *Journey* (ref 10) on Mars: the sun sits low and gold, the sky bleaches to cream around it, and haze swallows the far rim so Mount Sharp floats in the distance. Everything is almost one warm hue; the hero's cream suit and teal accent are the only cool things on screen. Faceted, flat-shaded everything (refs 9, 11, 12).

The front matter is the normative part. This file and its `DESIGN.<state>.md` siblings are the only
places a colour value may appear. Prose below is the same in all three variants; only tokens differ.

## Overview

Real in shape, stylised in surface. Real Gale terrain and real sizes, a warm almost-one-hue Mars, one
cool accent. Reference board: `refs/README.md` (confirmed 12 Nov 2026). Avoid ref 8: noon light, no
fog, default colours, grey HUD boxes.

## Colors

- `body`, `trim`: hulls, suits, panels. `hazard`: warm trim on machines (refs 3, 12). Never on the hero.
- `accent`: the one cool colour. It marks the hero, things that are on or usable, and the HUD's
  interactive parts. Small share of any frame. `light` is its glowing form.
- `rock` is the grey stone under the dust; `dust` is the red coat on flat ground. Steep faces show rock.
- `sky`, `horizon`, `ground`, `shade` feed the light rig and fog only. `shade` is the cool ambient that
  keeps shadows from going black or muddy.
- `danger` is HUD only, so red always means a problem. `primary` (amber) is the HUD's main colour.

## Typography

Lexend for sentences (designed for easier reading), 18 px body. A techno display face for numbers
and headings is added once downloaded (OFL), never for sentences.

## Layout

8 px grid. Touch targets at least 48 px. At most 8 words per card.

## Shapes

HUD panels are angled, small radius, thin glowing strokes: a helmet visor display, not a web page.

## Components

`button`: amber, one main action per card. `card`: dark warm translucent panel. `alert`: danger red,
always with an icon, pulsing no faster than 3 times a second.

## Materials

Nine roles: the seven core ones plus `dust` and `hazard`. Kit models map by material name (`kit`).

## Quality

A phone starts on `low` (one shadow split, no glow, no detail), anything else on `high`.

## Geometry & Proportions

1 unit = 1 metre. Person 1.8 m, door 2.0 m. `terrain_*` and the far backdrop have their own class.

## Lighting & Camera

One sun, warm, at the elevation token. Cool ambient. Depth fog in the horizon colour, light on the
sky so the gradient stays. ACES. Night, sunset and dust storm are `DESIGN.<state>.md` files.

## Kit adaptation

Kenney Space Kit: `metal` to body, `metalDark` to metal, `metalRed` to hazard, `dark` to trim,
`rock*` to dust or rock. Crystals do not exist on Mars and are not used.

## Do's and Don'ts

Do keep the accent rare and cool. Do keep Mount Sharp on the horizon. Don't make the astronaut red
or orange. Don't put `danger` on a model. Don't use shapes that cannot exist at Gale.

## Decided exceptions

None yet.
