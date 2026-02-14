# scripts/systems/territory/TerritoryManager.gd
# Territory control system - manages territory ownership and basic operations (200 lines max)
class_name TerritoryManager extends Node

signal territory_captured(territory_id: String)
signal territory_lost(territory_id: String)
signal territory_upgraded(territory_id: String, new_level: int)
signal node_unlocked(node_id: String, unlock_source: String)  # Emitted when dungeon completion unlocks a node

var controlled_territories: Array[String] = []
var territory_data: Dictionary = {}

func _ready() -> void:
	_load_territory_configuration()
	_connect_to_dungeon_coordinator()

## Load territory configuration
func _load_territory_configuration() -> void:
	var config_manager: Node = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
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
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
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
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
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
	
	var territory_info: Dictionary = get_territory_info(territory_id)
	if territory_info.is_empty():
		return false

	var current_level: int = territory_info.get("level", 1)
	var max_level: int = territory_info.get("max_level", 10)

	if current_level >= max_level:
		return false
	
	# Check upgrade cost through ResourceManager
	var upgrade_cost: Dictionary = _get_upgrade_cost(territory_id, current_level + 1)
	var resource_manager: Node = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null

	if not resource_manager or not resource_manager.can_afford(upgrade_cost):
		return false
	
	# Spend resources and upgrade
	resource_manager.spend_resources(upgrade_cost)
	territory_data[territory_id]["level"] = current_level + 1

	territory_upgraded.emit(territory_id, current_level + 1)
	return true

## Get territory upgrade cost
func _get_upgrade_cost(_territory_id: String, target_level: int) -> Dictionary:
	var base_cost: int = 1000
	var level_multiplier: float = pow(1.5, target_level - 1)
	
	return {
		"mana": int(base_cost * level_multiplier),
		"materials": int(base_cost * 0.1 * level_multiplier)
	}

## Get territory count
func get_territory_count() -> int:
	return controlled_territories.size()

## Get territory by type
func get_territories_by_type(territory_type: String) -> Array[String]:
	var matching_territories: Array[String] = []

	for territory_id: String in controlled_territories:
		var territory_info: Dictionary = get_territory_info(territory_id)
		if territory_info.get("type", "") == territory_type:
			matching_territories.append(territory_id)
	
	return matching_territories

## Check if can capture more territories
func can_capture_more_territories() -> bool:
	# Get player level from progression system
	var progression_manager: Node = SystemRegistry.get_instance().get_system("PlayerProgressionManager") if SystemRegistry.get_instance() else null
	var player_level: int = progression_manager.get_player_level() if progression_manager else 1

	var max_territories: int = _calculate_max_territories(player_level)
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

func load_save_data(save_data: Dictionary) -> void:
	var saved_territories: Array = save_data.get("controlled_territories", [])
	controlled_territories.clear()
	for territory: Variant in saved_territories:
		if territory is String:
			controlled_territories.append(territory)
	var saved_territory_data: Dictionary = save_data.get("territory_data", {})
	
	# Merge saved data with config data
	for territory_id in saved_territory_data:
		if territory_data.has(territory_id):
			territory_data[territory_id].merge(saved_territory_data[territory_id])

# ==============================================================================
# ENHANCED METHODS FOR TERRITORY UI SYSTEM
# ==============================================================================

## Get territories filtered by status (for enhanced UI)
func get_territories_by_filter(filter_id: String) -> Array:
	var config_manager: Node = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if not config_manager:
		return []

	var territories_config: Dictionary = config_manager.get_territories_config()
	var territories: Array = []

	# Handle both array and dictionary formats
	var territories_list: Array = []
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
	for territory_config_data: Variant in territories_list:
		var territory_id: String = territory_config_data.get("id", "unknown")

		# Create a simplified territory object for UI
		var territory: Dictionary = _create_territory_from_config(territory_id, territory_config_data)

		# Apply filter
		var include: bool = false
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
	var territory_info: Dictionary = get_territory_info(territory_id)
	var current_stage: int = territory_info.get("current_stage", 0)
	var max_stages: int = territory_info.get("max_stages", 10)
	return current_stage >= max_stages

## Get territory resource rate
func get_territory_resource_rate(territory_id: String) -> int:
	var territory_info: Dictionary = get_territory_info(territory_id)
	return territory_info.get("base_resource_rate", 100)

