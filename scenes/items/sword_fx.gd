extends Node3D
## Spins (and gently bobs) its child "spark" primitives around their parent so a
## weapon/orb has small orbiting particles (e.g. the staff's arcane orb).
## Code-only, no GPU particles.

@export var spin_speed := 3.5
@export var bob_amount := 0.04

var _base_y := 0.0
var _t := 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_t += delta
	rotation.y += spin_speed * delta
	position.y = _base_y + sin(_t * 4.0) * bob_amount
