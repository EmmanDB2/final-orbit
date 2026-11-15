# station_light.gd: works out how a station's ceiling lamps light its insides, once, into a light map
# the size of its picture. Seen from above, a ceiling lamp lights everything under it, furniture and
# all, but not past the walls of the room it hangs in, so each lamp lights only its own room. Lamps
# whose pools overlap blend the way light does, brighter together but never past full. The map has a
# channel for each kind of lamp, so the ones that change can change without working it out again:
# red for steady lamps and the light everywhere, green for failing ones that sputter, and blue for
# emergency lamps that pulse. Slow enough to run on a worker thread. A station with light fixtures
# set in its data (see bake_fixtures) is lit the planned way instead: one channel a power circuit, and
# how much of each circuit's light is warm or red, so the power and the flicker are live and nothing
# is baked again. From DESIGN.md, "Lighting".
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


## The power circuits a fixture can be on, as the channel each one's light is in, in this order.
const CIRCUIT_MAINS: int = 0
const CIRCUIT_FAILING: int = 1
const CIRCUIT_EMERGENCY: int = 2
const CIRCUIT_ALWAYS: int = 3


## Which channel a fixture's circuit name is.
static func circuit_index(circuit: String) -> int:
	match circuit:
		LightFixture.FAILING:
			return CIRCUIT_FAILING
		LightFixture.ALWAYS:
			return CIRCUIT_ALWAYS
	return CIRCUIT_MAINS


## How far a fixture's pool reaches a pixel's middle, from 1 at its middle (or along its strip) to 0 at
## its reach: the pixel's distance to the fixture's point, or, for a strip, to its line segment, which
## makes the pool a stadium.
static func pool_share(at: Vector2, center: Vector2, axis: Vector2, half_length: float, reach: float) -> float:
	var apart: Vector2 = at - center
	if axis != Vector2.ZERO:
		apart -= axis * clampf(apart.dot(axis), -half_length, half_length)
	return 1.0 - apart.length() / reach


## The light of a station's fixtures, worked out once whatever the power does. Three pictures the size
## of the station, four channels each, one per circuit in the order above: "light" is how much of the
## circuit's light reaches the pixel when it's fully on, "warm" is how much of that is warm, and "red"
## how much is red, each from 0 to 255. The mains, failing, and always channels are the fixtures on
## those circuits; the emergency channel is the red pools of the fixtures that are on_emergency, 0.6 of
## their reach. A fixture only lights the room it's in. Each fixture has a "point" and "reach" in
## picture pixels, a "room" (counting from 0), a "tint", a "circuit", a "brightness", whether it's
## "on_emergency", and for a ceiling strip its unit "axis" and "half_length" in pixels (zero axis for a
## point). Each room is its placed "image" and its corner "at".
static func bake_fixtures(size: Vector2i, rooms: Array, fixtures: Array) -> Dictionary:
	var count: int = size.x * size.y
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
	var light := PackedByteArray()
	var warm := PackedByteArray()
	var red := PackedByteArray()
	light.resize(count * 4)
	warm.resize(count * 4)
	red.resize(count * 4)
	# One circuit at a time: how much of the dark is left, and the light it throws in all, in warm, and
	# in red, from every pool that reaches the pixel.
	for circuit in range(4):
		var pools: Array[Dictionary] = []
		for fixture: Dictionary in fixtures:
			if circuit == CIRCUIT_EMERGENCY:
				if fixture.get("on_emergency", false):
					pools.append({"fixture": fixture, "reach": fixture["reach"] * LightFixture.EMERGENCY_REACH_SHARE, "tint": LightFixture.RED})
			elif circuit_index(fixture["circuit"]) == circuit:
				pools.append({"fixture": fixture, "reach": fixture["reach"], "tint": fixture["tint"]})
		if pools.is_empty():
			continue
		var dark := PackedFloat32Array()
		var total := PackedFloat32Array()
		var warm_sum := PackedFloat32Array()
		var red_sum := PackedFloat32Array()
		dark.resize(count)
		dark.fill(1.0)
		total.resize(count)
		warm_sum.resize(count)
		red_sum.resize(count)
		for pool: Dictionary in pools:
			var fixture: Dictionary = pool["fixture"]
			var center: Vector2 = fixture["point"]
			var axis: Vector2 = fixture.get("axis", Vector2.ZERO)
			var half_length: float = fixture.get("half_length", 0.0)
			var reach: float = pool["reach"]
			var room: int = fixture["room"] + 1
			var brightness: float = fixture["brightness"]
			var tint: String = pool["tint"]
			var spread: float = reach + (half_length if axis != Vector2.ZERO else 0.0)
			var low := Vector2i((center - Vector2(spread, spread)).floor()).max(Vector2i.ZERO)
			var high := Vector2i((center + Vector2(spread, spread)).ceil()).min(size - Vector2i.ONE)
			for y in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):
					var i: int = y * size.x + x
					if room_of[i] != room:
						continue
					var share: float = pool_share(Vector2(x + 0.5, y + 0.5), center, axis, half_length, reach)
					if share <= 0.0:
						continue
					var strength: float = brightness * share * share * (3.0 - 2.0 * share)
					dark[i] *= 1.0 - strength
					total[i] += strength
					match tint:
						LightFixture.WARM:
							warm_sum[i] += strength
						LightFixture.RED:
							red_sum[i] += strength
		for i in range(count):
			light[i * 4 + circuit] = int(clampf(1.0 - dark[i], 0.0, 1.0) * 255.0)
			if total[i] > 0.0:
				warm[i * 4 + circuit] = int(clampf(warm_sum[i] / total[i], 0.0, 1.0) * 255.0)
				red[i * 4 + circuit] = int(clampf(red_sum[i] / total[i], 0.0, 1.0) * 255.0)
	return {
		"light": Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, light),
		"warm": Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, warm),
		"red": Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, red),
	}


