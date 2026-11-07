# ship_design.gd: everything that defines one ship: its modules, materials, and engines.
# From DESIGN.md, "Ships". Adding a ship means adding a data file, not code, and each module
# brings its own art.
class_name ShipDesign
extends Resource

## What it's called, and what kind of ship it is, for its card.
@export var display_name: String = ""
@export var chip: String = ""
## Size of one module grid cell, in pixels.
@export var cell_size: int = 64
@export var modules: Array[ModuleData] = []
@export var materials: Array[MaterialData] = []
## Main engine thrust, in newtons, with one world unit counting as one meter.
@export var engine_force: float = 0.0
## Where the docking hatch is on the art, from the middle of the grid: the ship's nose.
@export var hatch_point: Vector2 = Vector2.ZERO
## How fast the ship drifts backward off a station when it undocks, in world units per second.
@export var undock_speed: float = 3.0
## How much of its speed the ship keeps bouncing off something solid in space, from 0 to 1.
@export var contact_bounce: float = 0.25
## How long the engine's flame gets flat out, in art pixels.
@export var flame_length: float = 150.0
## RCS turning strength, as force times distance.
@export var rcs_torque: float = 0.0
## How fast the main engine throws its exhaust, in meters per second. Higher is thriftier.
@export var exhaust_velocity: float = 1.0
## RCS translation thrust, in newtons, for moving without turning.
@export var rcs_translate_force: float = 0.0
## How thick each layer of a module with inside art is. A pixel of a layer has this share of
## its material's density and strength, so together the layers make up the whole ship.
@export var skin_thickness: float = 1.0
@export var systems_thickness: float = 1.0
@export var frame_thickness: float = 1.0
## The fastest a hit can be and do no damage, in meters per second.
@export var safe_impact_speed: float = 50.0
## The fastest a landing can be with the legs down and do no damage, in meters per second.
@export var legs_safe_impact_speed: float = 80.0
## How long the legs take to go up or down, in seconds.
@export var legs_seconds: float = 2.0
## How fast fuel escapes a tank that has lost all its pixels, in kilograms per second. A
## smaller hole leaks in proportion.
@export var tank_leak_rate: float = 2000.0
## How fast escaping fuel leaves a hole, in meters per second, which sets how hard it pushes.
@export var vent_speed: float = 800.0
## How much the ship's shape catches the air. 1.0 is the blunt lander.
@export var drag_coefficient: float = 1.0
## How much air heating reads as the top of the scale. Past it, the hull starts burning.
@export var heat_limit: float = 2.0e10
## How long the hull takes to warm up or cool down, in seconds.
@export var hull_heat_seconds: float = 6.0
## How fast a hull burns for each whole step past the top of the scale, in joules per second.
@export var burn_power: float = 2.0e8
## How often a burning hull loses pixels, in seconds.
@export var burn_seconds: float = 0.33
## How much fuel the RCS burns while firing flat out, in kilograms per second.
@export var rcs_fuel_rate: float = 0.0
