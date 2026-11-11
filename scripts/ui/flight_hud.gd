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
const EDGE: float = 8.0
const PAD_BUTTON: float = 44.0
const ROW_HEIGHT: float = 40.0
const ROW_GAP: float = 4.0
## The column at the right: EVA and LEGS and the dial at the top, STAB, ASST, and ENGINE at the
## bottom.
const COLUMN_WIDTH: float = 132.0
const SMALL_ROW_HEIGHT: float = 32.0
const DIAL_SIZE: float = 92.0
const ZOOM_WIDTH: float = 68.0
const BURN_HEIGHT: float = 72.0
const LEVER_WIDTH: float = 44.0
const LEVER_HEIGHT: float = 140.0
const GAUGES_WIDTH: float = 170.0
const GAUGES_HEIGHT: float = 55.0
## The bottom-right group: gauges, lever, then the column, and how tall it is.
const CORNER_WIDTH: float = EDGE + GAUGES_WIDTH + 16.0 + LEVER_WIDTH + 12.0 + COLUMN_WIDTH + EDGE
const CORNER_HEIGHT: float = 6.0 + ROW_HEIGHT * 2.0 + 6.0 + 14.0 + BURN_HEIGHT + EDGE
const TAB_SIZE: Vector2 = Vector2(12.0, 44.0)
## The pilot's box on screen for the context menu to keep off, in world units each way from their
## middle, and how far ahead their walking is followed, in seconds.
const PILOT_HALF: Vector2 = Vector2(14.0, 26.0)
const PILOT_LOOKAHEAD: float = 1.0
## The least distance ahead of the pilot kept clear while they're being pushed, in screen pixels.
const PILOT_REACH_AHEAD: float = 90.0
## The time warp control, in the clock's box.
const WARP_WIDTH: float = 92.0
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

## Whether the side panels hide by themselves after a while with no input, and after how long. Off,
## on Manny's call: the tab at the left hides and shows them.
@export var auto_hide: bool = false
@export var auto_hide_seconds: float = 6.0

var _top_bar: TopBar
var _pad_panel: Control
var _right_panel: SidePanel
var _gauges: TankGauges
var _zoom_row: Control
var _lever: ThrottleLever
var _burn: EngineButton
var _dial: HeadingDial
var _pad_up: RcsButton
var _pad_down: RcsButton
var _pad_left: RcsButton
var _pad_right: RcsButton
var _rotate_left: RcsButton
var _rotate_right: RcsButton
var _assist_button: UiButton
var _stab_button: UiButton
var _left_tab: SideTab
var _zoom_buttons: Array[UiButton] = []
var _restart_button: UiButton
var _undock_button: UiButton
var _chat_button: UiButton
var _warp_control: WarpControl
var _flight_button: UiButton
var _comms_log: CommsLog
var _flight_menu: FlightMenu
var _card: ContextCard
var _tap_possible: bool = false
var _tap_started: int = 0
var _legs_button: UiButton
var _eva_button: UiButton
var _context_menu: ContextMenu
var _gig_board: GigBoard
var _gig_tracker: GigTracker
var _survey_marker: SurveyMarker
var _agency: Agency
var _targeted_gig: int = -1
# Where the pilot was on screen against the context menu's target, and how fast that's changing, to
# keep the label out of where they're walking.
var _menu_pilot_from := Vector2.ZERO
var _menu_pilot_speed := Vector2.ZERO
var _menu_tracking: bool = false
# What each of the context menu's rows does, in order.
var _menu_runs: Array[Callable] = []
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


## Connects the agency, for its gig boards.
func connect_agency(agency: Agency) -> void:
	_agency = agency
	_pilot.terminal_used.connect(_open_gig_board)
	agency.credits_changed.connect(func(_credits: int) -> void: _gig_board.refresh())
	agency.gig_changed.connect(_on_gig_changed)


