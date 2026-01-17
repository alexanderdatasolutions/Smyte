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
	if territories_config.has("territories"):
		if territories_config.territories is Array:
			territories_list = territories_config.territories
		elif territories_config.territories is Dictionary:
			# Dictionary format - extract values
			territories_list = territories_config.territories.values()
	else:
		# Old fallback format
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
	# Level requirements and prerequisites not implemented - all territories attackable
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

# ==============================================================================
# TASK INTEGRATION - Territory task slot management
# ==============================================================================

## Get buildings unlocked in a territory
func get_territory_buildings(territory_id: String) -> Array[String]:
	"""Get list of building IDs constructed in this territory"""
	var territory_info = get_territory_info(territory_id)
	var buildings: Array[String] = []
	var building_list = territory_info.get("buildings", [])
	for b in building_list:
		buildings.append(str(b))
	return buildings

## Get territory level (for task requirements)
func get_territory_level(territory_id: String) -> int:
	"""Get the current level of a territory"""
	var territory_info = get_territory_info(territory_id)
	return territory_info.get("level", 1)

## Check if territory has a specific building
func has_building(territory_id: String, building_id: String) -> bool:
	"""Check if a territory has a specific building"""
	return building_id in get_territory_buildings(territory_id)

## Get max task worker slots for territory
func get_max_task_slots(territory_id: String) -> int:
	"""Get maximum number of gods that can work on tasks in this territory"""
	var territory_info = get_territory_info(territory_id)
	var base_slots = territory_info.get("max_task_slots", 3)
	var level = get_territory_level(territory_id)
	# +1 slot per 3 levels
	@warning_ignore("integer_division")
	return base_slots + (level - 1) / 3

## Get gods currently working in territory
func get_working_gods(territory_id: String) -> Array[String]:
	"""Get IDs of gods assigned to tasks in this territory"""
	var task_manager = SystemRegistry.get_instance().get_system("TaskAssignmentManager") if SystemRegistry.get_instance() else null
	if task_manager:
		return task_manager.get_gods_working_in_territory(territory_id)
	return []

## Check if territory has available task slots
func has_available_task_slots(territory_id: String) -> bool:
	"""Check if more gods can be assigned to tasks in this territory"""
	if not is_territory_controlled(territory_id):
		return false
	var working_count = get_working_gods(territory_id).size()
	return working_count < get_max_task_slots(territory_id)

## Add building to territory (unlocks new tasks)
func add_building(territory_id: String, building_id: String) -> bool:
	"""Add a building to a territory"""
	if not is_territory_controlled(territory_id):
		return false

	if not territory_data.has(territory_id):
		return false

	if not territory_data[territory_id].has("buildings"):
		territory_data[territory_id]["buildings"] = []

	if building_id in territory_data[territory_id]["buildings"]:
		return false

	territory_data[territory_id]["buildings"].append(building_id)
	return true

## Get available tasks for a territory based on level and buildings
func get_available_tasks(territory_id: String) -> Array:
	"""Get tasks available in this territory"""
	var task_manager = SystemRegistry.get_instance().get_system("TaskAssignmentManager") if SystemRegistry.get_instance() else null
	if not task_manager:
		return []

	var level = get_territory_level(territory_id)
	var buildings = get_territory_buildings(territory_id)

	return task_manager.get_available_tasks_for_territory(level, buildings)

# ==============================================================================
# HEX TERRITORY SYSTEM INTEGRATION
# ==============================================================================

## Capture a hex node by coordinate
func capture_node(coord) -> bool:
	"""Capture a hex node at given coordinate - returns true on success"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		push_error("TerritoryManager: HexGridManager not found")
		return false

	var node = hex_grid_manager.get_node_at(coord)
	if not node:
		push_error("TerritoryManager: No node found at coordinate")
		return false

	# Check requirements
	var requirement_checker = SystemRegistry.get_instance().get_system("NodeRequirementChecker") if SystemRegistry.get_instance() else null
	if requirement_checker and not requirement_checker.can_player_capture_node(node):
		push_warning("TerritoryManager: Cannot capture node - requirements not met")
		return false

	# Capture the node
	node.controller = "player"
	node.is_revealed = true

	# Add to controlled territories for backward compatibility
	if node.id not in controlled_territories:
		controlled_territories.append(node.id)

	territory_captured.emit(node.id)

	# Notify event bus
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("territory_captured", node.id)

	return true

## Lose control of a hex node
func lose_node(coord) -> bool:
	"""Player loses control of node at coordinate"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return false

	var node = hex_grid_manager.get_node_at(coord)
	if not node:
		return false

	if not node.is_controlled_by_player():
		return false

	# Set to neutral or enemy
	node.controller = "neutral"
	node.garrison.clear()
	node.assigned_workers.clear()
	node.active_tasks.clear()

	# Remove from controlled territories
	controlled_territories.erase(node.id)

	territory_lost.emit(node.id)

	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("territory_lost", node.id)

	return true

