# sound_director.gd: plays the game's sounds by listening to what happens, so nothing else has to know
# sound exists. It sets up the channels (Effects for the ship and the world, UI for the cockpit's
# switches, Radio for the comms line, Music), keeps a few players for one-off sounds and one for each
# loop, and plays the sound set's sounds for each event. Aboard, the ship's sounds come through the
# hull, so the Effects channel runs through a low filter that opens as the air thickens; out in vacuum
# they stop, and the pilot hears their suit: breathing, and the jetpack. In air there's wind, a roar on
# re-entry, and the ship's engine across the air. It buzzes the phone too. From DESIGN.md, "Sound".
class_name SoundDirector
extends Node

## The channels, each with its volume from the sound set. Effects runs through a filter so the ship
## sounds as it would through the hull.
const CHANNELS: Array[String] = ["Effects", "UI", "Radio", "Music"]
const PLAYERS_PER_CHANNEL: int = 6
## How high the Effects filter lets sound through, in hertz: through the hull, through the suit's
## microphone, and in thick air, with everything between following the air's density.
const HULL_CUTOFF: float = 650.0
const SUIT_CUTOFF: float = 3500.0
const OPEN_CUTOFF: float = 9000.0
## How fast through the air reads as a full gale, in world units a second, at the ground's density.
const GALE_SPEED: float = 400.0
## How far the ship's engine carries across the air to a pilot outside, in world units.
const ENGINE_CARRY: float = 2000.0
## How quickly a loop's loudness follows what it's following, per second.
const LOOP_FOLLOW: float = 10.0
## Loudness that counts as silent, in decibels.
const SILENT_DB: float = -60.0
## The loops, each on the Effects channel.
const LOOPS: Array[String] = ["rumble", "hiss", "servo", "wind", "roar", "breath"]

## Whether the phone buzzes.
@export var haptics: bool = true

@export var sounds: SoundSet = preload("res://data/sound_set.tres")

var _streams: Dictionary = {}
var _players: Dictionary = {}
var _next_player: Dictionary = {}
var _loops: Dictionary = {}
# How loud each loop is meant to be now, from 0 to 1, and how loud it is.
var _loop_wanted: Dictionary = {}
var _loop_level: Dictionary = {}
var _hull_filter: AudioEffectLowPassFilter
var _ship: Node2D
var _pilot: Pilot
var _engine_share: float = 0.0
var _legs_moving: bool = false
var _buzz_wait: float = 0.0


func _ready() -> void:
	# The cockpit's switches still click while the flight's paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_channels()
	for channel: String in CHANNELS:
		var pool: Array[AudioStreamPlayer] = []
		for i in range(PLAYERS_PER_CHANNEL):
			var player := AudioStreamPlayer.new()
			player.bus = channel
			add_child(player)
			pool.append(player)
		_players[channel] = pool
		_next_player[channel] = 0
	for slot: String in LOOPS:
		var loop := AudioStreamPlayer.new()
		loop.bus = "Effects"
		loop.volume_db = SILENT_DB
		add_child(loop)
		_loops[slot] = loop
		_loop_wanted[slot] = 0.0
		_loop_level[slot] = 0.0


## Listens to the HUD, the comms line, the ship, and the pilot.
func start(hud: FlightHud, comms: CommsLine, ship: Node2D, pilot: Pilot) -> void:
	_ship = ship
	_pilot = pilot
	hud.widget_touched.connect(_on_widget_touched)
	hud._lever.throttle_changed.connect(func(_value: float) -> void: play("tick", "UI"))
	comms.message_shown.connect(_on_message_shown)
	ship.engine_changed.connect(func(share: float) -> void: _engine_share = share)
	ship.legs_changed.connect(func(_down: bool, moving: bool) -> void: _legs_moving = moving)
	ship.touched_down.connect(_on_touched_down)
	ship.docked_changed.connect(func(_docked: bool) -> void: _hull_sound("clunk", 0.0, 60, 0.4))
	ship.part_detached.connect(func(_piece: Dictionary, _x: float, _y: float, _vx: float, _vy: float, _angle: float, _spin: float, _kick: Vector2) -> void: _hull_sound("crunch", 0.0, 140, 0.9))
	ship.warning_raised.connect(_on_ship_warning)
	ship.ship_lost.connect(func() -> void: _hull_sound("crunch", 4.0, 300, 1.0))


