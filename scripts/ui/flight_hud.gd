# flight_hud.gd: builds the flight UI, lays it out for each screen, hides the side panels
# when idle, and decides what each finger is doing. From DESIGN.md, "UI".
#
# The inner screen's RCS pad has rotate buttons and four translate arrows at once. The cover
# screen's compact pad has only the four arrows, and a ROT / TRANS switch flips what they do.
#
# A finger on a widget works that widget. A finger on open space points the ship, and two
# fingers on open space pinch to zoom, so the center of the screen stays clear of hardware.
class_name FlightHud
extends Control

signal zoom_button_pressed(button_name: String)
signal zoom_scaled(factor: float)
signal point_changed(screen_position: Vector2)
signal point_released

const BAR_HEIGHT: float = 44.0
const LEFT_WIDTH: float = 56.0
const RIGHT_WIDTH: float = 140.0
const PAD_BUTTON: float = 44.0
const PAD_MARGIN: float = 4.0
const ZOOM_WIDTH: float = 68.0
const BUTTON_HEIGHT: float = 44.0
const BURN_HEIGHT: float = 76.0
## How much of each hidden panel stays on screen as a strip.
const STRIP: float = 6.0
## How far a finger moves before a touch on open space counts as a drag.
const DRAG_START: float = 6.0

## Seconds with no input before the side panels hide.
@export var auto_hide_seconds: float = 6.0

var _top_bar: TopBar
var _left_panel: Control
var _right_panel: Control
var _zoom_row: Control
var _lever: ThrottleLever
var _burn: BurnButton
var _dial: HeadingDial
var _pad_up: RcsButton
var _pad_down: RcsButton
var _pad_left: RcsButton
var _pad_right: RcsButton
var _rotate_left: RcsButton
var _rotate_right: RcsButton
var _rot_trans_switch: UiButton
var _compact_pad_rotates: bool = false
var _right_height: float = 0.0
var _assist_button: UiButton
var _stab_button: UiButton
var _left_tab: SideTab
var _right_tab: SideTab
var _zoom_buttons: Array[UiButton] = []

var _ship: Node2D
var _is_inner_screen: bool = true
var _idle_seconds: float = 0.0
var _hidden: bool = false
var _hide_amount: float = 0.0
var _finger_widgets: Dictionary = {}
var _space_fingers: Dictionary = {}
var _point_start: Vector2 = Vector2.ZERO
var _pointing: bool = false
var _pinch_gap: float = 0.0
var _tapped_actions: Array[StringName] = []
var _actions_to_release: Array[StringName] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	get_parent().resized.connect(_layout)
	_layout()


## Connects the UI to the flight. The UI only talks to the ship and camera through signals
## and input actions, so the flight code doesn't know it's here.
func connect_flight(ship: Node2D, view: Node, turn_guide: Node) -> void:
	_ship = ship
	ship.flight_data_changed.connect(_top_bar.on_flight_data)
	ship.flight_data_changed.connect(_dial.on_flight_data)
	ship.flight_data_changed.connect((_left_panel as PlatePanel).on_flight_data)
	ship.assist_changed.connect(_on_assist_changed)
	ship.stab_changed.connect(_on_stab_changed)
	_lever.throttle_changed.connect(ship._on_throttle_changed)
	zoom_button_pressed.connect(view._on_zoom_button_pressed)
	zoom_scaled.connect(view._on_zoom_scaled)
	point_changed.connect(turn_guide._on_point_changed)
	point_released.connect(turn_guide._on_point_released)
	_on_assist_changed(ship.assist_enabled)
	_on_stab_changed(ship.stab_enabled)


