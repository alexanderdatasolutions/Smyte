# scripts/ui/components/ProductionSummaryWidget.gd
# Widget showing production summary on home screen with collect all functionality
extends PanelContainer
class_name ProductionSummaryWidget

"""
ProductionSummaryWidget - Home screen production overview
Shows: hourly rates, accumulated resources, collect all button, active crafts
Auto-updates every few seconds to show growing resources
"""

signal resources_collected(total: Dictionary)
signal craft_collected(task_data: Dictionary)
signal navigate_to_crafting_requested

# Update interval in seconds
const UPDATE_INTERVAL: float = 2.0
const CRAFT_UPDATE_INTERVAL: float = 1.0  # Faster updates for craft progress

var _update_timer: Timer = null
var _craft_update_timer: Timer = null
var _content_container: VBoxContainer = null
var _header_label: Label = null
var _production_rates_container: HBoxContainer = null
var _accumulated_container: HBoxContainer = null
var _collect_button: Button = null
var _no_nodes_label: Label = null

# Craft tracker UI
var _craft_section: VBoxContainer = null
var _craft_header: HBoxContainer = null
var _craft_list: VBoxContainer = null
var _no_crafts_container: HBoxContainer = null
var _craft_button: Button = null

# Cached data
var _cached_rates: Dictionary = {}
var _cached_accumulated: Dictionary = {}
var _tasks_data: Dictionary = {}

func _ready() -> void:
	_load_tasks_data()
	_setup_styling()
	_create_ui()
	_start_update_timer()

	# Initial update
	call_deferred("_update_display")

func _load_tasks_data() -> void:
	"""Load tasks from JSON file for reward info"""
	var file_path = "res://data/tasks.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_text) == OK:
		var data = json.get_data()
		if data.has("tasks"):
			_tasks_data = data.tasks

func _setup_styling() -> void:
	"""Apply dark fantasy styling to the widget"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(320, 160)  # Increased for craft section

func _create_ui() -> void:
	"""Build the widget UI"""
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 6)
	add_child(_content_container)

	# Header with icon
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	_content_container.add_child(header_hbox)

	var icon_label = Label.new()
	icon_label.text = "⚡"
	icon_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(icon_label)

	_header_label = Label.new()
	_header_label.text = "PRODUCTION"
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	header_hbox.add_child(_header_label)

	# Spacer to push collect button right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	# Collect All button
	_collect_button = Button.new()
	_collect_button.text = "Collect All"
	_collect_button.pressed.connect(_on_collect_all_pressed)
	_style_collect_button()
	header_hbox.add_child(_collect_button)

	# No nodes message (hidden by default)
	_no_nodes_label = Label.new()
	_no_nodes_label.text = "Capture territory nodes to start production!"
	_no_nodes_label.add_theme_font_size_override("font_size", 11)
	_no_nodes_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	_no_nodes_label.visible = false
	_content_container.add_child(_no_nodes_label)

	# Production rates row
	var rates_section = HBoxContainer.new()
	rates_section.add_theme_constant_override("separation", 4)
	_content_container.add_child(rates_section)

	var rates_icon = Label.new()
	rates_icon.text = "📈"
	rates_icon.add_theme_font_size_override("font_size", 12)
	rates_section.add_child(rates_icon)

	_production_rates_container = HBoxContainer.new()
	_production_rates_container.add_theme_constant_override("separation", 12)
	rates_section.add_child(_production_rates_container)

	# Accumulated resources row
	var accumulated_section = HBoxContainer.new()
	accumulated_section.add_theme_constant_override("separation", 4)
	_content_container.add_child(accumulated_section)

	var accumulated_icon = Label.new()
	accumulated_icon.text = "💎"
	accumulated_icon.add_theme_font_size_override("font_size", 12)
	accumulated_section.add_child(accumulated_icon)

	_accumulated_container = HBoxContainer.new()
	_accumulated_container.add_theme_constant_override("separation", 12)
	accumulated_section.add_child(_accumulated_container)

	# Separator before craft section
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	_content_container.add_child(separator)

	# Craft tracker section
	_create_craft_section()

func _style_collect_button() -> void:
	"""Style the collect all button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.3, 0.5, 0.3, 0.9)
	style_normal.border_color = Color(0.5, 0.8, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 4
	style_normal.content_margin_bottom = 4

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.35, 0.6, 0.35, 0.95)
	style_hover.border_color = Color(0.6, 0.9, 0.6, 1.0)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(4)
	style_hover.content_margin_left = 8
	style_hover.content_margin_right = 8
	style_hover.content_margin_top = 4
	style_hover.content_margin_bottom = 4

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.25, 0.4, 0.25, 1.0)
	style_pressed.border_color = Color(0.4, 0.6, 0.4, 0.8)
	style_pressed.set_border_width_all(1)
	style_pressed.set_corner_radius_all(4)
	style_pressed.content_margin_left = 8
	style_pressed.content_margin_right = 8
	style_pressed.content_margin_top = 4
	style_pressed.content_margin_bottom = 4

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style_disabled.set_border_width_all(1)
	style_disabled.set_corner_radius_all(4)
	style_disabled.content_margin_left = 8
	style_disabled.content_margin_right = 8
	style_disabled.content_margin_top = 4
	style_disabled.content_margin_bottom = 4

	_collect_button.add_theme_stylebox_override("normal", style_normal)
	_collect_button.add_theme_stylebox_override("hover", style_hover)
	_collect_button.add_theme_stylebox_override("pressed", style_pressed)
	_collect_button.add_theme_stylebox_override("disabled", style_disabled)
	_collect_button.add_theme_font_size_override("font_size", 12)
	_collect_button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))

