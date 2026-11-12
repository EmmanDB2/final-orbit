# module_data.gd: one module of a ship: its own art, and where and how it sits on the ship.
# From DESIGN.md, "Ships" (modules snap to a grid, and their pixels are the ship).
class_name ModuleData
extends Resource

@export var display_name: String = ""
## What the module does, such as cockpit, rcs, tank, engine, or leg.
@export var kind: String = ""
## The module's own art. Its pixels are its mass, collision, and damage.
@export var texture: Texture2D
## What's under the hull, in the same place as the hull's art: the systems first, then the bare
## frame under those. Damage shows them as it goes. Either can be left out.
@export var systems_texture: Texture2D
@export var frame_texture: Texture2D
## Which grid cell it fills, counted from the ship's top-left cell.
@export var cell: Vector2i = Vector2i.ZERO
## How much fuel it holds, in kilograms, if it's a tank.
@export var fuel_capacity: float = 0.0

@export_group("Working parts")
## The pixels that do the module's job, in the module's own art. It keeps working while at
## least half of them are left, however much of the rest is gone. Empty means all of them.
@export var working_rect: Rect2i = Rect2i()
## The pixels of its RCS nozzle, if it has one, in the module's own art.
@export var nozzle_rect: Rect2i = Rect2i()
## Where gas leaves that nozzle, in the module's own art.
@export var nozzle_point: Vector2 = Vector2.ZERO

@export_group("Moving parts")
## False for a part that doesn't sit in a grid cell, such as a landing leg.
@export var on_grid: bool = true
## Where the top-left of its art sits on the ship's grid, in pixels, if it's off the grid.
@export var art_position: Vector2i = Vector2i.ZERO
## The point it moves from, on the ship's grid, in pixels.
@export var hinge: Vector2i = Vector2i.ZERO
## How far that point travels when the part is fully out, in pixels.
@export var travel: Vector2i = Vector2i.ZERO
## True if the part also folds over its hinge on the way out, ending upside down.
@export var folds: bool = false

@export_group("Landing leg")
## How far the leg's shock absorber squeezes up before it bottoms out, in pixels.
@export var stroke: float = 6.0
## How hard a landing the leg soaks up, in world units a second, on top of what the hull can take: a
## ship's safe landing speed adds its working legs' share of this to its hull's, so two of these 62.5
## with a 50 hull make 80.
@export var soak_speed: float = 62.5
## How far the leg sags under the ship standing with full tanks, as a share of its stroke.
@export var sag_share: float = 0.35
