# flight_hud.gd: builds the flight UI, lays it out for each screen, hides the side panels
# when idle, and decides what each finger is doing. From DESIGN.md, "UI".
#
# A finger on a widget works that widget. On open space, a tap focuses the camera on what's under it,
# a hold opens that thing's card, a drag points the ship, and two fingers pinch to zoom, so the center
# of the screen stays clear of hardware.
class_name FlightHud
extends Control

signal zoom_button_pressed(button_name: String)
signal zoom_scaled(factor: float)
signal point_changed(screen_position: Vector2)
signal point_released
## Emitted when open space is tapped, not dragged or held.
signal space_tapped(screen_position: Vector2)
## Emitted when the panels move, with the part of the view they leave clear.
signal clear_area_changed(area: Rect2)
## Emitted when the layout changes, with where the comms line goes.
signal comms_area_changed(area: Rect2)

const BAR_HEIGHT: float = 44.0
const LEFT_WIDTH: float = 60.0
const RIGHT_WIDTH: float = 148.0
const EDGE: float = 8.0
const PAD_BUTTON: float = 44.0
const ROW_HEIGHT: float = 40.0
const ROW_GAP: float = 4.0
const DIAL_SIZE: float = 76.0
const ZOOM_WIDTH: float = 68.0
const BURN_HEIGHT: float = 72.0
const CENTER_BUTTON_WIDTH: float = 96.0
## How far below the top bar RESTART and UNDOCK sit.
const CENTER_BUTTON_DROP: float = 14.0
const CHAT_WIDTH: float = 44.0
const FLIGHT_WIDTH: float = 80.0
## How much of each hidden panel stays on screen as a strip.
const STRIP: float = 6.0
## How far a finger moves before a touch on open space counts as a drag.
const DRAG_START: float = 6.0
## How long a finger stays still before it's a hold rather than a tap, in milliseconds.
const HOLD_START: int = 400

## Seconds with no input before the side panels hide.
@export var auto_hide_seconds: float = 6.0

var _top_bar: TopBar
var _left_panel: SidePanel
var _right_panel: SidePanel
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
var _right_height: float = 0.0
var _left_height: float = 0.0
var _assist_button: UiButton
var _stab_button: UiButton
var _left_tab: SideTab
var _right_tab: SideTab
var _zoom_buttons: Array[UiButton] = []
var _restart_button: UiButton
var _undock_button: UiButton
var _chat_button: UiButton
var _flight_button: UiButton
var _comms_log: CommsLog
var _flight_menu: FlightMenu
var _card: ContextCard
var _tap_possible: bool = false
var _tap_started: int = 0
var _legs_button: UiButton
var _eva_button: UiButton
var _action_button: UiButton
var _center_view_x: float = 0.0

var _ship: Node2D
var _pilot: Pilot
var _turn_guide: Node
var _comms: CommsLine
var _mode: String = Pilot.ABOARD
var _can_leave: bool = false
var _ship_stranded: bool = false
var _pilot_stranded: bool = false
var _docked: bool = false
var _view: Node
var _catalog: WorldCatalog
var _markers: TargetMarkers
var _idle_seconds: float = 0.0
var _hidden: bool = false
var _hide_amount: float = 0.0
var _card_refresh: float = 0.0
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
	# It has to keep working while the flight is paused, to unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_parent().resized.connect(_layout)
	_layout()
	_hidden = false
	_idle_seconds = 0.0
	_place_panels()