func _start_update_timer() -> void:
	"""Start the auto-update timers"""
	_update_timer = Timer.new()
	_update_timer.wait_time = UPDATE_INTERVAL
	_update_timer.timeout.connect(_update_display)
	_update_timer.autostart = true
	add_child(_update_timer)

	# Faster timer for craft progress updates
	_craft_update_timer = Timer.new()
	_craft_update_timer.wait_time = CRAFT_UPDATE_INTERVAL
	_craft_update_timer.timeout.connect(_update_craft_display)
	_craft_update_timer.autostart = true
	add_child(_craft_update_timer)

func _update_display() -> void:
	"""Update all production info"""
	if not is_visible_in_tree():
		return

	var production_manager = _get_production_manager()
	var hex_grid_manager = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		_show_no_nodes_state()
		return

	# Get production rates
	_cached_rates = production_manager.get_all_hex_nodes_production()

	# Get accumulated resources from all player nodes
	_cached_accumulated = _get_total_accumulated_resources(hex_grid_manager)

	# Check if we have any production
	if _cached_rates.is_empty() and _cached_accumulated.is_empty():
		_show_no_nodes_state()
		return

	_show_production_state()
	_update_rates_display()
	_update_accumulated_display()
	_update_collect_button_state()

func _show_no_nodes_state() -> void:
	"""Show the 'no nodes' message"""
	_no_nodes_label.visible = true
	_production_rates_container.visible = false
	_accumulated_container.visible = false
	_collect_button.disabled = true
	_collect_button.text = "No Resources"

func _show_production_state() -> void:
	"""Show normal production state"""
	_no_nodes_label.visible = false
	_production_rates_container.visible = true
	_accumulated_container.visible = true

func _update_rates_display() -> void:
	"""Update the production rates row"""
	# Clear existing
	for child in _production_rates_container.get_children():
		child.queue_free()

	if _cached_rates.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No production"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_production_rates_container.add_child(empty_label)
		return

	# Show top resources (limit to 4 for space)
	var count = 0
	for resource_id in _cached_rates:
		if count >= 4:
			break
		var rate = _cached_rates[resource_id]
		if rate <= 0:
			continue

		var rate_label = Label.new()
		rate_label.text = "%s +%s/hr" % [_get_resource_icon(resource_id), _format_number(rate)]
		rate_label.add_theme_font_size_override("font_size", 11)
		rate_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		_production_rates_container.add_child(rate_label)
		count += 1

