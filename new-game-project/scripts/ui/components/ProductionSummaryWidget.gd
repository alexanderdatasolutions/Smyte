# scripts/ui/components/ProductionSummaryWidget.gd
# Widget showing production summary on home screen with collect all functionality
extends PanelContainer
class_name ProductionSummaryWidget

"""
ProductionSummaryWidget - Home screen production overview
Shows: hourly rates (all resources), refiners, active crafts, accumulated
Auto-updates every few seconds to show growing resources
"""

signal resources_collected(total: Dictionary)
signal craft_collected(task_data: Dictionary)
signal navigate_to_crafting_requested

# Colors from UI patterns
const COLOR_HEADER = Color(0.9, 0.85, 0.7)
const COLOR_TEXT = Color(0.75, 0.75, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_GOLD = Color(0.95, 0.85, 0.5)
const COLOR_REFINER = Color(0.8, 0.65, 0.4)

const UPDATE_INTERVAL: float = 2.0
const CRAFT_UPDATE_INTERVAL: float = 1.0

var _update_timer: Timer = null
var _craft_update_timer: Timer = null
var _content_container: VBoxContainer = null
var _collect_button: Button = null

# Expandable sections
var _production_section: VBoxContainer = null
var _production_grid: GridContainer = null

var _refiner_section: VBoxContainer = null
var _refiner_grid: GridContainer = null

var _craft_section: VBoxContainer = null
var _craft_list: VBoxContainer = null
var _craft_button: Button = null

var _accumulated_section: VBoxContainer = null
var _accumulated_grid: GridContainer = null

# Cached data
var _cached_rates: Dictionary = {}
var _cached_conversions: Array = []
var _cached_accumulated: Dictionary = {}
var _buildings_data: Dictionary = {}

# Craft popup
var _craft_popup: Control = null
var _recipes_data: Dictionary = {}
var _current_craft_node: HexNode = null
var _crafting_screen_manager: CraftingScreenManager = null

func _ready() -> void:
	_load_buildings_data()
	_load_recipes_data()
	_setup_styling()
	_create_ui()
	_start_update_timer()
	call_deferred("_update_display")

func _load_buildings_data() -> void:
	"""Load buildings data for refiner info"""
	var file = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			_buildings_data = data.get("buildings", {})
		file.close()

func _load_recipes_data() -> void:
	"""Load crafting recipes data"""
	var file = FileAccess.open("res://data/crafting_recipes.json", FileAccess.READ)
	if file:
		var json: JSON = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_recipes_data = json.get_data()
		file.close()

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
	custom_minimum_size = Vector2(600, 160)  # Wide for 3 multi-column layout

func _create_ui() -> void:
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 6)
	add_child(_content_container)

	# Header row
	var header = _create_header()
	_content_container.add_child(header)

	# Three-column layout for production data
	var columns_container: HBoxContainer = HBoxContainer.new()
	columns_container.add_theme_constant_override("separation", 8)
	columns_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_child(columns_container)

	# Column 1: Production rates
	_production_section = _create_column("PRODUCTION /hr", "production")
	_production_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(_production_section)

	# Vertical separator
	var vsep1: VSeparator = VSeparator.new()
	vsep1.add_theme_constant_override("separation", 2)
	columns_container.add_child(vsep1)

	# Column 2: Refiners
	_refiner_section = _create_column("REFINERS", "refiner")
	_refiner_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(_refiner_section)

	# Vertical separator
	var vsep2: VSeparator = VSeparator.new()
	vsep2.add_theme_constant_override("separation", 2)
	columns_container.add_child(vsep2)

	# Column 3: Ready to collect
	_accumulated_section = _create_column("READY TO COLLECT", "accumulated")
	_accumulated_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(_accumulated_section)

	# Separator before crafting
	var sep: HSeparator = HSeparator.new()
	_content_container.add_child(sep)

	# Crafting section
	_create_craft_section()

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

func _create_column(title: String, section_type: String) -> VBoxContainer:
	"""Create a column for the 3-column layout"""
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Column header
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

	# Content grid - multiple columns for compact display (icon+value pairs, 3 pairs per row = 6 columns)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6  # 3 pairs of icon+value per row
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)

	# Store reference
	match section_type:
		"production":
			_production_grid = grid
		"refiner":
			_refiner_grid = grid
		"accumulated":
			_accumulated_grid = grid

	return column

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

	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))

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

