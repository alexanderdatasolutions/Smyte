# scripts/systems/territory/HexCraftManager.gd
# Manages craft tracking for hex territory nodes
extends Node

"""
HexCraftManager - Craft tracking for territory nodes
RULE 2: Single responsibility - Craft lifecycle only
Extracted from HexGridManager to keep files under 500 lines.
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal craft_completed(node_id: String, task_id: String, task_data: Dictionary)
signal craft_auto_restarted(node_id: String, task_id: String)

# ==============================================================================
# STATE
# ==============================================================================

# Active crafts shared across all UI - {"node_id:task_id": {"node_id", "task_id", "start_time", "end_time", "task_data"}}
var _active_crafts: Dictionary = {}

# Auto-repeat settings - {"node_id:task_id": true} for tasks that should auto-repeat
var _auto_repeat_crafts: Dictionary = {}

# Reference to HexGridManager for node lookups
var _grid_manager: Node = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func initialize(grid_manager: Node) -> void:
	"""Initialize with reference to parent grid manager"""
	_grid_manager = grid_manager

func _process(_delta: float) -> void:
	"""Check for completed auto-repeat crafts"""
	_check_auto_repeat_crafts()

# ==============================================================================
# CRAFT LIFECYCLE
# ==============================================================================

func start_craft(node_id: String, task_id: String, task_data: Dictionary, auto_repeat: bool = false) -> bool:
	"""Start tracking a craft - called by UI when player starts crafting.
	Returns true if craft was started, false if node is at craft limit."""
	var node: HexNode = _grid_manager.get_node_by_id(node_id)
	if not node:
		push_error("HexCraftManager: Cannot start craft - node '%s' not found" % node_id)
		return false

	# Check craft limit for this node
	var current_crafts: Array = get_active_crafts_for_node(node_id)
	var max_crafts: int = _get_max_crafts_for_node(node)
	if current_crafts.size() >= max_crafts:
		push_warning("HexCraftManager: Node '%s' already at craft limit (%d/%d)" % [node_id, current_crafts.size(), max_crafts])
		return false

	# Check if node has an assigned worker (required for crafting)
	if node.assigned_workers.is_empty():
		push_warning("HexCraftManager: Cannot start craft - node '%s' has no assigned workers" % node_id)
		return false

	var duration_seconds: int = task_data.get("base_duration_seconds", 60)
	var current_time: int = int(Time.get_unix_time_from_system())
	var craft_key: String = "%s:%s" % [node_id, task_id]

	_active_crafts[craft_key] = {
		"task_id": task_id,
		"node_id": node_id,
		"start_time": current_time,
		"end_time": current_time + duration_seconds,
		"task_data": task_data,
		"auto_repeat": auto_repeat
	}

	# Track auto-repeat setting
	if auto_repeat:
		_auto_repeat_crafts[craft_key] = true
	elif _auto_repeat_crafts.has(craft_key):
		_auto_repeat_crafts.erase(craft_key)

	# Also add to node's active_tasks
	if not node.active_tasks.has(task_id):
		node.active_tasks.append(task_id)

	return true

func complete_craft(node_id: String, task_id: String) -> Dictionary:
	"""Complete a craft and return its data, or empty dict if not found"""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	if not _active_crafts.has(craft_key):
		return {}

	var craft_data: Dictionary = _active_crafts[craft_key]
	_active_crafts.erase(craft_key)

	# Remove from node's active_tasks
	var node: HexNode = _grid_manager.get_node_by_id(node_id)
	if node and node.active_tasks.has(task_id):
		node.active_tasks.erase(task_id)

	# Check if this is an equipment craft and create the equipment
	var task_data: Dictionary = craft_data.get("task_data", {})
	if task_data.has("equipment_type"):
		_create_equipment_from_craft(task_data, task_id)
	else:
		# Regular resource craft - award resources
		_award_craft_rewards(task_data)

	# Emit completion signal
	craft_completed.emit(node_id, task_id, task_data)

	return craft_data

func cancel_craft(node_id: String, task_id: String) -> bool:
	"""Cancel a specific craft. Returns true if craft was cancelled."""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	if not _active_crafts.has(craft_key):
		return false

	_active_crafts.erase(craft_key)
	_auto_repeat_crafts.erase(craft_key)

	# Remove from node's active_tasks
	var node: HexNode = _grid_manager.get_node_by_id(node_id)
	if node and node.active_tasks.has(task_id):
		node.active_tasks.erase(task_id)

	return true

func cancel_all_crafts_for_node(node_id: String) -> int:
	"""Cancel all crafts for a node. Returns number of crafts cancelled."""
	var cancelled: int = 0
	var crafts_to_cancel: Array = []

	# Find all crafts for this node
	for craft_key: String in _active_crafts.keys():
		var craft_data: Dictionary = _active_crafts[craft_key]
		if craft_data.get("node_id", "") == node_id:
			crafts_to_cancel.append(craft_data.get("task_id", ""))

	# Cancel them
	for task_id: String in crafts_to_cancel:
		if cancel_craft(node_id, task_id):
			cancelled += 1

	return cancelled

# ==============================================================================
# QUERIES
# ==============================================================================

func get_active_crafts() -> Dictionary:
	"""Get all active crafts"""
	return _active_crafts

func get_active_crafts_for_node(node_id: String) -> Array:
	"""Get active crafts for a specific node"""
	var result: Array = []
	for craft_key: String in _active_crafts.keys():
		var craft_data: Dictionary = _active_crafts[craft_key]
		if craft_data.get("node_id", "") == node_id:
			result.append(craft_data)
	return result

func set_auto_repeat(node_id: String, task_id: String, enabled: bool) -> void:
	"""Enable or disable auto-repeat for a craft"""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	if enabled:
		_auto_repeat_crafts[craft_key] = true
		# Also update the active craft data if it exists
		if _active_crafts.has(craft_key):
			_active_crafts[craft_key]["auto_repeat"] = true
	else:
		_auto_repeat_crafts.erase(craft_key)
		if _active_crafts.has(craft_key):
			_active_crafts[craft_key]["auto_repeat"] = false

func is_auto_repeat_enabled(node_id: String, task_id: String) -> bool:
	"""Check if auto-repeat is enabled for a craft"""
	var craft_key: String = "%s:%s" % [node_id, task_id]
	return _auto_repeat_crafts.has(craft_key)

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get craft state for saving"""
	return {
		"active_crafts": _active_crafts.duplicate(true),
		"auto_repeat_crafts": _auto_repeat_crafts.duplicate()
	}

