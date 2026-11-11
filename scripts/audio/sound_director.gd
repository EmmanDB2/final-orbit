# sound_director.gd: plays the game's sounds by listening to what happens, so nothing else has to know
# sound exists. It sets up the channels (Effects for the ship and the world, UI for the cockpit's
# switches, Radio for the comms line, Music), keeps a few players for one-off sounds and one for each
# loop, and plays the sound set's sounds for each event. Aboard, the ship's sounds come through the
# hull, so the Effects channel runs through a low filter that opens as the air thickens; out in vacuum
# they stop, and the pilot hears their suit: the jetpack. In air there's wind, a roar on re-entry, and
# the ship across the air. Crashes build with how bad they are: a knock for a bump, a thud and the frame
# groaning for damage, a crack for each part lost with debris rattling after, and for a lost ship one
# huge impact, then silence but for radio static. It buzzes the phone too. From DESIGN.md, "Sound".
class_name SoundDirector
extends Node

## The channels, each with its volume from the sound set. Effects runs through a filter so the ship
## sounds as it would through the hull.
const CHANNELS: Array[String] = ["Effects", "UI", "Radio", "Music"]
const PLAYERS_PER_CHANNEL: int = 8
## How high the Effects filter lets sound through, in hertz: through the hull, through the suit's
## microphone, and in thick air, with everything between following the air's density.
const HULL_CUTOFF: float = 650.0
const SUIT_CUTOFF: float = 3500.0
const OPEN_CUTOFF: float = 9000.0
## How fast through the air reads as a full gale, in world units a second, at the ground's density.
const GALE_SPEED: float = 400.0
## How loud the wind is in a full gale, and standing in still air at the ground, from 0 to 1. Turned
## down on 2026-11-11, when Manny found it too loud.
const GALE_LEVEL: float = 0.45
const BREEZE_LEVEL: float = 0.05
## How far the ship's engine carries across the air to a pilot outside, in world units.
const ENGINE_CARRY: float = 2000.0
## How quickly a loop's loudness follows what it's following, per second.
const LOOP_FOLLOW: float = 10.0
## Loudness that counts as silent, in decibels.
const SILENT_DB: float = -60.0
## How loud the RCS hiss is at full thrust, from 0 to 1. Manny halved it on 2026-11-10.
const RCS_LEVEL: float = 0.35
## The least time between two parts' cracks, in seconds, so a ship coming apart doesn't drown itself.
const CRACK_GAP: float = 0.07
## The loops, each on the Effects channel.
const LOOPS: Array[String] = ["rumble", "hiss", "servo", "wind", "roar"]

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
# How much of the ship the pilot can hear right now: all of it aboard, and outside only across air.
var _heard: float = 1.0
# Real seconds since start, and what's waiting to happen at a later one: [when, Callable].
var _clock: float = 0.0
var _later: Array = []
var _last_crack: float = -1.0
var _last_debris: float = -1.0
## Every sound slot, made ahead on another thread at start so none is made mid-flight.
const SLOTS: Array[String] = ["click", "tick", "clunk", "cover", "blip", "warning", "alarm", "chime", "radio_static", "thud", "rumble", "hiss", "servo", "knock", "crunch", "groan", "crack", "debris", "impact", "wind", "roar"]
var _made: Dictionary = {}
var _making: int = -1
var _making_lock := Mutex.new()


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
	_making = WorkerThreadPool.add_task(_make_all, false, "Make sounds")


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
	ship.part_detached.connect(func(piece: Dictionary, _x: float, _y: float, _vx: float, _vy: float, _angle: float, _spin: float, _kick: Vector2) -> void: _on_part_detached(piece))
	ship.hull_struck.connect(_on_hull_struck)
	ship.ship_lost.connect(_on_ship_lost)


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
		_making_lock.lock()
		var ready: AudioStream = _made.get(slot)
		_making_lock.unlock()
		_streams[slot] = ready if ready != null else sounds.stream(slot)
	return _streams[slot]


# On another thread: every sound made once, so the first engine burn doesn't wait for its rumble.
func _make_all() -> void:
	for slot: String in SLOTS:
		var made: AudioStream = sounds.stream(slot)
		_making_lock.lock()
		_made[slot] = made
		_making_lock.unlock()


func _exit_tree() -> void:
	if _making >= 0:
		WorkerThreadPool.wait_for_task_completion(_making)


func _process(delta: float) -> void:
	var real: float = TimeWarp.real(delta)
	_clock += real
	_run_later()
	if _ship == null:
		return
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
	_heard = heard
	var outside: bool = _pilot.mode == Pilot.EVA or _pilot.mode == Pilot.SURFACE
	var jetpack: float = 0.6 if outside and (_pilot._firing.length() > 0.01 or _pilot._jetting or absf(_pilot._turning) > 0.01) else 0.0
	_loop_wanted["rumble"] = _engine_share * heard
	_loop_wanted["hiss"] = maxf(_ship.rcs_activity() * RCS_LEVEL * heard, jetpack)
	_loop_wanted["servo"] = 0.6 * heard if _legs_moving else 0.0
	# Wind from moving through the air, and a light breeze standing in it; a roar from re-entry heat.
	var ground: PackedFloat64Array = gravity_model.get_surface_velocity(where.x, where.y, where.time)
	var through: float = Vector2(where.velocity_x - ground[0], where.velocity_y - ground[1]).length()
	var breeze: float = BREEZE_LEVEL * air if outside else 0.0
	_loop_wanted["wind"] = maxf(clampf(sqrt(air) * through / GALE_SPEED, 0.0, 1.0) * GALE_LEVEL, breeze)
	_loop_wanted["roar"] = clampf(_ship.heat_share * 1.2, 0.0, 1.0) if aboard else 0.0
	# A lost ship goes silent at once, all but the radio.
	var lost: bool = _ship._lost and aboard
	for slot: String in LOOPS:
		if lost:
			_loop_wanted[slot] = 0.0
			_loop_level[slot] = 0.0
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
	if haptics and aboard and _engine_share > 0.0 and not lost:
		_buzz_wait -= real
		if _buzz_wait <= 0.0:
			_buzz_wait = 0.12
			_buzz(60, 0.06 + 0.12 * _engine_share)


