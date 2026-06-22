extends CharacterBody3D
## Friendly villager NPC. Wanders gently near the village. No health and no
## "take_damage" method, so the player's staff can't hurt it — this is what keeps
## villagers distinct from the hostile goblins/orcs (which ARE damageable).

const WANDER_SPEED := 0.8
const GRAVITY := 22.0

@onready var humanoid = $Humanoid

var _wander_dir := Vector3.ZERO
var _wander_timer := 0.0


func _ready() -> void:
	add_to_group("villagers")
	humanoid.hair_style = randi() % 3  # vary appearance between villagers
	_pick_new_wander()


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
