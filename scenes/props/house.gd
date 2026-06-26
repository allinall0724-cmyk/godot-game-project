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


## A lived-in cottage interior: bed + nightstand, dining table with seating, a
## fireplace, a bookshelf, barrels, crates, wall shelves with pottery, ceiling
## beams, a broom, and warm light from the hearth + a ceiling lamp.
func _build_interior(hx: float, hz: float) -> void:
	# Shared extra materials.
	var light_wood := _solid(Color(0.55, 0.42, 0.26), 0.85)
	var metal := _solid(Color(0.24, 0.24, 0.27), 0.5)
	metal.metallic = 0.5
	var clay := _solid(Color(0.6, 0.35, 0.22), 0.9)
	var linen := _solid(Color(0.82, 0.8, 0.72), 1.0)

	_box(Vector3(2.4, 0.03, 1.8), Vector3(0, 0.02, 0), _mat_cloth, false)   # rug

	_build_bed(hx, hz, linen)
	_build_table(hx, light_wood, clay)
	_build_fireplace(hx, hz)
	_build_bookshelf(hx, light_wood)
	_build_storage(hx, hz, light_wood, metal)
	_build_wall_shelves(hx, light_wood, clay)
	_build_ceiling_beams()
	_build_broom(hx, hz)

	# Soft overall ceiling lamp (the hearth supplies the warm flicker-ish glow).
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, WALL_H - 0.5, 0)
	lamp.light_color = Color(1.0, 0.88, 0.66)
	lamp.light_energy = 0.9
	lamp.omni_range = maxf(W, D) * 1.4
	lamp.shadow_enabled = false
	add_child(lamp)


func _build_bed(hx: float, hz: float, linen: StandardMaterial3D) -> void:
	var bx := hx - 0.9
	var bz := -hz + 1.1
	_box(Vector3(1.4, 0.35, 2.0), Vector3(bx, 0.18, bz), _mat_wood)             # frame
	_box(Vector3(0.12, 0.55, 0.12), Vector3(bx - 0.6, 0.45, bz - 0.9), _mat_wood, false)  # posts
	_box(Vector3(0.12, 0.55, 0.12), Vector3(bx + 0.6, 0.45, bz - 0.9), _mat_wood, false)
	_box(Vector3(1.3, 0.18, 1.9), Vector3(bx, 0.44, bz), linen, false)          # mattress
	_box(Vector3(1.24, 0.1, 1.1), Vector3(bx, 0.55, bz + 0.35), _mat_cloth, false)  # blanket
	_box(Vector3(1.1, 0.14, 0.45), Vector3(bx, 0.6, bz - 0.7), linen, false)    # pillow
	# Nightstand + candle beside the bed.
	var nx := bx - 0.95
	_box(Vector3(0.5, 0.5, 0.5), Vector3(nx, 0.25, bz - 0.6), _mat_wood)
	_candle(Vector3(nx, 0.5, bz - 0.6))


func _build_table(hx: float, light_wood: StandardMaterial3D, clay: StandardMaterial3D) -> void:
	var tx := -hx + 1.2
	_box(Vector3(1.2, 0.1, 0.8), Vector3(tx, 0.78, 0.0), light_wood)            # top
	for lx in [-0.5, 0.5]:
		for lz in [-0.3, 0.3]:
			_box(Vector3(0.08, 0.73, 0.08), Vector3(tx + lx, 0.37, lz), light_wood, false)  # legs
	# Tableware.
	_cyl(0.12, 0.1, Vector3(tx - 0.2, 0.88, 0.1), clay, false)                  # bowl
	_cyl(0.05, 0.18, Vector3(tx + 0.25, 0.92, -0.1), _solid(Color(0.3, 0.5, 0.6), 0.4), false)  # jug
	# A stool and a chair (with backrest).
	_box(Vector3(0.4, 0.08, 0.4), Vector3(tx, 0.45, 1.0), _mat_wood, false)
	_box(Vector3(0.42, 0.08, 0.42), Vector3(tx, 0.45, -1.0), _mat_wood)         # chair seat
	_box(Vector3(0.42, 0.5, 0.08), Vector3(tx, 0.7, -1.2), _mat_wood, false)    # chair back


## Stone fireplace on the back wall: hearth, opening, logs, glowing embers (with a
## warm light), a mantel and a chimney breast rising up the wall.
func _build_fireplace(hx: float, hz: float) -> void:
	var fx := -hx + 0.9
	var wz := -hz + 0.3
	_box(Vector3(1.5, 1.3, 0.5), Vector3(fx, 0.65, wz), _mat_stone)             # surround
	_box(Vector3(0.9, 0.7, 0.4), Vector3(fx, 0.35, wz + 0.12), _solid(Color(0.08, 0.07, 0.07), 1.0), false)  # dark opening
	_box(Vector3(1.7, 0.16, 0.6), Vector3(fx, 1.34, wz), _mat_wood, false)      # mantel
	_box(Vector3(0.9, 1.4, 0.4), Vector3(fx, 2.1, wz - 0.05), _mat_stone, false)  # chimney breast
	# Logs + ember glow (short upright billets inside the hearth).
	_cyl(0.07, 0.42, Vector3(fx - 0.12, 0.24, wz + 0.18), _mat_wood, false)
	_cyl(0.07, 0.42, Vector3(fx + 0.12, 0.24, wz + 0.16), _mat_wood, false)
	var ember := _solid(Color(1.0, 0.45, 0.1), 1.0)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.45, 0.1)
	ember.emission_energy_multiplier = 4.0
	_box(Vector3(0.7, 0.12, 0.3), Vector3(fx, 0.16, wz + 0.16), ember, false)
	var fire := OmniLight3D.new()
	fire.position = Vector3(fx, 0.5, wz + 0.3)
	fire.light_color = Color(1.0, 0.5, 0.2)
	fire.light_energy = 2.0
	fire.omni_range = 6.0
	fire.shadow_enabled = false
	add_child(fire)


