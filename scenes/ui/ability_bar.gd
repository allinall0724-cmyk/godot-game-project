extends Control
## Bottom-of-screen spell bar. Shows one box per spell currently slotted onto the
## staff (up to 5, bound to Q/R/F/C/V). Each box is tinted by that spell's element.
## Reads the list from the player so there is a single source of truth
## (player.get_ability_bar_moves()).

const ELEMENT_TINT := {
	"fire": Color(1.0, 0.62, 0.38),
	"lightning": Color(0.62, 0.82, 1.0),
	"wind": Color(0.62, 1.0, 0.74),
	"sky": Color(0.86, 0.92, 1.0),
	"ice": Color(0.62, 0.86, 1.0),
	"earth": Color(0.78, 0.62, 0.42),
	"arcane": Color(0.82, 0.62, 1.0),
	"shadow": Color(0.66, 0.45, 0.82),
	"nature": Color(0.55, 0.85, 0.45),
}

@onready var slots := [
	$Panel/HBox/Slot0, $Panel/HBox/Slot1, $Panel/HBox/Slot2,
	$Panel/HBox/Slot3, $Panel/HBox/Slot4, $Panel/HBox/Slot5,
]
@onready var empty_label: Label = $Panel/HBox/Empty


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		visible = false
		return

	visible = true
	var moves: Array = player.get_ability_bar_moves()
	for i in range(slots.size()):
		var slot: Control = slots[i]
		if i < moves.size():
			slot.visible = true
			# Tint each slot by its own spell's element.
			slot.modulate = ELEMENT_TINT.get(str(moves[i].get("element", "")), Color(0.85, 0.85, 0.9))
			slot.get_node("VBox/Key").text = "%s · %d" % [moves[i]["key"], int(moves[i].get("cost", 0))]
			slot.get_node("VBox/Name").text = moves[i]["name"]
		else:
			slot.visible = false
	empty_label.visible = moves.is_empty()
