# palette_light.gd: fills the uniforms of shaders/palette_light.gdshaderinc from the agency palette:
# each color, the next darker step on its own ramp, and whether it glows. One place says how the
# palette shades, for every shader that lights art. From DESIGN.md, "Lighting" and "Art direction"
# (the locked palette).
class_name PaletteLight
extends RefCounted

## Each ramp, lightest first, by the palette's names. Each color steps down to the next, and the last
## stays put. Near black ends the hull ramp, and the others fall into it.
const RAMPS: Array = [
	[&"hull_lightest", &"hull_lighter", &"hull_light", &"hull_mid", &"hull_dark", &"hull_darkest"],
	[&"gold_light", &"gold", &"gold_dark", &"gold_darkest", &"hull_darkest"],
	[&"agency_orange_light", &"agency_orange", &"agency_orange_dark", &"hull_dark", &"hull_darkest"],
	[&"agency_red", &"agency_orange_dark", &"hull_dark", &"hull_darkest"],
	[&"agency_blue_light", &"agency_blue", &"agency_blue_dark", &"hull_dark", &"hull_darkest"],
	[&"glass_light", &"glass_dark", &"hull_dark", &"hull_darkest"],
]
## What warm light turns the two lightest hull colors to, and a plant's leaves' ramp.
const WARM_FROM: Array = [&"hull_lightest", &"hull_lighter"]
const WARM_TO: Array = [&"gold_light", &"gold"]
const PLANT_RAMP: Array = [&"telemetry_green", &"glass_dark", &"hull_dark"]
## Lights, screens, and flames: they glow, so they never darken.
const GLOWING: Array = [&"telemetry_cyan", &"telemetry_green", &"telemetry_amber", &"thrust_white", &"thrust_yellow", &"thrust_red"]
## The shader's arrays are this long.
const SIZE: int = 32
## The most steps any ramp has, as in the shader.
const MOST_STEPS: int = 5


## A material for this shader, with the palette's ramps filled in.
static func material_for(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	fill(material)
	return material


## The palette's steps for working out lit art in code, the same as the shader: each color, the index of
## its next darker step, and whether it glows.
static func table() -> Dictionary:
	var palette: AgencyPalette = UiStyle.palette()
	var names: Array[StringName] = _names()
	var colors := PackedColorArray()
	var glow := PackedByteArray()
	for color_name: StringName in names:
		colors.append(palette.get(color_name))
		glow.append(1 if GLOWING.has(color_name) else 0)
	return {"colors": colors, "down": _downs(names), "glow": glow}


## A color as this much light leaves it, as palette_lit() in the shader has it: the nearest step on
## its ramp, the same at every pixel.
static func lit_color(color: Color, light: float, steps_table: Dictionary) -> Color:
	if color.a <= 0.0:
		return color
	var colors: PackedColorArray = steps_table["colors"]
	var index: int = 0
	var nearest: float = INF
	for i in range(colors.size()):
		var apart: float = Vector3(color.r - colors[i].r, color.g - colors[i].g, color.b - colors[i].b).length_squared()
		if apart < nearest:
			nearest = apart
			index = i
	if steps_table["glow"][index] == 1:
		return color
	var down: float = (1.0 - clampf(light, 0.0, 1.0)) * MOST_STEPS
	var steps: int = floori(down + 0.5)
	for i in range(steps):
		index = steps_table["down"][index]
	var lit: Color = colors[index]
	lit.a = color.a
	return lit


static func _names() -> Array[StringName]:
	var names: Array[StringName] = []
	for ramp: Array in RAMPS:
		for color_name: StringName in ramp:
			if not names.has(color_name):
				names.append(color_name)
	for color_name: StringName in GLOWING:
		names.append(color_name)
	return names


static func _downs(names: Array[StringName]) -> PackedInt32Array:
	var down := PackedInt32Array()
	for i in range(names.size()):
		down.append(i)
	for ramp: Array in RAMPS:
		for step in range(ramp.size() - 1):
			var from: int = names.find(ramp[step])
			# Only the first ramp a color's on says where it goes, so near black stays near black.
			if down[from] == from:
				down[from] = names.find(ramp[step + 1])
	return down


static func fill(material: ShaderMaterial) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var names: Array[StringName] = _names()
	var colors := PackedVector3Array()
	var glow := PackedFloat32Array()
	for color_name: StringName in names:
		var color: Color = palette.get(color_name)
		colors.append(Vector3(color.r, color.g, color.b))
		glow.append(1.0 if GLOWING.has(color_name) else 0.0)
	var down: PackedInt32Array = _downs(names)
	material.set_shader_parameter("palette_count", names.size())
	colors.resize(SIZE)
	down.resize(SIZE)
	glow.resize(SIZE)
	material.set_shader_parameter("palette_colors", colors)
	material.set_shader_parameter("palette_down", down)
	material.set_shader_parameter("palette_glow", glow)
	material.set_shader_parameter("warm_from", _ramp_colors(palette, WARM_FROM))
	material.set_shader_parameter("warm_to", _ramp_colors(palette, WARM_TO))
	material.set_shader_parameter("plant_ramp", _ramp_colors(palette, PLANT_RAMP))


# A ramp's colors as the shader's arrays have them.
static func _ramp_colors(palette: AgencyPalette, ramp: Array) -> PackedVector3Array:
	var colors := PackedVector3Array()
	for color_name: StringName in ramp:
		var color: Color = palette.get(color_name)
		colors.append(Vector3(color.r, color.g, color.b))
	return colors
