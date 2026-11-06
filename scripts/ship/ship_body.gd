# ship_body.gd: a ship's pixels: which are left, and the mass, center of mass, and spin
# resistance they add up to.
# From DESIGN.md, "Ships" (each material has a density, and the ship's totals are summed
# from its pixels) and "Destruction" (damage erases pixels, and a connectivity check splits
# off any piece no longer attached).
class_name ShipBody
extends RefCounted

## Pixels are grouped into square cells this wide for the connectivity check, and touching
## cells count as attached. It's faster than checking every pixel, and it holds together
## parts the art draws with a pixel or two of gap, such as the engine bell.
const CONNECT_CELL: int = 3

## Total mass, in kilograms.
var mass: float = 0.0
## In pixels, measured from the middle of the art.
var center_of_mass: Vector2 = Vector2.ZERO
## How hard the ship is to spin around its center of mass, the moment of inertia.
var spin_resistance: float = 0.0
## Mass of each module, by grid cell.
var module_masses: Dictionary = {}
## Total fuel the tanks can hold now, in kilograms.
var fuel_capacity: float = 0.0
## What the tanks held when the ship was whole.
var original_fuel_capacity: float = 0.0
## How wide and long what's left of the art is, in pixels. Sets how much air the ship pushes.
var width: float = 0.0
var length: float = 0.0
## How many pixels are left.
var pixel_count: int = 0
## The art as it is now, with erased pixels transparent.
var image: Image
## The design's modules, in the order module_share counts them.
var modules: Array[ModuleData] = []
## Each tank: "position" from the middle of the art, "capacity" left, what it held when
## "full", and its "module" index.
var tanks: Array[Dictionary] = []

var _width: int = 0
var _height: int = 0
var _total_x: float = 0.0
var _total_y: float = 0.0
var _total_r_squared: float = 0.0
var _grid_offset: Vector2i = Vector2i.ZERO
var _cell_size: int = 64
# Per pixel, row by row. A density of zero means the pixel is gone.
var _density: PackedFloat32Array = PackedFloat32Array()
var _strength: PackedFloat32Array = PackedFloat32Array()
var _module_of: PackedInt32Array = PackedInt32Array()
# Per module.
var _module_start: PackedInt32Array = PackedInt32Array()
var _module_left: PackedInt32Array = PackedInt32Array()
var _module_hole: PackedVector2Array = PackedVector2Array()
var _outline: PackedVector2Array = PackedVector2Array()


## Measures a design's art, pixel by pixel.
static func measure(design: ShipDesign) -> ShipBody:
	var body := ShipBody.new()
	var materials: Dictionary = {}
	for material: MaterialData in design.materials:
		for color: Color in material.colors:
			materials[color.to_html(false)] = material

	body.image = design.texture.get_image().duplicate()
	if body.image.is_compressed():
		body.image.decompress()
	body.image.convert(Image.FORMAT_RGBA8)
	body.modules = design.modules
	body._cell_size = design.cell_size
	body._width = body.image.get_width()
	body._height = body.image.get_height()

	var module_at: Dictionary = {}
	var columns: int = 1
	var rows: int = 1
	for i in range(design.modules.size()):
		var module: ModuleData = design.modules[i]
		module_at[module.cell] = i
		columns = maxi(columns, module.cell.x + 1)
		rows = maxi(rows, module.cell.y + 1)
	var grid_size := Vector2i(columns, rows) * design.cell_size
	body._grid_offset = (grid_size - body.image.get_size()) / 2
	body._module_start.resize(design.modules.size())
	body._module_start.fill(0)
	body._module_hole.resize(design.modules.size())

	var total_pixels: int = body._width * body._height
	body._density.resize(total_pixels)
	body._density.fill(0.0)
	body._strength.resize(total_pixels)
	body._strength.fill(0.0)
	body._module_of.resize(total_pixels)
	body._module_of.fill(-1)

	for y in range(body._height):
		for x in range(body._width):
			var color: Color = body.image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			var key: String = color.to_html(false)
			if not materials.has(key):
				push_warning("Ship pixel color %s isn't in any material" % key)
				continue
			var material: MaterialData = materials[key]
			var index: int = y * body._width + x
			var from_middle: Vector2 = body._from_middle(index)
			body._density[index] = material.density
			body._strength[index] = material.strength
			body.mass += material.density
			body._total_x += material.density * from_middle.x
			body._total_y += material.density * from_middle.y
			body._total_r_squared += material.density * from_middle.length_squared()
			body.pixel_count += 1
			var cell: Vector2i = (Vector2i(x, y) + body._grid_offset) / design.cell_size
			body.module_masses[cell] = body.module_masses.get(cell, 0.0) + material.density
			if module_at.has(cell):
				var module_index: int = module_at[cell]
				body._module_of[index] = module_index
				body._module_start[module_index] += 1

	body._module_left = body._module_start.duplicate()
	for i in range(design.modules.size()):
		var module: ModuleData = design.modules[i]
		if module.fuel_capacity > 0.0:
			var middle: Vector2 = (Vector2(module.cell) + Vector2(0.5, 0.5)) * design.cell_size - Vector2(grid_size) / 2.0
			body.tanks.append({"position": middle, "capacity": module.fuel_capacity, "full": module.fuel_capacity, "module": i})
			body.fuel_capacity += module.fuel_capacity
	body.original_fuel_capacity = body.fuel_capacity
	body._refresh()
	return body