# A newly taken gig becomes the target, so the edge marker points the way.
func _on_gig_changed(gig: Gig) -> void:
	_gig_tracker.gig = gig
	_gig_tracker.wanted_open = true if gig != null and gig.id != _targeted_gig else _gig_tracker.wanted_open
	if gig != null and gig.id != _targeted_gig:
		_targeted_gig = gig.id
		var thing: Dictionary = _agency.place_thing(gig.destination)
		if not thing.is_empty():
			_markers.set_target(thing, _catalog.callsign_of(thing), _catalog.reach_of(thing), _view.point_getter(thing))
		else:
			# A survey spot isn't anything the camera knows, so it gets its own way to be found.
			var destination: Dictionary = gig.destination
			_markers.set_target({"kind": "survey", "gig": gig.id}, "SURVEY", 0.0, func() -> PackedFloat64Array: return _agency.place_point(destination))
	_gig_tracker.queue_redraw()


# The tracker's numbers: how far to where the current step happens, and the cargo aboard.
func _update_gig_tracker() -> void:
	var gig: Gig = _agency.active if _agency != null else null
	_gig_tracker.gig = gig
	if gig == null:
		_survey_marker.visible = false
		_gig_tracker.queue_redraw()
		return
	var place: Dictionary = _agency.current_place(gig)
	var at: PackedFloat64Array = _agency.place_point(place)
	var from: ShipState = _ship.state if _mode == Pilot.ABOARD else _pilot.state
	_gig_tracker.distance_text = Units.distance_text(Vector2(at[0] - from.x, at[1] - from.y).length()) if at.size() == 2 else ""
	_gig_tracker.cargo_text = "CARGO: %s KG" % Units.grouped(roundi(_ship.cargo_kg)) if _ship.cargo_kg > 0.0 else ""
	if gig.type.kind == "survey":
		match gig.step:
			1:
				_gig_tracker.cargo_text = "SCAN: %d%%" % roundi(gig.scan_share * 100.0) if gig.scanning or gig.scan_share > 0.0 else "LANDED: READY TO SCAN"
			2:
				_gig_tracker.cargo_text = "UPLINKING" if _agency.relay_in_sight else "NO RELAY IN SIGHT"
	# The survey spot gets brackets on screen once it's in view, while it's being found and while the
	# scan runs. Waiting to be scanned, the context menu's brackets are on it instead.
	_survey_marker.visible = gig.type.kind == "survey" and (gig.step == 0 or (gig.step == 1 and gig.scanning))
	if _survey_marker.visible and at.size() == 2:
		_survey_marker.at = _view.to_screen(at[0], at[1])
		_survey_marker.queue_redraw()
	_gig_tracker.queue_redraw()


func _open_gig_board(place: Dictionary) -> void:
	if _agency == null:
		return
	_card.visible = false
	_release_everything()
	_pilot.input_blocked = true
	_gig_board.open(_agency, place)


func _on_gig_board_closed() -> void:
	_pilot.input_blocked = false


