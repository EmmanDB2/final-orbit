# gig_type.gd: one kind of gig, as data: what it's called on a board, what it asks for, and what it
# pays. Boards are filled from these, so a new kind of gig is a new data file. From DESIGN.md, "Core
# loop" (gigs and payment rules) and "Tech" (gig types are data).
class_name GigType
extends Resource

## What it is: "cargo" carries something from one place to another; "survey" lands at a spot,
## scans it, and sends the data home.
@export var kind: String = "cargo"
## Before the colon in a gig's title, such as CARGO, and the line under it on the board.
@export var label: String = "CARGO"
@export var category: String = "CARGO & DELIVERY"
## What gets carried or surveyed, one picked per gig.
@export var things: PackedStringArray = PackedStringArray()
## How often it turns up on a board, against the other types.
@export var weight: float = 1.0
## Pay: a flat part, more for the route's delta-v in meters per second, and more per tonne carried,
## rounded to a hundred credits.
@export var base_pay: int = 2000
@export var pay_per_delta_v: float = 12.0
@export var pay_per_tonne: float = 1500.0
## Cargo, in kilograms: the lightest and heaviest a gig asks for, in steps of this much.
@export var lightest: float = 100.0
@export var heaviest: float = 500.0
@export var mass_step: float = 50.0