## Tall bookshelf against the right wall, stacked with coloured books.
func _build_bookshelf(hx: float, light_wood: StandardMaterial3D) -> void:
	var sx := hx - 0.18
	var sz := 1.5
	_box(Vector3(0.32, 1.9, 1.1), Vector3(sx, 0.95, sz), light_wood)            # carcass
	var book_cols := [Color(0.6, 0.2, 0.2), Color(0.2, 0.4, 0.55), Color(0.3, 0.5, 0.25),
		Color(0.6, 0.5, 0.2), Color(0.4, 0.3, 0.5), Color(0.7, 0.6, 0.4)]
	for shelf in range(3):
		var sy := 0.45 + shelf * 0.55
		_box(Vector3(0.3, 0.04, 1.0), Vector3(sx, sy, sz), _mat_wood, false)    # shelf board
		for b in range(6):
			var bz := sz - 0.42 + b * 0.15
			var bh: float = 0.32 + (b % 3) * 0.04
			var col: Color = book_cols[(shelf * 6 + b) % book_cols.size()]
			_box(Vector3(0.16, bh, 0.11), Vector3(sx - 0.03, sy + bh * 0.5 + 0.02, bz), _solid(col, 0.9), false)


## Barrels and a stack of crates in the front-left corner.
func _build_storage(hx: float, hz: float, light_wood: StandardMaterial3D, metal: StandardMaterial3D) -> void:
	var cx := -hx + 0.55
	_barrel(Vector3(cx, 0.0, hz - 0.9), metal)
	_barrel(Vector3(cx + 0.7, 0.0, hz - 0.7), metal)
	# Crate stack in the front-right (clear of the bed, bookshelf and door).
	_box(Vector3(0.6, 0.6, 0.6), Vector3(2.0, 0.3, hz - 0.9), light_wood)
	_box(Vector3(0.5, 0.5, 0.5), Vector3(2.0, 0.85, hz - 0.9), light_wood)
	_box(Vector3(0.55, 0.55, 0.55), Vector3(1.4, 0.28, hz - 0.5), light_wood)


## Wall shelf above the table holding pots and a sack.
func _build_wall_shelves(hx: float, light_wood: StandardMaterial3D, clay: StandardMaterial3D) -> void:
	var sx := -hx + 0.16
	_box(Vector3(0.26, 0.04, 1.4), Vector3(sx, 1.6, 1.4), light_wood, false)
	_cyl(0.1, 0.22, Vector3(sx + 0.02, 1.73, 1.1), clay, false)
	_cyl(0.08, 0.18, Vector3(sx + 0.02, 1.71, 1.4), _solid(Color(0.45, 0.5, 0.4), 0.9), false)
	_cyl(0.11, 0.2, Vector3(sx + 0.02, 1.72, 1.75), clay, false)


## Decorative ceiling beams spanning the room.
func _build_ceiling_beams() -> void:
	for z in [-1.4, 0.0, 1.4]:
		_box(Vector3(W + 0.3, 0.14, 0.16), Vector3(0, WALL_H - 0.12, z), _mat_wood, false)


## A broom leaning into the front-right corner.
func _build_broom(hx: float, hz: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(hx - 0.35, 0, hz - 0.35)
	pivot.rotation = Vector3(0.18, 0, 0.14)
	add_child(pivot)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 1.5
	pole.mesh = cm
	pole.material_override = _mat_wood
	pole.position = Vector3(0, 0.75, 0)
	pivot.add_child(pole)
	var bristles := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.03
	bm.bottom_radius = 0.14
	bm.height = 0.35
	bristles.mesh = bm
	bristles.material_override = _solid(Color(0.75, 0.6, 0.3), 1.0)
	bristles.position = Vector3(0, 0.17, 0)
	pivot.add_child(bristles)


# --- Small helpers ----------------------------------------------------------

## A lit candle: stick, drip, and an emissive flame.
func _candle(base: Vector3) -> void:
	_cyl(0.04, 0.18, base + Vector3(0, 0.09, 0), _solid(Color(0.9, 0.88, 0.8), 1.0), false)
	var flame := _solid(Color(1.0, 0.8, 0.3), 1.0)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.7, 0.25)
	flame.emission_energy_multiplier = 5.0
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var f := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.1
	f.mesh = sm
	f.material_override = flame
	f.position = base + Vector3(0, 0.23, 0)
	add_child(f)


## A wooden barrel (body + two iron bands + lid) standing on the floor.
func _barrel(base: Vector3, band_mat: StandardMaterial3D) -> void:
	var body := _solid(Color(0.42, 0.3, 0.18), 0.9)
	_cyl(0.27, 0.8, base + Vector3(0, 0.4, 0), body)
	_cyl(0.29, 0.06, base + Vector3(0, 0.22, 0), band_mat, false)
	_cyl(0.29, 0.06, base + Vector3(0, 0.6, 0), band_mat, false)
	_cyl(0.24, 0.04, base + Vector3(0, 0.81, 0), body, false)


## A cylinder mesh (and optional collider). `mostly_box_collider` swaps in a thin
## box collider — used where a true cylinder collider isn't worth it.
func _cyl(radius: float, height: float, pos: Vector3, mat: Material, collide := true, _logs := false) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = radius
		cs.height = height
		col.shape = cs
		col.position = pos
		add_child(col)


## Make a solid-colour material quickly.
func _solid(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m
