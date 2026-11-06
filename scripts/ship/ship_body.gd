# ship_body.gd: adds up a ship's mass, center of mass, and spin resistance from its pixels.
# From DESIGN.md, "Ships" (each material has a density, and the ship's total mass, center
# of mass, and spin resistance are summed from its pixels).
class_name ShipBody
extends RefCounted

## Total mass, in kilograms.
var mass: float = 0.0
## In pixels, measured from the middle of the art.
var center_of_mass: Vector2 = Vector2.ZERO
## How hard the ship is to spin around its center of mass, the moment of inertia.
var spin_resistance: float = 0.0
## Mass of each module, by grid cell.
var module_masses: Dictionary = {}


## Measures a design's art, pixel by pixel.
static func measure(design: ShipDesign) -> ShipBody:
	var body := ShipBody.new()
	var densities: Dictionary = {}
	for material: MaterialData in design.materials:
		for color: Color in material.colors:
			densities[color.to_html(false)] = material.density

	var image: Image = design.texture.get_image()
	var art_size: Vector2 = Vector2(image.get_size())
	var columns: int = 1
	var rows: int = 1
	for module: ModuleData in design.modules:
		columns = maxi(columns, module.cell.x + 1)
		rows = maxi(rows, module.cell.y + 1)
	var grid_size := Vector2i(columns, rows) * design.cell_size
	var grid_offset: Vector2i = (grid_size - image.get_size()) / 2

	var total_x: float = 0.0
	var total_y: float = 0.0
	var total_r_squared: float = 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			var key: String = color.to_html(false)
			if not densities.has(key):
				push_warning("Ship pixel color %s isn't in any material" % key)
				continue
			var density: float = densities[key]
			var from_middle := Vector2(x + 0.5, y + 0.5) - art_size / 2.0
			body.mass += density
			total_x += density * from_middle.x
			total_y += density * from_middle.y
			total_r_squared += density * from_middle.length_squared()
			var cell: Vector2i = (Vector2i(x, y) + grid_offset) / design.cell_size
			body.module_masses[cell] = body.module_masses.get(cell, 0.0) + density

	if body.mass > 0.0:
		body.center_of_mass = Vector2(total_x, total_y) / body.mass
		body.spin_resistance = total_r_squared - body.mass * body.center_of_mass.length_squared()
	return body
