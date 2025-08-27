# scripts/systems/TerritoryManager.gd
extends Node
class_name TerritoryManager

signal territory_role_assigned(territory_id: String, god_id: String, role: String)
signal territory_resources_generated(territory_id: String, resources: Dictionary)
signal territory_slots_updated(territory_id: String, new_slots: Dictionary)
signal god_role_changed(god_id: String, old_role: String, new_role: String)

# ==============================================================================
# MODULAR SYSTEM REFERENCES
# ==============================================================================

# System dependencies - injected for modularity (no type hints to avoid scope issues)
var resource_manager = null
var loot_system = null
var data_loader = null

# ==============================================================================
# CORE DATA STRUCTURES - LOADED FROM JSON
# ==============================================================================

# Role system data loaded from JSON
var role_definitions: Dictionary = {}
var god_role_assignments: Dictionary = {}
var pantheon_role_distribution: Dictionary = {}
var element_role_affinity: Dictionary = {}

# Runtime caches for performance
var territory_generation_cache: Dictionary = {}
var god_efficiency_cache: Dictionary = {}
var cache_update_time: float = 0.0
var cache_timeout_seconds: float = 300.0  # 5 minutes

# Balancing configuration - loaded from JSON
var balance_config: Dictionary = {}

func _ready():
	_initialize_system_references()
	load_role_system()
	load_balance_configuration()
	print("TerritoryManager: Initialized with modular architecture")

# ==============================================================================
# SYSTEM INITIALIZATION & DEPENDENCIES
# ==============================================================================

func _initialize_system_references():
	"""Initialize references to other systems through GameManager - proper architecture"""
	# Wait for parent GameManager to be ready
	if not GameManager:
		await get_tree().process_frame
	
	# Get system references from GameManager (following architecture blueprint)
	if GameManager:
		resource_manager = GameManager.resource_manager
		loot_system = GameManager.loot_system
		
		# Fallback: try to find ResourceManager as singleton if not in GameManager
		if not resource_manager:
			resource_manager = get_node("/root/ResourceManager") if has_node("/root/ResourceManager") else null
		
		if not resource_manager:
			print("TerritoryManager: ResourceManager not found - using fallback generation")
		
		if not loot_system:
			print("TerritoryManager: LootSystem not found - using fallback generation")
	
	# DataLoader is static, access directly
	data_loader = DataLoader
	
	print("TerritoryManager: System references initialized via GameManager")

func _create_fallback_balance_config():
	"""Create fallback balance config if JSON file missing"""
	balance_config = {
		"generation_timing": {
			"base_collection_interval_hours": 1.0,
			"max_storage_hours": 12.0,
			"overflow_protection": true,
			"cache_timeout_seconds": 300
		},
		"summoners_war_balance": {
			"base_generation_conservative": true,
			"require_god_assignment": true,
			"god_efficiency_matters": true,
			"element_matching_bonus": 0.25
		},
		"resource_flow_control": {
			"max_hourly_mana_per_territory": 500,
			"max_hourly_crystals_per_territory": 15,
			"progressive_diminishing_returns": 0.95
		}
	}
	print("TerritoryManager: Using fallback balance configuration")

# ==============================================================================
# INITIALIZATION & DATA LOADING - VIA DATALOADER
# ==============================================================================

func load_role_system():
	"""Load role system data from DataLoader - PROPER ARCHITECTURE"""
	# DataLoader handles ALL JSON loading - we just request the data we need
	var role_data = data_loader.get_god_roles_config()
	var territory_roles_data = data_loader.get_territory_roles_config()
	
	if role_data.is_empty():
		create_fallback_role_system()
		return
	
	role_definitions = role_data.get("role_definitions", {})
	god_role_assignments = role_data.get("god_role_assignments", {})
	pantheon_role_distribution = role_data.get("pantheon_role_distribution", {})
	element_role_affinity = role_data.get("element_role_affinity", {})
	
	# Store territory roles data for resource generation
	if not territory_roles_data.is_empty():
		set_meta("territory_roles_data", territory_roles_data)
		print("TerritoryManager: Loaded territory role specializations via DataLoader")
	
	print("TerritoryManager: Loaded %d role definitions via DataLoader" % [
		role_definitions.size()
	])

func load_balance_configuration():
	"""Load balance configuration via DataLoader - PROPER ARCHITECTURE"""
	var balance_data = data_loader.get_territory_balance_config()
	if balance_data.is_empty():
		_create_fallback_balance_config()
		return
	
	balance_config = balance_data
	print("TerritoryManager: Loaded balance configuration via DataLoader with %d parameters" % balance_config.size())

