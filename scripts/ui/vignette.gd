extends ColorRect
## Speed vignette plus the radial speed lines, in a single fullscreen blend.
## The line shader needs a tiling noise texture; it is generated here so no
## image has to ship with it.

var _mat := ShaderMaterial.new()
var _spin := 0.0
var _lines := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	_mat.shader = load("res://shaders/vignette.gdshader")
	_mat.set_shader_parameter("noise", _noise())
	_mat.set_shader_parameter("line_color", Color(1, 1, 1, 0.9))
	_mat.set_shader_parameter("sample_radius", 0.5)
	_mat.set_shader_parameter("center_radius", 0.42)
	material = _mat
	set_intensity(0.0)

## Seamless value noise: the shader walks a circle through it, so it has to
## tile, and it wants hard edges to read as separate rays.
func _noise() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_VALUE
	n.seed = 7
	n.frequency = 0.055
	n.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.normalize = true
	return tex

func _process(delta: float) -> void:
	_spin = fposmod(_spin + delta * 0.35 * (0.2 + _lines), TAU)
	_mat.set_shader_parameter("spin", _spin)
	var vp := get_viewport_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))

func set_intensity(v: float) -> void:
	_mat.set_shader_parameter("intensity", clampf(v, 0.0, 1.0))

## Speed 0..1 and the afterburner drive how hard the rays bite.
##
## Held well below full: at the old strength the rays whited out most of the
## screen under boost, and boost is exactly when the canyon is rushing past
## fastest and most worth seeing. The rays also keep clear of a wider middle,
## so the jet and the track ahead stay readable.
func set_speed_lines(speed: float, boosting: bool) -> void:
	var target := clampf((speed - 0.3) / 0.7, 0.0, 1.0) * 0.30
	if boosting:
		target = clampf(target + 0.16, 0.0, 0.38)
	_lines = lerpf(_lines, target, 0.1)
	_mat.set_shader_parameter("lines", _lines)
	_mat.set_shader_parameter("center_radius", lerpf(0.58, 0.44, clampf(speed, 0.0, 1.0)))
