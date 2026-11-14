# hull_light.gd: lights a ship's art by the star, through shaders/hull_light.gdshader. Ships are drawn
# flat; their shading comes from their own outline. Across each row of the art, each unbroken run of
# solid pixels is taken as a cylinder, so whatever sticks out, side pods, legs, the bell, curves on its
# own, for any ship, with no extra art. That's worked out once from the ship as it's built, so holes
# shot in it later don't change its shading. From DESIGN.md, "Lighting" (outside).
class_name HullLight
extends RefCounted

const SHADER: Shader = preload("res://shaders/hull_light.gdshader")


## Where across its run each pixel of the art is, from 0 at the run's left edge to 255 at its right,
## with 128 in the middle.
static func across_map(art: Image) -> Image:
	var width: int = art.get_width()
	var height: int = art.get_height()
	var bytes := PackedByteArray()
	bytes.resize(width * height)
	bytes.fill(128)
	for y in range(height):
		var x: int = 0
		while x < width:
			if art.get_pixel(x, y).a <= 0.0:
				x += 1
				continue
			var start: int = x
			while x < width and art.get_pixel(x, y).a > 0.0:
				x += 1
			var half: float = (x - start) / 2.0
			var middle: float = start + half
			for i in range(start, x):
				var across: float = clampf((i + 0.5 - middle) / half, -1.0, 1.0)
				bytes[y * width + i] = int(roundf((across * 0.5 + 0.5) * 255.0))
	return Image.create_from_data(width, height, false, Image.FORMAT_L8, bytes)


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
