shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A drifting layer of fog wisps for the void under the map: layered value noise scrolling slowly, fading out toward
// the plane's edge. Stack two at different heights for depth.

uniform vec3 fog_color : source_color = vec3(0.32, 0.18, 0.3);
uniform vec3 glow_color : source_color = vec3(0.85, 0.45, 0.55);
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
uniform float scale = 24.0;
uniform float drift_speed = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	return mix(
			mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
			mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x),
			blend.y);
}

void fragment() {
	vec2 p = UV * scale;
	float drift = TIME * drift_speed;
	float wisps = value_noise(p + vec2(drift, drift * 0.6)) * 0.55
			+ value_noise(p * 2.3 - vec2(drift * 1.4, 0.0)) * 0.3
			+ value_noise(p * 5.1 + drift) * 0.15;
	float edge = 1.0 - smoothstep(0.35, 0.5, length(UV - 0.5));
	ALBEDO = mix(fog_color, glow_color, smoothstep(0.5, 0.9, wisps));
	ALPHA = smoothstep(0.25, 0.75, wisps) * opacity * edge;
}
