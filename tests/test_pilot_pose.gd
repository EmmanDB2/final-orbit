# test_pilot_pose.gd: checks the 3D pilot's pose blending, the fall view and flail rules, and the
# death topple and settle: the numbers behind "nothing snaps".
# From DESIGN.md, "Player" (the 3D pilot) and "Death and the med bay".
# Run with: godot --headless --path . --script tests/test_pilot_pose.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_spring()
	_test_fall_view()
	_test_flail()
	_test_topple()
	_test_settle()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check_true(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
		print("FAIL %s" % label)


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL %s: got %s, wanted %s" % [label, actual, expected])


# Runs a spring from rest at 0 toward a target of 1 for this long, in steps of this size, and returns
# [the value at the end, the highest it got, the first time it was within 1%, the last time it
# was outside 1%].
func _run(omega: float, zeta: float, seconds: float, step: float) -> Array:
	var value: float = 0.0
	var speed: float = 0.0
	var top: float = 0.0
	var first_close: float = -1.0
	var last_far: float = 0.0
	var t: float = 0.0
	while t < seconds - 0.00001:
		var next: Vector2 = AstronautView.spring_step(value, speed, 1.0, omega, zeta, step)
		value = next.x
		speed = next.y
		t += step
		top = maxf(top, value)
		if absf(value - 1.0) <= 0.01 and first_close < 0.0:
			first_close = t
		if absf(value - 1.0) > 0.01:
			last_far = t
	return [value, top, first_close, last_far]


func _test_spring() -> void:
	# Critical damping at the default: close to the step fast, and never past it.
	var critical: Array = _run(30.0, 1.0, 0.5, 1.0 / 60.0)
	# (Critical damping at omega 30 is within 3% at 0.2 s and 1% at about 0.23 s: that's the maths.)
	_check_true("critical spring is within 3% of a step by 0.2 s", absf(_run(30.0, 1.0, 0.2, 1.0 / 60.0)[0] - 1.0) < 0.03)
	_check_true("critical spring is within 1% of a step by 0.25 s", absf(_run(30.0, 1.0, 0.25, 1.0 / 60.0)[0] - 1.0) < 0.01)
	_check_true("critical spring never overshoots", critical[1] <= 1.0001)
	_check_true("critical spring has settled", absf(critical[0] - 1.0) < 0.001)
	# A loose one swings past and still settles inside a second.
	var loose: Array = _run(16.0, 0.35, 1.0, 1.0 / 60.0)
	_check_true("a loose spring overshoots", loose[1] > 1.1)
	_check_true("a loose spring settles within 1 s", loose[3] < 1.0 and absf(loose[0] - 1.0) < 0.01)
	var floppy: Array = _run(30.0, 0.35, 1.0, 1.0 / 60.0)
	_check_true("a 0.35 spring at omega 30 overshoots", floppy[1] > 1.1)
	_check_true("a 0.35 spring at omega 30 settles within 1 s", absf(floppy[0] - 1.0) < 0.01)
	# A slow slump comes to rest without swinging.
	var slump: Array = _run(3.5, 1.0, 3.0, 1.0 / 60.0)
	_check_true("a slump doesn't overshoot", slump[1] <= 1.0001)
	# A long frame can't blow it up.
	for zeta: float in [1.0, 0.35, 0.5]:
		var long_frame: Array = _run(30.0, zeta, 2.0, 0.1)
		_check_true("stable at delta 0.1 (zeta %s)" % zeta, absf(long_frame[0] - 1.0) < 0.01 and long_frame[1] < 2.0)
	_check("no time means no change", AstronautView.spring_step(0.3, 2.0, 1.0, 30.0, 1.0, 0.0).x, 0.3, 0.0001)
	# Already at the target and still: stays there.
	_check("at rest stays at rest", AstronautView.spring_step(1.0, 0.0, 1.0, 30.0, 1.0, 0.016).x, 1.0, 0.0001)


# The fall view's rule: (world, low point, ground plus clearance, altitude, view height, open path,
# coming in).
func _test_fall_view() -> void:
	_check_true("the star never shows the fall view", not Pilot.falls_to_world(0, -5000.0, 100.0, 500.0, 40000.0, false, true))
	_check_true("a low point under the ground and under 2 km falls", Pilot.falls_to_world(1, -500.0, 130.0, 400.0, 40000.0, false, true))
	_check_true("in orbit it doesn't", not Pilot.falls_to_world(1, 9000.0, 130.0, 400.0, 40000.0, false, true))
	_check_true("above 2 km it doesn't", not Pilot.falls_to_world(1, -500.0, 130.0, 50000.0, 40000.0, false, true))
	_check_true("just under 2 km it does", Pilot.falls_to_world(1, -500.0, 130.0, 39999.0, 40000.0, false, true))
	_check_true("a low point at the ground's edge doesn't", not Pilot.falls_to_world(1, 130.0, 130.0, 400.0, 40000.0, false, true))
	_check_true("an open path coming in falls", Pilot.falls_to_world(1, -500.0, 130.0, 400.0, 40000.0, true, true))
	_check_true("an open path already past its low point doesn't", not Pilot.falls_to_world(1, -500.0, 130.0, 400.0, 40000.0, true, false))
	_check_true("a closed path going away from its low point still falls", Pilot.falls_to_world(1, -500.0, 130.0, 400.0, 40000.0, false, false))


func _test_flail() -> void:
	var data := PilotData.new()
	_check("no flail at rest", Pilot.flail_share(0.0, data.flail_from_speed, data.flail_full_speed), 0.0, 0.0001)
	_check("no flail at 60", Pilot.flail_share(60.0, data.flail_from_speed, data.flail_full_speed), 0.0, 0.0001)
	_check("half at 130", Pilot.flail_share(130.0, data.flail_from_speed, data.flail_full_speed), 0.5, 0.0001)
	_check("full at 200", Pilot.flail_share(200.0, data.flail_from_speed, data.flail_full_speed), 1.0, 0.0001)
	_check("full at 300", Pilot.flail_share(300.0, data.flail_from_speed, data.flail_full_speed), 1.0, 0.0001)
	_check("no flail going up", Pilot.flail_share(-50.0, data.flail_from_speed, data.flail_full_speed), 0.0, 0.0001)
	_check_true("the data's view height is 2 km", is_equal_approx(data.fall_view_height, 40000.0))


# Tips a body from upright for this long and says: [when it first reached flat, how many bounces,
# the tilt and spin at the end].
func _tip(g: float, seconds: float) -> Array:
	var tilt: float = PI / 2.0
	var spin: float = 0.0
	var first_flat: float = -1.0
	var bounces: int = 0
	var t: float = 0.0
	while t < seconds:
		var before: float = spin
		var next: Vector2 = AstronautView.topple_step(tilt, spin, g, 1.0 / 60.0)
		tilt = next.x
		spin = next.y
		t += 1.0 / 60.0
		if tilt <= 0.0 and first_flat < 0.0:
			first_flat = t
		if before >= 0.0 and spin < 0.0:
			bounces += 1
	return [first_flat, bounces, tilt, spin]


func _test_topple() -> void:
	var planet: Array = _tip(200.0, 6.0)
	var moon: Array = _tip(60.0, 8.0)
	_check_true("on the planet it reaches flat in under 1 s (got %s)" % planet[0], planet[0] > 0.0 and planet[0] < 1.0)
	_check_true("on the moon it takes longer than on the planet (got %s)" % moon[0], moon[0] > planet[0])
	_check_true("on the planet it bounces once (got %d)" % planet[1], planet[1] == 1)
	_check_true("on the moon it bounces once (got %d)" % moon[1], moon[1] == 1)
	_check("the planet's body comes to rest flat", planet[2], 0.0, 0.0001)
	_check("the planet's body comes to rest still", planet[3], 0.0, 0.0001)
	_check("the moon's body comes to rest flat", moon[2], 0.0, 0.0001)
	_check("the moon's body comes to rest still", moon[3], 0.0, 0.0001)
	# One already nearly down gets there too, and a standing body at no pull doesn't move.
	_check_true("a body nearly flat settles", _tip_from(0.1, 200.0) < 0.0001)
	_check("no pull, no tipping", AstronautView.topple_step(1.0, 0.0, 0.0, 0.1).x, 1.0, 0.0001)


func _tip_from(tilt: float, g: float) -> float:
	var spin: float = 0.0
	for i in range(600):
		var next: Vector2 = AstronautView.topple_step(tilt, spin, g, 1.0 / 60.0)
		tilt = next.x
		spin = next.y
	return tilt


# A dead body's middle settling while it tips, from either height it can start at, hit at any speed up
# to 400 units/s: it never rises, never steps more than the free fall from the impact speed would (or a
# pixel, where it's following the tipping body), and ends lying.
func _test_settle() -> void:
	for g: float in [200.0, 60.0]:
		for start: float in [AstronautView.STANDING_MIDDLE, 26.0]:
			for impact: float in [0.0, 100.0, 160.0, 250.0, 400.0]:
				var tilt: float = PI / 2.0
				var spin: float = 0.0
				var middle: float = start
				var falling: float = start
				var fall_speed: float = impact
				var worst_excess: float = 0.0
				var rose: bool = false
				for i in range(600):
					var tipped: Vector2 = AstronautView.topple_step(tilt, spin, g, 1.0 / 60.0)
					tilt = tipped.x
					spin = tipped.y
					var next: Vector3 = AstronautView.settle_step(middle, falling, fall_speed, PI / 2.0 - tilt, g, 1.0 / 60.0)
					# The free fall's step this frame, from the speed it had.
					var free_step: float = (fall_speed + g / 60.0) / 60.0
					worst_excess = maxf(worst_excess, (middle - next.x) - maxf(free_step, 1.0))
					rose = rose or next.x > middle + 0.00001
					middle = next.x
					falling = next.y
					fall_speed = next.z
				var label: String = "g %s from %s at %s" % [g, start, impact]
				_check_true("the middle never rises (%s)" % label, not rose)
				_check_true("the middle never steps more than the fall itself (%s, over by %s)" % [label, worst_excess], worst_excess <= 0.0001)
				_check("the middle ends lying flat (%s)" % label, middle, AstronautView.LYING_MIDDLE, 0.01)
