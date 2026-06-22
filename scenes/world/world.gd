extends Node3D
## World setup: water plane, islands, lighting, environment.
##
## Static geometry only — gameplay actors (player, ship, enemies) live in Main.
##
## To add another island later, follow the pattern under the "Islands" node:
##   1. Add a StaticBody3D named "IslandN" under Islands.
##   2. Give it a MeshInstance3D (CylinderMesh) + a CollisionShape3D (CylinderShape3D)
##      with matching radius/height, positioned so the top sits just above y=0.
##   3. Move it somewhere out on the water. That's it — no code changes needed.

func _ready() -> void:
	pass
