shader_type sky;
// The house rig's sky when DESIGN.md asks for a sun disc: a sky gradient, a haze that bleaches the sky
// around the sun, and a disc brighter than any sky colour. ProceduralSkyMaterial draws its disc at the
// light's energy, which comes out darker than a bleached horizon.

uniform vec3 top : source_color;
uniform vec3 horizon : source_color;
uniform vec3 ground : source_color;
uniform vec3 sun : source_color;
uniform float disc = 0.02; // radians
uniform float halo = 0.25; // radians for the glow to fall to a third

void sky() {
	float y = EYEDIR.y;
	vec3 c = y > 0.0 ? mix(horizon, top, pow(y, 0.5)) : mix(horizon, ground, clamp(-y * 8.0, 0.0, 1.0));
	if (LIGHT0_ENABLED) {
		float a = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
		c = mix(c, sun, exp(-a / halo) * 0.7);
		c = mix(c, sun * 4.0, smoothstep(disc * 1.15, disc, a));
	}
	COLOR = c;
}
