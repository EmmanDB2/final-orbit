// hull_light.gdshader: a hull lit by the star, a ship's or a station's. The hull's drawn flat and the
// shading comes from here: each run of solid pixels, across a row or down a column, whichever is
// shorter, is treated as a cylinder, so the side toward the star is bright, the middle a step down,
// and the far side falls into shadow, stepping down the palette like everything lit (see
// palette_light.gdshaderinc). Side pods, legs, the bell, and a station's arms each curve on their own.
// From DESIGN.md, "Lighting" (outside).
shader_type canvas_item;

#include "res://shaders/palette_light.gdshaderinc"

// Where each pixel is across its run: red across its row, green down its column, each from -1 to 1
// stored from 0 to 1, and blue set where the row's run is the one the curve goes across.
uniform sampler2D across_map : filter_nearest;
// The way to the star, in the art's own pixels, with y down.
uniform vec2 light_dir = vec2(-1.0, 0.0);
// How much of the starlight comes from the front, so the far side isn't black.
uniform float front = 0.55;
// How much of the star can be seen, from 0 in a world's shadow to 1.
uniform float sun = 1.0;
// The light with the star hidden or on the far side, from 0 to 1.
uniform float ambient = 0.32;
// How far round the far side light still creeps, so the shading rolls instead of cutting off.
uniform float wrap = 0.5;
// How strongly the lit side's lit: above 1, the middle stays full and only the far side darkens.
uniform float boost = 1.5;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec3 runs = texture(across_map, UV).rgb;
	vec3 normal;
	if (runs.b > 0.5) {
		float across = runs.r * 2.0 - 1.0;
		normal = vec3(across, 0.0, sqrt(max(1.0 - across * across, 0.0)));
	} else {
		float down = runs.g * 2.0 - 1.0;
		normal = vec3(0.0, down, sqrt(max(1.0 - down * down, 0.0)));
	}
	vec3 toward = normalize(vec3(light_dir.x, light_dir.y, front));
	float diffuse = clamp((dot(normal, toward) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float light = ambient + (1.0 - ambient) * min(diffuse * boost, 1.0) * sun;
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE) + 0.5;
	COLOR = palette_lit(art, light, pixel);
}