func load_save_data(save_data: Dictionary) -> void:
	"""Load craft state from save data"""
	if save_data.has("active_crafts"):
		_active_crafts = save_data.active_crafts.duplicate(true)
	if save_data.has("auto_repeat_crafts"):
		_auto_repeat_crafts = save_data.auto_repeat_crafts.duplicate()

# ==============================================================================
# AUTO-REPEAT PROCESSING
# ==============================================================================

func _check_auto_repeat_crafts() -> void:
	"""Check for completed auto-repeat crafts and restart them"""
	var current_time: int = int(Time.get_unix_time_from_system())
	var crafts_to_restart: Array = []
	var crafts_to_cancel: Array = []

	for craft_key: String in _active_crafts.keys():
		var craft_data: Dictionary = _active_crafts[craft_key]
		var end_time: int = craft_data.get("end_time", current_time)
		var node_id: String = craft_data.get("node_id", "")

		# Check if node still has workers assigned
		var node: HexNode = _grid_manager.get_node_by_id(node_id)
		if not node or node.assigned_workers.is_empty():
			# No workers = cancel craft
			crafts_to_cancel.append(craft_data)
			continue

		# Check if craft is complete
		if current_time >= end_time:
			var is_auto_repeat: bool = craft_data.get("auto_repeat", false) or _auto_repeat_crafts.has(craft_key)
			if is_auto_repeat:
				crafts_to_restart.append(craft_data)

	# Cancel crafts with no workers
	for craft_data: Dictionary in crafts_to_cancel:
		var node_id: String = craft_data.get("node_id", "")
		var task_id: String = craft_data.get("task_id", "")
		cancel_craft(node_id, task_id)

	# Process auto-restarts
	for craft_data: Dictionary in crafts_to_restart:
		var node_id: String = craft_data.get("node_id", "")
		var task_id: String = craft_data.get("task_id", "")
		var task_data: Dictionary = craft_data.get("task_data", {})

		# Double-check node still has workers (might have been cancelled above)
		var node: HexNode = _grid_manager.get_node_by_id(node_id)
		if not node or node.assigned_workers.is_empty():
			var cancel_key: String = "%s:%s" % [node_id, task_id]
			_auto_repeat_crafts.erase(cancel_key)
			continue

		# Check if we can afford the cost
		if _can_afford_craft_cost(task_data):
			# Spend the resources
			_spend_craft_cost(task_data)

			# Award the rewards
			_award_craft_rewards(task_data)

			# Restart the craft
			var duration_seconds: int = task_data.get("base_duration_seconds", 60)
			var craft_key: String = "%s:%s" % [node_id, task_id]

			_active_crafts[craft_key] = {
				"task_id": task_id,
				"node_id": node_id,
				"start_time": current_time,
				"end_time": current_time + duration_seconds,
				"task_data": task_data,
				"auto_repeat": true
			}

			craft_auto_restarted.emit(node_id, task_id)
		else:
			# Can't afford, disable auto-repeat
			var disable_key: String = "%s:%s" % [node_id, task_id]
			_auto_repeat_crafts.erase(disable_key)

