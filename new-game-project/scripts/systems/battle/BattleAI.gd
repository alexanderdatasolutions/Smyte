# scripts/systems/battle/BattleAI.gd
# Simple AI for enemy units - keeps it focused and minimal
class_name BattleAI extends RefCounted

## Choose the best action for an enemy unit (following the guide pattern)
static func choose_action(unit: BattleUnit, battle_state: BattleState) -> BattleAction:
	if not unit or not unit.is_alive:
		return null
	
	# Simple AI priority:
	# 1. Use most powerful available skill
	# 2. Target lowest HP enemy
	# 3. Fall back to basic attack
	
	var potential_targets = battle_state.get_living_player_units()
	if potential_targets.is_empty():
		return null
	
	# Try to use skills from most powerful to least
	for i in range(unit.skills.size() - 1, -1, -1):
		if unit.can_use_skill(i):
			var skill = unit.skills[i]
			var targets = _choose_targets(skill, potential_targets)
			if not targets.is_empty():
				return BattleAction.create_skill_action(unit, skill, targets)
	
	# Fall back to basic attack on lowest HP target
	var target = _choose_lowest_hp_target(potential_targets)
	if target:
		return BattleAction.create_attack_action(unit, target)
	
	return null

## Choose targets for a skill (simple targeting)
static func _choose_targets(skill: Skill, potential_targets: Array) -> Array:  # Array[BattleUnit] -> Array[BattleUnit]
	if potential_targets.is_empty():
		return []
	
	# Sort by lowest HP first
	var sorted_targets = potential_targets.duplicate()
	sorted_targets.sort_custom(func(a, b): return a.current_hp < b.current_hp)
	
	# Return appropriate number of targets
	var target_count = skill.get_target_count()
	return sorted_targets.slice(0, min(target_count, sorted_targets.size()))

## Choose lowest HP target
static func _choose_lowest_hp_target(targets: Array) -> BattleUnit:  # Array[BattleUnit]
	if targets.is_empty():
		return null
	
	var lowest_hp_target = targets[0]
	for target in targets:
		if target.current_hp < lowest_hp_target.current_hp:
			lowest_hp_target = target
	
	return lowest_hp_target
