# station_layout.gd: bolts a station's rooms together, port to port, into one picture. Rooms turn
# in quarter turns only, so no pixel moves off the grid. A station described as modules is built
# the second way (see _build_modules): each module has four layers of art, its joints get the
# standard hatch, and its props, ports, and fixtures are worked out onto one canvas.
# From DESIGN.md, "Universe generation" and "Art direction".
class_name StationLayout
extends RefCounted

## All the rooms as one picture.
var image: Image
## The same with the roof off.
var interior_image: Image
## Things to use inside, each with its "point" on the picture and its "kind".
var spots: Array[Dictionary] = []
## Where the first room's middle is on the picture. It's the point that rides the rails.
var origin: Vector2i = Vector2i.ZERO
## The ports with nothing on them, each with its outer "point" on the picture and its "face".
var free_ports: Array[Dictionary] = []
## The ceiling lamps, each with its "point" on the picture, its "reach" in picture pixels, and the
## "room" it hangs in.
var lamps: Array[Dictionary] = []
## Each room's insides as placed on the picture: its turned "image" and where its corner is, "at".
var room_areas: Array[Dictionary] = []

# Only for a station of modules.
## Whether this was built from modules. If so, "image" is the roof layer, "interior_image" the floor
## and walls together, and the rest of this section is filled in.
var modular: bool = false
## The four layers for the whole station, each the size of the picture.
var floor_image: Image
var walls_image: Image
var overhead_image: Image
var roof_image: Image
## Props that stand, each with the "prop", the "at" where its turned "image" has its top left corner,
## its "turns", its "footprint" as a rectangle on the picture, its "foot" (the picture row its base
## ends on, to sort it against the pilot), and its "module".
var props: Array[Dictionary] = []
## Every light put in the data, each with its "point" on the picture, its "reach" in picture pixels,
## the "room" (module) it's in, and its "tint", "circuit", and "brightness".
var fixtures: Array[Dictionary] = []
## Windows as rectangles on the picture.
var windows: Array[Rect2i] = []
## Outside lights, each with its "point" on the picture, its "kind", and the "port" it belongs to.
var outside_lights: Array[Dictionary] = []
## Every port, each with its "name", "kind", "module", "point" (its outer pixel on the module's
## shell), "face", whether it's "bolted", and for a free dock or airlock port the "inner" point the
## pilot stands at by its door and the "point" where the collar ends (the "shell_point" is the shell's).
var ports: Array[Dictionary] = []
## The unbolted airlock ports, as free_ports lists the dock ports.
var airlock_ports: Array[Dictionary] = []
## Each hatch piece placed, and each door inside a module (which has no piece of its own): its "rect" on the picture, its "turns" (0 if it runs up and down, 1 if
## sideways), its "center", its "kind" ("inner", "dock", or "airlock"), its "face" (the way it runs, out
## of its first port), and the "ports" it's on, by name.
var hatches: Array[Dictionary] = []

## Floors smaller than this many pixels, such as doorways, get no lamp of their own.
const SMALLEST_LIT_FLOOR: int = 300
## How far apart lamps go down a long corridor, in picture pixels.
const LAMP_SPACING: float = 40.0

var _size := Vector2i.ZERO
var _solid := PackedByteArray()
var _walkable := PackedByteArray()


## True if there's a solid pixel at this point on the picture.
func is_solid(point: Vector2) -> bool:
	var x: int = floori(point.x)
	var y: int = floori(point.y)
	if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
		return false
	return _solid[y * _size.x + x] == 1


## Which way is out of the solid near this point on the picture, from where the empty space around
## it lies. Zero if it's all one thing around here.
func normal_at(point: Vector2, reach: int = 8) -> Vector2:
	var total := Vector2.ZERO
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx * dx + dy * dy <= reach * reach and not is_solid(point + Vector2(dx, dy)):
				total += Vector2(dx, dy)
	return total.normalized()


## The picture's size in pixels.
func picture_size() -> Vector2i:
	return _size


## Which of the picture's pixels someone can stand on, row by row: 1 on a floor, 0 elsewhere.
func floors() -> PackedByteArray:
	return _walkable


