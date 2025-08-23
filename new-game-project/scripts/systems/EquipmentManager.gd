# scripts/systems/EquipmentManager.gd
extends Node
class_name EquipmentManager

signal equipment_equipped(god: God, equipment: Equipment, slot: int)
signal equipment_unequipped(god: God, slot: int)
signal equipment_enhanced(equipment: Equipment, success: bool)
signal socket_unlocked(equipment: Equipment, socket_index: int)
signal gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary)

var equipment_inventory: Array[Equipment] = []
var gems_inventory: Array[Dictionary] = []

# Equipment configuration cache
var equipment_config: Dictionary = {}

func _ready():
	load_equipment_config()

func load_equipment_config():
	"""Load equipment configuration from JSON"""
	Equipment.load_equipment_config()
	equipment_config = Equipment.equipment_config

# EQUIPMENT MANAGEMENT

func add_equipment_to_inventory(equipment: Equipment):
	"""Add equipment to player inventory"""
	if equipment == null:
		push_error("Tried to add null equipment to inventory")
		return
	
	equipment_inventory.append(equipment)
	print("Added to inventory: ", equipment.get_display_name())

func remove_equipment_from_inventory(equipment: Equipment) -> bool:
	"""Remove equipment from inventory"""
	var index = equipment_inventory.find(equipment)
	if index >= 0:
		equipment_inventory.remove_at(index)
		return true
	return false

func get_equipment_by_id(equipment_id: String) -> Equipment:
	"""Get equipment from inventory by ID"""
	for equipment in equipment_inventory:
		if equipment.id == equipment_id:
			return equipment
	return null

func get_equipment_by_slot_type(slot_type: Equipment.EquipmentType) -> Array[Equipment]:
	"""Get all equipment of specific slot type"""
	var result = []
	for equipment in equipment_inventory:
		if equipment.type == slot_type:
			result.append(equipment)
	return result

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

# ENHANCEMENT SYSTEM

func enhance_equipment(equipment: Equipment) -> bool:
	"""Enhance equipment by one level"""
	if not equipment:
		push_error("Invalid equipment for enhancement")
		return false
	
	if not equipment.can_enhance():
		push_error("Equipment cannot be enhanced further")
		return false
	
	# Check cost
	var cost = equipment.get_enhancement_cost()
	if not _can_afford_cost(cost):
		push_error("Cannot afford enhancement cost")
		return false
	
	# Check success chance
	var success_chance = equipment.get_enhancement_chance()
	var success = randf() <= success_chance
	
	# Pay cost regardless of success (like Summoners War)
	_pay_cost(cost)
	
	if success:
		_apply_enhancement_success(equipment)
		equipment_enhanced.emit(equipment, true)
		print("Successfully enhanced ", equipment.get_display_name(), " to +", equipment.level)
		return true
	else:
		equipment_enhanced.emit(equipment, false)
		print("Failed to enhance ", equipment.get_display_name())
		return false

func _apply_enhancement_success(equipment: Equipment):
	"""Apply enhancement success effects"""
	equipment.level += 1
	
	# Increase main stat
	var enhancement_config = equipment_config.get("enhancement_system", {})
	var main_stat_increase = enhancement_config.get("enhancement_effects", {}).get("main_stat_increase", 0.10)
	equipment.main_stat_value = int(equipment.main_stat_base * (1.0 + equipment.level * main_stat_increase))
	
	# Check if this level powers up substats
	var powerup_levels = enhancement_config.get("enhancement_effects", {}).get("substat_powerup_levels", [3, 6, 9, 12, 15])
	if powerup_levels.has(equipment.level):
		_powerup_random_substat(equipment)

