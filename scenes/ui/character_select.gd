extends CanvasLayer
class_name CharacterSelect
## Launch screen: pick a starting character. Each option previews live on the
## actual player model standing in the world (which also slowly turns so you can
## see it from all sides). Emits `chosen` with the selected preset dict.
##
## Built entirely in code so there's no .tscn to keep in sync — Main just does:
##   var sel := CharacterSelect.new(); add_child(sel); sel.setup(humanoid)
##   sel.chosen.connect(...)

signal chosen(preset: Dictionary)

const SPIN_SPEED := 0.6   # rad/sec turntable rotation of the preview model

var _preview = null             # the live Humanoid we restyle as a preview (untyped:
                                # we call its custom apply_appearance() dynamically)
var _blurb: Label = null
var _selected := 0


func setup(humanoid) -> void:
	_preview = humanoid


func _ready() -> void:
	layer = 10
	_build_ui()
	# Show the first option immediately so the player isn't a blank default.
	_preview_index(0)


func _process(delta: float) -> void:
	if _preview != null:
		var r: Vector3 = _preview.rotation
		r.y += SPIN_SPEED * delta
		_preview.rotation = r


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	var title := Label.new()
	title.text = "Choose your character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	for i in range(CharacterPresets.PRESETS.size()):
		var preset: Dictionary = CharacterPresets.PRESETS[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 64)
		btn.text = str(preset.get("name", "?"))
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 20)
		# Hover OR keyboard-focus previews; click confirms.
		btn.mouse_entered.connect(_preview_index.bind(i))
		btn.focus_entered.connect(_preview_index.bind(i))
		btn.pressed.connect(_confirm_index.bind(i))
		row.add_child(btn)
		if i == 0:
			btn.grab_focus.call_deferred()

	_blurb = Label.new()
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.add_theme_font_size_override("font_size", 18)
	col.add_child(_blurb)

	var hint := Label.new()
	hint.text = "Hover to preview  •  click to begin"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)


## Restyle the live player model to option `i` (used for hover/focus previews).
func _preview_index(i: int) -> void:
	_selected = i
	var preset: Dictionary = CharacterPresets.PRESETS[i]
	if _preview != null and _preview.has_method("apply_appearance"):
		_preview.apply_appearance(preset)
	if _blurb != null:
		_blurb.text = "%s — %s" % [str(preset.get("name", "?")), str(preset.get("blurb", ""))]


func _confirm_index(i: int) -> void:
	var preset: Dictionary = CharacterPresets.PRESETS[i]
	# Face forward again before handing control back to gameplay.
	if _preview != null:
		_preview.rotation = Vector3.ZERO
	chosen.emit(preset)
