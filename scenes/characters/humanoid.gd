extends Node3D
## Code-only blocky humanoid built from primitive meshes (no imported assets).
## Reused for the player (squire), villagers and enemies. Provides:
##   - per-instance colors (exported),
##   - a right-hand attach point (attach_to_hand) for held items,
##   - procedural walk animation (set move_speed each frame) + attack swing,
##   - apply_equipment(): visibly reflects equipped armor on the model.

@export var skin_color := Color(0.92, 0.76, 0.62)
@export var tunic_color := Color(0.30, 0.36, 0.50)
@export var shorts_color := Color(0.24, 0.22, 0.30)
@export var legs_color := Color(0.55, 0.55, 0.58)
@export var boot_color := Color(0.28, 0.18, 0.10)
@export var hair_color := Color(0.30, 0.18, 0.06)
## 0 = short messy, 1 = longer, 2 = spiky, 3 = bald/none. Set per-character.
@export var hair_style := 0:
	set(value):
		hair_style = value
		if is_node_ready():
			_build_hair()
## Race/feature flags (built procedurally) so one model covers many character types.
@export var ear_style := 0:        # 0 = round, 1 = pointed (goblins / orcs / elves)
	set(value):
		ear_style = value
		if is_node_ready():
			_build_features()
@export var tusks := false:        # orc / troll lower tusks
	set(value):
		tusks = value
		if is_node_ready():
			_build_features()
@export var bulk := 1.0            # body width (orc/troll > 1, goblin/skeleton < 1)
@export var ear_size := 1.0        # bigger goblin ears, etc.
@export var tusk_size := 1.0       # bigger orc tusks
@export var hat_style := 0:        # 0 = none, 1 = straw hat (villagers)
	set(value):
		hat_style = value
		if is_node_ready():
			_build_hat()

const WALK_FREQ := 9.0
const WALK_MAX_AMP := 0.7
const REF_SPEED := 5.0
const ATTACK_ANIM_TIME := 0.28

@onready var arm_l: Node3D = $ArmL_Pivot
@onready var arm_r: Node3D = $ArmR_Pivot
@onready var leg_l: Node3D = $LegL_Pivot
@onready var leg_r: Node3D = $LegR_Pivot
@onready var hand: Node3D = $ArmR_Pivot/Hand
@onready var helmet_node: Node3D = $Head/Helmet
@onready var chest_node: Node3D = $ChestArmor
@onready var greave_l: MeshInstance3D = $LegL_Pivot/GreaveL
@onready var greave_r: MeshInstance3D = $LegR_Pivot/GreaveR
@onready var hair_node: Node3D = $Hair

const ROLL_DUR := 0.45

var move_speed := 0.0
var _phase := 0.0
var _attack_time := 0.0
var _attack_total := ATTACK_ANIM_TIME
var _attack_dir := "stab"
var _roll_time := 0.0


func _ready() -> void:
	_paint("Torso", tunic_color)
	_paint("Shorts", shorts_color)
	_paint("Head", skin_color)
	_build_hair()
	_paint("ArmL_Pivot/ArmL", skin_color)
	_paint("ArmR_Pivot/ArmR", skin_color)
	_paint("LegL_Pivot/LegL", legs_color)
	_paint("LegR_Pivot/LegR", legs_color)
	_paint("LegL_Pivot/BootL", boot_color)
	_paint("LegR_Pivot/BootR", boot_color)
	# Armor hidden until equipped.
	helmet_node.visible = false
	chest_node.visible = false
	greave_l.visible = false
	greave_r.visible = false
	# Procedural extras (hands, ears/tusks, hat, bulk).
	_apply_bulk()
	_build_hands()
	_build_features()
	_build_hat()


## Build hair from many small tufts (messy throughout, not a solid block). The
## chosen hair_style and slight per-tuft random tilt make characters look distinct.
func _build_hair() -> void:
	for c in hair_node.get_children():
		c.queue_free()
	var tufts := _hair_tufts(hair_style)
	var i := 0
	for t in tufts:
		var tuft := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = t["size"]
		tuft.mesh = bm
		tuft.position = t["pos"]
		tuft.rotation = Vector3(randf_range(-0.25, 0.25), randf_range(-0.5, 0.5), randf_range(-0.25, 0.25))
		var shade: Color = hair_color if i % 2 == 0 else hair_color.darkened(0.22)
		var m := StandardMaterial3D.new()
		m.albedo_color = shade
		tuft.material_override = m
		hair_node.add_child(tuft)
		i += 1


## Tuft layouts per style. Positions are in the humanoid's local space (head is
## centered near y=0.62, radius ~0.17).
func _hair_tufts(style: int) -> Array:
	if style == 3:
		return []  # bald (skeletons / some helmets)
	# Scalp cap shared by short/long styles.
	var cap := [
		{"pos": Vector3(0.0, 0.79, -0.02), "size": Vector3(0.13, 0.12, 0.13)},
		{"pos": Vector3(0.1, 0.77, 0.02), "size": Vector3(0.11, 0.12, 0.11)},
		{"pos": Vector3(-0.1, 0.77, 0.02), "size": Vector3(0.11, 0.12, 0.11)},
		{"pos": Vector3(0.07, 0.75, -0.12), "size": Vector3(0.1, 0.12, 0.1)},
		{"pos": Vector3(-0.07, 0.75, -0.12), "size": Vector3(0.1, 0.12, 0.1)},
		{"pos": Vector3(0.09, 0.74, 0.12), "size": Vector3(0.1, 0.11, 0.1)},
		{"pos": Vector3(-0.09, 0.74, 0.12), "size": Vector3(0.1, 0.11, 0.1)},
		{"pos": Vector3(0.15, 0.72, 0.0), "size": Vector3(0.09, 0.11, 0.11)},
		{"pos": Vector3(-0.15, 0.72, 0.0), "size": Vector3(0.09, 0.11, 0.11)},
		{"pos": Vector3(0.0, 0.72, 0.15), "size": Vector3(0.12, 0.11, 0.1)},
	]
	if style == 2:
		# Spiky: fewer, taller tufts pointing up.
		return [
			{"pos": Vector3(0.0, 0.85, -0.02), "size": Vector3(0.09, 0.24, 0.09)},
			{"pos": Vector3(0.1, 0.83, 0.0), "size": Vector3(0.08, 0.2, 0.08)},
			{"pos": Vector3(-0.1, 0.83, 0.0), "size": Vector3(0.08, 0.2, 0.08)},
			{"pos": Vector3(0.05, 0.83, -0.11), "size": Vector3(0.08, 0.2, 0.08)},
			{"pos": Vector3(-0.05, 0.83, -0.11), "size": Vector3(0.08, 0.2, 0.08)},
			{"pos": Vector3(0.0, 0.83, 0.12), "size": Vector3(0.08, 0.18, 0.08)},
		]
	if style == 1:
		# Longer: cap + pieces hanging down the back and sides.
		var long := cap.duplicate()
		long.append({"pos": Vector3(0.0, 0.6, 0.17), "size": Vector3(0.18, 0.26, 0.1)})
		long.append({"pos": Vector3(-0.17, 0.6, 0.06), "size": Vector3(0.1, 0.24, 0.13)})
		long.append({"pos": Vector3(0.17, 0.6, 0.06), "size": Vector3(0.1, 0.24, 0.13)})
		return long
	return cap  # style 0 (short messy)


## Simple block hands at the end of each arm (move with the arm pivots).
func _build_hands() -> void:
	for pivot in [arm_l, arm_r]:
		var old = pivot.get_node_or_null("HandMesh")
		if old != null:
			old.queue_free()
		var h := MeshInstance3D.new()
		h.name = "HandMesh"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.14, 0.16)
		h.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = skin_color
		h.material_override = mat
		pivot.add_child(h)
		h.position = Vector3(0.0, -0.62, 0.0)


## Pointed ears (goblins/orcs/elves) and lower tusks (orcs/trolls), built on the head.
func _build_features() -> void:
	var head := get_node_or_null("Head") as Node3D
	if head == null:
		return
	for nm in ["EarL", "EarR", "TuskL", "TuskR"]:
		var old = head.get_node_or_null(nm)
		if old != null:
			old.queue_free()
	if ear_style == 1:
		var er := 0.055 * ear_size
		var eh := 0.22 * ear_size
		var ex := 0.15 + 0.035 * ear_size
		head.add_child(_make_cone("EarL", er, eh, skin_color, Vector3(-ex, 0.04, 0.02), Vector3(0, 0, deg_to_rad(72))))
		head.add_child(_make_cone("EarR", er, eh, skin_color, Vector3(ex, 0.04, 0.02), Vector3(0, 0, deg_to_rad(-72))))
	if tusks:
		var tr := 0.025 * tusk_size
		var th := 0.12 * tusk_size
		head.add_child(_make_cone("TuskL", tr, th, Color(0.93, 0.91, 0.82), Vector3(-0.06, -0.12, -0.15), Vector3.ZERO))
		head.add_child(_make_cone("TuskR", tr, th, Color(0.93, 0.91, 0.82), Vector3(0.06, -0.12, -0.15), Vector3.ZERO))


