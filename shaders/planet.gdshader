// planet.gdshader: draws a planet as a disc of up to six colors on the pixel grid.
// From DESIGN.md, "Art direction" (planets are shaders and code) and "Camera, zoom,
// and landing" (zooming swaps detail on a fixed pixel grid, so its rim becomes the
// horizon as you get close).
//
// Fills the whole screen and stays transparent outside the disc, so the disc can be
// far bigger than the screen when you're close to the ground.
shader_type canvas_item;

// Set by planet_view.gd every tick.
uniform vec2 center_px;
uniform float radius_px = 100.0;
uniform float units_per_px = 1.0;
// Set by planet_view.gd from the planet's data.
uniform vec4 surface_colors[6] : source_color;
uniform int terrain_seed = 1;
// Size of the largest land features, in world units.
uniform float largest_feature = 90000.0;

varying vec2 pixel;


uint hash(uint value) {
	uint state = value * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}


float corner(ivec2 cell, uint seed) {
	return float(hash(seed ^ hash(uint(cell.x) ^ hash(uint(cell.y)))) & 65535u) / 65535.0;
}


float value_noise(vec2 position, uint seed) {
	vec2 whole = floor(position);
	vec2 part = position - whole;
	vec2 blend = part * part * (3.0 - 2.0 * part);
	ivec2 cell = ivec2(whole);
	float bottom = mix(corner(cell, seed), corner(cell + ivec2(1, 0), seed), blend.x);
	float top = mix(corner(cell + ivec2(0, 1), seed), corner(cell + ivec2(1, 1), seed), blend.x);
	return mix(bottom, top, blend.y);
}


// Layers of noise, big to small. Layers too small to see at this zoom are skipped.
float terrain_height(vec2 world) {
	float height = 0.0;
	float weight = 0.5;
	float total = 0.0;
	float feature = largest_feature;
	for (int layer = 0; layer < 5; layer++) {
		if (feature < units_per_px * 3.0) {
			break;
		}
		height += value_noise(world / feature, uint(terrain_seed) + uint(layer)) * weight;
		total += weight;
		weight *= 0.5;
		feature *= 0.35;
	}
	return total > 0.0 ? height / total : 0.5;
}


void vertex() {
	pixel = VERTEX;
}


void fragment() {
	vec2 offset = floor(pixel) + vec2(0.5) - center_px;
	if (dot(offset, offset) > radius_px * radius_px) {
		COLOR = vec4(0.0);
	} else {
		float height = terrain_height(offset * units_per_px);
		// Noise bunches up around the middle, so stretch it to reach all six colors.
		int index = int(clamp((height - 0.25) * 2.0, 0.0, 0.999) * 6.0);
		COLOR = vec4(surface_colors[index].rgb, 1.0);
	}
}
