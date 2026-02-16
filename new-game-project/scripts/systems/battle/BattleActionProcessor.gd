# scripts/systems/battle/BattleActionProcessor.gd
# Processes battle actions and applies their effects
extends Node
class_name BattleActionProcessor

var battle_state: BattleState

## Cached abilities data — loaded once from abilities.json on first use
static var _cached_abilities: Dictionary = {}
static var _abilities_loaded: bool = false

signal action_executed(action: BattleAction, result: ActionResult)

## Setup battle context
func setup_battle_context(state: BattleState) -> void:
	battle_state = state

## Execute a battle action
func execute_action(action: BattleAction, state: BattleState) -> bool:
	if not action or not action.caster.is_alive:
		return false
	
	var result := ActionResult.new()
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
		for damage_result: DamageResult in result.damage_results:
			if action.caster.is_player_unit:
				state.record_damage_dealt(damage_result.total)
			else:
				state.record_damage_received(damage_result.total)
	
	# Emit signal
	action_executed.emit(action, result)
	
	return result.success

func _execute_attack(action: BattleAction, result: ActionResult) -> void:
	var attacker: BattleUnit = action.caster
	var target: BattleUnit = action.targets[0]

	if not target.is_alive:
		result.success = false
		result.message = attacker.display_name + " attacks " + target.display_name + ", but they are already defeated!"
		return
	
	# Use existing CombatCalculator for authentic SW combat
	var damage_result: DamageResult = CombatCalculator.calculate_damage(attacker, target)
	var damage_amount: int = damage_result.total
	
	# Apply damage
	target.take_damage(damage_amount)
	
	# Check if target was defeated
	if not target.is_alive:
		battle_state.record_unit_defeat()
	
	# Create damage result for tracking
	var attack_result := DamageResult.new(damage_amount, damage_result.is_critical, damage_result.is_glancing)
	result.add_damage_result(attack_result)
	result.message = attacker.display_name + " attacks " + target.display_name + " for " + str(damage_amount) + " damage!"

func _execute_skill(action: BattleAction, result: ActionResult) -> void:
	var caster: BattleUnit = action.caster
	var skill: Skill = action.skill
	var targets: Array = action.targets

	# Check if skill is on cooldown
	var skill_index: int = caster.skills.find(skill)
	if skill_index >= 0 and not caster.can_use_skill(skill_index):
		result.success = false
		result.message = skill.name + " is on cooldown!"
		return

	# Use the skill (set cooldown)
	if skill_index >= 0:
		caster.use_skill(skill_index)

	# Apply skill effects to each target using existing combat system
	for target: BattleUnit in targets:
		if not target.is_alive:
			continue

		if skill.targets_enemies:
			# Use existing skill damage calculation
			var skill_result: DamageResult = CombatCalculator.calculate_damage(caster, target, skill)
			target.take_damage(skill_result.total)

			var skill_damage := DamageResult.new(skill_result.total, skill_result.is_critical, skill_result.is_glancing)
			result.add_damage_result(skill_damage)

			if not target.is_alive:
				battle_state.record_unit_defeat()
		else:
			# Healing or buff skill
			var heal_amount: int = int(caster.attack * skill.damage_multiplier)
			target.heal(heal_amount)
			result.message += target.display_name + " healed for " + str(heal_amount) + "! "

		# Apply status effects from skill
		_apply_skill_status_effects(skill, caster, target, result)

	result.message = caster.display_name + " uses " + skill.name + "!"

func _execute_defend(action: BattleAction, result: ActionResult) -> void:
	var defender: BattleUnit = action.caster

	# Apply defense buff (simplified)
	var defense_buff := StatusEffect.new()
	defense_buff.id = "defend_buff"
	defense_buff.name = "Defending"
	defense_buff.duration = 1
	defense_buff.stat_modifier = {"defense": 0.5}  # +50% defense

	defender.add_status_effect(defense_buff)
	result.message = defender.display_name + " takes a defensive stance!"

