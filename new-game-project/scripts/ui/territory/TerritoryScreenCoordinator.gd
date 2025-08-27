# scripts/ui/territory/TerritoryScreenCoordinator.gd
# Single responsibility: Coordinate territory screen functionality
class_name TerritoryScreenCoordinator
extends Control

signal back_pressed

@onready var back_button = $BackButton
@onready var scroll_container = $ScrollContainer

# Load component scripts
const TerritoryHeaderManagerScript = preload("res://scripts/ui/territory/TerritoryHeaderManager.gd")
const TerritoryListManagerScript = preload("res://scripts/ui/territory/TerritoryListManager.gd") 
const TerritoryActionsManagerScript = preload("res://scripts/ui/territory/TerritoryActionsManager.gd")

var header_manager
var territory_list_manager
var territory_actions_manager

func _ready():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	_setup_managers()
	_setup_ui()
	_connect_signals()

func _setup_managers():
	# Create the component managers
	header_manager = TerritoryHeaderManagerScript.new()
	add_child(header_manager)
	
	territory_list_manager = TerritoryListManagerScript.new()
	add_child(territory_list_manager)
	
	territory_actions_manager = TerritoryActionsManagerScript.new()
	add_child(territory_actions_manager)

func _setup_ui():
	# Setup header
	var header = header_manager.create_header()
	add_child(header)
	
	# Setup territory list in scroll container
	var territory_list = territory_list_manager.create_territory_list()
	scroll_container.add_child(territory_list)
	
	# Configure scroll container
	if scroll_container:
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _connect_signals():
	# Connect cross-component signals
	header_manager.filter_changed.connect(territory_list_manager.on_filter_changed)
	header_manager.collect_all_requested.connect(_on_collect_all_territories)
	
	territory_list_manager.territory_action_requested.connect(territory_actions_manager.handle_territory_action)
	territory_actions_manager.territory_updated.connect(territory_list_manager.refresh_territories)

func _on_collect_all_territories():
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var result = territory_manager.collect_all_resources()
	
	if result.total_collected > 0:
		header_manager.show_collection_result(result)
		territory_list_manager.refresh_territories()

func _on_back_pressed():
	back_pressed.emit()
