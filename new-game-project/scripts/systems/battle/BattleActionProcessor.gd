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

		# Apply status effects from skill
		_apply_skill_status_effects(skill, caster, target, result)

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

func _apply_skill_status_effects(skill, caster, target, result: ActionResult):
	"""Apply status effects from skill to target"""
	# Load ability data from JSON to get effects
	var ability_data = _get_ability_data(skill.skill_id)
	if ability_data == null or ability_data.is_empty():
		print("BattleActionProcessor: No ability data found for skill: ", skill.skill_id)
		return

	var effects = ability_data.get("effects", [])
	if effects.is_empty():
		print("BattleActionProcessor: Skill %s has no effects" % skill.skill_id)
		return

	print("BattleActionProcessor: Processing %d effects for skill %s" % [effects.size(), skill.skill_id])

	# Process each effect in the skill
	for effect_data in effects:
		if not effect_data is Dictionary:
			continue

		var effect_type = effect_data.get("type", "")

		# Handle debuff effects
		if effect_type == "debuff":
			print("BattleActionProcessor: Applying debuff: ", effect_data.get("debuff", "unknown"))
			_apply_debuff_effect(effect_data, caster, target, result)
		# Handle buff effects
		elif effect_type == "buff":
			print("BattleActionProcessor: Applying buff: ", effect_data.get("buff", "unknown"))
			_apply_buff_effect(effect_data, caster, target, result)

func _get_ability_data(skill_id: String) -> Dictionary:
	"""Load ability data from JSON file"""
	var file = FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if not file:
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}

	var data = json.get_data()
	var abilities = data.get("abilities", {})
	return abilities.get(skill_id, {})

func _apply_debuff_effect(effect_data: Dictionary, caster, target, result: ActionResult):
	"""Apply a debuff status effect to target"""
	var debuff_type = effect_data.get("debuff", "")
	var chance = effect_data.get("chance", 100)
	var duration = effect_data.get("duration", 1)

	print("BattleActionProcessor: Attempting to apply %s (chance: %d%%, duration: %d)" % [debuff_type, chance, duration])

	# Roll for chance
	var roll = randf() * 100
	if roll > chance:
		print("BattleActionProcessor: Failed chance roll (%d > %d)" % [roll, chance])
		return

	print("BattleActionProcessor: Passed chance roll (%d <= %d)" % [roll, chance])

	# Create the appropriate status effect using factory methods
	var status_effect = null
	match debuff_type:
		"stun":
			status_effect = StatusEffect.create_stun(caster, duration)
		"slow":
			status_effect = StatusEffect.create_slow(caster, duration)
		"burn":
			status_effect = StatusEffect.create_burn(caster, duration)
		"poison":
			status_effect = StatusEffect.create_poison(caster, duration)
		"bleed":
			status_effect = StatusEffect.create_bleed(caster, duration)
		"freeze":
			status_effect = StatusEffect.create_freeze(caster, duration)
		"sleep":
			status_effect = StatusEffect.create_sleep(caster, duration)
		"silence":
			status_effect = StatusEffect.create_silence(caster, duration)
		"blind":
			status_effect = StatusEffect.create_blind(caster, duration)
		"fear":
			status_effect = StatusEffect.create_fear(caster, duration)
		"provoke":
			status_effect = StatusEffect.create_provoke(caster, duration)
		"immobilize":
			status_effect = StatusEffect.create_immobilize(caster, duration)
		"curse":
			status_effect = StatusEffect.create_curse(caster, duration)
		"heal_block":
			status_effect = StatusEffect.create_heal_block(caster, duration)
		"defense_down", "defense_reduction":
			status_effect = StatusEffect.create_defense_reduction(caster, duration)
		"attack_down", "attack_reduction":
			status_effect = StatusEffect.create_attack_reduction(caster, duration)
		"marked_for_death":
			status_effect = StatusEffect.create_marked_for_death(caster, duration)
		_:
			push_warning("BattleActionProcessor: Unknown debuff type: " + debuff_type)
			return

	# Apply the status effect to target
	if status_effect and target.has_method("add_status_effect"):
		print("BattleActionProcessor: Applying status effect to %s: %s" % [target.display_name, status_effect.name])
		target.add_status_effect(status_effect)
		result.message += " " + target.display_name + " is " + status_effect.name + "!"
		print("BattleActionProcessor: Status effect applied successfully")
	else:
		print("BattleActionProcessor: Failed to apply status effect (status_effect=%s, has_method=%s)" % [status_effect != null, target.has_method("add_status_effect")])

func _apply_buff_effect(effect_data: Dictionary, caster, target, result: ActionResult):
	"""Apply a buff status effect to target"""
	var buff_type = effect_data.get("buff", "")
	var chance = effect_data.get("chance", 100)
	var duration = effect_data.get("duration", 3)

	# Roll for chance
	if randf() * 100 > chance:
		return

	# Create the appropriate status effect using factory methods
	var status_effect = null
	match buff_type:
		"attack_boost", "attack_up":
			status_effect = StatusEffect.create_attack_boost(caster, duration)
		"defense_boost", "defense_up":
			status_effect = StatusEffect.create_defense_boost(caster, duration)
		"speed_boost", "speed_up":
			status_effect = StatusEffect.create_speed_boost(caster, duration)
		"shield":
			status_effect = StatusEffect.create_shield(caster, duration)
		"regeneration", "heal_over_time":
			status_effect = StatusEffect.create_regeneration(caster, duration)
		"debuff_immunity":
			status_effect = StatusEffect.create_debuff_immunity(caster, duration)
		"damage_immunity":
			status_effect = StatusEffect.create_damage_immunity(caster, duration)
		"crit_boost", "critical_boost":
			status_effect = StatusEffect.create_crit_boost(caster, duration)
		"accuracy_boost":
			status_effect = StatusEffect.create_accuracy_boost(caster, duration)
		"evasion_boost":
			status_effect = StatusEffect.create_evasion_boost(caster, duration)
		"counter_attack":
			status_effect = StatusEffect.create_counter_attack(caster, duration)
		"reflect_damage":
			status_effect = StatusEffect.create_reflect_damage(caster, duration)
		"untargetable":
			status_effect = StatusEffect.create_untargetable(caster, duration)
		_:
			push_warning("BattleActionProcessor: Unknown buff type: " + buff_type)
			return

	# Apply the status effect to target
	if status_effect and target.has_method("add_status_effect"):
		target.add_status_effect(status_effect)
		result.message += " " + target.display_name + " gains " + status_effect.name + "!"
