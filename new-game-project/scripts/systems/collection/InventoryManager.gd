# scripts/systems/InventoryManager.gd
extends Node
class_name InventoryManager

signal inventory_updated(item_type: String)
signal item_consumed(item_id: String, amount: int)

# Inventory storage - organized by type for Summoners War style organization
var consumables: Dictionary = {}  # item_id -> amount  
var materials: Dictionary = {}    # material_id -> amount
var quest_items: Dictionary = {}  # quest_item_id -> amount

# Configuration cache
var item_config: Dictionary = {}

func _ready():
	load_item_config()

func load_item_config():
	"""Load item configuration from loot_items.json"""
	var file = FileAccess.open("res://data/loot_items.json", FileAccess.READ)
	if not file:
		print("InventoryManager: Could not load loot_items.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("InventoryManager: Error parsing loot_items.json")
		return
	
	var data = json.get_data()
	item_config = data.get("loot_items", {})
	print("InventoryManager: Loaded %d item definitions" % item_config.size())

# MAIN INVENTORY METHODS

func add_item(item_id: String, amount: int = 1):
	"""Add items to appropriate inventory category"""
	var item_info = get_item_info(item_id)
	var category = item_info.get("category", "consumable")
	
	match category:
		"consumable":
			consumables[item_id] = consumables.get(item_id, 0) + amount
		"material", "awakening_material", "crafting_material":
			materials[item_id] = materials.get(item_id, 0) + amount
		"quest_item":
			quest_items[item_id] = quest_items.get(item_id, 0) + amount
		_:
			# Default to materials for unknown categories
			materials[item_id] = materials.get(item_id, 0) + amount
	
	print("InventoryManager: Added %d %s to %s inventory" % [amount, item_id, category])
	inventory_updated.emit(category)

func remove_item(item_id: String, amount: int = 1) -> bool:
	"""Remove items if available - returns success"""
	if not has_item(item_id, amount):
		return false
	
	var item_info = get_item_info(item_id)
	var category = item_info.get("category", "consumable")
	
	match category:
		"consumable":
			consumables[item_id] = consumables.get(item_id, 0) - amount
			if consumables[item_id] <= 0:
				consumables.erase(item_id)
		"material", "awakening_material", "crafting_material":
			materials[item_id] = materials.get(item_id, 0) - amount
			if materials[item_id] <= 0:
				materials.erase(item_id)
		"quest_item":
			quest_items[item_id] = quest_items.get(item_id, 0) - amount
			if quest_items[item_id] <= 0:
				quest_items.erase(item_id)
	
	inventory_updated.emit(category)
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	"""Check if player has enough of an item"""
	return get_item_count(item_id) >= amount

func get_item_count(item_id: String) -> int:
	"""Get count of specific item across all inventories"""
	var count = 0
	count += consumables.get(item_id, 0)
	count += materials.get(item_id, 0) 
	count += quest_items.get(item_id, 0)
	return count

# CONSUMABLE MANAGEMENT

func use_consumable(item_id: String, target_god: God = null) -> bool:
	"""Use a consumable item with effects"""
	if not has_item(item_id, 1):
		print("InventoryManager: Don't have %s to use" % item_id)
		return false
	
	var item_info = get_item_info(item_id)
	if item_info.get("category") != "consumable":
		print("InventoryManager: %s is not a consumable" % item_id)
		return false
	
	# Process consumable effects
	var effects = item_info.get("effects", [])
	for effect in effects:
		_apply_consumable_effect(effect, target_god)
	
	# Remove the item
	remove_item(item_id, 1)
	item_consumed.emit(item_id, 1)
	
	print("InventoryManager: Used %s" % item_id)
	return true

func _apply_consumable_effect(effect: Dictionary, target_god: God = null):
	"""Apply consumable effect to god or player"""
	var effect_type = effect.get("type", "")
	var value = effect.get("value", 0)
	
	match effect_type:
		"heal_god":
			if target_god:
				target_god.heal(value)
				print("Healed %s for %d HP" % [target_god.name, value])
		"restore_energy":
			var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
			if resource_manager:
				resource_manager.add_resource("energy", value)
				print("Restored %d energy" % value)
		"add_experience":
			if target_god:
				var system_registry = SystemRegistry.get_instance()
				var god_progression_manager = system_registry.get_system("GodProgressionManager")
				god_progression_manager.add_experience_to_god(target_god, value)
				print("Gave %d XP to %s" % [value, target_god.name])

# BATTLE INTEGRATION METHODS

func add_loot_items(loot_results: Dictionary):
	"""Add loot items from battle rewards to inventory"""
	for item_id in loot_results:
		var amount = loot_results[item_id]
		var item_info = get_item_info(item_id)
		var category = item_info.get("category", "material")
		
		# Skip resources - those go to ResourceManager
		if category in ["currency", "resource"]:
			continue
		
		# Add items to appropriate inventory
		add_item(item_id, amount)

# UTILITY METHODS

func get_item_info(item_id: String) -> Dictionary:
	"""Get item information from configuration"""
	return item_config.get(item_id, {"name": item_id.capitalize(), "category": "material"})

func get_all_consumables() -> Dictionary:
	"""Get all consumables with their info"""
	var result = {}
	for item_id in consumables:
		result[item_id] = {
			"count": consumables[item_id],
			"info": get_item_info(item_id)
		}
	return result

func get_all_materials() -> Dictionary:
	"""Get all materials with their info"""
	var result = {}
	for item_id in materials:
		result[item_id] = {
			"count": materials[item_id],
			"info": get_item_info(item_id)
		}
	return result

# SAVE/LOAD SYSTEM

func save_inventory_data() -> Dictionary:
	"""Save inventory data for game save"""
	return {
		"consumables": consumables.duplicate(),
		"materials": materials.duplicate(),
		"quest_items": quest_items.duplicate()
	}

func load_inventory_data(data: Dictionary):
	"""Load inventory data from game save"""
	consumables = data.get("consumables", {})
	materials = data.get("materials", {})
	quest_items = data.get("quest_items", {})
	
	print("InventoryManager: Loaded %d consumables, %d materials, %d quest items" % [
		consumables.size(), materials.size(), quest_items.size()
	])
