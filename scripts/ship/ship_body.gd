# ship_body.gd: a ship's pixels: which are left, and the mass, center of mass, and spin
# resistance they add up to.
# From DESIGN.md, "Ships" (each module is a pixel mask, each material has a density, and the
# ship's totals are summed from its pixels) and "Destruction" (damage erases pixels, and a
# connectivity check splits off any piece no longer attached).
#
# The modules on the grid are drawn together as one layer. A part that moves, such as a
# landing leg, is a layer of its own that can be somewhere else while its pixels stay the same.
# Mass always counts a moving part where it's stowed, since it's tiny next to the whole ship.
#
# A pixel can have depth: the hull's skin on top, then the systems under it, then the bare
# frame. Damage takes one at a time, and a pixel is only gone once it has nothing left.
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
	## How far a leg's shock absorber has it squeezed up, in pixels.
	var squash: float = 0.0

	## Where a point on this layer's stowed art is right now.
	func place(home: Vector2) -> Vector2:
		if not moves:
			return home
		var from_hinge: Vector2 = home - hinge_home
		return hinge_now + Vector2(from_hinge.x, from_hinge.y * fold - squash)

	## Where on this layer's stowed art a point is right now. A part edge-on covers nothing.
	func unplace(point: Vector2) -> Vector2:
		if not moves:
			return point
		var from_hinge: Vector2 = point - hinge_now + Vector2(0.0, squash)
		if absf(fold) < 0.2:
			return Vector2(INF, INF)
		return hinge_home + Vector2(from_hinge.x, from_hinge.y / fold)


## Pixels are attached if they touch, corners included. Parts the art draws with a small gap,
## such as the engine bell, get welded across it when the ship is measured: pixels this far
## apart or closer count as touching for as long as both are there.
const WELD_REACH: int = 4
## How many depths a pixel can have: skin, systems, and frame.
const DEPTHS: int = 3
## How far ahead of the next depth down each one goes, in pixels, so a hit strips the skin well
## past the point where it breaks through to the frame.
const DEPTH_GAP: int = 12

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
var original_pixel_count: int = 1
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
# Half the number of grid columns: a module whose middle is here sits on the ship's center line.
var _columns_middle: float = 0.5
var _layers: Array[Layer] = []
var _total_x: float = 0.0
var _total_y: float = 0.0
var _total_r_squared: float = 0.0
# Per pixel. A density of zero means the pixel is gone.
var _density: PackedFloat32Array = PackedFloat32Array()
var _depth: PackedByteArray = PackedByteArray()
var _module_of: PackedInt32Array = PackedInt32Array()
var _home: PackedVector2Array = PackedVector2Array()
var _color: PackedColorArray = PackedColorArray()
# Per pixel and depth, at pixel * DEPTHS + depth. An empty color means it has nothing there.
var _depth_mass: PackedFloat32Array = PackedFloat32Array()
var _depth_strength: PackedFloat32Array = PackedFloat32Array()
var _depth_color: PackedColorArray = PackedColorArray()
var _is_working: PackedByteArray = PackedByteArray()
var _is_nozzle: PackedByteArray = PackedByteArray()
var _cell_of: PackedInt32Array = PackedInt32Array()
# Which pixel is at each place on the grid, where the ship has it stowed. -1 for none.
var _pixel_at: PackedInt32Array = PackedInt32Array()
# A moving part's pixel that sits under a hull pixel's place on the grid, waiting to take that place
# over if the hull pixel goes. -1 for none.
var _pixel_behind: PackedInt32Array = PackedInt32Array()
# Pairs of pixels joined across a gap the art draws.
var _welds: PackedInt32Array = PackedInt32Array()
var _needs_split_check: bool = true
# The latest pieces found: each cell's run of pixels, and which run each run has joined.
var _run_at: PackedInt32Array = PackedInt32Array()
var _run_parent: PackedInt32Array = PackedInt32Array()
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
	body._columns_middle = columns / 2.0
	body._half = Vector2(body._canvas) / 2.0
	body._pixel_at.resize(body._canvas.x * body._canvas.y)
	body._pixel_at.fill(-1)
	body._pixel_behind.resize(body._canvas.x * body._canvas.y)
	body._pixel_behind.fill(-1)

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
		body._add_module(i, design.modules[i], materials, design)
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
	body.original_pixel_count = maxi(body.pixel_count, 1)
	body._weld_drawn_gaps()
	body._refresh()
	return body


