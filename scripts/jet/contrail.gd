class_name Contrail
extends MeshInstance3D
## A single ribbon mesh rebuilt each frame from a short position history.
## Cheaper than a particle trail and it does not fight the tile GPU with
## dozens of overlapping transparent quads.

@export var points := 30
@export var width := 0.45
@export var alpha := 0.16
@export var taper := 1.6
@export var tint := Color(0.95, 0.97, 1.0)
@export var fade_speed := 3.0

var _trail: Array[Vector3] = []
var _up: Array[Vector3] = []
var _im := ImmediateMesh.new()
var _strength := 0.0
var _material := StandardMaterial3D.new()

func _ready() -> void:
	mesh = _im
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_receive_shadows = true
	material_override = _material

## A skin texture is stretched along the ribbon; null falls back to the plain
## additive vapour trail.
func set_texture(tex: Texture2D) -> void:
	_material.albedo_texture = tex
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

func push(t: Transform3D, strength: float) -> void:
	_strength = strength
	_trail.push_front(t.origin)
	_up.push_front(t.basis.y)
	while _trail.size() > points:
		_trail.pop_back()
		_up.pop_back()
	_rebuild()

func _rebuild() -> void:
	_im.clear_surfaces()
	if _trail.size() < 3 or _strength <= 0.02:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail.size():
		var t := float(i) / float(_trail.size() - 1)
		# Fade the head in as well: the first few metres sit inside the chase
		# camera, and a solid ribbon there fills the whole screen with white.
		var a := (1.0 - t) * _strength * alpha * smoothstep(0.0, 0.22, t)
		var fwd := (_trail[maxi(i - 1, 0)] - _trail[mini(i + 1, _trail.size() - 1)])
		if fwd.length() < 0.001:
			fwd = Vector3.FORWARD
		var side := fwd.normalized().cross(_up[i]).normalized() * width * (1.0 + t * taper)
		var c := Color(tint.r, tint.g, tint.b, a)
		# v runs along the ribbon so a beam sprite stretches from tip to tail.
		_im.surface_set_color(c)
		_im.surface_set_uv(Vector2(0.0, t))
		_im.surface_add_vertex(_trail[i] - side)
		_im.surface_set_color(c)
		_im.surface_set_uv(Vector2(1.0, t))
		_im.surface_add_vertex(_trail[i] + side)
	_im.surface_end()
