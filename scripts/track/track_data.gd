class_name TrackData
extends Resource
## Hand-editable description of one canyon. Everything the generator needs
## lives here, so the track can be retuned from the inspector without code.

@export var track_name := "Red Mesa"

## Closed loop of spline control points, in metres.
@export var points: PackedVector3Array = PackedVector3Array()
## Half-width of the canyon floor at each control point. Full width is 2x this.
@export var half_widths: PackedFloat32Array = PackedFloat32Array()
## Wall height at each control point.
@export var wall_heights: PackedFloat32Array = PackedFloat32Array()

@export_group("Mesh")
@export var section_spacing := 26.0   ## metres between generated cross sections
@export var sections_per_chunk := 44  ## chunk size, drives frustum culling granularity
@export var lod_distance := 3200.0    ## chunks fade out past this

@export_group("Race")
@export var checkpoint_count := 16
@export var sector_count := 4
@export var laps := 3
## Medal thresholds for a single lap, in seconds.
## Tuned against a clean lap held at top speed (~60.5 s), so Author needs the
## afterburner and a line that never touches a wall.
@export var author_time := 58.5
@export var gold_time := 62.0
@export var silver_time := 70.0
@export var bronze_time := 82.0

## Difficulty tightens the canyon and lifts bot speed. 0 easy, 1 normal, 2 hard.
@export_group("Difficulty")
@export var width_scale := PackedFloat32Array([1.35, 1.15, 1.0])
@export var bot_speed_scale := PackedFloat32Array([1.0, 1.08, 1.16])

func is_valid() -> bool:
	return points.size() >= 8 and points.size() == half_widths.size() \
		and points.size() == wall_heights.size()

func medal_for(lap_time: float) -> String:
	if lap_time <= author_time:
		return "AUTHOR"
	if lap_time <= gold_time:
		return "GOLD"
	if lap_time <= silver_time:
		return "SILVER"
	if lap_time <= bronze_time:
		return "BRONZE"
	return ""

func build_curve(difficulty: int = 1) -> Curve3D:
	var curve := Curve3D.new()
	var n := points.size()
	if n < 4:
		return curve
	for i in n:
		var p := points[i]
		var prev := points[(i - 1 + n) % n]
		var next := points[(i + 1) % n]
		var tangent := (next - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	# Close the loop by repeating the first point.
	var t0 := (points[1] - points[n - 1]) * 0.25
	curve.add_point(points[0], -t0, t0)
	curve.bake_interval = 8.0
	return curve

func half_width_at(ratio: float, difficulty: int = 1) -> float:
	var scale := 1.0
	if difficulty >= 0 and difficulty < width_scale.size():
		scale = width_scale[difficulty]
	return _sample(half_widths, ratio) * scale

func wall_height_at(ratio: float) -> float:
	return _sample(wall_heights, ratio)

func _sample(arr: PackedFloat32Array, ratio: float) -> float:
	var n := arr.size()
	if n == 0:
		return 50.0
	var f := fposmod(ratio, 1.0) * n
	var i := int(f) % n
	var j := (i + 1) % n
	return lerpf(arr[i], arr[j], f - floorf(f))
