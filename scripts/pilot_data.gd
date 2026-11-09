# pilot_data.gd: the numbers for a pilot in a suit. From DESIGN.md, "Player" (EVA, walking on worlds,
# and the suit's limits), and CLAUDE.md (data-driven content).
class_name PilotData
extends Resource

## The sprite sheet, with this many frames across and down, each with the helmet in the middle.
@export var texture: Texture2D
@export var hframes: int = 5
@export var vframes: int = 4
## Which frames of the sheet to loop for each thing the pilot does, drawn facing down or right. The
## other two headings are those mirrored.
@export var walk_down: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4])
@export var walk_side: PackedInt32Array = PackedInt32Array([5, 6, 7, 8, 9])
@export var coast_down: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4])
@export var coast_side: PackedInt32Array = PackedInt32Array([17, 18, 19])
@export var jet_down: PackedInt32Array = PackedInt32Array([10, 11, 12, 13, 14])
@export var jet_side: PackedInt32Array = PackedInt32Array([15, 16])
## How fast those loop, in frames per second.
@export var walk_fps: float = 8.0
@export var coast_fps: float = 3.0
@export var jet_fps: float = 12.0
## The side-view sheet, for walking on worlds, with this many frames across and down. It's drawn
## facing right, and mirrored for left. The boot soles are this far below each frame's middle.
@export var side_texture: Texture2D
@export var side_hframes: int = 8
@export var side_vframes: int = 6
@export var stand_height: float = 26.0
## Which frames of the side sheet to loop standing and walking, and the jump in order: crouch, push
## off, rising, the top, falling, and landing. Then the jetpack firing.
@export var idle_side: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
@export var stride_side: PackedInt32Array = PackedInt32Array([8, 9, 10, 11, 12, 13, 14, 15])
@export var jump_side: PackedInt32Array = PackedInt32Array([16, 17, 18, 19, 20, 21])
@export var hover_side: PackedInt32Array = PackedInt32Array([40, 41, 42, 43])
## How fast standing still loops, and walking at full speed, in frames per second.
@export var idle_fps: float = 3.0
@export var stride_fps: float = 10.0
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
## On the ground: how fast the pilot walks, in world units per second, and how well their boots grip.
## Getting going takes gravity times the grip, up to the walking acceleration above, so low gravity
## is slippery.
@export var ground_walk_speed: float = 50.0
@export var ground_grip: float = 3.0
## How fast a jump leaves the ground, in world units per second, and the tallest step walked up
## without one.
@export var jump_speed: float = 70.0
@export var step_height: float = 8.0
## The hardest the pilot can come down on EVA and land on their feet, in world units per second.
@export var safe_landing_speed: float = 80.0
## Higher than this above the ground, the pilot's flying on EVA again, in world units.
@export var ground_reach: float = 400.0
