# Godot: triplanar in StandardMaterial3D, and two CC0 up-facing coat shaders from godotshaders.com
Fetched: 2026-11-12

## Godot docs, Standard Material 3D, "Triplanar Mapping" (4.7 docs, copy already saved at ../dust/godot/tutorials_3d_standard_material_3d.rst)
URL: https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html
> "Triplanar mapping is supported for both UV1 and UV2. This is an alternative way to obtain texture coordinates, sometimes called "Autotexture". Textures are sampled in X, Y and Z and blended by the normal. Triplanar mapping can be performed in either world space or object space."
> "Godot allows using secondary albedo and normal maps to generate a detail texture, which can be blended in many ways. By combining this with secondary UV or triplanar modes, many interesting textures can be achieved."

## "World Normal Mix Shader", Kasper Arnklit Frandsen, CC0 (WebFetch)
URL: https://godotshaders.com/shader/world-normal-mix-shader/
> "A shader that mixes two sets of textures based on direction of the world normals."
```
vec3 up_vector_viewspace = mat3(INV_CAMERA_MATRIX) * vec3(0.0, 1.0, 0.0);
float dot_product = dot(up_vector_viewspace, normal_applied);
float mask = smoothstep(offset - fade, offset + fade, dot_product);
ALBEDO = mix(albedo_tex_bg, albedo_tex_fg, mask);
vec3 mixed_orm = mix(orm_tex_bg, orm_tex_fg, mask);
ROUGHNESS = mixed_orm.g;
NORMALMAP = mix(normal_tex_bg, normal_tex_fg, mask);
```
(Godot 3 names: INV_CAMERA_MATRIX is VIEW_MATRIX's inverse; in 4.x use INV_VIEW_MATRIX / VIEW_MATRIX.)

## "Snow-Covered Surface", rrh, CC0 (WebFetch)
URL: https://godotshaders.com/shader/snow-covered-surface/
> "Displays snow colour on upward-facing surfaces, and accounts for normal map while we're at it."
```
vec3 world_normal = (INV_VIEW_MATRIX * vec4(viewspace_normal, 0.0)).xyz;
float mapped_snow_mask = smoothstep(0.0, 1.0 - snow_ammount, dot(world_normal, up));
mapped_snow_mask = pow(mapped_snow_mask, snow_softness);
float snow_mask = max(vertex_snow_mask, mapped_snow_mask);
ALBEDO = mix(base_colour, snow_colour, snow_mask);
NORMAL_MAP = mix(normal_map.rgb, vec3(0.5), snow_mask);   // flattens the base normal under the coat
```
