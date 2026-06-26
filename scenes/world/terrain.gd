extends Node3D
## Procedural single-landmass terrain.
##   - Visual: a noise heightmap baked into a flat-shaded, height-coloured ArrayMesh.
##   - Collision: a HeightMapShape3D (a heightfield) sampled from the SAME height
##     function — this is the shape Jolt physics handles reliably for terrain, so
##     the ground is solid everywhere (hills + valleys), not just at y=0.
##   - Trees and rocks are scattered across the hills.
##   - CAVES are bored INTO the mountains (not separate structures): each cave carves
##     a level floor + entrance slot down into the heightmap on a steep mountainside,
##     then an arched rock roof + chamber dome is laid over the carved-out space.
## A flat disc near the origin is kept level for the village + player spawn.
##
## To EXPAND / ADJUST later: tweak the consts (SIZE = world span, VIS_GRID = visual
## resolution, HILL_AMP / MOUNTAIN_AMP = height, FLAT_RADIUS = village clearing,
## SCATTER_* = prop counts, CAVE_* = cave shape/placement), or change _base_height()
## for a different landscape.

const SIZE := 500.0          # total width/depth of the landmass (world units)
# VIS_GRID: visual mesh resolution (cells per side). Finer cells keep the visual
# surface closer to the 1-unit collision heightfield AND resolve cave openings.
const VIS_GRID := 240
const FLAT_RADIUS := 28.0    # radius of the flat village clearing at the origin
const FLAT_BLEND := 18.0     # distance over which it blends into hills
const HILL_AMP := 8.0        # rolling-hill height
const MOUNTAIN_AMP := 95.0   # peak height
const SCATTER_TREES := 130
const SCATTER_ROCKS := 80          # rocks scattered anywhere on walkable ground
const SCATTER_ROCKS_HILL := 70     # extra rocks clustered on the foothills/mountains
const TERRAIN_SEED := 20240601

# Caves (carved into the mountainsides — see _setup_caves / _build_caves).
const CAVE_COUNT := 4               # how many caves to bore into the mountains
const CAVE_LENGTH := 22.0           # how far the tunnel reaches into the mountain
const CAVE_HALF_WIDTH := 4.2        # half-width of the corridor / entrance
const CAVE_CEIL := 5.5              # arched ceiling height above the cave floor
const CAVE_BLEND := 6.0             # how far the carve blends back into the slope
const CHAMBER_R := 8.5              # radius of the chamber at the tunnel's end
const CHAMBER_H := 9.5              # dome height of the chamber
const CAVE_MIN_H := 24.0           # entrances sit in this elevation band on the
const CAVE_MAX_H := 62.0           #   mountainsides (not valleys, not snow peaks)
const CAVE_MIN_SLOPE := 0.55        # only on genuinely steep faces (rise per unit)
const CAVE_MIN_SEP := 90.0          # keep caves spread across different mountains

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
var _wnoise: FastNoiseLite   # domain-warp noise (meandering ridgelines)
var _rnoise: FastNoiseLite   # low-frequency mask: where mountain ranges are allowed

# Each cave: { mouth:Vector2 (xz), dir:Vector2 (unit, into the mountain),
#              floor_y:float, half_width, length, chamber_r }
var _caves: Array[Dictionary] = []

# Flat building pads / points-of-interest. The village clearing at the origin is
# handled by FLAT_RADIUS in _landscape_height; THESE are the other "locations" (the
# cursed evil-totem sites) that also get a flattened patch so structures and fights
# sit on level ground. Coordinates match spawn_director.gd EVIL_SITES.
const SITE_FLAT_R := 15.0       # fully-flat radius of each pad
const SITE_FLAT_BLEND := 14.0   # blend ring back into the natural terrain
const EVIL_SITES_XZ := [Vector2(150, 110), Vector2(-170, 150), Vector2(80, -180)]
var _site_levels: Array = []    # the flattened height chosen for each evil site


