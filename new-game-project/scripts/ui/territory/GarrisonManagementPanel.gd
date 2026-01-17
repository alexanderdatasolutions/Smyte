# scripts/ui/territory/GarrisonManagementPanel.gd
# Panel for managing garrison assignments at hex nodes
extends Control
class_name GarrisonManagementPanel

"""
GarrisonManagementPanel.gd - Garrison assignment UI for hex nodes
RULE 2: Single responsibility - ONLY manages garrison UI for nodes
RULE 1: Under 500 lines
RULE 4: No data modification - delegates to TerritoryManager

Shows:
- Current garrison at node with combat stats
- Available gods (not in garrison/working elsewhere)
- Assign/unassign controls
- Defense rating calculation
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal close_requested()
signal garrison_assigned(node: HexNode, god_id: String)
signal garrison_unassigned(node: HexNode, god_id: String)

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_node: HexNode = null

# System references
var collection_manager = null
var territory_manager = null

# UI components
var _main_container: VBoxContainer = null
var _header_label: Label = null
var _defense_info_label: Label = null
var _current_garrison_container: VBoxContainer = null
var _available_gods_container: VBoxContainer = null
var _close_button: Button = null

# State
var _selected_god_id: String = ""

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH = 600
const PANEL_HEIGHT = 500
const BUTTON_HEIGHT = 36
const ITEM_HEIGHT = 40

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_build_ui()
	visible = false  # Start hidden

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("GarrisonManagementPanel: SystemRegistry not available")
		return

	collection_manager = registry.get_system("CollectionManager")
	territory_manager = registry.get_system("TerritoryManager")

	if not collection_manager:
		push_error("GarrisonManagementPanel: CollectionManager not found")
	if not territory_manager:
		push_error("GarrisonManagementPanel: TerritoryManager not found")

func _build_ui() -> void:
	"""Build the UI components"""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	bg_style.border_width_left = 3
	bg_style.border_width_right = 3
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0.3, 0.5, 0.7, 1)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Main container with margins
	_main_container = VBoxContainer.new()
	_main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_container.add_theme_constant_override("separation", 10)
	_main_container.offset_left = 20
	_main_container.offset_top = 20
	_main_container.offset_right = -20
	_main_container.offset_bottom = -20
	add_child(_main_container)

	# Header
	_header_label = Label.new()
	_header_label.text = "GARRISON MANAGEMENT"
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	_main_container.add_child(_header_label)

	# Defense info
	_defense_info_label = Label.new()
	_defense_info_label.add_theme_font_size_override("font_size", 12)
	_defense_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_main_container.add_child(_defense_info_label)

	# Separator
	var sep1 = HSeparator.new()
	_main_container.add_child(sep1)

	# Current garrison section
	var garrison_label = Label.new()
	garrison_label.text = "Current Garrison:"
	garrison_label.add_theme_font_size_override("font_size", 14)
	garrison_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	_main_container.add_child(garrison_label)

	var garrison_scroll = ScrollContainer.new()
	garrison_scroll.custom_minimum_size = Vector2(0, 120)
	_main_container.add_child(garrison_scroll)

	_current_garrison_container = VBoxContainer.new()
	_current_garrison_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garrison_scroll.add_child(_current_garrison_container)

	# Separator
	var sep2 = HSeparator.new()
	_main_container.add_child(sep2)

	# Available gods section
	var available_label = Label.new()
	available_label.text = "Available Gods:"
	available_label.add_theme_font_size_override("font_size", 14)
	available_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	_main_container.add_child(available_label)

	var available_scroll = ScrollContainer.new()
	available_scroll.custom_minimum_size = Vector2(0, 120)
	_main_container.add_child(available_scroll)

	_available_gods_container = VBoxContainer.new()
	_available_gods_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_scroll.add_child(_available_gods_container)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_container.add_child(spacer)

	# Close button
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	_close_button.pressed.connect(_on_close_pressed)
	_setup_button_style(_close_button)
	_main_container.add_child(_close_button)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func show_garrison(hex_node: HexNode) -> void:
	"""Show garrison management for a node"""
	if not hex_node:
		push_error("GarrisonManagementPanel: Cannot show garrison for null node")
		return

	current_node = hex_node
	_selected_god_id = ""
	_refresh_display()
	visible = true

func hide_panel() -> void:
	"""Hide the garrison management panel"""
	current_node = null
	_selected_god_id = ""
	visible = false

func refresh() -> void:
	"""Refresh the display with current data"""
	if current_node:
		_refresh_display()

# ==============================================================================
# INTERNAL METHODS
# ==============================================================================

func _refresh_display() -> void:
	"""Refresh all UI elements"""
	if not current_node:
		return

	_update_defense_info()
	_update_current_garrison()
	_update_available_gods()

func _update_defense_info() -> void:
	"""Update defense rating display"""
	if not territory_manager or not current_node:
		_defense_info_label.text = "Defense Rating: Unknown"
		return

	var defense_rating = territory_manager.get_node_defense_rating(current_node.coord)
	var distance_penalty = territory_manager.calculate_distance_penalty(current_node.coord)
	var connected_bonus = territory_manager.get_connected_bonus(current_node.coord)

	_defense_info_label.text = "Defense Rating: %.0f | Distance Penalty: -%.0f%% | Connected Bonus: +%.0f%%" % [
		defense_rating,
		distance_penalty * 100,
		connected_bonus * 100
	]

func _update_current_garrison() -> void:
	"""Update current garrison display"""
	# Clear existing
	for child in _current_garrison_container.get_children():
		child.queue_free()

	if not current_node or not collection_manager:
		return

	# Show empty state
	if current_node.garrison.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No gods in garrison (%d/%d)" % [0, current_node.max_garrison]
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_current_garrison_container.add_child(empty_label)
		return

	# Show garrison count
	var count_label = Label.new()
	count_label.text = "Garrison (%d/%d):" % [current_node.garrison.size(), current_node.max_garrison]
	count_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	_current_garrison_container.add_child(count_label)

	# Show each garrison god
	for god_id in current_node.garrison:
		var garrison_god = collection_manager.get_god_by_id(god_id)
		if not garrison_god:
			continue

		var god_row = _create_garrison_god_row(garrison_god)
		_current_garrison_container.add_child(god_row)

func _create_garrison_god_row(garrison_god: God) -> HBoxContainer:
	"""Create a row displaying a garrison god with unassign button"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ITEM_HEIGHT)

	# God info
	var info_label = Label.new()
	var power = _calculate_god_power(garrison_god)
	info_label.text = "%s (Lv%d) - Power: %.0f" % [garrison_god.god_name, garrison_god.level, power]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_label)

	# Unassign button
	var unassign_btn = Button.new()
	unassign_btn.text = "Remove"
	unassign_btn.custom_minimum_size = Vector2(80, 0)
	unassign_btn.pressed.connect(_on_unassign_garrison_pressed.bind(garrison_god.id))
	_setup_button_style(unassign_btn)
	row.add_child(unassign_btn)

	return row