func _update_accumulated_display() -> void:
	"""Update the accumulated resources row"""
	# Clear existing
	for child in _accumulated_container.get_children():
		child.queue_free()

	if _cached_accumulated.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Nothing to collect"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_accumulated_container.add_child(empty_label)
		return

	# Show accumulated (limit to 4 for space)
	var count = 0
	for resource_id in _cached_accumulated:
		if count >= 4:
			break
		var amount = _cached_accumulated[resource_id]
		if amount < 0.1:  # Skip tiny amounts
			continue

		var amount_label = Label.new()
		amount_label.text = "%s %s" % [_get_resource_icon(resource_id), _format_number(amount)]
		amount_label.add_theme_font_size_override("font_size", 11)
		amount_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		_accumulated_container.add_child(amount_label)
		count += 1

func _update_collect_button_state() -> void:
	"""Update collect button based on accumulated resources"""
	var has_resources = false
	for resource_id in _cached_accumulated:
		if _cached_accumulated[resource_id] >= 0.1:
			has_resources = true
			break

	_collect_button.disabled = not has_resources
	if has_resources:
		_collect_button.text = "Collect All"
	else:
		_collect_button.text = "Empty"

func _on_collect_all_pressed() -> void:
	"""Collect resources from all nodes"""
	var production_manager = _get_production_manager()
	var hex_grid_manager = _get_hex_grid_manager()

	if not production_manager or not hex_grid_manager:
		return

	var total_collected: Dictionary = {}
	var player_nodes = _get_player_nodes(hex_grid_manager)

	for node in player_nodes:
		if not node.accumulated_resources or node.accumulated_resources.is_empty():
			continue

		# Collect from this node
		var collected = production_manager.collect_node_resources(node.id)

		# Add to total
		for resource_id in collected:
			total_collected[resource_id] = total_collected.get(resource_id, 0) + collected[resource_id]

	if not total_collected.is_empty():
		resources_collected.emit(total_collected)
		_show_collection_feedback(total_collected)

	# Immediate update
	_update_display()

func _show_collection_feedback(collected: Dictionary) -> void:
	"""Show visual feedback when resources are collected"""
	# Flash the button green
	var original_modulate = _collect_button.modulate
	_collect_button.modulate = Color(0.5, 1.0, 0.5, 1.0)

	var tween = create_tween()
	tween.tween_property(_collect_button, "modulate", original_modulate, 0.3)

	# Temporarily show total collected
	var total = 0.0
	for resource_id in collected:
		total += collected[resource_id]

	_collect_button.text = "+%s!" % _format_number(total)

	# Reset button text after a moment
	await get_tree().create_timer(1.5).timeout
	_update_collect_button_state()

func _get_total_accumulated_resources(hex_grid_manager) -> Dictionary:
	"""Get total accumulated resources across all player nodes"""
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
	"""Get all player-controlled nodes from TerritoryManager (same source as production)"""
	# Use TerritoryManager.get_controlled_nodes() to get the same objects
	# that TerritoryProductionManager updates
	var territory_manager = _get_territory_manager()
	if territory_manager and territory_manager.has_method("get_controlled_nodes"):
		return territory_manager.get_controlled_nodes()
	return []

func _get_territory_manager():
	var registry = _get_system_registry()
	if registry:
		return registry.get_system("TerritoryManager")
	return null

func _get_resource_icon(resource_id: String) -> String:
	"""Get icon for resource type"""
	var icons = {
		"mana": "✦",
		"gold": "💰",
		"ore": "🪨",
		"wood": "🪵",
		"herbs": "🌿",
		"monster_parts": "🦴",
		"enhancement_powder": "✨",
		"refined_metal": "⚙️",
		"socket_crystals": "💎",
		"divine_essence": "🌟",
		"mana_crystals": "💠",
		"crystals": "◆",
		"fire_crystals": "🔥",
		"water_crystals": "💧",
		"earth_crystals": "🌍",
		"lightning_crystals": "⚡",
		"light_crystals": "☀️",
		"dark_crystals": "🌑"
	}
	return icons.get(resource_id, "📦")

