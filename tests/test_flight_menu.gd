# test_flight_menu.gd: checks the FLIGHT menu has no LIGHTS OUT, and that SETTINGS opens and closes without
# a crash from the FLIGHT menu, tapped by a real finger, and from the title screen. The crash was a button
# tapped by a finger: UiButton emitted "tapped" before it let go, SETTINGS released every finger, which
# let the same button go again, and so on until the stack ran out. Run with:
#   godot --headless --path . --script tests/test_flight_menu.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var hud: FlightHud = main.get_node("Hud/SafeArea/FlightHud")
	var labels: Array[String] = []
	for button: UiWidget in hud._flight_menu.buttons():
		labels.append((button as UiButton).label)
	_flag("the FLIGHT menu has PAUSE, SETTINGS, TITLE and no LIGHTS", labels == ["PAUSE", "SETTINGS", "TITLE"])
	# A real finger: down on the SETTINGS button, up again.
	hud._flight_menu.visible = true
	var settings_button: UiButton = hud._flight_menu.buttons()[1]
	var at: Vector2 = settings_button.get_global_rect().get_center()
	hud._on_finger_down(0, at)
	hud._on_finger_up(0)
	for i in range(5):
		await process_frame
	_flag("a tap on SETTINGS opens it", hud._settings.visible)
	_flag("and takes the menu away", not hud._flight_menu.visible)
	hud._settings._pressed = "done"
	hud._settings.finger_up()
	_flag("DONE closes it and gives the pilot back their controls", not hud._settings.visible and not main.get_node("Pilot").input_blocked)
	# Again, with a drag on the way, as a finger does.
	hud._flight_menu.visible = true
	hud._on_finger_down(0, at)
	hud._on_finger_moved(0, at + Vector2(2.0, 1.0))
	hud._on_finger_up(0)
	_flag("a tap with a little drag opens it too", hud._settings.visible)
	hud._settings._pressed = "done"
	hud._settings.finger_up()
	# From the title screen: its own settings screen, with its own input.
	var screen := SettingsScreen.new()
	screen.own_input = true
	screen.size = Vector2(1000.0, 700.0)
	root.add_child(screen)
	var closed: Array = []
	screen.closed.connect(func() -> void: closed.append(true))
	screen.open()
	await process_frame
	screen._pressed = "done"
	screen.finger_up()
	_flag("the title's settings open and close", closed.size() == 1 and not screen.visible)
	screen.queue_free()
	main.queue_free()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _flag(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_failures += 1
		print("FAIL %s" % label)
