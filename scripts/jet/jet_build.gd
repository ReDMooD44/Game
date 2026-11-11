class_name JetBuild
extends RefCounted
## Assembles a racer: the imported space fighter hull, its afterburners and a
## blob shadow. The hull comes from ShipMesh, which welds the model's many
## surfaces down to a couple of draw calls.

const BURNER_PARTICLES := 24

## `model_yaw` flips the imported ship if it faces the wrong way; the FBX is
## authored nose-along-+Z while Godot flies along -Z.
static var model_yaw := 180.0

static func build(parent: Node3D, livery: Color, with_vfx: bool) -> Dictionary:
	var body := Node3D.new()
	body.name = "Body"
	parent.add_child(body)

	var hull := MeshInstance3D.new()
	hull.mesh = ShipMesh.mesh()
	hull.rotation_degrees = Vector3(0, model_yaw, 0)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShipMesh.material(livery)
	for i in hull.get_surface_override_material_count():
		hull.set_surface_override_material(i, mat)
	body.add_child(hull)

	var out := {"body": body, "burners": [], "shadow": null, "hull": hull}
	if with_vfx:
		var span := ShipMesh.size()
		for x in [-span.x * 0.10, span.x * 0.10]:
			var b := _burner(livery)
			b.position = Vector3(x, 0.0, span.z * 0.46)
			body.add_child(b)
			out["burners"].append(b)
		out["shadow"] = _blob_shadow(parent)
	return out

static func _mat(albedo: Color, roughness: float, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	m.roughness = roughness
	m.metallic = 0.25
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func _burner(livery: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = BURNER_PARTICLES
	p.lifetime = 0.22
	p.local_coords = true
	p.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 6.0
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 38.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.62, 0.55))
	ramp.set_color(1, Color(1.0, 0.40, 0.08, 0.0))
	ramp.add_point(0.35, livery.lerp(Color(1, 0.7, 0.25), 0.7))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex
	p.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	qm.disable_receive_shadows = true
	quad.material = qm
	p.draw_pass_1 = quad
	return p

## A decal, not a real shadow. Mobile shadow maps are not worth the frame time,
## but without something under the jet it reads as floating.
static func _blob_shadow(parent: Node3D) -> Decal:
	var d := Decal.new()
	d.size = Vector3(22, 40, 22)
	d.texture_albedo = _blob_texture()
	d.modulate = Color(0, 0, 0, 1)
	d.albedo_mix = 1.0
	d.upper_fade = 0.1
	d.lower_fade = 2.0
	d.rotation_degrees = Vector3(0, 0, 0)
	parent.add_child(d)
	return d

static func _blob_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, pow(a, 1.7) * 0.55))
	return ImageTexture.create_from_image(img)
