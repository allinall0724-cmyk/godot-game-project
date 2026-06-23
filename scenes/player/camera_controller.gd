extends Node3D
## Third-person orbit camera that follows a target node (the player on foot, or
## the ship while sailing). It owns its own mouse-look so any pawn can be followed
## without forwarding input. Swap who it follows with set_target().
##
## Lives in the Main scene (not parented to the player) so that boarding the ship
## is just "change the target", and so a single camera follows the LOCAL player in
## multiplayer.

var sensitivity := 0.005        # mouse look sensitivity (adjustable in Settings)
const FOLLOW_DISTANCE := 4.5    # how far behind the target
const FOLLOW_HEIGHT := 1.6      # how high above the target
const LOOK_AT_HEIGHT := 0.8     # aim point above the target's origin
const PITCH_MIN := -1.2         # ~-69 deg (looking down)
const PITCH_MAX := 0.6          # ~+34 deg (looking up)
const FOLLOW_SMOOTHNESS := 12.0 # higher = snappier
const ZOOM_DISTANCE_MULT := 0.72 # hold RMB: pull in to ~72% distance (modest)
const ZOOM_SMOOTHNESS := 8.0    # how fast the zoom eases in/out
const ZOOM_LOOK_MULT := 0.45    # hold RMB: slower, more precise mouse-look (aim feel)

@onready var camera_3d: Camera3D = $Camera3D

var target: Node3D = null
var pitch := -0.3
var yaw := 0.0
var _base_fov := 75.0
var _dist_mult := 1.0           # current follow-distance multiplier (RMB zoom)


func set_target(new_target: Node3D) -> void:
	target = new_target


## Scope-in for a charged shot (Arc Sniper): narrow the FOV, hold, then restore.
func zoom_charge(hold: float) -> void:
	var tw := create_tween()
	tw.tween_property(camera_3d, "fov", _base_fov * 0.55, 0.16)
	tw.tween_interval(maxf(0.0, hold))
	tw.tween_property(camera_3d, "fov", _base_fov, 0.3)


func _ready() -> void:
	add_to_group("camera_rig")  # so the Settings menu can find us for sensitivity
	_base_fov = camera_3d.fov


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look (only while the mouse is captured)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Holding right-click (zoom) slows the turn rate for precise aiming; the
		# crosshair is unchanged — only the look speed drops.
		var s := sensitivity
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			s *= ZOOM_LOOK_MULT
		yaw -= event.relative.x * s
		pitch -= event.relative.y * s
		pitch = clamp(pitch, PITCH_MIN, PITCH_MAX)


const COLLISION_MARGIN := 0.3   # keep the camera this far in front of a hit surface
const GROUND_CLEARANCE := 0.5   # never let the camera sit closer than this to the ground


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var forward := get_forward_direction()
	# Hold right mouse (while in gameplay) to gently zoom in; release eases back out.
	var want_mult := ZOOM_DISTANCE_MULT if (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) else 1.0
	_dist_mult = lerpf(_dist_mult, want_mult, clamp(ZOOM_SMOOTHNESS * delta, 0.0, 1.0))
	var pivot := target.global_position + Vector3.UP * LOOK_AT_HEIGHT
	var desired := target.global_position - forward * (FOLLOW_DISTANCE * _dist_mult) + Vector3.UP * FOLLOW_HEIGHT
	# Pull the camera in if terrain/props would be between it and the player.
	desired = _avoid_obstacles(pivot, desired)
	# Smoothly glide to the desired position so target swaps aren't jarring.
	global_position = global_position.lerp(desired, clamp(FOLLOW_SMOOTHNESS * delta, 0.0, 1.0))
	# Hard clamp every frame so we never end up under the terrain mid-lerp.
	global_position = _clamp_above_ground(global_position)
	look_at(pivot, Vector3.UP)


## RIDs to ignore in camera raycasts (the followed pawn's own collider).
func _exclude_rids() -> Array[RID]:
	var ex: Array[RID] = []
	if target is CollisionObject3D:
		ex.append(target.get_rid())
	return ex


## If something solid sits between the player (pivot) and the ideal camera spot,
## move the camera to just in front of that surface so it never clips through.
func _avoid_obstacles(pivot: Vector3, desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pivot, desired)
	q.exclude = _exclude_rids()
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		var p: Vector3 = hit["position"]
		var back := (pivot - desired).normalized()
		return p + back * COLLISION_MARGIN
	return desired


## Keep the camera above the ground beneath it (cast straight down through the world).
func _clamp_above_ground(pos: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := Vector3(pos.x, 250.0, pos.z)
	var to := Vector3(pos.x, -60.0, pos.z)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = _exclude_rids()
	var hit := space.intersect_ray(q)
	if hit.has("position"):
		var min_y: float = float(hit["position"].y) + GROUND_CLEARANCE
		if pos.y < min_y:
			pos.y = min_y
	return pos


## Horizontal-aware forward vector used by pawns for camera-relative movement.
func get_forward_direction() -> Vector3:
	return Vector3(sin(yaw), sin(pitch), cos(yaw)).normalized()


## Rightward vector perpendicular to forward (for strafing).
func get_right_direction() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw)).normalized()
