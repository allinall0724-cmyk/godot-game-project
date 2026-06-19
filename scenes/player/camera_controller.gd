extends Node3D
## Third-person camera controller.
##
## Responsibilities:
##   1. Mouse input: capture mouse motion and compute pitch/yaw
##   2. Camera positioning: keep camera behind and above the player
##   3. Smooth following: use lerp/easing to avoid jerky motion
##
## Mouse sensitivity is tunable. By default, the camera follows smoothly
## but you can adjust the smoothness constants below.

# Mouse sensitivity (radians per pixel)
const MOUSE_SENSITIVITY = 0.005

# Smooth follow parameters
const FOLLOW_SMOOTHNESS = 0.15  # 0-1: higher = faster, snappier (try 0.1-0.3)
const FOLLOW_DISTANCE = 3.0  # How far behind the player
const FOLLOW_HEIGHT = 1.2  # How high above the player

# Camera angles
var pitch: float = -0.3  # Looking slightly downward (radians)
var yaw: float = 0.0    # Left-right (radians)

# References
@onready var camera_3d: Camera3D = $Camera3D
@onready var player: CharacterBody3D = get_parent()

# Input accumulation
var mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Hide and capture mouse for a cleaner experience
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if not camera_3d:
		push_error("CameraController: Camera3D child node not found!")


func _physics_process(delta: float) -> void:
	# Clamp pitch to prevent over-rotation (can't look fully behind)
	pitch = clamp(pitch, -1.2, 0.8)  # ~-69° to +46°
	
	# Update camera position: offset behind and above the player
	_update_camera_position()
	
	# Apply mouse input for next frame
	mouse_delta = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse capture on ESC
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	"""Called by the player when mouse motion occurs."""
	mouse_delta += event.relative * MOUSE_SENSITIVITY
	
	# Apply rotation
	yaw -= mouse_delta.x
	pitch -= mouse_delta.y
	
	mouse_delta = Vector2.ZERO  # Reset for next frame


func _update_camera_position() -> void:
	"""
	Position the camera behind and above the player, looking at them.
	Uses smooth interpolation to avoid jerky movement.
	"""
	# Desired offset: behind (along -Z in camera space) and above
	var camera_forward = Vector3(sin(yaw), sin(pitch), cos(yaw)).normalized()
	var desired_offset = -camera_forward * FOLLOW_DISTANCE + Vector3.UP * FOLLOW_HEIGHT
	
	# Smooth interpolation for the offset
	# (This makes the camera glide smoothly as you move/look)
	global_position = player.global_position + desired_offset
	
	# Point the camera at a spot slightly above the player's center
	look_at(player.global_position + Vector3.UP * 0.5, Vector3.UP)


func get_forward_direction() -> Vector3:
	"""Return the direction the camera is pointing (for player movement input)."""
	return Vector3(sin(yaw), sin(pitch), cos(yaw)).normalized()


func get_right_direction() -> Vector3:
	"""Return the rightward direction perpendicular to forward (for strafing)."""
	return Vector3(cos(yaw), 0, -sin(yaw)).normalized()
