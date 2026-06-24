extends Control
## Top-down minimap (top-right corner): shows the whole landmass with the village
## clearing, the player's position + facing, and a live X/Z/Y coordinate readout.
## MAP_SIZE must match the terrain's SIZE constant.

const MAP_SIZE := 500.0      # world span the minimap represents (= terrain SIZE)
const VILLAGE_RADIUS := 28.0 # = terrain FLAT_RADIUS
const Locations = preload("res://scenes/world/world_locations.gd")  # named landmarks

@onready var _font: Font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var mh := w  # the map itself is a square (w × w); text sits below it

	# Panel + border.
	draw_rect(Rect2(0, 0, w, mh), Color(0.05, 0.08, 0.05, 0.5))
	draw_rect(Rect2(0, 0, w, mh), Color(1, 1, 1, 0.3), false, 1.0)

	var center := Vector2(w * 0.5, mh * 0.5)
	# Village clearing + spawn marker.
	draw_arc(center, VILLAGE_RADIUS / MAP_SIZE * w, 0.0, TAU, 20, Color(0.9, 0.85, 0.4, 0.5), 1.0)
	draw_circle(center, 2.5, Color(0.95, 0.85, 0.3))

	# North label.
	if _font != null:
		draw_string(_font, Vector2(w * 0.5 - 4, 12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))

	# Named landmarks (villages, city, castle, dragon dungeon, ...).
	_draw_locations(w, mh)

	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	var pos: Vector3 = player.global_position

	# Player position on the map (world XZ -> minimap pixels).
	var mp := Vector2((pos.x / MAP_SIZE + 0.5) * w, (pos.z / MAP_SIZE + 0.5) * mh)
	mp.x = clampf(mp.x, 0.0, w)
	mp.y = clampf(mp.y, 0.0, mh)

	# Facing indicator (player's -Z forward).
	var fwd: Vector3 = -player.global_transform.basis.z
	var fdir := Vector2(fwd.x, fwd.z)
	if fdir.length() > 0.01:
		draw_line(mp, mp + fdir.normalized() * 9.0, Color(1, 1, 1, 0.9), 1.5)
	draw_circle(mp, 3.5, Color(0.3, 0.7, 1.0))

	# Coordinate readout below the map.
	if _font != null:
		var txt := "X %d   Z %d   Y %d" % [int(pos.x), int(pos.z), int(pos.y)]
		draw_string(_font, Vector2(2, mh + 15), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.95))


## Plot every WorldLocations landmark: a coloured dot plus its name. The label sits
## to the right of the dot, or flips to the left when it would run off the map edge.
func _draw_locations(w: float, mh: float) -> void:
	const FONT_SIZE := 8
	for loc in Locations.ALL:
		var lp: Vector2 = loc["pos"]
		var col := _kind_color(str(loc["kind"]))
		var mpix := Vector2((lp.x / MAP_SIZE + 0.5) * w, (lp.y / MAP_SIZE + 0.5) * mh)
		# Capitals and the dragon lair get a slightly bigger marker.
		var r := 3.0 if str(loc["kind"]) in ["kingdom", "dragon", "city"] else 2.3
		draw_circle(mpix, r, col)
		draw_circle(mpix, r, Color(0, 0, 0, 0.7), false, 1.0)
		if _font == null:
			continue
		var name: String = loc["name"]
		var tw: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var tx := mpix.x + r + 3.0
		if tx + tw > w - 2.0:
			tx = mpix.x - r - 3.0 - tw   # flip to the left of the dot
		var ty := clampf(mpix.y + 3.0, 10.0, mh - 2.0)
		var tpos := Vector2(tx, ty)
		# Dark shadow for legibility, then the label in a bright tint of the dot colour.
		draw_string(_font, tpos + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0, 0, 0, 0.85))
		draw_string(_font, tpos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col.lerp(Color.WHITE, 0.35))


## Minimap marker colour per landmark kind.
func _kind_color(kind: String) -> Color:
	match kind:
		"village": return Color(0.55, 0.85, 0.45)
		"forest": return Color(0.32, 0.66, 0.32)
		"city": return Color(0.7, 0.85, 1.0)
		"fortress": return Color(0.74, 0.76, 0.82)
		"castle": return Color(0.78, 0.6, 0.95)
		"kingdom": return Color(1.0, 0.82, 0.3)
		"undead": return Color(0.72, 0.85, 0.4)
		"dragon": return Color(1.0, 0.45, 0.3)
		_: return Color(0.9, 0.9, 0.9)
