# test_gigs.gd: checks the agency holds up to three gigs at once: the slot and cargo limits, the delta-v
# check, delivering several at one place, focus, losing them all, saving and loading, and old saves.
# From DESIGN.md, "Gigs". Run with:
#   godot --headless --path . --script tests/test_gigs.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0
var _agency: Agency
var _ship: Node2D
var _messages: Array[String] = []
var _next_id: int = 900


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_agency = main.agency
	_ship = main.get_node("Ship")
	# Docked at Kapteyn-3, where the station's gigs start and the cargo can be unloaded.
	main.get_node("Station").restore_state({"docked_port": 0})
	await process_frame
	_agency.message_raised.connect(func(text: String, _good: bool) -> void: _messages.append(text))
	_test_slots()
	_test_cargo_room()
	_test_delta_v()
	_test_delivering_together()
	_test_focus_follows_the_oldest()
	_test_losing_them_all()
	_test_save_and_restore()
	_test_old_save_upgrades()
	_test_board_stays_open(main)
	main.queue_free()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL %s %s" % [label, detail])


# Nothing held, nothing aboard.
func _reset() -> void:
	_agency.gigs.clear()
	_agency.focus = null
	_ship.unload_cargo()
	_messages.clear()


# A cargo gig from the station to a place, with a route that's easy on the ship's fuel.
func _cargo(kg: float, destination: Dictionary = {"kind": "station", "index": 0}) -> Gig:
	var gig := Gig.new()
	_next_id += 1
	gig.id = _next_id
	gig.type = load("res://data/gigs/cargo.tres")
	gig.title = "CARGO: TEST %d" % gig.id
	gig.thing = "Test goods"
	gig.origin = {"kind": "station", "index": 0}
	gig.destination = destination
	gig.cargo_kg = kg
	gig.route_delta_v = 1.0
	gig.payout = 1000
	gig.objectives = PackedStringArray(["LOAD", "ARRIVE", "UNLOAD"])
	return gig


func _survey() -> Gig:
	var gig := Gig.new()
	_next_id += 1
	gig.id = _next_id
	gig.type = load("res://data/gigs/survey.tres")
	gig.title = "SURVEY: TEST %d" % gig.id
	gig.thing = "Test spot"
	gig.origin = {"kind": "station", "index": 0}
	gig.destination = {"kind": "survey", "world": 1, "column": 3, "name": "Test spot"}
	gig.route_delta_v = 1.0
	gig.payout = 500
	gig.objectives = PackedStringArray(["LAND", "SCAN", "UPLINK"])
	return gig


func _slot_row(gig: Gig) -> Array:
	for row: Array in _agency.requirements(gig):
		if (row[0] as String).begins_with("GIG SLOT FREE"):
			return row
	return []


func _test_slots() -> void:
	_reset()
	_check("the lander starts docked", _ship.docked)
	var held: Array[Gig] = []
	for i in range(3):
		var gig: Gig = _cargo(100.0)
		_check("gig %d is taken" % (i + 1), _agency.accept(gig))
		held.append(gig)
	_check("three are held", _agency.held_count() == 3)
	_check("full once three are held", _agency.is_full())
	_check("focus is the last one taken", _agency.focus == held[2])
	_check("held gigs are in state active", held.all(func(gig: Gig) -> bool: return gig.state == "active"))
	var fourth: Gig = _cargo(100.0)
	var row: Array = _slot_row(fourth)
	_check("the slot row says 3 of 3", not row.is_empty() and row[0] == "GIG SLOT FREE (3 OF 3 HELD)", str(row))
	_check("the slot row is unmet when full", not row.is_empty() and row[1] == false)
	_check("a fourth is refused", not _agency.accept(fourth))
	_check("and still three are held", _agency.held_count() == 3)
	_agency.gigs.erase(held[0])
	var row_two: Array = _slot_row(fourth)
	_check("the slot row says 2 of 3", not row_two.is_empty() and row_two[0] == "GIG SLOT FREE (2 OF 3 HELD)", str(row_two))
	_check("and is met with a slot free", not row_two.is_empty() and row_two[1] == true)
	_reset()


func _test_cargo_room() -> void:
	_reset()
	var room: float = _ship.cargo_room()
	_check("the lander has room for 3 t", is_equal_approx(room, 3000.0), str(room))
	_check("a first 1.4 t is taken", _agency.accept(_cargo(1400.0)))
	_check("a second 1.4 t is taken", _agency.accept(_cargo(1400.0)))
	_check("2.8 t is aboard", is_equal_approx(_ship.cargo_kg, 2800.0), str(_ship.cargo_kg))
	var third: Gig = _cargo(400.0)
	_check("a third that doesn't fit is refused", not _agency.accept(third))
	var fits: bool = _agency.requirements(third).any(func(row: Array) -> bool: return (row[0] as String).begins_with("CARGO ROOM") and row[1] == false)
	_check("by its cargo room row", fits)
	_check("a survey fits with a full hold", _agency.accept(_survey()))
	_check("mixed gigs: three held", _agency.held_count() == 3)
	_reset()


