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

# Where the chosen starting character is remembered between sessions.
const SAVE_PATH := "user://save.cfg"

var piloting := false
var _trade_ui = null


func _ready() -> void:
	# Camera follows the player; pawns get a camera ref for camera-relative movement.
	camera.set_target(player)
	player.set_camera(camera)
	if ship != null:
		ship.set_camera(camera)
		ship.set_active(false)

	# First load only: pick a character. On later loads we restore the saved one
	# and drop straight into gameplay.
	var saved := _load_saved_character()
	if saved.is_empty():
		_show_character_select()
	else:
		_apply_appearance(saved)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Launch screen: choose a starting look. The player is frozen and the cursor is
## freed; the live model previews each option. On confirm we apply the chosen
## appearance, remember it, and drop into normal gameplay.
func _show_character_select() -> void:
	player.set_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var sel := CharacterSelect.new()
	sel.setup(player.get_node("Humanoid"))  # before add_child: _ready previews option 0
	add_child(sel)
	sel.chosen.connect(_on_character_chosen.bind(sel))


func _on_character_chosen(preset: Dictionary, sel: CharacterSelect) -> void:
	_apply_appearance(preset)
	_save_character(str(preset.get("name", "")))
	sel.queue_free()
	player.set_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _apply_appearance(preset: Dictionary) -> void:
	var humanoid = player.get_node("Humanoid")  # untyped: custom method call
	if humanoid.has_method("apply_appearance"):
		humanoid.apply_appearance(preset)


## Return the saved starting character's preset, or {} if none is saved yet (or the
## saved name no longer exists — in which case the picker shows again).
func _load_saved_character() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return {}
	var saved_name := str(cfg.get_value("character", "name", ""))
	if saved_name == "":
		return {}
	for p in CharacterPresets.PRESETS:
		if str((p as Dictionary).get("name", "")) == saved_name:
			return p
	return {}


func _save_character(saved_name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # preserve any other saved sections
	cfg.set_value("character", "name", saved_name)
	cfg.save(SAVE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_on_interact()


## E priority: (ignored while trading) exit/board ship > talk to a villager > open
## a nearby chest.
func _on_interact() -> void:
	if _trade_ui != null and _trade_ui.visible:
		return
	if ship != null:
		if piloting:
			_toggle_board()
			return
		if ship.player_in_range:
			_toggle_board()
			return
	var npc = _nearest_villager()
	if npc != null:
		_open_trade(npc)
		return
	var chest = _nearest_unopened_chest()
	if chest != null:
		chest.open(player)


## Nearest villager within talking distance, or null.
func _nearest_villager():
	var best = null
	var best_d := 3.5
	for v in get_tree().get_nodes_in_group("villagers"):
		var d: float = player.global_position.distance_to(v.global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


## Open the quest/trade dialogue with a villager; freezes the player + frees the
## cursor until the dialogue is closed.
func _open_trade(npc) -> void:
	if _trade_ui == null:
		_trade_ui = preload("res://scenes/ui/trade_ui.gd").new()
		get_node("UI").add_child(_trade_ui)
		_trade_ui.closed.connect(_on_trade_closed)
	player.set_active(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_trade_ui.open(npc, player)


func _on_trade_closed() -> void:
	player.set_active(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


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
