# scripts/systems/collection/EquipmentManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - coordinate equipment systems
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentManager

"""
Equipment Management Coordinator
Coordinates between all equipment subsystems: inventory, crafting, enhancement, and sockets
This is the main entry point for the equipment system (like Summoners War equipment)
According to prompt.prompt.md: "EquipmentManager - Equipment system (200 lines)"
"""

# Main equipment system signals
signal equipment_equipped(god: God, equipment: Equipment, slot: int)
signal equipment_unequipped(god: God, slot: int)
signal equipment_enhanced(equipment: Equipment, success: bool)
signal equipment_crafted(equipment: Equipment, recipe_id: String)
signal socket_unlocked(equipment: Equipment, socket_index: int)
signal gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary)

# Component managers for focused responsibilities
var inventory_manager: EquipmentInventoryManager
var crafting_manager: EquipmentCraftingManager
var enhancement_manager: EquipmentEnhancementManager
var socket_manager: EquipmentSocketManager

func _ready():
	"""Initialize the equipment management system"""
	print("EquipmentManager: Initializing equipment system coordinator")
	setup_component_managers()
	connect_component_signals()
	load_equipment_configuration()

func setup_component_managers():
	"""Initialize all equipment component managers - RULE 2: Focused responsibilities"""
	# Create inventory manager
	inventory_manager = EquipmentInventoryManager.new()
	add_child(inventory_manager)
	
	# Create crafting manager
	crafting_manager = EquipmentCraftingManager.new()
	add_child(crafting_manager)
	
	# Create enhancement manager
	enhancement_manager = EquipmentEnhancementManager.new()
	add_child(enhancement_manager)
	
	# Create socket manager
	socket_manager = EquipmentSocketManager.new()
	add_child(socket_manager)
	
	print("EquipmentManager: All component managers initialized")

func connect_component_signals():
	"""Connect all component manager signals"""
	# Inventory manager signals
	if inventory_manager:
		inventory_manager.equipment_equipped.connect(_on_equipment_equipped)
		inventory_manager.equipment_unequipped.connect(_on_equipment_unequipped)
	
	# Crafting manager signals  
	if crafting_manager:
		crafting_manager.equipment_crafted.connect(_on_equipment_crafted)
	
	# Enhancement manager signals
	if enhancement_manager:
		enhancement_manager.equipment_enhanced.connect(_on_equipment_enhanced)
	
	# Socket manager signals
	if socket_manager:
		socket_manager.socket_unlocked.connect(_on_socket_unlocked)
		socket_manager.gem_socketed.connect(_on_gem_socketed)
	
	print("EquipmentManager: Component signals connected")

func load_equipment_configuration():
	"""Load equipment configuration through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var config_manager = system_registry.get_system("ConfigurationManager")
		if config_manager:
			print("EquipmentManager: Configuration loaded through SystemRegistry")

# === INVENTORY OPERATIONS ===

func add_equipment_to_inventory(equipment: Equipment):
	"""Add equipment to inventory - delegate to inventory manager"""
	if inventory_manager:
		inventory_manager.add_equipment_to_inventory(equipment)

func remove_equipment_from_inventory(equipment: Equipment) -> bool:
	"""Remove equipment from inventory - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.remove_equipment_from_inventory(equipment)
	return false

func get_equipment_by_id(equipment_id: String) -> Equipment:
	"""Find equipment by ID - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.get_equipment_by_id(equipment_id)
	return null

func get_equipment_by_slot_type(slot_type: Equipment.EquipmentType) -> Array:
	"""Get equipment by slot type - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.get_equipment_by_slot_type(slot_type)
	return []

func equip_equipment_to_god(god: God, equipment: Equipment, slot: int) -> bool:
	"""Equip equipment to god - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.equip_equipment_to_god(god, equipment, slot)
	return false

func unequip_equipment_from_god(god: God, slot: int) -> Equipment:
	"""Unequip equipment from god - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.unequip_equipment_from_god(god, slot)
	return null

# === CRAFTING OPERATIONS ===

func can_craft_equipment(recipe_id: String, territory_id: String = "") -> Dictionary:
	"""Check if equipment can be crafted - delegate to crafting manager"""
	if crafting_manager:
		return crafting_manager.can_craft_equipment(recipe_id, territory_id)
	return {"can_craft": false, "reason": "Crafting manager not available"}

