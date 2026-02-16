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
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return

	var data = json.get_data()
	item_config = data.get("loot_items", {})

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

# UTILITY METHODS

func get_item_info(item_id: String) -> Dictionary:
	"""Get item information from configuration"""
	return item_config.get(item_id, {"name": item_id.capitalize(), "category": "material"})

# SAVE/LOAD SYSTEM

func get_save_data() -> Dictionary:
	return {
		"consumables": consumables.duplicate(),
		"materials": materials.duplicate(),
		"quest_items": quest_items.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	consumables = data.get("consumables", {})
	materials = data.get("materials", {})
	quest_items = data.get("quest_items", {})
