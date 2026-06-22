extends Node3D
## A fake copy of the player (a ghostly humanoid). Enemies in range target it instead
## of the player for a short time, then it vanishes. Pops early if it takes enough hits.
## It is in the "decoys" group, which enemy.gd prefers over the real player.

var life := 8.0
var _hp := 3
var _t := 0.0
var _gone := false
var _aura: MeshInstance3D


func setup(lifetime: float) -> void:
	life = lifetime


func _ready() -> void:
	add_to_group("decoys")
	var packed: PackedScene = load("res://scenes/characters/humanoid.tscn")
	if packed != null:
		add_child(packed.instantiate())
	# A cyan ground ring + light so it reads as a conjured illusion.
	_aura = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.05
	_aura.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	_aura.material_override = mat
	add_child(_aura)
	_aura.position = Vector3.UP * 0.05
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.8, 1.0)
	l.light_energy = 1.2
	l.omni_range = 3.0
	add_child(l)
	l.position = Vector3.UP * 1.0


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		_vanish()
		return
	if _aura != null:
		_aura.rotation.y += delta * 2.0  # gentle shimmer spin


## Enemies hit the decoy instead of the player; it pops after a few hits.
func take_damage(_amount: int) -> void:
	_hp -= 1
	if _hp <= 0:
		_vanish()


func _vanish() -> void:
	if _gone:
		return
	_gone = true
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		sm.radial_segments = 8
		sm.rings = 4
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.8, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.8, 1.0)
		mat.emission_energy_multiplier = 4.0
		m.material_override = mat
		get_tree().current_scene.add_child(m)
		m.global_position = global_position + Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3)
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", m.global_position + Vector3(cos(a), 0.5, sin(a)), 0.4)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.4)
		tw.chain().tween_callback(m.queue_free)
	queue_free()