func _format_number(value: float) -> String:
	"""Format number with K/M suffixes"""
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

# System access helpers
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

func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

# ==============================================================================
# CRAFT TRACKER SECTION
# ==============================================================================
func _create_craft_section() -> void:
	"""Create the craft tracking section"""
	_craft_section = VBoxContainer.new()
	_craft_section.add_theme_constant_override("separation", 4)
	_content_container.add_child(_craft_section)

	# Header row with title and craft button
	_craft_header = HBoxContainer.new()
	_craft_header.add_theme_constant_override("separation", 8)
	_craft_section.add_child(_craft_header)

	var craft_icon = Label.new()
	craft_icon.text = "⚒️"
	craft_icon.add_theme_font_size_override("font_size", 14)
	_craft_header.add_child(craft_icon)

	var craft_title = Label.new()
	craft_title.text = "CRAFTING"
	craft_title.add_theme_font_size_override("font_size", 12)
	craft_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
	_craft_header.add_child(craft_title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_craft_header.add_child(spacer)

	# Craft button (always visible, for navigation)
	_craft_button = Button.new()
	_craft_button.text = "Forge"
	_craft_button.pressed.connect(_on_craft_button_pressed)
	_style_craft_button()
	_craft_header.add_child(_craft_button)

	# No crafts message (shown when idle)
	_no_crafts_container = HBoxContainer.new()
	_no_crafts_container.add_theme_constant_override("separation", 8)
	_craft_section.add_child(_no_crafts_container)

	var no_crafts_label = Label.new()
	no_crafts_label.text = "No active crafts"
	no_crafts_label.add_theme_font_size_override("font_size", 11)
	no_crafts_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	_no_crafts_container.add_child(no_crafts_label)

	# Active craft list
	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override("separation", 4)
	_craft_section.add_child(_craft_list)

func _style_craft_button() -> void:
	"""Style the craft navigation button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.5, 0.35, 0.2, 0.9)
	style_normal.border_color = Color(0.7, 0.5, 0.3, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 3
	style_normal.content_margin_bottom = 3

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.6, 0.45, 0.25, 0.95)
	style_hover.border_color = Color(0.8, 0.6, 0.4, 1.0)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(4)
	style_hover.content_margin_left = 8
	style_hover.content_margin_right = 8
	style_hover.content_margin_top = 3
	style_hover.content_margin_bottom = 3

	_craft_button.add_theme_stylebox_override("normal", style_normal)
	_craft_button.add_theme_stylebox_override("hover", style_hover)
	_craft_button.add_theme_font_size_override("font_size", 11)
	_craft_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))

func _update_craft_display() -> void:
	"""Update the craft tracker display - simple approach:
	Just show active crafts from HexGridManager. If none, show 'no crafts'.
	Don't check forge ownership - if they don't have a forge, they can't craft anyway."""
	if not is_visible_in_tree():
		return

	# Always show craft section - it's always relevant info
	_craft_section.visible = true

	var hex_grid_manager = _get_hex_grid_manager()
	if not hex_grid_manager:
		_show_no_crafts_state()
		_update_forge_button_text(0)
		return

	# Update forge button to show count of player-owned forges
	var forge_count = _count_player_forges(hex_grid_manager)
	_update_forge_button_text(forge_count)

	var active_crafts = hex_grid_manager.get_active_crafts()
	if active_crafts.is_empty():
		_show_no_crafts_state()
		return

	_show_active_crafts_state(active_crafts)

func _count_player_forges(hex_grid_manager) -> int:
	"""Count how many forges the player owns"""
	var count = 0
	var forge_nodes = hex_grid_manager.get_nodes_by_type("forge")
	for node in forge_nodes:
		if node.is_controlled_by_player():
			count += 1
	return count

func _update_forge_button_text(forge_count: int) -> void:
	"""Update the forge button text to show how many forges player owns"""
	if not _craft_button:
		return
	if forge_count == 0:
		_craft_button.text = "No Forge"
		_craft_button.disabled = true
	elif forge_count == 1:
		_craft_button.text = "Forge"
		_craft_button.disabled = false
	else:
		_craft_button.text = "Forges (%d)" % forge_count
		_craft_button.disabled = false

func _show_no_crafts_state() -> void:
	"""Show the idle crafting state"""
	_no_crafts_container.visible = true
	_craft_list.visible = false

func _show_active_crafts_state(active_crafts: Dictionary) -> void:
	"""Show active crafts with progress"""
	_no_crafts_container.visible = false
	_craft_list.visible = true

	# Clear existing
	for child in _craft_list.get_children():
		child.queue_free()

	# Add craft progress items (limit to 3 for space)
	var count = 0
	var current_time = int(Time.get_unix_time_from_system())

	for craft_key in active_crafts:
		if count >= 3:
			break

		var craft_data = active_crafts[craft_key]
		var craft_item = _create_craft_progress_item(craft_data, current_time)
		_craft_list.add_child(craft_item)
		count += 1

	# Show how many more if we have more
	if active_crafts.size() > 3:
		var more_label = Label.new()
		more_label.text = "+%d more..." % (active_crafts.size() - 3)
		more_label.add_theme_font_size_override("font_size", 10)
		more_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
		_craft_list.add_child(more_label)

func _create_craft_progress_item(craft_data: Dictionary, current_time: int) -> HBoxContainer:
	"""Create a single craft progress item"""
	var item = HBoxContainer.new()
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

	# Shorten name if needed
	if task_name.length() > 18:
		task_name = task_name.substr(0, 16) + ".."

	# Name label
	var name_label = Label.new()
	name_label.text = task_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	name_label.custom_minimum_size.x = 100
	item.add_child(name_label)

	# Progress bar
	var progress_container = Panel.new()
	progress_container.custom_minimum_size = Vector2(80, 14)
	progress_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var prog_style = StyleBoxFlat.new()
	prog_style.bg_color = Color(0.15, 0.15, 0.18)
	prog_style.set_corner_radius_all(3)
	progress_container.add_theme_stylebox_override("panel", prog_style)
	item.add_child(progress_container)

	# Fill
	var fill = ColorRect.new()
	if is_complete:
		fill.color = Color(0.3, 0.7, 0.4)
	else:
		fill.color = Color(0.5, 0.4, 0.25)
	fill.anchor_right = progress
	fill.anchor_bottom = 1.0
	fill.offset_left = 1
	fill.offset_top = 1
	fill.offset_right = 0
	fill.offset_bottom = -1
	progress_container.add_child(fill)

	# Time/status label
	var status_label = Label.new()
	if is_complete:
		status_label.text = "✓ Ready!"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		status_label.text = _format_duration(remaining)
		status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.custom_minimum_size.x = 50
	item.add_child(status_label)

	# Make clickable if complete
	if is_complete:
		var collect_btn = Button.new()
		collect_btn.text = "Collect"
		collect_btn.custom_minimum_size = Vector2(50, 18)
		collect_btn.pressed.connect(_on_collect_craft.bind(craft_data))

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.5, 0.3, 0.9)
		btn_style.set_corner_radius_all(3)
		btn_style.content_margin_left = 4
		btn_style.content_margin_right = 4
		collect_btn.add_theme_stylebox_override("normal", btn_style)
		collect_btn.add_theme_font_size_override("font_size", 9)
		item.add_child(collect_btn)

	return item

