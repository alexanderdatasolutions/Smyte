# scripts/ui/territory/NodeInfoPanel.gd
# Info display panel for selected hex node
extends Control
class_name NodeInfoPanel

"""
NodeInfoPanel.gd - Display details for selected hex node with slot boxes
RULE 2: Single responsibility - ONLY displays node information with interactive slots
RULE 1: Under 500 lines

Shows:
- Node name, type, tier
- Production rates
- Garrison with slot boxes (60x60px tap targets)
- Workers with slot boxes (tier-based)
- Defense rating with combat power
- Requirements if locked
- Action buttons: Capture, Close
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal capture_requested(hex_node: HexNode)
signal close_requested()
signal slot_tapped(node: HexNode, slot_type: String, slot_index: int)
signal filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH = 380
const PANEL_HEIGHT = 600
const BUTTON_HEIGHT = 40
const SLOT_SIZE = 60  # 60x60px tap target (min requirement)
const SLOT_SPACING = 6
const MAX_GARRISON_SLOTS = 4

# Colors
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

const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1),
	God.ElementType.WATER: Color(0.2, 0.5, 0.9),
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2),
	God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0),
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3),
	God.ElementType.DARK: Color(0.5, 0.2, 0.6)
}

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
var node_production_info = null

# UI components
var _main_container: VBoxContainer = null
var _header_label: Label = null
var _type_tier_label: Label = null
var _pending_resources_container: VBoxContainer = null
var _production_container: VBoxContainer = null
var _garrison_container: VBoxContainer = null
var _workers_container: VBoxContainer = null
var _defense_label: Label = null
var _requirements_container: VBoxContainer = null
var _action_buttons: HBoxContainer = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_build_ui()
	_connect_signals()
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
	node_production_info = registry.get_system("NodeProductionInfo")

func _connect_signals() -> void:
	"""Connect to production update signals"""
	if production_manager:
		# Listen for production updates
		if production_manager.has_signal("production_updated"):
			production_manager.production_updated.connect(_on_production_updated)

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

	# Pending Resources section (above production)
	_build_pending_resources_section()

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

func _build_pending_resources_section() -> void:
	"""Build pending resources section with collect button"""
	var section_label = _create_section_label("Pending Resources")
	_main_container.add_child(section_label)

	_pending_resources_container = VBoxContainer.new()
	_pending_resources_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_pending_resources_container)

func _build_production_section() -> void:
	"""Build production info section"""
	var section_label = _create_section_label("Production")
	_main_container.add_child(section_label)

	_production_container = VBoxContainer.new()
	_production_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_production_container)

func _build_garrison_section() -> void:
	"""Build garrison info section with slot boxes"""
	var section_label = _create_section_label("Garrison (Defense)")
	_main_container.add_child(section_label)

	_garrison_container = VBoxContainer.new()
	_garrison_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_garrison_container)

func _build_workers_section() -> void:
	"""Build workers info section with slot boxes"""
	var section_label = _create_section_label("Workers (Production)")
	_main_container.add_child(section_label)

	_workers_container = VBoxContainer.new()
	_workers_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_workers_container)

func _build_defense_section() -> void:
	"""Build defense info section"""
	var section_label = _create_section_label("Combat Power")
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
	_update_pending_resources()
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

func _update_pending_resources() -> void:
	"""Update pending resources display with collect button"""
	# Clear existing
	for child in _pending_resources_container.get_children():
		child.queue_free()

	if not current_node:
		return

	# Only show for player-controlled nodes
	if not current_node.is_controlled_by_player():
		var not_available_label = Label.new()
		not_available_label.text = "  Capture node to accumulate resources"
		not_available_label.add_theme_font_size_override("font_size", 11)
		not_available_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_pending_resources_container.add_child(not_available_label)
		return

	# Check if there are accumulated resources
	if current_node.accumulated_resources.is_empty() or _get_total_accumulated() <= 0:
		var no_resources_label = Label.new()
		no_resources_label.text = "  No pending resources (assign workers to begin)"
		no_resources_label.add_theme_font_size_override("font_size", 11)
		no_resources_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
		_pending_resources_container.add_child(no_resources_label)
		return

	# Display accumulated resources
	for resource_id in current_node.accumulated_resources.keys():
		var amount = current_node.accumulated_resources[resource_id]
		if amount > 0:
			var resource_label = Label.new()
			resource_label.text = "  %s: %.1f" % [resource_id.replace("_", " ").capitalize(), amount]
			resource_label.add_theme_font_size_override("font_size", 12)
			resource_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7, 1))
			_pending_resources_container.add_child(resource_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_pending_resources_container.add_child(spacer)

	# Collect button
	var collect_btn = _create_button("Collect Resources", Color(0.3, 0.7, 0.4, 1))
	collect_btn.pressed.connect(_on_collect_resources_pressed)
	_pending_resources_container.add_child(collect_btn)

func _get_total_accumulated() -> float:
	"""Get total accumulated resources across all types"""
	if not current_node:
		return 0.0

	var total = 0.0
	for resource_id in current_node.accumulated_resources.keys():
		total += current_node.accumulated_resources[resource_id]
	return total

func _update_production() -> void:
	"""Update production display with bonuses breakdown"""
	# Clear existing
	for child in _production_container.get_children():
		child.queue_free()

	if not current_node:
		return

	# Show production category and type info
	if node_production_info and node_production_info.has_production_info(current_node.node_type):
		var category = node_production_info.get_node_production_category(current_node.node_type)
		var description = node_production_info.get_node_production_description(current_node.node_type)
		var focus = node_production_info.get_node_production_focus(current_node.node_type)
		var icon = node_production_info.get_node_icon(current_node.node_type)
		var category_color = node_production_info.get_category_color(category)

		# Production type header
		var type_label = Label.new()
		type_label.text = "%s %s" % [icon, node_production_info.get_category_name(category)]
		type_label.add_theme_font_size_override("font_size", 13)
		type_label.add_theme_color_override("font_color", category_color)
		_production_container.add_child(type_label)

		# Description
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(PANEL_WIDTH - 30, 0)
		_production_container.add_child(desc_label)

		# Focus
		var focus_label = Label.new()
		focus_label.text = "Produces: " + focus
		focus_label.add_theme_font_size_override("font_size", 11)
		focus_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
		_production_container.add_child(focus_label)

		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		_production_container.add_child(spacer)

	# Get production data and show hourly rates
	if production_manager and current_node.is_controlled_by_player():
		var production_data = production_manager.calculate_node_production(current_node)
		if not production_data.is_empty():
			# Display each resource production
			for resource_id in production_data.keys():
				var amount = production_data[resource_id]
				var resource_label = Label.new()
				resource_label.text = "  %s: +%.1f/hour" % [resource_id.replace("_", " ").capitalize(), amount]
				resource_label.add_theme_font_size_override("font_size", 12)
				resource_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1))
				_production_container.add_child(resource_label)

			# Spacer before bonuses
			var spacer2 = Control.new()
			spacer2.custom_minimum_size = Vector2(0, 4)
			_production_container.add_child(spacer2)

			# Show production bonuses breakdown
			_show_production_bonuses()
		else:
			# No production (no workers assigned)
			var no_prod_label = Label.new()
			no_prod_label.text = "  No production (assign workers)"
			no_prod_label.add_theme_font_size_override("font_size", 11)
			no_prod_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
			_production_container.add_child(no_prod_label)
	elif not current_node.is_controlled_by_player():
		# Not controlled by player
		var not_controlled_label = Label.new()
		not_controlled_label.text = "  Capture to enable production"
		not_controlled_label.add_theme_font_size_override("font_size", 11)
		not_controlled_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
		_production_container.add_child(not_controlled_label)

func _show_production_bonuses() -> void:
	"""Show breakdown of production bonuses"""
	if not current_node or not production_manager:
		return

	# Bonuses header
	var bonuses_label = Label.new()
	bonuses_label.text = "Bonuses:"
	bonuses_label.add_theme_font_size_override("font_size", 11)
	bonuses_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_production_container.add_child(bonuses_label)

	# Upgrade bonus
	if current_node.production_level > 1:
		var upgrade_bonus = (current_node.production_level - 1) * 0.10
		var upgrade_label = Label.new()
		upgrade_label.text = "  +%.0f%% Upgrade (Level %d)" % [upgrade_bonus * 100, current_node.production_level]
		upgrade_label.add_theme_font_size_override("font_size", 10)
		upgrade_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		_production_container.add_child(upgrade_label)

	# Connected bonus
	if territory_manager:
		var connected_count = territory_manager.get_connected_node_count(current_node.coord)
		var connected_bonus = 0.0
		if connected_count >= 4:
			connected_bonus = 0.30
		elif connected_count == 3:
			connected_bonus = 0.20
		elif connected_count == 2:
			connected_bonus = 0.10

		if connected_bonus > 0:
			var connected_label = Label.new()
			connected_label.text = "  +%.0f%% Connected (%d nodes)" % [connected_bonus * 100, connected_count]
			connected_label.add_theme_font_size_override("font_size", 10)
			connected_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			_production_container.add_child(connected_label)

	# Worker efficiency bonus
	if not current_node.assigned_workers.is_empty():
		var worker_efficiency = _calculate_worker_efficiency_display()
		if worker_efficiency > 0:
			var worker_label = Label.new()
			worker_label.text = "  +%.0f%% Workers (%d assigned)" % [worker_efficiency * 100, current_node.assigned_workers.size()]
			worker_label.add_theme_font_size_override("font_size", 10)
			worker_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
			_production_container.add_child(worker_label)

func _calculate_worker_efficiency_display() -> float:
	"""Calculate total worker efficiency for display purposes"""
	if not current_node or not collection_manager:
		return 0.0

	var total_efficiency = 0.0
	for worker_id in current_node.assigned_workers:
		var god = collection_manager.get_god_by_id(worker_id)
		if god:
			# Base 10% per worker
			var efficiency = 0.10

			# Add level bonus (1% per level)
			efficiency += god.level * 0.01

			# TODO: Add specialization bonus when SpecializationManager is available
			# For now, just use base + level

			total_efficiency += efficiency

	return total_efficiency

func _update_garrison() -> void:
	"""Update garrison display WITH SLOT BOXES"""
	# Clear existing
	for child in _garrison_container.get_children():
		child.queue_free()

	if not current_node:
		return

	# Create slot boxes
	var slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", SLOT_SPACING)
	_garrison_container.add_child(slots_row)

	for i in range(MAX_GARRISON_SLOTS):
		var slot: Control
		if i < current_node.garrison.size():
			var god = _get_god_by_id(current_node.garrison[i])
			slot = _create_filled_slot(current_node, "garrison", i, god)
		else:
			slot = _create_empty_slot(current_node, "garrison", i)
		slots_row.add_child(slot)

func _update_workers() -> void:
	"""Update workers display WITH SLOT BOXES"""
	# Clear existing
	for child in _workers_container.get_children():
		child.queue_free()

	if not current_node:
		return

	# Show optimal god recommendations
	if node_production_info and node_production_info.has_production_info(current_node.node_type):
		var optimal_stats = node_production_info.get_node_optimal_stats(current_node.node_type)
		var optimal_traits = node_production_info.get_node_optimal_traits(current_node.node_type)

		if not optimal_stats.is_empty() or not optimal_traits.is_empty():
			var rec_label = Label.new()
			rec_label.text = "Best workers:"
			rec_label.add_theme_font_size_override("font_size", 11)
			rec_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			_workers_container.add_child(rec_label)

			if not optimal_stats.is_empty():
				var stats_label = Label.new()
				var stats_text = "  High "
				for i in range(optimal_stats.size()):
					stats_text += optimal_stats[i].to_upper()
					if i < optimal_stats.size() - 1:
						stats_text += ", "
				stats_label.text = stats_text
				stats_label.add_theme_font_size_override("font_size", 10)
				stats_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
				_workers_container.add_child(stats_label)

			if not optimal_traits.is_empty():
				var traits_label = Label.new()
				var traits_text = "  Traits: "
				for i in range(optimal_traits.size()):
					traits_text += optimal_traits[i].replace("_", " ").capitalize()
					if i < optimal_traits.size() - 1:
						traits_text += ", "
				traits_label.text = traits_text
				traits_label.add_theme_font_size_override("font_size", 10)
				traits_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
				_workers_container.add_child(traits_label)

			# Spacer
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 6)
			_workers_container.add_child(spacer)

	var max_workers = mini(current_node.tier, 5)

	if max_workers == 0:
		var no_lbl = Label.new()
		no_lbl.text = "Not available (Tier 0)"
		no_lbl.add_theme_font_size_override("font_size", 11)
		no_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_workers_container.add_child(no_lbl)
		return

	# Create slot boxes
	var slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", SLOT_SPACING)
	_workers_container.add_child(slots_row)

	for i in range(max_workers):
		var slot: Control
		if i < current_node.assigned_workers.size():
			var god = _get_god_by_id(current_node.assigned_workers[i])
			slot = _create_filled_slot(current_node, "worker", i, god)
		else:
			slot = _create_empty_slot(current_node, "worker", i)
		slots_row.add_child(slot)

func _update_defense() -> void:
	"""Update combat power display"""
	if not current_node or not territory_manager:
		_defense_label.text = "Defense: N/A"
		return

	var defense_rating = territory_manager.get_node_defense_rating(current_node.coord)
	var distance_penalty = territory_manager.calculate_distance_penalty(current_node.coord)

	_defense_label.text = "Rating: %.0f | Distance Penalty: -%.0f%%" % [defense_rating, distance_penalty * 100]

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
	if not is_locked and not current_node.is_controlled_by_player():
		# Neutral/Enemy - show capture button
		var can_capture = node_requirement_checker and node_requirement_checker.can_player_capture_node(current_node)
		var capture_btn = _create_button("Capture", Color(0.2, 0.7, 0.3, 1))
		capture_btn.pressed.connect(_on_capture_pressed)
		capture_btn.disabled = not can_capture
		_action_buttons.add_child(capture_btn)

# ==============================================================================
# SLOT CREATION METHODS (copied from TerritoryOverviewScreen)
# ==============================================================================
func _create_empty_slot(node: HexNode, slot_type: String, slot_index: int) -> Control:
	"""Create an empty slot with '+' icon (60x60px tap target)"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.add_theme_stylebox_override("panel", _create_slot_style(Color(0.4, 0.4, 0.45, 0.7), 2))

	# Plus icon
	var plus_label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 24)
	plus_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plus_label)

	# Tappable button
	_add_slot_button(slot, node, slot_type, slot_index)
	return slot

