shader_type canvas_item;
// The boss-slain screen's full-screen pass: removes color, darkens and flashes the picture behind it.
// All three values are driven by victory_screen.gd (0 = off).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float desaturate = 0.0;
uniform float dim = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate);
	c = mix(c, vec3(0.0), dim);
	c = mix(c, vec3(1.0), flash);
	COLOR = vec4(c, 1.0);
}
