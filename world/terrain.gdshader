shader_type spatial;
// The ground: red dust on flat ground, grey rock where it is steep, colours from the DESIGN.md roles.
// Inside the walkable patch the surface direction comes from data/terrain_normal.png, made from the 1 m
// HiRISE heights, so the 2 m mesh shades with the real metre-scale bumps. Photo sets (colour, normal,
// roughness) add the centimetre detail; each photo is divided by its own average colour, so it only adds
// light and dark to the role's colour. With no photo set the samplers read neutral and nothing changes.

uniform vec3 dust_color : source_color = vec3(0.79, 0.54, 0.35);
uniform vec3 rock_color : source_color = vec3(0.53, 0.44, 0.42);
uniform float dust_roughness = 1.0;
uniform float rock_roughness = 0.95;

uniform sampler2D macro_normal : filter_linear_mipmap, repeat_disable;
uniform vec4 macro_rect = vec4(-200.0, -200.0, 400.0, 400.0);  // x, z of the corner, width, depth

uniform sampler2D dust_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D dust_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dust_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float dust_size = 3.0;  // metres per repeat
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_size = 4.0;
uniform float detail_strength = 1.0;  // 0 turns the photos off (the low preset)
uniform float rock_from = 0.80;  // cos of the slope where rock starts to show
uniform float rock_full = 0.62;  // and where it has taken over

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
	// metres-wide patches of lighter and darker dust, the way wind sorts it
	float drift = 0.88 + 0.24 * (0.6 * noise(wpos.xz / 23.0) + 0.4 * noise(wpos.xz / 7.0 + 13.0));

	vec2 du = wpos.xz / dust_size;
	vec2 ru = wpos.xz / rock_size;
	vec3 albedo = mix(dust_color * shade(dust_albedo, du) * drift, rock_color * shade(rock_albedo, ru), rock);
	vec3 dn = texture(dust_normal, du).xyz * 2.0 - 1.0;
	vec3 rn = texture(rock_normal, ru).xyz * 2.0 - 1.0;
	vec3 tn = normalize(mix(mix(vec3(0.0, 0.0, 1.0), dn, detail_strength), rn * vec3(detail_strength, detail_strength, 1.0), rock));
	// the photos are laid flat on x and z: their right is +X, their up (+v) is +Z
	vec3 tx = normalize(vec3(1.0, 0.0, 0.0) - n * n.x);
	vec3 tz = normalize(cross(tx, n));
	vec3 wn = normalize(tx * tn.x + tz * tn.y + n * tn.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = albedo;
	float r = mix(dust_roughness * texture(dust_rough, du).r, rock_roughness * texture(rock_rough, ru).r, rock);
	ROUGHNESS = mix(mix(dust_roughness, rock_roughness, rock), r, detail_strength);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
