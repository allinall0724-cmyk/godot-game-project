extends CharacterBody3D
## A simple sailable ship. Uses the SAME camera-relative WASD scheme as the player
## (per GAME_DESIGN.md "Resolved Decisions"), but with a heavier boat feel:
## higher top speed, slower acceleration, and the hull turns toward its travel
## direction instead of snapping. Stays on the flat water plane (no buoyancy yet).
##
## Boarding: Main toggles set_active() when the player presses E inside BoardArea.

const MAX_SPEED := 10.0
const ACCELERATION := 3.5     # slow to build up -> "weighty" boat feel
const FRICTION := 1.5         # coasts for a while when you let go
const TURN_RESPONSE := 2.0    # how quickly the hull rotates to face travel

@onready var board_area: Area3D = $BoardArea

var camera = null
var active := false
var player_in_range := false


func _ready() -> void:
	board_area.body_entered.connect(_on_board_body_entered)
	board_area.body_exited.connect(_on_board_body_exited)


func set_camera(c: Node3D) -> void:
	camera = c


func set_active(value: bool) -> void:
	active = value


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if active:
		# Same convention as the player: move_forward is the positive_y action.
		input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")

	var move_dir := Vector3.ZERO
	if camera != null and input_dir.length() > 0.01:
		var forward: Vector3 = camera.get_forward_direction()
		var right: Vector3 = camera.get_right_direction()
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		# Same convention as the player controller (strafe term negated to match A/D).
		move_dir = (forward * input_dir.y - right * input_dir.x).normalized()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if move_dir.length() > 0.01:
		horizontal = horizontal.lerp(move_dir * MAX_SPEED, ACCELERATION * delta)
	else:
		horizontal = horizontal.lerp(Vector3.ZERO, FRICTION * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0  # locked to the water surface (no buoyancy/waves yet)
	move_and_slide()

	# Turn the hull to face travel direction. Velocity changes slowly (low accel),
	# so pointing at the velocity vector reads as a smooth, weighty turn.
	var flat_v := Vector3(velocity.x, 0.0, velocity.z)
	if flat_v.length() > 0.4:
		var target := global_position + flat_v
		# Smoothly interpolate toward facing the travel direction.
		var current_forward := -global_transform.basis.z
		var desired_forward := flat_v.normalized()
		var blended := current_forward.lerp(desired_forward, clamp(TURN_RESPONSE * delta, 0.0, 1.0))
		if blended.length() > 0.01:
			look_at(global_position + blended, Vector3.UP)


func _on_board_body_entered(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = true


func _on_board_body_exited(body: Node3D) -> void:
	if body.is_in_group("local_player"):
		player_in_range = false
