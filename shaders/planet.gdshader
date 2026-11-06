// planet.gdshader: draws a planet or moon on the pixel grid: land and sea in about six colors,
// lit from the real star, with clouds, craters, and its atmosphere.
// From DESIGN.md, "Art direction" (planets are shaders and code, and each uses about six
// colors) and "Camera, zoom, and landing" (zooming swaps detail on a fixed pixel grid, so its
// rim becomes the horizon as you get close).
//
// Fills the whole screen and stays transparent outside the disc and its air, so the disc can
// be far bigger than the screen when you're close to the ground.
//
// The camera looks down on the spinning pole, so the middle of the disc is the pole and the rim
// is the equator, which is where the ship flies and lands.
shader_type canvas_item;

// Set by body_view.gd every tick.
uniform vec2 center_px;
uniform float radius_px = 100.0;
uniform float units_per_px = 1.0;
// How far the ground and the clouds have turned.
uniform float spin_cos = 1.0;
uniform float spin_sin = 0.0;
uniform float cloud_cos = 1.0;
uniform float cloud_sin = 0.0;
// The way to the star from here, as a unit direction on screen.
uniform vec2 light_way = vec2(1.0, 0.0);
// How high the air reaches on screen, in pixels. Zero means airless.
uniform float air_px = 0.0;

// Set by body_view.gd from the body's data.
uniform vec4 surface_colors[6] : source_color;
uniform int terrain_seed = 1;
// Size of the largest land features, in world units.
uniform float largest_feature = 90000.0;
// How much of the height range is under water, from 0 to 1. Zero means no sea.
uniform float sea_level = 0.0;
// How far out from the pole the ice reaches, as a share of the radius. Zero means none.
uniform float ice_cap = 0.0;
// How much of the sky has cloud, from 0 to 1. Zero means none.
uniform float cloud_amount = 0.0;
uniform vec3 cloud_color : source_color = vec3(1.0);
// How much of the ground has a crater at each of two sizes, from 0 to 1. Zero means none.
uniform float crater_amount = 0.0;
uniform vec3 air_color : source_color = vec3(1.0);
uniform vec3 air_sunset_color : source_color = vec3(1.0, 0.6, 0.4);
uniform vec3 star_color : source_color = vec3(1.0);

// Up close the big shapes are too large to show motion, so patches of the next color up
// speckle the ground. This is their smallest size, in world units, and how wide they
// stay on screen, in pixels, as you zoom out. Past the last zoom they switch off.
uniform float speckle_size = 22.0;
uniform float speckle_screen_size = 20.0;
uniform float speckle_last_zoom_out = 40.0;
// How much of the ground the speckles cover, from 0 to 1.
uniform float speckle_amount = 0.3;
// How many flat steps the daylight falls through, how far above the disc the star sits, and
// what color a surface turns on the night side, as a share of its own.
uniform float light_steps = 5.0;
uniform float light_lift = 0.55;
uniform vec3 night_share = vec3(0.3, 0.34, 0.48);
// How many flat steps the air fades through, and how strong it is at the ground.
uniform float air_steps = 6.0;
uniform float air_strength = 0.8;
// Closer than this many world units per pixel, clouds have faded away.
uniform float cloud_nearest = 24.0;

varying vec2 pixel;


uint hash(uint value) {
	uint state = value * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}


