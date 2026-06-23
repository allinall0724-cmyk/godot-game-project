extends Area3D
## A temporary teleport portal (placed in pairs by the Portal spell). When a body
## (the player or an enemy) steps into one, it is moved to its linked partner. A
## short post-teleport cooldown on BOTH ends prevents instant ping-ponging. Each
## portal fades on its own `_life` timer, consistent with other temporary structures.
##
## Built code-only: a flat glowing ground ring + a thin light column so it reads from
## a distance, with a gentle swirl. No imported assets.

var link: Area3D = null     # the partner portal this one teleports into
var _cd := 0.0              # post-teleport lockout (seconds)
var _life := 0.0           # remaining lifetime; <= 0 with _life==0 means "not counting yet"


## col tints the portal; life is how long it lasts (0 = don't count down yet, set on link).
func setup(col: Color, life: float) -> void:
	_life = life
	collision_layer = 0
	collision_mask = 0xFFFFFFFF  # detect any physics body that walks in
	monitoring = true
	monitorable = false

	var shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.1
	shape.shape = sp
	shape.position = Vector3.UP * 0.6
	add_child(shape)

	# Flat ground ring.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.1
	ring.mesh = torus
	ring.material_override = _emissive(col, 4.0)
	add_child(ring)

	# Swirling inner surface.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.85
	cyl.height = 0.04
	disc.mesh = cyl
	disc.material_override = _emissive(col.lightened(0.25), 2.2)
	add_child(disc)

	# Light column so the portal is visible from afar.
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.18
	bc.bottom_radius = 0.5
	bc.height = 4.0
	beam.mesh = bc
	beam.position = Vector3.UP * 2.0
	var bmat := _emissive(col, 2.5)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(col.r, col.g, col.b, 0.25)
	beam.material_override = bmat
	add_child(beam)

	var glow := OmniLight3D.new()
	glow.light_color = col
	glow.light_energy = 2.0
	glow.omni_range = 4.0
	glow.position = Vector3.UP * 0.6
	add_child(glow)

	body_entered.connect(_on_body_entered)


func _emissive(col: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	return mat


func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd -= delta
	rotation.y += delta * 1.6  # gentle swirl
	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			queue_free()


func _on_body_entered(body: Node) -> void:
	if _cd > 0.0 or link == null or not is_instance_valid(link):
		return
	# Only living things travel — ignore terrain/props/projectiles.
	if not (body.is_in_group("local_player") or body.is_in_group("enemies")):
		return
	# Lock both ends briefly so the arrival doesn't immediately send them back.
	_cd = 0.7
	link._cd = 0.7
	body.global_position = link.global_position + Vector3.UP * 0.4
	if "velocity" in body:
		body.velocity = Vector3.ZERO
