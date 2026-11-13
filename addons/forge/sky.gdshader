shader_type sky;
// The house rig's sky when DESIGN.md asks for a sun disc, a twilight or a night sky: a sky gradient, a haze around the
// sun in its own colour (`halo`), a glow along the horizon toward where the sun is or went down (`twilight`), and a
// disc brighter than any sky colour. ProceduralSkyMaterial draws its disc at the light's energy, which comes out
// darker than a bleached horizon.
// `lighting.celestial` adds the real night sky of a planet (house_style.gd fills these from it): stars from a catalogue
// and the Milky Way in celestial coordinates, turned to the local horizon about the planet's own pole; planets as
// points; moons as lit discs on their own orbits, seen from the surface (parallax and phase). The sky turns on
// `forge_sky_clock`, a global uniform: a material parameter changed every frame would re-render the reflection
// cubemap every few frames, and TIME re-renders it every frame. Neither stars nor moons go into that cubemap.

global uniform float forge_sky_clock; // seconds since the rig was built (house_style.gd SkyClock), or a day cycle's
// Everything that changes with the time of day is a global too, so a day cycle can turn it every frame without
// re-rendering the reflection cubemap (house_style.gd look(), set_look()). Colours are linear.
global uniform vec3 forge_sky_top;
global uniform vec3 forge_sky_horizon;
global uniform vec3 forge_sky_ground;
global uniform vec3 forge_sky_sun;
global uniform vec3 forge_sky_sun_dir; // toward the sun; the disc is drawn here and not at LIGHT0, which may be a night fill
global uniform float forge_sky_disc; // radians; 0 draws no sun and no halo
global uniform vec3 forge_sky_halo_color;
global uniform float forge_sky_halo; // radians for the glow to fall to a third
global uniform float forge_sky_halo_strength;
global uniform vec3 forge_sky_twilight_color;
global uniform vec3 forge_sky_twilight_dir; // flat, toward the glow
global uniform float forge_sky_twilight_height; // radians above the horizon for the glow to fall to a third
global uniform float forge_sky_twilight_strength;
global uniform float forge_sky_star_fade; // 0 by day, through twilight, 1 at night (the sun's elevation)
global uniform float forge_sky_moon_fade;
global uniform float forge_sky_milky_gain;

uniform bool celestial = false;
uniform mat3 frame = mat3(1.0); // columns: the planet's equator frame (x to the node, z the pole) in celestial axes
uniform float latitude = 0.0; // radians
uniform float lst0 = 0.0; // radians: the local meridian's angle in the equator frame at clock 0
uniform float spin = 0.0; // radians a second the sky turns (2 pi / sidereal day x time scale)
uniform float planet_radius = 1.0; // the moons' distances share its unit
uniform float tau = 0.5; // dust optical depth: a star at airmass X keeps exp(-tau X) of its light
uniform float star_gain = 1.0;
uniform vec3 milky_color : source_color = vec3(0.8, 0.82, 0.9);
uniform sampler2D star_map : source_color, filter_linear_mipmap, repeat_enable; // RA across, Dec up: the Milky Way in RGB, faint stars in A
uniform sampler2D star_list : filter_nearest, repeat_disable; // per cell, LIST_K stars as two texels: (RA16, Dec16), (rgb, magnitude)
uniform vec2 list_cells = vec2(128.0, 64.0);
uniform vec3 sun_eq = vec3(1.0, 0.0, 0.0); // the true sun, in the equator frame (for the moons' phases)
uniform vec4 planet_dir[4]; // xyz in the equator frame, w magnitude (0 in w and xyz: unused)
uniform vec3 planet_color[4] : source_color;
uniform vec4 moon_orbit[2]; // x radius, y orbit radius (planet radius units), z longitude at clock 0 (rad), w rad/s
uniform vec4 moon_look[2]; // rgb colour (linear), a brightness at full (0: unused)
const int LIST_K = 6;

