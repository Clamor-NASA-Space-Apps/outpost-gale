# Performance: what the 2007-2011 games did, and what Outpost Gale can steal

Research of 12 Nov 2026, for the ask "make it feel like something that came out of Activision in 2010": stunning
on weak hardware, at 60 fps. Sources and quotes are in `pages/performance/excerpts.md` (letters A and B below point
there). No game was run for this; a separate profiling run measures the real game. Where this file says
"expected", the profile decides.

**TL;DR.** Those games looked rich because they paid for light once, offline, and spent the live frame on the
few things that move. They rendered fewer pixels than the screen had (1024x600 on consoles), allowed one live
shadowed light per surface, and fixed the frame rate first and the art second. Godot's Compatibility renderer on
WebGL 2 can do most of the cheap half of that, but it has three costs we did not know about: every lit object is
drawn twice while the sun casts shadows, the web build forgets every compiled shader between visits, and a phone
renders at its full 3x pixel density unless we say otherwise. Fix the hitches first (warm-up, trail map), then
the pixel count, then the second sun pass.

---

## 1. What the 2007-2011 games did 🎮

### 1.1 Frame rate first, art second
- Infinity Ward "committed to keeping at 60 frames per second throughout both single- and multiplayer modes" on
  Call of Duty 4 (A1, 2007). Treyarch, five years on: "The one requirement for a Call of Duty game is that it has
  to run at 60 frames per second on a console" (A4).
- It was a budget, not a promise kept every frame: "the mere 16.66ms of rendering time available per frame", and
  the goal was a "perceptual 60FPS", high enough to pass as 60 (A3).
- Treyarch built one "Beautiful Corner" of a map first, a vertical slice that set the look inside the budget (A4).
- id Tech 5 (Rage) went further: it altered "model complexity and texture resolution" on the fly to hold 60 (A12),
  with visible texture popping as the price.

### 1.2 Fewer pixels, then anti-aliasing
- Console Call of Duty ran "at the standard COD resolution of 1024x600 with 2x multi-sample anti-aliasing", and
  "the sub-HD nature of the console games is mitigated somewhat by the high frame-rate" (A3). That is 0.61 million
  pixels, about two thirds of 720p.
- Particles and smoke were drawn into lower-resolution alpha buffers on PS3 to save fill rate (A3).
- On the web the same advice stands: "rendering into a smaller back buffer, and upscaling the result" (A17).

### 1.3 Light paid for once, offline
- "Call of Duty has always been a lightmapped title" (A6). Lighting was baked three ways side by side:
  "lightmap, vertex bake, light probe" (A5).
- Moving things were lit from a coarse grid of baked samples: Valve stored "ambient cube" samples every
  4 x 4 x 8 feet "since indirect illumination varies slowly", picked the one nearest the model's centre, and
  time-averaged it to hide jumps (A8). Activision calls its version the light grid (A6).
- Shiny surfaces reflected cube maps "pre-rendered" at hand-placed points and "stored as part of the static level
  data" (A8). Nothing reflected live.
- Ambient occlusion lived in textures: "it is common to use an additional texture channel to hold an ambient
  occlusion field" (A9). Valve later folded it into the bump map at no extra memory, and the result was faster (A9).

### 1.4 One live shadowed light, and cheap shadows
- Call of Duty 4: the sun is "a real time dynamic light that casts shadows", and "You may only have one active
  primary light on a surface" (A7, community copy of the mod-tool docs, ⚠️).
- Source on 2006 hardware: two local lights per pixel at most; the rest were added to the ambient cube (A8).
- Shadows were cheap and soft-edged by being low resolution: "Owing to the 60FPS nature of the game [...] they're
  very low res" (A3). Later Treyarch pre-baked whole-level shadow maps to "quickly shadow far objects" (A6).

### 1.5 Draw fewer things, in fewer calls
- Below about 130 triangles per batch a 2003 PC was "completely CPU-limited": the cost is the call, not the
  triangles, at roughly "25k batches/s @ 100% 1 GHz CPU" (A13). Texture atlases existed to merge batches (A14, A17).
