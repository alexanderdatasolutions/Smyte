# scripts/ui/sacrifice/AwakeningTabManager.gd
# Single responsibility: Manage the awakening tab UI and functionality
class_name AwakeningTabManager
extends Node

signal god_awakened(god: God)

# Load component scripts
const AwakeningGodListScript = preload("res://scripts/ui/sacrifice/AwakeningGodList.gd")
const AwakeningPanelScript = preload("res://scripts/ui/sacrifice/AwakeningPanel.gd")

var awakening_list_ui
var awakening_panel_ui
var current_tab: Control

func create_awakening_tab() -> Control:
	current_tab = Control.new()
	current_tab.name = "Awakening"
	
	var main_container = HBoxContainer.new()
	current_tab.add_child(main_container)
	
	# Create god list on the left
	awakening_list_ui = AwakeningGodListScript.new()
	awakening_list_ui.god_selected.connect(_on_god_selected)
	main_container.add_child(awakening_list_ui.create_god_list())
	
	# Create awakening panel on the right  
	awakening_panel_ui = AwakeningPanelScript.new()
	awakening_panel_ui.awakening_requested.connect(_on_awakening_requested)
	main_container.add_child(awakening_panel_ui.create_panel())
	
	return current_tab

func _on_god_selected(god: God):
	awakening_panel_ui.display_god(god)

func _on_awakening_requested(god: God):
	_perform_awakening(god)
	awakening_list_ui.refresh_list()
	awakening_panel_ui.clear_display()

func _perform_awakening(god: God):
	var awakening_system = SystemRegistry.get_instance().get_system("AwakeningSystem")
	var result = awakening_system.awaken_god(god.id)
	
	if result.success:
		var event_bus = SystemRegistry.get_instance().get_system("EventBus")
		event_bus.emit_signal("god_awakened", god.id)
		
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		notification_manager.show_awakening_result(god)
		
		god_awakened.emit(god)
