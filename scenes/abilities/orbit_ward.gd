extends Node3D
## Orbiting Wards: a pivot (parented to the player) with glowing orbs circling it.
## Each orb damages enemies it sweeps through, with a short per-enemy cooldown so it
## isn't every-frame. Frees itself after `_life` seconds.

var _count := 3
var _radius := 1.8
var _dmg := 3
var _life := 8.0
var _color := Color(0.78, 0.55, 1.0)

var _t := 0.0
var _orbs: Array = []
var _hit_cd := {}  # enemy -> remaining hit cooldown


func setup(count: int, radius: float, dmg: int, life: float, color: Color) -> void:
	_count = maxi(1, count)
	_radius = radius
	_dmg = dmg
	_life = life
	_color = color


func _ready() -> void:
	for i in range(_count):
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 8
		sm.rings = 4
		orb.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _color
		mat.emission_enabled = true
		mat.emission = _color
		mat.emission_energy_multiplier = 4.0
		orb.material_override = mat
		add_child(orb)
		_orbs.append(orb)
		var l := OmniLight3D.new()
		l.light_color = _color
		l.light_energy = 0.6
		l.omni_range = 2.0
		orb.add_child(l)
	get_tree().create_timer(_life).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_t += delta
	for k in _hit_cd.keys():
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0.0:
			_hit_cd.erase(k)
	for i in range(_orbs.size()):
		var a := _t * 4.0 + TAU * float(i) / float(_orbs.size())
		var op := Vector3(cos(a) * _radius, 1.0, sin(a) * _radius)
		_orbs[i].position = op
		var world := global_position + op
		for e in get_tree().get_nodes_in_group("enemies"):
			if _hit_cd.has(e):
				continue
			if world.distance_to(e.global_position) <= 0.7:
				if e.has_method("take_damage"):
					e.take_damage(_dmg)
				_hit_cd[e] = 0.5
