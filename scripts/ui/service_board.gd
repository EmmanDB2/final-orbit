# service_board.gd: a ship services terminal, at the station's docking room or a base's assembly
# building, in two tabs down the left. REPAIRS draws the ship as it is, with a tooltip on each damaged
# part saying what's wrong and, under it, what fixing it costs, and REPAIR ALL at the bottom right with
# the total. REFUEL draws the ship cut away to its systems, with a tooltip on each tank saying what it
# holds, a fuel meter at the right, and REFUEL with what filling up costs. At the station a third tab,
# SHIPS, is the hangar for now: the ships to fly, and FLY to trade for one. It only works on a ship
# docked there, or on the base's pad. It covers the flight while it's up. From DESIGN.md, "Prices",
# drawn to Manny's 2026-11-12 sketch.
class_name ServiceBoard
extends UiWidget

signal closed

const MOST_SIZE: Vector2 = Vector2(900.0, 560.0)
const HEADER: float = 50.0
const MARGIN: float = 16.0
const TAB_WIDTH: float = 150.0
const TAB_HEIGHT: float = 44.0
const BUTTON_SIZE: Vector2 = Vector2(250.0, 44.0)
const CLOSE_SIZE: Vector2 = Vector2(104.0, 30.0)
const TIP_SIZE: Vector2 = Vector2(150.0, 44.0)
const TIP_GAP: float = 6.0
const METER_WIDTH: float = 76.0
const SHIP_ROW: float = 30.0

var _services: ShipServices
# Where this terminal is: the station, or a base. The ship has to be docked there, or on its pad.
var _at: Dictionary = {"kind": "station"}
var _tab: String = "REPAIRS"
var _panel := Rect2()
var _finger := Vector2.ZERO
var _pressed: String = ""
# The press that opened it, a tap on USE TERMINAL or F, is still down when it opens. Keys only count
# once everything's been let go since.
var _keys_ready: bool = false
# The ship's pictures, plain for repairs and cut away for refuelling: [texture, where the grid's
# middle falls on it]. Made again after anything's done to the ship.
var _pictures: Dictionary = {}
# What the last thing done came to, shown under the balance.
var _note: String = ""
# On SHIPS, which ship in the hangar is picked.
var _picked_ship: int = 0


## Shows the terminal at a place, on REPAIRS if anything needs fixing and REFUEL if not.
func open(services: ShipServices, at: Dictionary = {"kind": "station"}) -> void:
	_services = services
	_at = at
	_picked_ship = maxi(_ships().find(services.ship().design), 0)
	_tab = "REPAIRS" if not services.problems().is_empty() else "REFUEL"
	_keys_ready = false
	_note = ""
	_pictures.clear()
	visible = true
	queue_redraw()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Reads everything again, after something's changed, such as the credits.
func refresh() -> void:
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
		elif part == "action":
			_act()
		elif part.begins_with("tab_"):
			_tab = part.substr(4)
		elif part.begins_with("ship_"):
			_picked_ship = int(part.substr(5))
	_pressed = ""
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not _keys_ready:
		_keys_ready = not (Input.is_action_pressed("interact") or Input.is_action_pressed("translate_forward") or Input.is_action_pressed("translate_back") or Input.is_action_pressed("ui_cancel"))
		return
	# On the Mac: up and down switch tabs, F does it, and Escape closes.
	if Input.is_action_just_pressed("translate_forward") or Input.is_action_just_pressed("translate_back"):
		var tabs: Array[String] = _tabs()
		var step: int = 1 if Input.is_action_just_pressed("translate_back") else -1
		_tab = tabs[posmod(tabs.find(_tab) + step, tabs.size())]
		queue_redraw()
	if _tab == "SHIPS" and (Input.is_action_just_pressed("translate_left") or Input.is_action_just_pressed("translate_right")):
		var step: int = 1 if Input.is_action_just_pressed("translate_right") else -1
		_picked_ship = posmod(_picked_ship + step, maxi(_ships().size(), 1))
		queue_redraw()
	if Input.is_action_just_pressed("interact"):
		_act()
	if Input.is_action_just_pressed("ui_cancel"):
		close()


