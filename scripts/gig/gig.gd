# gig.gd: one gig, offered on a board or taken: where it's from and to, what it pays, what it needs,
# and how far along it is. The agency makes and runs these. From DESIGN.md, "Core loop" (gigs).
class_name Gig
extends RefCounted

var id: int = 0
var type: GigType
## On the board, and on the tracker.
var title: String = ""
var thing: String = ""
var description: String = ""
## Places, as dictionaries the agency understands: {"kind": "station"}, {"kind": "site", "index": i}.
var origin: Dictionary = {}
var destination: Dictionary = {}
var payout: int = 0
var cargo_kg: float = 0.0
## The delta-v the route takes, roughly, in meters per second.
var route_delta_v: float = 0.0
## "offered", "active", "done", or "failed".
var state: String = "offered"
## The steps, each as its text, in order; the step being worked on is step.
var objectives: PackedStringArray = PackedStringArray()
var step: int = 0
## Surveys: how far the scan's got, from 0 to 1, and whether it's running.
var scan_share: float = 0.0
var scanning: bool = false