// light from a point source of magnitude `m` at angular distance `d` (radians: the chord between two unit vectors, the
// same for anything near enough to show, and exact where acos() is not), `px` radians per pixel, dimmed by
// `dim` on its way through the dust: a sharp core of one or two pixels whatever the screen, a little wider only for
// the few that would burn out (a log, not a root: a root made the planets soft blobs)
vec3 point(float d, float px, float m, vec3 col, float dim) {
	float flux = pow(10.0, -0.4 * (m - 1.0)) * star_gain * dim;
	float s = px * (0.7 + 0.2 * log2(max(flux, 1.0)));
	return col * min(flux, 1.5) * exp(-d * d / (2.0 * s * s));
}

void sky() {
	float y = EYEDIR.y;
	vec3 c = y > 0.0 ? mix(forge_sky_horizon, forge_sky_top, pow(y, 0.5)) : mix(forge_sky_horizon, forge_sky_ground, clamp(-y * 8.0, 0.0, 1.0));
	if (forge_sky_twilight_strength > 0.0 && y > -0.02) {
		// strongest on the horizon under the glow's direction, gone a quarter turn either side
		float along = max(dot(normalize(vec3(EYEDIR.x, 0.0, EYEDIR.z) + 1e-5), forge_sky_twilight_dir), 0.0);
		c = mix(c, forge_sky_twilight_color, exp(-asin(max(y, 0.0)) / forge_sky_twilight_height) * along * along * forge_sky_twilight_strength);
	}
	if (celestial && !AT_CUBEMAP_PASS && y > -0.05) {
		// the look direction in the planet's equator frame: east is +X, up +Y, north -Z here
		float th = lst0 + spin * forge_sky_clock;
		vec3 zen = vec3(cos(latitude) * cos(th), cos(latitude) * sin(th), sin(latitude));
		vec3 north = vec3(-sin(latitude) * cos(th), -sin(latitude) * sin(th), cos(latitude));
		vec3 east = vec3(-sin(th), cos(th), 0.0);
		vec3 d = normalize(east * EYEDIR.x + zen * EYEDIR.y - north * EYEDIR.z);
		vec3 s = frame * d; // celestial (RA, Dec) axes
		float px = max(length(fwidth(EYEDIR)), 1e-5);
		// dust: air mass grows toward the horizon (Kasten and Young's fit, near enough for a sky)
		float h = max(y, 0.0);
		float air = 1.0 / (h + 0.025 * exp(-11.0 * h));
		float dim = exp(-tau * air);
		vec3 lights = vec3(0.0);
		// the faint stars and the Milky Way from the map; the derivatives of whichever RA has no seam here
		vec2 uv = vec2(atan(s.y, s.x) / TAU + 0.5, asin(clamp(s.z, -1.0, 1.0)) / PI + 0.5);
		float u2 = fract(uv.x + 0.5);
		vec2 gx = vec2(abs(dFdx(uv.x)) < abs(dFdx(u2)) ? dFdx(uv.x) : dFdx(u2), dFdx(uv.y));
		vec2 gy = vec2(abs(dFdy(uv.x)) < abs(dFdy(u2)) ? dFdy(uv.x) : dFdy(u2), dFdy(uv.y));
		vec4 map = textureGrad(star_map, vec2(uv.x, 1.0 - uv.y), gx, gy);
		// alpha holds the square root of the faint stars' light, a star at the list's limit (V 5) filling it
		lights += (vec3(map.a * map.a * pow(10.0, -0.4 * 4.0) * star_gain) + map.rgb * milky_color * forge_sky_milky_gain) * dim;
		// the bright stars, drawn here so they stay one or two pixels sharp: the list holds every star whose glow
		// reaches into this cell
		vec2 cell = floor(vec2(uv.x * list_cells.x, uv.y * list_cells.y));
		for (int k = 0; k < LIST_K; k++) {
			ivec2 at = ivec2(int(cell.x) * LIST_K * 2 + k * 2, int(list_cells.y - 1.0 - cell.y));
			vec4 a = texelFetch(star_list, at, 0);
			vec4 b = texelFetch(star_list, at + ivec2(1, 0), 0);
			if (b.a == 0.0) {
				break;
			}
			float ra = (a.r * 255.0 * 256.0 + a.g * 255.0) / 65535.0 * TAU;
			float de = (a.b * 255.0 * 256.0 + a.a * 255.0) / 65535.0 * PI - PI / 2.0;
			vec3 st = vec3(cos(de) * cos(ra), cos(de) * sin(ra), sin(de));
			lights += point(length(s - st), px, b.a * 255.0 / 28.0 - 2.0, b.rgb, dim);
		}
		for (int i = 0; i < 4; i++) {
			if (planet_dir[i].xyz != vec3(0.0)) {
				lights += point(length(d - planet_dir[i].xyz), px, planet_dir[i].w, planet_color[i], dim);
			}
		}
		c += lights * forge_sky_star_fade;
		// moons: where each is now, seen from this spot on the surface (so near ones show parallax and rise
		// where their orbit takes them), a disc lit by the true sun
		vec3 eye = zen * planet_radius;
		for (int i = 0; i < 2; i++) {
			if (moon_look[i].a <= 0.0) {
				continue;
			}
			float lon = moon_orbit[i].z + moon_orbit[i].w * forge_sky_clock;
			vec3 at = vec3(cos(lon), sin(lon), 0.0) * moon_orbit[i].y;
			// inside the planet's shadow (a cylinder one radius wide behind it) the sun does not reach it: Phobos
			// goes dark there for most of an hour on most orbits
			float behind = dot(at, sun_eq);
			float sunlit = behind < 0.0 && length(at - sun_eq * behind) < 1.0 ? 0.0 : 1.0;
			vec3 to = at - eye;
			float dist = length(to);
			to /= dist;
			float r = max(asin(moon_orbit[i].x / dist), px * 0.7);
			// angles this small from acos() came out in steps of a fifth of Phobos (float precision): the length of
			// the offset across the line of sight is exact enough
			vec3 off = d - to * dot(d, to);
			float a = length(off);
			if (dot(to, zen) > -0.02 && dot(d, to) > 0.0 && a < r + px * 2.0) {
				// the sphere's normal under this pixel, from the disc's own coordinates
				float rho = min(a / r, 1.0);
				vec3 n = normalize(normalize(off + 1e-6) * rho - to * sqrt(1.0 - rho * rho));
				float lit = max(dot(n, sun_eq), 0.0) * sunlit;
				float edge = clamp((r + px * 0.5 - a) / px, 0.0, 1.0); // a soft pixel at the rim
				float hdim = exp(-tau * (1.0 / (max(dot(to, zen), 0.0) + 0.025 * exp(-11.0 * max(dot(to, zen), 0.0)))));
				// the night side is not black: the planet's own reflected light reaches it (as earthshine does the Moon)
				vec3 face = moon_look[i].rgb * moon_look[i].a * (0.08 + lit) * hdim;
				// the disc hides the stars behind it, its dark side too
				c = mix(c, c - lights * forge_sky_star_fade + face, edge * forge_sky_moon_fade);
			}
		}
	}
	if (forge_sky_disc > 0.0) {
		float a = acos(clamp(dot(EYEDIR, forge_sky_sun_dir), -1.0, 1.0));
		// a sun gone below the horizon takes its glow with it
		float up = smoothstep(-0.1, 0.02, forge_sky_sun_dir.y);
		c = mix(c, forge_sky_halo_color, exp(-a / forge_sky_halo) * forge_sky_halo_strength * up);
		c = mix(c, forge_sky_sun * 4.0, smoothstep(forge_sky_disc * 1.15, forge_sky_disc, a) * step(0.0, y));
	}
	// Compatibility draws into 8 bits with no debanding, and a hazy gradient bands: a 1/255 dither hides it
	COLOR = c + (fract(sin(dot(SCREEN_UV, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
}
