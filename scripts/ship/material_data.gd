# material_data.gd: what a ship's pixels are made of.
# From DESIGN.md, "Ships" (each material has a density). Adding a material means adding a
# data file here, not code.
class_name MaterialData
extends Resource

@export var display_name: String = ""
## Mass of one pixel of this material, in kilograms.
@export var density: float = 1.0
## Energy it takes to destroy one pixel of this material, in joules.
@export var strength: float = 500000.0
## The agency palette colors drawn in this material.
@export var colors: PackedColorArray = PackedColorArray()