## Connects the time warp control to the warp.
func connect_warp(warp: TimeWarp) -> void:
	_warp_control.faster.connect(warp.faster)
	_warp_control.slower.connect(warp.slower)
	_warp_control.reset.connect(warp.reset)
	warp.warp_changed.connect(func(factor: float) -> void: _warp_control.factor = factor)


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
	ship.engine_switched.connect(func(on: bool) -> void: _burn.engine_on = on)
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
	_pad_panel = _child_control(self)
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
	_context_menu = ContextMenu.new()
	_context_menu.visible = false
	_context_menu.chosen.connect(_on_context_chosen)
	add_child(_context_menu)

	_chat_button = UiButton.new().setup("", palette.telemetry_cyan)
	_chat_button.icon = "chat"
	_chat_button.tapped.connect(_toggle_comms_log)
	_top_bar.add_child(_chat_button)
	_flight_button = UiButton.new().setup("FLIGHT", palette.telemetry_cyan)
	_flight_button.icon = "menu"
	_flight_button.text_size = 1
	_flight_button.tapped.connect(_toggle_flight_menu)
	_top_bar.add_child(_flight_button)
	_warp_control = WarpControl.new()
	_top_bar.add_child(_warp_control)
	_top_bar.clock_extra = WARP_WIDTH + 8.0

	_gauges = TankGauges.new()
	_right_panel.add_child(_gauges)
	_lever = ThrottleLever.new()
	_right_panel.add_child(_lever)

	_dial = HeadingDial.new()
	add_child(_dial)
	_pad_up = RcsButton.new().setup(Vector2.UP, 0, &"translate_forward")
	_pad_down = RcsButton.new().setup(Vector2.DOWN, 0, &"translate_back")
	_pad_left = RcsButton.new().setup(Vector2.LEFT, 0, &"translate_left")
	_pad_right = RcsButton.new().setup(Vector2.RIGHT, 0, &"translate_right")
	_rotate_left = RcsButton.new().setup(Vector2.ZERO, -1, &"turn_left")
	_rotate_right = RcsButton.new().setup(Vector2.ZERO, 1, &"turn_right")
	for button: RcsButton in [_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right]:
		_pad_panel.add_child(button)
	_eva_button = UiButton.new().setup("EVA", palette.telemetry_cyan)
	_eva_button.visible = false
	add_child(_eva_button)
	_eva_button.tapped.connect(_tap_action.bind(&"eva"))
	_legs_button = UiButton.new().setup("LEGS", palette.telemetry_cyan)
	add_child(_legs_button)
	_stab_button = UiButton.new().setup("STAB", palette.telemetry_cyan)
	_assist_button = UiButton.new().setup("ASST", palette.telemetry_cyan)
	for button: UiButton in [_stab_button, _assist_button]:
		_right_panel.add_child(button)
	_legs_button.tapped.connect(_tap_action.bind(&"toggle_legs"))
	_stab_button.tapped.connect(_tap_action.bind(&"toggle_stab"))
	_assist_button.tapped.connect(_tap_action.bind(&"toggle_assist"))
	_burn = EngineButton.new()
	_right_panel.add_child(_burn)

	for button_name: String in ["SYS", "ORBIT", "SHIP"]:
		var button: UiButton = UiButton.new().setup(button_name, palette.telemetry_cyan)
		button.tapped.connect(func() -> void: zoom_button_pressed.emit(button_name))
		_zoom_row.add_child(button)
		_zoom_buttons.append(button)

	_left_tab = SideTab.new()
	add_child(_left_tab)
	_left_tab.dragged_in.connect(_show_panels)
	_left_tab.tapped.connect(_toggle_panels)

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
	_survey_marker = SurveyMarker.new()
	_survey_marker.visible = false
	add_child(_survey_marker)
	_gig_tracker = GigTracker.new()
	add_child(_gig_tracker)
	# Last, so it covers everything while it's up.
	_gig_board = GigBoard.new()
	_gig_board.visible = false
	_gig_board.closed.connect(_on_gig_board_closed)
	add_child(_gig_board)


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
	var bottom_row_y: float = view.y - EDGE - ROW_HEIGHT

	_top_bar.position = Vector2.ZERO
	_top_bar.size = Vector2(view.x, BAR_HEIGHT)
	_flight_button.size = Vector2(FLIGHT_WIDTH, 30.0)
	_flight_button.position = Vector2(view.x - EDGE - FLIGHT_WIDTH, 7.0)
	_chat_button.size = Vector2(CHAT_WIDTH, 30.0)
	_chat_button.position = Vector2(_flight_button.position.x - 6.0 - CHAT_WIDTH, 7.0)
	var clock: Rect2 = _top_bar.clock_rect()
	_warp_control.size = Vector2(WARP_WIDTH, 30.0)
	_warp_control.position = Vector2(clock.end.x - TopBar.CELL_PADDING - WARP_WIDTH, 7.0)

	_center_view_x = view.x / 2.0
	_place_center_buttons()

	# Top right, under the buttons: EVA and LEGS side by side, then the dial.
	var column_x: float = view.x - EDGE - COLUMN_WIDTH
	var half: float = floorf((COLUMN_WIDTH - ROW_GAP) / 2.0)
	_eva_button.size = Vector2(half, SMALL_ROW_HEIGHT)
	_legs_button.size = Vector2(COLUMN_WIDTH - half - ROW_GAP, SMALL_ROW_HEIGHT)
	_eva_button.position = Vector2(column_x, BAR_HEIGHT + 12.0)
	_legs_button.position = Vector2(column_x + half + ROW_GAP, BAR_HEIGHT + 12.0)
	_dial.size = Vector2(DIAL_SIZE, DIAL_SIZE + HeadingDial.READOUT_HEIGHT)
	_dial.position = Vector2(column_x + floorf((COLUMN_WIDTH - DIAL_SIZE) / 2.0), _eva_button.position.y + SMALL_ROW_HEIGHT + 12.0)

	# Bottom left: the zoom buttons, and the pad above them, the turns in the cross's top corners.
	_zoom_row.size = Vector2((ZOOM_WIDTH + ROW_GAP) * 3.0, ROW_HEIGHT)
	for i in range(_zoom_buttons.size()):
		_zoom_buttons[i].position = Vector2(i * (ZOOM_WIDTH + ROW_GAP), 0.0)
		_zoom_buttons[i].size = Vector2(ZOOM_WIDTH, ROW_HEIGHT)
	_pad_panel.size = Vector2(PAD_BUTTON * 3.0, PAD_BUTTON * 3.0)
	_rotate_left.position = Vector2(0.0, 0.0)
	_rotate_right.position = Vector2(PAD_BUTTON * 2.0, 0.0)
	_pad_up.position = Vector2(PAD_BUTTON, 0.0)
	_pad_left.position = Vector2(0.0, PAD_BUTTON)
	_pad_right.position = Vector2(PAD_BUTTON * 2.0, PAD_BUTTON)
	_pad_down.position = Vector2(PAD_BUTTON, PAD_BUTTON * 2.0)
	for button: RcsButton in [_pad_up, _pad_down, _pad_left, _pad_right, _rotate_left, _rotate_right]:
		button.size = Vector2(PAD_BUTTON, PAD_BUTTON)

	# Bottom right: the fuel and RCS gauges, the lever, then STAB, ASST, and ENGINE.
	_right_panel.size = Vector2(CORNER_WIDTH, CORNER_HEIGHT)
	var inner_x: float = CORNER_WIDTH - EDGE - COLUMN_WIDTH
	_burn.size = Vector2(COLUMN_WIDTH, BURN_HEIGHT)
	_burn.position = Vector2(inner_x, CORNER_HEIGHT - EDGE - BURN_HEIGHT)
	_assist_button.size = Vector2(COLUMN_WIDTH, ROW_HEIGHT)
	_assist_button.position = Vector2(inner_x, _burn.position.y - 14.0 - ROW_HEIGHT)
	_stab_button.size = Vector2(COLUMN_WIDTH, ROW_HEIGHT)
	_stab_button.position = Vector2(inner_x, _assist_button.position.y - 6.0 - ROW_HEIGHT)
	_lever.size = Vector2(LEVER_WIDTH, LEVER_HEIGHT)
	_lever.position = Vector2(inner_x - 12.0 - LEVER_WIDTH, CORNER_HEIGHT - EDGE - LEVER_HEIGHT)
	_gauges.size = Vector2(GAUGES_WIDTH, GAUGES_HEIGHT)
	_gauges.position = Vector2(_lever.position.x - 16.0 - GAUGES_WIDTH, CORNER_HEIGHT - EDGE - 14.0 - GAUGES_HEIGHT)
	# Hidden, the panel's left edge stays as a strip: the fuel level, and a mark where ENGINE is.
	_right_panel.fuel_mark = Rect2(STRIP - 3.0, _stab_button.position.y, 3.0, _burn.position.y - 6.0 - _stab_button.position.y)
	_right_panel.burn_mark = Rect2(0.0, _burn.position.y, 2.0, BURN_HEIGHT)

	_left_tab.size = TAB_SIZE
	_left_tab.position = Vector2(STRIP, floorf(BAR_HEIGHT + (bottom_row_y - BAR_HEIGHT) / 2.0 - TAB_SIZE.y / 2.0))

	_comms_log.place(Vector2(view.x - EDGE, BAR_HEIGHT + 2.0))
	_flight_menu.place(Vector2(view.x - EDGE, BAR_HEIGHT + 2.0))
	_context_menu.position = Vector2.ZERO
	_context_menu.size = view
	_gig_board.position = Vector2.ZERO
	_gig_board.size = view
	_survey_marker.position = Vector2.ZERO
	_survey_marker.size = view
	_gig_tracker.position = Vector2(EDGE, BAR_HEIGHT + 8.0)
	_gig_tracker.size = Vector2(GigTracker.WIDTH, 200.0)
	_place_panels()


