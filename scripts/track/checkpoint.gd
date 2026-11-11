class_name Checkpoint
extends Area3D
## One gate in the lap. Only fires when it is the gate the racer owes next,
## so cutting back across an earlier gate does nothing.

signal passed(body: Node3D, index: int)

var index := 0
var is_sector_gate := false
var sector := 0
var spline_offset := 0.0
## Where a racer is put back after falling out of the canyon.
var respawn_transform := Transform3D.IDENTITY

func setup(idx: int, frame: Transform3D, half_width: float, height: float,
		offset: float, sector_gate: bool, sector_index: int) -> void:
	index = idx
	is_sector_gate = sector_gate
	sector = sector_index
	spline_offset = offset
	global_transform = frame
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_width * 2.2, height * 1.4, 12.0)
	shape.shape = box
	shape.position = Vector3(0, height * 0.35, 0)
	add_child(shape)

	# Respawn a little above the floor and already pointing down the track.
	respawn_transform = frame
	respawn_transform.origin += frame.basis.y * (height * 0.52)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	passed.emit(body, index)
