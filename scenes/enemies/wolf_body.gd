extends Node3D
## Code-only quadruped wolf. Legs trot with movement, tail wags, head lunges on
## attack. Faces -Z (enemy.gd's look_at points -Z at the target). Exposes
## `move_speed` and `play_attack()` so enemy.gd drives it like the humanoid.

@export var fur_color := Color(0.5, 0.42, 0.32)

var move_speed := 0.0
var _t := 0.0
var _attack := 0.0
var _legs: Array = []
var _head: Node3D
var _tail: Node3D


func _ready() -> void:
	var mat := _mat(fur_color)
	var dark := _mat(fur_color.darkened(0.3))

	add_child(_box(Vector3(0.42, 0.4, 0.9), Vector3(0.0, 0.55, 0.0), mat))         # body
	add_child(_box(Vector3(0.5, 0.48, 0.32), Vector3(0.0, 0.56, -0.32), mat))      # neck ruff / chest fur

	_head = Node3D.new()
	add_child(_head)
	_head.position = Vector3(0.0, 0.62, -0.6)
	_head.add_child(_box(Vector3(0.32, 0.32, 0.34), Vector3.ZERO, mat))          # head
	_head.add_child(_box(Vector3(0.18, 0.16, 0.22), Vector3(0.0, -0.05, -0.25), dark))  # snout
	_head.add_child(_cone(0.07, 0.16, fur_color, Vector3(-0.11, 0.22, 0.04)))    # ears
	_head.add_child(_cone(0.07, 0.16, fur_color, Vector3(0.11, 0.22, 0.04)))
	for sx in [-1.0, 1.0]:
		_head.add_child(_box(Vector3(0.05, 0.06, 0.04), Vector3(0.09 * sx, 0.04, -0.17), _mat(Color(0.9, 0.85, 0.2))))  # eyes

	_tail = Node3D.new()
	add_child(_tail)
	_tail.position = Vector3(0.0, 0.62, 0.46)
	_tail.add_child(_box(Vector3(0.17, 0.17, 0.34), Vector3(0.0, 0.05, 0.17), mat))   # bushy base
	_tail.add_child(_box(Vector3(0.22, 0.22, 0.22), Vector3(0.0, 0.12, 0.4), dark))   # fluffy tip

	_legs = []
	for lp in [Vector3(-0.16, 0.0, -0.3), Vector3(0.16, 0.0, -0.3), Vector3(-0.16, 0.0, 0.32), Vector3(0.16, 0.0, 0.32)]:
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3(lp.x, 0.4, lp.z)
		pivot.add_child(_box(Vector3(0.12, 0.42, 0.12), Vector3(0.0, -0.21, 0.0), dark))
		_legs.append(pivot)


func play_attack(_dir: String = "stab", _charge: float = 0.0) -> void:
	_attack = 0.3


func _process(delta: float) -> void:
	_t += delta
	if _attack > 0.0:
		_attack -= delta
	var amp := 0.6 if move_speed > 0.2 else 0.0
	for i in range(_legs.size()):
		var phase := 0.0 if i % 2 == 0 else PI
		_legs[i].rotation.x = sin(_t * 10.0 + phase) * amp
	if _tail != null:
		_tail.rotation.y = sin(_t * 6.0) * 0.4
	if _head != null:
		_head.rotation.x = (-0.7 * sin((0.3 - _attack) / 0.3 * PI)) if _attack > 0.0 else 0.0


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	return mi


func _cone(base_r: float, h: float, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = base_r
	c.height = h
	mi.mesh = c
	mi.material_override = _mat(col)
	mi.position = pos
	return mi