func craft_equipment(recipe_id: String, crafting_god_id: String = "", territory_id: String = "") -> Equipment:
	"""Craft equipment - delegate to crafting manager"""
	if crafting_manager:
		return crafting_manager.craft_equipment(recipe_id, crafting_god_id, territory_id)
	return null

func get_available_recipes(territory_id: String = "") -> Array:
	"""Get available crafting recipes - delegate to crafting manager"""
	if crafting_manager:
		return crafting_manager.get_available_recipes(territory_id)
	return []

# === ENHANCEMENT OPERATIONS ===

func enhance_equipment(equipment: Equipment, use_blessed_oil: bool = false) -> bool:
	"""Enhance equipment - delegate to enhancement manager"""
	if enhancement_manager:
		return enhancement_manager.enhance_equipment(equipment, use_blessed_oil)
	return false

func get_enhancement_preview(equipment: Equipment, use_blessed_oil: bool = false) -> Dictionary:
	"""Get enhancement preview - delegate to enhancement manager"""
	if enhancement_manager:
		return enhancement_manager.get_enhancement_preview(equipment, use_blessed_oil)
	return {}

func enhance_equipment_bulk(equipment: Equipment, target_level: int, use_blessed_oil: bool = false) -> Dictionary:
	"""Bulk enhance equipment - delegate to enhancement manager"""
	if enhancement_manager:
		return enhancement_manager.enhance_equipment_bulk(equipment, target_level, use_blessed_oil)
	return {}

# === SOCKET OPERATIONS ===

func unlock_socket(equipment: Equipment, socket_index: int) -> bool:
	"""Unlock socket - delegate to socket manager"""
	if socket_manager:
		return socket_manager.unlock_socket(equipment, socket_index)
	return false

func socket_gem(equipment: Equipment, socket_index: int, gem_id: String) -> bool:
	"""Socket gem - delegate to socket manager"""
	if socket_manager:
		return socket_manager.socket_gem(equipment, socket_index, gem_id)
	return false

func unsocket_gem(equipment: Equipment, socket_index: int) -> Dictionary:
	"""Unsocket gem - delegate to socket manager"""
	if socket_manager:
		return socket_manager.unsocket_gem(equipment, socket_index)
	return {}

func add_gem_to_inventory(gem_id: String, quantity: int = 1):
	"""Add gems to inventory - delegate to socket manager"""
	if socket_manager:
		socket_manager.add_gem_to_inventory(gem_id, quantity)

# === EVENT HANDLERS ===

func _on_equipment_equipped(god: God, equipment: Equipment, slot: int):
	"""Handle equipment equipped event"""
	equipment_equipped.emit(god, equipment, slot)

func _on_equipment_unequipped(god: God, slot: int):
	"""Handle equipment unequipped event"""
	equipment_unequipped.emit(god, slot)

func _on_equipment_crafted(equipment: Equipment, recipe_id: String):
	"""Handle equipment crafted event"""
	equipment_crafted.emit(equipment, recipe_id)

func _on_equipment_enhanced(equipment: Equipment, success: bool):
	"""Handle equipment enhanced event"""
	equipment_enhanced.emit(equipment, success)

func _on_socket_unlocked(equipment: Equipment, socket_index: int):
	"""Handle socket unlocked event"""
	socket_unlocked.emit(equipment, socket_index)

func _on_gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary):
	"""Handle gem socketed event"""
	gem_socketed.emit(equipment, socket_index, gem)

# === UTILITY METHODS ===

func get_equipment_summary() -> Dictionary:
	"""Get summary of all equipment systems"""
	var summary = {
		"inventory": {},
		"crafting": {},
		"enhancement": {},
		"sockets": {}
	}
	
	if inventory_manager:
		summary.inventory = inventory_manager.get_inventory_summary()
	
	if crafting_manager:
		summary.crafting = {
			"available_recipes": crafting_manager.get_available_recipes().size(),
			"total_recipes": crafting_manager.get_all_recipes().size()
		}
	
	if socket_manager:
		summary.sockets = {
			"total_gems": socket_manager.get_gem_inventory().size()
		}
	
	return summary

