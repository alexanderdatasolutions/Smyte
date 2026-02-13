class_name TerritoryProductionManager
extends Node

"""
TerritoryProductionManager.gd - Hex node resource generation system
RULE 5: Uses SystemRegistry for all system access
RULE 2: Single responsibility - ONLY manages resource generation from hex nodes
RULE 4: No UI creation - emits events for UI updates
"""

signal resources_generated(territory_id: String, resources: Dictionary)
signal production_updated(territory_id: String, new_rate: int)

func initialize():
	"""Initialize production system - called by SystemRegistry"""
	_start_generation_cycle()

func _start_generation_cycle():
	"""Start automatic resource generation cycle"""
	# Generate resources every minute
	var timer = Timer.new()
	timer.wait_time = 60.0  # 1 minute
	timer.timeout.connect(_process_all_territory_generation)
	timer.autostart = true
	add_child(timer)

func _process_all_territory_generation():
	"""Process resource generation for all hex nodes - RULE 5: SystemRegistry"""
	_process_hex_node_generation()

func calculate_node_production(node: HexNode) -> Dictionary:
	"""Calculate total resource production for a hex node
	Production formula: base * (1 + upgrade_bonus) * (1 + connected_bonus) * (1 + worker_efficiency)
	Returns: Dictionary of {"resource_id": amount_per_hour}

	NEW BUILDING SYSTEM:
	- Special nodes: Use fixed_production (cannot be changed)
	- Blank tiles with building: Look up production from BuildingManager
	- Blank tiles without building: No production
	"""
	if not node or not node.is_controlled_by_player():
		return {}

	var production = {}
	var base_production = _get_node_base_production(node)

	if base_production.is_empty():
		return {}

	# Start with base production
	for resource_id in base_production:
		var base_amount = base_production[resource_id]

		# Apply upgrade bonus - use building_level for buildings, production_level for special nodes
		var upgrade_level = node.building_level if node.has_building() else node.production_level
		var upgrade_bonus = (upgrade_level - 1) * 0.10
		var amount = base_amount * (1.0 + upgrade_bonus)

		# Apply connected node bonus
		var connected_bonus = apply_connected_bonus(node)
		amount *= (1.0 + connected_bonus)

		# Apply worker efficiency bonuses from assigned gods
		var worker_bonus = _calculate_worker_efficiency(node)
		amount *= (1.0 + worker_bonus)

		production[resource_id] = int(amount)

	return production

func _get_node_base_production(node: HexNode) -> Dictionary:
	"""Get base production for a node based on its type:
	- Special nodes: fixed_production (immutable)
	- Blank tiles with building: BuildingManager.get_building_production()
	- Blank tiles without building: empty (no production)
	- Legacy nodes: base_production (backwards compat)
	"""
	# Special nodes have fixed production
	if node.is_special_node and not node.fixed_production.is_empty():
		return node.fixed_production

	# Check if node has a building
	if node.has_building():
		var building_manager = _get_building_manager()
		if building_manager:
			return building_manager.get_building_production(node.placed_building, node.building_level)

	# Blank tile without building - no production
	if node.node_type == "blank" and node.placed_building.is_empty():
		return {}

	# Base node (Divine Sanctum) uses fixed production
	if node.node_type == "base":
		return node.fixed_production if not node.fixed_production.is_empty() else node.base_production

	# Legacy fallback: use base_production directly
	return node.base_production

func _get_building_manager():
	"""Get BuildingManager via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("BuildingManager")
	return null

func _get_resource_manager():
	"""Get ResourceManager via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("ResourceManager")
	return null

func apply_connected_bonus(node: HexNode) -> float:
	"""Calculate production bonus from adjacent controlled nodes
	Bonuses (from CLAUDE.md):
	- 2 connected: +10% production
	- 3 connected: +20% production
	- 4+ connected: +30% production
	"""
	if not node:
		return 0.0

	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager or not territory_manager.has_method("get_connected_node_count"):
		return 0.0

	var connected_count = territory_manager.get_connected_node_count(node.coord)

	if connected_count >= 4:
		return 0.30  # 30% bonus for 4+ connected
	elif connected_count == 3:
		return 0.20  # 20% bonus for 3 connected
	elif connected_count == 2:
		return 0.10  # 10% bonus for 2 connected
	else:
		return 0.0  # No bonus

