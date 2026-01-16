# scripts/ui/territory/TerritoryActionsManager.gd
# Single responsibility: Handle territory-related actions (collect, manage, attack)
class_name TerritoryActionsManager
extends Node

signal territory_updated

func handle_territory_action(territory_id: String, action: String, data: Dictionary):
	"""Handle territory actions using SystemRegistry systems"""
	print("TerritoryActionsManager: Handling action '%s' for territory '%s'" % [action, territory_id])
	
	match action:
		"collect_resources":
			_handle_collect_resources(territory_id)
		"manage_gods":
			_handle_manage_gods(territory_id)
		"attack":
			_handle_attack_territory(territory_id, data)
		_:
			print("TerritoryActionsManager: Unknown territory action: %s" % action)

func _handle_collect_resources(territory_id: String):
	"""Handle resource collection from territory"""
	print("TerritoryActionsManager: Collecting resources from territory: %s" % territory_id)
	
	var territory_production = SystemRegistry.get_instance().get_system("TerritoryProductionManager")
	if not territory_production:
		print("TerritoryActionsManager: ERROR - TerritoryProductionManager not found")
		return
	
	var collection_result = territory_production.collect_territory_resources(territory_id)
	
	if collection_result.success:
		print("TerritoryActionsManager: Successfully collected resources: %s" % collection_result.resources)
		
		# Show collection notification
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		if notification_manager:
			notification_manager.show_resource_collection(collection_result)
		
		territory_updated.emit()
	else:
		print("TerritoryActionsManager: Collection failed: %s" % collection_result.error_message)

func _handle_manage_gods(territory_id: String):
	"""Handle opening territory management for god assignments"""
	print("TerritoryActionsManager: Opening territory management for: %s" % territory_id)
	
	# Navigate to territory role screen (this screen exists)
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		# Store territory context for the role screen
		screen_manager.set_screen_context("territory_role", {"territory_id": territory_id})
		screen_manager.change_screen("territory_role")
	else:
		print("TerritoryActionsManager: ERROR - ScreenManager not found")

func _handle_attack_territory(territory_id: String, _data: Dictionary):
	"""Handle territory attack setup"""
	print("TerritoryActionsManager: Setting up attack for territory: %s" % territory_id)
	
	# Get player power for validation
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if not collection_manager:
		print("TerritoryActionsManager: ERROR - CollectionManager not found")
		return
	
	# Get territory configuration for power requirement
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	if not config_manager:
		print("TerritoryActionsManager: ERROR - ConfigurationManager not found")
		return
	
	var territories_config = config_manager.get_territories_config()
	var territory_data = null
	
	# Find territory data
	if territories_config.has("territories") and territories_config.territories is Array:
		for territory in territories_config.territories:
			if territory.get("id") == territory_id:
				territory_data = territory
				break
	
	if not territory_data:
		print("TerritoryActionsManager: ERROR - Territory data not found for: %s" % territory_id)
		return
	
	# Check power requirement
	var required_power = territory_data.get("required_power", 0)
	var player_power = collection_manager.get_total_player_power()
	
	if player_power < required_power:
		print("TerritoryActionsManager: Insufficient power - need %d, have %d" % [required_power, player_power])
		
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		if notification_manager:
			notification_manager.show_error("Need %d power to attack this territory (you have %d)" % [required_power, player_power])
		return
	
	# Navigate to battle setup screen
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		# Store battle context for the battle setup screen
		screen_manager.set_screen_context("battle_setup", {
			"battle_type": "territory_conquest",
			"territory_id": territory_id,
			"territory_name": territory_data.get("name", territory_id),
			"required_power": required_power
		})
		screen_manager.change_screen("battle_setup")
	else:
		print("TerritoryActionsManager: ERROR - ScreenManager not found")
