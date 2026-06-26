extends Node3D
## Dynamic monster spawning driven by the day/night cycle (see world.gd).
##
##   DAY   — quiet. Only the occasional slime wanders the wilds.
##   NIGHT — dangerous. Goblins, wolves and skeletons spawn often, up to a high cap.
##   EVIL SITES — cursed places (marked with a dark totem) that spew monsters at ALL
##                hours, day or night.
##
## Spawns appear in a ring around the player (out of the immediate view), never in
## the village, and are culled when they drift too far so counts stay bounded.

const SLIME := preload("res://scenes/enemies/slime.tscn")
const GOBLIN := preload("res://scenes/enemies/enemy.tscn")
const WOLF := preload("res://scenes/enemies/wolf.tscn")
const SKELETON := preload("res://scenes/enemies/skeleton.tscn")

const DAY_CAP := 3            # max wandering monsters during the day (slimes)
const NIGHT_CAP := 16         # max wandering monsters at night
const DAY_INTERVAL := 9.0     # seconds between day spawn attempts
const NIGHT_INTERVAL := 2.2   # seconds between night spawn attempts

const SPAWN_MIN_R := 26.0     # spawn ring around the player
const SPAWN_MAX_R := 46.0
const VILLAGE_SAFE := 36.0    # never spawn within this of the village (origin)
const CULL_R := 80.0          # despawn wanderers further than this from the player

# Cursed sites: always active. Each keeps a small horde nearby.
const EVIL_SITES := [
	Vector3(150, 0, 110),
	Vector3(-170, 0, 150),
	Vector3(80, 0, -180),
]
const EVIL_RADIUS := 26.0
const EVIL_CAP := 5           # monsters maintained per site
const EVIL_INTERVAL := 3.0

var _ambient: Array = []      # wandering monsters we spawned (day/night)
var _evil: Array = []         # monsters tied to the cursed sites
var _evil_sites: Array = []   # resolved site positions (flattened Y from the terrain)
var _timer := 4.0
var _evil_timer := 2.0
var _terrain
var _world


func _ready() -> void:
	_terrain = get_tree().get_first_node_in_group("terrain")
	_world = get_tree().get_first_node_in_group("world")
	# Prefer the terrain's flattened site positions (level pads); fall back to the
	# raw constants if the terrain isn't found.
	if _terrain != null and _terrain.has_method("evil_sites"):
		_evil_sites = _terrain.evil_sites()
	else:
		_evil_sites = EVIL_SITES
	_build_evil_markers()


func _process(delta: float) -> void:
	_ambient = _ambient.filter(func(e): return is_instance_valid(e))
	_evil = _evil.filter(func(e): return is_instance_valid(e))

	_timer -= delta
	if _timer <= 0.0:
		_timer = NIGHT_INTERVAL if _is_night() else DAY_INTERVAL
		_ambient_spawn()

	_evil_timer -= delta
	if _evil_timer <= 0.0:
		_evil_timer = EVIL_INTERVAL
		_evil_spawn()

	_cull()


func _is_night() -> bool:
	return _world != null and _world.has_method("is_night") and _world.is_night()


# --- Wandering day/night spawns ---------------------------------------------

func _ambient_spawn() -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	var night := _is_night()
	var cap := NIGHT_CAP if night else DAY_CAP
	if _ambient.size() >= cap:
		return
	var scene: PackedScene = _pick_scene(night)
	var pos := _ring_pos(player.global_position)
	if pos == Vector3.INF:
		return
	var e := _spawn_at(scene, pos)
	if e != null:
		_ambient.append(e)


## Day: only slimes (the rare wandering critter). Night: a hostile mix.
func _pick_scene(night: bool) -> PackedScene:
	if not night:
		return SLIME
	var r := randf()
	if r < 0.34:
		return GOBLIN
	elif r < 0.6:
		return SKELETON
	elif r < 0.82:
		return WOLF
	return SLIME


## A random point in the spawn ring around `center`, skipping the village. Returns
## Vector3.INF if it couldn't find a spot outside the safe zone.
func _ring_pos(center: Vector3) -> Vector3:
	for attempt in range(6):
		var ang := randf() * TAU
		var r := randf_range(SPAWN_MIN_R, SPAWN_MAX_R)
		var x := center.x + cos(ang) * r
		var z := center.z + sin(ang) * r
		if Vector2(x, z).length() < VILLAGE_SAFE:
			continue
		return Vector3(x, _ground(x, z) + 1.0, z)
	return Vector3.INF


# --- Cursed-site spawns (always active) -------------------------------------

func _evil_spawn() -> void:
	for site in _evil_sites:
		var near := 0
		for e in _evil:
			if e.global_position.distance_to(site) < EVIL_RADIUS * 1.5:
				near += 1
		if near >= EVIL_CAP:
			continue
		var ang := randf() * TAU
		var r := randf_range(4.0, EVIL_RADIUS)
		var x: float = site.x + cos(ang) * r
		var z: float = site.z + sin(ang) * r
		var e := _spawn_at(_pick_scene(true), Vector3(x, _ground(x, z) + 1.0, z))
		if e != null:
			_evil.append(e)


func _build_evil_markers() -> void:
	for site in _evil_sites:
		var marker := Node3D.new()
		marker.position = Vector3(site.x, _ground(site.x, site.z), site.z)
		add_child(marker)
		# A dark stone totem.
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.1, 0.08, 0.1)
		stone.roughness = 1.0
		var pillar := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.5
		pm.bottom_radius = 0.8
		pm.height = 3.2
		pillar.mesh = pm
		pillar.material_override = stone
		pillar.position = Vector3(0, 1.6, 0)
		marker.add_child(pillar)
		# An ominous red glow.
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.9, 0.1, 0.1)
		glow.emission_enabled = true
		glow.emission = Color(0.9, 0.1, 0.1)
		glow.emission_energy_multiplier = 4.0
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		orb.mesh = sm
		orb.material_override = glow
		orb.position = Vector3(0, 3.4, 0)
		marker.add_child(orb)
		var light := OmniLight3D.new()
		light.light_color = Color(0.9, 0.15, 0.12)
		light.light_energy = 2.5
		light.omni_range = 14.0
		light.shadow_enabled = false
		light.position = Vector3(0, 3.4, 0)
		marker.add_child(light)


# --- Shared helpers ----------------------------------------------------------

func _spawn_at(scene: PackedScene, pos: Vector3) -> Node3D:
	if scene == null:
		return null
	var e: Node3D = scene.instantiate()
	add_child(e)
	e.global_position = pos
	return e


func _ground(x: float, z: float) -> float:
	if _terrain != null and _terrain.has_method("height_at"):
		return _terrain.height_at(x, z)
	return 0.0


## Free wanderers that have drifted far from the player (keeps counts in check).
## Cursed-site monsters are left alone — they belong to their totem.
func _cull() -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	for e in _ambient:
		if is_instance_valid(e) and e.global_position.distance_to(player.global_position) > CULL_R:
			e.queue_free()