float corner(ivec2 cell, uint seed) {
	return float(hash(uint(cell.x) * 73856093u ^ uint(cell.y) * 19349663u ^ seed * 83492791u) & 65535u) / 65535.0;
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


// A repeating 4 x 4 pattern from 0 to 1, for breaking up the edges between flat colors.
float dither(vec2 whole) {
	ivec2 at = ivec2(whole);
	int x = at.x & 3;
	int y = at.y & 3;
	int crossed = x ^ y;
	int value = ((crossed & 1) << 3) | ((y & 1) << 2) | (crossed & 2) | ((y & 2) >> 1);
	return (float(value) + 0.5) / 16.0;
}


// Layers of noise, big to small, after pushing the coordinates around with a slower noise so
// coasts wander instead of looking like round blobs. Layers too small to see are skipped.
float terrain_height(vec2 world) {
	uint seed = uint(terrain_seed);
	vec2 scaled = world / (largest_feature * 1.3);
	vec2 push = vec2(value_noise(scaled, seed + 40u), value_noise(scaled + vec2(5.2, 1.3), seed + 41u)) - vec2(0.5);
	vec2 warped = world + push * largest_feature * 0.9;
	float height = 0.0;
	float weight = 0.5;
	float total = 0.0;
	float feature = largest_feature;
	for (int layer = 0; layer < 6; layer++) {
		if (feature < units_per_px * 3.0) {
			break;
		}
		height += value_noise(warped / feature, seed + uint(layer)) * weight;
		total += weight;
		weight *= 0.52;
		feature *= 0.45;
	}
	return total > 0.0 ? height / total : 0.5;
}


// What craters of one size do to the height here: dark floors, bright rims, and an inside wall
// that catches the star on the far side.
float crater_change(vec2 world, float size, uint seed, vec2 light) {
	vec2 place = world / size;
	ivec2 base = ivec2(floor(place));
	float change = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 cell = base + ivec2(dx, dy);
			if (corner(cell, seed) > crater_amount) {
				continue;
			}
			vec2 middle = vec2(cell) + vec2(corner(cell, seed + 1u), corner(cell, seed + 2u));
			float crater_radius = 0.2 + 0.32 * corner(cell, seed + 3u);
			vec2 across = (place - middle) / crater_radius;
			float distance_out = length(across);
			if (distance_out < 0.86) {
				change += -0.09 - 0.13 * dot(across, light);
			} else if (distance_out < 1.12) {
				change += 0.07;
			}
		}
	}
	return change;
}


// Which of the six colors this height is, under the sea or on land, from 0 up to just under 6.
float height_to_band(float height) {
	float level = clamp((height - 0.25) * 2.0, 0.0, 0.999);
	if (sea_level <= 0.0) {
		return level * 6.0;
	}
	if (level < sea_level) {
		return level / sea_level * 3.0;
	}
	return 3.0 + (level - sea_level) / (1.0 - sea_level) * 3.0;
}


// Cloud cover here, in bands that twist around the pole. Layers too small to see are skipped,
// and most_layers keeps the shadow check cheap.
float cloud_cover(vec2 offset, float share_out, int most_layers) {
	float turn = share_out * 1.4;
	float c = cos(turn);
	float s = sin(turn);
	vec2 twisted = vec2(c * offset.x + s * offset.y, c * offset.y - s * offset.x);
	vec2 spun = vec2(cloud_cos * twisted.x + cloud_sin * twisted.y, cloud_cos * twisted.y - cloud_sin * twisted.x);
	float largest = largest_feature * 0.3;
	vec2 place = spun * units_per_px / largest;
	uint seed = uint(terrain_seed) + 60u;
	vec2 push = vec2(value_noise(place * 0.6, seed + 7u), value_noise(place * 0.6 + vec2(3.1, 8.7), seed + 8u)) - vec2(0.5);
	place += push * 1.6;
	float cover = 0.0;
	float weight = 0.5;
	float total = 0.0;
	float size = 1.0;
	for (int layer = 0; layer < most_layers; layer++) {
		if (largest / size < units_per_px * 2.5) {
			break;
		}
		cover += value_noise(place * size, seed + uint(layer)) * weight;
		total += weight;
		weight *= 0.55;
		size *= 2.2;
	}
	return total > 0.0 ? cover / total : 0.0;
}


void vertex() {
	pixel = VERTEX;
}


