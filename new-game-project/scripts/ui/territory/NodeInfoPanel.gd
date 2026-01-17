# scripts/ui/territory/NodeInfoPanel.gd
# Info display panel for selected hex node
extends Control
class_name NodeInfoPanel

"""
NodeInfoPanel.gd - Display details for selected hex node
RULE 2: Single responsibility - ONLY displays node information and action buttons
RULE 1: Under 500 lines

Shows:
- Node name, type, tier
- Production rates
- Garrison (gods defending)
- Workers (gods on tasks)
- Defense rating with distance penalty
- Requirements if locked
- Action buttons: Capture, Manage Workers, Manage Garrison
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal capture_requested(hex_node: HexNode)
signal manage_workers_requested(hex_node: HexNode)
signal manage_garrison_requested(hex_node: HexNode)
signal close_requested()

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_node: HexNode = null
var is_locked: bool = false

# System references
var territory_manager = null
var production_manager = null
var collection_manager = null
var node_requirement_checker = null

# UI components
var _main_container: VBoxContainer = null
var _header_label: Label = null
var _type_tier_label: Label = null
var _production_container: VBoxContainer = null
var _garrison_container: VBoxContainer = null
var _workers_container: VBoxContainer = null
var _defense_label: Label = null
var _requirements_container: VBoxContainer = null
var _action_buttons: HBoxContainer = null

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH = 350
const PANEL_HEIGHT = 500
const BUTTON_HEIGHT = 40

# Colors matching HexTile
const COLOR_LOCKED = Color(0.15, 0.15, 0.15, 0.9)
const COLOR_NEUTRAL = Color(0.3, 0.3, 0.35, 0.9)
const COLOR_CONTROLLED = Color(0.2, 0.5, 0.3, 0.9)

const TIER_COLORS = {
	1: Color(0.6, 0.6, 0.6, 1),
	2: Color(0.3, 0.8, 0.3, 1),
	3: Color(0.3, 0.5, 1.0, 1),
	4: Color(0.8, 0.3, 1.0, 1),
	5: Color(1.0, 0.6, 0.0, 1)
}

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
		push_error("NodeInfoPanel: SystemRegistry not available")
		return

	territory_manager = registry.get_system("TerritoryManager")
	production_manager = registry.get_system("TerritoryProductionManager")
	collection_manager = registry.get_system("CollectionManager")
	node_requirement_checker = registry.get_system("NodeRequirementChecker")

	if not territory_manager:
		push_error("NodeInfoPanel: TerritoryManager not found")
	if not production_manager:
		push_error("NodeInfoPanel: TerritoryProductionManager not found")
	if not collection_manager:
		push_error("NodeInfoPanel: CollectionManager not found")
	if not node_requirement_checker:
		push_error("NodeInfoPanel: NodeRequirementChecker not found")

func _build_ui() -> void:
	"""Build the UI components"""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.3, 0.35, 1)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Main scroll container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	add_child(scroll)

	# Main container
	_main_container = VBoxContainer.new()
	_main_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_main_container)

	# Header section
	_build_header()

	# Separator
	_add_separator()

	# Production section
	_build_production_section()

	# Garrison section
	_build_garrison_section()

	# Workers section
	_build_workers_section()

	# Defense section
	_build_defense_section()

	# Requirements section (shown when locked)
	_build_requirements_section()

	# Separator
	_add_separator()

	# Action buttons
	_build_action_buttons()

func _build_header() -> void:
	"""Build header with name and type"""
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", Color.WHITE)
	_main_container.add_child(_header_label)

	_type_tier_label = Label.new()
	_type_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_tier_label.add_theme_font_size_override("font_size", 14)
	_type_tier_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	_main_container.add_child(_type_tier_label)

func _build_production_section() -> void:
	"""Build production info section"""
	var section_label = _create_section_label("Production")
	_main_container.add_child(section_label)

	_production_container = VBoxContainer.new()
	_production_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_production_container)

func _build_garrison_section() -> void:
	"""Build garrison info section"""
	var section_label = _create_section_label("Garrison")
	_main_container.add_child(section_label)

	_garrison_container = VBoxContainer.new()
	_garrison_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_garrison_container)

func _build_workers_section() -> void:
	"""Build workers info section"""
	var section_label = _create_section_label("Workers")
	_main_container.add_child(section_label)

	_workers_container = VBoxContainer.new()
	_workers_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_workers_container)

func _build_defense_section() -> void:
	"""Build defense info section"""
	var section_label = _create_section_label("Defense")
	_main_container.add_child(section_label)

	_defense_label = Label.new()
	_defense_label.add_theme_font_size_override("font_size", 12)
	_defense_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	_main_container.add_child(_defense_label)

func _build_requirements_section() -> void:
	"""Build requirements section (shown when locked)"""
	var section_label = _create_section_label("Requirements")
	_main_container.add_child(section_label)

	_requirements_container = VBoxContainer.new()
	_requirements_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_requirements_container)

func _build_action_buttons() -> void:
	"""Build action buttons"""
	_action_buttons = HBoxContainer.new()
	_action_buttons.add_theme_constant_override("separation", 10)
	_action_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_container.add_child(_action_buttons)

func _create_section_label(text: String) -> Label:
	"""Create a section header label"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
	return label

