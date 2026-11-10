// astronaut_depth.gdshader: paints the 3D pilot by how far each pixel is from the camera, for the
// pixel shader to find where one part passes in front of another and draw a line there.
// From DESIGN.md, "Player" (the 3D pilot).
shader_type spatial;
render_mode unshaded, cull_back;

// The distances from the camera that map to black and to white, in meters.
uniform float nearest = 4.5;
uniform float farthest = 7.5;

void fragment() {
	// The Compatibility renderer stores this as written, with no turn to sRGB on the way out.
	ALBEDO = vec3(clamp((-VERTEX.z - nearest) / (farthest - nearest), 0.0, 1.0));
}