func _process_territory_role_specializations(territory_roles_data: Dictionary):
	"""Process territory role specializations for resource generation"""
	# Store territory role data for dynamic resource generation
	set_meta("territory_roles_data", territory_roles_data)
	print("TerritoryManager: Loaded territory role specialization system")

func create_fallback_role_system():
	"""Create basic role system if data files are missing"""
	role_definitions = {
		"defender": {
			"name": "Defender",
			"base_benefits": {"territory_defense": 100},
			"tier_multipliers": {"common": 1.0, "rare": 1.2, "epic": 1.4, "legendary": 1.8}
		},
		"gatherer": {
			"name": "Gatherer", 
			"base_benefits": {"resource_generation_bonus": 0.2},
			"tier_multipliers": {"common": 1.0, "rare": 1.2, "epic": 1.4, "legendary": 1.6}
		},
		"crafter": {
			"name": "Crafter",
			"base_benefits": {"crafting_speed": 0.15},
			"tier_multipliers": {"common": 1.0, "rare": 1.25, "epic": 1.5, "legendary": 1.8}
		}
	}
	print("TerritoryManager: Using fallback role system")

# ==============================================================================
# CORE ROLE SYSTEM
# ==============================================================================

func get_god_primary_role(god: God) -> String:
	"""Get god's primary role"""
	if god_role_assignments.has(god.id):
		return god_role_assignments[god.id].get("role", "")
	
	# Fallback: use element affinity or tier-based assignment
	var element_name = god.get_element_name().to_lower()
	if element_role_affinity.has(element_name):
		return element_role_affinity[element_name].get("preferred_role", "gatherer")
	
	# Tier-based fallback
	return get_fallback_role_by_tier(god.tier)

func get_god_secondary_role(god: God) -> String:
	"""Get god's secondary role (awakened only)"""
	if not god.is_awakened:
		return ""
	
	if god_role_assignments.has(god.id):
		return god_role_assignments[god.id].get("secondary_role", "")
	
	# Element-based secondary role
	var element_name = god.get_element_name().to_lower()
	if element_role_affinity.has(element_name):
		return element_role_affinity[element_name].get("secondary_role", "")
	
	return ""

func get_fallback_role_by_tier(tier: God.TierType) -> String:
	"""Assign role based on god tier as fallback"""
	match tier:
		God.TierType.LEGENDARY:
			return "defender"
		God.TierType.EPIC:
			return "defender" 
		God.TierType.RARE:
			return "gatherer"
		God.TierType.COMMON:
			return "gatherer"
		_:
			return "gatherer"

func can_god_perform_role(god: God, role: String) -> bool:
	"""Check if god can perform specific role"""
	if get_god_primary_role(god) == role:
		return true
	
	if god.is_awakened and get_god_secondary_role(god) == role:
		return true
	
	return false

func get_god_role_efficiency(god: God, role: String) -> float:
	"""Get god's efficiency in specific role"""
	# Check cache first
	var cache_key = "%s_%s" % [god.id, role]
	if god_efficiency_cache.has(cache_key):
		return god_efficiency_cache[cache_key]
	
	var efficiency = 0.0
	
	if get_god_primary_role(god) == role:
		efficiency = 1.0  # 100% in primary role
	elif god.is_awakened and get_god_secondary_role(god) == role:
		efficiency = 0.8  # 80% in secondary role
	
	# Cache the result
	god_efficiency_cache[cache_key] = efficiency
	return efficiency

func get_available_roles_for_god(god: God) -> Array:
	"""Get all roles this god can perform"""
	var roles = []
	
	var primary = get_god_primary_role(god)
	if not primary.is_empty():
		roles.append(primary)
	
	if god.is_awakened:
		var secondary = get_god_secondary_role(god)
		if not secondary.is_empty() and not roles.has(secondary):
			roles.append(secondary)
	
	return roles

# ==============================================================================
# TERRITORY SLOT MANAGEMENT
# ==============================================================================

func get_territory_slot_configuration(territory: Territory) -> Dictionary:
	"""Get slot configuration for territory"""
	var base_slots = get_base_slot_configuration(territory.tier)
	var upgrade_bonuses = calculate_slot_upgrades(territory)
	
	return {
		"defender_slots": base_slots.defender_slots + upgrade_bonuses.defender_slots,
		"gatherer_slots": base_slots.gatherer_slots + upgrade_bonuses.gatherer_slots,
		"crafter_slots": base_slots.crafter_slots + upgrade_bonuses.crafter_slots,
		"max_total_slots": base_slots.max_total_slots + upgrade_bonuses.max_total_slots
	}

