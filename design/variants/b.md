---
version: alpha
name: "Outpost Gale B: Toy outpost"
description: "Chunky bevelled machines with big labels in clean afternoon light, lighter haze, a strong cyan for on and usable, yellow trim on the parts you touch. The easiest frame for a 7-year-old to read."
colors:
  primary: "#f5a531"
  on-primary: "#1a0f05"
  surface: "#160f0c"
  surface-container: "#251914"
  on-surface: "#f6ecdc"
  on-surface-variant: "#c9b8a2"
  outline-variant: "#5a4234"
  danger: "#ff4d4d"
  body: "#f3f0ea"
  trim: "#353a42"
  accent: "#16c5ea"
  metal: "#a7adb4"
  glass: "#203447"
  rock: "#8c7064"
  dust: "#c7855a"
  hazard: "#f4be2e"
  light: "#7fe9ff"
  sky: "#d29a6a"
  horizon: "#ecc89e"
  ground: "#a5684a"
  shade: "#9aa2bf"
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
  shading: smooth
  bevel: 0.08
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
  sunColor: "#fff1dc"
  sun: 2.6
  ambient: 1.1
  elevation: 38
  azimuth: 35
  exposure: 1.0
  sunDisc: 0.8
  toneMapping: aces
  fog: { color: "{colors.horizon}", near: 60, far: 8000, sky: 0.15, curve: 0.9 }
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

The easiest to read. Refs 12 (*Astroneer*), 3 and 5.jpg: white hulls with dark trim, fat bevels that catch the light like moulded plastic, big labels, cyan lights for anything that is on, and yellow trim on what you can touch. The afternoon sun is higher and the haze lighter, so every machine reads at a glance. Serious in shape, never cartoon (Ravindu dropped 5.jpeg for that).

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
