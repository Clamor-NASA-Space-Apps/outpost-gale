---
version: alpha
name: "Outpost Gale"
description: "Variant A (Journey dusk) with realistic surfaces: a low gold sun, a bleached sky near it, haze that dissolves the distance, a palette that is almost one hue, one teal accent for on, usable and HUD, on real Gale ground with photographic texture sets."
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
  sky: "#c27d4c"
  horizon: "#f6d9a6"
  ground: "#9a5f3d"
  shade: "#7d86ad"
  hud-glass: "#160f0c57"
  hud-glass-menu: "#160f0cb8"
  hud-stroke: "#8ef7ea73"
  hud-stroke-faint: "#8ef7ea2e"
  hud-glow: "#2ed3c01f"
  hud-glow-amber: "#f0a64059"
  hud-glow-danger: "#ff4d4d59"
  hud-text-edge: "#160f0cd9"
  hud-highlight: "#ffffff1f"
  hud-arc: "#8ef7ea59"
  hud-arc-faint: "#8ef7ea40"
  hud-ink-faint: "#f6ecdc8c"
  hud-ink-dim: "#f6ecdc99"
  hud-ink-ghost: "#f6ecdc59"
  hud-track: "#f6ecdc26"
  hud-tab-on: "#8ef7ea1a"
  hud-seg-on: "#2ed3c038"
  hud-key: "#160f0c73"
  hud-scrim: "#160f0c73"
  hud-scrim-strong: "#160f0c99"
  hud-scrim-full: "#160f0ccc"
  hud-scrim-menu: "#0a07068c"
  hud-cover-track: "#251914e6"
  hud-cover-edge: "#f0a64099"
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
  # The glass HUD (design/mockups/hud.html and settings.html, approved 13 Nov 2026): tint, a 1.5 px stroke, a soft
  # outer glow and a top highlight, radius 10, no blur (phones). Each translucent token is one of these parts.
  hud-panel:
    backgroundColor: "{colors.hud-glass}"
    rounded: 10px
    padding: 14px 18px
  hud-menu:
    backgroundColor: "{colors.hud-glass-menu}"
    rounded: 10px
    padding: 26px 30px
  hud-stroke:
    backgroundColor: "{colors.hud-stroke}"
    width: 1.5px
  hud-divider:
    backgroundColor: "{colors.hud-stroke-faint}"
    height: 1px
  hud-glow:
    backgroundColor: "{colors.hud-glow}"
    size: 18px
  hud-glow-picked:
    backgroundColor: "{colors.hud-glow-amber}"
    size: 16px
  hud-glow-alert:
    backgroundColor: "{colors.hud-glow-danger}"
    size: 18px
  hud-text-outline:
    backgroundColor: "{colors.hud-text-edge}"
    size: 2px
  hud-highlight:
    backgroundColor: "{colors.hud-highlight}"
    height: 1px
  hud-visor-arc:
    backgroundColor: "{colors.hud-arc}"
    height: 1.5px
  hud-visor-arc-low:
    backgroundColor: "{colors.hud-arc-faint}"
    height: 1.5px
  hud-compass-tick:
    backgroundColor: "{colors.hud-ink-faint}"
    width: 2px
    height: 10px
  hud-compass-number:
    textColor: "{colors.hud-ink-dim}"
  hud-bubble-untyped:
    textColor: "{colors.hud-ink-ghost}"
  hud-meter-track:
    backgroundColor: "{colors.hud-track}"
    height: 6px
    rounded: 3px
  hud-tab-open:
    backgroundColor: "{colors.hud-tab-on}"
  hud-segment-on:
    backgroundColor: "{colors.hud-seg-on}"
  hud-key:
    backgroundColor: "{colors.hud-key}"
    rounded: 5px
  hud-scrim:
    backgroundColor: "{colors.hud-scrim}"
  hud-scrim-strong:
    backgroundColor: "{colors.hud-scrim-strong}"
  hud-scrim-full:
    backgroundColor: "{colors.hud-scrim-full}"
  hud-scrim-menu:
    backgroundColor: "{colors.hud-scrim-menu}"
  hud-cover-track:
    backgroundColor: "{colors.hud-cover-track}"
  hud-cover-edge:
    backgroundColor: "{colors.hud-cover-edge}"
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
  paver: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", roughness: "textures/gravel_rough.jpg", textureSize: 2.48, strength: 1.0, pattern: grain, size: 2.48 }, weathering: 0 }
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
  sunColor: "#ffd9a0"
  sun: 2.6
  ambient: 1.25
  elevation: 12
  azimuth: 345
  exposure: 1.0
  sunDisc: 1.2
  toneMapping: aces
  fog: { color: "{colors.horizon}", near: 25, far: 3500, sky: 0.25, curve: 1.0, density: 0.75, sun: 0.4 }
  room: { color: "#f4efe6", intensity: 6, distance: 4.5 }