func _powerup_random_substat(equipment: Equipment):
	"""Power up a random substat"""
	if equipment.substats.size() == 0:
		return
	
	var substat_index = randi() % equipment.substats.size()
	var substat = equipment.substats[substat_index]
	
	var enhancement_config = equipment_config.get("enhancement_system", {})
	var increase_range = enhancement_config.get("enhancement_effects", {}).get("substat_increase_range", [0.8, 1.2])
	var multiplier = randf_range(increase_range[0], increase_range[1])
	
	var increase = int(substat.value * 0.2 * multiplier)  # 20% increase with variance
	substat.value += max(1, increase)
	substat.powerups += 1
	
	print("Powered up ", substat.type, " by ", increase, " (now ", substat.value, ")")

# SOCKET SYSTEM

func unlock_socket(equipment: Equipment, socket_index: int) -> bool:
	"""Unlock a socket on equipment"""
	if not equipment:
		push_error("Invalid equipment for socket unlock")
		return false
	
	if socket_index < 0 or socket_index >= equipment.sockets.size():
		push_error("Invalid socket index: " + str(socket_index))
		return false
	
	var socket = equipment.sockets[socket_index]
	if socket.get("unlocked", false):
		push_error("Socket already unlocked")
		return false
	
	# Get unlock cost
	var cost = _get_socket_unlock_cost(socket_index)
	if not _can_afford_cost(cost):
		push_error("Cannot afford socket unlock cost")
		return false
	
	# Unlock socket
	_pay_cost(cost)
	socket.unlocked = true
	
	socket_unlocked.emit(equipment, socket_index)
	print("Unlocked socket ", socket_index + 1, " on ", equipment.get_display_name())
	return true

func socket_gem(equipment: Equipment, socket_index: int, gem: Dictionary) -> bool:
	"""Socket a gem into equipment"""
	if not equipment:
		push_error("Invalid equipment for gem socketing")
		return false
	
	if socket_index < 0 or socket_index >= equipment.sockets.size():
		push_error("Invalid socket index: " + str(socket_index))
		return false
	
	var socket = equipment.sockets[socket_index]
	if not socket.get("unlocked", false):
		push_error("Socket is not unlocked")
		return false
	
	if socket.get("gem") != null:
		push_error("Socket already contains a gem")
		return false
	
	# Check gem compatibility
	var socket_type = socket.get("type", "")
	if not _is_gem_compatible(gem, socket_type):
		push_error("Gem not compatible with socket type")
		return false
	
	# Remove gem from inventory
	if not gems_inventory.has(gem):
		push_error("Gem not found in inventory")
		return false
	
	gems_inventory.erase(gem)
	socket.gem = gem
	
	gem_socketed.emit(equipment, socket_index, gem)
	print("Socketed ", gem.get("name", "Unknown Gem"), " into ", equipment.get_display_name())
	return true

func unsocket_gem(equipment: Equipment, socket_index: int) -> Dictionary:
	"""Remove gem from socket (gem is destroyed)"""
	if not equipment:
		push_error("Invalid equipment for gem removal")
		return {}
	
	if socket_index < 0 or socket_index >= equipment.sockets.size():
		push_error("Invalid socket index: " + str(socket_index))
		return {}
	
	var socket = equipment.sockets[socket_index]
	var gem = socket.get("gem")
	if gem == null:
		return {}
	
	socket.gem = null
	print("Removed ", gem.get("name", "Unknown Gem"), " from ", equipment.get_display_name(), " (gem destroyed)")
	return gem

# SET BONUS CALCULATION

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

# STAT CALCULATION

func calculate_equipment_stats(god: God) -> Dictionary:
	"""Calculate total stat bonuses from all equipped equipment"""
	if not god:
		return {}
	
	var total_stats = {}
	
	# Add equipment stats
	for i in range(god.equipped_runes.size()):
		var equipment = god.equipped_runes[i]
		if equipment != null:
			var equipment_stats = equipment.get_stat_bonuses()
			for stat_type in equipment_stats:
				total_stats[stat_type] = total_stats.get(stat_type, 0) + equipment_stats[stat_type]
	
	# Add set bonuses
	var set_bonuses = get_equipped_set_bonuses(god)
	for bonus_type in set_bonuses:
		if bonus_type != "special_effects":
			total_stats[bonus_type] = total_stats.get(bonus_type, 0) + set_bonuses[bonus_type]
	
	return total_stats

