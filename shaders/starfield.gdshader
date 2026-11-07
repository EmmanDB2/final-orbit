// starfield.gdshader: seeded pixel-art stars for the background, in parallax layers.
// From DESIGN.md, "Art direction" (space is shaders and code, generated from a seed).
//
// Uses integer hashing rather than the usual sin() trick, so every GPU draws the
// same stars for the same seed.
//
// With the star tint on (see star_light.gd), this also paints the background in the
// star's color, and the star's glare washes out faint stars. With it off, pixels
// with no star stay transparent and the very dark clear color shows through.
shader_type canvas_item;

const int CELL_PIXELS = 32;
// CELL_PIXELS * TILE_CELLS must equal TILE_PIXELS in starfield.gd.
const int TILE_CELLS = 512;

uniform int star_seed = 1;
uniform vec4 star_colors[4] : source_color;
// Chance that a cell holds a star, per layer, farthest first.
uniform float layer_density[3];
uniform float layer_brightness[3];
// Chance that a star in the nearest layer is drawn as a larger plus shape.
uniform float big_star_chance = 0.15;
// Whole-pixel scroll per layer, set by starfield.gd.
uniform vec2 layer_scroll[3];
// How far the view is turned, and the middle of the screen it turns around.
uniform float view_cos = 1.0;
uniform float view_sin = 0.0;
uniform vec2 view_middle = vec2(0.0);

// Set by starfield.gd while the star tint is on.
uniform bool tint_enabled = false;
uniform vec3 star_color : source_color = vec3(1.0);
uniform float light_level = 0.0;
// Brightness of the background at full light. Keep it low: this is a slight tint.
uniform float max_tint = 0.18;
// How much of each layer the glare hides at full light, farthest first.
uniform float layer_washout[3];

varying vec2 pixel;


uint hash(uint value) {
	uint state = value * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}


float unit(uint value) {
	return float(value & 65535u) / 65536.0;
}


vec4 star_at(int layer, vec2 place) {
	ivec2 world_pixel = ivec2(floor(place));
	ivec2 cell = (world_pixel / CELL_PIXELS) % TILE_CELLS;
	uint h = hash(uint(star_seed) ^ hash(uint(layer) ^ hash(uint(cell.x) ^ hash(uint(cell.y)))));
	if (unit(h) >= layer_density[layer]) {
		return vec4(0.0);
	}

	// Keep stars one pixel away from the cell edge so a plus shape is never cut off.
	h = hash(h);
	int usable = CELL_PIXELS - 2;
	ivec2 star = ivec2(1 + int(h & 65535u) % usable, 1 + int(h >> 16u) % usable);
	vec2 from_star = mod(place, float(CELL_PIXELS)) - vec2(star) - vec2(0.5);
	h = hash(h);
	bool is_big = layer == 2 && unit(h) < big_star_chance;
	// Round, so a star stays the same size however the view is turned, and always covers a pixel.
	if (length(from_star) > (is_big ? 1.3 : 0.7072)) {
		return vec4(0.0);
	}

	vec4 color = star_colors[int((h >> 16u) & 3u)];
	return vec4(color.rgb * layer_brightness[layer], 1.0);
}


void vertex() {
	pixel = VERTEX;
}


void fragment() {
	vec3 background = star_color * light_level * max_tint;
	COLOR = tint_enabled ? vec4(background, 1.0) : vec4(0.0);
	vec2 from_middle = floor(pixel) + vec2(0.5) - view_middle;
	vec2 turned = view_middle + vec2(view_cos * from_middle.x - view_sin * from_middle.y, view_sin * from_middle.x + view_cos * from_middle.y);
	vec4 star;
	for (int layer = 0; layer < 3; layer++) {
		star = star_at(layer, turned + layer_scroll[layer] + vec2(float(CELL_PIXELS * TILE_CELLS)));
		if (star.a > 0.0) {
			float visible = 1.0 - layer_washout[layer] * light_level;
			COLOR = vec4(mix(background, star.rgb, visible), 1.0);
		}
	}
}
