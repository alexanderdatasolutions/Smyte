# scripts/data/Equipment.gd
extends Resource
class_name Equipment

enum EquipmentType { WEAPON, ARMOR, HELM, BOOTS, AMULET, RING }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }

@export var id: String = ""
@export var name: String = ""
@export var type: EquipmentType
@export var rarity: Rarity
@export var level: int = 0  # Enhancement level (0-15)
@export var slot: int = 1   # Equipment slot (1-6)

# Set information
@export var equipment_set_name: String = ""
@export var equipment_set_type: String = ""

# Main stat (always present)
@export var main_stat_type: String = ""
@export var main_stat_value: int = 0
@export var main_stat_base: int = 0

# Substats (up to 4)
@export var substats: Array[Dictionary] = []

# Sockets and gems
@export var sockets: Array[Dictionary] = []  # Socket types and gems
@export var max_sockets: int = 0

# Equipment origin/lore
@export var origin_dungeon: String = ""
@export var lore_text: String = ""

# Static equipment configuration data
static var equipment_config: Dictionary = {}
static var config_loaded: bool = false

# Load equipment configuration from JSON
static func load_equipment_config():
	if config_loaded:
		return
	
	var file = FileAccess.open("res://data/equipment.json", FileAccess.READ)
	if not file:
		push_error("Failed to load equipment.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse equipment.json: " + json.error_string)
		return
	
	equipment_config = json.get_data()
	config_loaded = true
	print("Equipment: Loaded configuration with ", equipment_config.size(), " sections")

# Create equipment from dungeon drop
static func create_from_dungeon(dungeon_id: String, equipment_type: String, rarity_str: String, item_level: int = 1) -> Equipment:
	load_equipment_config()
	
	var equipment = Equipment.new()
	equipment.id = generate_equipment_id()
	equipment.level = 0  # Always start at +0
	equipment.rarity = string_to_rarity(rarity_str)
	
	# Determine equipment type and slot
	var type_info = _get_equipment_type_info(equipment_type)
	if type_info.is_empty():
		push_error("Unknown equipment type: " + equipment_type)
		return null
	
	equipment.type = string_to_type(equipment_type)
	equipment.slot = type_info.slot
	equipment.name = _generate_equipment_name(equipment_type, rarity_str)
	
	# Set information
	equipment.equipment_set_type = _choose_random_set_for_type(equipment_type)
	equipment.equipment_set_name = _get_set_display_name(equipment.equipment_set_type)
	
	# Generate main stat
	_generate_main_stat(equipment, equipment_type, rarity_str, item_level)
	
	# Generate substats
	_generate_substats(equipment, equipment_type, rarity_str)
	
	# Set sockets
	equipment.max_sockets = _get_max_sockets_for_rarity(rarity_str)
	equipment.sockets = _generate_sockets(equipment.max_sockets)
	
	# Set origin info
	equipment.origin_dungeon = dungeon_id
	equipment.lore_text = _get_equipment_lore(equipment_type)
	
	return equipment

# Static factory method for creating test equipment with reasonable stats
static func create_test_equipment(equipment_type: String, rarity_str: String = "common", enhancement_level: int = 0) -> Equipment:
	load_equipment_config()
	
	var equipment = Equipment.new()
	equipment.id = generate_equipment_id()
	equipment.level = enhancement_level
	equipment.rarity = string_to_rarity(rarity_str)
	
	# Determine equipment type and slot
	var type_info = _get_equipment_type_info(equipment_type)
	if type_info.is_empty():
		push_error("Unknown equipment type: " + equipment_type)
		return null
	
	equipment.type = string_to_type(equipment_type)
	equipment.slot = type_info.slot
	equipment.name = _generate_equipment_name(equipment_type, rarity_str)
	
	# Set information
	equipment.equipment_set_type = _choose_random_set_for_type(equipment_type)
	equipment.equipment_set_name = _get_set_display_name(equipment.equipment_set_type)
	
	# Generate main stat
	_generate_main_stat(equipment, equipment_type, rarity_str, 1)
	
	# Generate substats
	_generate_substats(equipment, equipment_type, rarity_str)
	
	# Set sockets
	equipment.max_sockets = _get_max_sockets_for_rarity(rarity_str)
	equipment.sockets = _generate_sockets(equipment.max_sockets)
	
	# Set test origin info
	equipment.origin_dungeon = "test_dungeon"
	equipment.lore_text = "Test equipment generated for demonstration purposes."
	
	return equipment