## Get all controlled hex nodes
func get_controlled_nodes() -> Array:
	"""Get array of HexNode objects controlled by player"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return []

	return hex_grid_manager.get_player_nodes()

## Calculate defense rating for a node
func get_node_defense_rating(coord) -> float:
	"""Calculate total defense rating for node including distance penalty"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0.0

	var node = hex_grid_manager.get_node_at(coord)
	if not node:
		return 0.0

	# Base defense from garrison
	var base_defense = _calculate_garrison_power(node)

	# Apply defense level bonus (+10% per level)
	var defense_bonus = 1.0 + (node.defense_level - 1) * 0.1

	# Apply distance penalty
	var distance_penalty = calculate_distance_penalty(coord)

	# Apply connected node bonus
	var connected_bonus = get_connected_bonus(coord)

	return base_defense * defense_bonus * (1.0 - distance_penalty) * (1.0 + connected_bonus)

## Calculate distance penalty for a node
func calculate_distance_penalty(coord) -> float:
	"""Calculate defense penalty based on distance from base (5% per hex)"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0.0

	var distance = hex_grid_manager.get_distance_from_base(coord)
	return min(distance * 0.05, 0.95)  # Cap at 95% penalty

## Get connected node bonus for production/defense
func get_connected_bonus(coord) -> float:
	"""Calculate bonus from connected controlled nodes"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0.0

	var node = hex_grid_manager.get_node_at(coord)
	if not node or not node.is_controlled_by_player():
		return 0.0

	# Count adjacent controlled nodes
	var connected_count = 0
	var neighbors = hex_grid_manager.get_neighbors(coord)
	for neighbor_node in neighbors:
		if neighbor_node.is_controlled_by_player():
			connected_count += 1

	# Bonus tiers (from CLAUDE.md)
	if connected_count >= 4:
		return 0.30  # +30% production, +defense
	elif connected_count >= 3:
		return 0.20  # +20% production
	elif connected_count >= 2:
		return 0.10  # +10% production
	else:
		return 0.0

## Calculate total power of garrison gods
func _calculate_garrison_power(node) -> float:
	"""Calculate total combat power of gods in garrison"""
	if node.garrison.size() == 0:
		return 0.0

	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	if not collection_manager:
		return 0.0

	var total_power = 0.0
	for god_id in node.garrison:
		var god_obj = collection_manager.get_god(god_id)
		if god_obj:
			# Use same power calculation as NodeRequirementChecker
			var hp = god_obj.current_hp
			var attack = god_obj.attack
			var defense = god_obj.defense
			var speed = god_obj.speed
			var level = god_obj.level
			var awakening_bonus = 1.0 + (god_obj.awakening_level * 0.1)

			var god_power = (hp + attack * 2 + defense + speed) * (1.0 + level * 0.05) * awakening_bonus
			total_power += god_power

	return total_power

## Get number of connected controlled nodes
func get_connected_node_count(coord) -> int:
	"""Get count of adjacent controlled nodes"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0

	var neighbors = hex_grid_manager.get_neighbors(coord)
	var connected_count = 0
	for neighbor_node in neighbors:
		if neighbor_node.is_controlled_by_player():
			connected_count += 1

	return connected_count

## Check if a hex node is controlled by player
func is_hex_node_controlled(coord) -> bool:
	"""Check if player controls node at coordinate"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return false

	var node = hex_grid_manager.get_node_at(coord)
	if not node:
		return false

	return node.is_controlled_by_player()

## Get hex node at coordinate
func get_hex_node(coord):
	"""Get HexNode object at coordinate (convenience method)"""
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return null

	return hex_grid_manager.get_node_at(coord)
