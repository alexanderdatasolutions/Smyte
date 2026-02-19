# scripts/systems/battle/BattleAI.gd
# Smart AI for both enemy units and player auto-battle
# Designed to play like an experienced player for Arena PvP
class_name BattleAI extends RefCounted

## Priority weights for target selection
const WEIGHT_KILL_POTENTIAL: float = 100.0  # Can we kill this target?
const WEIGHT_LOW_HP: float = 30.0           # HP percentage factor
const WEIGHT_THREAT: float = 50.0           # High damage dealers
const WEIGHT_HEALER: float = 70.0           # Healers are priority
const WEIGHT_DEBUFFED: float = 20.0         # Targets with debuffs
const WEIGHT_ELEMENT_ADVANTAGE: float = 25.0 # Element matchup bonus
const WEIGHT_ATB_HIGH: float = 15.0         # About to take turn

## Skill category classifications
enum SkillCategory {
	DAMAGE_SINGLE,
	DAMAGE_AOE,
	HEAL_SINGLE,
	HEAL_AOE,
	BUFF_SELF,
	BUFF_ALLY,
	BUFF_TEAM,
	DEBUFF_SINGLE,
	DEBUFF_AOE,
	CC_SINGLE,      # Crowd control (stun, freeze, etc.)
	CC_AOE,
	ATB_MANIPULATION,
	UTILITY
}

## Choose the best action for a unit (works for enemy AI and player auto-battle)
static func choose_action(unit: BattleUnit, battle_state: BattleState) -> BattleAction:
	if not unit or not unit.is_alive:
		return null

	var allies: Array[BattleUnit] = _get_allies(unit, battle_state)
	var enemies: Array[BattleUnit] = _get_enemies(unit, battle_state)

	# Handle CHARM - charmed units attack their own allies
	if unit.is_charmed():
		var charm_targets: Array[BattleUnit] = allies.filter(func(a): return a != unit and a.is_alive)
		if not charm_targets.is_empty():
			var target: BattleUnit = charm_targets[randi() % charm_targets.size()]
			return BattleAction.create_attack_action(unit, target)
		# If no allies to attack, skip turn
		return null

	# Handle PROVOKE - must attack the provoker (basic attack only)
	if unit.is_provoked():
		var provoker_name: String = unit.get_provoker_name()
		for enemy: BattleUnit in enemies:
			if enemy.display_name == provoker_name and enemy.is_alive:
				return BattleAction.create_attack_action(unit, enemy)
		# If provoker is dead, provoke breaks

	if enemies.is_empty():
		return null

	# Filter out untargetable enemies for normal targeting
	var targetable_enemies: Array[BattleUnit] = enemies.filter(func(e): return not e.is_untargetable())
	if targetable_enemies.is_empty():
		# All enemies are untargetable, can't attack
		return null

	# Evaluate all available skills and pick the best action
	var best_action: BattleAction = null
	var best_score: float = -999999.0

	for i: int in range(unit.skills.size()):
		if not unit.can_use_skill(i):
			continue

		# Silenced units can only use basic attack (skill index 0)
		if unit.is_silenced() and i > 0:
			continue

		var skill: Skill = unit.skills[i]
		var action_data: Dictionary = _evaluate_skill_action(unit, skill, i, allies, targetable_enemies, battle_state)

		if action_data.score > best_score:
			best_score = action_data.score
			best_action = action_data.action

	# If no skill is available, fall back to basic attack on best target
	if best_action == null:
		var target: BattleUnit = _select_best_target(unit, targetable_enemies, null, battle_state)
		if target:
			best_action = BattleAction.create_attack_action(unit, target)

	return best_action

## Get living allies for a unit
static func _get_allies(unit: BattleUnit, battle_state: BattleState) -> Array[BattleUnit]:
	if unit.is_player_unit:
		return battle_state.get_living_player_units()
	else:
		return battle_state.get_living_enemy_units()

## Get living enemies for a unit
static func _get_enemies(unit: BattleUnit, battle_state: BattleState) -> Array[BattleUnit]:
	if unit.is_player_unit:
		return battle_state.get_living_enemy_units()
	else:
		return battle_state.get_living_player_units()

