extends Control
## Inventory screen (toggle with I). Light/white themed. Shows a live 3D preview of
## the character with equipment slots (each with a small colored icon) around it,
## real stat bars (Move Speed / Jump Height / Attack Damage) that reflect equipped
## gear, and a searchable carried-items list. Read-only (no drag/drop yet).
##
## Item icons are simple representative COLORED SQUARES matching each item's color
## (not true 3D mini-renders) — the live 3D model in the middle is the real preview.

@onready var preview_humanoid = $Panel/Margin/VBox/Row/Preview/SubViewport/Humanoid
@onready var preview_camera: Camera3D = $Panel/Margin/VBox/Row/Preview/SubViewport/Camera3D
@onready var preview_light: DirectionalLight3D = $Panel/Margin/VBox/Row/Preview/SubViewport/Light

@onready var helmet_slot: Control = $Panel/Margin/VBox/Row/Left/HelmetSlot
@onready var helmet_icon = $Panel/Margin/VBox/Row/Left/HelmetSlot/HB/Icon
@onready var helmet_val: Label = $Panel/Margin/VBox/Row/Left/HelmetSlot/HB/SVBox/Value
@onready var chest_slot: Control = $Panel/Margin/VBox/Row/Left/ChestSlot
@onready var chest_icon = $Panel/Margin/VBox/Row/Left/ChestSlot/HB/Icon
@onready var chest_val: Label = $Panel/Margin/VBox/Row/Left/ChestSlot/HB/SVBox/Value
@onready var legs_slot: Control = $Panel/Margin/VBox/Row/Right/LegsSlot
@onready var legs_icon = $Panel/Margin/VBox/Row/Right/LegsSlot/HB/Icon
@onready var legs_val: Label = $Panel/Margin/VBox/Row/Right/LegsSlot/HB/SVBox/Value
@onready var weapon_slot: Control = $Panel/Margin/VBox/Row/Right/WeaponSlot
@onready var weapon_icon = $Panel/Margin/VBox/Row/Right/WeaponSlot/HB/Icon
@onready var weapon_val: Label = $Panel/Margin/VBox/Row/Right/WeaponSlot/HB/SVBox/Value

@onready var move_bar: ProgressBar = $Panel/Margin/VBox/Stats/MoveRow/Bar
@onready var move_val: Label = $Panel/Margin/VBox/Stats/MoveRow/Val
@onready var jump_bar: ProgressBar = $Panel/Margin/VBox/Stats/JumpRow/Bar
@onready var jump_val: Label = $Panel/Margin/VBox/Stats/JumpRow/Val
@onready var atk_bar: ProgressBar = $Panel/Margin/VBox/Stats/AtkRow/Bar
@onready var atk_val: Label = $Panel/Margin/VBox/Stats/AtkRow/Val

@onready var search: LineEdit = $Panel/Margin/VBox/Search
@onready var carried_list: VBoxContainer = $Panel/Margin/VBox/CarriedList

const EMPTY_COLOR := Color(0.78, 0.78, 0.8)
const ITEM_ICON := preload("res://scenes/ui/item_icon.tscn")

# Stat bars scale against a max of 1000 but start LOW (~10 with nothing equipped)
# and grow as gear improves, so progression is obvious. Display-only — the real
# gameplay values are unchanged.
const STAT_MAX := 1000.0
const MOVE_MULT := 2.0    # base move speed 5 -> ~10
const JUMP_MULT := 8.0    # base jump height ~1.28 -> ~10
const ATK_PER_TIER := 200.0  # no weapon -> 10; Tier 1 -> 200 ... Tier 5 -> 1000

# Per-rarity total edition cap (GAME_DESIGN.md 1.7: rarer = scarcer).
const RARITY_CAP := {"Common": 1000, "Uncommon": 500, "Rare": 100, "Epic": 50, "Legendary": 25, "Mythic": 10}

var _preview_weapon: Node = null