## Connects the UI to the flight. The UI only talks to the ship and camera through signals
## and input actions, so the flight code doesn't know it's here.
func connect_flight(ship: Node2D, view: Node, turn_guide: Node, catalog: WorldCatalog, markers: TargetMarkers, comms: CommsLine, pilot: Pilot) -> void:
	_ship = ship
	_pilot = pilot
	_turn_guide = turn_guide
	_comms = comms
	_view = view
	_catalog = catalog
	_markers = markers
	_comms_log.comms = comms
	ship.flight_data_changed.connect(_on_ship_data)
	ship.flight_data_changed.connect(catalog.on_flight_data)
	pilot.flight_data_changed.connect(_show_flight_data)
	pilot.mode_changed.connect(_on_pilot_mode_changed)
	pilot.action_changed.connect(_on_action_changed)
	pilot.can_leave_changed.connect(_on_can_leave_changed)
	pilot.stranded_changed.connect(_on_pilot_stranded_changed)
	ship.assist_changed.connect(_on_assist_changed)
	ship.stab_changed.connect(_on_stab_changed)
	ship.stranded_changed.connect(_on_stranded_changed)
	ship.docked_changed.connect(_on_docked_changed)
	ship.legs_changed.connect(_on_legs_changed)
	_on_legs_changed(ship.legs_down, false)
	_lever.throttle_changed.connect(ship._on_throttle_changed)
	zoom_button_pressed.connect(view._on_zoom_button_pressed)
	zoom_scaled.connect(view._on_zoom_scaled)
	view.view_rolled.connect(_dial.on_view_rolled)
	view.zoom_stop_changed.connect(_on_zoom_stop_changed)
	space_tapped.connect(view._on_space_tapped)
	point_changed.connect(turn_guide._on_point_changed)
	point_released.connect(turn_guide._on_point_released)
	_on_assist_changed(ship.assist_enabled)
	_on_stab_changed(ship.stab_enabled)


func _build() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_left_panel = _side_panel()
	_right_panel = _side_panel()
	_zoom_row = _child_control(self)
	_top_bar = TopBar.new()
	add_child(_top_bar)
	_restart_button = UiButton.new().setup("RESTART", palette.telemetry_amber)
	_restart_button.lamp_on = true
	_restart_button.visible = false
	_restart_button.tapped.connect(_restart)
	add_child(_restart_button)
	_undock_button = UiButton.new().setup("UNDOCK", palette.telemetry_cyan)
	_undock_button.lamp_on = true
	_undock_button.visible = false
	_undock_button.tapped.connect(_tap_action.bind(&"undock"))
	add_child(_undock_button)
	_action_button = UiButton.new().setup("", palette.telemetry_cyan)
	_action_button.lamp_on = true
	_action_button.visible = false
	_action_button.tapped.connect(_tap_action.bind(&"interact"))
	add_child(_action_button)

	_chat_button = UiButton.new().setup("", palette.telemetry_cyan)
	_chat_button.icon = "chat"
	_chat_button.tapped.connect(_toggle_comms_log)
	_top_bar.add_child(_chat_button)
	_flight_button = UiButton.new().setup("FLIGHT", palette.telemetry_cyan)
	_flight_button.icon = "menu"
	_flight_button.text_size = 1
	_flight_button.tapped.connect(_toggle_flight_menu)
	_top_bar.add_child(_flight_button)

	_left_panel.shows_fuel = true
	_lever = ThrottleLever.new()
	_left_panel.add_child(_lever)

	_dial = HeadingDial.new()
	_right_panel.add_child(_dial)
	_pad_up = RcsButton.new().setup(Vector2.UP, 0, &"translate_forward")
	_pad_down = RcsButton.new().setup(Vector2.DOWN, 0, &"translate_back")
	_pad_left = RcsButton.new().setup(Vector2.LEFT, 0, &"translate_left")
	_pad_right = RcsButton.new().setup(Vector2.RIGHT, 0, &"translate_right")
	_rotate_left = RcsButton.new().setup(Vector2.ZERO, -1, &"turn_left")
	_rotate_right = RcsButton.new().setup(Vector2.ZERO, 1, &"turn_right")
	for button: RcsButton in [_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right]:
		_right_panel.add_child(button)
	_eva_button = UiButton.new().setup("EVA", palette.telemetry_cyan)
	_eva_button.visible = false
	_right_panel.add_child(_eva_button)
	_eva_button.tapped.connect(_tap_action.bind(&"eva"))
	_legs_button = UiButton.new().setup("LEGS", palette.telemetry_cyan)
	_stab_button = UiButton.new().setup("STAB", palette.telemetry_cyan)
	_assist_button = UiButton.new().setup("ASSIST", palette.telemetry_cyan)
	for button: UiButton in [_legs_button, _stab_button, _assist_button]:
		_right_panel.add_child(button)
	_legs_button.tapped.connect(_tap_action.bind(&"toggle_legs"))
	_stab_button.tapped.connect(_tap_action.bind(&"toggle_stab"))
	_assist_button.tapped.connect(_tap_action.bind(&"toggle_assist"))
	_burn = BurnButton.new()
	_right_panel.add_child(_burn)

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

	_card = ContextCard.new()
	_card.visible = false
	_card.target_pressed.connect(_on_card_target_pressed)
	_card.focus_pressed.connect(_on_card_focus_pressed)
	add_child(_card)
	_comms_log = CommsLog.new()
	_comms_log.visible = false
	add_child(_comms_log)
	_flight_menu = FlightMenu.new()
	_flight_menu.visible = false
	_flight_menu.pause_pressed.connect(_toggle_pause)
	_flight_menu.restart_pressed.connect(_restart)
	add_child(_flight_menu)


