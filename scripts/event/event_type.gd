# event_type.gd: one kind of mid-flight event, as data: what it's called, how often it comes up,
# where it turns up, what finishing it takes, and what it pays. The event director rolls events from
# these, so a new kind of event is a new data file plus what it asks of the pilot. From DESIGN.md,
# "Mid-flight events" and "Tech" (content is data).
class_name EventType
extends Resource

## What it is: "signal" is a source on a world's ground to scan; "distress" is an astronaut adrift
## to bring home; "comet" passes through, to be scanned from inside its coma.
@export var kind: String = "signal"
## What it's called before it's known, on its card and the events list, such as UNCHARTED SIGNAL.
@export var label: String = "UNCHARTED SIGNAL"
## The card's chip.
@export var chip: String = "SIGNAL"
## What the comms line says when it's picked up, before where and how far.
@export var call: String = "UNCHARTED SIGNAL"
## What it can turn out to be, one picked per event and only known once it's done, such as a radio
## echo.
@export var things: PackedStringArray = PackedStringArray()
## How often it comes up, against the other types.
@export var weight: float = 1.0
## Whether it's calm enough for Zen Mode.
@export var calm: bool = true
## The nearest to the ship it can turn up, in world units, so there's time to change course.
@export var nearest: float = 140000.0
## How close the ship has to be to scan it, in world units, and how long the scan takes there, in
## seconds.
@export var scan_reach: float = 6000.0
@export var scan_seconds: float = 12.0
## What finishing it pays, and the bonus for being the first to chart it, in credits.
@export var pay: int = 2500
@export var first_bonus: int = 1500
## Distress: the astronaut's mass with their suit, in kilograms, and their orbit's height over the
## ground, lowest and highest, in world units.
@export var mass_kg: float = 120.0
@export var lowest_orbit: float = 22000.0
@export var highest_orbit: float = 60000.0
## Comets: how long before their closest pass they're picked up, in seconds, the closest pass's
## height over the ground, lowest and highest, and how fast they come in from far away, in world
## units per second.
@export var lead_seconds: float = 900.0
@export var lowest_pass: float = 40000.0
@export var highest_pass: float = 160000.0
@export var approach_speed: float = 900.0
## Comets: how big the nucleus is and how long the tail, in world units, and their colors. They're
## nature's, not the agency's, so they're kept clear of telemetry cyan and agency orange.
@export var nucleus_radius: float = 400.0
@export var tail_length: float = 90000.0
@export var nucleus_color: Color = Color("B8C2C9")
@export var dust_color: Color = Color("5E5954")
@export var glow_color: Color = Color("D6ECF4")
## Comets: the ion tail's color, the dust tail's color, how long the dust tail is along its path, in
## world units, and how far its end is pushed away from the star, as a share of that length. Each
## tail's widest, at its end, as a share of its length (the ion tail is a third as wide), and the most
## jets a nucleus can have. Nature's colors: never telemetry cyan or agency orange.
@export var ion_color: Color = Color("9DB8F2")
@export var dust_tail_color: Color = Color("E6D8B8")
@export var dust_length: float = 60000.0
@export var dust_lift: float = 0.35
@export var tail_width: float = 0.16
@export var jets: int = 3