func apply_spec_bonus(node: HexNode, god: God) -> float:
	"""Calculate specialization bonus for god working at this node type
	Returns: Multiplier based on god's specialization and node type
	"""
	if not node or not god:
		return 0.0

	var spec_manager = SystemRegistry.get_instance().get_system("SpecializationManager")
	if not spec_manager:
		return 0.0

	# Get all task bonuses for this god
	var task_bonuses = spec_manager.get_total_task_bonuses_for_god(god)

	# Check for bonuses related to node type
	var total_bonus = 0.0

	# Map node types to task categories
	var node_task_mapping = {
		"mine": ["mining", "mine_ore", "mine_gems", "deep_mining", "gem_cutting"],
		"forest": ["logging", "herbalism", "foraging", "plant_cultivation"],
		"coast": ["fishing", "pearl_diving", "salt_harvesting"],
		"hunting_ground": ["hunting", "tracking", "monster_hunting", "taming"],
		"forge": ["smithing", "armor_crafting", "weapon_crafting", "enchanting"],
		"library": ["research", "scroll_crafting", "training", "skill_learning"],
		"temple": ["meditation", "blessing", "awakening_ritual", "divine_communion"],
		"fortress": ["garrison_duty", "war_planning", "combat_training", "defense_building"]
	}

	# Get tasks for this node type
	var relevant_tasks = node_task_mapping.get(node.node_type, [])

	# Find highest bonus from any relevant task
	for task_id in relevant_tasks:
		var bonus = task_bonuses.get(task_id, 0.0)
		if bonus > total_bonus:
			total_bonus = bonus

	return total_bonus

func _calculate_worker_efficiency(node: HexNode) -> float:
	"""Calculate total efficiency bonus from workers at this node
	Combines: spec bonuses, trait bonuses, level bonuses, pantheon bonuses
	Returns 0 if garrison power requirement is not met (workers inactive)
	"""
	if not node or node.assigned_workers.is_empty():
		return 0.0

	# Check garrison power requirement - workers are inactive without sufficient garrison
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and not territory_manager.can_assign_workers(node):
		return 0.0  # Workers inactive - no production bonus

	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	var spec_manager = SystemRegistry.get_instance().get_system("SpecializationManager")

	if not collection_manager:
		return 0.0

	var total_bonus = 0.0

	for god_id in node.assigned_workers:
		var god = collection_manager.get_god_by_id(god_id)
		if not god:
			continue

		# Base bonus: 10% per worker
		var worker_bonus = 0.10

		# Specialization bonus (can be 50-200% from CLAUDE.md)
		if spec_manager:
			var spec_bonus = apply_spec_bonus(node, god)
			worker_bonus += spec_bonus

		# Level bonus: 1% per god level
		worker_bonus += (god.level * 0.01)

		total_bonus += worker_bonus

	# Add pantheon matching bonus for worker team
	var pantheon_bonus = _calculate_pantheon_bonus(node.assigned_workers, collection_manager)
	total_bonus += pantheon_bonus

	return total_bonus

func _calculate_pantheon_bonus(god_ids: Array, collection_manager) -> float:
	"""Calculate production bonus for matching pantheons in a team
	Uses team_bonuses.json for configuration
	"""
	if god_ids.size() < 2 or not collection_manager:
		return 0.0

	# Count pantheons
	var pantheon_counts: Dictionary = {}
	for god_id in god_ids:
		var god = collection_manager.get_god_by_id(god_id)
		if god and god.pantheon:
			var pantheon = god.pantheon.to_lower()
			pantheon_counts[pantheon] = pantheon_counts.get(pantheon, 0) + 1

	# Find the most common pantheon
	var max_count = 0
	for pantheon in pantheon_counts:
		if pantheon_counts[pantheon] > max_count:
			max_count = pantheon_counts[pantheon]

	# Load team bonuses from dedicated config
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	var production_bonus = 0.0

	if config_manager:
		var team_bonuses = config_manager.get_team_bonuses_config()
		var pantheon_bonuses = team_bonuses.get("pantheon_bonuses", {})

		# Full pantheon bonus (all same)
		if max_count == god_ids.size() and max_count >= 2:
			var full_bonus = pantheon_bonuses.get("full_match", {}).get("bonuses", {})
			production_bonus = full_bonus.get("production", 0.25)
		# Majority bonus (3+ same)
		elif max_count >= 3:
			var majority_bonus = pantheon_bonuses.get("majority_match", {}).get("bonuses", {})
			production_bonus = majority_bonus.get("production", 0.10)
		# Duo bonus (2 same)
		elif max_count >= 2:
			var duo_bonus = pantheon_bonuses.get("duo_match", {}).get("bonuses", {})
			production_bonus = duo_bonus.get("production", 0.05)

	return production_bonus

