// comet_nucleus.gdshader: a comet's nucleus, a lumpy cratered rock lit from the star's side, drawn on
// chunky pixels in five banded tones with a 4 x 4 Bayer dither between them. From DESIGN.md,
// "Mid-flight events" (passing comets) and "Art direction" (space and effects are shaders and code).
//
// Drawn over a square 2.4 radii across, centred on the comet, in screen pixels. The outline, the
// craters, and the spin all come from the comet's name, worked out in scripts/event/comet_view.gd.
// Everything here works in the nucleus's own frame, turned by minus the spin, so the craters ride
// round with the surface while the lit side stays toward the star.
shader_type canvas_item;

// A number from the comet's name, for the surface grain.
uniform float seed = 0.0;
// How far the nucleus has turned, in radians.
uniform float spin = 0.0;
// Which way the star is, as a unit vector in the world's directions.
uniform vec2 light_dir = vec2(1.0, 0.0);
// How much of the star can be seen from here, from 0 to 1.
uniform float sun = 1.0;
// The nominal radius on screen, in pixels, and how wide each game pixel is, also in screen pixels.
uniform float radius_px = 50.0;
uniform float block = 4.0;
// How far the view is turned, so game pixels stay square to the screen.
uniform float roll = 0.0;
uniform vec3 nucleus_color : source_color = vec3(0.72, 0.76, 0.79);
uniform vec3 dust_color : source_color = vec3(0.37, 0.35, 0.33);
// The outline's radius at 18 evenly spaced angles, in nominal radii (0.72 to 1.0).
uniform float bulges[18];
// Each crater: its middle in nominal radii (x, y), its radius, and how deep it is.
uniform vec4 craters[10];
uniform int crater_count = 0;

varying vec2 local;

const float AMBIENT = 0.08;


void vertex() {
	local = VERTEX;
}


vec2 turn(vec2 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}


// The 4 x 4 Bayer threshold at a game pixel, from 0 to just under 1.
float bayer4(vec2 cell) {
	ivec2 at = ivec2(mod(cell, 4.0));
	int index = at.x + at.y * 4;
	int matrix[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(matrix[index]) + 0.5) / 16.0;
}


float hash(vec2 at) {
	return fract(sin(dot(at, vec2(12.9898, 78.233)) + seed * 0.37) * 43758.5453);
}


// The outline's radius toward an angle, blended smoothly between the bulges on either side.
float outline_at(float angle) {
	float turns = fract(angle / TAU) * 18.0;
	int first = int(floor(turns)) % 18;
	int second = (first + 1) % 18;
	float along = turns - floor(turns);
	along = along * along * (3.0 - 2.0 * along);
	return mix(bulges[first], bulges[second], along);
}


void fragment() {
	COLOR = vec4(0.0);
	// The middle of this game pixel, on a grid square to the screen, turned back to the world's
	// directions and counted in nominal radii.
	vec2 cell = floor(turn(local, -roll) / block);
	vec2 offset = turn((cell + vec2(0.5)) * block, roll) / radius_px;
	// Into the nucleus's own frame.
	vec2 own = turn(offset, -spin);
	float reach = outline_at(atan(own.y, own.x));
	float away = length(own);
	if (away >= reach) {
		discard;
	}
	// A lumpy sphere: its height over the middle, and which way its surface faces.
	float height = sqrt(1.0 - pow(away / reach, 2.0));
	vec3 normal = vec3(own / reach, height);
	float darker = 1.0;
	for (int k = 0; k < 10; k++) {
		if (k >= crater_count) {
			break;
		}
		vec4 bowl = craters[k];
		vec2 from_bowl = (own - bowl.xy) / bowl.z;
		float inside = length(from_bowl);
		if (inside < 1.0) {
			// The floor is darker, and the rim leans in toward the middle of the bowl.
			darker -= bowl.w * (1.0 - smoothstep(0.55, 0.8, inside));
			float rim = smoothstep(0.5, 0.8, inside) * (1.0 - smoothstep(0.9, 1.0, inside));
			normal.xy -= normalize(from_bowl + vec2(0.0001)) * rim * 0.9 * bowl.w * 2.0;
		}
	}
	normal = normalize(normal);
	// The star, in the nucleus's frame, a little toward the viewer so the lit side reads as a face.
	vec3 star = normalize(vec3(turn(light_dir, -spin), 0.45));
	float light = clamp(dot(normal, star), 0.0, 1.0) * sun * darker + AMBIENT;
	// A little grain, a fixed rough surface that turns with the rock.
	light += (hash(floor(own * radius_px / block)) - 0.5) * 0.06 * sun;
	// Five tones, shadow to highlight, dithered between neighbours.
	vec3 ramp[5];
	ramp[0] = dust_color * 0.3;
	ramp[1] = dust_color;
	ramp[2] = mix(dust_color, nucleus_color, 0.5);
	ramp[3] = nucleus_color;
	ramp[4] = mix(nucleus_color, vec3(1.0), 0.5);
	float level = clamp(light, 0.0, 1.0) * 4.0;
	int tone = int(floor(level));
	if (level - float(tone) > bayer4(cell)) {
		tone += 1;
	}
	tone = clamp(tone, 0, 4);
	COLOR = vec4(ramp[tone], 1.0);
}
