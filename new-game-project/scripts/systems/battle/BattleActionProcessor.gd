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
	var damage_result: DamageResult = CombatCalculator.calculate_damage(attacker, target, null, battle_state)
	var damage_amount: int = damage_result.total

	# Apply damage using new system (handles shields, death defiance, thorns, reflect, sleep break)
	var damage_info: Dictionary = target.apply_damage(damage_amount)
	target.on_damage_received()  # Track vengeance stacks

	# Check if damage was blocked by immunity
	if damage_info.get("damage_immune", false):
		result.message = attacker.display_name + " attacks " + target.display_name + ", but they are immune to damage!"
		return

	# Handle sleep broken
	if damage_info.get("sleep_broken", false):
		result.message += " %s wakes up!" % target.display_name

	# Handle thorns damage (Aegis set)
	if damage_info.thorns_damage > 0 and attacker.is_alive:
		attacker.take_damage(damage_info.thorns_damage)
		result.message += " Thorns deals %d damage back!" % damage_info.thorns_damage

	# Handle reflect damage (from status effect)
	if damage_info.get("reflect_damage", 0) > 0 and attacker.is_alive:
		attacker.take_damage(damage_info.reflect_damage)
		result.message += " Reflected %d damage!" % damage_info.reflect_damage

	# Handle Styx life steal
	_apply_set_life_steal(attacker, damage_amount, target.is_alive, result)

	# Handle Tempest chain lightning
	_apply_chain_lightning(attacker, target, damage_result, result)

	# Check if target was defeated
	if not target.is_alive:
		battle_state.record_unit_defeat()
		if target.is_player_unit:
			battle_state.record_player_unit_death()

	# Apply Despair petrify/stun effect (Gaze of Medusa)
	if target.is_alive and attacker.should_petrify():
		if not target.try_block_debuff():
			var stun_effect: StatusEffect = StatusEffect.create_stun(attacker, 1)
			stun_effect.target_name = target.display_name
			stun_effect.caster_name = attacker.display_name
			target.add_status_effect(stun_effect)
			result.message += " %s is petrified!" % target.display_name

	# Handle counter-attack (Fury of the Erinyes / Revenge set OR status effect)
	if target.is_alive and attacker.is_alive:
		if target.should_counter_attack() or target.has_counter_attack_buff():
			_execute_counter_attack(target, attacker, result)

	# Create damage result for tracking
	var attack_result := DamageResult.new(damage_amount, damage_result.is_critical, damage_result.is_glancing)
	result.add_damage_result(attack_result)

	var msg: String = attacker.display_name + " attacks " + target.display_name + " for " + str(damage_amount) + " damage!"
	if damage_info.shield_absorbed > 0:
		msg += " (Shield absorbed %d)" % damage_info.shield_absorbed
	if damage_info.death_defied:
		msg += " %s defies death!" % target.display_name
	result.message = msg

