shader_type canvas_item;
// The helmet visor's edge, drawn over the 3D view and under the HUD panels: a soft curved
// vignette tinted by design colours, a thin rim glow, and faint scanlines. No TIME, so it never
// flickers or strobes, and one pass of plain maths per pixel, so phones pay almost nothing.
// Colours come from the theme: ui/components/visor.gd sets them.

uniform vec4 tint : source_color = vec4(0.0);
uniform vec4 rim : source_color = vec4(0.0);
uniform float aspect = 1.7778;            // width / height of the rect, so the curve stays round
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float scanlines : hint_range(0.0, 0.2) = 0.05;
uniform float line_px = 3.0;              // scanline period in screen pixels

void fragment() {
	// a squashed circle: the visor is wider than tall, and its edge curves in at the corners
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float d = length(p / vec2(aspect * 0.5, 0.5) * vec2(0.92, 0.98));
	float edge = smoothstep(0.78, 1.32, d);
	float glow = smoothstep(0.98, 1.08, d) * (1.0 - smoothstep(1.08, 1.22, d));
	float line = step(0.5, fract(FRAGCOORD.y / line_px)) * scanlines;
	vec3 col = mix(tint.rgb, rim.rgb, glow * 0.6);
	COLOR = vec4(col, clamp(edge * strength + glow * 0.18 + line, 0.0, 0.9));
}
