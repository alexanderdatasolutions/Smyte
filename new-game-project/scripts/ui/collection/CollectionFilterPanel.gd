class_name CollectionFilterPanel
extends Control

"""
CollectionFilterPanel.gd - Enhanced collection filtering controls
RULE 1: Stays under 300 lines by focusing on filter UI only
RULE 2: Single responsibility - provides filtering interface
RULE 4: UI-only component - emits filter changes
RULE 5: SystemRegistry for accessing data definitions

Features:
- Filter by tier (1-6 stars)
- Filter by element (Fire, Water, Wind, etc.)
- Filter by role assignment status
- Filter by awakening status
- Quick filter presets
"""

signal filter_changed(filters: Dictionary)

# Core systems
var data_loader
var god_manager

# UI References
var main_container: HBoxContainer
var tier_option: OptionButton
var element_option: OptionButton
var role_option: OptionButton
var awakening_option: OptionButton
var clear_button: Button

# Current filters
var current_filters: Dictionary = {}

func _ready():
	print("CollectionFilterPanel: Initializing collection filter panel...")
	_init_systems()
	_setup_ui()
	_load_filter_options()

func _init_systems():
	"""Initialize required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("CollectionFilterPanel: SystemRegistry not available!")
		return
		
	data_loader = registry.get_system("ConfigurationManager")
	god_manager = registry.get_system("CollectionManager")
	
	if not data_loader:
		push_error("CollectionFilterPanel: ConfigurationManager not found!")
	if not god_manager:
		push_error("CollectionFilterPanel: CollectionManager not found!")

func _setup_ui():
	"""Setup the UI layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Main container
	main_container = HBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Filter label
	var filter_label = Label.new()
	filter_label.text = "Filters:"
	filter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(filter_label)
	
	# Tier filter
	_create_tier_filter()
	
	# Element filter
	_create_element_filter()
	
	# Role filter
	_create_role_filter()
	
	# Awakening filter
	_create_awakening_filter()
	
	# Clear filters button
	clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.custom_minimum_size = Vector2(60, 30)
	clear_button.pressed.connect(_on_clear_filters_pressed)
	main_container.add_child(clear_button)

func _create_tier_filter():
	"""Create tier filter dropdown"""
	var tier_label = Label.new()
	tier_label.text = "Tier:"
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(tier_label)
	
	tier_option = OptionButton.new()
	tier_option.custom_minimum_size = Vector2(80, 30)
	tier_option.add_item("All", 0)
	tier_option.add_item("1★", 1)
	tier_option.add_item("2★", 2)
	tier_option.add_item("3★", 3)
	tier_option.add_item("4★", 4)
	tier_option.add_item("5★", 5)
	tier_option.add_item("6★", 6)
	tier_option.item_selected.connect(_on_tier_filter_changed)
	main_container.add_child(tier_option)

func _create_element_filter():
	"""Create element filter dropdown"""
	var element_label = Label.new()
	element_label.text = "Element:"
	element_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(element_label)
	
	element_option = OptionButton.new()
	element_option.custom_minimum_size = Vector2(80, 30)
	element_option.add_item("All", 0)
	element_option.item_selected.connect(_on_element_filter_changed)
	main_container.add_child(element_option)

func _create_role_filter():
	"""Create role filter dropdown"""
	var role_label = Label.new()
	role_label.text = "Role:"
	role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(role_label)
	
	role_option = OptionButton.new()
	role_option.custom_minimum_size = Vector2(80, 30)
	role_option.add_item("All", 0)
	role_option.add_item("Unassigned", 1)
	role_option.item_selected.connect(_on_role_filter_changed)
	main_container.add_child(role_option)

func _create_awakening_filter():
	"""Create awakening filter dropdown"""
	var awakening_label = Label.new()
	awakening_label.text = "Awakened:"
	awakening_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(awakening_label)
	
	awakening_option = OptionButton.new()
	awakening_option.custom_minimum_size = Vector2(80, 30)
	awakening_option.add_item("All", 0)
	awakening_option.add_item("Awakened", 1)
	awakening_option.add_item("Unawakened", 2)
	awakening_option.item_selected.connect(_on_awakening_filter_changed)
	main_container.add_child(awakening_option)

func _load_filter_options():
	"""Load dynamic filter options from data - RULE 4: Read-only data access"""
	_load_element_options()
	_load_role_options()

