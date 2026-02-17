# scripts/ui/components/ProductionSummaryWidget.gd
# Dashboard widget - Production, Refinery, Crafting, Territory Alerts
extends PanelContainer
class_name ProductionSummaryWidget

const ProductionDisplayHelperScript = preload("res://scripts/ui/components/ProductionDisplayHelper.gd")
# CraftingScreenManager is a global class_name, no preload needed

signal resources_collected(total: Dictionary)

const COLOR_HEADER := Color(0.9, 0.85, 0.7)
const COLOR_SECTION := Color(0.7, 0.65, 0.8)
const COLOR_TEXT := Color(0.8, 0.8, 0.85)
const COLOR_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)
const COLOR_WARNING := Color(0.9, 0.7, 0.3)
const COLOR_DANGER := Color(0.9, 0.4, 0.4)
const COLOR_PANEL_BG := Color(0.1, 0.08, 0.14, 0.8)
const UPDATE_INTERVAL: float = 2.0

# Crafting screen manager reference (shared component)
var _crafting_manager_ui: CraftingScreenManager = null

var _update_timer: Timer = null
var _main_container: HBoxContainer = null
var _left_column: VBoxContainer = null
var _right_column: VBoxContainer = null
var _production_container: Control = null
var _refinery_container: Control = null
var _crafting_container: Control = null
var _alerts_container: Control = null
var _collect_button: Button = null
var _display_helper: RefCounted = null

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
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _create_ui() -> void:
	var outer_container: VBoxContainer = VBoxContainer.new()
	outer_container.add_theme_constant_override("separation", 12)
	outer_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer_container)

	# Dashboard title
	var title_row: HBoxContainer = HBoxContainer.new()
	outer_container.add_child(title_row)

	var title_label: Label = Label.new()
	title_label.text = "SMYTE"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title_row.add_child(title_label)

	var subtitle: Label = Label.new()
	subtitle.text = "  DIVINE NEXUS"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_row.add_child(subtitle)

	_main_container = HBoxContainer.new()
	_main_container.add_theme_constant_override("separation", 16)
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_container.add_child(_main_container)

	# Left column - Production (bigger)
	_left_column = VBoxContainer.new()
	_left_column.add_theme_constant_override("separation", 8)
	_left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_column.size_flags_stretch_ratio = 1.5
	_main_container.add_child(_left_column)

	# Production section header
	var prod_header: HBoxContainer = HBoxContainer.new()
	prod_header.add_theme_constant_override("separation", 8)
	_left_column.add_child(prod_header)

	var prod_title: Label = Label.new()
	prod_title.text = "⚡ PRODUCTION /hr"
	prod_title.add_theme_font_size_override("font_size", 14)
	prod_title.add_theme_color_override("font_color", COLOR_HEADER)
	prod_header.add_child(prod_title)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prod_header.add_child(spacer)

	_collect_button = Button.new()
	_collect_button.text = "Collect All"
	_collect_button.pressed.connect(_on_collect_all_pressed)
	_style_collect_button()
	prod_header.add_child(_collect_button)

	# Production content
	_production_container = VBoxContainer.new()
	_production_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_column.add_child(_production_container)

	# Initialize display helper for production
	_display_helper = ProductionDisplayHelperScript.new()
	_display_helper.initialize(_production_container)

	# Right column - Refinery, Crafting, Alerts
	_right_column = VBoxContainer.new()
	_right_column.add_theme_constant_override("separation", 12)
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_container.add_child(_right_column)

	# Refinery section
	var refinery_section: PanelContainer = _create_section_panel("🔄 REFINERY")
	_right_column.add_child(refinery_section)
	_refinery_container = refinery_section.get_child(0).get_child(1)  # Get content container

	# Crafting section
	var crafting_section: PanelContainer = _create_section_panel("🔨 CRAFTING")
	_right_column.add_child(crafting_section)
	_crafting_container = crafting_section.get_child(0).get_child(1)

	# Territory Alerts section
	var alerts_section: PanelContainer = _create_section_panel("⚠️ TERRITORY ALERTS")
	_right_column.add_child(alerts_section)
	_alerts_container = alerts_section.get_child(0).get_child(1)

