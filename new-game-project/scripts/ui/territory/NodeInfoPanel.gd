# scripts/ui/territory/NodeInfoPanel.gd
# Info display panel for selected hex node
extends Control
class_name NodeInfoPanel

"""
NodeInfoPanel.gd - Display details for selected hex node with slot boxes
RULE 2: Single responsibility - ONLY displays node information with interactive slots
RULE 1: Under 500 lines

Shows:
	pass
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
signal task_started(node: HexNode, task_id: String)
signal select_building_requested(hex_node: HexNode)
signal demolish_building_requested(hex_node: HexNode)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH = 380
const PANEL_HEIGHT = 600
const BUTTON_HEIGHT = 40
const SLOT_SIZE = 54  # Slightly smaller to fit 5 slots with spacing
const SLOT_SPACING = 4
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
var resource_manager = null
var hex_grid_manager = null  # For shared craft tracking
var building_manager = null  # For building data (crafting_enabled check)
var _craft_progress_container: VBoxContainer = null

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
var _tasks_container: VBoxContainer = null
var _craft_popup: Control = null
var _crafting_screen_manager: CraftingScreenManager = null
var _action_buttons: HBoxContainer = null

# Cached task data
var _available_tasks: Array = []
var _tasks_data: Dictionary = {}

# Attack timer UI references for live updates
var _attack_timer_progress_bar: ProgressBar = null
var _attack_timer_label: Label = null
var _attack_timer_fill_style: StyleBoxFlat = null
var _attack_timer_update_timer: float = 0.0

# ==============================================================================
# INITIALIZATION
# ==============================================================================
var _craft_update_timer: float = 0.0

func _ready() -> void:
	_init_systems()
	_build_ui()
	_connect_signals()
	visible = false  # Start hidden

func _process(delta: float) -> void:
	# Update crafting progress every second
	if not visible:
		return

	# Update attack timer display every second
	_attack_timer_update_timer += delta
	if _attack_timer_update_timer >= 1.0:
		_attack_timer_update_timer = 0.0
		_update_attack_timer_display()

	# Check for active crafts from shared tracker
	var has_active: bool = false
	if hex_grid_manager and current_node:
		has_active = not hex_grid_manager.get_active_crafts_for_node(current_node.id).is_empty()

	if not has_active:
		return

	_craft_update_timer += delta
	if _craft_update_timer >= 1.0:
		_craft_update_timer = 0.0
		_update_tasks()

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
	resource_manager = registry.get_system("ResourceManager")
	hex_grid_manager = registry.get_system("HexGridManager")
	building_manager = registry.get_system("BuildingManager")

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
	var bg_panel: Panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
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
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MainScrollContainer"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure it receives scroll events
	add_child(scroll)

	# Main container
	_main_container = VBoxContainer.new()
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	# Tasks/Crafting section (for forges with workers)
	_build_tasks_section()

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

func _build_tasks_section() -> void:
	"""Build tasks/crafting section (shown for forges with workers)"""
	var section_label = _create_section_label("⚒️ Crafting")
	section_label.name = "TasksSectionLabel"
	_main_container.add_child(section_label)

	_tasks_container = VBoxContainer.new()
	_tasks_container.name = "TasksContainer"
	_tasks_container.add_theme_constant_override("separation", 6)
	_main_container.add_child(_tasks_container)

	# Load tasks data
	_load_tasks_data()

func _build_action_buttons() -> void:
	"""Build action buttons"""
	_action_buttons = HBoxContainer.new()
	_action_buttons.add_theme_constant_override("separation", 10)
	_action_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_container.add_child(_action_buttons)

func _create_section_label(text: String) -> Label:
	"""Create a section header label"""
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
	return label

func _add_separator() -> void:
	"""Add a horizontal separator"""
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	_main_container.add_child(separator)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func show_node(hex_node: HexNode, locked: bool = false) -> void:
	"""Show panel with node data"""
	current_node = hex_node
	is_locked = locked

	# Clear attack timer references (will be recreated in _update_all_displays)
	_attack_timer_progress_bar = null
	_attack_timer_label = null
	_attack_timer_fill_style = null

	if not current_node:
		hide_panel()
		return

	_update_all_displays()
	visible = true

	# Check for garrison tutorial when showing a controlled node with no garrison
	_check_garrison_tutorial()

func hide_panel() -> void:
	"""Hide the panel"""
	current_node = null
	visible = false

func refresh() -> void:
	"""Refresh the display with current node data"""
	if current_node:
		_update_all_displays()

func check_pending_tutorial() -> void:
	"""Check for and show any pending tutorial highlights for node_info screen."""
	call_deferred("_check_node_info_tutorial")

func show_crafting_tab() -> void:
	"""Public method to open the crafting popup for the current node.
	Called externally when navigating to forge via craft button."""
	if not current_node:
		return

	# Only show crafting for forge-type nodes
	if current_node.node_type != "forge":
		return

	# Open the crafting popup
	_show_craft_popup()

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
	_update_tasks()
	_update_action_buttons()

func _update_header() -> void:
	"""Update header labels"""
	if not current_node:
		return

	_header_label.text = current_node.name

	var tier_stars: String = ""
	for i in range(current_node.tier):
		tier_stars += "★"

	# Use get_node_type_display() which handles buildings properly
	var type_display = current_node.get_node_type_display()
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
		var not_available_label: Label = Label.new()
		not_available_label.text = "  Capture node to accumulate resources"
		not_available_label.add_theme_font_size_override("font_size", 11)
		not_available_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_pending_resources_container.add_child(not_available_label)
		return

	# Check if there are accumulated resources
	if current_node.accumulated_resources.is_empty() or _get_total_accumulated() <= 0:
		var no_resources_label: Label = Label.new()
		no_resources_label.text = "  No pending resources (assign workers to begin)"
		no_resources_label.add_theme_font_size_override("font_size", 11)
		no_resources_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
		_pending_resources_container.add_child(no_resources_label)
		return

	# Check if we're approaching max storage
	var time_since_last_production: float = 0.0
	if current_node.last_production_time > 0:
		var current_time: int = int(Time.get_unix_time_from_system())
		time_since_last_production = (current_time - current_node.last_production_time) / 3600.0

	# Get max storage hours from config
	var max_storage_hours: float = TerritoryProductionManager.get_max_storage_hours()

	# Show warning if at or near max storage
	if time_since_last_production >= max_storage_hours:
		var warning_label: Label = Label.new()
		warning_label.text = "  ⚠️ Max storage reached (%.0f hours)" % max_storage_hours
		warning_label.add_theme_font_size_override("font_size", 11)
		warning_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		_pending_resources_container.add_child(warning_label)

		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		_pending_resources_container.add_child(spacer)

	# Display accumulated resources
	for resource_id in current_node.accumulated_resources.keys():
		var amount = current_node.accumulated_resources[resource_id]
		if amount > 0:
			var resource_label: Label = Label.new()
			resource_label.text = "  %s: %.1f" % [resource_id.replace("_", " ").capitalize(), amount]
			resource_label.add_theme_font_size_override("font_size", 12)
			resource_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7, 1))
			_pending_resources_container.add_child(resource_label)

	# Spacer
	var spacer: Control = Control.new()
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

	var total: float = 0.0
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
		var type_label: Label = Label.new()
		type_label.text = "%s %s" % [icon, node_production_info.get_category_name(category)]
		type_label.add_theme_font_size_override("font_size", 13)
		type_label.add_theme_color_override("font_color", category_color)
		_production_container.add_child(type_label)

		# Description
		var desc_label: Label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(PANEL_WIDTH - 30, 0)
		_production_container.add_child(desc_label)

		# Focus
		var focus_label: Label = Label.new()
		focus_label.text = "Produces: " + focus
		focus_label.add_theme_font_size_override("font_size", 11)
		focus_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
		_production_container.add_child(focus_label)

		# Spacer
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		_production_container.add_child(spacer)

	# Get production data and show hourly rates
	if production_manager and current_node.is_controlled_by_player():
		var production_data = production_manager.calculate_node_production(current_node)
		if not production_data.is_empty():
			# Check if this is a processing building with consumes
			var building_consumes: Dictionary = {}
			if not current_node.placed_building.is_empty() and building_manager:
				var building = building_manager.get_building(current_node.placed_building)
				building_consumes = building.get("consumes", {})

			if not building_consumes.is_empty():
				# Show conversion format for processing buildings
				var input_parts: Array = []
				var output_parts: Array = []
				for res_id in building_consumes:
					input_parts.append("%d %s" % [building_consumes[res_id], res_id.replace("_", " ")])
				for res_id in production_data.keys():
					output_parts.append("%.0f %s" % [production_data[res_id], res_id.replace("_", " ")])

				var convert_label: Label = Label.new()
				convert_label.text = "  Converts: %s → %s/hr" % [", ".join(input_parts), ", ".join(output_parts)]
				convert_label.add_theme_font_size_override("font_size", 12)
				convert_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Orange for conversion
				_production_container.add_child(convert_label)

				# Show input resource availability
				var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
				var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
				var status_parts: Array = []
				var all_available: bool = true

				for res_id in building_consumes:
					var needed = building_consumes[res_id]
					var available_accumulated: float = 0.0
					var available_inventory: int = 0

					# Count accumulated across all player nodes
					if hex_grid_manager:
						for check_node in hex_grid_manager.get_player_nodes():
							available_accumulated += check_node.accumulated_resources.get(res_id, 0)

					if resource_manager:
						available_inventory = resource_manager.get_resource(res_id)

					var total = available_accumulated + available_inventory
					var has_enough = total >= needed
					if not has_enough:
						all_available = false
					var check_mark: String = "✓" if has_enough else "✗"
					status_parts.append("%s %s: %.0f" % [check_mark, res_id.replace("_", " "), total])

				var status_label: Label = Label.new()
				status_label.text = "  Input: " + ", ".join(status_parts)
				status_label.add_theme_font_size_override("font_size", 10)
				if all_available:
					status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
				else:
					status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
				_production_container.add_child(status_label)
			else:
				# Display each resource production normally
				for resource_id in production_data.keys():
					var amount = production_data[resource_id]
					var resource_label: Label = Label.new()
					resource_label.text = "  %s: +%.1f/hour" % [resource_id.replace("_", " ").capitalize(), amount]
					resource_label.add_theme_font_size_override("font_size", 12)
					resource_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8, 1))
					_production_container.add_child(resource_label)

			# Spacer before bonuses
			var spacer2: Control = Control.new()
			spacer2.custom_minimum_size = Vector2(0, 4)
			_production_container.add_child(spacer2)

			# Show production bonuses breakdown
			_show_production_bonuses()

			# Show defense drops for player-controlled nodes (loot from defending)
			_show_defense_drops()
		else:
			# No production (no workers assigned)
			var no_prod_label: Label = Label.new()
			no_prod_label.text = "  No production (assign workers)"
			no_prod_label.add_theme_font_size_override("font_size", 11)
			no_prod_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
			_production_container.add_child(no_prod_label)

			# Still show defense drops even without workers (garrison can defend)
			_show_defense_drops()
	elif not current_node.is_controlled_by_player():
		# Show BASE PRODUCTION for uncaptured nodes - this is what you'll get!
		_show_potential_production()

func _show_production_bonuses() -> void:
	"""Show compact production bonuses summary"""
	if not current_node or not production_manager:
		return

	# Calculate total bonus for compact display
	var bonuses: Array[String] = []

	if current_node.production_level > 1:
		var upgrade_bonus = (current_node.production_level - 1) * 0.10
		bonuses.append("+%.0f%% Lv%d" % [upgrade_bonus * 100, current_node.production_level])

	if territory_manager:
		var connected_count = territory_manager.get_connected_node_count(current_node.coord)
		var connected_bonus: float = 0.0
		if connected_count >= 4:
			connected_bonus = 0.30
		elif connected_count == 3:
			connected_bonus = 0.20
		elif connected_count == 2:
			connected_bonus = 0.10
		if connected_bonus > 0:
			bonuses.append("+%.0f%% conn" % [connected_bonus * 100])

	if not current_node.assigned_workers.is_empty():
		var worker_efficiency = _calculate_worker_efficiency_display()
		if worker_efficiency > 0:
			bonuses.append("+%.0f%% workers" % [worker_efficiency * 100])

	if not bonuses.is_empty():
		var bonus_label: Label = Label.new()
		bonus_label.text = "  Bonuses: " + ", ".join(bonuses)
		bonus_label.add_theme_font_size_override("font_size", 10)
		bonus_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		_production_container.add_child(bonus_label)

func _show_defense_drops() -> void:
	"""Show defense battle drops for player-controlled nodes (loot from garrison battles)"""
	if not current_node:
		return

	# Only show if node has defense drops
	if current_node.defense_drops.is_empty():
		return

	# Spacer before defense drops
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_production_container.add_child(spacer)

	# Defense drops header
	var drops_header: Label = Label.new()
	drops_header.text = "⚔️ GARRISON BATTLE REWARDS:"
	drops_header.add_theme_font_size_override("font_size", 12)
	drops_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
	_production_container.add_child(drops_header)

	# Show attack timer for capturable nodes
	var attack_hours = current_node.attack_timer_hours
	if attack_hours > 0 and current_node.is_capturable:
		# Calculate timer values - if inactive (-1), treat as full time remaining
		var remaining_seconds = current_node.attack_timer_remaining
		var max_seconds = attack_hours * 3600.0
		var timer_active = remaining_seconds >= 0

		# If timer inactive, show full time (no attack pending yet)
		if not timer_active:
			remaining_seconds = max_seconds

		var progress = clampf(remaining_seconds / max_seconds, 0.0, 1.0)

		# Timer container with label
		var timer_row: HBoxContainer = HBoxContainer.new()
		timer_row.add_theme_constant_override("separation", 6)
		_production_container.add_child(timer_row)

		# Timer icon/label
		var timer_icon: Label = Label.new()
		timer_icon.text = "  ⏱️"
		timer_icon.add_theme_font_size_override("font_size", 12)
		timer_row.add_child(timer_icon)

		# Progress bar showing TIME REMAINING (full = safe, empty = attack imminent)
		_attack_timer_progress_bar = ProgressBar.new()
		_attack_timer_progress_bar.custom_minimum_size = Vector2(140, 16)
		_attack_timer_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_attack_timer_progress_bar.value = progress * 100.0  # Full bar = full time remaining
		_attack_timer_progress_bar.show_percentage = false

		# Style the progress bar
		var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.15, 0.15, 0.2, 1)
		bar_bg.set_corner_radius_all(4)
		_attack_timer_progress_bar.add_theme_stylebox_override("background", bar_bg)

		_attack_timer_fill_style = StyleBoxFlat.new()
		# Color changes from green to yellow to red as time runs out
		var fill_color: Color = _get_timer_fill_color(timer_active, progress)
		_attack_timer_fill_style.bg_color = fill_color
		_attack_timer_fill_style.set_corner_radius_all(4)
		_attack_timer_progress_bar.add_theme_stylebox_override("fill", _attack_timer_fill_style)
		timer_row.add_child(_attack_timer_progress_bar)

		# Time remaining text
		_attack_timer_label = Label.new()
		_attack_timer_label.text = _get_timer_text(timer_active, remaining_seconds, attack_hours)
		_attack_timer_label.add_theme_color_override("font_color", _get_timer_text_color(timer_active, remaining_seconds, fill_color))
		_attack_timer_label.add_theme_font_size_override("font_size", 11)
		timer_row.add_child(_attack_timer_label)
	elif attack_hours <= 0:
		# Safe node - no attacks
		var safe_label: Label = Label.new()
		safe_label.text = "  🛡️ Safe node (no attacks)"
		safe_label.add_theme_font_size_override("font_size", 10)
		safe_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		_production_container.add_child(safe_label)

	# List each drop with "per battle" label
	for drop_id in current_node.defense_drops.keys():
		var drop_data = current_node.defense_drops[drop_id]
		var drop_label: Label = Label.new()
		var drop_name = drop_id.replace("_", " ").capitalize()
		if drop_data is Dictionary:
			var min_amt = drop_data.get("min", 0)
			var max_amt = drop_data.get("max", 0)
			drop_label.text = "  • %s: %d-%d per battle" % [drop_name, min_amt, max_amt]
		else:
			drop_label.text = "  • %s" % drop_name
		drop_label.add_theme_font_size_override("font_size", 11)
		drop_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
		_production_container.add_child(drop_label)

func _get_timer_fill_color(timer_active: bool, progress: float) -> Color:
	"""Get the progress bar fill color based on timer state"""
	if not timer_active:
		return Color(0.3, 0.6, 0.4, 1)  # Green - safe/no attack pending
	elif progress > 0.5:
		return Color(0.3, 0.7, 0.4, 1)  # Green - plenty of time
	elif progress > 0.2:
		return Color(0.8, 0.7, 0.3, 1)  # Yellow - getting close
	else:
		return Color(0.9, 0.4, 0.3, 1)  # Red - imminent

func _get_timer_text(timer_active: bool, remaining_seconds: float, attack_hours: float) -> String:
	"""Get the timer label text based on state"""
	var hours_left: int = int(remaining_seconds / 3600)
	var minutes_left: int = int((remaining_seconds - hours_left * 3600) / 60)

	if not timer_active:
		return "Safe (%.0fh cycle)" % attack_hours
	elif remaining_seconds <= 0:
		return "⚔️ ATTACK!"
	elif hours_left > 0:
		return "%dh %dm left" % [hours_left, minutes_left]
	else:
		return "%dm left" % minutes_left

func _get_timer_text_color(timer_active: bool, remaining_seconds: float, fill_color: Color) -> Color:
	"""Get the timer label color based on state"""
	if not timer_active:
		return Color(0.5, 0.75, 0.55)
	elif remaining_seconds <= 0:
		return Color(1.0, 0.3, 0.3)
	else:
		return fill_color.lightened(0.2)

func _update_attack_timer_display() -> void:
	"""Update the attack timer progress bar and label in real-time"""
	if not current_node or not current_node.is_controlled_by_player():
		return

	if not _attack_timer_progress_bar or not _attack_timer_label:
		return

	var attack_hours = current_node.attack_timer_hours
	if attack_hours <= 0 or not current_node.is_capturable:
		return

	# Calculate current timer values
	var remaining_seconds = current_node.attack_timer_remaining
	var max_seconds = attack_hours * 3600.0
	var timer_active = remaining_seconds >= 0

	# If timer inactive, show full time
	if not timer_active:
		remaining_seconds = max_seconds

	var progress = clampf(remaining_seconds / max_seconds, 0.0, 1.0)

	# Update progress bar value
	_attack_timer_progress_bar.value = progress * 100.0

	# Update fill color
	var fill_color = _get_timer_fill_color(timer_active, progress)
	if _attack_timer_fill_style:
		_attack_timer_fill_style.bg_color = fill_color

	# Update label text and color
	_attack_timer_label.text = _get_timer_text(timer_active, remaining_seconds, attack_hours)
	_attack_timer_label.add_theme_color_override("font_color", _get_timer_text_color(timer_active, remaining_seconds, fill_color))

func _calculate_worker_efficiency_display() -> float:
	"""Calculate total worker efficiency for display purposes"""
	if not current_node or not collection_manager:
		return 0.0

	var total_efficiency: float = 0.0
	for worker_id in current_node.assigned_workers:
		var god = collection_manager.get_god_by_id(worker_id)
		if god:
			# Base 10% per worker
			var efficiency: float = 0.10

			# Add level bonus (1% per level)
			efficiency += god.level * 0.01

			total_efficiency += efficiency

	return total_efficiency

func _show_potential_production() -> void:
	"""Show what you'll get when you capture this node (base_production)"""
	if not current_node:
		return

	# Header showing this is what you'll get
	var header_label: Label = Label.new()
	header_label.text = "📦 CAPTURE TO RECEIVE:"
	header_label.add_theme_font_size_override("font_size", 12)
	header_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_production_container.add_child(header_label)

	# Show base production from the node's template
	if current_node.base_production.is_empty():
		var no_prod_label: Label = Label.new()
		no_prod_label.text = "  No production data"
		no_prod_label.add_theme_font_size_override("font_size", 11)
		no_prod_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_production_container.add_child(no_prod_label)
		return

	# Display each base production resource
	for resource_id in current_node.base_production.keys():
		var amount = current_node.base_production[resource_id]
		if amount > 0:
			var resource_label: Label = Label.new()
			var resource_name = resource_id.replace("_", " ").capitalize()
			resource_label.text = "  • %s: %d/hour" % [resource_name, amount]
			resource_label.add_theme_font_size_override("font_size", 12)
			resource_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
			_production_container.add_child(resource_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_production_container.add_child(spacer)

	# Show defense drops if any (loot when defending)
	if not current_node.defense_drops.is_empty():
		var drops_header: Label = Label.new()
		drops_header.text = "⚔️ DEFENSE BATTLE DROPS:"
		drops_header.add_theme_font_size_override("font_size", 11)
		drops_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
		_production_container.add_child(drops_header)

		for drop_id in current_node.defense_drops.keys():
			var drop_data = current_node.defense_drops[drop_id]
			var drop_label: Label = Label.new()
			var drop_name = drop_id.replace("_", " ").capitalize()
			if drop_data is Dictionary:
				var min_amt = drop_data.get("min", 0)
				var max_amt = drop_data.get("max", 0)
				drop_label.text = "  • %s: %d-%d" % [drop_name, min_amt, max_amt]
			else:
				drop_label.text = "  • %s" % drop_name
			drop_label.add_theme_font_size_override("font_size", 11)
			drop_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
			_production_container.add_child(drop_label)

	# Spacer
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6)
	_production_container.add_child(spacer2)

	# Show worker/garrison capacity
	var capacity_label: Label = Label.new()
	var max_workers = mini(current_node.tier, 5)
	capacity_label.text = "👥 Workers: %d slots | 🛡️ Garrison: %d slots" % [max_workers, current_node.max_garrison]
	capacity_label.add_theme_font_size_override("font_size", 11)
	capacity_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_production_container.add_child(capacity_label)

	# Show capture requirement
	var capture_label: Label = Label.new()
	capture_label.text = "⚡ Capture Power: %d required" % current_node.capture_power_required
	capture_label.add_theme_font_size_override("font_size", 11)
	capture_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	_production_container.add_child(capture_label)

