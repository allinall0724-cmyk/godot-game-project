extends Node3D
## The interactable heart of a mini-location (standing stones, shrine, old well...).
## Press E nearby (handled in main.gd) to "search" it once for a small reward and a
## line of flavour — a little discovery quest. These are deliberately NOT shown on
## the minimap, so you have to stumble across them.

var landmark_name := "Ruins"
var flavor := "You search the ruins."
var reward_coins := 0
var reward_xp := 0
var reward_item: Dictionary = {}     # optional armour/item handed over once
var claimed := false


func _ready() -> void:
	add_to_group("landmarks")


## Called by main when the player interacts. Returns a short message to toast.
func interact(player) -> String:
	if claimed:
		return "%s — nothing left to find here." % landmark_name
	claimed = true
	var bits: Array = []
	if player != null:
		if reward_coins > 0 and player.has_method("add_coins"):
			player.add_coins(reward_coins)
			bits.append("+%d coins" % reward_coins)
		if reward_xp > 0 and player.has_method("gain_xp"):
			player.gain_xp(reward_xp)
			bits.append("+%d XP" % reward_xp)
		if not reward_item.is_empty() and player.has_method("add_item"):
			player.add_item(reward_item.duplicate(true))
			bits.append(str(reward_item.get("name", "an item")))
	var reward := ("   (" + ", ".join(bits) + ")") if not bits.is_empty() else ""
	return "%s — %s%s" % [landmark_name, flavor, reward]
