# rough_touch_controls.gd: throwaway touch input, so the game can be flown on the phone.
# From DESIGN.md's open question on touch controls. This isn't the UI: there's nothing
# on screen, and it only presses the same input actions the keys do, so deleting this
# node removes it cleanly.
#
# Left half: put a thumb down anywhere and slide sideways to turn.
# Right half: hold to thrust.
# Mode panel: tap to switch between ASS and RAW.
# Two fingers landing close together: pinch to move one zoom tier at a time.
extends Node

const NO_FINGER: int = -1

## Where a tap switches flight mode, in game pixels from the safe area's top-left corner.
## Covers the panel, with room to miss.
@export var mode_panel_area: Rect2 = Rect2(0.0, 0.0, 90.0, 60.0)
## How far a thumb slides sideways before the ship starts turning, in game pixels.
@export var turn_dead_zone: float = 6.0
## How far a thumb slides for a full-strength turn, in game pixels.
@export var turn_full_distance: float = 30.0
## A second finger starts a pinch if it lands within this share of the screen's width...
@export var pinch_max_start_gap: float = 0.35
## ...and within this many physics ticks of the first. Two thumbs flying won't do both.
@export var pinch_max_start_ticks: int = 15
## How much the gap between pinching fingers changes to move one zoom tier.
@export var pinch_step_ratio: float = 1.3

var _safe_top_left: Vector2 = Vector2.ZERO
var _finger_positions: Dictionary = {}
var _finger_start_ticks: Dictionary = {}
var _turn_finger: int = NO_FINGER
var _turn_anchor_x: float = 0.0
var _thrust_fingers: Array[int] = []
var _pinch_fingers: Array[int] = []
var _pinch_gap: float = 0.0
var _tapped_actions: Array[StringName] = []
var _actions_to_release: Array[StringName] = []


func _on_screen_fitted(_view_size: Vector2, inset_top_left: Vector2, _inset_bottom_right: Vector2) -> void:
	_safe_top_left = inset_top_left
	# Folding or unfolding can drop a finger without saying so, which would stick the engine on.
	_release_everything()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_everything()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_finger_down(event.index, event.position)
		else:
			_on_finger_up(event.index)
	elif event is InputEventScreenDrag:
		_on_finger_moved(event.index, event.position)


# A tap has to stay pressed for a physics tick, or the game could miss it.
func _physics_process(_delta: float) -> void:
	for action: StringName in _actions_to_release:
		Input.action_release(action)
	_actions_to_release = _tapped_actions
	_tapped_actions = []


func _on_finger_down(index: int, position: Vector2) -> void:
	if mode_panel_area.has_point(position - _safe_top_left):
		_tap(&"toggle_assist")
		return

	var partner: int = _find_pinch_partner(position)
	_finger_positions[index] = position
	_finger_start_ticks[index] = Engine.get_physics_frames()

	if partner != NO_FINGER:
		_start_pinch(partner, index)
	elif _pinch_fingers.is_empty():
		if position.x < _screen_width() / 2.0:
			if _turn_finger == NO_FINGER:
				_turn_finger = index
				_turn_anchor_x = position.x
		else:
			_thrust_fingers.append(index)
			Input.action_press(&"thrust")


func _on_finger_moved(index: int, position: Vector2) -> void:
	if not _finger_positions.has(index):
		return
	_finger_positions[index] = position

	if index == _turn_finger:
		_update_turn(position.x)
	elif _pinch_fingers.has(index):
		_update_pinch()


func _on_finger_up(index: int) -> void:
	_finger_positions.erase(index)
	_finger_start_ticks.erase(index)

	if index == _turn_finger:
		_stop_turning()
	if _thrust_fingers.has(index):
		_stop_thrust_finger(index)
	if _pinch_fingers.has(index):
		_pinch_fingers.clear()


func _find_pinch_partner(position: Vector2) -> int:
	if not _pinch_fingers.is_empty():
		return NO_FINGER
	var now: int = Engine.get_physics_frames()
	for other: int in _finger_positions:
		var is_recent: bool = now - _finger_start_ticks[other] <= pinch_max_start_ticks
		if is_recent and position.distance_to(_finger_positions[other]) <= pinch_max_start_gap * _screen_width():
			return other
	return NO_FINGER


func _start_pinch(first: int, second: int) -> void:
	if first == _turn_finger:
		_stop_turning()
	if _thrust_fingers.has(first):
		_stop_thrust_finger(first)
	_pinch_fingers = [first, second]
	_pinch_gap = _current_pinch_gap()


func _update_pinch() -> void:
	var gap: float = _current_pinch_gap()
	if gap >= _pinch_gap * pinch_step_ratio:
		_tap(&"zoom_in")
		_pinch_gap = gap
	elif gap <= _pinch_gap / pinch_step_ratio:
		_tap(&"zoom_out")
		_pinch_gap = gap


func _current_pinch_gap() -> float:
	var first: Vector2 = _finger_positions[_pinch_fingers[0]]
	var second: Vector2 = _finger_positions[_pinch_fingers[1]]
	return maxf(first.distance_to(second), 1.0)


func _update_turn(x: float) -> void:
	var offset: float = x - _turn_anchor_x
	# Past full strength the anchor follows the thumb, so reversing takes effect at once.
	if absf(offset) > turn_full_distance:
		_turn_anchor_x = x - signf(offset) * turn_full_distance
		offset = signf(offset) * turn_full_distance

	var strength: float = clampf(inverse_lerp(turn_dead_zone, turn_full_distance, absf(offset)), 0.0, 1.0)
	if strength <= 0.0:
		_release_turn_actions()
	elif offset > 0.0:
		Input.action_release(&"turn_left")
		Input.action_press(&"turn_right", strength)
	else:
		Input.action_release(&"turn_right")
		Input.action_press(&"turn_left", strength)


func _stop_turning() -> void:
	_turn_finger = NO_FINGER
	_release_turn_actions()


func _release_turn_actions() -> void:
	Input.action_release(&"turn_left")
	Input.action_release(&"turn_right")


func _stop_thrust_finger(index: int) -> void:
	_thrust_fingers.erase(index)
	if _thrust_fingers.is_empty():
		Input.action_release(&"thrust")


func _tap(action: StringName) -> void:
	Input.action_press(action)
	_tapped_actions.append(action)


func _release_everything() -> void:
	if _turn_finger != NO_FINGER:
		_stop_turning()
	if not _thrust_fingers.is_empty():
		_thrust_fingers.clear()
		Input.action_release(&"thrust")
	_pinch_fingers.clear()
	_finger_positions.clear()
	_finger_start_ticks.clear()


func _screen_width() -> float:
	return get_viewport().get_visible_rect().size.x