func _update_garrison() -> void:
	"""Update garrison display WITH SLOT BOXES and TEAM BONUSES"""
	# Clear existing
	for child in _garrison_container.get_children():
		child.queue_free()

	if not current_node:
		return

	# Check if node is captured - garrison is only available for player-controlled nodes
	var is_captured = current_node.is_controlled_by_player()

	# Show lock message if not captured
	if not is_captured:
		var lock_label: Label = Label.new()
		lock_label.text = "🔒 Capture this node to assign garrison"
		lock_label.add_theme_font_size_override("font_size", 11)
		lock_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_garrison_container.add_child(lock_label)

	# Clean up stale god_ids (gods that were sacrificed but still in garrison)
	if is_captured:
		_cleanup_stale_garrison_ids()

	# Create slot boxes
	var slots_row: HBoxContainer = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", SLOT_SPACING)
	_garrison_container.add_child(slots_row)

	var garrison_gods: Array = []
	for i in range(MAX_GARRISON_SLOTS):
		var slot: Control
		if i < current_node.garrison.size() and is_captured:
			var god = _get_god_by_id(current_node.garrison[i])
			if god:
				garrison_gods.append(god)
				slot = _create_filled_slot(current_node, "garrison", i, god, not is_captured)
			else:
				# This shouldn't happen after cleanup, but as fallback treat as empty
				slot = _create_empty_slot(current_node, "garrison", i, not is_captured)
		else:
			slot = _create_empty_slot(current_node, "garrison", i, not is_captured)
		slots_row.add_child(slot)

	# Show team bonuses if garrison has 2+ gods
	if garrison_gods.size() >= 2:
		_show_garrison_team_bonuses(garrison_gods)