func _format_duration(seconds: int) -> String:
	"""Format duration in compact format"""
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		return "%dm %ds" % [seconds / 60, seconds % 60]
	else:
		var hours = seconds / 3600
		var minutes = (seconds % 3600) / 60
		return "%dh %dm" % [hours, minutes]

func _on_craft_button_pressed() -> void:
	"""Handle craft button press - navigate to forge node in territory with crafting panel open"""
	navigate_to_crafting_requested.emit()

	# Find a player-owned forge node
	var hex_grid_manager = _get_hex_grid_manager()
	if not hex_grid_manager:
		return

	var forge_nodes = hex_grid_manager.get_nodes_by_type("forge")
	var player_forge: HexNode = null
	for node in forge_nodes:
		if node.is_controlled_by_player():
			player_forge = node
			break

	if not player_forge:
		print("[ProductionSummaryWidget] No player-owned forge found")
		return

	# Navigate to territory screen
	var screen_manager = _get_screen_manager()
	if not screen_manager:
		return

	# Store the forge node ID for after navigation
	var forge_id = player_forge.id

	# Connect to screen transition to open node after navigation completes
	if not screen_manager.screen_transition_completed.is_connected(_on_territory_screen_ready):
		screen_manager.screen_transition_completed.connect(_on_territory_screen_ready.bind(forge_id), CONNECT_ONE_SHOT)

	screen_manager.change_screen("territory")

