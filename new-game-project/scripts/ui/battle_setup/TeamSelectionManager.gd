# scripts/ui/battle_setup/TeamSelectionManager.gd
# Unified team selection coordinator - delegates stats, preview, and equipment to helpers
class_name TeamSelectionManager
extends Node

signal team_changed(team: Array)
signal battle_start_requested(team: Array)
signal setup_cancelled

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")
const TeamBattlePreviewScript = preload("res://scripts/ui/battle_setup/TeamBattlePreview.gd")
const TeamEquipmentPopupScript = preload("res://scripts/ui/battle_setup/TeamEquipmentPopup.gd")
const TeamStatsPanelScript = preload("res://scripts/ui/battle_setup/TeamStatsPanel.gd")

# UI References
var available_gods_grid: GridContainer = null
var start_battle_button: Button = null
var cancel_button: Button = null

# Sorting UI references
var sort_dropdown: OptionButton = null
var sort_direction_btn: Button = null

# Data
var selected_team: Array = []
var team_slots: Array = []
var available_gods: Array = []
var unavailable_gods: Array = []  # Array of {god: God, assignment: String}
var max_team_size: int = 4
var battle_context: Dictionary = {}

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false

# Delegate helpers
var _stats_panel_helper: RefCounted = null
var _battle_preview: RefCounted = null
var _equipment_popup: RefCounted = null

func initialize(slots_container: HBoxContainer, gods_grid: GridContainer, start_btn: Button, cancel_btn: Button) -> void:
	_stats_panel_helper = TeamStatsPanelScript.new()
	_stats_panel_helper.team_slots_container = slots_container
	available_gods_grid = gods_grid
	start_battle_button = start_btn
	cancel_button = cancel_btn

	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_create_team_slots()
	_load_available_gods()
	_update_team_stats()

func initialize_full(parent_container: Control) -> void:
	_stats_panel_helper = TeamStatsPanelScript.new()
	_battle_preview = TeamBattlePreviewScript.new()
	_equipment_popup = TeamEquipmentPopupScript.new()
	_equipment_popup.equipment_changed.connect(_on_equipment_changed)
	_create_full_ui(parent_container)
	_load_available_gods()
	_update_team_stats()

func setup_for_context(context: Dictionary) -> void:
	battle_context = context
	_update_ui_for_context()

func _update_ui_for_context() -> void:
	match battle_context.get("type", ""):
		"territory", "dungeon", "pvp", "hex_capture", "tower", \
		"pvp_territory_attack", "pvp_territory_defense":
			max_team_size = 4
			_refresh_team_slots()

	# Update enemy and rewards preview via delegate
	if _battle_preview:
		_battle_preview.update_enemy_preview(battle_context)
		_battle_preview.update_rewards_preview(battle_context)

# ============================================================================
# TEAM STATS (delegated)
# ============================================================================

func _update_team_stats() -> void:
	if _stats_panel_helper:
		_stats_panel_helper.update_team_stats(selected_team)
	if _equipment_popup:
		_equipment_popup.update_equipment_display(selected_team)

func _on_equipment_changed() -> void:
	_update_team_stats()

# ============================================================================
# SORTING CONTROLS
# ============================================================================

func create_sorting_controls() -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	var sort_label: Label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	container.add_child(sort_label)

	sort_dropdown = OptionButton.new()
	sort_dropdown.custom_minimum_size = Vector2(100, 28)
	sort_dropdown.add_item("Power", SortType.POWER)
	sort_dropdown.add_item("Level", SortType.LEVEL)
	sort_dropdown.add_item("Tier", SortType.TIER)
	sort_dropdown.add_item("Element", SortType.ELEMENT)
	sort_dropdown.add_item("Name", SortType.NAME)
	sort_dropdown.selected = 0
	sort_dropdown.item_selected.connect(_on_sort_changed)
	container.add_child(sort_dropdown)

	sort_direction_btn = Button.new()
	sort_direction_btn.text = "▼"
	sort_direction_btn.custom_minimum_size = Vector2(30, 28)
	sort_direction_btn.tooltip_text = "Toggle sort direction"
	sort_direction_btn.pressed.connect(_toggle_sort_direction)
	_style_button(sort_direction_btn)
	container.add_child(sort_direction_btn)

	return container

func _on_sort_changed(index: int) -> void:
	current_sort = index as SortType
	_refresh_gods_grid()

func _toggle_sort_direction() -> void:
	sort_ascending = not sort_ascending
	sort_direction_btn.text = "▲" if sort_ascending else "▼"
	_refresh_gods_grid()

