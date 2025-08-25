# BattleEffectProcessor.gd - Process all SW battle effects (extracted from BattleManager)
class_name BattleEffectProcessor
extends RefCounted

# Static class for processing all Summoners War battle effects
# This handles the actual effect application logic, while StatusEffectManager handles status effect lifecycle

static func process_single_effect(effect_type: String, effect_data: Dictionary, caster, target, ability: Dictionary, battle_context: Dictionary):
	"""Modular SW effect processor - handles all Summoners War effects"""
	print("=== PROCESSING EFFECT: ", effect_type, " ===")
	print("Effect data: ", effect_data)
	print("Caster: ", _get_stat(caster, "name", "Unknown"))
	print("Target: ", _get_stat(target, "name", "Unknown") if target else "None")
	
	match effect_type:
		"heal":
			_process_heal_effect(effect_data, caster, target, battle_context)
		"shield":
			_process_shield_effect(effect_data, caster, target, battle_context)
		"buff":
			_process_buff_effect(effect_data, caster, target, battle_context)
		"debuff":
			_process_debuff_effect(effect_data, caster, target, battle_context)
		"self_buff":
			_process_self_buff_effect(effect_data, caster, battle_context)
		"cleanse":
			_process_cleanse_effect(effect_data, caster, target, battle_context)
		"cleanse_all":
			_process_cleanse_all_effect(effect_data, caster, battle_context)
		"strip":
			_process_strip_effect(effect_data, caster, target, battle_context)
		"strip_all":
			_process_strip_all_effect(effect_data, caster, battle_context)
		"atb_increase":
			_process_atb_increase_effect(effect_data, caster, target, battle_context)
		"atb_decrease":
			_process_atb_decrease_effect(effect_data, caster, target, battle_context)
		"atb_steal":
			_process_atb_steal_effect(effect_data, caster, target, battle_context)
		"self_atb_increase":
			_process_self_atb_increase_effect(effect_data, caster, battle_context)
		"life_drain":
			_process_life_drain_effect(effect_data, caster, target, ability, battle_context)
		"additional_turn":
			_process_additional_turn_effect(effect_data, caster, battle_context)
		"team_buff":
			_process_team_buff_effect(effect_data, caster, battle_context)
		"team_heal":
			_process_team_heal_effect(effect_data, caster, battle_context)
		"team_atb_increase":
			_process_team_atb_increase_effect(effect_data, caster, battle_context)
		"team_cleanse_all":
			_process_team_cleanse_all_effect(effect_data, caster, battle_context)
		"smart_heal":
			_process_smart_heal_effect(effect_data, caster, battle_context)
		"conditional_buff":
			_process_conditional_buff_effect(effect_data, caster, target, ability, battle_context)
		"conditional_debuff":
			_process_conditional_debuff_effect(effect_data, caster, target, ability, battle_context)
		"random_buff":
			_process_random_buff_effect(effect_data, caster, target, battle_context)
		"random_debuffs":
			_process_random_debuffs_effect(effect_data, caster, target, battle_context)
		"random_team_buff":
			_process_random_team_buff_effect(effect_data, caster, battle_context)
		"random_debuff_per_hit":
			_process_random_debuff_per_hit_effect(effect_data, caster, target, ability, battle_context)
		"steal_buff":
			_process_steal_buff_effect(effect_data, caster, target, battle_context)
		"sequential_debuffs":
			_process_sequential_debuffs_effect(effect_data, caster, target, battle_context)
		"reset_buff_duration":
			_process_reset_buff_duration_effect(effect_data, caster, target, battle_context)
		"max_hp_reduction":
			_process_max_hp_reduction_effect(effect_data, caster, target, battle_context)
		"revive_all":
			_process_revive_all_effect(effect_data, caster, battle_context)
		"random_team_buff_or_enemy_debuff":
			_process_random_team_buff_or_enemy_debuff_effect(effect_data, caster, battle_context)
		_:
			print("WARNING: Unknown effect type: %s" % effect_type)

# === CORE EFFECT IMPLEMENTATIONS ===