func _update_available_gods() -> void:
	"""Update available gods display"""
	# Clear existing
	for child in _available_gods_container.get_children():
		child.queue_free()

	if not collection_manager or not current_node:
		return

	var available_gods_list = _get_available_gods()

	# Show empty state
	if available_gods_list.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No gods available for garrison"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_available_gods_container.add_child(empty_label)
		return

	# Show each available god
	for available_god in available_gods_list:
		var god_row = _create_available_god_row(available_god)
		_available_gods_container.add_child(god_row)

func _create_available_god_row(available_god: God) -> HBoxContainer:
	"""Create a row displaying an available god with assign button"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ITEM_HEIGHT)

	# Highlight if selected
	var selected = (_selected_god_id == available_god.id)
	if selected:
		var bg = Panel.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.4, 0.6, 0.3)
		bg.add_theme_stylebox_override("panel", style)
		row.add_child(bg)

	# God info
	var info_label = Label.new()
	var power = _calculate_god_power(available_god)
	info_label.text = "%s (Lv%d) - Power: %.0f" % [available_god.god_name, available_god.level, power]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_label)

	# Assign button
	var assign_btn = Button.new()
	assign_btn.text = "Assign"
	assign_btn.custom_minimum_size = Vector2(80, 0)
	assign_btn.pressed.connect(_on_assign_garrison_pressed.bind(available_god.id))

	# Disable if garrison full
	if current_node and current_node.garrison.size() >= current_node.max_garrison:
		assign_btn.disabled = true

	_setup_button_style(assign_btn)
	row.add_child(assign_btn)

	return row

# ==============================================================================
# HELPER METHODS
# ==============================================================================

func _get_available_gods() -> Array:
	"""Get list of gods available for garrison (not in garrison/working)"""
	if not collection_manager:
		return []

	var all_gods = collection_manager.get_all_gods()
	var available = []

	for god_data in all_gods:
		# Skip if in garrison at ANY node
		if _is_god_in_any_garrison(god_data.id):
			continue

		# Skip if working at ANY node
		if _is_god_working_anywhere(god_data.id):
			continue

		available.append(god_data)

	return available

func _is_god_in_any_garrison(god_id: String) -> bool:
	"""Check if god is in garrison at any node"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	if not hex_grid_manager:
		return false

	var all_nodes = hex_grid_manager.get_all_nodes()
	for node in all_nodes:
		if node.garrison.find(god_id) != -1:
			return true

	return false