func _update_display() -> void:
	if not is_visible_in_tree():
		return

	var production_manager = _get_production_manager()
	var hex_grid_manager = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		return

	# Get production rates and conversions
	_cached_rates = production_manager.get_all_hex_nodes_production()
	_cached_conversions = _get_refiner_conversions(hex_grid_manager)
	_cached_accumulated = _get_total_accumulated_resources(hex_grid_manager)

	_update_production_grid()
	_update_refiner_grid()
	_update_accumulated_grid()
	_update_collect_button_state()

func _get_refiner_conversions(hex_grid_manager) -> Array:
	"""Get all active refiner/processing building conversions"""
	var conversions: Array = []
	var player_nodes = _get_player_nodes(hex_grid_manager)

	for node in player_nodes:
		if not node.placed_building:
			continue

		var building = _buildings_data.get(node.placed_building, {})
		var consumes = building.get("consumes", {})
		var production = building.get("production", {})

		if not consumes.is_empty() and not production.is_empty():
			conversions.append({
				"name": building.get("name", node.placed_building),
				"consumes": consumes,
				"produces": production,
				"node_name": node.name
			})

	return conversions

func _update_production_grid() -> void:
	if not _production_grid:
		return

	for child in _production_grid.get_children():
		child.queue_free()

	if _cached_rates.is_empty():
		var empty: Label = Label.new()
		empty.text = "No production"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_production_grid.columns = 1
		_production_grid.add_child(empty)
		return

	_production_grid.columns = 6  # 3 pairs per row

	# Sort by rate descending
	var sorted_resources = _cached_rates.keys()
	sorted_resources.sort_custom(func(a, b): return _cached_rates[a] > _cached_rates[b])

	for resource_id in sorted_resources:
		var rate = _cached_rates[resource_id]
		if rate <= 0:
			continue

		var items = _create_rate_item(resource_id, rate)
		for item in items:
			_production_grid.add_child(item)

func _update_refiner_grid() -> void:
	if not _refiner_grid:
		return

	for child in _refiner_grid.get_children():
		child.queue_free()

	if _cached_conversions.is_empty():
		var empty: Label = Label.new()
		empty.text = "No refiners"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_refiner_grid.columns = 1
		_refiner_grid.add_child(empty)
		return

	_refiner_grid.columns = 6  # 3 pairs per row

	for conversion in _cached_conversions:
		var items = _create_conversion_item(conversion)
		for item in items:
			_refiner_grid.add_child(item)

func _update_accumulated_grid() -> void:
	if not _accumulated_grid:
		return

	for child in _accumulated_grid.get_children():
		child.queue_free()

	if _cached_accumulated.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nothing ready"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_accumulated_grid.columns = 1
		_accumulated_grid.add_child(empty)
		return

	_accumulated_grid.columns = 6  # 3 pairs per row

	# Sort by amount descending
	var sorted_resources = _cached_accumulated.keys()
	sorted_resources.sort_custom(func(a, b): return _cached_accumulated[a] > _cached_accumulated[b])

	for resource_id in sorted_resources:
		var amount = _cached_accumulated[resource_id]
		if amount < 0.1:
			continue

		var items = _create_accumulated_item(resource_id, amount)
		for item in items:
			_accumulated_grid.add_child(item)

func _create_rate_item(resource_id: String, rate: float) -> Array:
	"""Returns [icon_label, value_label] for 2-column grid"""
	var tooltip: String = "%s: +%.1f per hour" % [resource_id.replace("_", " ").capitalize(), rate]

	var icon: Label = Label.new()
	icon.text = _get_resource_icon(resource_id)
	icon.add_theme_font_size_override("font_size", 11)
	icon.tooltip_text = tooltip
	icon.mouse_filter = Control.MOUSE_FILTER_PASS

	var rate_label: Label = Label.new()
	rate_label.text = "+%s" % _format_number(rate)
	rate_label.add_theme_font_size_override("font_size", 10)
	rate_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	rate_label.tooltip_text = tooltip
	rate_label.mouse_filter = Control.MOUSE_FILTER_PASS

	return [icon, rate_label]