static func _process_heal_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process healing effect with proper scaling"""
	var heal_value = effect_data.get("value", 0)
	var scaling = effect_data.get("scaling", "")
	
	var actual_heal = 0
	if scaling == "target_max_hp":
		var target_max_hp = _get_stat(target, "max_hp", 100)
		actual_heal = int(target_max_hp * heal_value / 100.0)
	elif scaling == "caster_attack":
		var caster_attack = _get_stat(caster, "attack", 50)
		actual_heal = int(caster_attack * heal_value / 100.0)
	else:
		actual_heal = heal_value
	
	# Apply healing
	var current_hp = _get_stat(target, "current_hp", 100)
	var max_hp = _get_stat(target, "max_hp", 100)
	var new_hp = min(max_hp, current_hp + actual_heal)
	_set_hp(target, new_hp)
	
	_emit_battle_log("heal applied", "%s heals for %d HP!" % [_get_stat(target, "name", "Unknown"), actual_heal], battle_context)
	_update_unit_ui(target, battle_context)

static func _process_shield_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process shield effect with proper scaling"""
	print("=== SHIELD EFFECT DEBUG ===")
	print("Effect data: ", effect_data)
	print("Caster: ", _get_stat(caster, "name", "Unknown"))
	print("Target: ", _get_stat(target, "name", "Unknown"))
	
	var shield_value = effect_data.get("value", 0)
	var scaling = effect_data.get("scaling", "")
	var duration = effect_data.get("duration", 3)
	
	var actual_shield = 0
	if scaling == "MAX_HP":
		var caster_max_hp = _get_stat(caster, "max_hp", 100)
		actual_shield = int(caster_max_hp * shield_value / 100.0)
	elif scaling == "ATK":
		var caster_attack = _get_stat(caster, "attack", 50)
		actual_shield = int(caster_attack * shield_value / 100.0)
	else:
		actual_shield = shield_value
	
	print("Shield calculation: value=%s, scaling=%s, final=%d" % [shield_value, scaling, actual_shield])
	
	# Create and apply shield effect
	var shield_effect = StatusEffect.create_shield(caster, duration)
	shield_effect.shield_value = actual_shield
	StatusEffectManager.apply_status_effect_to_target(target, shield_effect, battle_context.get("status_effect_manager"))
	
	_emit_battle_log("shield applied", "%s gains %d shield for %d turns!" % [_get_stat(target, "name", "Unknown"), actual_shield, duration], battle_context)
	_update_unit_ui(target, battle_context)

static func _process_buff_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process buff effect"""
	var buff_type = effect_data.get("buff", "attack_boost")
	var duration = effect_data.get("duration", 3)
	var chance = effect_data.get("chance", 100.0) / 100.0
	
	if randf() > chance:
		print("Buff failed chance check on %s" % _get_stat(target, "name", "Unknown"))
		return
	
	var status_effect = StatusEffectManager.create_status_effect_from_id(buff_type, caster)
	if status_effect:
		status_effect.duration = duration
		StatusEffectManager.apply_status_effect_to_target(target, status_effect, battle_context.get("status_effect_manager"))
		_emit_battle_log("buff applied", "%s gains %s!" % [_get_stat(target, "name", "Unknown"), status_effect.name], battle_context)
		_update_unit_ui(target, battle_context)

static func _process_debuff_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process debuff effect"""
	var debuff_type = effect_data.get("debuff", "stun")
	var duration = effect_data.get("duration", 2)
	var chance = effect_data.get("chance", 75.0) / 100.0
	
	if randf() > chance:
		print("Debuff failed chance check on %s" % _get_stat(target, "name", "Unknown"))
		return
	
	var status_effect = StatusEffectManager.create_status_effect_from_id(debuff_type, caster)
	if status_effect:
		status_effect.duration = duration
		StatusEffectManager.apply_status_effect_to_target(target, status_effect, battle_context.get("status_effect_manager"))
		_emit_battle_log("debuff applied", "Applied %s to %s (%s)" % [status_effect.name, _get_stat(target, "name", "Unknown"), "Enemy" if not target is God else "God"], battle_context)
		_update_unit_ui(target, battle_context)

