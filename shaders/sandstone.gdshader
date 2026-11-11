shader_type spatial;
render_mode cull_back, unshaded;

// Layered sandstone, lit entirely by hand.
//
// Unshaded on purpose. Real-time shadows are out of budget, and a slot canyon
// without them is a grey pipe - so the occlusion that matters is baked into
// the mesh on the CPU (see canyon_shading.gd) and spent here on the three
// terms a canyon is actually made of:
//
//   direct   hot, low sun on the upper wall, cut off at a hard shadow line
//   ambient  cool fill from the strip of sky, scaled by how much is visible
//   bounce   warm light that already hit the sunlit wall once - the colour
//            that fills the shade in every photograph of a slot canyon
//
// Still one texture fetch per channel and no noise() call anywhere.

uniform sampler2D strata : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The floor is nearer the camera than the walls and runs away from it, so
// its tiles have to be much smaller or the ripples come out metres wide.
uniform float sand_tiling = 6.0;

uniform vec2 rock_tiling = vec2(1.0, 1.0);
uniform float rock_strength : hint_range(0.0, 1.0) = 0.95;
uniform float grain_tiling = 3.5;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.36;
// Slow slide of the layers along the track, so a wall is never an exact
// copy of the wall behind it.
uniform float drift = 0.0009;
uniform vec2 detail_tiling = vec2(4.5, 4.5);
uniform float detail_strength : hint_range(0.0, 2.0) = 0.75;

uniform vec3 to_sun = vec3(0.50, 0.41, 0.76);
uniform vec3 sun_colour : source_color = vec3(1.00, 0.86, 0.66);
uniform float sun_energy = 1.50;
uniform vec3 sky_colour : source_color = vec3(0.46, 0.60, 0.86);
uniform float sky_energy = 0.58;
uniform vec3 bounce_colour : source_color = vec3(1.00, 0.52, 0.24);
uniform float bounce_energy = 1.10;
uniform float crest_gain : hint_range(0.0, 2.0) = 0.38;

uniform vec3 haze_colour : source_color = vec3(0.82, 0.68, 0.56);
uniform float haze_density = 0.00024;
uniform vec3 sand_colour : source_color = vec3(0.86, 0.71, 0.52);
uniform float sand_gain = 1.55;

varying vec3 world_pos;
varying vec4 vcol;
varying vec2 baked;      // x: direct sun visibility, y: height up the wall
varying float view_dist;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
	baked = UV2;
	// Distance from the camera, straight out of view space. Taken this way
	// rather than from CAMERA_POSITION_WORLD, which is not dependable across
	// both renderers - and when it comes back as the origin the haze is
	// computed against world zero instead, which on an 18 km track means a
	// milky film over every surface in the game.
	view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

float absf_dot(vec3 a, vec3 b) {
	return abs(dot(a, b));
}

void fragment() {
	// --- colour -----------------------------------------------------------
	// Driven by height up the WALL, not by world height. Every wall then
	// shows its whole stack of layers, floor to rim. Keyed to world Y the
	// visible span of a 100 m wall only ever reached a thin slice of the
	// palette, which is why the rock came out as one smooth brown wash.
	float t = clamp(baked.y * 0.86 + 0.07 + world_pos.y * drift, 0.0, 1.0);
	vec3 base = texture(strata, vec2(0.5, 1.0 - t)).rgb;
	base *= mix(0.90, 1.10, vcol.r);
	base *= mix(0.95, 1.04, vcol.g);
	// The canyon floor is wind-blown sand, not cut rock, so it gets its own
	// photographed surface instead of the bottom of the strata ramp. sand_colour
	// is only a tint now - a flat fill was the one surface in view with no
	// detail on it at all, and it showed.
	vec3 sand = texture(sand_albedo, UV * rock_tiling * sand_tiling).rgb;
	sand *= sand_colour * sand_gain * mix(0.92, 1.06, vcol.r);
	base = mix(base, sand, vcol.b);

	// UV.x runs in metres across the cross section and UV.y in metres along
	// the track, so the photographed grain never stretches on a tall wall.
	// Twice over: broad mottling, then the same photo tiled small for the
	// grain that tells the eye how close a wall is.
	vec3 rock = texture(rock_albedo, UV * rock_tiling).rgb;
	float grain = texture(rock_albedo, UV * rock_tiling * grain_tiling).r;
	float grey = dot(rock, vec3(0.299, 0.587, 0.114));
	// Centred on mid grey: the photo adds mottling without stamping its own
	// light and dark blocks over the strata.
	base *= 1.0 + (grey - 0.5) * rock_strength;
	base *= 1.0 + (grain - 0.5) * grain_strength;
	// Weighted toward the photograph rather than the generated ramp: the
	// strata still set the layering, the asset supplies the surface.
	base = mix(base, base * (rock / max(grey, 0.001)), rock_strength * 0.85);

	// --- surface ----------------------------------------------------------
	// Everything below is in view space, because that is the space Godot
	// hands NORMAL, TANGENT and BINORMAL to a fragment shader in.
	vec3 nm = texture(detail_normal, UV * detail_tiling).rgb * 2.0 - 1.0;
	vec3 N = normalize(NORMAL
		+ TANGENT * nm.x * detail_strength
		+ BINORMAL * nm.y * detail_strength);
	vec3 L = normalize((VIEW_MATRIX * vec4(to_sun, 0.0)).xyz);
	vec3 up_v = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;

	float lit = baked.x;
	float height = baked.y;
	float ao = vcol.a;

	// --- light ------------------------------------------------------------
	vec3 direct = sun_colour * sun_energy * max(dot(N, L), 0.0) * lit;

	// Sky fill reaches whatever can see the sky: up-facing and unoccluded.
	float sees_sky = mix(0.50, 1.0, clamp(dot(N, up_v) * 0.5 + 0.5, 0.0, 1.0));
	vec3 ambient = sky_colour * sky_energy * ao * sees_sky;

	// Bounce off the lit wall. Not given a direction on purpose: the source is
	// the whole opposite wall, a few tens of metres away and filling half the
	// sky from down here, so it arrives as a wash rather than from a point.
	// Steering it by the sun vector instead put it along the canyon rather
	// than across it, and the shaded wall came out a flat black mass instead
	// of the glowing orange a canyon shows in shade.
	float sideways = 1.0 - absf_dot(N, up_v);
	float fill = (1.0 - lit * 0.80) * ao * mix(0.70, 1.0, sideways);
	vec3 bounce = bounce_colour * bounce_energy * fill * mix(1.20, 0.55, height);

	// A hot edge along the top of the sunlit wall. Nothing physical, it is
	// just what the eye reads as a cliff catching the last of the light.
	float crest = smoothstep(0.76, 1.0, height) * lit;
	vec3 col = base * (direct + ambient + bounce) + sun_colour * crest * crest_gain;

	// --- air --------------------------------------------------------------
	// Done here rather than with the environment's depth fog so dust can pool
	// in the bottom of the canyon, which is where it really sits.
	float air = 1.0 - exp(-view_dist * haze_density);
	air *= mix(1.20, 0.75, clamp(world_pos.y / 220.0, 0.0, 1.0));
	col = mix(col, haze_colour, clamp(air, 0.0, 1.0));

	ALBEDO = col;
}