func _add_module(index: int, module: ModuleData, materials: Dictionary, design: ShipDesign) -> void:
	var art: Image = _art_of(module.texture)
	var systems: Image = _art_of(module.systems_texture)
	var frame: Image = _art_of(module.frame_texture)
	var has_inside: bool = systems != null or frame != null
	var skin_thickness: float = design.skin_thickness if has_inside else 1.0

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
			var pixel_mass: float = material.density * skin_thickness
			var at := Vector2i(x, y) + offset
			var home: Vector2 = Vector2(layer.top_left + at) + Vector2(0.5, 0.5) - _half
			layer.image.set_pixel(at.x, at.y, color)
			layer.lookup[at.y * layer_width + at.x] = _density.size()
			var on_canvas: Vector2i = layer.top_left + at
			var cell_index: int = on_canvas.y * _canvas.x + on_canvas.x
			_cell_of.append(cell_index)
			if on_canvas.x >= 0 and on_canvas.y >= 0 and on_canvas.x < _canvas.x and on_canvas.y < _canvas.y:
				# A moving part's pixel over a hull pixel's place leaves that place to the hull.
				if layer_index != 0 and _pixel_at[cell_index] >= 0:
					_pixel_behind[cell_index] = _density.size()
				else:
					_pixel_at[cell_index] = _density.size()
			_depth.append(0)
			_module_of.append(index)
			_home.append(home)
			_color.append(color)
			pixel_layer.append(layer_index)
			pixel_x.append(at.x)
			pixel_y.append(at.y)
			var working: bool = not module.working_rect.has_area() or module.working_rect.has_point(Vector2i(x, y))
			var nozzle: bool = _in_nozzle(module, Vector2i(x, y))
			_is_working.append(1 if working else 0)
			_is_nozzle.append(1 if nozzle else 0)
			_depth_mass.append(pixel_mass)
			_depth_strength.append(material.strength * skin_thickness)
			_depth_color.append(color)
			var total_mass: float = pixel_mass
			total_mass += _add_depth(systems, x, y, materials, design.systems_thickness)
			total_mass += _add_depth(frame, x, y, materials, design.frame_thickness)
			_density.append(total_mass)
			mass += total_mass
			_total_x += total_mass * home.x
			_total_y += total_mass * home.y
			_total_r_squared += total_mass * home.length_squared()
			pixel_count += 1
			module_masses[index] = module_masses.get(index, 0.0) + total_mass
			_module_start[index] += 1
			if working:
				_working_start[index] += 1
			if nozzle:
				_nozzle_start[index] += 1


# True if a pixel of the module's art is part of its RCS nozzle. A centered module's rect is the
# left tail nozzle, so its mirror image across the module's middle counts too.
func _in_nozzle(module: ModuleData, at: Vector2i) -> bool:
	if not module.nozzle_rect.has_area():
		return false
	if module.nozzle_rect.has_point(at):
		return true
	if is_centered(module):
		var rect: Rect2i = module.nozzle_rect
		var mirrored := Rect2i(_cell_size - rect.position.x - rect.size.x, rect.position.y, rect.size.x, rect.size.y)
		return mirrored.has_point(at)
	return false


## True if a module sits in the middle column, on the ship's center line.
func is_centered(module: ModuleData) -> bool:
	return module.on_grid and is_equal_approx(module.cell.x + 0.5, _columns_middle)


func _art_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var art: Image = texture.get_image().duplicate()
	if art.is_compressed():
		art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	return art


