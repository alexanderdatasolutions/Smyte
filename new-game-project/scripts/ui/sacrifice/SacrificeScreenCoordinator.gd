# scripts/ui/sacrifice/SacrificeScreenCoordinator.gd
# Coordinates the modular sacrifice screen - following CollectionScreenCoordinator pattern
class_name SacrificeScreenCoordinator
extends Control

signal back_pressed

# UI Components (following modular pattern like Collection System)
@onready var sacrifice_god_list: SacrificeGodList
@onready var sacrifice_panel: SacrificePanel  
@onready var awakening_god_list: AwakeningGodList
@onready var awakening_panel: AwakeningPanel
@onready var tab_container: TabContainer

# System references (using SystemRegistry)
var sacrifice_manager: SacrificeManager
var collection_manager: CollectionManager
var event_bus: EventBus

# State management
var current_sacrifice_god: God = null
var current_awakening_god: God = null

func _ready():
	_initialize_systems()
	_setup_ui_components()
	_connect_signals()

func _initialize_systems():
	"""Initialize system references through SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	sacrifice_manager = system_registry.get_system("SacrificeManager")
	collection_manager = system_registry.get_system("CollectionManager")
	event_bus = system_registry.get_system("EventBus")

func _setup_ui_components():
	"""Setup and initialize UI components"""
	if not tab_container:
		print("SacrificeScreenCoordinator: TabContainer not found!")
		return
	
	# Create Sacrifice tab with components
	var sacrifice_tab = _create_sacrifice_tab()
	tab_container.add_child(sacrifice_tab)
	
	# Create Awakening tab with components
	var awakening_tab = _create_awakening_tab()
	tab_container.add_child(awakening_tab)

func _create_sacrifice_tab() -> Control:
	"""Create the sacrifice tab with god list and sacrifice panel"""
	var tab = Control.new()
	tab.name = "Sacrifice"
	
	var main_container = HSplitContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.split_offset = 400  # Left side width
	tab.add_child(main_container)
	
	# Create and setup sacrifice god list
	sacrifice_god_list = SacrificeGodList.new()
	sacrifice_god_list.name = "SacrificeGodList"
	main_container.add_child(sacrifice_god_list)
	
	# Create and setup sacrifice panel
	sacrifice_panel = SacrificePanel.new()
	sacrifice_panel.name = "SacrificePanel"
	main_container.add_child(sacrifice_panel)
	
	return tab

func _create_awakening_tab() -> Control:
	"""Create the awakening tab with god list and awakening panel"""
	var tab = Control.new()
	tab.name = "Awakening"
	
	var main_container = HSplitContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.split_offset = 400  # Left side width
	tab.add_child(main_container)
	
	# Create and setup awakening god list
	awakening_god_list = AwakeningGodList.new()
	awakening_god_list.name = "AwakeningGodList"
	main_container.add_child(awakening_god_list)
	
	# Create and setup awakening panel
	awakening_panel = AwakeningPanel.new()
	awakening_panel.name = "AwakeningPanel"
	main_container.add_child(awakening_panel)
	
	return tab

func _connect_signals():
	"""Connect signals between components and systems"""
	# Sacrifice tab signals
	if sacrifice_god_list:
		sacrifice_god_list.god_selected.connect(_on_sacrifice_god_selected)
		sacrifice_god_list.god_double_clicked.connect(_on_sacrifice_god_material_selected)
	
	if sacrifice_panel:
		sacrifice_panel.sacrifice_requested.connect(_on_sacrifice_requested)
	
	# Awakening tab signals  
	if awakening_god_list:
		awakening_god_list.god_selected.connect(_on_awakening_god_selected)
	
	if awakening_panel:
		awakening_panel.awakening_requested.connect(_on_awakening_requested)
	
	# System events
	if event_bus:
		event_bus.collection_updated.connect(_refresh_displays)
		event_bus.god_sacrificed.connect(_on_god_sacrificed)
		event_bus.god_awakened.connect(_on_god_awakened)
	
	if sacrifice_manager:
		sacrifice_manager.sacrifice_completed.connect(_on_sacrifice_completed)
		sacrifice_manager.sacrifice_failed.connect(_on_sacrifice_failed)
		sacrifice_manager.awakening_completed.connect(_on_awakening_completed)  
		sacrifice_manager.awakening_failed.connect(_on_awakening_failed)

# === SACRIFICE TAB HANDLERS ===

func _on_sacrifice_god_selected(god: God):
	"""Handle god selection in sacrifice tab"""
	current_sacrifice_god = god
	if sacrifice_panel:
		sacrifice_panel.set_target_god(god)

func _on_sacrifice_god_material_selected(god: God):
	"""Handle god selection as material"""
	if sacrifice_panel:
		sacrifice_panel.add_material_god(god)

func _on_sacrifice_requested(target_god: God, material_gods: Array[God]):
	"""Handle sacrifice request from sacrifice panel"""
	if not sacrifice_manager:
		print("SacrificeScreenCoordinator: SacrificeManager not available")
		return
	
	var result = sacrifice_manager.perform_sacrifice(target_god, material_gods)
	if result.success:
		print("Sacrifice successful! XP gained: %d" % result.xp_gained)
	else:
		print("Sacrifice failed: %s" % result.error)

# === AWAKENING TAB HANDLERS ===

func _on_awakening_god_selected(god: God):
	"""Handle god selection in awakening tab"""
	current_awakening_god = god
	if awakening_panel:
		awakening_panel.set_target_god(god)

func _on_awakening_requested(god: God):
	"""Handle awakening request from awakening panel"""
	if not sacrifice_manager:
		print("SacrificeScreenCoordinator: SacrificeManager not available")
		return
	
	var result = sacrifice_manager.attempt_awakening(god)
	if result.success:
		print("Awakening successful for %s!" % god.name)
	else:
		print("Awakening failed: %s" % result.error)

# === SYSTEM EVENT HANDLERS ===

func _on_sacrifice_completed(target_god: God, _material_gods: Array, xp_gained: int):
	"""Handle successful sacrifice"""
	_refresh_displays()
	_show_sacrifice_success_notification(target_god, xp_gained)

func _on_sacrifice_failed(reason: String):
	"""Handle failed sacrifice"""
	_show_error_notification("Sacrifice Failed", reason)

func _on_awakening_completed(god: God):
	"""Handle successful awakening"""
	_refresh_displays()
	_show_awakening_success_notification(god)

func _on_awakening_failed(god: God, reason: String):
	"""Handle failed awakening"""
	_show_error_notification("Awakening Failed", "Failed to awaken %s: %s" % [god.name, reason])

func _on_god_sacrificed(_god_id: String, _xp_gained: int):
	"""Handle god sacrifice events from EventBus"""
	_refresh_displays()

func _on_god_awakened(_god_id: String):
	"""Handle god awakening events from EventBus"""
	_refresh_displays()

# === UI UPDATE METHODS ===

func _refresh_displays():
	"""Refresh all UI displays"""
	if sacrifice_god_list:
		sacrifice_god_list.refresh_god_list()
	
	if awakening_god_list:
		awakening_god_list.refresh_god_list()
	
	if sacrifice_panel:
		sacrifice_panel.refresh_display()
	
	if awakening_panel:
		awakening_panel.refresh_display()

func _show_sacrifice_success_notification(god: God, xp_gained: int):
	"""Show sacrifice success notification"""
	var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
	if notification_manager:
		notification_manager.show_notification(
			"Sacrifice Complete!",
			"%s gained %d experience" % [god.name, xp_gained],
			3.0
		)

func _show_awakening_success_notification(god: God):
	"""Show awakening success notification"""
	var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
	if notification_manager:
		notification_manager.show_notification(
			"Awakening Complete!",
			"%s has been awakened!" % god.name,
			3.0
		)

func _show_error_notification(title: String, message: String):
	"""Show error notification"""
	var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
	if notification_manager:
		notification_manager.show_notification(title, message, 3.0)

# === PUBLIC INTERFACE ===

func refresh():
	"""Public method to refresh the entire screen"""
	_refresh_displays()

func set_active_tab(tab_index: int):
	"""Set the active tab"""
	if tab_container and tab_index >= 0 and tab_index < tab_container.get_tab_count():
		tab_container.current_tab = tab_index

func get_sacrifice_manager() -> SacrificeManager:
	"""Get reference to sacrifice manager"""
	return sacrifice_manager