func _make_cone(nm: String, base_r: float, h: float, col: Color, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nm
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = base_r
	cone.height = h
	m.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	return m


## Widen the torso/arms for bulky races (orc/troll) or slim them (goblin/skeleton).
func _apply_bulk() -> void:
	if is_equal_approx(bulk, 1.0):
		return
	for p in ["Torso", "Shorts", "Belt"]:
		var n := get_node_or_null(p) as Node3D
		if n != null:
			n.scale = Vector3(bulk, 1.0, bulk)
	var aw := clampf(bulk, 0.8, 1.4)
	arm_l.position.x *= bulk
	arm_r.position.x *= bulk
	arm_l.scale = Vector3(aw, 1.0, aw)
	arm_r.scale = Vector3(aw, 1.0, aw)


## A simple straw hat for villagers (brim + cone). Hides hair while worn.
func _build_hat() -> void:
	var head := get_node_or_null("Head") as Node3D
	if head == null:
		return
	var old = head.get_node_or_null("Hat")
	if old != null:
		old.queue_free()
	hair_node.visible = hat_style != 1
	if hat_style != 1:
		return
	var hat := Node3D.new()
	hat.name = "Hat"
	head.add_child(hat)
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.78, 0.66, 0.36)
	straw.roughness = 0.95
	var brim := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.34
	bc.bottom_radius = 0.34
	bc.height = 0.04
	brim.mesh = bc
	brim.material_override = straw
	hat.add_child(brim)
	brim.position = Vector3(0.0, 0.17, 0.0)
	var top := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.05
	tc.bottom_radius = 0.2
	tc.height = 0.2
	top.mesh = tc
	top.material_override = straw
	hat.add_child(top)
	top.position = Vector3(0.0, 0.29, 0.0)


func _paint(path: String, color: Color) -> void:
	var part := get_node_or_null(path) as MeshInstance3D
	if part == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	part.material_override = mat


## Parent a held item (e.g. a weapon) to the right hand.
func attach_to_hand(item: Node3D) -> void:
	hand.add_child(item)


# === Procedural armor ===================================================
# Armor is BUILT from primitives per the item's "model" id, not just tinted, so
# different helmets/chests/pants have genuinely different silhouettes. Each
# apply_equipment() clears the slot container and rebuilds it for the current item.
const ARMOR_DEFAULT := Color(0.60, 0.62, 0.68)
const ACCENT_GOLD := Color(0.85, 0.72, 0.28)
const DARKSLOT := Color(0.07, 0.07, 0.09)   # eye slits / openings
const BONE_COL := Color(0.90, 0.87, 0.78)
# Open-topped helmets that should still show the character's hair.
const HAIR_OK_MODELS := ["circlet", "crown", "winged", "tiara", "antlers", "flame_crown", "ice_crown", "halo", "laurel"]


## Rebuild the visible armor (helmet / chest / per-leg) from the equipment dict.
## Each item picks its shape via "model"; "color" tints it. Called on equip and by
## the inventory preview.
func apply_equipment(equipment: Dictionary) -> void:
	var helmet = equipment.get("helmet")
	var chest = equipment.get("chest")
	var legs = equipment.get("legs")

	# Helmet
	_clear(helmet_node)
	helmet_node.visible = helmet != null
	if helmet != null:
		_build_helmet(str(helmet.get("model", "cap")), helmet.get("color", ARMOR_DEFAULT))
	# Hair shows only with no helmet or an open-topped one (so it doesn't poke through).
	var hair_ok: bool = helmet == null or HAIR_OK_MODELS.has(str(helmet.get("model", "")))
	hair_node.visible = hair_ok and hat_style != 1

	# Chest
	_clear(chest_node)
	chest_node.visible = chest != null
	if chest != null:
		_build_chest(str(chest.get("model", "leather")), chest.get("color", ARMOR_DEFAULT))

	# Legs (the old single-mesh greaves are replaced by per-leg built containers).
	greave_l.visible = false
	greave_r.visible = false
	var li := _leg_container(leg_l)
	var ri := _leg_container(leg_r)
	_clear(li)
	_clear(ri)
	li.visible = legs != null
	ri.visible = legs != null
	if legs != null:
		var lmodel := str(legs.get("model", "greaves"))
		var lcol: Color = legs.get("color", ARMOR_DEFAULT)
		_build_legs(li, lmodel, lcol, -1)
		_build_legs(ri, lmodel, lcol, 1)


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


## Lazily create (and reuse) a child container under a leg pivot to hold leg armor.
func _leg_container(pivot: Node3D) -> Node3D:
	var c := pivot.get_node_or_null("LegArmor") as Node3D
	if c == null:
		c = Node3D.new()
		c.name = "LegArmor"
		pivot.add_child(c)
	return c


# --- primitive + material helpers ---