func _create_conversion_item(conversion: Dictionary) -> Array:
	"""Returns [icon_label, value_label] for 2-column grid"""
	# Build tooltip
	var input_str: String = ""
	for res_id in conversion.consumes:
		input_str += "%d %s, " % [conversion.consumes[res_id], res_id.replace("_", " ")]
	input_str = input_str.trim_suffix(", ")

	var output_str: String = ""
	for res_id in conversion.produces:
		output_str += "%d %s, " % [conversion.produces[res_id], res_id.replace("_", " ")]
	output_str = output_str.trim_suffix(", ")

	var tooltip: String = "%s\nConverts: %s/hr\nProduces: %s/hr" % [conversion.name, input_str, output_str]

	# Show compact: input icon -> output icon
	var first_input = conversion.consumes.keys()[0] if not conversion.consumes.is_empty() else ""
	var first_output = conversion.produces.keys()[0] if not conversion.produces.is_empty() else ""
	var output_rate = conversion.produces.get(first_output, 0)

	var icons_label: Label = Label.new()
	icons_label.text = "%s→%s" % [_get_resource_icon(first_input), _get_resource_icon(first_output)]
	icons_label.add_theme_font_size_override("font_size", 10)
	icons_label.tooltip_text = tooltip
	icons_label.mouse_filter = Control.MOUSE_FILTER_PASS

	var rate_label: Label = Label.new()
	rate_label.text = "+%s" % _format_number(output_rate)
	rate_label.add_theme_font_size_override("font_size", 10)
	rate_label.add_theme_color_override("font_color", COLOR_REFINER)
	rate_label.tooltip_text = tooltip
	rate_label.mouse_filter = Control.MOUSE_FILTER_PASS

	return [icons_label, rate_label]

func _create_accumulated_item(resource_id: String, amount: float) -> Array:
	"""Returns [icon_label, value_label] for 2-column grid"""
	var tooltip: String = "%s: %.1f ready to collect" % [resource_id.replace("_", " ").capitalize(), amount]

	var icon: Label = Label.new()
	icon.text = _get_resource_icon(resource_id)
	icon.add_theme_font_size_override("font_size", 11)
	icon.tooltip_text = tooltip
	icon.mouse_filter = Control.MOUSE_FILTER_PASS

	var amount_label: Label = Label.new()
	amount_label.text = _format_number(amount)
	amount_label.add_theme_font_size_override("font_size", 10)
	amount_label.add_theme_color_override("font_color", COLOR_GOLD)
	amount_label.tooltip_text = tooltip
	amount_label.mouse_filter = Control.MOUSE_FILTER_PASS

	return [icon, amount_label]

func _update_collect_button_state() -> void:
	var has_resources: bool = false
	for resource_id in _cached_accumulated:
		if _cached_accumulated[resource_id] >= 0.1:
			has_resources = true
			break

	_collect_button.disabled = not has_resources
	_collect_button.text = "Collect All" if has_resources else "Empty"

func _on_collect_all_pressed() -> void:
	var production_manager = _get_production_manager()
	var hex_grid_manager = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		return

	var total_collected: Dictionary = {}
	var player_nodes = _get_player_nodes(hex_grid_manager)

	for node in player_nodes:
		if not node.accumulated_resources or node.accumulated_resources.is_empty():
			continue

		var collected = production_manager.collect_node_resources(node.id)
		for resource_id in collected:
			total_collected[resource_id] = total_collected.get(resource_id, 0) + collected[resource_id]

	if not total_collected.is_empty():
		resources_collected.emit(total_collected)
		_show_collection_feedback(total_collected)

	_update_display()

func _show_collection_feedback(collected: Dictionary) -> void:
	var original = _collect_button.modulate
	_collect_button.modulate = Color(0.5, 1.0, 0.5, 1.0)

	var tween = create_tween()
	tween.tween_property(_collect_button, "modulate", original, 0.3)

	var total: float = 0.0
	for resource_id in collected:
		total += collected[resource_id]

	_collect_button.text = "+%s!" % _format_number(total)
	await get_tree().create_timer(1.5).timeout
	_update_collect_button_state()

func _get_total_accumulated_resources(hex_grid_manager) -> Dictionary:
	var total: Dictionary = {}
	var player_nodes = _get_player_nodes(hex_grid_manager)

	for node in player_nodes:
		if not node.accumulated_resources or node.accumulated_resources.is_empty():
			continue

		for resource_id in node.accumulated_resources:
			var amount = node.accumulated_resources[resource_id]
			if amount > 0:
				total[resource_id] = total.get(resource_id, 0) + amount

	return total

func _get_player_nodes(_hex_grid_manager) -> Array:
	var territory_manager = _get_territory_manager()
	if territory_manager and territory_manager.has_method("get_controlled_nodes"):
		return territory_manager.get_controlled_nodes()
	return []