## The ship's mass and spin resistance with this much fuel aboard, shared across its tanks.
## Fuel has mass and burns off, so ships get lighter and more agile as they fly.
func with_fuel(fuel: float) -> Dictionary:
	var share: float = fuel / fuel_capacity if fuel_capacity > 0.0 else 0.0
	var total_mass: float = mass
	var total_x: float = _total_x
	var total_y: float = _total_y
	var total_r_squared: float = _total_r_squared
	for tank: Dictionary in tanks:
		var tank_mass: float = tank["capacity"] * share
		var tank_position: Vector2 = tank["position"]
		total_mass += tank_mass
		total_x += tank_mass * tank_position.x
		total_y += tank_mass * tank_position.y
		total_r_squared += tank_mass * tank_position.length_squared()
	if total_mass <= 0.0:
		return {"mass": 1.0, "center_of_mass": Vector2.ZERO, "spin_resistance": 1.0}
	var center := Vector2(total_x, total_y) / total_mass
	return {
		"mass": total_mass,
		"center_of_mass": center,
		"spin_resistance": maxf(total_r_squared - total_mass * center.length_squared(), 1.0),
	}


## How much of a module's pixels are left, from 0 to 1.
func module_share(module_index: int) -> float:
	var start: int = _module_start[module_index]
	return float(_module_left[module_index]) / start if start > 0 else 0.0


## The middle of the pixels a module has lost, from the middle of the art.
func module_hole(module_index: int) -> Vector2:
	var lost: int = _module_start[module_index] - _module_left[module_index]
	return _module_hole[module_index] / lost if lost > 0 else Vector2.ZERO


## The pixel left in a module that's closest to a point, from the middle of the art. Returns
## the point itself if the module has nothing left.
func nearest_in_module(module_index: int, point: Vector2) -> Vector2:
	var best: Vector2 = point
	var best_distance: float = INF
	for index in range(_density.size()):
		if _density[index] > 0.0 and _module_of[index] == module_index:
			var at: Vector2 = _from_middle(index)
			var distance: float = at.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				best = at
	return best


## Takes capacity out of a tank.
func cut_tank(tank: Dictionary, amount: float) -> void:
	var cut: float = minf(amount, tank["capacity"])
	tank["capacity"] -= cut
	fuel_capacity -= cut


## Whether there's a pixel at this point, measured from the middle of the art.
func has_pixel(point: Vector2) -> bool:
	var x: int = floori(point.x + _width / 2.0)
	var y: int = floori(point.y + _height / 2.0)
	if x < 0 or y < 0 or x >= _width or y >= _height:
		return false
	return _density[y * _width + x] > 0.0


## How far the ship reaches in a direction from a point, measured from the middle of the art.
## This is what touches the ground first.
func reach(from: Vector2, direction: Vector2) -> float:
	var farthest: float = 0.0
	for point: Vector2 in _outline:
		farthest = maxf(farthest, (point - from).dot(direction))
	return farthest


## Crushes the ship from one side, as flat ground does. Spends energy on the pixels farthest
## along the direction first, and returns what was erased as "points" and "colors".
func crush(direction: Vector2, energy: float, damage_seed: int) -> Dictionary:
	var order := PackedInt32Array()
	var ranks := PackedInt32Array()
	for index in range(_density.size()):
		if _density[index] > 0.0:
			order.append(index)
			ranks.append(floori(_from_middle(index).dot(direction)) + _jitter(index, damage_seed))
	return _erase_in_order(order, ranks, energy)


