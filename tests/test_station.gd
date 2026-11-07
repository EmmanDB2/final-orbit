# test_station.gd: checks a station's rooms bolt together properly.
# Run with: godot --headless --path . --script tests/test_station.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_ports_are_on_the_art()
	_test_rooms_fit()
	_test_walking()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL %s: got %s, wanted %s" % [label, actual, expected])


# A port's point is the outermost pixel of the sprite, along the way it faces.
func _test_ports_are_on_the_art() -> void:
	var design: StationDesign = load("res://data/station_1.tres")
	for room: StationRoom in design.rooms:
		var picture: Image = room.texture.get_image()
		picture.convert(Image.FORMAT_RGBA8)
		_check(room.display_name + " has a face for each port", room.port_points.size(), room.port_faces.size(), 0.0)
		for i in range(room.port_points.size()):
			var point := Vector2i(room.port_points[i])
			var face := Vector2i(room.port_faces[i])
			_check(room.display_name + " port is on its art", picture.get_pixelv(point).a, 1.0, 0.0)
			var next: Vector2i = point + face
			var inside: bool = next.x >= 0 and next.y >= 0 and next.x < picture.get_width() and next.y < picture.get_height()
			_check(room.display_name + " port is its outer edge", picture.get_pixelv(next).a if inside else 0.0, 0.0, 0.0)


func _test_rooms_fit() -> void:
	var design: StationDesign = load("res://data/station_1.tres")
	var layout: StationLayout = StationLayout.build(design)
	var solid: int = 0
	for room: StationRoom in design.rooms:
		solid += room.texture.get_image().get_used_rect().get_area()
	_check("six rooms", design.rooms.size(), 6.0, 0.0)
	_check("four ports left free", layout.free_ports.size(), 4.0, 0.0)
	var hub: Vector2i = layout.origin
	_check("the hub's middle is solid", layout.image.get_pixelv(hub).a, 1.0, 0.0)

	# Each free port opens onto empty space and has solid station behind it.
	var faces := {}
	for port: Dictionary in layout.free_ports:
		var point: Vector2i = port["point"]
		var face: Vector2i = port["face"]
		faces[face] = true
		_check("a free port is on the art", layout.image.get_pixelv(point).a, 1.0, 0.0)
		var clear: int = 0
		for step in range(1, 12):
			var next: Vector2i = point + face * step
			if next.x >= 0 and next.y >= 0 and next.x < layout.image.get_width() and next.y < layout.image.get_height():
				clear += 1 if layout.image.get_pixelv(next).a > 0.0 else 0
		_check("and opens onto empty space", clear, 0.0, 0.0)
	_check("free ports face all four ways", faces.size(), 4.0, 0.0)

	# It's all one piece: every room touches the next at its port.
	var w: int = layout.image.get_width()
	var h: int = layout.image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[int] = [hub.y * w + hub.x]
	seen[stack[0]] = 1
	var reached: int = 0
	var alpha: PackedByteArray = layout.image.get_data()
	while not stack.is_empty():
		var at: int = stack.pop_back()
		reached += 1
		var x: int = at % w
		var y: int = at / w
		for next: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
			if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h:
				continue
			var cell: int = next.y * w + next.x
			if seen[cell] == 0 and alpha[cell * 4 + 3] > 0:
				seen[cell] = 1
				stack.append(cell)
	var total: int = 0
	for i in range(w * h):
		total += 1 if alpha[i * 4 + 3] > 0 else 0
	_check("the whole station is one piece", reached, total, 0.0)
	print("station picture %d x %d art px, origin %s, solid %d px" % [w, h, layout.origin, total])


# Walks the station at the pilot's size, from the hub, to check every hatch and room connects.
func _test_walking() -> void:
	var design: StationDesign = load("res://data/station_1.tres")
	var layout: StationLayout = StationLayout.build(design)
	var size: Vector2i = layout.image.get_size()
	# The pilot's reach, in art pixels: 12 world units at 2 units each.
	var reach: float = 6.0
	var fits := func(cell: Vector2i) -> bool:
		for i in range(8):
			var point: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) + Vector2.UP.rotated(i * TAU / 8.0) * reach
			if not layout.is_walkable(point):
				return false
		return layout.is_walkable(Vector2(cell) + Vector2(0.5, 0.5))
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	var stack: Array[Vector2i] = [layout.origin]
	_check("the hub's middle can be stood on", 1.0 if fits.call(layout.origin) else 0.0, 1.0, 0.0)
	seen[layout.origin.y * size.x + layout.origin.x] = 1
	var reached: int = 0
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		reached += 1
		for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + way
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
				continue
			if seen[next.y * size.x + next.x] == 0 and fits.call(next):
				seen[next.y * size.x + next.x] = 1
				stack.append(next)
	print("the pilot can stand in %d art pixels" % reached)
	# Each free port's inner end can be reached, 20 art pixels back from its edge.
	for port: Dictionary in layout.free_ports:
		var inner: Vector2i = port["point"] - port["face"] * 20
		_check("a free port can be walked to", seen[inner.y * size.x + inner.x], 1.0, 0.0)
	# Each thing to use can be reached from within arm's reach of it.
	_check("the station has a gig board", layout.spots.size(), 1.0, 0.0)
	for spot: Dictionary in layout.spots:
		var near: int = 0
		for dy in range(-16, 17):
			for dx in range(-16, 17):
				var cell: Vector2i = spot["point"] + Vector2i(dx, dy)
				if seen[cell.y * size.x + cell.x] == 1:
					near += 1
		_check(spot["kind"] + " can be walked up to", 1.0 if near > 0 else 0.0, 1.0, 0.0)
	# Anywhere the pilot fits, the pilot can get to.
	var cut_off: int = 0
	for y in range(size.y):
		for x in range(size.x):
			if layout.is_walkable(Vector2(x, y) + Vector2(0.5, 0.5)) and seen[y * size.x + x] == 0 and fits.call(Vector2i(x, y)):
				cut_off += 1
	_check("no floor is cut off from the rest", cut_off, 0.0, 0.0)
