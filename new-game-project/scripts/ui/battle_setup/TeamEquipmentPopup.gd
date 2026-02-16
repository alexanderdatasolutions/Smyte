# scripts/ui/battle_setup/TeamEquipmentPopup.gd
# Handles equipment display summary and inline equipment editing popup
extends RefCounted

signal equipment_changed

var _stats_panel: Control = null

func initialize(stats_panel: Control) -> void:
	_stats_panel = stats_panel

func update_equipment_display(selected_team: Array) -> void:
	if not _stats_panel:
		return

	var equip_container: VBoxContainer = _stats_panel.get_node_or_null("MarginContainer/VBoxContainer/EquipmentContainer")
	if not equip_container:
		return

	for child: Node in equip_container.get_children():
		child.queue_free()

	var has_selected: bool = false
	for god: Variant in selected_team:
		if god != null:
			has_selected = true
			break

	if not has_selected:
		var no_team: Label = Label.new()
		no_team.text = "Select gods to view equipment"
		no_team.add_theme_font_size_override("font_size", 10)
		no_team.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		equip_container.add_child(no_team)
		return

	for god: Variant in selected_team:
		if god == null:
			continue

		var god_equip: HBoxContainer = HBoxContainer.new()
		god_equip.add_theme_constant_override("separation", 6)

		var name_label: Label = Label.new()
		var display_name: String = god.name.substr(0, 8) if god.name.length() > 8 else god.name
		name_label.text = display_name
		name_label.custom_minimum_size = Vector2(70, 0)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.9))
		god_equip.add_child(name_label)

		var equip_text: String = _get_equipment_summary(god)
		var equip_label: Label = Label.new()
		equip_label.text = equip_text
		equip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip_label.add_theme_font_size_override("font_size", 10)
		if equip_text == "No gear":
			equip_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		else:
			equip_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		god_equip.add_child(equip_label)

		var edit_btn: Button = Button.new()
		edit_btn.text = "⚙"
		edit_btn.tooltip_text = "Edit " + god.name + "'s equipment"
		edit_btn.custom_minimum_size = Vector2(28, 24)
		edit_btn.add_theme_font_size_override("font_size", 12)
		edit_btn.pressed.connect(_show_equipment_popup.bind(god))
		_style_button(edit_btn)
		god_equip.add_child(edit_btn)

		equip_container.add_child(god_equip)

func _get_equipment_summary(god: God) -> String:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return "No gear"
	var equipment_manager: Node = registry.get_system("EquipmentManager")
	if not equipment_manager:
		return "No gear"
	if not equipment_manager.has_method("get_equipped_items"):
		return "No gear"

	var equipped: Variant = equipment_manager.get_equipped_items(god.id)
	if equipped == null or equipped.is_empty():
		return "No gear"

	var count: int = equipped.size()
	if count == 1:
		return "1 item"
	return str(count) + " items"