# Generate a unique equipment ID
static func generate_equipment_id() -> String:
	var timestamp = str(Time.get_unix_time_from_system())
	var random_part = str(randi_range(1000, 9999))
	return "eq_" + timestamp + "_" + random_part

# Convert string to rarity enum
static func string_to_rarity(rarity_string: String) -> Rarity:
	match rarity_string.to_lower():
		"common": return Rarity.COMMON
		"rare": return Rarity.RARE
		"epic": return Rarity.EPIC
		"legendary": return Rarity.LEGENDARY
		"mythic": return Rarity.MYTHIC
		_: return Rarity.COMMON

# Convert string to type enum
static func string_to_type(type_str: String) -> EquipmentType:
	match type_str.to_lower():
		"weapon": return EquipmentType.WEAPON
		"armor": return EquipmentType.ARMOR
		"helm": return EquipmentType.HELM
		"boots": return EquipmentType.BOOTS
		"amulet": return EquipmentType.AMULET
		"ring": return EquipmentType.RING
		_: return EquipmentType.WEAPON

# Convert rarity enum to string
static func rarity_to_string(rarity_enum: Rarity) -> String:
	match rarity_enum:
		Rarity.COMMON: return "common"
		Rarity.RARE: return "rare"
		Rarity.EPIC: return "epic"
		Rarity.LEGENDARY: return "legendary"
		Rarity.MYTHIC: return "mythic"
		_: return "common"

# Convert type enum to string
static func type_to_string(type_enum: EquipmentType) -> String:
	match type_enum:
		EquipmentType.WEAPON: return "weapon"
		EquipmentType.ARMOR: return "armor"
		EquipmentType.HELM: return "helm"
		EquipmentType.BOOTS: return "boots"
		EquipmentType.AMULET: return "amulet"
		EquipmentType.RING: return "ring"
		_: return "weapon"

# Get equipment's total stat bonuses
func get_stat_bonuses() -> Dictionary:
	var bonuses = {}
	
	# Add main stat
	if main_stat_type != "":
		bonuses[main_stat_type] = bonuses.get(main_stat_type, 0) + main_stat_value
	
	# Add substats
	for substat in substats:
		var stat_type = substat.get("type", "")
		var stat_value = substat.get("value", 0)
		if stat_type != "":
			bonuses[stat_type] = bonuses.get(stat_type, 0) + stat_value
	
	# Add socket bonuses
	for socket in sockets:
		if socket.has("gem") and socket.gem != null:
			var gem_bonuses = _get_gem_stat_bonuses(socket.gem)
			for stat_type in gem_bonuses:
				bonuses[stat_type] = bonuses.get(stat_type, 0) + gem_bonuses[stat_type]
	
	return bonuses

# Get equipment display name with enhancement level
func get_display_name() -> String:
	var base_name = name
	if level > 0:
		base_name += " (+" + str(level) + ")"
	return base_name

# Get equipment color based on rarity
func get_rarity_color() -> Color:
	load_equipment_config()
	var rarities = equipment_config.get("equipment_rarities", {})
	var rarity_key = rarity_to_string(rarity)
	var color_hex = rarities.get(rarity_key, {}).get("color", "#FFFFFF")
	return Color(color_hex)

# Check if equipment can be enhanced
func can_enhance() -> bool:
	var max_level = equipment_config.get("enhancement_system", {}).get("max_level", 15)
	return level < max_level

# Get enhancement cost
func get_enhancement_cost() -> Dictionary:
	load_equipment_config()
	var enhancement = equipment_config.get("enhancement_system", {})
	var costs = enhancement.get("enhancement_costs", {})
	
	var base_cost = costs.get("divine_essence_base", 500)
	var level_mult = costs.get("level_multiplier", 2.0)
	var rarity_mult = costs.get("rarity_multipliers", {}).get(rarity_to_string(rarity), 1.0)
	
	var total_cost = int(base_cost * pow(level_mult, level) * rarity_mult)
	
	return {
		"divine_essence": total_cost
	}

# Get enhancement success chance
func get_enhancement_chance() -> float:
	load_equipment_config()
	var enhancement = equipment_config.get("enhancement_system", {})
	var chances = enhancement.get("enhancement_chances", {})
	return chances.get(str(level), 0.4)

# Private helper methods
static func _get_equipment_type_info(equipment_type: String) -> Dictionary:
	load_equipment_config()
	var types = equipment_config.get("equipment_types", {})
	return types.get(equipment_type, {})

