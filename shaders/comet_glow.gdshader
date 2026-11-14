// comet_glow.gdshader: a comet's coma, its two tails, and its jets, drawn as glow in chunky pixels:
// the glow's strength is cut into 5 alpha bands with a 4 x 4 Bayer dither between neighbours, never a
// smooth gradient, the way the engine flame is. The ion tail runs straight away from the star, thin
// and pale blue, with streamers rippling outward. The dust tail is wider and cream, and follows the
// comet's own path back from the nucleus, bent away from the star. From DESIGN.md, "Mid-flight
// events" (passing comets) and "Art direction" (space and effects are shaders and code).
//
// Drawn over a rectangle in screen pixels, centred on the comet, covering what's on screen of the
// coma and both tails. scripts/event/comet_view.gd works out the dust path and the jets each frame.
shader_type canvas_item;

// Where the comet is against the middle of the view, in screen pixels, and how far the view is
// turned, so the game pixels stay square to the screen.
uniform vec2 view_origin = vec2(0.0);
uniform float roll = 0.0;
// How wide each game pixel is, in screen pixels.
uniform float block = 4.0;
// How much of the star can be seen from here, from 0 to 1.
uniform float sun = 1.0;
// A number from the comet's name, so no two comets ripple in step.
uniform float seed = 0.0;
uniform vec3 glow_color : source_color = vec3(0.84, 0.93, 0.96);
uniform vec3 ion_color : source_color = vec3(0.62, 0.72, 0.95);
uniform vec3 dust_color : source_color = vec3(0.9, 0.85, 0.72);
// Sizes, in screen pixels: the coma's reach, the nucleus's radius, and each tail's length and its
// half width at the far end.
uniform float reach_px = 100.0;
uniform float nucleus_px = 4.0;
uniform float ion_length_px = 400.0;
uniform float ion_end_px = 20.0;
uniform float dust_length_px = 300.0;
uniform float dust_end_px = 40.0;
// The unit vector pointing away from the star.
uniform vec2 away = vec2(1.0, 0.0);
// The dust tail's path, from the nucleus back, in screen pixels from the comet. Its far end is
// already pushed away from the star.
uniform vec2 dust_points[25];
// Each jet: the way it points (x, y), where it leaves the nucleus (z, from the middle), and how
// strongly it's spraying (w, 0 when its spot faces away from the star).
uniform vec4 jets[3];
uniform int jet_count = 0;
// The most alpha the glow ever reaches, so the stars still show through the tails.
uniform float most_alpha = 0.45;

varying vec2 local;

const int DUST_SEGMENTS = 24;
// A jet's fan is this wide, in radians of half angle (10 degrees), and this many nucleus radii long.
const float JET_SPREAD = 0.1763;
const float JET_LENGTH = 4.0;


void vertex() {
	local = VERTEX;
}


vec2 turn(vec2 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}


float bayer4(vec2 cell) {
	ivec2 at = ivec2(mod(cell, 4.0));
	int index = at.x + at.y * 4;
	int matrix[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(matrix[index]) + 0.5) / 16.0;
}


float hash(float at) {
	return fract(sin(at * 12.9898 + seed * 0.37) * 43758.5453);
}


// Smooth noise along a line, from 0 to 1.
float value_noise(float at) {
	float whole = floor(at);
	float part = fract(at);
	part = part * part * (3.0 - 2.0 * part);
	return mix(hash(whole), hash(whole + 1.0), part);
}


