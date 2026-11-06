# ship_body.gd: a ship's pixels: which are left, and the mass, center of mass, and spin
# resistance they add up to.
# From DESIGN.md, "Ships" (each module is a pixel mask, each material has a density, and the
# ship's totals are summed from its pixels) and "Destruction" (damage erases pixels, and a
# connectivity check splits off any piece no longer attached).
#
# The modules on the grid are drawn together as one layer. A part that moves, such as a
# landing leg, is a layer of its own that can be somewhere else while its pixels stay the same.
# Mass always counts a moving part where it's stowed, since it's tiny next to the whole ship.
class_name ShipBody
extends RefCounted

## One set of pixels drawn and moved together.
class Layer:
	var image: Image
	var top_left: Vector2i = Vector2i.ZERO
	var lookup: PackedInt32Array = PackedInt32Array()
	var outline: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = Vector2.ZERO
	var module: int = -1
	var moves: bool = false
	var folds: bool = false
	var hinge_home: Vector2 = Vector2.ZERO
	var hinge_now: Vector2 = Vector2.ZERO
	var travel: Vector2 = Vector2.ZERO
	var fold: float = 1.0

	## Where a point on this layer's stowed art is right now.
	func place(home: Vector2) -> Vector2:
		if not moves:
			return home
		var from_hinge: Vector2 = home - hinge_home
		return hinge_now + Vector2(from_hinge.x, from_hinge.y * fold)

	## Where on this layer's stowed art a point is right now. A part edge-on covers nothing.
	func unplace(point: Vector2) -> Vector2:
		if not moves:
			return point
		var from_hinge: Vector2 = point - hinge_now
		if absf(fold) < 0.2:
			return Vector2(INF, INF)
		return hinge_home + Vector2(from_hinge.x, from_hinge.y / fold)


## Pixels are grouped into square cells this wide for the connectivity check, and touching
## cells count as attached. It's faster than checking every pixel, and it holds together
## parts the art draws with a pixel or two of gap, such as the engine bell.
const CONNECT_CELL: int = 3

## Total mass, in kilograms.
var mass: float = 0.0
## In pixels, measured from the middle of the ship's grid.
var center_of_mass: Vector2 = Vector2.ZERO
## How hard the ship is to spin around its center of mass, the moment of inertia.
var spin_resistance: float = 0.0
## Mass of each module, by its place in modules.
var module_masses: Dictionary = {}
## Total fuel the tanks can hold now, in kilograms.
var fuel_capacity: float = 0.0
## What the tanks held when the ship was whole.
var original_fuel_capacity: float = 0.0
## How wide and long what's left of the ship is, in pixels. Sets how much air it pushes.
var width: float = 0.0
var length: float = 0.0
## How many pixels are left.
var pixel_count: int = 0
## The design's modules, in the order module_share counts them.
var modules: Array[ModuleData] = []
## Each tank: "position" from the middle of the grid, "capacity" left, what it held when
## "full", and its "module" index.
var tanks: Array[Dictionary] = []
## Per pixel: which layer it's on, and where on that layer's art.
var pixel_layer: PackedByteArray = PackedByteArray()
var pixel_x: PackedInt32Array = PackedInt32Array()
var pixel_y: PackedInt32Array = PackedInt32Array()

var _half: Vector2 = Vector2.ZERO
var _canvas: Vector2i = Vector2i.ZERO
var _cell_size: int = 64
var _layers: Array[Layer] = []
var _total_x: float = 0.0
var _total_y: float = 0.0
var _total_r_squared: float = 0.0
# Per pixel. A density of zero means the pixel is gone.
var _density: PackedFloat32Array = PackedFloat32Array()
var _strength: PackedFloat32Array = PackedFloat32Array()
var _module_of: PackedInt32Array = PackedInt32Array()
var _home: PackedVector2Array = PackedVector2Array()
var _color: PackedColorArray = PackedColorArray()
var _is_working: PackedByteArray = PackedByteArray()
var _is_nozzle: PackedByteArray = PackedByteArray()
# Per module.
var _module_start: PackedInt32Array = PackedInt32Array()
var _module_left: PackedInt32Array = PackedInt32Array()
var _working_start: PackedInt32Array = PackedInt32Array()
var _working_left: PackedInt32Array = PackedInt32Array()
var _nozzle_start: PackedInt32Array = PackedInt32Array()
var _nozzle_left: PackedInt32Array = PackedInt32Array()
var _module_hole: PackedVector2Array = PackedVector2Array()