func _create_section_panel(title: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = Color(0.25, 0.2, 0.35, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	var header: Label = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", COLOR_SECTION)
	inner.add_child(header)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	inner.add_child(content)

	return panel

func _style_collect_button() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.3, 0.9)
	style.border_color = Color(0.5, 0.8, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_collect_button.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	_collect_button.add_theme_stylebox_override("hover", hover)

	_collect_button.add_theme_font_size_override("font_size", 11)
	_collect_button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))

func _start_update_timer() -> void:
	_update_timer = Timer.new()
	_update_timer.wait_time = UPDATE_INTERVAL
	_update_timer.timeout.connect(_update_display)
	_update_timer.autostart = true
	add_child(_update_timer)

func _update_display() -> void:
	if not is_visible_in_tree():
		return

	_update_production_section()
	_update_refinery_section()
	_update_crafting_section()
	_update_alerts_section()
	_update_collect_button_state()

# ==============================================================================
# PRODUCTION SECTION
# ==============================================================================

func _update_production_section() -> void:
	var production_manager: Variant = _get_production_manager()
	if not production_manager:
		return

	var cached_rates: Dictionary = production_manager.get_all_hex_nodes_production()
	_display_helper.update_production_display(cached_rates)

# ==============================================================================
# REFINERY SECTION
# ==============================================================================

func _update_refinery_section() -> void:
	_clear_container(_refinery_container)

	var production_manager: Variant = _get_production_manager()
	if not production_manager:
		_add_status_label(_refinery_container, "No active refineries", COLOR_MUTED)
		return

	# Check for active conversion buildings (refineries)
	var active_conversions: Array = []
	if production_manager.has_method("get_active_conversions"):
		active_conversions = production_manager.get_active_conversions()

	if active_conversions.is_empty():
		_add_status_label(_refinery_container, "No active refineries", COLOR_MUTED)
	else:
		for job in active_conversions:
			var input_name: String = str(job.get("input", "")).replace("_", " ").capitalize()
			var output_name: String = str(job.get("output", "")).replace("_", " ").capitalize()
			var rate: int = int(job.get("output_rate", job.get("rate", 0)))
			_add_conversion_row(_refinery_container, input_name, output_name, rate)

# ==============================================================================
# CRAFTING SECTION
# ==============================================================================

func _update_crafting_section() -> void:
	_clear_container(_crafting_container)

	var crafting_manager: Variant = _get_crafting_manager()
	var current_time: int = int(Time.get_unix_time_from_system())

	# Get forge nodes from territory
	var forge_nodes: Array = _get_forge_nodes()

	if forge_nodes.is_empty() and (not crafting_manager or not crafting_manager.has_method("get_active_crafts")):
		_add_status_label(_crafting_container, "No forges available", COLOR_MUTED)
		return

	# Get active crafts from HexCraftManager (returns Dictionary)
	var active_crafts: Dictionary = {}
	if crafting_manager and crafting_manager.has_method("get_active_crafts"):
		active_crafts = crafting_manager.get_active_crafts()

	# Show each forge node with its status
	var shown_any: bool = false
	for node in forge_nodes:
		# HexNode is a Resource, access properties directly
		var node_id: String = str(node.id) if "id" in node else ""
		var node_name: String = str(node.name) if "name" in node else "Forge"

		# Find active craft for this node
		var node_craft: Dictionary = {}
		for craft_key: String in active_crafts:
			var craft: Dictionary = active_crafts[craft_key]
			if str(craft.get("node_id", "")) == node_id:
				node_craft = craft
				break

		if node_craft.is_empty():
			# No active craft - show Start Craft button
			_add_forge_idle_row(_crafting_container, node_name, node_id)
		else:
			# Active craft - show progress
			var task_data: Dictionary = node_craft.get("task_data", {})
			var task_name: String = str(task_data.get("name", task_data.get("task_id", "Crafting"))).replace("_", " ").capitalize()
			var start_time: int = int(node_craft.get("start_time", current_time))
			var end_time: int = int(node_craft.get("end_time", current_time))
			var duration: int = end_time - start_time
			var elapsed: int = current_time - start_time
			var progress: float = clampf(float(elapsed) / float(duration), 0.0, 1.0) if duration > 0 else 1.0
			var time_left: int = maxi(0, end_time - current_time)
			_add_craft_progress_row(_crafting_container, task_name, progress, time_left)
		shown_any = true

	if not shown_any:
		_add_status_label(_crafting_container, "No forges available", COLOR_MUTED)

