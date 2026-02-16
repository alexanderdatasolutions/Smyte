# scripts/utilities/SaveLoadUtility.gd
# Standardizes all save/load operations across the game
class_name SaveLoadUtility extends RefCounted

const SAVE_VERSION = "1.0"
const SAVE_FILE_PATH = "user://save_game.dat"  # Match SaveManager and GameCoordinator
const LEGACY_SAVE_FILE_PATH = "user://savegame.dat"  # Old filename for compatibility
const SETTINGS_FILE_PATH = "user://settings.cfg"

## Serialize a God object to Dictionary for saving
static func serialize_god(god: God) -> Dictionary:
	if not god:
		return {}

	return {
		"id": god.id,  # Unique instance ID
		"template_id": god.template_id,  # Base god template for recreation
		"level": god.level,
		"experience": god.experience,
		"skill_levels": god.skill_levels.duplicate(),
		"equipment": god.equipment.duplicate(),  # Use correct property name
		"current_hp": god.current_hp,
		"max_hp": _calculate_god_max_hp(god),
		"awakened": god.is_awakened,  # Use correct property name
		"primary_role": god.primary_role,
		"secondary_role": god.secondary_role,
		"specialization_path": god.specialization_path.duplicate(),
		# Save base stats - these are modified when god levels up
		"base_hp": god.base_hp,
		"base_attack": god.base_attack,
		"base_defense": god.base_defense,
		"base_speed": god.base_speed
	}

## Deserialize Dictionary back to God object
static func deserialize_god(data: Dictionary) -> God:
	# Use template_id for creation (with fallback to id for legacy saves)
	var template_id = data.get("template_id", data.get("id", ""))
	var god = GodFactory.create_from_json(template_id)
	if not god:
		push_error("SaveLoadUtility: Could not create god with template ID: " + str(template_id))
		return null

	# Restore the unique instance ID (or keep the newly generated one for legacy saves)
	if data.has("id") and data.has("template_id"):
		god.id = data.get("id")  # Restore the exact instance ID

	god.level = data.get("level", 1)
	god.experience = data.get("experience", 0)
	var raw_skill_levels: Array = data.get("skill_levels", [1, 1, 1])
	var typed_skill_levels: Array[int] = []
	for sl: Variant in raw_skill_levels:
		typed_skill_levels.append(int(sl))
	god.skill_levels = typed_skill_levels

	# Restore base stats if saved (these are modified when god levels up)
	# Only apply if the save has these fields (for backwards compatibility)
	if data.has("base_hp"):
		god.base_hp = data.get("base_hp")
		god.base_attack = data.get("base_attack", god.base_attack)
		god.base_defense = data.get("base_defense", god.base_defense)
		god.base_speed = data.get("base_speed", god.base_speed)
	elif god.level > 1:
		# Legacy save without base stats - recalculate from level
		# This ensures old saves with leveled gods will have correct stats
		_recalculate_base_stats_for_level(god)

	# Properly deserialize equipment array
	var equipment_data = data.get("equipment", [null, null, null, null, null, null])
	god.equipment = []
	for i in range(6):  # 6 equipment slots
		if i < equipment_data.size() and equipment_data[i] != null:
			if equipment_data[i] is Dictionary:
				# Deserialize equipment object from dictionary data
				var equipment = deserialize_equipment(equipment_data[i])
				god.equipment.append(equipment)
			elif equipment_data[i] is String and equipment_data[i] != "":
				# Handle legacy string ID format - create equipment from ID
				var equipment_manager = SystemRegistry.get_instance().get_system("EquipmentManager")
				if equipment_manager:
					var equipment = equipment_manager.get_equipment_by_id(equipment_data[i])
					god.equipment.append(equipment)
				else:
					god.equipment.append(null)
			else:
				god.equipment.append(null)
		else:
			god.equipment.append(null)
	
	god.current_hp = data.get("current_hp", _calculate_god_max_hp(god))

	# Handle awakening if the god supports it
	if data.has("awakened"):
		god.is_awakened = data.awakened

	# Handle role and specialization data
	# Only override role if save data has non-empty value
	# Otherwise keep the role initialized by GodFactory from god definition
	var saved_primary_role = data.get("primary_role", "")
	if saved_primary_role != "":
		god.primary_role = saved_primary_role

	var saved_secondary_role = data.get("secondary_role", "")
	if saved_secondary_role != "":
		god.secondary_role = saved_secondary_role

	# Restore specialization path with proper array size and type
	var spec_path = data.get("specialization_path", ["", "", ""])
	if spec_path is Array:
		# Create properly typed Array[String] with exactly 3 elements
		var typed_spec_path: Array[String] = ["", "", ""]
		for i in range(min(3, spec_path.size())):
			if i < spec_path.size() and spec_path[i] is String:
				typed_spec_path[i] = spec_path[i]
		god.specialization_path = typed_spec_path
	else:
		god.specialization_path = ["", "", ""]

	return god