func _build() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_left_panel = _plate_panel()
	_right_panel = _plate_panel()
	_zoom_row = _child_control(self)
	_top_bar = TopBar.new()
	add_child(_top_bar)

	(_left_panel as PlatePanel).shows_fuel = true
	_lever = ThrottleLever.new()
	_left_panel.add_child(_lever)

	_dial = HeadingDial.new()
	_right_panel.add_child(_dial)
	_assist_button = UiButton.new().setup("ASS", palette.telemetry_green)
	_stab_button = UiButton.new().setup("STAB", palette.telemetry_green)
	_right_panel.add_child(_stab_button)
	_pad_up = RcsButton.new().setup(Vector2.UP, 0, &"translate_forward")
	_pad_down = RcsButton.new().setup(Vector2.DOWN, 0, &"translate_back")
	_pad_left = RcsButton.new().setup(Vector2.LEFT, 0, &"translate_left")
	_pad_right = RcsButton.new().setup(Vector2.RIGHT, 0, &"translate_right")
	_rotate_left = RcsButton.new().setup(Vector2.ZERO, -1, &"turn_left")
	_rotate_right = RcsButton.new().setup(Vector2.ZERO, 1, &"turn_right")
	for button: RcsButton in [_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right]:
		_right_panel.add_child(button)
	_rot_trans_switch = UiButton.new().setup("TRANS", palette.telemetry_cyan)
	_rot_trans_switch.lamp_on = true
	_rot_trans_switch.tapped.connect(_toggle_compact_pad)
	_right_panel.add_child(_rot_trans_switch)
	_burn = BurnButton.new()
	_right_panel.add_child(_burn)
	_assist_button.tapped.connect(_tap_action.bind(&"toggle_assist"))
	_stab_button.tapped.connect(_tap_action.bind(&"toggle_stab"))

	for button_name: String in ["SYS", "ORBIT", "SHIP"]:
		var button: UiButton = UiButton.new().setup(button_name, palette.telemetry_cyan)
		button.tapped.connect(func() -> void: zoom_button_pressed.emit(button_name))
		_zoom_row.add_child(button)
		_zoom_buttons.append(button)

	_left_tab = SideTab.new()
	_right_tab = SideTab.new()
	_right_tab.from_left = false
	add_child(_left_tab)
	add_child(_right_tab)
	_left_tab.dragged_in.connect(_show_panels)
	_right_tab.dragged_in.connect(_show_panels)


func _plate_panel() -> Control:
	var panel: PlatePanel = PlatePanel.new()
	add_child(panel)
	return panel