func _show_garrison_team_bonuses(garrison_gods: Array) -> void:
	"""Display team bonuses from garrison (applies to workers too)"""
	var node_type = current_node.node_type if current_node else ""
	var bonuses = TeamStatsCalculator.get_team_bonuses(garrison_gods, node_type)

	if bonuses.is_empty():
		return

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_garrison_container.add_child(spacer)

	# Team bonuses header
	var header: Label = Label.new()
	header.text = "⚔️ Team Bonuses (affects workers):"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	_garrison_container.add_child(header)

	# List each bonus (stacked vertically to prevent overflow)
	for bonus in bonuses:
		var bonus_row: VBoxContainer = VBoxContainer.new()
		bonus_row.add_theme_constant_override("separation", 1)
		_garrison_container.add_child(bonus_row)

		var bonus_name: Label = Label.new()
		var element_text: String = ""
		if bonus.has("element"):
			element_text = " (%s)" % bonus.element
		bonus_name.text = "  • %s%s" % [bonus.name, element_text]
		bonus_name.add_theme_font_size_override("font_size", 10)
		bonus_name.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		bonus_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bonus_name.clip_text = true
		bonus_row.add_child(bonus_name)

		var bonus_desc: Label = Label.new()
		bonus_desc.text = "    %s" % bonus.desc
		bonus_desc.add_theme_font_size_override("font_size", 9)
		bonus_desc.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		bonus_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bonus_desc.clip_text = true
		bonus_row.add_child(bonus_desc)

