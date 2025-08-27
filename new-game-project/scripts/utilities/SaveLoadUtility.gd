# scripts/utilities/SaveLoadUtility.gd
# Standardizes all save/load operations across the game
class_name SaveLoadUtility extends RefCounted

const SAVE_VERSION = "1.0"
const SAVE_FILE_PATH = "user://save_game.dat"
const SETTINGS_FILE_PATH = "user://settings.cfg"

## Serialize a God object to Dictionary for saving
static func serialize_god(god: God) -> Dictionary:
	if not god:
		return {}
	
	return {
		"id": god.id,
		"level": god.level,
		"experience": god.experience,
		"skill_levels": god.skill_levels.duplicate(),
		"equipped_equipment_ids": god.equipped_equipment_ids.duplicate(),
		"current_hp": god.current_hp,
		"max_hp": god.get_max_hp(),
		"awakened": god.awakened if god.has_method("is_awakened") else false
	}

## Deserialize Dictionary back to God object
static func deserialize_god(data: Dictionary) -> God:
	var god = GodFactory.create_from_json(data.get("id", ""))
	if not god:
		push_error("SaveLoadUtility: Could not create god with ID: " + str(data.get("id", "")))
		return null
	
	god.level = data.get("level", 1)
	god.experience = data.get("experience", 0)
	god.skill_levels = data.get("skill_levels", [1, 1, 1]).duplicate()
	god.equipped_equipment_ids = data.get("equipped_equipment_ids", ["", "", "", "", "", ""]).duplicate()
	god.current_hp = data.get("current_hp", god.get_max_hp())
	
	# Handle awakening if the god supports it
	if god.has_method("set_awakened") and data.has("awakened"):
		god.set_awakened(data.awakened)
	
	return god

## Serialize Equipment object to Dictionary
static func serialize_equipment(equipment: Equipment) -> Dictionary:
	if not equipment:
		return {}
	
	return {
		"id": equipment.id,
		"slot": equipment.slot,
		"set_id": equipment.set_id,
		"main_stat": equipment.main_stat,
		"main_stat_value": equipment.main_stat_value,
		"sub_stats": equipment.sub_stats.duplicate(),
		"level": equipment.level,
		"owner_god_id": equipment.owner_god_id if equipment.has("owner_god_id") else ""
	}

## Deserialize Dictionary back to Equipment object
static func deserialize_equipment(data: Dictionary) -> Equipment:
	var equipment = Equipment.new()
	equipment.id = data.get("id", "")
	equipment.slot = data.get("slot", 1)
	equipment.set_id = data.get("set_id", "")
	equipment.main_stat = data.get("main_stat", 0)
	equipment.main_stat_value = data.get("main_stat_value", 0)
	equipment.sub_stats = data.get("sub_stats", []).duplicate()
	equipment.level = data.get("level", 0)
	
	if equipment.has("owner_god_id"):
		equipment.owner_god_id = data.get("owner_god_id", "")
	
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
	
	print("SaveLoadUtility: Game saved successfully")
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