func _get_forge_nodes() -> Array:
	"""Get all player-owned nodes with crafting buildings (forges) that have workers assigned"""
	var forge_nodes: Array = []
	var territory_manager: Variant = _get_territory_manager()
	if not territory_manager or not territory_manager.has_method("get_controlled_nodes"):
		return forge_nodes

	# Crafting building IDs from buildings.json (category: "crafting")
	var crafting_buildings: Array = ["blacksmith", "weapon_forge", "armor_forge", "divine_forge", "jeweler"]

	var all_nodes: Array = territory_manager.get_controlled_nodes()
	for node in all_nodes:
		# Get placed_building - could be HexNode object or Dictionary
		var placed_building: String = ""
		if node is Dictionary:
			placed_building = str(node.get("placed_building", ""))
		elif "placed_building" in node:
			placed_building = str(node.placed_building)

		# Check if it's a crafting building
		if placed_building in crafting_buildings:
			# Check if it has workers assigned (can actually craft)
			var workers: Array = []
			if node is Dictionary:
				workers = node.get("assigned_workers", [])
			elif "assigned_workers" in node:
				workers = node.assigned_workers

			if not workers.is_empty():
				forge_nodes.append(node)

	return forge_nodes

func _add_forge_idle_row(container: Control, node_name: String, node_id: String) -> void:
	"""Add a row for an idle forge with Start Craft button"""
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = node_name + " - Idle"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var button: Button = Button.new()
	button.text = "Start Craft"
	button.add_theme_font_size_override("font_size", 10)
	# Store node_id in metadata for the callback
	button.set_meta("node_id", node_id)
	button.pressed.connect(_on_forge_start_craft_pressed.bind(node_id))
	row.add_child(button)

	container.add_child(row)

func _on_forge_start_craft_pressed(node_id: String) -> void:
	"""Handle Start Craft button for a specific forge node - opens crafting screen"""
	var hex_grid_manager: Variant = _get_hex_grid_manager()
	var resource_manager: Variant = _get_resource_manager()
	var territory_manager: Variant = _get_territory_manager()

	if not hex_grid_manager:
		return

	# Get the actual HexNode to pre-select
	var initial_node: HexNode = null
	if hex_grid_manager.has_method("get_node_by_id"):
		initial_node = hex_grid_manager.get_node_by_id(node_id)

	# Close existing crafting screen if any
	if _crafting_manager_ui:
		_crafting_manager_ui.close()

	# Use the unified CraftingScreenManager with all forges
	_crafting_manager_ui = CraftingScreenManager.new()
	_crafting_manager_ui.popup_closed.connect(_on_craft_popup_closed)
	_crafting_manager_ui.craft_started.connect(_on_craft_started)
	_crafting_manager_ui.show_all_forges(
		hex_grid_manager,
		resource_manager,
		territory_manager,
		self,
		initial_node
	)

func _on_craft_popup_closed() -> void:
	"""Handle craft popup being closed"""
	_crafting_manager_ui = null

func _on_craft_started(_node: Variant, _task_id: String) -> void:
	"""Handle craft being started from popup"""
	_update_display()

func _get_resource_manager() -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("ResourceManager")
	return null

# ==============================================================================
# TERRITORY ALERTS SECTION
# ==============================================================================

func _update_alerts_section() -> void:
	_clear_container(_alerts_container)

	var alerts: Array = _get_territory_alerts()

	if alerts.is_empty():
		_add_status_label(_alerts_container, "All territories secure ✓", COLOR_SUCCESS)
	else:
		for alert in alerts:
			var alert_type: String = str(alert.get("type", ""))
			var node_name: String = str(alert.get("node_name", "Unknown"))
			var color: Color = COLOR_DANGER if alert_type == "lost" else COLOR_WARNING

			match alert_type:
				"lost_pvp":
					_add_alert_row(_alerts_container, "🗡️ Lost to PvP: %s" % node_name, color)
				"lost_garrison":
					_add_alert_row(_alerts_container, "💀 Garrison failed: %s" % node_name, color)
				"low_garrison":
					_add_alert_row(_alerts_container, "⚠️ Low garrison: %s" % node_name, COLOR_WARNING)
				_:
					_add_alert_row(_alerts_container, "❓ %s: %s" % [alert_type, node_name], COLOR_MUTED)