static func _process_self_buff_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process self buff effect"""
	var buff_type = effect_data.get("buff", "attack_boost")
	var duration = effect_data.get("duration", 3)
	
	var status_effect = StatusEffectManager.create_status_effect_from_id(buff_type, caster)
	if status_effect:
		status_effect.duration = duration
		StatusEffectManager.apply_status_effect_to_target(caster, status_effect, battle_context.get("status_effect_manager"))
		_emit_battle_log("self buff applied", "%s buffs themselves with %s!" % [_get_stat(caster, "name", "Unknown"), status_effect.name], battle_context)
		_update_unit_ui(caster, battle_context)

static func _process_cleanse_effect(_effect_data: Dictionary, _caster, target, battle_context: Dictionary):
	"""Process cleanse effect - removes debuffs"""
	var removed_count = StatusEffectManager.cleanse_target(target, battle_context.get("status_effect_manager"))
	if removed_count > 0:
		_emit_battle_log("cleanse applied", "%d debuff(s) cleansed from %s!" % [removed_count, _get_stat(target, "name", "Unknown")], battle_context)
		_update_unit_ui(target, battle_context)

static func _process_cleanse_all_effect(_effect_data: Dictionary, _caster, battle_context: Dictionary):
	"""Process cleanse all effect - removes debuffs from all allies"""
	var current_battle_gods = battle_context.get("current_battle_gods", [])
	var cleansed_units = []
	for ally in current_battle_gods:
		if ally and _get_stat(ally, "current_hp", 0) > 0:
			var removed_count = StatusEffectManager.cleanse_target(ally, battle_context.get("status_effect_manager"))
			if removed_count > 0:
				cleansed_units.append(ally.name)
	
	if cleansed_units.size() > 0:
		_emit_battle_log("cleanse all applied", "Cleansed debuffs from: %s" % ", ".join(cleansed_units), battle_context)

static func _process_strip_effect(effect_data: Dictionary, _caster, target, battle_context: Dictionary):
	"""Process strip effect - removes buffs from target"""
	var count = effect_data.get("count", 1)
	var chance = effect_data.get("chance", 100.0) / 100.0
	
	if randf() > chance:
		print("Strip failed chance check on %s" % _get_stat(target, "name", "Unknown"))
		return
	
	var removed_count = StatusEffectManager.dispel_buffs_from_target(target, count, battle_context.get("status_effect_manager"))
	if removed_count > 0:
		_emit_battle_log("strip applied", "%d buff(s) stripped from %s!" % [removed_count, _get_stat(target, "name", "Unknown")], battle_context)
		_update_unit_ui(target, battle_context)

static func _process_strip_all_effect(_effect_data: Dictionary, _caster, battle_context: Dictionary):
	"""Process strip all effect - removes all buffs from all enemies"""
	var current_battle_enemies = battle_context.get("current_battle_enemies", [])
	var stripped_units = []
	for enemy in current_battle_enemies:
		if enemy and _get_stat(enemy, "current_hp", 0) > 0:
			var removed_count = StatusEffectManager.dispel_buffs_from_target(enemy, 99, battle_context.get("status_effect_manager"))
			if removed_count > 0:
				stripped_units.append(_get_stat(enemy, "name", "Unknown"))
	
	if stripped_units.size() > 0:
		_emit_battle_log("strip all applied", "Stripped buffs from: %s" % ", ".join(stripped_units), battle_context)

# === ATB MANIPULATION EFFECTS ===

static func _process_atb_increase_effect(effect_data: Dictionary, _caster, target, battle_context: Dictionary):
	"""Process ATB increase effect"""
	var value = effect_data.get("value", 15)
	print("ATB increase effect - not yet implemented in turn system")
	_emit_battle_log("atb increase", "%s gains %d%% ATB (not implemented)" % [_get_stat(target, "name", "Unknown"), value], battle_context)

static func _process_atb_decrease_effect(effect_data: Dictionary, _caster, target, battle_context: Dictionary):
	"""Process ATB decrease effect"""
	var value = effect_data.get("value", 15)
	print("ATB decrease effect - not yet implemented in turn system")
	_emit_battle_log("atb decrease", "%s loses %d%% ATB (not implemented)" % [_get_stat(target, "name", "Unknown"), value], battle_context)

static func _process_atb_steal_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process ATB steal effect"""
	var value = effect_data.get("value", 15)
	print("ATB steal effect - not yet implemented in turn system")
	_emit_battle_log("atb steal", "%s steals %d%% ATB from %s (not implemented)" % [_get_stat(caster, "name", "Unknown"), value, _get_stat(target, "name", "Unknown")], battle_context)

