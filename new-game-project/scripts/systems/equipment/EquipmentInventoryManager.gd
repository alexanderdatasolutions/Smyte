# scripts/systems/collection/EquipmentInventoryManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - equipment inventory storage only
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentInventoryManager

"""
Equipment Inventory Management System
Handles equipment storage, retrieval, and basic inventory operations
Part of the equipment system (like Summoners War equipment)
"""

# Signals for equipment inventory changes
signal equipment_added_to_inventory(equipment: Equipment)
signal equipment_removed_from_inventory(equipment: Equipment)
signal equipment_equipped(god: God, equipment: Equipment, slot: int)
signal equipment_unequipped(god: God, slot: int)

# Equipment inventory storage
var equipment_inventory: Array = []  # Array[Equipment]

func _ready():
	"""Initialize equipment inventory manager"""
	pass

# === INVENTORY MANAGEMENT ===

func add_equipment_to_inventory(equipment: Equipment):
	"""Add equipment to player inventory - RULE 2: Single responsibility"""
	if equipment == null:
		push_error("EquipmentInventoryManager: Cannot add null equipment to inventory")
		return
	
	equipment_inventory.append(equipment)
	equipment_added_to_inventory.emit(equipment)

func remove_equipment_from_inventory(equipment: Equipment) -> bool:
	"""Remove equipment from inventory - RULE 2: Single responsibility"""
	if equipment == null:
		return false
	
	var index = equipment_inventory.find(equipment)
	if index == -1:
		return false
	
	equipment_inventory.remove_at(index)
	equipment_removed_from_inventory.emit(equipment)

	return true

func get_equipment_by_id(equipment_id: String) -> Equipment:
	"""Find equipment by ID - RULE 2: Single responsibility"""
	for equipment in equipment_inventory:
		if equipment.id == equipment_id:
			return equipment
	return null

func get_equipment_by_slot_type(slot_type: Equipment.EquipmentType) -> Array:
	"""Get all equipment of specific slot type - RULE 2: Single responsibility"""
	var filtered: Array = []  # Array[Equipment]
	for equipment in equipment_inventory:
		if equipment.type == slot_type:
			filtered.append(equipment)
	return filtered

func get_equipment_by_rarity(rarity: Equipment.Rarity) -> Array:
	"""Get all equipment of specific rarity"""
	var filtered: Array = []  # Array[Equipment]
	for equipment in equipment_inventory:
		if equipment.rarity == rarity:
			filtered.append(equipment)
	return filtered

func get_unequipped_equipment() -> Array:
	"""Get all unequipped equipment"""
	var filtered: Array = []  # Array[Equipment]
	for equipment in equipment_inventory:
		if equipment.equipped_by_god_id == "":  # Not equipped to any god
			filtered.append(equipment)
	return filtered

func get_equipped_equipment() -> Array:
	"""Get all equipped equipment"""
	var filtered: Array = []  # Array[Equipment]
	for equipment in equipment_inventory:
		if equipment.equipped_by_god_id != "":  # Equipped to a god
			filtered.append(equipment)
	return filtered

func get_inventory_count() -> int:
	"""Get total equipment count"""
	return equipment_inventory.size()

func get_inventory_count_by_type(slot_type: Equipment.EquipmentType) -> int:
	"""Get count of equipment by type"""
	var count = 0
	for equipment in equipment_inventory:
		if equipment.type == slot_type:
			count += 1
	return count

# === EQUIPMENT MANAGEMENT ===

func equip_equipment_to_god(god: God, equipment: Equipment, slot: int) -> bool:
	"""Equip equipment to a god - RULE 5: Use SystemRegistry for god updates"""
	if god == null or equipment == null:
		return false
	
	# Check if equipment is in inventory
	if equipment not in equipment_inventory:
		push_error("EquipmentInventoryManager: Equipment not in inventory")
		return false
	
	# Check if equipment is already equipped
	if equipment.is_equipped:
		push_error("EquipmentInventoryManager: Equipment already equipped")
		return false
	
	# Check slot compatibility
	if not _is_slot_compatible(equipment, slot):
		push_error("EquipmentInventoryManager: Equipment not compatible with slot")
		return false
	
	# Unequip existing equipment in that slot
	var existing_equipment = _get_equipped_equipment_in_slot(god, slot)
	if existing_equipment:
		unequip_equipment_from_god(god, slot)
	
	# Equip new equipment
	equipment.is_equipped = true
	equipment.equipped_god_id = god.id
	equipment.equipped_slot = slot
	
	# Update god equipment through SystemRegistry - RULE 5 compliance
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if collection_manager:
		collection_manager.update_god_equipment(god.id, slot, equipment)
	
	equipment_equipped.emit(god, equipment, slot)
	return true

