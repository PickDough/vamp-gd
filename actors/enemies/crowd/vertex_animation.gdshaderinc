// Plays a VertexAnimation (see vertex_animation.gd): picks the frame from the time and the instance's phase, and
// blends two baked frames of positions and normals.

uniform sampler2D positions : filter_nearest;
uniform sampler2D normals : filter_nearest;
uniform float frame_count = 1.0;
uniform float frames_per_second = 30.0;

void play_vertex_animation(int vertex_id, float phase, float time, inout vec3 vertex, inout vec3 normal) {
	float frame = mod(time * frames_per_second + phase * frame_count, frame_count);
	int current = int(frame);
	int next = (current + 1) % int(frame_count);
	float blend = fract(frame);
	vertex = mix(
			texelFetch(positions, ivec2(vertex_id, current), 0).xyz,
			texelFetch(positions, ivec2(vertex_id, next), 0).xyz,
			blend);
	normal = normalize(mix(
			texelFetch(normals, ivec2(vertex_id, current), 0).xyz,
			texelFetch(normals, ivec2(vertex_id, next), 0).xyz,
			blend));
}