## Plays one of the sound set's sounds once, on a channel.
func play(slot: String, channel: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var pool: Array = _players[channel]
	var player: AudioStreamPlayer = pool[_next_player[channel]]
	_next_player[channel] = (_next_player[channel] + 1) % pool.size()
	player.stream = _stream(slot)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _stream(slot: String) -> AudioStream:
	if not _streams.has(slot):
		_streams[slot] = sounds.stream(slot)
	return _streams[slot]


func _process(delta: float) -> void:
	if _ship == null:
		return
	var real: float = TimeWarp.real(delta)
	var aboard: bool = _pilot.mode == Pilot.ABOARD
	var gravity_model: GravityModel = _ship._gravity_model
	var where: ShipState = _ship.state if aboard else _pilot.state
	var air: float = clampf(gravity_model.get_air_density(where.x, where.y, where.time), 0.0, 1.0)
	# Through the hull or the suit's microphone, opening up as the air thickens.
	var cutoff: float = lerpf(HULL_CUTOFF if aboard else SUIT_CUTOFF, OPEN_CUTOFF, sqrt(air))
	_hull_filter.cutoff_hz = lerpf(_hull_filter.cutoff_hz, cutoff, 1.0 - exp(-4.0 * real))
	# The ship's own sounds: all of them aboard, and outside only across air, fading with distance.
	var heard: float = 1.0
	if not aboard:
		var away: float = Vector2(_ship.state.x - where.x, _ship.state.y - where.y).length()
		heard = air * clampf(1.0 - away / ENGINE_CARRY, 0.0, 1.0)
	var outside: bool = _pilot.mode == Pilot.EVA or _pilot.mode == Pilot.SURFACE
	var jetpack: float = 0.6 if outside and (_pilot._firing.length() > 0.01 or _pilot._jetting or absf(_pilot._turning) > 0.01) else 0.0
	_loop_wanted["rumble"] = _engine_share * heard
	_loop_wanted["hiss"] = maxf(_ship.rcs_activity() * 0.7 * heard, jetpack)
	_loop_wanted["servo"] = 0.6 * heard if _legs_moving else 0.0
	# Wind from moving through the air, and a light breeze standing in it; a roar from re-entry heat.
	var ground: PackedFloat64Array = gravity_model.get_surface_velocity(where.x, where.y, where.time)
	var through: float = Vector2(where.velocity_x - ground[0], where.velocity_y - ground[1]).length()
	var breeze: float = 0.12 * air if outside else 0.0
	_loop_wanted["wind"] = maxf(clampf(sqrt(air) * through / GALE_SPEED, 0.0, 1.0) * 0.8, breeze)
	_loop_wanted["roar"] = clampf(_ship.heat_share * 1.2, 0.0, 1.0) if aboard else 0.0
	# Breathing in the suit while the pilot's outside.
	_loop_wanted["breath"] = 0.35 if outside else 0.0
	for slot: String in LOOPS:
		var level: float = move_toward(_loop_level[slot], _loop_wanted[slot], LOOP_FOLLOW * real)
		_loop_level[slot] = level
		var loop: AudioStreamPlayer = _loops[slot]
		if level > 0.001:
			if not loop.playing:
				loop.stream = _stream(slot)
				loop.play()
			loop.volume_db = linear_to_db(level)
		elif loop.playing:
			loop.stop()
	# The engine deepens and swells with the throttle.
	_loops["rumble"].pitch_scale = 0.8 + 0.35 * _engine_share
	# A faint purr in the hand while the engine burns.
	if haptics and aboard and _engine_share > 0.0:
		_buzz_wait -= real
		if _buzz_wait <= 0.0:
			_buzz_wait = 0.12
			_buzz(60, 0.06 + 0.12 * _engine_share)


# A one-off sound from the ship, and a buzz to go with it, if the pilot's aboard to hear it.
func _hull_sound(slot: String, volume_db: float, buzz_ms: int, buzz_strength: float) -> void:
	if _pilot != null and _pilot.mode != Pilot.ABOARD:
		return
	play(slot, "Effects", volume_db)
	_buzz(buzz_ms, buzz_strength)


func _on_touched_down(speed: float, upright: bool, safe_speed: float) -> void:
	var share: float = clampf(speed / maxf(safe_speed, 1.0), 0.0, 2.0)
	_hull_sound("thud", linear_to_db(clampf(0.35 + share * 0.5, 0.2, 1.0)), roundi(30 + 60 * minf(share, 1.0)), clampf(0.3 + share * 0.4, 0.2, 1.0))
	if speed > safe_speed or not upright:
		_hull_sound("crunch", 0.0, 200, 1.0)


func _on_ship_warning(text: String) -> void:
	if text.ends_with("COLLISION"):
		_hull_sound("crunch", -4.0, 120, 0.8)


func _buzz(milliseconds: int, strength: float) -> void:
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds, clampf(strength, 0.0, 1.0))


func _make_channels() -> void:
	var volumes: Dictionary = {"Effects": sounds.effects_db, "UI": sounds.ui_db, "Radio": sounds.radio_db, "Music": sounds.music_db}
	for channel: String in CHANNELS:
		var index: int = AudioServer.get_bus_index(channel)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, channel)
			AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, volumes[channel])
	# The ship sounds through its hull: muffled, low.
	var effects: int = AudioServer.get_bus_index("Effects")
	if AudioServer.get_bus_effect_count(effects) == 0:
		_hull_filter = AudioEffectLowPassFilter.new()
		_hull_filter.cutoff_hz = HULL_CUTOFF
		AudioServer.add_bus_effect(effects, _hull_filter)
	else:
		_hull_filter = AudioServer.get_bus_effect(effects, 0)


# A finger on a control: a switch click, a cover flipping up, or the engine switch's clunk.
func _on_widget_touched(widget: UiWidget) -> void:
	if widget is EngineButton:
		play("clunk" if widget.cover_open else "cover", "UI")
	elif widget is ThrottleLever:
		pass
	elif widget is GigBoard or widget is HeadingDial:
		play("click", "UI", -4.0)
	else:
		play("click", "UI")


# The comms line: good news with money in it chimes, trouble in red sounds the alarm, cautions in amber
# get two tones, and everything else is a radio blip.
func _on_message_shown(text: String, color: Color) -> void:
	var palette: AgencyPalette = UiStyle.palette()
	if color == palette.agency_red:
		play("alarm", "Radio")
	elif color == palette.telemetry_amber:
		play("warning", "Radio")
	elif text.contains(" CR"):
		play("chime", "Radio")
	else:
		play("blip", "Radio")