func _sort_gods(gods: Array) -> Array:
	var sorted: Array = gods.duplicate()

	match current_sort:
		SortType.POWER:
			sorted.sort_custom(func(a: God, b: God) -> bool:
				var pa: int = TeamStatsCalculator.calculate_god_power(a)
				var pb: int = TeamStatsCalculator.calculate_god_power(b)
				return pa < pb if sort_ascending else pa > pb)
		SortType.LEVEL:
			sorted.sort_custom(func(a: God, b: God) -> bool:
				return a.level < b.level if sort_ascending else a.level > b.level)
		SortType.TIER:
			sorted.sort_custom(func(a: God, b: God) -> bool:
				return a.tier < b.tier if sort_ascending else a.tier > b.tier)
		SortType.ELEMENT:
			sorted.sort_custom(func(a: God, b: God) -> bool:
				return a.element < b.element if sort_ascending else a.element > b.element)
		SortType.NAME:
			sorted.sort_custom(func(a: God, b: God) -> bool:
				return a.name < b.name if sort_ascending else a.name > b.name)

	return sorted

# ============================================================================
# TEAM SLOT MANAGEMENT
# ============================================================================

func _create_team_slots() -> void:
	var slots_container: HBoxContainer = null
	if _stats_panel_helper:
		slots_container = _stats_panel_helper.team_slots_container
	if not slots_container:
		return

	for child: Node in slots_container.get_children():
		child.queue_free()

	team_slots.clear()
	selected_team.clear()

	for i: int in range(max_team_size):
		var slot: Control = _create_team_slot(i)
		slots_container.add_child(slot)
		team_slots.append(slot)
		selected_team.append(null)

func _refresh_team_slots() -> void:
	for slot: Variant in team_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	team_slots.clear()
	selected_team.clear()
	_create_team_slots()
	_load_available_gods()
	_update_team_stats()

func _create_team_slot(index: int) -> Control:
	var slot: Panel = Panel.new()
	slot.name = "TeamSlot_" + str(index)
	slot.custom_minimum_size = Vector2(65, 85)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
	style.border_color = Color(0.4, 0.35, 0.5, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)

	var god_display: Control = Control.new()
	god_display.name = "GodDisplay"
	god_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(god_display)

	var empty_label: Label = Label.new()
	empty_label.text = "+"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	god_display.add_child(empty_label)

	slot.gui_input.connect(_on_slot_clicked.bind(index))

	return slot

func _on_slot_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_team[index] != null:
			_clear_slot(index)

func _clear_slot(slot_index: int) -> void:
	selected_team[slot_index] = null
	_update_slot_display(slot_index)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)

func _clear_team() -> void:
	for i: int in range(selected_team.size()):
		selected_team[i] = null
		_update_slot_display(i)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)

func _update_slot_display(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= team_slots.size():
		return

	var slot: Variant = team_slots[slot_index]
	if not slot or not is_instance_valid(slot):
		return

	var god_display: Control = slot.get_node_or_null("VBoxContainer/GodDisplay")
	if not god_display:
		return

	for child: Node in god_display.get_children():
		child.queue_free()

	var god: Variant = selected_team[slot_index]
	if god == null:
		var empty_label: Label = Label.new()
		empty_label.text = "+"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		god_display.add_child(empty_label)
	else:
		var god_card: Control = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_card.setup_god_card(god)
		god_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		god_display.add_child(god_card)

# ============================================================================
# AVAILABLE GODS GRID
# ============================================================================

func _load_available_gods() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	var collection_manager: Node = registry.get_system("CollectionManager")
	if not collection_manager:
		return

	var all_gods: Array = collection_manager.get_all_gods()

	available_gods.clear()
	unavailable_gods.clear()

	for god: God in all_gods:
		var assignment: String = _get_god_assignment(god)
		if assignment.is_empty():
			available_gods.append(god)
		else:
			unavailable_gods.append({"god": god, "assignment": assignment})

	_refresh_gods_grid()

func _refresh_gods_grid() -> void:
	if not available_gods_grid:
		return

	for child: Node in available_gods_grid.get_children():
		child.queue_free()

	var sorted_gods: Array = _sort_gods(available_gods)

	for god: God in sorted_gods:
		var already_selected: bool = false
		for selected: Variant in selected_team:
			if selected != null and selected.id == god.id:
				already_selected = true
				break

		if not already_selected:
			var card_container: Control = _create_god_card_for_grid(god, "")
			available_gods_grid.add_child(card_container)

	var sorted_unavailable: Array = unavailable_gods.duplicate()
	sorted_unavailable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.god.name < b.god.name)

	for entry: Dictionary in sorted_unavailable:
		var card_container: Control = _create_god_card_for_grid(entry.god, entry.assignment)
		available_gods_grid.add_child(card_container)

func _create_god_card_for_grid(god: God, assignment: String = "") -> Control:
	var is_unavailable: bool = not assignment.is_empty()

	var container: Panel = Panel.new()
	container.custom_minimum_size = Vector2(160, 200)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	container.add_theme_stylebox_override("panel", style)

	var god_card: Control = GodCardFactory.create_god_card(GodCardFactory.CardPreset.BATTLE_SELECTION)
	god_card.setup_god_card(god)
	god_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	god_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disable_mouse_on_children(god_card)
	container.add_child(god_card)

	var selection_overlay: ColorRect = ColorRect.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_overlay.color = Color(0.2, 0.6, 0.2, 0.3)
	selection_overlay.visible = false
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(selection_overlay)

	if is_unavailable:
		var unavailable_overlay: ColorRect = ColorRect.new()
		unavailable_overlay.name = "UnavailableOverlay"
		unavailable_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		unavailable_overlay.color = Color(0.1, 0.1, 0.15, 0.7)
		unavailable_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(unavailable_overlay)

		var assignment_label: Label = Label.new()
		assignment_label.text = assignment
		assignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		assignment_label.add_theme_font_size_override("font_size", 10)
		assignment_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		assignment_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		assignment_label.offset_top = -25
		assignment_label.offset_bottom = -5
		assignment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(assignment_label)

		container.tooltip_text = god.name + " is assigned to " + assignment + "\nRemove from node to use in battle"
	else:
		container.gui_input.connect(_on_god_card_clicked.bind(god, container))

	return container

