extends StaticBody3D
## Procedural low-poly boulder. Builds an irregular faceted rock mesh in code so no
## two rocks look the same: a random size class (pebble -> boulder), per-vertex
## radial jitter for a craggy silhouette, per-facet shading, and a randomized
## grey/brown tint. Only the larger classes get collision (pebbles are decorative).

const SIZE_CLASSES := [
	{"r": 0.16, "jitter": 0.38, "collide": false},  # pebble
	{"r": 0.42, "jitter": 0.34, "collide": false},  # small
	{"r": 0.85, "jitter": 0.28, "collide": true},   # medium
	{"r": 1.7,  "jitter": 0.24, "collide": true},   # boulder
]
const CLASS_WEIGHTS := [0.34, 0.34, 0.22, 0.10]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cls: Dictionary = SIZE_CLASSES[_weighted_pick(rng)]
	var r := float(cls["r"]) * rng.randf_range(0.85, 1.2)
	var jitter := float(cls["jitter"])
	var base_col := _rock_color(rng)

	var mi := MeshInstance3D.new()
	mi.mesh = _make_rock_mesh(rng, r, jitter, base_col)
	mi.position.y = r * 0.55  # lift so the flattened base rests on the ground
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)

	rotation.y = rng.randf() * TAU

	if bool(cls["collide"]):
		var col_shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = r * 0.7
		col_shape.shape = sphere
		col_shape.position.y = r * 0.5
		add_child(col_shape)


func _weighted_pick(rng: RandomNumberGenerator) -> int:
	var t := rng.randf()
	var acc := 0.0
	for i in range(CLASS_WEIGHTS.size()):
		acc += float(CLASS_WEIGHTS[i])
		if t <= acc:
			return i
	return CLASS_WEIGHTS.size() - 1


func _rock_color(rng: RandomNumberGenerator) -> Color:
	var g := rng.randf_range(0.36, 0.56)
	var warm := rng.randf_range(-0.03, 0.07)  # + = browner, - = cooler grey
	return Color(clampf(g + warm, 0.0, 1.0), clampf(g + warm * 0.4, 0.0, 1.0), clampf(g - warm * 0.3, 0.0, 1.0))


## A jittered low-poly sphere (single apex top + flattened bottom) -> craggy rock.
func _make_rock_mesh(rng: RandomNumberGenerator, r: float, jitter: float, base_col: Color) -> ArrayMesh:
	var lat_div := 5
	var segs := 8
	var rings: Array = []
	for k in range(lat_div):
		var lat := PI * float(k + 1) / float(lat_div + 1)
		var cy := cos(lat)
		var sy := sin(lat)
		var row := PackedVector3Array()
		for j in range(segs):
			var lon := TAU * float(j) / float(segs)
			var rad := r * (1.0 + rng.randf_range(-jitter, jitter))
			row.append(Vector3(sy * cos(lon) * rad, cy * rad * 0.9, sy * sin(lon) * rad))
		rings.append(row)
	var top := Vector3(0.0, r * (1.0 + rng.randf_range(-jitter, jitter)) * 0.9, 0.0)
	var bot := Vector3(0.0, -r * 0.55, 0.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Top fan.
	for j in range(segs):
		var j2 := (j + 1) % segs
		_rock_tri(st, rng, base_col, top, rings[0][j], rings[0][j2])
	# Middle bands.
	for k in range(lat_div - 1):
		for j in range(segs):
			var j2 := (j + 1) % segs
			_rock_tri(st, rng, base_col, rings[k][j], rings[k + 1][j], rings[k][j2])
			_rock_tri(st, rng, base_col, rings[k][j2], rings[k + 1][j], rings[k + 1][j2])
	# Bottom fan.
	var last := lat_div - 1
	for j in range(segs):
		var j2 := (j + 1) % segs
		_rock_tri(st, rng, base_col, bot, rings[last][j2], rings[last][j])
	st.generate_normals()
	return st.commit()


func _rock_tri(st: SurfaceTool, rng: RandomNumberGenerator, base_col: Color, a: Vector3, b: Vector3, c: Vector3) -> void:
	var shade := 1.0 - rng.randf() * 0.22  # per-facet shading for a craggy read
	var col := Color(base_col.r * shade, base_col.g * shade, base_col.b * shade)
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)
