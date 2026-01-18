class_name TerritoryProductionManager
extends Node

"""
TerritoryProductionManager.gd - Resource generation system
RULE 5: Uses SystemRegistry for all system access
RULE 2: Single responsibility - ONLY manages resource generation from territories  
RULE 4: No UI creation - emits events for UI updates

Following prompt.prompt.md CRITICAL SYSTEMS LIST:
- TerritoryProductionManager - Resource generation (150 lines)
"""

signal resources_generated(territory_id: String, resources: Dictionary)
signal production_updated(territory_id: String, new_rate: int)

var generation_timers: Dictionary = {}
var last_update_time: float = 0.0

func _ready():
	last_update_time = Time.get_unix_time_from_system()

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
	"""Process resource generation for all territories AND hex nodes - RULE 5: SystemRegistry"""
	# Old Territory system (legacy)
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		return

	var controlled_territories = territory_manager.get_controlled_territories()
	for territory_id in controlled_territories:
		var territory = _get_territory_data(territory_id)
		if territory:
			_generate_territory_resources(territory)

	# New Hex Node production system
	_process_hex_node_generation()

func calculate_territory_production(territory: Territory) -> int:
	"""Calculate total resource production rate for territory - RULE 3: Pure calculation"""
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		return 0
	
	var base_rate = territory.base_resource_rate
	
	# Territory level bonus
	var level_bonus = 1.0 + (territory.territory_level - 1) * 0.05
	base_rate = int(base_rate * level_bonus)
	
	# Upgrade bonuses  
	var upgrade_multiplier = 1.0 + (territory.resource_upgrades * 0.08)
	base_rate = int(base_rate * upgrade_multiplier)
	
	# God assignment bonuses
	var god_bonus = _calculate_god_production_bonus(territory)
	base_rate += god_bonus
	
	return base_rate

func _calculate_god_production_bonus(territory: Territory) -> int:
	"""Calculate production bonus from stationed gods - RULE 5: Use CollectionManager"""
	var bonus = 0
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	
	if not collection_manager:
		return 0
	
	for god_id in territory.stationed_gods:
		var god = collection_manager.get_god_by_id(god_id)
		if god:
			# Base 10% bonus per god
			var god_bonus = territory.base_resource_rate * 0.1
			
			# Element matching bonus (30%)
			if god.element == territory.element:
				god_bonus *= 1.3
			
			# Rarity bonus
			if god.has_method("get_tier"):
				var tier = god.get_tier()
				match tier:
					3: # Legendary
						god_bonus *= 1.2
					2: # Epic  
						god_bonus *= 1.1
			
			bonus += int(god_bonus)
	
	return bonus

func get_pending_resources(territory: Territory) -> Dictionary:
	"""Calculate pending resources for territory - RULE 3: Validate, calculate, return"""
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		return {}
	
	var current_time = Time.get_unix_time_from_system()
	var time_diff = current_time - territory.last_resource_generation
	var hours_passed = time_diff / 3600.0
	
	if hours_passed <= 0:
		return {}
	
	var hourly_rate = calculate_territory_production(territory)
	var total_resources = int(hourly_rate * hours_passed)
	
	# Different resource types based on territory tier and element
	var resources = _distribute_resources_by_type(territory, total_resources)
	
	return resources

func _distribute_resources_by_type(territory: Territory, total_amount: int) -> Dictionary:
	"""Distribute total resources into different types based on territory"""
	var resources = {}
	
	# Base resources
	resources["mana"] = int(total_amount * 0.6)  # 60% mana
	resources["gold"] = int(total_amount * 0.3)  # 30% gold
	
	# Element-specific materials (10%)
	var material_amount = int(total_amount * 0.1)
	if material_amount > 0:
		var element_material = _get_element_material_type(territory.element)
		resources[element_material] = material_amount
	
	# Tier bonus resources
	if territory.tier >= 2:
		resources["crystals"] = max(1, int(total_amount * 0.02))  # 2% crystals for tier 2+
	
	if territory.tier >= 3:
		resources["divine_essence"] = max(1, int(total_amount * 0.01))  # 1% divine essence for tier 3
	
	return resources

func _get_element_material_type(element: Territory.ElementType) -> String:
	"""Get material type for territory element"""
	match element:
		Territory.ElementType.FIRE: return "fire_crystals"
		Territory.ElementType.WATER: return "water_crystals"
		Territory.ElementType.EARTH: return "earth_crystals"
		Territory.ElementType.LIGHTNING: return "lightning_crystals"
		Territory.ElementType.LIGHT: return "light_crystals"
		Territory.ElementType.DARK: return "dark_crystals"
		_: return "magic_crystals"

