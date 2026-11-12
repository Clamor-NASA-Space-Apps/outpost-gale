shader_type spatial;
// The hero's own copy of a role (skills/third-person-camera rule 9, skills/surface-weathering): the role's plain
// values under the design's dust coat, laid where a suit gathers it (boots, shins, knees, gloves) in patches, in the
// rest pose (baked into the vertex colour by hero_model.gd), so it stays on the suit as the hero moves.
// player.gd makes a second shader from this code with "#define FADE" in place of the marker below, and swaps it
// in only while the lens is close: the whole body fades as one, drawn blended after a depth prepass, so only the
// nearest surface shows (no inside of the suit) and there is no dither grain. Solid, the hero stays in the opaque
// pass, where blended dust and shadows sort as they always did.
// VARIANT
#ifdef FADE
render_mode depth_prepass_alpha;
uniform float opacity = 1.0;
#endif

uniform vec4 albedo : source_color;
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform vec3 coat_color : source_color = vec3(1.0);  // DESIGN.md weathering.color
uniform float coat_amount = 0.6;  // DESIGN.md weathering.amount times the role's weathering share
uniform float coat_max = 0.6;  // the most of the coat the suit shows: it stays a dusty white, never the dust's colour
uniform float coat_chroma = 0.4;  // the share of the dust's hue the suit takes: dust's grey-brown, never orange

varying float gathers;  // how much dust this point of the suit gathers, patches included (vertex colour red)

void vertex() {
	gathers = COLOR.r;
}

void fragment() {
	// The house style's coat (surface.gdshader COAT, skills/surface-weathering), placed by the body instead of
	// the face's direction: a walker is dusted from below and where it touches things, not from above.
	float cov = min(clamp(coat_amount * gathers, 0.0, 1.0), coat_max);
	// thin, a filter that only darkens and warms (multiplied, so a dark sole stays dark); thicker, the dust's colour
	// The hero keeps less of the dust's hue than the base does: an orange-tinted suit vanishes against the ground
	// it stands on, so the stain darkens and greys it more than it warms it.
	vec3 dust = mix(vec3(dot(coat_color, vec3(0.299, 0.587, 0.114))), coat_color, coat_chroma);
	vec3 tint = dust / max(max(dust.r, dust.g), max(dust.b, 0.001));
	ALBEDO = mix(albedo.rgb * mix(vec3(1.0), tint, cov), dust, cov * cov);
	ROUGHNESS = mix(roughness, 1.0, cov);  // dust takes the shine
	METALLIC = metallic * (1.0 - cov);
#ifdef FADE
	ALPHA = opacity;
#endif
}
