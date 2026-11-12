# Performance sources: key excerpts

Collected 12 Nov 2026 for `design/research/performance.md`. Every quote below is copied from the saved text in
`raw/` (era talks and articles, as `.txt`) or `godot/` (Godot 4.7 docs as raw `.rst`), or `godot-src/` (engine
source at tag `4.7.2-stable`). Checked with grep on the saved copy. Accessed date for all: 2026-11-12.

## A. The 2007-2011 games

### A1. GameSpot, "Call of Duty 4: Modern Warfare Exclusive Single-Player Hands-On" (17 Aug 2007)
URL: https://www.gamespot.com/articles/call-of-duty-4-modern-warfare-exclusive-single-player-hands-on/1100-6176892/
(read through web.archive.org, snapshot 2025-08-19; local `raw/gamespot-cod4-60fps.txt`)
> "the game's performance level, which Infinity Ward has committed to keeping at 60 frames per second throughout
> both single- and multiplayer modes. So few developers have prioritized a high frame rate this generation that
> we'd almost forgotten how much it can impact gameplay."

### A2. Digital Foundry (Richard Leadbetter), "Face-Off: Modern Warfare 2", Eurogamer (12 Nov 2009)
URL: https://www.eurogamer.net/digitalfoundry-modern-warfare-2-face-off (web.archive.org snapshot 2025-01-20;
local `raw/df-mw2-faceoff.txt`)
> "Infinity Ward has jettisoned the notion of storing all textures in RAM and instead streams them in as and when
> they are needed. [...] in fast-moving scenes, lower-resolution textures are left on-screen for longer than you
> might like."
> "the lighting - one of the really impressive things in this game"

### A3. Digital Foundry, "Face-Off: Modern Warfare 3", Eurogamer (10 Nov 2011)
URL: https://www.eurogamer.net/digitalfoundry-face-off-modern-warfare-3 (web.archive.org snapshot 2025-01-30;
local `raw/df-mw3-faceoff.txt`)
> "Both versions run at the standard COD resolution of 1024x600 with 2x multi-sample anti-aliasing (MSAA) applied."
> "The sub-HD nature of the console games is mitigated somewhat by the high frame-rate"
> "In Call of Duty: World at War, the developers experimented with lower resolution alpha buffers (used for
> particle and transparency work) on PlayStation 3 in order to increase performance."
> "Owing to the 60FPS nature of the game, there's not much processing time available for computationally
> expensive shadow rendering, so they're very low res"
> "the 60 frames per second target frame-rate is the key to the ultra-responsive controls and the great "feel" of
> the game."
> "Call of Duty on console very rarely actually runs at the "rock solid 60FPS" that it is often lauded for.
> Performance drops are to be expected bearing in mind the mere 16.66ms of rendering time available per frame
> [...] The trick is to ensure that frame-rate remains high enough to pass as the highest possible frame-rate -
> something that we like to call the "perceptual 60FPS"."
> (PC version) "the inclusion of screen-space ambient occlusion (SSAO) does help a little" (consoles had none)

### A4. GamesBeat (Dean Takahashi), "It's not the same old 3D graphics in Call of Duty: Black Ops II" (2012)
URL: https://gamesbeat.com/call-of-duty-black-ops-ii-graphics/ (local `raw/gamesbeat-bo2.txt`)
> "The one requirement for a Call of Duty game is that it has to run at 60 frames per second on a console. The
> graphics of the game have to look good, but they can't slow the game down."
> Treyarch's "Beautiful Corner team [...] a vertical slice program that defines a flow of a map, starting with one
> corner of the map."
> "The tricky part is the 60 frames per second." (Bunting, Treyarch)

### A5. Dimitar Lazarov (Treyarch), "Getting More Physical in Call of Duty: Black Ops II", SIGGRAPH 2013 course notes
URL: https://blog.selfshadow.com/publications/s2013-shading-course/lazarov/s2013_pbs_black_ops_2_notes.pdf
(local `raw/lazarov-bo2-2013.txt`)
> "The new method added about 8 instructions to the vertex shader, 1 interpolator and 1 instruction to the pixel
> shader. However, we didn't see a measurable drop in frame rate [...] Our game is heavily pixel shader bound"
> "the tinted scalar SH we had to use for performance reasons"
> "three different light baking methods - lightmap (left), vertex bake (middle), light probe (right)"
> "The dielectric special case was only 5 pixel shader instructions, while the full approximation was 7"

