extends Node3D
## A burning rock that falls straight down onto a fixed target point, trailing
## embers, and EXPLODES on impact — dealing AoE damage to every enemy within
## `radius`. Spawned by the player's Meteor ability after its windup.

var target := Vector3.ZERO
var fall_speed := 26.0
var damage := 9
var radius := 3.0
var _ember_t := 0.0


## Called right after the player spawns + positions the meteor above the target.
func setup(target_point: Vector3, dmg: int, rad: float, sz: float, color: Color) -> void:
	target = target_point
	damage = dmg
	radius = rad
	scale = Vector3.ONE * sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.12, 0.08)   # dark rock
	mat.emission_enabled = true
	mat.emission = color                          # burning glow
	mat.emission_energy_multiplier = 3.0
	$Rock.material_override = mat
	$Light.light_color = color


func _physics_process(delta: float) -> void:
	global_position += Vector3.DOWN * fall_speed * delta
	rotation.x += delta * 6.0   # tumble
	rotation.z += delta * 4.0
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 0.025
		_spawn_ember()
	if global_position.y <= target.y:
		_impact()


func _impact() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var p: Vector3 = e.global_position
		if Vector2(p.x - target.x, p.z - target.z).length() <= radius and e.has_method("take_damage"):
			e.take_damage(damage)
	_explosion()
	queue_free()


func _spawn_ember() -> void:
	var m := _make_glow_sphere(0.12, Color(1, 0.6, 0.2))
	m.global_position = global_position
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.45)
	tw.tween_callback(m.queue_free)


func _explosion() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.5, 0.15)
	flash.light_energy = 6.0
	flash.omni_range = radius * 2.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = target + Vector3.UP * 0.5
	get_tree().create_timer(0.25).timeout.connect(flash.queue_free)
	for i in range(16):
		var a := TAU * float(i) / 16.0
		var m := _make_glow_sphere(0.2, Color(1, 0.5, 0.12))
		m.global_position = target + Vector3.UP * 0.3
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", target + Vector3(cos(a) * radius, 0.4, sin(a) * radius), 0.4)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.4)
		tw.chain().tween_callback(m.queue_free)


func _make_glow_sphere(r: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8  # low-poly: cheap to upload, avoids spawn stutter
	sm.rings = 4
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	return m