# ==============================================================================
# TASK INTEGRATION - Territory task slot management
# ==============================================================================

## Get buildings unlocked in a territory
func get_territory_buildings(territory_id: String) -> Array[String]:
	"""Get list of building IDs constructed in this territory"""
	var territory_info: Dictionary = get_territory_info(territory_id)
	var buildings: Array[String] = []
	var building_list: Array = territory_info.get("buildings", [])
	for b in building_list:
		buildings.append(str(b))
	return buildings

## Get territory level (for task requirements)
func get_territory_level(territory_id: String) -> int:
	"""Get the current level of a territory"""
	var territory_info: Dictionary = get_territory_info(territory_id)
	return territory_info.get("level", 1)

## Check if territory has a specific building
func has_building(territory_id: String, building_id: String) -> bool:
	"""Check if a territory has a specific building"""
	return building_id in get_territory_buildings(territory_id)

## Get max task worker slots for territory
func get_max_task_slots(territory_id: String) -> int:
	"""Get maximum number of gods that can work on tasks in this territory"""
	var territory_info: Dictionary = get_territory_info(territory_id)
	var base_slots: int = territory_info.get("max_task_slots", 3)
	var level: int = get_territory_level(territory_id)
	# +1 slot per 3 levels
	@warning_ignore("integer_division")
	return base_slots + (level - 1) / 3

## Get gods currently working in territory
func get_working_gods(territory_id: String) -> Array[String]:
	"""Get IDs of gods assigned to tasks in this territory"""
	var task_manager: Node = SystemRegistry.get_instance().get_system("TaskAssignmentManager") if SystemRegistry.get_instance() else null
	if task_manager:
		return task_manager.get_gods_working_in_territory(territory_id)
	return []

## Check if territory has available task slots
func has_available_task_slots(territory_id: String) -> bool:
	"""Check if more gods can be assigned to tasks in this territory"""
	if not is_territory_controlled(territory_id):
		return false
	var working_count: int = get_working_gods(territory_id).size()
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
	var task_manager: Node = SystemRegistry.get_instance().get_system("TaskAssignmentManager") if SystemRegistry.get_instance() else null
	if not task_manager:
		return []

	var level: int = get_territory_level(territory_id)
	var buildings: Array[String] = get_territory_buildings(territory_id)

	return task_manager.get_available_tasks_for_territory(level, buildings)

# ==============================================================================
# HEX TERRITORY SYSTEM INTEGRATION
# ==============================================================================

## Capture a hex node by coordinate
func capture_node(coord: HexCoord) -> bool:
	"""Capture a hex node at given coordinate - returns true on success"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		push_error("TerritoryManager: HexGridManager not found")
		return false

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		push_error("TerritoryManager: No node found at coordinate")
		return false

	# Check requirements
	var requirement_checker: Node = SystemRegistry.get_instance().get_system("NodeRequirementChecker") if SystemRegistry.get_instance() else null
	if requirement_checker and not requirement_checker.can_player_capture_node(node):
		push_warning("TerritoryManager: Cannot capture node - requirements not met")
		return false

	# Capture the node
	print("[TerritoryManager] BEFORE capture: node.id=%s, node.controller=%s" % [node.id, node.controller])
	node.controller = "player"
	node.is_revealed = true

	# Start the attack timer for this node (garrison defense mechanic)
	_start_attack_timer(node)

	print("[TerritoryManager] AFTER capture: node.id=%s, node.controller=%s" % [node.id, node.controller])

	# Add to controlled territories for backward compatibility
	if node.id not in controlled_territories:
		controlled_territories.append(node.id)

	# Reveal adjacent nodes (this is how T2+ nodes become accessible)
	_reveal_adjacent_nodes(node, hex_grid_manager)

	# Award early game capture rewards (crystals for first territories)
	_award_capture_rewards(node)

	territory_captured.emit(node.id)

	# Notify event bus
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("territory_captured", node.id)

	# IMMEDIATELY save game when capturing territory (don't rely on event bus)
	# This prevents progress loss if game is force-closed
	var save_manager: Node = SystemRegistry.get_instance().get_system("SaveManager") if SystemRegistry.get_instance() else null
	if save_manager:
		save_manager.save_game()
		print("TerritoryManager: Saved game after capturing node %s" % node.id)

	return true

## Lose control of a hex node
func lose_node(coord: HexCoord) -> bool:
	"""Player loses control of node at coordinate"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return false

	var node: HexNode = hex_grid_manager.get_node_at(coord)
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

	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("territory_lost", node.id)

	return true

