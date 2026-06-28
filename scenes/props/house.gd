extends StaticBody3D
## A fully enterable cottage, built procedurally so every instance is identical and
## easy to tweak. Real walls with a door opening and window openings (glass panes +
## mullions), an open front door you can walk through, a solid floor, simple interior
## furniture, a warm interior light, and a gable roof.
##
## GROUNDING: the floor's TOP sits at local y = 0, so when the house is placed with
## its origin on the ground the floor is flush with the terrain — no floating, no
## sinking. Place instances at the ground height (y = 0 on the flat village).
##
## Tweak the consts below for size; everything else follows.

const W := 5.2          # interior width  (x)
const D := 5.2          # interior depth  (z)
const WALL_H := 2.8     # wall height (ceiling) — clears the 1.8m-tall player
const WALL_T := 0.18    # wall thickness
const ROOF_RISE := 1.7  # ridge height above the walls
const OVERHANG := 0.4   # how far the roof oversails the walls

const DOOR_W := 1.3
const DOOR_H := 2.3

const WIN_W := 1.1
const WIN_Y0 := 1.0     # window sill height
const WIN_Y1 := 1.95    # window head height

var _mat_wall: StandardMaterial3D
var _mat_stone: StandardMaterial3D
var _mat_wood: StandardMaterial3D
var _mat_roof: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_cloth: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	var hx := W * 0.5
	var hz := D * 0.5
	var outer_x := hx + WALL_T          # half-extent including front/back wall ends
	_build_floor(outer_x, hz)
	# Front wall (+z) carries the door; the other three carry a window each.
	_wall_x(hz, WALL_T, W + 2.0 * WALL_T, WALL_H, DOOR_W, 0.0, DOOR_H, false)        # front, door
	_wall_x(-hz, WALL_T, W + 2.0 * WALL_T, WALL_H, WIN_W, WIN_Y0, WIN_Y1, true)      # back, window
	_wall_z(-hx, WALL_T, D, WALL_H, WIN_W, WIN_Y0, WIN_Y1, true)                     # left, window
	_wall_z(hx, WALL_T, D, WALL_H, WIN_W, WIN_Y0, WIN_Y1, true)                      # right, window
	# Glazing for the three windows.
	_window_pane(Vector3(0, (WIN_Y0 + WIN_Y1) * 0.5, -hz), false)
	_window_pane(Vector3(-hx, (WIN_Y0 + WIN_Y1) * 0.5, 0), true)
	_window_pane(Vector3(hx, (WIN_Y0 + WIN_Y1) * 0.5, 0), true)
	_build_door(Vector3(-DOOR_W * 0.5, 0, hz))
	_build_roof(outer_x, hz)
	_build_interior(hx, hz)


func _make_materials() -> void:
	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_color = Color(0.78, 0.66, 0.48)
	_mat_wall.roughness = 0.95
	_mat_stone = StandardMaterial3D.new()
	_mat_stone.albedo_color = Color(0.5, 0.49, 0.46)
	_mat_stone.roughness = 0.95
	_mat_wood = StandardMaterial3D.new()
	_mat_wood.albedo_color = Color(0.4, 0.27, 0.16)
	_mat_wood.roughness = 0.85
	_mat_roof = StandardMaterial3D.new()
	_mat_roof.albedo_color = Color(0.45, 0.2, 0.15)
	_mat_roof.roughness = 0.9
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.albedo_color = Color(0.55, 0.7, 0.8, 0.45)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.metallic = 0.2
	_mat_glass.roughness = 0.1
	_mat_cloth = StandardMaterial3D.new()
	_mat_cloth.albedo_color = Color(0.55, 0.2, 0.22)
	_mat_cloth.roughness = 1.0


