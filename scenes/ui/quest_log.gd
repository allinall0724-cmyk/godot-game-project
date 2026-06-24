extends Control
## Two pieces:
##   - a persistent BANNER (top-centre) showing the quest you're tracking and the task
##     you're on right now; click it (or press J) to expand full DETAILS,
##   - a DETAILS panel listing every active quest with its parts ticked off, the
##     "must not die" warning, and the reward.
##
## The banner is a Button so it's clickable; opening the panel frees the mouse (the
## camera normally captures it), pressing J or Esc / clicking again closes it.

var _banner: Button
var _panel: PanelContainer
var _detail: RichTextLabel
var _refresh_t := 0.0


func _ready() -> void:
	add_to_group("quest_log")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_banner()
	_build_panel()
	var quests := get_node_or_null("/root/Quests")
	if quests != null:
		quests.quest_updated.connect(func(_id): _update())
		quests.quest_started.connect(func(_id): _update())
		quests.quest_completed.connect(func(_id): _update())
	_update()


func _build_banner() -> void:
	_banner = Button.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -190.0
	_banner.offset_right = 190.0
	_banner.offset_top = 8.0
	_banner.offset_bottom = 34.0
	_banner.clip_text = true
	_banner.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.45, 0.95, 0.7)
	sb.set_content_margin_all(4)
	_banner.add_theme_stylebox_override("normal", sb)
	_banner.add_theme_stylebox_override("hover", sb)
	_banner.add_theme_stylebox_override("pressed", sb)
	_banner.pressed.connect(_toggle)
	add_child(_banner)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -240.0
	_panel.offset_right = 240.0
	_panel.offset_top = 40.0
	_panel.custom_minimum_size = Vector2(480, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.97)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.45, 0.95, 0.8)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(456, 60)
	_detail.add_theme_font_size_override("normal_font_size", 14)
	_panel.add_child(_detail)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif _panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_set_open(not _panel.visible)


func _set_open(open: bool) -> void:
	_panel.visible = open
	if open:
		_rebuild_detail()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.4
		_update()


## Update the one-line banner from whatever quest is being tracked.
func _update() -> void:
	var quests := get_node_or_null("/root/Quests")
	if quests == null:
		return
	var line: String = quests.get_active_objective_text()
	if line == "":
		_banner.visible = false
	else:
		_banner.visible = true
		_banner.text = "✦ " + line + "    (J)"
	if _panel.visible:
		_rebuild_detail()


func _rebuild_detail() -> void:
	var quests := get_node_or_null("/root/Quests")
	if quests == null:
		return
	var ids: Array = quests.tracked_ids()
	if ids.is_empty():
		_detail.text = "[i]No active quests. Seek out the ! markers.[/i]"
		return
	var blocks: Array = []
	for id in ids:
		var lines: Array = quests.detail_lines(id)
		if lines.is_empty():
			continue
		var body := "[b]" + str(lines[0]) + "[/b]"
		for i in range(1, lines.size()):
			body += "\n  " + str(lines[i])
		blocks.append(body)
	_detail.text = "\n\n".join(blocks)
