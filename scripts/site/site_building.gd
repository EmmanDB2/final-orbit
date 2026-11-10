# site_building.gd: one building at a place on a world: its art, outside and cut away, and where it
# stands along the ground. From DESIGN.md, "Places on worlds".
class_name SiteBuilding
extends Resource

@export var display_name: String = ""
## The outside, and the inside with the front wall gone, on canvases the same size, standing on
## their bottom edge. Open steelwork, like a tower, has no inside.
@export var texture: Texture2D
@export var interior_texture: Texture2D
## How far the building's middle is from the site's middle along the ground, in world units,
## clockwise positive.
@export var offset: float = 0.0
## How far the art's bottom sits below the ground, in world units, for a pad set flush with it.
@export var sink: float = 0.0
## The part of the art a ship hits, in art pixels. Empty means all of it. A tower's swing arms are
## left out, since they swing clear of a ship coming down onto the pad.
@export var solid_box: Rect2 = Rect2()
## Inside, measured on the art in its pixels from the top left. Floors are where the pilot walks, as
## (left end, right end, height of the floor's surface); ladders join them, as (x, top, bottom).
@export var floors: PackedVector3Array = PackedVector3Array()
@export var ladders: PackedVector3Array = PackedVector3Array()
## The door, as (x, floor height), where the pilot goes in and out. Below zero means no way in.
@export var door: Vector2 = Vector2(-1.0, -1.0)
## Terminals, each as (x, floor height), and what each says when used.
@export var terminals: PackedVector2Array = PackedVector2Array()
@export var terminal_messages: PackedStringArray = PackedStringArray()