## Evaluate a skill and return the best action using it with a score
static func _evaluate_skill_action(unit: BattleUnit, skill: Skill, _skill_index: int, allies: Array[BattleUnit], enemies: Array[BattleUnit], battle_state: BattleState) -> Dictionary:
	var category: SkillCategory = _classify_skill(skill)
	var score: float = 0.0
	var targets: Array[BattleUnit] = []

	match category:
		SkillCategory.DAMAGE_SINGLE:
			var target: BattleUnit = _select_best_target(unit, enemies, skill, battle_state)
			if target:
				targets = [target]
				score = _score_damage_action(unit, skill, target, enemies.size(), battle_state)

		SkillCategory.DAMAGE_AOE:
			targets = enemies.duplicate()
			score = _score_aoe_damage_action(unit, skill, enemies, battle_state)

		SkillCategory.HEAL_SINGLE, SkillCategory.BUFF_ALLY:
			var target: BattleUnit = _select_heal_target(unit, allies, skill)
			if target:
				targets = [target]
				score = _score_heal_action(skill, target, allies)

		SkillCategory.HEAL_AOE:
			targets = allies.duplicate()
			score = _score_team_heal_action(skill, allies)

		SkillCategory.BUFF_TEAM:
			targets = allies.duplicate()
			score = _score_team_buff_action(skill, allies)

		SkillCategory.BUFF_SELF:
			targets = [unit]
			score = _score_self_buff_action(unit, skill, battle_state)

		SkillCategory.DEBUFF_SINGLE, SkillCategory.CC_SINGLE:
			var target: BattleUnit = _select_cc_target(unit, enemies, skill, battle_state)
			if target:
				targets = [target]
				score = _score_cc_action(skill, target, enemies, battle_state)

		SkillCategory.DEBUFF_AOE, SkillCategory.CC_AOE:
			targets = enemies.duplicate()
			score = _score_aoe_cc_action(skill, enemies, battle_state)

		SkillCategory.ATB_MANIPULATION:
			var target: BattleUnit = _select_atb_target(enemies, skill)
			if target:
				targets = [target]
				score = _score_atb_action(skill, target, enemies)

		SkillCategory.UTILITY, _:
			# Default behavior for utility/unknown skills
			if skill.targets_enemies:
				var target: BattleUnit = _select_best_target(unit, enemies, skill, battle_state)
				if target:
					targets = [target]
					score = 50.0
			else:
				targets = [unit]
				score = 30.0

	# Penalize high cooldown skills if battle is almost over
	if enemies.size() == 1 and enemies[0].current_hp < enemies[0].max_hp * 0.3:
		if skill.cooldown >= 3:
			score *= 0.3  # Don't waste big cooldowns on nearly-dead last enemy

	# Create the action if we have valid targets
	var action: BattleAction = null
	if not targets.is_empty():
		action = BattleAction.create_skill_action(unit, skill, targets)

	return {"action": action, "score": score}

## Classify a skill into a category based on its properties
static func _classify_skill(skill: Skill) -> SkillCategory:
	var ability_data: Dictionary = _get_ability_data(skill.skill_id)
	var effects: Array = ability_data.get("effects", [])
	var targets_str: String = ability_data.get("targets", "single")
	var is_aoe: bool = targets_str in ["all_enemies", "all_allies", "all"]

	# Check for healing
	var has_heal: bool = false
	var has_buff: bool = false
	var has_debuff: bool = false
	var has_cc: bool = false
	var has_atb: bool = false

	for effect: Variant in effects:
		if not effect is Dictionary:
			continue
		var effect_dict: Dictionary = effect as Dictionary
		var effect_type: String = effect_dict.get("type", "")

		match effect_type:
			"buff":
				has_buff = true
			"debuff":
				var debuff_type: String = effect_dict.get("debuff", "")
				if debuff_type in ["stun", "freeze", "sleep", "fear", "provoke", "immobilize"]:
					has_cc = true
				else:
					has_debuff = true
			"heal", "shield":
				has_heal = true
			"atb_decrease", "atb_steal", "atb_increase":
				has_atb = true

	# Classify based on what we found
	if not skill.targets_enemies:
		if has_heal:
			return SkillCategory.HEAL_AOE if is_aoe else SkillCategory.HEAL_SINGLE
		if has_buff:
			if targets_str == "self":
				return SkillCategory.BUFF_SELF
			return SkillCategory.BUFF_TEAM if is_aoe else SkillCategory.BUFF_ALLY
		return SkillCategory.UTILITY

	# Enemy targeting skills
	if has_cc:
		return SkillCategory.CC_AOE if is_aoe else SkillCategory.CC_SINGLE
	if has_atb:
		return SkillCategory.ATB_MANIPULATION
	if has_debuff:
		return SkillCategory.DEBUFF_AOE if is_aoe else SkillCategory.DEBUFF_SINGLE
	return SkillCategory.DAMAGE_AOE if is_aoe else SkillCategory.DAMAGE_SINGLE

