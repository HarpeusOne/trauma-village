shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

// PS2-style surface: vertex snapping (jitter), ordered dithering and distance fog.
// One shader shared by all world primitives. Tint is a per-material uniform.

uniform vec4 tint : source_color = vec4(0.62, 0.62, 0.68, 1.0);
uniform float jitter_strength : hint_range(0.0, 2.0) = 1.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
uniform float color_levels : hint_range(4.0, 64.0) = 24.0;
uniform vec4 fog_color : source_color = vec4(0.025, 0.03, 0.04, 1.0);
uniform float fog_start = 9.0;
uniform float fog_end = 42.0;
uniform vec2 virtual_resolution = vec2(640.0, 480.0);

float bayer2(vec2 p) {
	p = floor(p);
	return fract(p.x * 0.5 + p.y * p.y * 0.75);
}

float bayer4(vec2 p) {
	return bayer2(p * 0.5) * 0.25 + bayer2(p);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float safe_w = max(abs(clip.w), 0.0001);
	vec2 ndc = clip.xy / safe_w;
	vec2 grid = virtual_resolution * 0.5;
	vec2 snapped = floor(ndc * grid) / grid;
	clip.xy = mix(ndc, snapped, jitter_strength) * safe_w;
	POSITION = clip;
}

void fragment() {
	vec3 col = tint.rgb;

	float depth = -VERTEX.z;
	float fog = clamp((depth - fog_start) / max(fog_end - fog_start, 0.001), 0.0, 1.0);
	col = mix(col, fog_color.rgb, fog);

	float d = bayer4(FRAGCOORD.xy);
	vec3 quantized = floor(col * color_levels + d * dither_strength) / color_levels;
	col = mix(col, quantized, dither_strength);

	ALBEDO = col;
	ALPHA = 1.0;
}