## True if someone can stand at this point on the picture.
func is_walkable(point: Vector2) -> bool:
	var x: int = floori(point.x)
	var y: int = floori(point.y)
	if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
		return false
	return _walkable[y * _size.x + x] == 1


# A room's lamps: the ones it sets, or else one over each floor big enough, and a row down a corridor.
static func _lamps_of(room: StationRoom) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not room.lamp_points.is_empty():
		for i in range(room.lamp_points.size()):
			found.append({"point": room.lamp_points[i], "reach": room.lamp_reaches[i] if i < room.lamp_reaches.size() else 40.0})
		return found
	return _lamps_over(room.walkable)


# The automatic lamps over a set of floors: one over each floor big enough, and a row down a long one.
static func _lamps_over(floors: Array[Rect2i]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for rect: Rect2i in floors:
		if rect.get_area() < SMALLEST_LIT_FLOOR:
			continue
		var long: float = maxf(rect.size.x, rect.size.y)
		var count: int = maxi(roundi(long / LAMP_SPACING), 1)
		var along := Vector2(1.0, 0.0) if rect.size.x >= rect.size.y else Vector2(0.0, 1.0)
		var reach: float = minf(rect.size.x, rect.size.y) * 0.5 + minf(long / count, LAMP_SPACING) * 0.75 + 8.0
		for i in range(count):
			var point: Vector2 = Vector2(rect.position) + (Vector2(rect.size) * (Vector2.ONE - along)) * 0.5 + along * long * (i + 0.5) / count
			found.append({"point": point.floor(), "reach": reach})
	return found


static func build(design: StationDesign) -> StationLayout:
	if not design.modules.is_empty():
		return _build_modules(design)
	var layout := StationLayout.new()
	var placed: Array[Dictionary] = []
	var used_ports := {}
	var low := Vector2i.ZERO
	var high := Vector2i.ZERO

	for i in range(design.rooms.size()):
		var room: StationRoom = design.rooms[i]
		var picture: Image = room.texture.get_image()
		picture.convert(Image.FORMAT_RGBA8)
		var turns: int = 0
		var at := Vector2i.ZERO
		if i == 0:
			at = -picture.get_size() / 2
		else:
			var parent: Dictionary = placed[room.bolts_to_room]
			var parent_face: Vector2i = _turned_face(design.rooms[room.bolts_to_room].port_faces[room.bolts_to_port], parent["turns"])
			var parent_point: Vector2i = parent["at"] + _turned_point(
					design.rooms[room.bolts_to_room].port_points[room.bolts_to_port], parent["size"], parent["turns"])
			while _turned_face(room.port_faces[room.own_port], turns) != -parent_face:
				turns += 1
			var own_point: Vector2i = _turned_point(room.port_points[room.own_port], picture.get_size(), turns)
			# The two ports' outer pixels end up side by side.
			at = parent_point + parent_face - own_point
			used_ports[Vector2i(room.bolts_to_room, room.bolts_to_port)] = true
			used_ports[Vector2i(i, room.own_port)] = true
		var size: Vector2i = picture.get_size()
		var turned_size: Vector2i = size if turns % 2 == 0 else Vector2i(size.y, size.x)
		low = low.min(at)
		high = high.max(at + turned_size)
		placed.append({"picture": picture, "turns": turns, "at": at, "size": size, "turned_size": turned_size})

	layout.origin = -low
	layout.image = Image.create(high.x - low.x, high.y - low.y, false, Image.FORMAT_RGBA8)
	layout.interior_image = Image.create(high.x - low.x, high.y - low.y, false, Image.FORMAT_RGBA8)
	layout._walkable.resize((high.x - low.x) * (high.y - low.y))
	for i in range(placed.size()):
		var entry: Dictionary = placed[i]
		var picture: Image = entry["picture"]
		match entry["turns"]:
			1:
				picture.rotate_90(CLOCKWISE)
			2:
				picture.rotate_180()
			3:
				picture.rotate_90(COUNTERCLOCKWISE)
		layout.image.blend_rect(picture, Rect2i(Vector2i.ZERO, entry["turned_size"]), entry["at"] - low)
		var room: StationRoom = design.rooms[i]
		var inside: Image = room.interior_texture.get_image()
		inside.convert(Image.FORMAT_RGBA8)
		match entry["turns"]:
			1:
				inside.rotate_90(CLOCKWISE)
			2:
				inside.rotate_180()
			3:
				inside.rotate_90(COUNTERCLOCKWISE)
		layout.interior_image.blend_rect(inside, Rect2i(Vector2i.ZERO, entry["turned_size"]), entry["at"] - low)
		var offset: Vector2i = entry["at"] - low
		layout.room_areas.append({"image": inside, "at": offset})
		for rect: Rect2i in room.walkable:
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var cell: Vector2i = offset + _turned_point(Vector2(x, y), entry["size"], entry["turns"])
					layout._walkable[cell.y * (high.x - low.x) + cell.x] = 1
		for lamp: Dictionary in _lamps_of(room):
			layout.lamps.append({
				"point": Vector2(offset + _turned_point(lamp["point"], entry["size"], entry["turns"])) + Vector2(0.5, 0.5),
				"reach": lamp["reach"],
				"room": i,
			})
		for s in range(room.spot_points.size()):
			layout.spots.append({
				"point": offset + _turned_point(room.spot_points[s], entry["size"], entry["turns"]),
				"kind": room.spot_kinds[s],
			})
		for port in range(room.port_points.size()):
			if not used_ports.has(Vector2i(i, port)):
				layout.free_ports.append({
					"point": entry["at"] - low + _turned_point(room.port_points[port], entry["size"], entry["turns"]),
					"face": _turned_face(room.port_faces[port], entry["turns"]),
				})
	layout._remember_solid()
	return layout


func _remember_solid() -> void:
	_size = image.get_size()
	_solid.resize(_size.x * _size.y)
	var data: PackedByteArray = image.get_data()
	for i in range(_solid.size()):
		_solid[i] = 1 if data[i * 4 + 3] > 127 else 0


# Where a pixel of a picture goes when the picture turns clockwise that many quarter turns.
static func _turned_point(point: Vector2, size: Vector2i, turns: int) -> Vector2i:
	var p := Vector2i(point)
	match turns % 4:
		1:
			return Vector2i(size.y - 1 - p.y, p.x)
		2:
			return Vector2i(size.x - 1 - p.x, size.y - 1 - p.y)
		3:
			return Vector2i(p.y, size.x - 1 - p.x)
	return p


static func _turned_face(face: Vector2, turns: int) -> Vector2i:
	var f := Vector2i(face)
	match turns % 4:
		1:
			return Vector2i(-f.y, f.x)
		2:
			return -f
		3:
			return Vector2i(f.y, -f.x)
	return f


# The port with this name, or nothing. Only for a station of modules.
func port_named(wanted: String) -> Dictionary:
	for port: Dictionary in ports:
		if port["name"] == wanted:
			return port
	return {}


# The hatch pieces' sizes, in pixels, drawn running up and down: 48 across the opening, 40 along it,
# and the docking ring and capped plate that go with them.
const HATCH_ACROSS: int = 48
const HATCH_LENGTH: int = 40
const RING_ACROSS: int = 64
const RING_DEPTH: int = 24
const CAPPED_ACROSS: int = 48
const CAPPED_DEPTH: int = 12
## How far a free collar's walkable part goes, from the shell toward its door in the middle.
const COLLAR_WALK: int = 20
## How far in from a free collar's shell the pilot stands at its door, in pixels.
const COLLAR_STAND: int = 6


# A station of modules: each placed like a room, with the hatch's 40 px between bolted ports, and
# every layer composed onto one canvas.
static func _build_modules(design: StationDesign) -> StationLayout:
	var layout := StationLayout.new()
	layout.modular = true
	var count: int = design.modules.size()
	# Placing the modules, in raw coordinates with the first one's middle at (0, 0).
	var placed: Array[Dictionary] = []
	var joints: Array[Dictionary] = []
	var bolted := {}
	for i in range(count):
		var module: StationModule = design.modules[i]
		var canvas: Vector2i = module.size()
		var turns: int = 0
		var at: Vector2i = -canvas / 2
		if i > 0 and module.bolts_to_module >= 0 and module.bolts_to_module < i:
			var parent: Dictionary = placed[module.bolts_to_module]
			var parent_module: StationModule = design.modules[module.bolts_to_module]
			var parent_port: StationPort = parent_module.port_named(module.bolts_to_port)
			var own: StationPort = module.port_named(module.own_port)
			if parent_port == null or own == null:
				push_error("%s can't bolt on: it needs ports %s and %s" % [module.display_name, module.bolts_to_port, module.own_port])
			else:
				var parent_face: Vector2i = _turned_face(Vector2(parent_port.face), parent["turns"])
				var parent_point: Vector2i = parent["at"] + _turned_point(Vector2(parent_port.point), parent["size"], parent["turns"])
				while turns < 4 and _turned_face(Vector2(own.face), turns) != -parent_face:
					turns += 1
				# The two ports' outer pixels end up a hatch's length and one pixel apart.
				at = parent_point + parent_face * (HATCH_LENGTH + 1) - _turned_point(Vector2(own.point), canvas, turns)
				bolted["%d:%s" % [module.bolts_to_module, parent_port.port_name]] = true
				bolted["%d:%s" % [i, own.port_name]] = true
				joints.append({"parent": module.bolts_to_module, "parent_port": parent_port.port_name, "child": i, "child_port": own.port_name})
		placed.append({"at": at, "turns": turns, "size": canvas, "turned_size": canvas if turns % 2 == 0 else Vector2i(canvas.y, canvas.x)})

	# Every port, on the raw picture.
	var raw_ports: Array[Dictionary] = []
	for i in range(count):
		var entry: Dictionary = placed[i]
		for port: StationPort in design.modules[i].ports:
			raw_ports.append({
				"name": port.port_name,
				"kind": port.kind,
				"module": i,
				"point": entry["at"] + _turned_point(Vector2(port.point), entry["size"], entry["turns"]),
				"face": _turned_face(Vector2(port.face), entry["turns"]),
				"bolted": bolted.has("%d:%s" % [i, port.port_name]),
			})
	var raw_by_name := {}
	for record: Dictionary in raw_ports:
		raw_by_name["%d:%s" % [record["module"], record["name"]]] = record

	# The hatch pieces: one at each joint, and a collar outside each free dock or airlock port, with a
	# docking ring on a dock's.
	var pieces: Array[Dictionary] = []
	for joint: Dictionary in joints:
		var from: Dictionary = raw_by_name["%d:%s" % [joint["parent"], joint["parent_port"]]]
		var to: Dictionary = raw_by_name["%d:%s" % [joint["child"], joint["child_port"]]]
		pieces.append(_hatch_piece(from["point"], from["face"], "inner", [from["name"], to["name"]]))
	var rings: Array[Dictionary] = []
	var plates: Array[Dictionary] = []
	for record: Dictionary in raw_ports:
		if record["bolted"]:
			continue
		if record["kind"] == StationPort.DOCK or record["kind"] == StationPort.AIRLOCK:
			var piece: Dictionary = _hatch_piece(record["point"], record["face"], record["kind"], [record["name"]])
			piece["free"] = record
			pieces.append(piece)
			if record["kind"] == StationPort.DOCK:
				rings.append(_ring_piece(record["point"], record["face"]))
		elif record["kind"] == StationPort.CAPPED:
			plates.append(_plate_piece(record["point"], record["face"]))

	# How big the picture is.
	var low := Vector2i.ZERO
	var high := Vector2i.ZERO
	for entry: Dictionary in placed:
		low = low.min(entry["at"])
		high = high.max(entry["at"] + entry["turned_size"])
	for piece: Dictionary in pieces + rings:
		low = low.min(piece["rect"].position)
		high = high.max(piece["rect"].end)
	var shift: Vector2i = -low
	var whole: Vector2i = high - low
	layout.origin = shift
	layout.floor_image = Image.create(whole.x, whole.y, false, Image.FORMAT_RGBA8)
	layout.walls_image = Image.create(whole.x, whole.y, false, Image.FORMAT_RGBA8)
	layout.overhead_image = Image.create(whole.x, whole.y, false, Image.FORMAT_RGBA8)
	layout.roof_image = Image.create(whole.x, whole.y, false, Image.FORMAT_RGBA8)
	layout._walkable.resize(whole.x * whole.y)

	# The modules' layers, each turned as the module is.
	var floors_here: Array[Rect2i] = []
	for i in range(count):
		var module: StationModule = design.modules[i]
		var entry: Dictionary = placed[i]
		var at: Vector2i = entry["at"] + shift
		_blend_turned(layout.floor_image, module.floor_texture, entry["turns"], at)
		_blend_turned(layout.walls_image, module.walls_texture, entry["turns"], at)
		_blend_turned(layout.overhead_image, module.overhead_texture, entry["turns"], at)
		_blend_turned(layout.roof_image, module.roof_texture, entry["turns"], at)
		for rect: Rect2i in module.floors:
			var turned_floor: Rect2i = turned_rect(rect, entry["size"], entry["turns"])
			floors_here.append(Rect2i(turned_floor.position + at, turned_floor.size))
		# The shell, for which room each pixel is in: where this module has floor or wall.
		var shell_bytes := PackedByteArray()
		shell_bytes.resize(entry["turned_size"].x * entry["turned_size"].y * 4)
		for texture: Texture2D in [module.floor_texture, module.walls_texture]:
			if texture == null:
				continue
			var layer_bytes: PackedByteArray = turned_image(texture, entry["turns"]).get_data()
			for p in range(mini(layer_bytes.size(), shell_bytes.size()) / 4):
				if layer_bytes[p * 4 + 3] > 0:
					shell_bytes[p * 4 + 3] = 255
		layout.room_areas.append({"image": Image.create_from_data(entry["turned_size"].x, entry["turned_size"].y, false, Image.FORMAT_RGBA8, shell_bytes), "at": at})
		for window: Rect2i in module.windows:
			var turned: Rect2i = turned_rect(window, entry["size"], entry["turns"])
			layout.windows.append(Rect2i(turned.position + at, turned.size))
		for light: OutsideLight in module.outside_lights:
			layout.outside_lights.append({
				"point": Vector2(at) + Vector2(_turned_point(light.point, entry["size"], entry["turns"])) + Vector2(0.5, 0.5),
				"kind": light.kind,
				"port": light.port_name,
			})
		for fixture: LightFixture in module.fixtures:
			layout._add_fixture(design, fixture, Vector2(at) + Vector2(_turned_point(fixture.point, entry["size"], entry["turns"])) + Vector2(0.5, 0.5), i)

	# Props: floor and overhead ones are painted into their layer, standing ones kept apart.
	var blocked: Array[Rect2i] = []
	for i in range(count):
		var module: StationModule = design.modules[i]
		var entry: Dictionary = placed[i]
		var at: Vector2i = entry["at"] + shift
		for placement: PropPlacement in module.props:
			var prop: StationProp = placement.prop
			if prop == null or prop.texture == null:
				continue
			var picture_size := Vector2i(prop.texture.get_size())
			var in_prop: Rect2i = turned_rect(prop.footprint, picture_size, placement.turns) if prop.footprint.size != Vector2i.ZERO else Rect2i()
			var prop_turned_size: Vector2i = picture_size if placement.turns % 2 == 0 else Vector2i(picture_size.y, picture_size.x)
			# Where its picture's top left falls on the module's canvas, then on the picture.
			var in_module: Rect2i = Rect2i(placement.position - in_prop.position, prop_turned_size)
			var on_picture: Rect2i = turned_rect(in_module, entry["size"], entry["turns"])
			var total: int = (placement.turns + entry["turns"]) % 4
			var image: Image = turned_image(prop.texture, total)
			var corner: Vector2i = on_picture.position + at
			match prop.layer:
				StationProp.FLOOR:
					layout.floor_image.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), corner)
				StationProp.OVERHEAD:
					layout.overhead_image.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), corner)
				_:
					var foot: Rect2i = Rect2i()
					if prop.footprint.size != Vector2i.ZERO:
						var in_final: Rect2i = turned_rect(prop.footprint, picture_size, total)
						foot = Rect2i(in_final.position + corner, in_final.size)
						blocked.append(foot)
					layout.props.append({
						"prop": prop, "at": corner, "turns": total, "image": image, "footprint": foot,
						"foot": foot.end.y if foot.size != Vector2i.ZERO else corner.y + image.get_height(), "module": i,
					})
			if prop.spot_kind != "":
				var spot: Vector2i = _turned_point(prop.spot_point(), picture_size, total) + corner
				layout.spots.append({"point": spot, "kind": prop.spot_kind})
			if prop.light != null:
				var light_at: Vector2 = Vector2(_turned_point(prop.light.point, picture_size, total) + corner) + Vector2(0.5, 0.5)
				layout._add_fixture(design, prop.light, light_at, i)

	# A station with no fixtures in its data gets automatic lamps over its floors, as the old rooms do.
	if layout.fixtures.is_empty():
		for i in range(count):
			var entry: Dictionary = placed[i]
			for lamp: Dictionary in _lamps_over(design.modules[i].floors):
				layout.lamps.append({
					"point": Vector2(entry["at"] + shift + _turned_point(lamp["point"], entry["size"], entry["turns"])) + Vector2(0.5, 0.5),
					"reach": lamp["reach"],
					"room": i,
				})

	# The hatch pieces, in every layer.
	var passages: Array[Rect2i] = []
	for piece: Dictionary in pieces:
		var rect := Rect2i(piece["rect"].position + shift, piece["rect"].size)
		var turns: int = piece["turns"]
		_blend_turned(layout.floor_image, design.hatch_floor, turns, rect.position)
		_blend_turned(layout.walls_image, design.hatch_walls, turns, rect.position)
		_blend_turned(layout.overhead_image, design.hatch_overhead, turns, rect.position)
		_blend_turned(layout.roof_image, design.hatch_roof, turns, rect.position)
		var passage_turned: Rect2i = turned_rect(design.hatch_passage, Vector2i(HATCH_ACROSS, HATCH_LENGTH), turns)
		var passage := Rect2i(passage_turned.position + rect.position, passage_turned.size)
		var face: Vector2i = piece["face"]
		var entry := {
			"rect": rect, "turns": turns, "center": Vector2(rect.position) + Vector2(rect.size) * 0.5,
			"kind": piece["kind"], "face": face, "ports": piece["ports"],
		}
		if piece.has("free"):
			# A collar hangs off its shell, so only the shell's half is walkable, up to its door.
			var half: Rect2i = rect
			if face.x > 0:
				half.size.x = COLLAR_WALK
			elif face.x < 0:
				half.position.x += HATCH_LENGTH - COLLAR_WALK
				half.size.x = COLLAR_WALK
			elif face.y > 0:
				half.size.y = COLLAR_WALK
			else:
				half.position.y += HATCH_LENGTH - COLLAR_WALK
				half.size.y = COLLAR_WALK
			passage = passage.intersection(half)
		passages.append(passage)
		layout.hatches.append(entry)
	# Doors inside a module, which have no piece of their own: just leaves in a doorway in the art.
	for i in range(count):
		var entry: Dictionary = placed[i]
		for door: StationPort in design.modules[i].doors:
			var where: Vector2i = entry["at"] + shift + _turned_point(Vector2(door.point), entry["size"], entry["turns"])
			var way: Vector2i = _turned_face(Vector2(door.face), entry["turns"])
			var door_turns: int = 0 if way.x == 0 else 1
			var half := Vector2i(HATCH_ACROSS, HATCH_LENGTH) / 2 if door_turns == 0 else Vector2i(HATCH_LENGTH, HATCH_ACROSS) / 2
			layout.hatches.append({
				"rect": Rect2i(where - half, half * 2), "turns": door_turns, "center": Vector2(where),
				"kind": "door", "face": way, "ports": [door.port_name],
			})
	for ring: Dictionary in rings:
		var rect := Rect2i(ring["rect"].position + shift, ring["rect"].size)
		_blend_turned(layout.roof_image, design.docking_ring_roof, ring["turns"], rect.position)
	for plate: Dictionary in plates:
		var rect := Rect2i(plate["rect"].position + shift, plate["rect"].size)
		_blend_turned(layout.walls_image, design.capped_plate, plate["turns"], rect.position)
		_blend_turned(layout.roof_image, design.capped_plate, plate["turns"], rect.position)

	# The ports, now on the finished picture.
	for record: Dictionary in raw_ports:
		var port := {
			"name": record["name"], "kind": record["kind"], "module": record["module"],
			"shell_point": record["point"] + shift, "point": record["point"] + shift, "face": record["face"], "bolted": record["bolted"],
		}
		layout.ports.append(port)
	for piece: Dictionary in pieces:
		if not piece.has("free"):
			continue
		var record: Dictionary = piece["free"]
		var port: Dictionary = layout.port_named(record["name"])
		var face: Vector2i = record["face"]
		var collar_end: Vector2i = record["point"] + shift + face * (HATCH_LENGTH if record["kind"] == StationPort.AIRLOCK else HATCH_LENGTH + RING_DEPTH)
		port["point"] = collar_end
		port["inner"] = Vector2(record["point"] + shift) + Vector2(face) * float(COLLAR_STAND) + Vector2(0.5, 0.5)
		if record["kind"] == StationPort.DOCK:
			layout.free_ports.append(port)
		else:
			layout.airlock_ports.append(port)

	# Where someone can stand: the floors and the hatch passages, less every wall pixel and every
	# standing prop's footprint.
	var width: int = whole.x
	for rect: Rect2i in floors_here + passages:
		for y in range(maxi(rect.position.y, 0), mini(rect.end.y, whole.y)):
			for x in range(maxi(rect.position.x, 0), mini(rect.end.x, width)):
				layout._walkable[y * width + x] = 1
	var wall_bytes: PackedByteArray = layout.walls_image.get_data()
	for i in range(width * whole.y):
		if wall_bytes[i * 4 + 3] > 127:
			layout._walkable[i] = 0
	for rect: Rect2i in blocked:
		for y in range(maxi(rect.position.y, 0), mini(rect.end.y, whole.y)):
			for x in range(maxi(rect.position.x, 0), mini(rect.end.x, width)):
				layout._walkable[y * width + x] = 0

	layout.image = layout.roof_image
	layout.interior_image = layout.floor_image.duplicate()
	layout.interior_image.blend_rect(layout.walls_image, Rect2i(Vector2i.ZERO, whole), Vector2i.ZERO)
	layout._remember_solid()
	return layout