## What the fixtures' light does at a pixel, as the shader works it out, given the baked pictures, how
## live each circuit is (mains, failing, emergency, always, each from 0 to 1), and the light with
## nothing near. Says the pixel's "light" from 0 to 1 and its "tint": "white", "warm", or "red", the
## one that's more than half the light there, when it's strong enough to show.
static func evaluate(maps: Dictionary, x: int, y: int, live: Vector4, ambient: float, extra_white: float = 0.0) -> Dictionary:
	var light_map: Image = maps["light"]
	var width: int = light_map.get_width()
	var height: int = light_map.get_height()
	var px: int = clampi(x, 0, width - 1)
	var py: int = clampi(y, 0, height - 1)
	var circuits: Color = light_map.get_pixel(px, py)
	var warm_share: Color = maps["warm"].get_pixel(px, py)
	var red_share: Color = maps["red"].get_pixel(px, py)
	var amounts := Vector4(circuits.r * live.x, circuits.g * live.y, circuits.b * live.z, circuits.a * live.w)
	var warm_amount: float = amounts.x * warm_share.r + amounts.y * warm_share.g + amounts.z * warm_share.b + amounts.w * warm_share.a
	var red_amount: float = amounts.x * red_share.r + amounts.y * red_share.g + amounts.z * red_share.b + amounts.w * red_share.a
	var all_amount: float = amounts.x + amounts.y + amounts.z + amounts.w
	var white_amount: float = maxf(all_amount - warm_amount - red_amount, 0.0) + extra_white
	var dark: float = (1.0 - ambient) * (1.0 - amounts.x) * (1.0 - amounts.y) * (1.0 - amounts.z) * (1.0 - amounts.w)
	var total: float = white_amount + warm_amount + red_amount
	var tint: String = "white"
	if red_amount > warm_amount and red_amount > 0.5 * total and red_amount > TINT_FROM:
		tint = "red"
	elif warm_amount > 0.5 * total and warm_amount > TINT_FROM:
		tint = "warm"
	return {"light": 1.0 - dark * (1.0 - extra_white), "tint": tint}


## A tint only shows where there's at least this much of it.
const TINT_FROM: float = 0.12
