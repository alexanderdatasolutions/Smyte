# scripts/ui/ResourceDisplay.gd
extends HBoxContainer

# Dynamic UI elements - created based on ResourceManager configuration
var currency_labels: Array[Label] = []
var separator_labels: Array[Label] = []
var energy_label: Label = null
var tickets_label: Label = null
var materials_button: Button = null
var materials_count_label: Label = null

# Reference to ResourceManager for complete modularity
var resource_manager: Node = null

func _ready():
	# Get ResourceManager reference
	resource_manager = get_node("/root/ResourceManager") if has_node("/root/ResourceManager") else null
	
	if not resource_manager:
		# Create ResourceManager if it doesn't exist
		resource_manager = preload("res://scripts/systems/ResourceManager.gd").new()
		resource_manager.name = "ResourceManager"
		get_tree().root.add_child(resource_manager)
	
	# Wait for resource definitions to load, then build UI
	if resource_manager.resource_definitions.is_empty():
		resource_manager.resource_definitions_loaded.connect(_build_dynamic_ui)
	else:
		_build_dynamic_ui()
	
	# Connect to signals
	if GameManager:
		GameManager.resources_updated.connect(_update_display)
	
	if resource_manager:
		resource_manager.resources_updated.connect(_update_display)

func _build_dynamic_ui():
	"""Build UI completely dynamically based on ResourceManager configuration"""
	print("ResourceDisplay: Building dynamic UI...")
	
	# Clear existing children (except those we want to keep)
	_clear_dynamic_elements()
	
	# Get currency display configuration from ResourceManager
	var display_currencies = resource_manager.get_display_currencies()
	
	# Create currency labels dynamically
	for i in range(display_currencies.size()):
		var currency_data = display_currencies[i]
		var currency_info = currency_data.info
		
		# Create currency label
		var label = Label.new()
		label.name = currency_data.id.capitalize() + "Label"
		label.text = currency_info.get("name", "Unknown") + ": 0"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)
		currency_labels.append(label)
		
		# Add separator if not the last element
		if i < display_currencies.size() - 1 or _should_add_extra_elements():
			var separator = Label.new()
			separator.name = "Separator" + str(i + 1)
			separator.text = " | "
			separator.modulate = Color(0.7, 0.7, 0.7, 1)
			separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(separator)
			separator_labels.append(separator)
	
	# Add additional elements based on configuration
	_add_extra_ui_elements()
	
	print("ResourceDisplay: Dynamic UI built with ", currency_labels.size(), " currency displays")
	_update_display()

func _should_add_extra_elements() -> bool:
	"""Check if we should add energy, tickets, materials button"""
	return true  # For now, always add them. Later this can be config-driven

func _add_extra_ui_elements():
	"""Add energy, tickets, materials button dynamically"""
	# Add energy label
	energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "Energy: 80/80"
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(energy_label)
	
	# Add separator
	var separator = Label.new()
	separator.text = " | "
	separator.modulate = Color(0.7, 0.7, 0.7, 1)
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(separator)
	separator_labels.append(separator)
	
	# Add tickets label
	tickets_label = Label.new()
	tickets_label.name = "TicketsLabel"
	tickets_label.text = "Tickets: 0"
	tickets_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tickets_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(tickets_label)
	
	# Add separator
	separator = Label.new()
	separator.text = " | "
	separator.modulate = Color(0.7, 0.7, 0.7, 1)
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(separator)
	separator_labels.append(separator)
	
	# Add materials button
	materials_button = Button.new()
	materials_button.name = "MaterialsButton"
	materials_button.text = "Materials"
	materials_button.custom_minimum_size = Vector2(80, 25)
	add_child(materials_button)
	
	# Add materials count label
	materials_count_label = Label.new()
	materials_count_label.name = "MaterialsCountLabel"
	materials_count_label.text = "(0)"
	materials_count_label.modulate = Color(0.7, 0.7, 0.7, 1)
	materials_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	materials_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(materials_count_label)
	
	# Connect materials button
	materials_button.pressed.connect(_show_materials_table)
	materials_button.mouse_entered.connect(func(): materials_button.modulate = Color(1.2, 1.2, 1.2))
	materials_button.mouse_exited.connect(func(): materials_button.modulate = Color.WHITE)