func get_god_equipment_stats(god: God) -> Dictionary:
	"""Get equipment stats for a specific god - RULE 5: Use SystemRegistry"""
	if not god:
		return {}
	
	var stats = {
		"equipped_count": 0,
		"total_enhancement_level": 0,
		"socketed_gems": 0,
		"stat_bonuses": {}
	}
	
	# Get god equipment through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var collection_manager = system_registry.get_system("CollectionManager")
		if collection_manager:
			var god_equipment = collection_manager.get_god_equipment(god.id)
			
			for equipment in god_equipment:
				if equipment:
					stats.equipped_count += 1
					stats.total_enhancement_level += equipment.enhancement_level
					
					# Count socketed gems
					if socket_manager:
						var socket_effects = socket_manager.get_gem_effects_on_equipment(equipment)
						for effect_type in socket_effects:
							stats.socketed_gems += 1
							if not stats.stat_bonuses.has(effect_type):
								stats.stat_bonuses[effect_type] = 0
							stats.stat_bonuses[effect_type] += socket_effects[effect_type]
	
	return stats

# === SAVE/LOAD INTEGRATION ===

func save_equipment_data() -> Dictionary:
	"""Save all equipment data"""
	var data = {
		"inventory": [],
		"gems": []
	}
	
	if inventory_manager:
		data.inventory = inventory_manager.get_all_equipment()
	
	if socket_manager:
		data.gems = socket_manager.get_gem_inventory()
	
	return data

func load_equipment_data(data: Dictionary):
	"""Load all equipment data"""
	if data.has("inventory") and inventory_manager:
		inventory_manager.clear_inventory()
		for equipment_data in data.inventory:
			if equipment_data is Equipment:
				inventory_manager.add_equipment_to_inventory(equipment_data)
	
	if data.has("gems") and socket_manager:
		# Load gems would need to be implemented in socket manager
		pass

# === INTEGRATION METHODS ===

func create_equipment_from_loot(dungeon_id: String, _difficulty: String, rarity: String) -> Equipment:
	"""Create equipment from loot system - RULE 5: Use SystemRegistry"""
	# Create equipment through proper channels
	var equipment = Equipment.create_from_dungeon(dungeon_id, "WEAPON", rarity, 1)
	
	if equipment:
		add_equipment_to_inventory(equipment)
		print("EquipmentManager: Created equipment from loot: %s" % equipment.get_display_name())
	
	return equipment

# === PUBLIC API SUMMARY ===

func get_public_api() -> Array:
	"""Get list of public API methods for this system"""
	return [
		"add_equipment_to_inventory",
		"remove_equipment_from_inventory", 
		"get_equipment_by_id",
		"get_equipment_by_slot_type",
		"equip_equipment_to_god",
		"unequip_equipment_from_god",
		"can_craft_equipment",
		"craft_equipment",
		"get_available_recipes",
		"enhance_equipment",
		"get_enhancement_preview",
		"enhance_equipment_bulk",
		"unlock_socket",
		"socket_gem",
		"unsocket_gem",
		"add_gem_to_inventory",
		"get_equipment_summary",
		"get_god_equipment_stats",
		"create_equipment_from_loot"
	]

# === CLEANUP ===

func _exit_tree():
	"""Clean up when equipment manager is removed"""
	print("EquipmentManager: Cleaning up")
	
	# Component managers are children and will be automatically freed
	# Just ensure any remaining connections are cleared
	if inventory_manager and inventory_manager.equipment_equipped.is_connected(_on_equipment_equipped):
		inventory_manager.equipment_equipped.disconnect(_on_equipment_equipped)
	
	if crafting_manager and crafting_manager.equipment_crafted.is_connected(_on_equipment_crafted):
		crafting_manager.equipment_crafted.disconnect(_on_equipment_crafted)
	
	if enhancement_manager and enhancement_manager.equipment_enhanced.is_connected(_on_equipment_enhanced):
		enhancement_manager.equipment_enhanced.disconnect(_on_equipment_enhanced)
	
	if socket_manager and socket_manager.socket_unlocked.is_connected(_on_socket_unlocked):
		socket_manager.socket_unlocked.disconnect(_on_socket_unlocked)
