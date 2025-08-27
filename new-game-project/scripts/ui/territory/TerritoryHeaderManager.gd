# scripts/ui/territory/TerritoryHeaderManager.gd
# Single responsibility: Manage territory screen header with filters and stats
class_name TerritoryHeaderManager
extends Node

signal filter_changed(filter_id: String)
signal collect_all_requested

var header_panel: Control
var filter_buttons: Control
var collection_button: Button
var territory_count_label: Label

func create_header() -> Control:
	header_panel = Panel.new()
	header_panel.name = "HeaderPanel"
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.custom_minimum_size = Vector2(0, 100)
	
	var header_container = HBoxContainer.new()
	header_panel.add_child(header_container)
	
	# Create filter buttons section
	filter_buttons = _create_filter_buttons()
	header_container.add_child(filter_buttons)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(spacer)
	
	# Create stats section
	var stats_section = _create_stats_section()
	header_container.add_child(stats_section)
	
	# Create collect all button
	collection_button = Button.new()
	collection_button.text = "Collect All"
	collection_button.pressed.connect(_on_collect_all_pressed)
	header_container.add_child(collection_button)
	
	update_header_summary()
	return header_panel

func _create_filter_buttons() -> Control:
	var buttons_container = HBoxContainer.new()
	
	var filters = [
		{"id": "all", "text": "All"},
		{"id": "controlled", "text": "Controlled"},
		{"id": "available", "text": "Available"},
		{"id": "locked", "text": "Locked"}
	]
	
	for filter in filters:
		var button = Button.new()
		button.text = filter.text
		button.toggle_mode = true
		button.pressed.connect(_on_filter_pressed.bind(filter.id, button))
		buttons_container.add_child(button)
		
		# Set first button as active
		if filter.id == "all":
			button.button_pressed = true
	
	return buttons_container

func _create_stats_section() -> Control:
	var stats_container = VBoxContainer.new()
	
	territory_count_label = Label.new()
	territory_count_label.text = "Territories: 0/0"
	stats_container.add_child(territory_count_label)
	
	return stats_container

func update_header_summary():
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var territories = territory_manager.get_all_territories()
	
	var controlled_count = 0
	for territory in territories:
		if territory.controller == "player":
			controlled_count += 1
	
	territory_count_label.text = "Territories: %d/%d" % [controlled_count, territories.size()]

func show_collection_result(result: Dictionary):
	var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
	notification_manager.show_resource_collection(result)

func _on_filter_pressed(filter_id: String, button: Button):
	# Uncheck other filter buttons
	for child in filter_buttons.get_children():
		if child != button and child is Button:
			child.button_pressed = false
	
	filter_changed.emit(filter_id)

func _on_collect_all_pressed():
	collect_all_requested.emit()