func _test_delta_v() -> void:
	_reset()
	var bare: float = _ship.delta_v_with(500.0)
	_ship.load_cargo(2000.0)
	var loaded: float = _ship.delta_v_with(500.0)
	_check("cargo aboard costs delta-v", loaded < bare)
	var gig: Gig = _cargo(500.0)
	gig.route_delta_v = (bare + loaded) / 2.0
	var dv_row: Array = []
	for row: Array in _agency.requirements(gig):
		if (row[0] as String).begins_with("ΔV"):
			dv_row = row
	_check("delta-v counts the cargo aboard plus the new", not dv_row.is_empty() and dv_row[1] == false)
	_ship.unload_cargo()
	dv_row = []
	for row: Array in _agency.requirements(gig):
		if (row[0] as String).begins_with("ΔV"):
			dv_row = row
	_check("and is met with the hold empty", not dv_row.is_empty() and dv_row[1] == true)
	_reset()


func _test_delivering_together() -> void:
	_reset()
	var here: Dictionary = {"kind": "station", "index": 0}
	var first: Gig = _cargo(1000.0, here)
	var second: Gig = _cargo(800.0, here)
	var third: Gig = _cargo(500.0, {"kind": "site", "index": 0})
	for gig: Gig in [first, second, third]:
		_check("takes %s" % gig.title, _agency.accept(gig))
	_check("2.3 t aboard", is_equal_approx(_ship.cargo_kg, 2300.0), str(_ship.cargo_kg))
	_agency._physics_process(0.1)
	_check("the ones due here reach their unload step", first.step == 2 and second.step == 2)
	_check("the far one stays at its arrive step", third.step == 1)
	var offered: Array = _agency.options()
	var unloads: int = offered.filter(func(option: Dictionary) -> bool: return option["label"] == "UNLOAD CARGO").size()
	_check("one UNLOAD CARGO row, not one per gig", unloads == 1, str(offered.map(func(o: Dictionary) -> String: return o["label"])))
	var before: int = _agency.credits
	_messages.clear()
	offered[0]["run"].call()
	_check("both are paid", _agency.credits == before + 2000, str(_agency.credits - before))
	_check("each raises its own comms line", _messages.filter(func(text: String) -> bool: return text.begins_with("CARGO DELIVERED")).size() == 2, str(_messages))
	_check("only the third is held", _agency.gigs == [third])
	_check("cargo is back to the third gig's mass", is_equal_approx(_ship.cargo_kg, 500.0), str(_ship.cargo_kg))
	_check("focus is the third", _agency.focus == third)
	_check("no more unloading offered", _agency.options().is_empty())
	_reset()


func _test_focus_follows_the_oldest() -> void:
	_reset()
	var here: Dictionary = {"kind": "station", "index": 0}
	var far: Dictionary = {"kind": "site", "index": 0}
	var oldest: Gig = _cargo(100.0, far)
	var middle: Gig = _cargo(100.0, here)
	var newest: Gig = _cargo(100.0, far)
	for gig: Gig in [oldest, middle, newest]:
		_agency.accept(gig)
	_check("focus is the newest", _agency.focus == newest)
	_agency.set_focus(middle)
	_check("a tap focuses another held gig", _agency.focus == middle)
	_agency.set_focus(_cargo(10.0))
	_check("a gig that isn't held can't be focused", _agency.focus == middle)
	_agency._physics_process(0.1)
	_agency.options()[0]["run"].call()
	_check("the focused gig was paid", not _agency.gigs.has(middle))
	_check("focus moves to the oldest left", _agency.focus == oldest)
	_reset()


func _test_losing_them_all() -> void:
	_reset()
	_agency.accept(_cargo(700.0))
	_agency.accept(_cargo(600.0))
	_agency.accept(_survey())
	_messages.clear()
	var last: Array = []
	var catcher: Callable = func(gig: Gig) -> void: last.append(gig)
	_agency.gig_changed.connect(catcher)
	_agency.pilot_lost()
	_agency.gig_changed.disconnect(catcher)
	_check("none are held after the pilot dies", _agency.gigs.is_empty() and _agency.focus == null)
	_check("the cargo is gone", is_zero_approx(_ship.cargo_kg))
	_check("one comms line", _messages == ["3 GIGS FAILED: PILOT LOST"], str(_messages))
	_check("gig_changed says nothing's held", last.size() == 1 and last[0] == null)
	_agency.accept(_cargo(300.0))
	_messages.clear()
	_agency.pilot_lost()
	_check("one gig says GIG FAILED", _messages == ["GIG FAILED: PILOT LOST"], str(_messages))

	_reset()
	_agency.accept(_cargo(300.0))
	_agency.accept(_survey())
	_messages.clear()
	_agency._on_ship_lost()
	_check("the ship's loss fails them all", _agency.gigs.is_empty())
	_check("with one comms line", _messages == ["2 GIGS FAILED: CARGO AND DATA LOST"], str(_messages))
	_reset()


