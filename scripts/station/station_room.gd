# station_room.gd: one room of a station: its sprite, its docking ports, and what it bolts onto.
# From DESIGN.md, "Universe generation" (stations are hubs), and CLAUDE.md (data-driven content).
class_name StationRoom
extends Resource

@export var display_name: String = ""
@export var texture: Texture2D
## The same room with its roof off, on the same canvas.
@export var interior_texture: Texture2D
## Where someone can go inside, as rectangles on the sprite: corridors, floors, and doorways.
@export var walkable: Array[Rect2i] = []
## Things to use inside: where each one is on the sprite, and what kind it is.
@export var spot_points: PackedVector2Array = PackedVector2Array()
@export var spot_kinds: PackedStringArray = PackedStringArray()
## The pixel at the outer edge of each port on the sprite, and which way each one faces.
@export var port_points: PackedVector2Array = PackedVector2Array()
@export var port_faces: PackedVector2Array = PackedVector2Array()
## Which earlier room this bolts onto, or -1 for the first room, which everything hangs from.
@export var bolts_to_room: int = -1
## Which of that room's ports it bolts onto, and which of its own ports does the bolting.
@export var bolts_to_port: int = 0
@export var own_port: int = 0
