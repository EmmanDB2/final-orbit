# game_settings.gd: the player's settings, kept in their own file apart from any world's save, so they
# hold for normal play and Zen Mode alike: how loud each sound channel is, haptics, the helmet lamp,
# and whether the controls hide when idle. A test run never reads or writes the player's file. From
# DESIGN.md, "Settings".
class_name GameSettings
extends RefCounted

## Where they're kept. A test points this somewhere of its own.
static var path: String = "user://settings.cfg"
## Each setting and what it is before it's changed.
const DEFAULTS: Dictionary = {
	"effects": 1.0,
	"ui": 1.0,
	"radio": 1.0,
	"music": 1.0,
	"haptics": true,
	"helmet_lamp": "AUTO",
	"auto_hide": false,
}
## The helmet lamp's choices, in the order a tap goes through them.
const LAMP_CHOICES: Array[String] = ["AUTO", "ON", "OFF"]

static var _values: Dictionary = {}
static var _loaded: bool = false


## A setting, read from the file the first time.
static func value(key: String) -> Variant:
	_load()
	return _values.get(key, DEFAULTS.get(key))


## Changes a setting and keeps it.
static func set_value(key: String, new_value: Variant) -> void:
	_load()
	_values[key] = new_value
	if SaveGame.enabled():
		var file := ConfigFile.new()
		for each: String in _values:
			file.set_value("settings", each, _values[each])
		file.save(path)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_values = DEFAULTS.duplicate()
	if not SaveGame.enabled():
		return
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for each: String in DEFAULTS:
		_values[each] = file.get_value("settings", each, DEFAULTS[each])