func _child_control(parent: Control) -> Control:
	var control := Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _layout() -> void:
	var view: Vector2 = get_parent().size
	if view.x <= 0.0:
		return
	# The inner screen is close to square, and the cover screen is much wider.
	_is_inner_screen = view.x / view.y < 1.45
	var body_height: float = view.y - BAR_HEIGHT

	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(view.x, BAR_HEIGHT)

	_left_panel.size = Vector2(LEFT_WIDTH, body_height)
	_lever.position = Vector2(6.0, 10.0)
	_lever.size = Vector2(LEFT_WIDTH - 16.0, body_height - 20.0)

	_zoom_row.size = Vector2(ZOOM_WIDTH * 3.0, BUTTON_HEIGHT)
	for i in range(_zoom_buttons.size()):
		_zoom_buttons[i].position = Vector2(i * ZOOM_WIDTH, 0.0)
		_zoom_buttons[i].size = Vector2(ZOOM_WIDTH, BUTTON_HEIGHT)

	# The inner screen's panel is full height. The cover screen has fewer controls, so its
	# panel only rises as far as they need, leaving more of the view clear.
	_right_height = body_height
	if not _is_inner_screen:
		_right_height = PAD_MARGIN * 4.0 + BUTTON_HEIGHT + PAD_BUTTON * 3.0 + BURN_HEIGHT
	_right_panel.size = Vector2(RIGHT_WIDTH, _right_height)
	var inner_width: float = RIGHT_WIDTH - PAD_MARGIN * 2.0
	_burn.position = Vector2(PAD_MARGIN, _right_height - BURN_HEIGHT - PAD_MARGIN)
	_burn.size = Vector2(inner_width, BURN_HEIGHT)
	(_right_panel as PlatePanel).burn_mark = Rect2(0.0, _burn.position.y, 2.0, BURN_HEIGHT)

	var half_width: float = floorf(inner_width / 2.0)
	var modes_y: float = _burn.position.y - BUTTON_HEIGHT - PAD_MARGIN
	var pad_y: float = 0.0
	if _is_inner_screen:
		_stab_button.position = Vector2(PAD_MARGIN + half_width, modes_y)
		_stab_button.size = Vector2(half_width, BUTTON_HEIGHT)
		_dial.position = Vector2(floorf((RIGHT_WIDTH - 64.0) / 2.0), 6.0)
		_dial.size = Vector2(64.0, 76.0)
		_rotate_left.position = Vector2(PAD_MARGIN, 88.0)
		_rotate_right.position = Vector2(PAD_MARGIN + half_width, 88.0)
		_rotate_left.size = Vector2(half_width, PAD_BUTTON)
		_rotate_right.size = Vector2(half_width, PAD_BUTTON)
		pad_y = 88.0 + PAD_BUTTON + PAD_MARGIN
		_compact_pad_rotates = false
	else:
		pad_y = _burn.position.y - PAD_MARGIN - PAD_BUTTON * 3.0
		_rot_trans_switch.position = Vector2(PAD_MARGIN, pad_y - PAD_MARGIN - BUTTON_HEIGHT)
		_rot_trans_switch.size = Vector2(inner_width, BUTTON_HEIGHT)
		_stab_button.position = Vector2(PAD_MARGIN + PAD_BUTTON, pad_y + PAD_BUTTON)
		_stab_button.size = Vector2(PAD_BUTTON, PAD_BUTTON)
	_rotate_left.visible = _is_inner_screen
	_rotate_right.visible = _is_inner_screen
	_rot_trans_switch.visible = not _is_inner_screen
	_pad_up.position = Vector2(PAD_MARGIN + PAD_BUTTON, pad_y)
	_pad_left.position = Vector2(PAD_MARGIN, pad_y + PAD_BUTTON)
	_pad_right.position = Vector2(PAD_MARGIN + PAD_BUTTON * 2.0, pad_y + PAD_BUTTON)
	_pad_down.position = Vector2(PAD_MARGIN + PAD_BUTTON, pad_y + PAD_BUTTON * 2.0)
	for button: RcsButton in [_pad_up, _pad_down, _pad_left, _pad_right]:
		button.size = Vector2(PAD_BUTTON, PAD_BUTTON)
	_apply_compact_pad()

	# ASS sits with the modes on the inner screen, and in the top bar on the cover screen.
	if _assist_button.get_parent() != null:
		_assist_button.get_parent().remove_child(_assist_button)
	if _is_inner_screen:
		_right_panel.add_child(_assist_button)
		_assist_button.position = Vector2(PAD_MARGIN, modes_y)
		_assist_button.size = Vector2(half_width, BUTTON_HEIGHT)
	else:
		_top_bar.add_child(_assist_button)
		_assist_button.position = Vector2(view.x - 64.0, 0.0)
		_assist_button.size = Vector2(64.0, BAR_HEIGHT)

	_dial.visible = _is_inner_screen

	_left_tab.size = Vector2(12.0, 44.0)
	_right_tab.size = Vector2(12.0, 44.0)
	_left_tab.position = Vector2(STRIP, floorf(BAR_HEIGHT + body_height / 2.0 - 22.0))
	_right_tab.position = Vector2(view.x - STRIP - 12.0, _left_tab.position.y)
	_place_panels()


# Slides the panels by how far hidden they are, leaving strips at the edges.
func _place_panels() -> void:
	var view: Vector2 = get_parent().size
	var left_offset: float = -(LEFT_WIDTH - STRIP) * _hide_amount
	var right_offset: float = (RIGHT_WIDTH - STRIP) * _hide_amount
	_left_panel.position = Vector2(left_offset, BAR_HEIGHT)
	_right_panel.position = Vector2(view.x - RIGHT_WIDTH + right_offset, view.y - _right_height)
	_zoom_row.position = Vector2(LEFT_WIDTH + 4.0, view.y - BUTTON_HEIGHT - 4.0 + (BUTTON_HEIGHT + 8.0) * _hide_amount)
	_left_tab.visible = _hidden
	_right_tab.visible = _hidden


func _process(delta: float) -> void:
	if not _hidden:
		if Input.is_anything_pressed() or not _finger_widgets.is_empty() or _pointing:
			_idle_seconds = 0.0
		else:
			_idle_seconds += delta
		if _idle_seconds >= auto_hide_seconds:
			_hidden = true
	var target: float = 1.0 if _hidden else 0.0
	if _hide_amount != target:
		_hide_amount = move_toward(_hide_amount, target, delta * 4.0)
		_place_panels()


func _physics_process(_delta: float) -> void:
	for action: StringName in _actions_to_release:
		Input.action_release(action)
	_actions_to_release = _tapped_actions
	_tapped_actions = []


func _toggle_compact_pad() -> void:
	_compact_pad_rotates = not _compact_pad_rotates
	_apply_compact_pad()


