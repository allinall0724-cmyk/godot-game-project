extends Node
class_name ArmorCatalog
## Central catalog of wearable armor (helmets / chests / pants).
##
## Each entry is a plain item dictionary in the SAME format the inventory/equip
## system already uses (see player.gd STARTING_STAFF and chest.gd LOOT_SETS):
##   name, rarity, tier, edition, slot, color, + stat modifiers.
##
## Stat modifiers (any may be omitted; omitted = 0):
##   move_mod      float  +/- walk speed (m/s)        -> mobility
##   jump_mod      float  +/- jump take-off velocity  -> mobility
##   health_bonus  int    +/- max HP                  -> health
##   stamina_bonus float  +/- max stamina             -> stamina
##   regen_bonus   float  +/- stamina regen / sec     -> stamina
##
## The "model" field selects a PROCEDURAL SHAPE built by humanoid.gd
## (apply_equipment), so pieces look genuinely different — not just recolored.
## To add a new look: add an entry here with a new "model" id, then add a branch
## for that id in humanoid.gd (_build_helmet / _build_chest / _build_legs).
##
## Design intent (so trade-offs feel meaningful, never strictly-better):
##   heavy metal  -> big +HP, but -move / -jump / -stamina
##   cloth/robe   -> +stamina / +regen / a little +move, little or negative HP
##   leather      -> modest all-round, small bonuses
##   exotic/magic -> one strong stat with a matching drawback

# accent colors reused across pieces
const GOLD := Color(0.85, 0.72, 0.28)
const BONE := Color(0.90, 0.87, 0.78)
const STEEL := Color(0.62, 0.64, 0.70)
const IRON := Color(0.50, 0.52, 0.58)

const HELMETS := [
	{"name": "Cloth Hood", "rarity": "Common", "tier": 1, "edition": 88, "slot": "helmet",
		"model": "hood", "color": Color(0.40, 0.30, 0.52),
		"move_mod": 0.2, "jump_mod": 0.1, "stamina_bonus": 10.0},
	{"name": "Leather Cap", "rarity": "Common", "tier": 1, "edition": 64, "slot": "helmet",
		"model": "cap", "color": Color(0.42, 0.28, 0.16),
		"health_bonus": 8, "stamina_bonus": 4.0},
	{"name": "Iron Helm", "rarity": "Uncommon", "tier": 2, "edition": 22, "slot": "helmet",
		"model": "great_helm", "color": IRON,
		"health_bonus": 25, "move_mod": -0.3, "jump_mod": -0.4},
	{"name": "Knight's Barbute", "rarity": "Uncommon", "tier": 2, "edition": 17, "slot": "helmet",
		"model": "barbute", "color": STEEL,
		"health_bonus": 20, "move_mod": -0.2},
	{"name": "Wizard's Hat", "rarity": "Rare", "tier": 3, "edition": 9, "slot": "helmet",
		"model": "wizard_hat", "color": Color(0.24, 0.18, 0.42),
		"stamina_bonus": 25.0, "regen_bonus": 6.0, "move_mod": 0.1, "health_bonus": -5},
	{"name": "Arcane Circlet", "rarity": "Rare", "tier": 3, "edition": 7, "slot": "helmet",
		"model": "circlet", "color": GOLD,
		"stamina_bonus": 20.0, "regen_bonus": 8.0, "move_mod": 0.15},
	{"name": "Horned Warhelm", "rarity": "Rare", "tier": 3, "edition": 5, "slot": "helmet",
		"model": "horned", "color": Color(0.34, 0.30, 0.34),
		"health_bonus": 30, "move_mod": -0.35, "stamina_bonus": -10.0},
	{"name": "Bone Skull-Mask", "rarity": "Epic", "tier": 4, "edition": 4, "slot": "helmet",
		"model": "bone", "color": BONE,
		"health_bonus": 10, "move_mod": 0.2, "jump_mod": 0.2, "regen_bonus": -3.0},
	{"name": "Gilded Crown", "rarity": "Epic", "tier": 4, "edition": 3, "slot": "helmet",
		"model": "crown", "color": GOLD,
		"health_bonus": 15, "stamina_bonus": 15.0, "regen_bonus": 4.0},
	{"name": "Winged Helm", "rarity": "Epic", "tier": 4, "edition": 2, "slot": "helmet",
		"model": "winged", "color": Color(0.78, 0.80, 0.86),
		"move_mod": 0.3, "jump_mod": 0.5, "health_bonus": 5},
]