# Whichever of these are up sit side by side, under the top bar.
func _place_center_buttons() -> void:
	var showing: Array[UiButton] = []
	for button: UiButton in [_restart_button, _undock_button]:
		if button.visible:
			showing.append(button)
	var total: float = showing.size() * CENTER_BUTTON_WIDTH + maxi(showing.size() - 1, 0) * ROW_GAP
	var x: float = floorf(_center_view_x - total / 2.0)
	for button: UiButton in showing:
		button.size = Vector2(CENTER_BUTTON_WIDTH, ROW_HEIGHT)
		button.position = Vector2(x, BAR_HEIGHT + CENTER_BUTTON_DROP)
		x += CENTER_BUTTON_WIDTH + ROW_GAP


# Slides the corner groups off by how far hidden they are: the pad off the left, and the bottom-right
# group off the right, leaving a strip. The zoom buttons drop away; the top, EVA, LEGS, and the dial
# stay.
func _place_panels() -> void:
	var view: Vector2 = get_parent().size
	var bottom_row_y: float = view.y - EDGE - ROW_HEIGHT
	var pad_x: float = EDGE + TAB_SIZE.x + 8.0
	_pad_panel.position = Vector2(pad_x - (pad_x + _pad_panel.size.x) * _hide_amount, bottom_row_y - 12.0 - _pad_panel.size.y)
	_right_panel.position = Vector2(view.x - CORNER_WIDTH + (CORNER_WIDTH - STRIP) * _hide_amount, view.y - CORNER_HEIGHT)
	_zoom_row.position = Vector2(EDGE, bottom_row_y + (ROW_HEIGHT + EDGE * 2.0) * _hide_amount)
	_right_panel.mark_shows = _hide_amount > 0.0
	# Slid off the safe area, it could still show in the space around a camera cutout.
	_lever.visible = _mode == Pilot.ABOARD and _hide_amount < 1.0
	_pad_panel.visible = _hide_amount < 1.0
	var comms_left: float = EDGE + (ZOOM_WIDTH + ROW_GAP) * 3.0 + 8.0
	var comms_right: float = _right_panel.position.x + _gauges.position.x - 12.0 if _hide_amount < 1.0 else view.x - STRIP - 8.0
	comms_area_changed.emit(Rect2(comms_left, bottom_row_y, comms_right - comms_left, ROW_HEIGHT))
	clear_area_changed.emit(_clear_area())