# REPAIR ALL or REFUEL, whichever tab's up, if the ship's here.
func _act() -> void:
	if not _services.ship_here(_at):
		return
	if _tab == "SHIPS":
		var ships: Array[ShipDesign] = _ships()
		if _picked_ship < ships.size() and _services.trade_for(ships[_picked_ship]):
			_note = "NOW FLYING %s" % ships[_picked_ship].display_name.to_upper()
			_pictures.clear()
	elif _tab == "REPAIRS":
		var cost: int = _services.repair_cost()
		if _services.repair():
			_note = "REPAIRED: -%s CR" % Units.grouped(cost) if cost > 0 else "REPAIRED"
			_pictures.clear()
	else:
		var cost: int = _services.refuel_paid()
		if _services.refuel():
			_note = "REFUELLED: -%s CR" % Units.grouped(cost) if cost > 0 else "REFUELLED"
	queue_redraw()


func _layout() -> void:
	var room: Vector2 = size - Vector2(32.0, 60.0)
	var panel_size := Vector2(minf(room.x, MOST_SIZE.x), minf(room.y, MOST_SIZE.y)).floor()
	_panel = Rect2(((size - panel_size) / 2.0 + Vector2(0.0, 18.0)).floor(), panel_size)


func _tab_rect(i: int) -> Rect2:
	return Rect2(_panel.position + Vector2(MARGIN, HEADER + MARGIN + i * (TAB_HEIGHT + 8.0)), Vector2(TAB_WIDTH, TAB_HEIGHT))


func _close_rect() -> Rect2:
	return Rect2(_panel.end.x - MARGIN - CLOSE_SIZE.x, _panel.position.y + floorf((HEADER - CLOSE_SIZE.y) / 2.0), CLOSE_SIZE.x, CLOSE_SIZE.y)


func _action_rect() -> Rect2:
	return Rect2(_panel.end - Vector2(MARGIN, MARGIN) - BUTTON_SIZE, BUTTON_SIZE)


# Right of the tabs, above the button: where the ship, its tooltips, and the meter go.
func _main_rect() -> Rect2:
	var left: float = _panel.position.x + MARGIN * 2.0 + TAB_WIDTH
	var top: float = _panel.position.y + HEADER + MARGIN
	return Rect2(left, top, _panel.end.x - MARGIN - left, _action_rect().position.y - 10.0 - top)


func _part_at(point: Vector2) -> String:
	if not _panel.has_point(point):
		return "outside"
	if _close_rect().grow(6.0).has_point(point):
		return "close"
	if _action_rect().has_point(point):
		return "action"
	var tabs: Array[String] = _tabs()
	for i in range(tabs.size()):
		if _tab_rect(i).has_point(point):
			return "tab_" + tabs[i]
	if _tab == "SHIPS":
		for i in range(_ships().size()):
			if _ship_row(i).has_point(point):
				return "ship_%d" % i
	return ""


# The tabs this terminal has: SHIPS only at the station, where the hangar is.
func _tabs() -> Array[String]:
	var tabs: Array[String] = ["REFUEL", "REPAIRS"]
	if _services != null and _services.hangar != null and _at.get("kind", "") == "station":
		tabs.append("SHIPS")
	return tabs


func _ships() -> Array[ShipDesign]:
	if _services == null or _services.hangar == null:
		return []
	return _services.hangar.ships


func _ship_row(i: int) -> Rect2:
	return Rect2(_panel.position.x + MARGIN, _list_top() + 14.0 + i * (SHIP_ROW + 6.0), TAB_WIDTH, SHIP_ROW)


