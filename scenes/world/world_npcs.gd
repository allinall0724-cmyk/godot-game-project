extends RefCounted
## Content + theming for the people (and themed enemies) at every landmark. Pure DATA,
## preloaded by the Landmarks builder and the Quests autoload — no nodes here.
##
## Per location (keyed by WorldLocations "kind") this defines:
##   - a flavour PALETTE for ordinary wandering NPCs (look matches the place),
##   - which ENEMY type haunts the area (and how many to spawn),
##   - TWO SPECIAL NPCs (a "warden" and a "sage"), each with a unique look, a quest
##     you must finish WITHOUT DYING, rewards, and a SHOP that unlocks once it's done.
##
## Quests support multiple STEPS (parts). The warden gives a 1-part hunt; the sage gives
## a 2-part "travel here, then clear them out" task. Add/edit content here and it flows
## automatically to the NPCs, quests, minimap and shops.

const THEMES := {
	"village": {
		"palette": {"skin": Color(0.9, 0.74, 0.6), "tunic": Color(0.55, 0.42, 0.28), "hair": Color(0.7, 0.55, 0.2), "hat": 1},
		"enemy": "goblin", "enemy_count": 0,
		"warden": "Captain Hale", "sage": "Mother Yarrow",
		"warden_robe": Color(0.85, 0.7, 0.25), "sage_robe": Color(0.95, 0.9, 0.55),
		"hunt": 4, "spell": "gust",
	},
	"forest": {
		"palette": {"skin": Color(0.82, 0.7, 0.55), "tunic": Color(0.2, 0.4, 0.22), "hair": Color(0.35, 0.25, 0.12), "hat": 0},
		"enemy": "wolf", "enemy_count": 5,
		"warden": "Ranger Thorn", "sage": "Druid Elowen",
		"warden_robe": Color(0.2, 0.55, 0.25), "sage_robe": Color(0.45, 0.75, 0.4),
		"hunt": 4, "spell": "levitate",
	},
	"city": {
		"palette": {"skin": Color(0.88, 0.72, 0.58), "tunic": Color(0.35, 0.4, 0.55), "hair": Color(0.25, 0.18, 0.1), "hat": 0},
		"enemy": "goblin", "enemy_count": 4,
		"warden": "Watch-Captain Doran", "sage": "Archivist Pell",
		"warden_robe": Color(0.3, 0.5, 0.85), "sage_robe": Color(0.6, 0.75, 1.0),
		"hunt": 5, "spell": "lightning_zap",
	},
	"fortress": {
		"palette": {"skin": Color(0.85, 0.68, 0.55), "tunic": Color(0.4, 0.4, 0.45), "hair": Color(0.2, 0.15, 0.1), "hat": 0},
		"enemy": "orc", "enemy_count": 4,
		"warden": "Sergeant Brakka", "sage": "Quartermaster Vell",
		"warden_robe": Color(0.7, 0.3, 0.25), "sage_robe": Color(0.8, 0.55, 0.3),
		"hunt": 3, "spell": "boulder_toss",
	},
	"castle": {
		"palette": {"skin": Color(0.9, 0.76, 0.62), "tunic": Color(0.45, 0.4, 0.6), "hair": Color(0.3, 0.2, 0.1), "hat": 0},
		"enemy": "skeleton", "enemy_count": 5,
		"warden": "Sir Gavin", "sage": "Court Mage Iselle",
		"warden_robe": Color(0.55, 0.4, 0.85), "sage_robe": Color(0.75, 0.6, 0.95),
		"hunt": 4, "spell": "frost_bolt",
	},
	"kingdom": {
		"palette": {"skin": Color(0.9, 0.78, 0.64), "tunic": Color(0.8, 0.78, 0.74), "hair": Color(0.35, 0.25, 0.12), "hat": 0},
		"enemy": "orc", "enemy_count": 5,
		"warden": "Lord-Marshal Aldric", "sage": "High Magus Soren",
		"warden_robe": Color(0.9, 0.82, 0.45), "sage_robe": Color(0.95, 0.95, 0.85),
		"hunt": 4, "spell": "chain_lightning",
	},
	"undead": {
		"palette": {"skin": Color(0.7, 0.78, 0.7), "tunic": Color(0.3, 0.34, 0.32), "hair": Color(0.4, 0.42, 0.4), "hat": 0},
		"enemy": "skeleton", "enemy_count": 6,
		"warden": "Gravewarden Mort", "sage": "Necrologist Vane",
		"warden_robe": Color(0.5, 0.7, 0.4), "sage_robe": Color(0.55, 0.85, 0.5),
		"hunt": 5, "spell": "ice_wall",
	},
	"dragon": {
		"palette": {"skin": Color(0.82, 0.66, 0.55), "tunic": Color(0.45, 0.2, 0.18), "hair": Color(0.15, 0.1, 0.08), "hat": 0},
		"enemy": "orc", "enemy_count": 4,
		"warden": "Dragonslayer Kael", "sage": "Cultist-Seer Nyx",
		"warden_robe": Color(0.9, 0.35, 0.2), "sage_robe": Color(0.7, 0.2, 0.25),
		"hunt": 3, "spell": "meteor",
	},
}