# ==============================================================================
# RESOURCE HELPERS
# ==============================================================================

func _get_max_crafts_for_node(_node: HexNode) -> int:
	"""Get maximum concurrent crafts allowed for a node based on tier"""
	return 1

func _can_afford_craft_cost(task_data: Dictionary) -> bool:
	"""Check if player can afford the craft costs (including accumulated node resources)"""
	var costs: Dictionary = task_data.get("materials", task_data.get("resource_costs", {}))
	if costs.is_empty():
		return true

	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		return true

	# First check if we can afford directly from inventory
	if resource_manager.can_afford(costs):
		return true

	# If not, check if accumulated resources on nodes can cover the deficit
	var total_available: Dictionary = _get_total_available_resources(resource_manager, costs)
	for resource_id: String in costs:
		var needed: int = costs[resource_id]
		var available: int = total_available.get(resource_id, 0)
		if available < needed:
			return false

	return true

func _get_total_available_resources(resource_manager: Node, costs: Dictionary) -> Dictionary:
	"""Get total resources available (inventory + accumulated on all player nodes)"""
	var total: Dictionary = {}

	# Add inventory resources
	for resource_id: String in costs:
		total[resource_id] = resource_manager.get_resource(resource_id) if resource_manager else 0

	# Add accumulated resources from all player-controlled nodes
	for node: HexNode in _grid_manager.get_player_nodes():
		for resource_id: String in node.accumulated_resources:
			if costs.has(resource_id):
				var amount: int = node.accumulated_resources.get(resource_id, 0)
				total[resource_id] = total.get(resource_id, 0) + amount

	return total

func _spend_craft_cost(task_data: Dictionary) -> void:
	"""Spend the resources for a craft, using accumulated resources if needed"""
	var costs: Dictionary = task_data.get("materials", task_data.get("resource_costs", {}))
	if costs.is_empty():
		return

	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		return

	for resource_id: String in costs:
		var needed: int = costs[resource_id]
		var in_inventory: int = resource_manager.get_resource(resource_id)

		if in_inventory >= needed:
			resource_manager.spend(resource_id, needed)
		else:
			var deficit: int = needed - in_inventory
			_auto_collect_resource_from_nodes(resource_id, deficit, resource_manager)
			resource_manager.spend(resource_id, needed)

