# Look study: Journey, flat shading, sky and fog in Godot 4.7 Compatibility

Written 12 Nov 2026 for the three style variants (`design/BRIEF.md` §2, §6). Sources are saved in `pages/` (list at the end). Status: ✅ seen in the source or measured, ⚠️ reported or partial, ❌ not found or false. "Phone cost" is reasoning from how the engine draws it unless it says measured: nothing here was timed on a phone.

The fixed limits (no volumetric fog, SSR, SDFGI, decals; MSAA only; 8-bit; one or two shadowed lights) are in `research/godot-build/engine-limits.md` and not repeated.

## 1. How *Journey* gets its look

The talk itself (John Edwards, thatgamecompany, GDC 2013, "Sand Rendering in Journey") is a video; the GDC Vault page confirms speaker, title and that it covers "all the technical details of the final sand implementation" ✅. The technique list below comes from Alan Zucconi's six-part reconstruction, which says it is "heavily inspired by" the talk and is built "mostly using visual references" ⚠️. The non-sand parts come from a 2012 CGW article.

| technique | Compatibility? | how / cost | source | status |
|---|---|---|---|---|
| "Diffuse contrast": Lambert multiplied by 4, normal's Y scaled by 0.3, so shade turns hard and shadows read more vertical | yes | custom `light()` in a spatial shader (runs "for every light in every pixel"), or `render_mode diffuse_toon` for a hard split. A few ALU ops per pixel: cheap | zucconi-2, spatial_shader | ⚠️ (constants named in the text, the formula is an image) |
| Sand normal: random per-grain normals from a noise texture | yes | one extra texture read per pixel. Faceting already breaks up our surfaces, so skip | zucconi-1, zucconi-3 | ⚠️ |
| Rim lighting (Fresnel) so one-hue dunes separate | yes | built-in `RIM` output, or a Fresnel term in `surface.gdshader`. Cheap | zucconi-1, zucconi-4, spatial_shader | ⚠️ |
| "Ocean specular" (Blinn-Phong) so sand reads like a liquid | yes | default GGX specular with low roughness on the sand role, or `light()`. Cheap | zucconi-4 | ⚠️ |
| Glitter: random sparkles that change with the view, also in shade | yes, poorly on phones | noise compared with the view vector, written as emission above the glow threshold. Sparkles a pixel wide alias and crawl; MSAA does not fix shader aliasing. High preset only, or skip | zucconi-5 | ⚠️ |
| Ripples: four normal maps blended by slope and wind direction | yes | four texture reads per pixel on every ground pixel: the costliest item here on a phone. Skip | zucconi-1, zucconi-6 | ⚠️ |
| Colours "beyond 100 percent brightness", "physically based light bloom" | partly | Compatibility glow is a simpler dual-filter blur (Bjørge, SIGGRAPH 2015). With glow on and a 10-bit buffer the engine keeps values up to 4.0 ("fake a little HDR to do glow"); otherwise the buffer is 8-bit | glow.glsl, rasterizer_scene.cpp, renderers | ✅ source; whether WebGL gets the 10-bit buffer is not measured |
| "Filmic tone mapping" | yes | Filmic, ACES and AgX all exist in Compatibility (see §3) | CGW, tonemap_inc.glsl | ✅ |
| Fog as atmosphere ("visuals, perceived light, fog, and wind") | yes | depth and height fog, sun scatter (§3). No technical detail on how *Journey* did it | CGW | ⚠️ (no detail) |
| Palette that "shifts and varies ... based on a curve established by the artists" | yes | tokens per sol or per event, applied with `apply_lighting()` again; or Environment adjustments (brightness, contrast, saturation), which add a post pass | CGW, renderers | ✅ |
| No real-time shadows: shadows faked with "special UV sets" | n/a | a choice, not a feature. Our low preset already drops the shadow; a blob shadow under the hero keeps it grounded | CGW | ✅ (WebFetch excerpt) |
| Motion blur | no | not built in, and a full-screen pass a phone cannot spare | renderers (absent) | ❌ |

