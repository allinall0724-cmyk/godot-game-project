extends Node
## Global quest tracker (autoloaded as "Quests"; see project.godot).
##
## Holds quest DEFINITIONS (the Elder's hand-written QUESTS below + the per-location
## special-NPC quests generated in world_npcs.gd), the player's per-quest STATE, the
## EVENT hooks that advance objectives, REWARD granting, the "without dying" fail rule,
## and PERSISTENCE.
##
## Quests have multiple STEPS (parts). A quest flows:
##   available --(talk to giver)--> active --(all steps met)--> ready
##            --(talk to giver again)--> done   (rewards granted once; shop unlocks)
## If a quest is flagged `no_death`, dying while it's active RESETS it to available.

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal toast(text: String)

const SAVE_PATH := "user://save.cfg"
const Locations = preload("res://scenes/world/world_locations.gd")
const NPCs = preload("res://scenes/world/world_npcs.gd")

# Hand-authored quests from the village Elder (giver_id "elder"). These use a single
# "objective" for brevity; it's normalised into a one-step quest at load.
const QUESTS := {
	"goblin_cull": {
		"title": "Goblin Cull", "giver": "elder",
		"summary": "Goblins have been raiding the village stores. Cull five of them.",
		"objective": {"type": "kill", "target": "goblin", "count": 5},
		"rewards": {"coins": 40, "gear": {"name": "Warden's Helm", "rarity": "Uncommon", "tier": 2, "edition": 7,
			"slot": "helmet", "model": "barbute", "color": Color(0.5, 0.55, 0.62), "move_mod": -0.2, "health_bonus": 18}},
		"offer_text": "You there, wizard — goblins are bleeding us dry. Thin them out and I'll see you rewarded.",
		"turnin_text": "The raids have eased already. Take this helm, you've earned it.",
	},
	"orc_warband": {
		"title": "Break the Warband", "giver": "elder",
		"summary": "An orc warband gathers beyond the hills. Slay two orcs.",
		"objective": {"type": "kill", "target": "orc", "count": 2},
		"rewards": {"coins": 75, "spell": "frost_bolt"},
		"offer_text": "The goblins were the least of it. Orcs are massing. End two of them and I'll teach you a frost incantation.",
		"turnin_text": "Frost will serve you well. The village is in your debt.",
	},
	"scout_bonefields": {
		"title": "Whispers in the Bonefields", "giver": "elder",
		"summary": "The dead are said to walk the Bonefields. Travel there and see.",
		"objective": {"type": "reach", "target": "The Bonefields", "count": 1},
		"rewards": {"coins": 60, "gear": {"name": "Wardstone Pendant", "rarity": "Rare", "tier": 3, "edition": 9, "slot": "", "color": Color(0.6, 0.85, 0.7)}},
		"offer_text": "Travellers speak of the dead stirring in the Bonefields to the south. Go and see, then report back.",
		"turnin_text": "So it's true. Keep this wardstone close — you'll need it out there.",
	},
}

# Runtime, normalised definitions: id -> def (always has a "steps" array).
var _defs := {}
# id -> {"status": String, "step": int, "progress": int}
var _state := {}
# discovered landmark names (for the one-time discovery toast).
var _discovered := {}


func _ready() -> void:
	for id in QUESTS:
		_defs[id] = _normalize(QUESTS[id])
	for id in NPCs.quest_defs():
		_defs[id] = _normalize(NPCs.quest_defs()[id])
	for id in _defs:
		_state[id] = {"status": "available", "step": 0, "progress": 0}
	_restore()


## Copy a def and guarantee a "steps" array (converting a single "objective" form).
func _normalize(def: Dictionary) -> Dictionary:
	var d := def.duplicate(true)
	if not d.has("steps"):
		d["steps"] = [d.get("objective", {"type": "none", "count": 1})]
	if not d.has("no_death"):
		d["no_death"] = false
	return d


# --- Event hooks -------------------------------------------------------------

func notify_enemy_killed(enemy_type: String) -> void:
	for id in _state:
		if _state[id]["status"] != "active":
			continue
		var step := _cur_step(id)
		if step.get("type", "") == "kill" and step.get("target", "") == enemy_type:
			_progress(id, 1)


