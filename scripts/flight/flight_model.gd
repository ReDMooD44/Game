class_name FlightModel
extends RefCounted
## Pure arcade flight maths. No Node dependency, deterministic at a fixed tick.
## The controller feeds it inputs and reads back rates; it never touches the scene.

# --- tuning -------------------------------------------------------------
var min_speed := 185.0          # m/s, cruise floor
var max_speed := 320.0          # m/s, top speed without boost
var boost_speed := 372.0        # m/s, ceiling while afterburner is lit
var thrust_accel := 55.0        # m/s^2 toward the target speed
var brake_accel := 110.0        # m/s^2 while the airbrake is held
var airbrake_floor := 0.55      # fraction of min_speed the airbrake can pull down to

var pitch_rate := 1.15          # rad/s at full stick
var roll_rate := 2.6            # rad/s at full stick
var coordinated_yaw := 0.95     # rad/s of yaw per unit of bank
var assist_level_rate := 2.2    # rad/s of auto roll-levelling
var assist_pitch_rate := 1.9    # rad/s of auto pitch-levelling
var input_dead_zone := 0.08

var g_limit := 9.0
var g_scale := 0.25             # maps raw centripetal g onto the reference HUD range

var boost_capacity := 3.0       # seconds
var boost_recharge := 0.35      # seconds of charge per second of flight
## Once the tank is empty the button does nothing until it has refilled this
## far. Without the latch, a held button drains and re-ignites every tick and
## the afterburner never really stops.
var boost_rearm_fraction := 0.5

# --- state --------------------------------------------------------------
var speed := 220.0
var pitch_input := 0.0
var roll_input := 0.0
var airbrake := false
var boosting := false
var boost_charge := 3.0
var boost_locked := false
var g_force := 1.0
var out_pitch := 0.0            # rad/s applied this tick
var out_roll := 0.0
var out_yaw := 0.0

func reset(start_speed := -1.0) -> void:
	speed = start_speed if start_speed > 0.0 else min_speed
	pitch_input = 0.0
	roll_input = 0.0
	airbrake = false
	boosting = false
	boost_charge = boost_capacity
	boost_locked = false
	g_force = 1.0
	out_pitch = 0.0
	out_roll = 0.0
	out_yaw = 0.0

## `bank_sin` is the world-Y component of the craft's local right vector: the
## signed sine of the bank angle, which drives the coordinated turn.
## `climb_sin` is the world-Y component of the nose direction, so zero means
## the jet is pointed at the horizon. `target_climb` is the climb the assist
## aims for with hands off the stick - the canyon floor rises and falls, so
## "level" is not the same thing as "safe".
func step(delta: float, bank_sin: float, climb_sin: float, target_climb: float,
		assist: bool) -> void:
	_step_speed(delta)
	_step_rates(delta, bank_sin, climb_sin, target_climb, assist)
	_step_g()

func _step_speed(delta: float) -> void:
	# Re-lighting needs BOTH a refilled tank and a finger lift: holding the
	# button down must not keep buying short bursts.
	if boost_locked and not boosting and boost_charge >= boost_capacity * boost_rearm_fraction:
		boost_locked = false
	if boosting and not boost_locked and boost_charge > 0.0:
		boost_charge = maxf(0.0, boost_charge - delta)
		if boost_charge <= 0.0:
			boost_locked = true
			boosting = false
	else:
		boosting = false
		boost_charge = minf(boost_capacity, boost_charge + boost_recharge * delta)

	var target := max_speed
	if boosting:
		target = boost_speed
	elif airbrake:
		target = min_speed * airbrake_floor

	if speed < target:
		speed = minf(target, speed + thrust_accel * delta)
	else:
		var decel := brake_accel if airbrake else thrust_accel * 0.8
		speed = maxf(target, speed - decel * delta)

func _step_rates(delta: float, bank_sin: float, climb_sin: float,
		target_climb: float, assist: bool) -> void:
	# Less pitch authority at the top of the speed range keeps high speed scary.
	var authority := lerpf(1.0, 0.80, clampf(speed_ratio(), 0.0, 1.0))

	# Hands off the stick means "fly straight and level", not "hold whatever
	# attitude you were left in": both the wings and the nose come back.
	if assist and absf(pitch_input) < input_dead_zone:
		out_pitch = (target_climb - climb_sin) * assist_pitch_rate
	else:
		out_pitch = pitch_input * pitch_rate * authority

	if assist and absf(roll_input) < input_dead_zone:
		out_roll = -bank_sin * assist_level_rate
	else:
		out_roll = roll_input * roll_rate

	out_yaw = -bank_sin * coordinated_yaw

	_apply_g_limiter(delta)

func _apply_g_limiter(_delta: float) -> void:
	if _raw_g() <= g_limit:
		return
	# Only the turn-rate term scales: the 1 g you always carry is not something
	# the limiter can trade away, so dividing the whole reading overshoots.
	var omega := sqrt(out_pitch * out_pitch + out_yaw * out_yaw)
	var omega_max := (g_limit - 1.0) * 9.81 / maxf(speed * g_scale, 0.001)
	var k := omega_max / maxf(omega, 0.001)
	out_pitch *= k
	out_yaw *= k

func _raw_g() -> float:
	var omega := sqrt(out_pitch * out_pitch + out_yaw * out_yaw)
	return 1.0 + (speed * omega) / 9.81 * g_scale

func _step_g() -> void:
	g_force = lerpf(g_force, _raw_g(), 0.25)

## 0 at `min_speed`, 1 at `max_speed`. Can exceed 1 while boosting.
func speed_ratio() -> float:
	return (speed - min_speed) / maxf(max_speed - min_speed, 1.0)

## HUD values. Real speed is mobile-friendly; the readout keeps the reference
## jet feel (630-1250 kt, M 1.09-1.85) by mapping the ratio onto those ranges.
func display_knots() -> float:
	return lerpf(630.0, 1250.0, clampf(speed_ratio(), 0.0, 1.0))

func display_mach() -> float:
	return lerpf(1.09, 1.85, clampf(speed_ratio(), 0.0, 1.0))

func boost_ratio() -> float:
	return boost_charge / maxf(boost_capacity, 0.001)

## False while the tank is too empty to re-light, so the UI can grey the button.
func boost_available() -> bool:
	return not boost_locked