func get_node_hourly_production(node: HexNode) -> Dictionary:
	"""Get hourly production rate for a specific hex node
	This is a convenience method that wraps calculate_node_production
	"""
	return calculate_node_production(node)

func get_all_hex_nodes_production() -> Dictionary:
	"""Get total production across all controlled hex nodes
	Returns: Dictionary of {"resource_id": total_amount_per_hour}
	"""
	var total_production = {}
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")

	if not territory_manager or not territory_manager.has_method("get_controlled_nodes"):
		return total_production

	var controlled_nodes = territory_manager.get_controlled_nodes()
	for node in controlled_nodes:
		var node_production = calculate_node_production(node)

		for resource_id in node_production:
			total_production[resource_id] = total_production.get(resource_id, 0) + node_production[resource_id]

	return total_production

func _process_hex_node_generation():
	"""Process resource accumulation for all player-controlled hex nodes
	Called every 60 seconds by the generation timer
	"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		return

	# Update attack timers (garrison defense mechanic)
	if territory_manager.has_method("update_attack_timers"):
		territory_manager.update_attack_timers()

	var controlled_nodes = territory_manager.get_controlled_nodes()
	if controlled_nodes.is_empty():
		return

	var current_time = Time.get_unix_time_from_system()

	for node in controlled_nodes:
		if not node or not node.is_controlled_by_player():
			continue

		# Check if this is a processing building that needs to consume resources
		var building_consumes = _get_building_consumes(node)

		if not building_consumes.is_empty():
			# Processing building - consume inputs to produce outputs
			_process_conversion_building(node, controlled_nodes, current_time)
		else:
			# Normal extraction/production building
			_process_extraction_building(node, current_time)

func _process_extraction_building(node: HexNode, current_time: float) -> void:
	"""Process normal extraction/production buildings that don't consume resources"""
	var hourly_production = calculate_node_production(node)
	if hourly_production.is_empty():
		return

	# Convert hourly to per-minute (60 second tick)
	var production_this_tick = {}
	for resource_id in hourly_production:
		var hourly_amount = hourly_production[resource_id]
		var tick_amount = hourly_amount / 60.0
		production_this_tick[resource_id] = tick_amount

	# Accumulate resources
	for resource_id in production_this_tick:
		var amount = production_this_tick[resource_id]
		if node.accumulated_resources.has(resource_id):
			node.accumulated_resources[resource_id] += amount
		else:
			node.accumulated_resources[resource_id] = amount

	# Update timestamp
	node.last_production_time = current_time

	# Debug output
	var coord_str = "(%d,%d)" % [node.coord.q, node.coord.r] if node.coord else "unknown"
	print("[TerritoryProductionManager] Node %s '%s' accumulated resources: %s (hourly rate: %s)" % [
		coord_str,
		node.name if node.name else node.id,
		_format_resources_dict(node.accumulated_resources),
		_format_resources_dict(hourly_production)
	])

func _process_conversion_building(node: HexNode, all_nodes: Array, current_time: float) -> void:
	"""Process conversion buildings that consume input resources to produce outputs"""
	var building_manager = _get_building_manager()
	if not building_manager:
		return

	var building = building_manager.get_building(node.placed_building)
	var consumes = building.get("consumes", {})
	var produces = building.get("production", {})

	if consumes.is_empty() or produces.is_empty():
		return

	# Check if we have workers assigned (required for conversion)
	if node.assigned_workers.is_empty():
		return

	# Check garrison power requirement - workers are inactive without sufficient garrison
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if territory_manager and not territory_manager.can_assign_workers(node):
		return  # Workers inactive - no conversion without garrison protection

	# Calculate how much we want to consume this tick (hourly / 60)
	var consume_this_tick = {}
	for res_id in consumes:
		consume_this_tick[res_id] = consumes[res_id] / 60.0

	# Calculate what fraction of consumption we can fulfill
	var fulfillment_ratio = _calculate_consumption_fulfillment(consume_this_tick, all_nodes)

	if fulfillment_ratio <= 0:
		# No input resources available
		var coord_str = "(%d,%d)" % [node.coord.q, node.coord.r] if node.coord else "unknown"
		print("[TerritoryProductionManager] Conversion %s '%s': No input resources available" % [coord_str, node.name])
		node.last_production_time = current_time
		return

	# Consume resources (from accumulated first, then inventory)
	for res_id in consume_this_tick:
		var amount_to_consume = consume_this_tick[res_id] * fulfillment_ratio
		_consume_resource(res_id, amount_to_consume, all_nodes)

	# Produce output proportional to what we consumed
	var hourly_production = calculate_node_production(node)
	for res_id in hourly_production:
		var base_tick_amount = hourly_production[res_id] / 60.0
		var actual_amount = base_tick_amount * fulfillment_ratio

		if node.accumulated_resources.has(res_id):
			node.accumulated_resources[res_id] += actual_amount
		else:
			node.accumulated_resources[res_id] = actual_amount

	# Update timestamp
	node.last_production_time = current_time

	# Debug output
	var coord_str = "(%d,%d)" % [node.coord.q, node.coord.r] if node.coord else "unknown"
	print("[TerritoryProductionManager] Conversion %s '%s': %.0f%% efficiency, consumed %s, produced %s" % [
		coord_str,
		node.name if node.name else node.id,
		fulfillment_ratio * 100,
		_format_resources_dict(consume_this_tick),
		_format_resources_dict(node.accumulated_resources)
	])