func notify_item_collected(_item_name: String) -> void:
	pass  # hook for future collect-objectives


## Called repeatedly while the player stands at a landmark. First arrival => discovery
## toast; also satisfies a current "reach" step pointing here.
func notify_location_reached(location_name: String) -> void:
	if not _discovered.has(location_name):
		_discovered[location_name] = true
		emit_signal("toast", "Discovered: " + location_name)
		_persist()
	for id in _state:
		if _state[id]["status"] != "active":
			continue
		var step := _cur_step(id)
		if step.get("type", "") == "reach" and step.get("target", "") == location_name:
			_progress(id, int(step.get("count", 1)))


## The player died. Any active quest that forbids death is reset to the start.
func notify_player_died() -> void:
	var changed := false
	for id in _state:
		if _state[id]["status"] == "active" and bool(_defs[id]["no_death"]):
			_state[id] = {"status": "available", "step": 0, "progress": 0}
			emit_signal("toast", "Quest failed (you died): " + str(_defs[id]["title"]))
			emit_signal("quest_updated", id)
			changed = true
	if changed:
		_persist()


# --- Quest-giver interaction -------------------------------------------------

## Offer / remind / turn-in for the quest belonging to `giver_id`. Returns dialogue.
func talk_to(giver_id: String, player) -> String:
	var ready_id := _first_for_giver(giver_id, "ready")
	if ready_id != "":
		_grant_rewards(ready_id, player)
		_state[ready_id]["status"] = "done"
		_persist()
		emit_signal("quest_completed", ready_id)
		emit_signal("toast", "Quest complete: " + str(_defs[ready_id]["title"]))
		return str(_defs[ready_id].get("turnin_text", "Well done."))

	var active_id := _first_for_giver(giver_id, "active")
	if active_id != "":
		return "Still going? " + current_step_text(active_id)

	var avail_id := _first_for_giver(giver_id, "available")
	if avail_id != "":
		_state[avail_id]["status"] = "active"
		_persist()
		emit_signal("quest_started", avail_id)
		emit_signal("toast", "Quest accepted: " + str(_defs[avail_id]["title"]))
		return str(_defs[avail_id].get("offer_text", "Help me with this."))

	return "Thank you for your help, wizard."


# --- Queries (UI) ------------------------------------------------------------

func status_of(quest_id: String) -> String:
	return str(_state.get(quest_id, {}).get("status", "available"))


## Ids of quests currently active or ready to hand in (for the journal/banner).
func tracked_ids() -> Array:
	var out: Array = []
	for id in _state:
		if _state[id]["status"] in ["active", "ready"]:
			out.append(id)
	return out


func title_of(quest_id: String) -> String:
	return str(_defs.get(quest_id, {}).get("title", "Quest"))


## Short "what to do right now" line for a quest's current step.
func current_step_text(quest_id: String) -> String:
	if status_of(quest_id) == "ready":
		return "Return to the quest giver"
	var step := _cur_step(quest_id)
	return _step_text(step, _state[quest_id]["progress"])


## Backward-compatible single-line objective for the HUD (first tracked quest).
func get_active_objective_text() -> String:
	for id in _state:
		if _state[id]["status"] == "ready":
			return title_of(id) + ": return to the quest giver"
	for id in _state:
		if _state[id]["status"] == "active":
			return title_of(id) + " — " + current_step_text(id)
	return ""


## Human-readable summary of a quest's rewards (e.g. "40 gold, Warden's Helm").
func reward_text(quest_id: String) -> String:
	var rw: Dictionary = _defs.get(quest_id, {}).get("rewards", {})
	var parts: Array = []
	if rw.has("coins"): parts.append("%d gold" % int(rw["coins"]))
	if rw.has("gear"): parts.append(str(rw["gear"].get("name", "gear")))
	if rw.has("spell"): parts.append("the %s spell" % str(rw["spell"]).replace("_", " "))
	return ", ".join(parts) if not parts.is_empty() else "my thanks"


