# StatusE	static func proces	static func process_turn_end_effects(unit, _manager: StatusEffectManager) -> Array:_turn_start_effects(unit, _manager: StatusEffectManager) -> Array:fectManager.gd - Handle all status effect operations
class_name StatusEffectManager
extends RefCounted

signal status_effect_applied(target, effect)
signal status_effect_removed(target, effect_id)

# Main status effect processing methods

static func process_turn_start_effects(unit, manager: StatusEffectManager) -> Array:
	"""Process status effects at start of turn - returns messages"""
	var messages = []
	
	if unit is God:
		var results = unit.process_turn_start_effects()
		messages.append_array(results.messages)
		
		# If there was damage/healing, emit signals for UI
		if results.total_damage > 0 or results.total_healing > 0:
			# Could emit specific signals here for UI updates
			pass
	else:
		# Process enemy status effects
		var enemy_messages = _process_enemy_turn_start_effects(unit)
		messages.append_array(enemy_messages)
	
	return messages

static func process_turn_end_effects(unit, manager: StatusEffectManager) -> Array:
	"""Process status effects at end of turn - returns messages"""
	var messages = []
	
	if unit is God:
		# For now, God class doesn't have turn end effects processing
		# Most effects are processed at turn start
		# Could add turn end processing to God class in the future if needed
		pass
	else:
		# Process enemy turn end effects
		var enemy_messages = _process_enemy_turn_end_effects(unit)
		messages.append_array(enemy_messages)
	
	return messages

static func apply_status_effect_to_target(target, effect: StatusEffect, manager: StatusEffectManager):
	"""Apply a status effect to a target"""
	var target_name = _get_unit_name(target)
	var effect_type = "BUFF" if effect.effect_type == StatusEffect.EffectType.BUFF else "DEBUFF"
	
	# Check for debuff immunity before applying negative effects
	if (effect.effect_type == StatusEffect.EffectType.DEBUFF or effect.effect_type == StatusEffect.EffectType.DOT) and target is God:
		for existing_effect in target.status_effects:
			if existing_effect.immune_to_debuffs:
				print("%s is immune to %s!" % [target_name, effect.name])
				return
	
	if target is God:
		if target.add_status_effect(effect):
			manager.status_effect_applied.emit(target, effect)
			print("Applied %s to %s (Type: %s, Duration: %d)" % [effect.name, target_name, effect_type, effect.duration])
	else:
		# Enemy status effects (simplified)
		if not target.has("status_effects"):
			target.status_effects = []
		
		# Check for existing effect to refresh or stack
		var existing_index = -1
		for i in range(target.status_effects.size()):
			if target.status_effects[i].id == effect.id:
				existing_index = i
				break
		
		if existing_index >= 0:
			# Refresh existing effect
			target.status_effects[existing_index].duration = effect.duration
			print("Refreshed %s on %s" % [effect.name, target_name])
		else:
			# Add new effect
			target.status_effects.append(effect)
			print("Applied %s to %s (Enemy)" % [effect.name, target_name])

static func remove_status_effect_from_target(target, effect_id: String, manager: StatusEffectManager):
	"""Remove a specific status effect from target"""
	if target is God:
		if target.remove_status_effect(effect_id):
			manager.status_effect_removed.emit(target, effect_id)
			print("Removed %s from %s" % [effect_id, target.name])
	else:
		# Enemy status effect removal
		if target.has("status_effects"):
			for i in range(target.status_effects.size() - 1, -1, -1):
				var effect = target.status_effects[i]
				var matches = false
				
				if effect is StatusEffect:
					# Handle StatusEffect objects
					matches = (effect.id == effect_id)
				else:
					# Handle dictionary effects (legacy)
					matches = (effect.get("id") == effect_id)
				
				if matches:
					target.status_effects.remove_at(i)
					manager.status_effect_removed.emit(target, effect_id)
					print("Removed %s from %s" % [effect_id, _get_unit_name(target)])
					break

