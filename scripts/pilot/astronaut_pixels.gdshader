// astronaut_pixels.gdshader: turns the 3D pilot's render into pixel art. Every pixel snaps to the
// nearest agency color, measured in Oklab, and a 1 px dark outline goes round the outside and
// round any part that passes in front of another, found from a second render of distances. The
// far side of the body is a shade darker.
// From DESIGN.md, "Player" (the 3D pilot) and "Art direction" (agency palette, 1 px outline).
shader_type canvas_item;

const int MOST_COLORS = 24;

// The colors the suit can be drawn in, as sRGB and as Oklab, set from the palette resource.
uniform vec3 colors[MOST_COLORS];
uniform vec3 colors_lab[MOST_COLORS];
uniform int color_count = 0;
uniform vec4 outline_color : source_color = vec4(0.055, 0.059, 0.071, 1.0);
// How far each pixel is from the camera, 0 to 1 over the depth shader's range, and how big a step
// in that counts as one part in front of another.
uniform sampler2D distances : filter_nearest;
uniform float step_to_line = 0.04;
// Anything farther than this, on the same 0 to 1 scale, is the far side of the body, drawn darker
// the way pixel artists shade the far arm and leg.
uniform float far_side = 0.48;
uniform float far_shade = 0.72;
// Burning up: how far the suit has gone to the re-entry glow colors (hottest first below) and how
// far it has broken up, each from 0 to 1, each a hard line sweeping down the sprite from the head.
uniform float flare = 0.0;
uniform float dissolve = 0.0;
uniform vec3 glow_white = vec3(1.0);
uniform vec3 glow_yellow = vec3(1.0, 0.7, 0.3);
uniform vec3 glow_red = vec3(0.9, 0.3, 0.1);
uniform vec3 glow_dull = vec3(0.5, 0.2, 0.1);

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_oklab(vec3 srgb) {
	vec3 c = to_linear(srgb);
	float l = pow(0.4122 * c.r + 0.5363 * c.g + 0.0514 * c.b, 1.0 / 3.0);
	float m = pow(0.2119 * c.r + 0.6807 * c.g + 0.1074 * c.b, 1.0 / 3.0);
	float s = pow(0.0883 * c.r + 0.2817 * c.g + 0.6300 * c.b, 1.0 / 3.0);
	return vec3(
			0.2105 * l + 0.7936 * m - 0.0041 * s,
			1.9780 * l - 2.4286 * m + 0.4506 * s,
			0.0259 * l + 0.7828 * m - 0.8087 * s);
}

void fragment() {
	vec4 here = texture(TEXTURE, UV);
	if (here.a < 0.5) {
		vec2 step_size = TEXTURE_PIXEL_SIZE;
		float near = texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a
				+ texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, step_size.y)).a
				+ texture(TEXTURE, UV - vec2(0.0, step_size.y)).a;
		COLOR = near > 0.5 ? outline_color : vec4(0.0);
	} else {
		// A pixel just behind the edge of something nearer becomes part of that thing's outline.
		float far = texture(distances, UV).r;
		vec2 step_size = TEXTURE_PIXEL_SIZE;
		bool behind = false;
		for (int i = 0; i < 4; i++) {
			vec2 offset = i == 0 ? vec2(step_size.x, 0.0) : (i == 1 ? vec2(-step_size.x, 0.0) : (i == 2 ? vec2(0.0, step_size.y) : vec2(0.0, -step_size.y)));
			vec4 near = texture(distances, UV + offset);
			if (near.a > 0.5 && near.r < far - step_to_line) {
				behind = true;
			}
		}
		vec3 lab = to_oklab(far > far_side ? here.rgb * far_shade : here.rgb);
		float best = 1e9;
		vec3 chosen = here.rgb;
		for (int i = 0; i < MOST_COLORS; i++) {
			if (i >= color_count) {
				break;
			}
			vec3 gap = lab - colors_lab[i];
			float distance = dot(gap, gap);
			if (distance < best) {
				best = distance;
				chosen = colors[i];
			}
		}
		COLOR = behind ? outline_color : vec4(chosen, 1.0);
	}
	// Burning up: pixels go to glow colors, lighter ones hotter, then drop out. Each is a hard line
	// moving from the head to the feet: everything above it has changed, everything below hasn't.
	if (COLOR.a > 0.5 && (flare > 0.0 || dissolve > 0.0)) {
		if (flare > UV.y) {
			float lum = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
			float heat = clamp(lum * 0.7 + flare * 0.45, 0.0, 1.0);
			COLOR.rgb = heat > 0.8 ? glow_white : (heat > 0.55 ? glow_yellow : (heat > 0.3 ? glow_red : glow_dull));
		}
		if (dissolve > UV.y) {
			COLOR = vec4(0.0);
		}
	}
}
