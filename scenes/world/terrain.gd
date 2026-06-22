extends Node3D
## Procedural single-landmass terrain.
##   - Visual: a noise heightmap baked into a flat-shaded, height-coloured ArrayMesh.
##   - Collision: a HeightMapShape3D (a heightfield) sampled from the SAME height
##     function — this is the shape Jolt physics handles reliably for terrain, so
##     the ground is solid everywhere (hills + valleys), not just at y=0.
##   - Trees and rocks are scattered across the hills.
## A flat disc near the origin is kept level for the village + player spawn.
##
## To EXPAND / ADJUST later: tweak the consts (SIZE = world span, VIS_GRID = visual
## resolution, HILL_AMP / MOUNTAIN_AMP = height, FLAT_RADIUS = village clearing,
## SCATTER_* = prop counts), or change height_at() for a different landscape.

const SIZE := 500.0          # total width/depth of the landmass (world units)
# VIS_GRID: visual mesh resolution (cells per side). Finer cells keep the visual
# surface closer to the 1-unit collision heightfield.
const VIS_GRID := 200
const FLAT_RADIUS := 28.0    # radius of the flat village clearing at the origin
const FLAT_BLEND := 18.0     # distance over which it blends into hills
const HILL_AMP := 8.0        # rolling-hill height
const MOUNTAIN_AMP := 80.0   # peak height
const SCATTER_TREES := 130
const SCATTER_ROCKS := 80          # rocks scattered anywhere on walkable ground
const SCATTER_ROCKS_HILL := 70     # extra rocks clustered on the foothills/mountains
const TERRAIN_SEED := 20240601

# Grass (MultiMesh tufts on the lower/flatter ground — see _scatter_grass).
const GRASS_TUFTS := 22000         # placement attempts (filtered by height + slope)
const GRASS_MAX_H := 24.0          # no grass high on the mountains
const GRASS_MAX_SLOPE := 2.6       # skip steep faces (slope = summed |dh| over 1.5u)

# Ground palette (height + slope based; see _ground_color).
const C_VALLEY := Color(0.2, 0.4, 0.15)    # dark green, low/flat ground
const C_GRASS := Color(0.34, 0.52, 0.24)   # mid grass
const C_HILL := Color(0.5, 0.52, 0.32)     # drier, lighter hilltops
const C_ROCK := Color(0.46, 0.45, 0.43)    # bare rock
const C_ROCK_D := Color(0.32, 0.31, 0.3)   # dark exposed cliff rock
const C_SNOW := Color(0.92, 0.94, 0.98)    # snow caps

var _noise: FastNoiseLite
var _mnoise: FastNoiseLite
var _cnoise: FastNoiseLite   # high-frequency mottling so the ground isn't flat-coloured


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = TERRAIN_SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_mnoise = FastNoiseLite.new()
	_mnoise.seed = TERRAIN_SEED + 99
	_mnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mnoise.frequency = 0.006
	_cnoise = FastNoiseLite.new()
	_cnoise.seed = TERRAIN_SEED + 33
	_cnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cnoise.frequency = 0.09
	_build_visual()
	_build_collision()
	_scatter()
	_scatter_grass()


## World height at an (x, z) position — flat near the origin, hills + mountains out.
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * HILL_AMP
	h += maxf(0.0, _mnoise.get_noise_2d(x, z)) * MOUNTAIN_AMP
	var d := Vector2(x, z).length()
	if d < FLAT_RADIUS:
		return 0.0
	elif d < FLAT_RADIUS + FLAT_BLEND:
		return lerpf(0.0, h, (d - FLAT_RADIUS) / FLAT_BLEND)
	return h


func _build_visual() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := SIZE / float(VIS_GRID)
	var half := SIZE * 0.5
	for i in range(VIS_GRID):
		for j in range(VIS_GRID):
			var x0 := -half + i * cell
			var z0 := -half + j * cell
			var x1 := x0 + cell
			var z1 := z0 + cell
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p11 := Vector3(x1, height_at(x1, z1), z1)
			_add_tri(st, p00, p01, p11)
			_add_tri(st, p00, p11, p10)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)


## Solid collision via a heightfield sampled at 1 world unit per cell. No scaling
## (avoids physics-engine scale quirks); covers exactly the same -SIZE/2..SIZE/2 area.
func _build_collision() -> void:
	var half := SIZE * 0.5
	var w := int(SIZE) + 1  # points per side, one per world unit
	var data := PackedFloat32Array()
	data.resize(w * w)
	for d in range(w):
		for wi in range(w):
			data[d * w + wi] = height_at(float(wi) - half, float(d) - half)
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = w
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Face slope (0 = flat ground, 1 = vertical cliff) shared by the triangle's verts.
	var n := (b - a).cross(c - a)
	if n.length() > 0.0001:
		n = n.normalized()
	var slope := 1.0 - absf(n.y)
	st.set_color(_ground_color(a.y, slope, a.x, a.z))
	st.add_vertex(a)
	st.set_color(_ground_color(b.y, slope, b.x, b.z))
	st.add_vertex(b)
	st.set_color(_ground_color(c.y, slope, c.x, c.z))
	st.add_vertex(c)