# Records what's at one depth under a pixel, and returns its mass.
func _add_depth(art: Image, x: int, y: int, materials: Dictionary, thickness: float) -> float:
	var color := Color(0.0, 0.0, 0.0, 0.0)
	var material: MaterialData = null
	if art != null:
		var there: Color = art.get_pixel(x, y)
		if there.a >= 0.5:
			var key: String = there.to_html(false)
			if materials.has(key):
				material = materials[key]
				color = there
			else:
				push_warning("Ship pixel color %s isn't in any material" % key)
	_depth_color.append(color)
	_depth_mass.append(material.density * thickness if material != null else 0.0)
	_depth_strength.append(material.strength * thickness if material != null else 0.0)
	return material.density * thickness if material != null else 0.0


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
## Where a module's art sits, from the grid's middle, trimmed to its drawn pixels: for pointing at
## the module, not for physics.
func module_art_rect(module_index: int) -> Rect2:
	var module: ModuleData = modules[module_index]
	var art: Image = _art_of(module.texture)
	if art == null:
		return Rect2()
	var used: Rect2i = art.get_used_rect()
	var corner: Vector2 = Vector2(module.cell * _cell_size) if module.on_grid else Vector2(module.art_position)
	return Rect2(corner + Vector2(used.position) - _half, Vector2(used.size))


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


## Where the flame leaves the engines right now: the "middle" of their lowest working pixels and
## their "half_width", from the middle of the grid. Only counts modules still working, so a lost
## engine moves it off to one side, and a crushed bell moves it up. Empty if there's nothing left.
func engine_exit(dead_share: float) -> Dictionary:
	var works := PackedByteArray()
	works.resize(modules.size())
	for i in range(modules.size()):
		works[i] = 1 if modules[i].kind == "engine" and working_share(i) >= dead_share else 0

	var lowest: float = -INF
	for index in range(_density.size()):
		if _density[index] > 0.0 and _is_working[index] == 1 and works[_module_of[index]] == 1:
			lowest = maxf(lowest, _home[index].y)
	if lowest == -INF:
		return {}

	# The bell's mouth is the widest part near the bottom.
	var left: float = INF
	var right: float = -INF
	for index in range(_density.size()):
		if _density[index] > 0.0 and _is_working[index] == 1 and works[_module_of[index]] == 1:
			var at: Vector2 = _home[index]
			if at.y > lowest - 4.0:
				left = minf(left, at.x)
				right = maxf(right, at.x)
	return {"middle": Vector2((left + right) / 2.0, lowest + 0.5), "half_width": (right - left + 1.0) / 2.0}


## Where gas leaves a module's RCS nozzle, from the middle of the grid.
func nozzle_point(module_index: int) -> Vector2:
	var module: ModuleData = modules[module_index]
	return Vector2(module.cell * _cell_size) + module.nozzle_point - _half


## Every place gas leaves a module's RCS nozzles: one, or two mirrored about the center line for
## a centered module (its nozzle_point is the left one).
func nozzle_points(module_index: int) -> PackedVector2Array:
	var module: ModuleData = modules[module_index]
	var points := PackedVector2Array([nozzle_point(module_index)])
	if module.nozzle_rect.has_area() and is_centered(module):
		var left: Vector2 = points[0]
		points.append(Vector2(-left.x, left.y))
	return points


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


## The landing legs, as [layer number, module number] pairs.
func legs() -> Array:
	var found: Array = []
	for i in range(_layers.size()):
		var layer: Layer = _layers[i]
		if layer.moves and layer.module >= 0 and modules[layer.module].kind == "leg":
			found.append([i, layer.module])
	return found


## Squeezes a leg up by its shock absorber, in pixels. Call size_changed after setting them all.
func set_squash(layer_index: int, pixels: float) -> void:
	_layers[layer_index].squash = pixels


## Measures the ship's size again, after its legs have squeezed or stretched.
func size_changed() -> void:
	_update_size()


