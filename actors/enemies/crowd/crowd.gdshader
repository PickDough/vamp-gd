shader_type spatial;

// One crowd enemy: plays the baked walk, takes its body color from INSTANCE_CUSTOM.yzw (picked per enemy from the
// enemy scene's colors) and flashes white as the instance color moves away from white (hit flashes). Matte cartoon
// lighting; crowd_outline.gdshader draws the outline as the next pass.

#include "res://actors/enemies/crowd/vertex_animation.gdshaderinc"
#include "res://assets/shaders/toon_light.gdshaderinc"

varying vec3 body_color;
varying float flash;

void vertex() {
	play_vertex_animation(VERTEX_ID, INSTANCE_CUSTOM.x, TIME, VERTEX, NORMAL);
	body_color = INSTANCE_CUSTOM.yzw;
	flash = 1.0 - COLOR.g;
}

void fragment() {
	ALBEDO = mix(body_color, vec3(1.0), flash);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = vec3(flash * 0.6);
}