# One light from the data, with its point already on the picture, kept with its reach in picture pixels.
func _add_fixture(design: StationDesign, fixture: LightFixture, point: Vector2, module: int) -> void:
	fixtures.append({
		"point": point,
		"reach": fixture.reach_metres / Units.METERS_PER_UNIT / design.art_pixel_size,
		"room": module,
		"tint": fixture.tint,
		"circuit": fixture.circuit,
		"brightness": fixture.brightness,
	})


# A hatch piece's place, in raw coordinates, running out of a port's outer pixel the way it faces. It's
# 48 across and centered on the port's pixel, and 40 long starting at the next pixel.
static func _hatch_piece(point: Vector2i, face: Vector2i, kind: String, names: Array) -> Dictionary:
	var rect: Rect2i
	if face.y > 0:
		rect = Rect2i(point.x - HATCH_ACROSS / 2, point.y + 1, HATCH_ACROSS, HATCH_LENGTH)
	elif face.y < 0:
		rect = Rect2i(point.x - HATCH_ACROSS / 2, point.y - HATCH_LENGTH, HATCH_ACROSS, HATCH_LENGTH)
	elif face.x > 0:
		rect = Rect2i(point.x + 1, point.y - HATCH_ACROSS / 2, HATCH_LENGTH, HATCH_ACROSS)
	else:
		rect = Rect2i(point.x - HATCH_LENGTH, point.y - HATCH_ACROSS / 2, HATCH_LENGTH, HATCH_ACROSS)
	return {"rect": rect, "turns": 0 if face.x == 0 else 1, "kind": kind, "face": face, "ports": names}


