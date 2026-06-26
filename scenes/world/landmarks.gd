extends Node3D
## Hidden mini-locations scattered across the wilds — standing stones, an abandoned
## camp, a forgotten shrine, an old well, forgotten graves, a fairy ring. Each is
## built procedurally in a fitting biome (some tucked into the dark forest so they're
## easy to miss) and carries a Landmark you can "search" once for a small reward.
## They are deliberately NOT drawn on the minimap.

const LANDMARK := preload("res://scenes/props/landmark.gd")

# Biome ids — must match terrain.gd's B_* constants.
const B_MEADOW := 0
const B_PLAINS := 1
const B_FOREST := 2
const B_DARK := 3

const MAP_EXTENT := 215.0   # keep within the terrain bounds (terrain SIZE/2 = 250)
const MIN_SEP := 55.0       # spacing between landmarks
const VILLAGE_CLEAR := 50.0 # keep clear of the village at the origin

# theme, display name, preferred biome, rewards, gives an item?, flavour line.
const SPECS := [
	{"theme": "stones", "name": "Standing Stones", "biome": B_PLAINS, "coins": 35, "xp": 20, "item": false,
		"flavor": "the old stones thrum with power."},
	{"theme": "camp", "name": "Abandoned Camp", "biome": B_FOREST, "coins": 25, "xp": 12, "item": false,
		"flavor": "you scavenge the cold campsite."},
	{"theme": "shrine", "name": "Forgotten Shrine", "biome": B_DARK, "coins": 45, "xp": 30, "item": true,
		"flavor": "something old stirs as you approach."},
	{"theme": "well", "name": "Old Well", "biome": B_PLAINS, "coins": 30, "xp": 10, "item": false,
		"flavor": "you fish a few coins from the deep."},
	{"theme": "graves", "name": "Forgotten Graves", "biome": B_DARK, "coins": 40, "xp": 25, "item": true,
		"flavor": "the graves give up a glint of treasure."},
	{"theme": "fairy", "name": "Fairy Ring", "biome": B_FOREST, "coins": 20, "xp": 18, "item": false,
		"flavor": "stepping inside, you feel oddly lucky."},
]

var _terrain
var _rng := RandomNumberGenerator.new()
var _placed: Array[Vector2] = []


func _ready() -> void:
	_terrain = get_tree().get_first_node_in_group("terrain")
	if _terrain == null:
		return
	_rng.seed = 90125
	for spec in SPECS:
		var spot := _find_spot(int(spec["biome"]))
		if spot == Vector3.INF:
			continue
		_build_landmark(spec, spot)


## Find ground in the preferred biome (falling back to anywhere), clear of the
## village, the cursed sites and other landmarks. Returns Vector3.INF if none.
func _find_spot(preferred: int) -> Vector3:
	for require_biome in [true, false]:
		for attempt in range(800):
			var x := _rng.randf_range(-MAP_EXTENT, MAP_EXTENT)
			var z := _rng.randf_range(-MAP_EXTENT, MAP_EXTENT)
			var p := Vector2(x, z)
			if p.length() < VILLAGE_CLEAR:
				continue
			var h: float = _terrain.height_at(x, z)
			if h < -1.0 or h > 20.0:           # walkable lowland only
				continue
			if require_biome and _terrain.biome_at(x, z) != preferred:
				continue
			if _too_close(p):
				continue
			_placed.append(p)
			return Vector3(x, h, z)
	return Vector3.INF


func _too_close(p: Vector2) -> bool:
	for q in _placed:
		if p.distance_to(q) < MIN_SEP:
			return true
	if _terrain.has_method("evil_sites"):
		for s in _terrain.evil_sites():
			if p.distance_to(Vector2(s.x, s.z)) < 35.0:
				return true
	return false


func _build_landmark(spec: Dictionary, spot: Vector3) -> void:
	var root := Node3D.new()
	root.name = str(spec["name"]).replace(" ", "")
	root.position = spot
	add_child(root)
	match str(spec["theme"]):
		"stones": _build_stones(root)
		"camp": _build_camp(root)
		"shrine": _build_shrine(root)
		"well": _build_well(root)
		"graves": _build_graves(root)
		"fairy": _build_fairy(root)
	# The interactable in the middle.
	var lm := LANDMARK.new()
	lm.landmark_name = str(spec["name"])
	lm.flavor = str(spec["flavor"])
	lm.reward_coins = int(spec["coins"])
	lm.reward_xp = int(spec["xp"])
	if bool(spec["item"]):
		lm.reward_item = ArmorCatalog.all_items().pick_random()
	root.add_child(lm)


# --- Themed builds -----------------------------------------------------------

func _build_stones(root: Node3D) -> void:
	var stone := _mat(Color(0.5, 0.5, 0.52))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		var pos := Vector3(cos(a) * 3.6, 1.3, sin(a) * 3.6)
		var b := _box(root, Vector3(0.7, 2.6, 0.45), pos, stone, true)
		b.rotation.y = -a
		b.rotation.x = _rng.randf_range(-0.06, 0.06)
	_box(root, Vector3(1.4, 0.7, 1.4), Vector3(0, 0.35, 0), _mat(Color(0.42, 0.42, 0.45)), true)