func _ready() -> void:
	theme = _build_theme()
	visible = false
	preview_camera.look_at(Vector3(0, 0.0, 0), Vector3.UP)
	preview_light.look_at(Vector3(0, -0.4, 1.0), Vector3.UP)
	search.text_changed.connect(_on_search_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle()


func _toggle() -> void:
	visible = not visible
	if visible:
		_refresh()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _refresh() -> void:
	var player = get_tree().get_first_node_in_group("local_player")
	if player == null:
		return
	var equipment = player.equipment

	_set_slot(helmet_slot, helmet_icon, helmet_val, equipment.get("helmet"))
	_set_slot(chest_slot, chest_icon, chest_val, equipment.get("chest"))
	_set_slot(legs_slot, legs_icon, legs_val, equipment.get("legs"))
	_set_slot(weapon_slot, weapon_icon, weapon_val, equipment.get("weapon"))

	# 3D preview reflects equipped armor + weapon.
	preview_humanoid.apply_equipment(equipment)
	_update_preview_weapon(equipment.get("weapon"))

	# Real gameplay values, displayed as a low-baseline rating on a 0-1000 bar.
	var ms: float = player.get_move_speed()
	var jh: float = player.get_jump_height()
	var tier: int = player.weapon_tier()
	var atk_rating: float = 10.0 if tier <= 0 else float(tier) * ATK_PER_TIER
	_set_stat(move_bar, move_val, ms * MOVE_MULT)
	_set_stat(jump_bar, jump_val, jh * JUMP_MULT)
	_set_stat(atk_bar, atk_val, atk_rating)

	_build_carried(player)
	_apply_filter(search.text)


func _set_slot(slot: Control, icon, value: Label, item) -> void:
	icon.set_item(item)
	value.text = "(empty)" if item == null else str(item.get("name", "?"))
	slot.tooltip_text = _item_tooltip(item)


func _set_stat(bar: ProgressBar, label: Label, scaled: float) -> void:
	bar.max_value = STAT_MAX
	bar.value = clampf(scaled, 0.0, STAT_MAX)
	label.text = "%d / %d" % [int(scaled), int(STAT_MAX)]


## Tooltip text: rarity/tier, edition #X of cap, and relevant modifiers.
func _item_tooltip(item) -> String:
	if item == null:
		return ""
	var lines: Array = []
	lines.append(str(item.get("name", "?")))
	var rarity := str(item.get("rarity", "Common"))
	var tier := int(item.get("tier", 1))
	lines.append("%s  ·  Tier %d" % [rarity, tier])
	var cap: int = int(RARITY_CAP.get(rarity, 1000))
	lines.append("#%d of %d" % [int(item.get("edition", 1)), cap])
	if str(item.get("slot", "")) == "weapon":
		lines.append("Damage: %d" % (2 + (tier - 1) * 2))
		var el := str(item.get("element", ""))
		if el != "":
			lines.append("Element: %s" % el.capitalize())
	if item.has("move_mod"):
		lines.append("Move Speed: %+.1f" % float(item["move_mod"]))
	if item.has("jump_mod"):
		lines.append("Jump: %+.1f" % float(item["jump_mod"]))
	return "\n".join(lines)


func _build_carried(player) -> void:
	for c in carried_list.get_children():
		carried_list.remove_child(c)
		c.queue_free()

	var equipped: Array = []
	for slot in player.equipment:
		if player.equipment[slot] != null:
			equipped.append(player.equipment[slot])

	for item in player.inventory:
		if item in equipped:
			continue
		var item_name := str(item.get("name", "?"))
		var row := HBoxContainer.new()
		row.set_meta("item_name", item_name.to_lower())
		row.mouse_filter = Control.MOUSE_FILTER_STOP  # receive hover (tooltip) + clicks
		row.tooltip_text = _item_tooltip(item)
		var hint := "  (click to equip)" if str(item.get("slot", "")) != "" else ""
		row.gui_input.connect(_on_carried_clicked.bind(item))
		var icon = ITEM_ICON.instantiate()
		icon.custom_minimum_size = Vector2(22, 22)
		row.add_child(icon)
		icon.set_item(item)
		var label := Label.new()
		label.text = "  " + item_name + hint
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks/hover reach the row
		row.add_child(label)
		carried_list.add_child(row)


func _on_carried_clicked(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if str(item.get("slot", "")) == "":
			return  # not equippable (e.g. a coin)
		var player = get_tree().get_first_node_in_group("local_player")
		if player != null:
			player.equip(item)
			_refresh()


func _on_search_changed(text: String) -> void:
	_apply_filter(text)


func _apply_filter(query: String) -> void:
	var q := query.to_lower()
	for row in carried_list.get_children():
		var name_lc := str(row.get_meta("item_name", ""))
		row.visible = q == "" or name_lc.find(q) != -1


func _update_preview_weapon(weapon_item) -> void:
	if _preview_weapon != null:
		_preview_weapon.queue_free()
		_preview_weapon = null
	if weapon_item == null:
		return
	var path: String = weapon_item.get("scene", "")
	if path == "":
		return
	var packed: PackedScene = load(path)
	if packed == null:
		return
	_preview_weapon = packed.instantiate()
	preview_humanoid.attach_to_hand(_preview_weapon)


func _build_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", Color(0.12, 0.12, 0.15))
	t.set_color("font_color", "LineEdit", Color(0.12, 0.12, 0.15))
	t.set_color("font_placeholder_color", "LineEdit", Color(0.45, 0.45, 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.95, 0.97)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	t.set_stylebox("panel", "PanelContainer", sb)
	return t