func _load_element_options():
	"""Load available elements from god data"""
	if not data_loader:
		return
	
	var gods_data = data_loader.get_gods_config()
	if gods_data.is_empty():
		print("CollectionFilterPanel: Failed to load gods data for elements")
		return
	
	var elements = {}
	
	# Handle both dictionary and array formats
	var gods_data_source = gods_data.get("gods", {})
	var gods_array = []
	
	# Convert dictionary format to array if needed
	if gods_data_source is Dictionary:
		# New dictionary format: {"gods": {"god_id": god_data, ...}}
		for god_id in gods_data_source:
			gods_array.append(gods_data_source[god_id])
	elif gods_data_source is Array:
		# Old array format: {"gods": [god_objects...]}
		gods_array = gods_data_source
	
	# Collect unique elements
	for god in gods_array:
		var element = god.get("element", null)
		if element != null:
			# Handle both string and integer/float element formats
			if element is int or element is float:
				# Convert integer/float element to string
				var element_index = int(element)
				var element_names = ["fire", "water", "earth", "lightning", "light", "dark"]
				if element_index >= 0 and element_index < element_names.size():
					element = element_names[element_index]
				else:
					element = "unknown"
			elif element is String and element != "":
				# Keep string element as is
				pass
			else:
				element = "unknown"
			
			if element != "unknown":
				elements[element] = true
	
	# Add elements to dropdown
	var element_list = elements.keys()
	element_list.sort()
	
	for element in element_list:
		element_option.add_item(element)

func _load_role_options():
	"""Load available roles from territory roles data"""
	if not data_loader:
		return
	
	var roles_data = data_loader.get_territory_roles_config()
	if roles_data.is_empty():
		print("CollectionFilterPanel: Failed to load territory roles data")
		return
	
	# Get the territory_roles section
	var territory_roles = roles_data.get("territory_roles", {})
	
	# Add roles to dropdown
	for role_id in territory_roles:
		var role = territory_roles[role_id]
		var role_name = role.get("name", role_id)
		role_option.add_item(role_name)

func _on_tier_filter_changed(index: int):
	"""Handle tier filter change"""
	if index == 0:  # "All" selected
		current_filters.erase("tier")
	else:
		current_filters["tier"] = str(index)
	
	print("CollectionFilterPanel: Tier filter changed to: ", current_filters.get("tier", "All"))
	_emit_filter_change()

func _on_element_filter_changed(index: int):
	"""Handle element filter change"""
	if index == 0:  # "All" selected
		current_filters.erase("element")
	else:
		var element_text = element_option.get_item_text(index)
		current_filters["element"] = element_text
	
	print("CollectionFilterPanel: Element filter changed to: ", current_filters.get("element", "All"))
	_emit_filter_change()

func _on_role_filter_changed(index: int):
	"""Handle role filter change"""
	if index == 0:  # "All" selected
		current_filters.erase("role")
	elif index == 1:  # "Unassigned" selected
		current_filters["role"] = ""
	else:
		var role_text = role_option.get_item_text(index)
		current_filters["role"] = role_text
	
	print("CollectionFilterPanel: Role filter changed to: ", current_filters.get("role", "All"))
	_emit_filter_change()

func _on_awakening_filter_changed(index: int):
	"""Handle awakening filter change"""
	match index:
		0:  # "All"
			current_filters.erase("awakened")
		1:  # "Awakened"
			current_filters["awakened"] = "awakened"
		2:  # "Unawakened"
			current_filters["awakened"] = "unawakened"
	
	print("CollectionFilterPanel: Awakening filter changed to: ", current_filters.get("awakened", "All"))
	_emit_filter_change()

func _on_clear_filters_pressed():
	"""Handle clear filters button press"""
	print("CollectionFilterPanel: Clearing all filters")
	
	# Reset all dropdowns to "All" (index 0)
	tier_option.selected = 0
	element_option.selected = 0
	role_option.selected = 0
	awakening_option.selected = 0
	
	# Clear filters dictionary
	current_filters.clear()
	
	_emit_filter_change()

func _emit_filter_change():
	"""Emit the filter change signal"""
	print("CollectionFilterPanel: Emitting filter change: ", current_filters)
	filter_changed.emit(current_filters)

func get_current_filters() -> Dictionary:
	"""Get the current filter settings"""
	return current_filters.duplicate()

func set_filters(filters: Dictionary):
	"""Set filters programmatically"""
	current_filters = filters.duplicate()
	_update_ui_from_filters()
	_emit_filter_change()

func _update_ui_from_filters():
	"""Update UI elements to match current filters"""
	# Update tier dropdown
	if current_filters.has("tier"):
		var tier_value = int(current_filters["tier"])
		tier_option.selected = tier_value
	else:
		tier_option.selected = 0
	
	# Update element dropdown
	if current_filters.has("element"):
		var element_value = current_filters["element"]
		for i in range(element_option.get_item_count()):
			if element_option.get_item_text(i) == element_value:
				element_option.selected = i
				break
	else:
		element_option.selected = 0
	
	# Update role dropdown
	if current_filters.has("role"):
		var role_value = current_filters["role"]
		if role_value == "":
			role_option.selected = 1  # "Unassigned"
		else:
			for i in range(role_option.get_item_count()):
				if role_option.get_item_text(i) == role_value:
					role_option.selected = i
					break
	else:
		role_option.selected = 0
	
	# Update awakening dropdown
	if current_filters.has("awakened"):
		var awakening_value = current_filters["awakened"]
		match awakening_value:
			"awakened":
				awakening_option.selected = 1
			"unawakened":
				awakening_option.selected = 2
			_:
				awakening_option.selected = 0
	else:
		awakening_option.selected = 0
