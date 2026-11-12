# music_player.gd: plays a list of ambient tracks on the Music channel, in a shuffled order that never
# repeats a track back to back, fading each one up and away, with a stretch of quiet between them so the
# music comes and goes. It keeps real time, so time warp doesn't hurry it. With no tracks, it's silent.
# From DESIGN.md, "Sound" (music is ambient, in Zen Mode).
class_name MusicPlayer
extends Node

const SILENT_DB: float = -60.0

var _set: MusicSet
var _tracks: Array[AudioStream] = []
var _bag: Array[AudioStream] = []
var _last: AudioStream
var _player := AudioStreamPlayer.new()
var _wait: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Music carries on while the flight's paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "Music"
	_player.volume_db = SILENT_DB
	add_child(_player)
	_rng.randomize()


## Starts working through a set's tracks, after a short wait.
func play(music: MusicSet, tracks: Array[AudioStream]) -> void:
	_set = music
	_tracks = tracks
	_bag.clear()
	_wait = music.first_wait


func stop() -> void:
	_tracks = []
	_player.stop()


func _process(delta: float) -> void:
	if _tracks.is_empty() or _set == null:
		return
	var real: float = TimeWarp.real(delta)
	if _player.playing:
		var position: float = _player.get_playback_position()
		var left: float = _player.stream.get_length() - position
		var share: float = clampf(minf(position, left) / maxf(_set.fade_seconds, 0.01), 0.0, 1.0)
		_player.volume_db = linear_to_db(maxf(share, 0.001))
		return
	_wait -= real
	if _wait <= 0.0:
		_player.stream = _next()
		_player.volume_db = SILENT_DB
		_player.play()
		_wait = _rng.randf_range(_set.quiet_between.x, _set.quiet_between.y)


# The next track: drawn from a shuffled bag, refilled when it's empty, never the last one again.
func _next() -> AudioStream:
	if _bag.is_empty():
		_bag = _tracks.duplicate()
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last:
			_bag.reverse()
	_last = _bag.pop_back()
	return _last
