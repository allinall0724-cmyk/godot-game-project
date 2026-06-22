extends Control
## Small crosshair drawn at the TRUE aim point: it projects the world point that
## ranged attacks/abilities will actually hit (player.get_aim_point()) into screen
## space, so in third-person it sits on the real target, not just screen-center.

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5  # fallback: screen centre
	var cam := get_viewport().get_camera_3d()
	var player = get_tree().get_first_node_in_group("local_player")
	if cam != null and player != null and player.has_method("get_aim_point"):
		var aim: Vector3 = player.get_aim_point()
		if not cam.is_position_behind(aim):
			c = cam.unproject_position(aim)
	draw_arc(c, 5.0, 0.0, TAU, 24, Color(1, 1, 1, 0.55), 1.5, true)
	draw_circle(c, 1.3, Color(1, 1, 1, 0.85))
