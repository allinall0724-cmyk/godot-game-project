extends Control
## On-screen HUD: player health bar + stamina bar (top-left). Reads the local
## player each frame; no coupling beyond the "local_player" group.

@onready var bar: ProgressBar = $HealthBar
@onready var label: Label = $HealthBar/Label
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaBar/Label


func _ready() -> void:
	_style_bar(bar, Color(0.85, 0.22, 0.22))
	_style_bar(stamina_bar, Color(0.92, 0.78, 0.2))


## Give a ProgressBar a clean dark rounded track with a colored fill.
func _style_bar(b: ProgressBar, fill_color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	bg.set_corner_radius_all(5)
	bg.set_border_width_all(1)
	bg.border_color = Color(0, 0, 0, 0.55)
	b.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	b.add_theme_stylebox_override("fill", fill)


func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	bar.max_value = player.max_health
	bar.value = player.health
	label.text = "HP  %d / %d" % [player.health, player.max_health]

	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	stamina_label.text = "STA  %d / %d" % [int(player.stamina), int(player.max_stamina)]
