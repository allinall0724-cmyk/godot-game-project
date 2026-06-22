extends Label3D
class_name DamageNumber
## A brief floating "-N" number that rises and fades above a character when it
## takes damage, then frees itself. Code-only (Label3D, no textures).

const SCENE_PATH := "res://scenes/ui/damage_number.tscn"


## Spawn a damage number at a world position under `world_parent`.
static func spawn(world_parent: Node, world_position: Vector3, amount: int) -> void:
	if world_parent == null:
		return
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		return
	var n: Label3D = packed.instantiate()
	n.text = "-%d" % amount
	world_parent.add_child(n)
	n.global_position = world_position

	var tween := n.create_tween().set_parallel(true)
	tween.tween_property(n, "global_position:y", world_position.y + 1.2, 0.8)
	tween.tween_property(n, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(n.queue_free)
