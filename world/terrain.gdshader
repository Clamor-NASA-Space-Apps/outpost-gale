shader_type spatial;
// The ground, in four layers, colours from the DESIGN.md roles:
//   dust    fine powder everywhere (the `dust` role and its photo set)
//   ripples wind ripples across open flats (a normal map only: ripples are shape, not colour)
//   gravel  patches of grit and pebbles (dust's colour, its own photo set)
//   rock    grey stone where the ground is steep (the `rock` role)
// Inside the walkable patch the surface direction comes from data/terrain_normal.png (the 1 m HiRISE
// heights), and a trail map holds the footprints and wheel tracks pressed into the dust (terrain.gd).
// Each photo is divided by its own average colour, so it only adds light and dark to its role's colour.

uniform vec3 dust_color : source_color = vec3(0.79, 0.54, 0.35);
uniform vec3 rock_color : source_color = vec3(0.53, 0.44, 0.42);
uniform float dust_roughness = 1.0;
uniform float rock_roughness = 0.95;

uniform sampler2D macro_normal : filter_linear_mipmap, repeat_disable;
uniform vec4 macro_rect = vec4(-200.0, -200.0, 400.0, 400.0);  // x, z of the corner, width, depth

uniform sampler2D dust_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D dust_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dust_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float dust_size = 3.1;  // metres per repeat
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float gravel_size = 2.48;
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ripple_size = 12.0;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_size = 1.83;
uniform float detail_strength = 1.0;  // 0 turns the photos off (the low preset)
uniform float rock_from = 0.80;  // cos of the slope where rock starts to show
uniform float rock_full = 0.62;  // and where it has taken over
uniform float gravel_share = 0.3;  // about this much of the open ground is gravel

uniform sampler2D trail_map : filter_linear, repeat_disable, hint_default_black;
uniform vec4 trail_rect = vec4(-32.0, -32.0, 64.0, 64.0);
// where things rest on the ground (terrain.gd contacts()): 1 under a foot, falling to 0 a little way out
uniform sampler2D contact_map : filter_linear, repeat_disable, hint_default_black;
uniform vec4 contact_rect = vec4(-150.0, -150.0, 300.0, 300.0);
uniform float contact_ao = 0.0;
uniform float contact_albedo = 0.0;
uniform float contact_pile = 0.0;
// things that move (terrain.gd movers()): x, z, radius, strength; 12 is terrain.gd MOVERS
uniform vec4 movers[12];

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A photo's light and dark around 1, sampled at two scales that do not line up, so no repeat shows.
vec3 shade(sampler2D t, vec2 uv) {
	vec3 avg = max(textureLod(t, vec2(0.5), 12.0).rgb, vec3(0.02));
	vec3 a = texture(t, uv).rgb / avg;
	vec3 b = texture(t, uv * 0.237 + 0.31).rgb / avg;
	return mix(vec3(1.0), a * mix(vec3(1.0), b, 0.5), detail_strength);
}

