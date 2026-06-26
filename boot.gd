extends Control
## Lightweight loading screen — the game's entry scene. It threaded-loads the main
## game scene so the page shows a title + progress bar instead of a frozen canvas,
## then switches to it. Also brackets the CrazyGames "loading" event.
##
## NOTE: the heavy procedural world still generates when the game scene instantiates
## (one brief hitch on the switch). This screen at least gives a clean intro and a
## place to later move generation to a background pass.

const GAME_SCENE := "res://node_3d.tscn"

var _bar: ProgressBar
var _switching := false
var _frames := 0


func _ready() -> void:
	CrazyGames.loading_start()
	_build_ui()
	ResourceLoader.load_threaded_request(GAME_SCENE)


func _process(_delta: float) -> void:
	if _switching:
		return
	_frames += 1
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
	if progress.size() > 0:
		_bar.value = float(progress[0]) * 100.0
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_switching = true
			_bar.value = 100.0
			var packed = ResourceLoader.load_threaded_get(GAME_SCENE)
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# Fall back to a plain (blocking) scene change so the game still starts.
			_switching = true
			get_tree().change_scene_to_file(GAME_SCENE)
		_:
			# Watchdog: if threaded loading stalls (some single-threaded web builds),
			# force a blocking load after ~10s so the game always starts.
			if _frames > 600:
				_switching = true
				get_tree().change_scene_to_file(GAME_SCENE)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "Wizard's Realm"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.38
	title.anchor_bottom = 0.38
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	add_child(title)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(340, 18)
	_bar.set_anchors_preset(Control.PRESET_CENTER)
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.52
	_bar.anchor_bottom = 0.52
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.max_value = 100.0
	add_child(_bar)

	var hint := Label.new()
	hint.text = "Loading…"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 0.58
	hint.anchor_bottom = 0.58
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	add_child(hint)