# ==============================================================================
# CRAFT TRACKER SECTION
# ==============================================================================
func _create_craft_section() -> void:
	_craft_section = VBoxContainer.new()
	_craft_section.add_theme_constant_override("separation", 4)
	_content_container.add_child(_craft_section)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_craft_section.add_child(header)

	var icon: Label = Label.new()
	icon.text = "⚒️"
	icon.add_theme_font_size_override("font_size", 14)
	header.add_child(icon)

	var title: Label = Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
	header.add_child(title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_craft_button = Button.new()
	_craft_button.text = "Blacksmith"
	_craft_button.pressed.connect(_on_craft_button_pressed)
	_style_button(_craft_button, false)
	header.add_child(_craft_button)

	# No crafts message
	var no_crafts: HBoxContainer = HBoxContainer.new()
	no_crafts.name = "NoCrafts"
	_craft_section.add_child(no_crafts)

	var no_label: Label = Label.new()
	no_label.text = "No active crafts"
	no_label.add_theme_font_size_override("font_size", 11)
	no_label.add_theme_color_override("font_color", COLOR_MUTED)
	no_crafts.add_child(no_label)

	_craft_list = VBoxContainer.new()
	_craft_list.name = "CraftList"
	_craft_list.add_theme_constant_override("separation", 4)
	_craft_section.add_child(_craft_list)

func _update_craft_display() -> void:
	if not is_visible_in_tree():
		return

	_craft_section.visible = true

	var hex_grid_manager = _get_hex_grid_manager()
	if not hex_grid_manager:
		_show_no_blacksmiths_state()
		return

	# Get all player-owned crafting buildings
	var blacksmith_nodes = _get_player_blacksmith_nodes(hex_grid_manager)

	if blacksmith_nodes.is_empty():
		_show_no_blacksmiths_state()
		return

	# Show each blacksmith on its own line
	_show_blacksmith_list(blacksmith_nodes, hex_grid_manager)

func _get_player_blacksmith_nodes(hex_grid_manager) -> Array:
	"""Get all player-owned crafting building nodes"""
	var nodes: Array = []
	var crafting_types: Array = ["blacksmith", "weapon_forge", "armor_forge", "divine_forge"]

	# Get all player-controlled nodes and check their placed_building
	var all_nodes: Array = []
	if hex_grid_manager.has_method("get_nodes_by_controller"):
		all_nodes = hex_grid_manager.get_nodes_by_controller("player")
	elif hex_grid_manager.has_method("get_all_nodes"):
		all_nodes = hex_grid_manager.get_all_nodes()

	for node in all_nodes:
		if not node.is_controlled_by_player():
			continue
		var building = node.placed_building if node.placed_building else ""
		if building in crafting_types:
			nodes.append(node)

	return nodes

func _show_no_blacksmiths_state() -> void:
	var no_crafts = _craft_section.get_node_or_null("NoCrafts")
	if no_crafts:
		no_crafts.visible = true
		# Update the message to say no blacksmiths
		for child in no_crafts.get_children():
			if child is Label:
				child.text = "No blacksmiths owned"
	_craft_list.visible = false
	# Hide the header craft button since we show per-node buttons now
	if _craft_button:
		_craft_button.visible = false

func _show_blacksmith_list(blacksmith_nodes: Array, hex_grid_manager) -> void:
	var no_crafts = _craft_section.get_node_or_null("NoCrafts")
	if no_crafts:
		no_crafts.visible = false
	_craft_list.visible = true
	# Hide the header craft button since we show per-node buttons now
	if _craft_button:
		_craft_button.visible = false

	for child in _craft_list.get_children():
		child.queue_free()

	var current_time: int = int(Time.get_unix_time_from_system())
	var count: int = 0

	for node in blacksmith_nodes:
		if count >= 4:  # Show max 4 blacksmiths
			break

		# Check if this node has an active craft
		var active_crafts_for_node: Array = []
		if hex_grid_manager.has_method("get_active_crafts_for_node"):
			active_crafts_for_node = hex_grid_manager.get_active_crafts_for_node(node.id)

		if active_crafts_for_node.is_empty():
			# No active craft - show idle state with Craft button
			var item = _create_idle_blacksmith_item(node)
			_craft_list.add_child(item)
		else:
			# Has active craft - show progress
			var craft_data = active_crafts_for_node[0]  # Show first active craft
			var item = _create_craft_progress_item(craft_data, current_time, node.name)
			_craft_list.add_child(item)

		count += 1

	if blacksmith_nodes.size() > 4:
		var more: Label = Label.new()
		more.text = "+%d more smithies..." % (blacksmith_nodes.size() - 4)
		more.add_theme_font_size_override("font_size", 10)
		more.add_theme_color_override("font_color", COLOR_MUTED)
		_craft_list.add_child(more)

func _create_idle_blacksmith_item(node: HexNode) -> HBoxContainer:
	"""Create a row for a blacksmith with no active craft"""
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)

	# Node name
	var node_name = node.name if node.name.length() <= 16 else node.name.substr(0, 14) + ".."
	var name_label: Label = Label.new()
	name_label.text = "⚒️ " + node_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	name_label.custom_minimum_size.x = 120
	item.add_child(name_label)

	# Idle status
	var status_label: Label = Label.new()
	status_label.text = "Idle"
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", COLOR_MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(status_label)

	# Craft button
	var craft_btn: Button = Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(50, 18)
	craft_btn.pressed.connect(_on_open_craft_for_node.bind(node))

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.5, 0.35, 0.2, 0.9)
	btn_style.border_color = Color(0.7, 0.5, 0.3, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	craft_btn.add_theme_stylebox_override("normal", btn_style)

	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color(0.6, 0.45, 0.3, 0.9)
	craft_btn.add_theme_stylebox_override("hover", hover_style)

	craft_btn.add_theme_font_size_override("font_size", 9)
	craft_btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	item.add_child(craft_btn)

	return item

func _on_open_craft_for_node(node: HexNode) -> void:
	"""Open the craft popup for a specific blacksmith node - directly on WorldView"""
	_current_craft_node = node
	_show_craft_popup(node)

# ==============================================================================
# CRAFT POPUP - Opens directly on WorldView
# ==============================================================================

func _show_craft_popup(node: HexNode) -> void:
	"""Show the crafting screen for a specific blacksmith node using CraftingScreenManager"""
	# Clean up any existing popup
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()
		_craft_popup = null

	var available_recipes := _get_available_recipes_for_node(node)
	if available_recipes.is_empty():
		return

	var hex_grid_manager = _get_hex_grid_manager()
	var resource_manager = _get_resource_manager()

	# Use the new CraftingScreenManager
	_crafting_screen_manager = CraftingScreenManager.new()
	_crafting_screen_manager.craft_started.connect(_on_craft_started_from_screen)
	_crafting_screen_manager.popup_closed.connect(_on_crafting_screen_closed)

	# Get the Main node to add the crafting screen to
	var parent_node: Node = get_tree().root.get_node_or_null("Main")
	if not parent_node:
		parent_node = get_tree().root

	_crafting_screen_manager.show_crafting_screen(node, available_recipes, hex_grid_manager, resource_manager, parent_node)

func _create_popup_overlay(viewport_size: Vector2) -> Control:
	"""Create the full-screen popup container with dark background"""
	var overlay := Control.new()
	overlay.name = "CraftPopup"
	overlay.z_index = 100
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.size = viewport_size

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.size = viewport_size
	bg.color = Color(0, 0, 0, 0.7)
	bg.gui_input.connect(_on_popup_bg_clicked)
	overlay.add_child(bg)

	return overlay

func _create_popup_panel(viewport_size: Vector2) -> PanelContainer:
	"""Create the centered popup panel with styling"""
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_width := mini(viewport_size.x * 0.9, 680)
	var panel_height := viewport_size.y * 0.75
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size = Vector2(panel_width, panel_height)
	panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	return panel

func _add_popup_header(content: VBoxContainer, node_name: String) -> void:
	"""Add title and close button to popup content"""
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)

	var title := Label.new()
	title.text = "⚒️ FORGE: " + node_name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(_close_craft_popup)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.4, 0.2, 0.2, 0.9)
	close_style.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_font_size_override("font_size", 16)
	header.add_child(close_btn)

