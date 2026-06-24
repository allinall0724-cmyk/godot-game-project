extends Node3D
## Builds a simple representative STRUCTURE at every WorldLocations landmark (city,
## fortress, castle, capital, graveyard, dragon dungeon, forest) out of low-poly
## primitives, sitting on the terrain. Also drives DISCOVERY: when the player gets
## close to a landmark for the first time, it tells the Quests autoload (which shows a
## "Discovered: X" toast and advances any "reach" quest pointing at that place).
##
## Everything is data-driven from world_locations.gd — add a landmark there and it gets
## a marker on the minimap AND a structure here (kinds without a builder are skipped).

const Locations = preload("res://scenes/world/world_locations.gd")
const NPCs = preload("res://scenes/world/world_npcs.gd")

const VILLAGER := preload("res://scenes/characters/villager.tscn")
const SPECIAL := preload("res://scenes/characters/special_npc.tscn")
const E_GOBLIN := preload("res://scenes/enemies/enemy.tscn")
const E_SKELETON := preload("res://scenes/enemies/skeleton.tscn")
const E_SLIME := preload("res://scenes/enemies/slime.tscn")
const E_WOLF := preload("res://scenes/enemies/wolf.tscn")

const DISCOVER_RADIUS := 32.0   # how close counts as "arriving" at a landmark
const CHECK_INTERVAL := 0.4     # seconds between proximity checks
const FLAVOR_PER_LOCATION := 3  # ordinary themed wanderers per landmark

var _terrain: Node = null
var _mats := {}                 # color -> StandardMaterial3D (shared, fewer materials)
var _check_t := 0.0


func _ready() -> void:
	_terrain = get_tree().get_first_node_in_group("terrain")
	for loc in Locations.ALL:
		_build(str(loc["kind"]), loc["pos"])
		_spawn_flavor(loc)
		_spawn_enemies(loc)
	for spec in NPCs.specials():
		_spawn_special(spec)


func _build(kind: String, c: Vector2) -> void:
	match kind:
		"city": _build_city(c)
		"fortress": _build_fortress(c)
		"castle": _build_castle(c)
		"kingdom": _build_capital(c)
		"undead": _build_graveyard(c)
		"dragon": _build_dragon_den(c)
		"forest": _build_forest(c)
		# "village" (home) is already hand-placed at the origin — nothing to build.


# --- Proximity / discovery ---------------------------------------------------

func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_INTERVAL
	var player = get_tree().get_first_node_in_group("local_player")
	var quests = get_node_or_null("/root/Quests")
	if player == null or quests == null:
		return
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for loc in Locations.ALL:
		if pp.distance_to(loc["pos"]) < DISCOVER_RADIUS:
			quests.notify_location_reached(str(loc["name"]))


# --- People & enemies --------------------------------------------------------

## Ordinary themed wanderers (their look matches the place).
func _spawn_flavor(loc: Dictionary) -> void:
	var palette: Dictionary = NPCs.flavor_palette(str(loc["kind"]))
	if palette.is_empty():
		return
	var rng := _rng(loc["pos"] + Vector2(11, 0))
	for i in range(FLAVOR_PER_LOCATION):
		var p: Vector2 = loc["pos"] + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		var npc: Node3D = VILLAGER.instantiate()
		add_child(npc)
		npc.global_position = Vector3(p.x, _ground(p.x, p.y) + 1.2, p.y)
		var h = npc.get_node_or_null("Humanoid")
		if h != null:
			# Location palette with small per-NPC variation so they're not identical.
			h.skin_color = palette.get("skin", h.skin_color)
			h.tunic_color = (palette.get("tunic", h.tunic_color) as Color).lightened(rng.randf_range(-0.1, 0.15))
			h.hair_color = palette.get("hair", h.hair_color)
			h.hair_style = rng.randi() % 3
			h.hat_style = int(palette.get("hat", 0))