func _show_equipment_popup(god: God) -> void:
	var popup_overlay: ColorRect = ColorRect.new()
	popup_overlay.name = "EquipmentPopupOverlay"
	popup_overlay.color = Color(0, 0, 0, 0.7)
	popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_overlay.z_index = 100

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var root: Window = tree.root
	root.add_child(popup_overlay)

	popup_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			popup_overlay.queue_free()
	)

	var popup_panel: PanelContainer = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(500, 450)
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.position = Vector2(-250, -225)
	_style_panel(popup_panel)
	popup_overlay.add_child(popup_panel)

	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	popup_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "EQUIPMENT: " + god.name.to_upper()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func() -> void: popup_overlay.queue_free())
	_style_button(close_btn)
	header.add_child(close_btn)

	# Equipped items section
	var slots_label: Label = Label.new()
	slots_label.text = "EQUIPPED ITEMS"
	slots_label.add_theme_font_size_override("font_size", 12)
	slots_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(slots_label)

	var slots_grid: GridContainer = GridContainer.new()
	slots_grid.columns = 3
	slots_grid.add_theme_constant_override("h_separation", 10)
	slots_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(slots_grid)

	var slot_types: Array[String] = ["weapon", "armor", "helmet", "accessory", "ring", "artifact"]
	var registry: Node = SystemRegistry.get_instance()
	var equipped_items: Dictionary = {}
	if registry:
		var equipment_manager: Node = registry.get_system("EquipmentManager")
		if equipment_manager and equipment_manager.has_method("get_equipped_items"):
			var result: Variant = equipment_manager.get_equipped_items(god.id)
			if result != null:
				equipped_items = result

	for slot_type: String in slot_types:
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(145, 60)
		var slot_style: StyleBoxFlat = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.1, 0.08, 0.15, 0.9)
		slot_style.border_color = Color(0.3, 0.25, 0.4, 0.6)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		slots_grid.add_child(slot_panel)

		var slot_vbox: VBoxContainer = VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)

		var slot_margin: MarginContainer = MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 8)
		slot_margin.add_theme_constant_override("margin_top", 5)
		slot_margin.add_child(slot_vbox)
		slot_panel.add_child(slot_margin)

		var slot_title: Label = Label.new()
		slot_title.text = slot_type.to_upper()
		slot_title.add_theme_font_size_override("font_size", 9)
		slot_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		slot_vbox.add_child(slot_title)

		var item_name: Label = Label.new()
		if equipped_items.has(slot_type) and equipped_items[slot_type] != null:
			var item: Variant = equipped_items[slot_type]
			item_name.text = item.name if item.has("name") else "Unknown"
			item_name.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
		else:
			item_name.text = "Empty"
			item_name.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		item_name.add_theme_font_size_override("font_size", 11)
		slot_vbox.add_child(item_name)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Inventory section
	var inv_label: Label = Label.new()
	inv_label.text = "INVENTORY"
	inv_label.add_theme_font_size_override("font_size", 12)
	inv_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(inv_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var inv_grid: GridContainer = GridContainer.new()
	inv_grid.columns = 4
	inv_grid.add_theme_constant_override("h_separation", 8)
	inv_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(inv_grid)

	var equipment_items: Array = []
	if registry:
		var inventory_manager: Node = registry.get_system("InventoryManager")
		if inventory_manager and inventory_manager.has_method("get_equipment_items"):
			equipment_items = inventory_manager.get_equipment_items()

	if equipment_items.is_empty():
		var no_items: Label = Label.new()
		no_items.text = "No equipment in inventory"
		no_items.add_theme_font_size_override("font_size", 11)
		no_items.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		inv_grid.add_child(no_items)
	else:
		for item: Dictionary in equipment_items.slice(0, 12):
			var item_btn: Button = Button.new()
			item_btn.text = item.get("name", "Item")
			item_btn.custom_minimum_size = Vector2(100, 40)
			item_btn.add_theme_font_size_override("font_size", 10)
			item_btn.tooltip_text = "Click to equip"
			item_btn.pressed.connect(func() -> void:
				_equip_item_to_god(god, item)
				popup_overlay.queue_free()
				_show_equipment_popup(god)
			)
			_style_button(item_btn)
			inv_grid.add_child(item_btn)

func _equip_item_to_god(god: God, item: Dictionary) -> void:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	var equipment_manager: Node = registry.get_system("EquipmentManager")
	if equipment_manager and equipment_manager.has_method("equip_item"):
		equipment_manager.equip_item(god.id, item.get("id", ""), item.get("slot", "weapon"))
	equipment_changed.emit()

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common": return Color(0.7, 0.7, 0.7)
		"uncommon": return Color(0.4, 0.8, 0.4)
		"rare": return Color(0.4, 0.6, 1.0)
		"epic": return Color(0.7, 0.4, 0.9)
		"legendary": return Color(1.0, 0.8, 0.2)
		_: return Color(0.7, 0.7, 0.7)

# ============================================================================
# STYLING HELPERS
# ============================================================================

func _style_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button) -> void:
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_font_size_override("font_size", 11)