func _create_filled_slot(node: HexNode, slot_type: String, slot_index: int, god: God) -> Control:
	"""Create a filled slot showing god portrait (60x60px)"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var border_color = ELEMENT_COLORS.get(god.element, Color.GRAY) if god else Color(0.5, 0.5, 0.5)
	slot.add_theme_stylebox_override("panel", _create_slot_style(border_color, 3))

	if god:
		var portrait = _create_god_portrait(god)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 4
		portrait.offset_right = -4
		portrait.offset_top = 4
		portrait.offset_bottom = -14
		slot.add_child(portrait)

		var level_label = Label.new()
		level_label.text = "Lv.%d" % god.level
		level_label.add_theme_font_size_override("font_size", 9)
		level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.anchor_left = 0
		level_label.anchor_right = 1
		level_label.anchor_top = 1
		level_label.anchor_bottom = 1
		level_label.offset_top = -14
		level_label.offset_bottom = -2
		slot.add_child(level_label)
	else:
		var lbl = Label.new()
		lbl.text = "?"
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(lbl)

	# Use filled slot handler for filled slots
	_add_filled_slot_button(slot, node, slot_type, slot_index, god)
	return slot

func _create_slot_style(border_color: Color, border_width: int) -> StyleBoxFlat:
	"""Create slot panel style"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style