func _add_separator() -> void:
	"""Add a horizontal separator"""
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	_main_container.add_child(separator)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func show_node(hex_node: HexNode, locked: bool = false) -> void:
	"""Show panel with node data"""
	current_node = hex_node
	is_locked = locked

	if not current_node:
		hide_panel()
		return

	_update_all_displays()
	visible = true

func hide_panel() -> void:
	"""Hide the panel"""
	current_node = null
	visible = false

func refresh() -> void:
	"""Refresh the display with current node data"""
	if current_node:
		_update_all_displays()

# ==============================================================================
# PRIVATE METHODS - Display Updates
# ==============================================================================
func _update_all_displays() -> void:
	"""Update all display sections"""
	_update_header()
	_update_production()
	_update_garrison()
	_update_workers()
	_update_defense()
	_update_requirements()
	_update_action_buttons()

func _update_header() -> void:
	"""Update header labels"""
	if not current_node:
		return

	_header_label.text = current_node.name

	var tier_stars = ""
	for i in range(current_node.tier):
		tier_stars += "★"

	var type_display = current_node.node_type.replace("_", " ").capitalize()
	_type_tier_label.text = "%s - %s" % [type_display, tier_stars]

	var tier_color = TIER_COLORS.get(current_node.tier, Color.WHITE)
	_type_tier_label.add_theme_color_override("font_color", tier_color)

func _update_production() -> void:
	"""Update production display"""
	# Clear existing
	for child in _production_container.get_children():
		child.queue_free()

	if not current_node or not production_manager:
		var no_prod_label = Label.new()
		no_prod_label.text = "No production data"
		no_prod_label.add_theme_font_size_override("font_size", 12)
		_production_container.add_child(no_prod_label)
		return

	# Get production data
	var production_data = production_manager.calculate_node_production(current_node)

	if production_data.is_empty():
		var no_prod_label = Label.new()
		no_prod_label.text = "No active production"
		no_prod_label.add_theme_font_size_override("font_size", 12)
		_production_container.add_child(no_prod_label)
		return

	# Display each resource production
	for resource_id in production_data.keys():
		var amount = production_data[resource_id]
		var resource_label = Label.new()
		resource_label.text = "  %s: +%d/hour" % [resource_id.replace("_", " ").capitalize(), amount]
		resource_label.add_theme_font_size_override("font_size", 12)
		resource_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1))
		_production_container.add_child(resource_label)

func _update_garrison() -> void:
	"""Update garrison display"""
	# Clear existing
	for child in _garrison_container.get_children():
		child.queue_free()

	if not current_node:
		return

	var garrison_count = current_node.get_garrison_count()
	var max_garrison = current_node.max_garrison

	var header = Label.new()
	header.text = "Garrison: %d / %d" % [garrison_count, max_garrison]
	header.add_theme_font_size_override("font_size", 12)
	_garrison_container.add_child(header)

	# List garrison gods
	if garrison_count > 0 and collection_manager:
		for god_id in current_node.garrison:
			var god = collection_manager.get_god_by_id(god_id)
			if god:
				var god_label = Label.new()
				god_label.text = "  - %s (Lv %d)" % [god.name, god.level]
				god_label.add_theme_font_size_override("font_size", 11)
				god_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8, 1))
				_garrison_container.add_child(god_label)

