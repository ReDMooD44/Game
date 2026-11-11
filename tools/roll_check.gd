extends Node
## Direction check: hold the stick right and see which way the jet actually
## banks and turns. bank > 0 must mean right wing down, and the heading must
## then swing right. Run: godot --headless --path . res://tools/roll_check.tscn

func _ready() -> void:
	Settings.flight_assist = false
	Settings.tilt_control = false
	for dir in [1.0, -1.0]:
		var jet := JetController.new()
		add_child(jet)
		jet.global_transform = Transform3D(Basis(), Vector3.ZERO)
		jet.arm(jet.global_transform)
		jet.autopilot = func(): return Vector2(dir, 0.0)
		var heading0 := _heading(jet)
		for i in 40:
			jet._read_input()
			jet.model.step(1.0 / 60.0, -jet.global_transform.basis.x.y, -jet.global_transform.basis.z.y, 0.0, false)
			jet._integrate(1.0 / 60.0)
		var bank := -jet.global_transform.basis.x.y
		var turned := wrapf(_heading(jet) - heading0, -PI, PI)
		print("stick %-5s -> bank=%+.3f (%s), heading %+.3f rad (%s)" % [
			"RIGHT" if dir > 0.0 else "LEFT", bank,
			"right wing down" if bank > 0.0 else "left wing down",
			turned, "turns right" if turned > 0.0 else "turns left"])
		jet.queue_free()
	_assist_check()
	_straight_check()
	_boost_check()
	get_tree().quit()

## Start banked over and let the assist take over with no stick input.
func _assist_check() -> void:
	Settings.flight_assist = true
	var jet := JetController.new()
	add_child(jet)
	var b := Basis().rotated(Vector3.FORWARD, 0.6)
	jet.global_transform = Transform3D(b, Vector3(0, 500, 0))
	jet.arm(jet.global_transform)
	jet.autopilot = func(): return Vector2.ZERO
	var start := absf(-jet.global_transform.basis.x.y)
	for i in 90:
		jet._read_input()
		jet.model.step(1.0 / 60.0, -jet.global_transform.basis.x.y, -jet.global_transform.basis.z.y, 0.0, true)
		jet._integrate(1.0 / 60.0)
	var finish := absf(-jet.global_transform.basis.x.y)
	print("assist: |bank| %.3f -> %.3f (%s)" % [start, finish,
		"levelling" if finish < start else "DIVERGING"])
	jet.queue_free()

## Hands off: the jet must return to wings-level AND nose-on-the-horizon.
func _straight_check() -> void:
	Settings.flight_assist = true
	var jet := JetController.new()
	add_child(jet)
	var b := Basis().rotated(Vector3.FORWARD, 0.5).rotated(Vector3.RIGHT, 0.35)
	jet.global_transform = Transform3D(b, Vector3(0, 800, 0))
	jet.arm(jet.global_transform)
	jet.autopilot = func(): return Vector2.ZERO
	var bank0 := absf(-jet.global_transform.basis.x.y)
	var climb0 := absf(-jet.global_transform.basis.z.y)
	for i in 150:
		jet._read_input()
		jet.model.step(1.0 / 60.0, -jet.global_transform.basis.x.y,
			-jet.global_transform.basis.z.y, 0.0, true)
		jet._integrate(1.0 / 60.0)
	var bank1 := absf(-jet.global_transform.basis.x.y)
	var climb1 := absf(-jet.global_transform.basis.z.y)
	print("no input: |bank| %.3f -> %.3f, |climb| %.3f -> %.3f (%s)" % [
		bank0, bank1, climb0, climb1,
		"straight and level" if bank1 < 0.05 and climb1 < 0.05 else "NOT LEVEL"])
	jet.queue_free()

## Holding the button down must not give endless afterburner.
func _boost_check() -> void:
	var m := FlightModel.new()
	m.reset()
	var lit := 0
	var dark := 0
	var relit_while_empty := false
	for i in 600:                      # 10 s with the button jammed on
		m.boosting = true
		m.step(1.0 / 60.0, 0.0, 0.0, 0.0, false)
		if m.boosting:
			lit += 1
			if m.boost_charge <= 0.0:
				relit_while_empty = true
		else:
			dark += 1
	print("boost held 10 s: lit %.1f s, cut %.1f s, charge %.2f, available=%s (%s)" % [
		lit / 60.0, dark / 60.0, m.boost_charge, m.boost_available(),
		"runs out" if dark > 300 and not relit_while_empty else "STILL FREE FUEL"])

func _heading(jet: Node3D) -> float:
	var f := -jet.global_transform.basis.z
	return atan2(f.x, -f.z)
