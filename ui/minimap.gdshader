shader_type canvas_item;
// The minimap disc: the baked base picture turned with the camera and centred on the hero, cut to a circle, darker
// toward the rim (design/mockups/hud.html .disc::after). Colours come in as uniforms from the theme.

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform vec2 centre = vec2(0.5);  // the hero, in the picture's UV
uniform float span = 0.3;  // the disc's diameter in UV
uniform float turn = 0.0;  // radians: the camera's heading, so "ahead" is up
uniform vec4 ground : source_color;  // outside the picture
uniform vec4 rim : source_color;  // the vignette toward the edge

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float c = cos(turn), s = sin(turn);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	vec2 uv = centre + q * span;
	bool inside = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
	vec4 col = inside ? texture(map, uv) : ground;
	col.rgb = mix(col.rgb, rim.rgb, rim.a * smoothstep(0.55, 1.0, r));
	col.a = 1.0 - smoothstep(0.98, 1.0, r);
	COLOR = col;
}
