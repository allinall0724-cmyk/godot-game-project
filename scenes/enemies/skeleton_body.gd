extends Node3D
## Code-only bipedal SKELETON. A real skeleton — bone limbs, a ribcage, spine and
## pelvis, and a skull with hollow eye sockets, a nasal cavity and rows of teeth on
## a jaw that opens when it attacks. Walks with swinging legs + counter-swinging
## arms; lunges and snaps its jaw on attack.
##
## Built with feet at local y = 0 (the collision capsule in skeleton.tscn is offset
## up to match). Faces -Z, like the other enemy bodies, and exposes `move_speed` +
## `play_attack()` so enemy.gd drives it exactly like the humanoid/wolf.

const BONE := Color(0.90, 0.88, 0.79)
const BONE_DK := Color(0.62, 0.59, 0.5)
const SOCKET := Color(0.04, 0.03, 0.03)
const TEETH := Color(0.96, 0.94, 0.87)

var move_speed := 0.0
var _t := 0.0
var _attack := 0.0

# Animated joints.
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _skull: Node3D
var _jaw: Node3D


func _ready() -> void:
	var bone := _mat(BONE)
	var bone_dk := _mat(BONE_DK)

	_build_torso(bone, bone_dk)
	_build_skull(bone)

	# Legs (hip -> thigh -> knee -> shin -> foot).
	_hip_l = _make_leg(-0.11, bone)
	_hip_r = _make_leg(0.11, bone)
	# pull the knee refs back out (set inside _make_leg via a marker).
	_knee_l = _hip_l.get_child(_hip_l.get_child_count() - 1)
	_knee_r = _hip_r.get_child(_hip_r.get_child_count() - 1)

	# Arms (shoulder -> upper -> elbow -> forearm -> hand).
	_sh_l = _make_arm(-0.22, bone)
	_sh_r = _make_arm(0.22, bone)
	_elbow_l = _sh_l.get_child(_sh_l.get_child_count() - 1)
	_elbow_r = _sh_r.get_child(_sh_r.get_child_count() - 1)


# --- Construction -----------------------------------------------------------

func _build_torso(bone: StandardMaterial3D, bone_dk: StandardMaterial3D) -> void:
	# Pelvis.
	add_child(_box(Vector3(0.30, 0.16, 0.17), Vector3(0, 0.94, 0), bone))
	add_child(_box(Vector3(0.12, 0.10, 0.15), Vector3(-0.09, 0.86, 0), bone))   # hip wings
	add_child(_box(Vector3(0.12, 0.10, 0.15), Vector3(0.09, 0.86, 0), bone))
	# Spine (slightly behind the ribs).
	add_child(_bone_seg(0.54, 0.035, bone_dk, Vector3(0, 1.30, 0.04)))
	# Ribcage: tapered hoops + a sternum down the front.
	var widths := [0.34, 0.37, 0.36, 0.30, 0.24]
	for i in range(widths.size()):
		var y := 1.04 + i * 0.085
		var w: float = widths[i]
		add_child(_box(Vector3(w, 0.028, 0.16), Vector3(0, y, -0.015), bone))    # rib hoop
	add_child(_box(Vector3(0.05, 0.34, 0.04), Vector3(0, 1.18, -0.10), bone))    # sternum
	# Shoulders / clavicle.
	add_child(_box(Vector3(0.44, 0.045, 0.06), Vector3(0, 1.47, -0.02), bone))
	# Neck.
	add_child(_bone_seg(0.12, 0.04, bone, Vector3(0, 1.55, 0)))


func _build_skull(bone: StandardMaterial3D) -> void:
	_skull = Node3D.new()
	_skull.position = Vector3(0, 1.6, 0)
	add_child(_skull)

	# Cranium — slightly egg-shaped, narrower at the jaw.
	var cran := _sphere(0.135, bone)
	cran.scale = Vector3(1.0, 1.08, 1.12)
	cran.position = Vector3(0, 0.12, 0.01)
	_skull.add_child(cran)
	# Brow ridge over the sockets.
	_skull.add_child(_box(Vector3(0.23, 0.03, 0.05), Vector3(0, 0.13, -0.115), bone))
	# Cheekbones.
	_skull.add_child(_box(Vector3(0.05, 0.06, 0.05), Vector3(-0.085, 0.04, -0.10), bone))
	_skull.add_child(_box(Vector3(0.05, 0.06, 0.05), Vector3(0.085, 0.04, -0.10), bone))

	# Hollow eye sockets (dark, recessed).
	var sk := _mat(SOCKET)
	for sx in [-1.0, 1.0]:
		var eye := _sphere(0.052, sk)
		eye.scale = Vector3(1.1, 1.0, 0.7)
		eye.position = Vector3(0.062 * sx, 0.10, -0.105)
		_skull.add_child(eye)
	# Nasal cavity — an inverted dark triangle.
	var nose := _cone(0.045, 0.10, SOCKET)
	nose.position = Vector3(0, 0.045, -0.12)
	_skull.add_child(nose)

	# Upper teeth (fixed to the skull).
	_add_teeth(_skull, 0.0, -0.105)

	# Jaw (mandible) on a hinge so it can open.
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0.0, -0.02)
	_skull.add_child(_jaw)
	_jaw.add_child(_box(Vector3(0.17, 0.045, 0.11), Vector3(0, -0.05, -0.06), bone))   # jawbone
	_jaw.add_child(_box(Vector3(0.045, 0.07, 0.05), Vector3(-0.08, -0.01, -0.02), bone))  # jaw corners
	_jaw.add_child(_box(Vector3(0.045, 0.07, 0.05), Vector3(0.08, -0.01, -0.02), bone))
	_add_teeth(_jaw, -0.035, -0.10)   # lower teeth


