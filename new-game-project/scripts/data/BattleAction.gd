# scripts/data/BattleAction.gd
# Represents an action taken during battle (attack, skill use, etc.)
class_name BattleAction extends RefCounted

enum ActionType {
	ATTACK,
	SKILL,
	DEFEND,
	ITEM_USE
}

var action_type: ActionType
var caster: BattleUnit
var targets: Array[BattleUnit] = []
var skill: Skill
var item_id: String = ""

## Create an attack action
static func create_attack_action(attacker: BattleUnit, target: BattleUnit) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = ActionType.ATTACK
	action.caster = attacker
	action.targets = [target]
	return action

## Create a skill action
static func create_skill_action(p_caster: BattleUnit, p_skill: Skill, p_targets: Array[BattleUnit]) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = ActionType.SKILL
	action.caster = p_caster
	action.skill = p_skill
	action.targets = p_targets
	return action

## Create a defend action
static func create_defend_action(defender: BattleUnit) -> BattleAction:
	var action := BattleAction.new()
	action.action_type = ActionType.DEFEND
	action.caster = defender
	return action

## Get action description for UI
func get_description() -> String:
	match action_type:
		ActionType.ATTACK:
			return caster.display_name + " attacks " + targets[0].display_name
		ActionType.SKILL:
			var target_names: Array = targets.map(func(t: BattleUnit) -> String: return t.display_name)
			return caster.display_name + " uses " + skill.name + " on " + ", ".join(target_names)
		ActionType.DEFEND:
			return caster.display_name + " defends"
		_:
			return "Unknown action"
