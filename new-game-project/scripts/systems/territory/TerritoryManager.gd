# scripts/systems/territory/TerritoryManager.gd
# Territory control system - manages territory ownership and operations
# Defense/garrison/attack logic delegated to TerritoryDefenseManager
class_name TerritoryManager extends Node

signal territory_captured(territory_id: String)
signal territory_lost(territory_id: String)
signal node_unlocked(node_id: String, unlock_source: String)

const TerritoryDefenseManagerScript := preload("res://scripts/systems/territory/TerritoryDefenseManager.gd")

var controlled_territories: Array[String] = []
var territory_data: Dictionary = {}

var _defense_manager: Node = null

func _ready() -> void:
	_defense_manager = TerritoryDefenseManagerScript.new()
	add_child(_defense_manager)
	_defense_manager.initialize(self)
	# Forward node_unlocked signal from defense manager
	_defense_manager.node_unlocked.connect(func(node_id: String, source: String) -> void: node_unlocked.emit(node_id, source))
	_load_territory_configuration()

## Load territory configuration
func _load_territory_configuration() -> void:
	var config_manager: Node = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if config_manager:
		territory_data = config_manager.get_territories_config()

## Check if territory is controlled
func is_territory_controlled(territory_id: String) -> bool:
	return territory_id in controlled_territories

## Get territory information
func get_territory_info(territory_id: String) -> Dictionary:
	return territory_data.get(territory_id, {})

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
	for territory_id: String in saved_territory_data:
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
			territories_list = territories_config.territories.values()
	else:
		territories_list = territories_config.values()

	# Convert config data to Territory dictionaries for UI
	for territory_config_data: Variant in territories_list:
		var territory_id: String = territory_config_data.get("id", "unknown")
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
	var territory_info: Dictionary = get_territory_info(territory_id)
	var buildings: Array[String] = []
	var building_list: Array = territory_info.get("buildings", [])
	for b: Variant in building_list:
		buildings.append(str(b))
	return buildings

## Get territory level (for task requirements)
func get_territory_level(territory_id: String) -> int:
	var territory_info: Dictionary = get_territory_info(territory_id)
	return territory_info.get("level", 1)

## Get max task worker slots for territory
func get_max_task_slots(territory_id: String) -> int:
	var territory_info: Dictionary = get_territory_info(territory_id)
	var base_slots: int = territory_info.get("max_task_slots", 3)
	var level: int = get_territory_level(territory_id)
	@warning_ignore("integer_division")
	return base_slots + (level - 1) / 3

## Get gods currently working in territory
func get_working_gods(territory_id: String) -> Array[String]:
	var task_manager: Node = SystemRegistry.get_instance().get_system("TaskAssignmentManager") if SystemRegistry.get_instance() else null
	if task_manager:
		return task_manager.get_gods_working_in_territory(territory_id)
	return []

## Get available tasks for a territory based on level and buildings
func get_available_tasks(territory_id: String) -> Array:
	var task_manager: Node = SystemRegistry.get_instance().get_system("TaskAssignmentManager") if SystemRegistry.get_instance() else null
	if not task_manager:
		return []

	var level: int = get_territory_level(territory_id)
	var buildings: Array[String] = get_territory_buildings(territory_id)

	return task_manager.get_available_tasks_for_territory(level, buildings)

# ==============================================================================
# HEX TERRITORY SYSTEM - Capture / Lose
# ==============================================================================

## Capture a hex node by coordinate
func capture_node(coord: HexCoord) -> bool:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		push_error("TerritoryManager: HexGridManager not found")
		return false

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		push_error("TerritoryManager: No node found at coordinate")
		return false

	# Check requirements
	var registry: Node = SystemRegistry.get_instance()
	var requirement_checker: Node = registry.get_system("NodeRequirementChecker") if registry else null
	if requirement_checker and not requirement_checker.can_player_capture_node(node):
		push_warning("TerritoryManager: Cannot capture node - requirements not met")
		return false

	# Capture the node
	node.controller = "player"
	node.is_revealed = true

	# Initialize production time to now (prevents exploit from unset timestamps)
	node.last_production_time = int(Time.get_unix_time_from_system())

	# Delegate defense operations to defense manager
	_defense_manager.start_attack_timer(node)

	# Add to controlled territories
	if node.id not in controlled_territories:
		controlled_territories.append(node.id)

	# Reveal adjacent nodes and award capture rewards
	_defense_manager.reveal_adjacent_nodes(node)
	_defense_manager.award_capture_rewards(node, controlled_territories.size())

	territory_captured.emit(node.id)

	# Notify event bus
	var event_bus: Node = _get_event_bus()
	if event_bus:
		event_bus.emit_signal("territory_captured", node.id)

	# Save immediately to prevent progress loss on force-close
	var save_manager: Node = registry.get_system("SaveManager") if registry else null
	if save_manager:
		save_manager.save_game()

	return true

## Lose control of a hex node
func lose_node(coord: HexCoord, reason: String = "unknown") -> bool:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return false

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		return false

	if not node.is_controlled_by_player():
		return false

	var node_name: String = node.name if node.name else "Unknown"

	node.controller = "neutral"
	node.garrison.clear()
	node.assigned_workers.clear()
	node.active_tasks.clear()

	controlled_territories.erase(node.id)

	territory_lost.emit(node.id)

	var event_bus: Node = _get_event_bus()
	if event_bus:
		event_bus.emit_signal("territory_lost", node.id, node_name, reason)

	return true

## Get all controlled hex nodes
func get_controlled_nodes() -> Array:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return []
	return hex_grid_manager.get_player_nodes()

