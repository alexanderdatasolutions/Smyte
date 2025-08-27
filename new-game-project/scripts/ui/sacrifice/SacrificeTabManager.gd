# scripts/ui/sacrifice/SacrificeTabManager.gd
# Single responsibility: Manage the sacrifice tab UI and functionality
class_name SacrificeTabManager
extends Node

signal god_selected(god: God)

# Load component scripts
const SacrificeGodListScript = preload("res://scripts/ui/sacrifice/SacrificeGodList.gd")
const SacrificePanelScript = preload("res://scripts/ui/sacrifice/SacrificePanel.gd")

var god_list_ui
var sacrifice_panel_ui
var current_tab: Control

func create_sacrifice_tab() -> Control:
	current_tab = Control.new()
	current_tab.name = "Sacrifice"
	
	var main_container = HBoxContainer.new()
	current_tab.add_child(main_container)
	
	# Create god list on the left
	god_list_ui = SacrificeGodListScript.new()
	god_list_ui.god_selected.connect(_on_god_selected)
	main_container.add_child(god_list_ui.create_god_list())
	
	# Create sacrifice panel on the right
	sacrifice_panel_ui = SacrificePanelScript.new()
	sacrifice_panel_ui.sacrifice_requested.connect(_on_sacrifice_requested)
	main_container.add_child(sacrifice_panel_ui.create_panel())
	
	return current_tab

func _on_god_selected(god: God):
	sacrifice_panel_ui.display_god(god)
	god_selected.emit(god)

func _on_sacrifice_requested(god: God):
	_perform_sacrifice(god)
	god_list_ui.refresh_list()
	sacrifice_panel_ui.clear_display()

func _perform_sacrifice(god: God):
	var sacrifice_system = SystemRegistry.get_instance().get_system("SacrificeSystem")
	var result = sacrifice_system.sacrifice_god(god.id)
	
	if result.success:
		var event_bus = SystemRegistry.get_instance().get_system("EventBus")
		event_bus.emit_signal("god_sacrificed", god.id, result.rewards)
		
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		notification_manager.show_sacrifice_result(result.rewards)