func _add_popup_tier_info(content: VBoxContainer, tier: int, recipe_count: int) -> void:
	"""Add tier info label to popup content"""
	var tier_label := Label.new()
	tier_label.text = "Tier %d Forge  •  %d recipes available" % [tier, recipe_count]
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	content.add_child(tier_label)

func _add_popup_recipe_grid(content: VBoxContainer, recipes: Array, node: HexNode) -> void:
	"""Add scrollable recipe grid to popup content"""
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var grid := CraftingUIUtils.create_recipe_grid(3)
	scroll.add_child(grid)

	var resource_manager = _get_resource_manager()
	for recipe in recipes:
		var costs: Dictionary = recipe.get("materials", recipe.get("resource_costs", {}))
		var can_afford := true
		if resource_manager and not costs.is_empty():
			can_afford = resource_manager.can_afford(costs)

		var craft_callback := func(task: Dictionary, _auto_repeat): _on_start_craft(task, node)
		var card := CraftingUIUtils.create_recipe_card(recipe, can_afford, craft_callback, false, resource_manager)
		grid.add_child(card)

func _get_available_recipes_for_node(node: HexNode) -> Array:
	"""Get equipment recipes available for a blacksmith node (flattened JSON structure)"""
	var available: Array = []
	var max_tier = node.tier

	# Iterate over top-level keys (flattened structure - no nesting)
	for recipe_id in _recipes_data.keys():
		# Skip metadata and comment keys
		if recipe_id.begins_with("_"):
			continue

		var recipe = _recipes_data[recipe_id]
		if not recipe is Dictionary:
			continue

		# Get recipe tier
		var recipe_tier = recipe.get("tier", recipe.get("territory_tier_requirement", 1))

		# Must meet tier requirement
		if recipe_tier > max_tier:
			continue

		# Add id to recipe for reference
		var recipe_with_id = recipe.duplicate()
		recipe_with_id["id"] = recipe_id
		available.append(recipe_with_id)

	return available

