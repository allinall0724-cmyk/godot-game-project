extends Area3D
## Magic projectile. Travels under an optional velocity model:
##   - straight (default): flies along its initial direction
##   - gravity > 0: arcs and drops (Boulder Toss, lobbed bombs)
##   - homing > 0: curves toward the nearest enemy (Spirit Wisps)
## Hits the first thing with take_damage() (or pops on terrain). With explode_radius
## it bursts for AoE on impact. Leaves a glowing trail when trail_on is set.

var direction := Vector3.FORWARD
var speed := 18.0
var life := 1.4
var damage := 2
var pierce := false        # if true, passes through enemies (Comet / Ice Lance)
var _hit: Array = []       # enemies already damaged (for pierce)

# Optional on-hit status.
var slow_factor := 0.0
var slow_dur := 0.0
var knock_force := 0.0

# Motion modifiers.
var grav_accel := 0.0      # downward accel; >0 makes the shot arc and drop (Area3D has its own 'gravity')
var homing := 0.0          # steer strength toward nearest enemy (0 = none)
var trail_on := false

# Impact AoE (lobbed bombs). 0 = single-target hit.
var explode_radius := 0.0
var explode_color := Color(1, 0.5, 0.15)

var _vel := Vector3.ZERO
var _color := Color(1, 0.5, 0.15)
var _trail_t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## spd/sc/color let element spells make bigger/faster/recoloured projectiles;
## piercing shots pass through enemies.
func setup(dir: Vector3, dmg: int, spd: float = 18.0, sc: float = 1.0, color: Color = Color(1, 0.5, 0.15), pierce_through: bool = false) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	pierce = pierce_through
	scale = Vector3.ONE * sc
	_color = color
	_vel = direction * speed
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	$Mesh.material_override = mat
	$Light.light_color = color
	$Light.light_energy = 2.0


## Optional: make this projectile slow and/or knock back what it hits.
func set_on_hit(slow_f: float, slow_t: float, knock: float) -> void:
	slow_factor = slow_f
	slow_dur = slow_t
	knock_force = knock


## Optional motion: gravity (arc/drop), homing strength, trail toggle.
func set_motion(grav: float, home: float, trail: bool) -> void:
	grav_accel = grav
	homing = home
	trail_on = trail


## Optional: burst for AoE on impact instead of a single hit.
func set_explode(radius: float, color: Color) -> void:
	explode_radius = radius
	explode_color = color


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var t = _nearest_enemy()
		if t != null:
			var want: Vector3 = (t.global_position + Vector3.UP * 0.8 - global_position).normalized()
			_vel = _vel.lerp(want * _vel.length(), clampf(homing * delta, 0.0, 1.0))
	if grav_accel > 0.0:
		_vel += Vector3.DOWN * grav_accel * delta
	global_position += _vel * delta

	if trail_on:
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			_spawn_trail()

	life -= delta
	if life <= 0.0:
		if explode_radius > 0.0:
			_explode()
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("local_player"):
		return  # ignore the caster

	# Lobbed bombs burst on ANY solid contact (enemy or ground).
	if explode_radius > 0.0:
		_explode()
		queue_free()
		return

	if body.has_method("take_damage"):
		if body in _hit:
			return
		_hit.append(body)
		body.take_damage(damage)
		if slow_factor > 0.0 and body.has_method("apply_slow"):
			body.apply_slow(slow_factor, slow_dur)
		if knock_force > 0.0 and body.has_method("apply_knockback"):
			body.apply_knockback(direction * knock_force)
		_impact_flash()
		if pierce:
			return  # keep flying through enemies
	queue_free()  # pop on a solid hit (wall/ground/tree), or any hit if not piercing


func _nearest_enemy():
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _explode() -> void:
	var col := explode_color
	for e in get_tree().get_nodes_in_group("enemies"):
		var p: Vector3 = e.global_position
		if Vector2(p.x - global_position.x, p.z - global_position.z).length() <= explode_radius and e.has_method("take_damage"):
			e.take_damage(damage)
			if slow_factor > 0.0 and e.has_method("apply_slow"):
				e.apply_slow(slow_factor, slow_dur)
	# Flash + expanding shards.
	var flash := OmniLight3D.new()
	flash.light_color = col
	flash.light_energy = 5.0
	flash.omni_range = explode_radius * 2.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.2).timeout.connect(flash.queue_free)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var m := _glow(0.18, col)
		m.global_position = global_position
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", global_position + Vector3(cos(a) * explode_radius, 0.3, sin(a) * explode_radius), 0.35)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.35)
		tw.chain().tween_callback(m.queue_free)


func _impact_flash() -> void:
	for i in range(5):
		var m := _glow(0.12, _color)
		m.global_position = global_position
		var dir := Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)).normalized()
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", global_position + dir * 0.8, 0.25)
		tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.25)
		tw.chain().tween_callback(m.queue_free)


func _spawn_trail() -> void:
	var m := _glow(0.13 * scale.x, _color)
	m.global_position = global_position
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 0.02, 0.28)
	tw.chain().tween_callback(m.queue_free)


func _glow(r: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.5
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	return m
