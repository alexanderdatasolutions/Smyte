# scripts/ui/territory/TerritoryActionsManager.gd
# Single responsibility: Handle territory-related actions (collect, manage, attack)
class_name TerritoryActionsManager
extends Node

signal territory_updated

func handle_territory_action(territory: Territory, action: String, _data: Dictionary):
	match action:
		"collect_resources":
			_handle_collect_resources(territory)
		"manage_gods":
			_handle_manage_gods(territory)
		"attack":
			_handle_attack_territory(territory)
		_:
			print("Unknown territory action: ", action)

func _handle_collect_resources(territory: Territory):
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var resources_collected = territory_manager.collect_territory_resources(territory.id)
	
	if resources_collected.total > 0:
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		notification_manager.show_resource_collection(resources_collected)
		territory_updated.emit()

func _handle_manage_gods(territory: Territory):
	# Open territory role management screen
	var scene_manager = SystemRegistry.get_instance().get_system("SceneManager")
	scene_manager.transition_to_territory_management(territory)

func _handle_attack_territory(territory: Territory):
	# Check if player has enough power
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	var player_power = collection_manager.get_total_player_power()
	
	if player_power < territory.required_power:
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		notification_manager.show_error("Insufficient power to attack this territory")
		return
	
	# Open battle setup for territory conquest
	var battle_manager = SystemRegistry.get_instance().get_system("BattleCoordinator")
	battle_manager.start_territory_conquest(territory)
