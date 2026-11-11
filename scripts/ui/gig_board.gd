# gig_board.gd: the agency gig board a terminal shows: the gigs that start here down the left, the one
# picked described on the right with its pay, destination, hazards, and requirements, met in green and
# unmet in red, and ACCEPT GIG once they're all met. It covers the flight while it's up. From DESIGN.md,
# "Gigs" (boards), drawn to Manny's 2026-11-10 mockup.
class_name GigBoard
extends UiWidget

signal closed

const MOST_SIZE: Vector2 = Vector2(880.0, 520.0)
const HEADER: float = 50.0
const MARGIN: float = 16.0
const ROW_HEIGHT: float = 56.0
const ROW_GAP: float = 10.0
const BUTTON_SIZE: Vector2 = Vector2(196.0, 44.0)
const CLOSE_SIZE: Vector2 = Vector2(104.0, 30.0)

var _agency: Agency
var _place: Dictionary = {}
var _gigs: Array[Gig] = []
var _picked: int = 0
var _panel := Rect2()
var _finger := Vector2.ZERO
var _pressed: String = ""


## Shows the board of gigs that start at a place.
func open(agency: Agency, place: Dictionary) -> void:
	_agency = agency
	_place = place
	_picked = 0
	visible = true
	refresh()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Reads the board again, after something's changed.
func refresh() -> void:
	if _agency == null:
		return
	_gigs = _agency.board(_place)
	_picked = clampi(_picked, 0, maxi(_gigs.size() - 1, 0))
	queue_redraw()


## The whole screen: tapping off the panel closes it, and nothing behind it takes a touch.
func touch_rect() -> Rect2:
	return get_global_rect()


func finger_down(position: Vector2) -> void:
	_finger = position - global_position
	_pressed = _part_at(_finger)
	queue_redraw()


func finger_moved(position: Vector2) -> void:
	_finger = position - global_position


func finger_up() -> void:
	var part: String = _part_at(_finger)
	if part == _pressed:
		if part == "close" or part == "outside":
			close()
		elif part == "accept":
			_accept()
		elif part.begins_with("row"):
			_picked = int(part.substr(3))
	_pressed = ""
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	# On the Mac: up and down pick, F takes it, and Escape closes.
	if Input.is_action_just_pressed("translate_forward"):
		_picked = maxi(_picked - 1, 0)
		queue_redraw()
	if Input.is_action_just_pressed("translate_back"):
		_picked = mini(_picked + 1, maxi(_gigs.size() - 1, 0))
		queue_redraw()
	if Input.is_action_just_pressed("interact"):
		_accept()
	if Input.is_action_just_pressed("ui_cancel"):
		close()


func _accept() -> void:
	if _gigs.is_empty() or not _can_take(_gigs[_picked]):
		return
	if _agency.accept(_gigs[_picked]):
		close()


func _can_take(gig: Gig) -> bool:
	for row: Array in _agency.requirements(gig):
		if not row[1]:
			return false
	return true


func _layout() -> void:
	var room: Vector2 = size - Vector2(32.0, 60.0)
	var panel_size := Vector2(minf(room.x, MOST_SIZE.x), minf(room.y, MOST_SIZE.y)).floor()
	_panel = Rect2(((size - panel_size) / 2.0 + Vector2(0.0, 18.0)).floor(), panel_size)


func _list_width() -> float:
	return floorf((_panel.size.x - MARGIN * 3.0) * 0.48)


func _row_rect(i: int) -> Rect2:
	return Rect2(_panel.position + Vector2(MARGIN, HEADER + MARGIN + i * (ROW_HEIGHT + ROW_GAP)), Vector2(_list_width(), ROW_HEIGHT))


func _detail_rect() -> Rect2:
	var x: float = _panel.position.x + MARGIN * 2.0 + _list_width() + 1.0
	return Rect2(x, _panel.position.y + HEADER + MARGIN, _panel.end.x - MARGIN - x, _panel.size.y - HEADER - MARGIN * 2.0)


func _close_rect() -> Rect2:
	return Rect2(_panel.end.x - MARGIN - CLOSE_SIZE.x, _panel.position.y + floorf((HEADER - CLOSE_SIZE.y) / 2.0), CLOSE_SIZE.x, CLOSE_SIZE.y)


func _accept_rect() -> Rect2:
	var detail: Rect2 = _detail_rect()
	return Rect2(detail.end - BUTTON_SIZE, BUTTON_SIZE)


func _part_at(point: Vector2) -> String:
	if not _panel.has_point(point):
		return "outside"
	if _close_rect().grow(6.0).has_point(point):
		return "close"
	if _accept_rect().has_point(point):
		return "accept"
	for i in range(_gigs.size()):
		if _row_rect(i).has_point(point):
			return "row%d" % i
	return ""