func _update_workers() -> void:
	"""Update workers display"""
	# Clear existing
	for child in _workers_container.get_children():
		child.queue_free()

	if not current_node:
		return

	var worker_count = current_node.get_worker_count()
	var max_workers = current_node.max_workers

	var header = Label.new()
	header.text = "Workers: %d / %d" % [worker_count, max_workers]
	header.add_theme_font_size_override("font_size", 12)
	_workers_container.add_child(header)

	# List worker gods
	if worker_count > 0 and collection_manager:
		for god_id in current_node.assigned_workers:
			var god = collection_manager.get_god_by_id(god_id)
			if god:
				var god_label = Label.new()
				god_label.text = "  - %s (Lv %d)" % [god.name, god.level]
				god_label.add_theme_font_size_override("font_size", 11)
				god_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1))
				_workers_container.add_child(god_label)

func _update_defense() -> void:
	"""Update defense display"""
	if not current_node or not territory_manager:
		_defense_label.text = "Defense: N/A"
		return

	var defense_rating = territory_manager.get_node_defense_rating(current_node.coord)
	var distance_penalty = territory_manager.calculate_distance_penalty(current_node.coord)

	_defense_label.text = "Defense Rating: %.0f\nDistance Penalty: -%.0f%%" % [defense_rating, distance_penalty * 100]

func _update_requirements() -> void:
	"""Update requirements display (shown when locked)"""
	# Clear existing
	for child in _requirements_container.get_children():
		child.queue_free()

	_requirements_container.visible = is_locked

	if not is_locked or not current_node or not node_requirement_checker:
		return

	var missing_reqs = node_requirement_checker.get_missing_requirements(current_node)

	if missing_reqs.is_empty():
		var met_label = Label.new()
		met_label.text = "All requirements met!"
		met_label.add_theme_font_size_override("font_size", 12)
		met_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1))
		_requirements_container.add_child(met_label)
	else:
		for req_text in missing_reqs:
			var req_label = Label.new()
			req_label.text = "  ✗ %s" % req_text
			req_label.add_theme_font_size_override("font_size", 11)
			req_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
			_requirements_container.add_child(req_label)

func _update_action_buttons() -> void:
	"""Update action buttons based on node state"""
	# Clear existing buttons
	for child in _action_buttons.get_children():
		child.queue_free()

	if not current_node:
		return

	# Close button (always visible)
	var close_btn = _create_button("Close", Color(0.4, 0.4, 0.45, 1))
	close_btn.pressed.connect(_on_close_pressed)
	_action_buttons.add_child(close_btn)

	# Context-specific buttons
	if is_locked:
		# Locked node - no actions available
		pass
	elif current_node.is_controlled_by_player():
		# Player controlled - show management buttons
		var workers_btn = _create_button("Workers", Color(0.3, 0.6, 0.8, 1))
		workers_btn.pressed.connect(_on_manage_workers_pressed)
		_action_buttons.add_child(workers_btn)

		var garrison_btn = _create_button("Garrison", Color(0.6, 0.3, 0.3, 1))
		garrison_btn.pressed.connect(_on_manage_garrison_pressed)
		_action_buttons.add_child(garrison_btn)
	else:
		# Neutral/Enemy - show capture button
		var can_capture = node_requirement_checker and node_requirement_checker.can_player_capture_node(current_node)
		var capture_btn = _create_button("Capture", Color(0.2, 0.7, 0.3, 1))
		capture_btn.pressed.connect(_on_capture_pressed)
		capture_btn.disabled = not can_capture
		_action_buttons.add_child(capture_btn)

func _create_button(text: String, color: Color) -> Button:
	"""Create a styled button"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, BUTTON_HEIGHT)

	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = color
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", hover_style)

	# Disabled state
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.3, 0.3, 0.3, 1)
	disabled_style.corner_radius_top_left = 4
	disabled_style.corner_radius_top_right = 4
	disabled_style.corner_radius_bottom_left = 4
	disabled_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("disabled", disabled_style)

	return button

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================
func _on_capture_pressed() -> void:
	"""Handle capture button press"""
	if current_node:
		capture_requested.emit(current_node)

func _on_manage_workers_pressed() -> void:
	"""Handle manage workers button press"""
	if current_node:
		manage_workers_requested.emit(current_node)

func _on_manage_garrison_pressed() -> void:
	"""Handle manage garrison button press"""
	if current_node:
		manage_garrison_requested.emit(current_node)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_requested.emit()
	hide_panel()