func get_base_slot_configuration(tier: int) -> Dictionary:
	"""Get base slots by territory tier"""
	match tier:
		1:
			return {"defender_slots": 1, "gatherer_slots": 2, "crafter_slots": 0, "max_total_slots": 3}
		2:
			return {"defender_slots": 2, "gatherer_slots": 2, "crafter_slots": 1, "max_total_slots": 5}
		3:
			return {"defender_slots": 3, "gatherer_slots": 3, "crafter_slots": 2, "max_total_slots": 8}
		_:
			return {"defender_slots": 1, "gatherer_slots": 1, "crafter_slots": 0, "max_total_slots": 2}

func calculate_slot_upgrades(territory: Territory) -> Dictionary:
	"""Calculate bonus slots from upgrades"""
	var bonuses = {"defender_slots": 0, "gatherer_slots": 0, "crafter_slots": 0, "max_total_slots": 0}
	
	# Upgrade bonuses (+1 slot per 5 levels, crafter slots unlock at level 3)
	var level_bonus = territory.territory_level / 5
	bonuses.defender_slots = level_bonus
	bonuses.gatherer_slots = level_bonus
	bonuses.crafter_slots = level_bonus if territory.territory_level >= 3 else 0
	bonuses.max_total_slots = level_bonus * 2
	
	return bonuses

func get_territory_role_assignments(territory: Territory) -> Dictionary:
	"""Get current god assignments by role"""
	var assignments = {"defender": [], "gatherer": [], "crafter": []}
	
	if not GameManager or not GameManager.player_data:
		return assignments
	
	for god in GameManager.player_data.gods:
		if god.stationed_territory == territory.id:
			var role = god.get_meta("territory_role", get_god_primary_role(god))
			if assignments.has(role):
				assignments[role].append(god)
	
	return assignments

# ==============================================================================
# GOD ASSIGNMENT SYSTEM
# ==============================================================================

func assign_god_to_territory_role(god: God, territory: Territory, role: String) -> bool:
	"""Assign god to territory in specific role"""
	# Validation
	if not role_definitions.has(role):
		push_error("Invalid role: " + role)
		return false
	
	if not can_god_perform_role(god, role):
		print("God %s cannot perform role %s" % [god.name, role])
		return false
	
	# Check slot availability
	var slot_config = get_territory_slot_configuration(territory)
	var current_assignments = get_territory_role_assignments(territory)
	
	var slot_type = role + "_slots"
	if current_assignments[role].size() >= slot_config[slot_type]:
		print("No available %s slots in %s" % [role, territory.name])
		return false
	
	# Remove from current assignment
	remove_god_from_territory(god)
	
	# Assign to new territory and role
	god.stationed_territory = territory.id
	god.set_meta("territory_role", role)
	
	if not territory.stationed_gods.has(god.id):
		territory.stationed_gods.append(god.id)
	
	# Clear caches
	clear_caches_for_territory(territory.id)
	
	territory_role_assigned.emit(territory.id, god.id, role)
	print("Assigned %s as %s to %s" % [god.name, role, territory.name])
	return true

func remove_god_from_territory(god: God):
	"""Remove god from current territory assignment"""
	if god.stationed_territory.is_empty():
		return
	
	var old_role = god.get_meta("territory_role", "")
	var territory = GameManager.get_territory_by_id(god.stationed_territory)
	
	if territory:
		territory.stationed_gods.erase(god.id)
		clear_caches_for_territory(territory.id)
	
	god.stationed_territory = ""
	god.remove_meta("territory_role")
	
	god_role_changed.emit(god.id, old_role, "")

func clear_caches_for_territory(territory_id: String):
	"""Clear cached data for territory"""
	territory_generation_cache.erase(territory_id)
	
	# Clear god efficiency cache for gods in this territory
	for key in god_efficiency_cache.keys():
		if key.begins_with(territory_id):
			god_efficiency_cache.erase(key)

# ==============================================================================
# MODULAR RESOURCE GENERATION SYSTEM
# ==============================================================================