func _execute_skill(action: BattleAction, result: ActionResult) -> void:
	var caster: BattleUnit = action.caster
	var skill: Skill = action.skill
	var targets: Array = action.targets

	# Check if caster is silenced (can only use basic attack, index 0)
	var skill_index: int = caster.skills.find(skill)
	if caster.is_silenced() and skill_index > 0:
		result.success = false
		result.message = caster.display_name + " is silenced and cannot use abilities!"
		return

	# Check if skill is on cooldown
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
			# Multi-hit support: loop for each hit
			var hit_count: int = skill.multi_hit if skill.multi_hit > 0 else 1
			var total_skill_damage: int = 0

			for hit_num: int in range(hit_count):
				if not target.is_alive:
					break  # Stop hitting dead targets

				# Use existing skill damage calculation
				var skill_result: DamageResult = CombatCalculator.calculate_damage(caster, target, skill, battle_state)

				# Apply damage using new system (handles shields, death defiance, thorns, reflect, immunity)
				var damage_info: Dictionary = target.apply_damage(skill_result.total)
				target.on_damage_received()  # Track vengeance stacks
				total_skill_damage += skill_result.total

				# Check if damage was blocked by immunity
				if damage_info.get("damage_immune", false):
					result.message += " %s is immune to damage!" % target.display_name
					break

				# Handle sleep broken
				if damage_info.get("sleep_broken", false):
					result.message += " %s wakes up!" % target.display_name

				# Handle thorns damage (Aegis set)
				if damage_info.thorns_damage > 0 and caster.is_alive:
					caster.take_damage(damage_info.thorns_damage)
					result.message += " Thorns deals %d back!" % damage_info.thorns_damage

				# Handle reflect damage (from status effect)
				if damage_info.get("reflect_damage", 0) > 0 and caster.is_alive:
					caster.take_damage(damage_info.reflect_damage)
					result.message += " Reflected %d!" % damage_info.reflect_damage

				# Handle chain lightning (only on first target, first hit)
				if target == targets[0] and hit_num == 0:
					_apply_chain_lightning(caster, target, skill_result, result)

				var skill_damage := DamageResult.new(skill_result.total, skill_result.is_critical, skill_result.is_glancing)
				result.add_damage_result(skill_damage)

			# Check kill and apply life steal based on total damage
			if not target.is_alive:
				battle_state.record_unit_defeat()
				if target.is_player_unit:
					battle_state.record_player_unit_death()
				# Soul drinker bonus on kill
				_apply_set_life_steal(caster, total_skill_damage, false, result)
			else:
				# Normal life steal
				_apply_set_life_steal(caster, total_skill_damage, true, result)
		else:
			# Healing or buff skill
			var heal_amount: int = int(caster.attack * skill.damage_multiplier)
			target.heal(heal_amount)
			result.message += target.display_name + " healed for " + str(heal_amount) + "! "

		# Apply status effects from skill (only once per target, not per hit)
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
			"self_buff":
				_apply_buff_effect(effect_dict, caster, caster, result)
			"team_buff":
				_apply_team_buff_effect(effect_dict, caster, result)
			"team_heal":
				_apply_team_heal_effect(effect_dict, caster, result)
			"smart_heal":
				_apply_smart_heal_effect(effect_dict, caster, result)
			"atb_decrease":
				_apply_atb_decrease(effect_dict, caster, target, result)
			"atb_steal":
				_apply_atb_steal(effect_dict, caster, target, result)
			"atb_increase":
				_apply_atb_increase(effect_dict, caster, target, result)
			"life_drain":
				_apply_life_drain(effect_dict, caster, target, result)
			"heal":
				_apply_heal_effect(effect_dict, caster, target, result)
			"shield":
				_apply_shield_effect(effect_dict, caster, target, result)
			"cleanse":
				_apply_cleanse_effect(effect_dict, caster, target, result)
			"strip":
				_apply_strip_effect(effect_dict, caster, target, result)
			"strip_all":
				_apply_strip_all_effect(effect_dict, caster, target, result)
			"steal_buff":
				_apply_steal_buff_effect(effect_dict, caster, target, result)
			"additional_turn":
				_apply_additional_turn(effect_dict, caster, result)

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

	# Check for debuff immunity (Will set, Olympus first debuff)
	if target.try_block_debuff():
		result.message += " %s resists the debuff!" % target.display_name
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

## Apply Styx set life steal effect
func _apply_set_life_steal(attacker: BattleUnit, damage_dealt: int, target_alive: bool, result: ActionResult) -> void:
	if not attacker.has_set_effect("life_steal") and not attacker.has_set_effect("soul_drinker"):
		return

	# Get life steal percentage from set effect
	var life_steal_pct: float = 0.0
	if attacker.has_set_effect("soul_drinker"):
		life_steal_pct = attacker.get_set_effect_value("soul_drinker")
	elif attacker.has_set_effect("life_steal"):
		life_steal_pct = attacker.get_set_effect_value("life_steal")

	if life_steal_pct <= 0:
		return

	var heal_amount: int = int(damage_dealt * life_steal_pct)
	if heal_amount > 0:
		attacker.heal(heal_amount)
		result.message += " %s drains %d HP!" % [attacker.display_name, heal_amount]

	# Soul drinker bonus: kills restore additional 15% max HP
	if not target_alive and attacker.has_set_effect("soul_drinker"):
		var bonus_heal: int = int(attacker.max_hp * 0.15)
		attacker.heal(bonus_heal)
		result.message += " Soul Drinker restores %d HP!" % bonus_heal