func _piece(parent: Node, mesh: Mesh, pos: Vector3, rot_deg: Vector3, col: Color, finish: String, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	mi.scale = scl
	mi.material_override = _finish_mat(col, finish)
	parent.add_child(mi)
	return mi


func _finish_mat(col: Color, finish: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	match finish:
		"metal":
			m.metallic = 0.6
			m.roughness = 0.35
		"accent":
			m.metallic = 0.7
			m.roughness = 0.28
		"bone":
			m.metallic = 0.0
			m.roughness = 0.7
		"dark":
			m.metallic = 0.0
			m.roughness = 0.6
		_:  # cloth
			m.metallic = 0.0
			m.roughness = 0.95
	return m


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 7
	return s


func _cone(base_r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = base_r
	c.height = h
	c.radial_segments = 8
	return c


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 14
	t.ring_segments = 8
	return t


# --- helmet models (built under $Head/Helmet; origin = head centre, head r~0.17) ---

func _build_helmet(model: String, col: Color) -> void:
	var p := helmet_node
	match model:
		"cap":
			_piece(p, _sphere(0.19), Vector3(0, 0.05, 0), Vector3.ZERO, col, "dark", Vector3(1, 0.6, 1))
			_piece(p, _box(Vector3(0.30, 0.04, 0.10)), Vector3(0, 0.0, -0.13), Vector3(8, 0, 0), col.darkened(0.2), "dark")
		"hood":
			_piece(p, _sphere(0.21), Vector3(0, 0.03, 0.04), Vector3.ZERO, col, "cloth", Vector3(1.05, 1.0, 1.05))
			_piece(p, _box(Vector3(0.15, 0.20, 0.16)), Vector3(0, 0.10, 0.17), Vector3(-28, 0, 0), col, "cloth")
			_piece(p, _box(Vector3(0.34, 0.22, 0.30)), Vector3(0, -0.17, 0.03), Vector3.ZERO, col.darkened(0.1), "cloth")
		"great_helm":
			_piece(p, _box(Vector3(0.36, 0.40, 0.36)), Vector3(0, 0.0, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.39, 0.07, 0.39)), Vector3(0, 0.20, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.26, 0.04, 0.03)), Vector3(0, 0.02, -0.19), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.03, 0.16, 0.03)), Vector3(0, -0.07, -0.19), Vector3.ZERO, DARKSLOT, "dark")
		"barbute":
			_piece(p, _sphere(0.20), Vector3(0, 0.02, 0), Vector3.ZERO, col, "metal", Vector3(1, 1.1, 1))
			_piece(p, _box(Vector3(0.06, 0.22, 0.03)), Vector3(0, -0.02, -0.19), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.22, 0.06, 0.03)), Vector3(0, 0.05, -0.19), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.05, 0.07, 0.30)), Vector3(0, 0.21, 0.0), Vector3.ZERO, col.lightened(0.15), "metal")
		"wizard_hat":
			_piece(p, _cyl(0.34, 0.04), Vector3(0, 0.15, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _cyl(0.21, 0.06), Vector3(0, 0.19, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _cone(0.20, 0.48), Vector3(0, 0.43, 0.02), Vector3(-6, 0, 5), col, "cloth")
			_piece(p, _box(Vector3(0.06, 0.06, 0.02)), Vector3(0.02, 0.32, -0.16), Vector3(0, 0, 20), ACCENT_GOLD, "accent")
		"circlet":
			_piece(p, _torus(0.155, 0.185), Vector3(0, 0.07, 0), Vector3.ZERO, col, "accent")
			_piece(p, _box(Vector3(0.05, 0.06, 0.04)), Vector3(0, 0.10, -0.165), Vector3(0, 0, 45), Color(0.5, 0.85, 1.0), "accent")
		"horned":
			_piece(p, _sphere(0.20), Vector3(0, 0.04, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.85, 1))
			_piece(p, _box(Vector3(0.34, 0.07, 0.10)), Vector3(0, -0.02, -0.13), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _cone(0.06, 0.26), Vector3(-0.17, 0.10, 0), Vector3(-10, 0, 40), col.lightened(0.2), "metal")
			_piece(p, _cone(0.06, 0.26), Vector3(0.17, 0.10, 0), Vector3(-10, 0, -40), col.lightened(0.2), "metal")
		"bone":
			_piece(p, _sphere(0.19), Vector3(0, 0.05, 0), Vector3.ZERO, col, "bone", Vector3(1, 0.95, 1))
			_piece(p, _box(Vector3(0.30, 0.05, 0.08)), Vector3(0, 0.0, -0.13), Vector3.ZERO, col.darkened(0.05), "bone")
			_piece(p, _box(Vector3(0.07, 0.07, 0.04)), Vector3(-0.07, 0.0, -0.16), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.07, 0.07, 0.04)), Vector3(0.07, 0.0, -0.16), Vector3.ZERO, DARKSLOT, "dark")
			for i in range(4):
				_piece(p, _box(Vector3(0.04, 0.06, 0.03)), Vector3(-0.09 + i * 0.06, -0.14, -0.13), Vector3.ZERO, BONE_COL, "bone")
		"crown":
			_piece(p, _torus(0.165, 0.205), Vector3(0, 0.12, 0), Vector3.ZERO, col, "accent")
			for i in range(6):
				var a := TAU * i / 6.0
				_piece(p, _cone(0.035, 0.14), Vector3(sin(a) * 0.18, 0.21, cos(a) * 0.18), Vector3.ZERO, col, "accent")
			_piece(p, _box(Vector3(0.05, 0.05, 0.04)), Vector3(0, 0.13, -0.18), Vector3(0, 0, 45), Color(0.9, 0.2, 0.3), "accent")
		"winged":
			_piece(p, _sphere(0.19), Vector3(0, 0.04, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.75, 1))
			_piece(p, _box(Vector3(0.04, 0.10, 0.24)), Vector3(0, 0.16, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.02, 0.13, 0.20)), Vector3(-0.19, 0.07, 0.02), Vector3(0, 0, 40), col.lightened(0.2), "metal")
			_piece(p, _box(Vector3(0.02, 0.13, 0.20)), Vector3(0.19, 0.07, 0.02), Vector3(0, 0, -40), col.lightened(0.2), "metal")
		"jester":
			_piece(p, _sphere(0.19), Vector3(0, 0.04, 0), Vector3.ZERO, col, "cloth", Vector3(1, 0.7, 1))
			_piece(p, _cone(0.05, 0.22), Vector3(-0.16, 0.10, 0), Vector3(0, 0, 70), col.darkened(0.1), "cloth")
			_piece(p, _sphere(0.045), Vector3(-0.27, 0.04, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _cone(0.05, 0.22), Vector3(0.16, 0.10, 0), Vector3(0, 0, -70), col.lightened(0.1), "cloth")
			_piece(p, _sphere(0.045), Vector3(0.27, 0.04, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _cone(0.05, 0.22), Vector3(0, 0.12, 0.16), Vector3(60, 0, 0), col.darkened(0.1), "cloth")
			_piece(p, _sphere(0.045), Vector3(0, 0.06, 0.29), Vector3.ZERO, ACCENT_GOLD, "accent")
		"viking":
			_piece(p, _sphere(0.20), Vector3(0, 0.02, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.95, 1))
			_piece(p, _box(Vector3(0.05, 0.16, 0.05)), Vector3(0, -0.04, -0.18), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _cone(0.06, 0.24), Vector3(-0.18, 0.06, 0), Vector3(0, 0, 55), BONE_COL, "bone")
			_piece(p, _cone(0.06, 0.24), Vector3(0.18, 0.06, 0), Vector3(0, 0, -55), BONE_COL, "bone")
		"kabuto":
			_piece(p, _sphere(0.19), Vector3(0, 0.04, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.8, 1))
			_piece(p, _cyl(0.28, 0.05), Vector3(0, -0.06, 0.04), Vector3(18, 0, 0), col.darkened(0.15), "metal")
			_piece(p, _cone(0.03, 0.18), Vector3(-0.05, 0.18, -0.08), Vector3(20, 0, 25), ACCENT_GOLD, "accent")
			_piece(p, _cone(0.03, 0.18), Vector3(0.05, 0.18, -0.08), Vector3(20, 0, -25), ACCENT_GOLD, "accent")
		"plague":
			_piece(p, _sphere(0.19), Vector3(0, 0.04, 0), Vector3.ZERO, col, "dark")
			_piece(p, _cone(0.07, 0.28), Vector3(0, -0.02, -0.20), Vector3(-90, 0, 0), col.darkened(0.2), "dark")
			_piece(p, _sphere(0.045), Vector3(-0.08, 0.03, -0.13), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _sphere(0.045), Vector3(0.08, 0.03, -0.13), Vector3.ZERO, DARKSLOT, "dark")
		"spartan":
			_piece(p, _sphere(0.19), Vector3(0, 0.02, 0), Vector3.ZERO, col, "metal", Vector3(1, 1.05, 1))
			_piece(p, _box(Vector3(0.05, 0.18, 0.03)), Vector3(0, -0.02, -0.19), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.18, 0.05, 0.03)), Vector3(0, 0.06, -0.19), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.03, 0.12, 0.34)), Vector3(0, 0.22, 0.0), Vector3.ZERO, Color(0.8, 0.2, 0.2), "cloth")
		"antlers":
			_piece(p, _sphere(0.18), Vector3(0, 0.04, 0), Vector3.ZERO, col, "dark", Vector3(1, 0.6, 1))
			_piece(p, _cone(0.03, 0.22), Vector3(-0.12, 0.12, 0), Vector3(0, 0, 28), BONE_COL, "bone")
			_piece(p, _cone(0.02, 0.10), Vector3(-0.19, 0.20, 0), Vector3(0, 0, 55), BONE_COL, "bone")
			_piece(p, _cone(0.03, 0.22), Vector3(0.12, 0.12, 0), Vector3(0, 0, -28), BONE_COL, "bone")
			_piece(p, _cone(0.02, 0.10), Vector3(0.19, 0.20, 0), Vector3(0, 0, -55), BONE_COL, "bone")
		"tiara":
			_piece(p, _torus(0.15, 0.17), Vector3(0, 0.08, 0), Vector3.ZERO, col, "accent")
			_piece(p, _box(Vector3(0.04, 0.05, 0.03)), Vector3(0, 0.11, -0.16), Vector3(0, 0, 45), Color(0.5, 0.85, 1.0), "accent")
			_piece(p, _box(Vector3(0.03, 0.04, 0.03)), Vector3(-0.10, 0.09, -0.12), Vector3(0, 0, 45), Color(1.0, 0.5, 0.7), "accent")
			_piece(p, _box(Vector3(0.03, 0.04, 0.03)), Vector3(0.10, 0.09, -0.12), Vector3(0, 0, 45), Color(1.0, 0.5, 0.7), "accent")
		"demon":
			_piece(p, _sphere(0.19), Vector3(0, 0.03, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.85, 1))
			_piece(p, _cone(0.07, 0.30), Vector3(-0.16, 0.08, 0.02), Vector3(-20, 0, 45), col.darkened(0.2), "metal")
			_piece(p, _cone(0.07, 0.30), Vector3(0.16, 0.08, 0.02), Vector3(-20, 0, -45), col.darkened(0.2), "metal")
			_piece(p, _box(Vector3(0.06, 0.04, 0.03)), Vector3(-0.07, 0.02, -0.16), Vector3(0, 0, 20), Color(1.0, 0.2, 0.1), "accent")
			_piece(p, _box(Vector3(0.06, 0.04, 0.03)), Vector3(0.07, 0.02, -0.16), Vector3(0, 0, -20), Color(1.0, 0.2, 0.1), "accent")
		"flame_crown":
			_piece(p, _torus(0.16, 0.19), Vector3(0, 0.08, 0), Vector3.ZERO, col, "accent")
			for i in range(5):
				var a := TAU * i / 5.0
				_piece(p, _cone(0.045, 0.20), Vector3(sin(a) * 0.16, 0.20, cos(a) * 0.16), Vector3.ZERO, Color(1.0, 0.45, 0.12), "accent")
		"ice_crown":
			_piece(p, _torus(0.155, 0.185), Vector3(0, 0.07, 0), Vector3.ZERO, col, "accent")
			_piece(p, _cone(0.04, 0.24), Vector3(0, 0.22, -0.02), Vector3.ZERO, Color(0.7, 0.9, 1.0), "accent")
			_piece(p, _cone(0.03, 0.16), Vector3(-0.12, 0.16, 0), Vector3(0, 0, 30), Color(0.7, 0.9, 1.0), "accent")
			_piece(p, _cone(0.03, 0.16), Vector3(0.12, 0.16, 0), Vector3(0, 0, -30), Color(0.7, 0.9, 1.0), "accent")
		"storm_helm":
			_piece(p, _sphere(0.19), Vector3(0, 0.03, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.85, 1))
			_piece(p, _box(Vector3(0.04, 0.10, 0.03)), Vector3(0, 0.20, -0.02), Vector3(0, 0, 20), Color(0.6, 0.85, 1.0), "accent")
			_piece(p, _box(Vector3(0.04, 0.10, 0.03)), Vector3(0.03, 0.27, -0.02), Vector3(0, 0, -25), Color(0.6, 0.85, 1.0), "accent")
			_piece(p, _box(Vector3(0.18, 0.04, 0.03)), Vector3(0, 0.06, -0.18), Vector3.ZERO, DARKSLOT, "dark")
		"halo":
			_piece(p, _sphere(0.18), Vector3(0, 0.03, 0), Vector3.ZERO, col, "cloth", Vector3(1, 0.55, 1))
			_piece(p, _torus(0.12, 0.15), Vector3(0, 0.30, 0), Vector3(8, 0, 0), Color(1.0, 0.92, 0.5), "accent")
		"shadow_hood":
			_piece(p, _sphere(0.21), Vector3(0, 0.03, 0.04), Vector3.ZERO, col, "cloth", Vector3(1.05, 1.0, 1.05))
			_piece(p, _box(Vector3(0.16, 0.12, 0.02)), Vector3(0, 0.0, -0.17), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.04, 0.03, 0.02)), Vector3(-0.05, 0.02, -0.16), Vector3.ZERO, Color(0.7, 0.3, 1.0), "accent")
			_piece(p, _box(Vector3(0.04, 0.03, 0.02)), Vector3(0.05, 0.02, -0.16), Vector3.ZERO, Color(0.7, 0.3, 1.0), "accent")
			_piece(p, _box(Vector3(0.30, 0.20, 0.28)), Vector3(0, -0.17, 0.03), Vector3.ZERO, col.darkened(0.1), "cloth")
		"druid_hood":
			_piece(p, _sphere(0.20), Vector3(0, 0.03, 0.03), Vector3.ZERO, col, "cloth", Vector3(1.02, 0.95, 1.02))
			_piece(p, _cone(0.05, 0.14), Vector3(-0.10, 0.16, 0.04), Vector3(0, 0, 40), col.lightened(0.15), "cloth")
			_piece(p, _cone(0.05, 0.14), Vector3(0.10, 0.16, 0.04), Vector3(0, 0, -40), col.lightened(0.15), "cloth")
			_piece(p, _cone(0.05, 0.16), Vector3(0, 0.18, 0.08), Vector3(20, 0, 0), col.lightened(0.1), "cloth")
		"crystal_helm":
			_piece(p, _sphere(0.18), Vector3(0, 0.04, 0), Vector3.ZERO, col, "accent", Vector3(1, 0.9, 1))
			_piece(p, _cone(0.05, 0.18), Vector3(0, 0.20, 0), Vector3.ZERO, col.lightened(0.2), "accent")
			_piece(p, _cone(0.035, 0.12), Vector3(-0.10, 0.16, 0), Vector3(0, 0, 25), col.lightened(0.2), "accent")
			_piece(p, _cone(0.035, 0.12), Vector3(0.10, 0.16, 0), Vector3(0, 0, -25), col.lightened(0.2), "accent")
		"pharaoh":
			_piece(p, _sphere(0.19), Vector3(0, 0.04, 0), Vector3.ZERO, col, "cloth", Vector3(1, 0.8, 1))
			_piece(p, _box(Vector3(0.16, 0.30, 0.10)), Vector3(-0.16, -0.06, 0.02), Vector3(0, 0, -8), col, "cloth")
			_piece(p, _box(Vector3(0.16, 0.30, 0.10)), Vector3(0.16, -0.06, 0.02), Vector3(0, 0, 8), col, "cloth")
			_piece(p, _box(Vector3(0.40, 0.04, 0.04)), Vector3(0, 0.0, -0.16), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _cone(0.03, 0.10), Vector3(0, 0.10, -0.16), Vector3(-30, 0, 0), Color(0.2, 0.7, 0.4), "accent")
		"mushroom":
			_piece(p, _sphere(0.26), Vector3(0, 0.10, 0), Vector3.ZERO, col, "cloth", Vector3(1, 0.6, 1))
			for sp in [Vector3(-0.10, 0.16, -0.08), Vector3(0.12, 0.14, -0.04), Vector3(0.0, 0.20, -0.12), Vector3(-0.14, 0.12, 0.06)]:
				_piece(p, _sphere(0.03), sp, Vector3.ZERO, Color(0.95, 0.92, 0.85), "cloth")
		"war_horns":
			_piece(p, _sphere(0.19), Vector3(0, 0.02, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.9, 1))
			_piece(p, _cone(0.07, 0.18), Vector3(-0.17, 0.06, 0), Vector3(0, 0, 80), BONE_COL, "bone")
			_piece(p, _cone(0.05, 0.14), Vector3(-0.26, 0.10, 0), Vector3(0, 0, 130), BONE_COL, "bone")
			_piece(p, _cone(0.07, 0.18), Vector3(0.17, 0.06, 0), Vector3(0, 0, -80), BONE_COL, "bone")
			_piece(p, _cone(0.05, 0.14), Vector3(0.26, 0.10, 0), Vector3(0, 0, -130), BONE_COL, "bone")
		"turban":
			_piece(p, _sphere(0.20), Vector3(0, 0.05, 0), Vector3.ZERO, col, "cloth", Vector3(1, 0.75, 1))
			_piece(p, _torus(0.17, 0.20), Vector3(0, 0.06, 0), Vector3.ZERO, col.lightened(0.1), "cloth")
			_piece(p, _torus(0.16, 0.185), Vector3(0, 0.12, 0), Vector3.ZERO, col.darkened(0.08), "cloth")
			_piece(p, _box(Vector3(0.05, 0.05, 0.03)), Vector3(0, 0.10, -0.18), Vector3(0, 0, 45), Color(0.5, 0.85, 1.0), "accent")
			_piece(p, _cone(0.04, 0.16), Vector3(0, 0.20, 0.04), Vector3(20, 0, 0), col.lightened(0.15), "cloth")
		"centurion":
			_piece(p, _sphere(0.19), Vector3(0, 0.02, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.36, 0.10, 0.04)), Vector3(0, 0.22, 0), Vector3.ZERO, Color(0.8, 0.2, 0.2), "cloth")
			_piece(p, _box(Vector3(0.18, 0.05, 0.03)), Vector3(0, 0.05, -0.18), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.05, 0.14, 0.03)), Vector3(0, -0.04, -0.17), Vector3.ZERO, col.lightened(0.1), "metal")
		"topknot":
			_piece(p, _sphere(0.19), Vector3(0, 0.04, 0), Vector3.ZERO, col, "cloth", Vector3(1, 0.55, 1))
			_piece(p, _torus(0.15, 0.175), Vector3(0, 0.06, 0), Vector3.ZERO, col.darkened(0.15), "dark")
			_piece(p, _cyl(0.03, 0.10), Vector3(0, 0.22, 0.02), Vector3.ZERO, Color(0.1, 0.08, 0.07), "dark")
			_piece(p, _sphere(0.05), Vector3(0, 0.28, 0.02), Vector3.ZERO, Color(0.1, 0.08, 0.07), "dark")
		"wolf_pelt":
			_piece(p, _sphere(0.21), Vector3(0, 0.04, 0.03), Vector3.ZERO, col, "cloth", Vector3(1.05, 1.0, 1.05))
			_piece(p, _box(Vector3(0.16, 0.12, 0.16)), Vector3(0, 0.10, -0.10), Vector3(20, 0, 0), col, "cloth")
			_piece(p, _cone(0.06, 0.16), Vector3(0, 0.02, -0.18), Vector3(-90, 0, 0), col.darkened(0.1), "cloth")
			_piece(p, _cone(0.05, 0.14), Vector3(-0.10, 0.22, -0.06), Vector3(0, 0, 18), col.darkened(0.05), "cloth")
			_piece(p, _cone(0.05, 0.14), Vector3(0.10, 0.22, -0.06), Vector3(0, 0, -18), col.darkened(0.05), "cloth")
			_piece(p, _box(Vector3(0.30, 0.18, 0.26)), Vector3(0, -0.16, 0.05), Vector3.ZERO, col.darkened(0.08), "cloth")
		"skull_crown":
			_piece(p, _sphere(0.19), Vector3(0, 0.05, 0), Vector3.ZERO, BONE_COL, "bone", Vector3(1, 0.95, 1))
			_piece(p, _box(Vector3(0.30, 0.05, 0.08)), Vector3(0, 0.0, -0.13), Vector3.ZERO, BONE_COL.darkened(0.05), "bone")
			_piece(p, _box(Vector3(0.07, 0.07, 0.04)), Vector3(-0.07, 0.0, -0.16), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _box(Vector3(0.07, 0.07, 0.04)), Vector3(0.07, 0.0, -0.16), Vector3.ZERO, DARKSLOT, "dark")
			_piece(p, _torus(0.16, 0.19), Vector3(0, 0.12, 0), Vector3.ZERO, col, "accent")
			for i in range(5):
				var a := TAU * i / 5.0
				_piece(p, _cone(0.03, 0.10), Vector3(sin(a) * 0.17, 0.18, cos(a) * 0.17), Vector3.ZERO, col, "accent")
		"laurel":
			for i in range(10):
				var a := TAU * i / 10.0
				_piece(p, _box(Vector3(0.05, 0.10, 0.03)), Vector3(sin(a) * 0.18, 0.07, cos(a) * 0.18), Vector3(0, -a, 30), col, "cloth")
		"diving_helm":
			_piece(p, _sphere(0.21), Vector3(0, 0.02, 0), Vector3.ZERO, col, "metal")
			_piece(p, _torus(0.07, 0.10), Vector3(0, 0.0, -0.18), Vector3(90, 0, 0), col.lightened(0.1), "metal")
			_piece(p, _sphere(0.06), Vector3(0, 0.0, -0.20), Vector3.ZERO, Color(0.5, 0.7, 0.8), "accent")
			for i in range(4):
				var a := TAU * i / 4.0
				_piece(p, _sphere(0.02), Vector3(sin(a) * 0.12, cos(a) * 0.10, -0.17), Vector3.ZERO, ACCENT_GOLD, "accent")
		"cyclops":
			_piece(p, _sphere(0.19), Vector3(0, 0.03, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.95, 1))
			_piece(p, _box(Vector3(0.30, 0.06, 0.05)), Vector3(0, 0.06, -0.15), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _sphere(0.07), Vector3(0, 0.0, -0.16), Vector3.ZERO, Color(0.9, 0.2, 0.15), "accent")
			_piece(p, _box(Vector3(0.18, 0.05, 0.03)), Vector3(0, -0.10, -0.16), Vector3.ZERO, DARKSLOT, "dark")
		_:
			_piece(p, _sphere(0.19), Vector3(0, 0.05, 0), Vector3.ZERO, col, "metal", Vector3(1, 0.6, 1))