# UTILITY METHODS

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford a cost"""
	if not GameManager or not GameManager.player_data:
		return false
	
	for resource_type in cost:
		var required_amount = cost[resource_type]
		var current_amount = GameManager.player_data.get_resource_amount(resource_type)
		if current_amount < required_amount:
			return false
	
	return true

func _pay_cost(cost: Dictionary):
	"""Pay a resource cost"""
	if not GameManager or not GameManager.player_data:
		return
	
	for resource_type in cost:
		var amount = cost[resource_type]
		GameManager.player_data.spend_resource(resource_type, amount)
	
	GameManager.resources_updated.emit()

func _get_socket_unlock_cost(socket_index: int) -> Dictionary:
	"""Get cost to unlock a socket"""
	var socket_costs = equipment_config.get("socketing_system", {}).get("socket_unlock_costs", {})
	var socket_key = "socket_" + str(socket_index + 1)
	return socket_costs.get(socket_key, {"divine_essence": 5000})

func _is_gem_compatible(gem: Dictionary, socket_type: String) -> bool:
	"""Check if gem is compatible with socket type"""
	var gem_socket_type = gem.get("socket_type", "")
	return gem_socket_type == socket_type or socket_type == "prismatic"

# EQUIPMENT CREATION FROM LOOT

func create_equipment_from_loot(loot_table: String, difficulty: String = "beginner") -> Equipment:
	"""Create equipment from dungeon loot - integrates with existing LootSystem"""
	# Map loot table to equipment type
	var equipment_type = "weapon"  # default
	var rarity = _determine_equipment_rarity(difficulty)
	
	# Determine equipment type from loot table
	if "divine_weapons" in loot_table:
		equipment_type = "weapon"
	elif "divine_armor" in loot_table:
		equipment_type = "armor"
	elif "divine_accessories" in loot_table:
		equipment_type = _choose_accessory_type()
	elif "divine_runes" in loot_table:
		equipment_type = _choose_random_equipment_type()
	elif "shadow_gear" in loot_table:
		equipment_type = _choose_random_equipment_type()
	
	var level = _get_equipment_level_for_difficulty(difficulty)
	return Equipment.create_from_dungeon(loot_table, equipment_type, rarity, level)

func _determine_equipment_rarity(difficulty: String) -> String:
	"""Determine equipment rarity based on difficulty"""
	var rarity_chances = {}
	
	match difficulty:
		"beginner":
			rarity_chances = {"common": 0.7, "rare": 0.25, "epic": 0.05}
		"intermediate":
			rarity_chances = {"common": 0.4, "rare": 0.45, "epic": 0.13, "legendary": 0.02}
		"advanced":
			rarity_chances = {"common": 0.2, "rare": 0.35, "epic": 0.35, "legendary": 0.09, "mythic": 0.01}
		"expert":
			rarity_chances = {"rare": 0.3, "epic": 0.45, "legendary": 0.23, "mythic": 0.02}
		"master":
			rarity_chances = {"epic": 0.4, "legendary": 0.5, "mythic": 0.1}
		_:
			rarity_chances = {"common": 0.8, "rare": 0.2}
	
	return _roll_weighted_choice(rarity_chances)

func _choose_accessory_type() -> String:
	"""Choose random accessory type"""
	var accessories = ["amulet", "ring", "helm"]
	return accessories[randi() % accessories.size()]

func _choose_random_equipment_type() -> String:
	"""Choose random equipment type"""
	var types = ["weapon", "armor", "helm", "boots", "amulet", "ring"]
	return types[randi() % types.size()]

func _get_equipment_level_for_difficulty(difficulty: String) -> int:
	"""Get equipment level based on difficulty"""
	match difficulty:
		"beginner": return randi_range(1, 3)
		"intermediate": return randi_range(3, 6)
		"advanced": return randi_range(6, 10)
		"expert": return randi_range(10, 15)
		"master": return randi_range(15, 20)
		_: return 1

func _roll_weighted_choice(weights: Dictionary) -> String:
	"""Roll a weighted random choice"""
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for choice in weights:
		current_weight += weights[choice]
		if roll <= current_weight:
			return choice
	
	# Fallback to first choice
	return weights.keys()[0] if weights.size() > 0 else "common"

# SAVE/LOAD SYSTEM

func save_equipment_data() -> Dictionary:
	"""Save equipment data for persistence"""
	var equipment_data = []
	for equipment in equipment_inventory:
		equipment_data.append(_equipment_to_dict(equipment))
	
	var gems_data = []
	for gem in gems_inventory:
		gems_data.append(gem)
	
	return {
		"equipment_inventory": equipment_data,
		"gems_inventory": gems_data
	}

func load_equipment_data(data: Dictionary):
	"""Load equipment data from save"""
	equipment_inventory.clear()
	gems_inventory.clear()
	
	# Load equipment
	var equipment_data = data.get("equipment_inventory", [])
	for equipment_dict in equipment_data:
		var equipment = _dict_to_equipment(equipment_dict)
		if equipment:
			equipment_inventory.append(equipment)
	
	# Load gems
	gems_inventory = data.get("gems_inventory", [])
	
	print("Loaded ", equipment_inventory.size(), " equipment pieces and ", gems_inventory.size(), " gems")

func _equipment_to_dict(equipment: Equipment) -> Dictionary:
	"""Convert equipment to dictionary for saving"""
	return {
		"id": equipment.id,
		"name": equipment.name,
		"type": Equipment.type_to_string(equipment.type),
		"rarity": Equipment.rarity_to_string(equipment.rarity),
		"level": equipment.level,
		"slot": equipment.slot,
		"equipment_set_name": equipment.equipment_set_name,
		"equipment_set_type": equipment.equipment_set_type,
		"main_stat_type": equipment.main_stat_type,
		"main_stat_value": equipment.main_stat_value,
		"main_stat_base": equipment.main_stat_base,
		"substats": equipment.substats,
		"sockets": equipment.sockets,
		"max_sockets": equipment.max_sockets,
		"origin_dungeon": equipment.origin_dungeon,
		"lore_text": equipment.lore_text
	}

func _dict_to_equipment(dict: Dictionary) -> Equipment:
	"""Convert dictionary to equipment for loading"""
	var equipment = Equipment.new()
	
	equipment.id = dict.get("id", "")
	equipment.name = dict.get("name", "")
	equipment.type = Equipment.string_to_type(dict.get("type", "weapon"))
	equipment.rarity = Equipment.string_to_rarity(dict.get("rarity", "common"))
	equipment.level = dict.get("level", 0)
	equipment.slot = dict.get("slot", 1)
	equipment.equipment_set_name = dict.get("equipment_set_name", "")
	equipment.equipment_set_type = dict.get("equipment_set_type", "")
	equipment.main_stat_type = dict.get("main_stat_type", "")
	equipment.main_stat_value = dict.get("main_stat_value", 0)
	equipment.main_stat_base = dict.get("main_stat_base", 0)
	equipment.substats = dict.get("substats", [])
	
	# Handle sockets with proper type conversion
	var sockets_data = dict.get("sockets", [])
	equipment.sockets.clear()
	for socket in sockets_data:
		if socket is Dictionary:
			equipment.sockets.append(socket)
	
	equipment.max_sockets = dict.get("max_sockets", 0)
	equipment.origin_dungeon = dict.get("origin_dungeon", "")
	equipment.lore_text = dict.get("lore_text", "")
	
	return equipment
