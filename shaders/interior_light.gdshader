// interior_light.gdshader: a station's insides lit by its lamps. Each lamp lights a round pool that
// fades toward its edge, on top of a little light everywhere, and the art steps down the palette
// where the light's low (see palette_light.gdshaderinc). Walls stop the lamps' light: that's worked
// out once into a light map (scripts/station/station_light.gd), and until it's ready the lamps light
// straight through. Lamps are in the picture's own pixels. Each piece of art that uses this, a layer
// or a prop, says where its top left corner is on the station's picture and how big that picture is, so
// all of them look the light up by station pixel. From DESIGN.md, "Lighting".
shader_type canvas_item;

#include "res://shaders/palette_light.gdshaderinc"

#define MOST_LAMPS 64

// Each lamp: where it is on the picture, in its pixels, how far its light reaches, and how bright
// it is, from 0 to 1.
uniform vec4 lamps[MOST_LAMPS];
uniform int lamp_count = 0;
// The light everywhere, with no lamp near, from 0 to 1.
uniform float ambient = 0.3;
// Where this art's top left corner is on the station's picture, in its pixels, and how big the
// picture is. A whole layer is at (0, 0) and the picture's size.
uniform vec2 sprite_at = vec2(0.0);
uniform vec2 map_size = vec2(1.0);
// The lamps' light, walls and all, once it's worked out: red for steady lamps and the light
// everywhere, green for failing lamps, and blue for emergency lamps.
uniform sampler2D light_map : filter_nearest;
uniform bool baked = false;
// Whether the failing lamps are lit this moment, and how far through its pulse the emergency light is,
// from 0 to 1.
uniform float flicker = 0.0;
uniform float pulse = 1.0;
// A station with fixtures set in its data is lit the planned way, from three light maps of four channels
// each, one channel a power circuit (mains, failing, emergency, always): how much of that circuit's
// light reaches the pixel, how much of it is warm, and how much red. Each circuit's light is scaled by
// how live it is now, so the power, the flicker, and the pulse change with nothing worked out again.
uniform bool planned = false;
uniform sampler2D circuit_light : filter_nearest;
uniform sampler2D warm_share : filter_nearest;
uniform sampler2D red_share : filter_nearest;
uniform vec4 circuit_live = vec4(1.0);
// Whether this art is a plant's, so its green leaves step down their own ramp.
uniform bool plant = false;
// Emergency light is red: what it lights most takes the palette's reds, light and dark.
uniform vec3 alarm_bright : source_color = vec3(0.784, 0.188, 0.173);
uniform vec3 alarm_dim : source_color = vec3(0.478, 0.18, 0.071);
// Where someone can stand: white on floors. Lights that move are stopped by everything else.
uniform sampler2D floor_mask : filter_nearest;
// The pilot's helmet lamp: whether it's on, where the pilot is on the picture, which way they face,
// how far it reaches in picture pixels, how wide its cone is as the cosine of half its angle, and how
// bright it is. Shining from head height, it's stopped by anything that isn't floor.
uniform bool helmet_on = false;
uniform vec2 helmet_at = vec2(0.0);
uniform vec2 helmet_facing = vec2(0.0, -1.0);
uniform float helmet_reach = 110.0;
uniform float helmet_cone = 0.8;
uniform float helmet_brightness = 0.9;
// A little light round the pilot, so they can see their own feet, in picture pixels.
uniform float helmet_glow = 9.0;
// How far the beam goes into what isn't floor before it's stopped, in picture pixels.
uniform float helmet_into_walls = 5.0;

#define HELMET_STEPS 48

// How much of the helmet lamp reaches this pixel, from 0 to 1.
float helmet_light(vec2 pixel, vec2 texel) {
	vec2 apart = pixel - helmet_at;
	float distance_to = length(apart);
	float glow = clamp(1.0 - distance_to / helmet_glow, 0.0, 1.0) * 0.6;
	if (distance_to >= helmet_reach || distance_to < 0.5) {
		return max(glow, distance_to < 0.5 ? 0.6 : 0.0);
	}
	float across = dot(apart / distance_to, helmet_facing);
	// The cone's edge softens over a few degrees.
	float cone = smoothstep(helmet_cone - 0.08, helmet_cone + 0.04, across);
	if (cone <= 0.0) {
		return glow;
	}
	// What stands off the floor throws a shadow, once the beam has gone a few pixels into it, so the
	// side of whatever it hits is lit, and a thin edge of floor the map leaves out isn't lost.
	int steps = min(int(distance_to / 1.5), HELMET_STEPS);
	float step_length = distance_to / float(max(steps, 1));
	float through = 0.0;
	for (int i = 1; i < HELMET_STEPS; i++) {
		if (i >= steps) {
			break;
		}
		vec2 sample_at = helmet_at + apart * (float(i) / float(steps));
		if (texture(floor_mask, sample_at * texel).r < 0.5) {
			through += step_length;
			if (through > helmet_into_walls) {
				return glow;
			}
		}
	}
	float share = 1.0 - distance_to / helmet_reach;
	return max(glow, helmet_brightness * cone * share * (2.0 - share));
}

