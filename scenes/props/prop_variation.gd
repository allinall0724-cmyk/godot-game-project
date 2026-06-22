extends StaticBody3D
## Gives a scattered prop (tree, rock, ...) a slightly randomized rotation/scale on
## spawn so repeated instances don't look identical. Origin is at the prop's base,
## so scaling keeps it sitting on the ground.

@export var min_scale := 0.85
@export var max_scale := 1.30
@export var non_uniform := false   # rocks look more natural with per-axis scaling


func _ready() -> void:
	rotation.y = randf() * TAU
	if non_uniform:
		scale = Vector3(
			randf_range(min_scale, max_scale),
			randf_range(min_scale, max_scale),
			randf_range(min_scale, max_scale))
	else:
		var s := randf_range(min_scale, max_scale)
		scale = Vector3(s, s, s)
