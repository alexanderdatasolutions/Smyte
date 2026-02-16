# scripts/ui/territory/TerritoryActionsManager.gd
# Single responsibility: Handle territory-related actions (collect, manage, attack)
class_name TerritoryActionsManager
extends Node

signal territory_updated

func handle_territory_action(territory_id: String, action: String, data: Dictionary):
	"""Handle territory actions using SystemRegistry systems"""

	match action:
		"collect_resources":
			_handle_collect_resources(territory_id)
		"manage_gods":
			_handle_manage_gods(territory_id)
		"manage_tasks":
			_handle_manage_tasks(territory_id)
		"attack":
			_handle_attack_territory(territory_id, data)
		_:
			pass

func _handle_collect_resources(territory_id: String):
	"""Handle resource collection from hex node"""

	var territory_production = SystemRegistry.get_instance().get_system("TerritoryProductionManager")
	if not territory_production:
		return

	var collected = territory_production.collect_node_resources(territory_id)

	if not collected.is_empty():
		territory_updated.emit()

func _handle_manage_gods(territory_id: String):
	"""Handle opening territory management for god assignments"""

	# Navigate to territory role screen (this screen exists)
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		# Store territory context for the role screen
		screen_manager.set_screen_context("territory_role", {"territory_id": territory_id})
		screen_manager.change_screen("territory_role")

func _handle_manage_tasks(territory_id: String):
	"""Handle opening task assignment screen for territory"""

	# Navigate to task assignment screen
	var screen_manager = SystemRegistry.get_instance().get_system("ScreenManager")
	if screen_manager:
		# Store territory context for the task screen
		screen_manager.set_screen_context("task_assignment", {"territory_id": territory_id})
		screen_manager.change_screen("task_assignment")

func _handle_attack_territory(territory_id: String, _data: Dictionary):
	"""Handle territory attack setup"""
	
	# Get player power for validation
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if not collection_manager:
		return
	
	# Get territory configuration for power requirement
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	if not config_manager:
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
		return
	
	# Check power requirement
	var required_power = territory_data.get("required_power", 0)
	var player_power = collection_manager.get_total_player_power()
	
	if player_power < required_power:
		
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
