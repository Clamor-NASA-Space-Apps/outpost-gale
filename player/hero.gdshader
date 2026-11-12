shader_type spatial;
// The hero's own copy of a role (skills/third-person-camera rule 9, skills/shadows-and-grounding section 4): the
// role's plain values, a pixel dither that fades the hero when the lens comes close (Godot's own
// DISTANCE_FADE_PIXEL_DITHER, which a ShaderMaterial does not get), and dust on the boots by height in the
// model's own space, so the tint stays on the boots as the hero moves.

uniform vec4 albedo : source_color;
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform vec3 dust : source_color;
uniform float dust_height = 0.2; // m above the soles where the tint has faded out
uniform float dust_share = 0.5; // how far toward the dust colour at the sole
uniform float fade_near = 0.5; // m: gone from here in
uniform float fade_far = 0.9; // m: fully drawn from here out

varying float height;

void vertex() {
	height = VERTEX.y;
}

void fragment() {
	// the engine's dither: interleaved gradient noise against the fade, a hard cap so no stray pixels stay
	const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
	float fade = clamp(smoothstep(fade_near, fade_far, length(VERTEX)), 0.0, 1.0);
	if (fade < 0.001 || fade < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
		discard;
	}
	float d = dust_share * (1.0 - smoothstep(0.0, dust_height, height));
	ALBEDO = mix(albedo.rgb, dust, d);
	ROUGHNESS = mix(roughness, 1.0, d); // dust is matte
	METALLIC = metallic * (1.0 - d);
}
