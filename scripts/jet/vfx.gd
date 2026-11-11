class_name Vfx
extends RefCounted
## Scrape sparks, the crash explosion, and the light the whole canyon is lit
## by. The two particle systems are small and short lived on purpose: additive
## overdraw is what kills tile GPUs.

static func sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.42
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false

	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 70.0
	m.initial_velocity_min = 14.0
	m.initial_velocity_max = 46.0
	m.gravity = Vector3(0, -24, 0)
	m.scale_min = 0.3
	m.scale_max = 0.8
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.55, 1.0))
	g.add_point(0.4, Color(1.0, 0.55, 0.15, 0.85))
	g.set_color(1, Color(0.6, 0.35, 0.2, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m

	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qm
	p.draw_pass_1 = quad
	return p

## Crash burst: a fireball core plus dark debris, one shot, gone in a second.
static func explosion() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 2.0
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 18.0
	m.initial_velocity_max = 64.0
	m.gravity = Vector3(0, -22, 0)
	m.damping_min = 12.0
	m.damping_max = 26.0
	m.scale_min = 1.6
	m.scale_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.98, 0.80, 1.0))
	g.add_point(0.18, Color(1.0, 0.62, 0.15, 0.95))
	g.add_point(0.55, Color(0.55, 0.22, 0.08, 0.7))
	g.set_color(1, Color(0.15, 0.13, 0.12, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m

	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qm
	p.draw_pass_1 = quad
	return p

## Midday sun, far fog, no SSAO/SSIL/volumetrics - none of them are cheap
## enough on the mobile renderer to be worth their frame time.
static func environment() -> Environment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SkyMood.SKY_TOP
	sky_mat.sky_horizon_color = SkyMood.SKY_HORIZON
	sky_mat.ground_bottom_color = SkyMood.GROUND_BOTTOM
	sky_mat.ground_horizon_color = SkyMood.GROUND_HORIZON
	# A big soft sun disc: low light through a lot of dusty air.
	sky_mat.sun_angle_max = 13.0
	sky_mat.sun_curve = 0.08
	sky_mat.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false
	env.volumetric_fog_enabled = false
	# Aerial perspective. The canyon walls do their own haze in the shader so
	# dust can pool on the floor; this is for everything else - the terrain
	# formations above the rim and the jets down the straight. It was sitting
	# at density zero, which meant none of these settings did anything and
	# the far end of the canyon stayed as crisp as the near end.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = SkyMood.HAZE
	env.fog_density = 0.55
	env.fog_depth_begin = 900.0
	env.fog_depth_end = 6500.0
	env.fog_depth_curve = 1.35
	# The sky is the horizon; fogging it turns a blue day into grey soup.
	env.fog_sky_affect = 0.0
	return env

static func sun() -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = SkyMood.euler()
	l.light_energy = 1.7
	l.light_color = SkyMood.SUN
	l.shadow_enabled = false
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	return l