## Half the width of what the ship stands on: its lowest points, within a couple of pixels of the
## bottom, measured out from its center of mass.
func stance_half_width() -> float:
	var lowest: float = -INF
	var points := PackedVector2Array()
	for layer: Layer in _layers:
		for point: Vector2 in layer.outline:
			var at: Vector2 = layer.place(point)
			points.append(at)
			lowest = maxf(lowest, at.y)
	var widest: float = 0.0
	for at: Vector2 in points:
		if at.y >= lowest - 2.0:
			widest = maxf(widest, absf(at.x - center_of_mass.x))
	return widest


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


## The corners of the ship's outline where they are right now, from the middle of the grid.
func outline_now() -> PackedVector2Array:
	var points := PackedVector2Array()
	for layer: Layer in _layers:
		for point: Vector2 in layer.outline:
			points.append(layer.place(point))
	return points


## Each layer's outline where it is right now, as its own closed shape, from the middle of the
## grid. This is what the air pushes on.
func outline_polygons_now() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for layer: Layer in _layers:
		var points := PackedVector2Array()
		for point: Vector2 in layer.outline:
			points.append(layer.place(point))
		polygons.append(points)
	return polygons


## Points along the edges of the ship's outline where they are right now, about this far apart, from
## the middle of the grid.
func outline_samples_now(spacing: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for layer: Layer in _layers:
		var count: int = layer.outline.size()
		for i in range(count):
			var from: Vector2 = layer.place(layer.outline[i])
			var to: Vector2 = layer.place(layer.outline[(i + 1) % count])
			var steps: int = maxi(ceili(from.distance_to(to) / spacing), 1)
			for step in range(steps):
				points.append(from.lerp(to, float(step) / steps))
	return points


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


## A picture of the ship as it is now, nose up, each pixel where it sits. With cutaway, it shows what's
## under the skin: the systems where there are any, else the frame, and the bare skin dimmed. Returns
## the "image", and where the grid's middle falls on it as "middle".
func picture(cutaway: bool) -> Dictionary:
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-(1 << 20), -(1 << 20))
	for index in range(_density.size()):
		if _density[index] > 0.0:
			var at := Vector2i(position_of(index).floor())
			low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
			high = Vector2i(maxi(high.x, at.x), maxi(high.y, at.y))
	if high.x < low.x:
		return {"image": Image.create(1, 1, false, Image.FORMAT_RGBA8), "middle": Vector2.ZERO}
	var image := Image.create(high.x - low.x + 1, high.y - low.y + 1, false, Image.FORMAT_RGBA8)
	for index in range(_density.size()):
		if _density[index] <= 0.0:
			continue
		var color: Color = _color[index]
		if cutaway:
			var inside: bool = false
			for depth in [1, 2]:
				var below: Color = _depth_color[index * DEPTHS + depth]
				if _depth[index] <= depth and below.a >= 0.5:
					color = below
					inside = true
					break
			if not inside:
				color = color.darkened(0.55)
		image.set_pixelv(Vector2i(position_of(index).floor()) - low, color)
	return {"image": image, "middle": -Vector2(low)}


## How much of a module's mass is left, from 0 to 1, against how much it had whole.
func module_mass_share(module_index: int, whole: ShipBody) -> float:
	var had: float = whole.module_masses.get(module_index, 0.0)
	return clampf(module_masses.get(module_index, 0.0) / had, 0.0, 1.0) if had > 0.0 else 1.0


## How deep the damage goes at every pixel, for a save: how many of its depths are gone, up to all
## of them for a pixel that's gone.
func damage_depths() -> PackedByteArray:
	return _depth.duplicate()


## Puts saved damage back on a whole body, as measure makes it, by peeling each pixel down to the
## depth it had. A save from a ship of another shape is ignored.
func restore_damage(depths: PackedByteArray) -> void:
	if depths.size() != _depth.size():
		return
	for index in range(depths.size()):
		while _depth[index] < mini(depths[index], DEPTHS):
			_peel(index)
	_refresh()


