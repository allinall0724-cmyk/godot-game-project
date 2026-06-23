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
const MOUNTAIN_AMP := 80.0   # (legacy) old scattered-mountain noise amplitude — unused now

# TWO big explicit mountains (instead of many scattered noise peaks). Each is a TERRACED
# mountain: a sharp irregular rise stepped into several genuinely FLAT plateaus at
# different elevations (buildable stops) with steeper risers between, and a gently-graded
# spiral trail carved up the slope linking base -> each terrace -> summit. Placed well
# away from the origin spawn.
#   c = center (x,z) · base_r = footprint radius · peak = summit height
#   turns = spiral revolutions of the trail (more turns = gentler grade) · theta0 = start angle
# Terrace heights/radii are derived proportionally in _mtn_profile().
const MOUNTAINS := [
	{"c": Vector2(140.0, 120.0), "base_r": 102.0, "peak": 124.0, "turns": 2.6, "theta0": 0.4},
	{"c": Vector2(-135.0, -85.0), "base_r": 90.0, "peak": 100.0, "turns": 2.6, "theta0": 2.2},
]
const PATH_HALF_WIDTH := 5.5   # half-width of the carved trail tread (wider = easier to follow)
const TRAIL_INNER_FRAC := 0.34 # spiral tops out at the MID terrace (not the tight summit
                               # centre, which made the carve build tall fill-spikes)

var _cave_spots: Array = []    # [{pos: Vector3 (flat floor), facing: Vector3}], set in _ready
var _cave_pads: Array = []     # [{x, z, h, r, blend}] flat foundations under each cave
# Per-mountain arc-length lookup: maps trail parameter u -> fraction of total horizontal
# trail length. The trail's HEIGHT follows this fraction (not u) so the climb is spread
# evenly along the real distance walked => a CONSTANT, gentle incline the whole way up.
var _mtn_arc: Array = []        # [PackedFloat32Array per mountain]
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
const C_PATH := Color(0.46, 0.35, 0.21)    # packed-dirt mountain trail

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
	_build_arc_luts()        # precompute the even-grade trail height profiles,
	_setup_caves()           # decide cave spots + flatten their foundation pads FIRST,
	_build_visual()          # so the terrain build bakes the flat pads in.
	_build_collision()
	_scatter()
	_scatter_grass()
	_spawn_caves()
	if OS.get_environment("TERRAIN_VERIFY") == "1":
		_verify_terrain()


## World height at an (x, z) position — flat near the origin, rolling hills, the two big
## terraced mountains further out, and small flat pads where caves are dug in.
func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * HILL_AMP
	h = _apply_mountains(x, z, h)
	var d := Vector2(x, z).length()
	if d < FLAT_RADIUS:
		h = 0.0
	elif d < FLAT_RADIUS + FLAT_BLEND:
		h = lerpf(0.0, h, (d - FLAT_RADIUS) / FLAT_BLEND)
	return _apply_cave_pads(x, z, h)


## Terraced mountain profile by normalised radius rr (0 = summit centre, 1 = base).
## Three genuinely flat terraces (summit, mid, lower) at distinct elevations, joined by
## steep but SMOOTHSTEP-rounded risers. The rounding matters: a hard convex rim aliases
## into spike triangles at the mesh resolution, so each step is eased at top and bottom.
func _mtn_profile(rr: float, peak: float) -> float:
	var th := 0.70 * peak   # mid terrace height
	var tl := 0.38 * peak   # lower terrace height
	var h := peak
	h = lerpf(h, th, smoothstep(0.16, 0.30, rr))   # summit -> mid terrace
	h = lerpf(h, tl, smoothstep(0.44, 0.58, rr))   # mid -> lower terrace
	h = lerpf(h, 0.0, smoothstep(0.74, 1.0, rr))   # lower terrace -> base
	return h


