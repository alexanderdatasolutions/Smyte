# scripts/data/Skill.gd
# Represents a skill/ability that can be used in battle
class_name Skill extends Resource

@export var skill_id: String
@export var name: String
@export var description: String
@export var icon_path: String = ""  # Path to PNG icon
@export var cooldown: int = 0
@export var damage_multiplier: float = 1.0
@export var target_count: int = 1
@export var targets_enemies: bool = true

# Cache for abilities data
static var _abilities_cache: Dictionary = {}

## Load abilities data from JSON file
static func _load_abilities_data() -> Dictionary:
	if not _abilities_cache.is_empty():
		return _abilities_cache

	var file = FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if not file:
		push_warning("Skill: Could not open abilities.json")
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("Skill: Error parsing abilities.json")
		return {}

	_abilities_cache = json.get_data()
	return _abilities_cache

## Load skill from ID using abilities.json data
static func load_from_id(id: String) -> Skill:
	var skill = Skill.new()
	skill.skill_id = id

	var abilities_data = _load_abilities_data()
	var ability_dict = abilities_data.get("abilities", {})

	if ability_dict.has(id):
		var data = ability_dict[id]
		skill.name = data.get("name", id.capitalize())
		skill.description = data.get("description", "A skill")
		skill.icon_path = data.get("icon_path", "")
		skill.cooldown = data.get("cooldown", 0)
		skill.damage_multiplier = data.get("damage_multiplier", 1.0)
		skill.targets_enemies = _parse_targets_enemies(data.get("targets", "single"))
		skill.target_count = _parse_target_count(data.get("targets", "single"))
	else:
		# Fallback for unknown skills
		skill.name = id.capitalize()
		skill.description = "A skill"

	return skill

## Parse targets field to determine if targeting enemies
static func _parse_targets_enemies(targets: String) -> bool:
	match targets:
		"all_allies", "single_ally", "self":
			return false
		_:
			return true

## Parse targets field to determine target count
static func _parse_target_count(targets: String) -> int:
	match targets:
		"all_enemies", "all_allies", "all":
			return 99  # High number to indicate all targets
		_:
			return 1

## Create a basic attack skill
static func create_basic_attack() -> Skill:
	var skill = Skill.new()
	skill.skill_id = "basic_attack"
	skill.name = "Basic Attack"
	skill.description = "A simple attack"
	skill.cooldown = 0
	skill.damage_multiplier = 1.0
	skill.target_count = 1
	skill.targets_enemies = true
	return skill

## Get target count for this skill
func get_target_count() -> int:
	return target_count

## Check if this skill targets enemies
func is_targeting_enemies() -> bool:
	return targets_enemies

## Get damage multiplier
func get_damage_multiplier() -> float:
	return damage_multiplier
