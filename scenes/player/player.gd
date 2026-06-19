extends CharacterBody3D
## Third-person player controller with basic movement and gravity.
## 
## Controls:
##   - WASD: Move forward/back/strafe left/right (relative to camera direction)
##   - Mouse: Look around (pitch and yaw the camera)
##   - Space: (reserved for jump in future)
##
## This script handles:
##   1. Physics: gravity, grounding, collision
##   2. Input: WASD movement, feeding camera input to camera_controller
##   3. Animation state: standing/walking (for future animation)

# Physics constants
const MOVE_SPEED = 5.0  # m/s walking speed
const ACCELERATION = 15.0  # How quickly we ramp up to max speed
const FRICTION = 10.0  # How quickly we slow down when not moving
const GRAVITY = -9.8  # m/s^2

# References
@onready var camera_controller: Node3D = $CameraController
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Current state
var current_velocity: Vector3 = Vector3.ZERO
var is_moving: bool = false


func _ready() -> void:
	# Ensure camera controller is present
	if not camera_controller:
		push_error("Player: CameraController not found! Make sure it's a child node.")


func _physics_process(delta: float) -> void:
	# Apply gravity
	current_velocity.y += GRAVITY * delta
	
	# Get movement input relative to camera direction
	var move_input = _get_movement_input()
	var desired_velocity = move_input * MOVE_SPEED
	
	# Apply acceleration/friction on horizontal plane (XZ)
	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	var desired_horizontal = Vector3(desired_velocity.x, 0, desired_velocity.z)
	
	if desired_horizontal.length() > 0.01:
		# Accelerate toward desired direction
		horizontal_velocity = horizontal_velocity.lerp(desired_horizontal, ACCELERATION * delta)
		is_moving = true
	else:
		# Decelerate when no input
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, FRICTION * delta)
		is_moving = false
	
	# Reconstruct velocity with updated horizontal components
	current_velocity.x = horizontal_velocity.x
	current_velocity.z = horizontal_velocity.z
	
	# Use Godot's move_and_slide for physics
	velocity = current_velocity
	move_and_slide()
	
	# Update the actual velocity after collision resolution
	current_velocity = velocity


func _input(event: InputEvent) -> void:
	# Delegate mouse input to camera controller
	if event is InputEventMouseMotion:
		if camera_controller:
			camera_controller._on_mouse_motion(event)


func _get_movement_input() -> Vector3:
	"""
	Get WASD input and convert it to world-space movement relative to camera direction.
	
	This ensures movement feels natural: pressing W always moves forward (relative to
	where the camera is looking), not toward a fixed world axis.
	"""
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Get camera's forward and right vectors (ignoring vertical look angle for XZ movement)
	var camera_forward = camera_controller.get_forward_direction()
	var camera_right = camera_controller.get_right_direction()
	
	# Flatten to XZ plane so vertical look doesn't tilt movement
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	# Combine inputs into world-space movement
	var move_direction = (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()
	
	return move_direction


func reset_velocity_vertical() -> void:
	"""Hard-reset vertical velocity (for jumps, knockback, etc. in future)."""
	current_velocity.y = 0.0
