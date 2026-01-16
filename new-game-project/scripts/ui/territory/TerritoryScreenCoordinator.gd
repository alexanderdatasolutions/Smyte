class_name TerritoryScreenCoordinator
extends Control

"""
TerritoryScreenCoordinator_CLEAN.gd - CLEAN territory screen following prompt rules
RULE 1: Under 200 lines 
RULE 2: Single responsibility - ONLY orchestrate existing components
RULE 5: Use SystemRegistry for all system access

This replaces the corrupted coordinator with a clean, working version.
"""

signal back_pressed

# Use existing working components
const TerritoryHeaderManagerScript = preload("res://scripts/ui/territory/TerritoryHeaderManager.gd")
const TerritoryListManagerScript = preload("res://scripts/ui/territory/TerritoryListManager.gd")  
const TerritoryActionsManagerScript = preload("res://scripts/ui/territory/TerritoryActionsManager.gd")

# UI components
var main_container: VBoxContainer
var scroll_container: ScrollContainer
var header_manager: TerritoryHeaderManager
var list_manager: TerritoryListManager
var actions_manager: TerritoryActionsManager
var back_button: Button

func _ready():
	print("TerritoryScreenCoordinator: Creating complete territory interface...")
	_create_ui_structure()
	_setup_managers()
	_setup_ui_components()
	_connect_signals()
	print("TerritoryScreenCoordinator: Enhanced territory interface ready!")

func _create_ui_structure():
	"""Create clean UI structure"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Back button
	back_button = Button.new()
	back_button.text = "← BACK TO WORLD"
	back_button.custom_minimum_size = Vector2(150, 40)
	back_button.pressed.connect(_on_back_pressed)
	main_container.add_child(back_button)
	
	# Scroll container for territory list
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_container.add_child(scroll_container)

func _setup_managers():
	"""Create component managers"""
	header_manager = TerritoryHeaderManagerScript.new()
	add_child(header_manager)
	
	list_manager = TerritoryListManagerScript.new()
	add_child(list_manager)
	
	actions_manager = TerritoryActionsManagerScript.new()
	add_child(actions_manager)

func _setup_ui_components():
	"""Setup UI using managers"""
	# Add header
	var header_panel = header_manager.create_header()
	main_container.add_child(header_panel)
	main_container.move_child(header_panel, 1)  # After back button
	
	# Add territory list
	var territory_list = list_manager.create_territory_list()
	scroll_container.add_child(territory_list)

func _connect_signals():
	"""Connect component signals"""
	header_manager.filter_changed.connect(list_manager.on_filter_changed)
	header_manager.collect_all_requested.connect(_on_collect_all_territories)
	
	list_manager.territory_action_requested.connect(actions_manager.handle_territory_action)
	actions_manager.territory_updated.connect(list_manager.refresh_territories)
	
	list_manager.territories_refreshed.connect(header_manager.update_summary_stats)

func _on_collect_all_territories():
	"""Handle collect all territories"""
	var territory_production = SystemRegistry.get_instance().get_system("TerritoryProductionManager")
	if not territory_production:
		return
	
	var collection_result = territory_production.collect_all_territory_resources()
	
	if collection_result.success:
		header_manager.show_collection_result(collection_result)
		list_manager.refresh_territories()

func _on_back_pressed():
	"""Handle back button"""
	back_pressed.emit()