static func cleanse_target(target, manager: StatusEffectManager) -> int:
	"""Remove debuffs from target - returns number of debuffs removed"""
	var debuffs_removed = 0
	
	if target is God:
		for i in range(target.status_effects.size() - 1, -1, -1):
			var effect = target.status_effects[i]
			if effect.effect_type == StatusEffect.EffectType.DEBUFF or effect.effect_type == StatusEffect.EffectType.DOT:
				var effect_id = effect.id
				target.status_effects.remove_at(i)
				manager.status_effect_removed.emit(target, effect_id)
				debuffs_removed += 1
	else:
		# Enemy cleanse
		if target.has("status_effects"):
			for i in range(target.status_effects.size() - 1, -1, -1):
				var effect = target.status_effects[i]
				var is_debuff = false
				
				if effect is StatusEffect:
					# Handle StatusEffect objects
					is_debuff = (effect.effect_type == StatusEffect.EffectType.DEBUFF or effect.effect_type == StatusEffect.EffectType.DOT)
				else:
					# Handle dictionary effects (legacy)
					is_debuff = (effect.get("effect_type") == "debuff" or effect.get("effect_type") == "dot")
				
				if is_debuff:
					target.status_effects.remove_at(i)
					debuffs_removed += 1
	
	return debuffs_removed

static func dispel_buffs_from_target(target, count: int, manager: StatusEffectManager) -> int:
	"""Remove buffs from target - returns number of buffs removed"""
	var buffs_removed = 0
	
	if target is God:
		var buffs_to_remove = []
		for effect in target.status_effects:
			if effect.effect_type == StatusEffect.EffectType.BUFF:
				buffs_to_remove.append(effect.id)
				if buffs_to_remove.size() >= count:
					break
		
		for effect_id in buffs_to_remove:
			if target.remove_status_effect(effect_id):
				manager.status_effect_removed.emit(target, effect_id)
				buffs_removed += 1
	else:
		# Enemy dispel
		if target.has("status_effects"):
			var removed = 0
			for i in range(target.status_effects.size() - 1, -1, -1):
				if removed >= count:
					break
				var effect = target.status_effects[i]
				var is_buff = false
				
				if effect is StatusEffect:
					# Handle StatusEffect objects
					is_buff = (effect.effect_type == StatusEffect.EffectType.BUFF)
				else:
					# Handle dictionary effects (legacy)
					is_buff = (effect.get("effect_type") == "buff")
				
				if is_buff:
					target.status_effects.remove_at(i)
					removed += 1
			buffs_removed = removed
	
	return buffs_removed

static func has_status_effect(target, effect_id: String) -> bool:
	"""Check if target has a specific status effect"""
	if target is God:
		return target.has_status_effect(effect_id)
	else:
		# Enemy status effect check
		if target.has("status_effects"):
			for effect in target.status_effects:
				if effect is StatusEffect:
					# Handle StatusEffect objects
					if effect.id == effect_id:
						return true
				else:
					# Handle dictionary effects (legacy)
					if effect.get("id") == effect_id:
						return true
		return false

static func create_status_effect_from_id(effect_id: String, caster = null) -> StatusEffect:
	"""Create a status effect from its ID with dynamic scaling based on caster"""
	match effect_id:
		"stun":
			return StatusEffect.create_stun(caster)
		"burn":
			return StatusEffect.create_burn(caster)
		"regeneration":
			return StatusEffect.create_regeneration(caster)
		"attack_boost":
			return StatusEffect.create_attack_boost(caster)
		"defense_boost":
			return StatusEffect.create_defense_boost(caster)
		"speed_boost":
			return StatusEffect.create_speed_boost(caster)
		"shield":
			return StatusEffect.create_shield(caster)
		"fear":
			return StatusEffect.create_fear(caster)
		"slow":
			return StatusEffect.create_slow(caster)
		"debuff_immunity":
			return StatusEffect.create_debuff_immunity(caster)
		"accuracy_boost":
			return StatusEffect.create_accuracy_boost(caster)
		"evasion_boost":
			return StatusEffect.create_evasion_boost(caster)
		"crit_boost":
			return StatusEffect.create_crit_boost(caster)
		"critical_damage_boost":
			return StatusEffect.create_critical_damage_boost(caster)
		"wisdom_boost":
			return StatusEffect.create_wisdom_boost(caster)
		"analyze_weakness":
			return StatusEffect.create_analyze_weakness(caster)
		"marked_for_death":
			return StatusEffect.create_marked_for_death(caster)
		"defense_reduction":
			return StatusEffect.create_defense_reduction(caster)
		"attack_reduction":
			return StatusEffect.create_attack_reduction(caster)
		"damage_immunity":
			return StatusEffect.create_damage_immunity(caster)
		"charm":
			return StatusEffect.create_charm(caster)
		"untargetable":
			return StatusEffect.create_untargetable(caster)
		"counter_attack":
			return StatusEffect.create_counter_attack(caster)
		"blind":
			return StatusEffect.create_blind(caster)
		"reflect_damage":
			return StatusEffect.create_reflect_damage(caster)
		"immobilize":
			return StatusEffect.create_immobilize(caster)
		"curse":
			return StatusEffect.create_curse(caster)
		"bleed":
			return StatusEffect.create_bleed(caster)
		"poison":
			return StatusEffect.create_poison(caster)
		"freeze":
			return StatusEffect.create_freeze(caster)
		"sleep":
			return StatusEffect.create_sleep(caster)
		"silence":
			return StatusEffect.create_silence(caster)
		"provoke":
			return StatusEffect.create_provoke(caster)
		_:
			print("Unknown status effect: ", effect_id)
			return null

