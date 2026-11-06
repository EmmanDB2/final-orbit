// star.gdshader: draws a star as a boiling disc with a stepped glow, on the pixel grid.
// From DESIGN.md, "Art direction" (space is shaders and code; star colors come from the
// star's temperature).
//
// Fills the whole screen and stays transparent outside the glow, like planet.gdshader.
shader_type canvas_item;

// Set by star_view.gd every tick.
uniform vec2 center_px;
uniform float radius_px = 20.0;
uniform float glow_px = 30.0;
// Set by star_view.gd from the star's data.
uniform vec3 star_color : source_color = vec3(1.0);
// Size of the boiling patches on the disc, in pixels.
uniform float patch_px = 4.0;
// How many times a second the patches change.
uniform float boil_rate = 5.0;
// How many flat steps the glow fades through.
uniform float glow_steps = 5.0;
// How strong the glow is right at the rim, from 0 to 1.
uniform float glow_strength = 0.55;

varying vec2 pixel;


float patch_noise(vec2 cell, float frame) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233)) + frame * 37.719) * 43758.5453);
}


void vertex() {
	pixel = VERTEX;
}


void fragment() {
	vec2 whole = floor(pixel);
	float distance_px = length(whole + vec2(0.5) - center_px);
	if (distance_px <= radius_px) {
		// White hot in the middle, taking on the star's color toward the rim.
		float depth = distance_px / radius_px;
		float boil = patch_noise(floor(whole / patch_px), floor(TIME * boil_rate));
		float whiteness = depth < 0.7 ? 0.9 : (depth < 0.92 ? 0.65 : 0.3);
		if (boil < 0.18) {
			whiteness -= 0.2;
		}
		COLOR = vec4(mix(star_color, vec3(1.0), whiteness), 1.0);
	} else if (distance_px <= radius_px + glow_px) {
		// A checker of pixels at each edge keeps the steps from looking like hard rings.
		float reach = 1.0 - (distance_px - radius_px) / glow_px;
		float checker = mod(whole.x + whole.y, 2.0) / glow_steps;
		float step_level = floor((reach * reach + checker * 0.5) * glow_steps) / glow_steps;
		COLOR = vec4(star_color, step_level * glow_strength);
	} else {
		COLOR = vec4(0.0);
	}
}