func _process(frame_delta: float) -> void:
	var delta: float = TimeWarp.real(frame_delta)
	if not _hidden:
		if Input.is_anything_pressed() or not _finger_widgets.is_empty() or _pointing:
			_idle_seconds = 0.0
		else:
			_idle_seconds += delta
		if auto_hide and _idle_seconds >= auto_hide_seconds:
			_hidden = true
	var target: float = 1.0 if _hidden else 0.0
	if _hide_amount != target:
		_hide_amount = move_toward(_hide_amount, target, delta * 4.0)
		_place_panels()
	_check_for_hold()
	_keep_card_current(delta)
	# What a board asks for can change while it's up, such as the ship docking.
	if _gig_board.visible:
		_gig_board.queue_redraw()
	_update_gig_tracker()
	_place_context_menu(delta)


func _physics_process(_delta: float) -> void:
	for action: StringName in _actions_to_release:
		Input.action_release(action)
	_actions_to_release = _tapped_actions
	_tapped_actions = []


func _show_panels() -> void:
	_hidden = false
	_idle_seconds = 0.0
	_place_panels()


func _toggle_panels() -> void:
	if _hidden:
		_show_panels()
	else:
		_hidden = true


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	_tapped_actions.append(action)


func _on_assist_changed(enabled: bool) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	_assist_button.set_lamp(true, palette.telemetry_cyan if enabled else palette.telemetry_amber, "ASST" if enabled else "RAW")


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