## Get all controlled hex nodes
func get_controlled_nodes() -> Array:
	"""Get array of HexNode objects controlled by player"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return []

	return hex_grid_manager.get_player_nodes()

## Calculate defense rating for a node
func get_node_defense_rating(coord: HexCoord) -> float:
	"""Calculate total defense rating for node including distance penalty"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0.0

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		return 0.0

	# Base defense from garrison
	var base_defense: float = _calculate_garrison_power(node)

	# Apply defense level bonus (+10% per level)
	var defense_bonus: float = 1.0 + (node.defense_level - 1) * 0.1

	# Apply distance penalty
	var distance_penalty: float = calculate_distance_penalty(coord)

	# Apply connected node bonus
	var connected_bonus: float = get_connected_bonus(coord)

	return base_defense * defense_bonus * (1.0 - distance_penalty) * (1.0 + connected_bonus)

## Calculate distance penalty for a node
func calculate_distance_penalty(coord: HexCoord) -> float:
	"""Calculate defense penalty based on distance from base (5% per hex)"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0.0

	var distance: int = hex_grid_manager.get_distance_from_base(coord)
	return min(distance * 0.05, 0.95)  # Cap at 95% penalty

## Get connected node bonus for production/defense
func get_connected_bonus(coord: HexCoord) -> float:
	"""Calculate bonus from connected controlled nodes"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0.0

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node or not node.is_controlled_by_player():
		return 0.0

	# Count adjacent controlled nodes
	var connected_count: int = 0
	var neighbors: Array = hex_grid_manager.get_neighbors(coord)
	for neighbor_node: HexNode in neighbors:
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
func _calculate_garrison_power(node: HexNode) -> float:
	"""Calculate total combat power of gods in garrison"""
	if node.garrison.size() == 0:
		return 0.0

	var collection_manager: Node = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	if not collection_manager:
		return 0.0

	var total_power: float = 0.0
	for god_id: String in node.garrison:
		var god_obj: God = collection_manager.get_god_by_id(god_id)
		if god_obj:
			# Use same power calculation as NodeRequirementChecker
			var hp: int = god_obj.base_hp
			var attack: int = god_obj.base_attack
			var defense: int = god_obj.base_defense
			var speed: int = god_obj.base_speed
			var level: int = god_obj.level
			var awakening_bonus: float = 1.0 + (god_obj.ascension_level * 0.1)

			var god_power: float = (hp + attack * 2 + defense + speed) * (1.0 + level * 0.05) * awakening_bonus
			total_power += god_power

	return total_power

## Get minimum garrison power required for workers based on node tier
func get_min_garrison_power_for_tier(tier: int) -> int:
	"""Workers need garrison protection - higher tier nodes need more power"""
	# Base requirement scales with tier
	# Tier 1: 500 (starter gods can handle)
	# Tier 2: 2000 (need leveled/rare gods)
	# Tier 3: 5000 (need epic/legendary or strong team)
	# Tier 4: 15000 (endgame teams)
	# Tier 5: 40000 (maxed legendary teams)
	match tier:
		1: return 500
		2: return 2000
		3: return 5000
		4: return 15000
		5: return 40000
		_: return 500

## Check if a node's garrison meets the minimum power requirement for workers
func can_assign_workers(node: HexNode) -> bool:
	"""Check if node garrison meets minimum combat power for workers"""
	if not node:
		return false
	if not node.is_controlled_by_player():
		return false

	var garrison_power: float = _calculate_garrison_power(node)
	var required_power: int = get_min_garrison_power_for_tier(node.tier)
	return garrison_power >= required_power

## Get garrison power status for UI display
func get_garrison_worker_status(node: HexNode) -> Dictionary:
	"""Get garrison power and requirement info for worker assignment"""
	if not node:
		return {"can_assign": false, "current": 0, "required": 0, "reason": "Invalid node"}

	var garrison_power: int = int(_calculate_garrison_power(node))
	var required_power: int = get_min_garrison_power_for_tier(node.tier)
	var can_assign: bool = garrison_power >= required_power

	return {
		"can_assign": can_assign,
		"current": garrison_power,
		"required": required_power,
		"reason": "" if can_assign else "Garrison power too low (%d/%d)" % [garrison_power, required_power]
	}

