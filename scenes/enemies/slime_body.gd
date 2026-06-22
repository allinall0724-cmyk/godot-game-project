extends Node3D
## Code-only slime blob. Squashes/stretches as it hops. Exposes `move_speed` and
## `play_attack()` so enemy.gd can drive it exactly like the humanoid visual.
## The base stays planted at y=0 (the body origin) while it stretches.

@export var slime_color := Color(0.3, 0.8, 0.4)

const BASE_R := 0.42

var move_speed := 0.0
var _t := 0.0
var _attack := 0.0
var _body: MeshInstance3D


func _ready() -> void:
	_body = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BASE_R
	sm.height = BASE_R * 2.0
	sm.radial_segments = 12
	sm.rings = 7
	_body.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = slime_color
	mat.roughness = 0.06   # very glossy gel
	mat.metallic = 0.25
	mat.emission_enabled = true
	mat.emission = slime_color
	mat.emission_energy_multiplier = 0.45
	_body.material_override = mat
	add_child(_body)
	_body.position = Vector3(0.0, BASE_R, 0.0)

	# Glossy highlight spot (the bright reflection blob).
	var hi := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.1
	hs.height = 0.2
	hs.radial_segments = 8
	hs.rings = 4
	hi.mesh = hs
	var him := StandardMaterial3D.new()
	him.albedo_color = Color(1, 1, 1)
	him.emission_enabled = true
	him.emission = Color(1, 1, 1)
	him.emission_energy_multiplier = 1.2
	hi.material_override = him
	_body.add_child(hi)
	hi.position = Vector3(-0.16, 0.22, -0.3)
	hi.scale = Vector3(1.0, 0.7, 0.5)

	# Eyes.
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.065
		es.height = 0.13
		es.radial_segments = 8
		es.rings = 4
		eye.mesh = es
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.04, 0.04, 0.05)
		eye.material_override = em
		_body.add_child(eye)
		eye.position = Vector3(0.13 * sx, 0.04, -0.35)
	# Little mouth.
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.12, 0.03, 0.02)
	mouth.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.04, 0.04, 0.05)
	mouth.material_override = mmat
	_body.add_child(mouth)
	mouth.position = Vector3(0.0, -0.1, -0.4)
	# Top droplet nub.
	var nub := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.07
	ns.height = 0.18
	ns.radial_segments = 8
	ns.rings = 4
	nub.mesh = ns
	nub.material_override = mat
	_body.add_child(nub)
	nub.position = Vector3(0.0, 0.42, 0.0)


func play_attack(_dir: String = "stab", _charge: float = 0.0) -> void:
	_attack = 0.3


func _process(delta: float) -> void:
	_t += delta
	if _attack > 0.0:
		_attack -= delta
	var moving := move_speed > 0.2
	var hop := absf(sin(_t * (8.0 if moving else 2.5)))
	var stretch := 1.0 + hop * (0.25 if moving else 0.06)
	var squash := 1.0 / sqrt(stretch)
	if _attack > 0.0:
		stretch = 0.7
		squash = 1.3  # squish lunge
	_body.scale = Vector3(squash, stretch, squash)
	# Keep the base planted, bob up with the hop.
	_body.position.y = BASE_R * stretch + (hop * 0.18 if moving else 0.0)