## Removes every piece no longer attached and returns them, biggest first. The piece with the
## most cockpit in it stays as the ship, or the biggest one if the cockpit's gone. Each has an
## "image", its "center" from the middle of the grid, its "mass", its "pixel_count", and its
## pixels as "pixels", "points", and "colors". Whether pieces touch goes by where they're
## stowed, since a moving part stays attached however far out it is.
func split_off() -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	if not _needs_split_check:
		return pieces
	_needs_split_check = false
	if _count_pieces(true) <= 1:
		return pieces

	# Every run's final piece, worked out once so the loops over pixels stay quick.
	var piece_of_run := PackedInt32Array()
	piece_of_run.resize(_run_parent.size())
	for run in range(_run_parent.size()):
		piece_of_run[run] = _root_of(run)
	var is_cockpit := PackedByteArray()
	is_cockpit.resize(modules.size())
	for i in range(modules.size()):
		is_cockpit[i] = 1 if modules[i].kind == "cockpit" else 0

	var counts := PackedInt32Array()
	counts.resize(_run_parent.size())
	counts.fill(0)
	var cockpit := PackedInt32Array()
	cockpit.resize(_run_parent.size())
	cockpit.fill(0)
	for index in range(_density.size()):
		if _density[index] > 0.0:
			var piece: int = piece_of_run[_run_at[_cell_of[index]]]
			counts[piece] += 1
			cockpit[piece] += is_cockpit[_module_of[index]]

	var main: int = 0
	for piece in range(counts.size()):
		if cockpit[piece] > cockpit[main] or (cockpit[piece] == cockpit[main] and counts[piece] > counts[main]):
			main = piece

	var entry_of: Dictionary = {}
	for piece in range(counts.size()):
		if piece != main and counts[piece] > 0:
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
		var piece: int = piece_of_run[_run_at[_cell_of[index]]]
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
	# Taking loose pieces away can't loosen anything else.
	_needs_split_check = false
	_refresh()
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pixel_count"] > b["pixel_count"])
	return pieces


# Finds what's attached to what. Each row's unbroken runs of pixels are joined to the runs they
# touch in the row above, which is far quicker than following every pixel. Returns how many
# separate pieces there are.
func _count_pieces(use_welds: bool) -> int:
	var columns: int = _canvas.x
	_run_at.resize(_pixel_at.size())
	_run_parent.resize(0)
	var above_starts := PackedInt32Array()
	var above_stops := PackedInt32Array()
	var above_first: int = 0
	var pieces: int = 0
	for y in range(_canvas.y):
		var row: int = y * columns
		var row_first: int = _run_parent.size()
		var starts := PackedInt32Array()
		var stops := PackedInt32Array()
		var x: int = 0
		var checked: int = 0
		while x < columns:
			var pixel: int = _pixel_at[row + x]
			if pixel < 0 or _density[pixel] <= 0.0:
				x += 1
				continue
			var start: int = x
			var run: int = _run_parent.size()
			_run_parent.append(run)
			pieces += 1
			while x < columns:
				pixel = _pixel_at[row + x]
				if pixel < 0 or _density[pixel] <= 0.0:
					break
				_run_at[row + x] = run
				x += 1
			starts.append(start)
			stops.append(x)
			# Corners count, so a run touches anything from one before it to one after it.
			var i: int = checked
			while i < above_starts.size() and above_starts[i] <= x:
				if above_stops[i] >= start:
					if _join_runs(run, above_first + i):
						pieces -= 1
				i += 1
			while checked < above_starts.size() and above_stops[checked] < x:
				checked += 1
		above_starts = starts
		above_stops = stops
		above_first = row_first

	if use_welds:
		for i in range(0, _welds.size(), 2):
			var a: int = _welds[i]
			var b: int = _welds[i + 1]
			if _density[a] > 0.0 and _density[b] > 0.0:
				if _join_runs(_run_at[_cell_of[a]], _run_at[_cell_of[b]]):
					pieces -= 1
	return pieces


# Joins two runs, and returns true if they weren't joined already.
func _join_runs(a: int, b: int) -> bool:
	var root_a: int = _root_of(a)
	var root_b: int = _root_of(b)
	if root_a == root_b:
		return false
	_run_parent[root_a] = root_b
	return true


