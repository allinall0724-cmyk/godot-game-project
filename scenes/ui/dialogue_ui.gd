extends Control
## A little chat box at the bottom of the screen. NPCs call say(speaker, text) to make
## a line appear (speaker name + what they're saying — why they want the quest done,
## what they'll give you, etc.). It fades out on its own after a few seconds, or when
## the next line is said. Purely visual: it doesn't grab the mouse or pause the game.
## In group "dialogue_ui" so any NPC can find it.

const HOLD_BASE := 5.0     # seconds on screen for a short line
const HOLD_PER_CHAR := 0.035

var _panel: PanelContainer
var _name_lbl: Label
var _text_lbl: Label
var _t := 0.0


func _ready() -> void:
	add_to_group("dialogue_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_panel.visible = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -340.0
	_panel.offset_right = 340.0
	_panel.offset_top = -170.0
	_panel.offset_bottom = -88.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.85, 0.78, 0.45, 0.85)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 16)
	_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vb.add_child(_name_lbl)

	_text_lbl = Label.new()
	_text_lbl.add_theme_font_size_override("font_size", 15)
	_text_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.custom_minimum_size = Vector2(640, 0)
	vb.add_child(_text_lbl)


## Show a spoken line. speaker = who's talking, text = what they say.
func say(speaker: String, text: String) -> void:
	_name_lbl.text = speaker
	_text_lbl.text = text
	_panel.visible = true
	_panel.modulate.a = 1.0
	_t = HOLD_BASE + float(text.length()) * HOLD_PER_CHAR


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_t -= delta
	if _t <= 0.0:
		_panel.modulate.a = maxf(0.0, _panel.modulate.a - delta * 2.0)
		if _panel.modulate.a <= 0.0:
			_panel.visible = false
