# title_screen.gd: the first thing the game shows, over the game itself frozen at the saved moment. FINAL
# ORBIT in stencil letters, the menu down the left, the mission clock top right, and a comms line along
# the bottom. Everything takes two taps: the first selects, the second goes. Selecting a world other
# than the one behind the menu pulls the view out, swaps worlds, and pushes back in. Going in slides
# everything off to its nearest side and hands the world back to play. From DESIGN.md, "Saving and the
# title screen", drawn to Manny's 2026-11-11 mockup.
class_name TitleScreen
extends Control

## Emitted once the menu's gone, to go into the world behind it: "CONTINUE" or "NEW FLIGHT".
signal entered(item: String)
## Emitted once the view's pulled out and gone dark, for another world behind the menu.
signal world_wanted(world: String)

## What the next load of the game does: whether the title opens, which world it builds behind it
## ("continue" or "new"), what's selected, and whether the view arrives from far out, after a change
## of world. They last across reloads.
static var opening: bool = true
static var world: String = "continue"
static var selected_item: String = ""
static var arriving: bool = false
## A test runs the game without the title, unless it asks for it.
static var on_in_tests: bool = false

const ITEMS: Array[String] = ["CONTINUE", "NEW FLIGHT", "ZEN MODE", "SETTINGS"]
## Not built yet, so shown dimmed and not selectable.
const NOT_YET: Array[String] = ["ZEN MODE", "SETTINGS"]
const WORLD_OF: Dictionary = {"CONTINUE": "continue", "NEW FLIGHT": "new"}
const SUBTITLE: String = "KEPLA SYSTEM · AGENCY FLIGHT OPERATIONS"
const EDGE: float = 24.0
const ROW: float = 44.0
const ROW_GAP: float = 10.0
const MENU_WIDTH: float = 236.0
const SELECTED_WIDER: float = 18.0
const SUBLINE: float = 14.0
const BOTTOM: float = 40.0
const SLIDE_SECONDS: float = 0.35
const PULL_SECONDS: float = 0.7
const FADE_SECONDS: float = 0.2
## Where the framed body's middle and the ship sit, as shares of the screen.
const BODY_SPOT := Vector2(0.98, 1.12)
const SHIP_SPOT := Vector2(0.62, 0.6)

## What the menu says about the world: "has_save", "where", "credits", "lost", "time", and the comms
## line's "comms" and "comms_red".
var info: Dictionary = {}

var _view: Node
var _body: int = 0
var _selected: String = ""
var _pressed: String = ""
# 0 to 1 as everything slides off, going in.
var _leave: float = 0.0
var _leaving: bool = false
# Black over everything, 0 to 1, for a change of world.
var _dark: float = 0.0
var _changing_to: String = ""
var _pull_left: float = 0.0
var _settling: bool = false
var _settle_ticks: int = 0
var _rects: Dictionary = {}
# The lettering, painted once as pixel art and drawn scaled up.
var _lettering: ImageTexture


## Whether the title can open: not while a test runs the game, unless it asks.
static func allowed() -> bool:
	return on_in_tests or (Engine.get_main_loop() != null and Engine.get_main_loop().get_script() == null)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Opens over a world: frames this body with the ship on its path, then freezes the world. After a
## change of world, the view arrives from far out and the screen comes up from dark.
func start(view: Node, body: int) -> void:
	_view = view
	_body = body
	var choices: Array[String] = _choices()
	_selected = selected_item if choices.has(selected_item) else ("CONTINUE" if choices.has("CONTINUE") else "NEW FLIGHT")
	selected_item = _selected
	_view.hold_title_frame(_body, _spot(SHIP_SPOT), _spot(BODY_SPOT), arriving)
	_dark = 1.0 if arriving else 0.0
	arriving = false
	_settle()


## Follows the safe area, like the HUD, and puts the framing where the new shape wants it.
func _on_screen_fitted(_view_size: Vector2, inset_top_left: Vector2, inset_bottom_right: Vector2) -> void:
	offset_left = inset_top_left.x
	offset_top = inset_top_left.y
	offset_right = -inset_bottom_right.x
	offset_bottom = -inset_bottom_right.y
	if _view != null and not _leaving and _changing_to == "":
		_view.move_title_frame(_spot(SHIP_SPOT), _spot(BODY_SPOT))
		_settle()
	queue_redraw()


# Lets the world run until the view's settled and a couple of ticks after, so everything in it has
# placed itself, then freezes it.
func _settle() -> void:
	get_tree().paused = false
	_settling = true
	_settle_ticks = 2


func _physics_process(_delta: float) -> void:
	if not _settling or not _view.title_settled():
		return
	_settle_ticks -= 1
	if _settle_ticks <= 0:
		_settling = false
		get_tree().paused = true