# --- chest models (built under $ChestArmor; origin = humanoid root, torso ~y0.2) ---

func _build_chest(model: String, col: Color) -> void:
	var p := chest_node
	match model:
		"robe":
			_piece(p, _box(Vector3(0.52, 0.56, 0.30)), Vector3(0, 0.18, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.46, 0.42, 0.34)), Vector3(0, -0.18, 0), Vector3.ZERO, col.darkened(0.08), "cloth")
			_piece(p, _box(Vector3(0.30, 0.10, 0.30)), Vector3(0, 0.44, 0), Vector3.ZERO, col.lightened(0.05), "cloth")
			_piece(p, _box(Vector3(0.04, 0.55, 0.02)), Vector3(0, 0.18, -0.16), Vector3.ZERO, col.darkened(0.25), "cloth")
		"leather":
			_piece(p, _box(Vector3(0.52, 0.50, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "dark")
			_piece(p, _box(Vector3(0.16, 0.10, 0.28)), Vector3(-0.27, 0.44, 0), Vector3.ZERO, col.darkened(0.1), "dark")
			_piece(p, _box(Vector3(0.16, 0.10, 0.28)), Vector3(0.27, 0.44, 0), Vector3.ZERO, col.darkened(0.1), "dark")
			_piece(p, _box(Vector3(0.40, 0.06, 0.02)), Vector3(0, 0.22, -0.16), Vector3(0, 0, 32), col.darkened(0.3), "dark")
		"plate":
			_piece(p, _box(Vector3(0.54, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(-0.27, 0.46, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(0.27, 0.46, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.20, 0.10, 0.24)), Vector3(0, 0.42, 0), Vector3.ZERO, col.lightened(0.05), "metal")
			_piece(p, _box(Vector3(0.40, 0.02, 0.02)), Vector3(0, 0.30, -0.165), Vector3.ZERO, col.darkened(0.2), "metal")
			_piece(p, _box(Vector3(0.40, 0.02, 0.02)), Vector3(0, 0.18, -0.165), Vector3.ZERO, col.darkened(0.2), "metal")
		"scale":
			_piece(p, _box(Vector3(0.50, 0.50, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col.darkened(0.2), "metal")
			for row in range(5):
				for cx in range(5):
					var sc: Color = col.lightened(0.08) if (row + cx) % 2 == 0 else col.darkened(0.12)
					_piece(p, _box(Vector3(0.085, 0.06, 0.02)), Vector3(-0.18 + cx * 0.09, 0.40 - row * 0.085, -0.155), Vector3.ZERO, sc, "metal")
		"brigandine":
			_piece(p, _box(Vector3(0.52, 0.50, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "dark")
			for row in range(4):
				for cx in range(4):
					_piece(p, _sphere(0.022), Vector3(-0.135 + cx * 0.09, 0.36 - row * 0.09, -0.155), Vector3.ZERO, ACCENT_GOLD, "accent")
		"cloak":
			_piece(p, _box(Vector3(0.48, 0.44, 0.28)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.50, 0.72, 0.04)), Vector3(0, 0.06, 0.17), Vector3(4, 0, 0), col.darkened(0.12), "cloth")
			_piece(p, _box(Vector3(0.42, 0.12, 0.22)), Vector3(0, 0.46, 0.04), Vector3.ZERO, col.darkened(0.05), "cloth")
			_piece(p, _box(Vector3(0.05, 0.05, 0.04)), Vector3(0, 0.40, -0.15), Vector3(0, 0, 45), ACCENT_GOLD, "accent")
		"bone":
			_piece(p, _box(Vector3(0.06, 0.50, 0.10)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "bone")
			_piece(p, _box(Vector3(0.06, 0.30, 0.06)), Vector3(0, 0.24, -0.13), Vector3.ZERO, col.lightened(0.05), "bone")
			for i in range(4):
				var ry := 0.36 - i * 0.08
				_piece(p, _box(Vector3(0.22, 0.04, 0.06)), Vector3(-0.10, ry, -0.10), Vector3(0, 0, 14), col, "bone")
				_piece(p, _box(Vector3(0.22, 0.04, 0.06)), Vector3(0.10, ry, -0.10), Vector3(0, 0, -14), col, "bone")
		"ornate_robe":
			_piece(p, _box(Vector3(0.52, 0.56, 0.30)), Vector3(0, 0.18, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.46, 0.44, 0.34)), Vector3(0, -0.18, 0), Vector3.ZERO, col.darkened(0.08), "cloth")
			_piece(p, _box(Vector3(0.05, 0.74, 0.02)), Vector3(-0.10, 0.10, -0.16), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.05, 0.74, 0.02)), Vector3(0.10, 0.10, -0.16), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.30, 0.08, 0.30)), Vector3(0, 0.45, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _sphere(0.04), Vector3(0, 0.28, -0.17), Vector3.ZERO, Color(0.5, 0.85, 1.0), "accent")
			_piece(p, _box(Vector3(0.10, 0.10, 0.10)), Vector3(-0.24, 0.44, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.10, 0.10, 0.10)), Vector3(0.24, 0.44, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
		"ornate_plate":
			_piece(p, _box(Vector3(0.55, 0.52, 0.33)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _sphere(0.13), Vector3(-0.28, 0.47, 0), Vector3.ZERO, col.lightened(0.12), "metal", Vector3(1, 0.8, 1))
			_piece(p, _sphere(0.13), Vector3(0.28, 0.47, 0), Vector3.ZERO, col.lightened(0.12), "metal", Vector3(1, 0.8, 1))
			_piece(p, _box(Vector3(0.22, 0.10, 0.26)), Vector3(0, 0.42, 0), Vector3.ZERO, col.lightened(0.05), "metal")
			_piece(p, _box(Vector3(0.42, 0.02, 0.02)), Vector3(0, 0.30, -0.17), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.10, 0.12, 0.04)), Vector3(0, 0.24, -0.17), Vector3(0, 0, 45), ACCENT_GOLD, "accent")
		"fur":
			_piece(p, _box(Vector3(0.50, 0.48, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "dark")
			_piece(p, _sphere(0.15), Vector3(-0.26, 0.46, 0), Vector3.ZERO, col.lightened(0.2), "cloth")
			_piece(p, _sphere(0.15), Vector3(0.26, 0.46, 0), Vector3.ZERO, col.lightened(0.2), "cloth")
			for i in range(5):
				_piece(p, _sphere(0.07), Vector3(-0.16 + i * 0.08, 0.44, -0.14), Vector3.ZERO, col.lightened(0.25), "cloth")
		"royal":
			_piece(p, _box(Vector3(0.52, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.52, 0.80, 0.04)), Vector3(0, 0.02, 0.17), Vector3(3, 0, 0), Color(0.6, 0.12, 0.16), "cloth")
			_piece(p, _box(Vector3(0.16, 0.10, 0.34)), Vector3(-0.27, 0.47, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.16, 0.10, 0.34)), Vector3(0.27, 0.47, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _sphere(0.05), Vector3(0, 0.28, -0.17), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.04, 0.50, 0.02)), Vector3(0, 0.22, -0.165), Vector3.ZERO, ACCENT_GOLD, "accent")
		"dragon":
			_piece(p, _box(Vector3(0.52, 0.50, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			for i in range(4):
				_piece(p, _cone(0.05, 0.16), Vector3(0, 0.42 - i * 0.11, 0.16), Vector3(70, 0, 0), col.lightened(0.15), "metal")
			_piece(p, _box(Vector3(0.20, 0.16, 0.32)), Vector3(-0.26, 0.44, 0), Vector3(0, 0, 18), col.darkened(0.1), "metal")
			_piece(p, _box(Vector3(0.20, 0.16, 0.32)), Vector3(0.26, 0.44, 0), Vector3(0, 0, -18), col.darkened(0.1), "metal")
		"chainmail":
			_piece(p, _box(Vector3(0.50, 0.52, 0.30)), Vector3(0, 0.20, 0), Vector3.ZERO, col.darkened(0.2), "metal")
			for row in range(6):
				for cx in range(6):
					_piece(p, _sphere(0.018), Vector3(-0.165 + cx * 0.066, 0.40 - row * 0.07, -0.155), Vector3.ZERO, col.lightened(0.05), "metal")
		"monk":
			_piece(p, _box(Vector3(0.50, 0.56, 0.30)), Vector3(0, 0.18, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.46, 0.40, 0.34)), Vector3(0, -0.18, 0), Vector3.ZERO, col.darkened(0.06), "cloth")
			_piece(p, _box(Vector3(0.54, 0.07, 0.34)), Vector3(0, 0.02, 0), Vector3.ZERO, col.darkened(0.3), "cloth")
			_piece(p, _box(Vector3(0.07, 0.34, 0.02)), Vector3(0.16, -0.10, -0.16), Vector3(0, 0, 8), col.darkened(0.3), "cloth")
		"spellweave":
			_piece(p, _box(Vector3(0.50, 0.56, 0.30)), Vector3(0, 0.18, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.46, 0.42, 0.34)), Vector3(0, -0.18, 0), Vector3.ZERO, col.darkened(0.08), "cloth")
			for r in [Vector3(-0.12, 0.30, -0.16), Vector3(0.12, 0.24, -0.16), Vector3(0.0, 0.12, -0.17), Vector3(-0.10, 0.0, -0.17), Vector3(0.13, 0.40, -0.15)]:
				_piece(p, _box(Vector3(0.05, 0.05, 0.02)), r, Vector3(0, 0, 45), Color(0.5, 0.9, 1.0), "accent")
		"flame_plate":
			_piece(p, _box(Vector3(0.54, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(-0.27, 0.46, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(0.27, 0.46, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			for r in [Vector3(-0.08, 0.32, -0.165), Vector3(0.06, 0.20, -0.165), Vector3(-0.02, 0.10, -0.165)]:
				_piece(p, _box(Vector3(0.03, 0.14, 0.02)), r, Vector3(0, 0, 15), Color(1.0, 0.45, 0.12), "accent")
		"ice_plate":
			_piece(p, _box(Vector3(0.54, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _cone(0.05, 0.18), Vector3(-0.27, 0.52, 0), Vector3(0, 0, 18), Color(0.7, 0.9, 1.0), "accent")
			_piece(p, _cone(0.05, 0.18), Vector3(0.27, 0.52, 0), Vector3(0, 0, -18), Color(0.7, 0.9, 1.0), "accent")
			_piece(p, _cone(0.04, 0.14), Vector3(0, 0.46, -0.10), Vector3(-20, 0, 0), Color(0.7, 0.9, 1.0), "accent")
		"storm_robe":
			_piece(p, _box(Vector3(0.52, 0.56, 0.30)), Vector3(0, 0.18, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.46, 0.42, 0.34)), Vector3(0, -0.18, 0), Vector3.ZERO, col.darkened(0.08), "cloth")
			for r in [Vector3(0, 0.34, -0.16), Vector3(0.03, 0.24, -0.16), Vector3(-0.02, 0.14, -0.17)]:
				_piece(p, _box(Vector3(0.05, 0.10, 0.02)), r, Vector3(0, 0, 25), Color(0.6, 0.85, 1.0), "accent")
		"holy_plate":
			_piece(p, _box(Vector3(0.54, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(-0.27, 0.46, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(0.27, 0.46, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _torus(0.05, 0.08), Vector3(0, 0.30, -0.165), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.10, 0.40, 0.04)), Vector3(-0.18, 0.20, 0.16), Vector3(0, 0, 25), Color(0.95, 0.95, 0.9), "cloth")
			_piece(p, _box(Vector3(0.10, 0.40, 0.04)), Vector3(0.18, 0.20, 0.16), Vector3(0, 0, -25), Color(0.95, 0.95, 0.9), "cloth")
		"shadow_robe":
			_piece(p, _box(Vector3(0.50, 0.54, 0.30)), Vector3(0, 0.18, 0), Vector3.ZERO, col, "cloth")
			for i in range(5):
				_piece(p, _box(Vector3(0.08, 0.24, 0.10)), Vector3(-0.16 + i * 0.08, -0.22, 0), Vector3.ZERO, col.darkened(0.1), "cloth")
			_piece(p, _box(Vector3(0.30, 0.10, 0.30)), Vector3(0, 0.44, 0), Vector3.ZERO, col.darkened(0.15), "cloth")
		"druid_chest":
			_piece(p, _box(Vector3(0.50, 0.50, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "dark")
			for i in range(3):
				_piece(p, _box(Vector3(0.06, 0.46, 0.03)), Vector3(-0.14 + i * 0.14, 0.22, -0.155), Vector3.ZERO, col.darkened(0.12), "dark")
			_piece(p, _cone(0.07, 0.16), Vector3(-0.26, 0.46, 0), Vector3(0, 0, 40), Color(0.3, 0.6, 0.25), "cloth")
			_piece(p, _cone(0.07, 0.16), Vector3(0.26, 0.46, 0), Vector3(0, 0, -40), Color(0.3, 0.6, 0.25), "cloth")
		"crystal_chest":
			_piece(p, _box(Vector3(0.52, 0.50, 0.30)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "accent")
			_piece(p, _cone(0.05, 0.16), Vector3(0, 0.30, -0.16), Vector3(-90, 0, 0), col.lightened(0.2), "accent")
			_piece(p, _cone(0.04, 0.12), Vector3(-0.08, 0.24, -0.16), Vector3(-70, 0, 20), col.lightened(0.2), "accent")
			_piece(p, _cone(0.04, 0.12), Vector3(0.08, 0.26, -0.16), Vector3(-70, 0, -20), col.lightened(0.2), "accent")
		"tabard":
			_piece(p, _box(Vector3(0.54, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(-0.27, 0.46, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.18, 0.14, 0.32)), Vector3(0.27, 0.46, 0), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.22, 0.62, 0.02)), Vector3(0, 0.14, -0.17), Vector3.ZERO, Color(0.7, 0.18, 0.2), "cloth")
			_piece(p, _box(Vector3(0.08, 0.08, 0.02)), Vector3(0, 0.24, -0.185), Vector3(0, 0, 45), ACCENT_GOLD, "accent")
		"gladiator":
			_piece(p, _box(Vector3(0.50, 0.46, 0.30)), Vector3(0, 0.20, 0), Vector3.ZERO, col, "dark")
			_piece(p, _box(Vector3(0.08, 0.50, 0.04)), Vector3(-0.12, 0.22, -0.16), Vector3(0, 0, -20), col.darkened(0.2), "dark")
			_piece(p, _sphere(0.16), Vector3(0.27, 0.47, 0), Vector3.ZERO, col.lightened(0.1), "metal", Vector3(1, 0.85, 1))
			_piece(p, _box(Vector3(0.06, 0.18, 0.32)), Vector3(0.30, 0.40, 0), Vector3.ZERO, col.lightened(0.05), "metal")
		"samurai_do":
			_piece(p, _box(Vector3(0.50, 0.50, 0.30)), Vector3(0, 0.20, 0), Vector3.ZERO, col.darkened(0.15), "dark")
			for row in range(4):
				for cx in range(4):
					_piece(p, _box(Vector3(0.10, 0.07, 0.02)), Vector3(-0.15 + cx * 0.10, 0.36 - row * 0.10, -0.155), Vector3.ZERO, col.lightened(0.05), "metal")
			_piece(p, _box(Vector3(0.20, 0.14, 0.32)), Vector3(-0.27, 0.46, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.20, 0.14, 0.32)), Vector3(0.27, 0.46, 0), Vector3.ZERO, col, "metal")
		"trenchcoat":
			_piece(p, _box(Vector3(0.50, 0.52, 0.30)), Vector3(0, 0.20, 0), Vector3.ZERO, col, "dark")
			_piece(p, _box(Vector3(0.22, 0.50, 0.32)), Vector3(-0.13, -0.18, 0), Vector3.ZERO, col.darkened(0.05), "dark")
			_piece(p, _box(Vector3(0.22, 0.50, 0.32)), Vector3(0.13, -0.18, 0), Vector3.ZERO, col.darkened(0.05), "dark")
			_piece(p, _box(Vector3(0.10, 0.14, 0.30)), Vector3(-0.18, 0.42, 0), Vector3(0, 0, 15), col.lightened(0.05), "dark")
			_piece(p, _box(Vector3(0.10, 0.14, 0.30)), Vector3(0.18, 0.42, 0), Vector3(0, 0, -15), col.lightened(0.05), "dark")
		"feathered_cloak":
			_piece(p, _box(Vector3(0.48, 0.46, 0.28)), Vector3(0, 0.21, 0), Vector3.ZERO, col, "cloth")
			for i in range(6):
				_piece(p, _cone(0.06, 0.20), Vector3(-0.25 + i * 0.10, 0.46, 0.10), Vector3(60, 0, 0), col.lightened(0.1 if i % 2 == 0 else 0.0), "cloth")
			_piece(p, _box(Vector3(0.44, 0.50, 0.04)), Vector3(0, 0.10, 0.16), Vector3(5, 0, 0), col.darkened(0.1), "cloth")
		"carapace":
			_piece(p, _sphere(0.30), Vector3(0, 0.24, 0.06), Vector3.ZERO, col, "accent", Vector3(1, 0.8, 0.9))
			for i in range(3):
				_piece(p, _box(Vector3(0.40, 0.10, 0.30)), Vector3(0, 0.34 - i * 0.12, -0.02), Vector3.ZERO, col.lightened(0.08), "accent")
			_piece(p, _box(Vector3(0.16, 0.12, 0.30)), Vector3(-0.26, 0.44, 0), Vector3.ZERO, col.darkened(0.1), "accent")
			_piece(p, _box(Vector3(0.16, 0.12, 0.30)), Vector3(0.26, 0.44, 0), Vector3.ZERO, col.darkened(0.1), "accent")
		_:
			_piece(p, _box(Vector3(0.54, 0.50, 0.32)), Vector3(0, 0.22, 0), Vector3.ZERO, col, "metal")


# --- leg models (built under each leg pivot's LegArmor; leg spans y0..-0.8, side ±1) ---

func _build_legs(p: Node, model: String, col: Color, side: int) -> void:
	match model:
		"trousers":
			_piece(p, _box(Vector3(0.20, 0.62, 0.22)), Vector3(0, -0.34, 0), Vector3.ZERO, col, "cloth")
		"leather_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.32, 0), Vector3.ZERO, col, "dark")
			_piece(p, _box(Vector3(0.17, 0.10, 0.07)), Vector3(0, -0.34, -0.10), Vector3.ZERO, col.darkened(0.15), "dark")
		"padded":
			_piece(p, _box(Vector3(0.20, 0.58, 0.22)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "cloth")
			for i in range(3):
				_piece(p, _box(Vector3(0.21, 0.02, 0.23)), Vector3(0, -0.18 - i * 0.16, 0), Vector3.ZERO, col.darkened(0.18), "cloth")
		"greaves":
			_piece(p, _box(Vector3(0.20, 0.42, 0.22)), Vector3(0, -0.50, 0), Vector3.ZERO, col, "metal")
			_piece(p, _sphere(0.10), Vector3(0, -0.30, -0.02), Vector3.ZERO, col.lightened(0.1), "metal")
			_piece(p, _box(Vector3(0.21, 0.06, 0.23)), Vector3(0, -0.18, 0), Vector3.ZERO, col.darkened(0.1), "metal")
		"wraps":
			_piece(p, _box(Vector3(0.18, 0.55, 0.20)), Vector3(0, -0.33, 0), Vector3.ZERO, col.darkened(0.15), "dark")
			for i in range(4):
				_piece(p, _box(Vector3(0.21, 0.06, 0.21)), Vector3(0, -0.14 - i * 0.13, 0), Vector3(0, 0, side * 14), col, "cloth")
		"bone_legs":
			_piece(p, _box(Vector3(0.18, 0.55, 0.20)), Vector3(0, -0.33, 0), Vector3.ZERO, col.darkened(0.1), "dark")
			_piece(p, _box(Vector3(0.04, 0.50, 0.04)), Vector3(-0.06, -0.33, -0.10), Vector3.ZERO, col, "bone")
			_piece(p, _box(Vector3(0.04, 0.50, 0.04)), Vector3(0.06, -0.33, -0.10), Vector3.ZERO, col, "bone")
			_piece(p, _box(Vector3(0.16, 0.08, 0.06)), Vector3(0, -0.30, -0.10), Vector3.ZERO, col, "bone")
		"swift":
			_piece(p, _box(Vector3(0.17, 0.55, 0.19)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.02, 0.16, 0.12)), Vector3(side * 0.09, -0.48, 0.06), Vector3(0, 0, side * -20), col.lightened(0.15), "accent")
		"plate_legs":
			_piece(p, _box(Vector3(0.21, 0.30, 0.23)), Vector3(0, -0.22, 0), Vector3.ZERO, col, "metal")
			_piece(p, _sphere(0.11), Vector3(0, -0.40, -0.02), Vector3.ZERO, col.lightened(0.12), "metal")
			_piece(p, _box(Vector3(0.21, 0.34, 0.23)), Vector3(0, -0.58, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.22, 0.02, 0.24)), Vector3(0, -0.20, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
		"fur_legs":
			_piece(p, _box(Vector3(0.20, 0.50, 0.22)), Vector3(0, -0.30, 0), Vector3.ZERO, col, "dark")
			_piece(p, _sphere(0.13), Vector3(0, -0.10, 0), Vector3.ZERO, col.lightened(0.22), "cloth")
			_piece(p, _sphere(0.13), Vector3(0, -0.60, 0.02), Vector3.ZERO, col.lightened(0.22), "cloth")
		"royal_legs":
			_piece(p, _box(Vector3(0.20, 0.55, 0.22)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.21, 0.02, 0.23)), Vector3(0, -0.20, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _box(Vector3(0.04, 0.50, 0.02)), Vector3(0, -0.33, -0.11), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _sphere(0.06), Vector3(0, -0.40, -0.03), Vector3.ZERO, ACCENT_GOLD, "accent")
		"dragon_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")
			for i in range(3):
				_piece(p, _cone(0.035, 0.12), Vector3(side * 0.11, -0.22 - i * 0.15, 0), Vector3(0, 0, side * -60), col.lightened(0.15), "metal")
			_piece(p, _cone(0.04, 0.12), Vector3(0, -0.30, -0.10), Vector3(-70, 0, 0), col.lightened(0.15), "metal")
		"chain_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.32, 0), Vector3.ZERO, col.darkened(0.2), "metal")
			for row in range(6):
				_piece(p, _sphere(0.018), Vector3(-0.05, -0.16 - row * 0.07, -0.105), Vector3.ZERO, col.lightened(0.05), "metal")
				_piece(p, _sphere(0.018), Vector3(0.05, -0.16 - row * 0.07, -0.105), Vector3.ZERO, col.lightened(0.05), "metal")
		"tassets":
			_piece(p, _box(Vector3(0.20, 0.50, 0.21)), Vector3(0, -0.34, 0), Vector3.ZERO, col.darkened(0.1), "dark")
			_piece(p, _box(Vector3(0.22, 0.28, 0.24)), Vector3(0, -0.18, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.20, 0.18, 0.24)), Vector3(0, -0.42, 0), Vector3.ZERO, col, "metal")
			_piece(p, _sphere(0.02), Vector3(-0.07, -0.18, -0.12), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _sphere(0.02), Vector3(0.07, -0.18, -0.12), Vector3.ZERO, ACCENT_GOLD, "accent")
		"boots_tall":
			_piece(p, _box(Vector3(0.17, 0.40, 0.19)), Vector3(0, -0.20, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.21, 0.42, 0.24)), Vector3(0, -0.58, 0.02), Vector3.ZERO, col.darkened(0.25), "dark")
			_piece(p, _box(Vector3(0.23, 0.06, 0.26)), Vector3(0, -0.40, 0.0), Vector3.ZERO, col.darkened(0.1), "dark")
		"flame_legs":
			_piece(p, _box(Vector3(0.20, 0.55, 0.22)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")
			for i in range(3):
				_piece(p, _box(Vector3(0.03, 0.12, 0.02)), Vector3(side * 0.06, -0.24 - i * 0.14, -0.11), Vector3(0, 0, 10), Color(1.0, 0.45, 0.12), "accent")
		"ice_legs":
			_piece(p, _box(Vector3(0.20, 0.55, 0.22)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")
			_piece(p, _cone(0.04, 0.14), Vector3(side * 0.11, -0.40, 0), Vector3(0, 0, side * -50), Color(0.7, 0.9, 1.0), "accent")
			_piece(p, _cone(0.03, 0.10), Vector3(side * 0.10, -0.20, 0), Vector3(0, 0, side * -50), Color(0.7, 0.9, 1.0), "accent")
		"holy_legs":
			_piece(p, _box(Vector3(0.20, 0.55, 0.22)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.21, 0.02, 0.23)), Vector3(0, -0.22, 0), Vector3.ZERO, ACCENT_GOLD, "accent")
			_piece(p, _sphere(0.07), Vector3(0, -0.40, -0.02), Vector3.ZERO, ACCENT_GOLD, "accent")
		"shadow_legs":
			_piece(p, _box(Vector3(0.18, 0.50, 0.20)), Vector3(0, -0.30, 0), Vector3.ZERO, col, "cloth")
			for i in range(3):
				_piece(p, _box(Vector3(0.06, 0.16, 0.08)), Vector3(-0.06 + i * 0.06, -0.58, 0), Vector3.ZERO, col.darkened(0.1), "cloth")
		"druid_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "dark")
			_piece(p, _cone(0.05, 0.12), Vector3(side * 0.10, -0.30, 0.02), Vector3(0, 0, side * -40), Color(0.3, 0.6, 0.25), "cloth")
			_piece(p, _cone(0.04, 0.10), Vector3(side * 0.09, -0.50, 0.02), Vector3(0, 0, side * -40), Color(0.3, 0.6, 0.25), "cloth")
		"crystal_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "accent")
			_piece(p, _cone(0.04, 0.12), Vector3(side * 0.10, -0.34, 0), Vector3(0, 0, side * -55), col.lightened(0.2), "accent")
			_piece(p, _cone(0.03, 0.09), Vector3(side * 0.09, -0.52, 0), Vector3(0, 0, side * -55), col.lightened(0.2), "accent")
		"faulds":
			_piece(p, _box(Vector3(0.19, 0.50, 0.21)), Vector3(0, -0.34, 0), Vector3.ZERO, col.darkened(0.1), "dark")
			_piece(p, _box(Vector3(0.22, 0.16, 0.24)), Vector3(0, -0.14, 0), Vector3.ZERO, col, "metal")
			_piece(p, _box(Vector3(0.20, 0.14, 0.24)), Vector3(0, -0.30, 0), Vector3(8, 0, 0), col, "metal")
		"hakama":
			_piece(p, _box(Vector3(0.22, 0.34, 0.24)), Vector3(0, -0.24, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.30, 0.30, 0.30)), Vector3(0, -0.52, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.23, 0.04, 0.25)), Vector3(0, -0.10, 0), Vector3.ZERO, col.darkened(0.2), "cloth")
		"shorts":
			_piece(p, _box(Vector3(0.21, 0.26, 0.23)), Vector3(0, -0.20, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.22, 0.04, 0.24)), Vector3(0, -0.30, 0), Vector3.ZERO, col.darkened(0.2), "cloth")
		"spiked_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")
			for i in range(3):
				_piece(p, _cone(0.03, 0.12), Vector3(side * 0.11, -0.20 - i * 0.16, 0), Vector3(0, 0, side * -90), col.lightened(0.15), "metal")
		"scale_legs":
			_piece(p, _box(Vector3(0.19, 0.55, 0.21)), Vector3(0, -0.33, 0), Vector3.ZERO, col.darkened(0.15), "metal")
			for row in range(5):
				_piece(p, _box(Vector3(0.07, 0.05, 0.02)), Vector3(-0.04, -0.16 - row * 0.08, -0.105), Vector3.ZERO, col.lightened(0.05), "metal")
				_piece(p, _box(Vector3(0.07, 0.05, 0.02)), Vector3(0.04, -0.16 - row * 0.08, -0.105), Vector3.ZERO, col.lightened(0.05), "metal")
		"winged_boots":
			_piece(p, _box(Vector3(0.18, 0.50, 0.20)), Vector3(0, -0.32, 0), Vector3.ZERO, col, "cloth")
			_piece(p, _box(Vector3(0.21, 0.16, 0.26)), Vector3(0, -0.60, 0.02), Vector3.ZERO, col.darkened(0.2), "dark")
			_piece(p, _box(Vector3(0.02, 0.10, 0.16)), Vector3(side * 0.10, -0.58, 0.0), Vector3(0, 0, side * 40), Color(0.95, 0.95, 1.0), "accent")
			_piece(p, _box(Vector3(0.02, 0.07, 0.10)), Vector3(side * 0.12, -0.56, -0.06), Vector3(0, 0, side * 55), Color(0.95, 0.95, 1.0), "accent")
		_:
			_piece(p, _box(Vector3(0.20, 0.55, 0.22)), Vector3(0, -0.33, 0), Vector3.ZERO, col, "metal")


## dir: "up" (upward swipe), "down" (overhead chop), or "stab" (forward poke).
## charge 0..1 makes a charged swing read a little slower/bigger.
func play_attack(dir: String = "stab", charge: float = 0.0) -> void:
	_attack_dir = dir
	_attack_total = ATTACK_ANIM_TIME * (1.0 + charge * 0.4)
	_attack_time = _attack_total


## Quick forward roll (used by dodge/dash): the whole body flips forward briefly.
func play_roll() -> void:
	_roll_time = ROLL_DUR


func _process(delta: float) -> void:
	var amp := clampf(move_speed / REF_SPEED, 0.0, 1.0) * WALK_MAX_AMP
	if move_speed > 0.2:
		_phase += delta * WALK_FREQ
	var swing := sin(_phase) * amp

	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	arm_l.rotation.x = -swing

	if _attack_time > 0.0:
		_attack_time -= delta
		var t := 1.0 - (_attack_time / _attack_total)
		match _attack_dir:
			"up":
				arm_r.rotation.x = lerpf(0.7, -1.9, t)    # low -> high swipe
			"down":
				arm_r.rotation.x = lerpf(-1.9, 0.7, t)    # overhead chop
			_:
				arm_r.rotation.x = -0.3 - sin(t * PI) * 0.9  # forward stab poke
	else:
		arm_r.rotation.x = swing

	# Dodge roll: flip the whole body forward over the roll duration.
	if _roll_time > 0.0:
		_roll_time -= delta
		var rt := 1.0 - (_roll_time / ROLL_DUR)
		rotation.x = -TAU * rt
		if _roll_time <= 0.0:
			rotation.x = 0.0
	elif rotation.x != 0.0:
		rotation.x = 0.0