## Apply Tempest chain lightning effect
func _apply_chain_lightning(attacker: BattleUnit, primary_target: BattleUnit, damage_result: DamageResult, result: ActionResult) -> void:
	if not attacker.has_set_effect("chain_lightning"):
		return

	var chain_chance: float = attacker.get_set_effect_chance("chain_lightning")
	if randf() > chain_chance:
		return

	# Find another random enemy target
	var potential_targets: Array[BattleUnit] = []
	if battle_state:
		if attacker.is_player_unit:
			for unit: BattleUnit in battle_state.get_living_enemy_units():
				if unit != primary_target:
					potential_targets.append(unit)
		else:
			for unit: BattleUnit in battle_state.get_living_player_units():
				if unit != primary_target:
					potential_targets.append(unit)

	if potential_targets.is_empty():
		return

	# Chain to random target for 50% damage
	var chain_target: BattleUnit = potential_targets[randi() % potential_targets.size()]
	var chain_damage: int = int(damage_result.total * 0.5)

	var _chain_info: Dictionary = chain_target.apply_damage(chain_damage)
	chain_target.on_damage_received()

	if not chain_target.is_alive:
		battle_state.record_unit_defeat()
		if chain_target.is_player_unit:
			battle_state.record_player_unit_death()

	result.message += " Chain Lightning hits %s for %d!" % [chain_target.display_name, chain_damage]

	# Add chain damage to results
	var chain_result := DamageResult.new(chain_damage, false, false)
	result.add_damage_result(chain_result)

## Execute a counter-attack (Fury of the Erinyes / Revenge set)
func _execute_counter_attack(counter_attacker: BattleUnit, original_attacker: BattleUnit, result: ActionResult) -> void:
	if not counter_attacker.is_alive or not original_attacker.is_alive:
		return

	# Calculate counter damage (reduced to 75% of normal attack)
	var counter_damage_result: DamageResult = CombatCalculator.calculate_damage(counter_attacker, original_attacker, null, battle_state)
	var counter_damage: int = int(counter_damage_result.total * 0.75)

	# Apply counter damage
	var _counter_info: Dictionary = original_attacker.apply_damage(counter_damage)

	if not original_attacker.is_alive:
		battle_state.record_unit_defeat()
		if original_attacker.is_player_unit:
			battle_state.record_player_unit_death()

	result.message += " %s counter-attacks for %d damage!" % [counter_attacker.display_name, counter_damage]

	# Add counter damage to results
	var counter_result := DamageResult.new(counter_damage, false, false)
	result.add_damage_result(counter_result)

## Apply ATB increase effect (boost turn bar)
func _apply_atb_increase(effect_data: Dictionary, _caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)
	var amount: int = effect_data.get("amount", 30)  # Percentage to increase

	if randf() * 100 > chance:
		return

	var threshold: float = TurnManager.get_turn_bar_threshold()
	var increase_amount: float = threshold * (amount / 100.0)
	target.current_turn_bar = minf(threshold, target.current_turn_bar + increase_amount)
	result.message += " %s's turn bar increased by %d%%!" % [target.display_name, amount]

## Apply heal effect
func _apply_heal_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var heal_percent: float = effect_data.get("value", 0.3)  # Percentage of caster ATK
	var scaling: String = effect_data.get("scaling", "attack")

	var base_value: int = caster.attack
	if scaling == "MAX_HP":
		base_value = caster.max_hp
	elif scaling == "target_max_hp":
		base_value = target.max_hp

	var heal_amount: int = int(base_value * heal_percent)
	target.heal(heal_amount)
	result.message += " %s healed for %d!" % [target.display_name, heal_amount]

## Apply shield effect (absorbs damage)
func _apply_shield_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var shield_percent: float = effect_data.get("value", 0.2)  # Percentage of caster ATK/HP
	var scaling: String = effect_data.get("scaling", "attack")
	var duration: int = effect_data.get("duration", 3)

	var base_value: int = caster.attack
	if scaling == "MAX_HP":
		base_value = caster.max_hp

	var shield_amount: int = int(base_value * shield_percent)

	# Create shield status effect
	var shield_effect: StatusEffect = StatusEffect.create_shield(caster, duration)
	shield_effect.shield_value = shield_amount
	shield_effect.target_name = target.display_name
	shield_effect.caster_name = caster.display_name
	shield_effect.description = "Absorbs %d damage" % shield_amount
	target.add_status_effect(shield_effect)

	result.message += " %s gains a %d HP shield!" % [target.display_name, shield_amount]

