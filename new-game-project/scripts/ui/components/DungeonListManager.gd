# scripts/ui/components/DungeonListManager.gd
# Single responsibility: Display and manage dungeon list selection
class_name DungeonListManager extends Node

# Dungeon list signals
signal dungeon_selected(dungeon_id: String)
signal dungeon_list_refreshed

var dungeon_list_container: Control
var current_dungeons: Array = []

func initialize(list_container: Control):
	"""Initialize with the dungeon list container"""
	dungeon_list_container = list_container
	print("DungeonListManager: Initialized")

func refresh_dungeon_list():
	"""Refresh the dungeon list display - RULE 5: Use SystemRegistry"""
	if not dungeon_list_container:
		return
	
	# Clear existing dungeons
	for child in dungeon_list_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get dungeon data through SystemRegistry
	load_dungeons_from_system()

func load_dungeons_from_system():
	"""Load dungeon data through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		show_error_placeholder("SystemRegistry not available")
		return
	
	var dungeon_manager = system_registry.get_system("DungeonManager")
	if not dungeon_manager:
		show_error_placeholder("DungeonManager not found")
		return
	
	# Get available dungeons
	current_dungeons = dungeon_manager.get_available_dungeons()
	
	if current_dungeons.is_empty():
		show_no_dungeons_placeholder()
		return
	
	# Create dungeon buttons
	create_dungeon_buttons()
	dungeon_list_refreshed.emit()

func show_error_placeholder(message: String):
	"""Show error placeholder"""
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color.RED
	dungeon_list_container.add_child(label)

func show_no_dungeons_placeholder():
	"""Show placeholder when no dungeons available"""
	var label = Label.new()
	label.text = "No dungeons available"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color.GRAY
	dungeon_list_container.add_child(label)

func create_dungeon_buttons():
	"""Create buttons for each available dungeon - RULE 4: UI creation only"""
	for dungeon_info in current_dungeons:
		var dungeon_button = create_dungeon_button(dungeon_info)
		dungeon_list_container.add_child(dungeon_button)

func create_dungeon_button(dungeon_info: Dictionary) -> Control:
	"""Create a single dungeon button with info - RULE 4: UI creation only"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(200, 60)
	
	# Create dungeon info display
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	button.add_child(vbox)
	
	# Dungeon name
	var name_label = Label.new()
	name_label.text = dungeon_info.get("name", "Unknown Dungeon")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Dungeon type/element
	var type_label = Label.new()
	type_label.text = dungeon_info.get("element", "Neutral")
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.modulate = get_element_color(dungeon_info.get("element", "neutral"))
	vbox.add_child(type_label)
	
	# Energy cost
	var cost_label = Label.new()
	var energy_cost = dungeon_info.get("energy_cost", 10)
	cost_label.text = "Energy: %d" % energy_cost
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.modulate = Color.YELLOW
	vbox.add_child(cost_label)
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	button_style.border_color = get_element_color(dungeon_info.get("element", "neutral"))
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", button_style)
	
	# Connect button press
	var dungeon_id = dungeon_info.get("id", "unknown")
	button.pressed.connect(_on_dungeon_button_pressed.bind(dungeon_id))
	
	return button

func _on_dungeon_button_pressed(dungeon_id: String):
	"""Handle dungeon button press"""
	print("DungeonListManager: Dungeon selected - %s" % dungeon_id)
	dungeon_selected.emit(dungeon_id)

func get_element_color(element: String) -> Color:
	"""Get color for dungeon element"""
	match element.to_lower():
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.2, 0.6, 1.0)
		"earth": return Color(0.6, 0.4, 0.2)
		"air": return Color(0.8, 0.9, 1.0)
		"light": return Color(1.0, 1.0, 0.7)
		"dark": return Color(0.4, 0.2, 0.6)
		"nature": return Color(0.3, 0.7, 0.3)
		_: return Color.CYAN

func get_dungeon_by_id(dungeon_id: String) -> Dictionary:
	"""Get dungeon data by ID"""
	for dungeon in current_dungeons:
		if dungeon.get("id", "") == dungeon_id:
			return dungeon
	return {}

func get_current_dungeons() -> Array:
	"""Get current dungeon list"""
	return current_dungeons.duplicate()
