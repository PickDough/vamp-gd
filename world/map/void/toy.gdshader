shader_type spatial;
render_mode depth_prepass_alpha;

// A floating toy in the void: matte cartoon color with optional polka dots, bobbing and spinning slowly on its own
// phase (taken from its position), and fading out near the camera so it never hides the play area.

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 dot_color : source_color = vec3(1.0);
uniform float dots : hint_range(0.0, 1.0) = 0.0;
uniform float dot_scale = 6.0;
uniform float bob_height = 0.08;
uniform float spin_speed = 0.15;
uniform float fade_near = 14.0;
uniform float fade_far = 34.0;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.18;

#include "res://assets/shaders/toon_light.gdshaderinc"

void vertex() {
	float phase = dot(NODE_POSITION_WORLD, vec3(0.13, 0.07, 0.11));
	float angle = TIME * spin_speed + phase;
	mat3 spin = mat3(vec3(cos(angle), 0.0, -sin(angle)), vec3(0.0, 1.0, 0.0), vec3(sin(angle), 0.0, cos(angle)));
	VERTEX = spin * VERTEX + vec3(0.0, sin(TIME * 0.6 + phase * 3.0) * bob_height, 0.0);
	NORMAL = spin * NORMAL;
}

void fragment() {
	vec2 grid = UV * dot_scale * vec2(2.0, 1.0);
	float in_dot = step(length(fract(grid) - 0.5), 0.28) * dots;
	ALBEDO = mix(albedo, dot_color, in_dot);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = mix(min_alpha, 1.0, smoothstep(fade_near, fade_far, length(VERTEX)));
}