func _root_of(run: int) -> int:
	while _run_parent[run] != run:
		_run_parent[run] = _run_parent[_run_parent[run]]
		run = _run_parent[run]
	return run


func _piece_of(index: int) -> int:
	return _root_of(_run_at[_cell_of[index]])


# The art can draw a part with a small gap, such as the engine bell, and it should still count
# as attached. So the whole ship gets welded together here, across only those gaps.
func _weld_drawn_gaps() -> void:
	if _count_pieces(false) <= 1:
		return

	var counts := PackedInt32Array()
	counts.resize(_run_parent.size())
	counts.fill(0)
	for index in range(_density.size()):
		counts[_piece_of(index)] += 1
	var biggest: int = 0
	for piece in range(counts.size()):
		if counts[piece] > counts[biggest]:
			biggest = piece

	for index in range(_density.size()):
		var piece: int = _piece_of(index)
		if piece != biggest:
			_weld_within(index, piece, WELD_REACH)

	# Anything still loose gets one weld to the nearest pixel, however far that is.
	var reach: int = WELD_REACH + 1
	var pieces: int = _count_pieces(true)
	while pieces > 1 and reach <= maxi(_canvas.x, _canvas.y):
		var main: int = _piece_of(_largest_pixel())
		for index in range(_density.size()):
			if _piece_of(index) != main:
				if _weld_within(index, _piece_of(index), reach):
					break
		pieces = _count_pieces(true)
		reach += 1
	_needs_split_check = true


func _largest_pixel() -> int:
	var counts := PackedInt32Array()
	counts.resize(_run_parent.size())
	counts.fill(0)
	var best: int = 0
	for index in range(_density.size()):
		var piece: int = _piece_of(index)
		counts[piece] += 1
		if counts[piece] > counts[_piece_of(best)]:
			best = index
	return best


# Welds a pixel to every pixel of another piece within reach, and returns whether it found any.
func _weld_within(index: int, piece: int, reach: int) -> bool:
	var found: bool = false
	var cell: int = _cell_of[index]
	var cx: int = cell % _canvas.x
	var cy: int = cell / _canvas.x
	for ny in range(maxi(cy - reach, 0), mini(cy + reach + 1, _canvas.y)):
		for nx in range(maxi(cx - reach, 0), mini(cx + reach + 1, _canvas.x)):
			var other: int = _pixel_at[ny * _canvas.x + nx]
			if other >= 0 and other != index and _piece_of(other) != piece:
				_welds.append(index)
				_welds.append(other)
				found = true
	return found


# A repeatable small number per pixel, so a crushed edge is jagged instead of ruled.
func _jitter(index: int, damage_seed: int) -> int:
	return ((index * 2654435761 + damage_seed * 40503) >> 7) & 7


# Destroys a pixel completely, whatever's left of it.
func _erase(index: int) -> void:
	while _depth[index] < DEPTHS:
		_peel(index)


# Takes the top depth off a pixel. Only with nothing left under it is the pixel gone.
func _peel(index: int) -> void:
	var depth: int = _depth[index]
	var taken: float = _depth_mass[index * DEPTHS + depth]
	var home: Vector2 = _home[index]
	mass -= taken
	_total_x -= taken * home.x
	_total_y -= taken * home.y
	_total_r_squared -= taken * home.length_squared()
	var module_index: int = _module_of[index]
	module_masses[module_index] = module_masses.get(module_index, 0.0) - taken

	var next: int = depth + 1
	while next < DEPTHS and _depth_color[index * DEPTHS + next].a < 0.5:
		next += 1
	_depth[index] = next
	if next < DEPTHS:
		_density[index] -= taken
		_color[index] = _depth_color[index * DEPTHS + next]
		_layers[pixel_layer[index]].image.set_pixel(pixel_x[index], pixel_y[index], _color[index])
		return

	_density[index] = 0.0
	_needs_split_check = true
	pixel_count -= 1
	_hand_over_place(index)
	_layers[pixel_layer[index]].image.set_pixel(pixel_x[index], pixel_y[index], Color(0.0, 0.0, 0.0, 0.0))
	_module_left[module_index] -= 1
	_module_hole[module_index] += home
	if _is_working[index] == 1:
		_working_left[module_index] -= 1
	if _is_nozzle[index] == 1:
		_nozzle_left[module_index] -= 1