- Precomputed visibility skipped hidden objects without runtime queries: 2.7 ms saved on the Xbox 360 render
  thread in Epic's sample (A11). It shines indoors and in "fairly 2D play areas"; it has a "Tiny 1ms hitch [...]
  when moving to a new area" (A11).
- Textures streamed in as needed; fast scenes showed low-resolution textures for a moment (A2).

### 1.6 Post effects: what they used and what they skipped
- Used: tone mapping and bloom, colour correction, "minimal motion blur [...] 15% of full-frame shutter", and
  motion blur switched off on a frame after a hitch (A10). Expensive analysis was spread over frames: "Amortize the
  cost of building the histogram over 16 frames" (A10).
- Skipped on consoles: screen-space ambient occlusion appeared only in the PC version of Modern Warfare 3 (A3).
  Depth of field and film grain were per-game choices (Mass Effect's grain was a switch, A18 ⚠️).
- What made them read as expensive was light and colour: Digital Foundry called Modern Warfare 2's lighting "one
  of the really impressive things in this game" (A2). Strong key light, graded colour, normal and specular maps,
  baked occlusion. Not more geometry.

---

## 2. What Godot 4.7 Compatibility on WebGL 2 can do of it 🔧

| 2010 technique | In our renderer | Notes |
|---|---|---|
| Fixed 60 fps budget, perceptual 60 | ✅ | Ours to enforce: a route profile with budgets (section 6) |
| Lower render resolution + upscale | ✅ `Viewport.scaling_3d_scale` | Bilinear only: FSR "will fall back to bilinear" (B12) |
| Dynamic resolution (id Tech 5) | ⚠️ by script | Change the scale in steps; each change likely reallocates buffers (inferred), so step rarely |
| MSAA | ✅ 3D only | FXAA, SMAA, TAA: not in Compatibility (B1) |
| Low-res particle buffer | ❌ | No separate alpha buffer; cap particle size and count instead |
| Lightmaps | ⚠️ render only | "Baking requires hardware with RenderingDevice support"; on the web only rendering lightmaps baked elsewhere (B1, B7). Our 4 skies would need 4 bakes |
| Light grid for moving things | ⚠️ | LightmapGI's probes do this, only with a lightmap bake (B7). Our substitute: the rig's ambient colour plus the reflection probe |
| Baked reflection cube maps | ✅ ReflectionProbe `UPDATE_ONCE` | "2 per mesh" in Compatibility (B1); redraws over six frames when touched (B11) |
| AO in textures or vertex colours | ✅ | `AO` in a spatial shader, vertex colours, our contact map |
| SSAO | ✅ simplified | New since 4.6, "should perform significantly better on low-end devices" (B13). Cost on our devices unmeasured |
| One shadowed sun | ✅ | But each shadowed light adds a second draw of every lit object (section 3.1) |
| Baked far shadows (shadowmask) | ⚠️ | Needs a LightmapGI bake (B7) |
| Blob shadows | ⚠️ | Decals are not in Compatibility (B1); our terrain shader's `movers` discs do this already |
| Precomputed visibility, portals | ❌ | Godot 4 has no PVS or portals |
| Occlusion culling | ❌ on the web | "not supported by default in Web export templates" (B8), and open ground gains little anyway |
| Manual LOD, HLOD, impostors | ✅ visibility ranges | No fade in Compatibility: "acts like FADE_DISABLED but with hysteresis disabled" (B9), so objects pop |
| Automatic mesh LOD | ✅ for imported GLBs | Generated on import (B16); meshes we merge at runtime with SurfaceTool keep none (inferred) |
| Batching | ✅ | Auto-instancing of identical opaque meshes, MultiMesh, our per-cell merge (B10) |
| Texture atlases, channel packing | ✅ | Ours to do in the asset pipeline |
| Shader precompile | ❌ | No ubershaders, no pipeline cache, no shader baker in Compatibility; on the web no shader cache at all (B2, B3). Only the old way: draw everything once while loading |
| Fog to hide the far edge | ✅ depth and height fog | Volumetric fog is Forward+ only (B1) |
| Soft particles | ✅ proximity fade | Costs a depth copy per frame (skills/ground-contact-fx) |
| Texture streaming | ❌ | Everything loads at start; keep texture memory inside the phone's budget instead |
| VRAM texture compression | ✅ | Both desktop and mobile formats are on in our web preset |
| Film grain, vignette, colour grading | ✅ | Grading through Environment adjustments; grain and vignette need a full-screen pass (B1) |
| GPU particles | ✅ with limits | No `emit_particle()`, no trails, no SDF collision (B1, B14) |

---

## 3. Four costs in our engine that 2010 consoles did not have 🔍

### 3.1 The shadowed sun draws everything twice
Read from the 4.7.2 GLES3 source (B4): an object's colour pass loops once per shadowed directional light and once
per omni or spot light that reaches it, adding each with additive blending. So while the sun casts shadows, every
lit opaque object (terrain chunks, merged cells, the hero, the rover, the backdrop) runs its whole fragment shader
twice, on top of the shadow-map draws. The docs say the same in one line: "Lights with shadows use a multi-pass
approach" (B1). Ways out, from the source:
- `unshaded` materials skip the extra pass (`uses_additive_lighting && !shader->unshaded`).
- A lightmapped mesh under a sun baked Static skips it (`continue`).
- A light cull mask does **not** skip it: the pass is still drawn, only its lighting code is switched off.
- Every lamp in reach is one more full pass of that object.
This is the Call of Duty 4 rule ("one active primary light on a surface", A7) with a price tag: in our renderer
each extra light is a whole redraw.

### 3.2 The web build forgets every shader
`_load_from_cache` and `_save_to_cache` in `shader_gles3.cpp` both stop at `#ifdef WEB_ENABLED` (B3). Each visit
compiles every material variant again, the first time it is drawn. Our house style makes one shader per role
variant (`#define` lines), and the GLES3 renderer adds compile-time variants for shadow splits, PCF level,
additive omni or spot, and lightmaps (B4). Changing the quality preset mid-game changes splits and filter, so it
compiles new variants too. The fix is the oldest one: "displaying them for at least one frame in the view frustum
when the level is loading" (B2).

### 3.3 The trail map copies 4 MB at a time
`world/terrain.gd` keeps footprints in a 2048 x 2048 one-byte image (4 MiB). Every frame a print lands,
`trail_tex.update(trail)` re-sends the whole image: Godot has no partial upload (B5). Every 16 m the camera walks,
`_move_trail()` allocates a new 4 MiB image and copies the old one into it. Each print is also drawn pixel by pixel
in GDScript (a boot is about 23 x 23 pixels, a wheel more), and the rover prints every frame it moves. On a
single-threaded web build all of this sits on the same thread as physics and rendering.

### 3.4 A phone renders at its full pixel density
`display/window/dpi/allow_hidpi` is on by default "on [...] Web" (B12). A phone at devicePixelRatio 3 gives the
canvas about 3 million pixels; our `low` preset's `scale: 0.75` still leaves about 1.7 million. Modern Warfare 2's
consoles shaded 0.61 million (A3).

---

## 4. The prioritised list 📋

Ranked by "removes hitches" first, then by frames gained per hour of work. Gains are expected, not measured;
re-rank with the profile. Folders: `world/`, `player/`, `addons/forge` (house style, generic, so a factory change
synced with `new-project.mjs --sync`), `models/`, `data/`, `sandbox/`.

| # | What | Why (source) | Expected gain | Cost | Folder |
|---|---|---|---|---|---|
| 1 | **Warm every shader at load.** Behind the loading screen, put one of each material variant in front of the camera for two frames: every role variant, the hero's FADE copy, glass, the terrain, every dust emitter (restarted once), a lamp-lit object, all under the active preset's shadow settings. Again after a preset or sky change, behind a fade | B2, B3, B4 (section 3.2) | Removes first-use compile hitches on every visit to the web build | 2 h | `addons/forge` (`HouseStyle.warm()`), `sandbox/` |
| 2 | **Trail map without copies.** Toroidal (wrap-around) addressing so the square never shifts: clear only the strip that wraps in. Stamp prints from a few pre-rotated brush images with `Image.blend_rect()` (engine code, not a GDScript loop). Rover prints by distance travelled, not per frame. Upload once per frame at most (already) | A15 (toroidal access), B5, section 3.3 | Removes the 16 m hitch; cuts per-frame CPU and upload while driving | 2-3 h | `world/terrain.gd` |
| 3 | **Physics cannot snowball.** `max_physics_steps_per_frame` from 8 to 3, so one slow frame cannot queue up eight physics steps for the next | B12 | Removes the slow-frame spiral on phones | 15 min + a feel check | `project.godot` |
| 4 | **A pixel budget, not a ratio.** Each preset names a 3D pixel count; `set_quality()` sets `scaling_3d_scale = min(1, sqrt(budget / window pixels))` | A3 (1024x600), A17, B12, section 3.4 | Likely the largest GPU win on phones: fragments scale with pixels | 30 min | `addons/forge` (`pixels` key), `DESIGN.md` quality |
| 5 | **Anisotropic level per preset** (`Viewport.anisotropic_filtering_level`). The terrain alone has 9 anisotropic samplers | B12 | Less texture bandwidth on Intel UHD and phones | 15 min | `addons/forge` |
| 6 | **Only shadows that read cast them.** Buildings, lander, rover, hero, big rocks cast; pebbles, small rocks, lettuce, telltales, beacons do not; terrain chunks cast on `high` only | A3 (low-res, few shadows), B4 | Fewer shadow-map draws per split | 30 min | `data/world.json` tag, `world/` |
| 7 | **Terrain shader diet.** Bake the seven value-noise calls (zones, drift, gravel, ripples) into one world-space RGBA mask texture; pass each photo's average colour as a uniform instead of three `textureLod` per pixel; move the slow terms (`dist`, `near`, `zones`) to `vertex()`; a `low` variant with one photo scale and no roughness or ripple maps | A5 ("heavily pixel shader bound"), A17 (vertex shader), B10 | The terrain fills most of the screen and runs twice with shadows: medium to large on fill-bound GPUs | 2-3 h | `world/terrain.gdshader`, `world/terrain.gd` |
| 8 | **`low` drops the live sun shadow, the 2007 way.** Shadows 0 on `low`: no shadow map, no second pass. Ground shadows of the still buildings are baked once per sky into the contact map (each footprint swept along the sun direction), darkening albedo by the share of light the sun gives; the hero and rover keep their contact discs (`movers`) | A6, A7, B4, B7 ("blob shadows instead") | Roughly halves colour-pass work on `low` (one pass instead of two for every lit object), plus the shadow passes | 3-4 h | `world/terrain.gd`, `world/terrain.gdshader`, `addons/forge` |
| 9 | **Far and fuzzy things are unshaded and light themselves.** The MOLA backdrop and the dust particles: `render_mode unshaded`, with a sun term from the rig's uniforms in the shader. Unshaded skips the extra pass | B4 (`!shader->unshaded`), A8 (vertex-lit, baked far lighting) | Backdrop and particles drawn once instead of twice | 2 h | `world/`, `addons/forge` |
| 10 | **Visibility ranges on scatter.** End pebble MultiMeshes, small rocks, props and the dust devil and streak emitters where they are a few pixels or under fog; margins set so they don't flicker | B9 | Fewer draws and triangles in long views | 1 h | `world/rocks.gd`, `data/world.json` |
| 11 | **Particles stay small and few.** Grit opaque or alpha-scissor, haze proximity fade on `high` only, tight `visibility_aabb`, `amount_ratio` per preset | A3 (low-res alpha), B10, skills/ground-contact-fx | Less blended overdraw near the camera | 1 h | `world/dust.gd` |
| 12 | **Lamps don't relight the terrain.** Each lamp is one more full pass of every chunk in reach; keep lamps off the ground and paint their pools into the terrain shader like `movers` (a uniform array). Check in the profile that a light's cull mask stops the pairing (section 3.1 says it does not stop the sun's pass) | B4, B6, A8 (two lights, the rest folded in) | Night sky only: one terrain pass per lamp saved | 2 h | `world/`, `addons/forge` (LampPool) |
| 13 | **Fewer samplers and draws per model.** Pack roughness into the albedo's alpha (normal maps cannot carry it: normal-map compression keeps only RG); count the hero's surfaces; keep the 150-draw budget | A14, A17, workspace budget | Fewer texture fetches per pixel and draws per frame | 1-2 h | `models/`, `addons/forge` |
| 14 | **Reflection probe stays still.** `UPDATE_ONCE`, never a property change per frame (each change redraws six faces), atlas 128 on `low` | B11, B12 | Prevents a hidden per-frame cost; small memory win | 15 min | `world/world.gd`, `project.godot` |
| 15 | **Dynamic resolution, id Tech 5 style.** Between the preset's floor and its pixel budget, step the scale down 10% after a second over budget and up after several seconds under | A12 | Holds 60 in heavy scenes (storm front, rover dust) | 1 h | `addons/forge` |
| 16 | **Not now: LightmapGI.** Baking needs a Forward+ editor, four skies need four bakes, the terrain is 400 m wide. Revisit for a habitat interior | B1, B7 | Large, but only for still scenes with one light set | 1 day | none |

---

## 5. Quality presets, as knobs 🎚️

Today's presets (`DESIGN.md` `quality`) set msaa, scale, shadows, shadowMap, shadowRange, shadowFilter, normalBias,
glow and detail. The rows marked "new" need items above. Values in brackets are our choice and wait on the
profile.

| Knob | low (phones, Intel UHD) | medium | high |
|---|---|---|---|
| 3D pixels (new, #4) | 0.6 Mpx, Modern Warfare 2's 1024x600 (A3) | [1.0 Mpx] | native, capped at [2.1 Mpx] |
| MSAA | 0 (2 on phones if the profile shows it cheap: tile GPUs resolve in tile memory, unverified) | 2 (A3) | 4 |
| Sun shadows | 0, baked mask (#8); until #8 lands: 1 split, 1024, 25 m | 2 splits, 2048, 60 m | 2 splits, 4096, 60 m (4 splits draw casters twice as often) |
| Shadow filter | PCF 5 (`shadowFilter: 2`) | PCF 5 | PCF 13 (`shadowFilter: 4`) |
| Shadow casters (new, #6) | buildings, rover, hero | plus big rocks | plus terrain chunks |
| Anisotropic (new, #5) | level 1 (2x) | level 2 (4x, engine default) | level 3 (8x) |
| Terrain shader (new, #7) | one photo scale, no roughness or ripple maps, detail fades by [40 m] | full, fades by 60 m | full |
| Role detail | off | code | texture |
| Glow | 0 | 0.4 | 0.5 |
| SSAO | off | off | [on, if the profile allows] (B13) |
| Lamps lit | 1 | 2 | 4 |
| Dust `amount_ratio` (new, #11) | [0.5], no haze fade | [0.75] | 1, haze proximity fade |
| Scatter visibility end (new, #10) | [40 m] | [80 m] | [150 m] |
| Trail map | [1024 px over 32 m] (same 3 cm print detail) | 2048 over 64 m | 2048 over 64 m |
| Reflection atlas | 128 | 256 | 256 |
| Physics | 60 Hz, at most 3 steps per frame | same | same |

A 30 Hz physics tick with `physics_interpolation` on would halve physics cost on `low`, but the docs warn that
"below 30, physics behavior can break down" and the controller was tuned at 60 (B12). Try it only if the profile
shows physics over its share.

---

## 6. What the profile should answer 📏

- The frame split on each device: script, physics, render submit, GPU. The window-size test from the Godot docs
  tells fill-bound from the rest: if the frame rate jumps in a small window, pixels are the cost (B10).
- Every frame over budget on a scripted route (walk, drive, sky switch, storm), tagged with what happened on it:
  first sight of a material, a trail shift, a print upload, a physics catch-up, a probe redraw.
- Draw calls and triangles per view, with and without sun shadows, to size item 8.
- Whether the warm-up (#1) leaves zero compile spikes on a cold browser visit.

The generic version of this method is `tooling/skills/frame-budget/SKILL.md`.

---

## Open questions ❓
- The real cost of a compile spike on our phones and the UHD laptop (unmeasured).
- Whether MSAA 2x at 0.6 Mpx beats 0 MSAA at a higher pixel count on a phone, as it did on the Xbox 360 (A3).
- Whether a light cull mask keeps a lamp from pairing with the terrain at all (item 12).
- Whether Godot's web build uses `KHR_parallel_shader_compile` (A17); not found in what was read.
