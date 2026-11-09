class_name Atmosphere
extends RefCounted
## The sky, fog and light for a time of day under some amount of cloud. Pure
## logic, so the look of a storm at sunset or at night can be tested.

## Brightness of a midday horizon. Storm grey is scaled to the time's own light,
## so a night storm stays dark and a sunset storm keeps some warmth.
const DAY_HORIZON_LUMA := 0.85
## Clouds this thick hide the sun's shadows, which also saves drawing them.
const OVERCAST := 0.6

var sky_top := Color.WHITE
var sky_horizon := Color.WHITE
var ground_bottom := Color.WHITE
var fog := Color.WHITE
var fog_scale: float = 1.0
var fog_extra: float = 0.0 ## Extra fog density on top of the graphics level's.
var ambient := Color.WHITE
var ambient_energy: float = 1.0
var sun_colour := Color.WHITE
var sun_energy: float = 1.0
var sun_rotation := Vector3.ZERO
var shadows: bool = true ## Off under heavy cloud, where nothing casts a hard shadow.
var shadow_strength: float = 1.0 ## Shadows fade as the clouds thicken, then go.


## cloud and rain run from 0 to 1. The sky follows the cloud; the haze the rain.
static func mix(time: TimeOfDay, settings: RainSettings, cloud: float, rain: float) -> Atmosphere:
	var air := Atmosphere.new()
	var light := clampf(time.sky_horizon.get_luminance() / DAY_HORIZON_LUMA, 0.08, 1.0)
	var grey := settings.storm_sky * light
	var turn := clampf(cloud, 0.0, 1.0) * settings.darken
	air.sky_top = time.sky_top.lerp(grey * 0.85, turn)
	air.sky_horizon = time.sky_horizon.lerp(grey, turn)
	air.ground_bottom = air.sky_horizon.darkened(0.6)
	air.fog = time.fog.lerp(grey * 1.05, clampf(cloud, 0.0, 1.0) * 0.8)
	air.fog_scale = time.fog_scale
	air.fog_extra = settings.fog_density * clampf(rain, 0.0, 1.0)
	air.ambient = time.ambient.lerp(Color(0.7, 0.75, 0.82) * maxf(light, 0.5), turn)
	air.ambient_energy = time.ambient_energy * (1.0 - 0.3 * clampf(cloud, 0.0, 1.0))
	air.sun_colour = time.sun_colour
	air.sun_energy = time.sun_energy * (1.0 - settings.sun_dim * clampf(cloud, 0.0, 1.0))
	air.sun_rotation = sun_rotation_for(time.sun_from, time.sun_elevation)
	air.shadows = time.shadows and cloud < OVERCAST
	air.shadow_strength = clampf(1.0 - cloud / OVERCAST, 0.0, 1.0)
	return air


## The sun shines from compass degrees sun_from (0 north, 90 east, where north is
## -Z and east +X) at elevation degrees above the horizon. A light points along its
## own -Z, so the rotation turns -Z to point away from the sun.
static func sun_rotation_for(sun_from: float, elevation: float) -> Vector3:
	return Vector3(-deg_to_rad(elevation), deg_to_rad(180.0 - sun_from), 0.0)
