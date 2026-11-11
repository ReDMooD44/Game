shader_type canvas_item;
render_mode blend_mix, unshaded;

// One fullscreen pass: the speed vignette and the radial speed lines.
//
// The speed lines are the supplied shader, ported to Godot 4: `hint_color`
// became `source_color`, and the noise is generated at load instead of being
// an imported image. The maths is unchanged - the angle around the centre
// picks a point on a circle in the noise, so each ray keeps its own width all
// the way out.

uniform vec2 center = vec2(0.5, 0.5);
uniform sampler2D noise : repeat_enable;
uniform float sample_radius : hint_range(0.0, 1.0) = 0.5;
uniform vec4 line_color : source_color = vec4(1.0);
uniform float center_radius : hint_range(0.0, 1.0) = 0.5;
uniform float lines : hint_range(0.0, 1.0) = 0.0;
uniform float spin = 0.0;
uniform float aspect = 1.78;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.25, 0.08, 0.04, 1.0);

const float pi = 3.14159265359;

void fragment() {
	vec2 d = UV - center;
	float r = length(d) * 1.42;
	float v = smoothstep(0.35, 1.0, r) * intensity;
	vec4 col = vec4(tint.rgb, v * 0.85);

	if (lines > 0.001) {
		// Corrected for the viewport's aspect so the rays stay straight, and
		// turned slowly so the pattern never reads as a static decal.
		vec2 dist = d * vec2(aspect, 1.0);
		float angle = atan(dist.y / dist.x) + spin;
		vec2 samp = vec2(sample_radius * cos(angle), sample_radius * sin(angle));
		float noise_value = texture(noise, samp).r;
		vec4 line = mix(line_color, vec4(0.0), noise_value);
		line = mix(line, vec4(0.0), clamp(1.0 - length(dist) - center_radius, 0.0, 1.0));
		float a = clamp(line.a * lines, 0.0, 1.0);
		col.rgb = mix(col.rgb, line.rgb, a);
		col.a = clamp(col.a + a, 0.0, 1.0);
	}
	COLOR = col;
}