func _show_worker_received_bonuses() -> void:
	"""Display production-relevant bonuses workers receive from garrison"""
	# Get garrison gods to calculate their bonuses
	var garrison_gods: Array = []
	for god_id in current_node.garrison:
		var god = _get_god_by_id(god_id)
		if god:
			garrison_gods.append(god)

	# Only show if garrison has bonuses
	if garrison_gods.size() < 2:
		return

	var node_type = current_node.node_type if current_node else ""
	var bonuses = TeamStatsCalculator.get_team_bonuses(garrison_gods, node_type)
	if bonuses.is_empty():
		return

	# Filter to only production-relevant bonuses
	var worker_bonuses = _filter_worker_relevant_bonuses(bonuses)
	if worker_bonuses.is_empty():
		return

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_workers_container.add_child(spacer)

	# Receiving bonuses header
	var header: Label = Label.new()
	header.text = "📈 Garrison Production Bonus:"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
	_workers_container.add_child(header)

	# Compact list of bonuses received
	var bonus_text: String = ""
	for i in range(worker_bonuses.size()):
		var bonus = worker_bonuses[i]
		if i > 0:
			bonus_text += ", "
		bonus_text += "%s" % bonus.desc

	var bonus_label: Label = Label.new()
	bonus_label.text = "  " + bonus_text
	bonus_label.add_theme_font_size_override("font_size", 10)
	bonus_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.5))
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_label.custom_minimum_size = Vector2(PANEL_WIDTH - 50, 0)
	_workers_container.add_child(bonus_label)

func _filter_worker_relevant_bonuses(bonuses: Array) -> Array:
	"""Filter bonuses to only include production-relevant ones for workers"""
	# Keys that matter for production/workers
	const WORKER_RELEVANT_KEYS = [
		"production", "resource_production", "crafting_speed", "quality_bonus",
		"mana_production", "divine_essence_production", "rare_drop_chance",
		"experience_gain", "healing_power"  # healing_power for shrines
	]

	var filtered: Array = []
	for bonus in bonuses:
		if not bonus.has("bonuses"):
			continue

		# Check if any bonus key is worker-relevant
		var has_relevant: bool = false
		for key in bonus.bonuses:
			if key in WORKER_RELEVANT_KEYS:
				has_relevant = true
				break

		if has_relevant:
			# Create a filtered version with only relevant bonuses in desc
			var relevant_parts: Array = []
			for key in bonus.bonuses:
				if key in WORKER_RELEVANT_KEYS:
					var value = bonus.bonuses[key]
					var formatted_key = key.replace("_", " ").capitalize()
					relevant_parts.append("+%d%% %s" % [int(value * 100), formatted_key])

			if not relevant_parts.is_empty():
				filtered.append({
					"name": bonus.name,
					"desc": ", ".join(relevant_parts)
				})

	return filtered

func _update_workers() -> void:
	"""Update workers display WITH SLOT BOXES and received bonuses"""
	# Clear existing
	for child in _workers_container.get_children():
		child.queue_free()

	if not current_node:
		return

	# Check if node is captured - workers are only available for player-controlled nodes
	var is_captured = current_node.is_controlled_by_player()

	# Show lock message if not captured
	if not is_captured:
		var lock_label: Label = Label.new()
		lock_label.text = "🔒 Capture this node to assign workers"
		lock_label.add_theme_font_size_override("font_size", 11)
		lock_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_workers_container.add_child(lock_label)

	# Clean up stale god_ids (gods that were sacrificed but still in workers)
	if is_captured:
		_cleanup_stale_worker_ids()

	var max_workers = mini(current_node.tier, 5)

	if max_workers == 0:
		var no_lbl: Label = Label.new()
		no_lbl.text = "Not available (Tier 0)"
		no_lbl.add_theme_font_size_override("font_size", 11)
		no_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_workers_container.add_child(no_lbl)
		return

	# Check garrison power requirement for workers (only matters if captured)
	var can_use_workers = is_captured
	var garrison_status: Dictionary = {}
	if territory_manager and is_captured:
		garrison_status = territory_manager.get_garrison_worker_status(current_node)
		can_use_workers = garrison_status.get("can_assign", true)

	# Show garrison power requirement warning if not met
	if not can_use_workers:
		var warning_label: Label = Label.new()
		warning_label.text = "🛡️ Garrison power required: %d/%d" % [garrison_status.get("current", 0), garrison_status.get("required", 0)]
		warning_label.add_theme_font_size_override("font_size", 11)
		warning_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		_workers_container.add_child(warning_label)

		var hint_label: Label = Label.new()
		hint_label.text = "  Assign stronger gods to garrison first"
		hint_label.add_theme_font_size_override("font_size", 10)
		hint_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_workers_container.add_child(hint_label)

	# Create slot boxes
	var slots_row: HBoxContainer = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", SLOT_SPACING)
	_workers_container.add_child(slots_row)

	for i in range(max_workers):
		var slot: Control
		if i < current_node.assigned_workers.size():
			var god = _get_god_by_id(current_node.assigned_workers[i])
			if god:
				# Pass inactive=true for workers when garrison power is too low
				slot = _create_filled_slot(current_node, "worker", i, god, not can_use_workers)
			else:
				# Null god (shouldn't happen after cleanup) - treat as empty
				slot = _create_empty_slot(current_node, "worker", i, not can_use_workers)
		else:
			slot = _create_empty_slot(current_node, "worker", i, not can_use_workers)
		slots_row.add_child(slot)

	# Show what bonuses workers receive from garrison (only if workers are active)
	if current_node.assigned_workers.size() > 0 and can_use_workers:
		_show_worker_received_bonuses()
	elif current_node.assigned_workers.size() > 0 and not can_use_workers:
		# Show that workers are inactive
		var inactive_label: Label = Label.new()
		inactive_label.text = "⚠️ Workers inactive - not producing"
		inactive_label.add_theme_font_size_override("font_size", 10)
		inactive_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3))
		_workers_container.add_child(inactive_label)

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
		var met_label: Label = Label.new()
		met_label.text = "All requirements met!"
		met_label.add_theme_font_size_override("font_size", 12)
		met_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1))
		_requirements_container.add_child(met_label)
	else:
		for req_text in missing_reqs:
			var req_label: Label = Label.new()
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
		# Store reference for tutorial highlighting
		_capture_button_ref = capture_btn
		# Check if we should highlight capture button for tutorial
		call_deferred("_check_capture_button_tutorial")
	elif current_node.is_controlled_by_player() and current_node.can_place_building():
		# Player-controlled blank tile - show select building button
		var build_btn = _create_button("🏗️ Select Building", Color(0.5, 0.4, 0.2, 1))
		build_btn.pressed.connect(_on_select_building_pressed)
		_action_buttons.add_child(build_btn)
	elif current_node.is_controlled_by_player() and current_node.has_building():
		# Player-controlled tile WITH building - show change building button
		var demolish_btn = _create_button("🔄 Change Building", Color(0.6, 0.3, 0.2, 1))
		demolish_btn.pressed.connect(_on_demolish_pressed)
		_action_buttons.add_child(demolish_btn)