## Serialize Equipment object to Dictionary
static func serialize_equipment(equipment: Equipment) -> Dictionary:
	if not equipment:
		return {}

	return {
		"id": equipment.id,
		"name": equipment.name,
		"type": equipment.type,
		"rarity": equipment.rarity,
		"level": equipment.level,
		"slot": equipment.slot,
		"equipment_set_name": equipment.equipment_set_name,
		"equipment_set_type": equipment.equipment_set_type,
		"main_stat_type": equipment.main_stat_type,
		"main_stat_value": equipment.main_stat_value,
		"main_stat_base": equipment.main_stat_base,
		"substats": equipment.substats.duplicate(),
		"sockets": equipment.sockets.duplicate(true),
		"max_sockets": equipment.max_sockets,
		"equipped_by_god_id": equipment.equipped_by_god_id,
		"equipped_slot": equipment.equipped_slot,
		"is_destroyed": equipment.is_destroyed,
		"origin_dungeon": equipment.origin_dungeon,
		"lore_text": equipment.lore_text,
	}

## Deserialize Dictionary back to Equipment object
static func deserialize_equipment(data: Dictionary) -> Equipment:
	var equipment := Equipment.new()
	equipment.id = data.get("id", "")
	equipment.name = data.get("name", "")
	equipment.type = data.get("type", 0)
	equipment.rarity = data.get("rarity", 0)
	equipment.level = data.get("level", 0)
	equipment.slot = data.get("slot", 1)
	equipment.equipment_set_name = data.get("equipment_set_name", "")
	equipment.equipment_set_type = data.get("equipment_set_type", "")
	equipment.main_stat_type = data.get("main_stat_type", "")
	equipment.main_stat_value = data.get("main_stat_value", 0)
	equipment.main_stat_base = data.get("main_stat_base", 0)
	equipment.substats = data.get("substats", []).duplicate()
	equipment.sockets = data.get("sockets", []).duplicate(true)
	equipment.max_sockets = data.get("max_sockets", 0)
	equipment.equipped_by_god_id = data.get("equipped_by_god_id", "")
	equipment.equipped_slot = data.get("equipped_slot", -1)
	equipment.is_destroyed = data.get("is_destroyed", false)
	equipment.origin_dungeon = data.get("origin_dungeon", "")
	equipment.lore_text = data.get("lore_text", "")

	return equipment

## Serialize complete game state
static func serialize_game_state(player_data) -> Dictionary:
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_ticks_msec(),
		"player_level": player_data.level if player_data.has("level") else 1,
		"resources": player_data.resources.duplicate() if player_data.has("resources") else {},
		"gods": [],
		"equipment": [],
		"territories": [],
		"settings": {}
	}
	
	# Serialize gods
	if player_data.has("gods"):
		for god in player_data.gods:
			save_data.gods.append(serialize_god(god))
	
	# Serialize equipment
	if player_data.has("equipment"):
		for equipment in player_data.equipment:
			save_data.equipment.append(serialize_equipment(equipment))
	
	# Serialize territories (simplified)
	if player_data.has("territories"):
		save_data.territories = player_data.territories.duplicate()
	
	return save_data