func _process(delta: float) -> void:
	if _leaving:
		_leave = minf(_leave + delta / SLIDE_SECONDS, 1.0)
		queue_redraw()
		if _leave >= 1.0:
			_leaving = false
			entered.emit(_selected)
		return
	if _changing_to != "":
		_pull_left -= delta
		if _pull_left <= FADE_SECONDS:
			_dark = minf(_dark + delta / FADE_SECONDS, 1.0)
			queue_redraw()
		if _pull_left <= 0.0 and _dark >= 1.0:
			var next: String = _changing_to
			_changing_to = ""
			world_wanted.emit(next)
		return
	if _dark > 0.0:
		_dark = maxf(_dark - delta / FADE_SECONDS, 0.0)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if _leaving or _changing_to != "":
		return
	if event is InputEventScreenTouch:
		var item: String = _item_at(event.position - global_position)
		if event.pressed:
			_pressed = item
		elif item != "" and item == _pressed:
			_tap(item)
		if not event.pressed:
			_pressed = ""
		queue_redraw()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var choices: Array[String] = _choices()
		var step: int = 1 if event.is_action_pressed("ui_down") else -1
		var at: int = clampi(choices.find(_selected) + step, 0, choices.size() - 1)
		_tap(choices[at])
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_tap(_selected)


# The first tap selects, and the second goes.
func _tap(item: String) -> void:
	if NOT_YET.has(item) or not _choices().has(item):
		return
	if item != _selected:
		_selected = item
		selected_item = item
		queue_redraw()
		if WORLD_OF[item] != world:
			_change_world(WORLD_OF[item])
		return
	_leaving = true
	_leave = 0.0


# Pulls the view far out and goes dark, so the other world can come in behind the menu.
func _change_world(next: String) -> void:
	_changing_to = next
	_pull_left = PULL_SECONDS
	_settling = false
	get_tree().paused = false
	_view.pull_title_out()


# What can be picked: CONTINUE only with a save to continue.
func _choices() -> Array[String]:
	var choices: Array[String] = []
	for item: String in ITEMS:
		if item == "CONTINUE" and not info.get("has_save", false):
			continue
		if not NOT_YET.has(item):
			choices.append(item)
	return choices


# A share of the whole screen, as a point on it.
func _spot(share: Vector2) -> Vector2:
	return (get_viewport_rect().size * share).round()


func _item_at(point: Vector2) -> String:
	for item: String in _rects:
		if _rects[item].has_point(point):
			return item
	return ""


# How many game pixels each of the lettering's art pixels takes on this screen: a whole number, so they
# stay crisp squares.
func _art_scale() -> int:
	var letters: Vector2 = Vector2(TitleLettering.letters_size())
	return clampi(floori(minf(size.x * 0.46 / letters.x, size.y * 0.36 / letters.y)), 1, 6)


func _draw() -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var eased: float = _leave * _leave * (3.0 - 2.0 * _leave)
	var art_scale: int = _art_scale()
	var lettering: Vector2 = Vector2(TitleLettering.letters_size() * art_scale)
	var subtitle_size: int = 2 if UiStyle.text_width(SUBTITLE, 2) <= lettering.x else 1
	var left_reach: float = EDGE + maxf(maxf(lettering.x, UiStyle.text_width(SUBTITLE, subtitle_size)), MENU_WIDTH + SELECTED_WIDER) + 40.0
	var left := Vector2(-left_reach * eased, 0.0)
	var right := Vector2((EDGE + 220.0) * eased, 0.0)

	if _lettering == null:
		_lettering = ImageTexture.create_from_image(TitleLettering.paint())
	var letters_at: Vector2 = Vector2(EDGE, EDGE - 4.0) - Vector2(TitleLettering.letters_offset() * art_scale)
	draw_texture_rect(_lettering, Rect2(letters_at + left, _lettering.get_size() * art_scale), false)
	var subtitle_at := Vector2(EDGE, EDGE - 4.0 + lettering.y + 10.0) + left
	UiStyle.draw_text(self, SUBTITLE, subtitle_at, palette.hull_lightest, subtitle_size)

	_draw_menu(palette, left)
	_draw_clock(palette, right)
	_draw_comms(palette, left, right)
	if _dark > 0.0:
		draw_rect(Rect2(-global_position, get_viewport_rect().size), Color(palette.hull_darkest, _dark))


