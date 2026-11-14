shader_type spatial;
// One shader for every DESIGN.md material role. house_style.gd makes a variant by putting #define lines
// in place of the marker below, so a role pays only for what it shows:
//   FLAT      geometry.shading: flat. One normal per triangle, taken from the surface itself,
//             so kit models and built-in meshes facet without re-importing them.
//   DETAIL    the role's `detail`, laid on by world position on meshes that hold still, and by the mesh's
//             own position (LOCAL) on meshes that move, so it travels with them.
//             With it, one of PATTERN_GRAIN, PATTERN_BRICKS, PATTERN_TILES, PATTERN_PLANKS (drawn here)
//             or TEXTURE (a photo). Detail only ever shades the role's colour, it never replaces it.
//             NORMALMAP and ROUGHMAP add the photo set's normal (OpenGL) and roughness maps.
//   LIT       the role's `lit`: panes that light up one by one. COLOR.r is a pane's own number.
//   SEE       the role's `opacity` below 1: glass you see through. What it lets through is 1 - ALPHA of what lies
//             behind it, and what it reflects is added on top (premultiplied), so it stays clear head-on and turns
//             to a mirror at a grazing angle, like real glass. Blended, so it sorts and costs more.
//   COAT      DESIGN.md `weathering`: settled dust (or snow, ash, grime) over the role, thickest on level tops, thin
//             on walls, none underneath, by the face's own direction (skills/surface-weathering). Thin, it tints
//             the surface and leaves its texture and bumps showing; it always takes the shine away. In the mesh's
//             own space with LOCAL, so it stays put on a part that turns. COAT_NOISE breaks it into patches,
//             COAT_GRAIN adds the coat's own photo. KEEP: an official model's own textures under the coat.
//             COAT_EACH scales it per copy in a MultiMesh by its custom data's red (0 clean, 1 the whole coat; a
//             mesh drawn on its own reads 0): one draw for a row of panels that each hold their own dust. Its
//             blue set to 1 or -1, a wiper is going that way along the copy's x and stands at its green (m): the
//             coat is left only ahead of it.
// VARIANT
#ifdef SEE
// no depth write: a blended pane that wrote depth hid any blended surface drawn after it behind it (its own far
// side by triangle order, other glass, a body fading out), and the draw order of blended things follows the camera
render_mode blend_premul_alpha, cull_disabled;
#endif
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
#ifdef DETAIL
uniform vec2 detail_size = vec2(1.0);  // metres per repeat
uniform float detail_strength = 0.4;
#endif
#if defined(DETAIL) || defined(COAT)
varying vec3 world_pos;
varying vec3 surf_nrm;
#endif
#ifdef COAT
uniform vec3 coat_color : source_color = vec3(1.0);
uniform float coat_amount = 0.5;  // how much a level top is covered, 0 to 1 (the role's share already in)
uniform float coat_side = 0.15;  // the share of that a wall keeps; undersides fade to none
uniform float coat_crevice = 0.5;  // extra in the dark seams of the role's photo
uniform float coat_noise = 1.5;  // metres per patch
#endif
#ifdef COAT_EACH
varying float coat_each;
varying float coat_past;  // m past the wiper, the way it goes: linear in x, so exact between vertices
#endif
#ifdef COAT_GRAIN
uniform sampler2D coat_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float coat_texture_size = 3.0;
#endif
#ifdef KEEP
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
#endif
#ifdef KEEP_NORMAL
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_normal_scale = 1.0;
#endif
#ifdef TEXTURE
uniform sampler2D detail_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
#endif
#ifdef NORMALMAP
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
#endif
#ifdef ROUGHMAP
uniform sampler2D detail_roughness : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
#endif
#ifdef LIT
uniform vec3 lit_color : source_color = vec3(1.0);
uniform float lit_share = 0.5;  // how many panes are on at any moment
uniform float lit_period = 60.0;  // seconds before a pane may change
varying flat float pane;
#endif

#if defined(DETAIL) || defined(COAT_NOISE)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise between 0 and 1, about one blob per unit.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
#endif

#ifdef DETAIL

// 1 inside a cell, 0 in the joint round it, which is `metres` wide on each side. `w` is how much of a cell
// one pixel covers, so a joint thinner than a pixel fades out and cannot flicker.
float joint(vec2 f, vec2 w, float metres) {
	vec2 gap = metres / detail_size;
	vec2 e = smoothstep(gap, gap + w, f) * (1.0 - smoothstep(1.0 - gap - w, 1.0 - gap, f));
	return mix(e.x * e.y, 1.0 - 2.0 * (gap.x + gap.y), clamp(max(w.x, w.y) * 3.0, 0.0, 1.0));
}
#endif