## Raise the surface for each mountain: a terraced, irregular rise (flat plateaus + steep
## risers), then carve a gently-graded spiral trail that links the base to every terrace
## and the summit. The trail climbs linearly (path height = u * peak) while winding
## `turns` times, which keeps its incline far below the 45° the player can walk.
func _apply_mountains(x: float, z: float, base_h: float) -> float:
	var surface := base_h
	for idx in range(MOUNTAINS.size()):
		var m = MOUNTAINS[idx]
		var c: Vector2 = m["c"]
		var dx := x - c.x
		var dz := z - c.y
		var d := sqrt(dx * dx + dz * dz)
		var base_r: float = m["base_r"]
		if d >= base_r:
			continue
		var peak: float = m["peak"]
		# Gentle, very-low-frequency wobble of the effective radius so the terrace outline
		# isn't a perfect circle. Kept SMALL: bigger values, or any per-vertex HEIGHT noise,
		# get amplified on the near-vertical risers into thin spikes — which is what we're
		# fixing here. The risers themselves stay clean, smooth, steep faces.
		var de := d + _mnoise.get_noise_2d(x, z) * (base_r * 0.035)
		var ms := _mtn_profile(clampf(de / base_r, 0.0, 1.0), peak)
		surface = maxf(surface, maxf(ms, 0.0))
		# Analytic spiral trail. r shrinks monotonically as it winds up, so each radius is
		# crossed once; the tread height follows arc length (even grade) not radius.
		var inner := TRAIL_INNER_FRAC * base_r
		if d > inner and d < base_r:
			var u := (base_r - d) / (base_r - inner)        # 0 at base, 1 at trail top
			var spiral_ang := float(m["theta0"]) + u * float(m["turns"]) * TAU
			var arc := absf(wrapf(atan2(dz, dx) - spiral_ang, -PI, PI)) * d
			if arc < PATH_HALF_WIDTH:
				var w := 1.0 - smoothstep(PATH_HALF_WIDTH * 0.45, PATH_HALF_WIDTH, arc)
				# Climb only to the height of the terrace the trail ends on, so the carve
				# follows the slope (cut/fill stays small => no raised spikes).
				var h_top := _mtn_profile(TRAIL_INNER_FRAC, peak)
				surface = lerpf(surface, _arc_lookup(idx, u) * h_top, w)
	return surface


## Precompute the even-grade height profile for each mountain's spiral trail: cumulative
## horizontal distance along the spiral, normalised to 0..1. Trail height = lookup * peak.
func _build_arc_luts() -> void:
	_mtn_arc.clear()
	for m in MOUNTAINS:
		var base_r: float = m["base_r"]
		var inner := TRAIL_INNER_FRAC * base_r
		var turns: float = m["turns"]
		var theta0: float = m["theta0"]
		var k := 256
		var cum := PackedFloat32Array()
		cum.resize(k + 1)
		var total := 0.0
		var prev := Vector2.ZERO
		for i in range(k + 1):
			var u := float(i) / float(k)
			var d := base_r - u * (base_r - inner)
			var ang := theta0 + u * turns * TAU
			var p := Vector2(d * cos(ang), d * sin(ang))
			if i > 0:
				total += prev.distance_to(p)
			cum[i] = total
			prev = p
		if total > 0.0:
			for i in range(k + 1):
				cum[i] = cum[i] / total
		_mtn_arc.append(cum)


## Fraction (0..1) of total trail length reached at parameter u — interpolated from the LUT.
func _arc_lookup(idx: int, u: float) -> float:
	var lut: PackedFloat32Array = _mtn_arc[idx]
	var k := lut.size() - 1
	var f := clampf(u, 0.0, 1.0) * float(k)
	var i0 := int(f)
	var i1 := mini(i0 + 1, k)
	return lerpf(lut[i0], lut[i1], f - float(i0))


## How strongly (0..1) the point lies on a mountain's spiral trail — used to tint the
## trail a dirt colour. Mirrors the trail test in _apply_mountains.
func _path_factor(x: float, z: float) -> float:
	var best := 0.0
	for m in MOUNTAINS:
		var c: Vector2 = m["c"]
		var dx := x - c.x
		var dz := z - c.y
		var d := sqrt(dx * dx + dz * dz)
		var base_r: float = m["base_r"]
		var inner := TRAIL_INNER_FRAC * base_r
		if d <= inner or d >= base_r:
			continue
		var u := (base_r - d) / (base_r - inner)
		var spiral_ang := float(m["theta0"]) + u * float(m["turns"]) * TAU
		var arc := absf(wrapf(atan2(dz, dx) - spiral_ang, -PI, PI)) * d
		if arc < PATH_HALF_WIDTH:
			best = maxf(best, 1.0 - smoothstep(PATH_HALF_WIDTH * 0.45, PATH_HALF_WIDTH, arc))
	return best