func _draw() -> void:
	if _services == null:
		return
	_layout()
	var palette: AgencyPalette = UiStyle.palette()
	var shade: Color = palette.hull_darkest
	shade.a = 0.45
	draw_rect(Rect2(Vector2.ZERO, size), shade)
	var fill: Color = palette.hull_darkest
	fill.a = 0.94
	UiStyle.draw_box(self, _panel, palette.hull_light, fill)

	# The header: the tab's name, where this is, and CLOSE.
	var title_size: int = 3 if _panel.size.x >= 760.0 else 2
	var title_y: float = _panel.position.y + floorf((HEADER - 7.0 * title_size) / 2.0)
	UiStyle.draw_text(self, _tab, Vector2(_panel.position.x + MARGIN, title_y), palette.agency_orange_light, title_size)
	var where: String = "SHIP SERVICES // %s" % ("DOCKING BAY" if _at.get("kind", "") == "station" else _services.place_name(_at))
	var where_x: float = _panel.position.x + MARGIN + UiStyle.text_width(_tab + "  ", title_size)
	if where_x + UiStyle.text_width(where, 1) < _close_rect().position.x - 12.0:
		UiStyle.draw_text(self, where, Vector2(where_x, _panel.position.y + floorf(HEADER / 2.0) - 3.0), palette.hull_lighter, 1)
	var close: Rect2 = _close_rect()
	UiStyle.draw_box(self, close, palette.hull_lighter, palette.hull_mid if _pressed == "close" else UiStyle.box_fill())
	UiStyle.draw_text(self, "CLOSE [×]", Vector2(close.position.x + floorf((close.size.x - UiStyle.text_width("CLOSE [×]", 1)) / 2.0), close.position.y + 11.0), palette.hull_lightest, 1)
	draw_rect(Rect2(_panel.position.x + MARGIN, _panel.position.y + HEADER, _panel.size.x - MARGIN * 2.0, 1.0), palette.hull_mid)
	var divider_x: float = _panel.position.x + MARGIN * 1.5 + TAB_WIDTH
	draw_rect(Rect2(divider_x, _panel.position.y + HEADER + MARGIN, 1.0, _panel.size.y - HEADER - MARGIN * 2.0), palette.hull_mid)

	var tabs: Array[String] = _tabs()
	if not tabs.has(_tab):
		_tab = tabs[0]
	for i in range(tabs.size()):
		_draw_tab(i, palette)
	if _tab == "REPAIRS":
		_draw_repairs(palette)
	elif _tab == "SHIPS":
		_draw_ships(palette)
	else:
		_draw_refuel(palette)
	_draw_balance(palette)


func _draw_tab(i: int, palette: AgencyPalette) -> void:
	var name: String = _tabs()[i]
	var rect: Rect2 = _tab_rect(i)
	var picked: bool = name == _tab
	var fill: Color = palette.agency_orange_dark if picked else (palette.hull_mid if _pressed == "tab_" + name else UiStyle.box_fill())
	UiStyle.draw_box(self, rect, palette.agency_orange_light if picked else palette.hull_lighter, fill)
	UiStyle.draw_text(self, name, rect.position + Vector2(12.0, 15.0), palette.hull_lightest)
	# A word on how things stand: how many problems, how full the tanks are, or how many ships.
	var badge: String = ""
	if name == "REPAIRS":
		var count: int = _services.problems().size()
		badge = "OK" if count == 0 else str(count)
	elif name == "SHIPS":
		badge = str(_ships().size())
	else:
		var ship: Node2D = _services.ship()
		badge = "%d%%" % roundi(100.0 * ship.fuel / maxf(ship.body.original_fuel_capacity, 1.0))
	UiStyle.draw_text(self, badge, Vector2(rect.end.x - 10.0 - UiStyle.text_width(badge, 1), rect.position.y + 19.0), palette.gold_light, 1)


# The balance, the credit line, and what the last thing done cost, at the bottom of the left column.
func _draw_balance(palette: AgencyPalette) -> void:
	var x: float = _panel.position.x + MARGIN
	var y: float = _panel.end.y - MARGIN - 7.0
	if _services.free:
		UiStyle.draw_text(self, "ZEN MODE: FREE", Vector2(x, y), palette.telemetry_green, 1)
		y -= 14.0
	else:
		var credits: int = _services.credits()
		UiStyle.draw_text(self, "CREDIT LINE %s CR" % Units.grouped(_services.prices.credit_line), Vector2(x, y), palette.hull_lighter, 1)
		y -= 14.0
		var balance: String = "BALANCE %s CR" % Units.grouped(credits)
		UiStyle.draw_text(self, balance, Vector2(x, y), palette.agency_red if credits < 0 else palette.gold_light, 1)
		y -= 14.0
	if _note != "":
		UiStyle.draw_text(self, _note, Vector2(x, y), palette.telemetry_green, 1)


