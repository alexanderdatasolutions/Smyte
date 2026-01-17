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
		"id": god.id,
		"level": god.level,
		"experience": god.experience,
		"skill_levels": god.skill_levels.duplicate(),
		"equipment": god.equipment.duplicate(),  # Use correct property name
		"current_hp": god.current_hp,
		"max_hp": _calculate_god_max_hp(god),
		"awakened": god.is_awakened,  # Use correct property name
		"primary_role": god.primary_role,
		"secondary_role": god.secondary_role,
		"specialization_path": god.specialization_path.duplicate()
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
		"slot": equipment.slot,
		"equipment_set_name": equipment.equipment_set_name,
		"main_stat_type": equipment.main_stat_type,
		"main_stat_value": equipment.main_stat_value,
		"substats": equipment.substats.duplicate(),
		"level": equipment.level
	}

## Deserialize Dictionary back to Equipment object
static func deserialize_equipment(data: Dictionary) -> Equipment:
	var equipment = Equipment.new()
	equipment.id = data.get("id", "")
	equipment.slot = data.get("slot", 1)
	equipment.equipment_set_name = data.get("equipment_set_name", "")
	equipment.main_stat_type = data.get("main_stat_type", "")
	equipment.main_stat_value = data.get("main_stat_value", 0)
	equipment.substats = data.get("substats", []).duplicate()
	equipment.level = data.get("level", 0)
	
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
