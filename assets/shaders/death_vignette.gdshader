shader_type canvas_item;
// The blood-red edge vignette of the death screen: a wobbling edge and a slow pulse.
// `strength` is driven by death_screen.gd (0 = off); the rest is tuned on the material in death_screen.tscn.
uniform vec4 vignette_color : source_color = vec4(0.5, 0.0, 0.02, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.3;
uniform float outer = 0.95;
uniform float pulse = 0.08;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float angle = atan(p.y, p.x);
	float d = length(p) / 1.4142;
	d += 0.05 * sin(angle * 5.0 + TIME * 0.5) + 0.03 * sin(angle * 11.0 - TIME * 0.8);
	float v = smoothstep(inner, outer, d);
	float beat = 1.0 + pulse * sin(TIME * 3.0);
	COLOR = vec4(vignette_color.rgb, clamp(v * strength * beat, 0.0, 1.0));
}