## Deserialize complete game state
static func deserialize_game_state(save_data: Dictionary) -> Dictionary:
	# Version check
	var save_version = save_data.get("version", "0.0")
	if save_version != SAVE_VERSION:
		push_warning("SaveLoadUtility: Save version mismatch. Expected: " + SAVE_VERSION + ", Got: " + save_version)
	
	var player_data = {
		"level": save_data.get("player_level", 1),
		"resources": save_data.get("resources", {}).duplicate(),
		"gods": [],
		"equipment": [],
		"territories": save_data.get("territories", []).duplicate()
	}
	
	# Deserialize gods
	for god_data in save_data.get("gods", []):
		var god = deserialize_god(god_data)
		if god:
			player_data.gods.append(god)
	
	# Deserialize equipment
	for equipment_data in save_data.get("equipment", []):
		var equipment = deserialize_equipment(equipment_data)
		if equipment:
			player_data.equipment.append(equipment)
	
	return player_data

## Save game to file
static func save_game(player_data) -> bool:
	var save_data = serialize_game_state(player_data)
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveLoadUtility: Could not open save file for writing")
		return false
	
	var json_string = JSON.stringify(save_data)
	file.store_string(json_string)
	file.close()

	return true

## Load game from file
static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		push_warning("SaveLoadUtility: No save file found")
		return {}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveLoadUtility: Could not open save file for reading")
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("SaveLoadUtility: Error parsing save file: " + json.error_string)
		return {}
	
	var save_data = json.data
	return deserialize_game_state(save_data)

## Check if save file exists
static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

## Delete save file
static func delete_save_file() -> bool:
	if has_save_file():
		var result = DirAccess.remove_absolute(SAVE_FILE_PATH)
		return result == OK
	return true

## Calculate god's max HP using EquipmentStatCalculator (RULE 3 compliance)
static func _calculate_god_max_hp(god: God) -> int:
	var equipment_stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator")
	if equipment_stat_calc:
		var total_stats = equipment_stat_calc.calculate_god_total_stats(god)
		return total_stats.hp
	else:
		# Fallback to base stats if system not available
		return god.base_hp

## Recalculate base stats for a god based on their level
## Used for legacy saves that don't have base stats saved
static func _recalculate_base_stats_for_level(god: God) -> void:
	# Get the original base stats from the template
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	if not config_manager:
		return

	var god_data = config_manager.get_god_config(god.template_id)
	if not god_data:
		return

	# Get original template stats
	var base_stats = god_data.get("base_stats", {})
	var original_hp = base_stats.get("hp", god_data.get("base_hp", 100))
	var original_attack = base_stats.get("attack", god_data.get("base_attack", 50))
	var original_defense = base_stats.get("defense", god_data.get("base_defense", 30))
	var original_speed = base_stats.get("speed", god_data.get("base_speed", 100))

	# Get stat bonuses per level based on tier (must match GodProgressionManager)
	var stat_bonuses = {
		1: {"attack": 10, "defense": 8, "hp": 25, "speed": 2},
		2: {"attack": 12, "defense": 10, "hp": 30, "speed": 2},
		3: {"attack": 15, "defense": 12, "hp": 40, "speed": 3},
		4: {"attack": 20, "defense": 15, "hp": 50, "speed": 3},
		5: {"attack": 25, "defense": 18, "hp": 65, "speed": 4}
	}

	var tier_bonuses = stat_bonuses.get(god.tier, stat_bonuses[1])
	var levels_gained = god.level - 1

	# Recalculate base stats
	god.base_hp = original_hp + (tier_bonuses.hp * levels_gained)
	god.base_attack = original_attack + (tier_bonuses.attack * levels_gained)
	god.base_defense = original_defense + (tier_bonuses.defense * levels_gained)
	god.base_speed = original_speed + (tier_bonuses.speed * levels_gained)

	print("SaveLoadUtility: Recalculated base stats for %s (level %d)" % [god.name, god.level])
