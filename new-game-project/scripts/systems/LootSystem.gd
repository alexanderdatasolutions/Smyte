# scripts/systems/LootSystem.gd
extends Node

signal loot_awarded(loot_results)

var loot_data: Dictionary = {}

func _ready():
	load_loot_data()

func load_loot_data():
	"""Load loot tables from loot.json"""
	var file = FileAccess.open("res://data/loot.json", FileAccess.READ)
	if not file:
		push_error("Failed to load loot.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse loot.json: " + json.error_string)
		return
	
	loot_data = json.get_data()
	print("LootSystem: Loaded ", loot_data.get("loot_tables", {}).size(), " loot tables")

func award_loot(loot_table_name: String, stage_level: int = 1, territory_element: String = "") -> Dictionary:
	"""Award loot from specified loot table - returns awarded items"""
	if not loot_data.has("loot_tables") and not loot_data.has("dungeon_loot_tables"):
		push_error("No loot tables found in loot.json")
		return {}
	
	var loot_table = {}
	
	# Check regular loot tables first
	if loot_data.has("loot_tables") and loot_data.loot_tables.has(loot_table_name):
		loot_table = loot_data.loot_tables[loot_table_name]
	# Check dungeon loot tables
	elif loot_data.has("dungeon_loot_tables") and loot_data.dungeon_loot_tables.has(loot_table_name):
		loot_table = loot_data.dungeon_loot_tables[loot_table_name]
	else:
		push_error("Loot table not found: " + loot_table_name)
		return {}
	
	var awarded_loot = {}
	
	# Process base loot (always awarded)
	if loot_table.has("base_loot"):
		for loot_item in loot_table.base_loot:
			var result = _process_loot_item(loot_item, stage_level, territory_element)
			if result.size() > 0:
				for resource_type in result:
					awarded_loot[resource_type] = awarded_loot.get(resource_type, 0) + result[resource_type]
	
	# Process guaranteed drops
	if loot_table.has("guaranteed_drops"):
		for loot_item in loot_table.guaranteed_drops:
			var result = _process_loot_item(loot_item, stage_level, territory_element)
			if result.size() > 0:
				for resource_type in result:
					awarded_loot[resource_type] = awarded_loot.get(resource_type, 0) + result[resource_type]
	
	# Process rare drops (chance-based)
	if loot_table.has("rare_drops"):
		for loot_item in loot_table.rare_drops:
			var result = _process_loot_item(loot_item, stage_level, territory_element)
			if result.size() > 0:
				for resource_type in result:
					awarded_loot[resource_type] = awarded_loot.get(resource_type, 0) + result[resource_type]
	
	# Award to player
	_award_to_player(awarded_loot)
	
	loot_awarded.emit(awarded_loot)
	return awarded_loot

func _process_loot_item(loot_item: Dictionary, stage_level: int, territory_element: String) -> Dictionary:
	"""Process individual loot item and return resources to award"""
	var chance = loot_item.get("chance", 1.0)
	
	# Check chance
	if randf() > chance:
		return {}
	
	var loot_type = loot_item.get("type", "")
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", 1)
	var amount = randi_range(min_amount, max_amount)
	
	# Apply scaling
	if loot_item.get("scales_with_stage", false):
		var multiplier = loot_item.get("stage_multiplier", 1.1)
		amount = int(amount * pow(multiplier, stage_level - 1))
	
	# Handle element-based loot (powders)
	if loot_item.get("element_based", false):
		return _handle_element_based_loot(loot_type, amount, territory_element, loot_item)
	
	# Handle pantheon-based loot (relics)
	if loot_item.get("pantheon_based", false):
		return _handle_pantheon_based_loot(loot_type, amount)
	
	# Handle equipment drops
	if loot_type == "equipment":
		var equipment = _handle_equipment_drop(loot_item, stage_level)
		if equipment:
			return {"equipment_dropped": 1}  # Return indicator that equipment was dropped
		return {}
	
	# Handle standard loot types
	return _handle_standard_loot(loot_type, amount)