# Sets what the four arrows do. Rotating only uses left and right, so up and down go blank.
func _apply_compact_pad() -> void:
	if _compact_pad_rotates and not _is_inner_screen:
		_pad_up.set_action(&"", Vector2.UP, 0)
		_pad_down.set_action(&"", Vector2.DOWN, 0)
		_pad_left.set_action(&"turn_left", Vector2.ZERO, -1)
		_pad_right.set_action(&"turn_right", Vector2.ZERO, 1)
		_rot_trans_switch.set_lamp(true, UiStyle.palette().telemetry_amber, "ROT")
	else:
		_pad_up.set_action(&"translate_forward", Vector2.UP, 0)
		_pad_down.set_action(&"translate_back", Vector2.DOWN, 0)
		_pad_left.set_action(&"translate_left", Vector2.LEFT, 0)
		_pad_right.set_action(&"translate_right", Vector2.RIGHT, 0)
		_rot_trans_switch.set_lamp(true, UiStyle.palette().telemetry_cyan, "TRANS")


func _show_panels() -> void:
	_hidden = false
	_idle_seconds = 0.0
	_place_panels()


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	_tapped_actions.append(action)


func _on_assist_changed(enabled: bool) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_assist_button.set_lamp(true, palette.telemetry_green if enabled else palette.telemetry_amber, "ASS" if enabled else "RAW")


func _on_stab_changed(enabled: bool) -> void:
	_stab_button.set_lamp(enabled, UiStyle.palette().telemetry_green, "STAB")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_everything()


## Called when the screen changes, because a fold can drop fingers without saying so.
func _on_screen_fitted(_view_size: Vector2, _inset_top_left: Vector2, _inset_bottom_right: Vector2) -> void:
	_release_everything()


func _release_everything() -> void:
	for index: int in _finger_widgets:
		_finger_widgets[index].finger_up()
	_finger_widgets.clear()
	_space_fingers.clear()
	_stop_pointing()


func _stop_pointing() -> void:
	if _pointing:
		_pointing = false
		point_released.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_finger_down(event.index, event.position)
		else:
			_on_finger_up(event.index)
	elif event is InputEventScreenDrag:
		_on_finger_moved(event.index, event.position)


func _widgets_in_reach() -> Array[UiWidget]:
	var widgets: Array[UiWidget] = []
	if _hidden:
		widgets.append(_left_tab)
		widgets.append(_right_tab)
	else:
		widgets.append(_lever)
		widgets.append(_burn)
		widgets.append(_stab_button)
		widgets.append_array([_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right, _rot_trans_switch])
		widgets.append_array(_zoom_buttons)
	widgets.append(_assist_button)
	return widgets


func _on_finger_down(index: int, position: Vector2) -> void:
	if not _hidden:
		_idle_seconds = 0.0
	for widget: UiWidget in _widgets_in_reach():
		if widget.is_inside_tree() and widget.is_visible_in_tree() and widget.touch_rect().has_point(position):
			_finger_widgets[index] = widget
			widget.finger_down(position)
			return
	# The top bar and plates are hardware too, so touching them doesn't steer.
	if _top_bar.get_global_rect().has_point(position):
		return
	if not _hidden and (_left_panel.get_global_rect().has_point(position) or _right_panel.get_global_rect().has_point(position)):
		return

	_space_fingers[index] = position
	if _space_fingers.size() == 1:
		_point_start = position
	elif _space_fingers.size() == 2:
		_stop_pointing()
		_pinch_gap = _current_gap()


func _on_finger_moved(index: int, position: Vector2) -> void:
	if _finger_widgets.has(index):
		_finger_widgets[index].finger_moved(position)
		return
	if not _space_fingers.has(index):
		return
	_space_fingers[index] = position
	if _space_fingers.size() == 1:
		if _pointing or position.distance_to(_point_start) >= DRAG_START:
			_pointing = true
			point_changed.emit(position)
	elif _space_fingers.size() == 2:
		var gap: float = _current_gap()
		if _pinch_gap > 0.0:
			zoom_scaled.emit(gap / _pinch_gap)
		_pinch_gap = gap


func _on_finger_up(index: int) -> void:
	if _finger_widgets.has(index):
		_finger_widgets[index].finger_up()
		_finger_widgets.erase(index)
		return
	if _space_fingers.has(index):
		_space_fingers.erase(index)
		if _space_fingers.is_empty():
			_stop_pointing()


func _current_gap() -> float:
	var positions: Array = _space_fingers.values()
	return maxf(positions[0].distance_to(positions[1]), 1.0)
