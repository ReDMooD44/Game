extends Control
## Top-down overview of the circuit, drawn from the spline itself so it can
## never disagree with the track. North-up and always showing the whole lap:
## on a 19 km loop a rotating, zoomed map tells you nothing you cannot already
## see out of the cockpit.

const SAMPLES := 180
const BOX := 190.0
const PAD := 16.0

var canyon: Canyon
var player: Node3D
var bots: Array = []
var sector_marks: Array[Vector2] = []

var _line := PackedVector2Array()
var _scale := 1.0
var _origin := Vector2.ZERO
var _rect := Rect2()

func setup(canyon_node: Canyon, player_node: Node3D, bot_list: Array,
		gate_offsets: Array = []) -> void:
	canyon = canyon_node
	player = player_node
	bots = bot_list
	_build(gate_offsets)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Flattens the spline to x/z and fits it into the box, keeping the aspect so
## the shape of the circuit stays recognisable.
func _build(gate_offsets: Array) -> void:
	if canyon == null or canyon.length <= 0.0:
		return
	var pts := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in SAMPLES:
		var p := canyon.point_at(canyon.length * float(i) / SAMPLES)
		var v := Vector2(p.x, p.z)
		pts.append(v)
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	pts.append(pts[0])
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 1.0)
	_scale = (BOX - PAD * 2.0) / span
	_origin = (lo + hi) * 0.5
	_line = pts

	sector_marks.clear()
	for off in gate_offsets:
		var p: Vector3 = canyon.point_at(float(off))
		sector_marks.append(Vector2(p.x, p.z))

func _to_map(world: Vector2) -> Vector2:
	return _rect.get_center() + (world - _origin) * _scale

func _process(_delta: float) -> void:
	if canyon != null:
		queue_redraw()

func _draw() -> void:
	if _line.size() < 3:
		return
	var vp := get_viewport_rect().size
	_rect = Rect2(Vector2((vp.x - BOX) * 0.5, vp.y - BOX - 18.0), Vector2(BOX, BOX))

	draw_rect(_rect, Color(0.04, 0.04, 0.06, 0.45), true)
	draw_rect(_rect, Color(1, 1, 1, 0.20), false, 1.5)

	var mapped := PackedVector2Array()
	for v in _line:
		mapped.append(_to_map(v))
	draw_polyline(mapped, Color(0.95, 0.80, 0.60, 0.75), 2.0, true)

	for m in sector_marks:
		draw_circle(_to_map(m), 2.5, Color(1, 1, 1, 0.45))

	for b in bots:
		if b == null or not is_instance_valid(b):
			continue
		var col: Color = b.livery if "livery" in b else Color(1, 0.4, 0.4)
		draw_circle(_to_map(Vector2(b.global_position.x, b.global_position.z)), 3.5,
			Color(col.r, col.g, col.b, 0.9))

	if player != null and is_instance_valid(player):
		_draw_player()

## A triangle, so heading is readable at a glance.
func _draw_player() -> void:
	var p := _to_map(Vector2(player.global_position.x, player.global_position.z))
	var f := -player.global_transform.basis.z
	var dir := Vector2(f.x, f.z)
	if dir.length() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		p + dir * 8.0,
		p - dir * 5.0 + side * 5.0,
		p - dir * 5.0 - side * 5.0,
	])
	draw_colored_polygon(pts, Color(0.45, 1.0, 0.55, 0.95))
