shader_type spatial;

// Checkerboard in world space with faint marble veins. Walls take the pattern from the plane they face, so the
// letter reads as one checkered block.

uniform vec3 color_a : source_color = vec3(0.9, 0.86, 0.82);
uniform vec3 color_b : source_color = vec3(0.6, 0.36, 0.37);
uniform float tile_size = 3.0;
uniform float marble : hint_range(0.0, 1.0) = 0.12;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_position;
varying vec3 world_normal;

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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 facing = abs(world_normal);
	vec2 plane = facing.y > 0.5 ? world_position.xz : (facing.x > facing.z ? world_position.zy : world_position.xy);
	vec2 tile = floor(plane / tile_size);
	float veins = value_noise(plane * 0.5) * 0.6 + value_noise(plane * 1.7) * 0.4;
	ALBEDO = mix(color_a, color_b, mod(tile.x + tile.y, 2.0)) * (1.0 - marble + marble * smoothstep(0.2, 0.8, veins));
	ROUGHNESS = roughness_value;
}
