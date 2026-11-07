# pilot_data.gd: the numbers for a pilot in a suit. From DESIGN.md, "Player" (EVA, and the suit's
# limits), and CLAUDE.md (data-driven content).
class_name PilotData
extends Resource

@export var texture: Texture2D
## How hard the jetpack pushes, in world units per second squared.
@export var jet_acceleration: float = 12.0
## How many seconds of full push the jetpack holds. It fills up aboard the ship or a station.
@export var jet_seconds: float = 60.0
## How fast the pilot gets around inside, in world units per second, and how quickly they get going.
@export var walk_speed: float = 120.0
@export var walk_acceleration: float = 700.0
## How fast the pilot turns to face where they're going, in radians per second.
@export var turn_speed: float = 6.0
## How far the pilot's body reaches from their middle, for touching things, in world units.
@export var body_radius: float = 12.0
## How close and how slow the pilot has to be to board a ship.
@export var board_reach: float = 90.0
@export var board_speed: float = 12.0
## How close the pilot has to be to an outside hatch to go in, and to anything to use it inside.
@export var hatch_reach: float = 90.0
@export var use_reach: float = 44.0
## How fast the pilot drifts away from a ship or station on leaving it, in world units per second.
@export var push_off_speed: float = 2.0