# A docking ring's place beyond a collar. Its picture is drawn for a collar facing down.
static func _ring_piece(point: Vector2i, face: Vector2i) -> Dictionary:
	var out: int = HATCH_LENGTH + 1
	var rect: Rect2i
	var turns: int
	if face.y > 0:
		rect = Rect2i(point.x - RING_ACROSS / 2, point.y + out, RING_ACROSS, RING_DEPTH)
		turns = 0
	elif face.y < 0:
		rect = Rect2i(point.x - RING_ACROSS / 2, point.y - HATCH_LENGTH - RING_DEPTH, RING_ACROSS, RING_DEPTH)
		turns = 2
	elif face.x > 0:
		rect = Rect2i(point.x + out, point.y - RING_ACROSS / 2, RING_DEPTH, RING_ACROSS)
		turns = 3
	else:
		rect = Rect2i(point.x - HATCH_LENGTH - RING_DEPTH, point.y - RING_ACROSS / 2, RING_DEPTH, RING_ACROSS)
		turns = 1
	return {"rect": rect, "turns": turns}


# A capped port's plate, with its outer edge on the port's outer pixel and the rest inside the shell.
static func _plate_piece(point: Vector2i, face: Vector2i) -> Dictionary:
	var rect: Rect2i
	if face.y > 0:
		rect = Rect2i(point.x - CAPPED_ACROSS / 2, point.y - CAPPED_DEPTH + 1, CAPPED_ACROSS, CAPPED_DEPTH)
	elif face.y < 0:
		rect = Rect2i(point.x - CAPPED_ACROSS / 2, point.y, CAPPED_ACROSS, CAPPED_DEPTH)
	elif face.x > 0:
		rect = Rect2i(point.x - CAPPED_DEPTH + 1, point.y - CAPPED_ACROSS / 2, CAPPED_DEPTH, CAPPED_ACROSS)
	else:
		rect = Rect2i(point.x, point.y - CAPPED_ACROSS / 2, CAPPED_DEPTH, CAPPED_ACROSS)
	return {"rect": rect, "turns": 0 if face.x == 0 else 1}


