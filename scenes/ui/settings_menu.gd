extends Control
## Pause/Settings menu (toggle with Escape). Lets the player adjust mouse
## sensitivity and rebind keys. Changes apply immediately and persist for the
## session (InputMap is in-memory; not written to disk). Pauses the game while open.

const REBINDABLE := [
	["move_forward", "Move Forward"], ["move_back", "Move Back"],
	["move_left", "Move Left"], ["move_right", "Move Right"],
	["jump", "Jump"], ["sprint", "Sprint"], ["attack", "Attack"],
	["interact", "Interact / Board"], ["inventory", "Inventory"],
	["ability_1", "Ability 1"], ["ability_2", "Ability 2"], ["ability_3", "Ability 3"],
	["ability_4", "Ability 4"], ["ability_5", "Ability 5"],
]

@onready var sens_slider: HSlider = $Panel/Margin/VBox/SensRow/Slider
@onready var sens_value: Label = $Panel/Margin/VBox/SensRow/Value
@onready var rebind_list: VBoxContainer = $Panel/Margin/VBox/Scroll/RebindList
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _rebinding := ""        # action currently awaiting a new key
var _buttons := {}          # action -> Button


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	sens_slider.value_changed.connect(_on_sens_changed)
	for entry in REBINDABLE:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = entry[1]
		lbl.custom_minimum_size = Vector2(170, 0)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(170, 0)
		btn.text = _key_name(entry[0])
		btn.pressed.connect(_start_rebind.bind(entry[0]))
		row.add_child(btn)
		rebind_list.add_child(row)
		_buttons[entry[0]] = btn


func _unhandled_input(event: InputEvent) -> void:
	if _rebinding == "" and event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _rebinding == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:  # Esc cancels the rebind
			InputMap.action_erase_events(_rebinding)
			InputMap.action_add_event(_rebinding, event)
		_buttons[_rebinding].text = _key_name(_rebinding)
		_rebinding = ""
		accept_event()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	var cam = get_tree().get_first_node_in_group("camera_rig")
	if cam != null:
		sens_slider.value = cam.sensitivity
		sens_value.text = "%.4f" % cam.sensitivity
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func close() -> void:
	visible = false
	_rebinding = ""
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_sens_changed(value: float) -> void:
	var cam = get_tree().get_first_node_in_group("camera_rig")
	if cam != null:
		cam.sensitivity = value
	sens_value.text = "%.4f" % value


func _start_rebind(action: String) -> void:
	_rebinding = action
	_buttons[action].text = "Press a key..."


func _key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(code)
		elif ev is InputEventMouseButton:
			return "Mouse Button %d" % ev.button_index
	return "(unset)"
