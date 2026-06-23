extends CanvasLayer
class_name CharacterSelect
## Launch screen: pick a starting character.
##
## Each option is shown as a live 3D PORTRAIT — a small isolated viewport that
## renders that character's head & shoulders (lit, on a turntable). Picking also
## previews on the full-body player model standing in the world. Emits `chosen`
## with the selected preset dict.
##
## Built entirely in code so there's no .tscn to keep in sync — Main just does:
##   var sel := CharacterSelect.new(); sel.setup(humanoid); add_child(sel)
##   sel.chosen.connect(...)

signal chosen(preset: Dictionary)

const HUMANOID_SCENE := preload("res://scenes/characters/humanoid.tscn")
const SPIN_SPEED := 0.6          # rad/sec turntable for the full-body world model
const PORTRAIT_SPIN := 0.5       # rad/sec turntable inside each portrait
const PORTRAIT_SIZE := Vector2i(150, 190)

var _preview = null              # the live full-body Humanoid (untyped: dynamic calls)
var _blurb: Label = null
var _portraits: Array = []       # the per-card portrait model Node3Ds, to spin


func setup(humanoid) -> void:
	_preview = humanoid


func _ready() -> void:
	layer = 10
	_build_ui()
	_preview_index(0)


func _process(delta: float) -> void:
	if _preview != null:
		var r: Vector3 = _preview.rotation
		r.y += SPIN_SPEED * delta
		_preview.rotation = r
	for m in _portraits:
		if is_instance_valid(m):
			var pr: Vector3 = m.rotation
			pr.y += PORTRAIT_SPIN * delta
			m.rotation = pr


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.78)
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
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)

	for i in range(CharacterPresets.PRESETS.size()):
		row.add_child(_build_card(i))
	# Cards (and their portrait models) are now in the tree, so each model's
	# _ready has run — safe to style them.
	for i in range(_portraits.size()):
		var m = _portraits[i]
		if m.has_method("apply_appearance"):
			m.apply_appearance(CharacterPresets.PRESETS[i])

	_blurb = Label.new()
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb.add_theme_font_size_override("font_size", 18)
	col.add_child(_blurb)

	var hint := Label.new()
	hint.text = "Hover to preview  •  click to begin"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	col.add_child(hint)


## One character card: a 3D portrait above a name button. Hovering either (or
## keyboard-focusing the button) previews; clicking the button confirms.
func _build_card(i: int) -> Control:
	var preset: Dictionary = CharacterPresets.PRESETS[i]
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)

	var portrait := _make_portrait()
	portrait.mouse_entered.connect(_preview_index.bind(i))
	card.add_child(portrait)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(PORTRAIT_SIZE.x, 44)
	btn.text = str(preset.get("name", "?"))
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 20)
	btn.mouse_entered.connect(_preview_index.bind(i))
	btn.focus_entered.connect(_preview_index.bind(i))
	btn.pressed.connect(_confirm_index.bind(i))
	card.add_child(btn)
	if i == 0:
		btn.grab_focus.call_deferred()
	return card


## A self-contained 3D portrait: an isolated viewport with its own light, dark
## backdrop, framed camera, and a styled copy of the character model.
func _make_portrait() -> SubViewportContainer:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(PORTRAIT_SIZE)

	var vp := SubViewport.new()
	vp.size = PORTRAIT_SIZE
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(vp)

	var root := Node3D.new()
	vp.add_child(root)

	# Dark studio backdrop + soft ambient so the unlit side isn't pure black.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.74)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# Key + fill lights aimed at the face (the model faces -Z). Orient via pure
	# Transform3D math so it's valid even before the node enters the tree.
	var face := Vector3(0, 0.5, 0)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.transform = Transform3D(Basis(), Vector3(-1.2, 2.2, -2.0)).looking_at(face, Vector3.UP)
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.transform = Transform3D(Basis(), Vector3(1.6, 0.6, -1.8)).looking_at(face, Vector3.UP)
	root.add_child(fill)

	# The character (head & shoulders framed). It's styled by the caller AFTER the
	# card is in the tree (so the model's _ready has run and its nodes exist).
	var model = HUMANOID_SCENE.instantiate()
	root.add_child(model)
	_portraits.append(model)

	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.transform = Transform3D(Basis(), Vector3(0.0, 0.55, -1.15)).looking_at(Vector3(0.0, 0.48, 0.0), Vector3.UP)
	root.add_child(cam)
	cam.current = true

	return cont


## Restyle the live full-body player model to option `i` and update the blurb.
func _preview_index(i: int) -> void:
	var preset: Dictionary = CharacterPresets.PRESETS[i]
	if _preview != null and _preview.has_method("apply_appearance"):
		_preview.apply_appearance(preset)
	if _blurb != null:
		_blurb.text = "%s — %s" % [str(preset.get("name", "?")), str(preset.get("blurb", ""))]


func _confirm_index(i: int) -> void:
	var preset: Dictionary = CharacterPresets.PRESETS[i]
	if _preview != null:
		_preview.rotation = Vector3.ZERO  # face forward again for gameplay
	chosen.emit(preset)