## A row of small teeth across the front of `parent` at the given y/z.
func _add_teeth(parent: Node3D, y: float, z: float) -> void:
	var tm := _mat(TEETH)
	for i in range(6):
		var x := -0.05 + i * 0.02
		parent.add_child(_box(Vector3(0.016, 0.03, 0.02), Vector3(x, y, z), tm))


## Hip pivot containing a thigh bone and a nested knee pivot (shin + foot). The knee
## pivot is the LAST child so _ready can grab it back.
func _make_leg(x: float, bone: StandardMaterial3D) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0.92, 0)
	add_child(hip)
	hip.add_child(_bone_seg(0.42, 0.05, bone, Vector3(0, -0.21, 0)))    # thigh
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.42, 0)
	knee.add_child(_bone_seg(0.42, 0.045, bone, Vector3(0, -0.21, 0)))  # shin
	knee.add_child(_box(Vector3(0.10, 0.05, 0.22), Vector3(0, -0.42, -0.06), bone))  # foot
	hip.add_child(knee)
	return hip


## Shoulder pivot with an upper-arm bone and a nested elbow pivot (forearm + hand).
func _make_arm(x: float, bone: StandardMaterial3D) -> Node3D:
	var sh := Node3D.new()
	sh.position = Vector3(x, 1.45, 0)
	add_child(sh)
	sh.add_child(_bone_seg(0.34, 0.035, bone, Vector3(0, -0.17, 0)))    # upper arm
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -0.34, 0)
	elbow.add_child(_bone_seg(0.32, 0.03, bone, Vector3(0, -0.16, 0)))  # forearm
	# Bony hand: palm + a few fingers.
	elbow.add_child(_box(Vector3(0.06, 0.07, 0.035), Vector3(0, -0.35, 0), bone))
	for fx in [-0.02, 0.0, 0.02]:
		elbow.add_child(_box(Vector3(0.012, 0.06, 0.012), Vector3(fx, -0.41, 0), bone))
	sh.add_child(elbow)
	return sh


# --- Animation --------------------------------------------------------------

func play_attack(_dir: String = "stab", _charge: float = 0.0) -> void:
	_attack = 0.35


func _process(delta: float) -> void:
	_t += delta
	if _attack > 0.0:
		_attack -= delta

	var moving := move_speed > 0.2
	var spd := 9.0
	var leg_amp := 0.55 if moving else 0.0
	var arm_amp := 0.4 if moving else 0.0
	var s := sin(_t * spd)
	var s2 := sin(_t * spd + PI)

	# Legs swing from the hips; knees bend on the back-swing.
	_hip_l.rotation.x = s * leg_amp
	_hip_r.rotation.x = s2 * leg_amp
	_knee_l.rotation.x = maxf(0.0, -s) * (1.0 if moving else 0.0) + 0.06
	_knee_r.rotation.x = maxf(0.0, -s2) * (1.0 if moving else 0.0) + 0.06

	# Arms counter-swing; right arm is overridden by an attack.
	_sh_l.rotation.x = s2 * arm_amp
	_elbow_l.rotation.x = -0.25
	if _attack > 0.0:
		var a := sin((0.35 - _attack) / 0.35 * PI)   # 0 -> 1 -> 0
		_sh_r.rotation.x = -1.7 * a                  # swing the arm up and forward
		_elbow_r.rotation.x = -0.9 * a
		_jaw.rotation.x = 0.55 * a                   # snap the jaw open
		_skull.rotation.x = -0.18 * a                # lunge the head
	else:
		_sh_r.rotation.x = s * arm_amp
		_elbow_r.rotation.x = -0.25
		_jaw.rotation.x = 0.05 + (0.04 * sin(_t * 7.0) if moving else 0.0)  # faint chatter
		_skull.rotation.x = 0.04 * sin(_t * 1.6)     # idle bob


# --- Mesh helpers -----------------------------------------------------------

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.65
	return m


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	return mi


## A bone segment: a thin capsule centred at `pos` (use for limbs/spine/neck).
func _bone_seg(length: float, radius: float, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = length
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	return mi


func _sphere(r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	return mi


func _cone(base_r: float, h: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = base_r
	c.height = h
	mi.mesh = c
	mi.material_override = _mat(col)
	return mi