## Apply cleanse effect (remove debuffs from target)
func _apply_cleanse_effect(effect_data: Dictionary, _caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var count: int = effect_data.get("count", 1)  # Number of debuffs to remove

	var removed: int = 0
	for i: int in range(count):
		if target.remove_random_debuff():
			removed += 1
		else:
			break

	if removed > 0:
		result.message += " %s cleansed %d debuff(s)!" % [target.display_name, removed]

## Apply strip effect (remove buffs from enemy)
func _apply_strip_effect(effect_data: Dictionary, _caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)
	var count: int = effect_data.get("count", 1)

	if randf() * 100 > chance:
		return

	var removed: int = 0
	for i: int in range(count):
		if target.remove_random_buff():
			removed += 1
		else:
			break

	if removed > 0:
		result.message += " %s stripped %d buff(s)!" % [target.display_name, removed]

## Apply strip all effect (remove all buffs from enemy)
func _apply_strip_all_effect(effect_data: Dictionary, _caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)

	if randf() * 100 > chance:
		return

	var removed: int = target.remove_all_buffs()
	if removed > 0:
		result.message += " All buffs stripped from %s!" % target.display_name

## Apply steal buff effect (take a buff from enemy)
func _apply_steal_buff_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)
	var count: int = effect_data.get("count", 1)

	if randf() * 100 > chance:
		return

	var stolen: int = 0
	for i: int in range(count):
		var buff: StatusEffect = target.steal_random_buff()
		if buff:
			buff.target_name = caster.display_name
			caster.add_status_effect(buff)
			stolen += 1
		else:
			break

	if stolen > 0:
		result.message += " %s stole %d buff(s) from %s!" % [caster.display_name, stolen, target.display_name]

## Apply additional turn effect (grants extra turn)
func _apply_additional_turn(effect_data: Dictionary, caster: BattleUnit, result: ActionResult) -> void:
	var chance: int = effect_data.get("chance", 100)

	if randf() * 100 > chance:
		return

	# Fill turn bar to threshold for immediate next turn
	var threshold: float = TurnManager.get_turn_bar_threshold()
	caster.current_turn_bar = threshold
	result.message += " %s gains an additional turn!" % caster.display_name

## Apply team buff effect (buff all allies)
func _apply_team_buff_effect(effect_data: Dictionary, caster: BattleUnit, result: ActionResult) -> void:
	if not battle_state:
		return

	var allies: Array[BattleUnit] = []
	if caster.is_player_unit:
		allies = battle_state.get_living_player_units()
	else:
		allies = battle_state.get_living_enemy_units()

	for ally: BattleUnit in allies:
		_apply_buff_effect(effect_data, caster, ally, result)

## Apply team heal effect (heal all allies)
func _apply_team_heal_effect(effect_data: Dictionary, caster: BattleUnit, result: ActionResult) -> void:
	if not battle_state:
		return

	var heal_percent: float = effect_data.get("value", 0.2)
	var scaling: String = effect_data.get("scaling", "attack")

	var base_value: int = caster.attack
	if scaling == "MAX_HP":
		base_value = caster.max_hp

	var heal_amount: int = int(base_value * heal_percent)

	var allies: Array[BattleUnit] = []
	if caster.is_player_unit:
		allies = battle_state.get_living_player_units()
	else:
		allies = battle_state.get_living_enemy_units()

	for ally: BattleUnit in allies:
		ally.heal(heal_amount)

	result.message += " All allies healed for %d!" % heal_amount

## Apply smart heal effect (heal lowest HP ally)
func _apply_smart_heal_effect(effect_data: Dictionary, caster: BattleUnit, result: ActionResult) -> void:
	if not battle_state:
		return

	var heal_percent: float = effect_data.get("value", 0.3)
	var scaling: String = effect_data.get("scaling", "attack")

	var base_value: int = caster.attack
	if scaling == "MAX_HP":
		base_value = caster.max_hp

	var heal_amount: int = int(base_value * heal_percent)

	var allies: Array[BattleUnit] = []
	if caster.is_player_unit:
		allies = battle_state.get_living_player_units()
	else:
		allies = battle_state.get_living_enemy_units()

	# Find ally with lowest HP percentage
	var lowest_ally: BattleUnit = null
	var lowest_hp_pct: float = 1.0

	for ally: BattleUnit in allies:
		var hp_pct: float = float(ally.current_hp) / float(ally.max_hp)
		if hp_pct < lowest_hp_pct:
			lowest_hp_pct = hp_pct
			lowest_ally = ally

	if lowest_ally:
		lowest_ally.heal(heal_amount)
		result.message += " %s healed for %d!" % [lowest_ally.display_name, heal_amount]
