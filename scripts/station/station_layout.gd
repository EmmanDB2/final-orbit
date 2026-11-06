# station_layout.gd: bolts a station's rooms together, port to port, into one picture. Rooms turn
# in quarter turns only, so no pixel moves off the grid.
# From DESIGN.md, "Universe generation" and "Art direction".
class_name StationLayout
extends RefCounted

## All the rooms as one picture.
var image: Image
## Where the first room's middle is on the picture. It's the point that rides the rails.
var origin: Vector2i = Vector2i.ZERO
## The ports with nothing on them, each with its outer "point" on the picture and its "face".
var free_ports: Array[Dictionary] = []


static func build(design: StationDesign) -> StationLayout:
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
		for port in range(room.port_points.size()):
			if not used_ports.has(Vector2i(i, port)):
				layout.free_ports.append({
					"point": entry["at"] - low + _turned_point(room.port_points[port], entry["size"], entry["turns"]),
					"face": _turned_face(room.port_faces[port], entry["turns"]),
				})
	return layout


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