static func _process_self_atb_increase_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process self ATB increase effect"""
	var value = effect_data.get("value", 25)
	print("Self ATB increase effect - not yet implemented in turn system")
	_emit_battle_log("self atb increase", "%s gains %d%% ATB (not implemented)" % [_get_stat(caster, "name", "Unknown"), value], battle_context)

# === ADVANCED SW EFFECTS ===

static func _process_life_drain_effect(effect_data: Dictionary, caster, _target, ability: Dictionary, battle_context: Dictionary):
	"""Process life drain effect - heal based on damage dealt"""
	var drain_percent = effect_data.get("percent", 30.0) / 100.0
	var last_damage = ability.get("last_damage_dealt", 0)  # Would need to be set by damage calculation
	
	if last_damage > 0:
		var heal_amount = int(last_damage * drain_percent)
		var current_hp = _get_stat(caster, "current_hp", 100)
		var max_hp = _get_stat(caster, "max_hp", 100)
		var new_hp = min(max_hp, current_hp + heal_amount)
		_set_hp(caster, new_hp)
		
		_emit_battle_log("life drain", "%s drains %d HP!" % [_get_stat(caster, "name", "Unknown"), heal_amount], battle_context)
		_update_unit_ui(caster, battle_context)

static func _process_additional_turn_effect(_effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process additional turn effect"""
	print("Additional turn effect - not yet implemented in turn system")
	_emit_battle_log("additional turn", "%s gains an additional turn (not implemented)" % _get_stat(caster, "name", "Unknown"), battle_context)

# === TEAM EFFECTS ===

static func _process_team_buff_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process team buff effect"""
	var buff_type = effect_data.get("buff", "attack_boost")
	var duration = effect_data.get("duration", 3)
	var current_battle_gods = battle_context.get("current_battle_gods", [])
	
	var buffed_allies = []
	for ally in current_battle_gods:
		if ally and _get_stat(ally, "current_hp", 0) > 0:
			var status_effect = StatusEffectManager.create_status_effect_from_id(buff_type, caster)
			if status_effect:
				status_effect.duration = duration
				StatusEffectManager.apply_status_effect_to_target(ally, status_effect, battle_context.get("status_effect_manager"))
				buffed_allies.append(ally.name)
				_update_unit_ui(ally, battle_context)
	
	if buffed_allies.size() > 0:
		_emit_battle_log("team buff", "Team buffed with %s: %s" % [buff_type.replace("_", " ").capitalize(), ", ".join(buffed_allies)], battle_context)

static func _process_team_heal_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process team heal effect"""
	var heal_value = effect_data.get("value", 15)
	var scaling = effect_data.get("scaling", "caster_attack")
	var current_battle_gods = battle_context.get("current_battle_gods", [])
	
	var healed_allies = []
	for ally in current_battle_gods:
		if ally and _get_stat(ally, "current_hp", 0) > 0:
			var actual_heal = 0
			if scaling == "caster_attack":
				var caster_attack = _get_stat(caster, "attack", 50)
				actual_heal = int(caster_attack * heal_value / 100.0)
			else:
				var ally_max_hp = _get_stat(ally, "max_hp", 100)
				actual_heal = int(ally_max_hp * heal_value / 100.0)
			
			var current_hp = _get_stat(ally, "current_hp", 100)
			var max_hp = _get_stat(ally, "max_hp", 100)
			var new_hp = min(max_hp, current_hp + actual_heal)
			_set_hp(ally, new_hp)
			
			healed_allies.append("%s (+%d)" % [ally.name, actual_heal])
			_update_unit_ui(ally, battle_context)
	
	if healed_allies.size() > 0:
		_emit_battle_log("team heal", "Team healed: %s" % ", ".join(healed_allies), battle_context)

