extends StaticBody3D
## A standing torch: wooden post, metal bowl, an emissive flame, and a warm
## OmniLight that flickers. Drop it anywhere (towns, paths, dungeons). Built
## procedurally so it's easy to tweak.

const POST_H := 1.5
const BASE_ENERGY := 2.4

var _light: OmniLight3D
var _flame: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.22, 0.13)
	wood.roughness = 0.9
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.19, 0.18)
	metal.metallic = 0.6
	metal.roughness = 0.5

	# Post.
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.055
	pm.bottom_radius = 0.07
	pm.height = POST_H
	post.mesh = pm
	post.material_override = wood
	post.position = Vector3(0, POST_H * 0.5, 0)
	add_child(post)

	# A thin collider so you can't walk through it.
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.12
	cs.height = POST_H
	col.shape = cs
	col.position = Vector3(0, POST_H * 0.5, 0)
	add_child(col)

	# Fuel bowl at the top.
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.17
	bm.bottom_radius = 0.07
	bm.height = 0.2
	bowl.mesh = bm
	bowl.material_override = metal
	bowl.position = Vector3(0, POST_H + 0.08, 0)
	add_child(bowl)

	# Flame: an emissive sphere squashed into a teardrop.
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color(1.0, 0.55, 0.12)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.55, 0.12)
	fire.emission_energy_multiplier = 3.0
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.13
	fm.height = 0.26
	_flame.mesh = fm
	_flame.material_override = fire
	_flame.scale = Vector3(1.0, 1.7, 1.0)
	_flame.position = Vector3(0, POST_H + 0.32, 0)
	add_child(_flame)

	# Warm flickering light.
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.light_energy = BASE_ENERGY
	_light.omni_range = 9.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, POST_H + 0.35, 0)
	add_child(_light)

	_t = randf() * 10.0   # desync flicker between torches


func _process(delta: float) -> void:
	_t += delta
	# Layered sines give an irregular flicker without per-frame randomness.
	var f := sin(_t * 11.0) * 0.18 + sin(_t * 23.0) * 0.1 + sin(_t * 5.0) * 0.08
	_light.light_energy = BASE_ENERGY + f * BASE_ENERGY
	var s := 1.0 + f * 0.35
	_flame.scale = Vector3(1.0 + f * 0.15, 1.7 * s, 1.0 + f * 0.15)