func _build_camp(root: Node3D) -> void:
	var stone := _mat(Color(0.45, 0.44, 0.42))
	for i in range(7):
		var a := TAU * float(i) / 7.0
		_box(root, Vector3(0.22, 0.18, 0.22), Vector3(cos(a) * 0.7, 0.09, sin(a) * 0.7), stone, false)
	# Crossed logs + embers.
	var wood := _mat(Color(0.32, 0.22, 0.13))
	var l1 := _cyl(root, 0.08, 0.9, Vector3(0, 0.12, 0), wood, false)
	l1.rotation = Vector3(PI * 0.5, 0.4, 0)
	var l2 := _cyl(root, 0.08, 0.9, Vector3(0, 0.18, 0), wood, false)
	l2.rotation = Vector3(PI * 0.5, -0.5, 0)
	var ember := _emis(Color(1.0, 0.45, 0.12), 4.0)
	_box(root, Vector3(0.4, 0.1, 0.4), Vector3(0, 0.08, 0), ember, false)
	_light(root, Vector3(0, 0.6, 0), Color(1.0, 0.5, 0.2), 1.6, 6.0)
	# Lean-to shelter.
	var cloth := _mat(Color(0.5, 0.42, 0.3))
	var lean := _box(root, Vector3(2.2, 0.1, 1.8), Vector3(2.2, 1.0, 0), cloth, false)
	lean.rotation.z = 0.7
	_cyl(root, 0.06, 1.6, Vector3(3.0, 0.8, 0.8), wood, false)
	_cyl(root, 0.06, 1.6, Vector3(3.0, 0.8, -0.8), wood, false)


func _build_shrine(root: Node3D) -> void:
	var stone := _mat(Color(0.3, 0.3, 0.34))
	_box(root, Vector3(1.8, 0.5, 1.8), Vector3(0, 0.25, 0), stone, true)
	_box(root, Vector3(0.6, 1.5, 0.6), Vector3(0, 1.25, 0), stone, true)
	# A dark idol with glowing eyes + an eerie light.
	var idol := _mat(Color(0.08, 0.07, 0.1))
	_box(root, Vector3(0.7, 0.7, 0.5), Vector3(0, 2.3, 0), idol, false)
	var eye := _emis(Color(0.7, 0.2, 0.9), 5.0)
	_box(root, Vector3(0.1, 0.08, 0.05), Vector3(-0.15, 2.4, -0.26), eye, false)
	_box(root, Vector3(0.1, 0.08, 0.05), Vector3(0.15, 2.4, -0.26), eye, false)
	_light(root, Vector3(0, 2.3, 0), Color(0.6, 0.2, 0.9), 2.0, 9.0)


func _build_well(root: Node3D) -> void:
	var stone := _mat(Color(0.48, 0.47, 0.45))
	for i in range(10):
		var a := TAU * float(i) / 10.0
		_box(root, Vector3(0.4, 0.7, 0.3), Vector3(cos(a) * 1.0, 0.45, sin(a) * 1.0), stone, true).rotation.y = -a
	var wood := _mat(Color(0.36, 0.24, 0.14))
	_cyl(root, 0.08, 1.8, Vector3(-1.0, 0.9, 0), wood, true)
	_cyl(root, 0.08, 1.8, Vector3(1.0, 0.9, 0), wood, true)
	var roof := _box(root, Vector3(2.6, 0.12, 1.4), Vector3(0, 1.9, 0), _mat(Color(0.4, 0.2, 0.15)), false)
	roof.rotation.x = 0.0
	_box(root, Vector3(0.4, 0.4, 0.4), Vector3(0, 1.2, 0), wood, false)   # bucket


func _build_graves(root: Node3D) -> void:
	var stone := _mat(Color(0.34, 0.35, 0.36))
	for i in range(5):
		var gx := _rng.randf_range(-2.4, 2.4)
		var gz := _rng.randf_range(-2.0, 2.0)
		var g := _box(root, Vector3(0.6, 0.9, 0.16), Vector3(gx, 0.45, gz), stone, true)
		g.rotation = Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(0, TAU), _rng.randf_range(-0.12, 0.12))
	# A leaning stone cross.
	var cross := Node3D.new()
	cross.position = Vector3(0, 0, 0)
	cross.rotation.z = 0.12
	root.add_child(cross)
	_box(cross, Vector3(0.2, 1.4, 0.2), Vector3(0, 0.7, 0), stone, false)
	_box(cross, Vector3(0.8, 0.2, 0.2), Vector3(0, 1.0, 0), stone, false)


func _build_fairy(root: Node3D) -> void:
	var stalk := _mat(Color(0.9, 0.88, 0.8))
	var cap := _mat(Color(0.75, 0.2, 0.2))
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var pos := Vector3(cos(a) * 2.0, 0, sin(a) * 2.0)
		_cyl(root, 0.05, 0.3, pos + Vector3(0, 0.15, 0), stalk, false)
		_sphere(root, 0.13, pos + Vector3(0, 0.32, 0), cap)
	_light(root, Vector3(0, 0.6, 0), Color(0.4, 0.9, 0.5), 1.2, 6.0)


# --- Mesh helpers ------------------------------------------------------------

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.92
	return m


func _emis(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		col.shape = bs
		body.add_child(col)
		body.position = pos
		parent.add_child(body)
	return mi


func _cyl(parent: Node3D, radius: float, h: float, pos: Vector3, mat: StandardMaterial3D, collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = radius
		cs.height = h
		col.shape = cs
		body.add_child(col)
		body.position = pos
		parent.add_child(body)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	parent.add_child(l)