vec3 tnormal(sampler2D t, vec2 uv) {
	return texture(t, uv).xyz * 2.0 - 1.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec2 m = (wpos.xz - macro_rect.xy) / macro_rect.zw;
	// fade the 1 m map out over the patch's last 10%, where the backdrop takes over
	float inside = smoothstep(0.0, 0.1, min(min(m.x, m.y), min(1.0 - m.x, 1.0 - m.y)));
	if (inside > 0.0) {
		vec3 t = texture(macro_normal, m).rgb * 2.0 - 1.0;
		n = normalize(mix(n, normalize(vec3(t.x, t.z, t.y)), inside));
	}
	float rock = 1.0 - smoothstep(rock_full, rock_from, n.y);
	// photo detail fades out with distance: past a few hundred metres it only sparkles. Broad light and dark
	// zones take over there, about a kilometre across on the (squeezed) skyline
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = (1.0 - smoothstep(60.0, 350.0, dist)) * detail_strength;
	float zones = 0.8 + 0.4 * (0.65 * noise(wpos.xz / 900.0) + 0.35 * noise(wpos.xz / 260.0 + 5.0));
	// metres-wide patches of lighter and darker dust, the way wind sorts it
	float drift = 0.9 + 0.2 * (0.6 * noise(wpos.xz / 23.0) + 0.4 * noise(wpos.xz / 7.0 + 13.0));
	// gravel lies in patches; ripples cover the open sand between them
	float g = 0.7 * noise(wpos.xz / 9.0 + 3.0) + 0.3 * noise(wpos.xz / 2.7);
	float gravel = smoothstep(1.0 - gravel_share - 0.08, 1.0 - gravel_share + 0.08, g) * (1.0 - rock);
	float ripples = smoothstep(0.5, 0.7, noise(wpos.xz / 37.0 + 41.0)) * (1.0 - gravel) * (1.0 - rock);

	vec2 du = wpos.xz / dust_size;
	vec2 gu = wpos.xz / gravel_size;
	vec2 ru = wpos.xz / rock_size;
	vec3 ground = mix(shade(dust_albedo, du), shade(gravel_albedo, gu) * 0.93, gravel);
	vec3 albedo = mix(dust_color * mix(vec3(1.0), ground, near) * drift, rock_color * mix(vec3(1.0), shade(rock_albedo, ru), near), rock);
	albedo *= mix(zones, 1.0, near);

	vec3 tn = mix(tnormal(dust_normal, du), tnormal(gravel_normal, gu), gravel);
	vec3 rp = tnormal(ripple_normal, wpos.xz / ripple_size);
	tn.xy += rp.xy * ripples * 0.45;
	tn = mix(tn, tnormal(rock_normal, ru), rock);

	// footprints and tracks: a dent in the dust, a little darker where it is pressed
	vec2 tu = (wpos.xz - trail_rect.xy) / trail_rect.zw;
	if (tu.x > 0.0 && tu.y > 0.0 && tu.x < 1.0 && tu.y < 1.0) {
		vec2 e = vec2(1.0 / float(textureSize(trail_map, 0).x), 0.0);
		float d = texture(trail_map, tu).r;
		float dx = texture(trail_map, tu + e.xy).r - texture(trail_map, tu - e.xy).r;
		float dz = texture(trail_map, tu + e.yx).r - texture(trail_map, tu - e.yx).r;
		float soft = 1.0 - rock;
		albedo *= 1.0 - 0.04 * d * soft;  // a fresh print darkens Mars dust 2 to 4% (design/research/dust.md); the dent does the rest
		tn.xy += vec2(dx, dz) * 2.5 * soft;
	}

	// where something rests: the sky is blocked (AO, which Compatibility applies to the ambient light only,
	// skills/shadows-and-grounding), the dust a little darker, and a faint rim of dust pushed up round it
	float contact = 0.0;
	vec2 cu = (wpos.xz - contact_rect.xy) / contact_rect.zw;
	if (cu.x > 0.0 && cu.y > 0.0 && cu.x < 1.0 && cu.y < 1.0) {
		vec2 e = vec2(1.0 / float(textureSize(contact_map, 0).x), 0.0);
		contact = texture(contact_map, cu).r;
		float cx = texture(contact_map, cu + e.xy).r - texture(contact_map, cu - e.xy).r;
		float cz = texture(contact_map, cu + e.yx).r - texture(contact_map, cu - e.yx).r;
		tn.xy -= vec2(cx, cz) * contact_pile * (1.0 - rock);
	}
	for (int i = 0; i < 12; i++) {
		float d = 1.0 - length(wpos.xz - movers[i].xy) / max(movers[i].z, 0.001);
		contact = max(contact, movers[i].w * d * d * step(0.0, d));
	}
	albedo *= 1.0 - contact_albedo * contact;

	tn = normalize(mix(vec3(0.0, 0.0, 1.0), tn, near));
	// the photos are laid flat on x and z: their right is +X, their up (+v) is +Z
	vec3 tx = normalize(vec3(1.0, 0.0, 0.0) - n * n.x);
	vec3 tz = normalize(cross(tx, n));
	vec3 wn = normalize(tx * tn.x + tz * tn.y + n * tn.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = albedo;
	float r = mix(dust_roughness * texture(dust_rough, du).r, rock_roughness * texture(rock_rough, ru).r, rock);
	ROUGHNESS = mix(mix(dust_roughness, rock_roughness, rock), r, near);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	AO = 1.0 - contact_ao * contact;
}