# When a pixel is gone, a moving part's pixel that was under it takes its place on the grid.
func _hand_over_place(index: int) -> void:
	var cell: int = _cell_of[index]
	if cell < 0 or cell >= _pixel_at.size() or _pixel_at[cell] != index:
		return
	var behind: int = _pixel_behind[cell]
	if behind >= 0 and _density[behind] > 0.0:
		_pixel_at[cell] = behind
		_pixel_behind[cell] = -1


# Spends the energy from the highest rank down. A counting sort sorts the pixels, since the
# ranks are whole numbers in a small range and there are thousands of pixels. Then three fronts
# walk down them together, one per depth, each a little behind the one before.
func _erase_in_order(order: PackedInt32Array, ranks: PackedInt32Array, energy: float) -> Dictionary:
	var erased := {"pixels": PackedInt32Array(), "points": PackedVector2Array(), "colors": PackedColorArray(), "reveals": PackedColorArray()}
	if order.is_empty():
		return erased
	var lowest: int = ranks[0]
	var highest: int = ranks[0]
	for rank: int in ranks:
		lowest = mini(lowest, rank)
		highest = maxi(highest, rank)
	var span: int = highest - lowest + 1
	var starts := PackedInt32Array()
	starts.resize(span + 1)
	starts.fill(0)
	for rank: int in ranks:
		starts[highest - rank + 1] += 1
	for i in range(1, span + 1):
		starts[i] += starts[i - 1]
	var filling: PackedInt32Array = starts.duplicate()
	var sorted := PackedInt32Array()
	sorted.resize(order.size())
	for i in range(order.size()):
		var slot: int = highest - ranks[i]
		sorted[filling[slot]] = order[i]
		filling[slot] += 1

	var left: float = energy
	var front: int = highest
	while front >= lowest - DEPTH_GAP * (DEPTHS - 1):
		for depth in range(DEPTHS):
			var slot: int = highest - (front + depth * DEPTH_GAP)
			if slot < 0 or slot >= span:
				continue
			for i in range(starts[slot], starts[slot + 1]):
				var index: int = sorted[i]
				if _depth[index] != depth:
					continue
				var cost: float = _depth_strength[index * DEPTHS + depth]
				if cost > left:
					_refresh()
					return erased
				left -= cost
				erased["pixels"].append(index)
				erased["points"].append(position_of(index))
				erased["colors"].append(_color[index])
				_peel(index)
				erased["reveals"].append(_color[index] if _depth[index] < DEPTHS else Color(0.0, 0.0, 0.0, 0.0))
		front -= 1
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
	var firsts: Array[PackedInt32Array] = []
	var lasts: Array[PackedInt32Array] = []
	for layer: Layer in _layers:
		var first := PackedInt32Array()
		first.resize(layer.image.get_height())
		first.fill(-1)
		firsts.append(first)
		lasts.append(first.duplicate())
	for index in range(_density.size()):
		if _density[index] > 0.0:
			var layer_index: int = pixel_layer[index]
			var x: int = pixel_x[index]
			var y: int = pixel_y[index]
			if firsts[layer_index][y] < 0 or x < firsts[layer_index][y]:
				firsts[layer_index][y] = x
			if x > lasts[layer_index][y]:
				lasts[layer_index][y] = x

	for layer_index in range(_layers.size()):
		var layer: Layer = _layers[layer_index]
		var first: PackedInt32Array = firsts[layer_index]
		var last: PackedInt32Array = lasts[layer_index]
		var edge_points := PackedVector2Array()
		var corner: Vector2 = Vector2(layer.top_left) - _half
		for y in range(first.size()):
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
