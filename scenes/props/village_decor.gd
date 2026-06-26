extends Node3D
## Village dressing: packed-dirt paths linking the houses to a central plaza, plus
## standing torches along the routes and around the doors. Paths are flat ribbon
## meshes laid just above the (flat) village ground; torches are torch.tscn instances.
##
## The village sits on the flat clearing at the origin (see terrain.gd FLAT_RADIUS),
## so everything here stays within that flat disc and sits cleanly on y = 0.

const PATH_Y := 0.03          # lift paths just above the ground to avoid z-fighting
const PATH_W := 1.7           # path half... no: full width
const PLAZA_R := 3.6          # radius of the round plaza at the village centre

const C_PATH := Color(0.46, 0.38, 0.28)   # packed dirt
const C_PLAZA := Color(0.5, 0.45, 0.38)   # paler, more trodden centre

const TORCH := preload("res://scenes/props/torch.tscn")

# Path waypoints (x, z). The main route runs from the plaza out to the house
# cluster, then short branches reach each front door.
const NODES := {
	"plaza": Vector2(0, 0),
	"a": Vector2(-4, -3),
	"b": Vector2(-7, -6),
	"hub": Vector2(-9.5, -9),
	"door1": Vector2(-10, -8.8),    # House1 faces south
	"door2": Vector2(-8.9, -11),    # House2 faces west
	"door3": Vector2(-13, -8.2),    # House3 faces north
}
const SEGMENTS := [
	["plaza", "a"], ["a", "b"], ["b", "hub"],
	["hub", "door1"], ["hub", "door2"], ["hub", "door3"],
]

# Where torches go (x, z). Plaza, along the path, and beside the doors. Kept to a
# handful so the Compatibility renderer (web) doesn't overload the village lighting.
const TORCHES := [
	Vector2(2.9, 1.0), Vector2(-2.4, 2.4),
	Vector2(-7.0, -7.2),
	Vector2(-11.3, -8.4), Vector2(-8.6, -12.3), Vector2(-14.3, -7.9),
]


func _ready() -> void:
	_build_paths()
	_place_torches()


func _build_paths() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Round plaza (triangle fan).
	var segs := 28
	for i in range(segs):
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var c := Vector3(0, PATH_Y, 0)
		var p0 := Vector3(cos(a0) * PLAZA_R, PATH_Y, sin(a0) * PLAZA_R)
		var p1 := Vector3(cos(a1) * PLAZA_R, PATH_Y, sin(a1) * PLAZA_R)
		_quad_tri(st, c, p0, p1, C_PLAZA)
	# Path ribbons.
	for seg in SEGMENTS:
		_ribbon(st, NODES[seg[0]], NODES[seg[1]])
	# Small patch at every junction so corners don't show gaps.
	for key in NODES:
		_patch(st, NODES[key])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Paths"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func _ribbon(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var dir := (b - a)
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x) * (PATH_W * 0.5)
	var a0 := Vector3(a.x - perp.x, PATH_Y, a.y - perp.y)
	var a1 := Vector3(a.x + perp.x, PATH_Y, a.y + perp.y)
	var b0 := Vector3(b.x - perp.x, PATH_Y, b.y - perp.y)
	var b1 := Vector3(b.x + perp.x, PATH_Y, b.y + perp.y)
	_quad_tri(st, a0, a1, b1, C_PATH)
	_quad_tri(st, a0, b1, b0, C_PATH)


func _patch(st: SurfaceTool, p: Vector2) -> void:
	var r := PATH_W * 0.5
	var c0 := Vector3(p.x - r, PATH_Y, p.y - r)
	var c1 := Vector3(p.x + r, PATH_Y, p.y - r)
	var c2 := Vector3(p.x + r, PATH_Y, p.y + r)
	var c3 := Vector3(p.x - r, PATH_Y, p.y + r)
	_quad_tri(st, c0, c1, c2, C_PATH)
	_quad_tri(st, c0, c2, c3, C_PATH)


func _quad_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	# Flat path on the ground — normals always point up so the sun lights it.
	st.set_normal(Vector3.UP)
	st.set_color(col)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.set_color(col)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.set_color(col)
	st.add_vertex(c)


func _place_torches() -> void:
	for p in TORCHES:
		var t := TORCH.instantiate()
		t.position = Vector3(p.x, 0, p.y)
		add_child(t)