func _test_save_and_restore() -> void:
	_reset()
	var a: Gig = _cargo(900.0, {"kind": "site", "index": 0})
	var b: Gig = _survey()
	var c: Gig = _cargo(450.0, {"kind": "site", "index": 0})
	for gig: Gig in [a, b, c]:
		_agency.accept(gig)
	b.step = 1
	b.scan_share = 0.4
	_agency.set_focus(b)
	var saved: Dictionary = _agency.save_state()
	_check("the save lists three gigs", saved["gigs"].size() == 3)
	_check("and the focus", saved["focus"] == b.id)
	_check("and no old active entry", not saved.has("active"))
	# Written and read back like a real save would be.
	var bytes: PackedByteArray = var_to_bytes(saved)
	var again: Dictionary = bytes_to_var(bytes)
	_reset()
	_agency.restore_state(again)
	_check("three gigs come back", _agency.held_count() == 3)
	_check("in the same order", _agency.gigs.map(func(gig: Gig) -> int: return gig.id) == [a.id, b.id, c.id])
	_check("with the same focus", _agency.focus != null and _agency.focus.id == b.id)
	_check("and the survey's progress", _agency.gigs[1].step == 1 and is_equal_approx(_agency.gigs[1].scan_share, 0.4))
	_check("and the cargo aboard", is_equal_approx(_ship.cargo_kg, 1350.0), str(_ship.cargo_kg))
	_reset()
	_agency.restore_state({})
	_check("an empty save holds nothing", _agency.gigs.is_empty() and _agency.focus == null)


func _test_old_save_upgrades() -> void:
	_reset()
	var old_gig: Gig = _cargo(600.0, {"kind": "site", "index": 0})
	_agency.accept(old_gig)
	var one: Dictionary = _agency.save_state()
	var old: Dictionary = {"version": 2, "agency": {"credits": 1500, "next_id": 12, "rounds": {}, "active": one["gigs"][0], "cargo_kg": 600.0}}
	_reset()
	var upgraded: Dictionary = SaveGame._upgrade(old)
	_check("the save is now version 3", upgraded["version"] == SaveGame.VERSION and SaveGame.VERSION == 3)
	var agency_data: Dictionary = upgraded["agency"]
	_check("the active gig is a one-item list", agency_data["gigs"].size() == 1 and not agency_data.has("active"))
	_check("focus is its id", agency_data["focus"] == old_gig.id)
	_agency.restore_state(agency_data)
	_check("it's held again", _agency.held_count() == 1 and _agency.focus != null and _agency.focus.id == old_gig.id)
	_check("with its cargo aboard", is_equal_approx(_ship.cargo_kg, 600.0), str(_ship.cargo_kg))
	_check("and the credits", _agency.credits == 1500)
	var none: Dictionary = SaveGame._upgrade({"version": 2, "agency": {"credits": 5, "active": {}}})
	_check("an old save with no gig holds none", none["agency"]["gigs"].is_empty() and none["agency"]["focus"] == -1)
	var bare: Dictionary = SaveGame._upgrade({"version": 1})
	_check("a version 1 save steps all the way up", bare["version"] == 3 and bare["agency"]["gigs"].is_empty())
	_agency.credits = 0
	_reset()


# Taking a gig keeps the board open; the button waits for another pick, so a double tap takes only one.
func _test_board_stays_open(main: Node) -> void:
	_reset()
	var hud: Node = main.get_node("Hud/SafeArea/FlightHud")
	var board: GigBoard = hud._gig_board
	hud._open_gig_board({"kind": "station", "index": 0})
	board.refresh()
	var shown: Array[Gig] = _agency.board({"kind": "station", "index": 0})
	# Make the first row something that's surely takeable: a small cargo gig.
	var easy: Gig = _cargo(100.0)
	easy.origin = {"kind": "station", "index": 0}
	var slots: Array = _agency._boards[Agency.place_key({"kind": "station", "index": 0})]
	slots[0] = easy
	board.refresh()
	board._picked = 0
	board._accept()
	_check("the gig is taken", _agency.held_count() == 1 and _agency.gigs[0] == easy)
	_check("the board stays open", board.visible)
	_check("the button waits", board._just_taken)
	_check("the row was replaced", _agency.board({"kind": "station", "index": 0})[0] != easy)
	board._accept()
	_check("a second tap takes nothing", _agency.held_count() == 1)
	board._picked = 1
	board._just_taken = false
	board._accept()
	_check("after picking a row, the next can be taken", _agency.held_count() == 2 or not board._can_take(shown[1]))
	board.close()
	_reset()
