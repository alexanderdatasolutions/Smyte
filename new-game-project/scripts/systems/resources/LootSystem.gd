# scripts/systems/resources/LootSystem.gd
# Loot generation system - handles all loot drops and rewards (200 lines max)
class_name LootSystem extends Node

signal loot_generated(loot_results: Dictionary)
signal loot_awarded(rewards: Dictionary)

var loot_tables: Dictionary = {}
var loot_items: Dictionary = {}

func _ready():
	_load_loot_configuration()

## Load loot configuration through ConfigurationManager
func _load_loot_configuration():
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if config_manager:
		var loot_config = config_manager.get_loot_config()
		loot_tables = loot_config.get("loot_templates", {})  # Fixed: was "loot_tables"
		loot_items = loot_config.get("loot_items", {})
	else:
		push_warning("LootSystem: ConfigurationManager not available, loading fallback")
		_load_fallback_loot_tables()

func _load_fallback_loot_tables():
	"""Load loot tables directly if ConfigurationManager unavailable"""
	# Load loot_tables.json
	var file = FileAccess.open("res://data/loot_tables.json", FileAccess.READ)
	if not file:
		push_error("LootSystem: Could not load loot_tables.json")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("LootSystem: Error parsing loot_tables.json")
		return
	
	var data = json.get_data()
	loot_tables = data.get("loot_templates", {})
	
	# Load loot_items.json
	var items_file = FileAccess.open("res://data/loot_items.json", FileAccess.READ)
	if items_file:
		var items_json_text = items_file.get_as_text()
		items_file.close()
		
		var items_json = JSON.new()
		if items_json.parse(items_json_text) == OK:
			var items_data = items_json.get_data()
			loot_items = items_data.get("loot_items", {})
		else:
			push_error("LootSystem: Error parsing loot_items.json")
	else:
		push_warning("LootSystem: Could not load loot_items.json - using empty loot_items")
		loot_items = {}

## Generate loot from a table
func generate_loot(table_id: String, multiplier: float = 1.0, element: String = "") -> Dictionary:
	if not loot_tables.has(table_id):
		push_warning("LootSystem: Unknown loot table: " + table_id)
		return {}

	var table = loot_tables[table_id]
	var results = {}

	# Process guaranteed drops (always drop if chance roll succeeds)
	for item_data in table.get("guaranteed_drops", []):
		if _roll_chance(item_data.get("chance", 1.0)):
			var loot_item_id = item_data.get("loot_item_id", "")
			var is_element_specific = item_data.get("element_specific", false)
			var resource_id = _resolve_resource_id(loot_item_id, element if is_element_specific else "")
			var amount = _calculate_loot_amount(loot_item_id, multiplier)

			if amount > 0 and resource_id != "":
				results[resource_id] = results.get(resource_id, 0) + amount

	# Process rare drops (chance-based)
	for item_data in table.get("rare_drops", []):
		if _roll_chance(item_data.get("chance", 0.0)):
			var loot_item_id = item_data.get("loot_item_id", "")
			var is_element_specific = item_data.get("element_specific", false)
			var resource_id = _resolve_resource_id(loot_item_id, element if is_element_specific else "")
			var amount = _calculate_loot_amount(loot_item_id, multiplier)

			if amount > 0 and resource_id != "":
				results[resource_id] = results.get(resource_id, 0) + amount

	# Fallback for old "items" format
	for item_data in table.get("items", []):
		if _roll_chance(item_data.get("chance", 0.0)):
			var item_id = item_data.get("item_id", "")
			var amount = _calculate_amount(item_data, multiplier)

			if amount > 0:
				results[item_id] = results.get(item_id, 0) + amount

	loot_generated.emit(results)
	return results

## Resolve loot_item_id to actual resource_id, with element substitution
func _resolve_resource_id(loot_item_id: String, element: String) -> String:
	if not loot_items.has(loot_item_id):
		# If not in loot_items, treat as direct resource_id
		return loot_item_id

	var item_def = loot_items[loot_item_id]

	# Check for element-based items
	if item_def.get("resource_type", "") == "element_based":
		var base_resource = item_def.get("base_resource", "")
		if element != "" and base_resource != "":
			# Return element-specific resource (e.g., "fire_powder_low" from "powder_low")
			return element + "_" + base_resource
		else:
			# Fallback to generic if no element specified
			return "magic_" + base_resource

	# Standard resource_id lookup
	return item_def.get("resource_id", loot_item_id)