### A6. Angelo Pesce, "Activision @ Siggraph 2016" (blog, Aug 2016)
URL: https://c0de517e.blogspot.com/2016/08/activision-siggraph-2016.html (local `raw/c0de517e-2016.txt`)
> "Call of Duty has always been a lightmapped title, but lightmaps come with a quite large set of issues: large
> baking times, complexity in representing runtime materials and effects, lighting discontinuities with dynamic
> objects"
> (Treyarch) "fully pre-bake a shadowmaps for entire levels [...] we can use the SST to quickly shadow far objects"

### A7. Call of Duty 4 mod tools wiki, "Call of Duty 4: Advanced Lighting" (community copy of the IW docs)
URL: https://wiki.zeroy.com/index.php/Call_of_Duty_4:_Advanced_Lighting (local `raw/zeroy-cod4-lighting.txt`)
> "Sunlight is considered a "Direct" light. [...] this is a real time dynamic light that casts shadows"
> "You may only have one active primary light on a surface"
> "A Primary light is a dynamic light, it will cast shadow of all objects and reflect off surfaces in relation to
> the player. It is also a higher quality light than a non-primary."
Status: community wiki, ⚠️ (reported, not the studio's own page).

### A8. Mitchell, McTaggart, Green (Valve), "Shading in Valve's Source Engine", SIGGRAPH 2006 course
URL: https://advances.realtimerendering.com/s2006/Chapter7-Shading_in_Valve's_Source_Engine.pdf
(local `raw/valve-source-2006.txt`)
> "at the cost of tripling the memory footprint of our light maps, we have been able to encode directionality"
> "our level designers manually place point entities in their maps which are used as sample points for specular
> lighting. High dynamic range cube maps are pre-rendered from these positions [...] stored as part of the static
> level data."
> "The samples are stored non-hierarchically at a fairly coarse (4' x 4' x 8') granularity since indirect
> illumination varies slowly through space and we only need a fast lookup, not extreme accuracy. When drawing any
> model that moves [...] the nearest sample point to the model's centroid is selected"
> "we choose to time-average the ambient and local lighting information to limit the effect of lighting
> discontinuities"
> "On ps_2_0 video cards (20% of our users) we compute diffuse illumination for up to two local lights. Any nearby
> local lights beyond the two most significant lights are added into the ambient cube on the fly."

### A9. Chris Green (Valve), "Efficient Self-Shadowed Radiosity Normal Mapping", SIGGRAPH 2007
URL: https://cdn.cloudflare.steamstatic.com/apps/valve/2007/SIGGRAPH2007_EfficientSelfShadowedRadiosityNormalMapping.pdf
(local `raw/valve-green-ssbump-2007.txt`)
> "While it is common to use an additional texture channel to hold an "ambient occlusion" field, this only provides
> a darkening effect which is independent of the direction from which the surface is being lit."
> "This modification provides a directional occlusion function to the bump maps, which requires no additional
> texture memory and is actually faster than our previous non-shadowing solution."

### A10. Alex Vlachos (Valve), "Post Processing in The Orange Box", GDC 2008
URL: https://cdn.steamstatic.com/apps/valve/2008/GDC2008_PostProcessingInTheOrangeBox.pdf
(local `raw/valve-postproc-2008.txt`)
> "Amortize the cost of building the histogram over 16 frames / Update one bucket per frame"
> "System hitches can cause one very blurry frame / Time lapse between frames greater than 0.1 seconds, we disable
> motion blur for that frame"
> "Use minimal motion blur to achieve the effect. We only use 15% of full-frame shutter!"

### A11. Daniel Wright (Epic), "Precomputed Visibility", Unreal Engine 3 documentation (UDN)
URL: https://docs.unrealengine.com/udk/Three/PrecomputedVisibility.html (web.archive.org snapshot 2025-04-29;
local `raw/ue3-precomputed-visibility.txt`)
> "The primary benefits of precomputed visibility are for mobile platforms which don't support hardware occlusion
> queries, and to save rendering thread time [...] at the cost of increasing runtime memory and lighting build
> time somewhat."
> "Savings of 2.7ms of rendering thread time on Xbox 360 compared to without precomputed occlusion (35.4ms ->32.7ms)."
> "Tiny 1ms hitch on the rendering thread when moving to a new area and occlusion gets decompressed"