# What's left between the corner groups and the right column: the top bar above, the right column
# beside, and below, whichever is higher of the pad and the bottom-right group while they show.
func _clear_area() -> Rect2:
	var view: Vector2 = get_parent().size
	var left: float = EDGE + TAB_SIZE.x + 8.0
	var right: float = view.x - EDGE - COLUMN_WIDTH - 8.0
	var bottom: float = view.y - EDGE - ROW_HEIGHT - 8.0
	if _hide_amount < 1.0:
		bottom = minf(_pad_panel.position.y, _right_panel.position.y) - 4.0
	return Rect2(left, BAR_HEIGHT + 4.0, maxf(right - left, 0.0), maxf(bottom - BAR_HEIGHT - 4.0, 0.0))


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


func _on_action_changed(_label: String) -> void:
	_place_context_menu(0.0)


func _on_context_chosen(index: int) -> void:
	if index < _menu_runs.size():
		_menu_runs[index].call()


# The rows the context menu shows: the pilot's own action first, if there is one, then whatever the
# agency adds, such as UNLOAD CARGO. The brackets go round the first row's thing.
func _gather_context_rows() -> Array:
	var labels := PackedStringArray()
	_menu_runs.clear()
	var corners := PackedFloat64Array()
	if _pilot._action != "":
		labels.append(_pilot._action)
		_menu_runs.append(_tap_action.bind(&"interact"))
		corners = _pilot.action_target()
	if _agency != null:
		for option: Dictionary in _agency.options():
			labels.append(option["label"])
			_menu_runs.append(option["run"])
			if corners.is_empty() and option["target"].is_valid():
				corners = option["target"].call()
	return [labels, corners]


# The context menu sits on what the pilot's action is about, which moves, so it's placed every frame,
# keeping off the ship, the pilot, and where the pilot's walking.
func _place_context_menu(delta: float) -> void:
	if _pilot == null or _view == null:
		return
	var gathered: Array = _gather_context_rows()
	var labels: PackedStringArray = gathered[0]
	if labels != _context_menu.options:
		_context_menu.options = labels
		_context_menu.reset()
		_menu_tracking = false
		_menu_pilot_speed = Vector2.ZERO
	# Smaller zoomed out, and gone once the world's too small to point at; F still works then.
	_context_menu.visible = not labels.is_empty() and _context_menu.fit_zoom(_view._zoom)
	if not _context_menu.visible:
		return
	var corners: PackedFloat64Array = gathered[1]
	var box: Rect2 = _screen_box(corners)
	var avoid: Array = []
	if _ship != null:
		avoid.append([_screen_box(_ship.hull_corners()), 2.0])
	var tracker: Rect2 = _gig_tracker.shown_rect()
	if tracker.has_area():
		avoid.append([Rect2(_gig_tracker.position + tracker.position, tracker.size).grow(6.0), 4.0])
	if _mode != Pilot.ABOARD and corners.size() >= 8:
		var pilot_at: Vector2 = _view.to_screen(_pilot.state.x, _pilot.state.y)
		var half: Vector2 = (PILOT_HALF * _view._zoom).max(Vector2(8.0, 12.0))
		var pilot_box := Rect2(pilot_at - half, half * 2.0)
		avoid.append([pilot_box, 3.0])
		# How the pilot's moving against the thing on screen, smoothed, since the camera follows them.
		var against: Vector2 = pilot_at - box.get_center()
		if _menu_tracking and delta > 0.0:
			_menu_pilot_speed = _menu_pilot_speed.lerp((against - _menu_pilot_from) / delta, 1.0 - exp(-6.0 * delta))
		_menu_pilot_from = against
		_menu_tracking = true
		# Where they're about to be: the way they're being pushed if they are, or else how they're
		# drifting against the thing.
		var heading: Vector2 = _pilot.wanted_on_screen() * maxf(_pilot.data.ground_walk_speed * _view._zoom, PILOT_REACH_AHEAD)
		if heading == Vector2.ZERO and _menu_pilot_speed.length() > 15.0:
			heading = _menu_pilot_speed
		if heading != Vector2.ZERO:
			var ahead := Rect2(pilot_box.position + heading * PILOT_LOOKAHEAD, pilot_box.size)
			avoid.append([pilot_box.merge(ahead), 2.0])
	# Below UNDOCK and RESTART when they're up, so the label never lands under them.
	var clear: Rect2 = _clear_area()
	if _undock_button.visible or _restart_button.visible:
		var below: float = BAR_HEIGHT + CENTER_BUTTON_DROP + ROW_HEIGHT + 6.0
		clear = clear.grow_individual(0.0, -maxf(below - clear.position.y, 0.0), 0.0, 0.0)
	_context_menu.place(box, corners.size() >= 8, clear, avoid, delta)