func _side_panel() -> SidePanel:
	var panel: SidePanel = SidePanel.new()
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
	var body_height: float = view.y - BAR_HEIGHT
	var bottom_row_y: float = view.y - EDGE - ROW_HEIGHT

	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(view.x, BAR_HEIGHT)
	_flight_button.size = Vector2(FLIGHT_WIDTH, 30.0)
	_flight_button.position = Vector2(view.x - EDGE - FLIGHT_WIDTH, 7.0)
	_chat_button.size = Vector2(CHAT_WIDTH, 30.0)
	_chat_button.position = Vector2(_flight_button.position.x - 6.0 - CHAT_WIDTH, 7.0)

	_center_view_x = view.x / 2.0
	_place_center_buttons()

	# The lever and fuel gauge stop above the zoom buttons, and the gauge is what stays as the strip.
	_left_height = bottom_row_y - BAR_HEIGHT - 16.0
	_left_panel.size = Vector2(LEFT_WIDTH, _left_height)
	_left_panel.gauge_height = _left_height - 12.0
	_lever.position = Vector2(8.0, 6.0)
	_lever.size = Vector2(44.0, _left_height - 12.0)

	_zoom_row.size = Vector2((ZOOM_WIDTH + ROW_GAP) * 3.0, ROW_HEIGHT)
	for i in range(_zoom_buttons.size()):
		_zoom_buttons[i].position = Vector2(i * (ZOOM_WIDTH + ROW_GAP), 0.0)
		_zoom_buttons[i].size = Vector2(ZOOM_WIDTH, ROW_HEIGHT)

	# The right side: dial, switch, and pad from the top, and modes and BURN from the bottom.
	_right_height = body_height
	_right_panel.size = Vector2(RIGHT_WIDTH, _right_height)
	var inner_width: float = RIGHT_WIDTH - EDGE * 2.0
	_dial.size = Vector2(DIAL_SIZE, DIAL_SIZE)
	_dial.position = Vector2(floorf((RIGHT_WIDTH - DIAL_SIZE) / 2.0), 6.0)
	var pad_y: float = _dial.position.y + DIAL_SIZE + 12.0
	# The arrows make a cross, and the two turns sit in its top corners.
	_rotate_left.position = Vector2(EDGE, pad_y)
	_rotate_right.position = Vector2(EDGE + PAD_BUTTON * 2.0, pad_y)
	_pad_up.position = Vector2(EDGE + PAD_BUTTON, pad_y)
	_pad_left.position = Vector2(EDGE, pad_y + PAD_BUTTON)
	_pad_right.position = Vector2(EDGE + PAD_BUTTON * 2.0, pad_y + PAD_BUTTON)
	_pad_down.position = Vector2(EDGE + PAD_BUTTON, pad_y + PAD_BUTTON * 2.0)
	for button: RcsButton in [_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right]:
		button.size = Vector2(PAD_BUTTON, PAD_BUTTON)

	_burn.size = Vector2(inner_width, BURN_HEIGHT)
	_burn.position = Vector2(EDGE, _right_height - EDGE - BURN_HEIGHT)
	_right_panel.burn_mark = Rect2(0.0, _burn.position.y, 2.0, BURN_HEIGHT)
	var row_y: float = _burn.position.y - 12.0 - ROW_HEIGHT
	for button: UiButton in [_assist_button, _stab_button, _legs_button, _eva_button]:
		button.size = Vector2(inner_width, ROW_HEIGHT)
		button.position = Vector2(EDGE, row_y)
		row_y -= ROW_HEIGHT + ROW_GAP

	_left_tab.size = Vector2(12.0, 44.0)
	_right_tab.size = Vector2(12.0, 44.0)
	_left_tab.position = Vector2(STRIP, floorf(BAR_HEIGHT + body_height / 2.0 - 22.0))
	_right_tab.position = Vector2(view.x - STRIP - 12.0, _left_tab.position.y)

	_comms_log.place(Vector2(view.x - EDGE, BAR_HEIGHT + 2.0))
	_flight_menu.place(Vector2(view.x - EDGE, BAR_HEIGHT + 2.0))
	var comms_left: float = EDGE + (ZOOM_WIDTH + ROW_GAP) * 3.0 + 8.0
	comms_area_changed.emit(Rect2(comms_left, bottom_row_y, view.x - RIGHT_WIDTH - comms_left - 4.0, ROW_HEIGHT))
	_place_panels()


