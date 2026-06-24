extends Control
## On-screen HUD: player health + stamina bars, plus a level/XP bar (top-left) and
## a brief "LEVEL UP!" banner. Reads the local player each frame; no coupling
## beyond the "local_player" group.

@onready var bar: ProgressBar = $HealthBar
@onready var label: Label = $HealthBar/Label
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaBar/Label

var xp_bar: ProgressBar
var xp_label: Label
var banner: Label
var coin_label: Label
var time_label: Label
var _last_level := 1
var _banner_time := 0.0


func _ready() -> void:
	_style_bar(bar, Color(0.85, 0.22, 0.22))
	_style_bar(stamina_bar, Color(0.92, 0.78, 0.2))
	_build_xp_ui()
	_build_banner()
	_build_status()


## Coins + day/night readout, top-right corner.
func _build_status() -> void:
	coin_label = Label.new()
	coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_label.anchor_left = 1.0
	coin_label.anchor_right = 1.0
	coin_label.offset_left = -180.0
	coin_label.offset_top = 212.0   # below the minimap
	coin_label.offset_right = -12.0
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_label.add_theme_font_size_override("font_size", 18)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(coin_label)

	time_label = Label.new()
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	time_label.anchor_left = 1.0
	time_label.anchor_right = 1.0
	time_label.offset_left = -180.0
	time_label.offset_top = 236.0   # below the coins
	time_label.offset_right = -12.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.add_theme_font_size_override("font_size", 15)
	add_child(time_label)


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


## Build the XP bar + level readout just below the stamina bar.
func _build_xp_ui() -> void:
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.position = Vector2(20, 80)
	xp_bar.size = Vector2(260, 16)
	xp_bar.max_value = 100.0
	xp_bar.value = 0.0
	add_child(xp_bar)
	_style_bar(xp_bar, Color(0.55, 0.45, 0.95))

	xp_label = Label.new()
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_bar.add_child(xp_label)


## A big centered "LEVEL UP!" banner, hidden until a level is gained.
func _build_banner() -> void:
	banner = Label.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.offset_top = -80.0  # sit a little above screen centre
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 44)
	banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.add_theme_constant_override("outline_size", 8)
	banner.modulate.a = 0.0
	add_child(banner)


func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	bar.max_value = player.max_health
	bar.value = player.health
	label.text = "HP  %d / %d" % [player.health, player.max_health]

	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	stamina_label.text = "STA  %d / %d" % [int(player.stamina), int(player.max_stamina)]

	# Level / XP.
	var lvl: int = player.level
	var need: int = player.xp_to_next()
	xp_bar.max_value = float(maxi(need, 1))
	xp_bar.value = float(player.xp)
	xp_label.text = "Lv %d    XP %d / %d" % [lvl, player.xp, need]

	# Coins + day/night readout.
	coin_label.text = "Coins: %d" % int(player.coins)
	var world = get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("is_night"):
		if world.is_night():
			time_label.text = "🌙 Night"
			time_label.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
		else:
			time_label.text = "☀ Day"
			time_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))

	# Detect a level-up and flash the banner.
	if lvl > _last_level:
		_show_banner("LEVEL UP!   Lv %d" % lvl)
	_last_level = lvl

	if _banner_time > 0.0:
		_banner_time -= delta
		banner.modulate.a = clampf(_banner_time / 1.6, 0.0, 1.0)
		if _banner_time <= 0.0:
			banner.modulate.a = 0.0


func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	_banner_time = 1.6