func _ready() -> void:
	add_to_group("terrain")   # so the spawn director can sample ground height
	_noise = FastNoiseLite.new()
	_noise.seed = TERRAIN_SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_mnoise = FastNoiseLite.new()
	_mnoise.seed = TERRAIN_SEED + 99
	_mnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mnoise.frequency = 0.0055
	_cnoise = FastNoiseLite.new()
	_cnoise.seed = TERRAIN_SEED + 33
	_cnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cnoise.frequency = 0.09
	_wnoise = FastNoiseLite.new()
	_wnoise.seed = TERRAIN_SEED + 71
	_wnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_wnoise.frequency = 0.01
	_rnoise = FastNoiseLite.new()
	_rnoise.seed = TERRAIN_SEED + 17
	_rnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_rnoise.frequency = 0.0028
	_setup_site_flats()  # choose each location's level BEFORE anything samples height
	_setup_caves()      # must run before the mesh/collision so the carve is baked in
	_build_visual()
	_build_collision()
	_build_caves()      # roof + chamber geometry over the carved-out space
	_scatter()
	_scatter_grass()


## World height at an (x, z) position, INCLUDING flat location pads + cave carving.
func height_at(x: float, z: float) -> float:
	return _apply_caves(x, z, _base_height(x, z))


## Pick a flat level for each evil site = the natural landscape height at its centre.
## Done once, up front, so the flattened pad is identical everywhere it's sampled.
func _setup_site_flats() -> void:
	_site_levels.clear()
	for c in EVIL_SITES_XZ:
		_site_levels.append(_landscape_height(c.x, c.y))


## World positions (with the flattened Y) of the evil sites, for the spawn director.
func evil_sites() -> Array:
	var out: Array = []
	for i in range(EVIL_SITES_XZ.size()):
		var c: Vector2 = EVIL_SITES_XZ[i]
		out.append(Vector3(c.x, _site_levels[i], c.y))
	return out


## Landscape height with the flat location pads applied (village clearing lives in
## _landscape_height; the evil sites are flattened to their chosen level here).
func _base_height(x: float, z: float) -> float:
	var h := _landscape_height(x, z)
	var p := Vector2(x, z)
	for i in range(EVIL_SITES_XZ.size()):
		var d := p.distance_to(EVIL_SITES_XZ[i])
		if d < SITE_FLAT_R + SITE_FLAT_BLEND:
			var t := 1.0 - smoothstep(SITE_FLAT_R, SITE_FLAT_R + SITE_FLAT_BLEND, d)
			h = lerpf(h, _site_levels[i], t)
	return h


## Bare landscape height (no pads, no caves) — flat near the origin, rolling hills,
## and ridged mountain ranges further out. Domain-warped for natural meandering and
## masked so mountains form ranges instead of sprouting everywhere.
func _landscape_height(x: float, z: float) -> float:
	# Domain warp: sample the terrain at a wobbled position so ridgelines meander.
	var wx := x + _wnoise.get_noise_2d(x, z) * 22.0
	var wz := z + _wnoise.get_noise_2d(x + 500.0, z - 500.0) * 22.0
	# Rolling hills everywhere.
	var h := _noise.get_noise_2d(wx, wz) * HILL_AMP
	# Mountain ranges: ridged multifractal (sharp crests), masked into bands.
	var mask := smoothstep(0.12, 0.55, _rnoise.get_noise_2d(x, z) * 0.5 + 0.5)
	if mask > 0.0:
		var r1 := 1.0 - absf(_mnoise.get_noise_2d(wx, wz))
		r1 *= r1
		var r2 := 1.0 - absf(_mnoise.get_noise_2d(wx * 2.3, wz * 2.3))
		r2 *= r2
		var r3 := 1.0 - absf(_mnoise.get_noise_2d(wx * 4.7, wz * 4.7))
		r3 *= r3
		var ridge := r1 * 0.62 + r2 * 0.28 + r3 * 0.10
		h += mask * ridge * MOUNTAIN_AMP
	# Keep the village clearing flat, then blend out into the landscape.
	var d := Vector2(x, z).length()
	if d < FLAT_RADIUS:
		return 0.0
	elif d < FLAT_RADIUS + FLAT_BLEND:
		return lerpf(0.0, h, (d - FLAT_RADIUS) / FLAT_BLEND)
	return h