# Private helper methods

static func _process_enemy_turn_start_effects(enemy: Dictionary) -> Array:
	"""Process enemy status effects at turn start"""
	var messages = []
	
	if not enemy.has("status_effects") or enemy.status_effects.size() == 0:
		return messages
	
	# Process each effect
	for i in range(enemy.status_effects.size() - 1, -1, -1):
		var effect = enemy.status_effects[i]
		
		# Handle StatusEffect objects (not dictionaries)
		if effect is StatusEffect:
			# Apply damage over time
			if effect.damage_per_turn > 0:
				var dot_damage = int(enemy.get("hp", 100) * effect.damage_per_turn * effect.stacks)
				enemy.current_hp = max(0, enemy.current_hp - dot_damage)
				messages.append("%s takes %d %s damage!" % [enemy.get("name", "Enemy"), dot_damage, effect.name])
			
			# Apply heal over time
			if effect.heal_per_turn > 0:
				var hot_healing = int(enemy.get("hp", 100) * effect.heal_per_turn * effect.stacks)
				var max_hp = enemy.get("hp", 100)
				var actual_healing = min(hot_healing, max_hp - enemy.current_hp)
				if actual_healing > 0:
					enemy.current_hp += actual_healing
					messages.append("%s recovers %d HP from %s!" % [enemy.get("name", "Enemy"), actual_healing, effect.name])
			
			# Reduce duration and remove if expired
			effect.duration -= 1
			if effect.duration <= 0:
				messages.append("%s's %s expired" % [enemy.get("name", "Enemy"), effect.name])
				enemy.status_effects.remove_at(i)
		else:
			# Fallback for dictionary-based effects (legacy support)
			var damage_per_turn = effect.get("damage_per_turn", 0.0)
			if damage_per_turn > 0:
				var dot_damage = int(enemy.get("hp", 100) * damage_per_turn * effect.get("stacks", 1))
				enemy.current_hp = max(0, enemy.current_hp - dot_damage)
				var effect_name = effect.get("name", "DOT")
				messages.append("%s takes %d %s damage!" % [enemy.get("name", "Enemy"), dot_damage, effect_name])
			
			# Apply heal over time
			var heal_per_turn = effect.get("heal_per_turn", 0.0)
			if heal_per_turn > 0:
				var hot_healing = int(enemy.get("hp", 100) * heal_per_turn * effect.get("stacks", 1))
				var max_hp = enemy.get("hp", 100)
				var actual_healing = min(hot_healing, max_hp - enemy.current_hp)
				if actual_healing > 0:
					enemy.current_hp += actual_healing
					var effect_name = effect.get("name", "HOT")
					messages.append("%s recovers %d HP from %s!" % [enemy.get("name", "Enemy"), actual_healing, effect_name])
			
			# Reduce duration and remove if expired
			effect.duration = effect.get("duration", 1) - 1
			if effect.duration <= 0:
				messages.append("%s's %s expired" % [enemy.get("name", "Enemy"), effect.get("name", "effect")])
				enemy.status_effects.remove_at(i)
	
	return messages

static func _process_enemy_turn_end_effects(_enemy: Dictionary) -> Array:
	"""Process enemy status effects at turn end"""
	var messages = []
	
	# For now, most effects are processed at turn start
	# This could handle special turn-end effects if needed
	
	return messages

static func _get_unit_name(unit) -> String:
	"""Get name from either God or dictionary"""
	if unit is God:
		return unit.name
	else:
		return unit.get("name", "Unknown")
