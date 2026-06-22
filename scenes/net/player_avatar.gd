extends Node3D
## Networked stand-in for a player, spawned once per connected peer by the
## MultiplayerSpawner (server-authoritative spawn list).
##
## How presence sync works here:
##   - The node is named after the owning peer id; in _ready we set this node's
##     (and its synchronizer's) multiplayer authority to that id.
##   - On the OWNING peer's machine, this avatar copies that machine's LOCAL player
##     transform every frame, and the MultiplayerSynchronizer replicates position +
##     rotation out to everyone else.
##   - On every OTHER machine, this avatar is remote: it just displays whatever the
##     synchronizer received.
##   - We hide our OWN avatar locally (we already render our real local player), so
##     it only ever represents *other* players on screen.
##
## This is presence/movement only — no combat/trade/weapon sync yet (future phases).

@onready var mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	var id := name.to_int()
	set_multiplayer_authority(id)
	$MultiplayerSynchronizer.set_multiplayer_authority(id)


func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		var local_player := get_tree().get_first_node_in_group("local_player") as Node3D
		if local_player != null:
			global_position = local_player.global_position
			rotation.y = local_player.rotation.y
		# Don't draw our own avatar on our own screen.
		mesh.visible = false
	# Remote avatars keep their mesh visible; transform arrives via the synchronizer.