func unequip_equipment_from_god(god: God, slot: int) -> Equipment:
	"""Unequip equipment from a god - RULE 5: Use SystemRegistry for god updates"""
	if god == null:
		return null
	
	var equipment = _get_equipped_equipment_in_slot(god, slot)
	if not equipment:
		return null
	
	# Unequip equipment
	equipment.is_equipped = false
	equipment.equipped_god_id = ""
	equipment.equipped_slot = -1
	
	# Update god equipment through SystemRegistry - RULE 5 compliance
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if collection_manager:
		collection_manager.update_god_equipment(god.id, slot, null)
	
	equipment_unequipped.emit(god, slot)
	return equipment

func _get_equipped_equipment_in_slot(god: God, slot: int) -> Equipment:
	"""Get equipment equipped in specific slot"""
	for equipment in equipment_inventory:
		if equipment.is_equipped and equipment.equipped_god_id == god.id and equipment.equipped_slot == slot:
			return equipment
	return null

func _is_slot_compatible(equipment: Equipment, slot: int) -> bool:
	"""Check if equipment is compatible with slot"""
	# Equipment slots: 0=Weapon, 1=Armor, 2=Helm, 3=Boots, 4=Amulet, 5=Ring
	match equipment.type:
		Equipment.EquipmentType.WEAPON:
			return slot == 0
		Equipment.EquipmentType.ARMOR:
			return slot == 1
		Equipment.EquipmentType.HELM:
			return slot == 2
		Equipment.EquipmentType.BOOTS:
			return slot == 3
		Equipment.EquipmentType.AMULET:
			return slot == 4
		Equipment.EquipmentType.RING:
			return slot == 5
		_:
			return false

# === UTILITY METHODS ===

func get_all_equipment() -> Array:
	"""Get all equipment in inventory"""
	return equipment_inventory.duplicate()

func clear_inventory():
	"""Clear all equipment from inventory - for testing/reset"""
	equipment_inventory.clear()

func get_inventory_summary() -> Dictionary:
	"""Get inventory summary statistics"""
	var summary = {
		"total": equipment_inventory.size(),
		"equipped": 0,
		"unequipped": 0,
		"by_rarity": {},
		"by_type": {}
	}
	
	for equipment in equipment_inventory:
		# Count equipped/unequipped
		if equipment.is_equipped:
			summary.equipped += 1
		else:
			summary.unequipped += 1
		
		# Count by rarity
		var rarity_name = Equipment.Rarity.keys()[equipment.rarity]
		if not summary.by_rarity.has(rarity_name):
			summary.by_rarity[rarity_name] = 0
		summary.by_rarity[rarity_name] += 1
		
		# Count by type
		var type_name = Equipment.EquipmentType.keys()[equipment.type]
		if not summary.by_type.has(type_name):
			summary.by_type[type_name] = 0
		summary.by_type[type_name] += 1
	
	return summary

func has_equipment(equipment: Equipment) -> bool:
	"""Check if equipment exists in inventory"""
	return equipment in equipment_inventory

func find_best_equipment_for_slot(slot: int, _god: God = null) -> Equipment:
	"""Find the best unequipped equipment for a specific slot"""
	var compatible_equipment = []
	
	for equipment in equipment_inventory:
		if not equipment.is_equipped and _is_slot_compatible(equipment, slot):
			compatible_equipment.append(equipment)
	
	if compatible_equipment.is_empty():
		return null
	
	# Sort by rarity and level (higher is better)
	compatible_equipment.sort_custom(func(a, b): 
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		return a.level > b.level
	)
	
	return compatible_equipment[0]

# === TESTING METHODS ===

func _test_inventory_operations():
	"""Test inventory operations"""
	# Create test equipment
	var test_equipment = Equipment.create_from_dungeon("test_weapon", "WEAPON", "COMMON", 1)

	# Test adding
	add_equipment_to_inventory(test_equipment)
	assert(has_equipment(test_equipment), "Equipment should be in inventory")

	# Test removing
	var removed = remove_equipment_from_inventory(test_equipment)
	assert(removed, "Equipment should be removed")
	assert(not has_equipment(test_equipment), "Equipment should not be in inventory")
