// reentry.gdshader: what heat does to one layer of the ship's art: the hull glows from the hot
// side, the air packed against it burns in a thin layer, and flames trail off its edges.
// From DESIGN.md, "Hazards" (atmospheres: drag and re-entry heat). Uses the ship's own art as a
// mask, so all of it follows the ship's real shape, whatever has been shot off it.
//
// Drawn over a rectangle bigger than the art, in the art's own pixels, centered on its middle.
shader_type canvas_item;

// The art this heat applies to, and its size in pixels.
uniform sampler2D art : filter_nearest, repeat_disable;
uniform vec2 art_size = vec2(1.0);
// The way the ship is moving through the air, on the art, and how hot the air is making it.
uniform vec2 wind_way = vec2(0.0, -1.0);
uniform float air_heat = 0.0;
// The side of the hull that's soaked up heat, on the art, and how hot the hull has got.
uniform vec2 soak_way = vec2(0.0, -1.0);
uniform float hull_heat = 0.0;
// The agency palette's fire colors, hottest first.
uniform vec3 white_hot : source_color = vec3(1.0);
uniform vec3 yellow_hot : source_color = vec3(1.0, 0.7, 0.3);
uniform vec3 red_hot : source_color = vec3(0.9, 0.3, 0.1);
uniform vec3 dull_hot : source_color = vec3(0.5, 0.2, 0.1);

varying vec2 local;


void vertex() {
	local = VERTEX;
}


bool solid(vec2 at) {
	vec2 uv = at / art_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return false;
	}
	return texture(art, uv).a > 0.5;
}


float flicker(vec2 at, float frame) {
	return fract(sin(dot(at, vec2(12.9898, 78.233)) + frame * 37.719) * 43758.5453);
}


// The hull glows from the hot side in, as far as the heat has got: dull at first, then red,
// orange, and nearly white right at the surface.
vec4 hull_glow(vec2 at) {
	float depth = 42.0;
	for (int step = 1; step <= 14; step++) {
		if (!solid(at + soak_way * float(step) * 3.0)) {
			depth = float(step - 1) * 3.0;
			break;
		}
	}
	float level = hull_heat - depth / 40.0;
	// A checker of pixels softens each edge, as the art's own shading would.
	level += mod(floor(at.x) + floor(at.y), 2.0) * 0.04;
	if (level < 0.1) {
		return vec4(0.0);
	}
	if (level < 0.35) {
		return vec4(dull_hot, 0.75);
	}
	if (level < 0.6) {
		return vec4(red_hot, 0.9);
	}
	if (level < 0.85) {
		return vec4(yellow_hot, 1.0);
	}
	return vec4(white_hot, 1.0);
}


// The air packed against the front of the ship: a thin, flickering layer, hottest against it.
vec4 air_layer(vec2 chunk, float strength, float frame) {
	float thickness = 1.5 + strength * 9.0;
	for (int step = 1; step <= 7; step++) {
		float standoff = float(step) * 2.0;
		if (standoff > thickness + 2.0) {
			break;
		}
		if (solid(chunk - wind_way * standoff)) {
			float share = standoff / thickness;
			if (flicker(chunk, frame) < share * share * 0.85) {
				return vec4(0.0);
			}
			if (strength < 0.3) {
				return vec4(share < 0.6 ? yellow_hot : red_hot, 1.0);
			}
			if (share < 0.4) {
				return vec4(strength > 0.45 ? white_hot : yellow_hot, 1.0);
			}
			return vec4(share < 0.75 ? yellow_hot : red_hot, 1.0);
		}
	}
	return vec4(0.0);
}


// Flames streaming back from the ship, in lanes, longest off its edges. A little heat only makes
// a few short red licks. Gaps in the art have hull right in front of them, so they stay clear.
vec4 flames(vec2 chunk, float strength, float frame) {
	if (solid(chunk - wind_way * 5.0) || solid(chunk - wind_way * 10.0)) {
		return vec4(0.0);
	}
	vec2 across = vec2(-wind_way.y, wind_way.x);
	float lane = floor(dot(chunk, across) / 4.0);
	float heat = min(strength, 1.0);
	float longest = (8.0 + heat * 215.0) * (0.45 + 0.55 * flicker(vec2(lane, 3.0), floor(frame / 2.0)));
	for (int step = 1; step <= 28; step++) {
		float behind = float(step) * 8.0;
		if (behind > longest + 8.0) {
			break;
		}
		vec2 probe = chunk + wind_way * behind;
		if (solid(probe)) {
			float reach = longest;
			if (solid(probe + across * 6.0) && solid(probe - across * 6.0)) {
				reach *= 0.45;
			}
			float share = behind / reach;
			if (share > 1.0 || flicker(chunk, frame) > (1.0 - share * 0.75) * (0.3 + 0.7 * sqrt(heat))) {
				return vec4(0.0);
			}
			if (heat < 0.3) {
				return vec4(share < 0.5 ? red_hot : dull_hot, 1.0);
			}
			if (share < 0.3) {
				return vec4(heat > 0.75 ? white_hot : yellow_hot, 1.0);
			}
			return vec4(share < 0.65 ? yellow_hot : red_hot, 1.0);
		}
	}
	return vec4(0.0);
}


void fragment() {
	vec2 at = floor(local + art_size / 2.0) + vec2(0.5);
	COLOR = vec4(0.0);
	if (solid(at)) {
		if (hull_heat > 0.05) {
			COLOR = hull_glow(at);
		}
	} else if (air_heat > 0.03) {
		// Fire is drawn in chunkier pixels than the hull, to read as gas instead of metal.
		vec2 chunk = floor(at / 2.0) * 2.0 + vec2(1.0);
		float strength = min(air_heat, 1.3);
		float frame = floor(TIME * 14.0);
		COLOR = air_layer(chunk, strength, frame);
		if (COLOR.a <= 0.0) {
			COLOR = flames(chunk, strength, frame);
		}
	}
}