## Add a box mesh (and, optionally, a matching box collider) at pos.
func _box(size: Vector3, pos: Vector3, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		col.shape = bs
		col.position = pos
		add_child(col)


func _build_floor(outer_x: float, hz: float) -> void:
	# Floor: top at y = 0 so it's flush with the ground (no floating/sinking).
	var fx := outer_x * 2.0
	var fz := (hz + WALL_T) * 2.0
	_box(Vector3(fx, 0.2, fz), Vector3(0, -0.1, 0), _mat_wood)
	# A short stone foundation skirt below it, for a grounded look.
	_box(Vector3(fx + 0.2, 0.4, fz + 0.2), Vector3(0, -0.4, 0), _mat_stone)


## A wall running along X (front/back) at z = zc, with a centred opening.
func _wall_x(zc: float, t: float, total_len: float, h: float, op_w: float, op_y0: float, op_y1: float, has_sill: bool) -> void:
	var side_w := (total_len - op_w) * 0.5
	var off := op_w * 0.5 + side_w * 0.5
	_box(Vector3(side_w, h, t), Vector3(-off, h * 0.5, zc), _mat_wall)
	_box(Vector3(side_w, h, t), Vector3(off, h * 0.5, zc), _mat_wall)
	var head_h := h - op_y1
	if head_h > 0.01:
		_box(Vector3(op_w, head_h, t), Vector3(0, (op_y1 + h) * 0.5, zc), _mat_wall)
	if has_sill and op_y0 > 0.01:
		_box(Vector3(op_w, op_y0, t), Vector3(0, op_y0 * 0.5, zc), _mat_wall)


## A wall running along Z (left/right) at x = xc, with a centred opening.
func _wall_z(xc: float, t: float, total_len: float, h: float, op_w: float, op_y0: float, op_y1: float, has_sill: bool) -> void:
	var side_w := (total_len - op_w) * 0.5
	var off := op_w * 0.5 + side_w * 0.5
	_box(Vector3(t, h, side_w), Vector3(xc, h * 0.5, -off), _mat_wall)
	_box(Vector3(t, h, side_w), Vector3(xc, h * 0.5, off), _mat_wall)
	var head_h := h - op_y1
	if head_h > 0.01:
		_box(Vector3(t, head_h, op_w), Vector3(xc, (op_y1 + h) * 0.5, 0), _mat_wall)
	if has_sill and op_y0 > 0.01:
		_box(Vector3(t, op_y0, op_w), Vector3(xc, op_y0 * 0.5, 0), _mat_wall)


## Glass pane + a cross mullion filling a window opening. `along_z` = the window is
## in a side wall (opening spans Z) rather than a front/back wall (spans X).
func _window_pane(center: Vector3, along_z: bool) -> void:
	var wh := WIN_Y1 - WIN_Y0
	var pane: Vector3
	var barv: Vector3
	var barh: Vector3
	if along_z:
		pane = Vector3(0.05, wh, WIN_W)
		barv = Vector3(0.07, wh, 0.06)
		barh = Vector3(0.07, 0.06, WIN_W)
	else:
		pane = Vector3(WIN_W, wh, 0.05)
		barv = Vector3(0.06, wh, 0.07)
		barh = Vector3(WIN_W, 0.06, 0.07)
	_box(pane, center, _mat_glass)              # collides so the house stays enclosed
	_box(barv, center, _mat_wood, false)        # mullions are decorative
	_box(barh, center, _mat_wood, false)


## An open, swung-inward front door on a hinge, plus a knob. No collision so you can
## simply walk through the doorway.
func _build_door(hinge_pos: Vector3) -> void:
	var hinge := Node3D.new()
	hinge.position = hinge_pos
	hinge.rotation.y = deg_to_rad(78.0)   # swung open into the room
	add_child(hinge)
	var leaf := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(DOOR_W * 0.94, DOOR_H * 0.97, 0.07)
	leaf.mesh = bm
	leaf.material_override = _mat_wood
	leaf.position = Vector3(DOOR_W * 0.47, DOOR_H * 0.5, 0)
	hinge.add_child(leaf)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	knob.mesh = sm
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.6, 0.2)
	brass.metallic = 0.6
	brass.roughness = 0.3
	knob.material_override = brass
	knob.position = Vector3(DOOR_W * 0.88, DOOR_H * 0.5, 0.05)
	hinge.add_child(knob)


## Gable roof built as a triangular prism (two slopes + two gable ends), oversailing
## the walls. Flat-shaded; no collision (the walls already enclose the house).
func _build_roof(outer_x: float, hz: float) -> void:
	var rx := outer_x + OVERHANG
	var rz := hz + WALL_T + OVERHANG
	var base_y := WALL_H - 0.05
	var ridge_y := WALL_H + ROOF_RISE
	# Corners.
	var fbl := Vector3(-rx, base_y, rz)   # front-bottom-left
	var fbr := Vector3(rx, base_y, rz)
	var bbl := Vector3(-rx, base_y, -rz)
	var bbr := Vector3(rx, base_y, -rz)
	var rf := Vector3(0, ridge_y, rz)     # ridge front
	var rb := Vector3(0, ridge_y, -rz)    # ridge back
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri(st, fbl, rf, rb); _tri(st, fbl, rb, bbl)     # left slope
	_tri(st, fbr, rb, rf); _tri(st, fbr, bbr, rb)     # right slope
	_tri(st, fbl, fbr, rf)                            # front gable
	_tri(st, bbl, rb, bbr)                            # back gable
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Roof"
	mi.mesh = st.commit()
	mi.material_override = _mat_roof
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Simple furnishings + a warm interior light so the inside reads as a lived-in room.
func _build_interior(hx: float, hz: float) -> void:
	# Rug.
	_box(Vector3(2.4, 0.03, 1.8), Vector3(0, 0.02, 0), _mat_cloth, false)
	# Bed (frame + mattress + pillow) in a back corner.
	var bx := hx - 0.9
	var bz := -hz + 1.1
	_box(Vector3(1.4, 0.35, 2.0), Vector3(bx, 0.18, bz), _mat_wood)
	var mattress := StandardMaterial3D.new()
	mattress.albedo_color = Color(0.85, 0.85, 0.8)
	mattress.roughness = 1.0
	_box(Vector3(1.3, 0.18, 1.9), Vector3(bx, 0.44, bz), mattress, false)
	_box(Vector3(1.1, 0.14, 0.45), Vector3(bx, 0.6, bz - 0.7), _mat_cloth, false)
	# Table (top + four legs) with a stool either side, opposite the bed.
	var tx := -hx + 1.2
	_box(Vector3(1.2, 0.1, 0.8), Vector3(tx, 0.78, 0.0), _mat_wood)
	for lx in [-0.5, 0.5]:
		for lz in [-0.3, 0.3]:
			_box(Vector3(0.08, 0.73, 0.08), Vector3(tx + lx, 0.37, lz), _mat_wood, false)
	_box(Vector3(0.4, 0.08, 0.4), Vector3(tx, 0.45, 1.0), _mat_wood, false)
	_box(Vector3(0.4, 0.08, 0.4), Vector3(tx, 0.45, -1.0), _mat_wood, false)
	# Warm hanging light.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, WALL_H - 0.5, 0)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.3
	lamp.omni_range = maxf(W, D) * 1.4
	lamp.shadow_enabled = false
	add_child(lamp)
