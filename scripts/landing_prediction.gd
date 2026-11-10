# landing_prediction.gd: works out how the ship comes down, on another thread, so the flight never
# waits for it. One forecast runs at a time: start one, then ask each tick whether it's done.
# From DESIGN.md, "Physics" (Landing prediction: flown ahead step by step, off the main thread).
#
# The flying itself is GravityModel.predict_descent, in the physics core. It's handed its own copies
# of the ship's state and outline, so nothing it reads changes under it.
class_name LandingPrediction
extends RefCounted

## One forecast being worked out. It holds the answer itself, so the thread never writes to
## anything that might be gone by the time it finishes, such as a ship after a restart.
class Job:
	extends RefCounted
	var answer: Dictionary = {}

	func run(gravity_model: GravityModel, state: ShipState, aero: AeroBody, flight: Dictionary, horizon: float, samples: int) -> void:
		answer = gravity_model.predict_descent(state, aero, flight, horizon, samples)


var _job: Job
var _task: int = -1


## Whether a forecast is still being worked out, or is done and waiting to be taken.
func is_busy() -> bool:
	return _task >= 0


## Starts a forecast. The state and outline must be copies nothing else will touch.
func start(gravity_model: GravityModel, state: ShipState, aero: AeroBody, flight: Dictionary, horizon: float, samples: int) -> void:
	if is_busy():
		return
	_job = Job.new()
	_task = WorkerThreadPool.add_task(_job.run.bind(gravity_model, state, aero, flight, horizon, samples), false, "Landing prediction")


## The forecast, if it's finished, or nothing if it's still going or there isn't one. Never waits.
func take() -> Dictionary:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return {}
	# It's done, so this returns at once. It only tidies the task away.
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var answer: Dictionary = _job.answer
	_job = null
	return answer


## Lets a forecast in progress finish and drops it, for when the flight's over.
func finish() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_job = null
