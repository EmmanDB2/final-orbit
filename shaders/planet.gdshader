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
// How many screen pixels wide each of the planet's own pixels is, from far out.
uniform float block_px = 1.0;
// How big the smallest pixel is here, in world units, which sets how fine the detail can be.
uniform float detail_units = 1.0;
// Close to the surface, pixels are laid out along the rim instead, in columns around the planet
// and rows up from it, on a grid fixed to the ground. These say where the middle of the view is
// on that grid. They're worked out in 64-bit, so the grid stays steady anywhere on the planet.
uniform bool on_surface_grid = false;
uniform vec2 screen_middle = vec2(0.0);
uniform vec2 view_from_body = vec2(0.0, -1.0);
uniform float view_height_px = 0.0;
uniform float view_column_share = 0.0;
uniform int view_column = 0;
uniform float cell_px = 1.0;
uniform float cell_units = 2.0;
// The stretch of the rim in view: its height in world units and its map color, one entry per
// column, with the middle of the view at the middle. How much of its height to show, too.
uniform sampler2D rim_strip : filter_nearest, repeat_disable;
uniform float rim_fade = 0.0;
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
// The sky just above the ground, which fades up through air_color into space.
uniform vec3 air_horizon_color : source_color = vec3(1.0);
uniform vec3 star_color : source_color = vec3(1.0);

