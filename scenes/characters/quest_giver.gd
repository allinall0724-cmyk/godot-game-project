extends CharacterBody3D
## A stationary NPC that offers and turns in quests. The player walks up and presses
## E (interaction is routed through Main, exactly like chests and the ship). All the
## quest LOGIC lives in the Quests autoload — this node only identifies which giver it
## is (giver_id) and shows the reply it gets back as a floating speech label.
##
## To add another quest giver: drop this scene in the world, set giver_id, and point a
## quest's "giver" field at that id in quest_manager.gd.

const GRAVITY := 22.0

## Matches the "giver" field of the quests this NPC hands out (see quest_manager.gd).
@export var giver_id := "elder"

@onready var interact_area: Area3D = $InteractArea
@onready var humanoid = get_node_or_null("Humanoid")

var player_in_range := false


func _ready() -> void:
	add_to_group("quest_givers")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	if humanoid != null:
		humanoid.hair_style = 2  # give the elder a distinct look


func _physics_process(delta: float) -> void:
	# Just stay grounded; the elder doesn't wander.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = false


## Called by Main's interact handler when the player presses E in range.
func talk(player) -> void:
	var quests := get_node_or_null("/root/Quests")
	if quests == null:
		return
	if player_in_range and player != null:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	var before: String = quests.status_of(_first_quest())
	var line: String = str(quests.talk_to(giver_id, player))
	if before == "available" and _first_quest() != "":
		line += "\n\nFor your trouble: " + quests.reward_text(_first_quest()) + "."
	_say(line)


## The Elder's next offerable/active quest id (for showing reward text), or "".
func _first_quest() -> String:
	var quests := get_node_or_null("/root/Quests")
	if quests == null:
		return ""
	for st in ["available", "active", "ready"]:
		var id: String = quests._first_for_giver(giver_id, st)
		if id != "":
			return id
	return ""


## Show a line in the on-screen chat box at the bottom of the screen.
func _say(text: String) -> void:
	if text == "":
		return
	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if ui != null:
		ui.say("Village Elder", text)