quality:
  phone: { start: phone, msaa: 0, pixels: 0.6, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off, aniso: 1, ground: flat, particles: 0.5, trail: 1024, lamps: 2 }
  older: { msaa: 0, pixels: 0.8, shadows: 1, shadowMap: 1024, shadowRange: 25, shadowFilter: 2, normalBias: 2, glow: 0, detail: off, aniso: 1, ground: cheap, particles: 0.5, trail: 1024, lamps: 2 }
  laptop: { start: desktop, msaa: 2, pixels: 1.4, shadows: 2, shadowMap: 2048, shadowRange: 40, shadowFilter: 3, normalBias: 6, glow: 0.4, detail: texture, aniso: 2, ground: full, particles: 0.75, trail: 2048, lamps: 4 }
  gaming: { msaa: 4, scale: 1, shadows: 4, shadowMap: 4096, shadowRange: 40, shadowFilter: 4, normalBias: 3, glow: 0.5, detail: texture, aniso: 3, ground: full, particles: 1, trail: 2048 }
  max: { msaa: 8, scale: 1, shadows: 4, shadowMap: 4096, shadowRange: 40, shadowFilter: 5, normalBias: 3, glow: 0.5, ssao: true, detail: texture, aniso: 4, ground: full, particles: 1, trail: 2048 }
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

# DESIGN.md

Picked by Ravindu on 12 Nov 2026: variant A's light and mood, with realistic surfaces ("the graphics look
low-quality... it doesn't feel like a web-based game"). The bar for surfaces sits between ref 3 (HABITAT 01
render) and ref 4 (Godot hangar demo).

*Journey* (ref 10) on Mars: the sun sits low and gold, the sky bleaches to cream around it, and haze
swallows the far rim so Mount Sharp's flanks float in the distance. Everything is almost one warm hue; the
hero's cream suit and teal accent are the only cool things on screen. Surfaces are photographic: real
HiRISE ground at 1 m detail, texture sets (colour, normal, roughness) on every role, reflections from probes.

The front matter is the normative part. This file and its `DESIGN.<state>.md` siblings are the only
places a colour value may appear. Prose below is the same in all three variants; only tokens differ.

## Overview

Real in shape, stylised in surface. Real Gale terrain and real sizes, a warm almost-one-hue Mars, one
cool accent. Reference board: `refs/README.md` (confirmed 12 Nov 2026). Avoid ref 8: noon light, no
fog, default colours, grey HUD boxes.

## Colors

- `body`, `trim`: hulls, suits, panels. `hazard`: warm trim on machines (refs 3, 12). Never on the hero.
- `stripe`: the dark orange bands on the suit's arms and legs (Ravindu, 12 Nov 2026), nowhere else. The suit
  stays white, so the hero still reads against Mars.
- `accent`: the one cool colour. It marks the hero, things that are on or usable, and the HUD's
  interactive parts. Small share of any frame. `light` is its glowing form.
- `rock` is the grey stone under the dust; `dust` is the red coat on flat ground. Steep faces show rock.
- `paver` is sintered regolith laid flat (the build pads): rock's colour with the gravel photo, because the
  cliff photo on a flat slab read as grey-blue blobs (approved by Ravindu on 13 Nov 2026).
- `sky`, `horizon`, `ground`, `shade` feed the light rig and fog only. `shade` is the cool ambient that
  keeps shadows from going black or muddy.
- `grow` is the plant light's magenta glow and nothing else; `romaine` is red leaves and roots only.
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

Eighteen roles: `deck` (the swept floor plates inside HAB 1 and the greenhouse aisle, a warm grey without shine: as `metal` it mirrored the warm sky and read as sand in first person, 13 Nov 2026), `panel` (the painted face of indoor cabinets, racks, cubicle walls, HAB 1's wall liner and a hatch's room side: in `body` they wore the hull's metal plates, 12 Nov playtest, and the hull's inside took the dust coat and read peach), `bedding` (the sleeping bags' and the curtains' muted blue, so a bed reads as a bed at a glance and a curtain shows against the white walls; art direction; `deck`, `panel` and `bedding` approved by Ravindu on 13 Nov 2026), `visor` (an EVA helmet's gold sun visor: opaque, so no face ever shows), plus the seven core ones and `dust` (the ground), `hazard`, `suit` (the astronauts' fabric, so they never wear hull panels), `stripe` (the suit's bands), `plant` (lettuce green, Ravindu's pick on 12 Nov), `romaine` (the red leaf of 'Outredgeous', the first lettuce eaten in space, and a radish's red root) and `grow` (the magenta glow of Veggie's red 630 nm and blue 455 nm LEDs, NTRS 20160005059; both roles approved by Ravindu on 12 Nov 2026). Kit models map by material name (`kit`).

