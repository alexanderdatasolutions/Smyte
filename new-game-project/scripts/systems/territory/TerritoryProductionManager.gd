class_name TerritoryProductionManager
extends Node

# Hex node resource generation system
# RULE 5: Uses SystemRegistry for all system access
# RULE 2: Single responsibility - ONLY manages resource generation from hex nodes
# RULE 4: No UI creation - emits events for UI updates

signal resources_generated(territory_id: String, resources: Dictionary)
signal production_updated(territory_id: String, new_rate: int)

static var _config: Dictionary = {}
static var _config_loaded: bool = false

static func _load_config() -> void:
	if _config_loaded:
		return
	var file: FileAccess = FileAccess.open("res://data/territory_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			_config = parsed
	_config_loaded = true

static func get_tick_interval() -> float:
	_load_config()
	return _config.get("generation_timing", {}).get("tick_interval_seconds", 60.0)

static func get_max_storage_hours() -> float:
	_load_config()
	return _config.get("generation_timing", {}).get("max_storage_hours", 12.0)

static func get_manual_collection_bonus() -> float:
	_load_config()
	return _config.get("generation_timing", {}).get("manual_collection_bonus", 1.0)

static func get_upgrade_bonus_per_level() -> float:
	_load_config()
	return _config.get("production_bonuses", {}).get("upgrade_bonus_per_level", 0.10)

static func get_worker_base_bonus() -> float:
	_load_config()
	return _config.get("production_bonuses", {}).get("worker_base_bonus", 0.10)

static func get_god_level_bonus_per_level() -> float:
	_load_config()
	return _config.get("production_bonuses", {}).get("god_level_bonus_per_level", 0.01)

static func get_connected_bonuses() -> Dictionary:
	_load_config()
	return _config.get("connected_bonuses", {"2": 0.10, "3": 0.20, "4": 0.30})

static func get_node_task_mapping() -> Dictionary:
	_load_config()
	var default_mapping: Dictionary = {
		"mine": ["mining", "mine_ore", "mine_gems", "deep_mining", "gem_cutting"],
		"forest": ["logging", "herbalism", "foraging", "plant_cultivation"],
		"coast": ["fishing", "pearl_diving", "salt_harvesting"],
		"hunting_ground": ["hunting", "tracking", "monster_hunting", "taming"],
		"forge": ["smithing", "armor_crafting", "weapon_crafting", "enchanting"],
		"library": ["research", "scroll_crafting", "training", "skill_learning"],
		"temple": ["meditation", "blessing", "awakening_ritual", "divine_communion"],
		"fortress": ["garrison_duty", "war_planning", "combat_training", "defense_building"]
	}
	return _config.get("node_task_mapping", default_mapping)

func initialize() -> void:
	_load_config()
	_start_generation_cycle()

func _start_generation_cycle() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = get_tick_interval()
	timer.timeout.connect(_process_all_territory_generation)
	timer.autostart = true
	add_child(timer)

func _process_all_territory_generation() -> void:
	_process_hex_node_generation()

func calculate_node_production(node: HexNode) -> Dictionary:
	if not node or not node.is_controlled_by_player():
		return {}

	var production: Dictionary = {}
	var base_production: Dictionary = _get_node_base_production(node)

	if base_production.is_empty():
		return {}

	var upgrade_bonus_per_level: float = get_upgrade_bonus_per_level()

	for resource_id: String in base_production:
		var base_amount: float = base_production[resource_id]

		# Apply upgrade bonus - use building_level for buildings, production_level for special nodes
		var upgrade_level: int = node.building_level if node.has_building() else node.production_level
		var upgrade_bonus: float = (upgrade_level - 1) * upgrade_bonus_per_level
		var amount: float = base_amount * (1.0 + upgrade_bonus)

		# Apply connected node bonus
		var connected_bonus: float = apply_connected_bonus(node)
		amount *= (1.0 + connected_bonus)

		# Apply worker efficiency bonuses from assigned gods
		var worker_bonus: float = _calculate_worker_efficiency(node)
		amount *= (1.0 + worker_bonus)

		production[resource_id] = int(amount)

	return production

func _get_node_base_production(node: HexNode) -> Dictionary:
	# Special nodes have fixed production
	if node.is_special_node and not node.fixed_production.is_empty():
		return node.fixed_production

	# Check if node has a building
	if node.has_building():
		var building_manager: Variant = _get_building_manager()
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

func _get_building_manager() -> Variant:
	var registry: Variant = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("BuildingManager")
	return null

func _get_resource_manager() -> Variant:
	var registry: Variant = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("ResourceManager")
	return null

func apply_connected_bonus(node: HexNode) -> float:
	if not node:
		return 0.0

	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return 0.0

	var territory_manager: Variant = registry.get_system("TerritoryManager")
	if not territory_manager or not territory_manager.has_method("get_connected_node_count"):
		return 0.0

	var connected_count: int = territory_manager.get_connected_node_count(node.coord)
	var bonuses: Dictionary = get_connected_bonuses()

	# Check from highest to lowest
	if connected_count >= 4:
		return bonuses.get("4", 0.30)
	elif connected_count == 3:
		return bonuses.get("3", 0.20)
	elif connected_count == 2:
		return bonuses.get("2", 0.10)
	else:
		return 0.0

func _calculate_worker_efficiency(node: HexNode) -> float:
	if not node or node.assigned_workers.is_empty():
		return 0.0

	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return 0.0

	var territory_manager: Variant = registry.get_system("TerritoryManager")
	if territory_manager and not territory_manager.can_assign_workers(node):
		return 0.0

	var collection_manager: Variant = registry.get_system("CollectionManager")

	if not collection_manager:
		return 0.0

	var worker_base: float = get_worker_base_bonus()
	var level_bonus_rate: float = get_god_level_bonus_per_level()
	var total_bonus: float = 0.0
	var worker_gods: Array[God] = []

	for god_id: String in node.assigned_workers:
		var god: Variant = collection_manager.get_god_by_id(god_id)
		if not god:
			continue

		worker_gods.append(god)
		var worker_bonus: float = worker_base

		# Level bonus
		worker_bonus += (god.level * level_bonus_rate)

		# Equipment/Power bonus from config (default: +0.5% per 100 power rating)
		var power_rating: int = GodCalculator.get_power_rating(god)
		var power_rate: float = _config.get("production_bonuses", {}).get("power_bonus_rate", 0.005)
		var power_bonus: float = (power_rating / 100.0) * power_rate
		worker_bonus += power_bonus

		total_bonus += worker_bonus

	# Apply team bonuses from TeamStatsCalculator (element/pantheon synergies)
	if worker_gods.size() >= 2:
		var team_bonus: float = _calculate_worker_team_bonus(worker_gods)
		total_bonus += team_bonus

	return total_bonus

## Calculate team bonus for workers using TeamStatsCalculator
func _calculate_worker_team_bonus(gods: Array[God]) -> float:
	if gods.size() < 2:
		return 0.0

	var team_bonuses: Array = TeamStatsCalculator.get_team_bonuses(gods)
	var total_bonus: float = 0.0

	for bonus: Dictionary in team_bonuses:
		var bonuses: Dictionary = bonus.get("bonuses", {})
		# Production-relevant bonuses (multipliers from config)
		var prod_cfg: Dictionary = _config.get("production_bonuses", {})
		if bonuses.has("production"):
			total_bonus += bonuses.production
		# Speed helps gathering efficiency
		if bonuses.has("speed"):
			total_bonus += bonuses.speed * prod_cfg.get("speed_multiplier", 0.3)
		# All stats helps a bit
		if bonuses.has("all_stats"):
			total_bonus += bonuses.all_stats * prod_cfg.get("all_stats_multiplier", 0.5)

	return total_bonus

func get_node_hourly_production(node: HexNode) -> Dictionary:
	return calculate_node_production(node)

func get_all_hex_nodes_production() -> Dictionary:
	var total_production: Dictionary = {}
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return total_production

	var territory_manager: Variant = registry.get_system("TerritoryManager")
	if not territory_manager or not territory_manager.has_method("get_controlled_nodes"):
		return total_production

	var controlled_nodes: Array = territory_manager.get_controlled_nodes()
	for node: Variant in controlled_nodes:
		var node_production: Dictionary = calculate_node_production(node)
		for resource_id: String in node_production:
			total_production[resource_id] = total_production.get(resource_id, 0) + node_production[resource_id]

	return total_production

func get_active_conversions() -> Array:
	"""Returns active conversion buildings with their input/output/rates for UI display"""
	var conversions: Array = []
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return conversions

	var territory_manager: Variant = registry.get_system("TerritoryManager")
	if not territory_manager or not territory_manager.has_method("get_controlled_nodes"):
		return conversions

	var building_manager: Variant = _get_building_manager()
	if not building_manager:
		return conversions

	var controlled_nodes: Array = territory_manager.get_controlled_nodes()
	for node: Variant in controlled_nodes:
		if not node or not node.is_controlled_by_player():
			continue
		if node.placed_building.is_empty():
			continue
		if node.assigned_workers.is_empty():
			continue

		# Check if garrison power is sufficient for workers
		if not territory_manager.can_assign_workers(node):
			continue

		var building: Dictionary = building_manager.get_building(node.placed_building)
		var consumes: Dictionary = building.get("consumes", {})
		var produces: Dictionary = building.get("production", {})

		if consumes.is_empty() or produces.is_empty():
			continue

		# This is a conversion building - add each input->output pair
		for input_id: String in consumes:
			var input_rate: int = int(consumes[input_id])
			for output_id: String in produces:
				var output_rate: int = int(produces[output_id])
				conversions.append({
					"node_name": node.name,
					"building": node.placed_building,
					"input": input_id,
					"output": output_id,
					"input_rate": input_rate,
					"output_rate": output_rate,
					"rate": output_rate  # For backwards compat with widget
				})

	return conversions

func _process_hex_node_generation() -> void:
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return

	var territory_manager: Variant = registry.get_system("TerritoryManager")
	if not territory_manager:
		return

	if territory_manager.has_method("update_attack_timers"):
		territory_manager.update_attack_timers()

	var controlled_nodes: Array = territory_manager.get_controlled_nodes()
	if controlled_nodes.is_empty():
		return

	var current_time: float = Time.get_unix_time_from_system()

	for node: Variant in controlled_nodes:
		if not node or not node.is_controlled_by_player():
			continue

		var building_consumes: Dictionary = _get_building_consumes(node)

		if not building_consumes.is_empty():
			_process_conversion_building(node, controlled_nodes, current_time)
		else:
			_process_extraction_building(node, current_time)

		# Process Day Care XP for assigned gods
		_process_day_care_xp(node)

func _process_extraction_building(node: HexNode, current_time: float) -> void:
	# Base node (Divine Sanctum) always produces, other nodes need garrison + workers
	if node.node_type != "base":
		# Check if node has garrison (required for all non-base nodes)
		if node.garrison.is_empty():
			return
		# Check if node has workers assigned (required for production)
		if node.assigned_workers.is_empty():
			return

	var hourly_production: Dictionary = calculate_node_production(node)
	if hourly_production.is_empty():
		return

	var production_this_tick: Dictionary = {}
	for resource_id: String in hourly_production:
		var hourly_amount: float = hourly_production[resource_id]
		var tick_amount: float = hourly_amount / 60.0
		production_this_tick[resource_id] = tick_amount

	for resource_id: String in production_this_tick:
		var amount: float = production_this_tick[resource_id]
		if node.accumulated_resources.has(resource_id):
			node.accumulated_resources[resource_id] += amount
		else:
			node.accumulated_resources[resource_id] = amount

	node.last_production_time = int(current_time)

func _process_conversion_building(node: HexNode, all_nodes: Array, current_time: float) -> void:
	var building_manager: Variant = _get_building_manager()
	if not building_manager:
		return

	var building: Dictionary = building_manager.get_building(node.placed_building)
	var consumes: Dictionary = building.get("consumes", {})
	var produces: Dictionary = building.get("production", {})

	if consumes.is_empty() or produces.is_empty():
		return

	if node.assigned_workers.is_empty():
		return

	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return

	var territory_manager: Variant = registry.get_system("TerritoryManager")
	if territory_manager and not territory_manager.can_assign_workers(node):
		return

	var consume_this_tick: Dictionary = {}
	for res_id: String in consumes:
		consume_this_tick[res_id] = consumes[res_id] / 60.0

	var fulfillment_ratio: float = _calculate_consumption_fulfillment(consume_this_tick, all_nodes)

	if fulfillment_ratio <= 0:
		node.last_production_time = int(current_time)
		return

	for res_id: String in consume_this_tick:
		var amount_to_consume: float = consume_this_tick[res_id] * fulfillment_ratio
		_consume_resource(res_id, amount_to_consume, all_nodes)

	var hourly_production: Dictionary = calculate_node_production(node)
	for res_id: String in hourly_production:
		var base_tick_amount: float = hourly_production[res_id] / 60.0
		var actual_amount: float = base_tick_amount * fulfillment_ratio

		if node.accumulated_resources.has(res_id):
			node.accumulated_resources[res_id] += actual_amount
		else:
			node.accumulated_resources[res_id] = actual_amount

	node.last_production_time = int(current_time)

func _get_building_consumes(node: HexNode) -> Dictionary:
	if node.placed_building.is_empty():
		return {}

	var building_manager: Variant = _get_building_manager()
	if not building_manager:
		return {}

	var building: Dictionary = building_manager.get_building(node.placed_building)
	return building.get("consumes", {})

func _calculate_consumption_fulfillment(consume_amounts: Dictionary, all_nodes: Array) -> float:
	var resource_manager: Variant = _get_resource_manager()
	var min_ratio: float = 1.0

	for res_id: String in consume_amounts:
		var needed: float = consume_amounts[res_id]
		if needed <= 0:
			continue

		var available_accumulated: float = 0.0
		for node: Variant in all_nodes:
			if node and node.is_controlled_by_player():
				available_accumulated += node.accumulated_resources.get(res_id, 0)

		var available_inventory: float = 0.0
		if resource_manager:
			available_inventory = resource_manager.get_resource(res_id)

		var total_available: float = available_accumulated + available_inventory
		var ratio: float = total_available / needed if needed > 0 else 0.0
		min_ratio = minf(min_ratio, ratio)

	return clampf(min_ratio, 0.0, 1.0)

func _consume_resource(res_id: String, amount: float, all_nodes: Array) -> void:
	var remaining: float = amount

	for node: Variant in all_nodes:
		if remaining <= 0:
			break
		if not node or not node.is_controlled_by_player():
			continue

		var available: float = node.accumulated_resources.get(res_id, 0)
		if available > 0:
			var to_consume: float = minf(available, remaining)
			node.accumulated_resources[res_id] = available - to_consume
			remaining -= to_consume

	if remaining > 0:
		var resource_manager: Variant = _get_resource_manager()
		if resource_manager:
			resource_manager.spend(res_id, int(ceil(remaining)))

func calculate_offline_hex_production(node: HexNode) -> Dictionary:
	if not node or not node.is_controlled_by_player():
		return {}

	# Base node (Divine Sanctum) always produces, other nodes need garrison + workers
	if node.node_type != "base":
		if node.garrison.is_empty() or node.assigned_workers.is_empty():
			return {}

	var current_time: int = int(Time.get_unix_time_from_system())

	# If last_production_time is 0 or invalid (more than max_offline_days old), initialize it
	# This prevents exploits from closing/reopening the game
	_load_config()
	var max_offline_days: int = _config.get("generation_timing", {}).get("max_offline_days", 30)
	var max_reasonable_time: int = max_offline_days * 24 * 3600
	if node.last_production_time <= 0 or (current_time - node.last_production_time) > max_reasonable_time:
		print("[TerritoryProductionManager] Initializing last_production_time for node %s (was %d)" % [node.id, node.last_production_time])
		node.last_production_time = current_time
		return {}

	var time_diff: int = current_time - node.last_production_time
	var hours_passed: float = time_diff / 3600.0

	if hours_passed <= 0:
		return {}

	var max_hours: float = get_max_storage_hours()
	if hours_passed > max_hours:
		hours_passed = max_hours

	var hourly_rate: Dictionary = calculate_node_production(node)
	if hourly_rate.is_empty():
		return {}

	var offline_resources: Dictionary = {}
	for resource_id: String in hourly_rate:
		offline_resources[resource_id] = hourly_rate[resource_id] * hours_passed

	for resource_id: String in offline_resources:
		if node.accumulated_resources.has(resource_id):
			node.accumulated_resources[resource_id] += offline_resources[resource_id]
		else:
			node.accumulated_resources[resource_id] = offline_resources[resource_id]

	node.last_production_time = current_time
	return offline_resources

func collect_node_resources(node_id: String) -> Dictionary:
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return {}

	var hex_grid_manager: Variant = registry.get_system("HexGridManager")
	if not hex_grid_manager or not hex_grid_manager.has_method("get_node_by_id"):
		return {}

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		return {}

	if not node.is_controlled_by_player():
		return {}

	var collected_resources: Dictionary = {}
	for resource_id: String in node.accumulated_resources:
		collected_resources[resource_id] = node.accumulated_resources[resource_id]

	if collected_resources.is_empty():
		return {}

	var manual_bonus: float = get_manual_collection_bonus()

	if manual_bonus > 1.0:
		for resource_id: String in collected_resources:
			collected_resources[resource_id] *= manual_bonus

	var integer_resources: Dictionary = {}
	for resource_id: String in collected_resources:
		var int_amount: int = int(collected_resources[resource_id])
		if int_amount > 0:
			integer_resources[resource_id] = int_amount

	var resource_manager: Variant = registry.get_system("ResourceManager")
	if resource_manager and not integer_resources.is_empty():
		if resource_manager.has_method("award_resources"):
			resource_manager.award_resources(integer_resources)

	node.accumulated_resources.clear()
	resources_generated.emit(node_id, collected_resources)

	return collected_resources

# ==============================================================================
# DAY CARE XP PROCESSING
# ==============================================================================

func _process_day_care_xp(node: HexNode) -> void:
	"""Process XP gain for gods assigned to Day Care buildings"""
	if not node or node.placed_building != "day_care":
		return

	# Get building effects to find XP rate
	var building_manager: Variant = _get_building_manager()
	if not building_manager:
		return

	var building: Dictionary = building_manager.get_building("day_care")
	var effects: Dictionary = building.get("effects", {})
	var xp_per_hour: int = effects.get("xp_per_hour", 100)

	# Scale XP by building level (same scaling as production, from config)
	_load_config()
	var level_multipliers: Dictionary = _config.get("building_level_multipliers", {"1": 1.0, "2": 1.15, "3": 1.35, "4": 1.60, "5": 2.00})
	var level_mult: float = level_multipliers.get(str(node.building_level), 1.0)
	xp_per_hour = int(xp_per_hour * level_mult)

	# Calculate XP per tick (tick is 1 minute, so divide hourly by 60)
	@warning_ignore("integer_division")
	var xp_per_tick: int = maxi(1, xp_per_hour / 60)

	# Get all assigned gods (garrison + workers)
	var god_ids: Array = []
	god_ids.append_array(node.garrison)
	god_ids.append_array(node.assigned_workers)

	if god_ids.is_empty():
		return

	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return

	var collection_manager: Variant = registry.get_system("CollectionManager")
	var god_progression: Variant = registry.get_system("GodProgressionManager")

	if not collection_manager or not god_progression:
		return

	# Award XP to each assigned god
	for god_id: Variant in god_ids:
		if god_id is String and not god_id.is_empty():
			var god: Variant = collection_manager.get_god_by_id(god_id)
			if god and god_progression.has_method("add_experience_to_god"):
				god_progression.add_experience_to_god(god, xp_per_tick)