# ==============================================================================
# SLOT CREATION METHODS (copied from TerritoryOverviewScreen)
# ==============================================================================
func _create_empty_slot(node: HexNode, slot_type: String, slot_index: int, disabled: bool = false) -> Control:
	"""Create an empty slot with '+' icon (60x60px tap target)"""
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	# Mark as empty for tutorial highlighting
	slot.set_meta("is_empty", true)
	slot.set_meta("slot_type", slot_type)

	# Greyed out style if disabled
	var border_color: Color = Color(0.3, 0.3, 0.35, 0.5) if disabled else Color(0.4, 0.4, 0.45, 0.7)
	slot.add_theme_stylebox_override("panel", _create_slot_style(border_color, 2))

	# Plus icon or lock icon if disabled
	var plus_label: Label = Label.new()
	plus_label.text = "🔒" if disabled else "+"
	plus_label.add_theme_font_size_override("font_size", 20 if disabled else 24)
	plus_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3) if disabled else Color(0.5, 0.5, 0.55))
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plus_label)

	# Tappable button (only if not disabled)
	if not disabled:
		_add_slot_button(slot, node, slot_type, slot_index)
	return slot

func _create_filled_slot(node: HexNode, slot_type: String, slot_index: int, god: God, inactive: bool = false) -> Control:
	"""Create a filled slot showing god portrait (60x60px). Inactive shows grayed out."""
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	# Mark as filled for tutorial highlighting
	slot.set_meta("is_empty", false)
	slot.set_meta("slot_type", slot_type)
	var border_color = ELEMENT_COLORS.get(god.element, Color.GRAY) if god else Color(0.5, 0.5, 0.5)
	if inactive:
		border_color = border_color * 0.5  # Dim the border color
	slot.add_theme_stylebox_override("panel", _create_slot_style(border_color, 3))

	if god:
		var portrait = _create_god_portrait(god)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 4
		portrait.offset_right = -4
		portrait.offset_top = 4
		portrait.offset_bottom = -14
		if inactive:
			portrait.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grayscale/dim effect
		slot.add_child(portrait)

		var level_label: Label = Label.new()
		level_label.text = "Lv.%d" % god.level
		level_label.add_theme_font_size_override("font_size", 9)
		level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5) if inactive else Color(0.8, 0.8, 0.8))
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.anchor_left = 0
		level_label.anchor_right = 1
		level_label.anchor_top = 1
		level_label.anchor_bottom = 1
		level_label.offset_top = -14
		level_label.offset_bottom = -2
		slot.add_child(level_label)

		# Add "INACTIVE" overlay for workers without garrison protection
		if inactive:
			var inactive_overlay: Label = Label.new()
			inactive_overlay.text = "⚠️"
			inactive_overlay.add_theme_font_size_override("font_size", 16)
			inactive_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inactive_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			inactive_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(inactive_overlay)
	else:
		var lbl: Label = Label.new()
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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style

func _add_slot_button(slot: Panel, node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Add tappable button overlay to empty slot"""
	var button: Button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_slot_tapped.bind(node, slot_type, slot_index))
	slot.add_child(button)

func _add_filled_slot_button(slot: Panel, node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Add tappable button overlay to filled slot (emits different signal)"""
	var button: Button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_filled_slot_tapped.bind(node, slot_type, slot_index, god))
	slot.add_child(button)

func _create_god_portrait(god: God) -> TextureRect:
	"""Create god portrait TextureRect"""
	var portrait: TextureRect = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var god_template = god.template_id if god.template_id else god.id
	var sprite_path: String = "res://assets/gods/" + god_template + ".png"
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

func _cleanup_stale_garrison_ids() -> void:
	"""Remove god_ids from garrison that no longer exist (were sacrificed)"""
	if not current_node or not territory_manager:
		return

	var stale_ids: Array = []
	for god_id in current_node.garrison:
		var god = _get_god_by_id(god_id)
		if god == null:
			stale_ids.append(god_id)

	if stale_ids.size() > 0:
		# Remove stale IDs from garrison
		var clean_garrison: Array = []
		for god_id in current_node.garrison:
			if not stale_ids.has(god_id):
				clean_garrison.append(god_id)

		# Update via TerritoryManager to persist the cleanup
		territory_manager.update_node_garrison(current_node.id, clean_garrison)

func _cleanup_stale_worker_ids() -> void:
	"""Remove god_ids from workers that no longer exist (were sacrificed)"""
	if not current_node or not territory_manager:
		return

	var stale_ids: Array = []
	for god_id in current_node.assigned_workers:
		var god = _get_god_by_id(god_id)
		if god == null:
			stale_ids.append(god_id)

	if stale_ids.size() > 0:
		# Remove stale IDs from workers
		var clean_workers: Array = []
		for god_id in current_node.assigned_workers:
			if not stale_ids.has(god_id):
				clean_workers.append(god_id)

		# Update via TerritoryManager to persist the cleanup
		territory_manager.update_node_workers(current_node.id, clean_workers)

func _create_button(text: String, color: Color) -> Button:
	"""Create a styled button"""
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, BUTTON_HEIGHT)

	# Normal state
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = color
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover state
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", hover_style)

	# Disabled state
	var disabled_style: StyleBoxFlat = StyleBoxFlat.new()
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
		# Clear any tutorial highlight
		_clear_tutorial_highlight()
		# Emit tutorial action
		_emit_tutorial_action("capture_button_pressed")
		capture_requested.emit(current_node)

func _on_select_building_pressed() -> void:
	"""Handle select building button press"""
	if current_node:
		select_building_requested.emit(current_node)

func _on_demolish_pressed() -> void:
	"""Handle demolish/change building button press"""
	if current_node:
		demolish_building_requested.emit(current_node)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_requested.emit()
	hide_panel()


