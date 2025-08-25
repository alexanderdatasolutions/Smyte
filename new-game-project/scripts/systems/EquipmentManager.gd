# scripts/systems/EquipmentManager.gd
extends Node
class_name EquipmentManager

signal equipment_equipped(god: God, equipment: Equipment, slot: int)
signal equipment_unequipped(god: God, slot: int)
signal equipment_enhanced(equipment: Equipment, success: bool)
signal equipment_crafted(equipment: Equipment, recipe_id: String)
signal socket_unlocked(equipment: Equipment, socket_index: int)
signal gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary)

var equipment_inventory: Array[Equipment] = []
var gems_inventory: Array[Dictionary] = []

# Configuration cache
var equipment_config: Dictionary = {}
var resource_config: Dictionary = {}
var resources_data: Dictionary = {}

func _ready():
	load_equipment_config()

func load_equipment_config():
	"""Load equipment configuration from JSON files"""
	Equipment.load_equipment_config()
	equipment_config = Equipment.equipment_config
	
	# Load resource config for equipment integration
	var resource_file = FileAccess.open("res://data/resource_config.json", FileAccess.READ)
	if resource_file:
		var json_string = resource_file.get_as_text()
		resource_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			resource_config = json.get_data()
		else:
			push_error("Failed to parse resource_config.json")
	else:
		push_error("Failed to load resource_config.json")
	
	# Load resources data for crafting
	_load_resources_data()
	
	print("EquipmentManager: Loaded equipment configuration")
	print("  - Equipment Types: ", equipment_config.get("equipment_types", {}).size())
	print("  - Crafting Recipes: ", equipment_config.get("crafting_recipes", {}).size())

func _load_resources_data():
	"""Load resources data from resources.json"""
	var file = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if not file:
		push_error("Failed to load resources.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse resources.json: " + json.error_string)
		return
	
	resources_data = json.get_data()

# EQUIPMENT INVENTORY MANAGEMENT

func add_equipment_to_inventory(equipment: Equipment):
	"""Add equipment to player inventory"""
	if equipment == null:
		push_error("Cannot add null equipment to inventory")
		return
	
	equipment_inventory.append(equipment)
	print("EquipmentManager: Added ", equipment.get_display_name(), " to inventory")

func remove_equipment_from_inventory(equipment: Equipment) -> bool:
	"""Remove equipment from inventory"""
	var index = equipment_inventory.find(equipment)
	if index == -1:
		return false
	
	equipment_inventory.remove_at(index)
	return true

func get_equipment_by_id(equipment_id: String) -> Equipment:
	"""Find equipment by ID"""
	for equipment in equipment_inventory:
		if equipment.id == equipment_id:
			return equipment
	return null

func get_equipment_by_slot_type(slot_type: Equipment.EquipmentType) -> Array[Equipment]:
	"""Get all equipment of specific slot type"""
	var filtered: Array[Equipment] = []
	for equipment in equipment_inventory:
		if equipment.type == slot_type:
			filtered.append(equipment)
	return filtered

# CRAFTING SYSTEM

func can_craft_equipment(recipe_id: String, territory_id: String = "") -> Dictionary:
	"""Check if player can craft equipment with given recipe"""
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
		
		# Check territory tier requirement
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

func craft_equipment(recipe_id: String, crafting_god_id: String = "", territory_id: String = "") -> Equipment:
	"""Craft equipment using specified recipe"""
	var craft_check = can_craft_equipment(recipe_id, territory_id)
	if not craft_check.can_craft:
		push_error("Cannot craft equipment: " + craft_check.reason)
		return null
	
	var recipe = craft_check.recipe
	
	# Pay materials cost
	var materials_cost = recipe.get("materials", {})
	if not _pay_materials_cost(materials_cost, crafting_god_id):
		push_error("Failed to pay materials cost")
		return null
	
	# Create equipment
	var equipment = Equipment.create_from_dungeon("crafted_" + recipe_id, recipe.equipment_type, recipe.rarity, 1)
	if equipment == null:
		push_error("Failed to create equipment")
		return null
	
	# Add to inventory
	add_equipment_to_inventory(equipment)
	
	# Emit crafting signal
	equipment_crafted.emit(equipment, recipe_id)
	
	print("EquipmentManager: Successfully crafted ", equipment.get_display_name())
	return equipment

func get_available_recipes(territory_id: String = "") -> Array[String]:
	"""Get list of recipes player can currently craft"""
	var available: Array[String] = []
	
	if not equipment_config.has("crafting_recipes"):
		return available
	
	for recipe_id in equipment_config.crafting_recipes:
		var craft_check = can_craft_equipment(recipe_id, territory_id)
		if craft_check.can_craft:
			available.append(recipe_id)
	
	return available

# ENHANCEMENT SYSTEM