## A small group of the location's themed enemy (so quests there are completable).
func _spawn_enemies(loc: Dictionary) -> void:
	var kind := str(loc["kind"])
	var etype := NPCs.enemy_for(kind)
	var count := NPCs.enemy_count_for(kind)
	if count <= 0:
		return
	var rng := _rng(loc["pos"] + Vector2(0, 23))
	for i in range(count):
		var p: Vector2 = loc["pos"] + Vector2(rng.randf_range(-26, 26), rng.randf_range(-26, 26))
		var inst: Node3D = _enemy_scene(etype).instantiate()
		# Code-built orcs: reuse the goblin scene but make them tanky and tag the type.
		if etype == "orc":
			inst.enemy_type = "orc"
			inst.max_health = 12
			inst.chase_speed = 2.0
			inst.attack_damage = 15
			inst.xp_reward = 14
		add_child(inst)
		inst.global_position = Vector3(p.x, _ground(p.x, p.y) + 1.5, p.y)


func _enemy_scene(etype: String) -> PackedScene:
	match etype:
		"skeleton": return E_SKELETON
		"slime": return E_SLIME
		"wolf": return E_WOLF
		_: return E_GOBLIN   # goblin and (overridden) orc both use the base enemy scene


## One of the two special NPCs (quest giver + shop), built from world_npcs data.
func _spawn_special(spec: Dictionary) -> void:
	var npc: Node3D = SPECIAL.instantiate()
	npc.npc_id = str(spec["id"])
	npc.display_name = str(spec["name"])
	npc.quest_id = str(spec["quest_id"])
	npc.role = str(spec["role"])
	npc.robe = spec["robe"]
	npc.shop = spec["shop"]
	npc.palette = NPCs.flavor_palette(str(spec["kind"]))
	add_child(npc)
	var p: Vector2 = spec["pos"]
	npc.global_position = Vector3(p.x, _ground(p.x, p.y) + 1.2, p.y)


# --- Landmark builders -------------------------------------------------------

## A market town: a cluster of gabled buildings of varying size around a taller hall.
func _build_city(c: Vector2) -> void:
	var rng := _rng(c)
	var wall := Color(0.78, 0.72, 0.6)
	var roof := Color(0.5, 0.28, 0.2)
	# Central market hall.
	_building(c, 8.0, 7.0, 10.0, wall, roof, 0.0)
	# Surrounding houses in a loose ring.
	for i in range(8):
		var a := TAU * float(i) / 8.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(13.0, 22.0)
		var p := c + Vector2(cos(a), sin(a)) * d
		var ww := rng.randf_range(4.0, 6.5)
		var hh := rng.randf_range(3.5, 6.0)
		_building(p, ww, hh, ww * rng.randf_range(1.0, 1.6), wall, roof, rng.randf() * TAU)


## A square keep ringed by a curtain wall with round corner towers and a gate gap.
func _build_fortress(c: Vector2) -> void:
	var stone := Color(0.6, 0.6, 0.64)
	var roof := Color(0.35, 0.3, 0.4)
	var s := 16.0   # half-extent of the wall ring
	var wh := 6.0   # wall height
	# Four walls, with a gate gap in the south (+Z) wall.
	_box(Vector2(c.x, c.y - s), 2.0 * s, wh, 1.6, stone)           # north
	_box(Vector2(c.x - s, c.y), 1.6, wh, 2.0 * s, stone)           # west
	_box(Vector2(c.x + s, c.y), 1.6, wh, 2.0 * s, stone)           # east
	_box(Vector2(c.x - s * 0.6, c.y + s), s * 0.8, wh, 1.6, stone) # south-left (gate gap between)
	_box(Vector2(c.x + s * 0.6, c.y + s), s * 0.8, wh, 1.6, stone) # south-right
	# Corner towers.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tp := c + Vector2(sx * s, sz * s)
			_cyl(tp, 2.6, 2.6, wh + 2.5, stone)
			_cone(tp, 3.1, 3.5, roof, wh + 2.5)
	# Inner keep.
	_box(c, 9.0, 9.0, 9.0, stone)
	_battlements(c, 4.5, 4.5, 9.0, stone)


## A raised stone castle: central keep with battlements + four round corner towers.
func _build_castle(c: Vector2) -> void:
	var stone := Color(0.66, 0.66, 0.7)
	var roof := Color(0.45, 0.3, 0.55)
	# Wide low base/motte.
	_box(c, 30.0, 2.0, 30.0, Color(0.5, 0.5, 0.52))
	var keep_h := 16.0
	_box(c, 11.0, keep_h, 11.0, stone, 2.0)
	_battlements(c, 5.5, 5.5, keep_h, stone, 2.0)
	# Corner towers with conical roofs.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tp := c + Vector2(sx * 11.0, sz * 11.0)
			_cyl(tp, 3.0, 3.0, keep_h * 0.85, stone, 2.0)
			_cone(tp, 3.6, 5.0, roof, 2.0 + keep_h * 0.85)