const CHESTS := [
	{"name": "Cloth Robe", "rarity": "Common", "tier": 1, "edition": 90, "slot": "chest",
		"model": "robe", "color": Color(0.36, 0.34, 0.55),
		"stamina_bonus": 20.0, "regen_bonus": 5.0, "move_mod": 0.1},
	{"name": "Leather Vest", "rarity": "Common", "tier": 1, "edition": 71, "slot": "chest",
		"model": "leather", "color": Color(0.45, 0.30, 0.18),
		"health_bonus": 15},
	{"name": "Iron Cuirass", "rarity": "Uncommon", "tier": 2, "edition": 28, "slot": "chest",
		"model": "plate", "color": IRON,
		"health_bonus": 40, "move_mod": -0.5, "jump_mod": -0.6, "stamina_bonus": -10.0},
	{"name": "Scale Mail", "rarity": "Uncommon", "tier": 2, "edition": 19, "slot": "chest",
		"model": "scale", "color": Color(0.46, 0.50, 0.46),
		"health_bonus": 28, "move_mod": -0.3},
	{"name": "Studded Brigandine", "rarity": "Uncommon", "tier": 2, "edition": 14, "slot": "chest",
		"model": "brigandine", "color": Color(0.36, 0.24, 0.16),
		"health_bonus": 22, "stamina_bonus": 5.0},
	{"name": "Ranger's Cloak", "rarity": "Rare", "tier": 3, "edition": 8, "slot": "chest",
		"model": "cloak", "color": Color(0.22, 0.40, 0.26),
		"move_mod": 0.4, "jump_mod": 0.3, "stamina_bonus": 15.0, "health_bonus": 5},
	{"name": "Bonecage Harness", "rarity": "Epic", "tier": 4, "edition": 4, "slot": "chest",
		"model": "bone", "color": BONE,
		"health_bonus": 18, "move_mod": 0.2, "regen_bonus": -3.0},
	{"name": "Archmage Robe", "rarity": "Epic", "tier": 4, "edition": 3, "slot": "chest",
		"model": "ornate_robe", "color": Color(0.30, 0.16, 0.46),
		"stamina_bonus": 35.0, "regen_bonus": 10.0, "move_mod": 0.2, "health_bonus": -10},
	{"name": "Steel Cuirass", "rarity": "Epic", "tier": 4, "edition": 2, "slot": "chest",
		"model": "ornate_plate", "color": STEEL,
		"health_bonus": 55, "move_mod": -0.6, "jump_mod": -0.8},
]

const PANTS := [
	{"name": "Cloth Trousers", "rarity": "Common", "tier": 1, "edition": 92, "slot": "legs",
		"model": "trousers", "color": Color(0.34, 0.32, 0.50),
		"move_mod": 0.2, "stamina_bonus": 10.0},
	{"name": "Leather Leggings", "rarity": "Common", "tier": 1, "edition": 75, "slot": "legs",
		"model": "leather_legs", "color": Color(0.42, 0.28, 0.16),
		"health_bonus": 10},
	{"name": "Padded Leggings", "rarity": "Common", "tier": 1, "edition": 60, "slot": "legs",
		"model": "padded", "color": Color(0.50, 0.46, 0.40),
		"health_bonus": 12, "stamina_bonus": 8.0},
	{"name": "Iron Greaves", "rarity": "Uncommon", "tier": 2, "edition": 24, "slot": "legs",
		"model": "greaves", "color": IRON,
		"health_bonus": 20, "move_mod": -0.3, "jump_mod": -0.5},
	{"name": "Ranger Leggings", "rarity": "Rare", "tier": 3, "edition": 8, "slot": "legs",
		"model": "wraps", "color": Color(0.24, 0.40, 0.26),
		"move_mod": 0.35, "jump_mod": 0.4, "stamina_bonus": 10.0},
	{"name": "Bone Legguards", "rarity": "Rare", "tier": 3, "edition": 6, "slot": "legs",
		"model": "bone_legs", "color": BONE,
		"health_bonus": 15, "move_mod": 0.1},
	{"name": "Windstep Trousers", "rarity": "Epic", "tier": 4, "edition": 3, "slot": "legs",
		"model": "swift", "color": Color(0.70, 0.82, 0.92),
		"move_mod": 0.5, "jump_mod": 0.6, "stamina_bonus": 5.0, "health_bonus": -5},
	{"name": "Steel Legplates", "rarity": "Epic", "tier": 4, "edition": 2, "slot": "legs",
		"model": "plate_legs", "color": STEEL,
		"health_bonus": 35, "move_mod": -0.5, "jump_mod": -0.7},
]


## Every armor item in the catalog (helmets + chests + pants), as fresh copies so
## callers can mutate their own instances without touching the constants.
static func all_items() -> Array:
	var out: Array = []
	for group in [HELMETS, CHESTS, PANTS]:
		for item in group:
			out.append((item as Dictionary).duplicate(true))
	return out
