shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float border_width : hint_range(0.001, 0.1) = 0.015;
uniform float glow_width : hint_range(0.01, 0.5) = 0.12;
uniform float speed : hint_range(0.0, 2.0) = 0.20;
uniform float intensity : hint_range(0.0, 5.0) = 1.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	float edge = min(
		min(UV.x, 1.0 - UV.x),
		min(UV.y, 1.0 - UV.y)
	);

	float border = 1.0 - smoothstep(border_width, border_width * 2.0, edge);
	float perimeter;

	if (UV.x < 0.5) {
		if (UV.y < 0.5) {
			perimeter = UV.x + UV.y;
		} else {
			perimeter = UV.x + (1.0 - UV.y);
		}
	} else {
		if (UV.y < 0.5) {
			perimeter = (1.0 - UV.x) + UV.y;
		} else {
			perimeter = (1.0 - UV.x) + (1.0 - UV.y);
		}
	}

	float position = fract(perimeter * 2.0 - TIME * speed);
	float highlight = smoothstep(0.0, glow_width, position) * smoothstep(glow_width * 2.0, glow_width, position);
	vec3 glow = glow_color.rgb * highlight * intensity;

	COLOR = vec4(tex.rgb + glow * border, tex.a);
}