func calculate_territory_passive_generation(territory: Territory) -> Dictionary:
	"""Calculate total passive resource generation using role-based system - ENHANCED"""
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		return {}
	
	# Check cache first for performance
	var current_time = Time.get_unix_time_from_system()
	if _is_cache_valid(territory.id, current_time):
		return territory_generation_cache[territory.id]
	
	# Get base generation from DataLoader (mana and divine_crystals)
	var assigned_gods = _get_assigned_gods_array(territory)
	var base_generation = data_loader.get_territory_passive_income(territory.id, assigned_gods)
	
	if base_generation.is_empty():
		print("TerritoryManager: Warning - No generation data for territory: ", territory.id)
		base_generation = _get_emergency_fallback_generation(territory)
	
	# Add role-based resource generation - THIS IS THE KEY ENHANCEMENT
	var role_generation = _calculate_role_based_generation(territory, assigned_gods)
	
	# Merge base generation with role generation
	var total_generation = base_generation.duplicate()
	for resource_type in role_generation:
		total_generation[resource_type] = total_generation.get(resource_type, 0) + role_generation[resource_type]
	
	# Apply Summoners War style balancing
	var balanced_generation = _apply_summoners_war_balance(territory, total_generation, assigned_gods)
	
	# Apply territory upgrades and level bonuses
	var final_generation = _apply_territory_upgrades(territory, balanced_generation)
	
	# Cache the result
	_cache_generation_result(territory.id, final_generation, current_time)
	
	return final_generation

func get_base_territory_generation(territory: Territory) -> Dictionary:
	"""Get base territory generation without god bonuses - FOR UI CALCULATIONS"""
	# Get base generation from DataLoader without gods
	var base_generation = data_loader.get_territory_passive_income(territory.id, [])
	
	if base_generation.is_empty():
		base_generation = _get_emergency_fallback_generation(territory)
	
	# Apply territory upgrades but not god bonuses
	var final_generation = _apply_territory_upgrades(territory, base_generation)
	
	return final_generation

func _calculate_role_based_generation(territory: Territory, assigned_gods: Array) -> Dictionary:
	"""Calculate resources generated by god roles - CORE ROLE SYSTEM"""
	var role_generation = {}
	
	if assigned_gods.is_empty():
		return role_generation
	
	var territory_roles_data = get_meta("territory_roles_data", {})
	if territory_roles_data.is_empty():
		print("TerritoryManager: No territory roles data - using basic generation")
		return role_generation
	
	var role_assignments = get_territory_role_assignments(territory)
	
	# Process each role type
	for role_type in ["gatherer", "crafter", "defender"]:
		var gods_in_role = role_assignments.get(role_type, [])
		if gods_in_role.is_empty():
			continue
		
		var role_resources = _get_role_resource_generation(territory, role_type, gods_in_role, territory_roles_data)
		
		# Merge role resources into total
		for resource_type in role_resources:
			role_generation[resource_type] = role_generation.get(resource_type, 0) + role_resources[resource_type]
	
	return role_generation

func _get_role_resource_generation(territory: Territory, role_type: String, gods: Array, territory_roles_data: Dictionary) -> Dictionary:
	"""Get resource generation for specific role based on territory specialization"""
	var resources = {}
	
	# Get territory specialization for this role
	var territory_specialization = _get_territory_role_specialization(territory, role_type)
	
	# Get role data from territory_roles.json
	var role_data = territory_roles_data.get("territory_roles", {}).get(role_type, {})
	var sub_roles = role_data.get("sub_roles", {})
	
	if territory_specialization.is_empty():
		print("TerritoryManager: No specialization for %s role in %s" % [role_type, territory.name])
		return resources
	
	for god in gods:
		var god_efficiency = get_god_role_efficiency(god, role_type)
		var tier_multiplier = _get_god_tier_multiplier(god)
		var element_bonus = 1.0 + (0.25 if god.element == territory.element else 0.0)
		
		var final_efficiency = god_efficiency * tier_multiplier * element_bonus
		
		# Generate resources based on territory specialization
		for specialization in territory_specialization:
			if sub_roles.has(specialization):
				var sub_role_data = sub_roles[specialization]
				var base_production = sub_role_data.get("base_production", {})
				
				for resource_type in base_production:
					var base_amount = base_production[resource_type]
					var final_amount = int(base_amount * final_efficiency)
					
					# Map generic resource names to specific ones
					var actual_resource = _map_resource_to_territory(resource_type, territory)
					
					resources[actual_resource] = resources.get(actual_resource, 0) + final_amount
	
	return resources