func _on_territory_screen_ready(screen_name: String, forge_id: String) -> void:
	"""Called when territory screen is ready - open the forge node with crafting"""
	if screen_name != "territory" and screen_name != "hex_territory":
		return

	# Get the territory screen and navigate to forge node
	var screen_manager = _get_screen_manager()
	if not screen_manager:
		return

	var territory_screen = screen_manager.get_current_screen()
	if territory_screen and territory_screen.has_method("navigate_to_node"):
		# Defer to ensure screen is fully initialized
		territory_screen.call_deferred("navigate_to_node", forge_id, true)

func _on_collect_craft(craft_data: Dictionary) -> void:
	"""Handle collecting a completed craft"""
	var task_data = craft_data.get("task_data", {})
	var task_id = craft_data.get("task_id", "")
	var node_id = craft_data.get("node_id", "")

	print("ProductionSummaryWidget: Collecting craft '%s' from node '%s'" % [task_id, node_id])
	print("ProductionSummaryWidget: task_data keys: %s" % [task_data.keys()])

	# Award rewards
	_award_craft_rewards(task_data)

	# Remove from tracker
	var hex_grid_manager = _get_hex_grid_manager()
	if hex_grid_manager:
		hex_grid_manager.complete_craft(node_id, task_id)

	craft_collected.emit(task_data)
	_update_craft_display()

	# Show feedback
	_show_craft_collected_feedback(task_data)

func _award_craft_rewards(task_data: Dictionary) -> void:
	"""Award rewards from a completed craft"""
	var resource_manager = _get_resource_manager()
	if not resource_manager:
		push_error("ProductionSummaryWidget: Cannot award craft rewards - no ResourceManager")
		return

	# Resource rewards - use "output" from crafting_recipes.json (fallback to "resource_rewards")
	var resources = task_data.get("output", task_data.get("resource_rewards", {}))
	if resources.is_empty():
		push_warning("ProductionSummaryWidget: No output resources found in task_data: %s" % task_data.keys())
		return

	for resource_id in resources.keys():
		var amount = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)
		print("ProductionSummaryWidget: Awarded %d %s" % [amount, resource_id])

func _show_craft_collected_feedback(task_data: Dictionary) -> void:
	"""Show brief visual feedback when craft collected"""
	var task_name = task_data.get("name", "Item")

	# Flash the craft button
	var original_modulate = _craft_button.modulate
	_craft_button.modulate = Color(0.5, 1.0, 0.5, 1.0)
	_craft_button.text = "✓ " + task_name.substr(0, 8) if task_name.length() > 8 else "✓ " + task_name

	var tween = create_tween()
	tween.tween_property(_craft_button, "modulate", original_modulate, 0.4)
	tween.tween_callback(func(): _craft_button.text = "Forge")

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