func _draw_menu(palette: AgencyPalette, shift: Vector2) -> void:
	_rects.clear()
	var shown: Array[String] = []
	for item: String in ITEMS:
		if item != "CONTINUE" or info.get("has_save", false):
			shown.append(item)
	var heights: Array[float] = []
	var total: float = 0.0
	for item: String in shown:
		var height: float = ROW + (SUBLINE if item == "CONTINUE" and item == _selected else 0.0)
		heights.append(height)
		total += height + ROW_GAP
	var y: float = size.y - BOTTOM - total + ROW_GAP
	for i in range(shown.size()):
		var item: String = shown[i]
		var selected: bool = item == _selected
		var rect := Rect2(Vector2(EDGE, y) + shift, Vector2(MENU_WIDTH + (SELECTED_WIDER if selected else 0.0), heights[i]))
		_rects[item] = rect
		_draw_item(palette, item, rect, selected)
		y += heights[i] + ROW_GAP


func _draw_item(palette: AgencyPalette, item: String, rect: Rect2, selected: bool) -> void:
	var not_yet: bool = NOT_YET.has(item)
	var fill: Color = palette.hull_mid if item == _pressed and not not_yet else UiStyle.box_fill()
	var line: Color = palette.agency_orange if selected else (palette.hull_mid if not_yet else palette.hull_light)
	var text: Color = palette.agency_orange_light if selected else (palette.hull_mid if not_yet else palette.hull_lighter)
	UiStyle.draw_box(self, rect, line, fill)
	var label_at := Vector2(rect.position.x + 12.0, rect.position.y + floorf((ROW - 14.0) / 2.0))
	UiStyle.draw_text(self, item, label_at, text, 2)
	if selected:
		_draw_brackets(rect.grow(3.0), palette.agency_orange)
		var tip := Vector2(label_at.x + UiStyle.text_width(item + " ", 2) + 2.0, label_at.y + 7.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -4), tip + Vector2(4, 0), tip + Vector2(0, 4), tip + Vector2(-4, 0)]), palette.agency_orange)
	if not_yet:
		UiStyle.draw_text(self, "SOON", Vector2(rect.end.x - 10.0 - UiStyle.text_width("SOON", 1), rect.position.y + floorf((ROW - 7.0) / 2.0)), palette.hull_mid, 1)
	if item == "CONTINUE" and selected:
		var lost: bool = info.get("lost", false)
		var where: String = "SHIP LOST" if lost else info.get("where", "")
		var line_text: String = "%s · %s CR" % [where, Units.grouped(info.get("credits", 0))]
		UiStyle.draw_text(self, line_text, Vector2(label_at.x, rect.position.y + ROW - 6.0), palette.agency_red if lost else palette.telemetry_cyan, 1)


func _draw_brackets(box: Rect2, color: Color) -> void:
	var arm: float = 8.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = box.position.x if corner.x == 0 else box.end.x - 2.0
		var y: float = box.position.y if corner.y == 0 else box.end.y - 2.0
		draw_rect(Rect2(x if corner.x == 0 else x - arm + 2.0, y, arm, 2.0), color)
		draw_rect(Rect2(x, y if corner.y == 0 else y - arm + 2.0, 2.0, arm), color)


# The mission clock, in its box hanging at the top right.
func _draw_clock(palette: AgencyPalette, shift: Vector2) -> void:
	var total: int = int(info.get("time", 0.0))
	var clock: String = "T+ %03d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
	var width: float = UiStyle.text_width(clock, 2) + 18.0
	var rect := Rect2(Vector2(size.x - EDGE - width, EDGE - 8.0) + shift, Vector2(width, 32.0))
	UiStyle.draw_box(self, rect, palette.hull_light, UiStyle.box_fill())
	UiStyle.draw_text(self, clock, rect.position + Vector2(10.0, 9.0), palette.hull_lightest, 2)


# The comms line along the bottom, and the version at its right end.
func _draw_comms(palette: AgencyPalette, left: Vector2, right: Vector2) -> void:
	var y: float = size.y - 24.0
	draw_rect(Rect2(Vector2(0.0, y) + left, Vector2(size.x, 1.0)), Color(palette.telemetry_cyan, 0.6))
	var color: Color = palette.agency_red if info.get("comms_red", false) else palette.telemetry_cyan
	UiStyle.draw_text(self, info.get("comms", "COMMS: ALL SYSTEMS NOMINAL"), Vector2(EDGE, y + 6.0) + left, color, 2)
	var version: String = info.get("version", "v0.1")
	var version_at := Vector2(size.x - EDGE - UiStyle.text_width(version, 1), y + 10.0) + right
	draw_rect(Rect2(version_at - Vector2(3.0, 3.0), Vector2(UiStyle.text_width(version, 1) + 5.0, 13.0)), UiStyle.box_fill())
	UiStyle.draw_text(self, version, version_at, palette.hull_light, 1)