func _on_popup_bg_clicked(event: InputEvent) -> void:
	"""Close popup when clicking on background"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_craft_popup()

func _close_craft_popup() -> void:
	"""Close the craft popup"""
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()
		_craft_popup = null
	_current_craft_node = null
	_crafting_screen_manager = null

func _on_craft_started_from_screen(_node: HexNode, task_id: String) -> void:
	"""Handle craft started from the new CraftingScreenManager"""
	_update_craft_display()
	var task_data: Dictionary = _recipes_data.get(task_id, {})
	var task_name: String = task_data.get("name", task_id)
	_show_craft_success(task_name)

func _on_crafting_screen_closed() -> void:
	"""Handle crafting screen closed"""
	_crafting_screen_manager = null
	_current_craft_node = null
	_update_craft_display()

func _on_start_craft(task: Dictionary, node: HexNode) -> void:
	"""Handle starting a craft task"""
	var task_id = task.get("id", "")
	if task_id.is_empty():
		return

	var resource_manager = _get_resource_manager()
	var hex_grid_manager = _get_hex_grid_manager()

	# Check and spend resources
	var costs = task.get("materials", task.get("resource_costs", {}))
	if not costs.is_empty():
		if not resource_manager:
			return
		if not resource_manager.can_afford(costs):
			return
		if not resource_manager.spend_resources(costs):
			return

	# Start the craft
	var craft_started: bool = false
	if hex_grid_manager:
		craft_started = hex_grid_manager.start_craft(node.id, task_id, task)

	if not craft_started:
		# Refund resources
		if resource_manager:
			for resource_id in costs:
				resource_manager.add_resource(resource_id, costs[resource_id])
		_show_craft_error("Forge busy or no worker assigned")
		return

	_close_craft_popup()
	_update_craft_display()
	_show_craft_success(task.get("name", "Item"))

func _show_craft_error(message: String) -> void:
	"""Show error feedback"""
	# Simple feedback - flash the popup border red briefly
	pass

func _show_craft_success(item_name: String) -> void:
	"""Show success feedback"""
	# Brief visual feedback
	pass

func _create_craft_progress_item(craft_data: Dictionary, current_time: int, node_name: String = "") -> HBoxContainer:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)

	var task_data = craft_data.get("task_data", {})
	var task_name = task_data.get("name", "Crafting...")
	var start_time = craft_data.get("start_time", current_time)
	var end_time = craft_data.get("end_time", current_time + 60)

	var total_duration = end_time - start_time
	var elapsed = current_time - start_time
	var progress = clampf(float(elapsed) / float(total_duration), 0.0, 1.0)
	var remaining = maxi(0, end_time - current_time)
	var is_complete = progress >= 1.0

	# Node name (blacksmith location)
	var display_name = node_name if node_name != "" else task_name
	if display_name.length() > 14:
		display_name = display_name.substr(0, 12) + ".."

	var node_label: Label = Label.new()
	node_label.text = "⚒️ " + display_name
	node_label.add_theme_font_size_override("font_size", 10)
	node_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	node_label.custom_minimum_size.x = 100
	item.add_child(node_label)

	# Progress bar container
	var progress_container: Panel = Panel.new()
	progress_container.custom_minimum_size = Vector2(80, 14)
	progress_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var prog_style: StyleBoxFlat = StyleBoxFlat.new()
	prog_style.bg_color = Color(0.15, 0.15, 0.18)
	prog_style.set_corner_radius_all(3)
	progress_container.add_theme_stylebox_override("panel", prog_style)
	item.add_child(progress_container)

	# Progress fill bar
	var fill: ColorRect = ColorRect.new()
	fill.color = Color(0.3, 0.7, 0.4) if is_complete else Color(0.5, 0.4, 0.25)
	fill.anchor_right = progress
	fill.anchor_bottom = 1.0
	fill.offset_left = 1
	fill.offset_top = 1
	fill.offset_bottom = -1
	progress_container.add_child(fill)

	# Countdown timer / status
	var status_label: Label = Label.new()
	if is_complete:
		status_label.text = "✓ Ready!"
		status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		status_label.text = _format_duration(remaining)
		status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.custom_minimum_size.x = 55
	item.add_child(status_label)

	# Collect button when complete
	if is_complete:
		var collect_btn: Button = Button.new()
		collect_btn.text = "Collect"
		collect_btn.custom_minimum_size = Vector2(50, 18)
		collect_btn.pressed.connect(_on_collect_craft.bind(craft_data))

		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.5, 0.3, 0.9)
		btn_style.set_corner_radius_all(3)
		collect_btn.add_theme_stylebox_override("normal", btn_style)
		collect_btn.add_theme_font_size_override("font_size", 9)
		collect_btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		item.add_child(collect_btn)

	return item

func _format_duration(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		return "%dm %ds" % [seconds / 60, seconds % 60]
	else:
		return "%dh %dm" % [seconds / 3600, (seconds % 3600) / 60]

func _on_craft_button_pressed() -> void:
	navigate_to_crafting_requested.emit()

	var hex_grid_manager = _get_hex_grid_manager()
	if not hex_grid_manager:
		return

	# Find player-owned crafting building
	var crafting_types: Array = ["blacksmith", "weapon_forge", "armor_forge", "divine_forge"]
	var player_smithy: HexNode = null

	for building_type in crafting_types:
		if hex_grid_manager.has_method("get_nodes_by_building"):
			var nodes = hex_grid_manager.get_nodes_by_building(building_type)
			for node in nodes:
				if node.is_controlled_by_player():
					player_smithy = node
					break
		if player_smithy:
			break

	if not player_smithy:
		return

	var screen_manager = _get_screen_manager()
	if not screen_manager:
		return

	var smithy_id = player_smithy.id
	if not screen_manager.screen_transition_completed.is_connected(_on_territory_screen_ready):
		screen_manager.screen_transition_completed.connect(_on_territory_screen_ready.bind(smithy_id), CONNECT_ONE_SHOT)

	screen_manager.change_screen("territory")

func _on_territory_screen_ready(screen_name: String, smithy_id: String) -> void:
	if screen_name != "territory" and screen_name != "hex_territory":
		return

	var screen_manager = _get_screen_manager()
	if not screen_manager:
		return

	var territory_screen = screen_manager.get_current_screen()
	if territory_screen and territory_screen.has_method("navigate_to_node"):
		territory_screen.call_deferred("navigate_to_node", smithy_id, true)

func _on_collect_craft(craft_data: Dictionary) -> void:
	var task_data = craft_data.get("task_data", {})
	var task_id = craft_data.get("task_id", "")
	var node_id = craft_data.get("node_id", "")

	_award_craft_rewards(task_data)

	var hex_grid_manager = _get_hex_grid_manager()
	if hex_grid_manager:
		hex_grid_manager.complete_craft(node_id, task_id)

	craft_collected.emit(task_data)
	_update_craft_display()
	_show_craft_collected_feedback(task_data)

func _award_craft_rewards(task_data: Dictionary) -> void:
	# Check if this is equipment crafting (has equipment_type field)
	if task_data.has("equipment_type"):
		_award_equipment_craft(task_data)
		return

	# Otherwise it's a resource conversion
	var resource_manager = _get_resource_manager()
	if not resource_manager:
		return

	var resources = task_data.get("output", task_data.get("resource_rewards", {}))
	for resource_id in resources.keys():
		var amount = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

func _award_equipment_craft(task_data: Dictionary) -> void:
	"""Create and award equipment from a crafting recipe"""
	var registry = _get_system_registry()
	if not registry:
		push_error("[ProductionSummaryWidget] Cannot award equipment - SystemRegistry not available")
		return

	# Create equipment from recipe data
	var equipment_type = task_data.get("equipment_type", "weapon")
	var rarity = task_data.get("rarity", "common")
	var recipe_id = task_data.get("id", "crafted_item")
	var equipment_set = task_data.get("equipment_set", "")
	var base_stats = task_data.get("base_stats", {})
	var item_name = task_data.get("name", "Crafted Equipment")

	# Create the equipment (equipment_type and rarity should be lowercase)
	var equipment = Equipment.create_from_dungeon("crafted_" + recipe_id, equipment_type.to_lower(), rarity.to_lower(), 1)
	if not equipment:
		push_error("[ProductionSummaryWidget] Failed to create equipment from recipe: %s" % recipe_id)
		return

	# Override with recipe-specific data
	equipment.name = item_name
	if equipment_set != "":
		equipment.equipment_set_type = equipment_set
		equipment.equipment_set_name = equipment_set.capitalize()

	# Apply base stats from recipe
	for stat_name in base_stats:
		equipment.add_stat_bonus(stat_name, base_stats[stat_name])

	# Add to inventory and collection
	var equipment_manager = registry.get_system("EquipmentManager")
	if equipment_manager:
		equipment_manager.add_equipment_to_inventory(equipment)
	else:
		push_error("[ProductionSummaryWidget] EquipmentManager not found")

	var collection_manager = registry.get_system("CollectionManager")
	if collection_manager:
		collection_manager.add_equipment(equipment)
	else:
		push_error("[ProductionSummaryWidget] CollectionManager not found")

	# Trigger save
	var event_bus = registry.get_system("EventBus")
	if event_bus:
		event_bus.save_requested.emit()

func _show_craft_collected_feedback(task_data: Dictionary) -> void:
	var task_name = task_data.get("name", "Item")
	var original = _craft_button.modulate
	_craft_button.modulate = Color(0.5, 1.0, 0.5, 1.0)
	_craft_button.text = "✓ " + (task_name.substr(0, 8) if task_name.length() > 8 else task_name)

	var tween = create_tween()
	tween.tween_property(_craft_button, "modulate", original, 0.4)
	tween.tween_callback(func(): _craft_button.text = "Blacksmith")

# ==============================================================================
# RESOURCE HELPERS
# ==============================================================================
func _get_resource_icon(resource_id: String) -> String:
	var icons = {
		"mana": "✦", "gold": "💰", "ore": "🪨", "wood": "🪵",
		"herbs": "🌿", "monster_parts": "🦴", "enhancement_powder": "✨",
		"refined_metal": "⚙️", "socket_crystals": "💎", "divine_essence": "🌟",
		"mana_crystals": "💠", "divine_crystals": "✝️", "crystals": "◆",
		"fire_crystals": "🔥", "water_crystals": "💧", "earth_crystals": "🌍",
		"lightning_crystals": "⚡", "light_crystals": "☀️", "dark_crystals": "🌑",
		"fine_ore": "⛏️", "hardwood": "🌳", "exotic_herbs": "🌺",
		"beast_scales": "🐉", "quality_timber": "📐", "rare_herbs": "💊",
		"steel_ingot": "🔩", "treated_lumber": "🪓", "alchemical_extract": "⚗️",
		"arcane_ore": "💜", "ancient_wood": "🌲", "mystic_herbs": "🔮",
		"magic_crystals": "💎", "prometheum": "🌋", "enchanted_wood": "✨",
		"mystic_bloom": "🌸", "astral_shard": "⭐", "forging_flame": "🔥",
		"divine_flame": "🕯️", "socket_crystal": "💠", "common_soul": "👻",
		"blessed_oil": "🛢️"
	}
	return icons.get(resource_id, "📦")

func _format_number(value: float) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	elif value >= 100:
		return "%d" % int(value)
	elif value >= 10:
		return "%.1f" % value
	else:
		return "%.2f" % value

# ==============================================================================
# SYSTEM ACCESS
# ==============================================================================
func _get_production_manager():
	var registry = _get_system_registry()
	if registry:
		return registry.get_system("TerritoryProductionManager")
	return null

func _get_hex_grid_manager():
	var registry = _get_system_registry()
	if registry:
		return registry.get_system("HexGridManager")
	return null

func _get_territory_manager():
	var registry = _get_system_registry()
	if registry:
		return registry.get_system("TerritoryManager")
	return null

func _get_screen_manager():
	var registry = _get_system_registry()
	if registry:
		return registry.get_system("ScreenManager")
	return null

func _get_resource_manager():
	var registry = _get_system_registry()
	if registry:
		return registry.get_system("ResourceManager")
	return null

func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null