**Kid version:** *Journey* is mostly clever light on smooth sand plus haze. We keep the haze, the hard light-dark split and the rim, and skip the expensive sand tricks.

## 2. Flat shading in Compatibility

| technique | Compatibility? | how / cost | source | status |
|---|---|---|---|---|
| Split vertex normals (each face owns its 3 vertices) | yes | baked in Blender: `forge/lib.py` `smooth()` leaves the mesh flat when `shading: flat`, and the GLB exports split normals. Zero shader cost; up to about 3 times the vertices of a smooth mesh, triangles unchanged. Kit models keep whatever normals they shipped with | lib.py | ✅ |
| Normal from screen derivatives, `normalize(cross(dFdy(VERTEX), dFdx(VERTEX)))` | yes | two derivatives and a cross per pixel: cheap. Works on any mesh without re-import. `VERTEX` is linear across one triangle, so the result is that triangle's plane | surface.gdshader, shader_functions | ✅ code; plane claim is reasoning |
| Precision | ok | Godot's GLES3 shaders default to `precision highp float`, so view-space positions keep full float precision; the docs warn derivatives are undefined in non-uniform control flow (keep the line at the top of `fragment()`, as now) | shader_gles3.cpp, shader_functions | ✅ |
| Order of cross | matters | `cross(dFdy, dFdx)` in that order gives an outward normal in Godot's view space; the other order flips every face dark | surface.gdshader | ✅ (in use) |

**What `shading: flat` does now:** `house_style.gd` `role()` builds every role as a `ShaderMaterial` from `surface.gdshader` with `#define FLAT` when `geometry.shading` is `flat` (`_flat()`, `_dress()`). The shader replaces `NORMAL` with the derivative normal, so Kenney models and engine primitives facet too, with no re-import. Forge models are faceted twice (baked and shader), which costs nothing visible. One catch: in flat mode skinned meshes also get the shader, so the astronaut facets. Check that this reads well in variant A before keeping it.

## 3. Sky, fog, glow and tone mapping in Compatibility (4.7)

