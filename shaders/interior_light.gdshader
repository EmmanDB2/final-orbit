// interior_light.gdshader: a station's insides lit by its lamps. Each lamp lights a round pool that
// fades toward its edge, on top of a little light everywhere, and the art steps down the palette
// where the light's low (see palette_light.gdshaderinc). Walls stop the lamps' light: that's worked
// out once into a light map (scripts/station/station_light.gd), and until it's ready the lamps light
// straight through. Lamps are in the picture's own pixels. From DESIGN.md, "Lighting".
shader_type canvas_item;

#include "res://shaders/palette_light.gdshaderinc"

#define MOST_LAMPS 64

// Each lamp: where it is on the picture, in its pixels, how far its light reaches, and how bright
// it is, from 0 to 1.
uniform vec4 lamps[MOST_LAMPS];
uniform int lamp_count = 0;
// The light everywhere, with no lamp near, from 0 to 1.
uniform float ambient = 0.3;
// The lamps' light, walls and all, once it's worked out.
uniform sampler2D light_map : filter_nearest;
uniform bool baked = false;
// Where someone can stand: white on floors. Lights that move are stopped by everything else.
uniform sampler2D floor_mask : filter_nearest;

void fragment() {
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE) + 0.5;
	float light = ambient;
	for (int i = 0; i < MOST_LAMPS; i++) {
		if (baked || i >= lamp_count) {
			break;
		}
		vec4 lamp = lamps[i];
		float share = clamp(1.0 - distance(pixel, lamp.xy) / lamp.z, 0.0, 1.0);
		light += lamp.w * share * share * (3.0 - 2.0 * share);
	}
	if (baked) {
		light = texture(light_map, UV).r;
	}
	COLOR = palette_lit(texture(TEXTURE, UV), light, pixel);
}
