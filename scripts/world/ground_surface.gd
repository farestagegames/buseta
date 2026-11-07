class_name GroundSurface
extends RefCounted
## Answers "how high is the ground here?" for physics and for the world builder.
## Terrain height is smooth hills. Full height adds kerbs and road features that
## only wheels feel. With nothing added it is a flat plane.

const KERB_HEIGHT := 0.12
const KERB_RAMP := 0.25
const PAVEMENT_WIDTH := 3.0

## Eastward from this line the ground falls to the sea. Far away means no coast.
const NO_COAST := INF
const BEACH_DROP := 1.2
const SEA_LEVEL := -0.6

var hills: Array[Dictionary] = [] ## position: Vector2, radius: float, height: float
var coast_x: float = NO_COAST ## Where the sand starts.
var beach_width: float = 40.0
var features: Array[Dictionary] = [] ## See add_speed_bump and add_pothole.
var network: RoadNetwork = null


func add_hill(position: Vector2, radius: float, height: float) -> void:
	hills.append({"position": position, "radius": radius, "height": height})


## A bump across the road. direction is the way traffic crosses it.
func add_speed_bump(position: Vector2, direction: Vector2, half_length: float, half_width: float, height: float) -> void:
	features.append({"kind": "bump", "position": position, "direction": direction.normalized(),
		"half_length": half_length, "half_width": half_width, "height": height})


func add_pothole(position: Vector2, radius: float, depth: float) -> void:
	features.append({"kind": "pothole", "position": position, "radius": radius, "depth": depth})


func terrain_height(point: Vector2) -> float:
	var total := 0.0
	for hill: Dictionary in hills:
		var reach: float = point.distance_to(hill["position"]) / float(hill["radius"])
		if reach < 1.0:
			var bell := cos(reach * PI / 2.0)
			total += float(hill["height"]) * bell * bell
	return total - beach_share(point) * BEACH_DROP


## 0 inland, rising to 1 at the waterline.
func beach_share(point: Vector2) -> float:
	if coast_x == NO_COAST or point.x <= coast_x:
		return 0.0
	return minf((point.x - coast_x) / beach_width, 1.5)


## Height a wheel rides on at this point.
func height_at(point: Vector2) -> float:
	return terrain_height(point) + detail_height(point)


## Kerbs, bumps and potholes only, without the hills.
func detail_height(point: Vector2) -> float:
	return _kerb_height(point) + _feature_height(point)


func _kerb_height(point: Vector2) -> float:
	if network == null:
		return 0.0
	var outside := network.edge_distance(point)
	if outside <= 0.0:
		return 0.0
	if outside < KERB_RAMP:
		return KERB_HEIGHT * outside / KERB_RAMP
	if outside < PAVEMENT_WIDTH:
		return KERB_HEIGHT
	if outside < PAVEMENT_WIDTH + KERB_RAMP:
		return KERB_HEIGHT * (PAVEMENT_WIDTH + KERB_RAMP - outside) / KERB_RAMP
	return 0.0


func _feature_height(point: Vector2) -> float:
	var total := 0.0
	for feature: Dictionary in features:
		var offset: Vector2 = point - feature["position"]
		if feature["kind"] == "bump":
			var direction: Vector2 = feature["direction"]
			var along := absf(offset.dot(direction))
			var across := absf(offset.cross(direction))
			var half_length: float = feature["half_length"]
			if along < half_length and across < float(feature["half_width"]):
				total += float(feature["height"]) * cos(along / half_length * PI / 2.0)
		else:
			var radius: float = feature["radius"]
			var distance := offset.length()
			if distance < radius:
				total -= float(feature["depth"]) * cos(distance / radius * PI / 2.0)
	return total