func _draw_repairs(palette: AgencyPalette) -> void:
	var problems: Array[Dictionary] = _services.problems()
	var area: Rect2 = _main_rect()
	var picture: Rect2 = _draw_ship(area, false)
	var tips: Array[Dictionary] = []
	for problem: Dictionary in problems:
		var color: Color = palette.agency_red if problem["state"] == "NOT WORKING" else palette.telemetry_amber
		var cost: String = "FREE" if _services.free else "%s CR" % Units.grouped(problem["cost"])
		tips.append({
			"at": _on_picture(picture, problem["at"]),
			"lines": [problem["name"], "%s · %d%% GONE" % [problem["state"], ceili(problem["gone"] * 100.0)], cost],
			"color": color,
		})
	_draw_tips(tips, area, picture, palette)
	_draw_list_heading("DAMAGE REPORT", palette)
	var y: float = _list_top() + 14.0
	if problems.is_empty():
		UiStyle.draw_text(self, "NO DAMAGE FOUND", Vector2(_panel.position.x + MARGIN, y), palette.telemetry_green, 1)
	for problem: Dictionary in problems:
		if y > _panel.end.y - MARGIN - 60.0:
			break
		UiStyle.draw_text(self, _fit(problem["name"], TAB_WIDTH, 1), Vector2(_panel.position.x + MARGIN, y), palette.hull_lightest, 1)
		var cost: String = "FREE" if _services.free else "%s CR" % Units.grouped(problem["cost"])
		UiStyle.draw_text(self, cost, Vector2(_panel.position.x + MARGIN, y + 10.0), palette.gold_light, 1)
		y += 26.0

	var total: int = _services.repair_cost()
	if not _services.ship_here(_at):
		_draw_action("REPAIR ALL", false, palette, _away_reason())
	elif problems.is_empty():
		_draw_action("NO REPAIRS NEEDED", false, palette)
	elif not _services.can_pay(total):
		_draw_action("REPAIR ALL · %s CR" % Units.grouped(total), false, palette, "NOT ENOUGH CREDIT")
	else:
		_draw_action("REPAIR ALL · %s" % ("FREE" if _services.free else "%s CR" % Units.grouped(total)), true, palette)


func _draw_refuel(palette: AgencyPalette) -> void:
	var area: Rect2 = _main_rect()
	var meter := Rect2(area.end.x - METER_WIDTH, area.position.y, METER_WIDTH, area.size.y)
	var ship_area := Rect2(area.position, Vector2(area.size.x - METER_WIDTH - 10.0, area.size.y))
	var picture: Rect2 = _draw_ship(ship_area, true)
	var tips: Array[Dictionary] = []
	for tank: Dictionary in _services.tanks():
		var color: Color = palette.telemetry_cyan if tank["rcs"] else palette.agency_orange_light
		var held: String = "%s / %s KG" % [Units.grouped(roundi(tank["kg"])), Units.grouped(roundi(tank["room"]))]
		var state: String = "HOLED, HOLDS %d%%" % roundi(100.0 * tank["room"] / tank["full"]) if tank["holed"] else "%d%% FULL" % roundi(100.0 * tank["kg"] / maxf(tank["room"], 1.0))
		tips.append({"at": _on_picture(picture, tank["at"]), "lines": [tank["name"], held, state], "color": palette.telemetry_amber if tank["holed"] else color})
	_draw_tips(tips, ship_area, picture, palette)
	_draw_meter(meter, palette)
	_draw_list_heading("TANKS", palette)
	var y: float = _list_top() + 14.0
	for tank: Dictionary in _services.tanks():
		UiStyle.draw_text(self, _fit(tank["name"], TAB_WIDTH, 1), Vector2(_panel.position.x + MARGIN, y), palette.hull_lightest, 1)
		UiStyle.draw_text(self, "%s KG" % Units.grouped(roundi(tank["kg"])), Vector2(_panel.position.x + MARGIN, y + 10.0), palette.telemetry_cyan if tank["rcs"] else palette.agency_orange_light, 1)
		y += 26.0

	var wanted: float = _services.fuel_wanted() + _services.rcs_wanted()
	var share: float = _services.refuel_share()
	if not _services.ship_here(_at):
		_draw_action("REFUEL", false, palette, _away_reason())
	elif wanted <= 0.01:
		_draw_action("TANKS FULL", false, palette)
	elif share <= 0.0:
		_draw_action("REFUEL · %s CR" % Units.grouped(_services.refuel_cost()), false, palette, "NO CREDIT LEFT")
	elif share < 1.0:
		_draw_action("REFUEL %d%% · %s CR" % [floori(share * 100.0), Units.grouped(_services.refuel_paid())], true, palette, "ALL YOUR CREDIT BUYS")
	else:
		_draw_action("REFUEL · %s" % ("FREE" if _services.free else "%s CR" % Units.grouped(_services.refuel_cost())), true, palette)