func collect_territory_resources(territory: Territory) -> Dictionary:
	"""Collect resources from territory - RULE 3: Validate, update, emit"""
	# 1. Validate
	var pending = get_pending_resources(territory)
	if pending.is_empty():
		return {}
	
	# 2. Update territory timestamp
	territory.last_resource_generation = Time.get_unix_time_from_system()
	territory.last_collection_time = territory.last_resource_generation
	
	# 3. Add resources to player through ResourceManager
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if resource_manager:
		for resource_type in pending:
			resource_manager.add(resource_type, pending[resource_type])
	
	# 4. Emit event
	resources_generated.emit(territory.id, pending)

	return pending

func _generate_territory_resources(territory: Territory):
	"""Generate resources for a single territory"""
	var _resources = collect_territory_resources(territory)

func _get_territory_data(territory_id: String) -> Territory:
	"""Get territory data through SystemRegistry - helper function"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager") 
	if territory_manager and territory_manager.has_method("get_territory_by_id"):
		return territory_manager.get_territory_by_id(territory_id)
	return null

func get_total_hourly_production() -> Dictionary:
	"""Get total production across all territories"""
	var total_production = {}
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")

	if not territory_manager:
		return total_production

	var controlled = territory_manager.get_controlled_territories()
	for territory_id in controlled:
		var territory = _get_territory_data(territory_id)
		if territory:
			var production = calculate_territory_production(territory)
			var resources = _distribute_resources_by_type(territory, production)

			for resource_type in resources:
				total_production[resource_type] = total_production.get(resource_type, 0) + resources[resource_type]

	return total_production

# ==============================================================================
# HEX NODE PRODUCTION SYSTEM (Phase 2: Hex Territory Integration)
# ==============================================================================

func calculate_node_production(node: HexNode) -> Dictionary:
	"""Calculate total resource production for a hex node
	Production formula: base * (1 + upgrade_bonus) * (1 + connected_bonus) * (1 + worker_efficiency)
	Returns: Dictionary of {"resource_id": amount_per_hour}
	"""
	if not node or not node.is_controlled_by_player():
		return {}

	var production = {}

	# Start with base production from node
	for resource_id in node.base_production:
		var base_amount = node.base_production[resource_id]

		# Apply upgrade bonus (10% per production level above 1)
		var upgrade_bonus = (node.production_level - 1) * 0.10
		var amount = base_amount * (1.0 + upgrade_bonus)

		# Apply connected node bonus
		var connected_bonus = apply_connected_bonus(node)
		amount *= (1.0 + connected_bonus)

		# Apply worker efficiency bonuses from assigned gods
		var worker_bonus = _calculate_worker_efficiency(node)
		amount *= (1.0 + worker_bonus)

		production[resource_id] = int(amount)

	return production

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
	Combines: spec bonuses, trait bonuses, level bonuses
	"""
	if not node or node.assigned_workers.is_empty():
		return 0.0

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

	return total_bonus

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

	var controlled_nodes = territory_manager.get_controlled_nodes()
	if controlled_nodes.is_empty():
		return

	var current_time = Time.get_unix_time_from_system()

	for node in controlled_nodes:
		if not node or not node.is_controlled_by_player():
			continue

		# Calculate production for this node
		var hourly_production = calculate_node_production(node)
		if hourly_production.is_empty():
			continue

		# Convert hourly to per-minute (60 second tick)
		var production_this_tick = {}
		for resource_id in hourly_production:
			var hourly_amount = hourly_production[resource_id]
			# 60 seconds = 1/60 of an hour
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
	Follows pattern from get_pending_resources() (Lines 104-122)
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

	# Award resources to player via ResourceManager
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if resource_manager and resource_manager.has_method("award_resources"):
		resource_manager.award_resources(collected_resources)

	# Clear node.accumulated_resources
	node.accumulated_resources.clear()

	# Emit resources_generated signal
	resources_generated.emit(node_id, collected_resources)

	# Debug output
	var coord_str = "(%d,%d)" % [node.coord.q, node.coord.r] if node.coord else "unknown"
	print("[TerritoryProductionManager] Collected resources from node %s '%s': %s" % [
		coord_str,
		node.name if node.name else node_id,
		_format_resources_dict(collected_resources)
	])

	return collected_resources