func _handle_equipment_drop(loot_item: Dictionary, _stage_level: int) -> Equipment:
	"""Handle equipment drop from loot - integrates with EquipmentManager"""
	if not GameManager or not GameManager.equipment_manager:
		print("LootSystem: EquipmentManager not available")
		return null
	
	var difficulty = loot_item.get("difficulty", "beginner")
	var dungeon_id = loot_item.get("source", "divine_sanctum")
	
	# Create equipment through EquipmentManager
	var equipment = GameManager.equipment_manager.create_equipment_from_loot(dungeon_id, difficulty)
	
	if equipment:
		# Add to player inventory through EquipmentManager
		GameManager.equipment_manager.add_equipment_to_inventory(equipment)
		print("LootSystem: Awarded ", equipment.get_display_name())
	
	return equipment

func _handle_element_based_loot(base_type: String, amount: int, territory_element: String, loot_item: Dictionary) -> Dictionary:
	"""Handle element-based loot like powders"""
	var result = {}
	
	# Use specific_element if provided (for dungeons), otherwise use territory_element
	var element = loot_item.get("specific_element", territory_element)
	
	# Choose random element if no element specified
	if element == "":
		var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
		element = elements[randi() % elements.size()]
	
	# Apply territory element bonus
	var bonus_multiplier = loot_item.get("territory_element_bonus", 1.0)
	if territory_element != "" and territory_element == element:
		amount = int(amount * bonus_multiplier)
	
	# Create the resource key using loot.json terminology
	var resource_key = element + "_" + base_type
	result[resource_key] = amount
	
	return result

func _handle_pantheon_based_loot(base_type: String, amount: int) -> Dictionary:
	"""Handle pantheon-based loot like relics"""
	var result = {}
	
	# Choose random pantheon
	var pantheons = ["greek", "norse", "egyptian", "hindu", "celtic", "japanese", "aztec"]
	var pantheon = pantheons[randi() % pantheons.size()]
	
	var resource_key = pantheon + "_" + base_type
	result[resource_key] = amount
	
	return result

func _handle_standard_loot(loot_type: String, amount: int) -> Dictionary:
	"""Handle standard loot types"""
	var result = {}
	
	match loot_type:
		"divine_essence":
			result["divine_essence"] = amount
		"divine_crystals", "crystals":
			result["divine_crystals"] = amount
		"awakening_stone", "awakening_stones":
			result["awakening_stones"] = amount
		"summon_tickets":
			result["summon_tickets"] = amount
		"ascension_materials":
			result["ascension_materials"] = amount
		"experience":
			result["experience"] = amount  # Handle experience from loot.json
		"magic_powder_low", "magic_powder_mid", "magic_powder_high":
			# Handle magic powders (universal awakening material)
			result[loot_type] = amount
		_:
			# Direct resource type
			result[loot_type] = amount
	
	return result

func _award_to_player(loot_results: Dictionary):
	"""Award loot to player using PlayerData methods"""
	if not GameManager or not GameManager.player_data:
		return
	
	for resource_type in loot_results:
		var amount = loot_results[resource_type]
		
		# Handle experience separately (award to gods, not player data)
		if resource_type == "experience":
			GameManager.award_experience_to_gods(amount)
			print("Awarded: ", amount, " XP to participating gods")
		else:
			GameManager.player_data.add_resource(resource_type, amount)
			print("Awarded: ", resource_type, " x", amount)
	
	# Trigger resource update
	GameManager.resources_updated.emit()

# Convenience methods for common loot scenarios
func award_stage_victory_loot(stage_level: int, territory_element: String = "") -> Dictionary:
	"""Award loot for stage victory"""
	return award_loot("stage_victory", stage_level, territory_element)

func award_boss_stage_loot(stage_level: int, territory_element: String = "") -> Dictionary:
	"""Award loot for boss stage victory"""
	return award_loot("boss_stage", stage_level, territory_element)

func award_territory_unlock_loot(territory_tier: int, territory_element: String = "") -> Dictionary:
	"""Award loot for territory unlock"""
	return award_loot("territory_unlock", territory_tier, territory_element)