func _get_territory_role_specialization(territory: Territory, role_type: String) -> Array:
	"""Get what sub-roles this territory specializes in for the given role type"""
	# This defines what each territory produces - EASY TO CONFIGURE!
	var specializations = {
		# Tier 1 - Basic resource generation
		"sacred_grove": {
			"gatherer": ["cultist"],  # Produces awakening powder
			"crafter": ["alchemist"],  # Converts powder types
			"defender": ["guardian"]
		},
		"crystal_springs": {
			"gatherer": ["soul_harvester"],  # Produces souls for summoning
			"crafter": ["chef"],  # Makes temporary buffs
			"defender": ["guardian"]
		},
		"ember_hills": {
			"gatherer": ["miner"],  # Produces ore for equipment
			"crafter": ["blacksmith"],  # Makes equipment/runes
			"defender": ["champion"]
		},
		"storm_peaks": {
			"gatherer": ["energy_conduit"],  # Energy regeneration
			"crafter": ["alchemist"],  # Multi-element conversion
			"defender": ["champion"]
		},
		
		# Tier 2 - Advanced specializations
		"ancient_ruins": {
			"gatherer": ["cultist", "soul_harvester"],  # Mixed production
			"crafter": ["alchemist", "chef"],  # Advanced crafting
			"defender": ["champion"]
		},
		"shadow_realm": {
			"gatherer": ["soul_harvester", "miner"],  # Dark materials
			"crafter": ["blacksmith"],  # Dark equipment
			"defender": ["guardian", "champion"]
		},
		"elemental_nexus": {
			"gatherer": ["cultist", "miner"],  # All element materials
			"crafter": ["alchemist", "blacksmith"],  # Elemental crafting
			"defender": ["champion"]
		},
		"divine_sanctum": {
			"gatherer": ["cultist", "energy_conduit"],  # Divine power
			"crafter": ["chef", "alchemist"],  # Divine buffs
			"defender": ["guardian", "champion"]
		},
		"frozen_wastes": {
			"gatherer": ["miner", "energy_conduit"],  # Ice materials
			"crafter": ["blacksmith"],  # Ice equipment
			"defender": ["guardian"]
		},
		
		# Tier 3 - Elite production
		"primordial_chaos": {
			"gatherer": ["soul_harvester", "cultist", "miner"],  # All materials
			"crafter": ["alchemist", "blacksmith", "chef"],  # Master crafting
			"defender": ["champion"]
		},
		"celestial_throne": {
			"gatherer": ["cultist", "energy_conduit", "soul_harvester"],  # Divine resources
			"crafter": ["alchemist", "chef"],  # Celestial crafting
			"defender": ["guardian", "champion"]
		},
		"volcanic_core": {
			"gatherer": ["miner", "cultist", "energy_conduit"],  # Ultimate materials
			"crafter": ["blacksmith", "alchemist"],  # Legendary crafting
			"defender": ["champion"]
		}
	}
	
	return specializations.get(territory.id, {}).get(role_type, [])

func _map_resource_to_territory(generic_resource: String, territory: Territory) -> String:
	"""Map generic resource names to territory-specific ones"""
	var element_name = territory.get_element_name().to_lower()
	
	match generic_resource:
		"powder":
			return element_name + "_powder_low"
		"souls":
			return element_name + "_soul"
		"ore":
			# Different territories produce different ore tiers
			match territory.tier:
				1: return "iron_ore"
				2: return "mythril_ore"
				3: return "adamantite_ore"
				_: return "iron_ore"
		"energy_regen":
			return "energy_boost_temp"  # Temporary energy boost item
		_:
			return generic_resource

func _get_god_tier_multiplier(god: God) -> float:
	"""Get tier-based multiplier for gods"""
	var tier_bonuses = balance_config.get("god_assignment_balance", {}).get("tier_bonuses", {})
	var tier_name = _get_god_tier_name(god)
	return tier_bonuses.get(tier_name, 1.0)

func _get_god_tier_name(god: God) -> String:
	"""Convert god tier enum to string"""
	match god.tier:
		God.TierType.COMMON: return "common"
		God.TierType.RARE: return "rare"
		God.TierType.EPIC: return "epic"
		God.TierType.LEGENDARY: return "legendary"
		_: return "common"

func _is_cache_valid(territory_id: String, current_time: float) -> bool:
	"""Check if cached generation is still valid"""
	if not territory_generation_cache.has(territory_id):
		return false
	
	var cache_age = current_time - cache_update_time
	var timeout = balance_config.get("generation_timing", {}).get("cache_timeout_seconds", cache_timeout_seconds)
	
	return cache_age < timeout

func _get_assigned_gods_array(territory: Territory) -> Array:
	"""Get array of God objects assigned to territory"""
	var gods = []
	if not GameManager or not GameManager.player_data:
		return gods
	
	for god_id in territory.stationed_gods:
		var god = GameManager.get_god_by_id(god_id)
		if god:
			gods.append(god)
	
	return gods