## Flatten a small disc of ground to a constant height under each cave (so the cave's
## floor sits flush and the heightfield never pokes up through the interior).
func _apply_cave_pads(x: float, z: float, h: float) -> float:
	for pad in _cave_pads:
		var pd := Vector2(x - pad["x"], z - pad["z"]).length()
		if pd < pad["r"]:
			h = pad["h"]
		elif pd < pad["r"] + pad["blend"]:
			h = lerpf(pad["h"], h, (pd - pad["r"]) / pad["blend"])
	return h


# ============================================================================
#  Caves — enterable hollow spaces (foundation for future dungeons)
# ============================================================================

## Choose cave spots (one at the foot of each mountain, mouth facing the origin) and
## register a flat foundation pad under each so the interior floor sits flush.
func _setup_caves() -> void:
	for m in MOUNTAINS:
		var c: Vector2 = m["c"]
		var base_r: float = m["base_r"]
		var to_origin := (Vector2.ZERO - c).normalized()
		var sx := c.x + to_origin.x * (base_r + 7.0)
		var sz := c.y + to_origin.y * (base_r + 7.0)
		var pad_h := _noise.get_noise_2d(sx, sz) * HILL_AMP   # local hill height (no mountain here)
		_cave_pads.append({"x": sx, "z": sz, "h": pad_h, "r": 12.0, "blend": 8.0})
		_cave_spots.append({"pos": Vector3(sx, pad_h, sz), "facing": Vector3(to_origin.x, 0.0, to_origin.y)})


func _spawn_caves() -> void:
	var root := Node3D.new()
	root.name = "Caves"
	add_child(root)
	for spot in _cave_spots:
		_build_cave(spot, root)


