// palette_light.gdshaderinc: light and shade that keep to the agency palette. Shade never mixes in
// black: each pixel steps down its own ramp in the palette, white hull through the grays to near
// black, orange, gold, blue, and glass each down their own, and where one step meets the next the
// art's own pixels are dithered in a 4x4 Bayer pattern, like the sky's bands. Lights and screens
// (telemetry and thrust colors) glow and never darken. Shared by every shader that lights art, so
// rooms and, later, hulls shade the same way: each works out how much light reaches a pixel, from
// 0 to 1, and hands it to palette_lit(). From DESIGN.md, "Art direction" (the locked palette) and
// "Lighting".
//
// scripts/palette_light.gd fills these uniforms from the palette.

#define PALETTE_SIZE 32
// The most steps any ramp has, from its lightest to near black.
#define MOST_STEPS 5

uniform vec3 palette_colors[PALETTE_SIZE];
// Each color's next darker step on its ramp, as an index into palette_colors, or itself at the end.
uniform int palette_down[PALETTE_SIZE];
// 1 for a color that glows and never darkens.
uniform float palette_glow[PALETTE_SIZE];
uniform int palette_count = 0;

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

// The 4x4 Bayer threshold at an art pixel, from 0 to just under 1.
float bayer4(vec2 pixel) {
	ivec2 at = ivec2(mod(floor(pixel), 4.0));
	int index = at.x + at.y * 4;
	int matrix[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(matrix[index]) + 0.5) / 16.0;
}

// This color as this much light leaves it, at this art pixel: stepped down its ramp, dithered
// between steps. Full light leaves it as it is; none takes it all the way down.
vec4 palette_lit(vec4 color, float light, vec2 pixel) {
	if (color.a <= 0.0 || palette_count == 0) {
		return color;
	}
	int index = palette_index(color.rgb);
	if (palette_glow[index] > 0.5) {
		return color;
	}
	float down = (1.0 - clamp(light, 0.0, 1.0)) * float(MOST_STEPS);
	int steps = int(floor(down));
	if (down - float(steps) > bayer4(pixel)) {
		steps += 1;
	}
	for (int i = 0; i < MOST_STEPS; i++) {
		if (i < steps) {
			index = palette_down[index];
		}
	}
	return vec4(palette_colors[index], color.a);
}