func _apply_summoners_war_balance(territory: Territory, base_generation: Dictionary, gods: Array) -> Dictionary:
	"""Apply Summoners War style conservative balance - prevent resource explosion"""
	var balanced = {}
	
	# Get balance settings
	var balance_settings = balance_config.get("summoners_war_balance", {})
	var resource_limits = balance_config.get("resource_flow_control", {})
	
	for resource_type in base_generation:
		var base_amount = base_generation[resource_type]
		var final_amount = base_amount
		
		# Conservative generation if enabled
		if balance_settings.get("base_generation_conservative", true):
			final_amount = int(final_amount * 0.8)  # 20% reduction for balance
		
		# Apply resource caps per territory
		match resource_type:
			"mana":
				var max_mana = resource_limits.get("max_hourly_mana_per_territory", 500)
				final_amount = min(final_amount, max_mana)
			"divine_crystals":
				var max_crystals = resource_limits.get("max_hourly_crystals_per_territory", 15)
				final_amount = min(final_amount, max_crystals)
		
		# Diminishing returns for multiple territories
		if _get_player_territory_count() > 3:
			var diminish_rate = resource_limits.get("progressive_diminishing_returns", 0.95)
			var territory_penalty = pow(diminish_rate, _get_player_territory_count() - 3)
			final_amount = int(final_amount * territory_penalty)
		
		balanced[resource_type] = max(1, final_amount)  # Minimum of 1
	
	return balanced

func _apply_territory_upgrades(territory: Territory, generation: Dictionary) -> Dictionary:
	"""Apply territory-specific upgrades and bonuses"""
	var upgraded = {}
	
	for resource_type in generation:
		var base_amount = generation[resource_type]
		var upgraded_amount = base_amount
		
		# Territory level bonus (5% per level, capped at 15 levels)
		var level_bonus = min(territory.territory_level, 15) * 0.05
		upgraded_amount = int(upgraded_amount * (1.0 + level_bonus))
		
		# Resource upgrade bonus (8% per upgrade)
		if territory.resource_upgrades > 0:
			var resource_bonus = territory.resource_upgrades * 0.08
			upgraded_amount = int(upgraded_amount * (1.0 + resource_bonus))
		
		upgraded[resource_type] = max(1, upgraded_amount)
	
	return upgraded

func _get_emergency_fallback_generation(territory: Territory) -> Dictionary:
	"""Emergency fallback if DataLoader fails"""
	var tier = territory.tier
	match tier:
		1:
			return {"mana": 35, "divine_crystals": 1}
		2:
			return {"mana": 85, "divine_crystals": 2}
		3:
			return {"mana": 200, "divine_crystals": 5}
		_:
			return {"mana": 25}

func _get_player_territory_count() -> int:
	"""Get number of territories controlled by player"""
	var count = 0
	if GameManager and GameManager.player_data:
		for territory_id in GameManager.player_data.controlled_territories:
			count += 1
	return count

func _cache_generation_result(territory_id: String, generation: Dictionary, timestamp: float):
	"""Cache generation result with timestamp"""
	territory_generation_cache[territory_id] = generation
	cache_update_time = timestamp

# ==============================================================================
# MODULAR RESOURCE COLLECTION SYSTEM
# ==============================================================================

func collect_territory_resources(territory: Territory) -> Dictionary:
	"""Collect resources from territory using modular LootSystem"""
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		return {}
	
	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - territory.last_resource_generation
	
	# Calculate hours passed (minimum 1 minute = 0.0167 hours)
	var hours_passed = max(time_since_last / 3600.0, 0.0167)
	
	# Get hourly generation rate
	var hourly_generation = calculate_territory_passive_generation(territory)
	
	# Calculate total resources to award
	var resources_to_award = {}
	for resource_type in hourly_generation:
		var hourly_amount = hourly_generation[resource_type]
		var total_amount = int(hourly_amount * hours_passed)
		
		# Apply collection bonuses and caps
		total_amount = _apply_collection_modifiers(territory, resource_type, total_amount, hours_passed)
		
		if total_amount > 0:
			resources_to_award[resource_type] = total_amount
	
	# Award resources through ResourceManager (modular!)
	if not resources_to_award.is_empty():
		_award_resources_to_player(resources_to_award)
		
		# Update territory's last collection time
		territory.last_resource_generation = current_time
		
		# Emit signal for UI updates
		territory_resources_generated.emit(territory.id, resources_to_award)
		
		# Log collection for debugging
		print("TerritoryManager: Collected from %s: %s" % [territory.name, resources_to_award])
	
	return resources_to_award

