class_name CanyonShading
extends RefCounted
## Light baked into the canyon mesh at load, on the CPU.
##
## The spec rules out real-time shadows, and a slot canyon without shadows is
## a grey pipe: the shape only reads when one wall is hot, the other is in
## shade, and there is a hard terminator between them. So the two terms that
## need occlusion are worked out per vertex here, once, and stored in the mesh:
##
##   COLOR.a  ambient occlusion - how much of the sky strip this point sees
##   UV2.x    direct sun - whether the opposite rim shadows this point
##   UV2.y    height up the wall, 0 at the floor and 1 at the rim
##
## Both are plain geometry on a cross section, not a ray trace, which is why
## 22,000 vertices bake in a few milliseconds instead of a few minutes.

const AO_FLOOR := 0.10          ## darkest the deepest slot floor goes
const TERMINATOR := 0.085       ## softness of the shadow line, in wall heights
const RIM := 1.25               ## profile y at the canyon rim
const RIM_X := 1.22             ## profile x at the canyon rim
const TERRACES := 6.0           ## flat ledges stacked up each wall
const TERRACE_SHARPNESS := 0.13 ## narrower means crisper risers
const RIM_RELIEF := 0.16        ## how far the skyline wanders, as a fraction

## Fraction of the sky hemisphere a point on the cross section can see.
##
## Looking up out of a slot you see a strip of sky subtending roughly
## 2*atan(halfGap / depthBelowRim). At the rim that is the whole hemisphere; on
## the floor of a deep narrow canyon it is a slot, and the floor goes dark.
static func occlusion(px: float, py: float, half_width: float, height: float) -> float:
	var fall: float = maxf((RIM - py) * height, 0.5)
	var gap: float = maxf(RIM_X * half_width, 1.0)
	var open: float = atan2(gap, fall) / (PI * 0.5)
	# A point tucked under an overhang sees less than the slot alone implies.
	var tuck: float = clampf((RIM_X - absf(px)) * 1.2, 0.0, 1.0)
	open *= 1.0 - tuck * 0.22
	# Squared rather than eased: a gentle curve left the floor at 0.44, which
	# is far too bright for the bottom of a slot and flattened the whole shape.
	return lerpf(AO_FLOOR, 1.0, clampf(pow(open, 1.85), 0.0, 1.0))

## 1 where the sun reaches, 0 where the opposite rim cuts it off.
##
## In the plane of the cross section the sun comes in at (lat, up). A point is
## lit if a ray from it toward the sun clears the rim on the sun's side before
## running into the wall - pure similar triangles.
static func sunlit(px: float, py: float, half_width: float, height: float,
		lat: float, up: float) -> float:
	if up <= 0.01:
		return 0.0
	# Sun straight down the canyon: no wall between it and anything.
	if absf(lat) < 0.04:
		return 1.0
	var sun_side: float = signf(lat)
	# Horizontal run from here out to the rim the sun is behind, in metres.
	var dx: float = maxf((RIM_X * sun_side - px) * half_width * sun_side, 0.0)
	var rise: float = dx * (up / absf(lat))
	var shadow_y: float = (RIM * height - rise) / maxf(height, 1.0)
	return smoothstep(shadow_y - TERMINATOR, shadow_y + TERMINATOR, py)

## Outward normal of the cross section at a profile vertex, in frame space.
## Taken from the two neighbouring profile points so overhangs get a normal
## that actually points down and out, the way an undercut should.
static func profile_normal(profile: Array, index: int, half_width: float,
		height: float) -> Vector2:
	var n: int = profile.size()
	var prev: Vector2 = profile[maxi(index - 1, 0)]
	var next: Vector2 = profile[mini(index + 1, n - 1)]
	var tangent := Vector2((next.x - prev.x) * half_width, (next.y - prev.y) * height)
	if tangent.length_squared() < 0.000001:
		return Vector2(signf(profile[index].x), 0.0)
	# Rotate the tangent a quarter turn, then face it away from the centre.
	var nrm := Vector2(tangent.y, -tangent.x).normalized()
	if nrm.dot(Vector2(profile[index].x, 0.2)) < 0.0:
		nrm = -nrm
	return nrm

## Deterministic relief, always pushing OUTWARD so the smooth collider stays
## inside the mesh and nobody ever bounces off a wall they cannot see.
##
## Harmonics in the lap fraction, so the pattern meets itself at the start
## line instead of showing a seam, then quantised into terraces. The quantising
## is the part that matters: a smooth sum of sines gives rounded swells that
## read as sand dunes, while flat steps with sharp risers between them read as
## bedded rock - and the risers line up with the strata bands, because both are
## keyed to the same profile column.
static func relief(lap_fraction: float, col: int, amount: float) -> float:
	var r: float = lap_fraction * TAU
	var k := float(col)
	var h: float = 0.34 * sin(r * 3.0 + k * 1.73) 		+ 0.24 * sin(r * 7.0 - k * 0.91) 		+ 0.17 * sin(r * 13.0 + k * 2.61) 		+ 0.13 * sin(r * 23.0 + k * 4.10) 		+ 0.08 * sin(r * 41.0 - k * 5.30) 		+ 0.04 * sin(r * 73.0 + k * 8.10)
	return amount * terrace(0.5 + 0.5 * h, TERRACES, TERRACE_SHARPNESS)

## Quantises 0..1 into flat treads joined by short, steep risers.
static func terrace(v: float, steps: float, sharpness: float) -> float:
	var scaled: float = clampf(v, 0.0, 1.0) * steps
	var tread: float = floor(scaled)
	var within: float = scaled - tread
	# smoothstep over a narrow band leaves most of each step flat.
	var riser: float = smoothstep(0.5 - sharpness, 0.5 + sharpness, within)
	return (tread + riser) / steps

## Ragged skyline. Wall heights come off the track data as a smooth curve, and
## a smooth curve against the sky looks like a dune, not a cliff.
static func rim_jitter(lap_fraction: float) -> float:
	var r: float = lap_fraction * TAU
	var h: float = 0.50 * sin(r * 5.0 + 0.7) 		+ 0.28 * sin(r * 11.0 - 1.9) 		+ 0.14 * sin(r * 19.0 + 2.6) 		+ 0.08 * sin(r * 37.0 - 0.4)
	return 1.0 + RIM_RELIEF * terrace(0.5 + 0.5 * h, 5.0, 0.22) * 2.0 - RIM_RELIEF