func _get_building_consumes(node: HexNode) -> Dictionary:
	"""Get the consumes dictionary for a node's building, if any"""
	if node.placed_building.is_empty():
		return {}

	var building_manager = _get_building_manager()
	if not building_manager:
		return {}

	var building = building_manager.get_building(node.placed_building)
	return building.get("consumes", {})

func _calculate_consumption_fulfillment(consume_amounts: Dictionary, all_nodes: Array) -> float:
	"""Calculate what fraction of the consumption we can fulfill (0.0 to 1.0)"""
	var resource_manager = _get_resource_manager()
	var min_ratio = 1.0

	for res_id in consume_amounts:
		var needed = consume_amounts[res_id]
		if needed <= 0:
			continue

		# Count available from accumulated resources across all nodes
		var available_accumulated = 0.0
		for node in all_nodes:
			if node and node.is_controlled_by_player():
				available_accumulated += node.accumulated_resources.get(res_id, 0)

		# Add inventory
		var available_inventory = 0.0
		if resource_manager:
			available_inventory = resource_manager.get_resource(res_id)

		var total_available = available_accumulated + available_inventory
		var ratio = total_available / needed if needed > 0 else 0.0
		min_ratio = min(min_ratio, ratio)

	return clamp(min_ratio, 0.0, 1.0)

func _consume_resource(res_id: String, amount: float, all_nodes: Array) -> void:
	"""Consume resources - from accumulated first, then inventory"""
	var remaining = amount

	# First consume from accumulated resources on nodes
	for node in all_nodes:
		if remaining <= 0:
			break
		if not node or not node.is_controlled_by_player():
			continue

		var available = node.accumulated_resources.get(res_id, 0)
		if available > 0:
			var to_consume = min(available, remaining)
			node.accumulated_resources[res_id] = available - to_consume
			remaining -= to_consume

	# Then consume from inventory if needed
	if remaining > 0:
		var resource_manager = _get_resource_manager()
		if resource_manager:
			resource_manager.spend(res_id, int(ceil(remaining)))

func _format_resources_dict(resources: Dictionary) -> String:
	"""Format resource dictionary for debug output"""
	if resources.is_empty():
		return "{}"

	var parts = []
	for resource_id in resources:
		var amount = resources[resource_id]
		# Format with 1 decimal place
		parts.append("%s: %.1f" % [resource_id, amount])

	return "{" + ", ".join(parts) + "}"

func calculate_offline_hex_production(node: HexNode) -> Dictionary:
	"""Calculate offline production for a hex node based on time passed
	Returns: Dictionary of resources generated while offline
	"""
	if not node or not node.is_controlled_by_player():
		return {}

	# Calculate time difference since last production
	var current_time: int = int(Time.get_unix_time_from_system())
	var time_diff: int = current_time - node.last_production_time

	# Convert to hours
	var hours_passed: float = time_diff / 3600.0

	if hours_passed <= 0:
		return {}

	# Apply max storage hours cap from balance config
	var max_storage_hours: float = 12.0  # Default
	var was_capped: bool = false

	# Load balance config directly
	var balance_config = _load_balance_config()
	if balance_config and balance_config.has("generation_timing"):
		max_storage_hours = balance_config.generation_timing.get("max_storage_hours", 12.0)

	if hours_passed > max_storage_hours:
		was_capped = true
		hours_passed = max_storage_hours

	# Get hourly production rate using existing formula
	var hourly_rate: Dictionary = calculate_node_production(node)

	if hourly_rate.is_empty():
		return {}

	# Calculate total offline resources (hourly_rate × hours)
	var offline_resources: Dictionary = {}
	for resource_id in hourly_rate:
		offline_resources[resource_id] = hourly_rate[resource_id] * hours_passed

	# Add to node's accumulated resources (don't replace)
	for resource_id in offline_resources:
		if node.accumulated_resources.has(resource_id):
			node.accumulated_resources[resource_id] += offline_resources[resource_id]
		else:
			node.accumulated_resources[resource_id] = offline_resources[resource_id]

	# Update timestamp
	node.last_production_time = current_time

	# Debug output
	print("[TerritoryProductionManager] Offline calculation for node (%d,%d) '%s':" % [node.coord.q, node.coord.r, node.name])
	print("  - Offline duration: %.2f hours (%.0f seconds)" % [hours_passed, time_diff])
	if was_capped:
		print("  - ⚠️ Max storage reached (capped at %.1f hours)" % max_storage_hours)
	print("  - Hourly rate: %s" % _format_resources_dict(hourly_rate))
	print("  - Generated offline: %s" % _format_resources_dict(offline_resources))
	print("  - Total accumulated: %s" % _format_resources_dict(node.accumulated_resources))

	return offline_resources