| technique | Compatibility? | how / cost | source | status |
|---|---|---|---|---|
| `ProceduralSkyMaterial` | yes | gradient plus up to 4 sun discs. The rig's own note: its disc is drawn at the light's energy and comes out darker than a bleached horizon | env_post, house_style.gd | ✅ |
| `PhysicalSkyMaterial` | yes | "slightly more expensive", one sun, Earth-like scattering; Mars colours would mean tuning Mie and Rayleigh by eye. Not worth it | env_post | ✅ |
| Sky shader (`shader_type sky`) | yes | full control (gradient, halo round the sun, a disc brighter than the sky). Cost per visible sky pixel each frame, plus the radiance cubemap when the sky changes; heavy work belongs behind `AT_CUBEMAP_PASS` | sky_shader, class_sky | ✅ |
| Depth fog (`FOG_MODE_DEPTH`) | yes | `smoothstep(begin, end, distance)^curve * fog_density`. **`fog_density` is the maximum.** Its default is 0.01, so a rig that leaves it alone gets 1% fog. Measured on 4.7.2 Compatibility: white fog over black at full depth gave 0.098 sRGB at density 0.01 and 1.0 at density 1.0 | scene.glsl, class_environment, measured | ✅ |
| Exponential fog | yes | `1 - exp(-distance * density)`. Harder to place the far rim at an exact share | scene.glsl | ✅ |
| Height fog (`fog_height`, `fog_height_density`) | yes | per pixel, combined with depth fog by `max()`. Everything below `fog_height` fogs at any distance, the player's feet included | scene.glsl, renderers | ✅ |
| Sun scatter (`fog_sun_scatter`) | yes | adds the sun's colour to the fog when looking at the sun (`pow(dot, 8)`): the *Journey* bleach near the sun. One loop per light per pixel: cheap | scene.glsl, env_post | ✅ |
| Aerial perspective (`fog_aerial_perspective`) | **no on objects** | the code for scene objects is commented out in 4.7.2 GLES3; it only tints the sky. Set the fog colour to the horizon colour by hand | scene.glsl, sky.glsl | ✅ |
| `fog_sky_affect` | yes | how much fog covers the sky. Low keeps the sky gradient | class_environment | ✅ |
| Glow | yes, simplified | only `glow_intensity`, `glow_bloom`, `glow_hdr_threshold`, `glow_hdr_scale`, `glow_hdr_luminance_cap` act; levels, strength, normalized, mix, map are ignored and blend is always Screen. Turning glow (or SSAO, or adjustments) on moves tone mapping into a post pass: one more full-screen pass on a phone | class_environment, rasterizer_scene.cpp | ✅ |
| Tone mappers | all five | Linear, Reinhard, Filmic, ACES, AgX all in the GLES3 tone map code. AgX is "the slowest". The rig's `_on_screen()` treats AgX as linear, so its shadowed-sun correction is wrong under AgX | tonemap_inc.glsl, env_post, house_style.gd | ✅ |
| Banding | a risk | Compatibility is RGBA8 with no debanding; the docs warn fog causes banding at high density. A smooth sky gradient plus haze is the worst case: add 1/255 of noise in the sky shader | renderers, env_post | ✅ |
| Depth of field (ref 9's tilt-shift) | no | | renderers | ✅ |
| SSAO (contact darkening) | yes, simplified | since 4.6; only radius and intensity. A full-screen pass: high preset only | env_post | ✅ |

## 4. Ref 4: Abandoned Spaceship demo (perfoon, commit 5ddf086, 15 Mar 2023)

Licence: **CC BY-NC 4.0** ("All assets Copyright (c) 2023 Jaanus Jaggo"). Non-commercial and attribution: nothing from it goes into our repo, only the ideas below. Renderer: `config/features` names **Forward Plus**, with TAA on. Built for Godot 4.0.

| setting | Compatibility? | how / cost | source | status |
|---|---|---|---|---|
| ProceduralSky, grey top (0.50, 0.51, 0.55), Reinhard tone mapping | yes | the cool grey sky against warm sun is the mood we take | environment.tres, Sky.tres | ✅ |
| Volumetric fog (density 0.06, hangar sun `light_volumetric_fog_energy` 20): the light shafts | no | Forward+ only. Fake with sun scatter and flat transparent quads | environment.tres, Hangar.tscn | ✅ |
| SSIL, SDFGI energy, TAA | no | Forward+ only | environment.tres, project.godot | ✅ |
| SSAO (radius 2, intensity 7.48, power, detail) | partly | Compatibility keeps radius and intensity only | environment.tres | ✅ |
| Glow (levels 2 and 4, strength 0.37, intensity 3.62, bloom 0.02, blend additive) | partly | intensity and bloom work; levels, strength and blend are ignored | environment.tres | ✅ |
| Baked lightmaps (`LightmapGI`, outside and hangar) | render yes, bake on a desktop GPU | most of its warm bounce light is baked; light cost at runtime is near zero | Outside.tscn, renderers | ✅ |
| Sun: outside 61.7° high, colour (1, 0.92, 0.81), energy 6, baked; hangar 37.3°, (1, 0.87, 0.62), energy 0.7 | yes | elevations computed from the scene transforms with Godot's own parser | Outside.tscn, Hangar.tscn | ✅ |
| 14 shadowed orange (1, 0.59, 0.11) omni lamps | no on phones | Compatibility draws each shadowed light in its own pass; one or two is the budget | lights.tscn, engine-limits | ✅ |
| Box-projected reflection probes (4+) | yes, 2 per mesh | | world_environment.tscn | ✅ |
| Trim-sheet `ShaderMaterial` (albedo, ORM, normal map, parallax offset, grunge, `paint_color` recolour) | yes | 5 texture reads per pixel: the opposite of our flat-colour plan | utrim_spaceship_recolored.tres | ✅ |
| Emissive floor lamp (energy 1.96) as the glow source | yes | the pattern we want for cyan "on" lights | floorLamp.tres | ✅ |

**What to take:** warm key light against a cool grey sky, warm practical lights, and one saturated colour for what you can use. Its depth comes from baking and Forward+ effects we do not have, so our depth has to come from fog.

## Recommendations for the three variants

1. **Fog density is a token.** Add `lighting.fog.density` (the maximum share) and pass it to `env.fog_density`; today the rig leaves it at 0.01, so depth fog is barely visible. Place the far rim and Mount Sharp past `far` so they sit at exactly `density`: A 0.70, B 0.40, C 0.55 (brief §3 asks 40 to 70%).
2. **Fog colour = the sky's horizon colour**, set by hand (aerial perspective does nothing on objects in Compatibility). `fog.sky` (fog_sky_affect) 0.1 to 0.3 so the gradient survives; `fog.curve` 1.5 to 2 for A to keep the base clear and swallow the distance.
3. **Sun scatter:** A 0.4, C 0.2, B 0. It is the *Journey* bleach round the sun, almost free.
4. **Height fog:** off by default. Only for A, and only with `fog_height` below the playable floor (crater dips), since it fogs everything under that height.
5. **Sun elevation:** A 12 to 15° (shadows about 4 times object height), C 25°, B 40° (the clean "toy" light). Check shadow acne at the low angle; normal bias is already 4.
6. **Sky:** the rig's sky shader (gradient, halo, disc brighter than the sky), with a 1/255 dither against banding. Not PhysicalSky. Move the sun in steps, not every frame, so the radiance map is not rebuilt each frame.
7. **Tone mapper:** ACES for A and C (it desaturates highlights, so the sun area bleaches warm), Filmic for B (keeps toy colours bright). Exposure 1.0 to 1.1, white 6 as the rig sets. AgX only after `_on_screen()` gets its curve.
8. **Glow:** low preset 0. Medium and high: intensity 0.5 to 0.8, bloom 0, threshold a little above the brightest sunlit role (measure a sunlit sand pixel in capture-view first, or the whole ground glows), and cyan emissive at 2 to 3 so only accents bloom.
9. **Flat shading:** `shading: flat` for A and B (the existing derivative shader, no re-import, no extra vertices); C smooth. Check the faceted astronaut in A.
10. **From *Journey*, add only cheap terms:** a rim (Fresnel) term on sand and rock for A so one-hue landforms separate, and a hard diffuse split (`diffuse_toon` or the 4x Lambert) to try in A. Skip glitter, ripples and grain normals; SSAO on the high preset only.

## Sources (all in `pages/`, fetched 12 Nov 2026)
- `gdcvault-sand-rendering-journey.html`: https://www.gdcvault.com/play/1017742/Sand-Rendering-in
- `zucconi-journey-sand-{1..6}.html`: https://www.alanzucconi.com/2019/10/08/journey-sand-shader-1/ (parts 1 to 6)
- `cgw-mysterious-journey-2012.md`: WebFetch excerpt of https://www.cgw.com/Publications/CGW/2012/Volume-35-Issue-4-June-July-2012/Mysterious-Journey.aspx (curl 403)
- `godot47-*.rst`: godot-docs branch 4.7: class_environment, class_sky, class_proceduralskymaterial, class_physicalskymaterial, renderers, environment_and_post_processing, spatial_shader, sky_shader, shading_language, shader_functions, standard_material_3d
- `godot472-gles3-*`: engine source at tag 4.7.2-stable: drivers/gles3/shaders/{scene,sky,tonemap_inc}.glsl, effects/glow.glsl, rasterizer_scene_gles3.cpp, shader_gles3.cpp
- Abandoned Spaceship demo: https://github.com/perfoon/Abandoned-Spaceship-Godot-Demo at 5ddf086, read from a scratch clone, not saved here (CC BY-NC)
- Measured: a headless-display test on Godot 4.7.2 Compatibility (depth fog 0 to 10 m, white fog over black, centre pixel at 50 m)
- In repo: `tooling/godot/addons/forge/house_style.gd`, `surface.gdshader`, `sky.gdshader`, `tooling/forge/lib.py`
