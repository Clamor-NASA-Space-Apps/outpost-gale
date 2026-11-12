shader_type sky;
// The house rig's sky when DESIGN.md asks for a sun disc or a twilight: a sky gradient, a haze around the sun
// in its own colour (`halo`), a glow along the horizon toward where the sun is or went down (`twilight`), and
// a disc brighter than any sky colour. ProceduralSkyMaterial draws its disc at the light's energy, which comes
// out darker than a bleached horizon.

uniform vec3 top : source_color;
uniform vec3 horizon : source_color;
uniform vec3 ground : source_color;
uniform vec3 sun : source_color;
uniform float disc = 0.02; // radians; 0 draws no sun and no halo
uniform vec3 halo_color : source_color = vec3(1.0);
uniform float halo = 0.25; // radians for the glow to fall to a third
uniform float halo_strength = 0.7;
uniform vec3 twilight_color : source_color = vec3(1.0);
uniform vec3 twilight_dir = vec3(0.0, 0.0, -1.0); // flat, toward the glow
uniform float twilight_height = 0.2; // radians above the horizon for the glow to fall to a third
uniform float twilight_strength = 0.0;

void sky() {
	float y = EYEDIR.y;
	vec3 c = y > 0.0 ? mix(horizon, top, pow(y, 0.5)) : mix(horizon, ground, clamp(-y * 8.0, 0.0, 1.0));
	if (twilight_strength > 0.0 && y > -0.02) {
		// strongest on the horizon under the glow's direction, gone a quarter turn either side
		float along = max(dot(normalize(vec3(EYEDIR.x, 0.0, EYEDIR.z) + 1e-5), twilight_dir), 0.0);
		c = mix(c, twilight_color, exp(-asin(max(y, 0.0)) / twilight_height) * along * along * twilight_strength);
	}
	if (LIGHT0_ENABLED && disc > 0.0) {
		float a = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
		c = mix(c, halo_color, exp(-a / halo) * halo_strength);
		c = mix(c, sun * 4.0, smoothstep(disc * 1.15, disc, a));
	}
	// Compatibility draws into 8 bits with no debanding, and a hazy gradient bands: a 1/255 dither hides it
	COLOR = c + (fract(sin(dot(SCREEN_UV, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
}