void fragment() {
	vec2 whole = floor(pixel);
	vec2 offset = whole + vec2(0.5) - center_px;
	float distance_px = length(offset);
	float pattern = dither(whole);
	vec2 outward = distance_px > 0.0 ? offset / distance_px : vec2(0.0, -1.0);
	float facing = dot(outward, light_way);
	float air_day = clamp(facing * 1.4 + 0.45, 0.0, 1.0) * 4.0;
	air_day = clamp(floor(air_day + pattern * clamp(fwidth(air_day) * 1.5, 0.0, 1.0)), 0.0, 4.0) / 4.0;

	if (distance_px > radius_px) {
		float above_ground = distance_px - radius_px;
		if (above_ground < air_px) {
			// The air glows on the day side and turns warm around sunrise and sunset.
			float reach = 1.0 - above_ground / air_px;
			float checker = mod(whole.x + whole.y, 2.0) / air_steps;
			float level = floor((reach * reach + checker * 0.5) * air_steps) / air_steps;
			float sunset = clamp(1.0 - abs(facing + 0.05) * 3.2, 0.0, 0.85);
			COLOR = vec4(mix(air_color, air_sunset_color, sunset), level * air_strength * mix(0.08, 1.0, air_day));
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		// Turn the screen offset back by the spin to find which ground is under this pixel.
		vec2 ground = vec2(spin_cos * offset.x + spin_sin * offset.y, spin_cos * offset.y - spin_sin * offset.x) * units_per_px;
		vec2 light_on_ground = vec2(spin_cos * light_way.x + spin_sin * light_way.y, spin_cos * light_way.y - spin_sin * light_way.x);
		float height = terrain_height(ground);
		if (crater_amount > 0.0) {
			uint seed = uint(terrain_seed) + 80u;
			if (largest_feature * 0.32 > units_per_px * 4.0) {
				height += crater_change(ground, largest_feature * 0.32, seed, light_on_ground);
			}
			if (largest_feature * 0.08 > units_per_px * 4.0) {
				height += crater_change(ground, largest_feature * 0.08, seed + 8u, light_on_ground);
			}
		}

		// The edges between colors break up into a pattern of pixels, a pixel or two wide at
		// any zoom.
		float exact_band = height_to_band(height);
		float band = exact_band + (pattern - 0.5) * clamp(fwidth(exact_band) * 1.5, 0.0, 0.6);
		int index = int(clamp(band, 0.0, 5.999));
		if (units_per_px < speckle_last_zoom_out) {
			float size = max(speckle_size, units_per_px * speckle_screen_size);
			float speckle = value_noise(ground / size, uint(terrain_seed) + 16u);
			if (speckle < speckle_amount) {
				// The last color of the sea and of the land step back, so sea stays sea.
				index = (index == 2 || index == 5) ? index - 1 : index + 1;
			}
		}
		float share_out = distance_px / radius_px;
		if (ice_cap > 0.0 && share_out + (height - 0.5) * 0.35 + (pattern - 0.5) * 0.015 < ice_cap) {
			index = 5;
		}
		vec3 color = surface_colors[index].rgb;

		// The disc is a ball, so the star lights it from one side, in flat steps.
		vec2 on_ball = offset / radius_px;
		float rise = sqrt(max(1.0 - dot(on_ball, on_ball), 0.0));
		float sun = dot(vec3(on_ball, rise), normalize(vec3(light_way, light_lift)));
		float exact_light = clamp(sun * 1.25 + 0.2, 0.0, 1.0) * light_steps;
		float daylight = clamp(floor(exact_light + pattern * clamp(fwidth(exact_light) * 1.5, 0.0, 0.9)), 0.0, light_steps) / light_steps;

		// Clouds fade out as you get close, and throw a shadow on the side away from the star.
		if (cloud_amount > 0.0 && units_per_px > cloud_nearest) {
			float fading = clamp((units_per_px - cloud_nearest) / (cloud_nearest * 3.0), 0.0, 1.0);
			float needed = 1.0 - cloud_amount * fading;
			float cover = cloud_cover(offset, share_out, 5);
			if (cover + (pattern - 0.5) * clamp(fwidth(cover) * 1.5, 0.0, 0.05) > needed) {
				color = mix(color, cloud_color, cover > needed + 0.03 ? 0.92 : 0.55);
			} else {
				vec2 shadow_offset = offset - light_way * radius_px * 0.012;
				if (cloud_cover(shadow_offset, share_out, 2) > needed) {
					color *= 0.8;
				}
			}
		}

		vec3 lit_color = color * mix(vec3(1.0), star_color, 0.12);
		color = mix(color * night_share, lit_color, daylight);

		// Looking through more air near the rim, the ground takes on its color.
		if (air_px > 0.0) {
			// Only from far out: on the ground, you're not looking through much of it.
			float from_far = clamp(units_per_px / 256.0, 0.0, 1.0);
			float haze = 1.0 - (radius_px - distance_px) / (air_px * 0.6);
			if (haze > 0.0 && from_far > 0.0) {
				float exact_haze = haze * haze * 4.0;
				float steps = floor(exact_haze + (pattern - 0.5) * clamp(fwidth(exact_haze) * 1.5, 0.0, 1.0)) / 4.0;
				color = mix(color, air_color, clamp(steps, 0.0, 1.0) * 0.6 * air_day * from_far);
			}
		}
		COLOR = vec4(color, 1.0);
	}
}
