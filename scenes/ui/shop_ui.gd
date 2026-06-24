extends Control
## Shop screen, opened by a special NPC once you've completed their quest. Lists their
## wares with gold prices; clicking Buy spends the player's looted coins and adds (and
## auto-equips, if it's gear) the item. Frees the mouse while open. In group "shop_ui"
## so SpecialNPC can find and open() it.

var _stock: Array = []
var _title: Label
var _coins: Label
var _list: VBoxContainer


func _ready() -> void:
	add_to_group("shop_ui")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# Dim backdrop.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 380)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.14, 0.97)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.8, 0.7, 0.3, 0.8)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	vb.add_child(_title)

	_coins = Label.new()
	_coins.add_theme_font_size_override("font_size", 15)
	_coins.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vb.add_child(_coins)

	var sep := HSeparator.new()
	vb.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var close := Button.new()
	close.text = "Close  (Esc)"
	close.pressed.connect(_close)
	vb.add_child(close)


func open(npc_name: String, stock: Array) -> void:
	_stock = stock
	_title.text = npc_name + " — Wares"
	_populate()
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	_refresh_coins()
	for entry in _stock:
		var item: Dictionary = entry["item"]
		var price: int = int(entry["price"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = str(item.get("name", "?"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d g" % price
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row.add_child(price_lbl)

		var buy := Button.new()
		buy.text = "Buy"
		buy.pressed.connect(_on_buy.bind(item, price))
		row.add_child(buy)

		_list.add_child(row)


func _refresh_coins() -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	_coins.text = "Your gold: %d" % (int(player.coins) if player != null else 0)


func _on_buy(item: Dictionary, price: int) -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	if not player.spend_coins(price):
		_flash_coins("Not enough gold!")
		return
	player.add_item(item)
	if item.get("slot", "") != "" and player.has_method("equip"):
		player.equip(item)
	_flash_coins("Bought %s" % str(item.get("name", "item")))
	_refresh_coins()


func _flash_coins(msg: String) -> void:
	_coins.text = msg
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(_refresh_coins)
