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
var caster  # BattleUnit reference  
var targets: Array = []  # Array[BattleUnit] reference
var skill  # Skill reference
var item_id: String = ""

## Create an attack action
static func create_attack_action(attacker, target) -> BattleAction:
	var action = BattleAction.new()
	action.action_type = ActionType.ATTACK
	action.caster = attacker
	action.targets = [target]
	return action

## Create a skill action
static func create_skill_action(caster, skill, targets) -> BattleAction:
	var action = BattleAction.new()
	action.action_type = ActionType.SKILL
	action.caster = caster
	action.skill = skill
	action.targets = targets
	return action

## Create a defend action
static func create_defend_action(defender) -> BattleAction:
	var action = BattleAction.new()
	action.action_type = ActionType.DEFEND
	action.caster = defender
	return action

## Get action description for UI
func get_description() -> String:
	match action_type:
		ActionType.ATTACK:
			return caster.display_name + " attacks " + targets[0].display_name
		ActionType.SKILL:
			var target_names = targets.map(func(t): return t.display_name)
			return caster.display_name + " uses " + skill.name + " on " + ", ".join(target_names)
		ActionType.DEFEND:
			return caster.display_name + " defends"
		_:
			return "Unknown action"
