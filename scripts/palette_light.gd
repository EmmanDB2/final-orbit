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
## Lights, screens, and flames: they glow, so they never darken.
const GLOWING: Array = [&"telemetry_cyan", &"telemetry_green", &"telemetry_amber", &"thrust_white", &"thrust_yellow", &"thrust_red"]
## The shader's arrays are this long.
const SIZE: int = 32


## A material for this shader, with the palette's ramps filled in.
static func material_for(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	fill(material)
	return material


static func fill(material: ShaderMaterial) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var names: Array[StringName] = []
	for ramp: Array in RAMPS:
		for color_name: StringName in ramp:
			if not names.has(color_name):
				names.append(color_name)
	for color_name: StringName in GLOWING:
		names.append(color_name)
	var colors := PackedVector3Array()
	var down := PackedInt32Array()
	var glow := PackedFloat32Array()
	for i in range(names.size()):
		var color: Color = palette.get(names[i])
		colors.append(Vector3(color.r, color.g, color.b))
		down.append(i)
		glow.append(1.0 if GLOWING.has(names[i]) else 0.0)
	for ramp: Array in RAMPS:
		for step in range(ramp.size() - 1):
			var from: int = names.find(ramp[step])
			# Only the first ramp a color's on says where it goes, so near black stays near black.
			if down[from] == from:
				down[from] = names.find(ramp[step + 1])
	material.set_shader_parameter("palette_count", names.size())
	colors.resize(SIZE)
	down.resize(SIZE)
	glow.resize(SIZE)
	material.set_shader_parameter("palette_colors", colors)
	material.set_shader_parameter("palette_down", down)
	material.set_shader_parameter("palette_glow", glow)
