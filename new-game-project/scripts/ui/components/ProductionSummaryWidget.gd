# scripts/ui/components/ProductionSummaryWidget.gd
# Widget showing production summary on home screen with collect all functionality
extends PanelContainer
class_name ProductionSummaryWidget

"""
ProductionSummaryWidget - Home screen production overview
Shows: hourly rates (all resources), refiners, active crafts, accumulated
Auto-updates every few seconds to show growing resources
"""

const ProductionDisplayHelperScript = preload("res://scripts/ui/components/ProductionDisplayHelper.gd")
const CraftTrackerDisplayScript = preload("res://scripts/ui/components/CraftTrackerDisplay.gd")

signal resources_collected(total: Dictionary)
signal craft_collected(task_data: Dictionary)
signal navigate_to_crafting_requested

# Colors from UI patterns
const COLOR_HEADER := Color(0.9, 0.85, 0.7)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)
const COLOR_GOLD := Color(0.95, 0.85, 0.5)
const COLOR_REFINER := Color(0.8, 0.65, 0.4)

const UPDATE_INTERVAL: float = 2.0
const CRAFT_UPDATE_INTERVAL: float = 1.0

var _update_timer: Timer = null
var _craft_update_timer: Timer = null
var _content_container: VBoxContainer = null
var _collect_button: Button = null

# Column sections
var _production_section: VBoxContainer = null
var _refiner_section: VBoxContainer = null
var _accumulated_section: VBoxContainer = null

# Cached data
var _cached_rates: Dictionary = {}
var _cached_conversions: Array = []
var _cached_accumulated: Dictionary = {}

# Helpers
var _display_helper: RefCounted = null
var _craft_tracker: RefCounted = null

func _ready() -> void:
	_setup_styling()
	_create_ui()
	_start_update_timer()
	call_deferred("_update_display")

func _setup_styling() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(600, 160)

func _create_ui() -> void:
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 6)
	add_child(_content_container)

	# Header row
	var header: HBoxContainer = _create_header()
	_content_container.add_child(header)

	# Three-column layout for production data
	var columns_container: HBoxContainer = HBoxContainer.new()
	columns_container.add_theme_constant_override("separation", 8)
	columns_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(columns_container)

	# Column 1: Production rates
	var prod_result: Array = _create_column("PRODUCTION /hr", "production")
	_production_section = prod_result[0] as VBoxContainer
	var prod_grid: GridContainer = prod_result[1] as GridContainer
	_production_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(_production_section)

	# Vertical separator
	var vsep1: VSeparator = VSeparator.new()
	vsep1.add_theme_constant_override("separation", 2)
	columns_container.add_child(vsep1)

	# Column 2: Refiners
	var ref_result: Array = _create_column("REFINERS", "refiner")
	_refiner_section = ref_result[0] as VBoxContainer
	var ref_grid: GridContainer = ref_result[1] as GridContainer
	_refiner_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(_refiner_section)

	# Vertical separator
	var vsep2: VSeparator = VSeparator.new()
	vsep2.add_theme_constant_override("separation", 2)
	columns_container.add_child(vsep2)

	# Column 3: Ready to collect
	var acc_result: Array = _create_column("READY TO COLLECT", "accumulated")
	_accumulated_section = acc_result[0] as VBoxContainer
	var acc_grid: GridContainer = acc_result[1] as GridContainer
	_accumulated_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(_accumulated_section)

	# Initialize display helper with grids
	_display_helper = ProductionDisplayHelperScript.new()
	_display_helper.initialize(prod_grid, ref_grid, acc_grid)

	# Separator before crafting
	var sep: HSeparator = HSeparator.new()
	_content_container.add_child(sep)

	# Initialize craft tracker
	_craft_tracker = CraftTrackerDisplayScript.new()
	_craft_tracker.craft_collected.connect(func(task_data: Dictionary) -> void: craft_collected.emit(task_data))
	_craft_tracker.navigate_to_crafting_requested.connect(func() -> void: navigate_to_crafting_requested.emit())
	_craft_tracker.initialize(_content_container, self)

func _create_header() -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var icon: Label = Label.new()
	icon.text = "⚡"
	icon.add_theme_font_size_override("font_size", 16)
	header.add_child(icon)

	var title: Label = Label.new()
	title.text = "TERRITORY PRODUCTION"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	header.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_collect_button = Button.new()
	_collect_button.text = "Collect All"
	_collect_button.pressed.connect(_on_collect_all_pressed)
	_style_button(_collect_button, true)
	header.add_child(_collect_button)

	return header

func _create_column(title: String, section_type: String) -> Array:
	"""Create a column for the 3-column layout. Returns [VBoxContainer, GridContainer]"""
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)

	var section_icon: Label = Label.new()
	match section_type:
		"production":
			section_icon.text = "📈"
		"refiner":
			section_icon.text = "⚙️"
		"accumulated":
			section_icon.text = "💎"
	section_icon.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(section_icon)

	var section_title: Label = Label.new()
	section_title.text = title
	section_title.add_theme_font_size_override("font_size", 10)
	match section_type:
		"production":
			section_title.add_theme_color_override("font_color", COLOR_SUCCESS)
		"refiner":
			section_title.add_theme_color_override("font_color", COLOR_REFINER)
		"accumulated":
			section_title.add_theme_color_override("font_color", COLOR_GOLD)
	header_hbox.add_child(section_title)

	column.add_child(header_hbox)

	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)

	return [column, grid]