func _draw() -> void:
	if _agency == null:
		return
	_layout()
	var palette: AgencyPalette = UiStyle.palette()
	var shade: Color = palette.hull_darkest
	shade.a = 0.45
	draw_rect(Rect2(Vector2.ZERO, size), shade)
	var fill: Color = palette.hull_darkest
	fill.a = 0.94
	UiStyle.draw_box(self, _panel, palette.hull_light, fill)

	# The header: the board's name between warning signs, where it is, and CLOSE.
	var title_size: int = 3 if _panel.size.x >= 760.0 else 2
	var title_y: float = _panel.position.y + floorf((HEADER - 7.0 * title_size) / 2.0)
	var x: float = _panel.position.x + MARGIN
	_draw_warning(Vector2(x, title_y), 7.0 * title_size, palette.agency_orange)
	x += 7.0 * title_size + 8.0
	UiStyle.draw_text(self, "AGENCY GIG BOARD", Vector2(x, title_y), palette.agency_orange_light, title_size)
	x += UiStyle.text_width("AGENCY GIG BOARD", title_size) + 2.0
	_draw_warning(Vector2(x, title_y), 7.0 * title_size, palette.agency_orange)
	x += 7.0 * title_size + 18.0
	var where: String = "%s TERMINAL // OPEN_GIGS" % _agency.place_tag(_place)
	if x + UiStyle.text_width(where, 1) < _close_rect().position.x - 12.0:
		UiStyle.draw_text(self, where, Vector2(x, _panel.position.y + floorf(HEADER / 2.0) - 3.0), palette.hull_lighter, 1)
	var close: Rect2 = _close_rect()
	UiStyle.draw_box(self, close, palette.hull_lighter, palette.hull_mid if _pressed == "close" else UiStyle.box_fill())
	UiStyle.draw_text(self, "CLOSE [×]", Vector2(close.position.x + floorf((close.size.x - UiStyle.text_width("CLOSE [×]", 1)) / 2.0), close.position.y + 11.0), palette.hull_lightest, 1)
	draw_rect(Rect2(_panel.position.x + MARGIN, _panel.position.y + HEADER, _panel.size.x - MARGIN * 2.0, 1.0), palette.hull_mid)
	var divider_x: float = _panel.position.x + MARGIN * 1.5 + _list_width()
	draw_rect(Rect2(divider_x, _panel.position.y + HEADER + MARGIN, 1.0, _panel.size.y - HEADER - MARGIN * 2.0), palette.hull_mid)

	if _gigs.is_empty():
		UiStyle.draw_text(self, "NO GIGS POSTED", _row_rect(0).position + Vector2(12.0, 8.0), palette.hull_lighter)
		return
	for i in range(_gigs.size()):
		_draw_row(i)
	_draw_detail(_gigs[_picked])
	var balance: String = "BALANCE %s Cr" % Units.grouped(_agency.credits)
	UiStyle.draw_text(self, balance, Vector2(_panel.position.x + MARGIN, _panel.end.y - MARGIN - 7.0), palette.gold_light, 1)


func _draw_row(i: int) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var gig: Gig = _gigs[i]
	var rect: Rect2 = _row_rect(i)
	var picked: bool = i == _picked
	var line: Color = palette.agency_orange_light if picked else palette.hull_lighter
	var fill: Color = palette.agency_orange_dark if picked else UiStyle.box_fill()
	if _pressed == "row%d" % i and not picked:
		fill = palette.hull_mid
	UiStyle.draw_box(self, rect, line, fill)
	var pay: String = "%s Cr" % Units.grouped(gig.payout)
	var pay_width: float = UiStyle.text_width(pay)
	UiStyle.draw_text(self, pay, Vector2(rect.end.x - 12.0 - pay_width, rect.position.y + 10.0), palette.hull_lightest)
	var title_size: int = 2 if UiStyle.text_width(gig.title) + pay_width + 36.0 <= rect.size.x else 1
	UiStyle.draw_text(self, gig.title, Vector2(rect.position.x + 12.0, rect.position.y + (10.0 if title_size == 2 else 14.0)), palette.hull_lightest, title_size)
	var under: String = "%s // TO %s" % [gig.type.category, _agency.place_tag(gig.destination)]
	UiStyle.draw_text(self, under, Vector2(rect.position.x + 12.0, rect.position.y + 36.0), palette.gold_light if picked else palette.hull_lighter, 1)


