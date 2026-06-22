extends Control
## A small 2D icon that draws a simple SHAPE resembling the item type (staff,
## helmet, chestplate, greaves, coin), tinted to the item's color. Not a 3D render
## — just code-drawn primitives, so it reads as the item type rather than a square.

var _color := Color(0.72, 0.72, 0.75)
var _kind := "empty"  # weapon / helmet / chest / legs / coin / empty


func set_item(item) -> void:
	if item == null:
		_kind = "empty"
		_color = Color(0.72, 0.72, 0.75)
	else:
		_color = item.get("color", Color(0.72, 0.72, 0.75))
		match str(item.get("slot", "")):
			"weapon": _kind = "weapon"
			"helmet": _kind = "helmet"
			"chest": _kind = "chest"
			"legs": _kind = "legs"
			_: _kind = "coin"
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var c := _color
	var dark := c.darkened(0.45)
	var cx := w * 0.5
	match _kind:
		"weapon":
			# Staff: a wooden shaft with a glowing orb at the top.
			draw_rect(Rect2(cx - w * 0.03, h * 0.28, w * 0.06, h * 0.64), Color(0.32, 0.2, 0.1))
			draw_circle(Vector2(cx, h * 0.22), w * 0.16, c)
			draw_circle(Vector2(cx, h * 0.22), w * 0.08, c.lightened(0.4))
		"helmet":
			# Rounded dome + brim + a darker face opening.
			draw_circle(Vector2(cx, h * 0.46), w * 0.3, c)
			draw_rect(Rect2(cx - w * 0.36, h * 0.55, w * 0.72, h * 0.1), dark)
			draw_rect(Rect2(cx - w * 0.13, h * 0.4, w * 0.26, h * 0.16), c.darkened(0.25))
		"chest":
			# Tapered breastplate + center seam + shoulder bumps.
			var plate := PackedVector2Array([
				Vector2(cx - w * 0.32, h * 0.22), Vector2(cx + w * 0.32, h * 0.22),
				Vector2(cx + w * 0.22, h * 0.85), Vector2(cx - w * 0.22, h * 0.85)])
			draw_colored_polygon(plate, c)
			draw_circle(Vector2(cx - w * 0.3, h * 0.26), w * 0.08, c)
			draw_circle(Vector2(cx + w * 0.3, h * 0.26), w * 0.08, c)
			draw_rect(Rect2(cx - w * 0.015, h * 0.24, w * 0.03, h * 0.6), dark)
		"legs":
			draw_rect(Rect2(cx - w * 0.28, h * 0.2, w * 0.2, h * 0.7), c)
			draw_rect(Rect2(cx + w * 0.08, h * 0.2, w * 0.2, h * 0.7), c)
			draw_rect(Rect2(cx - w * 0.28, h * 0.78, w * 0.2, h * 0.12), dark)
			draw_rect(Rect2(cx + w * 0.08, h * 0.78, w * 0.2, h * 0.12), dark)
		"coin":
			draw_circle(Vector2(cx, h * 0.5), w * 0.32, c)
			draw_circle(Vector2(cx, h * 0.5), w * 0.18, c.darkened(0.2))
		_:
			# Empty slot: faint dashed-looking outline.
			draw_rect(Rect2(w * 0.15, h * 0.15, w * 0.7, h * 0.7), Color(0.6, 0.6, 0.62, 0.5), false, 2.0)
