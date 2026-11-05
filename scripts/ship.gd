# ship.gd: the player's ship, seen top-down.
# From DESIGN.md, "Scope ladder" (Tier 0: a single fixed ship).
#
# Ticket 1 only turns the ship. Thrust and orbits come in later tickets.
extends Node2D

## How fast the ship turns, in radians per second.
## @export makes this value editable in the Inspector panel.
@export var turn_speed: float = 2.0


# Godot calls this once per rendered frame.
# delta is the number of seconds since the previous frame.
func _process(delta: float) -> void:
	var axis: float = Input.get_axis("turn_left", "turn_right")

	rotation += axis * turn_speed * delta