static func _process_team_atb_increase_effect(effect_data: Dictionary, _caster, battle_context: Dictionary):
	"""Process team ATB increase effect"""
	var _value = effect_data.get("value", 15)
	print("Team ATB increase effect - not yet implemented in turn system")
	_emit_battle_log("team atb increase", "Team gains ATB boost (not implemented)", battle_context)

static func _process_team_cleanse_all_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process team cleanse all effect"""
	_process_cleanse_all_effect(effect_data, caster, battle_context)

# === SMART/CONDITIONAL EFFECTS (Basic implementations) ===

static func _process_smart_heal_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process smart heal - heals ally with lowest HP%"""
	var heal_value = effect_data.get("value", 25)
	var current_battle_gods = battle_context.get("current_battle_gods", [])
	
	var lowest_hp_ally = null
	var lowest_hp_percent = 1.0
	
	for ally in current_battle_gods:
		if ally and _get_stat(ally, "current_hp", 0) > 0:
			var hp_percent = float(_get_stat(ally, "current_hp", 100)) / float(_get_stat(ally, "max_hp", 100))
			if hp_percent < lowest_hp_percent:
				lowest_hp_percent = hp_percent
				lowest_hp_ally = ally
	
	if lowest_hp_ally:
		_process_heal_effect({"value": heal_value, "scaling": "caster_attack"}, caster, lowest_hp_ally, battle_context)

static func _process_conditional_buff_effect(_effect_data: Dictionary, _caster, _target, _ability: Dictionary, battle_context: Dictionary):
	"""Process conditional buff effect (simplified)"""
	print("Conditional buff effect - simplified implementation")
	_emit_battle_log("conditional buff", "Conditional effect triggered (simplified)", battle_context)

static func _process_conditional_debuff_effect(_effect_data: Dictionary, _caster, _target, _ability: Dictionary, battle_context: Dictionary):
	"""Process conditional debuff effect (simplified)"""
	print("Conditional debuff effect - simplified implementation")
	_emit_battle_log("conditional debuff", "Conditional effect triggered (simplified)", battle_context)

# === RANDOM EFFECTS (Simplified implementations) ===

static func _process_random_buff_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process random buff effect"""
	var possible_buffs = ["attack_boost", "defense_boost", "speed_boost", "crit_boost"]
	var random_buff = possible_buffs[randi() % possible_buffs.size()]
	var duration = effect_data.get("duration", 2)
	
	_process_buff_effect({"buff": random_buff, "duration": duration, "chance": 100}, caster, target, battle_context)

static func _process_random_debuffs_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process random debuffs effect"""
	var possible_debuffs = ["stun", "slow", "defense_reduction", "attack_reduction"]
	var debuff_count = effect_data.get("count", 1)
	var _duration = effect_data.get("duration", 2)
	
	for i in range(debuff_count):
		var random_debuff = possible_debuffs[randi() % possible_debuffs.size()]
		_process_debuff_effect({"debuff": random_debuff, "duration": _duration, "chance": 75}, caster, target, battle_context)

static func _process_random_team_buff_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process random team buff effect"""
	var possible_buffs = ["attack_boost", "defense_boost", "speed_boost"]
	var random_buff = possible_buffs[randi() % possible_buffs.size()]
	var duration = effect_data.get("duration", 2)
	
	_process_team_buff_effect({"buff": random_buff, "duration": duration}, caster, battle_context)

static func _process_random_debuff_per_hit_effect(effect_data: Dictionary, caster, target, _ability: Dictionary, battle_context: Dictionary):
	"""Process random debuff per hit effect"""
	var possible_debuffs = ["stun", "slow", "defense_reduction"]
	var random_debuff = possible_debuffs[randi() % possible_debuffs.size()]
	var duration = effect_data.get("duration", 1)
	
	_process_debuff_effect({"debuff": random_debuff, "duration": duration, "chance": 25}, caster, target, battle_context)

# === ADVANCED/SPECIAL EFFECTS (Basic implementations) ===

static func _process_steal_buff_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process steal buff effect"""
	var count = effect_data.get("count", 1)
	var removed_count = StatusEffectManager.dispel_buffs_from_target(target, count, battle_context.get("status_effect_manager"))
	if removed_count > 0:
		# For simplicity, just give caster a random buff instead of transferring exact buff
		_process_random_buff_effect({"duration": 3}, caster, caster, battle_context)
		_emit_battle_log("steal buff", "%s steals %d buff(s) from %s" % [_get_stat(caster, "name", "Unknown"), removed_count, _get_stat(target, "name", "Unknown")], battle_context)

