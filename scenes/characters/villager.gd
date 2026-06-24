extends CharacterBody3D
## Friendly villager NPC. Wanders gently near the village. No health and no
## "take_damage" method, so the player's staff can't hurt it — this is what keeps
## villagers distinct from the hostile goblins/orcs (which ARE damageable).
##
## QUESTS + TRADING: each villager offers a "slay N beasts" quest. Once you've
## completed and turned it in, they become a merchant with THREE fixed wares that
## stay on offer until you actually buy them (sold ones stay sold). The trade UI
## (scenes/ui/trade_ui.gd) drives the conversation by calling the methods below.

const WANDER_SPEED := 0.8
const GRAVITY := 22.0

const NAMES := ["Bramble", "Posy", "Cobb", "Hazel", "Tomkin", "Maud", "Edda", "Wat", "Nell"]

@onready var humanoid = $Humanoid

var _wander_dir := Vector3.ZERO
var _wander_timer := 0.0

# Quest + trade state (read/advanced by the trade UI).
var npc_name := "Villager"
var quest_target := 0           # beasts to slay
var quest_accepted := false
var quest_turned_in := false
var _start_kills := 0           # player's kill count when the quest was taken
var offers: Array = []          # [{ item:Dictionary, price:int, sold:bool }]


func _ready() -> void:
	add_to_group("villagers")
	humanoid.hair_style = randi() % 3  # vary appearance between villagers
	npc_name = NAMES[randi() % NAMES.size()]
	quest_target = randi_range(3, 6)
	_build_offers()
	_pick_new_wander()


## Three random wares, priced by tier. Kept until bought (see buy()).
func _build_offers() -> void:
	var pool: Array = ArmorCatalog.all_items()
	pool.shuffle()
	for i in range(3):
		var item: Dictionary = pool[i % pool.size()]
		var tier: int = int(item.get("tier", 1))
		var price := 20 + tier * 18 + randi_range(0, 12)
		offers.append({"item": item, "price": price, "sold": false})


# --- Quest API (called by the trade UI) -------------------------------------

func quest_progress(player) -> int:
	if player == null:
		return 0
	return clampi(player.kills - _start_kills, 0, quest_target)


func quest_complete(player) -> bool:
	return quest_accepted and quest_progress(player) >= quest_target


func accept_quest(player) -> void:
	quest_accepted = true
	_start_kills = (player.kills if player != null else 0)


## Hand in a finished quest; pays a coin reward and unlocks trading. Returns reward.
func turn_in(player) -> int:
	quest_turned_in = true
	var reward := 30 + quest_target * 10
	if player != null and player.has_method("add_coins"):
		player.add_coins(reward)
	return reward


# --- Trade API --------------------------------------------------------------

## Attempt to buy offer `index`. Returns true if the coins were spent and the item
## was handed over. The offer is then marked sold and stays sold.
func buy(index: int, player) -> bool:
	if index < 0 or index >= offers.size():
		return false
	var o: Dictionary = offers[index]
	if o.sold or player == null:
		return false
	if player.has_method("spend_coins") and player.spend_coins(o.price):
		o.sold = true
		if player.has_method("add_item"):
			player.add_item((o.item as Dictionary).duplicate(true))
		return true
	return false


# --- Wandering (unchanged) --------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander()

	velocity.x = _wander_dir.x * WANDER_SPEED
	velocity.z = _wander_dir.z * WANDER_SPEED
	move_and_slide()

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	humanoid.move_speed = flat.length()
	if flat.length() > 0.1:
		look_at(global_position + flat, Vector3.UP)


func _pick_new_wander() -> void:
	_wander_timer = randf_range(2.0, 5.0)
	if randf() < 0.5:
		_wander_dir = Vector3.ZERO  # often just stand around
	else:
		var angle := randf() * TAU
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle))