# The screen box round some world corners, given as x, y pairs.
func _screen_box(corners: PackedFloat64Array) -> Rect2:
	var box := Rect2()
	for i in range(0, corners.size(), 2):
		var at: Vector2 = _view.to_screen(corners[i], corners[i + 1])
		box = Rect2(at, Vector2.ZERO) if i == 0 else box.expand(at)
	return box


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
	_gauges.on_flight_data(data)
	_right_panel.on_flight_data(data)
	_comms._on_flight_data(data)


# Out of the ship, the controls are the arrows, the rotate buttons on EVA, and the fuel gauge, which
# reads the jetpack.
func _on_pilot_mode_changed(mode: String) -> void:
	_mode = mode
	var aboard: bool = mode == Pilot.ABOARD
	for control: Control in [_lever, _burn, _legs_button, _stab_button, _assist_button]:
		control.visible = aboard
	# On EVA the jetpack turns the pilot the way the ship turns, so the rotate buttons stay.
	for control: Control in [_rotate_left, _rotate_right]:
		control.visible = aboard or mode == Pilot.EVA
	_eva_button.visible = aboard and _can_leave
	_gauges.shows_rcs = aboard
	_right_panel.burn_mark = Rect2(0.0, _burn.position.y, 2.0, BURN_HEIGHT) if aboard else Rect2()
	_show_panels()
	_turn_guide.ship = _ship if aboard else _pilot
	_markers.measure_from(_view.point_getter({"kind": "ship", "index": 0} if aboard else {"kind": "pilot", "index": 0}))
	if mode == Pilot.EVA or mode == Pilot.SURFACE or mode == Pilot.INDOORS:
		_markers.set_way_home("SHIP", 110.0, _view.point_getter({"kind": "ship", "index": 0}))
	else:
		_markers.clear_way_home()
	_markers.hide_target(mode == Pilot.INSIDE)
	_update_center_buttons()


func _widgets_in_reach() -> Array[UiWidget]:
	# Whatever's on top gets first say. While paused, only the way out works. A gig board takes
	# every touch while it's up.
	var widgets: Array[UiWidget] = []
	if _gig_board.visible:
		widgets.append(_gig_board)
		return widgets
	if _flight_menu.visible:
		widgets.append_array(_flight_menu.buttons())
	widgets.append(_flight_button)
	if get_tree().paused:
		return widgets
	widgets.append(_chat_button)
	widgets.append(_warp_control)
	if _comms_log.visible:
		widgets.append(_comms_log)
	if _card.visible:
		widgets.append_array(_card.buttons())
	widgets.append_array([_restart_button, _undock_button, _context_menu])
	# After the context menu, which keeps off it anyway, so a choice is never lost under it.
	if _gig_tracker.gig != null:
		widgets.append(_gig_tracker)
	widgets.append_array([_left_tab, _eva_button, _legs_button])
	if not _hidden:
		widgets.append(_lever)
		widgets.append(_burn)
		widgets.append_array([_stab_button, _assist_button])
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
	if _top_bar.covers(position):
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
