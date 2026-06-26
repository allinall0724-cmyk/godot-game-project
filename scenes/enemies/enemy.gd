extends CharacterBody3D
## Hostile enemy (goblin / orc) for the wizard combat loop.
##  - Wanders gently until the player comes within detect_range.
##  - Then chases, and when in attack_range lunges in for a melee hit on a cooldown.
##  - take_damage() is what the player's staff hitbox + spells call; dies at 0 HP.
##
## Goblin vs Orc is just tuning: the base scene (enemy.tscn) is a fast, weak GOBLIN;
## the Orc instance in node_3d.tscn overrides these exports to be a slower, tankier,
## harder-hitting brute. Drop more instances in the scene tree to add enemies.

@export var max_health := 30       # hits to defeat
@export var wander_speed := 1.2
@export var chase_speed := 2.8     # speed while pursuing the player
@export var detect_range := 13.0   # starts chasing within this distance
@export var attack_range := 1.9    # lunges in to hit within this distance
@export var attack_damage := 8
@export var attack_cooldown := 1.2 # seconds between hits
@export var xp_reward := 6          # XP granted to the player on death (orcs override higher)

const GRAVITY := 22.0

var health := 0
var _attack_cd := 0.0
var _wander_dir := Vector3.ZERO
var _wander_timer := 0.0
var _knockback := Vector3.ZERO
var _launch := 0.0  # pending upward launch from an upward melee swing

# Status effects (applied by debuff / curse / zone spells).
var _slow_factor := 1.0   # speed multiplier (1 = normal)
var _slow_time := 0.0
var _root_time := 0.0     # frozen: can't move or attack (also used as "stun")
var _fear_time := 0.0     # flees from the player
var _dot_dps := 0.0       # damage-over-time (curses, scorched earth, poison...)
var _dot_time := 0.0
var _dot_tick := 0.0
# Newer statuses (added with the expanded spellbook).
var _vuln_factor := 1.0   # incoming-damage multiplier (>1 = armor shredded)
var _vuln_time := 0.0
var _weak_factor := 1.0   # outgoing-damage multiplier (<1 = weakened, Eclipse)
var _weak_time := 0.0
var _sleep_time := 0.0    # asleep: frozen like root, but wakes when damaged
var _charm_time := 0.0    # charmed: fights OTHER enemies instead of the player
var _poly_time := 0.0     # polymorphed: shrunk, harmless, can only wander
var _link_peers: Array = [] # Soul Chains: share a fraction of damage with these
var _link_share := 0.0
var _link_time := 0.0
var _in_link_echo := false  # guard so linked damage doesn't ping-pong forever

@onready var humanoid = $Humanoid


## Debuff hooks called by spells (and the Frost Bolt projectile).
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = clampf(factor, 0.1, 1.0)
	_slow_time = maxf(_slow_time, duration)

func apply_root(duration: float) -> void:
	_root_time = maxf(_root_time, duration)

func apply_fear(duration: float) -> void:
	_fear_time = maxf(_fear_time, duration)

## Lingering damage over time (curses / DoT zones). Refreshes to the stronger one.
func apply_dot(dps: float, duration: float) -> void:
	_dot_dps = maxf(_dot_dps, dps)
	_dot_time = maxf(_dot_time, duration)

## Armor-shred: take extra damage for a while (Acid Spray / Corrosive effects).
func apply_vulnerable(factor: float, duration: float) -> void:
	_vuln_factor = maxf(_vuln_factor, factor)
	_vuln_time = maxf(_vuln_time, duration)

## Weaken: deal less melee damage for a while (Eclipse).
func apply_weaken(factor: float, duration: float) -> void:
	_weak_factor = minf(_weak_factor, clampf(factor, 0.1, 1.0))
	_weak_time = maxf(_weak_time, duration)

## Sleep: frozen until damaged (Lullaby).
func apply_sleep(duration: float) -> void:
	_sleep_time = maxf(_sleep_time, duration)

## Charm: turn against other enemies for a while (Charm / Confusion).
func apply_charm(duration: float) -> void:
	_charm_time = maxf(_charm_time, duration)

## Polymorph: shrink to a harmless critter that can only wander (Polymorph).
func apply_polymorph(duration: float) -> void:
	var was_poly := _poly_time > 0.0
	_poly_time = maxf(_poly_time, duration)
	if not was_poly:
		var tw := create_tween()
		tw.tween_property(humanoid, "scale", Vector3.ONE * 0.5, 0.2)

## Soul Chains: share a fraction of any damage taken with `peers`.
func set_links(peers: Array, share: float, duration: float) -> void:
	_link_peers = peers
	_link_share = share
	_link_time = duration


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_pick_new_wander()


## Pushed by wind spells / directional melee. Horizontal part decays; a positive
## y component launches the enemy upward once.
func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	if impulse.y > 0.0:
		_launch = maxf(_launch, impulse.y)


## Called by the player's attack hitbox / spells. amount is how much health to remove.
## `from_link` marks damage echoed from a Soul-Chains peer (so it doesn't echo again).
func take_damage(amount: int, from_link: bool = false) -> void:
	if _vuln_time > 0.0:
		amount = maxi(1, int(round(float(amount) * _vuln_factor)))  # armor shredded
	_sleep_time = 0.0  # any hit wakes a sleeping enemy
	health -= amount
	DamageNumber.spawn(get_tree().current_scene, global_position + Vector3.UP * 1.1, amount)
	_flash()
	# Soul Chains: bleed a share of this hit to linked peers (once, no ping-pong).
	if _link_time > 0.0 and _link_share > 0.0 and not from_link and not _in_link_echo:
		var share := int(round(float(amount) * _link_share))
		if share > 0:
			_in_link_echo = true
			for p in _link_peers:
				if is_instance_valid(p) and p != self and p.has_method("take_damage"):
					p.take_damage(share, true)
			_in_link_echo = false
	if health <= 0:
		_die()