func _on_slot_tapped(node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Handle empty slot tap - emit signal for parent to open god selection"""
	# Emit tutorial action for garrison slot tap
	if slot_type == "garrison":
		_emit_tutorial_action("garrison_slot_tapped")
	slot_tapped.emit(node, slot_type, slot_index)

func _on_filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Handle filled slot tap - emit signal for parent to show remove confirmation"""
	filled_slot_tapped.emit(node, slot_type, slot_index, god)

func _on_collect_resources_pressed() -> void:
	"""Handle collect resources button press"""
	if not current_node or not production_manager:
		return

	# Call production manager to collect resources
	var collected = production_manager.collect_node_resources(current_node.id)

	if collected.is_empty():
		_show_collection_feedback("No resources to collect", Color(0.8, 0.6, 0.4))
	else:
		var manual_bonus: float = TerritoryProductionManager.get_manual_collection_bonus()

		# Format collected resources for display
		var message: String = "Collected:\n"
		for resource_id in collected.keys():
			var amount = collected[resource_id]
			if manual_bonus > 1.0:
				var base_amount = amount / manual_bonus
				var bonus_amount = amount - base_amount
				message += "%s: %.1f (+%.1f bonus)\n" % [resource_id.replace("_", " ").capitalize(), amount, bonus_amount]
			else:
				message += "%s: %.1f\n" % [resource_id.replace("_", " ").capitalize(), amount]

		# Add bonus indicator to message if applicable
		if manual_bonus > 1.0:
			var bonus_percent: int = int((manual_bonus - 1.0) * 100)
			message += "\n✨ +%d%% Manual Collection Bonus" % bonus_percent

		_show_collection_feedback(message, Color(0.3, 0.9, 0.4))

		# Trigger visual collection effect on the hex tile
		_trigger_collection_effect_on_tile()

		# Refresh the display to show updated (cleared) accumulated resources
		_update_pending_resources()

func _trigger_collection_effect_on_tile() -> void:
	"""Trigger visual collection effect on the hex tile in the map view"""
	if not current_node:
		return

	# Get HexMapView from parent screen
	var hex_screen = get_parent()
	if not hex_screen:
		return

	var hex_map_view = hex_screen.get_node_or_null("HexMapView")
	if not hex_map_view:
		return

	# Get the tile for current node
	var coord_key: String = "%d,%d" % [current_node.coord.q, current_node.coord.r]
	if hex_map_view.hex_tiles.has(coord_key):
		var tile = hex_map_view.hex_tiles[coord_key]
		if tile and tile.has_method("show_collection_effect"):
			tile.show_collection_effect()

func _show_collection_feedback(message: String, color: Color) -> void:
	"""Show a temporary feedback message about collection"""
	# Create a temporary label that fades out
	var feedback_label: Label = Label.new()
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

# ==============================================================================
# TASKS / CRAFTING SYSTEM
# ==============================================================================
func _load_tasks_data() -> void:
	"""Load crafting recipes from JSON file"""
	var file_path: String = "res://data/crafting_recipes.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("NodeInfoPanel: Could not load crafting_recipes.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("NodeInfoPanel: Failed to parse crafting_recipes.json")
		return

	var data = json.get_data()
	# Load recipes from flattened structure (recipes at top level)
	_tasks_data = {}
	for recipe_id in data.keys():
		# Skip metadata and comment keys
		if recipe_id.begins_with("_"):
			continue
		var recipe = data[recipe_id]
		if recipe is Dictionary:
			_tasks_data[recipe_id] = recipe

func _update_tasks() -> void:
	"""Update tasks/crafting section - shows Craft button for forges with workers"""
	# Clear existing
	for child in _tasks_container.get_children():
		child.queue_free()

	# Find the section label to hide/show
	var section_label = _main_container.get_node_or_null("TasksSectionLabel")

	if not current_node:
		if section_label:
			section_label.visible = false
		_tasks_container.visible = false
		return

	# Only show for player-controlled nodes with crafting buildings and workers
	var is_forge = current_node.node_type == "forge"
	var has_workers = current_node.assigned_workers.size() > 0
	var is_player_controlled = current_node.is_controlled_by_player()

	# Also check if node has a building with crafting_enabled
	var has_crafting_building: bool = false
	if not current_node.placed_building.is_empty() and building_manager:
		var building = building_manager.get_building(current_node.placed_building)
		var effects = building.get("effects", {})
		has_crafting_building = effects.get("crafting_enabled", false)

	if (not is_forge and not has_crafting_building) or not has_workers or not is_player_controlled:
		if section_label:
			section_label.visible = false
		_tasks_container.visible = false
		return

	# Show the section
	if section_label:
		section_label.visible = true
	_tasks_container.visible = true

	# Get the craft tier and type from the building
	var craft_tier = current_node.tier
	var craft_type: String = ""  # empty = all types
	if has_crafting_building and building_manager:
		var building = building_manager.get_building(current_node.placed_building)
		var effects = building.get("effects", {})
		craft_tier = effects.get("max_craft_tier", current_node.tier)
		craft_type = effects.get("craft_type", "")  # "weapon", "armor", "consumable", or "" for all

	# Get available recipes for this building
	_available_tasks = _get_available_recipes(craft_tier, craft_type)

	# Calculate craft slot info (tier-based: T1=1, T2=2, T3=3, T4=4)
	var max_craft_slots: int = maxi(1, current_node.tier)
	var active_for_this_node = _get_active_crafts_for_node(current_node.id)
	var active_count: int = active_for_this_node.size()

	# Show craft slot status
	var slot_label: Label = Label.new()
	var tier_stars: String = "★".repeat(current_node.tier)
	slot_label.text = "  %s Craft Slots: %d/%d" % [tier_stars, active_count, max_craft_slots]
	slot_label.add_theme_font_size_override("font_size", 11)
	if active_count >= max_craft_slots:
		slot_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))  # Orange - full
	else:
		slot_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))  # Green - available
	_tasks_container.add_child(slot_label)

	# Show active crafts (with progress bars)
	if not active_for_this_node.is_empty():
		var active_label: Label = Label.new()
		active_label.text = "  🔨 Active Crafting:"
		active_label.add_theme_font_size_override("font_size", 12)
		active_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		_tasks_container.add_child(active_label)

		for craft_data in active_for_this_node:
			var progress_card = _create_craft_progress_card(craft_data)
			_tasks_container.add_child(progress_card)

		# Spacer after active crafts
		var active_spacer: Control = Control.new()
		active_spacer.custom_minimum_size = Vector2(0, 8)
		_tasks_container.add_child(active_spacer)

	if _available_tasks.is_empty():
		var no_tasks_label: Label = Label.new()
		no_tasks_label.text = "  No recipes available for this tier"
		no_tasks_label.add_theme_font_size_override("font_size", 11)
		no_tasks_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_tasks_container.add_child(no_tasks_label)
		return

	# Show recipe count and Craft button
	var info_label: Label = Label.new()
	var slots_text: String = " (%d slots free)" % (max_craft_slots - active_count) if active_count < max_craft_slots else " (FULL)"
	info_label.text = "  %d recipes available%s" % [_available_tasks.size(), slots_text]
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	_tasks_container.add_child(info_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_tasks_container.add_child(spacer)

	# Craft button
	var craft_btn = _create_button("⚒️ Open Crafting", Color(0.6, 0.4, 0.2, 1))
	craft_btn.pressed.connect(_on_craft_button_pressed)
	_tasks_container.add_child(craft_btn)

func _get_active_crafts_for_node(node_id: String) -> Array:
	"""Get active crafts for a specific node from shared tracker"""
	if hex_grid_manager:
		return hex_grid_manager.get_active_crafts_for_node(node_id)
	return []

func _create_craft_progress_card(craft_data: Dictionary) -> PanelContainer:
	"""Create a progress card for an active craft"""
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 60)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.18, 0.95)
	style.border_color = Color(0.4, 0.6, 0.4, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Task name
	var task_data = craft_data.get("task_data", {})
	var name_label: Label = Label.new()
	name_label.text = "⚒️ " + task_data.get("name", "Crafting...")
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	vbox.add_child(name_label)

	# Progress bar
	var current_time: int = int(Time.get_unix_time_from_system())
	var start_time = craft_data.get("start_time", current_time)
	var end_time = craft_data.get("end_time", current_time + 60)
	var total_duration = end_time - start_time
	var elapsed = current_time - start_time
	var progress = clampf(float(elapsed) / float(total_duration), 0.0, 1.0)
	var remaining = maxi(0, end_time - current_time)

	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.value = progress * 100.0
	progress_bar.show_percentage = false

	# Style the progress bar
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2, 1)
	bar_bg.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.4, 0.7, 0.4, 1) if progress < 1.0 else Color(0.3, 0.9, 0.3, 1)
	bar_fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(progress_bar)

	# Time remaining or complete
	var time_label: Label = Label.new()
	if progress >= 1.0:
		time_label.text = "✓ Complete! Tap to collect"
		time_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		time_label.text = "⏱️ %s remaining" % _format_duration(remaining)
		time_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	time_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(time_label)

	# Make the card clickable if complete
	if progress >= 1.0:
		var btn: Button = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(_on_craft_complete_clicked.bind(craft_data))
		card.add_child(btn)

	return card

func _on_craft_complete_clicked(craft_data: Dictionary) -> void:
	"""Handle clicking on a completed craft to collect it"""
	var task_data = craft_data.get("task_data", {})
	var task_id = craft_data.get("task_id", "")
	var node_id = craft_data.get("node_id", "")


	# Award rewards
	_award_craft_rewards(task_data)

	# Remove from active crafts using shared tracker
	if hex_grid_manager:
		hex_grid_manager.complete_craft(node_id, task_id)

	# Refresh display
	_update_tasks()

	# Show collection feedback
	_show_craft_collected_feedback(task_data)

func _award_craft_rewards(task_data: Dictionary) -> void:
	"""Award the rewards from a completed craft"""
	if not resource_manager:
		push_error("NodeInfoPanel: Cannot award craft rewards - no ResourceManager")
		return

	# Resource rewards - use "output" from crafting_recipes.json (fallback to "resource_rewards")
	var resources = task_data.get("output", task_data.get("resource_rewards", {}))
	if resources.is_empty():
		push_warning("NodeInfoPanel: No output resources found in task_data: %s" % task_data.keys())
		return

	for resource_id in resources.keys():
		var amount = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

	# Item rewards (would need InventoryManager)
	var items = task_data.get("item_rewards", [])
	for item in items:
		if item is Dictionary:
			var chance = item.get("chance", 1.0)
			if randf() <= chance:
				var item_id = item.get("id", "")
				var item_rarity = item.get("rarity", "common")
				# TODO: Add to inventory when InventoryManager is integrated