func collect_node_resources(node_id: String) -> Dictionary:
	"""Collect accumulated resources from a hex node for manual claiming
	Returns: Dictionary of collected resources that were awarded to player
	"""
	# Get node from HexGridManager
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	if not hex_grid_manager or not hex_grid_manager.has_method("get_node_by_id"):
		print("[TerritoryProductionManager] ERROR: HexGridManager not available for collect_node_resources")
		return {}

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		print("[TerritoryProductionManager] ERROR: Node '%s' not found" % node_id)
		return {}

	if not node.is_controlled_by_player():
		print("[TerritoryProductionManager] ERROR: Node '%s' not controlled by player" % node_id)
		return {}

	# Copy accumulated_resources to return Dictionary
	var collected_resources: Dictionary = {}
	for resource_id in node.accumulated_resources:
		collected_resources[resource_id] = node.accumulated_resources[resource_id]

	if collected_resources.is_empty():
		print("[TerritoryProductionManager] Node '%s' has no accumulated resources to collect" % node_id)
		return {}

	# Apply manual collection bonus from balance config
	var balance_config: Dictionary = _load_balance_config()
	var manual_bonus: float = 1.0
	if balance_config.has("generation_timing") and balance_config.generation_timing.has("manual_collection_bonus"):
		manual_bonus = balance_config.generation_timing.manual_collection_bonus

	# Multiply collected resources by bonus
	var base_collected: Dictionary = {}  # Track base amounts for display
	if manual_bonus > 1.0:
		for resource_id in collected_resources:
			base_collected[resource_id] = collected_resources[resource_id]  # Store original
			collected_resources[resource_id] *= manual_bonus  # Apply bonus

	# Award resources to player via ResourceManager
	# Convert float amounts to integers for ResourceManager (which expects ints)
	var integer_resources: Dictionary = {}
	for resource_id in collected_resources:
		var int_amount = int(collected_resources[resource_id])
		if int_amount > 0:
			integer_resources[resource_id] = int_amount

	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if resource_manager and not integer_resources.is_empty():
		if resource_manager.has_method("award_resources"):
			resource_manager.award_resources(integer_resources)
			print("[TerritoryProductionManager] Awarded to ResourceManager: %s" % str(integer_resources))

	# Clear node.accumulated_resources
	node.accumulated_resources.clear()

	# Emit resources_generated signal
	resources_generated.emit(node_id, collected_resources)

	# Debug output
	var coord_str = "(%d,%d)" % [node.coord.q, node.coord.r] if node.coord else "unknown"
	if manual_bonus > 1.0:
		var bonus_percent = int((manual_bonus - 1.0) * 100)
		print("[TerritoryProductionManager] Collected resources from node %s '%s': %s (+%d%% manual bonus)" % [
			coord_str,
			node.name if node.name else node_id,
			_format_resources_dict(collected_resources),
			bonus_percent
		])
	else:
		print("[TerritoryProductionManager] Collected resources from node %s '%s': %s" % [
			coord_str,
			node.name if node.name else node_id,
			_format_resources_dict(collected_resources)
		])

	return collected_resources

func _load_balance_config() -> Dictionary:
	"""Load territory balance config from JSON file
	Returns: Dictionary with balance configuration or empty dict on failure
	"""
	var file_path = "res://data/territory_balance_config.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("TerritoryProductionManager: Could not open " + file_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("TerritoryProductionManager: Error parsing " + file_path + ": " + json.get_error_message())
		return {}

	return json.get_data()