func _is_god_working_anywhere(god_id: String) -> bool:
	"""Check if god is working at any node"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	if not hex_grid_manager:
		return false

	var all_nodes = hex_grid_manager.get_all_nodes()
	for node in all_nodes:
		if node.assigned_workers.find(god_id) != -1:
			return true

	return false

func _calculate_god_power(god_data: God) -> float:
	"""Calculate combat power of a god"""
	if not god_data:
		return 0.0

	# Use GodCalculator for consistent power calculation
	var calculator = SystemRegistry.get_instance().get_system("GodCalculator")
	if calculator and calculator.has_method("get_power_rating"):
		return calculator.get_power_rating(god_data)

	# Fallback if calculator not available
	var base_power = god_data.base_hp + god_data.base_attack * 2.0 + god_data.base_defense * 1.5
	var level_multiplier = 1.0 + (god_data.level - 1) * 0.1
	return base_power * level_multiplier

# ==============================================================================
# BUTTON HANDLERS
# ==============================================================================

func _on_assign_garrison_pressed(god_id: String) -> void:
	"""Handle assign button press"""
	if not current_node:
		return

	# Check garrison space
	if current_node.garrison.size() >= current_node.max_garrison:
		push_warning("GarrisonManagementPanel: Garrison is full")
		return

	# Add to garrison
	current_node.garrison.append(god_id)

	# Emit signal
	garrison_assigned.emit(current_node, god_id)

	# Refresh display
	_refresh_display()

func _on_unassign_garrison_pressed(god_id: String) -> void:
	"""Handle unassign button press"""
	if not current_node:
		return

	# Remove from garrison
	var idx = current_node.garrison.find(god_id)
	if idx >= 0:
		current_node.garrison.remove_at(idx)

		# Emit signal
		garrison_unassigned.emit(current_node, god_id)

		# Refresh display
		_refresh_display()

func _on_close_pressed() -> void:
	"""Handle close button press"""
	hide_panel()
	close_requested.emit()

# ==============================================================================
# STYLING
# ==============================================================================

func _setup_button_style(button: Button) -> void:
	"""Apply consistent button styling"""
	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.3, 0.5)
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.4, 0.6)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed state
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.25, 0.45)
	pressed_style.corner_radius_top_left = 4
	pressed_style.corner_radius_top_right = 4
	pressed_style.corner_radius_bottom_left = 4
	pressed_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("pressed", pressed_style)

	# Disabled state
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.15, 0.15, 0.15)
	disabled_style.corner_radius_top_left = 4
	disabled_style.corner_radius_top_right = 4
	disabled_style.corner_radius_bottom_left = 4
	disabled_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("disabled", disabled_style)

	# Text color
	button.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