## The capital: a grand central spire surrounded by halls inside a walled ring.
func _build_capital(c: Vector2) -> void:
	var stone := Color(0.82, 0.8, 0.78)
	var gold := Color(0.85, 0.7, 0.3)
	var roof := Color(0.3, 0.4, 0.6)
	# Outer wall ring with towers.
	var s := 30.0
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var p := c + Vector2(cos(a), sin(a)) * s
		_box(p, 6.0, 5.0, 2.0, stone, 0.0, a)
	for i in range(6):
		var a2 := TAU * float(i) / 6.0
		var tp := c + Vector2(cos(a2), sin(a2)) * s
		_cyl(tp, 2.4, 2.4, 8.0, stone)
		_cone(tp, 2.9, 3.0, roof, 8.0)
	# Grand central spire.
	_cyl(c, 7.0, 8.0, 22.0, stone)
	_cone(c, 7.6, 12.0, gold, 22.0)
	# A few inner halls.
	var rng := _rng(c)
	for i in range(5):
		var a3 := TAU * float(i) / 5.0 + 0.3
		var p3 := c + Vector2(cos(a3), sin(a3)) * 15.0
		_building(p3, 6.0, 6.0, 8.0, stone, roof, a3)


## A graveyard: tilted tombstones, a crypt, bone piles and a couple of dead trees.
func _build_graveyard(c: Vector2) -> void:
	var rng := _rng(c)
	var stone := Color(0.5, 0.52, 0.5)
	var bone := Color(0.85, 0.83, 0.74)
	# Crypt.
	_box(c, 8.0, 5.0, 9.0, Color(0.42, 0.44, 0.43))
	_box(c + Vector2(0, 4.8), 3.0, 3.4, 1.0, Color(0.1, 0.1, 0.12))  # dark doorway
	# Scattered tombstones.
	for i in range(16):
		var p := c + Vector2(rng.randf_range(-22, 22), rng.randf_range(-22, 22))
		if p.distance_to(c) < 6.0:
			continue
		var m := _box(p, rng.randf_range(0.8, 1.4), rng.randf_range(1.2, 2.0), 0.3, stone)
		m.rotation.z = rng.randf_range(-0.18, 0.18)  # leaning, weathered
		m.rotation.y = rng.randf() * TAU
	# Bone piles.
	for i in range(6):
		var bp := c + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		_cyl(bp, 0.15, 0.15, rng.randf_range(0.8, 1.4), bone, 0.0, rng.randf_range(0.0, 1.2))
	# Dead trees (bare trunks with a few stubby branches).
	for i in range(3):
		var tp := c + Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18))
		var trunk := _cyl(tp, 0.25, 0.4, 5.0, Color(0.25, 0.22, 0.2))
		for b in range(3):
			var br := _box(tp, 0.2, 0.2, 2.0, Color(0.25, 0.22, 0.2), 3.0 + b * 0.6, rng.randf() * TAU)
			br.rotation.x = rng.randf_range(-0.6, -1.0)


## The dragon's lair: a dark stone arch set against the mountain, ribs and a skull.
func _build_dragon_den(c: Vector2) -> void:
	var dark := Color(0.22, 0.2, 0.22)
	var bone := Color(0.86, 0.84, 0.76)
	# Arched entrance: two pillars + a lintel + a black void behind.
	_box(c + Vector2(-3.0, 0), 2.0, 8.0, 2.0, dark)
	_box(c + Vector2(3.0, 0), 2.0, 8.0, 2.0, dark)
	_box(c, 9.0, 2.0, 2.0, dark, 8.0)                       # lintel across the top
	_box(c + Vector2(0, -1.5), 5.0, 7.0, 0.5, Color(0.03, 0.03, 0.04))  # the dark maw
	# Ribcage of a fallen beast framing the approach.
	for i in range(5):
		var off := float(i - 2) * 3.0
		for sx in [-1.0, 1.0]:
			var rp := c + Vector2(sx * 6.0, 9.0 + off)
			var rib := _cyl(rp, 0.22, 0.22, 6.0, bone)
			rib.rotation.z = sx * 0.7
	# A great skull to one side.
	_sphere(c + Vector2(-9.0, 4.0), 1.8, bone)
	for hx in [-1.0, 1.0]:
		var horn := _cone(c + Vector2(-9.0 + hx * 1.0, 4.0), 0.4, 2.4, bone, 2.6)
		horn.rotation.z = hx * 0.5