func enhance_equipment(equipment: Equipment, use_blessed_oil: bool = false) -> bool:
	"""Attempt to enhance equipment"""
	if equipment == null:
		return false
	
	if not equipment.can_be_enhanced():
		print("EquipmentManager: Equipment cannot be enhanced further")
		return false
	
	var enhancement_cost = equipment.get_enhancement_cost()
	if not _can_afford_cost(enhancement_cost):
		print("EquipmentManager: Cannot afford enhancement cost")
		return false
	
	var success_rate = equipment.get_enhancement_success_rate()
	
	# Apply blessed oil bonus
	if use_blessed_oil:
		if not GameManager.player_data.has_resource("blessed_oil", 1):
			print("EquipmentManager: No blessed oil available")
			return false
		
		success_rate += equipment_config.enhancement_system.get("blessed_oil_bonus", 20) / 100.0
		success_rate = min(success_rate, 1.0)
	
	# Pay the cost
	_pay_cost(enhancement_cost)
	if use_blessed_oil:
		GameManager.player_data.spend_resource("blessed_oil", 1)
	
	# Roll for success
	var success = randf() <= success_rate
	
	if success:
		equipment.enhancement_level += 1
		print("EquipmentManager: Enhancement successful! ", equipment.get_display_name())
	else:
		print("EquipmentManager: Enhancement failed!")
		_handle_enhancement_failure(equipment, use_blessed_oil)
	
	equipment_enhanced.emit(equipment, success)
	return success

func _handle_enhancement_failure(equipment: Equipment, used_blessed_oil: bool):
	"""Handle what happens when enhancement fails"""
	if used_blessed_oil:
		return  # Blessed oil prevents consequences
	
	var failure_consequences = equipment_config.enhancement_system.get("failure_consequences", {})
	var rarity_name = Equipment.rarity_to_string(equipment.rarity)
	var consequence = failure_consequences.get(rarity_name, "none")
	
	if consequence == "none":
		return
	
	# Parse consequence (e.g., "level_reset_chance_30")
	if consequence.begins_with("level_reset_chance_"):
		var chance_str = consequence.replace("level_reset_chance_", "")
		var chance = int(chance_str) / 100.0
		
		if randf() <= chance:
			equipment.enhancement_level = 0
			print("EquipmentManager: Enhancement level reset due to failure!")

# SOCKET SYSTEM

func unlock_socket(equipment: Equipment, socket_index: int) -> bool:
	"""Unlock a socket on equipment"""
	if equipment == null:
		return false
	
	if not equipment.can_unlock_socket(socket_index):
		print("EquipmentManager: Cannot unlock socket ", socket_index)
		return false
	
	var unlock_cost = equipment.get_socket_unlock_cost(socket_index)
	if not _can_afford_cost(unlock_cost):
		print("EquipmentManager: Cannot afford socket unlock cost")
		return false
	
	# Pay cost and unlock socket
	_pay_cost(unlock_cost)
	
	# Add new socket
	var type_name = Equipment.type_to_string(equipment.type)
	var socket_types = equipment_config.equipment_types[type_name].get("socket_types", ["universal"])
	var socket_type = socket_types[randi() % socket_types.size()]
	
	equipment.socket_slots.append({
		"type": socket_type,
		"gem": {},
		"unlocked": true
	})
	
	socket_unlocked.emit(equipment, socket_index)
	print("EquipmentManager: Unlocked socket ", socket_index, " on ", equipment.get_display_name())
	return true

func socket_gem(equipment: Equipment, socket_index: int, gem_id: String) -> bool:
	"""Socket a gem into equipment"""
	if equipment == null or socket_index >= equipment.socket_slots.size():
		return false
	
	var socket = equipment.socket_slots[socket_index]
	if not socket.get("unlocked", false):
		print("EquipmentManager: Socket not unlocked")
		return false
	
	if not socket.gem.is_empty():
		print("EquipmentManager: Socket already occupied")
		return false
	
	# Check if player has the gem
	if not _has_gem_in_inventory(gem_id):
		print("EquipmentManager: Gem not found in inventory")
		return false
	
	# Check compatibility
	if not _is_gem_compatible_with_socket(gem_id, socket.type):
		print("EquipmentManager: Gem not compatible with socket type")
		return false
	
	# Remove gem from inventory and socket it
	_consume_gem_from_inventory(gem_id)
	socket.gem = {"id": gem_id}
	
	gem_socketed.emit(equipment, socket_index, socket.gem)
	print("EquipmentManager: Socketed ", gem_id, " into ", equipment.get_display_name())
	return true

func unsocket_gem(equipment: Equipment, socket_index: int) -> Dictionary:
	"""Remove gem from socket"""
	if equipment == null or socket_index >= equipment.socket_slots.size():
		return {}
	
	var socket = equipment.socket_slots[socket_index]
	var gem = socket.get("gem", {})
	
	if gem.is_empty():
		return {}
	
	# Add gem back to inventory
	gems_inventory.append(gem)
	
	# Clear socket
	socket.gem = {}
	
	print("EquipmentManager: Removed gem from ", equipment.get_display_name())
	return gem