## A hollow rock room (floor/ceiling/4 walls) with a doorway gap in the front wall and a
## dim interior light — a real enterable space, all code-only primitives with collision.
func _build_cave(spot: Dictionary, parent: Node) -> void:
	var pos: Vector3 = spot["pos"]
	var facing: Vector3 = spot["facing"]
	var w := 11.0
	var dpt := 13.0
	var hgt := 4.5
	var t := 1.2
	var door_w := 4.0
	var door_h := 3.2
	var rock := Color(0.26, 0.25, 0.27)
	var rock_d := Color(0.17, 0.16, 0.19)
	var body := StaticBody3D.new()
	body.name = "Cave"
	# Floor + ceiling (slightly oversized so they seal the corners).
	_add_cave_box(body, Vector3(w + 2.0 * t, t, dpt + 2.0 * t), Vector3(0, -t * 0.5, 0), rock_d)
	_add_cave_box(body, Vector3(w + 2.0 * t, t, dpt + 2.0 * t), Vector3(0, hgt + t * 0.5, 0), rock_d)
	# Back + side walls (entrance is +Z / front).
	_add_cave_box(body, Vector3(w + 2.0 * t, hgt, t), Vector3(0, hgt * 0.5, -(dpt * 0.5) - t * 0.5), rock)
	_add_cave_box(body, Vector3(t, hgt, dpt), Vector3(-(w * 0.5) - t * 0.5, hgt * 0.5, 0), rock)
	_add_cave_box(body, Vector3(t, hgt, dpt), Vector3((w * 0.5) + t * 0.5, hgt * 0.5, 0), rock)
	var fz := (dpt * 0.5) + t * 0.5
	# Recessed, dark structural front seals everything except the doorway. It sits BEHIND
	# the visible rock mouth so the cave can't be slipped into, while the look is natural.
	var pill_w := w * 0.5 - door_w * 0.5
	var pill_cx := (w * 0.5 + door_w * 0.5) * 0.5
	_add_cave_box(body, Vector3(pill_w, hgt, t), Vector3(-pill_cx, hgt * 0.5, fz - 0.6), rock_d)
	_add_cave_box(body, Vector3(pill_w, hgt, t), Vector3(pill_cx, hgt * 0.5, fz - 0.6), rock_d)
	_add_cave_box(body, Vector3(door_w, hgt - door_h, t), Vector3(0, door_h + (hgt - door_h) * 0.5, fz - 0.6), rock_d)
	# Natural rock mouth: jittered, rotated boulders piled around the opening (kept clear
	# of the doorway corridor itself) so it reads as a hole in a rocky outcrop, not a door.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(pos.x) * 17.0 + absf(pos.z) * 31.0) + 1
	for side in [-1.0, 1.0]:
		var s := float(side)
		for i in range(4):  # a column of rocks just outside each doorway edge
			var fsz := Vector3(rng.randf_range(1.8, 2.8), rng.randf_range(2.0, 3.0), rng.randf_range(1.6, 2.4))
			var fbx := s * (door_w * 0.5 + fsz.x * 0.5 + rng.randf_range(0.1, 0.6))
			var fby := (float(i) + 0.5) / 4.0 * (hgt + 0.6) + rng.randf_range(-0.3, 0.3)
			var fbz := fz + rng.randf_range(-0.2, 0.8)
			_add_rock(body, fsz, Vector3(fbx, fby, fbz), Vector3(rng.randf_range(-18, 18), rng.randf_range(-32, 32), rng.randf_range(-18, 18)), rock.lerp(rock_d, rng.randf()), rng.randf() < 0.4)
		for j in range(3):  # fill out to the side wall, covering the recessed pillar
			var gsz := Vector3(rng.randf_range(2.2, 3.4), rng.randf_range(2.6, 3.8), rng.randf_range(1.6, 2.4))
			var gbx := s * lerpf(door_w * 0.5 + 2.6, w * 0.5 + 0.6, float(j) / 2.0)
			var gby := rng.randf_range(1.2, hgt - 0.3)
			var gbz := fz + rng.randf_range(-0.3, 0.6)
			_add_rock(body, gsz, Vector3(gbx, gby, gbz), Vector3(rng.randf_range(-18, 18), rng.randf_range(-32, 32), rng.randf_range(-18, 18)), rock.lerp(rock_d, rng.randf()), rng.randf() < 0.4)
	for i in range(4):  # rough overhang above the doorway
		var osz := Vector3(rng.randf_range(2.2, 3.4), rng.randf_range(1.8, 2.6), rng.randf_range(1.8, 2.6))
		var obx := rng.randf_range(-door_w * 0.4, door_w * 0.4)
		var oby := door_h + 0.6 + rng.randf_range(0.0, 0.9)
		var obz := fz + rng.randf_range(-0.2, 0.6)
		_add_rock(body, osz, Vector3(obx, oby, obz), Vector3(rng.randf_range(-15, 15), rng.randf_range(-25, 25), rng.randf_range(-15, 15)), rock.lerp(rock_d, rng.randf()), false)
	for i in range(6):  # loose boulders at the foot + a couple over the top (rocky outcrop)
		var bsz := Vector3(rng.randf_range(1.8, 3.2), rng.randf_range(1.8, 3.0), rng.randf_range(1.8, 3.2))
		var bang := rng.randf() * TAU
		var brr := rng.randf_range(w * 0.35, w * 0.62)
		var bbz := fz + rng.randf_range(-dpt * 0.25, 1.0)
		_add_rock(body, bsz, Vector3(cos(bang) * brr, rng.randf_range(0.4, hgt + 1.0), bbz), Vector3(rng.randf_range(-22, 22), rng.randf_range(-35, 35), rng.randf_range(-22, 22)), rock.lerp(rock_d, rng.randf()), rng.randf() < 0.5)
	# Dim interior light (cave ambiance; real dungeon lighting comes later).
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.84, 0.58)
	lamp.light_energy = 1.5
	lamp.omni_range = 17.0
	lamp.position = Vector3(0, hgt * 0.6, 0)
	body.add_child(lamp)
	# Orient so the doorway (+Z) faces outward, place the floor on the flat pad.
	body.transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), pos)
	parent.add_child(body)