## Get number of connected controlled nodes
func get_connected_node_count(coord: HexCoord) -> int:
	"""Get count of adjacent controlled nodes"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return 0

	var neighbors: Array = hex_grid_manager.get_neighbors(coord)
	var connected_count: int = 0
	for neighbor_node: HexNode in neighbors:
		if neighbor_node.is_controlled_by_player():
			connected_count += 1

	return connected_count

## Check if a hex node is controlled by player
func is_hex_node_controlled(coord: HexCoord) -> bool:
	"""Check if player controls node at coordinate"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return false

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		return false

	return node.is_controlled_by_player()

## Get hex node at coordinate
func get_hex_node(coord: HexCoord) -> HexNode:
	"""Get HexNode object at coordinate (convenience method)"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return null

	return hex_grid_manager.get_node_at(coord)

# ==============================================================================
# NODE GARRISON AND WORKER MANAGEMENT
# ==============================================================================

## Update garrison gods for a hex node by node ID
func update_node_garrison(node_id: String, garrison_ids: Array) -> bool:
	"""Update the garrison of a hex node"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		push_error("TerritoryManager: HexGridManager not found")
		return false

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		push_error("TerritoryManager: Node not found: " + node_id)
		return false

	if not node.is_controlled_by_player():
		push_error("TerritoryManager: Cannot modify garrison of uncontrolled node")
		return false

	# Update the garrison array
	node.garrison.clear()
	for god_id: Variant in garrison_ids:
		if god_id is String:
			node.garrison.append(god_id)

	print("TerritoryManager: Updated garrison for node %s: %s" % [node_id, node.garrison])

	# Trigger save after assigning garrison
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.save_requested.emit()

	return true

## Update worker gods for a hex node by node ID
func update_node_workers(node_id: String, worker_ids: Array) -> bool:
	"""Update the assigned workers of a hex node"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		push_error("TerritoryManager: HexGridManager not found")
		return false

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		push_error("TerritoryManager: Node not found: " + node_id)
		return false

	if not node.is_controlled_by_player():
		push_error("TerritoryManager: Cannot modify workers of uncontrolled node")
		return false

	# Check garrison power requirement before allowing workers
	if worker_ids.size() > 0 and not can_assign_workers(node):
		var status: Dictionary = get_garrison_worker_status(node)
		push_warning("TerritoryManager: Cannot assign workers - %s" % status.reason)
		return false

	# Update the assigned workers array
	node.assigned_workers.clear()
	for god_id: Variant in worker_ids:
		if god_id is String:
			node.assigned_workers.append(god_id)

	print("TerritoryManager: Updated workers for node %s: %s" % [node_id, node.assigned_workers])

	# Emit production_updated signal to refresh UI
	var production_manager: Node = SystemRegistry.get_instance().get_system("TerritoryProductionManager")
	if production_manager:
		var new_production_rate: Dictionary = production_manager.calculate_node_production(node)
		var total_rate: int = 0
		for resource_id: String in new_production_rate:
			total_rate += int(new_production_rate[resource_id])
		production_manager.production_updated.emit(node_id, total_rate)
		print("TerritoryManager: Emitted production_updated signal for node %s with rate %d" % [node_id, total_rate])

	# Trigger save after assigning workers
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.save_requested.emit()

	return true

## Upgrade production level of a hex node
func upgrade_hex_node(node_id: String) -> bool:
	"""Upgrade the production_level of a hex node"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		push_error("TerritoryManager: HexGridManager not found")
		return false

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		push_error("TerritoryManager: Node not found: " + node_id)
		return false

	if not node.is_controlled_by_player():
		push_error("TerritoryManager: Cannot upgrade uncontrolled node")
		return false

	# Check if already at max level
	var max_level: int = 5  # From CLAUDE.md
	if node.production_level >= max_level:
		print("TerritoryManager: Node %s already at max production level" % node_id)
		return false

	# Get upgrade cost
	var upgrade_cost: Dictionary = _get_hex_node_upgrade_cost(node.production_level + 1)
	var resource_manager: Node = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null

	if not resource_manager or not resource_manager.can_afford(upgrade_cost):
		print("TerritoryManager: Cannot afford upgrade cost for node %s" % node_id)
		return false

	# Spend resources and upgrade
	resource_manager.spend_resources(upgrade_cost)
	node.production_level += 1

	print("TerritoryManager: Upgraded node %s to production level %d" % [node_id, node.production_level])

	# Emit production_updated signal to refresh UI
	var production_manager: Node = SystemRegistry.get_instance().get_system("TerritoryProductionManager")
	if production_manager:
		var new_production_rate: Dictionary = production_manager.calculate_node_production(node)
		var total_rate: int = 0
		for resource_id: String in new_production_rate:
			total_rate += int(new_production_rate[resource_id])
		production_manager.production_updated.emit(node_id, total_rate)
		print("TerritoryManager: Emitted production_updated signal for node %s with new rate %d" % [node_id, total_rate])

	# Trigger save after upgrading node
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.save_requested.emit()

	return true

