extends Control
## Quest + trading dialogue with a villager. Driven entirely by the villager's
## quest/trade API (see villager.gd):
##   - Not accepted     -> offer the "slay N beasts" quest.
##   - Accepted, ongoing -> show progress.
##   - Complete          -> turn in for a coin reward (unlocks the shop).
##   - Merchant          -> three wares that stay until bought (sold ones stay sold).
##
## Built in code; instanced + shown by main.gd when you press E near a villager.

signal closed

var _npc
var _player
var _title: Label
var _body: Label
var _btns: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(540, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.11, 0.14, 0.97)
	ps.set_corner_radius_all(10)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.5, 0.42, 0.2)
	ps.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	# Centre the panel.
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	vb.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(500, 0)
	_body.add_theme_font_size_override("font_size", 16)
	vb.add_child(_body)

	var sep := HSeparator.new()
	vb.add_child(sep)

	_btns = VBoxContainer.new()
	_btns.add_theme_constant_override("separation", 8)
	vb.add_child(_btns)

	hide()


## Open the dialogue for a villager. The caller (main) freezes the player + frees
## the mouse; we restore via the `closed` signal.
func open(npc, player) -> void:
	_npc = npc
	_player = player
	show()
	_refresh()


func _refresh() -> void:
	if _npc == null:
		return
	_title.text = "%s        Coins: %d" % [_npc.npc_name, _coins()]
	for c in _btns.get_children():
		c.queue_free()

	if not _npc.quest_accepted:
		_body.text = "\"Greetings, traveller. Beasts plague these wilds — slay %d of them for me, and I'll pay you and open my wares.\"" % _npc.quest_target
		_add_button("Accept Quest", _on_accept)
	elif not _npc.quest_turned_in:
		if _npc.quest_complete(_player):
			_body.text = "\"You've done it! The village is safer for it. Here — take this.\""
			_add_button("Turn In  (+%d coins)" % (30 + _npc.quest_target * 10), _on_turn_in)
		else:
			_body.text = "\"Slay the beasts roaming the wilds, then return to me.\"\n\nProgress:  %d / %d" % [_npc.quest_progress(_player), _npc.quest_target]
	else:
		_body.text = "\"Welcome back, friend. Take your pick — these are all I have.\""
		for i in range(_npc.offers.size()):
			var o: Dictionary = _npc.offers[i]
			var item: Dictionary = o.item
			var name_str: String = str(item.get("name", "Item"))
			if o.sold:
				_add_button("%s — SOLD" % name_str, Callable(), true)
			else:
				var afford: bool = _coins() >= int(o.price)
				_add_button("%s — %d coins" % [name_str, int(o.price)], _on_buy.bind(i), not afford)

	_add_button("Close", _on_close)


func _add_button(text: String, cb: Callable, disabled := false) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	if not disabled and cb.is_valid():
		b.pressed.connect(cb)
	_btns.add_child(b)


func _coins() -> int:
	return int(_player.coins) if _player != null else 0


func _on_accept() -> void:
	_npc.accept_quest(_player)
	_refresh()


func _on_turn_in() -> void:
	_npc.turn_in(_player)
	_refresh()


func _on_buy(index: int) -> void:
	_npc.buy(index, _player)
	_refresh()


func _on_close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