func _add_slot_button(slot: Panel, node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Add tappable button overlay to empty slot"""
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_slot_tapped.bind(node, slot_type, slot_index))
	slot.add_child(button)

func _add_filled_slot_button(slot: Panel, node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Add tappable button overlay to filled slot (emits different signal)"""
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_filled_slot_tapped.bind(node, slot_type, slot_index, god))
	slot.add_child(button)

func _create_god_portrait(god: God) -> TextureRect:
	"""Create god portrait TextureRect"""
	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
		var image = Image.create(50, 50, false, Image.FORMAT_RGBA8)
		image.fill(element_color)
		portrait.texture = ImageTexture.create_from_image(image)
	return portrait

func _get_god_by_id(god_id: String) -> God:
	"""Get god by ID from CollectionManager"""
	if not collection_manager:
		return null
	if god_id == "":
		return null
	return collection_manager.get_god_by_id(god_id)

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
func _on_production_updated(territory_id: String, _new_rate: int) -> void:
	"""Handle production update signal - refresh display if this is our node"""
	if current_node and current_node.id == territory_id:
		_update_production()
		_update_pending_resources()

func _on_capture_pressed() -> void:
	"""Handle capture button press"""
	if current_node:
		capture_requested.emit(current_node)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_requested.emit()
	hide_panel()

