# station_light.gd: works out how a station's ceiling lamps light its insides, once, into a light map
# the size of its picture. Seen from above, a ceiling lamp lights everything under it, furniture and
# all, but not past the walls of the room it hangs in, so each lamp lights only its own room. Lamps
# whose pools overlap blend the way light does, brighter together but never past full. The map has a
# channel for each kind of lamp, so the ones that change can change without working it out again:
# red for steady lamps and the light everywhere, green for failing ones that sputter, and blue for
# emergency lamps that pulse. Slow enough to run on a worker thread. From DESIGN.md, "Lighting".
class_name StationLight
extends RefCounted

## Which channel a lamp's light goes in.
const STEADY: int = 0
const FAILING: int = 1
const EMERGENCY: int = 2


## The light map, three bytes a pixel, from none at 0 to full at 255. Each lamp has a "point" and a
## "reach" in picture pixels, the "room" it hangs in, how bright it is as "brightness", and its
## "kind": STEADY, FAILING, or EMERGENCY. Each room's area is its placed "image" and its corner "at".
static func bake(size: Vector2i, rooms: Array, lamps: Array, ambient: float) -> Image:
	var count: int = size.x * size.y
	# Which room each pixel's in, counting from 1, with 0 for none.
	var room_of := PackedByteArray()
	room_of.resize(count)
	for r in range(rooms.size()):
		var picture: Image = rooms[r]["image"]
		var at: Vector2i = rooms[r]["at"]
		var data: PackedByteArray = picture.get_data()
		var width: int = picture.get_width()
		for y in range(picture.get_height()):
			var row: int = (at.y + y) * size.x + at.x
			for x in range(width):
				if data[(y * width + x) * 4 + 3] > 0:
					room_of[row + x] = r + 1
	# How much of the dark is left at each pixel, in each channel, as light multiplies it away.
	var darks: Array[PackedFloat32Array] = []
	for channel in range(3):
		var dark := PackedFloat32Array()
		dark.resize(count)
		dark.fill(1.0)
		darks.append(dark)
	for lamp: Dictionary in lamps:
		var center: Vector2 = lamp["point"]
		var reach: float = lamp["reach"]
		var room: int = lamp["room"] + 1
		var brightness: float = lamp["brightness"]
		var dark: PackedFloat32Array = darks[lamp["kind"]]
		var low := Vector2i((center - Vector2(reach, reach)).floor()).max(Vector2i.ZERO)
		var high := Vector2i((center + Vector2(reach, reach)).ceil()).min(size - Vector2i.ONE)
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var i: int = y * size.x + x
				if room_of[i] != room:
					continue
				var share: float = 1.0 - Vector2(x + 0.5 - center.x, y + 0.5 - center.y).length() / reach
				if share > 0.0:
					dark[i] *= 1.0 - brightness * share * share * (3.0 - 2.0 * share)
		darks[lamp["kind"]] = dark
	var bytes := PackedByteArray()
	bytes.resize(count * 3)
	for i in range(count):
		bytes[i * 3] = int(clampf(ambient + (1.0 - ambient) * (1.0 - darks[STEADY][i]), 0.0, 1.0) * 255.0)
		bytes[i * 3 + 1] = int(clampf(1.0 - darks[FAILING][i], 0.0, 1.0) * 255.0)
		bytes[i * 3 + 2] = int(clampf(1.0 - darks[EMERGENCY][i], 0.0, 1.0) * 255.0)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGB8, bytes)


## Where someone can stand, as a picture: 255 on floors, 0 elsewhere. Lights that move, like a
## helmet lamp, are stopped by everything off the floor.
static func floor_mask(size: Vector2i, walkable: PackedByteArray) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(walkable.size())
	for i in range(walkable.size()):
		bytes[i] = 255 if walkable[i] == 1 else 0
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, bytes)
