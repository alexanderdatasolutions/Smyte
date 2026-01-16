# scripts/ui/territory/TerritoryHeaderManager.gd
# Single responsibility: Manage comprehensive territory screen header with rich UI
class_name TerritoryHeaderManager
extends Node

signal filter_changed(filter_id: String)
signal collect_all_requested

var header_panel: Control
var filter_buttons: Control
var collection_button: Button
var summary_stats: Dictionary = {}
var current_filter: String = "all"

func create_header() -> Control:
	header_panel = Panel.new()
	header_panel.name = "HeaderPanel"
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.custom_minimum_size = Vector2(0, 120)  # Increased height for rich content
	
	# Style the header
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	header_style.border_width_bottom = 2
	header_style.border_color = Color(0.8, 0.6, 0.2, 1)
	header_panel.add_theme_stylebox_override("panel", header_style)
	
	# Main header container with margins
	var header_content = VBoxContainer.new()
	header_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_content.add_theme_constant_override("separation", 8)
	header_content.add_theme_constant_override("margin_left", 15)
	header_content.add_theme_constant_override("margin_right", 15)
	header_content.add_theme_constant_override("margin_top", 10)
	header_content.add_theme_constant_override("margin_bottom", 10)
	header_panel.add_child(header_content)
	
	# Top row - Territory summary statistics
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 30)
	header_content.add_child(top_row)
	
	# Territory summary stats
	var summary_container = HBoxContainer.new()
	summary_container.add_theme_constant_override("separation", 40)
	top_row.add_child(summary_container)
	
	# Controlled territories count
	var controlled_stat = _create_summary_stat("🏰 Controlled", "0/0", Color.GREEN)
	summary_container.add_child(controlled_stat)
	summary_stats["controlled"] = controlled_stat
	
	# Total resource rate
	var resource_stat = _create_summary_stat("⚡ Total Rate", "0/hr", Color.YELLOW)
	summary_container.add_child(resource_stat)
	summary_stats["resource_rate"] = resource_stat
	
	# Pending resources
	var pending_stat = _create_summary_stat("💰 Pending", "0", Color.CYAN)
	summary_container.add_child(pending_stat)
	summary_stats["pending"] = pending_stat
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	
	# Collect All button - enhanced
	collection_button = Button.new()
	collection_button.text = "🎁 COLLECT ALL"
	collection_button.custom_minimum_size = Vector2(150, 40)
	collection_button.modulate = Color.GREEN
	collection_button.add_theme_font_size_override("font_size", 14)
	collection_button.pressed.connect(_on_collect_all_pressed)
	top_row.add_child(collection_button)
	
	# Bottom row - Enhanced filter buttons
	var filter_container = HBoxContainer.new()
	filter_container.add_theme_constant_override("separation", 15)
	header_content.add_child(filter_container)
	
	# Filter label
	var filter_label = Label.new()
	filter_label.text = "Filter Territories:"
	filter_label.add_theme_font_size_override("font_size", 12)
	filter_label.modulate = Color.WHITE
	filter_container.add_child(filter_label)
	
	# Create enhanced filter buttons
	filter_buttons = _create_enhanced_filter_buttons()
	filter_container.add_child(filter_buttons)
	
	update_header_summary()
	return header_panel

func _create_enhanced_filter_buttons() -> Control:
	"""Create enhanced filter buttons with proper styling and descriptions"""
	var buttons_container = HBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 12)
	
	# Enhanced filter descriptions (matching original implementation)
	var filters = [
		{"id": "all", "text": "All", "color": Color.WHITE, "description": "Show all unlocked territories"},
		{"id": "controlled", "text": "Controlled", "color": Color.GREEN, "description": "Territories under your control"},
		{"id": "available", "text": "Available", "color": Color.YELLOW, "description": "Territories you can attack"},
		{"id": "completed", "text": "Completed", "color": Color.BLUE, "description": "Cleared territories ready to claim"}  # Changed from "Locked" to "Completed"
	]
	
	for filter_data in filters:
		var filter_btn = Button.new()
		filter_btn.text = filter_data.text
		filter_btn.toggle_mode = true
		filter_btn.button_pressed = (filter_data.id == current_filter)
		filter_btn.custom_minimum_size = Vector2(110, 32)
		filter_btn.add_theme_font_size_override("font_size", 12)
		
		# Style based on selection
		if filter_data.id == current_filter:
			filter_btn.modulate = filter_data.color
		else:
			filter_btn.modulate = Color.GRAY
			
		filter_btn.pressed.connect(_on_filter_changed.bind(filter_data.id, filter_btn, filter_data.color))
		buttons_container.add_child(filter_btn)
	
	return buttons_container