## Puts a design's modules together and measures them, pixel by pixel.
static func measure(design: ShipDesign) -> ShipBody:
	var body := ShipBody.new()
	var materials: Dictionary = {}
	for material: MaterialData in design.materials:
		for color: Color in material.colors:
			materials[color.to_html(false)] = material

	body.modules = design.modules
	body._cell_size = design.cell_size
	var columns: int = 1
	var rows: int = 1
	for module: ModuleData in design.modules:
		if module.on_grid:
			columns = maxi(columns, module.cell.x + 1)
			rows = maxi(rows, module.cell.y + 1)
	body._canvas = Vector2i(columns, rows) * design.cell_size
	body._half = Vector2(body._canvas) / 2.0

	var grid_layer := Layer.new()
	grid_layer.image = Image.create(body._canvas.x, body._canvas.y, false, Image.FORMAT_RGBA8)
	grid_layer.lookup.resize(body._canvas.x * body._canvas.y)
	grid_layer.lookup.fill(-1)
	grid_layer.center = Vector2.ZERO
	body._layers.append(grid_layer)

	var count: int = design.modules.size()
	for list: PackedInt32Array in [body._module_start, body._module_left, body._working_start, body._working_left, body._nozzle_start, body._nozzle_left]:
		list.resize(count)
		list.fill(0)
	body._module_hole.resize(count)
	for i in range(count):
		body._add_module(i, design.modules[i], materials)
	body._module_left = body._module_start.duplicate()
	body._working_left = body._working_start.duplicate()
	body._nozzle_left = body._nozzle_start.duplicate()

	for i in range(count):
		var module: ModuleData = design.modules[i]
		if module.fuel_capacity > 0.0:
			var middle: Vector2 = (Vector2(module.cell) + Vector2(0.5, 0.5)) * design.cell_size - body._half
			body.tanks.append({"position": middle, "capacity": module.fuel_capacity, "full": module.fuel_capacity, "module": i})
			body.fuel_capacity += module.fuel_capacity
	body.original_fuel_capacity = body.fuel_capacity
	body._refresh()
	return body


func _add_module(index: int, module: ModuleData, materials: Dictionary) -> void:
	var art: Image = module.texture.get_image().duplicate()
	if art.is_compressed():
		art.decompress()
	art.convert(Image.FORMAT_RGBA8)

	var layer: Layer = _layers[0]
	var layer_index: int = 0
	var offset: Vector2i = module.cell * _cell_size
	if not module.on_grid:
		layer = Layer.new()
		layer.image = Image.create(art.get_width(), art.get_height(), false, Image.FORMAT_RGBA8)
		layer.lookup.resize(art.get_width() * art.get_height())
		layer.lookup.fill(-1)
		layer.top_left = module.art_position
		layer.center = Vector2(module.art_position) + Vector2(art.get_size()) / 2.0 - _half
		layer.module = index
		layer.moves = true
		layer.folds = module.folds
		layer.hinge_home = Vector2(module.hinge) - _half
		layer.hinge_now = layer.hinge_home
		layer.travel = Vector2(module.travel)
		layer_index = _layers.size()
		_layers.append(layer)
		offset = Vector2i.ZERO

	var layer_width: int = layer.image.get_width()
	for y in range(art.get_height()):
		for x in range(art.get_width()):
			var color: Color = art.get_pixel(x, y)
			if color.a < 0.5:
				continue
			var key: String = color.to_html(false)
			if not materials.has(key):
				push_warning("Ship pixel color %s isn't in any material" % key)
				continue
			var material: MaterialData = materials[key]
			var at := Vector2i(x, y) + offset
			var home: Vector2 = Vector2(layer.top_left + at) + Vector2(0.5, 0.5) - _half
			layer.image.set_pixel(at.x, at.y, color)
			layer.lookup[at.y * layer_width + at.x] = _density.size()
			_density.append(material.density)
			_strength.append(material.strength)
			_module_of.append(index)
			_home.append(home)
			_color.append(color)
			pixel_layer.append(layer_index)
			pixel_x.append(at.x)
			pixel_y.append(at.y)
			var working: bool = not module.working_rect.has_area() or module.working_rect.has_point(Vector2i(x, y))
			var nozzle: bool = module.nozzle_rect.has_area() and module.nozzle_rect.has_point(Vector2i(x, y))
			_is_working.append(1 if working else 0)
			_is_nozzle.append(1 if nozzle else 0)
			mass += material.density
			_total_x += material.density * home.x
			_total_y += material.density * home.y
			_total_r_squared += material.density * home.length_squared()
			pixel_count += 1
			module_masses[index] = module_masses.get(index, 0.0) + material.density
			_module_start[index] += 1
			if working:
				_working_start[index] += 1
			if nozzle:
				_nozzle_start[index] += 1


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


