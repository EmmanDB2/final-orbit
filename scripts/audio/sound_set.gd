# sound_set.gd: which sound plays for each thing that happens, and how loud each kind is. Any slot left
# empty uses the sound the game makes itself (SoundSynth), so recordings can be dropped in one at a
# time. From DESIGN.md, "Sound" (sounds are data).
class_name SoundSet
extends Resource

@export_group("Cockpit")
@export var click: AudioStream
@export var tick: AudioStream
@export var clunk: AudioStream
@export var cover: AudioStream
@export_group("Radio")
@export var blip: AudioStream
@export var warning: AudioStream
@export var alarm: AudioStream
@export var chime: AudioStream
@export var radio_static: AudioStream
@export_group("Ship")
@export var thud: AudioStream
@export var rumble: AudioStream
@export var hiss: AudioStream
@export var servo: AudioStream
@export_group("Crashes")
@export var knock: AudioStream
@export var crunch: AudioStream
@export var groan: AudioStream
@export var crack: AudioStream
@export var debris: AudioStream
@export var impact: AudioStream
@export_group("Air")
@export var wind: AudioStream
@export var roar: AudioStream

@export_group("Volumes")
## Each channel's loudness, in decibels.
@export var effects_db: float = -2.0
@export var ui_db: float = -10.0
@export var radio_db: float = -8.0
@export var music_db: float = -12.0


## A slot's sound, or the made one when it's empty.
func stream(slot: String) -> AudioStream:
	var chosen: AudioStream = get(slot)
	if chosen != null:
		return chosen
	match slot:
		"click": return SoundSynth.click()
		"tick": return SoundSynth.tick()
		"clunk": return SoundSynth.clunk()
		"cover": return SoundSynth.cover()
		"blip": return SoundSynth.blip()
		"warning": return SoundSynth.warning()
		"alarm": return SoundSynth.alarm()
		"chime": return SoundSynth.chime()
		"radio_static": return SoundSynth.radio_static()
		"thud": return SoundSynth.thud()
		"knock": return SoundSynth.knock()
		"crunch": return SoundSynth.crunch()
		"groan": return SoundSynth.groan()
		"crack": return SoundSynth.crack()
		"debris": return SoundSynth.debris()
		"impact": return SoundSynth.impact()
		"rumble": return SoundSynth.rumble()
		"hiss": return SoundSynth.hiss()
		"servo": return SoundSynth.servo()
		"wind": return SoundSynth.wind()
		"roar": return SoundSynth.roar()
	return null