func _clear_dynamic_elements():
	"""Clear dynamically created elements"""
	for label in currency_labels:
		if label and is_instance_valid(label):
			label.queue_free()
	
	for separator in separator_labels:
		if separator and is_instance_valid(separator):
			separator.queue_free()
	
	if energy_label and is_instance_valid(energy_label):
		energy_label.queue_free()
		energy_label = null
	
	if tickets_label and is_instance_valid(tickets_label):
		tickets_label.queue_free()
		tickets_label = null
	
	if materials_button and is_instance_valid(materials_button):
		materials_button.queue_free()
		materials_button = null
	
	if materials_count_label and is_instance_valid(materials_count_label):
		materials_count_label.queue_free()
		materials_count_label = null
	
	currency_labels.clear()
	separator_labels.clear()

func _update_display():
	"""Update all display elements using ResourceManager data"""
	if not resource_manager or not GameManager or not GameManager.player_data:
		return
	
	# Update currency displays dynamically
	var display_currencies = resource_manager.get_display_currencies()
	
	for i in range(min(display_currencies.size(), currency_labels.size())):
		var currency_data = display_currencies[i]
		var currency_info = currency_data.info
		var currency_id = currency_data.id
		
		if currency_labels[i] and is_instance_valid(currency_labels[i]):
			# Get current value from player data using helper function
			var current_value = _get_player_resource(currency_id)
			var display_name = currency_info.get("name", currency_id.capitalize())
			
			# Format large numbers
			if current_value > 1000000000:
				currency_labels[i].text = display_name + ": " + format_large_number(current_value)
			else:
				currency_labels[i].text = display_name + ": " + str(current_value)
	
	# Update energy (special handling)
	if energy_label and is_instance_valid(energy_label):
		_update_energy_display()
	
	# Update tickets
	if tickets_label and is_instance_valid(tickets_label):
		var tickets_count = _get_player_resource("summon_tickets")
		tickets_label.text = "Tickets: " + str(tickets_count)
	
	# Update materials count
	if materials_count_label and is_instance_valid(materials_count_label):
		var total_count = _get_total_materials_count()
		materials_count_label.text = "(%d)" % total_count

func _update_energy_display():
	"""Update energy display with regeneration info"""
	if not GameManager.player_data.has_method("update_energy"):
		energy_label.text = "Energy: N/A"
		return
	
	GameManager.player_data.update_energy()
	var energy_status = GameManager.player_data.get_energy_status()
	var energy_text = "Energy: %d/%d" % [energy_status.current, energy_status.max]
	
	# Add time to full energy if not at max
	if energy_status.current < energy_status.max:
		var minutes_to_full = energy_status.minutes_to_full
		if minutes_to_full < 60:
			energy_text += " (%dm)" % minutes_to_full
		else:
			var hours = minutes_to_full / 60
			energy_text += " (%dh %dm)" % [hours, minutes_to_full % 60]
	
	energy_label.text = energy_text

func format_large_number(number: int) -> String:
	"""Format large numbers for display (e.g., 1.5B instead of 1500000000)"""
	if number >= 1000000000:
		return "%.1fB" % (float(number) / 1000000000.0)
	elif number >= 1000000:
		return "%.1fM" % (float(number) / 1000000.0)
	elif number >= 1000:
		return "%.1fK" % (float(number) / 1000.0)
	else:
		return str(number)

func _get_total_materials_count() -> int:
	"""Get total count of all materials using ResourceManager"""
	if not resource_manager or not GameManager or not GameManager.player_data:
		return 0
	
	var total = 0
	var all_materials = resource_manager.get_all_materials()
	
	# Count materials that exist in player data
	for resource_id in all_materials:
		var count = _get_player_resource(resource_id)
		total += count
	
	return total

func _show_materials_table():
	"""Show materials in a completely dynamic table driven by ResourceManager"""
	if not resource_manager:
		push_error("ResourceManager not available for materials table")
		return
	
	print("Materials button clicked - opening dynamic table")
	
	var popup = AcceptDialog.new()
	popup.title = "Materials Inventory"
	popup.size = Vector2(700, 500)
	popup.position = Vector2(100, 100)
	
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	# Create table using GridContainer
	var grid = GridContainer.new()
	grid.columns = 4  # Resource Name, Category, Element/Type, Amount
	margin.add_child(grid)
	
	# Add headers
	_add_table_header(grid, "Resource")
	_add_table_header(grid, "Category")
	_add_table_header(grid, "Element/Type")
	_add_table_header(grid, "Amount")
	
	# Add materials dynamically
	_populate_materials_table(grid)
	
	# Add to scene and show
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func _add_table_header(grid: GridContainer, text: String):
	"""Add a header to the materials table"""
	var header = Label.new()
	header.text = text
	header.add_theme_stylebox_override("normal", _create_header_style())
	grid.add_child(header)