## Carve any caves out of the height: along each cave's corridor (and the chamber
## disc at its end) the ground is pulled DOWN to a level floor, leaving an entrance
## slot in the mountainside and a hollow the roof geometry then covers. Only ever
## lowers the terrain, never raises it.
func _apply_caves(x: float, z: float, h: float) -> float:
	if _caves.is_empty():
		return h
	var p := Vector2(x, z)
	for c in _caves:
		var t := _cave_carve_t(p, c)
		if t > 0.0:
			h = minf(h, lerpf(h, c.floor_y, t))
	return h


## 0..1 carve weight for point p in cave c: 1 inside the corridor/chamber, fading
## to 0 over CAVE_BLEND past the walls.
func _cave_carve_t(p: Vector2, c: Dictionary) -> float:
	var a: Vector2 = c.mouth
	var b: Vector2 = c.mouth + c.dir * c.length
	var d_corr := _dist_point_segment(p, a, b)
	var t := 1.0 - smoothstep(c.half_width, c.half_width + CAVE_BLEND, d_corr)
	var d_cham := p.distance_to(b)
	var tc := 1.0 - smoothstep(c.chamber_r, c.chamber_r + CAVE_BLEND, d_cham)
	return maxf(t, tc)


func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var u := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * u)


## Pick cave entrances on steep mountainsides, spread across different mountains.
## The tunnel bores UPHILL (into the mountain); the mouth faces downhill so it opens.
func _setup_caves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TERRAIN_SEED + 404
	var e := 2.0
	for attempt in range(4000):
		if _caves.size() >= CAVE_COUNT:
			break
		var x := rng.randf_range(-SIZE * 0.42, SIZE * 0.42)
		var z := rng.randf_range(-SIZE * 0.42, SIZE * 0.42)
		if Vector2(x, z).length() < FLAT_RADIUS + 40.0:
			continue
		var hh := _base_height(x, z)
		if hh < CAVE_MIN_H or hh > CAVE_MAX_H:
			continue
		# Uphill gradient = direction further into the mountain.
		var gx := _base_height(x + e, z) - _base_height(x - e, z)
		var gz := _base_height(x, z + e) - _base_height(x, z - e)
		var grad := Vector2(gx, gz)
		var slope := grad.length() / (2.0 * e)
		if slope < CAVE_MIN_SLOPE:
			continue
		var mouth := Vector2(x, z)
		var too_close := false
		for c in _caves:
			if (c.mouth as Vector2).distance_to(mouth) < CAVE_MIN_SEP:
				too_close = true
				break
		if too_close:
			continue
		_caves.append({
			"mouth": mouth,
			"dir": grad.normalized(),     # uphill, into the mountain
			"floor_y": hh - 1.0,          # level floor, just below the entrance lip
			"half_width": CAVE_HALF_WIDTH,
			"length": CAVE_LENGTH,
			"chamber_r": CHAMBER_R,
		})


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


# --- Caves -------------------------------------------------------------------

## Build the rock roof + chamber dome over every carved cave, plus a dim interior
## light. The floor and lower walls are the carved terrain itself; this geometry is
## only the arched ceiling that the heightfield can't represent.
func _build_caves() -> void:
	if _caves.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in _caves:
		_build_cave_roof(st, c)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "CaveRoofs"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.12, 0.11)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "CaveBodies"
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	add_child(body)
	# A warm, dim light deep in each chamber so the interior reads as a cave.
	for c in _caves:
		var center: Vector2 = c.mouth + c.dir * c.length
		var light := OmniLight3D.new()
		light.position = Vector3(center.x, c.floor_y + CHAMBER_H * 0.4, center.y)
		light.omni_range = c.chamber_r * 3.2
		light.light_energy = 1.7
		light.light_color = Color(1.0, 0.82, 0.55)
		light.shadow_enabled = false
		add_child(light)