func _draw_detail(gig: Gig) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	var area: Rect2 = _detail_rect()
	var y: float = area.position.y
	for line: String in _wrap(gig.title.to_upper(), area.size.x, 2):
		UiStyle.draw_text(self, line, Vector2(area.position.x, y), palette.agency_orange_light)
		y += 18.0
	y += 4.0
	draw_rect(Rect2(area.position.x, y, area.size.x, 1.0), palette.hull_mid)
	y += 10.0
	var value_x: float = area.position.x + UiStyle.text_width("HAZARDS: ", 1) + 6.0
	var rows: Array = [
		["PAYOUT:", "%s Cr" % Units.grouped(gig.payout)],
		["TO:", _agency.place_name(gig.destination)],
	]
	if gig.type.kind == "cargo":
		rows.append(["CARGO:", "%s kg of %s" % [Units.grouped(roundi(gig.cargo_kg)), gig.thing.to_lower()]])
	else:
		rows.append(["SCAN:", "%d s, within %s" % [roundi(gig.type.scan_seconds), Units.distance_text(gig.type.site_reach).to_lower()]])
	for row: Array in rows:
		UiStyle.draw_text(self, row[0], Vector2(area.position.x, y + 4.0), palette.hull_lighter, 1)
		UiStyle.draw_text(self, row[1], Vector2(value_x, y), palette.hull_lightest)
		y += 20.0
	UiStyle.draw_text(self, "HAZARDS:", Vector2(area.position.x, y + 4.0), palette.hull_lighter, 1)
	for hazard: Array in _agency.hazards(gig):
		var text: String = hazard[0]
		UiStyle.draw_text(self, text, Vector2(value_x, y), palette.hull_lightest)
		if hazard[1] != "":
			var level_color: Color = palette.agency_red if hazard[1] == "HIGH" else (palette.telemetry_amber if hazard[1] == "MEDIUM" else palette.telemetry_green)
			UiStyle.draw_text(self, "(%s)" % hazard[1], Vector2(value_x + UiStyle.text_width(text + " "), y), level_color)
		y += 20.0
	y += 4.0
	draw_rect(Rect2(area.position.x, y, area.size.x, 1.0), palette.hull_mid)
	y += 10.0
	for line: String in _wrap(gig.description, area.size.x, 1):
		UiStyle.draw_text(self, line, Vector2(area.position.x, y), palette.hull_lightest, 1)
		y += 12.0
	y += 6.0
	draw_rect(Rect2(area.position.x, y, area.size.x, 1.0), palette.hull_mid)
	y += 10.0
	UiStyle.draw_text(self, "MIN. REQS:", Vector2(area.position.x, y), palette.hull_lighter, 1)
	for requirement: Array in _agency.requirements(gig):
		var met: bool = requirement[1]
		UiStyle.draw_text(self, "%s %s" % ["[x]" if met else "[ ]", requirement[0]], Vector2(value_x, y), palette.telemetry_green if met else palette.agency_red, 1)
		y += 13.0

	var button: Rect2 = _accept_rect()
	var ready: bool = _can_take(gig)
	var line_color: Color = palette.agency_orange_light if ready else palette.hull_mid
	var fill: Color = palette.agency_orange_dark if ready and _pressed == "accept" else UiStyle.box_fill()
	UiStyle.draw_box(self, button, line_color, fill, 2)
	var label: String = "[ ACCEPT GIG ]"
	UiStyle.draw_text(self, label, Vector2(button.position.x + floorf((button.size.x - UiStyle.text_width(label)) / 2.0), button.position.y + 15.0), palette.agency_orange_light if ready else palette.hull_light)


# A warning sign: an orange triangle with an exclamation mark, this tall.
func _draw_warning(top_left: Vector2, height: float, color: Color) -> void:
	var width: float = height + 2.0
	var tip := Vector2(top_left.x + floorf(width / 2.0), top_left.y)
	draw_colored_polygon(PackedVector2Array([tip, Vector2(top_left.x + width, top_left.y + height), Vector2(top_left.x, top_left.y + height)]), color)
	var dark: Color = UiStyle.palette().hull_darkest
	draw_rect(Rect2(tip.x - 1.0, top_left.y + height * 0.35, 2.0, height * 0.35), dark)
	draw_rect(Rect2(tip.x - 1.0, top_left.y + height * 0.78, 2.0, 2.0), dark)


# Splits text into lines that fit a width at a text size, at spaces.
func _wrap(text: String, width: float, pixel_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line: String = ""
	for word: String in text.split(" "):
		var tried: String = word if line == "" else line + " " + word
		if UiStyle.text_width(tried, pixel_size) > width and line != "":
			lines.append(line)
			line = word
		else:
			line = tried
	if line != "":
		lines.append(line)
	return lines