# SHIPS: the hangar's ships down the left, the picked one drawn with its numbers, and FLY to trade the
# docked ship for it. The one being flown is the live ship, damage and all.
func _draw_ships(palette: AgencyPalette) -> void:
	var ships: Array[ShipDesign] = _ships()
	if ships.is_empty():
		return
	_picked_ship = clampi(_picked_ship, 0, ships.size() - 1)
	var current: ShipDesign = _services.ship().design
	_draw_list_heading("HANGAR", palette)
	for i in range(ships.size()):
		var row: Rect2 = _ship_row(i)
		var picked: bool = i == _picked_ship
		var fill: Color = palette.agency_orange_dark if picked else (palette.hull_mid if _pressed == "ship_%d" % i else UiStyle.box_fill())
		UiStyle.draw_box(self, row, palette.agency_orange_light if picked else palette.hull_light, fill)
		UiStyle.draw_text(self, _fit(ships[i].display_name.to_upper(), TAB_WIDTH - 16.0, 1), row.position + Vector2(8.0, 6.0), palette.hull_lightest, 1)
		var state: String = "IN USE" if ships[i] == current else ("LEFT HERE" if _services.hangar.has_kept(ships[i]) else "NEW")
		UiStyle.draw_text(self, state, row.position + Vector2(8.0, 17.0), palette.telemetry_cyan if ships[i] == current else palette.gold_light, 1)

	var design: ShipDesign = ships[_picked_ship]
	var area: Rect2 = _main_rect()
	var facts_width: float = 210.0
	var picture_area := Rect2(area.position, Vector2(area.size.x - facts_width - 16.0, area.size.y))
	if design == current:
		_draw_ship(picture_area, false, null, "plain", false)
	else:
		_draw_ship(picture_area, false, _services.whole_of(design), "hangar_" + design.resource_path, false)
	var numbers: Dictionary = _services.numbers_of(design)
	var x: float = area.end.x - facts_width
	var y: float = area.position.y + 20.0
	UiStyle.draw_text(self, _fit(design.display_name.to_upper(), facts_width, 2), Vector2(x, y), palette.agency_orange_light, 2)
	y += 28.0
	var facts: Array = [
		["DRY MASS", "%s KG" % Units.grouped(roundi(numbers["dry_kg"]))],
		["FUEL", "%s KG" % Units.grouped(roundi(numbers["fuel_kg"]))],
		["ΔV, FULL", "%s M/S" % Units.speed_number(numbers["delta_v"])],
		["SAFE LANDING", "%s M/S ON LEGS" % Units.speed_number(numbers["safe_speed"])],
		["CARGO", "%s KG" % Units.grouped(roundi(design.cargo_capacity))],
	]
	for fact: Array in facts:
		UiStyle.draw_text(self, fact[0], Vector2(x, y), palette.hull_lighter, 1)
		UiStyle.draw_text(self, fact[1], Vector2(x, y + 11.0), palette.hull_lightest, 1)
		y += 30.0
	var status: String = "THE SHIP YOU'RE FLYING" if design == current else ("AS YOU LEFT IT" if _services.hangar.has_kept(design) else "NEW: WHOLE, FULL TANKS")
	UiStyle.draw_text(self, status, Vector2(x, y + 6.0), palette.telemetry_cyan, 1)
	UiStyle.draw_text(self, "FREE FOR NOW", Vector2(x, y + 20.0), palette.gold_light, 1)

	if not _services.ship_here(_at):
		_draw_action("FLY", false, palette, _away_reason())
	elif design == current:
		_draw_action("IN USE", false, palette)
	else:
		_draw_action("FLY %s" % design.display_name.to_upper(), true, palette)


