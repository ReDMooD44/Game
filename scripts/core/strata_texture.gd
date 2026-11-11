class_name StrataTexture
extends RefCounted
## Bakes the sandstone look into textures once, at load, instead of evaluating
## it per fragment. The strip is 32x256: the shader only ever samples one
## column, the width just keeps the sampler happy on old drivers.

const WIDTH := 32
const HEIGHT := 256
## The reference photo, resampled down to this before a normal map is derived
## from it. 256 is plenty: the relief is read at a distance, at 300 m/s.
const NORMAL_SIZE := 256
const ROCK := "res://assets/ground/canyon_wall.png"
const ROCK_FALLBACK := "res://assets/ground/rock.jpg"
const SAND := "res://assets/ground/canyon_floor.png"

## Floor-to-rim palette read off the reference footage: dark red at the base,
## pale ochre bands climbing to a bleached rim. These are albedo values now -
## the shader lights them - so nothing here is pre-brightened.
const BANDS := [
	[0.00, Color(0.42, 0.20, 0.14)],
	[0.08, Color(0.60, 0.30, 0.20)],
	[0.16, Color(0.74, 0.44, 0.30)],
	[0.24, Color(0.55, 0.26, 0.18)],
	[0.34, Color(0.78, 0.50, 0.34)],
	[0.44, Color(0.86, 0.62, 0.42)],
	[0.52, Color(0.66, 0.34, 0.23)],
	[0.62, Color(0.84, 0.58, 0.39)],
	[0.72, Color(0.90, 0.70, 0.50)],
	[0.82, Color(0.76, 0.48, 0.33)],
	[0.91, Color(0.92, 0.76, 0.58)],
	[1.00, Color(0.95, 0.84, 0.70)],
]

static func strip() -> ImageTexture:
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	for y in HEIGHT:
		var t := 1.0 - float(y) / float(HEIGHT - 1)
		var c := _band_colour(t)
		# Thin hard lines on top of the ramp read as bedding planes. Sharper
		# and more of them than the strata ramp alone: the layers are the one
		# thing that says sedimentary rock rather than a sand dune.
		var line := absf(sin(t * 47.0))
		c = c.darkened(0.30 * pow(line, 4.0))
		var coarse := absf(sin(t * 13.0 + 0.6))
		c = c.darkened(0.16 * pow(coarse, 6.0))
		for x in WIDTH:
			img.set_pixel(x, y, c)
	# Mipmaps matter here: a 100 m wall squeezed into a few hundred pixels
	# turns unmipped bands into shimmering corduroy.
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _band_colour(t: float) -> Color:
	for i in range(BANDS.size() - 1):
		var a: Array = BANDS[i]
		var b: Array = BANDS[i + 1]
		if t >= a[0] and t <= b[0]:
			var f := inverse_lerp(a[0], b[0], t)
			# Hold each band flat and cross quickly between them, so a wall
			# shows discrete layers rather than one continuous gradient.
			f = smoothstep(0.34, 0.66, f)
			return (a[1] as Color).lerp(b[1] as Color, f)
	return BANDS[BANDS.size() - 1][1]

## Relief for the walls, derived from the rock photo's own brightness so the
## bumps line up with the mottling you can see rather than fighting it. The
## photo is resampled to 256 first, which keeps this at a few milliseconds.
static func rock_normal() -> ImageTexture:
	var src := _rock_path()
	if src == "":
		return detail_normal()
	var tex: Texture2D = load(src)
	if tex == null:
		return detail_normal()
	var img := tex.get_image()
	if img == null:
		return detail_normal()
	img = img.duplicate()
	if img.is_compressed():
		if img.decompress() != OK:
			return detail_normal()
	img.resize(NORMAL_SIZE, NORMAL_SIZE, Image.INTERPOLATE_BILINEAR)
	var h := PackedFloat32Array()
	h.resize(NORMAL_SIZE * NORMAL_SIZE)
	for y in NORMAL_SIZE:
		for x in NORMAL_SIZE:
			h[y * NORMAL_SIZE + x] = img.get_pixel(x, y).get_luminance()
	return _to_normal_map(h, NORMAL_SIZE, 11.0)

## Fallback grain when there is no photo to derive from.
static func detail_normal() -> ImageTexture:
	var size := 128
	var h := PackedFloat32Array()
	h.resize(size * size)
	for y in size:
		for x in size:
			var v := sin(x * 0.7) * 0.5 + sin(y * 1.3 + x * 0.2) * 0.3 \
				+ sin((x + y) * 2.1) * 0.2 + sin((x - y) * 3.7) * 0.12
			h[y * size + x] = v
	return _to_normal_map(h, size, 9.0)

## Central-difference height field to tangent-space normals, wrapping at the
## edges so the result tiles.
static func _to_normal_map(h: PackedFloat32Array, size: int, strength: float) -> ImageTexture:
	# Normalise first. The reference photo is deliberately flat and evenly
	# lit, so its raw derivatives are almost nothing: left as they came, the
	# whole wall got a normal map of (0, 0, 1) and no relief at all.
	var lo := INF
	var hi := -INF
	for v in h:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span: float = maxf(hi - lo, 0.0001)
	for i in h.size():
		h[i] = (h[i] - lo) / span
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var l := h[y * size + (x - 1 + size) % size]
			var r := h[y * size + (x + 1) % size]
			var u := h[((y - 1 + size) % size) * size + x]
			var d := h[((y + 1) % size) * size + x]
			var n := Vector3((l - r) * strength, (u - d) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _rock_path() -> String:
	if ResourceLoader.exists(ROCK):
		return ROCK
	if ResourceLoader.exists(ROCK_FALLBACK):
		return ROCK_FALLBACK
	return ""

static func _flat(c: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/sandstone.gdshader")
	m.set_shader_parameter("strata", strip())
	m.set_shader_parameter("detail_normal", rock_normal())
	var rock := _rock_path()
	if rock != "":
		m.set_shader_parameter("rock_albedo", load(rock))
	else:
		m.set_shader_parameter("rock_strength", 0.0)
	# A flat fill stands in when the photo is missing, so the floor can never
	# come out sampling an undefined white texture.
	m.set_shader_parameter("sand_albedo",
		load(SAND) if ResourceLoader.exists(SAND) else _flat(Color.WHITE))
	# One source of truth for the light, shared with the sky and the real sun.
	m.set_shader_parameter("to_sun", SkyMood.to_sun())
	m.set_shader_parameter("sun_colour", SkyMood.SUN)
	m.set_shader_parameter("sun_energy", SkyMood.SUN_ENERGY)
	m.set_shader_parameter("sky_colour", SkyMood.SKY)
	m.set_shader_parameter("sky_energy", SkyMood.SKY_ENERGY)
	m.set_shader_parameter("bounce_colour", SkyMood.BOUNCE)
	m.set_shader_parameter("bounce_energy", SkyMood.BOUNCE_ENERGY)
	m.set_shader_parameter("haze_colour", SkyMood.HAZE)
	return m
