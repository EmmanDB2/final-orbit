# assist_indicator.gd: shows whether the ship is flying in RAW or SAS.
# From DESIGN.md, "Physics" (Flight modes).
extends Sprite2D

const FRAME_RAW: int = 0
const FRAME_SAS: int = 1


func _on_ship_assist_changed(enabled: bool) -> void:
	frame = FRAME_SAS if enabled else FRAME_RAW
