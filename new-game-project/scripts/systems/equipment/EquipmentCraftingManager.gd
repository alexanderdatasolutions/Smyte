# scripts/systems/collection/EquipmentCraftingManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - equipment crafting only
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentCraftingManager

"""
Equipment Crafting Management System
Handles equipment creation from recipes, territory requirements, and crafting validation
Part of the equipment system (like Summoners War equipment crafting)
"""

# Signals for crafting events
signal equipment_crafted(equipment: Equipment, recipe_id: String)
signal crafting_failed(recipe_id: String, reason: String)
signal recipe_unlocked(recipe_id: String)

# Configuration cache
var equipment_config: Dictionary = {}
var resource_config: Dictionary = {}
var resources_data: Dictionary = {}

func _ready():
	"""Initialize equipment crafting manager"""
	load_crafting_config()

func load_crafting_config():
	"""Load crafting configuration from JSON files - RULE 5: Use SystemRegistry"""
	# Load equipment config through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var config_manager = system_registry.get_system("ConfigurationManager")
		if config_manager:
			equipment_config = config_manager.get_equipment_config()
			resource_config = config_manager.get_resources_config()
			resources_data = config_manager.get_resources_config()  # Same as resource_config
			return
	
	# Fallback to direct loading
	_load_configs_directly()

func _load_configs_directly():
	"""Fallback method to load configs directly"""
	# Load equipment config
	var equipment_file = FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
	if equipment_file:
		var json_string = equipment_file.get_as_text()
		equipment_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			equipment_config = json.get_data()
	
	# Load resource config
	var resource_file = FileAccess.open("res://data/resource_config.json", FileAccess.READ)
	if resource_file:
		var json_string = resource_file.get_as_text()
		resource_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			resource_config = json.get_data()
	
	# Load resources data
	var resources_file = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if resources_file:
		var json_string = resources_file.get_as_text()
		resources_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			resources_data = json.get_data()

# === CRAFTING VALIDATION ===

func can_craft_equipment(recipe_id: String, territory_id: String = "") -> Dictionary:
	"""Check if player can craft equipment with given recipe - RULE 2: Single responsibility"""
	if not equipment_config.has("crafting_recipes"):
		return {"can_craft": false, "reason": "No crafting recipes available"}
	
	var recipes = equipment_config.crafting_recipes
	if not recipes.has(recipe_id):
		return {"can_craft": false, "reason": "Recipe not found"}
	
	var recipe = recipes[recipe_id]
	
	# Check territory requirements
	if recipe.get("territory_required", false):
		if territory_id == "":
			return {"can_craft": false, "reason": "Territory required for crafting"}
		
		var tier_required = recipe.get("territory_tier_requirement", 1)
		if not _territory_meets_tier_requirement(territory_id, tier_required):
			return {"can_craft": false, "reason": "Territory tier too low"}
	
	# Check god level requirements
	var god_level_required = recipe.get("god_level_requirement", 0)
	if god_level_required > 0:
		if not _has_god_meeting_level_requirement(god_level_required):
			return {"can_craft": false, "reason": "No god meets level requirement"}
	
	# Check awakened god requirement
	if recipe.get("awakened_god_required", false):
		if not _has_awakened_god():
			return {"can_craft": false, "reason": "Awakened god required"}
	
	# Check materials
	var materials_needed = recipe.get("materials", {})
	var missing_materials = _check_materials_availability(materials_needed)
	if not missing_materials.is_empty():
		return {"can_craft": false, "reason": "Missing materials", "missing": missing_materials}
	
	return {"can_craft": true, "recipe": recipe}

func _territory_meets_tier_requirement(territory_id: String, tier_required: int) -> bool:
	"""Check if territory meets tier requirement - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			return territory_manager.get_territory_tier(territory_id) >= tier_required
	
	# Fallback - assume tier 1 territories
	return tier_required <= 1

func _has_god_meeting_level_requirement(level_required: int) -> bool:
	"""Check if player has god meeting level requirement - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var collection_manager = system_registry.get_system("CollectionManager")
		if collection_manager:
			var gods = collection_manager.get_all_gods()
			for god in gods:
				if god.level >= level_required:
					return true
	
	return false

