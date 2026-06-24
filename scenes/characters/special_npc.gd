extends CharacterBody3D
## A SPECIAL NPC (one of two per location). Distinct from ordinary wandering folk:
##   - a unique robed look + a floating marker over the head,
##   - gives a quest you must finish WITHOUT dying,
##   - on completion grants rewards AND opens a SHOP you can spend looted gold at.
##
## All data (id, name, quest, robe colour, shop stock) is pushed in by the Landmarks
## spawner before _ready (see landmarks.gd / world_npcs.gd). Quest LOGIC lives in the
## Quests autoload; this node drives presentation + the shop hand-off.

const GRAVITY := 22.0

# Set by the spawner before add_child:
var npc_id := ""
var display_name := "Stranger"
var quest_id := ""
var role := "warden"              # "warden" (hunt) or "sage" (robed caster)
var robe := Color(0.8, 0.7, 0.3)
var shop: Array = []              # [{item:Dictionary, price:int}, ...]
var palette := {}                # base location palette

@onready var interact_area: Area3D = $InteractArea
@onready var humanoid = get_node_or_null("Humanoid")

const MARKER_VIEW_DIST := 50.0   # only show the "?" when this close AND on-screen

var player_in_range := false
var _marker: Label3D
var _mark_t := 0.0


func _ready() -> void:
	add_to_group("special_npcs")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_apply_look()
	_build_marker()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _process(delta: float) -> void:
	_mark_t -= delta
	if _mark_t <= 0.0:
		_mark_t = 0.2
		_refresh_marker()


# --- Look --------------------------------------------------------------------

func _apply_look() -> void:
	if humanoid == null:
		return
	# Base on the location palette, then override with the special's bright robe so they
	# stand out from ordinary NPCs.
	if not palette.is_empty():
		humanoid.skin_color = palette.get("skin", humanoid.skin_color)
		humanoid.hair_color = palette.get("hair", humanoid.hair_color)
	humanoid.tunic_color = robe
	humanoid.shorts_color = robe.darkened(0.35)
	humanoid.legs_color = robe.darkened(0.2)
	if role == "sage":
		humanoid.hat_style = 1                 # hooded/hatted caster
		humanoid.hair_style = 1
		humanoid.tunic_color = robe.lightened(0.1)
	else:
		humanoid.hair_style = 2                # warden: rugged
	humanoid.scale = Vector3.ONE * 1.12        # slightly larger presence


## A small floating marker above the head: a "?" while they have a quest for you
## (gold = on offer, green = ready to hand in), or a "$" once their shop is open. Only
## shown when the NPC is actually on screen and reasonably close.
func _build_marker() -> void:
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.fixed_size = true
	_marker.pixel_size = 0.004
	_marker.font_size = 40
	_marker.outline_size = 10
	_marker.no_depth_test = true
	_marker.position = Vector3(0, 2.4, 0)
	add_child(_marker)
	_refresh_marker()


func _refresh_marker() -> void:
	if _marker == null:
		return
	# Hide unless the NPC is on screen (in the camera's view) and close enough.
	var cam := get_viewport().get_camera_3d()
	var head := global_position + Vector3.UP * 2.4
	var on_screen := cam != null and cam.is_position_in_frustum(head) \
		and global_position.distance_to(cam.global_position) < MARKER_VIEW_DIST
	if not on_screen:
		_marker.visible = false
		return
	_marker.visible = true
	var quests := get_node_or_null("/root/Quests")
	var st: String = quests.status_of(quest_id) if quests != null else "available"
	match st:
		"available":
			_marker.text = "?"
			_marker.modulate = Color(1.0, 0.85, 0.2)
		"active":
			_marker.text = "?"
			_marker.modulate = Color(0.8, 0.8, 0.85)
		"ready":
			_marker.text = "?"
			_marker.modulate = Color(0.4, 1.0, 0.4)
		"done":
			_marker.text = "$"
			_marker.modulate = Color(0.5, 0.9, 1.0)


# --- Interaction -------------------------------------------------------------

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = false


## Called by Main when the player presses E in range.
func interact(player) -> void:
	var quests := get_node_or_null("/root/Quests")
	if quests == null:
		return
	if player != null:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	var before: String = quests.status_of(quest_id)
	if before == "done":
		# Quest already finished: greet them and open the shop to spend gold.
		_say("Good to see you again. Take a look — gold buys plenty here.")
		_open_shop()
		return
	# Otherwise advance the quest lifecycle (offer / remind / turn in) and chat about it.
	var line: String = str(quests.talk_to(npc_id, player))
	if before == "available":
		line += "\n\nDo this for me and you'll have: " + quests.reward_text(quest_id) + "."
	_say(line)
	_refresh_marker()


func _open_shop() -> void:
	var ui = get_tree().get_first_node_in_group("shop_ui")
	if ui != null:
		ui.open(display_name, shop)


## Show a line in the on-screen chat box (the little dialogue panel at the bottom).
func _say(text: String) -> void:
	if text == "":
		return
	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if ui != null:
		ui.say(display_name, text)
