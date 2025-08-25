# scripts/systems/TerritoryManager.gd
extends Node
class_name TerritoryManager

signal territory_role_assigned(territory_id: String, god_id: String, role: String)
signal territory_resources_generated(territory_id: String, resources: Dictionary)
signal territory_slots_updated(territory_id: String, new_slots: Dictionary)
signal god_role_changed(god_id: String, old_role: String, new_role: String)

# ==============================================================================
# CORE DATA STRUCTURES
# ==============================================================================

# Role system data loaded from JSON
var role_definitions: Dictionary = {}
var god_role_assignments: Dictionary = {}
var pantheon_role_distribution: Dictionary = {}
var element_role_affinity: Dictionary = {}

# Runtime caches
var territory_generation_cache: Dictionary = {}
var god_efficiency_cache: Dictionary = {}
var cache_update_time: float = 0.0

# Core resource types - simplified economy
const CORE_RESOURCES = {
	"divine_essence": "Primary currency for upgrades",
	"ore": "Equipment crafting materials", 
	"souls": "Summon scroll materials",
	"energy_regen": "Energy regeneration boost"
}

func _ready():
	load_role_system()
	print("TerritoryManager: Role system initialized")

# ==============================================================================
# INITIALIZATION & DATA LOADING  
# ==============================================================================

func load_role_system():
	"""Load role system data from configuration files"""
	var role_data = load_json_file("res://data/god_roles.json")
	if role_data.is_empty():
		create_fallback_role_system()
		return
	
	role_definitions = role_data.get("role_definitions", {})
	god_role_assignments = role_data.get("god_role_assignments", {})
	pantheon_role_distribution = role_data.get("pantheon_role_distribution", {})
	element_role_affinity = role_data.get("element_role_affinity", {})
	
	print("TerritoryManager: Loaded %d role definitions, %d god assignments" % [
		role_definitions.size(), god_role_assignments.size()
	])

func load_json_file(path: String) -> Dictionary:
	"""Load and parse JSON file"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("TerritoryManager: Cannot open file: " + path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("TerritoryManager: JSON parse error in: " + path)
		return {}
	
	return json.get_data()

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
# RESOURCE GENERATION SYSTEM
# ==============================================================================

func calculate_territory_passive_generation(territory: Territory) -> Dictionary:
	"""Calculate total passive resource generation for territory"""
	# Check cache
	var current_time = Time.get_unix_time_from_system()
	if territory_generation_cache.has(territory.id) and (current_time - cache_update_time) < 30.0:
		return territory_generation_cache[territory.id]
	
	if not territory.is_controlled_by_player():
		return {}
	
	var total_generation = get_base_territory_generation(territory)
	var role_assignments = get_territory_role_assignments(territory)
	
	# Apply role bonuses
	for role in role_assignments:
		var gods = role_assignments[role]
		var role_bonus = calculate_role_bonus(role, gods, territory)
		
		for resource in role_bonus:
			total_generation[resource] = total_generation.get(resource, 0) + role_bonus[resource]
	
	# Apply territory level bonuses
	total_generation = apply_territory_level_bonus(territory, total_generation)
	
	# Cache result
	territory_generation_cache[territory.id] = total_generation
	cache_update_time = current_time
	
	return total_generation

func get_base_territory_generation(territory: Territory) -> Dictionary:
	"""Get base generation before god bonuses"""
	# Use tier-based generation
	match territory.tier:
		1:
			return {"divine_essence": 50, "ore": 20}
		2: 
			return {"divine_essence": 120, "ore": 50, "souls": 10}
		3:
			return {"divine_essence": 300, "ore": 120, "souls": 30, "energy_regen": 5}
		_:
			return {"divine_essence": 25}

func calculate_role_bonus(role: String, gods: Array, territory: Territory) -> Dictionary:
	"""Calculate bonus from gods in specific role"""
	var role_bonus = {}
	
	for god in gods:
		var god_bonus = calculate_god_contribution(god, role, territory)
		for resource in god_bonus:
			role_bonus[resource] = role_bonus.get(resource, 0) + god_bonus[resource]
	
	return role_bonus

func calculate_god_contribution(god: God, role: String, territory: Territory) -> Dictionary:
	"""Calculate single god's resource contribution"""
	var contribution = {}
	var efficiency = get_god_role_efficiency(god, role)
	var tier_bonus = get_tier_bonus(god)
	var element_bonus = get_element_bonus(god, territory)
	
	var total_multiplier = efficiency * tier_bonus * (1.0 + element_bonus)
	
	match role:
		"gatherer":
			var base_gen = get_base_territory_generation(territory)
			for resource in base_gen:
				var bonus = int(base_gen[resource] * 0.25 * total_multiplier)  # 25% of base per gatherer
				contribution[resource] = bonus
		
		"defender":
			# Defenders provide small resource protection bonus
			contribution["divine_essence"] = int(10 * total_multiplier)
		
		"crafter":
			# Crafters generate crafting materials
			var element_name = territory.get_element_name().to_lower()
			contribution[element_name + "_powder"] = max(1, int(3 * total_multiplier))
	
	return contribution

func get_tier_bonus(god: God) -> float:
	"""Get tier-based multiplier"""
	match god.tier:
		God.TierType.LEGENDARY:
			return 1.8
		God.TierType.EPIC:
			return 1.4
		God.TierType.RARE:
			return 1.2
		God.TierType.COMMON:
			return 1.0
		_:
			return 1.0

func get_element_bonus(god: God, territory: Territory) -> float:
	"""Get element matching bonus"""
	return 0.25 if god.element == territory.element else 0.0

func apply_territory_level_bonus(territory: Territory, generation: Dictionary) -> Dictionary:
	"""Apply territory level bonuses"""
	var level_multiplier = 1.0 + (territory.territory_level * 0.05)  # 5% per level
	var boosted_generation = {}
	
	for resource in generation:
		boosted_generation[resource] = max(1, int(generation[resource] * level_multiplier))
	
	return boosted_generation

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