func _die() -> void:
	# Reward the player with XP toward their next level (+ feed Soul Harvest).
	var player = get_tree().get_first_node_in_group("local_player")
	if player != null:
		if player.has_method("gain_xp"):
			player.gain_xp(xp_reward)
		if player.has_method("on_enemy_killed"):
			player.on_enemy_killed(global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	if _attack_cd > 0.0:
		_attack_cd -= delta

	# Tick status timers.
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
	if _root_time > 0.0:
		_root_time -= delta
	if _fear_time > 0.0:
		_fear_time -= delta
	if _sleep_time > 0.0:
		_sleep_time -= delta
	if _charm_time > 0.0:
		_charm_time -= delta
	if _vuln_time > 0.0:
		_vuln_time -= delta
		if _vuln_time <= 0.0:
			_vuln_factor = 1.0
	if _weak_time > 0.0:
		_weak_time -= delta
		if _weak_time <= 0.0:
			_weak_factor = 1.0
	if _link_time > 0.0:
		_link_time -= delta
	if _poly_time > 0.0:
		_poly_time -= delta
		if _poly_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(humanoid, "scale", Vector3.ONE, 0.2)  # un-shrink
	if _dot_time > 0.0:
		_dot_time -= delta
		_dot_tick -= delta
		if _dot_tick <= 0.0:
			_dot_tick = 0.5
			take_damage(maxi(1, int(round(_dot_dps * 0.5))))
			if health <= 0:
				return

	# Vertical motion (gravity + one-frame upward launch).
	if _launch > 0.0:
		velocity.y = _launch
		_launch = 0.0
	elif is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	# Pick a target: a decoy distracts first; otherwise the player (unless stealthed).
	var desired := Vector3.ZERO
	var facing := Vector3.ZERO
	var target = _find_target()
	var to_target := Vector3.ZERO
	if target != null:
		to_target = target.global_position - global_position
		to_target.y = 0.0

	if _root_time > 0.0 or _sleep_time > 0.0:
		# Frozen/stunned/asleep — no movement, no attacks.
		desired = Vector3.ZERO
		facing = to_target
	elif _poly_time > 0.0:
		# Polymorphed: a harmless critter that can only wander.
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_new_wander()
		desired = _wander_dir * wander_speed
		facing = desired
	elif _fear_time > 0.0 and target != null:
		desired = -to_target.normalized() * chase_speed   # flee
		facing = desired
	elif target != null:
		facing = to_target
		if to_target.length() > attack_range:
			desired = to_target.normalized() * chase_speed  # pursue
		else:
			_try_attack(target, to_target)                  # strike
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_new_wander()
		desired = _wander_dir * wander_speed
		facing = desired

	desired *= _slow_factor  # debuff slow
	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	_knockback = _knockback.lerp(Vector3.ZERO, clampf(delta * 5.0, 0.0, 1.0))
	move_and_slide()

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	humanoid.move_speed = flat.length()
	if facing.length() > 0.1:
		look_at(global_position + Vector3(facing.x, 0.0, facing.z), Vector3.UP)


## Find who to attack: a decoy in range distracts first; otherwise the player
## (unless they are stealthed). Returns null if nothing is targetable.
func _find_target():
	# Charmed/confused: attack the nearest OTHER enemy instead of the player.
	if _charm_time > 0.0:
		return _nearest_other_enemy()
	var decoy = _nearest_in_group("decoys")
	if decoy != null and global_position.distance_to(decoy.global_position) < detect_range:
		return decoy
	var player = get_tree().get_first_node_in_group("local_player")
	if player != null and global_position.distance_to(player.global_position) < detect_range:
		if player.has_method("is_stealthed") and player.is_stealthed():
			return null
		return player
	return null


func _nearest_in_group(group: String):
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## Nearest enemy that isn't us (target for charmed/confused enemies).
func _nearest_other_enemy():
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Lunge in and hit the target, then go on cooldown. If the target is countering,
## WE take the hit instead (Counter Ward).
func _try_attack(target, to_target: Vector3) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown
	humanoid.play_attack()  # visible swing
	if to_target.length() > 0.01:
		_knockback += to_target.normalized() * 2.5  # small forward lunge
	if target.has_method("is_countering") and target.is_countering():
		if target.has_method("counter_hit"):
			target.counter_hit(self)
		return
	if target.has_method("take_damage"):
		var dmg := attack_damage
		if _weak_time > 0.0:
			dmg = maxi(1, int(round(float(dmg) * _weak_factor)))  # Eclipse weaken
		target.take_damage(dmg)


func _pick_new_wander() -> void:
	_wander_timer = randf_range(2.0, 4.0)
	if randf() < 0.4:
		_wander_dir = Vector3.ZERO  # sometimes just stand still
	else:
		var angle := randf() * TAU
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle))


## Quick "I got hit" feedback: a brief scale punch. Skipped while polymorphed so
## it doesn't fight the shrink tween.
func _flash() -> void:
	if _poly_time > 0.0:
		return
	var visual: Node3D = $Humanoid
	visual.scale = Vector3.ONE * 1.25
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, 0.15)
