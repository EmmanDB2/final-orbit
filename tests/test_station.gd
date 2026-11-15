# test_station.gd: checks a station's rooms bolt together properly, and that a station of modules
# (built here in code from small generated pictures) gets its hatches, floors, ports, and lights.
# Run with: godot --headless --path . --script tests/test_station.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_ports_are_on_the_art()
	_test_rooms_fit()
	_test_walking()
	_test_modular_station()
	_test_hatch_doors()
	_test_planned_lighting()
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
	var kinds: Array = []
	for spot: Dictionary in layout.spots:
		kinds.append(spot["kind"])
	_check("the station has a gig board", 1.0 if kinds.has("gig_board") else 0.0, 1.0, 0.0)
	_check("and a ship services terminal", 1.0 if kinds.has("service") else 0.0, 1.0, 0.0)
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


# --- A station of modules, made in code ---

func _flag(label: String, yes: bool) -> void:
	_check(label, 1.0 if yes else 0.0, 1.0, 0.0)


# A picture of a flat color, with these rectangles cut out of it.
func _picture(size: Vector2i, color: Color, holes: Array[Rect2i] = []) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	for hole: Rect2i in holes:
		image.fill_rect(hole, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


# A square frame of this thickness with these gaps in it.
func _frame(size: Vector2i, thickness: int, gaps: Array[Rect2i]) -> ImageTexture:
	var inside := Rect2i(thickness, thickness, size.x - thickness * 2, size.y - thickness * 2)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.2, 0.25, 1.0))
	image.fill_rect(inside, Color(0.0, 0.0, 0.0, 0.0))
	for gap: Rect2i in gaps:
		image.fill_rect(gap, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


func _port(port_name: String, point: Vector2i, face: Vector2i, kind: String) -> StationPort:
	var port := StationPort.new()
	port.port_name = port_name
	port.point = point
	port.face = face
	port.kind = kind
	return port


func _place(prop: StationProp, position: Vector2i, turns: int = 0) -> PropPlacement:
	var placement := PropPlacement.new()
	placement.prop = prop
	placement.position = position
	placement.turns = turns
	return placement


func _prop(prop_id: String, size: Vector2i, layer: String, footprint: Rect2i = Rect2i()) -> StationProp:
	var prop := StationProp.new()
	prop.id = prop_id
	prop.texture = _picture(size, Color(0.8, 0.5, 0.2, 1.0))
	prop.layer = layer
	prop.footprint = footprint
	return prop


# Two modules, a hub and a side room: the hub's east port bolts to the side room's west port, its
# south port is a docking collar, its west is capped; the side room has an airlock on its north.
func _synthetic_station() -> StationDesign:
	var design := StationDesign.new()
	design.art_pixel_size = 1.0
	var hatch_size := Vector2i(48, 40)
	design.hatch_floor = _picture(hatch_size, Color(0.3, 0.3, 0.3, 1.0))
	design.hatch_walls = _picture(hatch_size, Color(0.7, 0.7, 0.7, 1.0), [Rect2i(8, 0, 32, 40)])
	design.hatch_overhead = _picture(Vector2i(48, 4), Color(0.9, 0.9, 0.9, 1.0))
	design.hatch_roof = _picture(hatch_size, Color(0.8, 0.8, 0.9, 1.0))
	design.hatch_door_left = _picture(Vector2i(18, 6), Color.WHITE)
	design.hatch_door_right = _picture(Vector2i(18, 6), Color.WHITE)
	design.docking_ring_roof = _picture(Vector2i(64, 24), Color(0.9, 0.5, 0.1, 1.0))
	design.capped_plate = _picture(Vector2i(48, 12), Color(0.5, 0.5, 0.5, 1.0))
	design.home_port = "dock_s"
	var canvas := Vector2i(100, 100)
	var floor_rect := Rect2i(8, 8, 84, 84)

	var hub := StationModule.new()
	hub.display_name = "Hub"
	hub.canvas_size = canvas
	hub.floor_texture = _picture(canvas, Color(0.4, 0.4, 0.45, 1.0), [Rect2i(0, 0, 100, 8), Rect2i(0, 92, 100, 8), Rect2i(0, 0, 8, 100), Rect2i(92, 0, 8, 100)])
	hub.walls_texture = _frame(canvas, 8, [Rect2i(92, 34, 8, 32), Rect2i(34, 92, 32, 8), Rect2i(0, 34, 8, 32)])
	hub.roof_texture = _picture(canvas, Color(0.85, 0.85, 0.9, 1.0))
	hub.floors = [floor_rect, Rect2i(92, 34, 8, 32), Rect2i(34, 92, 32, 8)]
	hub.ports = [_port("east", Vector2i(99, 50), Vector2i(1, 0), "inner"), _port("dock_s", Vector2i(50, 99), Vector2i(0, 1), "dock"), _port("west", Vector2i(0, 50), Vector2i(-1, 0), "capped")]
	var desk: StationProp = _prop("desk", Vector2i(12, 8), "standing", Rect2i(0, 0, 12, 6))
	desk.lip = 2
	desk.spot_kind = "gig_board"
	var decal: StationProp = _prop("decal", Vector2i(10, 10), "floor")
	var lamp: StationProp = _prop("lamp", Vector2i(6, 6), "overhead")
	lamp.light = LightFixture.new()
	lamp.light.point = Vector2(3.0, 3.0)
	lamp.light.reach_metres = 2.0
	hub.props = [_place(desk, Vector2i(20, 20)), _place(decal, Vector2i(60, 60)), _place(lamp, Vector2i(40, 40))]
	var red_light := LightFixture.new()
	red_light.point = Vector2(90.0, 50.0)
	red_light.tint = "red"
	red_light.circuit = "emergency"
	hub.fixtures = [red_light]
	var window := Rect2i(10, 10, 20, 4)
	hub.windows = [window]
	var strobe := OutsideLight.new()
	strobe.point = Vector2(5.0, 5.0)
	strobe.kind = "strobe"
	hub.outside_lights = [strobe]

	var side := StationModule.new()
	side.display_name = "Side room"
	side.bolts_to_module = 0
	side.bolts_to_port = "east"
	side.own_port = "west"
	side.canvas_size = canvas
	side.floor_texture = hub.floor_texture
	side.walls_texture = _frame(canvas, 8, [Rect2i(0, 34, 8, 32), Rect2i(34, 0, 32, 8)])
	side.roof_texture = hub.roof_texture
	side.floors = [floor_rect, Rect2i(0, 34, 8, 32), Rect2i(34, 0, 32, 8)]
	side.ports = [_port("west", Vector2i(0, 50), Vector2i(-1, 0), "inner"), _port("airlock", Vector2i(50, 0), Vector2i(0, -1), "airlock")]
	var bed: StationProp = _prop("bed", Vector2i(20, 10), "standing", Rect2i(0, 0, 20, 10))
	bed.spot_kind = "wake"
	side.props = [_place(bed, Vector2i(20, 60), 1)]
	design.modules = [hub, side]
	return design


func _test_modular_station() -> void:
	var design: StationDesign = _synthetic_station()
	var layout: StationLayout = StationLayout.build(design)
	_flag("a station with modules builds the modular way", layout.modular)
	var hub_east: Dictionary = layout.port_named("east")
	var side_west: Dictionary = layout.ports[layout.ports.size() - 2]
	_check("two modules and their ports", layout.ports.size(), 5.0, 0.0)
	var between: float = float(side_west["shell_point"].x - hub_east["shell_point"].x)
	_check("bolted modules sit 40 px apart", between, 41.0, 0.0)
	_check("and sit level", float(side_west["shell_point"].y - hub_east["shell_point"].y), 0.0, 0.0)
	# The port's names and kinds.
	_check("the east port is inner", 1.0 if hub_east["kind"] == "inner" and hub_east["bolted"] else 0.0, 1.0, 0.0)
	_check("a dock port keeps its kind", 1.0 if layout.port_named("dock_s")["kind"] == "dock" else 0.0, 1.0, 0.0)
	_check("one free port, the dock", layout.free_ports.size(), 1.0, 0.0)
	_check("and it's the south one", 1.0 if layout.free_ports[0]["name"] == "dock_s" else 0.0, 1.0, 0.0)
	_check("the airlock is listed as one, not as free", layout.airlock_ports.size(), 1.0, 0.0)
	_check("the airlock is no free port", 1.0 if layout.port_named("airlock") in layout.free_ports else 0.0, 0.0, 0.0)
	_check("the capped port is neither", 1.0 if layout.port_named("west") in layout.free_ports or layout.port_named("west") in layout.airlock_ports else 0.0, 0.0, 0.0)
	# The hatch between them: its passage can be stood on, its side walls can't.
	var joint: Dictionary = layout.hatches[0]
	var middle: Vector2 = joint["center"]
	_flag("the hatch passage is walkable", layout.is_walkable(middle))
	_flag("and so is its end next to a shell", layout.is_walkable(middle + Vector2(-19.0, 0.0)) and layout.is_walkable(middle + Vector2(19.0, 0.0)))
	_flag("its side walls aren't", not layout.is_walkable(middle + Vector2(0.0, 20.0)) and not layout.is_walkable(middle + Vector2(0.0, -21.0)))
	_flag("the hatch's floor is painted into the floor layer", layout.floor_image.get_pixelv(Vector2i(middle) + Vector2i(0, 3)).a > 0.0)
	_flag("its roof is in the roof layer", layout.roof_image.get_pixelv(Vector2i(middle) + Vector2i(0, 21)).a > 0.0)
	# A wall pixel, a standing footprint, and a floor decal.
	var hub_at: Vector2i = layout.origin - Vector2i(50, 50)
	_flag("a wall pixel isn't walkable", not layout.is_walkable(Vector2(hub_at) + Vector2(3.5, 20.5)))
	_flag("open floor is", layout.is_walkable(Vector2(hub_at) + Vector2(50.5, 30.5)))
	_flag("a standing prop's footprint isn't", not layout.is_walkable(Vector2(hub_at) + Vector2(25.5, 22.5)))
	_flag("the floor beside it is", layout.is_walkable(Vector2(hub_at) + Vector2(25.5, 28.5)))
	_flag("a floor decal is", layout.is_walkable(Vector2(hub_at) + Vector2(65.5, 65.5)))
	_flag("the decal is in the floor layer", layout.floor_image.get_pixelv(hub_at + Vector2i(65, 65)).a > 0.0)
	_flag("an overhead prop is in the overhead layer", layout.overhead_image.get_pixelv(hub_at + Vector2i(43, 43)).a > 0.0)
	_check("one prop stands", layout.props.size(), 2.0, 0.0)
	# The side room's bed is turned a quarter: its 20 x 10 footprint is 10 x 20 now.
	var bed: Dictionary = {}
	for entry: Dictionary in layout.props:
		if entry["prop"].id == "bed":
			bed = entry
	_check("a turned footprint is 10 x 20", float(bed["footprint"].size.x * 100 + bed["footprint"].size.y), 1020.0, 0.0)
	_check("a standing prop sorts by the base of its footprint", float(bed["foot"]), float(bed["footprint"].end.y), 0.0)
	# Spots come from props.
	var kinds: Array = []
	for spot: Dictionary in layout.spots:
		kinds.append(spot["kind"])
	_flag("a prop's spot shows up", kinds.has("gig_board") and kinds.has("wake"))
	for spot: Dictionary in layout.spots:
		if spot["kind"] == "gig_board":
			_check("the gig board's spot is the middle of its footprint", float((spot["point"] - hub_at).x * 1000 + (spot["point"] - hub_at).y), 26023.0, 0.0)
	# The dock port: its collar's walkable half, and where its ring ends.
	var dock: Dictionary = layout.free_ports[0]
	_check("the docking point is past the ring", float(dock["point"].y - dock["shell_point"].y), 64.0, 0.0)
	_check("the pilot's spot by the door is inside the collar", float(Vector2(dock["inner"]).y - dock["shell_point"].y), 6.5, 0.0)
	_flag("and can be stood on", layout.is_walkable(dock["inner"]))
	_flag("the collar's outer half can't be", not layout.is_walkable(Vector2(dock["shell_point"]) + Vector2(0.5, 30.0)))
	var airlock: Dictionary = layout.airlock_ports[0]
	_check("the airlock ends at its hatch, with no ring", float(airlock["shell_point"].y - airlock["point"].y), 40.0, 0.0)
	# Rooms for the light bake: the hatch belongs to none.
	_check("one room a module", layout.room_areas.size(), 2.0, 0.0)
	var in_room: int = 0
	for area: Dictionary in layout.room_areas:
		var shell: Image = area["image"]
		var local: Vector2i = Vector2i(middle) - area["at"]
		if local.x >= 0 and local.y >= 0 and local.x < shell.get_width() and local.y < shell.get_height() and shell.get_pixelv(local).a > 0.0:
			in_room += 1
	_check("a hatch is in no room", in_room, 0.0, 0.0)
	_flag("a module's floor is in its room", layout.room_areas[0]["image"].get_pixelv(Vector2i(50, 50)).a > 0.0)
	# Fixtures: the prop's light and the module's, reach turned from metres.
	_check("two fixtures", layout.fixtures.size(), 2.0, 0.0)
	var reaches: Array = []
	for fixture: Dictionary in layout.fixtures:
		reaches.append(fixture["reach"])
	_flag("a 2 m reach is 40 pixels at 5 cm a pixel", reaches.has(40.0))
	_flag("a prop's light lands on its picture", layout.fixtures.any(func(f: Dictionary) -> bool: return f["point"] == Vector2(hub_at) + Vector2(43.5, 43.5)))
	_flag("the module's red one is emergency", layout.fixtures.any(func(f: Dictionary) -> bool: return f["circuit"] == "emergency" and f["tint"] == "red"))
	_check("one window", layout.windows.size(), 1.0, 0.0)
	_check("and one outside light", layout.outside_lights.size(), 1.0, 0.0)
	# Everything that can be walked to: from the hub's middle to the side room, the dock and the airlock.
	var size: Vector2i = layout.picture_size()
	var reach: float = 12.0
	var fits := func(cell: Vector2i) -> bool:
		for i in range(8):
			if not layout.is_walkable(Vector2(cell) + Vector2(0.5, 0.5) + Vector2.UP.rotated(i * TAU / 8.0) * reach):
				return false
		return layout.is_walkable(Vector2(cell) + Vector2(0.5, 0.5))
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	var start: Vector2i = hub_at + Vector2i(50, 50)
	var stack: Array[Vector2i] = [start]
	seen[start.y * size.x + start.x] = 1
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + way
			if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and seen[next.y * size.x + next.x] == 0 and fits.call(next):
				seen[next.y * size.x + next.x] = 1
				stack.append(next)
	var side_middle: Vector2i = Vector2i(side_west["shell_point"]) + Vector2i(50, 0)
	_flag("the side room can be walked to through the hatch", seen[side_middle.y * size.x + side_middle.x] == 1)
	var dock_stand := Vector2i(dock["inner"])
	_flag("the docking collar's door can be walked to", seen[dock_stand.y * size.x + dock_stand.x] == 1)
	var airlock_stand := Vector2i(airlock["inner"])
	_flag("the airlock's door can be walked to", seen[airlock_stand.y * size.x + airlock_stand.x] == 1)
	# An old-style station still builds the old way.
	_flag("rooms still build the old way", not StationLayout.build(load("res://data/station_1.tres")).modular)


# The hatch doors open over 0.25 s when the pilot's within 32 px, and close 0.6 s after they leave.
func _test_hatch_doors() -> void:
	var design: StationDesign = _synthetic_station()
	var layout: StationLayout = StationLayout.build(design)
	var parent := Node2D.new()
	var doors := HatchDoors.new()
	doors.build(parent, layout.hatches, design, layout.origin, func(_corner: Vector2) -> ShaderMaterial: return ShaderMaterial.new())
	_check("a door in each hatch", doors.count(), layout.hatches.size(), 0.0)
	_check("two leaves a door", parent.get_child_count(), layout.hatches.size() * 2, 0.0)
	var middle: Vector2 = layout.hatches[0]["center"]
	var nobody := Vector2(-1.0e9, -1.0e9)
	_check("doors start shut", doors.openness(0), 0.0, 0.0)
	doors.update(0.125, middle + Vector2(31.0, 0.0), layout.origin)
	_check("half open after half the slide", doors.openness(0), 0.5, 0.001)
	doors.update(0.2, middle + Vector2(31.0, 0.0), layout.origin)
	_check("open within 32 px", doors.openness(0), 1.0, 0.0)
	doors.update(0.5, middle + Vector2(33.0, 0.0), layout.origin)
	_check("still open half a second after they step back", doors.openness(0), 1.0, 0.0)
	doors.update(0.2, nobody, layout.origin)
	_check("closing after 0.6 s", doors.openness(0), 0.0, 0.999)
	_flag("closing has begun", doors.openness(0) < 1.0)
	doors.update(0.5, nobody, layout.origin)
	_check("shut again", doors.openness(0), 0.0, 0.0)
	# A hatch the pilot's not near stays shut, and a held door ignores them.
	_check("a far hatch stays shut", doors.openness(1), 0.0, 0.0)
	var shut_at: Vector2 = (parent.get_child(2) as Sprite2D).position
	doors.force(1, HatchDoors.OPEN)
	doors.update(0.3, nobody, layout.origin)
	_check("a held-open door opens with nobody there", doors.openness(1), 1.0, 0.0)
	_flag("and its leaf has slid", (parent.get_child(2) as Sprite2D).position != shut_at)
	parent.free()


# The planned lighting: fixtures baked per circuit, tint, and room, with the power only a live factor.
func _test_planned_lighting() -> void:
	var design: StationDesign = _synthetic_station()
	var hub: StationModule = design.modules[0]
	var side: StationModule = design.modules[1]
	# A wide white mains light by the hub's east wall, reaching 60 px: past the wall, into the side room's
	# pixels, if light went through walls. A warm mains lamp in the side room, a failing white one in the
	# hub, and an always-on screen.
	var wide := LightFixture.new()
	wide.point = Vector2(88.0, 70.0)
	wide.reach_metres = 3.0
	var warm_lamp := LightFixture.new()
	warm_lamp.point = Vector2(50.0, 50.0)
	warm_lamp.reach_metres = 2.5
	warm_lamp.tint = "warm"
	var flicker := LightFixture.new()
	flicker.point = Vector2(15.0, 90.0)
	flicker.reach_metres = 1.5
	flicker.circuit = "failing"
	var screen := LightFixture.new()
	screen.point = Vector2(20.0, 50.0)
	screen.reach_metres = 1.0
	screen.circuit = "always"
	hub.fixtures[0].reach_metres = 1.0
	hub.fixtures.append_array([wide, flicker, screen])
	side.fixtures = [warm_lamp]
	var layout: StationLayout = StationLayout.build(design)
	var maps: Dictionary = StationLight.bake_fixtures(layout.picture_size(), layout.room_areas, layout.fixtures)
	var hub_at: Vector2i = layout.origin - Vector2i(50, 50)
	var side_at := Vector2i.ZERO
	for port: Dictionary in layout.ports:
		if port["name"] == "west" and port["module"] == 1:
			side_at = port["shell_point"]
	var ambient: float = 0.1
	var on := Vector4(1.0, 1.0, 0.0, 1.0)
	var off := Vector4(0.0, 0.0, 1.0, 1.0)
	var lit: Dictionary = StationLight.evaluate(maps, hub_at.x + 88, hub_at.y + 70, on, ambient)
	_flag("a mains white fixture lights its room", lit["light"] > 0.9 and lit["tint"] == "white")
	# 20 px past the hub's east edge is the hatch, then the side room: both out of its room.
	var across: Dictionary = StationLight.evaluate(maps, side_at.x + 5, side_at.y + 20, on, ambient)
	_flag("but not through the wall into the next room", across["light"] < ambient + 0.001)
	var hatch: Dictionary = StationLight.evaluate(maps, hub_at.x + 120, hub_at.y + 70, on, ambient)
	_flag("or into the hatch, which is in no room", hatch["light"] < ambient + 0.001)
	var warm: Dictionary = StationLight.evaluate(maps, side_at.x + 50, side_at.y, on, ambient)
	_flag("a warm fixture gives warm light", warm["light"] > 0.9 and warm["tint"] == "warm")
	var power_off: Dictionary = StationLight.evaluate(maps, hub_at.x + 88, hub_at.y + 75, off, ambient)
	_flag("mains is dark without the power", power_off["light"] < ambient + 0.001)
	var out: Dictionary = StationLight.evaluate(maps, hub_at.x + 15, hub_at.y + 90, Vector4(1.0, 0.0, 0.0, 1.0), ambient)
	var in_flicker: Dictionary = StationLight.evaluate(maps, hub_at.x + 15, hub_at.y + 90, Vector4(1.0, 1.0, 0.0, 1.0), ambient)
	_flag("a failing fixture is out when it flickers and on otherwise", out["light"] < ambient + 0.001 and in_flicker["light"] > 0.9)
	var sputter: Dictionary = StationLight.evaluate(maps, hub_at.x + 15, hub_at.y + 90, Vector4(0.0, 1.0, 1.0, 1.0), ambient)
	_flag("and it sputters without the power", sputter["light"] > 0.9)
	var screen_dark: Dictionary = StationLight.evaluate(maps, hub_at.x + 20, hub_at.y + 50, off, ambient)
	_flag("a screen is on whatever the power", screen_dark["light"] > 0.9)
	# The emergency lamp, the first fixture, by the east door: red, and only without the power.
	var emergency_on: Dictionary = StationLight.evaluate(maps, hub_at.x + 90, hub_at.y + 50, Vector4(1.0, 1.0, 0.0, 1.0), ambient)
	var emergency_off: Dictionary = StationLight.evaluate(maps, hub_at.x + 90, hub_at.y + 50, Vector4(0.0, 0.0, 1.0, 1.0), ambient)
	_flag("an emergency fixture is dark while powered", emergency_on["tint"] != "red")
	_flag("and red with the power off", emergency_off["tint"] == "red" and emergency_off["light"] > ambient + 0.2)
	var pulsing: Dictionary = StationLight.evaluate(maps, hub_at.x + 90, hub_at.y + 50, Vector4(0.0, 0.0, 0.4, 1.0), ambient)
	_flag("and pulses with its live factor", pulsing["light"] < emergency_off["light"])
	# With no fixtures at all, a modular station gets automatic lamps instead.
	var bare: StationDesign = _synthetic_station()
	for module: StationModule in bare.modules:
		module.fixtures = []
		for placement: PropPlacement in module.props:
			placement.prop.light = null
	var plain: StationLayout = StationLayout.build(bare)
	_check("no fixtures: none baked", plain.fixtures.size(), 0.0, 0.0)
	_flag("no fixtures: automatic lamps instead", plain.lamps.size() > 0)