// Each zoom shows finer detail than the last: patches of the next color, in tiers from this
// size down, each a quarter of the last, appearing once their pixels can show them. This is also
// what lets you see drift up close.
uniform float detail_largest = 4800.0;
// What's under the ground, from the top down: dirt, rock, deep rock, and the dark core. The very
// top is whatever the surface map shows at that spot on the rim.
uniform vec4 strata_colors[4] : source_color;
// The cross-section grows down from the skyline as you zoom in, starting at the first zoom and
// filling the screen by the second, in world units per pixel. The map stays below it.
uniform float section_starts = 300.0;
uniform float section_full = 32.0;
uniform float section_deepest_px = 1200.0;
// How many flat steps the daylight falls through, how far above the disc the star sits, and
// what color a surface turns on the night side, as a share of its own.
uniform float light_steps = 2.0;
uniform float light_lift = 0.55;
uniform vec3 night_share = vec3(0.3, 0.34, 0.48);
// How many flat bands the sky fades through close up, how strong it is at the ground, and how
// much of each band's edge breaks up into a pattern of pixels.
uniform float air_steps = 8.0;
uniform float air_strength = 0.96;
uniform float sky_dither = 0.4;
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
		if (feature < detail_units * 7.0) {
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


// The side view of the ground: which color belongs this far below the skyline, at this far
// around the rim. Layers wander a little, and stay at least a few pixels thick when far out.
vec3 section_color(float along, float depth_below, float band, float reach_units) {
	uint seed = uint(terrain_seed) + 120u;
	float wander = value_noise(vec2(along / 90.0, 0.0), seed) - 0.5;
	float wander_slow = value_noise(vec2(along / 700.0, 3.0), seed + 1u) - 0.5;
	int top = int(clamp(band, 0.0, 5.999));
	vec3 crust = surface_colors[top].rgb;
	float depth = depth_below;

	// Sea is water down to a bed of the lowest land color.
	if (sea_level > 0.0 && band < 3.0) {
		float water = (3.0 - band) * max(40.0, cell_units * 3.0);
		if (depth < water) {
			return crust;
		}
		depth -= water;
		crust = surface_colors[3].rgb;
	}

	float crust_end = max(10.0, cell_units * 2.0);
	// While it only reaches part way down, its layers share that reach, so the dark core doesn't
	// show as a ring around the planet. Once it fills the screen, they settle at their true depths.
	float dirt_end = max(max(110.0, cell_units * 5.0), reach_units * 0.14);
	float rock_end = max(max(900.0, cell_units * 11.0), reach_units * 0.5);
	float deep_end = max(max(7000.0, cell_units * 24.0), reach_units * 1.1);
	if (depth < crust_end + wander * crust_end) {
		return crust;
	}
	vec3 color;
	vec3 other;
	if (depth < dirt_end + wander * dirt_end * 0.5) {
		color = strata_colors[0].rgb;
		other = strata_colors[1].rgb;
	} else if (depth < rock_end + wander_slow * rock_end * 0.5) {
		// Rock lies in bands that follow the ground.
		bool banded = mod(floor((depth + wander_slow * 200.0) / max(90.0, cell_units * 3.0)), 3.0) < 1.0;
		color = banded ? mix(strata_colors[1].rgb, strata_colors[2].rgb, 0.5) : strata_colors[1].rgb;
		other = strata_colors[2].rgb;
	} else if (depth < deep_end + wander_slow * deep_end * 0.3) {
		color = strata_colors[2].rgb;
		other = strata_colors[3].rgb;
	} else {
		return strata_colors[3].rgb;
	}

	// Stones in it, big ones first, and small ones only once their pixels can show.
	float stone = value_noise(vec2(along, depth) / max(44.0, cell_units * 5.0), seed + 2u);
	if (stone > 0.78) {
		return other;
	}
	if (cell_units * 4.0 < 26.0 && value_noise(vec2(along, depth) / 13.0, seed + 3u) > 0.8) {
		return mix(color, other, 0.5);
	}
	return color;
}


// Moves a color up or down one wherever this zoom's detail tiers say so. Sea stays sea, and
// land stays land.
int with_detail(int index, vec2 ground) {
	uint seed = uint(terrain_seed) + 20u;
	float feature = detail_largest;
	int shift = 0;
	for (int tier = 0; tier < 5; tier++) {
		if (feature > detail_units * 3.0) {
			float value = value_noise(ground / feature, seed + uint(tier));
			if (value < 0.3) {
				shift = 1;
			} else if (value > 0.74) {
				shift = -1;
			}
		}
		feature *= 0.25;
	}
	bool has_sea = sea_level > 0.0;
	int lowest = (has_sea && index >= 3) ? 3 : 0;
	int highest = (has_sea && index < 3) ? 2 : 5;
	return clamp(index + shift, lowest, highest);
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
		if (largest / size < detail_units * 7.0) {
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
	// Far out, everything below works on the planet's own pixels, counted out from its middle,
	// so the disc is a clean shape however big they are.
	vec2 middle = round(center_px);
	vec2 block_at = floor((floor(pixel) + vec2(0.5) - middle) / block_px);
	vec2 offset = (block_at + vec2(0.5)) * block_px;
	vec2 whole = block_at + vec2(4096.0);

	// Close up, it works on the grid fixed to the ground instead. Near the pole that grid would
	// pinch together, so the middle of the disc stays on the far-out pixels.
	bool on_grid = false;
	bool above_ground = false;
	float ground_px = 0.0;
	float height_px = 0.0;
	float rim_band = 4.0;
	float along_rim = 0.0;
	float depth_units = 0.0;
	vec2 grid_ground = vec2(0.0);
	if (on_surface_grid) {
		vec2 from_view = floor(pixel) + vec2(0.5) - screen_middle;
		vec2 from_body = view_from_body + from_view;
		float distance_now = length(from_body);
		if (distance_now > radius_px * 0.6) {
			on_grid = true;
			// Measured against the middle of the view, which keeps the numbers small and exact.
			float turn = atan(view_from_body.x * from_view.y - view_from_body.y * from_view.x, dot(view_from_body, from_body));
			float column = floor(view_column_share + turn * radius_px / cell_px);
			height_px = view_height_px + (2.0 * dot(view_from_body, from_view) + dot(from_view, from_view)) / (distance_now + length(view_from_body));
			float row = floor(height_px / cell_px);
			whole = vec2(column + 4096.0, row + 4096.0);
			float strip_at = column + 512.0;
			if (strip_at >= 0.0 && strip_at < 1024.0) {
				vec4 rim = texelFetch(rim_strip, ivec2(int(strip_at), 0), 0);
				ground_px = rim.r * rim_fade / units_per_px;
				rim_band = rim.g;
			}
			along_rim = (float(view_column) + column + 0.5) * cell_units;
			depth_units = (floor(ground_px / cell_px) * cell_px - (row + 0.5) * cell_px) * units_per_px;
			above_ground = row * cell_px >= floor(ground_px / cell_px) * cell_px;
			float at_angle = (float(view_column) + column + 0.5) * cell_px / radius_px;
			float at_radius = (radius_px + (row + 0.5) * cell_px) * units_per_px;
			grid_ground = vec2(sin(at_angle), -cos(at_angle)) * at_radius;
			// The planet's own pixel, for the things that don't care about the grid.
			offset = from_body;
		}
	}
	float distance_px = length(offset);
	float pattern = dither(whole);
	float from_far = clamp(units_per_px / 256.0, 0.0, 1.0);
	vec2 outward = distance_px > 0.0 ? offset / distance_px : vec2(0.0, -1.0);
	float facing = dot(outward, light_way);
	float air_day = clamp(floor(clamp(facing * 1.4 + 0.45, 0.0, 1.0) * 3.0 + pattern), 0.0, 3.0) / 3.0;

	if (on_grid ? above_ground : distance_px > radius_px) {
		float above_base = on_grid ? max(height_px, 0.0) : distance_px - radius_px;
		if (above_base < air_px) {
			// Flat bands of sky, thinning with height: the horizon color at the bottom, fading up
			// through the air's color into space. Dark on the night side, and warm around sunrise
			// and sunset. Far out it's just a few bands around the planet.
			float reach = 1.0 - above_base / air_px;
			float steps = mix(air_steps, 3.0, from_far);
			float level = clamp(floor(reach * reach * steps + 1.0 - sky_dither + pattern * sky_dither), 0.0, steps) / steps;
			vec3 sky = mix(air_color, air_horizon_color, smoothstep(0.55, 1.0, level));
			float sunset = clamp(floor((1.0 - abs(facing + 0.05) / 0.2) * 3.0 + pattern), 0.0, 3.0) / 3.0 * 0.8 * level;
			COLOR = vec4(mix(sky, air_sunset_color, sunset), level * air_strength * mix(0.05, 1.0, air_day));
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		// Turn the screen offset back by the spin to find which ground is under this pixel.
		vec2 ground = vec2(spin_cos * offset.x + spin_sin * offset.y, spin_cos * offset.y - spin_sin * offset.x) * units_per_px;
		if (on_grid) {
			ground = grid_ground;
		}
		vec2 light_on_ground = vec2(spin_cos * light_way.x + spin_sin * light_way.y, spin_cos * light_way.y - spin_sin * light_way.x);
		float height = terrain_height(ground);
		if (crater_amount > 0.0) {
			uint seed = uint(terrain_seed) + 80u;
			if (largest_feature * 0.32 > detail_units * 5.0) {
				height += crater_change(ground, largest_feature * 0.32, seed, light_on_ground);
			}
			if (largest_feature * 0.08 > detail_units * 5.0) {
				height += crater_change(ground, largest_feature * 0.08, seed + 8u, light_on_ground);
			}
		}

		// Flat colors with hard edges, the way the ship is drawn.
		int index = with_detail(int(clamp(height_to_band(height), 0.0, 5.999)), ground);
		float share_out = distance_px / radius_px;
		if (ice_cap > 0.0 && share_out + (height - 0.5) * 0.35 < ice_cap) {
			index = 5;
		}
		vec3 color = surface_colors[index].rgb;

		// Close in, a side view of the ground grows down from the skyline over the map, with a
		// dithered edge where they meet.
		float section = clamp((section_starts - units_per_px) / (section_starts - section_full), 0.0, 1.0);
		float section_reach = section * section * section * section * section_deepest_px;
		bool in_section = on_surface_grid && (on_grid ? depth_units / units_per_px + (pattern - 0.5) * 40.0 < section_reach : section >= 1.0);
		if (in_section) {
			color = on_grid ? section_color(along_rim, depth_units, rim_band, section < 1.0 ? section_reach * units_per_px : 0.0) : strata_colors[3].rgb;
		}

		// Clouds are one flat color, and fade out as you get close.
		if (!in_section && cloud_amount > 0.0 && units_per_px > cloud_nearest) {
			float fading = clamp((units_per_px - cloud_nearest) / (cloud_nearest * 3.0), 0.0, 1.0);
			if (cloud_cover(offset, share_out, 5) > 1.0 - cloud_amount * fading) {
				color = cloud_color;
			}
		}

		// The disc is a ball, so the star lights it from one side, in flat steps. Far out, a
		// checker of pixels marks each step, as a pixel artist would shade it.
		vec2 on_ball = offset / radius_px;
		float rise = sqrt(max(1.0 - dot(on_ball, on_ball), 0.0));
		float sun = dot(vec3(on_ball, rise), normalize(vec3(light_way, light_lift)));
		float exact_light = clamp(sun * 1.25 + 0.2, 0.0, 1.0) * light_steps;
		float checker = mod(whole.x + whole.y, 2.0) * 0.14 * from_far;
		float daylight = clamp(floor(exact_light + checker), 0.0, light_steps) / light_steps;
		color = mix(color * night_share, color, daylight);

		// A thin bright rim of air on the day side, from far out.
		if (!on_grid && air_px > 0.0 && from_far > 0.0 && radius_px - distance_px < block_px * 2.5 && air_day > 0.0) {
			color = mix(color, air_color, 0.75 * air_day);
		}
		COLOR = vec4(color, 1.0);
	}
}