## Check if a hex node is controlled by player
func is_hex_node_controlled(coord: HexCoord) -> bool:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return false

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		return false

	return node.is_controlled_by_player()

## Get hex node at coordinate (convenience method)
func get_hex_node(coord: HexCoord) -> HexNode:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return null
	return hex_grid_manager.get_node_at(coord)

# ==============================================================================
# DEFENSE DELEGATION - Forward to TerritoryDefenseManager
# ==============================================================================

func get_node_defense_rating(coord: HexCoord) -> float:
	return _defense_manager.get_node_defense_rating(coord)

func calculate_distance_penalty(coord: HexCoord) -> float:
	return _defense_manager.calculate_distance_penalty(coord)

func get_connected_bonus(coord: HexCoord) -> float:
	return _defense_manager.get_connected_bonus(coord)

func get_connected_node_count(coord: HexCoord) -> int:
	return _defense_manager.get_connected_node_count(coord)

func get_min_garrison_power_for_tier(tier: int) -> int:
	return _defense_manager.get_min_garrison_power_for_tier(tier)

func can_assign_workers(node: HexNode) -> bool:
	return _defense_manager.can_assign_workers(node)

func get_garrison_worker_status(node: HexNode) -> Dictionary:
	return _defense_manager.get_garrison_worker_status(node)

func update_attack_timers() -> void:
	_defense_manager.update_attack_timers()

func reset_attack_timer(node_id: String) -> void:
	_defense_manager.reset_attack_timer(node_id)

# ==============================================================================
# NODE GARRISON AND WORKER MANAGEMENT
# ==============================================================================

## Update garrison gods for a hex node by node ID
func update_node_garrison(node_id: String, garrison_ids: Array) -> bool:
	var hex_grid_manager: Node = _get_hex_grid_manager()
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

	node.garrison.clear()
	for god_id: Variant in garrison_ids:
		if god_id is String:
			node.garrison.append(god_id)

	var event_bus: Node = _get_event_bus()
	if event_bus:
		event_bus.save_requested.emit()
		var total_power: int = int(_defense_manager.calculate_garrison_power(node))
		event_bus.garrison_updated.emit({
			"node_id": node_id,
			"node_tier": node.tier,
			"god_ids": node.garrison.duplicate(),
			"total_power": total_power
		})

	return true

## Update worker gods for a hex node by node ID
func update_node_workers(node_id: String, worker_ids: Array) -> bool:
	var hex_grid_manager: Node = _get_hex_grid_manager()
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

	if worker_ids.size() > 0 and not can_assign_workers(node):
		var status: Dictionary = get_garrison_worker_status(node)
		push_warning("TerritoryManager: Cannot assign workers - %s" % status.reason)
		return false

	node.assigned_workers.clear()
	for god_id: Variant in worker_ids:
		if god_id is String:
			node.assigned_workers.append(god_id)

	# Emit production_updated signal to refresh UI
	var registry: Node = SystemRegistry.get_instance()
	var production_manager: Node = registry.get_system("TerritoryProductionManager") if registry else null
	if production_manager:
		var new_production_rate: Dictionary = production_manager.calculate_node_production(node)
		var total_rate: int = 0
		for resource_id: String in new_production_rate:
			total_rate += int(new_production_rate[resource_id])
		production_manager.production_updated.emit(node_id, total_rate)

	var event_bus: Node = _get_event_bus()
	if event_bus:
		event_bus.save_requested.emit()
		event_bus.workers_updated.emit({
			"node_id": node_id,
			"node_tier": node.tier,
			"god_ids": node.assigned_workers.duplicate(),
			"task_ids": node.active_tasks.duplicate() if "active_tasks" in node else []
		})

	return true

## Upgrade production level of a hex node
func upgrade_hex_node(node_id: String) -> bool:
	var hex_grid_manager: Node = _get_hex_grid_manager()
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

	var max_level: int = 5
	if node.production_level >= max_level:
		return false

	var upgrade_cost: Dictionary = _get_hex_node_upgrade_cost(node.production_level + 1)
	var registry: Node = SystemRegistry.get_instance()
	var resource_manager: Node = registry.get_system("ResourceManager") if registry else null

	if not resource_manager or not resource_manager.can_afford(upgrade_cost):
		return false

	resource_manager.spend_resources(upgrade_cost)
	node.production_level += 1

	var production_manager: Node = registry.get_system("TerritoryProductionManager") if registry else null
	if production_manager:
		var new_production_rate: Dictionary = production_manager.calculate_node_production(node)
		var total_rate: int = 0
		for resource_id: String in new_production_rate:
			total_rate += int(new_production_rate[resource_id])
		production_manager.production_updated.emit(node_id, total_rate)

	var event_bus: Node = _get_event_bus()
	if event_bus:
		event_bus.save_requested.emit()

	return true

## Calculate resource cost for upgrading to target production level
func _get_hex_node_upgrade_cost(target_level: int) -> Dictionary:
	var base_cost: int = 500
	var level_multiplier: float = pow(1.5, target_level - 1)

	return {
		"gold": int(base_cost * level_multiplier),
		"mana": int(base_cost * 0.5 * level_multiplier)
	}

# ==============================================================================
# HELPERS
# ==============================================================================

func _get_hex_grid_manager() -> Node:
	var registry: Node = SystemRegistry.get_instance()
	return registry.get_system("HexGridManager") if registry else null

func _get_event_bus() -> Node:
	var registry: Node = SystemRegistry.get_instance()
	return registry.get_system("EventBus") if registry else null
