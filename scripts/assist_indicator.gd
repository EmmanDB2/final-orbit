# assist_indicator.gd: shows whether the ship is flying in RAW or ASS.
# From DESIGN.md, "Physics" (Flight modes).
extends Sprite2D

const FRAME_RAW: int = 0
const FRAME_ASS: int = 1


func _on_ship_assist_changed(enabled: bool) -> void:
	frame = FRAME_ASS if enabled else FRAME_RAW