## Knocks a dent in the ship at a point, as a small hard object does. Spends energy on the
## pixels nearest it first, and returns what was erased as "points" and "colors".
func dent(point: Vector2, energy: float, damage_seed: int) -> Dictionary:
	var order := PackedInt32Array()
	var ranks := PackedInt32Array()
	for index in range(_density.size()):
		if _density[index] > 0.0:
			order.append(index)
			ranks.append(_jitter(index, damage_seed) - floori(_from_middle(index).distance_to(point)))
	return _erase_in_order(order, ranks, energy)


## Removes every piece no longer attached and returns them, biggest first. The piece with the
## most cockpit in it stays as the ship, or the biggest one if the cockpit's gone. Each has an
## "image", its "center" from the middle of the art, its "mass", its "pixel_count", and its
## pixels as "points" and "colors".
func split_off() -> Array[Dictionary]:
	var columns: int = ceili(float(_width) / CONNECT_CELL)
	var rows: int = ceili(float(_height) / CONNECT_CELL)
	var cell_piece := PackedInt32Array()
	cell_piece.resize(columns * rows)
	cell_piece.fill(-1)
	const UNLABELED: int = -2
	for index in range(_density.size()):
		if _density[index] > 0.0:
			cell_piece[(index / _width) / CONNECT_CELL * columns + (index % _width) / CONNECT_CELL] = UNLABELED

	var piece_count: int = 0
	for start in range(cell_piece.size()):
		if cell_piece[start] != UNLABELED:
			continue
		var stack := PackedInt32Array([start])
		cell_piece[start] = piece_count
		while not stack.is_empty():
			var at: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var cx: int = at % columns
			var cy: int = at / columns
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx >= 0 and ny >= 0 and nx < columns and ny < rows and cell_piece[ny * columns + nx] == UNLABELED:
						cell_piece[ny * columns + nx] = piece_count
						stack.append(ny * columns + nx)
		piece_count += 1

	var pieces: Array[Dictionary] = []
	if piece_count <= 1:
		return pieces

	var counts := PackedInt32Array()
	counts.resize(piece_count)
	counts.fill(0)
	var cockpit := PackedInt32Array()
	cockpit.resize(piece_count)
	cockpit.fill(0)
	for index in range(_density.size()):
		if _density[index] > 0.0:
			var piece: int = cell_piece[(index / _width) / CONNECT_CELL * columns + (index % _width) / CONNECT_CELL]
			counts[piece] += 1
			var module_index: int = _module_of[index]
			if module_index >= 0 and modules[module_index].kind == "cockpit":
				cockpit[piece] += 1

	var main: int = 0
	for piece in range(piece_count):
		if cockpit[piece] > cockpit[main] or (cockpit[piece] == cockpit[main] and counts[piece] > counts[main]):
			main = piece

	for piece in range(piece_count):
		if piece != main:
			pieces.append({
				"mass": 0.0,
				"pixel_count": counts[piece],
				"points": PackedVector2Array(),
				"colors": PackedColorArray(),
				"low": Vector2i(_width, _height),
				"high": Vector2i(-1, -1),
				"id": piece,
			})
	var entry_of: Dictionary = {}
	for i in range(pieces.size()):
		entry_of[pieces[i]["id"]] = pieces[i]
	for index in range(_density.size()):
		if _density[index] <= 0.0:
			continue
		var piece: int = cell_piece[(index / _width) / CONNECT_CELL * columns + (index % _width) / CONNECT_CELL]
		if piece == main:
			continue
		var entry: Dictionary = entry_of[piece]
		var x: int = index % _width
		var y: int = index / _width
		entry["mass"] += _density[index]
		entry["points"].append(Vector2(x, y))
		entry["colors"].append(image.get_pixel(x, y))
		entry["low"] = Vector2i(mini(entry["low"].x, x), mini(entry["low"].y, y))
		entry["high"] = Vector2i(maxi(entry["high"].x, x), maxi(entry["high"].y, y))
		_erase(index)

	for entry: Dictionary in pieces:
		var low: Vector2i = entry["low"]
		var piece_size: Vector2i = entry["high"] - low + Vector2i.ONE
		var piece_image := Image.create(piece_size.x, piece_size.y, false, Image.FORMAT_RGBA8)
		var points: PackedVector2Array = entry["points"]
		var colors: PackedColorArray = entry["colors"]
		for i in range(points.size()):
			piece_image.set_pixel(int(points[i].x) - low.x, int(points[i].y) - low.y, colors[i])
		entry["image"] = piece_image
		entry["center"] = Vector2(low) + Vector2(piece_size) / 2.0 - Vector2(_width, _height) / 2.0
		for i in range(points.size()):
			points[i] += Vector2(0.5, 0.5) - Vector2(_width, _height) / 2.0
		entry["points"] = points
	_refresh()
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pixel_count"] > b["pixel_count"])
	return pieces