func _populate_materials_table(grid: GridContainer):
	"""Populate materials table completely dynamically from ResourceManager"""
	if not GameManager or not GameManager.player_data:
		return
	
	var all_materials = resource_manager.get_all_materials()
	
	# Sort materials by category and name for better organization
	var sorted_materials = []
	for resource_id in all_materials:
		var resource_info = all_materials[resource_id]
		var player_count = _get_player_resource(resource_id)
		
		# Only show materials the player actually has (configurable)
		if player_count > 0 or true:  # Change to false to hide zero-count materials
			sorted_materials.append({
				"id": resource_id,
				"info": resource_info,
				"count": player_count
			})
	
	# Sort by category, then by name
	sorted_materials.sort_custom(func(a, b):
		var cat_a = a.info.get("category", "unknown")
		var cat_b = b.info.get("category", "unknown")
		if cat_a != cat_b:
			return cat_a < cat_b
		return a.info.get("name", a.id) < b.info.get("name", b.id)
	)
	
	# Add sorted materials to table
	for material_data in sorted_materials:
		_add_material_row(grid, material_data)

func _add_material_row(grid: GridContainer, material_data: Dictionary):
	"""Add a single material row to the table"""
	var resource_info = material_data.info
	var resource_id = material_data.id
	var count = material_data.count
	
	# Resource name
	var name_label = Label.new()
	name_label.text = resource_info.get("name", resource_id.capitalize().replace("_", " "))
	grid.add_child(name_label)
	
	# Category
	var category_label = Label.new()
	category_label.text = resource_info.get("category", "unknown").replace("_", " ").capitalize()
	grid.add_child(category_label)
	
	# Element/Type info
	var type_label = Label.new()
	var element = resource_info.get("element", "")
	var tier = resource_info.get("tier", "")
	var rarity = resource_info.get("rarity", "")
	
	var type_text = ""
	if element != "":
		type_text = element.capitalize()
	elif rarity != "":
		type_text = rarity.capitalize()
	elif tier != "":
		type_text = tier.capitalize()
	else:
		type_text = "General"
	
	type_label.text = type_text
	grid.add_child(type_label)
	
	# Amount
	var amount_label = Label.new()
	amount_label.text = str(count)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Color code based on amount
	if count == 0:
		amount_label.modulate = Color.GRAY
	elif count >= 1000:
		amount_label.modulate = Color.GREEN
	elif count >= 100:
		amount_label.modulate = Color.YELLOW
	
	grid.add_child(amount_label)

func _create_header_style() -> StyleBoxFlat:
	"""Create header style for table"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color.WHITE
	return style

# === Debug Functions ===

func debug_print_resources():
	"""Debug function to print resource information"""
	if resource_manager:
		resource_manager.print_all_resources()

# Helper function for robust player data access
func _get_player_resource(resource_id: String) -> int:
	"""Safely get resource amount from player data"""
	if not GameManager or not GameManager.player_data:
		return 0
	
	# Use Godot's get() method with null check for Resources
	var value = GameManager.player_data.get(resource_id)
	if value != null and typeof(value) == TYPE_INT:
		return value
	
	# Try common aliases for backwards compatibility
	match resource_id:
		"skrib", "mana":
			var essence = GameManager.player_data.get("divine_essence")
			if essence != null:
				return essence
			var mana_val = GameManager.player_data.get("mana")
			if mana_val != null:
				return mana_val
			var skrib_val = GameManager.player_data.get("skrib")
			if skrib_val != null:
				return skrib_val
		"divine_crystals":
			var crystals = GameManager.player_data.get("premium_crystals")
			if crystals != null:
				return crystals
		"energy":
			var energy = GameManager.player_data.get("current_energy")
			if energy != null:
				return energy
		"summon_tickets":
			var tickets = GameManager.player_data.get("summon_tickets")
			if tickets != null:
				return tickets
	
	return 0
