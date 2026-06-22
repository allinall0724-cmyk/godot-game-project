extends Node
## Minimal dedicated-server-style networking using Godot's high-level multiplayer
## API + ENetMultiplayerPeer (per GAME_DESIGN.md Technical Notes).
##
## One instance hosts (it IS the authoritative server). Others join as clients.
## The server spawns one player_avatar per connected peer under RemotePlayers; a
## MultiplayerSpawner replicates those spawns to every client (including late
## joiners). Each avatar mirrors the movement of its owner's local player.
##
## Scope: presence/movement only. No trading, PvP, or weapon-cap logic yet.

signal status(text: String)

const PORT := 24545
const MAX_CLIENTS := 8
const AVATAR_SCENE := "res://scenes/net/player_avatar.tscn"

@onready var remote_players: Node = get_node("../RemotePlayers")


## Start hosting. The host is also a player (peer id 1).
func host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status.emit("Host failed (%s)" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_spawn_avatar(multiplayer.get_unique_id())  # the host's own avatar (id 1)
	status.emit("Hosting on port %d — you are the server." % PORT)


## Connect to a host (defaults to localhost for same-PC testing).
func join(address: String = "127.0.0.1") -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		status.emit("Join failed (%s)" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	status.emit("Connecting to %s:%d ..." % [address, PORT])


func _on_peer_connected(id: int) -> void:
	# Only the server owns the spawn list / source of truth.
	if multiplayer.is_server():
		_spawn_avatar(id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		var node := remote_players.get_node_or_null(str(id))
		if node != null:
			node.queue_free()


func _spawn_avatar(id: int) -> void:
	if remote_players.has_node(str(id)):
		return
	var avatar: Node = load(AVATAR_SCENE).instantiate()
	avatar.name = str(id)  # name == peer id; the avatar derives authority from it
	# Added under the MultiplayerSpawner's path -> auto-replicated to all clients.
	remote_players.add_child(avatar, true)