func _has_awakened_god() -> bool:
	"""Check if player has any awakened god - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var collection_manager = system_registry.get_system("CollectionManager")
		if collection_manager:
			var gods = collection_manager.get_all_gods()
			for god in gods:
				if god.is_awakened:
					return true
	
	return false

func _check_materials_availability(materials_needed: Dictionary) -> Array:
	"""Check what materials are missing - RULE 5: Use SystemRegistry"""
	var missing: Array = []
	
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager:
			for material_id in materials_needed:
				var needed_amount = materials_needed[material_id]
				var current_amount = resource_manager.get_resource(material_id)
				if current_amount < needed_amount:
					missing.append({
						"material": material_id,
						"needed": needed_amount,
						"have": current_amount,
						"missing": needed_amount - current_amount
					})
	
	return missing

# === CRAFTING EXECUTION ===

func craft_equipment(recipe_id: String, crafting_god_id: String = "", territory_id: String = "") -> Equipment:
	"""Craft equipment using specified recipe - RULE 2: Single responsibility"""
	var craft_check = can_craft_equipment(recipe_id, territory_id)
	if not craft_check.can_craft:
		push_error("EquipmentCraftingManager: Cannot craft equipment - " + craft_check.reason)
		crafting_failed.emit(recipe_id, craft_check.reason)
		return null
	
	var recipe = craft_check.recipe
	
	# Pay materials cost
	var materials_cost = recipe.get("materials", {})
	if not _pay_materials_cost(materials_cost, crafting_god_id):
		push_error("EquipmentCraftingManager: Failed to pay materials cost")
		crafting_failed.emit(recipe_id, "Insufficient materials")
		return null
	
	# Create equipment
	var equipment = _create_equipment_from_recipe(recipe, recipe_id)
	if equipment == null:
		push_error("EquipmentCraftingManager: Failed to create equipment")
		crafting_failed.emit(recipe_id, "Equipment creation failed")
		return null
	
	# Add to inventory through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var inventory_manager = system_registry.get_system("EquipmentInventoryManager")
		if inventory_manager:
			inventory_manager.add_equipment_to_inventory(equipment)
	
	# Emit crafting signal
	equipment_crafted.emit(equipment, recipe_id)

	return equipment

func _create_equipment_from_recipe(recipe: Dictionary, recipe_id: String) -> Equipment:
	"""Create equipment from recipe data"""
	var equipment_type = recipe.get("equipment_type", "WEAPON")
	var rarity = recipe.get("rarity", "COMMON")
	var level = recipe.get("level", 1)
	
	# Create base equipment
	var equipment = Equipment.create_from_dungeon("crafted_" + recipe_id, equipment_type, rarity, level)
	if equipment == null:
		return null
	
	# Apply recipe-specific bonuses
	var stat_bonuses = recipe.get("stat_bonuses", {})
	for stat_name in stat_bonuses:
		var bonus_value = stat_bonuses[stat_name]
		equipment.add_stat_bonus(stat_name, bonus_value)
	
	# Apply recipe-specific substats
	var guaranteed_substats = recipe.get("guaranteed_substats", [])
	for substat_data in guaranteed_substats:
		equipment.add_substat(substat_data.stat, substat_data.value)
	
	return equipment

func _pay_materials_cost(materials_cost: Dictionary, crafting_god_id: String) -> bool:
	"""Pay the materials cost for crafting - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return false
	
	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return false
	
	# Check if we can afford all materials first
	for material_id in materials_cost:
		var needed_amount = materials_cost[material_id]
		var current_amount = resource_manager.get_resource(material_id)
		if current_amount < needed_amount:
			return false
	
	# Pay all materials
	for material_id in materials_cost:
		var needed_amount = materials_cost[material_id]
		if not resource_manager.spend_resource(material_id, needed_amount):
			# This shouldn't happen since we checked above, but safety first
			push_error("EquipmentCraftingManager: Failed to spend material: " + material_id)
			return false
	
	# Apply crafting god bonus if specified
	if crafting_god_id != "":
		_apply_crafting_god_bonus(crafting_god_id)
	
	return true