static func _generate_equipment_name(equipment_type: String, rarity_str: String) -> String:
	var type_info = _get_equipment_type_info(equipment_type)
	var type_name = type_info.get("name", "Divine Item")
	
	# Add rarity prefix
	var rarity_config = equipment_config.get("equipment_rarities", {}).get(rarity_str, {})
	var rarity_name = rarity_config.get("name", "Common")
	
	return rarity_name + " " + type_name

static func _choose_random_set_for_type(equipment_type: String) -> String:
	var type_info = _get_equipment_type_info(equipment_type)
	var available_sets = type_info.get("set_types", ["guardian"])
	return available_sets[randi() % available_sets.size()]

static func _get_set_display_name(set_type_str: String) -> String:
	load_equipment_config()
	var sets = equipment_config.get("equipment_sets", {})
	return sets.get(set_type_str, {}).get("name", set_type_str.capitalize())

static func _generate_main_stat(equipment: Equipment, equipment_type: String, rarity_str: String, _item_level: int):
	var type_info = _get_equipment_type_info(equipment_type)
	var primary_stats = type_info.get("primary_stats", ["attack"])
	
	# Choose random primary stat
	equipment.main_stat_type = primary_stats[randi() % primary_stats.size()]
	
	# Get stat range from configuration
	var stat_ranges = equipment_config.get("stat_ranges", {}).get("base_values", {})
	var stat_range = stat_ranges.get(equipment.main_stat_type, {}).get(equipment_type, [10, 50])
	
	# Apply rarity multiplier
	var rarity_config = equipment_config.get("equipment_rarities", {}).get(rarity_str, {})
	var multiplier = rarity_config.get("stat_multiplier", 1.0)
	
	var min_value = int(stat_range[0] * multiplier)
	var max_value = int(stat_range[1] * multiplier)
	
	equipment.main_stat_base = randi_range(min_value, max_value)
	equipment.main_stat_value = equipment.main_stat_base

static func _generate_substats(equipment: Equipment, equipment_type: String, rarity_str: String):
	var rarity_config = equipment_config.get("equipment_rarities", {}).get(rarity_str, {})
	var max_substats = rarity_config.get("max_substats", 2)
	
	if max_substats == 0:
		return
	
	var type_info = _get_equipment_type_info(equipment_type)
	var available_stats = type_info.get("secondary_stats", ["hp", "defense"])
	
	# Remove main stat from available substats
	var filtered_stats = []
	for stat in available_stats:
		if stat != equipment.main_stat_type:
			filtered_stats.append(stat)
	
	# Generate substats
	var num_substats = randi_range(1, max_substats)
	
	for i in range(num_substats):
		if filtered_stats.size() == 0:
			break
		
		var stat_index = randi() % filtered_stats.size()
		var stat_type = filtered_stats[stat_index]
		filtered_stats.remove_at(stat_index)
		
		var stat_ranges = equipment_config.get("stat_ranges", {}).get("substat_values", {})
		var stat_range = stat_ranges.get(stat_type, [5, 25])
		var stat_value = randi_range(stat_range[0], stat_range[1])
		
		equipment.substats.append({
			"type": stat_type,
			"value": stat_value,
			"powerups": 0
		})

static func _get_max_sockets_for_rarity(rarity_str: String) -> int:
	load_equipment_config()
	var socket_config = equipment_config.get("socketing_system", {})
	var max_socket_config = socket_config.get("max_sockets", {})
	return max_socket_config.get(rarity_str, 0)

static func _generate_sockets(socket_count: int) -> Array[Dictionary]:
	var socket_list: Array[Dictionary] = []
	var socket_types = ["red", "blue", "yellow", "green"]
	
	for i in range(socket_count):
		var socket_type = socket_types[randi() % socket_types.size()]
		socket_list.append({
			"type": socket_type,
			"gem": null,
			"unlocked": false
		})
	
	return socket_list

static func _get_equipment_lore(equipment_type: String) -> String:
	load_equipment_config()
	var origins = equipment_config.get("equipment_origins", {})
	return origins.get(equipment_type, {}).get("lore", "A mysterious piece of divine equipment.")

static func _get_gem_stat_bonuses(gem_id: String) -> Dictionary:
	load_equipment_config()
	var gems = equipment_config.get("gem_types", {})
	var gem_info = gems.get(gem_id, {})
	return gem_info.get("stat_bonus", {})
