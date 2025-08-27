# scripts/systems/battle/BattleActionProcessor.gd
# Processes battle actions and applies their effects
extends Node
class_name BattleActionProcessor

var battle_state: BattleState

signal action_executed(action: BattleAction, result: ActionResult)

## Setup battle context
func setup_battle_context(state: BattleState):
	battle_state = state

## Execute a battle action
func execute_action(action: BattleAction, state: BattleState) -> bool:
	if not action or not action.caster.is_alive:
		return false
	
	var result = ActionResult.new()
	result.success = true
	
	match action.action_type:
		BattleAction.ActionType.ATTACK:
			_execute_attack(action, result)
		BattleAction.ActionType.SKILL:
			_execute_skill(action, result)
		BattleAction.ActionType.DEFEND:
			_execute_defend(action, result)
		_:
			result.success = false
			result.message = "Unknown action type"
	
	# Record statistics
	if result.success:
		state.record_skill_use()
		
		# Record damage
		for damage_result in result.damage_results:
			if action.caster.is_player_unit:
				state.record_damage_dealt(damage_result.total)
			else:
				state.record_damage_received(damage_result.total)
	
	# Emit signal
	action_executed.emit(action, result)
	
	return result.success

func _execute_attack(action: BattleAction, result: ActionResult):
	"""Execute a basic attack"""
	var attacker = action.caster
	var target = action.targets[0]
	
	if not target.is_alive:
		result.success = false
		result.message = attacker.display_name + " attacks " + target.display_name + ", but they are already defeated!"
		return
	
	# Use existing CombatCalculator for authentic SW combat
	var damage_result = CombatCalculator.calculate_damage(attacker, target)
	var damage_amount = damage_result.total
	
	# Apply damage
	target.take_damage(damage_amount)
	
	# Check if target was defeated
	if not target.is_alive:
		battle_state.record_unit_defeat()
	
	# Create damage result for tracking
	var attack_result = DamageResult.new(damage_amount, damage_result.is_critical, damage_result.is_glancing)
	result.add_damage_result(attack_result)
	result.message = attacker.display_name + " attacks " + target.display_name + " for " + str(damage_amount) + " damage!"

func _execute_skill(action: BattleAction, result: ActionResult):
	"""Execute a skill"""
	var caster = action.caster
	var skill = action.skill
	var targets = action.targets
	
	# Check if skill is on cooldown
	var skill_index = caster.skills.find(skill)
	if skill_index >= 0 and not caster.can_use_skill(skill_index):
		result.success = false
		result.message = skill.name + " is on cooldown!"
		return
	
	# Use the skill (set cooldown)
	if skill_index >= 0:
		caster.use_skill(skill_index)
	
	# Apply skill effects to each target using existing combat system
	for target in targets:
		if not target.is_alive:
			continue
		
		if skill.targets_enemies:
			# Use existing skill damage calculation
			var skill_result = CombatCalculator.calculate_damage(caster, target, skill)
			target.take_damage(skill_result.total)
			
			var skill_damage = DamageResult.new(skill_result.total, skill_result.is_critical, skill_result.is_glancing)
			result.add_damage_result(skill_damage)
			
			if not target.is_alive:
				battle_state.record_unit_defeat()
		else:
			# Healing or buff skill
			var heal_amount = int(caster.attack * skill.damage_multiplier)
			target.heal(heal_amount)
			result.message += target.display_name + " healed for " + str(heal_amount) + "! "
	
	result.message = caster.display_name + " uses " + skill.name + "!"

func _execute_defend(action: BattleAction, result: ActionResult):
	"""Execute defend action"""
	var defender = action.caster
	
	# Apply defense buff (simplified)
	var defense_buff = StatusEffect.new()
	defense_buff.effect_id = "defend_buff"
	defense_buff.name = "Defending"
	defense_buff.duration = 1
	defense_buff.stat_modifiers = {"defense": 0.5}  # +50% defense
	
	defender.add_status_effect(defense_buff)
	result.message = defender.display_name + " takes a defensive stance!"