func _on_god_card_clicked(event: InputEvent, god: God, _container: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_god_selected(god)

func _on_god_selected(god: God) -> void:
	for i: int in range(selected_team.size()):
		if selected_team[i] == null:
			_assign_god_to_slot(god, i)
			break

func _assign_god_to_slot(god: God, slot_index: int) -> void:
	selected_team[slot_index] = god
	_update_slot_display(slot_index)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)

func _get_god_assignment(god: God) -> String:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return ""
	var territory_manager: Node = registry.get_system("TerritoryManager")
	if not territory_manager:
		return ""

	var controlled_nodes: Array = territory_manager.get_controlled_nodes()
	for hex_node: Variant in controlled_nodes:
		if hex_node.garrison.find(god.id) != -1:
			return "Garrison: " + hex_node.name
		if hex_node.assigned_workers.find(god.id) != -1:
			return "Worker: " + hex_node.name

	return ""

func _disable_mouse_on_children(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(child)

# ============================================================================
# BUTTONS & ACTIONS
# ============================================================================

func _on_start_battle_pressed() -> void:
	var has_gods: bool = false
	for god: Variant in selected_team:
		if god != null:
			has_gods = true
			break

	if not has_gods:
		var registry: Node = SystemRegistry.get_instance()
		if registry:
			var notification_manager: Node = registry.get_system("NotificationManager")
			if notification_manager:
				notification_manager.show_error("Please select at least one god for battle")
		return

	battle_start_requested.emit(selected_team)

func _on_cancel_pressed() -> void:
	setup_cancelled.emit()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _style_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool = false) -> void:
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_font_size_override("font_size", 11)

func _create_full_ui(parent: Control) -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	parent.add_child(main_vbox)

	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)

	# Left panel - stats (delegated to TeamStatsPanel)
	var left_panel: Control = _stats_panel_helper.create_stats_panel(_clear_team)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(left_panel)

	# Wire up preview and equipment helpers to the panel's containers
	_battle_preview.initialize(
		_stats_panel_helper.enemy_preview_container,
		_stats_panel_helper.rewards_preview_container
	)
	_equipment_popup.initialize(_stats_panel_helper.stats_panel)

	# Right panel - gods grid
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(right_panel)
	content_hbox.add_child(right_panel)

	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_panel.add_child(right_margin)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	right_vbox.add_child(header_row)

	var header: Label = Label.new()
	header.text = "SELECT GODS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	var sorting: HBoxContainer = create_sorting_controls()
	header_row.add_child(sorting)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	available_gods_grid = GridContainer.new()
	available_gods_grid.columns = 4
	available_gods_grid.add_theme_constant_override("h_separation", 10)
	available_gods_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(available_gods_grid)

	# Bottom buttons panel
	var buttons_panel: PanelContainer = PanelContainer.new()
	buttons_panel.custom_minimum_size = Vector2(0, 60)
	_style_panel(buttons_panel)
	main_vbox.add_child(buttons_panel)

	var buttons_margin: MarginContainer = MarginContainer.new()
	buttons_margin.add_theme_constant_override("margin_left", 20)
	buttons_margin.add_theme_constant_override("margin_right", 20)
	buttons_margin.add_theme_constant_override("margin_top", 10)
	buttons_margin.add_theme_constant_override("margin_bottom", 10)
	buttons_panel.add_child(buttons_margin)

	var buttons_hbox: HBoxContainer = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 20)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_margin.add_child(buttons_hbox)

	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.custom_minimum_size = Vector2(120, 40)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_style_button(cancel_button, false)
	buttons_hbox.add_child(cancel_button)

	start_battle_button = Button.new()
	start_battle_button.text = "START BATTLE"
	start_battle_button.custom_minimum_size = Vector2(160, 40)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	_style_button(start_battle_button, true)
	buttons_hbox.add_child(start_battle_button)

	# Create team slots now that the container exists
	_create_team_slots()

# ============================================================================
# PUBLIC API
# ============================================================================

func get_selected_team() -> Array:
	return selected_team.duplicate()

func set_team(team: Array) -> void:
	selected_team = team.duplicate()
	selected_team.resize(max_team_size)
	for i: int in range(team_slots.size()):
		_update_slot_display(i)
	_refresh_gods_grid()
	_update_team_stats()
	team_changed.emit(selected_team)