## Get hex node upgrade cost
func _get_hex_node_upgrade_cost(target_level: int) -> Dictionary:
	"""Calculate resource cost for upgrading to target production level"""
	var base_cost: int = 500
	var level_multiplier: float = pow(1.5, target_level - 1)

	return {
		"gold": int(base_cost * level_multiplier),
		"mana": int(base_cost * 0.5 * level_multiplier)
	}

# ==============================================================================
# DUNGEON COMPLETION INTEGRATION
# ==============================================================================

## Connect to DungeonCoordinator for dungeon completion events
func _connect_to_dungeon_coordinator() -> void:
	"""Connect to DungeonCoordinator to listen for dungeon completions"""
	# Use call_deferred to ensure systems are ready
	call_deferred("_deferred_connect_dungeon_coordinator")

func _deferred_connect_dungeon_coordinator() -> void:
	"""Deferred connection to DungeonCoordinator"""
	var system_registry: Node = SystemRegistry.get_instance()
	if not system_registry:
		return

	var dungeon_coordinator: Node = system_registry.get_system("DungeonCoordinator")
	if dungeon_coordinator and dungeon_coordinator.has_signal("dungeon_completed"):
		if not dungeon_coordinator.dungeon_completed.is_connected(_on_dungeon_completed):
			dungeon_coordinator.dungeon_completed.connect(_on_dungeon_completed)
			print("TerritoryManager: Connected to DungeonCoordinator.dungeon_completed signal")

## Handle dungeon completion event
func _on_dungeon_completed(dungeon_id: String, difficulty: String) -> void:
	"""Check if dungeon completion unlocks any hex nodes"""
	print("TerritoryManager: Received dungeon_completed for %s %s" % [dungeon_id, difficulty])

	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return

	# Check all nodes to see if any require this dungeon clear
	var all_nodes: Array = hex_grid_manager.get_all_nodes()
	for node: HexNode in all_nodes:
		if _check_node_dungeon_unlock(node, dungeon_id, difficulty):
			print("TerritoryManager: Dungeon clear %s %s unlocked node %s" % [dungeon_id, difficulty, node.id])
			node_unlocked.emit(node.id, "%s_%s" % [dungeon_id, difficulty])

## Check if a node's dungeon unlock requirements are satisfied by this clear
func _check_node_dungeon_unlock(node: HexNode, dungeon_id: String, difficulty: String) -> bool:
	"""Check if node has a dungeon_clears requirement that matches this completion"""
	if not node or not node.unlock_requirements:
		return false

	var dungeon_clears: Array = node.unlock_requirements.get("dungeon_clears", [])
	if dungeon_clears.is_empty():
		return false

	for requirement: Variant in dungeon_clears:
		var req_dungeon: String = requirement.get("dungeon_id", "")
		var req_difficulty: String = requirement.get("difficulty", "")

		if req_dungeon == dungeon_id and req_difficulty == difficulty:
			return true

	return false

