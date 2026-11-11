class_name TrailSkins
extends RefCounted
## Wingtip trail looks. The plain white vapour is the default and always
## available; the rest are cut out of the laser-beam sheet and are meant to be
## unlockable later. They are all switched on for now so they can be tried.

const SHEET := "res://assets/fx/laser_beams_src.jpg"
const COLS := 2
const ROWS := 4

## name, cell (column,row) in the sheet, tint, width, brightness.
## Cell (-1,-1) means "no texture": the stock white vapour trail.
const SKINS := [
	{"name": "BEYAZ", "cell": Vector2i(-1, -1), "tint": Color(0.95, 0.97, 1.0), "width": 0.30, "alpha": 0.85},
	{"name": "ALEV", "cell": Vector2i(0, 0), "tint": Color(1.0, 0.75, 0.35), "width": 0.34, "alpha": 0.95},
	{"name": "PLAZMA", "cell": Vector2i(1, 0), "tint": Color(0.45, 0.80, 1.0), "width": 0.34, "alpha": 0.95},
	{"name": "NEON", "cell": Vector2i(0, 1), "tint": Color(0.85, 0.55, 1.0), "width": 0.32, "alpha": 0.92},
	{"name": "ASİT", "cell": Vector2i(1, 1), "tint": Color(0.60, 1.0, 0.35), "width": 0.34, "alpha": 0.95},
	{"name": "ŞİMŞEK", "cell": Vector2i(0, 2), "tint": Color(0.45, 0.75, 1.0), "width": 0.36, "alpha": 0.95},
	{"name": "MANYETO", "cell": Vector2i(1, 2), "tint": Color(1.0, 0.45, 0.95), "width": 0.34, "alpha": 0.95},
	{"name": "DALGA", "cell": Vector2i(0, 3), "tint": Color(0.70, 1.0, 0.45), "width": 0.34, "alpha": 0.92},
	{"name": "MAGMA", "cell": Vector2i(1, 3), "tint": Color(1.0, 0.55, 0.20), "width": 0.36, "alpha": 0.95},
]

static var _sheet: Texture2D = null
static var _cells := {}

static func count() -> int:
	return SKINS.size()

static func skin_name(index: int) -> String:
	return str(SKINS[wrapi(index, 0, SKINS.size())]["name"])

static func data(index: int) -> Dictionary:
	return SKINS[wrapi(index, 0, SKINS.size())]

## The sheet is one JPG of eight beams; each skin is an atlas window onto it,
## so all nine looks share a single texture.
static func texture(index: int) -> Texture2D:
	var cell: Vector2i = data(index)["cell"]
	if cell.x < 0:
		return null
	if _cells.has(cell):
		return _cells[cell]
	if _sheet == null:
		if not ResourceLoader.exists(SHEET):
			return null
		_sheet = load(SHEET)
	var size := _sheet.get_size()
	var w := size.x / float(COLS)
	var h := size.y / float(ROWS)
	var atlas := AtlasTexture.new()
	atlas.atlas = _sheet
	# Trimmed a little: the sheet's cells have dark padding around the beams.
	atlas.region = Rect2(cell.x * w + w * 0.04, cell.y * h + h * 0.18,
		w * 0.92, h * 0.64)
	_cells[cell] = atlas
	return atlas

## Applies a skin to one of the ribbon trails.
static func apply(trail: Contrail, index: int) -> void:
	var d := data(index)
	trail.tint = d["tint"]
	trail.width = d["width"]
	trail.alpha = d["alpha"]
	trail.set_texture(texture(index))
