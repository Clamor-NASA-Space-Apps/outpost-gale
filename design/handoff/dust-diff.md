# Dust coat: look change (12 Nov 2026, dust-coat lane)

Ravindu asked for it: "we need to cover up every single object except the panels with the dust ... surface dust
levels become worse in the storm mode ... accurate to what happens irl ... should not choke the performance ...
we can see the texture of underlying layer of the object through the dust". That request is the approval; this file
records the change as the factory asks (`diff -u old new` of every DESIGN file, before and after pictures).
Revert: restore the four DESIGN files and the token files, and the factory's `house_style.gd` and `surface.gdshader`.

## What changes and why
1. **A dust coat on every model** (`weathering`, factory skill `surface-weathering`): settled dust in the `dust`
   colour. Level tops 60% covered (about 460 sols at the typical 0.2% per sol, Lorenz 2021), walls 0.45 of that,
   undersides none, more in the dark seams of each photo set (sand "fills cracks", Mishkinis 2013). Thin, it acts as
   a filter (Mars dust is "dark at blue wavelengths and bright in the red", Kinch 2015): plates, lettering and bumps
   show through. Wherever it lies, roughness goes up and metalness down (a dusty array is diffuse, a clean one "more
   like specular glass", Vaughan 2010).
2. **Storm is worse:** tops 85%, walls 0.65 of that (55%; Curiosity's vertical target reached 49% "during a major
   dust storm", Lorenz 2021 after Yingst 2020). Sunset and night keep the day's coat. The sky key's restyle carries it.
3. **Kept clean on purpose:** solar panels (`clean: "^panel_[0-9]+$"`, the moving panel nodes, glass and frame),
   lights (0), visor (0), plants (0), ground and rocks (0, already dust-coloured). Glass gets a film (0.35, still
   see-through). The teal accent keeps 0.6 so usable things still read. Curiosity's own NASA textures get the coat too.
4. **Decided exception:** walls carry more than measured (vertical target mean 4.7%), so walls read dusty too.
5. **Performance:** no extra pass or draw call (counts below are equal), a few ALU ops; `low` is the plain mask,
   `medium` adds ALU noise patches, `high` adds the ground's own dust photo (already loaded, no new memory).

## Draw calls, before and after (capture-view, same views)
| View | Before | After |
|---|---|---|
| default | 216 | 216 |
| base | 202 | 202 |
| hero | 59 | 59 |
| panel | 108 | 108 |
| wall close-up | 147 | 147 |
| rover roof close-up | 146 | 146 |
| Curiosity | 34 | 34 |
| storm default / base / panel | 195 / 193 / 136 | 195 / 193 / 136 |
| storm wall / roof close-ups | 131 / 150 | 131 / 150 |

## Pictures (before left, after right; `captures/dust/` beside this file, local only)
`day_wall.png`, `day_rover_roof.png`, `day_solar_panel.png` (clean), `day_curiosity.png`, `day_base.png`,
`day_default.png`, `day_hero.png`, `storm_wall.png`, `storm_rover_roof.png`, `storm_solar_panel.png` (clean),
`storm_base.png`, and `low_wall_after.png` (the phone preset).

## DESIGN.md
```diff
--- DESIGN.md (before)
+++ DESIGN.md
@@ -75,16 +75,17 @@
 materials:
   body: { color: "{colors.body}", roughness: 0.55, metalness: 0.1, detail: { texture: "textures/body_albedo.jpg", normal: "textures/body_normal.jpg", roughness: "textures/body_rough.jpg", textureSize: 2.0, strength: 0.8, pattern: grain, size: 2.0 } }
   trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
-  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
+  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0, weathering: 0.6 }
   metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
-  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5 }
-  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
-  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
+  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, weathering: 0.35 }
+  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 }, weathering: 0 }
+  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } }, weathering: 0 }
   hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
-  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5 }
+  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5, weathering: 0 }
   suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
-  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0 }
-  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1 }
+  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0, weathering: 0 }
+  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1, weathering: 0 }
+weathering: { color: "{colors.dust}", amount: 0.6, side: 0.45, crevice: 0.6, noise: 1.2, texture: "textures/dust_albedo.jpg", textureSize: 1.5, clean: "^panel_[0-9]+$" }
 geometry:
   shading: smooth
   bevel: 0.03
@@ -192,6 +193,14 @@
 Fabric061, rock cliff_side, dust moon_02 (fine powder, after Ravindu asked for a soft Sahara / *The Martian*
 ground), with gravelly_sand patches and aerial_beach_01 wind ripples on the ground. Each only shades its role's colour.
 
+Dust coat (`weathering`, skills/surface-weathering), asked for by Ravindu on 12 Nov 2026 ("nothing can exist shining
+on Mars"): every model wears settled dust in the `dust` colour, the same colour the hero's boots pick up. Level tops
+are 60% covered, about 460 sols at the typical 0.2% per sol (Lorenz 2021); walls a share of that, undersides none,
+more in the seams of each photo set. Thin, it tints the paint and lets its plates and lettering show; it always takes
+the shine. The storm file raises tops to 85% and walls to 65% of that (Curiosity's vertical target reached 49% in a
+major storm). Clean on purpose: the solar panels (swept, `clean`), lights, the visor, plants, the ground and rocks
+(already dust). Glass gets a film (0.35), the teal accent stays legible (0.6). `design/research/pages/dust-coat/`.
+
 ## Quality
 
 A phone starts on `low` (one shadow split, no glow, no detail), anything else on `high`.
@@ -222,5 +231,7 @@
   rejected flat surfaces as low quality on 12 Nov 2026.
 - Download size is not a limit (hosted on Ravindu's home server; an internet build gets a loading bar).
   Texture memory still is: iPhone 16 and 17 Safari are the phones.
+- Walls carry more dust than measured: Curiosity's vertical target averaged 4.7% (Lorenz 2021), our day walls about
+  27%, so a wall reads as dusty too (Ravindu: "cover up every single object"). The storm's 55% is near its 49% peak.
 - `vehicle_curiosity.glb` keeps NASA's own textures (the real rover, insignia painted out) instead of role
   colours, so style-check reports its materials as not roles. Check the other models with it left out.
```

## DESIGN.sunset.md
```diff
--- DESIGN.sunset.md (before)
+++ DESIGN.sunset.md
@@ -75,16 +75,17 @@
 materials:
   body: { color: "{colors.body}", roughness: 0.55, metalness: 0.1, detail: { texture: "textures/body_albedo.jpg", normal: "textures/body_normal.jpg", roughness: "textures/body_rough.jpg", textureSize: 2.0, strength: 0.8, pattern: grain, size: 2.0 } }
   trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
-  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
+  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0, weathering: 0.6 }
   metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
-  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, lit: { color: "#ffbe72", emissive: 1.5, share: 0.6, period: 90 } }
-  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
-  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
+  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, lit: { color: "#ffbe72", emissive: 1.5, share: 0.6, period: 90 }, weathering: 0.35 }
+  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 }, weathering: 0 }
+  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } }, weathering: 0 }
   hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
-  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5 }
+  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5, weathering: 0 }
   suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
-  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0 }
-  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1 }
+  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0, weathering: 0 }
+  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1, weathering: 0 }
+weathering: { color: "{colors.dust}", amount: 0.6, side: 0.45, crevice: 0.6, noise: 1.2, texture: "textures/dust_albedo.jpg", textureSize: 1.5, clean: "^panel_[0-9]+$" }
 geometry:
   shading: smooth
   bevel: 0.03
```

## DESIGN.night.md
```diff
--- DESIGN.night.md (before)
+++ DESIGN.night.md
@@ -75,16 +75,17 @@
 materials:
   body: { color: "{colors.body}", roughness: 0.55, metalness: 0.1, detail: { texture: "textures/body_albedo.jpg", normal: "textures/body_normal.jpg", roughness: "textures/body_rough.jpg", textureSize: 2.0, strength: 0.8, pattern: grain, size: 2.0 } }
   trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
-  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
+  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0, weathering: 0.6 }
   metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
-  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, lit: { color: "#ffbe72", emissive: 1.5, share: 0.85, period: 90 } }
-  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
-  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
+  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, lit: { color: "#ffbe72", emissive: 1.5, share: 0.85, period: 90 }, weathering: 0.35 }
+  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 }, weathering: 0 }
+  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } }, weathering: 0 }
   hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
-  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5 }
+  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5, weathering: 0 }
   suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
-  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0 }
-  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1 }
+  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0, weathering: 0 }
+  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1, weathering: 0 }
+weathering: { color: "{colors.dust}", amount: 0.6, side: 0.45, crevice: 0.6, noise: 1.2, texture: "textures/dust_albedo.jpg", textureSize: 1.5, clean: "^panel_[0-9]+$" }
 geometry:
   shading: smooth
   bevel: 0.03
```

## DESIGN.storm.md
```diff
--- DESIGN.storm.md (before)
+++ DESIGN.storm.md
@@ -75,16 +75,17 @@
 materials:
   body: { color: "{colors.body}", roughness: 0.55, metalness: 0.1, detail: { texture: "textures/body_albedo.jpg", normal: "textures/body_normal.jpg", roughness: "textures/body_rough.jpg", textureSize: 2.0, strength: 0.8, pattern: grain, size: 2.0 } }
   trim: { color: "{colors.trim}", roughness: 0.75, metalness: 0, detail: { texture: "textures/trim_albedo.jpg", normal: "textures/trim_normal.jpg", roughness: "textures/trim_rough.jpg", textureSize: 0.75, strength: 0.6, pattern: grain, size: 0.75 } }
-  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0 }
+  accent: { color: "{colors.accent}", roughness: 0.45, metalness: 0, weathering: 0.6 }
   metal: { color: "{colors.metal}", roughness: 0.4, metalness: 1, detail: { texture: "textures/metal_albedo.jpg", normal: "textures/metal_normal.jpg", roughness: "textures/metal_rough.jpg", textureSize: 1.0, strength: 0.8, pattern: grain, size: 1.0 } }
-  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5 }
-  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 } }
-  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } } }
+  glass: { color: "{colors.glass}", roughness: 0.08, metalness: 0, opacity: 0.5, weathering: 0.35 }
+  rock: { color: "{colors.rock}", roughness: 0.95, metalness: 0, detail: { texture: "textures/rock_albedo.jpg", normal: "textures/rock_normal.jpg", roughness: "textures/rock_rough.jpg", textureSize: 1.83, strength: 1.0, pattern: grain, size: 1.83 }, weathering: 0 }
+  dust: { color: "{colors.dust}", roughness: 1, metalness: 0, detail: { texture: "textures/dust_albedo.jpg", normal: "textures/dust_normal.jpg", roughness: "textures/dust_rough.jpg", textureSize: 3.1, strength: 1.0, pattern: grain, size: 3.1, gravel: { texture: "textures/gravel_albedo.jpg", normal: "textures/gravel_normal.jpg", textureSize: 2.48, share: 0.3 }, ripple: { normal: "textures/ripple_normal.jpg", textureSize: 12 } }, weathering: 0 }
   hazard: { color: "{colors.hazard}", roughness: 0.5, metalness: 0 }
-  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5 }
+  light: { color: "{colors.light}", roughness: 0.4, metalness: 0, emissive: 2.5, weathering: 0 }
   suit: { color: "{colors.suit}", roughness: 0.85, metalness: 0, detail: { texture: "textures/suit_albedo.jpg", normal: "textures/suit_normal.jpg", roughness: "textures/suit_rough.jpg", textureSize: 0.4, strength: 0.7, pattern: grain, size: 0.4 } }
-  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0 }
-  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1 }
+  plant: { color: "{colors.plant}", roughness: 0.6, metalness: 0, weathering: 0 }
+  visor: { color: "{colors.visor}", roughness: 0.12, metalness: 1, weathering: 0 }
+weathering: { color: "{colors.dust}", amount: 0.85, side: 0.65, crevice: 0.6, noise: 1.2, texture: "textures/dust_albedo.jpg", textureSize: 1.5, clean: "^panel_[0-9]+$" }
 geometry:
   shading: smooth
   bevel: 0.03
```