func _apply_crafting_god_bonus(god_id: String):
	"""Apply bonus effects from crafting god - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var collection_manager = system_registry.get_system("CollectionManager")
		if collection_manager:
			var god = collection_manager.get_god_by_id(god_id)
			if god and god.level > 1:
				# Higher level gods get exp from crafting
				var exp_gained = 10 + (god.level * 2)
				collection_manager.add_god_exp(god_id, exp_gained)

# === RECIPE MANAGEMENT ===

func get_available_recipes(territory_id: String = "") -> Array:
	"""Get available crafting recipes for current territory - RULE 2: Single responsibility"""
	var available: Array = []  # Array[String]
	
	if not equipment_config.has("crafting_recipes"):
		return available
	
	for recipe_id in equipment_config.crafting_recipes:
		var craft_check = can_craft_equipment(recipe_id, territory_id)
		if craft_check.can_craft:
			available.append(recipe_id)
	
	return available

func get_all_recipes() -> Array:
	"""Get all crafting recipes regardless of availability"""
	if not equipment_config.has("crafting_recipes"):
		return []
	
	return equipment_config.crafting_recipes.keys()

func get_recipe_details(recipe_id: String) -> Dictionary:
	"""Get detailed information about a recipe"""
	if not equipment_config.has("crafting_recipes"):
		return {}
	
	var recipes = equipment_config.crafting_recipes
	if not recipes.has(recipe_id):
		return {}
	
	return recipes[recipe_id].duplicate()

func get_recipes_for_equipment_type(equipment_type: String) -> Array:
	"""Get all recipes that create specific equipment type"""
	var filtered: Array = []
	
	if not equipment_config.has("crafting_recipes"):
		return filtered
	
	for recipe_id in equipment_config.crafting_recipes:
		var recipe = equipment_config.crafting_recipes[recipe_id]
		if recipe.get("equipment_type", "") == equipment_type:
			filtered.append(recipe_id)
	
	return filtered

func get_recipes_for_rarity(rarity: String) -> Array:
	"""Get all recipes that create specific rarity"""
	var filtered: Array = []
	
	if not equipment_config.has("crafting_recipes"):
		return filtered
	
	for recipe_id in equipment_config.crafting_recipes:
		var recipe = equipment_config.crafting_recipes[recipe_id]
		if recipe.get("rarity", "") == rarity:
			filtered.append(recipe_id)
	
	return filtered

# === UTILITY METHODS ===

func get_crafting_cost_summary(recipe_id: String) -> Dictionary:
	"""Get summary of crafting costs"""
	var recipe = get_recipe_details(recipe_id)
	if recipe.is_empty():
		return {}
	
	var summary = {
		"materials": recipe.get("materials", {}),
		"total_cost": 0,
		"affordable": true
	}
	
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager:
			for material_id in summary.materials:
				var needed = summary.materials[material_id]
				var have = resource_manager.get_resource(material_id)
				summary.total_cost += needed
				if have < needed:
					summary.affordable = false
	
	return summary

func unlock_recipe(recipe_id: String):
	"""Unlock a recipe for crafting"""
	# This would typically be called when certain conditions are met
	# For now, just emit the signal
	recipe_unlocked.emit(recipe_id)

# === TESTING METHODS ===

func _test_crafting_operations():
	"""Test crafting operations"""
	var test_recipes = get_all_recipes()
	if test_recipes.size() > 0:
		var test_recipe = test_recipes[0]
		var _craft_check = can_craft_equipment(test_recipe)
