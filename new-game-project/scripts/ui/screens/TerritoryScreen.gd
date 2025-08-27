class_name TerritoryScreen
extends Control

"""
TerritoryScreen.gd - Territory management screen
RULE 2: Single responsibility - ONLY displays territory information
RULE 4: No data modification - delegates to systems through SystemRegistry
RULE 5: Uses SystemRegistry for all system access

Following prompt.prompt.md architecture:
- UI LAYER: Only display, no data modification
"""

signal back_pressed

# UI elements
@onready var back_button = $BackButton
@onready var title_label = $TitleLabel
@onready var territory_list = $ScrollContainer/TerritoryList

func _ready():
	print("TerritoryScreen: Initializing territory management screen")
	
	# Connect back button (RULE 4: UI signals)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Set title
	if title_label:
		title_label.text = "TERRITORY COMMAND"
	
	# Load territories through SystemRegistry (RULE 5)
	call_deferred("_load_territory_display")

func _on_back_pressed():
	"""Handle back button press - RULE 4: UI signals"""
	print("TerritoryScreen: Back button pressed")
	back_pressed.emit()

func _load_territory_display():
	"""Load and display territories - RULE 5: Use SystemRegistry"""
	print("TerritoryScreen: Loading territory display")
	
	# Get territories through ConfigurationManager
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	if not config_manager:
		print("TerritoryScreen: ERROR - ConfigurationManager not found")
		return
	
	var territories_config = config_manager.get_territories_config()
	if territories_config.is_empty():
		print("TerritoryScreen: No territory configuration found")
		return
	
	# Create territory displays
	_create_territory_displays(territories_config)

func _create_territory_displays(territories_config: Dictionary):
	"""Create UI displays for territories - RULE 4: UI only displays"""
	
	# Check if territories are in array format
	var territories_list = []
	if territories_config.has("territories") and territories_config.territories is Array:
		territories_list = territories_config.territories
		print("TerritoryScreen: Creating displays for %d territories" % territories_list.size())
	else:
		# Fallback for dictionary format
		territories_list = territories_config.values()
		print("TerritoryScreen: Creating displays for %d territories (dict format)" % territories_list.size())
	
	# Clear existing displays
	if territory_list:
		for child in territory_list.get_children():
			child.queue_free()
	
	# Create display for each territory
	for territory_data in territories_list:
		var territory_id = territory_data.get("id", "unknown")
		_create_territory_card(territory_id, territory_data)

func _create_territory_card(territory_id: String, territory_data: Dictionary):
	"""Create a single territory card - RULE 4: UI display only"""
	# Create card container
	var card = Panel.new()
	card.custom_minimum_size = Vector2(950, 80)
	
	# Create card layout
	var hbox = HBoxContainer.new()
	card.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	
	# Territory name
	var name_label = Label.new()
	name_label.text = territory_data.get("name", territory_id)
	name_label.custom_minimum_size.x = 200
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)
	
	# Territory info
	var info_label = Label.new()
	var tier = territory_data.get("tier", 1)
	var element = territory_data.get("element", "unknown")
	info_label.text = "Tier %d • %s Element" % [tier, element.capitalize()]
	info_label.custom_minimum_size.x = 200
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(info_label)
	
	# Status info
	var status_label = Label.new()
	status_label.text = _get_territory_status_text(territory_id)
	status_label.custom_minimum_size.x = 200
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(status_label)
	
	# Action button
	var action_button = Button.new()
	action_button.text = _get_territory_action_text(territory_id)
	action_button.custom_minimum_size.x = 100
	action_button.pressed.connect(_on_territory_action_pressed.bind(territory_id))
	hbox.add_child(action_button)
	
	# Add card to list
	territory_list.add_child(card)
	print("TerritoryScreen: Created card for territory: %s" % territory_id)

func _get_territory_status_text(territory_id: String) -> String:
	"""Get status text for territory - RULE 5: Use SystemRegistry"""
	var territory_controller = SystemRegistry.get_instance().get_system("TerritoryController")
	if not territory_controller:
		return "Unknown"
	
	if territory_controller.is_territory_controlled(territory_id):
		return "CONTROLLED"
	else:
		return "AVAILABLE"

func _get_territory_action_text(territory_id: String) -> String:
	"""Get action button text - RULE 5: Use SystemRegistry"""
	var territory_controller = SystemRegistry.get_instance().get_system("TerritoryController")
	if not territory_controller:
		return "Attack"
	
	if territory_controller.is_territory_controlled(territory_id):
		return "Manage"
	else:
		return "Attack"

func _on_territory_action_pressed(territory_id: String):
	"""Handle territory action - RULE 5: Delegate to systems"""
	print("TerritoryScreen: Territory action pressed: %s" % territory_id)
	
	var territory_controller = SystemRegistry.get_instance().get_system("TerritoryController")
	if not territory_controller:
		print("TerritoryScreen: ERROR - TerritoryController not found")
		return
	
	if territory_controller.is_territory_controlled(territory_id):
		_manage_territory(territory_id)
	else:
		_attack_territory(territory_id)

func _attack_territory(territory_id: String):
	"""Start territory attack - RULE 5: Delegate to systems"""
	print("TerritoryScreen: Starting attack on territory: %s" % territory_id)
	
	# Navigate to battle setup screen for territory attack
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		# TODO: Pass territory data to battle setup
		screen_manager.change_screen("battle_setup")
	else:
		print("TerritoryScreen: ERROR - ScreenManager not found")

func _manage_territory(territory_id: String):
	"""Manage controlled territory - RULE 5: Delegate to systems"""
	print("TerritoryScreen: Managing territory: %s" % territory_id)
	
	# For now, show basic territory info
	# TODO: Create TerritoryManagementScreen for detailed management
	_show_territory_details(territory_id)

func _show_territory_details(territory_id: String):
	"""Show territory details - placeholder for future detailed screen"""
	print("TerritoryScreen: Showing details for territory: %s" % territory_id)
	
	# TODO: Navigate to detailed territory management screen
	# For now, just print info
	var territory_controller = SystemRegistry.get_instance().get_system("TerritoryController")
	if territory_controller:
		var territory_info = territory_controller.get_territory_info(territory_id)
		print("TerritoryScreen: Territory info: %s" % territory_info)