## Calculate amount from loot_items definition
func _calculate_loot_amount(loot_item_id: String, multiplier: float) -> int:
	if not loot_items.has(loot_item_id):
		return 1  # Default to 1 if not defined

	var item_def = loot_items[loot_item_id]
	var min_amount = item_def.get("min_amount", 1)
	var max_amount = item_def.get("max_amount", 1)
	var base_amount = randi_range(min_amount, max_amount)

	return int(base_amount * multiplier)

## Generate battle rewards
func generate_battle_rewards(stage_level: int, victory_type: String = "normal") -> Dictionary:
	var base_table = "battle_rewards_stage_" + str(stage_level)
	var multiplier = _get_victory_multiplier(victory_type)
	
	return generate_loot(base_table, multiplier)

## Generate dungeon rewards
func generate_dungeon_rewards(dungeon_id: String, difficulty: String = "normal") -> Dictionary:
	var table_id = dungeon_id + "_" + difficulty
	var multiplier = _get_difficulty_multiplier(difficulty)
	
	return generate_loot(table_id, multiplier)

## Award loot to player through ResourceManager
func award_loot(loot_results: Dictionary):
	if loot_results.is_empty():
		return
	
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_manager:
		push_error("LootSystem: ResourceManager not available")
		return
	
	for resource_id in loot_results:
		var amount = loot_results[resource_id]
		resource_manager.add_resource(resource_id, amount)

	loot_awarded.emit(loot_results)

## Check if player can roll for specific loot
func can_roll_loot(table_id: String) -> bool:
	return loot_tables.has(table_id)

## Get loot table preview (for UI)
func get_loot_preview(table_id: String) -> Array:
	if not loot_tables.has(table_id):
		push_warning("LootSystem: No loot table found for: " + table_id)
		return []
	
	var preview = []
	var table = loot_tables[table_id]
	
	# Handle guaranteed drops
	for item_data in table.get("guaranteed_drops", []):
		preview.append({
			"item_id": item_data.get("loot_item_id", ""),
			"chance": item_data.get("chance", 1.0) * 100.0,  # Convert to percentage
			"min_amount": item_data.get("min_amount", 1),
			"max_amount": item_data.get("max_amount", 1)
		})
	
	# Handle rare drops
	for item_data in table.get("rare_drops", []):
		preview.append({
			"item_id": item_data.get("loot_item_id", ""),
			"chance": item_data.get("chance", 0.0) * 100.0,  # Convert to percentage
			"min_amount": item_data.get("min_amount", 1),
			"max_amount": item_data.get("max_amount", 1)
		})
	
	# Fallback for old "items" format
	for item_data in table.get("items", []):
		preview.append({
			"item_id": item_data.get("item_id", ""),
			"chance": item_data.get("chance", 0.0),
			"min_amount": item_data.get("min_amount", 1),
			"max_amount": item_data.get("max_amount", 1)
		})
	
	return preview

## Private helper methods
func _roll_chance(chance: float) -> bool:
	return randf() <= chance

func _calculate_amount(item_data: Dictionary, multiplier: float) -> int:
	var min_amount = item_data.get("min_amount", 1)
	var max_amount = item_data.get("max_amount", 1)
	var base_amount = randi_range(min_amount, max_amount)
	
	return int(base_amount * multiplier)

func _get_victory_multiplier(victory_type: String) -> float:
	match victory_type:
		"perfect":
			return 1.5
		"fast":
			return 1.2
		"normal":
			return 1.0
		"close":
			return 0.9
		_:
			return 1.0

func _get_difficulty_multiplier(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.8
		"normal":
			return 1.0
		"hard":
			return 1.3
		"nightmare":
			return 1.6
		_:
			return 1.0

## For save/load
func get_save_data() -> Dictionary:
	return {
		# LootSystem doesn't need persistent state
	}

func load_save_data(_save_data: Dictionary):
	# LootSystem doesn't need persistent state
	pass