### A12. Tom's Hardware, "Rage: Performance Analysis On The PC" (Oct 2011)
URL: https://www.tomshardware.com/reviews/rage-pc-performance,3057-2.html (local `raw/toms-rage.txt`)
> "The Tech 5 engine's goal is to generate a 60 frame-per-second (FPS) output, regardless of whether it's running
> on PC, Xbox 360, PS3, or Mac. The software does whatever it has to in order to achieve a steady 60 FPS, going so
> far as to alter a number of variables on the fly, including model complexity and texture resolution."
> "various texture popping issues"

### A13. Matthias Wloka (NVIDIA), "Batch, Batch, Batch: What Does It Really Mean?", GDC 2003
URL: https://www.nvidia.com/docs/IO/8228/BatchBatchBatch.pdf (local `raw/wloka-batch-2003.txt`)
> "<130 tris/batch: App is GPU-independent, Completely CPU-limited"
> "25k batches/s @ 100% 1 GHz CPU. Target: 30fps; 2GHz CPU; 20% (0.2) Draw/SetState: X = 333 batches/frame"
> "Formula: 25k * GHz * Percentage/Framerate"

### A14. NVIDIA, "Improve Batching Using Texture Atlases" (whitepaper, 2004)
URL: https://download.nvidia.com/developer/NVTextureSuite/Atlas_Tools/Texture_Atlas_Whitepaper.pdf
(local `raw/nvidia-atlas-2004.txt`)
> "Submitting hundreds or worse, thousands of batches per frame inevitably makes an application CPU-limited due to
> inherent driver overhead."

### A15. Asirvatham and Hoppe, "Terrain Rendering Using GPU-Based Geometry Clipmaps", GPU Gems 2 ch. 2 (2005)
URL: https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-2-terrain-rendering-using-gpu-based-geometry
(local `raw/gpugems2-ch2-clipmaps.txt`)
> "we perform all accesses toroidally [...] That is, we use wraparound addressing to position the clipmap window
> within the texture image. Under this toroidal access, the L-shaped update region usually becomes a + shape"

### A16. NVIDIA, "Soft Particles" (Tristan Lorach, DirectX 10 SDK whitepaper, 2007)
URL: https://developer.download.nvidia.com/whitepapers/2007/SDK10/SoftParticles_hi.pdf (local `raw/nvidia-soft-particles-2007.txt`)
> (two methods) one can "read the depth buffer as a texture; the other uses a more conventional second render
> target to store depth values."

### A17. MDN, "WebGL best practices" (living page)
URL: https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices (local `raw/mdn-webgl-best-practices.txt`)
> "A common (and easy) way to trade off quality for speed is rendering into a smaller back buffer, and upscaling
> the result."
> "Batching draw calls into fewer, larger draw calls will generally improve performance."
> "texture atlasing [...] lets you combine more draw calls into fewer, bigger batches."
> "Do as much work as you can in the vertex shader, rather than in the fragment shader."
> "GPU compressed texture formats are smaller in GPU memory, and are faster to sample from. (This reduces texture
> memory bandwidth, which is precious on mobile.)"
> "Certain WebGL entry points - including getError and getParameter - cause synchronous stalls"
> "many browsers can compile and link in parallel on background threads" / "Prefer KHR_parallel_shader_compile"

### A18. Mass Effect (BioWare, UE3, 2007) film grain toggle
PCGamesHardware.de "Mass Effect (PC): Tuning-Guide" (2008): BioWare added a switch for a grain filter "meant to
create a film feel, but personal taste decides". Read via search summary only, ⚠️ (not saved).

## B. Godot 4.7 (docs at https://raw.githubusercontent.com/godotengine/godot-docs/4.7/ , local `godot/`)

### B1. tutorials/rendering/renderers.rst (feature table)
- Lighting approach, Compatibility: "Forward single-pass. Lights with shadows use a multi-pass approach and less
  accurate blending." OmniLights and SpotLights "8 per mesh. Can be increased."
- ReflectionProbe: "Supported, 2 per mesh." LightmapGI: "Rendering of baked lightmaps is supported. Baking
  requires hardware with RenderingDevice support." VoxelGI, SDFGI, SSIL, SSR, volumetric fog: not supported.