## Ground colour from elevation AND slope: dark green valleys -> grass -> drier
## hilltops -> rock, with snow on the peaks and bare rock on steep faces. A little
## high-frequency noise mottles it so it never reads as one flat colour.
func _ground_color(h: float, slope: float, x: float, z: float) -> Color:
	var base: Color
	if h < 2.0:
		base = C_VALLEY.lerp(C_GRASS, clampf(h / 2.0, 0.0, 1.0))
	elif h < 14.0:
		base = C_GRASS.lerp(C_HILL, (h - 2.0) / 12.0)
	elif h < 30.0:
		base = C_HILL.lerp(C_ROCK, (h - 14.0) / 16.0)
	elif h < 46.0:
		base = C_ROCK
	else:
		base = C_ROCK.lerp(C_SNOW, clampf((h - 46.0) / 8.0, 0.0, 1.0))
	# Steep faces below the snow line are exposed rock regardless of height.
	if h < 46.0 and slope > 0.4:
		base = base.lerp(C_ROCK_D, clampf((slope - 0.4) / 0.5, 0.0, 1.0))
	# Subtle brightness mottle for a textured feel.
	var m := _cnoise.get_noise_2d(x, z) * 0.07
	return Color(clampf(base.r + m, 0.0, 1.0), clampf(base.g + m, 0.0, 1.0), clampf(base.b + m, 0.0, 1.0))


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TERRAIN_SEED + 7
	var tree_scene: PackedScene = load("res://scenes/props/tree.tscn")
	var rock_scene: PackedScene = load("res://scenes/props/rock.tscn")
	var trees := Node3D.new()
	trees.name = "ScatterTrees"
	add_child(trees)
	var rocks := Node3D.new()
	rocks.name = "ScatterRocks"
	add_child(rocks)
	for i in range(SCATTER_TREES):
		_place(tree_scene, trees, rng, 14.0)             # forests on the lowlands/foothills
	for i in range(SCATTER_ROCKS):
		_place(rock_scene, rocks, rng, 50.0)             # rocks anywhere on walkable ground
	for i in range(SCATTER_ROCKS_HILL):
		_place(rock_scene, rocks, rng, 60.0, 12.0)       # clustered up the foothills/mountains


func _place(scene: PackedScene, parent: Node, rng: RandomNumberGenerator, max_h: float, min_h: float = -1000.0) -> void:
	if scene == null:
		return
	for attempt in range(6):
		var x := rng.randf_range(-SIZE * 0.45, SIZE * 0.45)
		var z := rng.randf_range(-SIZE * 0.45, SIZE * 0.45)
		if Vector2(x, z).length() < FLAT_RADIUS + 6.0:
			continue
		var h := height_at(x, z)
		if h > max_h or h < min_h:
			continue
		var inst: Node3D = scene.instantiate()
		parent.add_child(inst)
		inst.global_position = Vector3(x, h, z)
		return


## Grass coverage as a single MultiMesh of small tufts (ONE draw call). Tufts are
## scattered on the lower/flatter ground and skipped on steep faces + high mountains.
## Tradeoff: this reads as scattered grass clumps, not a dense continuous lawn, which
## keeps it to one cheap draw call instead of millions of blades. Tune via GRASS_TUFTS.
func _scatter_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TERRAIN_SEED + 21
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_grass_tuft(rng)

	var xforms: Array[Transform3D] = []
	for i in range(GRASS_TUFTS):
		var x := rng.randf_range(-SIZE * 0.48, SIZE * 0.48)
		var z := rng.randf_range(-SIZE * 0.48, SIZE * 0.48)
		var h := height_at(x, z)
		if h > GRASS_MAX_H:
			continue
		var e := 1.5
		var slope := absf(height_at(x + e, z) - height_at(x - e, z)) + absf(height_at(x, z + e) - height_at(x, z - e))
		if slope > GRASS_MAX_SLOPE:
			continue
		var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4))
		xforms.append(Transform3D(b, Vector3(x, h, z)))

	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # grass is small; skip shadows
	add_child(mmi)


## One grass tuft = a few splayed flat blades (dark base -> lighter tip vertex colours).
func _make_grass_tuft(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_col := Color(0.2, 0.38, 0.14)
	var tip_col := Color(0.46, 0.64, 0.3)
	for i in range(5):
		var ang := rng.randf() * TAU
		var fwd := Vector3(cos(ang), 0.0, sin(ang))
		var perp := Vector3(-sin(ang), 0.0, cos(ang)) * 0.03
		var off := fwd * rng.randf_range(0.0, 0.06)
		var hgt := rng.randf_range(0.3, 0.55)
		var tip := off + fwd * rng.randf_range(0.05, 0.16) + Vector3.UP * hgt
		st.set_color(base_col)
		st.add_vertex(off - perp)
		st.set_color(base_col)
		st.add_vertex(off + perp)
		st.set_color(tip_col)
		st.add_vertex(tip)
	st.generate_normals()
	return st.commit()