void fragment() {
	// The middle of this game pixel, on a grid square to the screen, in the comet's own directions.
	vec2 cell = floor(turn(local + view_origin, -roll) / block);
	vec2 p = turn((cell + vec2(0.5)) * block, roll) - view_origin;
	vec2 toward = -away;
	vec2 sideways = vec2(-away.y, away.x);
	float head = max(nucleus_px, block);

	// The coma: brightest at the nucleus, out to the scan's reach, a little off toward the star.
	float from_middle = length(p - toward * reach_px * 0.1) / reach_px;
	float coma = pow(clamp(1.0 - from_middle, 0.0, 1.0), 2.2) * 0.55;
	coma += (1.0 - smoothstep(0.0, 0.14, length(p) / reach_px)) * 0.35;
	// With the star hidden, only a faint glow's left.
	coma *= mix(0.3, 1.0, sun);

	// The ion tail: straight away from the star, streamers rippling outward and bending a little
	// the further out they go.
	float ion = 0.0;
	float along = dot(p, away);
	float t = along / ion_length_px;
	if (along > -head && t < 1.0) {
		float grown = clamp(t, 0.0, 1.0);
		float half_width = mix(head, ion_end_px, grown);
		float bend = (value_noise(grown * 2.5 + TIME * 0.15) - 0.5) * 2.0 * half_width * 0.6 * grown;
		// Behind the head it's capped round instead of cut off flat.
		float across = length(vec2(min(along, 0.0), dot(p, sideways) - bend)) / half_width;
		float body = 1.0 - clamp(across * across, 0.0, 1.0);
		float streak = 0.35 + 1.15 * value_noise(across * 3.0 + grown * 5.0 - TIME * 0.9);
		ion = body * pow(1.0 - grown, 1.3) * streak * 0.9 * sun;
	}

	// The dust tail: the nearest point on the comet's path, and how far along it that is.
	float nearest = 1e9;
	float nearest_along = 0.0;
	vec2 nearest_point = vec2(0.0);
	float walked = 0.0;
	for (int i = 0; i < DUST_SEGMENTS; i++) {
		vec2 start = dust_points[i];
		vec2 finish = dust_points[i + 1];
		vec2 step_on = finish - start;
		float length_sq = dot(step_on, step_on);
		float share = length_sq > 0.0001 ? clamp(dot(p - start, step_on) / length_sq, 0.0, 1.0) : 0.0;
		vec2 close = start + step_on * share;
		float apart = length(p - close);
		if (apart < nearest) {
			nearest = apart;
			nearest_along = walked + share * sqrt(length_sq);
			nearest_point = close;
		}
		walked += sqrt(length_sq);
	}
	float lengthwise = clamp(nearest_along / dust_length_px, 0.0, 1.0);
	float dust_half = mix(head, dust_end_px, lengthwise);
	float dust_across = nearest / dust_half;
	float dust_body = 1.0 - clamp(dust_across * dust_across, 0.0, 1.0);
	// Brightest along the inner edge, the side toward the star.
	float star_side = clamp(dot(p - nearest_point, toward) / dust_half, -1.0, 1.0);
	float dust = dust_body * pow(1.0 - lengthwise, 1.2) * (0.6 + 0.5 * (star_side * 0.5 + 0.5)) * 0.85 * sun;

	// The jets: a narrow fan from each spot that faces the star, flickering about 8 times a second.
	float spray = 0.0;
	for (int k = 0; k < 3; k++) {
		if (k >= jet_count) {
			break;
		}
		vec4 jet = jets[k];
		if (jet.w <= 0.0) {
			continue;
		}
		vec2 out_of = p - jet.xy * jet.z;
		float run = dot(out_of, jet.xy);
		float length_px = max(nucleus_px, block) * JET_LENGTH;
		if (run > 0.0 && run < length_px) {
			float fan_half = run * JET_SPREAD + block * 0.5;
			float off = abs(dot(out_of, vec2(-jet.y, jet.x))) / fan_half;
			if (off < 1.0) {
				float flicker = 0.5 + 0.5 * hash(floor(TIME * 8.0) + float(k) * 7.0);
				spray += (1.0 - off * off) * pow(1.0 - run / length_px, 1.2) * flicker * 0.6 * jet.w * sun;
			}
		}
	}

	// Add them up, mixing the colors by how much each gives, then cut the total into 5 bands.
	float glow_share = coma + spray;
	float total = glow_share + ion + dust;
	vec3 mixed = (glow_color * glow_share + ion_color * ion + dust_color * dust) / max(total, 0.0001);
	float level = clamp(total, 0.0, 1.0) * 5.0;
	float band = floor(level);
	if (level - band > bayer4(cell)) {
		band += 1.0;
	}
	band = min(band, 5.0);
	COLOR = vec4(mixed, band / 5.0 * most_alpha);
}