Glass (`opacity` 0.15 per surface, Ravindu's 12 Nov playtest asking for clear greenhouse panes): the greenhouse dome
is a 4 cm shell, so a look through it crosses four surfaces, and 0.5 each let only 6% of the far side through. No
sky state lights the glass pane by pane (`lit`): HAB 1 and the greenhouse have their rooms modelled behind it, and the
dome is one pane, so it glowed as one cream lantern at night and flipped clear every 90 s at sunset. Their own lights
(HAB 1's ceiling strips, the magenta grow bars) show through instead.

Photo sets (CC0, `textures/README.md`): body MetalPlates009, metal Metal011, trim Rubber004, suit
Fabric061, rock cliff_side, dust moon_02 (fine powder, after Ravindu asked for a soft Sahara / *The Martian*
ground), with gravelly_sand patches and aerial_beach_01 wind ripples on the ground. Each only shades its role's colour.

Dust coat (`weathering`, skills/surface-weathering), asked for by Ravindu on 12 Nov 2026 ("nothing can exist shining
on Mars"): every model wears settled dust in the `dust` colour, the same colour the hero's boots pick up. Level tops
are 60% covered, about 460 sols at the typical 0.2% per sol (Lorenz 2021); walls a share of that, undersides none,
more in the seams of each photo set. Thin, it tints the paint and lets its plates and lettering show; it always takes
the shine. The storm file raises tops to 85% and walls to 65% of that (Curiosity's vertical target reached 49% in a
major storm). Clean on purpose: the solar panels (swept, `clean`), pressurised floors and HAB 1's fit-out (`interior`: habitat, greenhouse, rover cabin: crews sweep them), lights, the visor, plants, the ground and rocks
(already dust). Glass gets a film (0.35), the teal accent stays legible (0.6). `design/research/pages/dust-coat/`.

## Quality

Five presets named for the hardware, weakest first: `phone` (budget phones such as the Galaxy A16), `older` (Intel HD
laptops, 6th to 8th gen), `laptop` (Iris Xe and UHD), `gaming` (a graphics card) and `max`. A phone starts on `phone`,
anything else on `laptop` (`start`). Each value and its measured cost: `design/research/presets.md`. `gaming` splits its sun shadow in four: with a
sun that moves to 60 degrees, two splits stair-stepped the greenhouse frame's shadows on its floor, and four cost nothing
measurable on a graphics card (approved by Ravindu on 13 Nov 2026).

## Geometry & Proportions

1 unit = 1 metre. Person 1.8 m, door 2.0 m. `terrain_*` and the far backdrop have their own class, and so do
`character_*` (the Quaternius astronaut is 10.6k triangles; never decimate a skinned model) and `pad_*` (flat).

## Lighting & Camera

One sun, warm, at the elevation token. Cool ambient. Depth fog in the horizon colour, light on the
sky so the gradient stays. ACES. Night, sunset and dust storm are `DESIGN.<state>.md` files.
Indoors, one unshadowed ceiling light per room (`lighting.room`, the same in every sky): always on, like the
ISS's LED panels, so HAB 1 and the greenhouse look by day as they do at night. It lights only the rooms' own render
layer, never the ground outside through a wall (approved by Ravindu on 13 Nov 2026). The greenhouse's light is `{colors.growlight}` (data/world.json
`probe.rooms`),
Veggie's red and blue LEDs with some green (630, 455 and 530 nm, NTRS 20160005059): under pure `grow` magenta the
yellow-green lettuce read olive and tan, as if dying (approved by Ravindu on 13 Nov 2026). The LED bars stay `grow`.

## Kit adaptation

Kenney Space Kit: `metal` to body, `metalDark` to metal, `metalRed` to hazard, `dark` to trim,
`rock*` to dust or rock. Crystals do not exist on Mars and are not used.

## Do's and Don'ts

Do keep the accent rare and cool. Do keep Mount Sharp on the horizon. Don't make the astronaut red
or orange (the bands are the only orange on it). Don't put `danger` on a model. Don't use shapes that cannot exist at Gale.

## Decided exceptions

- Smooth shading and photo texture sets instead of the faceted low-poly look the brief proposed: Ravindu
  rejected flat surfaces as low quality on 12 Nov 2026.
- Download size is not a limit (hosted on Ravindu's home server; an internet build gets a loading bar).
  Texture memory still is: iPhone 16 and 17 Safari are the phones.
- Walls carry more dust than measured: Curiosity's vertical target averaged 4.7% (Lorenz 2021), our day walls about
  27%, so a wall reads as dusty too (Ravindu: "cover up every single object"). The storm's 55% is near its 49% peak.
- `vehicle_curiosity.glb` keeps NASA's own textures (the real rover, insignia painted out) instead of role
  colours, so style-check reports its materials as not roles. Check the other models with it left out.
