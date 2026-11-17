shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// Thick cartoon outline as a next pass, back faces only, in a flat color. Pushing vertices along their normals
// splits the hull at hard edges, so instead each vertex moves outward from the part's center along each axis by up
// to outline_width (in the mesh's own units): faces of box-like parts offset evenly and corners stay closed. The
// owner sets the per-mesh `outline_center` and `outline_extent` (its AABB center and half size). The hull is pushed
// depth_push meters away from the camera, so neighbouring parts' outlines draw behind the body instead of over it.

uniform vec3 outline_color : source_color = vec3(0.55, 0.85, 1.0);
uniform float outline_width = 0.09;
uniform float depth_push = 0.25;
instance uniform vec3 outline_center = vec3(0.0);
instance uniform vec3 outline_extent = vec3(1.0);

void vertex() {
	vec3 from_center = VERTEX - outline_center;
	VERTEX += clamp(from_center / max(outline_extent * 0.5, vec3(0.001)), -1.0, 1.0) * outline_width;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z -= depth_push;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = outline_color;
}
