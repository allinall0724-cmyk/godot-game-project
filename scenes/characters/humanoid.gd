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


## Visibly reflect equipped armor on the model by showing/tinting dedicated armor
## meshes (helmet, chestplate, greaves). `equipment` is the player's equipment dict;
## items may carry a "color".
func apply_equipment(equipment: Dictionary) -> void:
	var helmet = equipment.get("helmet")
	helmet_node.visible = helmet != null
	# Hide hair under a helmet so it doesn't poke through.
	hair_node.visible = helmet == null
	# Shape variant: some helmets have horns.
	var has_horns: bool = helmet != null and bool(helmet.get("horns", false))
	var horn_l = helmet_node.get_node_or_null("HornL")
	var horn_r = helmet_node.get_node_or_null("HornR")
	if horn_l != null:
		horn_l.visible = has_horns
	if horn_r != null:
		horn_r.visible = has_horns
	if helmet != null:
		_tint_group(helmet_node, helmet.get("color", Color(0.6, 0.62, 0.68)))

	var chest = equipment.get("chest")
	chest_node.visible = chest != null
	if chest != null:
		_tint_group(chest_node, chest.get("color", Color(0.5, 0.5, 0.55)))

	var legs = equipment.get("legs")
	var show_legs: bool = legs != null
	greave_l.visible = show_legs
	greave_r.visible = show_legs
	if show_legs:
		var lcol: Color = legs.get("color", Color(0.5, 0.5, 0.55))
		_tint_group(greave_l, lcol)
		_tint_group(greave_r, lcol)


## Apply a metal-tinted material to a mesh (or every MeshInstance3D under a group).
func _tint_group(root: Node, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.5
	mat.roughness = 0.4
	if root is MeshInstance3D:
		root.material_override = mat
	for child in root.find_children("*", "MeshInstance3D", true, false):
		child.material_override = mat


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
