# hull_light.gd: lights art by the star, through shaders/hull_light.gdshader: ships, and stations from
# outside. Hulls are drawn flat; their shading comes from their own outline. Each unbroken run of solid
# pixels, across a row or down a column, is taken as a cylinder, and each pixel takes whichever of its
# two runs is shorter, the way across its part rather than along it. So whatever sticks out, side
# pods, legs, the bell, a station's arms, curves on its own, for any art, with nothing extra drawn.
# That's worked out once from the art as it's built, so holes shot in it later don't change its
# shading. From DESIGN.md, "Lighting" (outside).
class_name HullLight
extends RefCounted

const SHADER: Shader = preload("res://shaders/hull_light.gdshader")


## Where each pixel of the art is across its run: red across its row, from 0 at the left to 255 at
## the right, green down its column, from 0 at the top to 255 at the bottom, and blue 255 where the
## row's run is the shorter, so the curve goes across, or 0 where it goes down.
static func across_map(art: Image) -> Image:
	var width: int = art.get_width()
	var height: int = art.get_height()
	var solid := PackedByteArray()
	solid.resize(width * height)
	var data: PackedByteArray = art.get_data() if art.get_format() == Image.FORMAT_RGBA8 else _rgba(art).get_data()
	for i in range(width * height):
		solid[i] = 1 if data[i * 4 + 3] > 0 else 0
	var across := PackedFloat32Array()
	across.resize(width * height)
	var row_run := PackedInt32Array()
	row_run.resize(width * height)
	var down := PackedFloat32Array()
	down.resize(width * height)
	var column_run := PackedInt32Array()
	column_run.resize(width * height)
	for y in range(height):
		var x: int = 0
		while x < width:
			if solid[y * width + x] == 0:
				x += 1
				continue
			var start: int = x
			while x < width and solid[y * width + x] == 1:
				x += 1
			for i in range(start, x):
				across[y * width + i] = _place(i, start, x)
				row_run[y * width + i] = x - start
	for x in range(width):
		var y: int = 0
		while y < height:
			if solid[y * width + x] == 0:
				y += 1
				continue
			var start: int = y
			while y < height and solid[y * width + x] == 1:
				y += 1
			for i in range(start, y):
				down[i * width + x] = _place(i, start, y)
				column_run[i * width + x] = y - start
	var bytes := PackedByteArray()
	bytes.resize(width * height * 3)
	for i in range(width * height):
		bytes[i * 3] = int(roundf((across[i] * 0.5 + 0.5) * 255.0))
		bytes[i * 3 + 1] = int(roundf((down[i] * 0.5 + 0.5) * 255.0))
		bytes[i * 3 + 2] = 255 if row_run[i] <= column_run[i] else 0
	return Image.create_from_data(width, height, false, Image.FORMAT_RGB8, bytes)


# Where a pixel sits along a run from start to end, from -1 to 1.
static func _place(at: int, start: int, end: int) -> float:
	var half: float = (end - start) / 2.0
	return clampf((at + 0.5 - (start + half)) / half, -1.0, 1.0)


static func _rgba(art: Image) -> Image:
	var copy: Image = art.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	return copy


## A material that lights this art, with its curvature worked out.
static func material_for(art: Image) -> ShaderMaterial:
	var material: ShaderMaterial = PaletteLight.material_for(SHADER)
	material.set_shader_parameter("across_map", ImageTexture.create_from_image(across_map(art)))
	return material


## Points a lit sprite's light at a point in the world, given where the sprite is and how it's turned
## there, and how much of the star can be seen.
static func aim(sprite: CanvasItem, toward: Vector2, sun: float) -> void:
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("light_dir", toward.rotated(-sprite.global_rotation))
	material.set_shader_parameter("sun", sun)
