# flight_event.gd: one mid-flight event that's come up: what kind it is, where it is, and how far
# along finishing it is. The event director makes these, moves them, and saves them. From DESIGN.md,
# "Mid-flight events".
class_name FlightEvent
extends RefCounted

## For signals and comets, before the data's in: being found and scanned.
const FOUND: int = 0
## The scan's whole and the data's stored aboard, waiting for a relay in sight.
const STORED: int = 1
## Charted, rescued, or otherwise finished. A charted signal stays on the map.
const DONE: int = 2

var id: int = 0
var type: EventType
var step: int = FOUND
## How much of the scan's done, from 0 to 1, and whether it's been started.
var scan_share: float = 0.0
var scanning: bool = false
## What it turns out to be, such as a radio echo, known once it's done.
var thing: String = ""
## Its name on the map once it's charted, such as A-01.
var name: String = ""
## Signals: where on a world's ground it is, as a "world" and a "column".
var place: Dictionary = {}
## Distress beacons and comets: where it is and how it's moving, on the gravity model like the ship.
var state: ShipState
## When it was picked up, on the flight's clock.
var found_at: float = 0.0
## Distress: "adrift", "held" by the pilot, or "aboard" the ship.
var rescue: String = "adrift"
## Comets: when their closest pass is, on the flight's clock.
var closest_at: float = 0.0


## How the camera, markers, and cards know it.
func thing_dict() -> Dictionary:
	return {"kind": "event", "index": id}


func is_open() -> bool:
	return step != DONE


## Everything a save needs.
func save_state() -> Dictionary:
	var saved: Dictionary = {
		"id": id,
		"type": type.resource_path,
		"step": step,
		"scan_share": scan_share,
		"scanning": scanning,
		"thing": thing,
		"name": name,
		"place": place.duplicate(true),
		"found_at": found_at,
		"rescue": rescue,
		"closest_at": closest_at,
	}
	if state != null:
		saved["state"] = [state.x, state.y, state.velocity_x, state.velocity_y, state.time]
	return saved


## An event back from a save, or null if its type's gone.
static func from_saved(saved: Dictionary) -> FlightEvent:
	if not ResourceLoader.exists(saved.get("type", "")):
		return null
	var event := FlightEvent.new()
	event.id = saved["id"]
	event.type = load(saved["type"])
	event.step = saved["step"]
	event.scan_share = saved["scan_share"]
	event.scanning = saved["scanning"]
	event.thing = saved["thing"]
	event.name = saved["name"]
	event.place = saved["place"]
	event.found_at = saved["found_at"]
	event.rescue = saved.get("rescue", "adrift")
	event.closest_at = saved.get("closest_at", 0.0)
	if saved.has("state"):
		var numbers: Array = saved["state"]
		event.state = ShipState.new()
		event.state.x = numbers[0]
		event.state.y = numbers[1]
		event.state.velocity_x = numbers[2]
		event.state.velocity_y = numbers[3]
		event.state.time = numbers[4]
	return event
