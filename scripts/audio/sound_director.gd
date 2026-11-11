# sound_director.gd: plays the game's sounds by listening to what happens, so nothing else has to know
# sound exists. It sets up the channels (Effects for the ship and the world, UI for the cockpit's
# switches, Radio for the comms line, Music), keeps a few players for one-off sounds, and plays the
# sound set's sounds for each event. From DESIGN.md, "Sound".
class_name SoundDirector
extends Node

## The channels, each with its volume from the sound set. Effects runs through a filter so the ship
## sounds as it would through the hull.
const CHANNELS: Array[String] = ["Effects", "UI", "Radio", "Music"]
const PLAYERS_PER_CHANNEL: int = 6

@export var sounds: SoundSet = preload("res://data/sound_set.tres")

var _streams: Dictionary = {}
var _players: Dictionary = {}
var _next_player: Dictionary = {}


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


## Listens to the HUD and the comms line.
func start(hud: FlightHud, comms: CommsLine) -> void:
	hud.widget_touched.connect(_on_widget_touched)
	comms.message_shown.connect(_on_message_shown)


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


# A finger on a control: a switch click, a cover flipping up, or the engine switch's clunk.
func _on_widget_touched(widget: UiWidget) -> void:
	if widget is EngineButton:
		play("clunk" if widget.cover_open else "cover", "UI")
	elif widget is ThrottleLever:
		play("tick", "UI")
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