func _show_craft_collected_feedback(task_data: Dictionary) -> void:
	"""Show feedback when a craft is collected"""
	var task_name = task_data.get("name", "Item")

	var feedback: PanelContainer = PanelContainer.new()
	feedback.z_index = 150

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.45, 0.3, 0.95)
	style.border_color = Color(0.4, 0.8, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	feedback.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = "✓ Crafted: %s" % task_name
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	feedback.add_child(label)

	feedback.anchor_left = 0.5
	feedback.anchor_right = 0.5
	feedback.anchor_top = 0.35
	feedback.anchor_bottom = 0.35
	feedback.offset_left = -120
	feedback.offset_right = 120

	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.add_child(feedback)
	else:
		add_child(feedback)

	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

func _get_available_recipes(max_tier: int, craft_type: String) -> Array:
	"""Get crafting recipes available for a building with given tier and type.

	Args:
		max_tier: Maximum recipe tier this building can craft (1-4)
		craft_type: Filter by type - "weapon", "armor", "consumable", or "" for all

	Returns:
		Array of available recipe dictionaries
	"""
	var available: Array = []

	for recipe_id in _tasks_data.keys():
		var recipe = _tasks_data[recipe_id]

		# NEVER show conversion recipes - these are handled automatically by refinery buildings
		var recipe_type = recipe.get("recipe_type", "")
		if recipe_type == "conversion":
			continue

		# Get recipe tier (default to 1)
		var recipe_tier = recipe.get("tier", recipe.get("territory_tier_requirement", 1))

		# Must meet tier requirement
		if recipe_tier > max_tier:
			continue

		# Filter by craft_type if specified
		if not craft_type.is_empty():
			var equipment_type = recipe.get("equipment_type", "")

			match craft_type:
				"weapon":
					# Weapon forge: only weapon equipment
					if equipment_type != "weapon":
						continue
				"armor":
					# Armor forge: armor, boots, helmet, gloves, accessories
					if equipment_type not in ["armor", "boots", "helmet", "gloves", "accessory"]:
						continue
				"consumable":
					# Consumable crafting: only consumable recipes
					if recipe_type != "consumable" and equipment_type != "consumable":
						continue
				_:
					# Unknown type - allow all equipment recipes
					pass

		# Add to available (include recipe_id in the data)
		var recipe_with_id = recipe.duplicate()
		recipe_with_id["id"] = recipe_id
		available.append(recipe_with_id)

	return available

func _on_craft_button_pressed() -> void:
	"""Handle craft button press - show recipe popup"""
	_show_craft_popup()

func _show_craft_popup() -> void:
	"""Show the new crafting screen with left/right panel layout"""
	# Create new crafting screen manager if needed
	_crafting_screen_manager = CraftingScreenManager.new()

	# Connect signals
	_crafting_screen_manager.craft_started.connect(_on_craft_started_from_screen)
	_crafting_screen_manager.popup_closed.connect(_on_crafting_screen_closed)

	# Show the crafting screen
	_crafting_screen_manager.show_crafting_screen(
		current_node,
		_available_tasks,
		hex_grid_manager,
		resource_manager,
		self
	)

func _on_craft_started_from_screen(node: HexNode, task_id: String) -> void:
	"""Handle craft started from new crafting screen"""
	task_started.emit(node, task_id)
	_update_tasks()

func _on_crafting_screen_closed() -> void:
	"""Handle crafting screen closed"""
	_crafting_screen_manager = null
	_update_tasks()

func _can_afford_craft(costs: Dictionary) -> bool:
	"""Check if player can afford the craft costs"""
	if costs.is_empty():
		return true
	if not resource_manager:
		return true  # Assume can afford if no manager
	return resource_manager.can_afford(costs)

func _format_costs_with_check(costs: Dictionary) -> String:
	"""Format costs with color indicators (✓ green / ✗ red)"""
	var parts: Array = []
	for resource_id in costs.keys():
		var needed = costs[resource_id]
		var have: int = 0
		if resource_manager:
			have = resource_manager.player_resources.get(resource_id, 0)
		var name = resource_id.replace("_", " ").capitalize()
		var can_afford_this = have >= needed
		if can_afford_this:
			parts.append("%s: %d/%d ✓" % [name, have, needed])
		else:
			parts.append("%s: %d/%d ✗" % [name, have, needed])
	return ", ".join(parts) if not parts.is_empty() else "Free"

func _format_duration(seconds: int) -> String:
	"""Format duration in human-readable format"""
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		var minutes = seconds / 60
		return "%dm" % minutes
	else:
		var hours = seconds / 3600
		var remaining_minutes = (seconds % 3600) / 60
		if remaining_minutes > 0:
			return "%dh %dm" % [hours, remaining_minutes]
		else:
			return "%dh" % hours

func _format_task_rewards(task: Dictionary) -> String:
	"""Format task rewards for display"""
	var parts: Array = []

	# Resource rewards - use "output" from crafting_recipes.json
	var resources = task.get("output", task.get("resource_rewards", {}))
	for resource_id in resources.keys():
		var amount = resources[resource_id]
		var name = resource_id.replace("_", " ").capitalize()
		parts.append("%s x%d" % [name, amount])

	# Item rewards - with rarity indication
	var items = task.get("item_rewards", [])
	for item in items:
		if item is Dictionary:
			var item_id = item.get("id", "Item")
			var item_name = item_id.replace("_", " ").capitalize()
			var rarity = item.get("rarity", "")
			var chance = item.get("chance", 1.0)

			# Add rarity indicator for equipment
			var rarity_prefix: String = ""
			match rarity:
				"common":
					rarity_prefix = "⚪ "
				"rare":
					rarity_prefix = "🔵 "
				"epic":
					rarity_prefix = "🟣 "
				"legendary":
					rarity_prefix = "🟡 "
				"mythic":
					rarity_prefix = "🔴 "

			if chance < 1.0:
				parts.append("%s%s (%.0f%%)" % [rarity_prefix, item_name, chance * 100])
			else:
				parts.append("%s%s" % [rarity_prefix, item_name])

	if parts.is_empty():
		# Show XP rewards if no items/resources
		var xp_rewards = task.get("experience_rewards", {})
		var god_xp = xp_rewards.get("god_xp", 0)
		if god_xp > 0:
			parts.append("%d God XP" % god_xp)

	return ", ".join(parts) if not parts.is_empty() else "Experience"

func _on_popup_bg_clicked(event: InputEvent) -> void:
	"""Handle click on popup background - close popup"""
	if event is InputEventMouseButton and event.pressed:
		_close_craft_popup()

func _close_craft_popup() -> void:
	"""Close the crafting popup/screen"""
	# Close new crafting screen manager
	if _crafting_screen_manager:
		_crafting_screen_manager.close()
		_crafting_screen_manager = null

	# Close old popup if it exists
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()
		_craft_popup = null

func _on_start_craft(task: Dictionary, auto_repeat_check = null) -> void:
	"""Handle starting a craft task"""
	if not current_node:
		return

	var task_id = task.get("id", "")
	if task_id.is_empty():
		return

	# Check if auto-repeat is enabled
	var auto_repeat: bool = false
	if auto_repeat_check and auto_repeat_check is CheckButton:
		auto_repeat = auto_repeat_check.button_pressed

	# Check and spend resources - use "materials" from crafting_recipes.json
	var costs = task.get("materials", task.get("resource_costs", {}))
	if not costs.is_empty():
		if not resource_manager:
			return
		if not resource_manager.can_afford(costs):
			return
		# Spend the resources
		if not resource_manager.spend_resources(costs):
			return


	# Track the craft using shared tracker in HexGridManager
	var craft_started: bool = false
	if hex_grid_manager:
		craft_started = hex_grid_manager.start_craft(current_node.id, task_id, task, auto_repeat)

	if not craft_started:
		# Refund the resources
		for resource_id in costs:
			resource_manager.add_resource(resource_id, costs[resource_id])
		_show_craft_error_feedback("Cannot start craft - forge already busy or no worker assigned")
		return

	# Emit signal for parent systems
	task_started.emit(current_node, task_id)

	# Close popup
	_close_craft_popup()

	# Show feedback
	_show_craft_started_feedback(task)

	# Update the tasks display to show progress
	_update_tasks()

func _show_craft_error_feedback(message: String) -> void:
	"""Show error feedback when craft cannot start"""
	var feedback: PanelContainer = PanelContainer.new()
	feedback.z_index = 150

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.15, 0.15, 0.95)
	style.border_color = Color(0.8, 0.3, 0.3, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	feedback.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = "❌ " + message
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	feedback.add_child(label)

	add_child(feedback)
	feedback.position = Vector2(size.x / 2 - 150, 100)

	# Fade out and remove
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

func _show_craft_started_feedback(task: Dictionary) -> void:
	"""Show feedback that a craft task has started"""
	var task_name = task.get("name", "Recipe")
	var duration = task.get("base_duration_seconds", 0)
	var duration_text = _format_duration(duration)

	# Create floating feedback panel
	var feedback: PanelContainer = PanelContainer.new()
	feedback.z_index = 150

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.3, 0.95)
	style.border_color = Color(0.4, 0.7, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	feedback.add_theme_stylebox_override("panel", style)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	feedback.add_child(content)

	var title_label: Label = Label.new()
	title_label.text = "⚒️ Crafting Started!"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var task_label: Label = Label.new()
	task_label.text = task_name
	task_label.add_theme_font_size_override("font_size", 14)
	task_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(task_label)

	var time_label: Label = Label.new()
	time_label.text = "Completes in: %s" % duration_text
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(time_label)

	# Add to main first, then position (anchors need parent)
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.add_child(feedback)
	else:
		add_child(feedback)

	# Position at center of screen AFTER adding to tree
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	feedback.custom_minimum_size = Vector2(300, 100)

	# Fade out and remove after 2.5 seconds
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

# ==============================================================================
# TUTORIAL INTEGRATION
# ==============================================================================
var _tutorial_highlight_overlay: TutorialHighlightOverlay = null
var _capture_button_ref: Button = null

func _check_garrison_tutorial() -> void:
	"""Check if garrison tutorial should be shown for this node."""
	if not current_node:
		return

	# Only show tutorial for player-controlled nodes with no garrison
	if not current_node.is_controlled_by_player():
		return

	if not current_node.garrison.is_empty():
		return

	var registry = SystemRegistry.get_instance()
	if not registry:
		return

	var tutorial_orch: Node = registry.get_system("TutorialOrchestrator")
	if not tutorial_orch:
		return

	# Trigger the garrison intro tutorial
	tutorial_orch.trigger_node_info_opened()

func _check_node_info_tutorial() -> void:
	"""Check if any node_info tutorial highlight should be shown."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return

	var tutorial_orch: Node = registry.get_system("TutorialOrchestrator")
	if not tutorial_orch:
		return

	# Connect to highlight signals if not already connected
	if tutorial_orch.has_signal("highlight_requested"):
		if not tutorial_orch.highlight_requested.is_connected(_on_tutorial_highlight_requested):
			tutorial_orch.highlight_requested.connect(_on_tutorial_highlight_requested)
	if tutorial_orch.has_signal("highlight_cleared"):
		if not tutorial_orch.highlight_cleared.is_connected(_on_tutorial_highlight_cleared):
			tutorial_orch.highlight_cleared.connect(_on_tutorial_highlight_cleared)

	if not tutorial_orch.is_tutorial_active():
		return

	var step_data: Dictionary = tutorial_orch.get_current_step_data()
	if step_data.is_empty():
		return

	# Check if current step wants to highlight something on node_info screen
	if step_data.get("type") == "highlight" and step_data.get("target_screen") == "node_info":
		var target_id: String = step_data.get("target_id", "")
		var message: String = step_data.get("message", "")
		var title: String = step_data.get("title", "")
		var show_button: bool = step_data.get("show_button", false)
		var wait_for_action: String = step_data.get("wait_for_action", "")

		call_deferred("_show_tutorial_highlight", target_id, message, title, show_button, wait_for_action)

func _on_tutorial_highlight_requested(_target_id: String, _message: String, _title: String, _show_button: bool = true) -> void:
	"""Handle highlight request from TutorialOrchestrator."""
	if not visible:
		return
	# Re-check current step data (may be different from signal params)
	_check_node_info_tutorial()

func _on_tutorial_highlight_cleared() -> void:
	"""Handle highlight cleared signal."""
	_clear_tutorial_highlight()

func _check_capture_button_tutorial() -> void:
	"""Check if capture button tutorial should be shown (legacy, calls generic method)."""
	if not current_node or current_node.is_controlled_by_player():
		return
	_check_node_info_tutorial()

func _get_highlightable_element(target_id: String) -> Control:
	"""Get the Control element to highlight by target_id."""
	match target_id:
		"capture_button":
			return _capture_button_ref
		"production_section":
			return _production_container
		"garrison_section":
			return _garrison_container
		"workers_section":
			return _workers_container
		"garrison_slot":
			# Return first empty garrison slot
			return _get_first_empty_garrison_slot()
		"worker_slot":
			# Return first empty worker slot
			return _get_first_empty_worker_slot()
	return null

func _get_first_empty_garrison_slot() -> Control:
	"""Find the first empty garrison slot for highlighting."""
	if not _garrison_container:
		return null
	# Look for slot boxes in garrison container
	for child in _garrison_container.get_children():
		if child is HBoxContainer:  # Slots row
			for slot in child.get_children():
				if slot.has_meta("is_empty") and slot.get_meta("is_empty"):
					if slot.has_meta("slot_type") and slot.get_meta("slot_type") == "garrison":
						return slot
	return _garrison_container  # Fallback to container

func _get_first_empty_worker_slot() -> Control:
	"""Find the first empty worker slot for highlighting."""
	if not _workers_container:
		return null
	# Look for slot boxes in workers container
	for child in _workers_container.get_children():
		if child is HBoxContainer:  # Slots row
			for slot in child.get_children():
				if slot.has_meta("is_empty") and slot.get_meta("is_empty"):
					if slot.has_meta("slot_type") and slot.get_meta("slot_type") == "worker":
						return slot
	return _workers_container  # Fallback to container

func _show_tutorial_highlight(target_id: String, message: String, title: String, show_button: bool, wait_for_action: String) -> void:
	"""Show tutorial highlight for a target element."""
	var target: Control = _get_highlightable_element(target_id)
	if not target or not is_instance_valid(target):
		print("NodeInfoPanel: Could not find highlight target '%s'" % target_id)
		return

	# Create highlight overlay if needed
	if not _tutorial_highlight_overlay:
		_tutorial_highlight_overlay = TutorialHighlightOverlay.new()
		# Add to root to ensure proper z-ordering
		var root: Node = get_tree().root
		if root:
			root.add_child(_tutorial_highlight_overlay)

	# Disconnect any existing signals to avoid duplicates
	if _tutorial_highlight_overlay.continue_pressed.is_connected(_on_tutorial_continue_pressed):
		_tutorial_highlight_overlay.continue_pressed.disconnect(_on_tutorial_continue_pressed)

	# Connect continue signal if showing button
	if show_button:
		_tutorial_highlight_overlay.continue_pressed.connect(_on_tutorial_continue_pressed, CONNECT_ONE_SHOT)

	# wait_for_click should be true only if we're waiting for a specific action (like slot tap)
	var wait_for_click: bool = not wait_for_action.is_empty() and not show_button

	_tutorial_highlight_overlay.highlight_target(target, message, title, "Got it!", wait_for_click, show_button)

func _on_tutorial_continue_pressed() -> void:
	"""Handle continue button press on tutorial highlight."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return

	var tutorial_orch: Node = registry.get_system("TutorialOrchestrator")
	if tutorial_orch:
		tutorial_orch.advance_tutorial()
		# Check for next highlight after advancing
		call_deferred("_check_node_info_tutorial")

func _highlight_capture_button(message: String, title: String) -> void:
	"""Highlight the capture button for tutorial (legacy method)."""
	_show_tutorial_highlight("capture_button", message, title, false, "")

func _clear_tutorial_highlight() -> void:
	"""Clear any active tutorial highlight."""
	if _tutorial_highlight_overlay:
		_tutorial_highlight_overlay.clear_highlight()

func _emit_tutorial_action(action_id: String) -> void:
	"""Emit a tutorial action via EventBus."""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return
	var event_bus: Node = registry.get_system("EventBus")
	if event_bus and event_bus.has_signal("tutorial_action_completed"):
		event_bus.tutorial_action_completed.emit(action_id)