func _apply_collection_modifiers(territory: Territory, resource_type: String, amount: int, hours_passed: float) -> int:
	"""Apply collection bonuses, caps, and penalties"""
	var modified_amount = amount
	
	# Get balance settings
	var collection_settings = balance_config.get("generation_timing", {})
	var max_storage_hours = collection_settings.get("max_storage_hours", 12.0)
	
	# Overflow protection - cap resources at max storage time
	if hours_passed > max_storage_hours:
		var overflow_protection = collection_settings.get("overflow_protection", true)
		if overflow_protection:
			# Calculate amount as if collected at max storage time
			var max_amount = int(amount * (max_storage_hours / hours_passed))
			modified_amount = max_amount
			
			print("TerritoryManager: Overflow protection applied for %s - %d hours capped to %d hours" % [
				territory.name, int(hours_passed), int(max_storage_hours)
			])
	
	# Manual collection bonus (10% more if collected frequently)
	if hours_passed < 2.0:  # Collected within 2 hours
		modified_amount = int(modified_amount * 1.1)
	
	return max(1, modified_amount)

func _award_resources_to_player(resources: Dictionary):
	"""Award resources to player using ResourceManager - MODULAR"""
	if not resource_manager:
		push_error("TerritoryManager: Cannot award resources - ResourceManager not found")
		return
	
	# Award through ResourceManager for proper tracking
	for resource_type in resources:
		var amount = resources[resource_type]
		if amount > 0:
			if GameManager and GameManager.player_data:
				GameManager.player_data.add_resource(resource_type, amount)
			
			print("TerritoryManager: Awarded %d %s" % [amount, resource_type])
	
	# Emit global resources updated signal
	if resource_manager.has_signal("resources_updated"):
		resource_manager.resources_updated.emit()

func collect_all_territories_resources() -> Dictionary:
	"""Collect resources from all player-controlled territories"""
	var total_collected = {}
	
	if not GameManager or not GameManager.player_data:
		return total_collected
	
	var territories = GameManager.get_all_territories()
	for territory in territories:
		if territory.is_controlled_by_player():
			var collected = collect_territory_resources(territory)
			
			# Merge into total
			for resource_type in collected:
				total_collected[resource_type] = total_collected.get(resource_type, 0) + collected[resource_type]
	
	if not total_collected.is_empty():
		print("TerritoryManager: Total collected from all territories: %s" % total_collected)
	
	return total_collected

func get_pending_resources_for_territory(territory: Territory) -> Dictionary:
	"""Get resources waiting to be collected without actually collecting them"""
	if not territory.is_controlled_by_player() or not territory.is_unlocked:
		return {}
	
	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - territory.last_resource_generation
	var hours_passed = time_since_last / 3600.0
	
	var hourly_generation = calculate_territory_passive_generation(territory)
	var pending = {}
	
	for resource_type in hourly_generation:
		var hourly_amount = hourly_generation[resource_type]
		var total_amount = int(hourly_amount * hours_passed)
		total_amount = _apply_collection_modifiers(territory, resource_type, total_amount, hours_passed)
		
		if total_amount > 0:
			pending[resource_type] = total_amount
	
	return pending

# ==============================================================================
# ANALYSIS & UTILITIES
# ==============================================================================

func get_territory_efficiency_summary(territory: Territory) -> Dictionary:
	"""Get comprehensive territory efficiency analysis"""
	var slot_config = get_territory_slot_configuration(territory)
	var assignments = get_territory_role_assignments(territory)
	
	var summary = {
		"total_slots_used": 0,
		"total_slots_available": slot_config.max_total_slots,
		"role_efficiency": {},
		"resource_generation": calculate_territory_passive_generation(territory),
		"recommendations": []
	}
	
	# Analyze each role
	for role in ["defender", "gatherer", "crafter"]:
		var gods = assignments[role]
		var available_slots = slot_config[role + "_slots"]
		
		summary.total_slots_used += gods.size()
		
		var total_efficiency = 0.0
		for god in gods:
			total_efficiency += get_god_role_efficiency(god, role)
		
		summary.role_efficiency[role] = {
			"used_slots": gods.size(),
			"available_slots": available_slots,
			"total_efficiency": total_efficiency,
			"average_efficiency": total_efficiency / max(1, gods.size()) if gods.size() > 0 else 0.0
		}
		
		# Generate recommendations
		if gods.size() < available_slots:
			summary.recommendations.append("Add more %ss to increase resource generation" % role)
		
		if gods.size() > 0:
			var avg_efficiency = total_efficiency / gods.size()
			if avg_efficiency < 0.8:
				summary.recommendations.append("Consider using awakened gods or better role matches for %s" % role)
	
	return summary

