# scripts/systems/territory/TerritoryManager.gd
# Territory control system - manages territory ownership and basic operations (200 lines max)
class_name TerritoryController extends Node

signal territory_captured(territory_id: String)
signal territory_lost(territory_id: String)
signal territory_upgraded(territory_id: String, new_level: int)

var controlled_territories: Array[String] = []
var territory_data: Dictionary = {}

func _ready():
	print("TerritoryManager: Initialized")
	_load_territory_configuration()

## Load territory configuration
func _load_territory_configuration():
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if config_manager:
		territory_data = config_manager.get_territories_config()
		print("TerritoryManager: Loaded ", territory_data.size(), " territories")

## Capture a territory
func capture_territory(territory_id: String) -> bool:
	if territory_id in controlled_territories:
		print("TerritoryManager: Territory already controlled: ", territory_id)
		return false
	
	if not territory_data.has(territory_id):
		push_error("TerritoryManager: Unknown territory: " + territory_id)
		return false
	
	controlled_territories.append(territory_id)
	territory_captured.emit(territory_id)
	
	# Notify other systems
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("territory_captured", territory_id)
	
	print("TerritoryManager: Captured territory: ", territory_id)
	return true

## Lose a territory
func lose_territory(territory_id: String) -> bool:
	if territory_id not in controlled_territories:
		return false
	
	controlled_territories.erase(territory_id)
	territory_lost.emit(territory_id)
	
	# Notify other systems
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("territory_lost", territory_id)
	
	print("TerritoryManager: Lost territory: ", territory_id)
	return true

## Check if territory is controlled
func is_territory_controlled(territory_id: String) -> bool:
	return territory_id in controlled_territories

## Get all controlled territories
func get_controlled_territories() -> Array[String]:
	return controlled_territories.duplicate()

## Get territory information
func get_territory_info(territory_id: String) -> Dictionary:
	return territory_data.get(territory_id, {})

## Upgrade territory
func upgrade_territory(territory_id: String) -> bool:
	if territory_id not in controlled_territories:
		push_error("TerritoryManager: Cannot upgrade uncontrolled territory: " + territory_id)
		return false
	
	var territory_info = get_territory_info(territory_id)
	if territory_info.is_empty():
		return false
	
	var current_level = territory_info.get("level", 1)
	var max_level = territory_info.get("max_level", 10)
	
	if current_level >= max_level:
		print("TerritoryManager: Territory already at max level: ", territory_id)
		return false
	
	# Check upgrade cost through ResourceManager
	var upgrade_cost = _get_upgrade_cost(territory_id, current_level + 1)
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	
	if not resource_manager or not resource_manager.can_afford(upgrade_cost):
		print("TerritoryManager: Cannot afford territory upgrade: ", territory_id)
		return false
	
	# Spend resources and upgrade
	resource_manager.spend_resources(upgrade_cost)
	territory_data[territory_id]["level"] = current_level + 1
	
	territory_upgraded.emit(territory_id, current_level + 1)
	print("TerritoryManager: Upgraded territory ", territory_id, " to level ", current_level + 1)
	return true

## Get territory upgrade cost
func _get_upgrade_cost(_territory_id: String, target_level: int) -> Dictionary:
	var base_cost = 1000
	var level_multiplier = pow(1.5, target_level - 1)
	
	return {
		"mana": int(base_cost * level_multiplier),
		"materials": int(base_cost * 0.1 * level_multiplier)
	}

## Get territory count
func get_territory_count() -> int:
	return controlled_territories.size()

## Get territory by type
func get_territories_by_type(territory_type: String) -> Array[String]:
	var matching_territories = []
	
	for territory_id in controlled_territories:
		var territory_info = get_territory_info(territory_id)
		if territory_info.get("type", "") == territory_type:
			matching_territories.append(territory_id)
	
	return matching_territories

## Check if can capture more territories
func can_capture_more_territories() -> bool:
	# Get player level from progression system
	var progression_manager = SystemRegistry.get_instance().get_system("PlayerProgressionManager") if SystemRegistry.get_instance() else null
	var player_level = progression_manager.get_player_level() if progression_manager else 1
	
	var max_territories = _calculate_max_territories(player_level)
	return controlled_territories.size() < max_territories

func _calculate_max_territories(player_level: int) -> int:
	# Base: 3 territories, +1 every 5 levels
	return 3 + (player_level - 1) / 5

## For save/load
func get_save_data() -> Dictionary:
	return {
		"controlled_territories": controlled_territories.duplicate(),
		"territory_data": territory_data.duplicate()
	}

func load_save_data(save_data: Dictionary):
	controlled_territories = save_data.get("controlled_territories", [])
	var saved_territory_data = save_data.get("territory_data", {})
	
	# Merge saved data with config data
	for territory_id in saved_territory_data:
		if territory_data.has(territory_id):
			territory_data[territory_id].merge(saved_territory_data[territory_id])
	
	print("TerritoryManager: Loaded ", controlled_territories.size(), " controlled territories")
