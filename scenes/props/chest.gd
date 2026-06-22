extends StaticBody3D
## A simple lootable chest. Walk up and press E (interaction is driven by Main,
## the same input used for ship boarding). Opening it once gives the player a
## couple of basic items via the existing inventory/equipment system, plays a
## lid-open animation, and shows a floating pickup label. Test case for loot —
## not a full loot table yet.

@onready var interact_area: Area3D = $InteractArea
@onready var lid: Node3D = $Lid

## Which loot set this chest drops (set per-instance in the editor / scene).
@export var loot_set := "hub"

var player_in_range := false
var opened := false

# Named loot sets, in the same item format the player inventory already uses
# (GAME_DESIGN.md 1.6/1.7). Higher-tier sets give better loot. With the wizard
# pivot these are ARMOR + trinkets only — the player's weapon is always the staff,
# and spells are equipped separately (not looted as weapons yet).
const LOOT_SETS := {
	"hub_armor": [
		{"name": "Iron Helmet", "rarity": "Common", "tier": 1, "edition": 1, "slot": "helmet", "model": "great_helm", "color": Color(0.6, 0.62, 0.68), "move_mod": -0.2, "health_bonus": 12},
		{"name": "Gold Coin", "rarity": "Common", "tier": 1, "edition": 1, "slot": "", "color": Color(0.9, 0.75, 0.2)},
	],
	"island_rare": [
		{"name": "Leather Tunic", "rarity": "Uncommon", "tier": 2, "edition": 4, "slot": "chest", "model": "leather", "color": Color(0.45, 0.3, 0.18), "move_mod": -0.1, "health_bonus": 16},
		{"name": "Silver Coin", "rarity": "Uncommon", "tier": 2, "edition": 3, "slot": "", "color": Color(0.8, 0.8, 0.85)},
	],
	"island_epic": [
		{"name": "Knight Helmet", "rarity": "Rare", "tier": 3, "edition": 2, "slot": "helmet", "model": "barbute", "color": Color(0.45, 0.5, 0.62), "move_mod": -0.3, "health_bonus": 22},
		{"name": "Iron Greaves", "rarity": "Rare", "tier": 3, "edition": 5, "slot": "legs", "model": "greaves", "color": Color(0.5, 0.52, 0.58), "move_mod": -0.4, "jump_mod": -0.8, "health_bonus": 18},
	],
	# Extra gear variety for testing (distinct colors + stat trade-offs).
	"armory1": [
		{"name": "Bronze Helm", "rarity": "Common", "tier": 1, "edition": 12, "slot": "helmet", "model": "cap", "color": Color(0.7, 0.5, 0.25), "health_bonus": 8},
		{"name": "Cloth Robe", "rarity": "Common", "tier": 1, "edition": 40, "slot": "chest", "model": "robe", "color": Color(0.45, 0.25, 0.5), "stamina_bonus": 18.0, "regen_bonus": 4.0},
		{"name": "Padded Legs", "rarity": "Common", "tier": 1, "edition": 33, "slot": "legs", "model": "padded", "color": Color(0.4, 0.3, 0.2), "health_bonus": 12, "stamina_bonus": 6.0},
	],
	"armory2": [
		{"name": "Gilded Helm", "rarity": "Epic", "tier": 4, "edition": 4, "slot": "helmet", "model": "horned", "color": Color(0.85, 0.7, 0.3), "move_mod": -0.25, "health_bonus": 30},
		{"name": "Plate Cuirass", "rarity": "Epic", "tier": 4, "edition": 6, "slot": "chest", "model": "ornate_plate", "color": Color(0.6, 0.62, 0.7), "move_mod": -0.5, "health_bonus": 50, "jump_mod": -0.6},
		{"name": "Plate Greaves", "rarity": "Epic", "tier": 4, "edition": 9, "slot": "legs", "model": "plate_legs", "color": Color(0.6, 0.62, 0.7), "move_mod": -0.5, "jump_mod": -1.0, "health_bonus": 25},
	],
}


func _ready() -> void:
	add_to_group("chests")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = false


## Open the chest and hand its loot to `player` (the Player node). Once only.
func open(player) -> void:
	if opened:
		return
	opened = true

	var loot: Array = LOOT_SETS.get(loot_set, [])
	var names: Array = []
	for item in loot:
		player.add_item(item)
		if item.get("slot", "") != "":
			player.equip(item)
		names.append(item["name"])

	_animate_open()
	_show_pickup("Looted: " + ", ".join(names))
	print("Chest opened. Player received: ", names)


func _animate_open() -> void:
	var tween := create_tween()
	tween.tween_property(lid, "rotation:x", deg_to_rad(-110), 0.4).set_trans(Tween.TRANS_BACK)


func _show_pickup(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.007
	l.font_size = 48
	l.outline_size = 12
	l.no_depth_test = true
	l.modulate = Color(1, 0.9, 0.4)
	get_tree().current_scene.add_child(l)
	l.global_position = global_position + Vector3.UP * 1.4

	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.0, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.4)
	tw.chain().tween_callback(l.queue_free)
