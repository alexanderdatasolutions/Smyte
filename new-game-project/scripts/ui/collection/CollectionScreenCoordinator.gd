class_name CollectionScreenCoordinator
extends Control

"""
CollectionScreenCoordinator.gd - Enhanced god collection interface coordinator
RULE 1: File stays under 300 lines by using specialized components
RULE 2: Single responsibility - coordinates collection display components
RULE 4: No data modification - uses systems for all god management
RULE 5: SystemRegistry for all system access

Architecture:
	pass
- Coordinates god list, sorting, filtering, and details components
- Rich interface with advanced sorting and filtering options
- Detailed god information panels with equipment and role management
"""

signal back_pressed

# Core systems
var collection_manager
var god_manager
var equipment_manager

# UI Components (loaded as separate modules)
const GodCollectionListScript = preload("res://scripts/ui/collection/GodCollectionList.gd")
const GodDetailsPanelScript = preload("res://scripts/ui/collection/GodDetailsPanel.gd") 
const CollectionFilterPanelScript = preload("res://scripts/ui/collection/CollectionFilterPanel.gd")

var god_list: GodCollectionList
var details_panel: GodDetailsPanel
var filter_panel: CollectionFilterPanel

# UI References
var main_container: HSplitContainer
var back_button: Button

func _ready():
	_init_systems()
	_setup_ui()
	_connect_signals()

