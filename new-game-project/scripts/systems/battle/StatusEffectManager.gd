# scripts/systems/battle/StatusEffectManager.gd
extends Node
class_name StatusEffectManager

# ==============================================================================
# STATUS EFFECT MANAGER - Battle status effect processing (150 lines max)
# ==============================================================================
# Single responsibility: Process turn-based status effects
# Uses SystemRegistry pattern for clean architecture

signal status_effect_applied(target, effect)
signal status_effect_removed(target, effect_id)
signal status_effect_triggered(target, effect, result)

func _ready():
	pass

# ==============================================================================
# MAIN STATUS EFFECT PROCESSING - Clean and focused
# ==============================================================================

func process_turn_start_effects(unit) -> Array:
	"""Process status effects at start of turn - returns messages"""
	var messages = []
	
	if not unit.has_method("get_status_effects"):
		return messages
	
	var effects = unit.get_status_effects()
	for effect in effects:
		var result = _process_single_effect(unit, effect, "turn_start")
		if result.message:
			messages.append(result.message)
	
	return messages

func process_turn_end_effects(unit) -> Array:
	"""Process status effects at end of turn - returns messages"""
	var messages = []
	
	if not unit.has_method("get_status_effects"):
		return messages
	
	var effects = unit.get_status_effects()
	for effect in effects:
		var result = _process_single_effect(unit, effect, "turn_end")
		if result.message:
			messages.append(result.message)
	
	return messages

func _process_single_effect(unit, effect, timing: String) -> Dictionary:
	"""Process a single status effect"""
	var result = {"message": "", "damage": 0, "healing": 0}
	
	if not effect.should_trigger_on(timing):
		return result
	
	match effect.effect_type:
		"poison":
			result = _process_poison_effect(unit, effect)
		"burn":
			result = _process_burn_effect(unit, effect)
		"heal_over_time":
			result = _process_heal_effect(unit, effect)
		"shield":
			result = _process_shield_effect(unit, effect)
		"stun":
			result = _process_stun_effect(unit, effect)
	
	# Emit signal for UI updates
	if result.damage > 0 or result.healing > 0:
		status_effect_triggered.emit(unit, effect, result)
	
	# Reduce effect duration
	effect.reduce_duration()
	if effect.is_expired():
		_remove_effect(unit, effect)
	
	return result

# ==============================================================================
# SPECIFIC EFFECT PROCESSING - Single responsibility per effect
# ==============================================================================

func _process_poison_effect(unit, effect) -> Dictionary:
	"""Process poison damage"""
	var damage = effect.get_damage_amount()
	unit.take_damage(damage)
	
	return {
		"message": "%s takes %d poison damage" % [unit.get_display_name(), damage],
		"damage": damage,
		"healing": 0
	}

func _process_burn_effect(unit, effect) -> Dictionary:
	"""Process burn damage"""
	var damage = effect.get_damage_amount()
	unit.take_damage(damage)
	
	return {
		"message": "%s takes %d burn damage" % [unit.get_display_name(), damage],
		"damage": damage,
		"healing": 0
	}

func _process_heal_effect(unit, effect) -> Dictionary:
	"""Process healing over time"""
	var healing = effect.get_heal_amount()
	unit.heal(healing)
	
	return {
		"message": "%s heals for %d HP" % [unit.get_display_name(), healing],
		"damage": 0,
		"healing": healing
	}

func _process_shield_effect(unit, effect) -> Dictionary:
	"""Process shield effect"""
	# Shield effects are passive, just track
	return {
		"message": "%s is protected by shield" % unit.get_display_name(),
		"damage": 0,
		"healing": 0
	}

func _process_stun_effect(unit, effect) -> Dictionary:
	"""Process stun effect"""
	unit.set_stunned(true)
	return {
		"message": "%s is stunned" % unit.get_display_name(),
		"damage": 0,
		"healing": 0
	}

func _remove_effect(unit, effect):
	"""Remove expired effect from unit"""
	if unit.has_method("remove_status_effect"):
		unit.remove_status_effect(effect.id)
		status_effect_removed.emit(unit, effect.id)

# ==============================================================================
# EFFECT APPLICATION - Clean interface
# ==============================================================================

func apply_status_effect(target, effect):
	"""Apply a status effect to target"""
	if not target.has_method("add_status_effect"):
		return false
	
	target.add_status_effect(effect)
	status_effect_applied.emit(target, effect)
	return true

func remove_status_effect(target, effect_id: String):
	"""Remove specific status effect from target"""
	if not target.has_method("remove_status_effect"):
		return false
	
	target.remove_status_effect(effect_id)
	status_effect_removed.emit(target, effect_id)
	return true