void vertex() {
#if defined(DETAIL) || defined(COAT)
#ifdef LOCAL
	world_pos = VERTEX;
	surf_nrm = NORMAL;
#else
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surf_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
#endif
#endif
#ifdef LIT
	pane = COLOR.r;
#endif
#ifdef COAT_EACH
	coat_each = INSTANCE_CUSTOM.r;
	coat_past = INSTANCE_CUSTOM.b == 0.0 ? 1.0 : (VERTEX.x - INSTANCE_CUSTOM.g) * INSTANCE_CUSTOM.b;
#endif
}

void fragment() {
#ifdef FLAT
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
#endif
	vec3 shade = vec3(1.0);
#ifdef DETAIL
	// each face takes the detail from the side it mostly looks at, so walls get rows and floors get slabs
#if defined(FLAT) && defined(LOCAL)
	vec3 g = normalize(inverse(mat3(MODEL_MATRIX)) * (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);  // flat rebuilt NORMAL just now
#elif defined(FLAT)
	vec3 g = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
#else
	vec3 g = normalize(surf_nrm);
#endif
	vec3 n = abs(g);
	bool top = n.y >= n.x && n.y >= n.z;
	bool side_x = !top && n.x >= n.z;
	vec2 uv = (top ? world_pos.xz : (side_x ? world_pos.zy : world_pos.xy)) / detail_size;
	vec2 w = fwidth(uv);
	float far = clamp(max(w.x, w.y) * 2.0, 0.0, 1.0);  // 1 where a repeat is smaller than two pixels
#ifdef TEXTURE
	// the photo over its own average colour: what is left is the surface's light and dark, in the role's hue
	shade = texture(detail_texture, uv).rgb / max(textureLod(detail_texture, uv, 16.0).rgb, vec3(0.02));
#elif defined(PATTERN_GRAIN)
	shade = vec3(0.5 + 0.6 * noise(uv) + 0.4 * noise(uv * 4.0 + 7.0));
#elif defined(PATTERN_PLANKS)
	// boards run along v, each with its own tone and its own end joints
	float board = floor(uv.x);
	vec2 p = vec2(uv.x, uv.y + hash(vec2(board, 3.0)));
	shade = vec3((0.85 + 0.3 * hash(vec2(board, floor(p.y)))) * joint(fract(p), w, 0.004));
#else
	vec2 p = uv;
#ifdef PATTERN_BRICKS
	p.x += 0.5 * floor(p.y);  // every other row is shifted half a brick
#endif
	shade = vec3((0.85 + 0.3 * hash(floor(p))) * joint(fract(p), w, 0.008));
#endif
	shade = mix(vec3(1.0), mix(shade, vec3(1.0), far), detail_strength);
#endif
	ALBEDO = albedo.rgb * shade;
#ifdef KEEP
	ALBEDO *= texture(base_texture, UV).rgb;
#endif
#ifdef SEE
	ALPHA = albedo.a;
#endif
	float cov = 0.0;  // how much of the surface the coat hides
#ifdef COAT
	// the face as built, before any normal map: a level top takes all of it, a wall coat_side, an underside none
	vec3 cn = normalize(surf_nrm);
	float face = cn.y > 0.0 ? mix(coat_side, 1.0, smoothstep(0.2, 0.85, cn.y)) : coat_side * (1.0 + cn.y);
	float thick = coat_amount * face;
#if defined(COAT_NOISE) || defined(COAT_GRAIN)
	vec2 cp = abs(cn.y) > 0.5 ? world_pos.xz : (abs(cn.x) > abs(cn.z) ? world_pos.zy : world_pos.xy);
#endif
#ifdef COAT_NOISE
	// patches: thick here, swept thin there (wind leaves "heavily dusty and windswept areas"), never a clean edge
	thick *= 0.3 + 1.4 * (0.7 * noise(cp / coat_noise) + 0.3 * noise(cp * 3.7 / coat_noise + 5.0));
#endif
#ifdef DETAIL
	// it gathers in seams and pits: the dark of the role's own photo or pattern
	thick += coat_crevice * coat_amount * max(face, 0.0) * clamp(1.0 - dot(shade, vec3(0.333)), 0.0, 1.0);
#endif
#ifdef COAT_EACH
	thick *= coat_each * smoothstep(0.0, 0.25, coat_past);
#endif
	cov = clamp(thick, 0.0, 1.0);
	vec3 coat = coat_color;
#ifdef COAT_GRAIN
	vec2 gp = cp / coat_texture_size;
	coat *= texture(coat_texture, gp).rgb / max(textureLod(coat_texture, gp, 16.0).rgb, vec3(0.02));
#endif
	// Thin, the coat is a filter: its grains swallow blue and pass red, so what shows through is tinted by its
	// colour (multiplied, so dark stays dark). Thick, it is the coat's own colour.
	vec3 tint = coat_color / max(max(coat_color.r, coat_color.g), max(coat_color.b, 0.001));
	ALBEDO = mix(ALBEDO * mix(vec3(1.0), tint, cov), coat, cov);
#ifdef SEE
	ALPHA = mix(ALPHA, 1.0, cov);  // a film on glass: still see-through while thin
#endif
#endif
	ROUGHNESS = roughness;
#ifdef ROUGHMAP
	// the map's own average stays the role's roughness, so a set never makes a role glossier overall
	float rough_avg = max(textureLod(detail_roughness, uv, 16.0).r, 0.02);
	ROUGHNESS = clamp(roughness * mix(1.0, texture(detail_roughness, uv).r / rough_avg, detail_strength), 0.02, 1.0);
#endif
	ROUGHNESS = mix(ROUGHNESS, 1.0, cov);  // powder has no shine
#ifdef NORMALMAP
	// the photo's right and up on the side it was laid on, then bent by its normal map
	vec3 tu = top ? vec3(1.0, 0.0, 0.0) : (side_x ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
	vec3 tv = top ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	tu = normalize(tu - g * dot(g, tu));
	tv = normalize(tv - g * dot(g, tv) - tu * dot(tu, tv));
	vec3 tn = texture(detail_normal, uv).xyz * 2.0 - 1.0;
	tn.xy *= detail_strength * (1.0 - far) * (1.0 - 0.5 * cov);  // a thin coat drapes the bumps, it does not fill them
	vec3 bent = normalize(tu * tn.x + tv * tn.y + g * tn.z);
#ifdef LOCAL
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(bent, 0.0))).xyz);  // MODELVIEW_MATRIX is vertex-only
#else
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
#endif
	// A bent normal turned away from the eye (a thin rail seen edge-on) reflects into the surface itself, and the
	// engine darkens that reflection (scene.glsl `horizon`): pixel by pixel, a two-tone speckle that crawled along
	// rails at sunset. Leaned back until it faces the eye a little, it reflects the sky like its neighbours.
	NORMAL = normalize(NORMAL + VIEW * max(0.0, 0.1 - dot(NORMAL, VIEW)));
