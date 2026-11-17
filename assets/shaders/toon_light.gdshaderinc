// Matte cartoon lighting: a soft two-tone step instead of a gradient, no specular. Ambient light fills the shaded
// side. Include it after the shader's uniforms; it defines light().

uniform float shade_softness : hint_range(0.0, 1.0) = 0.08;

void light() {
	float facing = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += smoothstep(0.0, shade_softness, facing) * ATTENUATION * LIGHT_COLOR / PI;
}