## Check if a node is unlocked based on dungeon completion progress
func is_node_unlocked_by_dungeons(node_id: String) -> bool:
	"""Check if all dungeon requirements are met for a node"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return true  # Default to unlocked if can't check

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		return true

	var dungeon_clears: Array = node.unlock_requirements.get("dungeon_clears", [])
	if dungeon_clears.is_empty():
		return true  # No dungeon requirements

	var dungeon_manager: Node = SystemRegistry.get_instance().get_system("DungeonManager") if SystemRegistry.get_instance() else null
	if not dungeon_manager:
		return false  # Can't verify

	# Check all dungeon requirements
	for requirement: Variant in dungeon_clears:
		var req_dungeon: String = requirement.get("dungeon_id", "")
		var req_difficulty: String = requirement.get("difficulty", "")

		if not dungeon_manager.is_first_clear(req_dungeon, req_difficulty):
			# is_first_clear returns false if the dungeon HAS been cleared
			# So NOT is_first_clear means it has been cleared
			continue
		else:
			# Still first clear available = not yet completed
			return false

	return true

## Get list of nodes that would be unlocked by completing a specific dungeon
func get_nodes_unlockable_by_dungeon(dungeon_id: String, difficulty: String) -> Array:
	"""Get all nodes that have this dungeon as an unlock requirement"""
	var unlockable_nodes: Array = []

	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return unlockable_nodes

	var all_nodes: Array = hex_grid_manager.get_all_nodes()
	for node: HexNode in all_nodes:
		if _check_node_dungeon_unlock(node, dungeon_id, difficulty):
			unlockable_nodes.append(node)

	return unlockable_nodes

# ==============================================================================
# CAPTURE REWARDS
# ==============================================================================

## Award crystal rewards for capturing territories (helps early game progression)
## Economy: 100 crystals = 1 summon, 900 crystals = 10x multi-summon
func _award_capture_rewards(node: HexNode) -> void:
	"""Give players crystals for capturing territories, especially early ones"""
	var resource_manager: Node = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_manager:
		return

	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	var territories_owned: int = controlled_territories.size()

	# Early game bonus: First 10 territories give bonus crystals
	# Goal: ~1000 crystals from first 10 territories (enough for one 10x multi-summon)
	var early_game_bonus: int = 0
	if territories_owned == 1:
		early_game_bonus = 300  # First territory: Big welcome bonus (3 summons worth)
	elif territories_owned <= 3:
		early_game_bonus = 200  # Territories 2-3: 2 summons each
	elif territories_owned <= 6:
		early_game_bonus = 100  # Territories 4-6: 1 summon each
	elif territories_owned <= 10:
		early_game_bonus = 50   # Territories 7-10: Half summon each

	# Tier-based rewards (higher tier nodes = more crystals)
	var tier_reward: int = 0
	if node and node.tier:
		match node.tier:
			1: tier_reward = 10   # Tier 1: 0.1 summons
			2: tier_reward = 25   # Tier 2: 0.25 summons
			3: tier_reward = 50   # Tier 3: 0.5 summons
			4: tier_reward = 100  # Tier 4: 1 summon
			5: tier_reward = 200  # Tier 5: 2 summons
			_: tier_reward = 10

	var total_crystals: int = early_game_bonus + tier_reward

	if total_crystals > 0:
		resource_manager.add_resource("divine_crystals", total_crystals)
		print("TerritoryManager: Awarded %d divine crystals for capturing %s (early bonus: %d, tier bonus: %d)" % [
			total_crystals, node.name if node else "territory", early_game_bonus, tier_reward
		])

		# Show notification to player
		if event_bus:
			var msg: String = "+%d Divine Crystals" % total_crystals
			if early_game_bonus > 0:
				msg += " (Early Capture Bonus!)"
			event_bus.emit_notification(msg, "reward", 2.5)

## Reveal adjacent nodes when a node is captured
## This is how T2+ nodes become visible - you need to capture adjacent T1 nodes first
func _reveal_adjacent_nodes(captured_node: HexNode, hex_grid_manager: Node) -> void:
	"""Reveal all adjacent nodes to a newly captured node."""
	if not hex_grid_manager or not captured_node:
		return

	var neighbors: Array = hex_grid_manager.get_neighbors(captured_node.coord)
	var newly_revealed: int = 0

	for neighbor: HexNode in neighbors:
		if neighbor and not neighbor.is_revealed:
			neighbor.is_revealed = true
			newly_revealed += 1
			print("TerritoryManager: Revealed adjacent node '%s' (tier %d)" % [neighbor.name, neighbor.tier])

	if newly_revealed > 0:
		# Notify that grid has updated (for UI refresh)
		hex_grid_manager.grid_updated.emit()
		print("TerritoryManager: Revealed %d new adjacent nodes from capturing '%s'" % [newly_revealed, captured_node.name])

# ==============================================================================
# ATTACK TIMER SYSTEM
# ==============================================================================

## Start the attack timer for a newly captured node
func _start_attack_timer(node: HexNode) -> void:
	"""Initialize the attack timer when a node is captured.
	The timer counts down and when it reaches 0, a defense battle is triggered.
	"""
	if not node or not node.is_capturable:
		return

	# Only start timer for capturable nodes (not base)
	if node.attack_timer_hours <= 0:
		node.attack_timer_remaining = -1.0  # No timer for this node
		return

	# Set timer to full duration (hours -> seconds)
	var max_seconds: float = node.attack_timer_hours * 3600.0
	node.attack_timer_remaining = max_seconds
	node.last_attack_check_time = int(Time.get_unix_time_from_system())

	print("TerritoryManager: Started attack timer for node '%s' - %.1f hours (%.0f seconds)" % [
		node.name if node.name else node.id,
		node.attack_timer_hours,
		max_seconds
	])

## Update attack timers for all player-controlled nodes
## Called periodically (e.g., every 60 seconds from TerritoryProductionManager)
func update_attack_timers() -> void:
	"""Decrement attack timers and check for expired timers (defense battles)"""
	var current_time: int = int(Time.get_unix_time_from_system())

	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return

	var player_nodes: Array = hex_grid_manager.get_player_nodes()
	var nodes_under_attack: Array = []

	for node: HexNode in player_nodes:
		if not node or not node.is_capturable:
			continue

		# Skip nodes without active timers
		if node.attack_timer_remaining < 0:
			continue

		# Calculate time elapsed since last check
		var time_elapsed: int = current_time - node.last_attack_check_time
		if time_elapsed <= 0:
			continue

		# Decrement the timer
		node.attack_timer_remaining -= time_elapsed
		node.last_attack_check_time = current_time

		# Check if timer has expired
		if node.attack_timer_remaining <= 0:
			node.attack_timer_remaining = 0.0  # Clamp at 0
			nodes_under_attack.append(node)
			print("TerritoryManager: ⚔️ Attack timer EXPIRED for node '%s' - Defense battle needed!" % [
				node.name if node.name else node.id
			])

	# Handle expired timers (defense battles)
	for node: HexNode in nodes_under_attack:
		_handle_node_attack(node)

## Handle a node being attacked (timer expired)
func _handle_node_attack(node: HexNode) -> void:
	"""Process an attack on a node when its timer expires.
	If garrison is empty, node is lost. Otherwise, defense battle can be fought.
	"""
	if not node:
		return

	# Check garrison status
	if node.garrison.size() == 0:
		# No garrison = automatic loss
		print("TerritoryManager: ❌ Node '%s' LOST - no garrison to defend!" % [node.name if node.name else node.id])

		# Emit event for UI notification
		var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
		if event_bus:
			event_bus.emit_notification("Territory Lost: %s (No garrison!)" % [node.name if node.name else "Unknown"], "warning", 4.0)

		# Lose the node
		lose_node(node.coord)
	else:
		# Has garrison - defense battle available
		# The actual battle will be initiated by UI when player clicks on the node
		print("TerritoryManager: ⚔️ Node '%s' is under attack! Garrison defense available." % [node.name if node.name else node.id])

		# Emit event for UI notification
		var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
		if event_bus:
			event_bus.emit_notification("⚔️ Territory Under Attack: %s" % [node.name if node.name else "Unknown"], "danger", 5.0)

## Reset attack timer after successful defense
func reset_attack_timer(node_id: String) -> void:
	"""Reset a node's attack timer after a successful defense battle"""
	var hex_grid_manager: Node = SystemRegistry.get_instance().get_system("HexGridManager") if SystemRegistry.get_instance() else null
	if not hex_grid_manager:
		return

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		return

	_start_attack_timer(node)
	print("TerritoryManager: Reset attack timer for node '%s' after successful defense" % [node.name if node.name else node_id])