#endif
#ifdef KEEP_NORMAL
	NORMAL_MAP = texture(base_normal, UV).rgb;
	NORMAL_MAP_DEPTH = base_normal_scale * (1.0 - 0.5 * cov);
#endif
	METALLIC = metallic * (1.0 - cov);  // dust on metal is dust
	EMISSION = emission;
#ifdef SEE
	// Blended, the engine dims reflections by ALPHA too, so a half-opaque pane read as a milky film. Here the
	// engine's reflection, with its own Fresnel, is added whole, and the pane lets less through at a grazing angle
	// (Schlick, glass F0 0.04).
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 5.0);
	ALPHA = mix(ALPHA, 1.0, 0.04 + 0.96 * fres);
	// Clean glass scatters next to no light of its own: lit by the sun, a body at the role's colour put a pale veil
	// over everything behind a dome (four surfaces). ALBEDO is still sRGB here (Compatibility makes it linear after
	// this shader), so this scales the body by about ALPHA^2.2: nothing head-on, a dust film where the coat is thick.
	ALBEDO *= ALPHA;
	EMISSION *= ALPHA;
	// Compatibility's environment BRDF (Lazarov's fit, scene.glsl) gives a smooth dielectric 12% head-on at the
	// default F0 0.04, three times real glass; 0.225 (F0 0.008) brings it back to about 4% per surface
	SPECULAR = 0.225;
#endif
#ifdef LIT
	// a pane decides again every lit_period seconds, each at its own moment
	float turn = floor(TIME / lit_period + pane * 7.0);
	float on = step(fract(sin(pane * 91.7 + turn * 17.3) * 43758.5453), lit_share);
	ALBEDO = mix(ALBEDO, lit_color, on);
	EMISSION += lit_color * on;
#endif
}