static func _process_sequential_debuffs_effect(effect_data: Dictionary, caster, target, battle_context: Dictionary):
	"""Process sequential debuffs effect"""
	var debuff_list = effect_data.get("debuffs", ["stun", "slow"])
	var _duration = effect_data.get("duration", 2)
	
	for debuff_type in debuff_list:
		_process_debuff_effect({"debuff": debuff_type, "duration": _duration, "chance": 50}, caster, target, battle_context)

static func _process_reset_buff_duration_effect(_effect_data: Dictionary, _caster, target, battle_context: Dictionary):
	"""Process reset buff duration effect"""
	print("Reset buff duration effect - simplified implementation")
	_emit_battle_log("reset buff duration", "%s's buff durations reset (simplified)" % _get_stat(target, "name", "Unknown"), battle_context)

static func _process_max_hp_reduction_effect(_effect_data: Dictionary, _caster, target, battle_context: Dictionary):
	"""Process max HP reduction effect"""
	print("Max HP reduction effect - not implemented")
	_emit_battle_log("max hp reduction", "%s's max HP reduced (not implemented)" % _get_stat(target, "name", "Unknown"), battle_context)

static func _process_revive_all_effect(_effect_data: Dictionary, _caster, battle_context: Dictionary):
	"""Process revive all effect"""
	print("Revive all effect - not implemented")
	_emit_battle_log("revive all", "All allies revived (not implemented)", battle_context)

static func _process_random_team_buff_or_enemy_debuff_effect(effect_data: Dictionary, caster, battle_context: Dictionary):
	"""Process random team buff or enemy debuff effect"""
	if randf() < 0.5:
		_process_random_team_buff_effect(effect_data, caster, battle_context)
	else:
		var current_battle_enemies = battle_context.get("current_battle_enemies", [])
		if current_battle_enemies.size() > 0:
			var random_enemy = current_battle_enemies[randi() % current_battle_enemies.size()]
			_process_random_debuffs_effect(effect_data, caster, random_enemy, battle_context)

# === HELPER FUNCTIONS ===

static func _get_stat(unit, stat_name: String, default_value: Variant = 0):
	"""Safely get a stat from either God object or dictionary - UNIFIED APPROACH"""
	if not unit:
		return default_value
	if unit is God:
		match stat_name:
			"name": return unit.name
			"hp", "current_hp": return unit.current_hp
			"max_hp": return unit.get_max_hp()
			"attack": return unit.get_current_attack()
			"defense": return unit.get_current_defense()
			_: return default_value
	elif stat_name == "current_hp":
		return unit.get("current_hp", unit.get("hp", default_value))
	elif unit.has(stat_name):
		return unit[stat_name]
	else:
		return default_value

static func _set_hp(unit, new_hp: int):
	"""Safely set HP for either God object or dictionary - UNIFIED APPROACH"""
	if unit is God:
		unit.current_hp = new_hp
	else:
		unit.current_hp = new_hp

static func _emit_battle_log(event_type: String, message: String, battle_context: Dictionary):
	"""Emit battle log message through battle context"""
	print("BATTLE LOG [%s]: %s" % [event_type, message])
	# Battle context could contain a signal to emit or battle manager reference
	var battle_manager = battle_context.get("battle_manager")
	if battle_manager and battle_manager.has_signal("battle_log_updated"):
		battle_manager.battle_log_updated.emit(message)

static func _update_unit_ui(unit, battle_context: Dictionary):
	"""Update unit UI through battle context"""
	var battle_screen = battle_context.get("battle_screen")
	if battle_screen:
		if unit is God:
			battle_screen.update_god_hp_instantly(unit)
			battle_screen.update_god_status_effects(unit)
		else:
			battle_screen.update_enemy_hp_instantly(unit)
			battle_screen.update_enemy_status_effects(unit)