## Get ability data from JSON (using Skill's cache)
static func _get_ability_data(skill_id: String) -> Dictionary:
	var abilities_data: Dictionary = Skill._load_abilities_data()
	return abilities_data.get("abilities", {}).get(skill_id, {})

## Select the best target for a damage skill
static func _select_best_target(attacker: BattleUnit, enemies: Array[BattleUnit], skill: Skill, battle_state: BattleState) -> BattleUnit:
	if enemies.is_empty():
		return null

	var best_target: BattleUnit = null
	var best_score: float = -999999.0

	for enemy: BattleUnit in enemies:
		if not enemy.is_alive:
			continue
		# Skip untargetable enemies
		if enemy.is_untargetable():
			continue

		var score: float = _calculate_target_score(attacker, enemy, skill, battle_state)
		if score > best_score:
			best_score = score
			best_target = enemy

	# If all valid enemies are untargetable, return first living one as fallback
	if best_target == null:
		for enemy: BattleUnit in enemies:
			if enemy.is_alive:
				return enemy
	return best_target

## Calculate a priority score for targeting a specific enemy
static func _calculate_target_score(attacker: BattleUnit, target: BattleUnit, skill: Skill, _battle_state: BattleState) -> float:
	var score: float = 0.0

	# Kill potential - massive bonus if we can kill this turn
	var estimated_damage: int = _estimate_damage(attacker, target, skill)
	if estimated_damage >= target.current_hp:
		score += WEIGHT_KILL_POTENTIAL

	# Low HP percentage bonus (inverse - lower HP = higher score)
	var hp_percent: float = float(target.current_hp) / float(target.max_hp)
	score += WEIGHT_LOW_HP * (1.0 - hp_percent)

	# Threat assessment - high attack enemies are threats
	var threat_level: float = float(target.attack) / 300.0  # Normalize around 300 attack
	score += WEIGHT_THREAT * minf(threat_level, 2.0)

	# Healer/support detection (check for healing skills)
	if _is_healer(target):
		score += WEIGHT_HEALER

	# Debuffed targets take priority (easier to kill)
	var debuff_count: int = _count_debuffs(target)
	score += WEIGHT_DEBUFFED * minf(debuff_count, 3)

	# Element advantage
	if attacker.source_god and target.source_god:
		var element_mult: float = _get_element_advantage(attacker, target)
		if element_mult > 1.0:
			score += WEIGHT_ELEMENT_ADVANTAGE * (element_mult - 1.0) * 10.0

	# ATB consideration - target about to move is more dangerous
	var atb_progress: float = target.get_turn_progress()
	score += WEIGHT_ATB_HIGH * atb_progress

	return score

## Estimate damage output against a target
static func _estimate_damage(attacker: BattleUnit, target: BattleUnit, skill: Skill) -> int:
	var base_attack: int = attacker.get_modified_attack()
	var multiplier: float = skill.get_damage_multiplier() if skill else 1.0
	var defense: int = target.defense

	# Simplified damage formula estimation
	var estimated: float = base_attack * multiplier * (1000.0 / (1140.0 + 3.5 * defense))
	return int(estimated)

## Check if a unit has healing abilities
static func _is_healer(unit: BattleUnit) -> bool:
	for skill: Skill in unit.skills:
		if not skill.targets_enemies:
			var ability_data: Dictionary = _get_ability_data(skill.skill_id)
			var effects: Array = ability_data.get("effects", [])
			for effect: Variant in effects:
				if effect is Dictionary:
					var effect_type: String = effect.get("type", "")
					if effect_type in ["heal", "shield", "regeneration"]:
						return true
	return false

