# prop_placement.gd: one prop put in a module: which one, where, and how it's turned. From DESIGN.md,
# "Universe generation" (stations).
class_name PropPlacement
extends Resource

@export var prop: StationProp
## Where the prop's footprint has its top left corner, in pixels on the module's canvas, once turned.
## A prop with no footprint goes by its picture's top left corner.
@export var position: Vector2i = Vector2i.ZERO
## How many quarter turns clockwise the prop is turned, from 0 to 3.
@export_range(0, 3) var turns: int = 0