## Build the full list of special NPCs (2 per location). Each entry carries everything
## a SpecialNPC node and the Quests autoload need.
static func specials() -> Array:
	var out: Array = []
	for loc in _locations():
		var kind: String = loc["kind"]
		if not THEMES.has(kind):
			continue
		var th: Dictionary = THEMES[kind]
		var c: Vector2 = loc["pos"]
		var lname: String = loc["name"]
		# Warden: a one-part hunt right here, no dying.
		out.append({
			"id": kind + "_warden",
			"name": th["warden"], "role": "warden", "robe": th["warden_robe"],
			"location": lname, "kind": kind, "pos": c + Vector2(7, 5),
			"quest_id": kind + "_warden_q",
			"shop": _warden_shop(kind, lname),
		})
		# Sage: a two-part task (travel here, then clear them out), no dying.
		out.append({
			"id": kind + "_sage",
			"name": th["sage"], "role": "sage", "robe": th["sage_robe"],
			"location": lname, "kind": kind, "pos": c + Vector2(-7, -5),
			"quest_id": kind + "_sage_q",
			"shop": _sage_shop(kind, lname),
		})
	return out


## Quest definitions for every special NPC, keyed by quest id. Merged into the Quests
## autoload at startup.
static func quest_defs() -> Dictionary:
	var defs: Dictionary = {}
	for loc in _locations():
		var kind: String = loc["kind"]
		if not THEMES.has(kind):
			continue
		var th: Dictionary = THEMES[kind]
		var lname: String = loc["name"]
		var enemy: String = th["enemy"]
		var hunt: int = int(th["hunt"])
		defs[kind + "_warden_q"] = {
			"title": "%s: The Hunt" % lname,
			"giver": kind + "_warden", "no_death": true,
			"steps": [{"type": "kill", "target": enemy, "count": hunt}],
			"rewards": {"coins": 35 + hunt * 5, "gear": _warden_reward(kind, lname)},
			"offer_text": "Prove yourself: slay %d %ss — and do NOT fall in battle. Die, and the deal's off." % [hunt, enemy],
			"turnin_text": "Not a scratch on you. Take this, and my stall's open to you now.",
		}
		defs[kind + "_sage_q"] = {
			"title": "%s: Reckoning" % lname,
			"giver": kind + "_sage", "no_death": true,
			"steps": [
				{"type": "reach", "target": lname, "count": 1},
				{"type": "kill", "target": enemy, "count": maxi(2, hunt - 1)},
			],
			"rewards": {"coins": 60 + hunt * 6, "spell": th["spell"], "gear": _sage_reward(kind, lname)},
			"offer_text": "Two trials, wizard, and no dying between them: reach %s, then cull %d %ss. Survive and I'll share old secrets — and my wares." % [lname, maxi(2, hunt - 1), enemy],
			"turnin_text": "You walked through it and lived. The knowledge — and the shop — are yours.",
		}
	return defs


# --- Shops & rewards (item dicts use the inventory format; price = gold cost) -------

static func _warden_shop(kind: String, lname: String) -> Array:
	var th: Dictionary = THEMES[kind]
	return [
		{"item": {"name": "%s Helm" % lname, "rarity": "Uncommon", "tier": 2, "edition": 20, "slot": "helmet", "model": "cap", "color": th["warden_robe"], "health_bonus": 14}, "price": 40},
		{"item": {"name": "%s Greaves" % lname, "rarity": "Uncommon", "tier": 2, "edition": 20, "slot": "legs", "model": "greaves", "color": th["warden_robe"], "health_bonus": 12, "move_mod": -0.1}, "price": 55},
		{"item": {"name": "Healing Draught", "rarity": "Common", "tier": 1, "edition": 99, "slot": "", "color": Color(0.8, 0.2, 0.3)}, "price": 15},
	]


static func _sage_shop(kind: String, lname: String) -> Array:
	var th: Dictionary = THEMES[kind]
	return [
		{"item": {"name": "%s Robe" % lname, "rarity": "Rare", "tier": 3, "edition": 12, "slot": "chest", "model": "robe", "color": th["sage_robe"], "stamina_bonus": 20.0, "regen_bonus": 4.0}, "price": 90},
		{"item": {"name": "Mana Trinket", "rarity": "Uncommon", "tier": 2, "edition": 30, "slot": "", "color": th["sage_robe"]}, "price": 35},
	]


static func _warden_reward(kind: String, lname: String) -> Dictionary:
	var th: Dictionary = THEMES[kind]
	return {"name": "%s Bulwark" % lname, "rarity": "Rare", "tier": 3, "edition": 8, "slot": "chest", "model": "ornate_plate", "color": th["warden_robe"], "health_bonus": 30, "move_mod": -0.3}


static func _sage_reward(kind: String, lname: String) -> Dictionary:
	var th: Dictionary = THEMES[kind]
	return {"name": "%s Sigil" % lname, "rarity": "Epic", "tier": 4, "edition": 4, "slot": "", "color": th["sage_robe"]}


# --- Flavour NPCs ------------------------------------------------------------

## Appearance palette for ordinary wandering NPCs at a location (or {} if unknown).
static func flavor_palette(kind: String) -> Dictionary:
	if THEMES.has(kind):
		return THEMES[kind]["palette"]
	return {}


static func enemy_for(kind: String) -> String:
	return str(THEMES.get(kind, {}).get("enemy", "goblin"))


static func enemy_count_for(kind: String) -> int:
	return int(THEMES.get(kind, {}).get("enemy_count", 0))


static func _locations() -> Array:
	return load("res://scenes/world/world_locations.gd").ALL