## How much of the pixels that do a module's job are left, from 0 to 1.
func working_share(module_index: int) -> float:
	var start: int = _working_start[module_index]
	return float(_working_left[module_index]) / start if start > 0 else 0.0


## How much of a module's RCS nozzle is left, from 0 to 1. Zero if it hasn't got one.
func nozzle_share(module_index: int) -> float:
	var start: int = _nozzle_start[module_index]
	return float(_nozzle_left[module_index]) / start if start > 0 else 0.0


## Where gas leaves a module's RCS nozzle, from the middle of the grid.
func nozzle_point(module_index: int) -> Vector2:
	var module: ModuleData = modules[module_index]
	return Vector2(module.cell * _cell_size) + module.nozzle_point - _half


## The middle of the pixels a module has lost, from the middle of the grid.
func module_hole(module_index: int) -> Vector2:
	var lost: int = _module_start[module_index] - _module_left[module_index]
	return _module_hole[module_index] / lost if lost > 0 else Vector2.ZERO


## The pixel left in a module that's closest to a point, from the middle of the grid. Returns
## the point itself if the module has nothing left.
func nearest_in_module(module_index: int, point: Vector2) -> Vector2:
	var best: Vector2 = point
	var best_distance: float = INF
	for index in range(_density.size()):
		if _density[index] > 0.0 and _module_of[index] == module_index:
			var at: Vector2 = position_of(index)
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


## Where a pixel is right now, from the middle of the grid.
func position_of(index: int) -> Vector2:
	var layer_index: int = pixel_layer[index]
	return _home[index] if layer_index == 0 else _layers[layer_index].place(_home[index])


func layer_count() -> int:
	return _layers.size()


## A layer's art as it is now, with erased pixels transparent.
func layer_image(layer_index: int) -> Image:
	return _layers[layer_index].image


## Where the middle of a layer's art is right now, from the middle of the grid.
func layer_center(layer_index: int) -> Vector2:
	var layer: Layer = _layers[layer_index]
	return layer.place(layer.center)


## How far over a layer is folded: 1 is as drawn, and -1 is upside down.
func layer_fold(layer_index: int) -> float:
	return _layers[layer_index].fold


## Moves every moving part, from 0 for stowed to 1 for fully out. Parts fold over in the first
## half of the way, and the whole way they stay on whole pixels.
func set_parts_out(share: float) -> void:
	for layer: Layer in _layers:
		if layer.moves:
			layer.hinge_now = (layer.hinge_home + layer.travel * share).round()
			if layer.folds:
				layer.fold = cos(PI * minf(share * 2.0, 1.0))
	_update_size()


## What's holding each moving part out, as pairs of points from the middle of the grid: where
## it's mounted, and where its hinge has got to. Only for parts that still work.
func part_struts(dead_share: float) -> Array:
	var struts: Array = []
	for layer: Layer in _layers:
		if layer.moves and layer.hinge_now != layer.hinge_home and module_share(layer.module) >= dead_share:
			struts.append([layer.hinge_home, layer.hinge_now])
	return struts


## How far the ship tips when it comes to rest on the ground, in radians, from standing on the
## flat of its outline. Of the sides it could stay balanced on, the one nearest upright wins.
func rest_angle() -> float:
	var points := PackedVector2Array()
	for layer: Layer in _layers:
		for point: Vector2 in layer.outline:
			points.append(layer.place(point))
	if points.size() < 3:
		return 0.0
	var around: PackedVector2Array = Geometry2D.convex_hull(points)
	var best: float = INF
	for i in range(around.size() - 1):
		var edge: Vector2 = around[i + 1] - around[i]
		var edge_squared: float = edge.length_squared()
		if edge_squared < 1.0:
			continue
		var along: float = (center_of_mass - around[i]).dot(edge) / edge_squared
		if along < 0.0 or along > 1.0:
			continue
		var outward: Vector2 = edge.orthogonal().normalized()
		if outward.dot(around[i] - center_of_mass) < 0.0:
			outward = -outward
		var angle: float = Vector2.DOWN.angle_to(outward)
		if absf(angle) < absf(best):
			best = angle
	if best == INF or absf(best) < 0.02:
		return 0.0
	return best


