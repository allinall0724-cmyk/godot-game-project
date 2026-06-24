extends Node3D
## World setup + DAY / NIGHT cycle.
##
## Drives the sun (DirectionalLight3D), the sky (ProceduralSkyMaterial) and the
## ambient light over a repeating cycle so the world cycles dawn -> day -> dusk ->
## night. Other systems ask this node `is_night()` (the spawn director makes far
## more monsters at night; see spawn_director.gd).
##
## Tweak DAY_LEN / NIGHT_LEN for cycle length; the colour consts for the mood.

const DAY_LEN := 130.0      # seconds of daylight
const NIGHT_LEN := 90.0     # seconds of night
const CYCLE := DAY_LEN + NIGHT_LEN

const SUN_DAY := Color(1.0, 0.97, 0.9)
const SUN_NIGHT := Color(0.45, 0.55, 0.85)   # cool moonlight
const SKY_TOP_DAY := Color(0.38, 0.6, 0.92)
const SKY_TOP_NIGHT := Color(0.02, 0.03, 0.08)
const SKY_HORIZON_DAY := Color(0.7, 0.8, 0.92)
const SKY_HORIZON_NIGHT := Color(0.05, 0.06, 0.12)

@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _env_node: WorldEnvironment = $WorldEnvironment

var _time := 18.0           # start a little after dawn
var _sky_mat: ProceduralSkyMaterial
var _env: Environment


func _ready() -> void:
	add_to_group("world")
	_env = _env_node.environment
	if _env != null and _env.sky != null:
		_sky_mat = _env.sky.sky_material as ProceduralSkyMaterial
	_apply()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE)
	_apply()


## True for the night half of the cycle.
func is_night() -> bool:
	return _time >= DAY_LEN


## 0 at deep night, 1 at midday — a smooth daylight level for visuals.
func light_level() -> float:
	if _time >= DAY_LEN:
		return 0.0
	var fd := _time / DAY_LEN
	return clampf(sin(fd * PI) * 1.7, 0.0, 1.0)


func _apply() -> void:
	var l := light_level()
	# Sun: bright warm by day, faint blue "moon" by night; arcs across the sky.
	_sun.light_energy = lerpf(0.06, 1.15, l)
	_sun.light_color = SUN_NIGHT.lerp(SUN_DAY, l)
	var pitch := -(12.0 + l * 66.0)                 # higher in the sky at midday
	var yaw := -50.0 + (_time / CYCLE) * 60.0        # slowly swings round
	_sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
	# Ambient + sky darken at night.
	if _env != null:
		_env.ambient_light_energy = lerpf(0.12, 0.6, l)
	if _sky_mat != null:
		_sky_mat.sky_top_color = SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, l)
		_sky_mat.sky_horizon_color = SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_DAY, l)
		_sky_mat.ground_horizon_color = SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_DAY, l)
		_sky_mat.sky_energy_multiplier = lerpf(0.1, 1.0, l)
		_sky_mat.ground_energy_multiplier = lerpf(0.1, 1.0, l)
