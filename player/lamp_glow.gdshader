shader_type spatial;
// The helmet lamps' light in the air (player/suit_lamps.gd): a hollow cone ahead of each lamp, and, built with
// "#define HALO" in place of the marker below, a small disc of glare that faces the lens. Added to the picture,
// never lit and never written to depth: a wall hides it as it hides any mesh, and it costs no light pass. The
// Compatibility renderer has no volumetric fog, and a spot only shows where it lands (the hero's own beam landed
// metres ahead, so on foot nothing was seen leaving the lamps).
// VARIANT
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float strength = 0.0;  // the look's share (data/tuning.json lamps) times the lamps' fade
uniform float size = 1.0;  // m: the cone's length, or the halo's radius

varying float along;  // 0 at the lamp, 1 at the cone's far end
varying vec3 axis;  // the way the lamp points (the mesh's +Y), in view space
varying float facing;  // how squarely the lamp faces the lens

void vertex() {
	axis = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
#ifdef HALO
	// a quad turned to the lens and pulled a radius toward it, so the helmet behind the lamp does not cut it in half
	vec3 mid = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 eye = normalize(-mid);
	facing = dot(axis, eye);
	POSITION = PROJECTION_MATRIX * vec4(mid + eye * size + vec3(VERTEX.xy * size * 2.0, 0.0), 1.0);
#else
	along = VERTEX.y / size + 0.5;
#endif
}

void fragment() {
#ifdef HALO
	// glare is seen from in front only: from behind the helmet is in the way, and no glow spills round it
	float d = clamp(1.0 - length(UV - 0.5) * 2.0, 0.0, 1.0);
	ALBEDO = color * strength * d * d * smoothstep(0.0, 0.5, facing);
#else
	vec3 eye = normalize(VIEW);
	float into = dot(axis, eye);  // 1 looking straight into the lamp, -1 from right behind it
	// across the beam, whatever the angle it is seen from: full along its middle, nothing at its outline, so the
	// cone has no edge (the wall's normal is square to the axis, near enough for a narrow cone)
	float across = abs(dot(normalize(NORMAL), eye)) / max(sqrt(1.0 - into * into), 0.05);
	// looking into the lamp the cone would be a white disc over the lens: the halo is the glare there
	float end_on = 1.0 - smoothstep(0.6, 0.95, into);
	// a sight line along the beam crosses more lit air than one across it: brighter, and lit further out, so from
	// the play camera behind the hero the light shows round the body instead of hiding behind it
	float sight = into * into;
	float fall = 1.0 - along;
	ALBEDO = color * strength * mix(fall * fall, fall, sight) * (1.0 + 4.0 * sight) * min(across * across, 1.0) * end_on;
#endif
}