func _auto_collect_resource_from_nodes(resource_id: String, amount_needed: float, resource_manager: Node) -> float:
	"""Auto-collect a specific resource from player nodes to cover craft costs"""
	var collected: float = 0.0

	for node: HexNode in _grid_manager.get_player_nodes():
		if collected >= amount_needed:
			break

		var available: float = node.accumulated_resources.get(resource_id, 0)
		if available > 0:
			var to_collect: float = minf(available, amount_needed - collected)

			node.accumulated_resources[resource_id] = available - to_collect

			if resource_manager:
				resource_manager.add_resource(resource_id, to_collect)

			collected += to_collect

	return collected

func _award_craft_rewards(task_data: Dictionary) -> void:
	"""Award the rewards from a completed auto-repeat craft"""
	var resource_manager: Node = _get_resource_manager()
	if not resource_manager:
		push_error("HexCraftManager: Cannot award craft rewards - no ResourceManager")
		return

	var resources: Dictionary = task_data.get("output", task_data.get("resource_rewards", {}))
	if resources.is_empty():
		push_warning("HexCraftManager: No output resources found in task_data: %s" % task_data.keys())
		return

	for resource_id: String in resources.keys():
		var amount: int = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

func _get_resource_manager() -> Node:
	"""Get ResourceManager via SystemRegistry"""
	var registry_script: GDScript = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		var registry: Node = registry_script.get_instance()
		if registry:
			return registry.get_system("ResourceManager")
	return null

func _create_equipment_from_craft(task_data: Dictionary, recipe_id: String) -> void:
	"""Create equipment from a completed forge craft and add to inventory"""
	var equipment_type: String = task_data.get("equipment_type", "")
	var rarity: String = task_data.get("rarity", "common")
	var level: int = task_data.get("level", 1)

	if equipment_type.is_empty():
		push_error("HexCraftManager: Cannot create equipment - missing equipment_type")
		return

	# Create the equipment using Equipment.create_from_dungeon
	var equipment = Equipment.create_from_dungeon("crafted_" + recipe_id, equipment_type, rarity, level)
	if equipment == null:
		push_error("HexCraftManager: Failed to create equipment for type: %s" % equipment_type)
		return

	# Apply recipe-specific guaranteed substats
	var guaranteed_substats: Array = task_data.get("guaranteed_substats", [])
	for substat_data in guaranteed_substats:
		if substat_data is Dictionary:
			equipment.add_substat(substat_data.get("stat", ""), substat_data.get("value", 0))

	# Apply recipe-specific base stats as bonuses
	var base_stats: Dictionary = task_data.get("base_stats", {})
	for stat_name: String in base_stats:
		equipment.add_stat_bonus(stat_name, base_stats[stat_name])

	# Set equipment set info from recipe
	if task_data.has("equipment_set"):
		equipment.equipment_set_type = task_data.get("equipment_set", "")
		equipment.equipment_set_name = task_data.get("equipment_set", "").capitalize()

	print("[HexCraftManager] Created equipment: %s (id: %s, type: %s, rarity: %s)" % [
		equipment.name, equipment.id, equipment_type, rarity
	])

	# Add to inventory via SystemRegistry
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("HexCraftManager: SystemRegistry not available - equipment created but not added to inventory!")
		return

	var equipment_manager = registry.get_system("EquipmentManager")
	if equipment_manager:
		equipment_manager.add_equipment_to_inventory(equipment)
		print("[HexCraftManager] Added equipment to EquipmentManager")
	else:
		push_error("HexCraftManager: Could not find EquipmentManager")

	var collection_manager = registry.get_system("CollectionManager")
	if collection_manager:
		var added: bool = collection_manager.add_equipment(equipment)
		print("[HexCraftManager] Added equipment to CollectionManager (success: %s)" % str(added))
	else:
		push_error("HexCraftManager: Could not find CollectionManager")

	# Trigger save
	var event_bus = registry.get_system("EventBus")
	if event_bus:
		event_bus.save_requested.emit()
		print("[HexCraftManager] Triggered save after equipment craft")