func _from_middle(index: int) -> Vector2:
	return Vector2(index % _width + 0.5, index / _width + 0.5) - Vector2(_width, _height) / 2.0


# A repeatable small number per pixel, so a crushed edge is jagged instead of ruled.
func _jitter(index: int, damage_seed: int) -> int:
	return ((index * 2654435761 + damage_seed * 40503) >> 7) & 7


func _erase(index: int) -> void:
	var density: float = _density[index]
	var from_middle: Vector2 = _from_middle(index)
	mass -= density
	_total_x -= density * from_middle.x
	_total_y -= density * from_middle.y
	_total_r_squared -= density * from_middle.length_squared()
	_density[index] = 0.0
	pixel_count -= 1
	var x: int = index % _width
	var y: int = index / _width
	image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	var cell: Vector2i = (Vector2i(x, y) + _grid_offset) / _cell_size
	module_masses[cell] = module_masses.get(cell, 0.0) - density
	var module_index: int = _module_of[index]
	if module_index >= 0:
		_module_left[module_index] -= 1
		_module_hole[module_index] += from_middle


# Erases highest rank first until the energy runs out. A counting sort, since the ranks are
# whole numbers in a small range and there are thousands of pixels.
func _erase_in_order(order: PackedInt32Array, ranks: PackedInt32Array, energy: float) -> Dictionary:
	var erased := {"points": PackedVector2Array(), "colors": PackedColorArray()}
	if order.is_empty():
		return erased
	var lowest: int = ranks[0]
	var highest: int = ranks[0]
	for rank: int in ranks:
		lowest = mini(lowest, rank)
		highest = maxi(highest, rank)
	var counts := PackedInt32Array()
	counts.resize(highest - lowest + 2)
	counts.fill(0)
	for rank: int in ranks:
		counts[highest - rank + 1] += 1
	for i in range(1, counts.size()):
		counts[i] += counts[i - 1]
	var sorted := PackedInt32Array()
	sorted.resize(order.size())
	for i in range(order.size()):
		var slot: int = highest - ranks[i]
		sorted[counts[slot]] = order[i]
		counts[slot] += 1

	var left: float = energy
	for index: int in sorted:
		var cost: float = _strength[index]
		if cost > left:
			break
		left -= cost
		erased["points"].append(_from_middle(index))
		erased["colors"].append(image.get_pixel(index % _width, index / _width))
		_erase(index)
	if not erased["points"].is_empty():
		_refresh()
	return erased


# Works out the totals that come from the whole set of pixels.
func _refresh() -> void:
	if mass > 0.0:
		center_of_mass = Vector2(_total_x, _total_y) / mass
		spin_resistance = maxf(_total_r_squared - mass * center_of_mass.length_squared(), 0.0)
	else:
		center_of_mass = Vector2.ZERO
		spin_resistance = 0.0

	# Each row's two ends are enough to find the outline.
	var edge_points := PackedVector2Array()
	var half := Vector2(_width, _height) / 2.0
	for y in range(_height):
		var first: int = -1
		var last: int = -1
		for x in range(_width):
			if _density[y * _width + x] > 0.0:
				if first < 0:
					first = x
				last = x
		if first >= 0:
			edge_points.append(Vector2(first, y) - half)
			edge_points.append(Vector2(first, y + 1) - half)
			edge_points.append(Vector2(last + 1, y) - half)
			edge_points.append(Vector2(last + 1, y + 1) - half)
	_outline = Geometry2D.convex_hull(edge_points) if edge_points.size() >= 3 else edge_points
	var low := Vector2(_width, _height)
	var high := -low
	for point: Vector2 in _outline:
		low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	width = maxf(high.x - low.x, 0.0)
	length = maxf(high.y - low.y, 0.0)
