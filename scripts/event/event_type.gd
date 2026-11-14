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