func _create_summary_stat(label_text: String, value_text: String, color: Color) -> Control:
	"""Create a summary stat display with enhanced styling"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color.LIGHT_GRAY
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.modulate = color
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.name = "Value"  # For easy updating
	container.add_child(value)
	
	return container

func update_header_summary():
	"""Update header summary with comprehensive statistics"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		return
		
	var territories = territory_manager.get_all_territories() if territory_manager.has_method("get_all_territories") else []
	
	var controlled_count = 0
	var total_count = territories.size()
	var total_rate = 0
	var total_pending = 0
	
	for territory in territories:
		if _is_territory_controlled(territory):
			controlled_count += 1
			total_rate += _get_territory_resource_rate(territory)
			
			var pending = _get_territory_pending_resources(territory)
			for amount in pending.values():
				total_pending += amount
	
	# Update controlled territories stat
	if summary_stats.has("controlled"):
		var value_label = summary_stats["controlled"].get_node_or_null("Value")
		if value_label:
			value_label.text = "%d/%d" % [controlled_count, total_count]
	
	# Update resource rate stat
	if summary_stats.has("resource_rate"):
		var value_label = summary_stats["resource_rate"].get_node_or_null("Value")
		if value_label:
			value_label.text = "%s/hr" % _format_large_number(total_rate)
	
	# Update pending resources stat
	if summary_stats.has("pending"):
		var value_label = summary_stats["pending"].get_node_or_null("Value")
		if value_label:
			value_label.text = _format_large_number(total_pending)

func show_collection_result(result: Dictionary):
	"""Show collection results with enhanced popup"""
	_show_collection_popup(result)

func _show_collection_popup(resources: Dictionary):
	"""Show enhanced collection results popup"""
	var popup = AcceptDialog.new()
	popup.title = "🎁 Resources Collected!"
	popup.custom_minimum_size = Vector2(400, 300)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	
	var header = Label.new()
	var territory_count = resources.get("territory_count", 0)
	header.text = "Successfully collected from %d territories:" % territory_count
	header.add_theme_font_size_override("font_size", 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)
	
	# Resource breakdown
	var resources_collected = resources.get("resources", {})
	for resource_type in resources_collected:
		var line = HBoxContainer.new()
		
		var icon = Label.new()
		icon.text = _get_resource_icon(resource_type)
		icon.add_theme_font_size_override("font_size", 16)
		line.add_child(icon)
		
		var resource_label = Label.new()
		resource_label.text = "  %s: +%s" % [resource_type.capitalize(), _format_large_number(resources_collected[resource_type])]
		resource_label.add_theme_font_size_override("font_size", 14)
		resource_label.modulate = Color.YELLOW
		line.add_child(resource_label)
		
		content.add_child(line)
	
	popup.add_child(content)
	get_tree().root.add_child(popup)
	popup.popup_centered()
	popup.popup_hide.connect(popup.queue_free)

func _on_filter_changed(filter_id: String, button: Button, color: Color):
	"""Handle filter button changes with enhanced styling"""
	current_filter = filter_id
	
	# Update button states
	for child in filter_buttons.get_children():
		if child is Button:
			if child == button:
				child.button_pressed = true
				child.modulate = color
			else:
				child.button_pressed = false
				child.modulate = Color.GRAY
	
	filter_changed.emit(filter_id)

func _on_collect_all_pressed():
	"""Handle collect all button press"""
	collect_all_requested.emit()

# ==============================================================================
# UTILITY METHODS
# ==============================================================================

func _is_territory_controlled(territory) -> bool:
	"""Check if territory is controlled by player"""
	if territory is Dictionary:
		return territory.get("controller", "neutral") == "player"
	return territory.controller == "player" if territory.has_method("controller") else false

func _get_territory_resource_rate(territory) -> int:
	"""Get territory resource generation rate"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("get_territory_resource_rate"):
		var territory_id = territory.id if territory.has_method("id") else territory.get("id", "")
		return territory_manager.get_territory_resource_rate(territory_id)
	return territory.base_resource_rate if territory.has_method("base_resource_rate") else 0

func _get_territory_pending_resources(territory) -> Dictionary:
	"""Get pending resources for territory"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and territory_manager.has_method("get_pending_resources"):
		return territory_manager.get_pending_resources(territory.id)
	return {}

func _format_large_number(num: int) -> String:
	"""Format large numbers for display"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _get_resource_icon(resource_type: String) -> String:
	"""Get icon for resource type"""
	if "powder" in resource_type: return "✨"
	elif "soul" in resource_type: return "👻"
	elif "ore" in resource_type: return "⛏️"
	elif "mana" in resource_type: return "💎"
	elif "crystal" in resource_type: return "💠"
	elif "energy" in resource_type: return "⚡"
	else: return "•"

func update_summary_stats(territory_count: int, controlled_count: int):
	"""Update header summary statistics from territory list"""
	print("TerritoryHeaderManager: Updating summary - %d controlled / %d total" % [controlled_count, territory_count])
	
	# Update controlled territories stat
	if summary_stats.has("controlled"):
		var controlled_stat = summary_stats["controlled"]
		var value_label = controlled_stat.get_node_or_null("Value")
		if value_label:
			value_label.text = "%d/%d" % [controlled_count, territory_count]
	
	# Calculate and update resource rate (simplified for now)
	if summary_stats.has("resource_rate"):
		var resource_stat = summary_stats["resource_rate"]
		var value_label = resource_stat.get_node_or_null("Value")
		if value_label:
			var hourly_rate = controlled_count * 1000  # Simplified calculation
			value_label.text = "%s/hr" % _format_large_number(hourly_rate)
	
	# Update pending resources (simplified)
	if summary_stats.has("pending"):
		var pending_stat = summary_stats["pending"]
		var value_label = pending_stat.get_node_or_null("Value")
		if value_label:
			var pending_amount = controlled_count * 500  # Simplified calculation
			value_label.text = _format_large_number(pending_amount)