func _build_cave_roof(st: SurfaceTool, c: Dictionary) -> void:
	var floor_y: float = c.floor_y
	var dir: Vector2 = c.dir
	var perp := Vector2(-dir.y, dir.x)   # horizontal, across the tunnel
	var w: float = c.half_width
	var ribs: Array = []                 # each = Array[Vector3] arch from rim to rim
	var rib_count := 9
	var arc := 12
	for s in range(rib_count + 1):
		var t := float(s) / rib_count
		var along: float = c.length * t
		var cx: float = c.mouth.x + dir.x * along
		var cz: float = c.mouth.y + dir.y * along
		var hc: float = lerpf(CAVE_CEIL * 0.85, CAVE_CEIL, t)
		var rib: Array = []
		for k in range(arc + 1):
			var ang := PI * float(k) / arc       # 0..PI, over the top of the arch
			var ox := cos(ang)                   # -1 .. 1 across the tunnel
			var oy := sin(ang)                   # 0 .. 1 up the arch
			var pert := 1.0 + _cnoise.get_noise_3d(cx + ox * w, oy * hc, cz) * 0.16
			var px := cx + perp.x * ox * w * pert
			var pz := cz + perp.y * ox * w * pert
			var py := floor_y + oy * hc * pert
			rib.append(Vector3(px, py, pz))
		ribs.append(rib)
	# Connect successive ribs into the corridor roof (inward-facing).
	for s in range(rib_count):
		var along_mid: float = c.length * (float(s) + 0.5) / rib_count
		var ref := Vector3(
			c.mouth.x + dir.x * along_mid,
			floor_y + CAVE_CEIL * 0.35,
			c.mouth.y + dir.y * along_mid)
		for k in range(arc):
			var a0: Vector3 = ribs[s][k]
			var a1: Vector3 = ribs[s][k + 1]
			var b0: Vector3 = ribs[s + 1][k]
			var b1: Vector3 = ribs[s + 1][k + 1]
			_add_cave_tri(st, a0, a1, b1, ref)
			_add_cave_tri(st, a0, b1, b0, ref)
	# Chamber dome over the tunnel's end.
	_build_chamber_dome(st, c)


func _build_chamber_dome(st: SurfaceTool, c: Dictionary) -> void:
	var center: Vector2 = c.mouth + c.dir * c.length
	var cc := Vector3(center.x, c.floor_y, center.y)
	var ref := cc + Vector3(0, CHAMBER_H * 0.35, 0)
	var cr: float = c.chamber_r * 0.96
	var lat := 6
	var lon := 16
	var grid: Array = []
	for la in range(lat + 1):
		var phi := (PI * 0.5) * float(la) / lat   # 0 = top, PI/2 = rim at floor
		var row: Array = []
		for lo in range(lon + 1):
			var th := TAU * float(lo) / lon
			var pert := 1.0 + _cnoise.get_noise_3d(cc.x + cos(th) * cr, phi * 8.0, cc.z + sin(th) * cr) * 0.14
			var px := cc.x + cos(th) * sin(phi) * cr * pert
			var py := cc.y + cos(phi) * CHAMBER_H * pert
			var pz := cc.z + sin(th) * sin(phi) * cr * pert
			row.append(Vector3(px, py, pz))
		grid.append(row)
	for la in range(lat):
		for lo in range(lon):
			var a0: Vector3 = grid[la][lo]
			var a1: Vector3 = grid[la][lo + 1]
			var b0: Vector3 = grid[la + 1][lo]
			var b1: Vector3 = grid[la + 1][lo + 1]
			_add_cave_tri(st, a0, a1, b1, ref)
			_add_cave_tri(st, a0, b1, b0, ref)


## Add a cave triangle with its normal flipped to face the interior reference point
## (so the OmniLight inside actually lights the surface we look at).
func _add_cave_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ref: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() > 0.0001:
		n = n.normalized()
	var centroid := (a + b + c) / 3.0
	if n.dot(ref - centroid) < 0.0:
		n = -n
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


# --- Scatter -----------------------------------------------------------------

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
		if _in_cave_area(x, z):                          # don't litter props inside caves
			continue
		var h := height_at(x, z)
		if h > max_h or h < min_h:
			continue
		var inst: Node3D = scene.instantiate()
		parent.add_child(inst)
		inst.global_position = Vector3(x, h, z)
		return


## True if (x,z) is inside (or right at the mouth of) any carved cave — used to keep
## scattered props and grass out of the caves.
func _in_cave_area(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for c in _caves:
		if _cave_carve_t(p, c) > 0.05:
			return true
	return false


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
		if _in_cave_area(x, z):
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
