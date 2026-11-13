# Low sun shadows: stair-steps and spikes (research, 13 Nov 2026)

Problem: Godot 4.7 Compatibility, one DirectionalLight3D sun on a day cycle. At 5 to 25 degrees sun elevation, straight-edged shadows on flat ground show stair-steps and thin spikes from box corners. Classic perspective/projective aliasing at grazing light.

## Findings (one per line, with URL)

### Godot docs (saved: pages/shadow-low-sun/godot-lights-and-shadows.html, godot-class-*.rst)
- Godot says raise Shadow Normal Bias before Shadow Bias: normal bias causes less peter-panning but makes shadows thinner. https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot: "Any sort of bias issues can be fixed by increasing the shadow map resolution", and "Tweaking shadow mapping settings is an art". https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot: a lower Max Distance gives better-looking shadows and better performance (more texels per metre). https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot: Blend Splits trades detail and performance for smoother split transitions; it is ignored in SHADOW_ORTHOGONAL mode. https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_directionallight3d.rst
- Godot: Pancake Size (default 20) moves the shadow frustum start for more depth precision; a high value can cause artifacts on large objects near the frustum edge; 0 turns it off. Change only for missing shadows. https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_directionallight3d.rst
- Godot: Light Blur multiplies the blur radius; higher is softer and "more temporally stable for moving objects", but shows the grainy filter pattern more. https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot: Shadow filter mode default is Soft Low; raise to Soft Medium or more (or FXAA) to hide the dither pattern; Soft High/Ultra raise blur automatically. https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot: Fade Start can go to 1.0 only when Max Distance covers the whole scene. https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html

### Microsoft, "Common Techniques to Improve Shadow Depth Maps" (saved: pages/shadow-low-sun/msdn-common-techniques.html)
- Projective aliasing "occurs as the tangent plane of the geometry becomes parallel to the light rays": this is exactly our low sun on flat ground, and it shows as distended (stretched) shadows. https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps
- Polygons steep to the light suffer more projective aliasing, so each depth needs a different offset by slope: slope-scaled depth bias (hardware feature since D3D10). https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps
- Perspective aliasing (texels per screen pixel) is what cascades fix; techniques for it also help projective aliasing. https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps
- Keep the light projection the same size every frame and move it in texel-sized increments, or edges shimmer as the camera moves; tight near and far planes give more depth precision. https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps

### Godot community (forum, issues)
- Godot forum: when the light is almost parallel to the ground, too much geometry has to fit in the shadow buffer, which leads to glitches; advice was higher shadow quality and adjusting split distances (forum answer, not a maintainer). https://forum.godotengine.org/t/why-do-my-shadows-look-so-jagged/104023
- Godot issue #73472: shadows look low-resolution when the light's Blur is set low (reported with ortho camera); blur hides texel steps. https://github.com/godotengine/godot/issues/73472
- Search found no Godot GitHub issue specific to low-sun stair-stepping with a maintainer fix (searched 13 Nov 2026, 08:08). Not checked: whether Compatibility honours soft filter quality and blend splits (no source read in time).

### Unity
- Unity: Bias is a depth offset in the shadow map; Normal Bias insets casters along their normals; too high a Normal Bias makes shadows too narrow and can leak light; set by eye. https://docs.unity3d.com/2022.3/Documentation/Manual/ShadowPerformance.html
- Unity 6.4: camera-relative shadow culling reduces distant-shadow flicker. https://docs.unity3d.com/6000.4/Documentation/Manual/ShadowPerformance.html

### Normal offset shadows
- Normal offset: push the receiver position along its normal (scaled, a tunable factor) before the shadow lookup, in place of depth bias; removes acne with less peter-panning. https://gamedev.net/blogs/515/entry-2260845-me-and-my-shadow/
- Holbert GDC 2011 talk itself was not found in time; not verified.

### Godot Light3D class reference (saved: pages/shadow-low-sun/godot-class-light3d.rst)
- shadow_normal_bias "offsets the lookup into the shadow map by the object's normal" (Godot's normal offset); tune it together with shadow_bias. https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_light3d.rst
- shadow_opacity below 1.0 lets light show through shadows: this is the knob to fade shadow strength near sunrise and sunset. https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_light3d.rst
- light_angular_distance above 0 turns on PCSS (softer far shadows) with a "noticeable performance cost"; the real Sun from Earth is about 0.5 degrees. https://raw.githubusercontent.com/godotengine/godot-docs/master/classes/class_light3d.rst

### Games and Unreal
- Unreal forum: low sun angles are a worst case for cascaded shadow maps because more casters cross the shadow frusta, and "some titles artificially limit the sun angle" (a forum reply, no game named). https://forums.unrealengine.com/t/fps-issues-dynamic-lightning-during-sun-set-rise/380534
- Unity: objects near the shadow distance fade out gradually; Unity clamps casters to the light near plane in the vertex shader (pancaking), with a near plane offset for very large triangles. https://docs.unity3d.com/2017.3/Documentation/Manual/DirLightShadows.html
- Not found in time (no source, do not cite): named games (Assassin's Creed, Far Cry, GTA V, Witcher 3, Minecraft shaders) clamping sun elevation; receiver plane depth bias; Unreal Shadow Slope Bias docs.

## Recommendation for Outpost Gale (ranked; our judgement built on the sources above)
1. Keep the minimum shadow-casting elevation, at 15 degrees (now) to 20 degrees. Projective aliasing grows as ground turns parallel to the light (Microsoft), and shipped titles limit the sun angle (Unreal forum). The sky disc stays at the real position; only the shadow light is clamped.
2. Fade shadow_opacity as the real sun drops below about 20 degrees, down to about 0.3 to 0.5 at the horizon. Real low-sun light is weaker and the sky ambient takes over, so softer shadows read as right, and it hides the stair-steps the clamp leaves (Light3D shadow_opacity doc).
3. Tighten Max Distance before raising map size: 60 m is fine; 40 m gives 1.5x texels per metre along each axis (Godot docs: lower max distance = better shadows). Keep 4096.
4. Bias: keep shadow_bias low (around the default 0.1) and use shadow_normal_bias as the main fix (Godot: prefer normal bias; it is a normal offset). Try 2 to 3 instead of 4 if contact shadows look thin or detached at box feet; raise only if acne returns.
5. Raise shadow_blur on the sun (1.5 to 2) at low sun: it smears texel steps and is more temporally stable (Godot docs, issue #73472). Check Soft filter quality in Compatibility on the A16 first (unverified that Compatibility honours it).
6. Keep blend splits on only if Compatibility draws them right (13 Nov playtest saw trouble, then traced it to tilted panels); it trades detail for no visible seam (Godot doc).
7. Snapping and stable fit: Godot already does a stable (texel-snapped) directional fit internally, so no game code; move the sun in smoothed steps (factory skill day-cycle) so the projection does not crawl (Microsoft: texel-sized increments, constant projection size). Not verified in the Godot source this session.
8. Skip PCSS (light_angular_distance > 0): a noticeable cost (Godot doc) and the A16 is already at about 20 fps.
