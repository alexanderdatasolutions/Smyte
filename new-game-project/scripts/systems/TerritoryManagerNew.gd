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

# Simplified role system data
var territory_roles: Dictionary = {}
var core_resources: Dictionary = {}
var slot_configuration: Dictionary = {}
var god_assignments: Dictionary = {}

# Runtime caches
var territory_generation_cache: Dictionary = {}
var god_efficiency_cache: Dictionary = {}
var cache_update_time: float = 0.0

func _ready():
	load_territory_roles_system()
	print("TerritoryManager: Simplified territory role system initialized")

# ==============================================================================
# INITIALIZATION & DATA LOADING  
# ==============================================================================

func load_territory_roles_system():
	"""Load simplified territory roles system"""
	var role_data = load_json_file("res://data/territory_roles.json")
	if role_data.is_empty():
		create_fallback_role_system()
		return
	
	territory_roles = role_data.get("territory_roles", {})
	core_resources = role_data.get("core_resources", {})
	slot_configuration = role_data.get("territory_slot_configuration", {})
	god_assignments = role_data.get("god_role_assignments", {})
	
	print("TerritoryManager: Loaded %d role types, %d resources" % [
		territory_roles.size(), core_resources.size()
	])

func load_json_file(path: String) -> Dictionary:
	"""Load and parse JSON file"""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("TerritoryManager: Failed to load %s" % path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("TerritoryManager: JSON parse error in %s" % path)
		return {}
	
	return json.get_data()

func create_fallback_role_system():
	"""Create basic role system if data files are missing"""
	territory_roles = {
		"gatherer": {
			"id": "gatherer",
			"name": "Gatherer",
			"sub_roles": {
				"cultist": {"base_production": {"essence": 1}, "hourly_rate": true}
			}
		},
		"crafter": {
			"id": "crafter", 
			"name": "Crafter",
			"sub_roles": {
				"alchemist": {"conversion_recipes": []}
			}
		},
		"defender": {
			"id": "defender",
			"name": "Defender", 
			"sub_roles": {
				"guardian": {"effects": {"territory_defense": 100}}
			}
		}
	}
	
	core_resources = {
		"essence": {"id": "essence", "name": "Essence"},
		"ore": {"id": "ore", "name": "Ore"},
		"souls": {"id": "souls", "name": "Souls"},
		"energy_regen": {"id": "energy_regen", "name": "Energy"},
		"mana": {"id": "mana", "name": "Mana"}
	}
	
	print("TerritoryManager: Using fallback role system")

# ==============================================================================
# SIMPLIFIED ROLE SYSTEM
# ==============================================================================

func get_god_available_roles(god: God) -> Array:
	"""Get roles this god can perform based on tier"""
	if not god_assignments.has("tier_bonuses"):
		return ["gatherer"]  # Fallback
	
	var tier_name = god.get_tier_name().to_lower()
	var tier_data = god_assignments["tier_bonuses"].get(tier_name, {})
	return tier_data.get("can_roles", ["gatherer"])

func get_god_role_efficiency(god: God, role: String) -> float:
	"""Get god's efficiency in specific role (simplified)"""
	var base_efficiency = 1.0
	
	# Tier bonus
	var tier_name = god.get_tier_name().to_lower()
	if god_assignments.has("tier_bonuses"):
		var tier_data = god_assignments["tier_bonuses"].get(tier_name, {})
		base_efficiency = tier_data.get("efficiency_multiplier", 1.0)
	
	# Element bonus for preferred roles
	var element_name = god.get_element_name().to_lower()
	if god_assignments.has("element_bonuses"):
		var element_data = god_assignments["element_bonuses"].get(element_name, {})
		var preferred_role = element_data.get("preferred_" + role + "_role", "")
		if not preferred_role.is_empty():
			base_efficiency += element_data.get("efficiency_bonus", 0.0)
	
	# Awakened bonus
	if god.is_awakened and god_assignments.has("awakened_bonus"):
		var awakened_data = god_assignments["awakened_bonus"]
		base_efficiency *= awakened_data.get("primary_role_efficiency", 1.5)
	
	return base_efficiency

func can_god_perform_role(god: God, role: String) -> bool:
	"""Check if god can perform specific role"""
	var available_roles = get_god_available_roles(god)
	return available_roles.has(role)

# ==============================================================================
# TERRITORY SLOT MANAGEMENT
# ==============================================================================

func get_territory_slot_configuration(territory: Territory) -> Dictionary:
	"""Get slot configuration for territory"""
	if not slot_configuration.has("base_slots"):
		return {"gatherer_slots": 2, "crafter_slots": 1, "defender_slots": 1}
	
	var base_slots_key = "tier_%d" % territory.tier
	var base_slots = slot_configuration["base_slots"].get(base_slots_key, {})
	
	# Add upgrade bonuses
	var upgrade_bonuses = calculate_slot_upgrades(territory)
	var final_slots = {}
	
	for slot_type in ["gatherer_slots", "crafter_slots", "defender_slots"]:
		final_slots[slot_type] = base_slots.get(slot_type, 0) + upgrade_bonuses.get(slot_type, 0)
	
	return final_slots

func calculate_slot_upgrades(territory: Territory) -> Dictionary:
	"""Calculate bonus slots from territory level"""
	var bonuses = {"gatherer_slots": 0, "crafter_slots": 0, "defender_slots": 0}
	
	if not slot_configuration.has("upgrade_bonuses"):
		return bonuses
	
	var upgrade_data = slot_configuration["upgrade_bonuses"]
	var level = territory.territory_level
	
	# Per 5 levels bonus
	if upgrade_data.has("per_5_levels"):
		var bonus_5 = upgrade_data["per_5_levels"]
		var multiplier = level / 5
		for slot_type in bonus_5:
			bonuses[slot_type] += bonus_5[slot_type] * multiplier
	
	# Per 10 levels bonus  
	if upgrade_data.has("per_10_levels"):
		var bonus_10 = upgrade_data["per_10_levels"]
		var multiplier = level / 10
		for slot_type in bonus_10:
			bonuses[slot_type] += bonus_10[slot_type] * multiplier
	
	# Per 15 levels bonus
	if upgrade_data.has("per_15_levels"):
		var bonus_15 = upgrade_data["per_15_levels"]
		var multiplier = level / 15
		for slot_type in bonus_15:
			bonuses[slot_type] += bonus_15[slot_type] * multiplier
	
	return bonuses

func get_territory_role_assignments(territory: Territory) -> Dictionary:
	"""Get current god assignments by role for territory"""
	var assignments = {"gatherer": [], "crafter": [], "defender": []}
	
	if not GameManager or not GameManager.player_data:
		return assignments
	
	for god in GameManager.player_data.gods:
		if god.stationed_territory == territory.id:
			var role = god.get_meta("territory_role", "")
			if assignments.has(role):
				assignments[role].append(god)
	
	return assignments

# ==============================================================================
# RESOURCE GENERATION SYSTEM (SIMPLIFIED)
# ==============================================================================

func calculate_territory_passive_generation(territory: Territory) -> Dictionary:
	"""Calculate total passive resource generation for territory - ONLY if gods are slotted"""
	var total_generation = {}
	
	if not territory.is_controlled_by_player():
		return total_generation
	
	var role_assignments = get_territory_role_assignments(territory)
	
	# NO BASE GENERATION - only god-generated resources
	# Gatherers produce resources
	for god in role_assignments.get("gatherer", []):
		var god_production = calculate_god_gatherer_production(god, territory)
		for resource in god_production:
			total_generation[resource] = total_generation.get(resource, 0) + god_production[resource]
	
	return total_generation

func calculate_god_gatherer_production(god: God, territory: Territory) -> Dictionary:
	"""Calculate what a specific gatherer god produces"""
	var production = {}
	
	# Get god's preferred gatherer role based on element
	var element_name = god.get_element_name().to_lower()
	var preferred_role = "cultist"  # Default
	
	if god_assignments.has("element_bonuses"):
		var element_data = god_assignments["element_bonuses"].get(element_name, {})
		preferred_role = element_data.get("preferred_gatherer_role", "cultist")
	
	# Get base production from role
	if territory_roles.has("gatherer") and territory_roles["gatherer"].has("sub_roles"):
		var sub_roles = territory_roles["gatherer"]["sub_roles"]
		if sub_roles.has(preferred_role):
			var role_data = sub_roles[preferred_role]
			var base_production = role_data.get("base_production", {})
			
			# Apply god efficiency
			var efficiency = get_god_role_efficiency(god, "gatherer")
			
			for resource in base_production:
				var amount = int(base_production[resource] * efficiency)
				production[resource] = amount
	
	return production

func get_base_territory_generation(territory: Territory) -> Dictionary:
	"""Base generation is now ZERO - only gods generate resources"""
	return {}

func calculate_god_contribution(god: God, role: String, territory: Territory) -> Dictionary:
	"""Calculate what this god will contribute in this role"""
	match role:
		"gatherer":
			return calculate_god_gatherer_production(god, territory)
		"crafter":
			return {}  # Crafters don't generate resources, they convert
		"defender":
			return {}  # Defenders provide protection, not resources
		_:
			return {}

# ==============================================================================
# CRAFTER SYSTEM
# ==============================================================================

func get_god_crafter_recipes(god: God) -> Array:
	"""Get available crafting recipes for this god"""
	var recipes = []
	
	# Get god's preferred crafter role based on element
	var element_name = god.get_element_name().to_lower()
	var preferred_role = "alchemist"  # Default
	
	if god_assignments.has("element_bonuses"):
		var element_data = god_assignments["element_bonuses"].get(element_name, {})
		preferred_role = element_data.get("preferred_crafter_role", "alchemist")
	
	# Get recipes from role
	if territory_roles.has("crafter") and territory_roles["crafter"].has("sub_roles"):
		var sub_roles = territory_roles["crafter"]["sub_roles"]
		if sub_roles.has(preferred_role):
			var role_data = sub_roles[preferred_role]
			recipes = role_data.get("conversion_recipes", [])
	
	return recipes

# ==============================================================================
# DEFENDER SYSTEM
# ==============================================================================

func get_god_defender_effects(god: God) -> Dictionary:
	"""Get defensive effects this god provides"""
	var effects = {}
	
	# Get god's preferred defender role based on element
	var element_name = god.get_element_name().to_lower()
	var preferred_role = "guardian"  # Default
	
	if god_assignments.has("element_bonuses"):
		var element_data = god_assignments["element_bonuses"].get(element_name, {})
		preferred_role = element_data.get("preferred_defender_role", "guardian")
	
	# Get effects from role
	if territory_roles.has("defender") and territory_roles["defender"].has("sub_roles"):
		var sub_roles = territory_roles["defender"]["sub_roles"]
		if sub_roles.has(preferred_role):
			var role_data = sub_roles[preferred_role]
			effects = role_data.get("effects", {})
	
	# Apply god efficiency multiplier
	var efficiency = get_god_role_efficiency(god, "defender")
	for effect in effects:
		if typeof(effects[effect]) == TYPE_INT or typeof(effects[effect]) == TYPE_FLOAT:
			effects[effect] = effects[effect] * efficiency
	
	return effects

# ==============================================================================
# ASSIGNMENT SYSTEM
# ==============================================================================

func assign_god_to_territory_role(god: God, territory: Territory, role: String) -> bool:
	"""Assign god to territory in specific role"""
	if not can_god_perform_role(god, role):
		print("God %s cannot perform role %s" % [god.name, role])
		return false
	
	# Check slot availability
	var slot_config = get_territory_slot_configuration(territory)
	var current_assignments = get_territory_role_assignments(territory)
	
	var slot_type = role + "_slots"
	if current_assignments[role].size() >= slot_config.get(slot_type, 0):
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
	cache_update_time = 0.0

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

func get_territory_efficiency_summary(territory: Territory) -> Dictionary:
	"""Get efficiency summary for territory"""
	var role_assignments = get_territory_role_assignments(territory)
	var total_generation = calculate_territory_passive_generation(territory)
	var slot_config = get_territory_slot_configuration(territory)
	
	return {
		"total_generation": total_generation,
		"slot_usage": {
			"gatherer": "%d/%d" % [role_assignments["gatherer"].size(), slot_config["gatherer_slots"]],
			"crafter": "%d/%d" % [role_assignments["crafter"].size(), slot_config["crafter_slots"]],
			"defender": "%d/%d" % [role_assignments["defender"].size(), slot_config["defender_slots"]]
		},
		"efficiency_rating": calculate_overall_efficiency(territory)
	}

func calculate_overall_efficiency(territory: Territory) -> float:
	"""Calculate overall territory efficiency rating"""
	var role_assignments = get_territory_role_assignments(territory)
	var slot_config = get_territory_slot_configuration(territory)
	var total_efficiency = 0.0
	var total_slots = 0
	
	for role in ["gatherer", "crafter", "defender"]:
		var assigned_gods = role_assignments[role]
		var available_slots = slot_config[role + "_slots"]
		
		for god in assigned_gods:
			total_efficiency += get_god_role_efficiency(god, role)
		
		total_slots += available_slots
	
	return total_efficiency / max(total_slots, 1)

func print_territory_debug(territory: Territory):
	"""Debug information for territory"""
	print("=== Territory Debug: %s ===" % territory.name)
	var role_assignments = get_territory_role_assignments(territory)
	var generation = calculate_territory_passive_generation(territory)
	
	print("Generation: %s" % generation)
	for role in role_assignments:
		var god_names = []
		for god in role_assignments[role]:
			god_names.append(god.name)
		print("%s (%d): %s" % [role.capitalize(), role_assignments[role].size(), god_names])