# The ship's picture, as big as fits, in the middle of an area. Returns where it's drawn, and remembers
# the scale on the rect's size, the picture's size times it.
func _draw_ship(area: Rect2, cutaway: bool, body: ShipBody = null, key: String = "", tip_room: bool = true) -> Rect2:
	if key == "":
		key = "cutaway" if cutaway else "plain"
	if not _pictures.has(key):
		var made: Dictionary = (body if body != null else _services.ship().body).picture(cutaway)
		# Lit from the upper left, so a ship drawn flat shows its shape here too.
		_pictures[key] = [ImageTexture.create_from_image(HullLight.lit_picture(made["image"])), made["middle"]]
	var texture: ImageTexture = _pictures[key][0]
	var picture_size := Vector2(texture.get_size())
	var room := Vector2(area.size.x - ((TIP_SIZE.x + 30.0) * 2.0 if tip_room else 0.0), area.size.y)
	var scale: int = clampi(floori(minf(room.x / picture_size.x, room.y / picture_size.y)), 1, 4)
	var drawn: Vector2 = picture_size * scale
	var rect := Rect2((area.get_center() - drawn / 2.0).floor(), drawn)
	draw_texture_rect(texture, rect, false)
	return rect


# A point on the ship, from the middle of its grid, on the drawn picture.
func _on_picture(picture: Rect2, at: Vector2) -> Vector2:
	var key: String = "cutaway" if _tab == "REFUEL" else "plain"
	var middle: Vector2 = _pictures[key][1]
	var scale: float = picture.size.x / float(_pictures[key][0].get_width())
	return (picture.position + (at + middle) * scale).floor()


# Tooltips beside the ship, each joined to its point by a line: those on the left half go left, the rest
# right, stacked down in the order of their points so lines don't cross.
func _draw_tips(tips: Array[Dictionary], area: Rect2, picture: Rect2, palette: AgencyPalette) -> void:
	var middle_x: float = picture.get_center().x
	for left_side: bool in [true, false]:
		var side: Array[Dictionary] = []
		for tip: Dictionary in tips:
			if (tip["at"].x < middle_x) == left_side:
				side.append(tip)
		side.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"].y < b["at"].y)
		var x: float = maxf(area.position.x, picture.position.x - 24.0 - TIP_SIZE.x) if left_side else minf(area.end.x - TIP_SIZE.x, picture.end.x + 24.0)
		var tops: Array[float] = []
		var y: float = area.position.y
		for tip: Dictionary in side:
			y = maxf(y, tip["at"].y - TIP_SIZE.y / 2.0)
			tops.append(y)
			y += TIP_SIZE.y + TIP_GAP
		# Too many to fit going down: lift the whole stack.
		var over: float = y - TIP_GAP - area.end.y
		for i in range(tops.size()):
			tops[i] = floorf(maxf(tops[i] - maxf(over, 0.0), area.position.y + i * (TIP_SIZE.y + TIP_GAP)))
		for i in range(side.size()):
			_draw_tip(side[i], Rect2(Vector2(floorf(x), tops[i]), TIP_SIZE), left_side, palette)


func _draw_tip(tip: Dictionary, box: Rect2, left_side: bool, palette: AgencyPalette) -> void:
	var color: Color = tip["color"]
	var at: Vector2 = tip["at"]
	var edge := Vector2(box.end.x if left_side else box.position.x, box.position.y + floorf(box.size.y / 2.0))
	var stub := edge + Vector2(10.0 if left_side else -10.0, 0.0)
	draw_line(edge, stub, color, 1.0)
	draw_line(stub, at, color, 1.0)
	draw_rect(Rect2(at - Vector2(2.0, 2.0), Vector2(5.0, 5.0)), palette.hull_darkest)
	draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), color)
	UiStyle.draw_box(self, box, color, UiStyle.box_fill())
	var lines: Array = tip["lines"]
	var y: float = box.position.y + 6.0
	for i in range(lines.size()):
		var text_color: Color = palette.hull_lightest if i == 0 else (palette.gold_light if i == lines.size() - 1 else color)
		UiStyle.draw_text(self, _fit(lines[i], box.size.x - 14.0, 1), Vector2(box.position.x + 7.0, y), text_color, 1)
		y += 12.0


