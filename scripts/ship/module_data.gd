# module_data.gd: one module of a ship, sitting on the fixed module grid.
# From DESIGN.md, "Ships" (modules snap to a grid, and their pixels are the ship).
class_name ModuleData
extends Resource

@export var display_name: String = ""
## What the module does, such as cockpit, rcs, tank, or engine.
@export var kind: String = ""
## Which grid cell it fills, counted from the ship's top-left cell.
@export var cell: Vector2i = Vector2i.ZERO
## How much fuel it holds, in kilograms, if it's a tank.
@export var fuel_capacity: float = 0.0