func _style_button(button: Button, primary: bool = false) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if primary:
		style.bg_color = Color(0.3, 0.5, 0.3, 0.9)
		style.border_color = Color(0.5, 0.8, 0.5, 0.8)
	else:
		style.bg_color = Color(0.5, 0.35, 0.2, 0.9)
		style.border_color = Color(0.7, 0.5, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))

# ==============================================================================
# TIMERS
# ==============================================================================

func _start_update_timer() -> void:
	_update_timer = Timer.new()
	_update_timer.wait_time = UPDATE_INTERVAL
	_update_timer.timeout.connect(_update_display)
	_update_timer.autostart = true
	add_child(_update_timer)

	_craft_update_timer = Timer.new()
	_craft_update_timer.wait_time = CRAFT_UPDATE_INTERVAL
	_craft_update_timer.timeout.connect(_update_craft_display)
	_craft_update_timer.autostart = true
	add_child(_craft_update_timer)

# ==============================================================================
# DISPLAY UPDATES
# ==============================================================================

func _update_display() -> void:
	if not is_visible_in_tree():
		return

	var production_manager: Variant = _get_production_manager()
	var hex_grid_manager: Variant = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		return

	var player_nodes: Array = _get_player_nodes(hex_grid_manager)

	_cached_rates = production_manager.get_all_hex_nodes_production()
	_cached_conversions = _craft_tracker.get_refiner_conversions(hex_grid_manager, player_nodes)
	_cached_accumulated = _get_total_accumulated_resources(player_nodes)

	_display_helper.update_production_grid(_cached_rates)
	_display_helper.update_refiner_grid(_cached_conversions)
	_display_helper.update_accumulated_grid(_cached_accumulated)
	_update_collect_button_state()

func _update_craft_display() -> void:
	if not is_visible_in_tree():
		return

	var hex_grid_manager: Variant = _get_hex_grid_manager()
	_craft_tracker.update_craft_display(hex_grid_manager)

func _update_collect_button_state() -> void:
	var has_resources: bool = false
	for resource_id: String in _cached_accumulated:
		if _cached_accumulated[resource_id] >= 0.1:
			has_resources = true
			break

	_collect_button.disabled = not has_resources
	_collect_button.text = "Collect All" if has_resources else "Empty"

# ==============================================================================
# COLLECTION
# ==============================================================================

func _on_collect_all_pressed() -> void:
	var production_manager: Variant = _get_production_manager()
	var hex_grid_manager: Variant = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		return

	var total_collected: Dictionary = {}
	var player_nodes: Array = _get_player_nodes(hex_grid_manager)

	for node: HexNode in player_nodes:
		if not node.accumulated_resources or node.accumulated_resources.is_empty():
			continue

		var collected: Dictionary = production_manager.collect_node_resources(node.id)
		for resource_id: String in collected:
			total_collected[resource_id] = total_collected.get(resource_id, 0) + collected[resource_id]

	if not total_collected.is_empty():
		resources_collected.emit(total_collected)
		_show_collection_feedback(total_collected)

	_update_display()

func _show_collection_feedback(collected: Dictionary) -> void:
	var original: Color = _collect_button.modulate
	_collect_button.modulate = Color(0.5, 1.0, 0.5, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(_collect_button, "modulate", original, 0.3)

	var total: float = 0.0
	for resource_id: String in collected:
		total += collected[resource_id]

	_collect_button.text = "+%s!" % _display_helper.format_number(total)
	await get_tree().create_timer(1.5).timeout
	_update_collect_button_state()

# ==============================================================================
# DATA HELPERS
# ==============================================================================

func _get_total_accumulated_resources(player_nodes: Array) -> Dictionary:
	var total: Dictionary = {}
	for node: HexNode in player_nodes:
		if not node.accumulated_resources or node.accumulated_resources.is_empty():
			continue

		for resource_id: String in node.accumulated_resources:
			var amount: float = node.accumulated_resources[resource_id]
			if amount > 0:
				total[resource_id] = total.get(resource_id, 0) + amount

	return total

func _get_player_nodes(_hex_grid_manager: Variant) -> Array:
	var territory_manager: Variant = _get_territory_manager()
	if territory_manager and territory_manager.has_method("get_controlled_nodes"):
		return territory_manager.get_controlled_nodes()
	return []

# ==============================================================================
# SYSTEM ACCESS
# ==============================================================================

func _get_production_manager() -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("TerritoryProductionManager")
	return null

func _get_hex_grid_manager() -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("HexGridManager")
	return null

func _get_territory_manager() -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("TerritoryManager")
	return null

func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null