# The fuel meter: engine fuel in orange and RCS propellant in cyan, what's aboard solid, what filling up
# would add in light, and a red mark where a holed tank stops.
func _draw_meter(meter: Rect2, palette: AgencyPalette) -> void:
	var ship: Node2D = _services.ship()
	var share: float = _services.refuel_share()
	var gauges: Array = [
		["F", ship.fuel, _services.fuel_wanted() * share, ship.body.fuel_capacity, ship.body.original_fuel_capacity, palette.agency_orange, palette.agency_orange_light],
		["R", ship.rcs_fuel, _services.rcs_wanted() * share, ship.design.rcs_capacity, ship.design.rcs_capacity, palette.telemetry_cyan, palette.agency_blue_light],
	]
	var width: float = floorf((meter.size.x - 6.0) / 2.0)
	for i in range(gauges.size()):
		var gauge: Array = gauges[i]
		var column := Rect2(meter.position.x + i * (width + 6.0), meter.position.y, width, meter.size.y)
		UiStyle.draw_text(self, gauge[0], Vector2(column.position.x + floorf((width - 10.0) / 2.0), column.position.y), gauge[5], 2)
		var bar := Rect2(column.position.x, column.position.y + 22.0, width, column.size.y - 44.0)
		UiStyle.draw_box(self, bar, palette.hull_light, UiStyle.box_fill())
		var inside: Rect2 = bar.grow(-3.0)
		var whole: float = maxf(gauge[4], 1.0)
		var aboard: float = inside.size.y * clampf(gauge[1] / whole, 0.0, 1.0)
		var adding: float = inside.size.y * clampf(gauge[2] / whole, 0.0, 1.0)
		draw_rect(Rect2(inside.position.x, inside.end.y - aboard, inside.size.x, aboard), gauge[5])
		if adding >= 1.0:
			var light: Color = gauge[6]
			light.a = 0.55
			draw_rect(Rect2(inside.position.x, inside.end.y - aboard - adding, inside.size.x, adding), light)
		if gauge[3] < gauge[4] - 0.5:
			var stop: float = inside.end.y - inside.size.y * clampf(gauge[3] / whole, 0.0, 1.0)
			draw_rect(Rect2(inside.position.x - 2.0, floorf(stop), inside.size.x + 4.0, 2.0), palette.agency_red)
		var percent: String = "%d%%" % roundi(100.0 * gauge[1] / whole)
		UiStyle.draw_text(self, percent, Vector2(column.position.x + floorf((width - UiStyle.text_width(percent, 1)) / 2.0), bar.end.y + 8.0), palette.hull_lightest, 1)


# Why the ship can't be served from here.
func _away_reason() -> String:
	return "SHIP NOT DOCKED" if _at.get("kind", "") == "station" else "SHIP NOT ON THE PAD"


func _list_top() -> float:
	return _tab_rect(_tabs().size() - 1).end.y + 18.0


func _draw_list_heading(text: String, palette: AgencyPalette) -> void:
	UiStyle.draw_text(self, text, Vector2(_panel.position.x + MARGIN, _list_top()), palette.hull_lighter, 1)


# The bottom-right button, lit if it can be used, with a word above it when it can't do everything.
func _draw_action(label: String, ready: bool, palette: AgencyPalette, why: String = "") -> void:
	var button: Rect2 = _action_rect()
	var line: Color = palette.agency_orange_light if ready else palette.hull_mid
	var fill: Color = palette.agency_orange_dark if ready and _pressed == "action" else UiStyle.box_fill()
	UiStyle.draw_box(self, button, line, fill, 2)
	var text: String = "[ %s ]" % label
	var size_used: int = 2 if UiStyle.text_width(text, 2) <= button.size.x - 16.0 else 1
	var text_y: float = button.position.y + floorf((button.size.y - 7.0 * size_used) / 2.0)
	UiStyle.draw_text(self, text, Vector2(button.position.x + floorf((button.size.x - UiStyle.text_width(text, size_used)) / 2.0), text_y), palette.agency_orange_light if ready else palette.hull_light, size_used)
	if why != "":
		UiStyle.draw_text(self, why, Vector2(button.end.x - UiStyle.text_width(why, 1), button.position.y - 12.0), palette.agency_red if not ready else palette.telemetry_amber, 1)


# Cuts text down to fit a width, with dots if it's cut.
func _fit(text: String, width: float, pixel_size: int) -> String:
	if UiStyle.text_width(text, pixel_size) <= width:
		return text
	var cut: String = text
	while cut.length() > 1 and UiStyle.text_width(cut + "..", pixel_size) > width:
		cut = cut.substr(0, cut.length() - 1)
	return cut + ".."