# UTILITY METHODS

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford given cost"""
	if not GameManager or not GameManager.player_data:
		return false
	
	for resource_id in cost:
		var amount_needed = cost[resource_id]
		if not GameManager.player_data.has_resource(resource_id, amount_needed):
			return false
	
	return true

func _pay_cost(cost: Dictionary):
	"""Pay the specified cost"""
	if not GameManager or not GameManager.player_data:
		return
	
	for resource_id in cost:
		var amount = cost[resource_id]
		GameManager.player_data.spend_resource(resource_id, amount)

func _pay_materials_cost(materials: Dictionary, crafting_god_id: String = "") -> bool:
	"""Pay materials cost with god efficiency bonuses"""
	var effective_cost = materials.duplicate()
	
	# Apply god efficiency bonuses
	if crafting_god_id != "" and resource_config.has("crafting_god_specializations"):
		var specializations = resource_config.crafting_god_specializations
		if specializations.has(crafting_god_id):
			var god_spec = specializations[crafting_god_id]
			var efficiency = god_spec.get("bonus_efficiency", 1.0)
			
			# Reduce material costs
			for material_id in effective_cost:
				effective_cost[material_id] = int(effective_cost[material_id] / efficiency)
	
	if not _can_afford_cost(effective_cost):
		return false
	
	_pay_cost(effective_cost)
	return true

func _check_materials_availability(materials: Dictionary) -> Array[String]:
	"""Check which materials are missing"""
	var missing: Array[String] = []
	
	for material_id in materials:
		var amount_needed = materials[material_id]
		if not GameManager.player_data.has_resource(material_id, amount_needed):
			missing.append(material_id)
	
	return missing

func _territory_meets_tier_requirement(_territory_id: String, _tier_required: int) -> bool:
	"""Check if territory meets tier requirement"""
	# This would integrate with your territory system
	# For now, assume all territories meet requirements
	return true

func _has_god_meeting_level_requirement(_level_required: int) -> bool:
	"""Check if player has any god meeting level requirement"""
	# This would integrate with your god system
	# For now, return true
	return true

func _has_awakened_god() -> bool:
	"""Check if player has any awakened gods"""
	# This would integrate with your god system
	# For now, return true
	return true

func _has_gem_in_inventory(gem_id: String) -> bool:
	"""Check if gem is available in inventory"""
	if GameManager and GameManager.player_data:
		return GameManager.player_data.has_resource(gem_id, 1)
	return false

func _consume_gem_from_inventory(gem_id: String):
	"""Remove gem from inventory"""
	if GameManager and GameManager.player_data:
		GameManager.player_data.spend_resource(gem_id, 1)

func _is_gem_compatible_with_socket(gem_id: String, socket_type: String) -> bool:
	"""Check if gem can be socketed into specific socket type"""
	if not equipment_config.has("socket_system"):
		return false
	
	var gemstone_effects = equipment_config.socket_system.get("gemstone_effects", {})
	if not gemstone_effects.has(gem_id):
		return false
	
	var compatible_sockets = gemstone_effects[gem_id].get("compatible_sockets", [])
	return socket_type in compatible_sockets

# LOOT INTEGRATION

func create_equipment_from_loot(dungeon_id: String, _difficulty: String) -> Equipment:
	"""Create equipment from loot system"""
	var equipment = Equipment.create_from_dungeon(dungeon_id, "weapon", "common", 1)  # Default values, should be improved
	return equipment

# SAVE/LOAD SYSTEM

func save_equipment_data() -> Dictionary:
	"""Save equipment inventory to dictionary"""
	var data = {
		"equipment_inventory": [],
		"gems_inventory": gems_inventory.duplicate()
	}
	
	for equipment in equipment_inventory:
		data.equipment_inventory.append(_equipment_to_dict(equipment))
	
	return data

func load_equipment_data(data: Dictionary):
	"""Load equipment inventory from dictionary"""
	equipment_inventory.clear()
	
	if data.has("equipment_inventory"):
		for equipment_data in data.equipment_inventory:
			var equipment = _dict_to_equipment(equipment_data)
			if equipment:
				equipment_inventory.append(equipment)
	
	if data.has("gems_inventory"):
		gems_inventory = data.gems_inventory.duplicate()

func _equipment_to_dict(equipment: Equipment) -> Dictionary:
	"""Convert equipment to dictionary for saving"""
	return {
		"id": equipment.id,
		"equipment_type": equipment.type,
		"rarity": equipment.rarity,
		"level": equipment.level,
		"enhancement_level": equipment.enhancement_level,
		"primary_stat": equipment.primary_stat,
		"primary_stat_value": equipment.primary_stat_value,
		"substats": equipment.substats.duplicate(),
		"base_stats": equipment.base_stats.duplicate(),
		"socket_slots": equipment.socket_slots.duplicate(),
		"max_sockets": equipment.max_sockets,
		"crafted_by_god": equipment.crafted_by_god,
		"crafted_in_territory": equipment.crafted_in_territory,
		"creation_date": equipment.creation_date
	}

func _dict_to_equipment(dict: Dictionary) -> Equipment:
	"""Convert dictionary to equipment for loading"""
	var equipment = Equipment.new()
	
	equipment.id = dict.get("id", "")
	equipment.type = dict.get("equipment_type", Equipment.EquipmentType.WEAPON)
	equipment.rarity = Equipment.string_to_rarity(dict.get("rarity", "common"))
	equipment.level = dict.get("level", 1)
	equipment.enhancement_level = dict.get("enhancement_level", 0)
	equipment.primary_stat = dict.get("primary_stat", "")
	equipment.primary_stat_value = dict.get("primary_stat_value", 0)
	equipment.substats = dict.get("substats", {}).duplicate()
	equipment.base_stats = dict.get("base_stats", {}).duplicate()
	equipment.socket_slots = dict.get("socket_slots", []).duplicate()
	equipment.max_sockets = dict.get("max_sockets", 0)
	equipment.crafted_by_god = dict.get("crafted_by_god", "")
	equipment.crafted_in_territory = dict.get("crafted_in_territory", "")
	equipment.creation_date = dict.get("creation_date", "")
	
	return equipment

# EQUIPPING AND UNEQUIPPING

func equip_equipment(god: God, equipment: Equipment) -> bool:
	"""Equip equipment to a god"""
	if not god or not equipment:
		push_error("Invalid god or equipment for equipping")
		return false
	
	# Check if equipment exists in inventory
	if not equipment_inventory.has(equipment):
		push_error("Equipment not found in inventory")
		return false
	
	var slot = equipment.slot - 1  # Convert to 0-based index
	if slot < 0 or slot >= god.equipped_runes.size():
		push_error("Invalid equipment slot: " + str(slot))
		return false
	
	# Unequip current equipment if any
	if god.equipped_runes[slot] != null:
		unequip_equipment(god, slot)
	
	# Equip new equipment
	god.equipped_runes[slot] = equipment
	remove_equipment_from_inventory(equipment)
	
	equipment_equipped.emit(god, equipment, slot)
	print("Equipped ", equipment.get_display_name(), " to ", god.name, " slot ", slot + 1)
	return true

func unequip_equipment(god: God, slot: int) -> Equipment:
	"""Unequip equipment from a god slot"""
	if not god:
		push_error("Invalid god for unequipping")
		return null
	
	if slot < 0 or slot >= god.equipped_runes.size():
		push_error("Invalid equipment slot: " + str(slot))
		return null
	
	var equipment = god.equipped_runes[slot]
	if equipment == null:
		return null
	
	# Remove from god
	god.equipped_runes[slot] = null
	
	# Return to inventory
	add_equipment_to_inventory(equipment)
	
	equipment_unequipped.emit(god, slot)
	print("Unequipped ", equipment.get_display_name(), " from ", god.name, " slot ", slot + 1)
	return equipment

func get_equipped_set_bonuses(god: God) -> Dictionary:
	"""Calculate set bonuses for a god's equipped equipment"""
	if not god:
		return {}
	
	var set_counts = {}
	var active_bonuses = {}
	
	# Count equipped sets
	for i in range(god.equipped_runes.size()):
		var equipment = god.equipped_runes[i]
		if equipment != null:
			var set_type = equipment.equipment_set_type
			if set_type != "":
				set_counts[set_type] = set_counts.get(set_type, 0) + 1
	
	# Calculate active set bonuses
	var sets_config = equipment_config.get("equipment_sets", {})
	for set_type in set_counts:
		var set_info = sets_config.get(set_type, {})
		var pieces_required = set_info.get("pieces_required", 4)
		var equipped_pieces = set_counts[set_type]
		
		# Check if we have enough pieces for bonus
		if equipped_pieces >= pieces_required:
			var num_bonuses = equipped_pieces / pieces_required
			var set_bonus = set_info.get("set_bonus", {})
			
			for bonus_type in set_bonus:
				var bonus_value = set_bonus[bonus_type]
				if bonus_type != "special":
					active_bonuses[bonus_type] = active_bonuses.get(bonus_type, 0) + (bonus_value * num_bonuses)
				else:
					# Handle special bonuses
					if not active_bonuses.has("special_effects"):
						active_bonuses.special_effects = []
					active_bonuses.special_effects.append(bonus_value)
	
	return active_bonuses
