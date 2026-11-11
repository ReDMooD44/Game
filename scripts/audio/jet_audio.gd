class_name JetAudio
extends Node
## Continuous jet sound: turbine, afterburner and airflow, three looping
## players whose pitch and level follow the flight model. Non-positional,
## because the player's own jet never leaves the middle of the screen.

@export var engine_db_quiet := -16.0
@export var engine_db_loud := -5.0
@export var wind_db_loud := -9.0
@export var burner_db := -7.0

var _engine := AudioStreamPlayer.new()
var _burner := AudioStreamPlayer.new()
var _wind := AudioStreamPlayer.new()
var model: FlightModel

func _ready() -> void:
	for p in [_engine, _burner, _wind]:
		add_child(p)
	_engine.stream = Sfx.engine_loop()
	_burner.stream = Sfx.burner_loop()
	_wind.stream = Sfx.wind_loop()
	_burner.volume_db = -80.0
	_engine.play()
	_wind.play()
	_burner.play()

func _process(delta: float) -> void:
	if model == null:
		return
	var r := clampf(model.speed_ratio(), 0.0, 1.3)
	_engine.pitch_scale = lerpf(0.82, 1.45, r)
	_engine.volume_db = lerpf(engine_db_quiet, engine_db_loud, r)
	_wind.pitch_scale = lerpf(0.9, 1.25, r)
	_wind.volume_db = lerpf(-30.0, wind_db_loud, pow(r, 1.4))
	# The burner layer crossfades in rather than popping on.
	var want := burner_db if model.boosting else -80.0
	_burner.volume_db = lerpf(_burner.volume_db, want, clampf(6.0 * delta, 0.0, 1.0))
	_burner.pitch_scale = lerpf(0.95, 1.2, r)
