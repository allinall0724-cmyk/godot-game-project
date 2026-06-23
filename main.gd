extends Node3D
## Game manager for the Main scene (single-player).
##   - Wires the shared camera rig to the player / ship.
##   - Boarding: press E near the ship to pilot it; press E again to step off.
##
## (Multiplayer was removed for now — the networking scripts under scenes/net/
## are left on disk, unused, in case we wire it back later.)

@onready var camera = $CameraController
@onready var player = $Player
# Ship is OPTIONAL now — the active world is a single landmass with no water, so the
# Ship node was removed from node_3d.tscn. The boarding code below is kept and works
# automatically if you re-add a "Ship" node (instance scenes/ship/ship.tscn).
@onready var ship = get_node_or_null("Ship")

var piloting := false


func _ready() -> void:
	# Camera follows the player; pawns get a camera ref for camera-relative movement.
	camera.set_target(player)
	player.set_camera(camera)
	if ship != null:
		ship.set_camera(camera)
		ship.set_active(false)

	# Pick a character before play begins (freezes the player; mouse stays free).
	_show_character_select()


## Launch screen: choose a starting look. The player is frozen and the cursor is
## freed; the live model previews each option. On confirm we apply the chosen
## appearance and drop into normal gameplay.
func _show_character_select() -> void:
	player.set_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var sel := CharacterSelect.new()
	sel.setup(player.get_node("Humanoid"))  # before add_child: _ready previews option 0
	add_child(sel)
	sel.chosen.connect(_on_character_chosen.bind(sel))


func _on_character_chosen(preset: Dictionary, sel: CharacterSelect) -> void:
	var humanoid = player.get_node("Humanoid")  # untyped: custom method call
	if humanoid.has_method("apply_appearance"):
		humanoid.apply_appearance(preset)
	sel.queue_free()
	player.set_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_on_interact()


## E priority: exit ship if piloting > board ship if near it > open a nearby chest.
func _on_interact() -> void:
	if ship != null:
		if piloting:
			_toggle_board()
			return
		if ship.player_in_range:
			_toggle_board()
			return
	var chest = _nearest_unopened_chest()
	if chest != null:
		chest.open(player)


func _nearest_unopened_chest():
	var best = null
	var best_dist := INF
	for c in get_tree().get_nodes_in_group("chests"):
		if c.player_in_range and not c.opened:
			var d: float = player.global_position.distance_to(c.global_position)
			if d < best_dist:
				best = c
				best_dist = d
	return best


func _toggle_board() -> void:
	if not piloting:
		if ship.player_in_range:
			piloting = true
			player.set_active(false)
			player.visible = false
			ship.set_active(true)
			camera.set_target(ship)
	else:
		piloting = false
		ship.set_active(false)
		# Step off next to the bow, lifted a little so we don't clip the hull.
		player.global_position = ship.global_position + Vector3(0, 1.2, 3.0)
		player.visible = true
		player.set_active(true)
		camera.set_target(player)
