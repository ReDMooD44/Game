extends SceneTree
## Generates the Android launcher icons from code so no binary art has to be
## checked in or downloaded.
## godot --headless --script tools/make_icons.gd

const LAYERS := [
	[0.00, Color(0.30, 0.55, 0.85)],   # sky
	[0.34, Color(0.42, 0.65, 0.90)],
	[0.40, Color(0.80, 0.52, 0.34)],   # rim
	[0.52, Color(0.62, 0.30, 0.20)],
	[0.60, Color(0.78, 0.48, 0.32)],
	[0.70, Color(0.55, 0.26, 0.18)],
	[0.80, Color(0.86, 0.68, 0.48)],   # sand
	[1.00, Color(0.92, 0.80, 0.62)],
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets")
	_save(_draw(192, false), "res://assets/icon_192.png")
	_save(_draw(432, false), "res://assets/icon_fg_432.png")
	_save(_draw(432, true), "res://assets/icon_bg_432.png")
	print("icons written")
	quit()

func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		push_error("icon save failed: %s (%d)" % [path, err])

func _draw(size: int, background_only: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var t := float(y) / float(size - 1)
		var c := _band(t)
		for x in size:
			img.set_pixel(x, y, c)
	if background_only:
		return img
	_jet(img, size)
	return img

func _band(t: float) -> Color:
	for i in range(LAYERS.size() - 1):
		var a: Array = LAYERS[i]
		var b: Array = LAYERS[i + 1]
		if t >= a[0] and t <= b[0]:
			var f := smoothstep(0.0, 1.0, inverse_lerp(a[0], b[0], t))
			return (a[1] as Color).lerp(b[1] as Color, f)
	return LAYERS[LAYERS.size() - 1][1]

## A blocky jet silhouette: a nose triangle, a swept wing and two burners.
func _jet(img: Image, size: int) -> void:
	var s := float(size)
	var white := Color(0.96, 0.97, 1.0)
	var flame := Color(1.0, 0.78, 0.25)
	var cx := s * 0.5
	for y in size:
		var fy := float(y) / s
		for x in size:
			var fx := float(x) / s
			var dx := absf(fx - 0.5)
			var hit := false
			# fuselage
			if fy > 0.30 and fy < 0.74 and dx < lerpf(0.02, 0.075, clampf((fy - 0.30) / 0.44, 0.0, 1.0)):
				hit = true
			# wing
			if fy > 0.52 and fy < 0.62 and dx < 0.34 - (fy - 0.52) * 1.2:
				hit = true
			# tailplane
			if fy > 0.66 and fy < 0.72 and dx < 0.17 - (fy - 0.66) * 1.0:
				hit = true
			if hit:
				img.set_pixel(x, y, white)
	# burners
	for y in size:
		var fy := float(y) / s
		if fy < 0.74 or fy > 0.84:
			continue
		for x in size:
			var fx := float(x) / s
			var d := minf(absf(fx - 0.455), absf(fx - 0.545))
			if d < 0.030 * (1.0 - (fy - 0.74) / 0.10):
				img.set_pixel(x, y, flame.lerp(Color(1, 1, 1), 1.0 - (fy - 0.74) / 0.10))