func _init_systems():
	"""Initialize all required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("CollectionScreenCoordinator: SystemRegistry not available!")
		return
		
	collection_manager = registry.get_system("CollectionManager")
	god_manager = registry.get_system("CollectionManager")
	equipment_manager = registry.get_system("EquipmentManager")
	
	if not collection_manager:
		push_error("CollectionScreenCoordinator: CollectionManager not found!")
	if not god_manager:
		push_error("CollectionScreenCoordinator: CollectionManager not found!")
	if not equipment_manager:
		push_error("CollectionScreenCoordinator: EquipmentManager not found!")

func _setup_ui():
	"""Setup the main UI layout"""
	# Set up the main container
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create back button
	_create_back_button()
	
	# Create main horizontal split
	main_container = HSplitContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.offset_top = 50  # Space for back button
	add_child(main_container)
	
	# Left panel - God list with filtering
	_setup_left_panel()
	
	# Right panel - God details
	_setup_right_panel()
	
	# Set split ratio - ensure right panel has adequate space
	main_container.split_offset = 600  # Give more space for left panel, ensure right panel is visible
	

func _create_back_button():
	"""Create header bar with back button and skins button"""
	var header_bar: HBoxContainer = HBoxContainer.new()
	header_bar.name = "HeaderBar"
	header_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_bar.offset_bottom = 45
	header_bar.add_theme_constant_override("separation", 10)
	add_child(header_bar)

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(100, 40)
	back_button.pressed.connect(_on_back_pressed)
	header_bar.add_child(back_button)

	# Spacer to push skins button to the right
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)

	# Skins button (only visible if feature unlocked)
	var skins_button: Button = Button.new()
	skins_button.name = "SkinsButton"
	skins_button.text = "🎨 Skins"
	skins_button.custom_minimum_size = Vector2(100, 40)
	skins_button.pressed.connect(_on_skins_button_pressed)
	header_bar.add_child(skins_button)

	# Check if skins feature is unlocked
	_update_skins_button_visibility(skins_button)

func _setup_left_panel():
	"""Setup the left panel with god list and filtering"""
	var left_container = VBoxContainer.new()
	left_container.name = "LeftContainer"
	main_container.add_child(left_container)
	
	# Add filter panel
	filter_panel = CollectionFilterPanelScript.new()
	filter_panel.name = "FilterPanel"
	filter_panel.custom_minimum_size = Vector2(0, 80)
	left_container.add_child(filter_panel)
	
	# Add god list
	god_list = GodCollectionListScript.new()
	god_list.name = "GodList"
	god_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_container.add_child(god_list)

func _setup_right_panel():
	"""Setup the right panel with god details"""
	details_panel = GodDetailsPanelScript.new()
	details_panel.name = "DetailsPanel"
	details_panel.custom_minimum_size = Vector2(400, 0)
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Ensure visibility
	details_panel.visible = true
	details_panel.modulate = Color.WHITE
	
	main_container.add_child(details_panel)

func _connect_signals():
	"""Connect all component signals"""
	if god_list:
		god_list.god_selected.connect(_on_god_selected)
		god_list.god_action_requested.connect(_on_god_action_requested)
	
	if filter_panel:
		filter_panel.filter_changed.connect(_on_filter_changed)
	
	if details_panel:
		details_panel.god_action_requested.connect(_on_god_action_requested)
	
	# Connect to event bus for real-time updates
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		if event_bus.has_signal("god_obtained"):
			event_bus.god_obtained.connect(_refresh_god_list)
		if event_bus.has_signal("god_updated"):
			event_bus.god_updated.connect(_refresh_god_list)
		if event_bus.has_signal("equipment_changed"):
			event_bus.equipment_changed.connect(_refresh_god_details)

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()

func _on_god_selected(god_id: String):
	"""Handle god selection from list"""
	if details_panel:
		details_panel.display_god(god_id)

func _on_filter_changed(filters: Dictionary):
	"""Handle filter changes from filter panel"""
	if god_list:
		god_list.apply_filters(filters)

func _on_god_action_requested(action: String, god_id: String, data: Dictionary = {}):
	"""Handle god actions from any component - RULE 4: Delegate to systems"""
	
	match action:
		"assign_role":
			_handle_role_assignment(god_id, data.get("role", ""))
		"change_equipment":
			_handle_equipment_change(god_id, data.get("slot", ""), data.get("equipment_id", ""))
		"level_up":
			_handle_level_up(god_id)
		"evolve":
			_handle_evolution(god_id)
		"sacrifice":
			_handle_sacrifice(god_id)
		"view_details":
			_on_god_selected(god_id)
		_:
			pass

func _handle_role_assignment(god_id: String, role: String):
	"""Handle role assignment through systems - RULE 4: No direct data modification"""
	if not collection_manager:
		return
	
	var result = collection_manager.assign_god_role(god_id, role)
	if result.success:
		_refresh_god_details(god_id)

func _handle_equipment_change(god_id: String, slot: String, equipment_id: String):
	"""Handle equipment changes through systems - RULE 4: No direct data modification"""
	if not equipment_manager:
		return
	
	var result = equipment_manager.equip_item_to_god(god_id, equipment_id, slot)
	if result.success:
		_refresh_god_details(god_id)

func _handle_level_up(god_id: String):
	"""Handle god level up through systems - RULE 4: No direct data modification"""
	if not god_manager:
		return
	
	var result = god_manager.level_up_god(god_id)
	if result.success:
		_refresh_god_details(god_id)
		_refresh_god_list()

func _handle_evolution(god_id: String):
	"""Handle god evolution through systems - RULE 4: No direct data modification"""
	if not god_manager:
		return
	
	var result = god_manager.evolve_god(god_id)
	if result.success:
		_refresh_god_details(god_id)
		_refresh_god_list()

func _handle_sacrifice(god_id: String):
	"""Handle god sacrifice through systems - RULE 4: No direct data modification"""
	if not god_manager:
		return
	
	# This would typically show a confirmation dialog first
	var result = god_manager.sacrifice_god(god_id)
	if result.success:
		_refresh_god_list()
		# Clear details if this god was selected
		if details_panel:
			details_panel.clear_display()

func _refresh_god_list():
	"""Refresh the god list display"""
	if god_list:
		god_list.refresh_display()

func _refresh_god_details(god_id: String = ""):
	"""Refresh the god details display"""
	if details_panel and god_id != "":
		details_panel.display_god(god_id)
	elif details_panel:
		details_panel.refresh_current_display()

func _update_skins_button_visibility(skins_button: Button) -> void:
	"""Show/hide skins button based on feature unlock"""
	var registry = SystemRegistry.get_instance()
	var feature_manager = registry.get_system("FeatureUnlockManager") if registry else null
	if feature_manager and feature_manager.is_feature_unlocked("skin_selection"):
		skins_button.visible = true
	else:
		skins_button.visible = false

func _on_skins_button_pressed() -> void:
	"""Open the skin management popup"""
	var registry = SystemRegistry.get_instance()
	var skin_manager: Node = registry.get_system("SkinManager") if registry else null
	var collection_mgr: Node = registry.get_system("CollectionManager") if registry else null

	if not skin_manager or not collection_mgr:
		return

	# Create and show skin management popup
	var popup: SkinManagementPopup = SkinManagementPopup.new()
	add_child(popup)
	popup.show_popup()