# ==============================================================================
# DEBUG & TESTING
# ==============================================================================

func print_territory_debug(territory: Territory):
	"""Print detailed debug info for territory"""
	print("=== Territory Debug: %s ===" % territory.name)
	print("Tier: %d, Level: %d, Element: %s" % [territory.tier, territory.territory_level, territory.get_element_name()])
	
	var slots = get_territory_slot_configuration(territory)
	print("Slots: %s" % slots)
	
	var assignments = get_territory_role_assignments(territory)
	print("Assignments:")
	for role in assignments:
		print("  %s (%d gods):" % [role, assignments[role].size()])
		for god in assignments[role]:
			var eff = get_god_role_efficiency(god, role)
			print("    - %s (%.1f%% efficiency, Lvl %d)" % [god.name, eff * 100, god.level])
	
	var generation = calculate_territory_passive_generation(territory)
	print("Generation: %s" % generation)
	
	var summary = get_territory_efficiency_summary(territory)
	print("Recommendations: %s" % summary.recommendations)

func validate_role_system() -> bool:
	"""Validate role system integrity"""
	var valid = true
	
	# Check role definitions
	for required_role in ["defender", "gatherer", "crafter"]:
		if not role_definitions.has(required_role):
			push_error("Missing role definition: " + required_role)
			valid = false
	
	# Check god assignments
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			var primary_role = get_god_primary_role(god)
			if primary_role.is_empty():
				push_warning("God %s has no primary role" % god.name)
	
	return valid

func calculate_god_contribution(god: God, role: String, territory: Territory) -> Dictionary:
	"""Calculate specific resource contributions for a god in a role - FOR UI DISPLAY"""
	var contribution = {}
	
	if not god or not territory:
		return contribution
	
	# Get god's efficiency in this role
	var efficiency = get_god_role_efficiency(god, role)
	if efficiency <= 0.0:
		return contribution  # God can't perform this role
	
	# Get tier multiplier
	var tier_multiplier = _get_god_tier_multiplier(god)
	
	# Element matching bonus
	var element_bonus = 1.0
	if god.element == territory.element:
		element_bonus = 1.25  # 25% bonus
	
	# Calculate final efficiency
	var final_efficiency = efficiency * tier_multiplier * element_bonus
	
	# Get territory's role specializations
	var territory_specializations = _get_territory_role_specialization(territory, role)
	
	if territory_specializations.is_empty():
		# Fallback to basic generation if no specialization data
		return _calculate_fallback_god_contribution(god, role, territory, final_efficiency)
	
	# Get role data from territory_roles.json
	var territory_roles_data = get_meta("territory_roles_data", {})
	var role_data = territory_roles_data.get("territory_roles", {}).get(role, {})
	var sub_roles = role_data.get("sub_roles", {})
	
	# Calculate contribution for each specialization this territory has
	for specialization in territory_specializations:
		if sub_roles.has(specialization):
			var sub_role_data = sub_roles[specialization]
			var base_production = sub_role_data.get("base_production", {})
			
			for resource_type in base_production:
				var base_amount = base_production[resource_type]
				var god_amount = int(base_amount * final_efficiency)
				
				# Map generic resource names to specific ones
				var actual_resource = _map_resource_to_territory(resource_type, territory)
				
				contribution[actual_resource] = contribution.get(actual_resource, 0) + god_amount
	
	return contribution

func _calculate_fallback_god_contribution(god: God, role: String, territory: Territory, efficiency: float) -> Dictionary:
	"""Fallback calculation when role data is unavailable"""
	var contribution = {}
	
	match role:
		"gatherer":
			# Base resource generation based on territory tier
			match territory.tier:
				1:
					contribution["mana"] = int(12 * efficiency)
				2:
					contribution["mana"] = int(18 * efficiency)
					contribution["iron_ore"] = int(8 * efficiency)
				3:
					contribution["divine_crystals"] = int(3 * efficiency)
					contribution["mythril_ore"] = int(12 * efficiency)
					var element_name = territory.get_element_name().to_lower()
					contribution[element_name + "_soul"] = int(2 * efficiency)
				_:
					contribution["mana"] = int(10 * efficiency)
		
		"crafter":
			# Craft element-specific materials
			var element_name = territory.get_element_name().to_lower()
			contribution[element_name + "_powder_low"] = int(3 * efficiency)
			
			if territory.tier >= 2:
				contribution[element_name + "_powder_mid"] = int(1 * efficiency)
		
		"defender":
			# Defenders don't generate resources directly, but provide territory defense
			# This is more for combat bonuses, so we'll return empty for resource display
			pass
	
	return contribution