func _apply_skill_status_effects(skill: Skill, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	# Load ability data from JSON to get effects
	var ability_data: Dictionary = _get_ability_data(skill.skill_id)
	if ability_data == null or ability_data.is_empty():
		return

	var effects: Array = ability_data.get("effects", [])
	if effects.is_empty():
		return

	# Process each effect in the skill
	for effect_data: Variant in effects:
		if not effect_data is Dictionary:
			continue

		var effect_dict: Dictionary = effect_data as Dictionary
		var effect_type: String = effect_dict.get("type", "")

		match effect_type:
			"debuff":
				_apply_debuff_effect(effect_dict, caster, target, result)
			"buff":
				_apply_buff_effect(effect_dict, caster, target, result)
			"atb_decrease":
				_apply_atb_decrease(effect_dict, caster, target, result)
			"atb_steal":
				_apply_atb_steal(effect_dict, caster, target, result)
			"life_drain":
				_apply_life_drain(effect_dict, caster, target, result)

func _get_ability_data(skill_id: String) -> Dictionary:
	"""Look up ability data from cached abilities dictionary"""
	if not _abilities_loaded:
		_load_abilities_cache()
	return _cached_abilities.get(skill_id, {})

static func _load_abilities_cache() -> void:
	"""Load abilities.json once and cache the result"""
	_abilities_loaded = true
	var file := FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if not file:
		push_warning("BattleActionProcessor: Could not open abilities.json")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_warning("BattleActionProcessor: Failed to parse abilities.json")
		return

	var data: Dictionary = json.get_data()
	_cached_abilities = data.get("abilities", {})

func _apply_debuff_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var debuff_type: String = effect_data.get("debuff", "")
	var chance: int = effect_data.get("chance", 100)
	var duration: int = effect_data.get("duration", 1)

	# Roll for chance
	var roll: float = randf() * 100
	if roll > chance:
		return

	# Create the appropriate status effect using factory methods
	var status_effect: StatusEffect = null
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
		"defense_down", "defense_reduction", "decrease_defense":
			status_effect = StatusEffect.create_defense_reduction(caster, duration)
		"attack_down", "attack_reduction", "decrease_attack":
			status_effect = StatusEffect.create_attack_reduction(caster, duration)
		"marked_for_death", "brand":
			status_effect = StatusEffect.create_marked_for_death(caster, duration)
		"continuous_damage":
			status_effect = StatusEffect.create_continuous_damage(caster, duration)
		"glancing":
			status_effect = StatusEffect.create_blind(caster, duration)  # Glancing = reduced accuracy
		"block_beneficial_effects":
			status_effect = StatusEffect.create_debuff_immunity(caster, duration)  # Block buffs
		"oblivion":
			status_effect = StatusEffect.create_silence(caster, duration)  # Oblivion = can't use passives
		_:
			push_warning("BattleActionProcessor: Unknown debuff type: " + debuff_type)
			return

	# Apply the status effect to target
	if status_effect:
		# Set tracking info for battle log
		status_effect.target_name = target.display_name
		status_effect.caster_name = caster.display_name if caster else ""
		target.add_status_effect(status_effect)
		result.message += " " + target.display_name + " is " + status_effect.name + "!"
		# Track applied status effect in result for logging
		result.add_status_effect(status_effect)

func _apply_buff_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var buff_type: String = effect_data.get("buff", "")
	var chance: int = effect_data.get("chance", 100)
	var duration: int = effect_data.get("duration", 3)

	# Roll for chance
	if randf() * 100 > chance:
		return

	# Create the appropriate status effect using factory methods
	var status_effect: StatusEffect = null
	match buff_type:
		"attack_boost", "attack_up", "increase_attack":
			status_effect = StatusEffect.create_attack_boost(caster, duration)
		"defense_boost", "defense_up", "increase_defense":
			status_effect = StatusEffect.create_defense_boost(caster, duration)
		"speed_boost", "speed_up", "increase_speed":
			status_effect = StatusEffect.create_speed_boost(caster, duration)
		"shield":
			status_effect = StatusEffect.create_shield(caster, duration)
		"regeneration", "heal_over_time", "continuous_recovery":
			status_effect = StatusEffect.create_regeneration(caster, duration)
		"debuff_immunity", "immunity":
			status_effect = StatusEffect.create_debuff_immunity(caster, duration)
		"damage_immunity", "endure":
			status_effect = StatusEffect.create_damage_immunity(caster, duration)
		"crit_boost", "critical_boost", "increase_critical_rate":
			status_effect = StatusEffect.create_crit_boost(caster, duration)
		"increase_critical_damage":
			status_effect = StatusEffect.create_critical_damage_boost(caster, duration)
		"accuracy_boost", "increase_accuracy":
			status_effect = StatusEffect.create_accuracy_boost(caster, duration)
		"evasion_boost":
			status_effect = StatusEffect.create_evasion_boost(caster, duration)
		"counter_attack", "counterattack":
			status_effect = StatusEffect.create_counter_attack(caster, duration)
		"reflect_damage":
			status_effect = StatusEffect.create_reflect_damage(caster, duration)
		"untargetable":
			status_effect = StatusEffect.create_untargetable(caster, duration)
		_:
			push_warning("BattleActionProcessor: Unknown buff type: " + buff_type)
			return

	# Apply the status effect to target
	if status_effect:
		# Set tracking info for battle log
		status_effect.target_name = target.display_name
		status_effect.caster_name = caster.display_name if caster else ""
		target.add_status_effect(status_effect)
		result.message += " " + target.display_name + " gains " + status_effect.name + "!"
		# Track applied status effect in result for logging
		result.add_status_effect(status_effect)

func _apply_atb_decrease(effect_data: Dictionary, _caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)
	var amount: int = effect_data.get("amount", 30)  # Percentage to decrease

	if randf() * 100 > chance:
		return

	var decrease_amount: float = target.current_turn_bar * (amount / 100.0)
	target.current_turn_bar = max(0, target.current_turn_bar - decrease_amount)
	result.message += " %s's turn bar decreased by %d%%!" % [target.display_name, amount]

func _apply_atb_steal(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)
	var amount: int = effect_data.get("amount", 20)  # Percentage to steal

	if randf() * 100 > chance:
		return

	var steal_amount: float = target.current_turn_bar * (amount / 100.0)
	target.current_turn_bar = max(0, target.current_turn_bar - steal_amount)
	var threshold: float = TurnManager.get_turn_bar_threshold()
	caster.current_turn_bar = minf(threshold, caster.current_turn_bar + steal_amount)
	result.message += " %s steals %d%% turn bar from %s!" % [caster.display_name, amount, target.display_name]

func _apply_life_drain(effect_data: Dictionary, caster: BattleUnit, _target: BattleUnit, result: ActionResult) -> void:
	var drain_percent: int = effect_data.get("amount", 30)  # Percentage of damage to heal

	# Calculate heal from total damage dealt this action
	var total_damage: int = 0
	for dmg_result: DamageResult in result.damage_results:
		total_damage += dmg_result.total

	var heal_amount: int = int(total_damage * (drain_percent / 100.0))
	if heal_amount > 0:
		caster.heal(heal_amount)
		result.message += " %s drains %d HP!" % [caster.display_name, heal_amount]
