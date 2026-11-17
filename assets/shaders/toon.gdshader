shader_type spatial;

// Plain matte cartoon surface (player, ragdolls).

uniform vec3 albedo : source_color = vec3(1.0);

#include "res://assets/shaders/toon_light.gdshaderinc"

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
