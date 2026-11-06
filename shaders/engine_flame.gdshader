// engine_flame.gdshader: the main engine's flame, drawn in chunky pixels in the fire colors.
// From DESIGN.md, "Art direction" (space and effects are shaders and code) and "Ships".
//
// Drawn over a rectangle in the art's own pixels, with its origin at the middle of the engine's
// exit and "down" pointing out of it. Its shape comes from what the engine is doing: long and
// white hot at full throttle, short and orange when throttled back, spreading wide in a vacuum and
// held narrow by air, with bright knots in it when it's held tight. A damaged engine sputters.
shader_type canvas_item;

// How hard the engine is pushing, from 0 to 1.
uniform float power = 0.0;
// How wide the engine's exit is, and how long the flame gets flat out, in art pixels.
uniform float half_exit = 10.0;
uniform float longest = 150.0;
// How thick the air is here, from 0 to 1.
uniform float air = 0.0;
// How damaged the engine is, from 0 for whole to 1 for nearly gone.
uniform float sputter = 0.0;
// How far away the ground is along the flame, in art pixels. It stops there.
uniform float room = 100000.0;
// The agency palette's fire colors, hottest first.
uniform vec3 white_hot : source_color = vec3(1.0);
uniform vec3 yellow_hot : source_color = vec3(1.0, 0.7, 0.3);
uniform vec3 red_hot : source_color = vec3(0.9, 0.3, 0.1);

// How many times a second the flame changes.
uniform float flicker_rate = 22.0;

varying vec2 local;


void vertex() {
	local = VERTEX;
}


float flicker(vec2 at, float frame) {
	return fract(sin(dot(at, vec2(12.9898, 78.233)) + frame * 37.719) * 43758.5453);
}


void fragment() {
	COLOR = vec4(0.0);
	// Flames are drawn in chunkier pixels than the hull, to read as gas instead of metal.
	vec2 chunk = floor(local / 2.0) * 2.0 + vec2(1.0);
	float down = chunk.y;
	float frame = floor(TIME * flicker_rate);
	if (down >= 0.0 && down < room) {
		// A vacuum lets it spread, and air holds it in.
		float spread = mix(0.3, 0.07, air);
		float half_width = half_exit * (0.5 + 0.5 * power) + down * spread;
		float side = abs(chunk.x) / half_width;
		if (side < 1.0) {
			// Each column of pixels has its own flickering length, so the tip is never still.
			float column = floor(chunk.x / 2.0);
			float tip = longest * power * (0.72 + 0.28 * flicker(vec2(column, 1.0), frame));
			tip *= 1.0 - side * side * 0.72;
			// A damaged engine keeps dropping out, a few pixels at a time.
			tip *= 1.0 - sputter * 0.75 * step(flicker(vec2(3.0, 7.0), frame), 0.45);
			if (down < tip) {
				float along = down / tip;
				// The tail breaks up into separate pixels.
				bool kept = along < 0.55 || flicker(chunk, frame) > (along - 0.55) * 1.7;
				if (kept) {
					float heat = (1.0 - along) * (1.0 - side * 0.55) * (0.45 + 0.75 * power);
					// Held tight by air, a hard-pushing flame shows bright knots along its middle.
					heat += air * power * 0.22 * sin(down * 0.17) * (1.0 - side);
					if (heat > 0.55) {
						COLOR = vec4(white_hot, 1.0);
					} else if (heat > 0.26) {
						COLOR = vec4(yellow_hot, 1.0);
					} else {
						COLOR = vec4(red_hot, 1.0);
					}
				}
			}
		}
	}
}