## Count debuffs on a target
static func _count_debuffs(target: BattleUnit) -> int:
	var count: int = 0
	for effect: StatusEffect in target.status_effects:
		if effect.effect_type == StatusEffect.EffectType.DEBUFF or effect.effect_type == StatusEffect.EffectType.DOT:
			count += 1
	return count

## Get element advantage multiplier
static func _get_element_advantage(attacker: BattleUnit, target: BattleUnit) -> float:
	if not attacker.source_god or not target.source_god:
		return 1.0

	var attacker_element: God.ElementType = attacker.source_god.element
	var target_element: God.ElementType = target.source_god.element

	# Element wheel: Fire > Earth > Water > Fire, Light <> Dark
	match attacker_element:
		God.ElementType.FIRE:
			if target_element == God.ElementType.EARTH:
				return 1.3
		God.ElementType.WATER:
			if target_element == God.ElementType.FIRE:
				return 1.3
		God.ElementType.EARTH:
			if target_element == God.ElementType.WATER:
				return 1.3
		God.ElementType.LIGHT:
			if target_element == God.ElementType.DARK:
				return 1.3
		God.ElementType.DARK:
			if target_element == God.ElementType.LIGHT:
				return 1.3

	return 1.0

## Select best target for healing
static func _select_heal_target(healer: BattleUnit, allies: Array[BattleUnit], _skill: Skill) -> BattleUnit:
	if allies.is_empty():
		return null

	var best_target: BattleUnit = null
	var lowest_hp_percent: float = 1.0

	for ally: BattleUnit in allies:
		if not ally.is_alive:
			continue

		var hp_percent: float = float(ally.current_hp) / float(ally.max_hp)

		# Don't heal if everyone is above 80% HP
		if hp_percent < lowest_hp_percent and hp_percent < 0.8:
			lowest_hp_percent = hp_percent
			best_target = ally

	# If no one needs healing, return null (don't waste the skill)
	if best_target == null and lowest_hp_percent > 0.7:
		return null

	# If healer itself is very low, prioritize self
	var healer_hp_percent: float = float(healer.current_hp) / float(healer.max_hp)
	if healer_hp_percent < 0.3:
		return healer

	return best_target

## Select best target for crowd control
static func _select_cc_target(caster: BattleUnit, enemies: Array[BattleUnit], skill: Skill, battle_state: BattleState) -> BattleUnit:
	if enemies.is_empty():
		return null

	var best_target: BattleUnit = null
	var best_score: float = -999999.0

	for enemy: BattleUnit in enemies:
		if not enemy.is_alive:
			continue

		# Skip targets already CC'd
		if _is_cc_immune(enemy):
			continue

		var score: float = 0.0

		# Prioritize high threat targets for CC
		score += float(enemy.attack) / 200.0 * 50.0

		# Prioritize targets about to move
		score += enemy.get_turn_progress() * 100.0

		# Prioritize targets that haven't been CC'd
		if not _has_cc_effect(enemy):
			score += 30.0

		# Add base target score
		score += _calculate_target_score(caster, enemy, skill, battle_state) * 0.3

		if score > best_score:
			best_score = score
			best_target = enemy

	return best_target if best_target else enemies[0]

## Check if target is immune to CC
static func _is_cc_immune(target: BattleUnit) -> bool:
	# Check for debuff immunity from Will set or status effects
	if target.immunity_turns > 0:
		return true
	for effect: StatusEffect in target.status_effects:
		if effect.immune_to_debuffs:
			return true
	return false

## Check if target already has a CC effect
static func _has_cc_effect(target: BattleUnit) -> bool:
	for effect: StatusEffect in target.status_effects:
		if effect.prevents_action:
			return true
	return false

## Select best target for ATB manipulation
static func _select_atb_target(enemies: Array[BattleUnit], _skill: Skill) -> BattleUnit:
	if enemies.is_empty():
		return null

	# Target the enemy with highest ATB (about to move)
	var best_target: BattleUnit = null
	var highest_atb: float = -1.0

	for enemy: BattleUnit in enemies:
		if not enemy.is_alive:
			continue
		if enemy.current_turn_bar > highest_atb:
			highest_atb = enemy.current_turn_bar
			best_target = enemy

	return best_target

