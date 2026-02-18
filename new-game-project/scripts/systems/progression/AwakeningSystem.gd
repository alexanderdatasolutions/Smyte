# scripts/systems/AwakeningSystem.gd
extends Node
class_name AwakeningSystem

signal awakening_completed(god: God)
signal awakening_failed(god: God, reason: String)

# Awakened gods data (per-god definitions from awakened_gods.json)
var awakening_data: Dictionary = {}

# Awakening system config (requirements, costs, bonuses from awakening_config.json)
static var _config: Dictionary = {}
static var _config_loaded: bool = false

func _ready() -> void:
	_load_config()
	load_awakening_data()

static func _load_config() -> void:
	if _config_loaded:
		return
	var file: FileAccess = FileAccess.open("res://data/awakening_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			_config = parsed as Dictionary
		else:
			push_warning("AwakeningSystem: Failed to parse awakening_config.json")
			_config = {}
	else:
		push_warning("AwakeningSystem: awakening_config.json not found, using defaults")
		_config = {}
	_config_loaded = true

static func get_required_level() -> int:
	var reqs: Dictionary = _config.get("requirements", {})
	return int(reqs.get("base_god_level", 40))

static func get_awakened_level_cap() -> int:
	return int(_config.get("awakened_level_cap", 50))

static func get_costs_for_tier(tier_name: String) -> Dictionary:
	var costs_by_tier: Dictionary = _config.get("costs_by_tier", {})
	return costs_by_tier.get(tier_name, {})

static func get_stat_bonuses() -> Dictionary:
	return _config.get("stat_bonuses", {
		"hp_percent": 10, "attack_percent": 10,
		"defense_percent": 10, "speed_percent": 5
	})

static func get_default_base_stats() -> Dictionary:
	return _config.get("default_base_stats", {
		"hp": 1000, "attack": 500, "defense": 400, "speed": 100
	})

static func get_default_resource_generation() -> float:
	return float(_config.get("default_resource_generation", 15))

func load_awakening_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/awakened_gods.json", FileAccess.READ)
	if not file:
		awakening_data = {}
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result: int = json.parse(json_text)
	if parse_result != OK:
		return

	var data: Variant = json.get_data()
	if data is Dictionary:
		awakening_data = data as Dictionary

func can_awaken_god(god: God) -> Dictionary:
	var result: Dictionary = {
		"can_awaken": false,
		"missing_requirements": [],
		"requirements_met": [],
		"awakened_god_id": ""
	}

	# Check if awakened version exists for this god
	var awakened_god_id: String = god.id + "_awakened"
	var awakened_gods: Dictionary = awakening_data.get("awakened_gods", {})
	var awakened_god_data: Dictionary = awakened_gods.get(awakened_god_id, {})
	if awakened_god_data.is_empty():
		result.missing_requirements.append("No awakened form available for " + god.name)
		return result

	result.awakened_god_id = awakened_god_id

	# Check basic god requirements
	if god.is_awakened:
		result.missing_requirements.append("Already awakened")
		return result

	# Get requirements from config (with fallback to awakened_gods.json for backwards compat)
	var config_reqs: Dictionary = _config.get("requirements", {})
	var json_reqs: Dictionary = awakening_data.get("awakening_requirements", {})
	var requirements: Dictionary = config_reqs if not config_reqs.is_empty() else json_reqs

	# Level requirement
	var required_level: int = int(requirements.get("base_god_level", 40))
	if god.level >= required_level:
		result.requirements_met.append("Level %d" % required_level)
	else:
		result.missing_requirements.append("Level %d (currently %d)" % [required_level, god.level])

	# Max level requirement
	if requirements.get("base_god_max_level", false):
		var max_level: int = God.get_max_level()
		if god.level >= max_level:
			result.requirements_met.append("Max level")
		else:
			result.missing_requirements.append("Must be max level (%d)" % max_level)

	# Skills at level 1 (simple requirement)
	if requirements.get("all_skills_level_1", false):
		result.requirements_met.append("Basic skill requirements")

	result.can_awaken = result.missing_requirements.size() == 0
	return result

func get_awakening_requirements(god: God) -> Dictionary:
	var god_awakening: Dictionary = awakening_data.get("awakened_gods", {}).get(god.id, {})
	return god_awakening.get("awakening_requirements", {})

func get_awakening_materials_cost(god: God) -> Dictionary:
	# Always use tier-based costs from awakening_config.json (per-god materials in
	# awakened_gods.json use legacy/invalid material IDs)
	var tier_name: String = God.tier_to_string(god.tier)
	return get_costs_for_tier(tier_name)

func attempt_awakening(god: God) -> bool:
	var requirements_check: Dictionary = can_awaken_god(god)
	if not requirements_check.can_awaken:
		awakening_failed.emit(god, "Requirements not met")
		return false

	# Check materials in player inventory
	var materials_needed: Dictionary = get_awakening_materials_cost(god)
	var materials_check: Dictionary = check_awakening_materials(materials_needed)

	if not materials_check.can_afford:
		awakening_failed.emit(god, "Insufficient materials")
		return false

	# Consume materials
	consume_awakening_materials(materials_needed)

	# Get awakened god data
	var awakened_god_id: String = requirements_check.awakened_god_id
	var awakened_god_data: Dictionary = awakening_data.get("awakened_gods", {}).get(awakened_god_id, {})

	# Replace the god with the awakened version
	if replace_god_with_awakened(god, awakened_god_data):
		awakening_completed.emit(god)
		_show_awakening_notification(god)
		return true
	else:
		awakening_failed.emit(god, "Awakening process failed")
		return false

func _show_awakening_notification(god: God) -> void:
	var main_loop: SceneTree = Engine.get_main_loop() as SceneTree
	if not main_loop:
		return
	var root: Node = main_loop.current_scene
	if not root:
		return

	var awakened_cap: int = get_awakened_level_cap()
	var GenericPopupClass: Variant = load("res://scripts/ui/components/GenericPopup.gd")
	if GenericPopupClass:
		GenericPopupClass.show_popup(root, {
			"title": "Awakening Complete!",
			"message": "%s has awakened!\n\nLevel cap increased to %d\nNew abilities unlocked!" % [god.name, awakened_cap],
			"icon": "",
			"accent": "feature",
			"buttons": [{"id": "ok", "text": "Amazing!", "primary": true}]
		})

func replace_god_with_awakened(old_god: God, awakened_data: Dictionary) -> bool:
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return false
	var collection_manager: Variant = registry.get_system("CollectionManager")
	if not collection_manager:
		return false

	# Find the god in player's collection
	var god_index: int = -1
	for i: int in range(collection_manager.gods.size()):
		if collection_manager.gods[i] == old_god:
			god_index = i
			break

	if god_index == -1:
		return false

	# Create the awakened god from the JSON data
	var awakened_god: God = create_awakened_god_from_data(awakened_data)
	if not awakened_god:
		return false

	# Preserve some stats from the original god
	awakened_god.level = old_god.level
	awakened_god.experience = old_god.experience
	awakened_god.ascension_level = old_god.ascension_level
	var dup_skill_levels: Array[int] = []
	for sl: int in old_god.skill_levels:
		dup_skill_levels.append(sl)
	awakened_god.skill_levels = dup_skill_levels
	awakened_god.stationed_territory = old_god.stationed_territory

	# Mark as awakened
	awakened_god.is_awakened = true

	# Replace in collection
	collection_manager.gods[god_index] = awakened_god

	return true

func create_awakened_god_from_data(awakened_data: Dictionary) -> God:
	var god := God.new()

	# Basic info
	god.id = awakened_data.get("id", "")
	god.name = awakened_data.get("name", "")
	god.pantheon = awakened_data.get("pantheon", "")
	god.element = God.string_to_element(awakened_data.get("element", "light"))
	god.tier = God.string_to_tier(awakened_data.get("tier", "legendary"))

	# Stats - use per-god stats with config defaults as fallback
	var defaults: Dictionary = get_default_base_stats()
	var base_stats: Dictionary = awakened_data.get("base_stats", {})
	god.base_hp = int(base_stats.get("hp", defaults.get("hp", 1000)))
	god.base_attack = int(base_stats.get("attack", defaults.get("attack", 500)))
	god.base_defense = int(base_stats.get("defense", defaults.get("defense", 400)))
	god.base_speed = int(base_stats.get("speed", defaults.get("speed", 100)))
	god.resource_generation = int(awakened_data.get("resource_generation", get_default_resource_generation()))

	# Abilities
	god.active_abilities = awakened_data.get("active_abilities", [])
	god.passive_abilities = awakened_data.get("passive_abilities", [])

	return god

func check_awakening_materials(materials_needed: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"can_afford": true,
		"missing_materials": []
	}

	for material_type: String in materials_needed.keys():
		var needed_amount: int = int(materials_needed[material_type])
		var current_amount: int = get_player_material_amount(material_type)

		if current_amount < needed_amount:
			result.can_afford = false
			result.missing_materials.append({
				"type": material_type,
				"needed": needed_amount,
				"current": current_amount,
				"missing": needed_amount - current_amount
			})

	return result

func consume_awakening_materials(materials_needed: Dictionary) -> void:
	for material_type: String in materials_needed.keys():
		var amount: int = int(materials_needed[material_type])
		consume_player_material(material_type, amount)

func get_player_material_amount(material_type: String) -> int:
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return 0
	var resource_manager: Variant = registry.get_system("ResourceManager")
	if not resource_manager:
		return 0
	return resource_manager.get_resource(material_type)

func consume_player_material(material_type: String, amount: int) -> void:
	var registry: Variant = SystemRegistry.get_instance()
	if not registry:
		return
	var resource_manager: Variant = registry.get_system("ResourceManager")
	if resource_manager:
		resource_manager.spend_resource(material_type, amount)
