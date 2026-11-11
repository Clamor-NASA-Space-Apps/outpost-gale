shader_type spatial;
// One shader for every DESIGN.md material role. house_style.gd makes a variant by putting #define lines
// in place of the marker below, so a role pays only for what it shows:
//   FLAT      geometry.shading: flat. One normal per triangle, taken from the surface itself,
//             so kit models and built-in meshes facet without re-importing them.
//   DETAIL    the role's `detail`, laid on by world position, so it only suits meshes that hold still.
//             With it, one of PATTERN_GRAIN, PATTERN_BRICKS, PATTERN_TILES, PATTERN_PLANKS (drawn here)
//             or TEXTURE (a photo). Detail only ever shades the role's colour, it never replaces it.
//   LIT       the role's `lit`: panes that light up one by one. COLOR.r is a pane's own number.
// VARIANT
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform vec3 emission : source_color = vec3(0.0);
#ifdef DETAIL
uniform vec2 detail_size = vec2(1.0);  // metres per repeat
uniform float detail_strength = 0.4;
varying vec3 world_pos;
#endif
#ifdef TEXTURE
uniform sampler2D detail_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
#endif
#ifdef LIT
uniform vec3 lit_color : source_color = vec3(1.0);
uniform float lit_share = 0.5;  // how many panes are on at any moment
uniform float lit_period = 60.0;  // seconds before a pane may change
varying flat float pane;
#endif

#ifdef DETAIL
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

// 1 inside a cell, 0 in the joint round it, which is `metres` wide on each side. `w` is how much of a cell
// one pixel covers, so a joint thinner than a pixel fades out and cannot flicker.
float joint(vec2 f, vec2 w, float metres) {
	vec2 gap = metres / detail_size;
	vec2 e = smoothstep(gap, gap + w, f) * (1.0 - smoothstep(1.0 - gap - w, 1.0 - gap, f));
	return mix(e.x * e.y, 1.0 - 2.0 * (gap.x + gap.y), clamp(max(w.x, w.y) * 3.0, 0.0, 1.0));
}
#endif

void vertex() {
#ifdef DETAIL
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#endif
#ifdef LIT
	pane = COLOR.r;
#endif
}

void fragment() {
#ifdef FLAT
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
#endif
	vec3 shade = vec3(1.0);
#ifdef DETAIL
	// each face takes the detail from the side it mostly looks at, so walls get rows and floors get slabs
	vec3 n = abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 uv = (n.y >= n.x && n.y >= n.z ? world_pos.xz : (n.x >= n.z ? world_pos.zy : world_pos.xy)) / detail_size;
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
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
#ifdef LIT
	// a pane decides again every lit_period seconds, each at its own moment
	float turn = floor(TIME / lit_period + pane * 7.0);
	float on = step(fract(sin(pane * 91.7 + turn * 17.3) * 43758.5453), lit_share);
	ALBEDO = mix(ALBEDO, lit_color, on);
	EMISSION += lit_color * on;
#endif
}