## Score a single target damage action
static func _score_damage_action(attacker: BattleUnit, skill: Skill, target: BattleUnit, enemy_count: int, battle_state: BattleState) -> float:
	var score: float = 50.0  # Base score for damage

	# Add damage potential
	var estimated_damage: int = _estimate_damage(attacker, target, skill)
	var damage_ratio: float = float(estimated_damage) / float(target.current_hp)
	score += damage_ratio * 40.0

	# Big bonus for kill potential
	if estimated_damage >= target.current_hp:
		score += 80.0

	# Scale up single target if fewer enemies (focus fire)
	if enemy_count <= 2:
		score += 30.0

	# Add skill multiplier consideration
	score += skill.damage_multiplier * 20.0

	# Consider target priority
	score += _calculate_target_score(attacker, target, skill, battle_state) * 0.5

	return score

## Score an AoE damage action
static func _score_aoe_damage_action(attacker: BattleUnit, skill: Skill, enemies: Array[BattleUnit], _battle_state: BattleState) -> float:
	if enemies.is_empty():
		return 0.0

	var score: float = 30.0  # Base score for AoE

	# Scale heavily with enemy count
	score += enemies.size() * 25.0

	# Check for potential kills
	var kill_count: int = 0
	for enemy: BattleUnit in enemies:
		var estimated_damage: int = _estimate_damage(attacker, enemy, skill)
		if estimated_damage >= enemy.current_hp:
			kill_count += 1

	score += kill_count * 50.0

	# Add skill multiplier
	score += skill.damage_multiplier * 15.0

	# Penalize AoE if only 1 enemy
	if enemies.size() == 1:
		score *= 0.5

	return score

## Score a healing action
static func _score_heal_action(skill: Skill, target: BattleUnit, allies: Array[BattleUnit]) -> float:
	if not target:
		return -100.0

	var hp_percent: float = float(target.current_hp) / float(target.max_hp)
	var score: float = 0.0

	# Score based on how much healing is needed
	score += (1.0 - hp_percent) * 100.0

	# Bonus for saving nearly-dead allies
	if hp_percent < 0.2:
		score += 80.0
	elif hp_percent < 0.4:
		score += 40.0

	# Penalty if target doesn't really need healing
	if hp_percent > 0.7:
		score -= 50.0

	# Consider skill cooldown - don't waste big heals on small damage
	if skill.cooldown >= 3 and hp_percent > 0.5:
		score -= 30.0

	# Bonus if multiple allies are hurt
	var hurt_allies: int = 0
	for ally: BattleUnit in allies:
		if float(ally.current_hp) / float(ally.max_hp) < 0.7:
			hurt_allies += 1
	score += hurt_allies * 10.0

	return score

## Score a team heal action (AOE heal like Dagda's Cauldron)
static func _score_team_heal_action(_skill: Skill, allies: Array[BattleUnit]) -> float:
	if allies.is_empty():
		return -100.0

	var score: float = 0.0
	var total_missing_hp_percent: float = 0.0
	var critically_low_count: int = 0  # Below 25%
	var danger_count: int = 0          # Below 40%
	var hurt_count: int = 0            # Below 60%

	for ally: BattleUnit in allies:
		if not ally.is_alive:
			continue
		var hp_percent: float = float(ally.current_hp) / float(ally.max_hp)
		total_missing_hp_percent += (1.0 - hp_percent)

		if hp_percent < 0.25:
			critically_low_count += 1
		elif hp_percent < 0.40:
			danger_count += 1
		elif hp_percent < 0.60:
			hurt_count += 1

	# PRIORITY 1: Someone is about to die - MUST HEAL NOW
	if critically_low_count > 0:
		score += 300.0  # Massive priority - saving lives trumps everything
		score += critically_low_count * 100.0  # More dying = more urgent

	# PRIORITY 2: Someone is in danger zone
	if danger_count > 0:
		score += 150.0  # High priority
		score += danger_count * 50.0

	# PRIORITY 3: General team damage
	score += hurt_count * 25.0
	score += total_missing_hp_percent * 40.0

	# Bonus for healing multiple hurt allies (efficient use)
	var total_hurt: int = critically_low_count + danger_count + hurt_count
	if total_hurt >= 2:
		score += 30.0
	if total_hurt >= 3:
		score += 20.0

	# Only penalize if team is VERY healthy and no one is hurt
	if total_hurt == 0:
		var avg_missing: float = total_missing_hp_percent / allies.size()
		if avg_missing < 0.15:
			score -= 80.0  # Team above 85% - don't waste the heal
		elif avg_missing < 0.25:
			score -= 40.0  # Team above 75%

	return score

