// palette_light.gdshaderinc: light and shade that keep to the agency palette. Shade never mixes in
// black: each pixel steps down its own ramp in the palette, white hull through the grays to near
// black, orange, gold, blue, and glass each down their own, and where one step meets the next the
// art's own pixels switch in a hard line to the nearest step, like the sky's bands. Lights and screens
// (telemetry and thrust colors) glow and never darken. Shared by every shader that lights art, so
// rooms and, later, hulls shade the same way: each works out how much light reaches a pixel, from
// 0 to 1, and hands it to palette_lit(). From DESIGN.md, "Art direction" (the locked palette) and
// "Lighting".
//
// Light that has a color of its own is gentle: warm light only turns the two lightest hull colors to
// the matching warm steps (so it tints what's white and never hides what's colored), and a plant's
// leaves step down their own three greens, so they aren't glowing screens. scripts/palette_light.gd fills these uniforms from the palette.

#define PALETTE_SIZE 32
// The most steps any ramp has, from its lightest to near black.
#define MOST_STEPS 5

uniform vec3 palette_colors[PALETTE_SIZE];
// Each color's next darker step on its ramp, as an index into palette_colors, or itself at the end.
uniform int palette_down[PALETTE_SIZE];
// 1 for a color that glows and never darkens.
uniform float palette_glow[PALETTE_SIZE];
uniform int palette_count = 0;

// What warm light turns the two lightest hull colors to, and a plant's leaves' ramp: their own green,
// dark glass, near black.
#define PLANT_STEPS 3
uniform vec3 warm_from[2];
uniform vec3 warm_to[2];
uniform vec3 plant_ramp[PLANT_STEPS];

// The palette color nearest this one.
int palette_index(vec3 color) {
	int best = 0;
	float nearest = 1e9;
	for (int i = 0; i < palette_count; i++) {
		vec3 apart = color - palette_colors[i];
		float d = dot(apart, apart);
		if (d < nearest) {
			nearest = d;
			best = i;
		}
	}
	return best;
}

// This color as this much light leaves it: stepped down its ramp to the nearest step, with a hard
// edge where one step meets the next. Full light leaves it as it is; none takes it all the way down.
vec4 palette_lit(vec4 color, float light) {
	if (color.a <= 0.0 || palette_count == 0) {
		return color;
	}
	int index = palette_index(color.rgb);
	if (palette_glow[index] > 0.5) {
		return color;
	}
	float down = (1.0 - clamp(light, 0.0, 1.0)) * float(MOST_STEPS);
	int steps = int(floor(down + 0.5));
	for (int i = 0; i < MOST_STEPS; i++) {
		if (i < steps) {
			index = palette_down[index];
		}
	}
	return vec4(palette_colors[index], color.a);
}

// A color as warm light leaves it: the lightest hull white becomes the warm cream, the next one the
// warm gold, and any other color stays as it is.
vec3 warm_swap(vec3 color) {
	for (int i = 0; i < 2; i++) {
		vec3 apart = color - warm_from[i];
		if (dot(apart, apart) < 0.002) {
			return warm_to[i];
		}
	}
	return color;
}

// Whether this color is a plant's leaves' green.
bool is_plant_green(vec3 color) {
	vec3 apart = color - plant_ramp[0];
	return dot(apart, apart) < 0.004;
}

// A plant's leaves with this much light on them: the green, then dark glass, then near black.
vec3 plant_lit(float light) {
	int steps = int(floor((1.0 - clamp(light, 0.0, 1.0)) * float(MOST_STEPS) + 0.5));
	if (steps <= 0) {
		return plant_ramp[0];
	}
	return steps <= 2 ? plant_ramp[1] : plant_ramp[2];
}
