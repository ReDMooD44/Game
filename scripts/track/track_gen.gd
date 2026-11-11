@tool
class_name TrackGen
extends RefCounted
## Builds the default canyon layout and writes it to a .tres so the points
## become ordinary, hand-editable resource data instead of hidden code.
## Run: godot --headless --script tools/make_track.gd

const CONTROL_POINTS := 48

## One entry per circuit. Everything that gives a track its character lives
## here, so a new map is a row rather than a new file.
const PRESETS := [
	{
		"name": "Red Mesa", "radius": 2750.0,
		"bend": Vector2(0.145, 0.07), "rise": Vector2(55.0, 11.0),
		"half": Vector2(64.0, 12.0), "wall": Vector2(86.0, 20.0),
		"corridors": [0.72, 2.77, 4.86], "laps": 3,
		"medals": [58.5, 62.0, 70.0, 82.0],
	},
	{
		"name": "Dust Basin", "radius": 2380.0,
		"bend": Vector2(0.21, 0.10), "rise": Vector2(78.0, 16.0),
		"half": Vector2(72.0, 16.0), "wall": Vector2(104.0, 26.0),
		"corridors": [0.35, 1.95, 3.55, 5.15], "laps": 3,
		"medals": [53.0, 56.5, 64.0, 75.0],
	},
]

## Three squeezed sections, each 5.33% of the lap, so corridors cover 16% of
## the track. Centres are placed on bends, where a narrow slot actually asks
## something of the player.
const CORRIDOR_HALF_SPAN := TAU * 0.0533 * 0.5
const CORRIDOR_WIDTH := 0.46                   # of the normal half-width
const CORRIDOR_HEIGHT := 1.18                  # walls rise in the slot
const CORRIDOR_BLEND := 0.35                   # share of the span used to ease in

## 0 in the open canyon, 1 deep inside a corridor, eased at both ends so the
## walls close in rather than appearing.
static func track_count() -> int:
	return PRESETS.size()

static func preset(index: int) -> Dictionary:
	return PRESETS[clampi(index, 0, PRESETS.size() - 1)]

static func corridor_amount(angle: float, centres: Array) -> float:
	var best := 0.0
	for centre in centres:
		var d: float = absf(wrapf(angle - float(centre), -PI, PI))
		if d >= CORRIDOR_HALF_SPAN:
			continue
		var edge := CORRIDOR_HALF_SPAN * CORRIDOR_BLEND
		var inner := CORRIDOR_HALF_SPAN - edge
		var amount := 1.0 if d <= inner else smoothstep(CORRIDOR_HALF_SPAN, inner, d)
		best = maxf(best, amount)
	return best

static func generate(index := 0) -> TrackData:
	var p := preset(index)
	var d := TrackData.new()
	d.track_name = str(p["name"])
	d.laps = int(p["laps"])
	var medals: Array = p["medals"]
	d.author_time = float(medals[0])
	d.gold_time = float(medals[1])
	d.silver_time = float(medals[2])
	d.bronze_time = float(medals[3])
	var bend: Vector2 = p["bend"]
	var rise: Vector2 = p["rise"]
	var half_p: Vector2 = p["half"]
	var wall_p: Vector2 = p["wall"]
	var radius: float = p["radius"]
	var centres: Array = p["corridors"]
	var pts := PackedVector3Array()
	var halfs := PackedFloat32Array()
	var heights := PackedFloat32Array()
	for i in CONTROL_POINTS:
		var a := TAU * float(i) / CONTROL_POINTS
		# Two harmonics give four strong bends and four softer ones. Both were
		# softened, and the fast vertical ripple cut right back: blind rises in
		# a narrow canyon are not a challenge, just an ambush.
		var r: float = radius * (1.0 + bend.x * sin(a * 3.0) + bend.y * sin(a * 5.0 + 1.2))
		var y: float = rise.x * sin(a * 2.0 + 0.5) + rise.y * sin(a * 7.0 + 2.1)
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
		var squeeze := corridor_amount(a, centres)
		var half := half_p.x + half_p.y * sin(a * 4.0 + 0.7)
		var height := wall_p.x + wall_p.y * sin(a * 3.0 + 1.9)
		halfs.append(half * lerpf(1.0, CORRIDOR_WIDTH, squeeze))
		heights.append(height * lerpf(1.0, CORRIDOR_HEIGHT, squeeze))
	d.points = pts
	d.half_widths = halfs
	d.wall_heights = heights
	return d

static func track_path(index: int) -> String:
	return "res://resources/track_%d.tres" % index

static func write_all() -> void:
	for i in PRESETS.size():
		var d := generate(i)
		var path := track_path(i)
		var err := ResourceSaver.save(d, path)
		if err != OK:
			push_error("track_gen: save failed %d" % err)
		else:
			print("track_gen: wrote %s (%s, %d points)" % [path, d.track_name, d.points.size()])
