shader_type spatial;
render_mode unshaded, cull_front;

// Cartoon outline for crowd enemies: the same baked walk, pushed out along the normals and drawn back faces only, so
// a dark rim shows around each enemy against the floor.

#include "res://actors/enemies/crowd/vertex_animation.gdshaderinc"

uniform vec3 outline_color : source_color = vec3(0.16, 0.08, 0.16);
uniform float outline_width = 0.035;

void vertex() {
	play_vertex_animation(VERTEX_ID, INSTANCE_CUSTOM.x, TIME, VERTEX, NORMAL);
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color;
}
