# scripts/systems/territory/TerritoryManager.gd
# Territory control system - manages territory ownership and basic operations (200 lines max)
class_name TerritoryManager extends Node

signal territory_captured(territory_id: String)
signal territory_lost(territory_id: String)
signal territory_upgraded(territory_id: String, new_level: int)

var controlled_territories: Array[String] = []
var territory_data: Dictionary = {}

func _ready():
	_load_territory_configuration()

## Load territory configuration
func _load_territory_configuration():
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if config_manager:
		territory_data = config_manager.get_territories_config()

## Capture a territory
func capture_territory(territory_id: String) -> bool:
	if territory_id in controlled_territories:
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
		return false
	
	# Check upgrade cost through ResourceManager
	var upgrade_cost = _get_upgrade_cost(territory_id, current_level + 1)
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null

	if not resource_manager or not resource_manager.can_afford(upgrade_cost):
		return false
	
	# Spend resources and upgrade
	resource_manager.spend_resources(upgrade_cost)
	territory_data[territory_id]["level"] = current_level + 1

	territory_upgraded.emit(territory_id, current_level + 1)
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
	@warning_ignore("integer_division")
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

# ==============================================================================
# ENHANCED METHODS FOR TERRITORY UI SYSTEM
# ==============================================================================

## Get territories filtered by status (for enhanced UI)
func get_territories_by_filter(filter_id: String) -> Array:
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if not config_manager:
		return []
	
	var territories_config = config_manager.get_territories_config()
	var territories = []
	
	# Handle both array and dictionary formats
	var territories_list = []
	if territories_config.has("territories") and territories_config.territories is Array:
		territories_list = territories_config.territories
	else:
		# Fallback for dictionary format
		territories_list = territories_config.values()
	
	# Convert config data to Territory dictionaries for UI
	for territory_config_data in territories_list:
		var territory_id = territory_config_data.get("id", "unknown")
		
		# Create a simplified territory object for UI
		var territory = _create_territory_from_config(territory_id, territory_config_data)
		
		# Apply filter
		var include = false
		match filter_id:
			"all":
				include = true
			"controlled":
				include = is_territory_controlled(territory_id)
			"available":
				include = not is_territory_controlled(territory_id) and _can_attack_territory(territory_id)
			"completed":
				include = not is_territory_controlled(territory_id) and _is_territory_completed(territory_id)
		
		if include:
			territories.append(territory)
	
	return territories

## Get all territories (for enhanced UI)
func get_all_territories() -> Array:
	return get_territories_by_filter("all")

## Create a territory object from config data
func _create_territory_from_config(territory_id: String, config: Dictionary) -> Dictionary:
	return {
		"id": territory_id,
		"name": config.get("name", territory_id.capitalize()),
		"tier": config.get("tier", 1),
		"element": config.get("element", "neutral"),
		"controller": "player" if is_territory_controlled(territory_id) else "enemy",
		"current_stage": config.get("current_stage", 0),
		"max_stages": config.get("max_stages", 10),
		"base_resource_rate": config.get("base_resource_rate", 100),
		"territory_level": config.get("level", 1),
		"stationed_gods": config.get("stationed_gods", []),
		"max_god_slots": config.get("max_god_slots", 3)
	}

## Check if territory can be attacked
func _can_attack_territory(territory_id: String) -> bool:
	# For now, assume all territories can be attacked
	# TODO: Implement level requirements and prerequisites
	return not is_territory_controlled(territory_id)

## Check if territory is completed (all stages cleared)
func _is_territory_completed(territory_id: String) -> bool:
	var territory_info = get_territory_info(territory_id)
	var current_stage = territory_info.get("current_stage", 0)
	var max_stages = territory_info.get("max_stages", 10)
	return current_stage >= max_stages

## Get territory resource rate
func get_territory_resource_rate(territory_id: String) -> int:
	var territory_info = get_territory_info(territory_id)
	return territory_info.get("base_resource_rate", 100)

## Get pending resources for territory
func get_pending_resources(_territory_id: String) -> Dictionary:
	# For now, return empty - this would be implemented with actual resource generation
	return {}

## Collect territory resources
func collect_territory_resources(_territory_id: String) -> Dictionary:
	# For now, return empty - this would be implemented with actual resource collection
	return {"total": 0, "resources": {}}

## Collect all resources from controlled territories
func collect_all_resources() -> Dictionary:
	var total_collected = {}
	var territories_collected = 0
	
	for territory_id in controlled_territories:
		var resources = collect_territory_resources(territory_id)
		if resources.get("total", 0) > 0:
			territories_collected += 1
			# Merge resources
			for resource_type in resources.get("resources", {}):
				total_collected[resource_type] = total_collected.get(resource_type, 0) + resources["resources"][resource_type]
	
	return {
		"territory_count": territories_collected,
		"total_collected": _sum_dictionary_values(total_collected),
		"resources": total_collected
	}

func _sum_dictionary_values(dict: Dictionary) -> int:
	var total = 0
	for value in dict.values():
		total += value
	return total
