extends Node
## Hands off the stick: the assist no longer steers, so wall contact is
## expected - what it must still do is hold a sane altitude above the canyon
## floor rather than sinking into it or climbing to the rim.
## godot --headless --path . res://tools/ride_check.tscn

const SECONDS := 20

var game: Node3D
var frame := 0
var started := false
var scrapes := 0
var respawns := 0
var min_clear := 1e9
var sum_clear := 0.0
var samples := 0
var probe := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	Settings.mode = 1
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().physics_frame
	probe.collision_mask = 1
	var jet0: JetController = game.jet
	jet0.scraped.connect(func(_p, _n): scrapes += 1)
	game.race.respawned.connect(func(): respawns += 1)

func _physics_process(_d: float) -> void:
	if not started:
		if game.race.running:
			started = true
		return
	frame += 1
	var jet: JetController = game.jet
	var space: PhysicsDirectSpaceState3D = jet.get_world_3d().direct_space_state
	probe.from = jet.global_position
	probe.to = probe.from + Vector3.DOWN * 600.0
	probe.exclude = [jet.get_rid()]
	var hit: Dictionary = space.intersect_ray(probe)
	if not hit.is_empty():
		var clear: float = probe.from.distance_to(hit.position)
		min_clear = minf(min_clear, clear)
		sum_clear += clear
		samples += 1
	if frame >= SECONDS * 60:
		print("%d s hands off: clearance min %.0f m, average %.0f m" % [
			SECONDS, min_clear, sum_clear / maxf(samples, 1)])
		var avg := sum_clear / maxf(samples, 1)
		print("scrapes=%d respawns=%d; altitude hold %s" % [scrapes, respawns,
			"ok" if avg > 25.0 and avg < 90.0 else "OFF TARGET"])
		get_tree().quit()