- SSAO: supported. Glow, tonemapping, adjustments, depth and height fog: supported. Custom post-processing with a
  fullscreen quad: supported.
- MSAA 3D: supported. TAA, FSR2, FXAA, SMAA: not supported. "Color precision: RGBA8. Low dynamic range".
- Decals, particle trails, particle SDF collision, depth of field blur: not supported.

### B2. tutorials/performance/pipeline_compilations.rst
> "This page only applies to the Forward+ and Mobile renderers, not Compatibility. Ubershaders and pipeline
> precompilation rely on functionality only available in modern low-level graphics APIs [...] To avoid shader
> stutters in Compatibility, you need to use the legacy approach of preloading materials, shaders, and particles by
> displaying them for at least one frame in the view frustum when the level is loading."
> "The shader baker is only supported for the Forward+ and Mobile renderers. [...] not supported on the web platform"

### B3. Engine source `drivers/gles3/shader_gles3.cpp` (4.7.2-stable, local `godot-src/`)
`ShaderGLES3::_load_from_cache` and `_save_to_cache` both start with `#ifdef WEB_ENABLED // not supported in webgl`
and return: the web build keeps no compiled shader between sessions, so every visit compiles every variant again.

### B4. Engine source `drivers/gles3/rasterizer_scene_gles3.cpp` (4.7.2, local `../godot472-gles3-rasterizer_scene.cpp`)
- `uses_additive_lighting = (inst->light_passes.size() + p_render_data->directional_shadow_count) > 0;` and
  `uses_additive_lighting && !shader->unshaded`, then `for (pass = 0; pass < MAX(1, light_passes + directional_shadow_count); pass++)`
  with `desired_blend_mode = BLEND_MODE_ADD` for `pass > 0`: every lit opaque object is drawn once more for each
  shadowed directional light and once more for each omni or spot light that reaches it.
- `if (inst->lightmap_instance.is_valid() && ... bake_mode == RSE::LIGHT_BAKE_STATIC) { // Skip shadows for static
  lights on meshes with a lightmap. continue; }`: a lightmapped mesh under a Static-baked sun skips that pass.
- `// Disable additive lighting when masks are not overlapping.` only clears the lighting constant; the pass is not
  skipped (no `continue`), so a cull mask does not save the draw.
- Shadow modes are compile-time constants: `LIGHT_USE_PSSM2`, `LIGHT_USE_PSSM4`, `LIGHT_USE_PSSM_BLEND`,
  `SHADOW_MODE_PCF_5`, `SHADOW_MODE_PCF_13`: changing splits or filter quality makes new shader variants.

### B5. Engine source `drivers/gles3/storage/texture_storage.cpp` and `scene/resources/image_texture.cpp`
`ImageTexture::update()` calls `RS::texture_2d_update(texture, p_image)`, which calls `texture_set_data()` with the
whole image: there is no partial upload. `texture_2d_update(texture, image, layer)` takes a layer, so one layer of a
texture array can be replaced alone.

### B6. tutorials/3d/lights_and_shadows.rst
> "shadows are implemented using a multi-pass rendering approach so lights with shadows are rendered in sRGB space
> instead of linear space."
> "When using the Compatibility renderer, up to 8 OmniLights + 8 SpotLights can be rendered per mesh resource."

### B7. tutorials/3d/global_illumination/using_lightmap_gi.rst
> "On the web platform, only *rendering* lightmaps that were baked on a different platform is supported."
> (Static bake mode) "Since static surfaces can skip lighting and shadow computations entirely, this mode provides
> the best performance [...] dynamic objects will not cast real-time shadows onto baked surfaces, so you need to use
> a different approach such as blob shadows instead."
> (Dynamic + Shadowmask) "This allows shadows up close to be real-time and show dynamic objects, while allowing
> static objects in the distance to still cast shadows."
> "To display indirect lighting on dynamic objects, a 3D probe system is used"

### B8. tutorials/3d/occlusion_culling.rst and classes/class_occluderinstance3d.rst
> "occlusion culling is most effective in indoor scenes"
> "Due to memory constraints, occlusion culling is not supported by default in Web export templates. It can be
> enabled by compiling custom Web export templates with module_raycast_enabled=yes."
> (ProjectSettings) "Large open scenes with few or no objects blocking the view will generally not benefit much from
> occlusion culling. Large open scenes generally benefit more from mesh LOD and visibility ranges"

