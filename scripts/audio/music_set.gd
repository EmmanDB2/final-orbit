# music_set.gd: the game's music, as data: the ambient tracks Zen Mode plays, and how it spaces them out.
# Drop recordings into zen_tracks (mp3, ogg, or wav) and they're in. From DESIGN.md, "Sound" (music is
# ambient, in Zen Mode).
class_name MusicSet
extends Resource

## Zen Mode's tracks, played in a shuffled order, never the same one twice in a row.
@export var zen_tracks: Array[AudioStream] = []
## How long it's quiet between tracks, at least and at most, in seconds.
@export var quiet_between := Vector2(20.0, 60.0)
## How long the first track waits before it starts, in seconds.
@export var first_wait: float = 6.0
## How long each track takes to fade up and to fade away, in seconds.
@export var fade_seconds: float = 6.0
