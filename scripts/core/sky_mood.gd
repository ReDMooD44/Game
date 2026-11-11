class_name SkyMood
extends RefCounted
## One source of truth for the light. The canyon shades itself from these
## numbers on the CPU, the sky and the real sun are built from them too, so
## the baked rock and the lit ships agree about where the sun is.
##
## Late afternoon, low and raking. A canyon lit from overhead is a grey trench;
## everything that makes one photograph well - the hot upper wall, the shadow
## line partway down, the warm bounce in the slot - comes from a low sun.

## Degrees. -x is elevation above the horizon, y is azimuth.
const ELEVATION := 24.0
const AZIMUTH := 34.0

const SUN := Color(1.00, 0.86, 0.66)       ## direct, warm from the long path
const SUN_ENERGY := 1.50
const SKY := Color(0.46, 0.60, 0.86)       ## cool fill from the strip of sky
const SKY_ENERGY := 0.58
## Light that has already hit the sunlit wall once. This is the colour that
## fills the shadow side of a real slot canyon, and it is the whole trick.
const BOUNCE := Color(1.00, 0.52, 0.24)
const BOUNCE_ENERGY := 1.10

const HAZE := Color(0.82, 0.68, 0.56)      ## dust in the air at distance
const SKY_TOP := Color(0.11, 0.28, 0.62)
const SKY_HORIZON := Color(0.74, 0.70, 0.66)
const GROUND_HORIZON := Color(0.62, 0.48, 0.38)
const GROUND_BOTTOM := Color(0.34, 0.22, 0.16)

static func euler() -> Vector3:
	return Vector3(-ELEVATION, AZIMUTH, 0.0)

## Unit vector pointing AT the sun, which is what shading maths wants.
static func to_sun() -> Vector3:
	var b := Basis.from_euler(Vector3(deg_to_rad(-ELEVATION), deg_to_rad(AZIMUTH), 0.0))
	# A DirectionalLight3D throws light along its local -Z.
	return (b * Vector3.BACK).normalized()