func _get_territory_alerts() -> Array:
	var alerts: Array = []
	var save_manager: Variant = _get_save_manager()
	var territory_manager: Variant = _get_territory_manager()

	# Check save data for recent territory losses
	if save_manager and save_manager.has_method("get_player_value"):
		var lost_territories: Array = save_manager.get_player_value("lost_territories", [])
		for loss in lost_territories:
			if loss is Dictionary:
				alerts.append(loss)

	# Check for low garrison nodes
	if territory_manager and territory_manager.has_method("get_controlled_nodes"):
		var nodes: Array = territory_manager.get_controlled_nodes()
		for node in nodes:
			# Check if garrison is low (if applicable)
			if "garrison_strength" in node and "max_garrison" in node:
				var strength: float = float(node.garrison_strength)
				var max_str: float = float(node.max_garrison)
				if max_str > 0 and strength / max_str < 0.25:
					alerts.append({
						"type": "low_garrison",
						"node_name": node.name if "name" in node else "Unknown"
					})

	return alerts

# ==============================================================================
# UI HELPER FUNCTIONS
# ==============================================================================

func _clear_container(container: Control) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _add_status_label(container: Control, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)

func _add_conversion_row(container: Control, input_text: String, output_text: String, rate: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var label: Label = Label.new()
	label.text = "%s → %s (%d/hr)" % [input_text, output_text, rate]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(label)

	container.add_child(row)

func _add_craft_progress_row(container: Control, item_name: String, progress: float, time_left: int) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var label: Label = Label.new()
	var time_str: String = _format_time(time_left)
	label.text = "%s - %s left" % [item_name, time_str]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(label)

	# Progress bar
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.value = progress * 100
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.show_percentage = false
	row.add_child(progress_bar)

	container.add_child(row)

func _add_action_row(container: Control, text: String, button_text: String, callback: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var button: Button = Button.new()
	button.text = button_text
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(callback)
	row.add_child(button)

	container.add_child(row)

func _add_alert_row(container: Control, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)

func _format_time(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		return "%dm" % (seconds / 60)
	else:
		return "%dh %dm" % [seconds / 3600, (seconds % 3600) / 60]

# ==============================================================================
# BUTTON CALLBACKS
# ==============================================================================

func _update_collect_button_state() -> void:
	var hex_grid_manager: Variant = _get_hex_grid_manager()
	var has_resources: bool = false

	if hex_grid_manager:
		var player_nodes: Array = _get_player_nodes(hex_grid_manager)
		for node in player_nodes:
			if node.accumulated_resources and not node.accumulated_resources.is_empty():
				for res_id: String in node.accumulated_resources:
					if node.accumulated_resources[res_id] >= 0.1:
						has_resources = true
						break
			if has_resources:
				break

	_collect_button.disabled = not has_resources
	_collect_button.text = "Collect All" if has_resources else "Nothing Ready"

func _on_collect_all_pressed() -> void:
	var production_manager: Variant = _get_production_manager()
	var hex_grid_manager: Variant = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		return

	var total_collected: Dictionary = {}
	var player_nodes: Array = _get_player_nodes(hex_grid_manager)

	for node in player_nodes:
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

	var total: int = 0
	for resource_id: String in collected:
		total += int(collected[resource_id])

	_collect_button.text = "+%d!" % total
	await get_tree().create_timer(1.5).timeout
	_update_collect_button_state()

func _get_player_nodes(_hex_grid_manager: Variant) -> Array:
	var territory_manager: Variant = _get_territory_manager()
	if territory_manager and territory_manager.has_method("get_controlled_nodes"):
		return territory_manager.get_controlled_nodes()
	return []

# ==============================================================================
# SYSTEM GETTERS
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

func _get_crafting_manager() -> Variant:
	# HexCraftManager handles time-based forge crafting
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("HexCraftManager")
	return null

func _get_save_manager() -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("SaveManager")
	return null

func _get_screen_manager() -> Variant:
	var registry: Variant = _get_system_registry()
	if registry:
		return registry.get_system("ScreenManager")
	return null

func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null