# A one-off sound from the ship, as loud as the pilot can hear it from where they are, and a buzz to
# go with it if they're aboard. A lost ship makes no more sounds.
func _hull_sound(slot: String, volume_db: float, buzz_ms: int, buzz_strength: float, pitch: float = 1.0) -> void:
	if _ship != null and _ship._lost:
		return
	var aboard: bool = _pilot == null or _pilot.mode == Pilot.ABOARD
	var heard: float = 1.0 if aboard else _heard
	if heard < 0.02:
		return
	play(slot, "Effects", volume_db + linear_to_db(heard), pitch)
	# A new buzz cuts off the one before, so a sound with none leaves the last alone.
	if aboard and buzz_ms > 0:
		_buzz(buzz_ms, buzz_strength)


func _on_touched_down(speed: float, upright: bool, safe_speed: float) -> void:
	var share: float = clampf(speed / maxf(safe_speed, 1.0), 0.0, 2.0)
	_hull_sound("thud", linear_to_db(clampf(0.35 + share * 0.5, 0.2, 1.0)), roundi(30 + 60 * minf(share, 1.0)), clampf(0.3 + share * 0.4, 0.2, 1.0))
	# Coming down leaning, it knocks as it goes over. Damage is heard from the hit itself.
	if not upright:
		_after(0.25, func() -> void: _hull_sound("knock", -2.0, 60, 0.6, 0.8))


# A hit, by how bad it is. A bump knocks, louder the harder it is. Damage thuds and grinds, and the
# frame groans after, with a heavy jolt in the hand.
func _on_hull_struck(strength: float, damage: int) -> void:
	if damage <= 0:
		var share: float = clampf(strength, 0.0, 1.0)
		_hull_sound("knock", lerpf(-18.0, -2.0, share), roundi(20 + 40 * share), 0.2 + 0.5 * share, randf_range(0.9, 1.1))
		return
	var size: float = clampf(damage / 200.0, 0.3, 1.0)
	_hull_sound("thud", 0.0, 150, 1.0, 0.8)
	_hull_sound("crunch", linear_to_db(size), 0, 0.0)
	_after(0.25, func() -> void: _hull_sound("groan", linear_to_db(0.6 + 0.4 * size), 0, 0.0, randf_range(0.9, 1.05)))


# A part breaking off cracks, deeper for a bigger part, and sets debris rattling against the hull.
func _on_part_detached(piece: Dictionary) -> void:
	if _clock - _last_crack < CRACK_GAP:
		return
	_last_crack = _clock
	var size: float = clampf(log(maxf(piece["pixel_count"], 30) / 30.0) / log(50.0), 0.0, 1.0)
	_hull_sound("crack", lerpf(-4.0, 0.0, size), 90, 1.0, lerpf(1.3, 0.7, size))
	if _clock - _last_debris > 0.6:
		_last_debris = _clock
		_after(0.15, func() -> void: _hull_sound("debris", -3.0, 0, 0.0))
		# The debris in the hand: a stutter of small taps.
		for i in range(5):
			_after(0.18 + i * randf_range(0.06, 0.12), func() -> void: _hull_sound_buzz(25, 0.35))


# The ship lost: one huge impact and a long jolt, then only the radio, hissing static. The comms line
# sounds the alarm.
func _on_ship_lost() -> void:
	var aboard: bool = _pilot == null or _pilot.mode == Pilot.ABOARD
	var heard: float = 1.0 if aboard else _heard
	if heard >= 0.02:
		play("impact", "Effects", 2.0 + linear_to_db(heard))
	if aboard:
		_buzz(400, 1.0)
	_after(0.5, func() -> void: play("radio_static", "Radio", -2.0))


func _hull_sound_buzz(milliseconds: int, strength: float) -> void:
	if _pilot == null or _pilot.mode == Pilot.ABOARD:
		_buzz(milliseconds, strength)


# Does this a little later, in real seconds.
func _after(seconds: float, action: Callable) -> void:
	_later.append([_clock + seconds, action])


func _run_later() -> void:
	var i: int = 0
	while i < _later.size():
		if _later[i][0] <= _clock:
			var action: Callable = _later[i][1]
			_later.remove_at(i)
			action.call()
		else:
			i += 1


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


# A finger on a control: only ENGINE makes a sound, its cover flipping up and then its switch's clunk.
# The other buttons are silent, on Manny's call (2026-11-11).
func _on_widget_touched(widget: UiWidget) -> void:
	if widget is EngineButton:
		play("clunk" if widget.cover_open else "cover", "UI")


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