# Whichever of these are up sit side by side, under the top bar.
func _place_center_buttons() -> void:
	var showing: Array[UiButton] = []
	for button: UiButton in [_restart_button, _undock_button, _action_button]:
		if button.visible:
			showing.append(button)
	var total: float = showing.size() * CENTER_BUTTON_WIDTH + maxi(showing.size() - 1, 0) * ROW_GAP
	var x: float = floorf(_center_view_x - total / 2.0)
	for button: UiButton in showing:
		button.size = Vector2(CENTER_BUTTON_WIDTH, ROW_HEIGHT)
		button.position = Vector2(x, BAR_HEIGHT + CENTER_BUTTON_DROP)
		x += CENTER_BUTTON_WIDTH + ROW_GAP


# Slides the panels by how far hidden they are, leaving strips at the edges.
func _place_panels() -> void:
	var view: Vector2 = get_parent().size
	var left_offset: float = -(LEFT_WIDTH - STRIP) * _hide_amount
	var right_offset: float = (RIGHT_WIDTH - STRIP) * _hide_amount
	_left_panel.position = Vector2(left_offset, BAR_HEIGHT + 8.0)
	_right_panel.position = Vector2(view.x - RIGHT_WIDTH + right_offset, view.y - _right_height)
	_zoom_row.position = Vector2(EDGE, view.y - EDGE - ROW_HEIGHT + (ROW_HEIGHT + EDGE * 2.0) * _hide_amount)
	_left_tab.visible = _hidden
	_right_tab.visible = _hidden
	_right_panel.mark_shows = _hide_amount > 0.0
	# Slid off the safe area, it could still show in the space around a camera cutout.
	_lever.visible = _mode == Pilot.ABOARD and _hide_amount < 1.0
	var clear_left: float = _left_panel.position.x + LEFT_WIDTH
	clear_area_changed.emit(Rect2(clear_left, BAR_HEIGHT, _right_panel.position.x - clear_left,
			view.y - EDGE - ROW_HEIGHT - BAR_HEIGHT - 4.0))


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
	_check_for_hold()
	_keep_card_current(delta)


func _physics_process(_delta: float) -> void:
	for action: StringName in _actions_to_release:
		Input.action_release(action)
	_actions_to_release = _tapped_actions
	_tapped_actions = []


func _show_panels() -> void:
	_hidden = false
	_idle_seconds = 0.0
	_place_panels()


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	_tapped_actions.append(action)


func _on_assist_changed(enabled: bool) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_assist_button.set_lamp(true, palette.telemetry_cyan if enabled else palette.telemetry_amber, "ASSIST" if enabled else "RAW")