func _on_slot_tapped(node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Handle empty slot tap - emit signal for parent to open god selection"""
	print("NodeInfoPanel: Empty slot tapped - node: %s, type: %s, index: %d" % [node.id, slot_type, slot_index])
	slot_tapped.emit(node, slot_type, slot_index)

func _on_filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Handle filled slot tap - emit signal for parent to show remove confirmation"""
	print("NodeInfoPanel: Filled slot tapped - node: %s, type: %s, index: %d, god: %s" % [node.id, slot_type, slot_index, god.name if god else "null"])
	filled_slot_tapped.emit(node, slot_type, slot_index, god)

func _on_collect_resources_pressed() -> void:
	"""Handle collect resources button press"""
	if not current_node or not production_manager:
		print("NodeInfoPanel: Cannot collect - missing node or production manager")
		return

	# Call production manager to collect resources
	var collected = production_manager.collect_node_resources(current_node.id)

	if collected.is_empty():
		print("NodeInfoPanel: No resources collected from node %s" % current_node.id)
		_show_collection_feedback("No resources to collect", Color(0.8, 0.6, 0.4))
	else:
		# Format collected resources for display
		var message = "Collected:\n"
		for resource_id in collected.keys():
			message += "%s: %.1f\n" % [resource_id.replace("_", " ").capitalize(), collected[resource_id]]

		print("NodeInfoPanel: Collected resources from node %s: %s" % [current_node.id, str(collected)])
		_show_collection_feedback(message, Color(0.3, 0.9, 0.4))

		# Refresh the display to show updated (cleared) accumulated resources
		_update_pending_resources()

func _show_collection_feedback(message: String, color: Color) -> void:
	"""Show a temporary feedback message about collection"""
	# Create a temporary label that fades out
	var feedback_label = Label.new()
	feedback_label.text = message
	feedback_label.add_theme_font_size_override("font_size", 13)
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pending_resources_container.add_child(feedback_label)

	# Remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(feedback_label):
		feedback_label.queue_free()