## Whether there's a pixel at this point, measured from the middle of the grid.
func has_pixel(point: Vector2) -> bool:
	for layer: Layer in _layers:
		var home: Vector2 = layer.unplace(point)
		if home.x == INF:
			continue
		var on_art: Vector2 = home + _half - Vector2(layer.top_left)
		var x: int = floori(on_art.x)
		var y: int = floori(on_art.y)
		var art_width: int = layer.image.get_width()
		if x < 0 or y < 0 or x >= art_width or y >= layer.image.get_height():
			continue
		var index: int = layer.lookup[y * art_width + x]
		if index >= 0 and _density[index] > 0.0:
			return true
	return false


## How far the ship reaches in a direction from a point, measured from the middle of the grid.
## This is what touches the ground first.
func reach(from: Vector2, direction: Vector2) -> float:
	var farthest: float = 0.0
	for layer: Layer in _layers:
		for point: Vector2 in layer.outline:
			farthest = maxf(farthest, (layer.place(point) - from).dot(direction))
	return farthest


## Crushes the ship from one side, as flat ground does. Spends energy on the pixels farthest
## along the direction first, and returns what was erased as "pixels", "points", and "colors".
func crush(direction: Vector2, energy: float, damage_seed: int) -> Dictionary:
	var order := PackedInt32Array()
	var ranks := PackedInt32Array()
	for index in range(_density.size()):
		if _density[index] > 0.0:
			order.append(index)
			ranks.append(floori(position_of(index).dot(direction)) + _jitter(index, damage_seed))
	return _erase_in_order(order, ranks, energy)


## Knocks a dent in the ship at a point, as a small hard object does. Spends energy on the
## pixels nearest it first, and returns what was erased as "pixels", "points", and "colors".
func dent(point: Vector2, energy: float, damage_seed: int) -> Dictionary:
	var order := PackedInt32Array()
	var ranks := PackedInt32Array()
	for index in range(_density.size()):
		if _density[index] > 0.0:
			order.append(index)
			ranks.append(_jitter(index, damage_seed) - floori(position_of(index).distance_to(point)))
	return _erase_in_order(order, ranks, energy)


## Removes every piece no longer attached and returns them, biggest first. The piece with the
## most cockpit in it stays as the ship, or the biggest one if the cockpit's gone. Each has an
## "image", its "center" from the middle of the grid, its "mass", its "pixel_count", and its
## pixels as "pixels", "points", and "colors". Whether pieces touch goes by where they're
## stowed, since a moving part stays attached however far out it is.
func split_off() -> Array[Dictionary]:
	var columns: int = ceili(float(_canvas.x) / CONNECT_CELL)
	var rows: int = ceili(float(_canvas.y) / CONNECT_CELL)
	var cell_piece := PackedInt32Array()
	cell_piece.resize(columns * rows)
	cell_piece.fill(-1)
	const UNLABELED: int = -2
	for index in range(_density.size()):
		if _density[index] > 0.0:
			cell_piece[_connect_cell(index, columns)] = UNLABELED

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
			var piece: int = cell_piece[_connect_cell(index, columns)]
			counts[piece] += 1
			if modules[_module_of[index]].kind == "cockpit":
				cockpit[piece] += 1

	var main: int = 0
	for piece in range(piece_count):
		if cockpit[piece] > cockpit[main] or (cockpit[piece] == cockpit[main] and counts[piece] > counts[main]):
			main = piece

	var entry_of: Dictionary = {}
	for piece in range(piece_count):
		if piece != main:
			var entry := {
				"mass": 0.0,
				"pixel_count": counts[piece],
				"pixels": PackedInt32Array(),
				"points": PackedVector2Array(),
				"colors": PackedColorArray(),
				"low": Vector2i(1 << 20, 1 << 20),
				"high": Vector2i(-(1 << 20), -(1 << 20)),
			}
			entry_of[piece] = entry
			pieces.append(entry)
	for index in range(_density.size()):
		if _density[index] <= 0.0:
			continue
		var piece: int = cell_piece[_connect_cell(index, columns)]
		if piece == main:
			continue
		var entry: Dictionary = entry_of[piece]
		var at: Vector2 = position_of(index)
		var whole := Vector2i(floori(at.x), floori(at.y))
		entry["mass"] += _density[index]
		entry["pixels"].append(index)
		entry["points"].append(at)
		entry["colors"].append(_color[index])
		entry["low"] = Vector2i(mini(entry["low"].x, whole.x), mini(entry["low"].y, whole.y))
		entry["high"] = Vector2i(maxi(entry["high"].x, whole.x), maxi(entry["high"].y, whole.y))
		_erase(index)

	for entry: Dictionary in pieces:
		var low: Vector2i = entry["low"]
		var piece_size: Vector2i = entry["high"] - low + Vector2i.ONE
		var piece_image := Image.create(piece_size.x, piece_size.y, false, Image.FORMAT_RGBA8)
		var points: PackedVector2Array = entry["points"]
		var colors: PackedColorArray = entry["colors"]
		for i in range(points.size()):
			piece_image.set_pixel(floori(points[i].x) - low.x, floori(points[i].y) - low.y, colors[i])
		entry["image"] = piece_image
		entry["center"] = Vector2(low) + Vector2(piece_size) / 2.0
	_refresh()
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pixel_count"] > b["pixel_count"])
	return pieces