func _on_legs_changed(down: bool, moving: bool) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_legs_button.set_lamp(down or moving, palette.telemetry_amber if moving else palette.telemetry_cyan, "LEGS")


func _on_stab_changed(enabled: bool) -> void:
	_stab_button.set_lamp(enabled, UiStyle.palette().telemetry_cyan, "STAB")


func _on_zoom_stop_changed(stop_name: String) -> void:
	for button: UiButton in _zoom_buttons:
		button.set_lamp(button.label == stop_name, UiStyle.palette().telemetry_cyan, button.label)


func _toggle_comms_log() -> void:
	_comms_log.visible = not _comms_log.visible
	_flight_menu.visible = false
	_chat_button.set_lamp(_comms_log.visible, UiStyle.palette().telemetry_cyan, "")
	_flight_button.set_lamp(false, UiStyle.palette().telemetry_cyan, "FLIGHT")


func _toggle_flight_menu() -> void:
	_flight_menu.visible = not _flight_menu.visible
	_comms_log.visible = false
	_flight_button.set_lamp(_flight_menu.visible, UiStyle.palette().telemetry_cyan, "FLIGHT")
	_chat_button.set_lamp(false, UiStyle.palette().telemetry_cyan, "")


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_flight_menu.show_paused(get_tree().paused)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# A finger held still on something opens its card. It's used up then, so lifting it isn't a tap, and
# moving it doesn't point the ship.
func _check_for_hold() -> void:
	if not _tap_possible or _view == null or Time.get_ticks_msec() - _tap_started < HOLD_START:
		return
	_tap_possible = false
	var thing: Dictionary = _view.thing_at(_point_start)
	if thing.is_empty():
		return
	_space_fingers.clear()
	_open_card(thing)


func _open_card(thing: Dictionary) -> void:
	_card.visible = true
	_card.show_info(_catalog.info_of(thing), thing, _markers.is_target(thing), _view.is_focus(thing))
	_card_refresh = 0.0
	var spot: Dictionary = _view.screen_spot_of(thing)
	_card.place_beside(spot["center"], spot["radius"], _clear_area())
	_keep_card_current(0.0)


# Live numbers change, and what the card points at moves.
func _keep_card_current(delta: float) -> void:
	if not _card.visible:
		return
	var thing: Dictionary = _card.thing
	var spot: Dictionary = _view.screen_spot_of(thing)
	_card.point_at(spot["center"], spot["radius"])
	_card_refresh -= delta
	if _card_refresh <= 0.0:
		_card_refresh = 0.25
		_card.show_info(_catalog.info_of(thing), thing, _markers.is_target(thing), _view.is_focus(thing))


func _clear_area() -> Rect2:
	var view: Vector2 = get_parent().size
	var left: float = _left_panel.position.x + LEFT_WIDTH
	return Rect2(left, BAR_HEIGHT + 4.0, _right_panel.position.x - left, view.y - EDGE - ROW_HEIGHT - BAR_HEIGHT - 8.0)


func _on_card_target_pressed() -> void:
	if _markers.is_target(_card.thing):
		_markers.clear_target()
	else:
		var thing: Dictionary = _card.thing
		_markers.set_target(thing, _catalog.callsign_of(thing), _catalog.reach_of(thing), _view.point_getter(thing))
	_card_refresh = 0.0


func _on_card_focus_pressed() -> void:
	_view.set_focus(_card.thing)
	_card.visible = false


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


func _on_stranded_changed(stranded: bool) -> void:
	_ship_stranded = stranded
	_update_center_buttons()


func _on_pilot_stranded_changed(stranded: bool) -> void:
	_pilot_stranded = stranded
	_update_center_buttons()


func _on_docked_changed(is_docked: bool) -> void:
	_docked = is_docked
	_update_center_buttons()


func _on_action_changed(label: String) -> void:
	_action_button.label = label
	_action_button.visible = label != ""
	_action_button.queue_redraw()
	_place_center_buttons()


