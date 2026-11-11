shader_type spatial;
render_mode cull_disabled, blend_mix;
// Footstep grit and haze, lit as the ground they came from: a camera-facing particle quad, shaded as if it
// faced up, so it takes the same sun, ambient and shadow as the dust around it. A grain in a building's
// shadow is as dark as the shaded ground there; a quad facing the camera with its own normal went dark
// brown when the camera looked toward a low sun. dust.gd puts "#define GRIT" in place of the marker
// below for the grains (cut out, opaque); without it the quad is blended (the haze).
// VARIANT

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D shape : source_color, filter_linear_mipmap;

void vertex() {
	// the engine's particle billboard (BaseMaterial3D BILLBOARD_PARTICLES, keep scale), without its rotation
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	ALPHA = texture(shape, UV).a * COLOR.a;
#ifdef GRIT
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;  // matte, like the dust role
	SPECULAR = 0.3;
}