func _connect_cell(index: int, columns: int) -> int:
	var on_canvas: Vector2 = _home[index] + _half
	return int(on_canvas.y) / CONNECT_CELL * columns + int(on_canvas.x) / CONNECT_CELL


# A repeatable small number per pixel, so a crushed edge is jagged instead of ruled.
func _jitter(index: int, damage_seed: int) -> int:
	return ((index * 2654435761 + damage_seed * 40503) >> 7) & 7


func _erase(index: int) -> void:
	var density: float = _density[index]
	var home: Vector2 = _home[index]
	mass -= density
	_total_x -= density * home.x
	_total_y -= density * home.y
	_total_r_squared -= density * home.length_squared()
	_density[index] = 0.0
	pixel_count -= 1
	_layers[pixel_layer[index]].image.set_pixel(pixel_x[index], pixel_y[index], Color(0.0, 0.0, 0.0, 0.0))
	var module_index: int = _module_of[index]
	module_masses[module_index] = module_masses.get(module_index, 0.0) - density
	_module_left[module_index] -= 1
	_module_hole[module_index] += home
	if _is_working[index] == 1:
		_working_left[module_index] -= 1
	if _is_nozzle[index] == 1:
		_nozzle_left[module_index] -= 1


# Erases highest rank first until the energy runs out. A counting sort, since the ranks are
# whole numbers in a small range and there are thousands of pixels.
func _erase_in_order(order: PackedInt32Array, ranks: PackedInt32Array, energy: float) -> Dictionary:
	var erased := {"pixels": PackedInt32Array(), "points": PackedVector2Array(), "colors": PackedColorArray()}
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
		erased["pixels"].append(index)
		erased["points"].append(position_of(index))
		erased["colors"].append(_color[index])
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

	# Each row's two ends are enough to find a layer's outline.
	for layer_index in range(_layers.size()):
		var layer: Layer = _layers[layer_index]
		var rows: int = layer.image.get_height()
		var first := PackedInt32Array()
		var last := PackedInt32Array()
		first.resize(rows)
		first.fill(-1)
		last.resize(rows)
		last.fill(-1)
		for index in range(_density.size()):
			if _density[index] > 0.0 and pixel_layer[index] == layer_index:
				var x: int = pixel_x[index]
				var y: int = pixel_y[index]
				if first[y] < 0 or x < first[y]:
					first[y] = x
				last[y] = maxi(last[y], x)
		var edge_points := PackedVector2Array()
		var corner: Vector2 = Vector2(layer.top_left) - _half
		for y in range(rows):
			if first[y] >= 0:
				edge_points.append(corner + Vector2(first[y], y))
				edge_points.append(corner + Vector2(first[y], y + 1))
				edge_points.append(corner + Vector2(last[y] + 1, y))
				edge_points.append(corner + Vector2(last[y] + 1, y + 1))
		layer.outline = Geometry2D.convex_hull(edge_points) if edge_points.size() >= 3 else edge_points
	_update_size()


func _update_size() -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for layer: Layer in _layers:
		for point: Vector2 in layer.outline:
			var at: Vector2 = layer.place(point)
			low = Vector2(minf(low.x, at.x), minf(low.y, at.y))
			high = Vector2(maxf(high.x, at.x), maxf(high.y, at.y))
	width = maxf(high.x - low.x, 0.0) if low.x != INF else 0.0
	length = maxf(high.y - low.y, 0.0) if low.x != INF else 0.0