## A single irregular rock chunk (rotated box, or a rounded boulder) with collision —
## used to build the natural cave mouth.
func _add_rock(body: Node, size: Vector3, lpos: Vector3, rot_deg: Vector3, color: Color, rounded: bool) -> void:
	var rot := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var mi := MeshInstance3D.new()
	if rounded:
		var sm := SphereMesh.new()
		sm.radius = size.x * 0.5
		sm.height = size.y
		sm.radial_segments = 7
		sm.rings = 4
		mi.mesh = sm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = lpos
	mi.rotation = rot
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = lpos
	cs.rotation = rot
	body.add_child(cs)


func _add_cave_box(body: Node, size: Vector3, lpos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = lpos
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = lpos
	body.add_child(cs)


# ============================================================================
#  Verification (TERRAIN_VERIFY=1) — logically checks the trail is walkable + continuous
# ============================================================================
func _verify_terrain() -> void:
	var limit := 45.0  # player CharacterBody3D floor_max_angle default (deg)
	print("=== TERRAIN VERIFY (player walkable slope limit = ", limit, " deg) ===")
	for mi in range(MOUNTAINS.size()):
		var m = MOUNTAINS[mi]
		var c: Vector2 = m["c"]
		var base_r: float = m["base_r"]
		var peak: float = m["peak"]
		var inner := TRAIL_INNER_FRAC * base_r
		var n := 240
		var prev := Vector3.ZERO
		var max_slope := 0.0
		var max_carve_err := 0.0
		var max_step := 0.0
		for i in range(n + 1):
			var u := float(i) / float(n)
			var d := base_r - u * (base_r - inner)
			var ang := float(m["theta0"]) + u * float(m["turns"]) * TAU
			var px := c.x + d * cos(ang)
			var pz := c.y + d * sin(ang)
			var got := height_at(px, pz)
			max_carve_err = maxf(max_carve_err, absf(got - _arc_lookup(mi, u) * _mtn_profile(TRAIL_INNER_FRAC, peak)))
			var p := Vector3(px, got, pz)
			if i > 0:
				var horiz := Vector2(p.x - prev.x, p.z - prev.z).length()
				var dy := absf(p.y - prev.y)
				max_step = maxf(max_step, dy)
				if horiz > 0.001:
					max_slope = maxf(max_slope, rad_to_deg(atan2(dy, horiz)))
			prev = p
		print("Mountain ", mi, "  peak=", peak)
		print("  TRAIL incline max = ", snappedf(max_slope, 0.1), " deg  -> ", ("WALKABLE" if max_slope < limit else "TOO STEEP"))
		print("  TRAIL continuity: carve error vs intended height max = ", snappedf(max_carve_err, 0.1), " ; max step between samples = ", snappedf(max_step, 0.2), " (small => continuous, no gaps)")
		# Terrace flatness: sample a ring on each terrace, count points within 0.8 of the flat height.
		for terr in [[0.67, 0.38, "lower"], [0.37, 0.70, "mid"], [0.08, 1.0, "summit"]]:
			var rr: float = terr[0]
			var exp_h: float = float(terr[1]) * peak
			var flat_n := 0
			for k in range(24):
				var a := TAU * float(k) / 24.0
				var d := rr * base_r
				var hh := height_at(c.x + d * cos(a), c.y + d * sin(a))
				if absf(hh - exp_h) < 0.8:
					flat_n += 1
			print("  TERRACE ", terr[2], " (h~", snappedf(exp_h, 0.1), "): ", flat_n, "/24 sample points flat")
	for ci in range(_cave_spots.size()):
		var sp = _cave_spots[ci]
		var p: Vector3 = sp["pos"]
		var lo := INF
		var hi := -INF
		for k in range(12):
			var a := TAU * float(k) / 12.0
			var hh := height_at(p.x + 6.0 * cos(a), p.z + 6.0 * sin(a))
			lo = minf(lo, hh)
			hi = maxf(hi, hh)
		print("CAVE ", ci, " floor_h=", snappedf(p.y, 0.1), "  pad flatness spread(±6m)=", snappedf(hi - lo, 0.1))
	print("=== END VERIFY ===")


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
	# Tint the carved mountain trail like packed dirt so the route is visible (even on snow).
	var pf := _path_factor(x, z)
	if pf > 0.0:
		base = base.lerp(C_PATH, pf * 0.85)
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
