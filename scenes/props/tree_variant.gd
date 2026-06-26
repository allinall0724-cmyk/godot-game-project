extends StaticBody3D
## Procedural tree with several KINDS so the biomes look distinct:
##   0 BROADLEAF — rounded green canopy (meadow / forest edges)
##   1 PINE      — tall stacked-cone conifer (forest)
##   2 DARK      — tall, gnarled, near-black canopy (dark forest)
## Origin sits at the base; collision is the trunk. Set `kind` BEFORE add_child so
## _ready builds the right one.

const BROADLEAF := 0
const PINE := 1
const DARK := 2

@export var kind := 0


func _ready() -> void:
	rotation.y = randf() * TAU
	var s := randf_range(0.85, 1.25)
	scale = Vector3(s, s, s)
	match kind:
		PINE: _build_pine()
		DARK: _build_dark()
		_: _build_broadleaf()


func _build_broadleaf() -> void:
	var trunk := _mat(Color(0.4, 0.26, 0.13))
	_cyl(0.26, 0.22, 2.2, Vector3(0, 1.1, 0), trunk, true)
	var c1 := _mat(Color(0.16, 0.42, 0.18))
	var c2 := _mat(Color(0.24, 0.52, 0.24))
	_sphere(1.5, Vector3(0, 2.9, 0), c1)
	_sphere(1.1, Vector3(0.2, 3.7, -0.1), c2)
	_sphere(1.0, Vector3(-0.3, 3.5, 0.2), c1)


func _build_pine() -> void:
	var trunk := _mat(Color(0.34, 0.23, 0.13))
	_cyl(0.18, 0.16, 3.4, Vector3(0, 1.7, 0), trunk, true)
	var needle := _mat(Color(0.12, 0.32, 0.18))
	_cone(1.4, 1.7, Vector3(0, 2.4, 0), needle)
	_cone(1.1, 1.5, Vector3(0, 3.3, 0), needle)
	_cone(0.8, 1.3, Vector3(0, 4.1, 0), needle)
	_cone(0.5, 1.1, Vector3(0, 4.8, 0), needle)


func _build_dark() -> void:
	# A taller, leaning, near-bare trunk with sparse blackish foliage.
	rotation.x = randf_range(-0.06, 0.06)
	rotation.z = randf_range(-0.06, 0.06)
	var trunk := _mat(Color(0.16, 0.14, 0.13))
	_cyl(0.22, 0.14, 4.4, Vector3(0, 2.2, 0), trunk, true)
	# A couple of bare branch stubs.
	var br := _box(Vector3(0.12, 0.1, 1.4), Vector3(0.5, 3.4, 0), trunk, false)
	br.rotation = Vector3(0, 0.4, 0.5)
	var br2 := _box(Vector3(0.12, 0.1, 1.2), Vector3(-0.45, 3.9, 0.1), trunk, false)
	br2.rotation = Vector3(0, -0.5, -0.5)
	# Sparse, very dark canopy.
	var leaf := _mat(Color(0.08, 0.11, 0.09))
	_sphere(1.1, Vector3(0, 4.5, 0), leaf)
	_sphere(0.8, Vector3(0.4, 5.0, -0.2), leaf)
	_sphere(0.7, Vector3(-0.3, 4.9, 0.3), leaf)


# --- Mesh helpers ------------------------------------------------------------

func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	return m


func _cyl(bottom_r: float, top_r: float, h: float, pos: Vector3, mat: StandardMaterial3D, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_r
	cm.top_radius = top_r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = maxf(bottom_r, 0.3)
		cs.height = h
		col.shape = cs
		col.position = pos
		add_child(col)


func _cone(base_r: float, h: float, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = base_r
	cm.top_radius = 0.0
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _sphere(r: float, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.9
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D, _collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