### B9. tutorials/3d/visibility_ranges.rst and class_geometryinstance3d.rst
> "A single larger mesh can replace several smaller meshes, so that the number of draw calls can be reduced at a
> distance, but culling opportunities can be preserved when up close."
> "replace it with a Sprite3D impostor in the distance"
> VISIBILITY_RANGE_FADE_SELF: "Only supported when using the Forward+ rendering method. When using the Mobile or
> Compatibility rendering method, this mode acts like VISIBILITY_RANGE_FADE_DISABLED but with hysteresis disabled."

### B10. tutorials/performance/optimizing_3d_performance.rst and gpu_optimization.rst
> "try to use as few transparent objects as possible"
> "For automatic instancing to be effective, the material must be opaque or alpha-tested [...] Alpha-blended or
> depth pre-pass materials are never instanced this way. Instead, you must use MultiMesh"
> "Consider using baked lighting, especially for mobile."
> "Turn off V-Sync [...] compare the frames per second when running with a large window, to running with a very
> small window. [...] you will find the FPS increases quite a bit using a small window, which indicates you are to
> some extent fill rate-limited."
> "When targeting mobile devices, consider using the simplest possible shaders you can reasonably afford to use."
> "don't worry about vertex count on mobile, but avoid concentration of vertices in small parts of the screen."

### B11. classes/class_reflectionprobe.rst
> UPDATE_ONCE: "The corresponding radiance map will be generated over the following six frames."
> UPDATE_ALWAYS: "it has a significant performance cost. Due to the cost, it's recommended to only use one
> ReflectionProbe with UPDATE_ALWAYS at most per scene."

### B12. classes/class_projectsettings.rst (extracts; full file not kept)
- `physics/common/physics_ticks_per_second` = 60: "CPU usage scales approximately with the physics tick rate.
  However, at very low tick rates (usually below 30), physics behavior can break down."
- `physics/common/max_physics_steps_per_frame` = 8: "the game will appear to slow down if the rendering FPS is less
  than 1 / max_physics_steps_per_frame of physics_ticks_per_second".
- `physics/common/physics_interpolation`: "the renderer will interpolate the transforms of objects [...] so that
  smooth motion is seen even when physics ticks do not coincide with rendered frames."
- `rendering/scaling_3d/mode`: "FSR is only effective when using the Forward+ rendering method [...] FSR will fall
  back to bilinear scaling."
- `rendering/shading/overrides/force_vertex_shading`: "This can increase performance a lot, but also reduces
  quality immensely."
- `rendering/lights_and_shadows/directional_shadow/16_bits` = true; `directional_shadow/size` = 4096.
- `rendering/reflections/reflection_atlas/reflection_size` = 256 (`.mobile` = 128).
- `rendering/textures/default_filters/anisotropic_filtering_level` = 2 (4x); "set Viewport.anisotropic_filtering_level"
  at runtime.
- `display/window/dpi/allow_hidpi` = true: "allows HiDPI display on Windows, macOS, Android, iOS and Web."
- `rendering/limits/opengl/max_lights_per_object` = 8, Compatibility only.

### B13. tutorials/3d/environment_and_post_processing.rst
> "Since Godot 4.6, a simplified version of SSAO is available in the Compatibility renderer. [...] should perform
> significantly better on low-end devices compared to SSAO in Forward+. When using the Compatibility renderer, only
> the Radius and Intensity parameters can be adjusted."

### B14. classes/class_gpuparticles3d.rst
> "emit_particle() is only supported on the Forward+ and Mobile rendering methods, not Compatibility."

### B15. tutorials/assets_pipeline/importing_images.rst and export/exporting_for_web.rst
> VRAM Compressed: "video memory usage is also decreased considerably (usually by a factor between 4 and 6)"
> "If you plan to use VRAM compression make sure that VRAM Texture Compression is enabled for the targeted
> platforms (enabling both For Desktop and For Mobile will result in a bigger, but more compatible export)."
> Single-threaded export: "it cannot use threads, and is not as performant as the multi-threaded export"

### B16. tutorials/3d/mesh_lod.rst
> "By default, mesh LOD generation happens automatically for imported 3D scenes (glTF, .blend, Collada, FBX)."
(Nothing in the page covers meshes built at runtime; that ours lose their LODs is inferred.)
