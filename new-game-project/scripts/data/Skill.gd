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

# Scaling type: "attack" (default), "MAX_HP" (caster HP), "target_max_hp" (enemy HP)
@export var scaling_stat: String = "attack"
# For target_max_hp scaling, the percentage of target HP as bonus damage
@export var target_hp_percent: float = 0.0
# Whether this skill ignores a percentage of defense
@export var ignore_def_percent: float = 0.0
# Whether this skill always hits (no glancing)
@export var always_hit: bool = false
# Number of hits for multi-hit skills
@export var multi_hit: int = 1

# Cache for abilities data
static var _abilities_cache: Dictionary = {}
static var _awakened_abilities_cache: Dictionary = {}

## Clear the static abilities cache to free memory.
## Call during scene transitions or when memory pressure is high.
static func clear_cache() -> void:
	_abilities_cache = {}
	_awakened_abilities_cache = {}

## Load abilities data from JSON file
static func _load_abilities_data() -> Dictionary:
	if not _abilities_cache.is_empty():
		return _abilities_cache

	var file := FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if not file:
		push_warning("Skill: Could not open abilities.json")
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("Skill: Error parsing abilities.json")
		return {}

	_abilities_cache = json.get_data()
	return _abilities_cache

## Load awakened god abilities data from JSON file
static func _load_awakened_abilities() -> Dictionary:
	if not _awakened_abilities_cache.is_empty():
		return _awakened_abilities_cache

	var file := FileAccess.open("res://data/awakened_gods.json", FileAccess.READ)
	if not file:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}

	var data: Dictionary = json.get_data()
	# Build a flat map of ability_id -> ability_data from all awakened gods
	var awakened_gods: Dictionary = data.get("awakened_gods", {})
	for god_id: String in awakened_gods:
		var god_data: Dictionary = awakened_gods[god_id]
		for ability: Dictionary in god_data.get("active_abilities", []):
			var ability_id: String = ability.get("id", "")
			if ability_id != "":
				_awakened_abilities_cache[ability_id] = ability

	return _awakened_abilities_cache

## Load skill from ID using abilities.json data (with awakened_gods.json fallback)
static func load_from_id(id: String) -> Skill:
	var skill := Skill.new()
	skill.skill_id = id

	var abilities_data := _load_abilities_data()
	var ability_dict: Dictionary = abilities_data.get("abilities", {})

	var data: Dictionary = {}

	if ability_dict.has(id):
		data = ability_dict[id]
	else:
		# Fallback: check awakened gods abilities
		var awakened_abilities := _load_awakened_abilities()
		if awakened_abilities.has(id):
			data = awakened_abilities[id]

	if not data.is_empty():
		skill.name = data.get("name", id.capitalize())
		skill.description = data.get("description", "A skill")
		skill.icon_path = data.get("icon_path", "")
		skill.cooldown = int(data.get("cooldown", 0))
		skill.damage_multiplier = float(data.get("damage_multiplier", 1.0))
		var targets_str: String = data.get("targets", "single")
		skill.targets_enemies = _parse_targets_enemies(targets_str)
		skill.target_count = _parse_target_count(targets_str)

		# Parse scaling stat (attack, MAX_HP, or target_max_hp)
		skill.scaling_stat = data.get("scaling_stat", "attack")

		# Parse additional properties from effects array
		var effects: Array = data.get("effects", [])
		for effect: Variant in effects:
			if effect is Dictionary:
				var effect_dict: Dictionary = effect
				var effect_type: String = effect_dict.get("type", "")

				# Check for damage effects with special scaling
				if effect_type == "damage":
					var scaling: String = effect_dict.get("scaling", "")
					if scaling == "target_max_hp":
						skill.scaling_stat = "target_max_hp"
						skill.target_hp_percent = float(effect_dict.get("value", 0.0))
					elif scaling == "MAX_HP":
						skill.scaling_stat = "MAX_HP"

					# Check for defense ignore
					skill.ignore_def_percent = float(effect_dict.get("ignore_def_percent", 0.0))
					skill.always_hit = effect_dict.get("always_hit", false)
					skill.multi_hit = int(effect_dict.get("hits", 1))
	else:
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
	var skill := Skill.new()
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
