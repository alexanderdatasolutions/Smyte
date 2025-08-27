# scripts/data/Skill.gd
# Represents a skill/ability that can be used in battle
class_name Skill extends Resource

@export var skill_id: String
@export var name: String
@export var description: String
@export var cooldown: int = 0
@export var damage_multiplier: float = 1.0
@export var target_count: int = 1
@export var targets_enemies: bool = true

## Load skill from ID (placeholder implementation)
static func load_from_id(id: String) -> Skill:
	var skill = Skill.new()
	skill.skill_id = id
	skill.name = id.capitalize()
	skill.description = "A skill"
	return skill

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