## Score a team buff action
static func _score_team_buff_action(_skill: Skill, allies: Array[BattleUnit]) -> float:
	var score: float = 40.0  # Base score for buffs

	# Scale with team size
	score += allies.size() * 15.0

	# Check if allies already have buffs (don't stack same buffs)
	var buffed_count: int = 0
	for ally: BattleUnit in allies:
		for effect: StatusEffect in ally.status_effects:
			if effect.effect_type == StatusEffect.EffectType.BUFF:
				buffed_count += 1
				break

	# Penalty if most allies already buffed
	if buffed_count >= allies.size() * 0.7:
		score -= 30.0

	return score

## Score a self buff action
static func _score_self_buff_action(unit: BattleUnit, skill: Skill, _battle_state: BattleState) -> float:
	var score: float = 30.0  # Base score

	# Check if already has same buff type
	var already_buffed: bool = false
	for effect: StatusEffect in unit.status_effects:
		if effect.effect_type == StatusEffect.EffectType.BUFF:
			already_buffed = true
			break

	if already_buffed:
		score -= 40.0  # Don't stack buffs unnecessarily

	# Boost score early in battle
	if _battle_state.current_turn < 2:
		score += 25.0

	# Consider skill cooldown value
	if skill.cooldown >= 3:
		score += 15.0  # Bigger cooldown = more valuable skill

	return score

## Score a CC action
static func _score_cc_action(skill: Skill, target: BattleUnit, enemies: Array[BattleUnit], _battle_state: BattleState) -> float:
	if not target:
		return -100.0

	var score: float = 60.0  # Base score for CC

	# Bonus for high threat targets
	score += float(target.attack) / 250.0 * 40.0

	# Bonus for target about to move
	score += target.get_turn_progress() * 50.0

	# Penalty if target already CC'd
	if _has_cc_effect(target):
		score -= 100.0

	# Penalty if target is immune
	if _is_cc_immune(target):
		score -= 200.0

	# Scale with enemy count (CC more valuable with more enemies)
	score += enemies.size() * 10.0

	# Consider skill cooldown
	score += skill.cooldown * 8.0

	return score

## Score an AoE CC action
static func _score_aoe_cc_action(_skill: Skill, enemies: Array[BattleUnit], _battle_state: BattleState) -> float:
	if enemies.is_empty():
		return 0.0

	var score: float = 50.0  # Base score

	# Count valid CC targets
	var valid_targets: int = 0
	for enemy: BattleUnit in enemies:
		if not _is_cc_immune(enemy) and not _has_cc_effect(enemy):
			valid_targets += 1

	# Scale heavily with valid target count
	score += valid_targets * 30.0

	# Penalty if most are immune/already CC'd
	if valid_targets == 0:
		return -100.0

	return score

## Score an ATB manipulation action
static func _score_atb_action(_skill: Skill, target: BattleUnit, enemies: Array[BattleUnit]) -> float:
	if not target:
		return -100.0

	var score: float = 40.0  # Base score

	# Score based on how close target is to moving
	score += target.get_turn_progress() * 80.0

	# Bonus for targeting high threat units
	score += float(target.attack) / 300.0 * 30.0

	# Scale with enemy count
	score += enemies.size() * 5.0

	return score

## Choose the best action for auto-battle (wrapper for player units)
static func choose_auto_action(unit: BattleUnit, battle_state: BattleState) -> BattleAction:
	# Use the same smart AI for auto-battle
	return choose_action(unit, battle_state)