void fragment() {
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE) + sprite_at + 0.5;
	vec2 map_uv = pixel / map_size;
	float light = ambient;
	for (int i = 0; i < MOST_LAMPS; i++) {
		if (baked || i >= lamp_count) {
			break;
		}
		vec4 lamp = lamps[i];
		float share = clamp(1.0 - distance(pixel, lamp.xy) / lamp.z, 0.0, 1.0);
		light += lamp.w * share * share * (3.0 - 2.0 * share);
	}
	float alarm = 0.0;
	// The light that isn't the emergency lamps', which keeps its color.
	float white = light;
	// The planned way: how much of the light is warm and how much is red.
	float warm_amount = 0.0;
	float red_amount = 0.0;
	// The light that isn't tinted, not counting the light everywhere, so a bright room's still warm where a warm lamp is.
	float white_amount = 0.0;
	if (planned && baked) {
		vec4 amounts = texture(circuit_light, map_uv) * circuit_live;
		vec4 warm_of = texture(warm_share, map_uv);
		vec4 red_of = texture(red_share, map_uv);
		float all_amount = amounts.r + amounts.g + amounts.b + amounts.a;
		warm_amount = dot(amounts, warm_of);
		red_amount = dot(amounts, red_of);
		white_amount = max(all_amount - warm_amount - red_amount, 0.0);
		light = 1.0 - (1.0 - ambient) * (1.0 - amounts.r) * (1.0 - amounts.g) * (1.0 - amounts.b) * (1.0 - amounts.a);
	} else if (baked) {
		vec3 maps = texture(light_map, map_uv).rgb;
		alarm = maps.b * pulse;
		white = 1.0 - (1.0 - maps.r) * (1.0 - maps.g * flicker);
		light = 1.0 - (1.0 - white) * (1.0 - alarm);
	}
	if (helmet_on) {
		float beam = helmet_light(pixel, 1.0 / map_size);
		light = 1.0 - (1.0 - light) * (1.0 - beam);
		white = 1.0 - (1.0 - white) * (1.0 - beam);
		white_amount += beam;
	}
	vec4 art = texture(TEXTURE, UV);
	float shade = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	// The planned way: whichever of warm and red is more than half the light tints the pixel.
	bool warm_tint = false;
	bool red_tint = false;
	if (planned && baked) {
		float total_amount = white_amount + warm_amount + red_amount;
		red_tint = red_amount > warm_amount && red_amount > 0.5 * total_amount && red_amount > 0.12;
		warm_tint = !red_tint && warm_amount > 0.5 * total_amount && warm_amount > 0.12;
	}
	vec4 source = art;
	if (warm_tint) {
		source.rgb = warm_swap(art.rgb);
	}
	vec4 lit = palette_lit(source, light);
	if (planned && baked) {
		// Red light takes what it lights onto the palette's reds, with a clean edge. Outlines and the
		// darkest colors stay dark, and glowing colors keep their own. Warm light has only changed the
		// two lightest hull colors, above.
		if (plant && art.a > 0.0 && is_plant_green(art.rgb)) {
			lit.rgb = plant_lit(light);
		} else if (red_tint && art.a > 0.0 && shade > 0.12 && palette_glow[palette_index(art.rgb)] < 0.5) {
			if (red_amount * (0.6 + shade) > 0.4) {
				lit.rgb = alarm_bright;
			} else {
				lit.rgb = alarm_dim;
			}
		}
	} else {
		// Where the emergency light outshines the rest, it's red: the light red where it's strong, the
		// dark red where it's weaker, with a clean edge. Outlines and the darkest colors stay dark,
		// and glowing colors keep their own.
		float red = clamp((alarm - white) * 2.5, 0.0, 1.0);
		if (red > 0.5 && art.a > 0.0 && shade > 0.12 && palette_glow[palette_index(art.rgb)] < 0.5) {
			if (alarm * (0.6 + shade) > 0.4) {
				lit.rgb = alarm_bright;
			} else if (alarm > 0.12) {
				lit.rgb = alarm_dim;
			}
		}
	}
	COLOR = lit;
}
