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
	print("TerritoryProductionManager: Resource generation system ready")
	last_update_time = Time.get_unix_time_from_system()

func initialize():
	"""Initialize production system - called by SystemRegistry"""
	print("TerritoryProductionManager: Initializing resource generation")
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
	"""Process resource generation for all territories - RULE 5: SystemRegistry"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryController")
	if not territory_manager:
		return
	
	var controlled_territories = territory_manager.get_controlled_territories()
	for territory_id in controlled_territories:
		var territory = _get_territory_data(territory_id)
		if territory:
			_generate_territory_resources(territory)

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
	
	print("TerritoryProductionManager: Collected %s from %s" % [pending, territory.name])
	return pending

func _generate_territory_resources(territory: Territory):
	"""Generate resources for a single territory"""
	var resources = collect_territory_resources(territory)
	if not resources.is_empty():
		print("TerritoryProductionManager: Auto-generated %s from %s" % [resources, territory.name])

func _get_territory_data(territory_id: String) -> Territory:
	"""Get territory data through SystemRegistry - helper function"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryController") 
	if territory_manager and territory_manager.has_method("get_territory_by_id"):
		return territory_manager.get_territory_by_id(territory_id)
	return null

func get_total_hourly_production() -> Dictionary:
	"""Get total production across all territories"""
	var total_production = {}
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryController")
	
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