func _on_can_leave_changed(can_leave: bool) -> void:
	_can_leave = can_leave
	_eva_button.visible = can_leave and _mode == Pilot.ABOARD


func _update_center_buttons() -> void:
	var aboard: bool = _mode == Pilot.ABOARD
	_restart_button.visible = _pilot_stranded or (_ship_stranded and aboard)
	_undock_button.visible = _docked and aboard
	_place_center_buttons()


# While the pilot's out of the ship, the readouts are theirs.
func _on_ship_data(data: Dictionary) -> void:
	if _mode == Pilot.ABOARD:
		_show_flight_data(data)


func _show_flight_data(data: Dictionary) -> void:
	_top_bar.on_flight_data(data)
	_dial.on_flight_data(data)
	_left_panel.on_flight_data(data)
	_comms._on_flight_data(data)


# Out of the ship, the only controls are the arrows and the fuel gauge, which reads the jetpack.
func _on_pilot_mode_changed(mode: String) -> void:
	_mode = mode
	var aboard: bool = mode == Pilot.ABOARD
	for control: Control in [_lever, _burn, _legs_button, _stab_button, _assist_button, _rotate_left, _rotate_right]:
		control.visible = aboard
	_eva_button.visible = aboard and _can_leave
	_right_panel.burn_mark = Rect2(0.0, _burn.position.y, 2.0, BURN_HEIGHT) if aboard else Rect2()
	_show_panels()
	_turn_guide.ship = _ship if aboard else _pilot
	_markers.measure_from(_view.point_getter({"kind": "ship", "index": 0} if aboard else {"kind": "pilot", "index": 0}))
	if mode == Pilot.EVA:
		_markers.set_way_home("SHIP", 110.0, _view.point_getter({"kind": "ship", "index": 0}))
	else:
		_markers.clear_way_home()
	_markers.hide_target(mode == Pilot.INSIDE)
	_update_center_buttons()


func _widgets_in_reach() -> Array[UiWidget]:
	# Whatever's on top gets first say. While paused, only the way out works.
	var widgets: Array[UiWidget] = []
	if _flight_menu.visible:
		widgets.append_array(_flight_menu.buttons())
	widgets.append(_flight_button)
	if get_tree().paused:
		return widgets
	widgets.append(_chat_button)
	if _comms_log.visible:
		widgets.append(_comms_log)
	if _card.visible:
		widgets.append_array(_card.buttons())
	widgets.append_array([_restart_button, _undock_button, _action_button])
	if _hidden:
		widgets.append(_left_tab)
		widgets.append(_right_tab)
	else:
		widgets.append(_lever)
		widgets.append(_burn)
		widgets.append_array([_eva_button, _stab_button, _legs_button, _assist_button])
		widgets.append_array([_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right])
		widgets.append_array(_zoom_buttons)
	return widgets


func _on_finger_down(index: int, position: Vector2) -> void:
	if not _hidden:
		_idle_seconds = 0.0
	for widget: UiWidget in _widgets_in_reach():
		if widget.is_inside_tree() and widget.is_visible_in_tree() and widget.touch_rect().has_point(position):
			_finger_widgets[index] = widget
			widget.finger_down(position)
			return
	# The top bar is hardware too, so touching it doesn't steer. Between the panels' controls, it's
	# all open space now.
	if _top_bar.get_global_rect().has_point(position):
		return
	if get_tree().paused:
		return
	if _card.visible and _card.get_global_rect().has_point(position):
		return

	_space_fingers[index] = position
	if _space_fingers.size() == 1:
		_point_start = position
		_tap_possible = true
		_tap_started = Time.get_ticks_msec()
	elif _space_fingers.size() == 2:
		_tap_possible = false
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
			_tap_possible = false
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
			if _tap_possible:
				# With a card up, the first tap away only closes it.
				if _card.visible:
					_card.visible = false
				else:
					space_tapped.emit(_point_start)
			_tap_possible = false


func _current_gap() -> float:
	var positions: Array = _space_fingers.values()
	return maxf(positions[0].distance_to(positions[1]), 1.0)
