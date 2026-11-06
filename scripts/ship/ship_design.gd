# ship_design.gd: everything that defines one ship: its art, modules, materials, and engines.
# From DESIGN.md, "Ships". Adding a ship means adding a data file, not code.
class_name ShipDesign
extends Resource

## The whole ship's art, centered on its module grid.
@export var texture: Texture2D
## Size of one module grid cell, in pixels.
@export var cell_size: int = 64
@export var modules: Array[ModuleData] = []
@export var materials: Array[MaterialData] = []
## Main engine thrust, in newtons, with one world unit counting as one meter.
@export var engine_force: float = 0.0
## RCS turning strength, as force times distance.
@export var rcs_torque: float = 0.0
## How fast the main engine throws its exhaust, in meters per second. Higher is thriftier.
@export var exhaust_velocity: float = 1.0
## How much fuel the RCS burns while firing flat out, in kilograms per second.
@export var rcs_fuel_rate: float = 0.0