# A texture as an RGBA8 picture turned that many quarter turns clockwise.
static func turned_image(texture: Texture2D, turns: int) -> Image:
	# A copy, since a texture made from a picture may hand out the picture itself, and turning it
	# would turn it for everyone.
	var picture: Image = texture.get_image().duplicate()
	picture.convert(Image.FORMAT_RGBA8)
	match turns % 4:
		1:
			picture.rotate_90(CLOCKWISE)
		2:
			picture.rotate_180()
		3:
			picture.rotate_90(COUNTERCLOCKWISE)
	return picture


# Paints a texture, turned, onto a layer with its top left corner here. A missing texture adds nothing.
static func _blend_turned(layer: Image, texture: Texture2D, turns: int, at: Vector2i) -> void:
	if texture == null:
		return
	var picture: Image = turned_image(texture, turns)
	layer.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), at)


# Where a rectangle of a picture goes when the picture turns that many quarter turns clockwise.
static func turned_rect(rect: Rect2i, size: Vector2i, turns: int) -> Rect2i:
	if rect.size == Vector2i.ZERO:
		return rect
	var a: Vector2i = _turned_point(Vector2(rect.position), size, turns)
	var b: Vector2i = _turned_point(Vector2(rect.end - Vector2i.ONE), size, turns)
	var low: Vector2i = a.min(b)
	return Rect2i(low, a.max(b) - low + Vector2i.ONE)
