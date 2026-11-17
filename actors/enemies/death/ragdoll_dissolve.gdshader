shader_type spatial;

// Disintegration with a glowing ember front, for ragdolls. Animate `dissolve` from 0 (untouched) to 1 (completely
// gone). The hot rim follows the burn line and cools to ember toward the untouched surface. A 3D port of a sprite
// dissolve: instead of sprite UVs it uses the model's own coordinates normalized to 0..1 over `bounds_position` and
// `bounds_size` (the mesh AABB), so it looks the same on any model. Burnt surface is cut out with alpha scissor, so
// shadows burn away too and nothing needs sorting. The surface keeps the matte cartoon shading in `albedo`.

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 bounds_position = vec3(-0.5);
uniform vec3 bounds_size = vec3(1.0);

group_uniforms Dissolve;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(2.0, 64.0) = 8.0;   // size of the burnt patches
uniform float warp : hint_range(0.0, 1.0) = 0.6;             // how organic, curly the edges are
// 0 = the holes open everywhere at once, 1 = the burn sweeps across the model
uniform float sweep : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_angle : hint_range(-3.1416, 3.1416) = 1.5708;   // default: from top to bottom
group_uniforms Edge;
uniform float edge_width : hint_range(0.0, 0.25) = 0.18;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 edge_hot : source_color = vec4(1.0, 0.95, 0.6, 1.0);
uniform float edge_glow : hint_range(0.0, 8.0) = 3.0;
group_uniforms;

#include "res://assets/shaders/toon_light.gdshaderinc"

varying vec3 local_position;

float hash(vec2 p) {
	p = fract(p * 0.3183099 + vec2(0.1, 0.113));
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);   // quintic: no grid creases
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// rotated octaves hide the square noise grid
float fbm(vec2 p) {
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = r * p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v / 0.9375;
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// the model's coordinates over its bounds, flipped so v grows downward like a sprite's UV; depth mixes into the
	// noise so the sides of the model don't show stretched streaks
	vec3 normalized = (local_position - bounds_position) / max(bounds_size, vec3(0.0001));
	vec2 fuv = vec2(normalized.x, 1.0 - normalized.y);
	vec2 p = (fuv + normalized.zx * 0.37) * noise_scale * 0.35;
	// domain warp: the burnt patches get curly, organic outlines
	vec2 w = vec2(fbm(p * 0.7 + 3.1), fbm(p * 0.7 + 8.4)) - 0.5;
	float n = fbm(p + w * warp * 2.5);
	// fbm values bunch up around 0.5: spread them evenly over 0..1 (an approximate normal CDF) so the burn
	// progresses steadily from start to end
	float z = (n - 0.5) / 0.11;
	n = 0.5 + 0.5 * tanh(z * 0.85);
	vec2 dir = vec2(cos(sweep_angle), sin(sweep_angle));
	float g = dot(fuv - 0.5, dir) / (abs(dir.x) + abs(dir.y)) + 0.5;
	n = mix(n, g * 0.75 + n * 0.25, sweep);
	// the cut: 0 keeps every pixel, 1 removes every pixel, whatever the noise
	float thr = mix(-edge_width - 0.02, 1.04, dissolve);
	float aa = min(fwidth(n), 0.02) + 0.001;
	float kept = smoothstep(thr - aa, thr + aa, n);
	// ember hugs the front: hottest at the burn line, cooling outward
	float e = clamp((n - thr) / max(edge_width, 0.0001), 0.0, 1.0);
	vec3 ember = mix(edge_hot.rgb, edge_color.rgb, e);
	float burning = (1.0 - e) * kept * step(0.0001, edge_width);
	ALBEDO = mix(albedo, ember, burning);
	EMISSION = ember * burning * edge_glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = kept;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