## Full multi-line detail for the quest-log popup.
func detail_lines(quest_id: String) -> Array:
	var def: Dictionary = _defs.get(quest_id, {})
	if def.is_empty():
		return []
	var lines: Array = [str(def["title"])]
	if def.get("no_death", false):
		lines.append("⚠ Must be completed WITHOUT dying")
	var steps: Array = def["steps"]
	var cur: int = _state[quest_id]["step"]
	var done := status_of(quest_id) == "ready" or status_of(quest_id) == "done"
	for i in range(steps.size()):
		var mark := "•"
		if done or i < cur:
			mark = "✔"
		elif i == cur:
			mark = "▶"
		lines.append("%s %s" % [mark, _step_text(steps[i], _state[quest_id]["progress"] if i == cur else 0)])
	var rw: Dictionary = def.get("rewards", {})
	var rparts: Array = []
	if rw.has("coins"): rparts.append("%d gold" % int(rw["coins"]))
	if rw.has("gear"): rparts.append(str(rw["gear"].get("name", "gear")))
	if rw.has("spell"): rparts.append("spell: " + str(rw["spell"]))
	if not rparts.is_empty():
		lines.append("Reward: " + ", ".join(rparts))
	return lines


# --- Internals ---------------------------------------------------------------

func _cur_step(quest_id: String) -> Dictionary:
	var steps: Array = _defs[quest_id]["steps"]
	var i: int = _state[quest_id]["step"]
	return steps[i] if i < steps.size() else {}


func _step_text(step: Dictionary, prog: int) -> String:
	match str(step.get("type", "")):
		"kill":
			return "Slay %ss  (%d / %d)" % [step.get("target", "enemy"), prog, int(step.get("count", 1))]
		"reach":
			return "Travel to %s" % step.get("target", "the marker")
		_:
			return "Complete the objective"


## Add progress to the current step; roll over to the next step or mark ready.
func _progress(quest_id: String, amount: int) -> void:
	var st: Dictionary = _state[quest_id]
	var step := _cur_step(quest_id)
	st["progress"] = int(st["progress"]) + amount
	if st["progress"] >= int(step.get("count", 1)):
		st["step"] = int(st["step"]) + 1
		st["progress"] = 0
		var steps: Array = _defs[quest_id]["steps"]
		if st["step"] >= steps.size():
			st["status"] = "ready"
			emit_signal("toast", str(_defs[quest_id]["title"]) + " — done! Return to the quest giver.")
		else:
			emit_signal("toast", str(_defs[quest_id]["title"]) + " — next: " + current_step_text(quest_id))
	emit_signal("quest_updated", quest_id)
	_persist()


func _grant_rewards(quest_id: String, player) -> void:
	var rewards: Dictionary = _defs[quest_id].get("rewards", {})
	var lines: Array = []
	if rewards.has("coins") and player.has_method("add_coins"):
		player.add_coins(int(rewards["coins"]))
		lines.append("%d gold" % int(rewards["coins"]))
	if rewards.has("gear") and player.has_method("add_item"):
		var gear: Dictionary = rewards["gear"]
		player.add_item(gear)
		if gear.get("slot", "") != "" and player.has_method("equip"):
			player.equip(gear)
		lines.append(str(gear.get("name", "gear")))
	if rewards.has("spell") and player.has_method("learn_spell"):
		if player.learn_spell(str(rewards["spell"])):
			lines.append("spell: " + str(rewards["spell"]))
	if not lines.is_empty():
		emit_signal("toast", "Reward: " + ", ".join(lines))


func _first_for_giver(giver_id: String, status: String) -> String:
	for id in _state:
		if str(_defs[id].get("giver", "")) == giver_id and _state[id]["status"] == status:
			return id
	return ""


# --- Persistence -------------------------------------------------------------

func _persist() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for id in _state:
		cfg.set_value("quests", id + "_status", _state[id]["status"])
		cfg.set_value("quests", id + "_step", _state[id]["step"])
		cfg.set_value("quests", id + "_progress", _state[id]["progress"])
	cfg.set_value("exploration", "discovered", _discovered.keys())
	cfg.save(SAVE_PATH)


func _restore() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for id in _state:
		_state[id]["status"] = str(cfg.get_value("quests", id + "_status", _state[id]["status"]))
		_state[id]["step"] = int(cfg.get_value("quests", id + "_step", _state[id]["step"]))
		_state[id]["progress"] = int(cfg.get_value("quests", id + "_progress", _state[id]["progress"]))
	for n in cfg.get_value("exploration", "discovered", []):
		_discovered[str(n)] = true
