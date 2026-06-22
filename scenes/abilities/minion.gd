extends Node3D
## A temporary summoned ally — a fire elemental or a stone golem. It moves toward
## the nearest enemy, strikes it on a cooldown, and vanishes after `life` seconds.
## Code-only primitive visuals. Spawned by the player's summon spells.

var kind := "fire"            # "fire" | "golem"
var damage := 2
var life := 12.0
var move_speed := 4.0
var attack_range := 1.7
var attack_interval := 0.8
var color := Color(1, 0.5, 0.15)

var _atk_cd := 0.0
var _t := 0.0


## Called right after instantiate(), BEFORE add_child (so _ready can use these).
func setup(k: String, dmg: int, lifetime: float, col: Color) -> void:
	kind = k
	damage = dmg
	life = lifetime
	color = col
	if k == "golem":
		move_speed = 2.6
		attack_interval = 1.1
		attack_range = 2.0


func _ready() -> void:
	add_to_group("summons")
	_build_visual()
	get_tree().create_timer(life).timeout.connect(_vanish)


func _vanish() -> void:
	for i in range(8):
		var a := TAU * float(i) / 8.0
		_puff(global_position + Vector3(cos(a) * 0.3, 0.6, sin(a) * 0.3))
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _atk_cd > 0.0:
		_atk_cd -= delta
	var e = _nearest_enemy()
	var base_y := _ground_y() + (0.9 if kind == "fire" else 0.0)
	if e != null:
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > attack_range:
			global_position += to.normalized() * move_speed * delta
			if d > 0.05:
				look_at(global_position + Vector3(to.x, 0.0, to.z), Vector3.UP)
		elif _atk_cd <= 0.0:
			_atk_cd = attack_interval
			if e.has_method("take_damage"):
				e.take_damage(damage)
			_attack_fx(e.global_position)
	var hover := (sin(_t * 4.0) * 0.12) if kind == "fire" else 0.0
	global_position.y = lerpf(global_position.y, base_y + hover, clampf(delta * 8.0, 0.0, 1.0))


func _nearest_enemy():
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _ground_y() -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 30.0, global_position - Vector3.UP * 60.0)
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		return float(hit["position"].y)
	return global_position.y


func _build_visual() -> void:
	if kind == "golem":
		_add_box(Vector3(0, 0.55, 0), Vector3(0.75, 1.0, 0.5), color)
		_add_box(Vector3(0, 1.2, 0), Vector3(0.45, 0.42, 0.45), color.darkened(0.12))
		_add_box(Vector3(-0.52, 0.65, 0), Vector3(0.26, 0.8, 0.26), color)
		_add_box(Vector3(0.52, 0.65, 0), Vector3(0.26, 0.8, 0.26), color)
		_add_light(color, 0.8, 3.0)
	else:
		_add_sphere(Vector3(0, 0.55, 0), 0.36, color)
		_add_sphere(Vector3(0, 0.98, 0), 0.22, color.lerp(Color(1, 1, 0.6), 0.5))
		_add_sphere(Vector3(0.18, 0.6, 0.1), 0.14, color)
		_add_sphere(Vector3(-0.16, 0.66, -0.1), 0.13, color)
		_add_light(color, 1.6, 3.5)


func _add_box(pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, kind == "fire")
	add_child(mi)
	mi.position = pos


func _add_sphere(pos: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _mat(col, true)
	add_child(mi)
	mi.position = pos


func _add_light(col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	l.position = Vector3.UP * 0.7


func _mat(col: Color, glow: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	if glow:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 3.0
	return mat


func _attack_fx(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.material_override = _mat(color, true)
	get_tree().current_scene.add_child(m)
	m.global_position = pos + Vector3.UP * 0.8
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(m.queue_free)


func _puff(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.material_override = _mat(color, true)
	get_tree().current_scene.add_child(m)
	m.global_position = pos
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_property(m, "global_position", pos + Vector3.UP * 0.6, 0.4)
	tw.chain().tween_callback(m.queue_free)