## A dense stand of trees (reuses the existing tree prop).
func _build_forest(c: Vector2) -> void:
	var rng := _rng(c)
	var tree_scene: PackedScene = load("res://scenes/props/tree.tscn")
	if tree_scene == null:
		return
	for i in range(28):
		var p := c + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
		var inst: Node3D = tree_scene.instantiate()
		add_child(inst)
		inst.global_position = Vector3(p.x, _ground(p.x, p.y), p.y)
		inst.rotation.y = rng.randf() * TAU
		inst.scale = Vector3.ONE * rng.randf_range(0.85, 1.4)


# --- Primitive helpers -------------------------------------------------------

## A house = a box body with a gabled (prism) roof on top.
func _building(c: Vector2, w: float, h: float, d: float, wall: Color, roof: Color, rot: float) -> void:
	var body := _box(c, w, h, d, wall, 0.0, rot)
	var pm := PrismMesh.new()
	pm.size = Vector3(w * 1.05, h * 0.6, d * 1.05)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = _mat(roof)
	mi.position = body.position + Vector3(0, h * 0.5 + h * 0.3, 0)
	mi.rotation.y = rot
	add_child(mi)


## A box whose BOTTOM rests on the terrain at (c.x, c.z). y_off lifts it further.
func _box(c: Vector2, w: float, h: float, d: float, color: Color, y_off := 0.0, rot := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = Vector3(c.x, _ground(c.x, c.y) + h * 0.5 + y_off, c.y)
	mi.rotation.y = rot
	add_child(mi)
	return mi


## A vertical cylinder/cone resting on the terrain (top_r = 0 makes a cone).
func _cyl(c: Vector2, top_r: float, bot_r: float, h: float, color: Color, y_off := 0.0, rot := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = Vector3(c.x, _ground(c.x, c.y) + h * 0.5 + y_off, c.y)
	mi.rotation.y = rot
	add_child(mi)
	return mi


func _cone(c: Vector2, r: float, h: float, color: Color, y_off := 0.0) -> MeshInstance3D:
	return _cyl(c, 0.0, r, h, color, y_off)


func _sphere(c: Vector2, r: float, color: Color) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(color)
	mi.position = Vector3(c.x, _ground(c.x, c.y) + r, c.y)
	add_child(mi)
	return mi


## A ring of small merlons sitting ON TOP of a square keep (half = keep half-width,
## top_h = keep height, y_off = the keep's own base lift). Merlon bases rest at the
## keep's roof line (ground + y_off + top_h).
func _battlements(c: Vector2, half: float, _half2: float, top_h: float, color: Color, y_off := 0.0) -> void:
	var lift := y_off + top_h
	var n := 4
	for i in range(n + 1):
		var t := -half + 2.0 * half * float(i) / n
		_box(c + Vector2(t, -half), 0.8, 1.2, 0.8, color, lift)
		_box(c + Vector2(t, half), 0.8, 1.2, 0.8, color, lift)
		_box(c + Vector2(-half, t), 0.8, 1.2, 0.8, color, lift)
		_box(c + Vector2(half, t), 0.8, 1.2, 0.8, color, lift)


func _ground(x: float, z: float) -> float:
	if _terrain != null and _terrain.has_method("height_at"):
		return _terrain.height_at(x, z)
	return 0.0


func _mat(color: Color) -> StandardMaterial3D:
	if _mats.has(color):
		return _mats[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	_mats[color] = m
	return m


## Deterministic RNG seeded by position, so each landmark looks the same every run.
func _rng(c: Vector2) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x) * 73856093 ^ int(c.y) * 19349663
	return rng
