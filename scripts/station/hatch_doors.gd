# hatch_doors.gd: the sliding doors of a station of modules. Each hatch (and each door inside a module)
# has two leaves that meet in the middle of its opening and slide into its side walls. They open over
# 0.25 s when the pilot comes within 32 px of the hatch's middle, and close 0.6 s after the pilot's
# farther, so the way through is always open by the time anyone gets to it. Something else, like an
# airlock's cycle, can hold a door open or shut instead. From DESIGN.md, "Universe generation" (stations)
# and the new Kapteyn-3's hatches.
class_name HatchDoors
extends RefCounted

## How long the leaves take to slide open or shut, in seconds.
const SLIDE_SECONDS: float = 0.25
## How long after the pilot's moved off they wait before shutting, in seconds.
const CLOSE_AFTER_SECONDS: float = 0.6
## How near the pilot has to be to a hatch's middle for it to open, in station pixels.
const NEAR_PIXELS: float = 32.0
## The hatch picture's size, running up and down, before it's turned.
const HATCH_SIZE := Vector2i(StationLayout.HATCH_ACROSS, StationLayout.HATCH_LENGTH)
## A forced state: let the pilot's nearness decide, hold shut, or hold open.
const FREE: int = -1
const SHUT: int = 0
const OPEN: int = 1

# Each door: its hatch's "center" and "kind" and "ports", how far open it is as "open" (0 to 1), how
# long since the pilot was near as "idle", whether something's holding it as "forced", and its two
# leaves, each with its "sprite" and the "closed" and "opened" positions of its top left corner on the
# station's picture.
var _doors: Array[Dictionary] = []


## Puts a pair of leaves in each of the hatches, as children of this node, with their corner positions
## in station pixels less the origin. make_material is called with where a leaf's top left corner is,
## and gives the material the leaf is drawn with.
func build(parent: Node2D, hatches: Array[Dictionary], design: StationDesign, origin: Vector2i, make_material: Callable) -> void:
	for hatch: Dictionary in hatches:
		var turns: int = hatch["turns"]
		var rect: Rect2i = hatch["rect"]
		var door := {
			"center": hatch["center"], "kind": hatch["kind"], "ports": hatch["ports"],
			"open": 0.0, "idle": CLOSE_AFTER_SECONDS, "forced": FREE, "leaves": [],
		}
		var leaves: Array = [
			[design.hatch_door_left, design.door_left_closed, design.door_left_open],
			[design.hatch_door_right, design.door_right_closed, design.door_right_open],
		]
		for leaf: Array in leaves:
			var texture: Texture2D = leaf[0]
			if texture == null:
				continue
			var turned: Image = StationLayout.turned_image(texture, turns)
			var picture_size: Vector2i = Vector2i(texture.get_size())
			var closed: Rect2i = StationLayout.turned_rect(Rect2i(leaf[1], picture_size), HATCH_SIZE, turns)
			var opened: Rect2i = StationLayout.turned_rect(Rect2i(leaf[2], picture_size), HATCH_SIZE, turns)
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(turned)
			sprite.centered = false
			sprite.material = make_material.call(Vector2(rect.position + closed.position))
			sprite.position = Vector2(rect.position + closed.position - origin)
			parent.add_child(sprite)
			door["leaves"].append({
				"sprite": sprite,
				"closed": Vector2(rect.position + closed.position),
				"opened": Vector2(rect.position + opened.position),
			})
		_doors.append(door)


## How many doors there are.
func count() -> int:
	return _doors.size()


## The first door that's on this port, of this kind ("inner", "dock", "airlock", or "door"), or -1.
func find(port_name: String, kind: String) -> int:
	for i in range(_doors.size()):
		if _doors[i]["kind"] == kind and _doors[i]["ports"].has(port_name):
			return i
	return -1


## How far open a door is, from 0 shut to 1 open.
func openness(index: int) -> float:
	return _doors[index]["open"]


## Holds a door shut, holds it open, or lets the pilot's nearness decide again.
func force(index: int, state: int) -> void:
	_doors[index]["forced"] = state


## Moves every door on a bit, given where the pilot is on the station's picture, or somewhere far off
## if they aren't in the station.
func update(delta: float, pilot: Vector2, origin: Vector2i) -> void:
	for door: Dictionary in _doors:
		var want_open: bool
		if door["forced"] != FREE:
			want_open = door["forced"] == OPEN
		else:
			if pilot.distance_to(door["center"]) <= NEAR_PIXELS:
				door["idle"] = 0.0
			else:
				door["idle"] += delta
			want_open = door["idle"] < CLOSE_AFTER_SECONDS
		var before: float = door["open"]
		door["open"] = move_toward(before, 1.0 if want_open else 0.0, delta / SLIDE_SECONDS)
		if door["open"] == before and delta > 0.0:
			continue
		for leaf: Dictionary in door["leaves"]:
			var at: Vector2 = leaf["closed"].lerp(leaf["opened"], door["open"]).round()
			var sprite: Sprite2D = leaf["sprite"]
			sprite.position = at - Vector2(origin)
			sprite.material.set_shader_parameter("sprite_at", at)
