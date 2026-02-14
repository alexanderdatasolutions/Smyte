# scripts/systems/battle/StatusEffectManager.gd
extends Node
class_name StatusEffectManager

# ==============================================================================
# STATUS EFFECT MANAGER - Battle status effect processing
# ==============================================================================
# Single responsibility: Process turn-based status effects
# Uses SystemRegistry pattern for clean architecture

signal status_effect_applied(target: BattleUnit, effect: StatusEffect)
signal status_effect_removed(target: BattleUnit, effect_id: String)
signal status_effect_triggered(target: BattleUnit, effect: StatusEffect, result: Dictionary)

func _ready() -> void:
	pass

# ==============================================================================
# MAIN STATUS EFFECT PROCESSING - Clean and focused
# ==============================================================================

func process_turn_start_effects(unit: BattleUnit) -> Array[String]:
	"""Process status effects at start of turn - returns messages"""
	var messages: Array[String] = []

	for effect: StatusEffect in unit.status_effects:
		var result: Dictionary = _process_single_effect(unit, effect)
		var msg: String = result.get("message", "")
		if msg != "":
			messages.append(msg)

	return messages

func process_turn_end_effects(unit: BattleUnit) -> Array[String]:
	"""Process status effects at end of turn - returns messages"""
	var messages: Array[String] = []

	for effect: StatusEffect in unit.status_effects:
		var result: Dictionary = _process_single_effect(unit, effect)
		var msg: String = result.get("message", "")
		if msg != "":
			messages.append(msg)

	return messages

func _process_single_effect(unit: BattleUnit, effect: StatusEffect) -> Dictionary:
	"""Process a single status effect"""
	var result: Dictionary = {"message": "", "damage": 0, "healing": 0}

	match effect.id:
		"poison":
			result = _process_dot_effect(unit, effect, "poison")
		"burn":
			result = _process_dot_effect(unit, effect, "burn")
		"bleed":
			result = _process_dot_effect(unit, effect, "bleed")
		"continuous_damage":
			result = _process_dot_effect(unit, effect, "continuous damage")
		"regeneration":
			result = _process_hot_effect(unit, effect)
		"shield":
			result = _process_shield_effect(unit, effect)
		"stun", "freeze", "sleep", "immobilize", "fear":
			result = _process_cc_effect(unit, effect)

	# Emit signal for UI updates
	if result.damage > 0 or result.healing > 0:
		status_effect_triggered.emit(unit, effect, result)

	# Reduce effect duration
	effect.duration -= 1
	if effect.is_expired():
		_remove_effect(unit, effect)

	return result

# ==============================================================================
# SPECIFIC EFFECT PROCESSING - Single responsibility per effect
# ==============================================================================

func _process_dot_effect(unit: BattleUnit, effect: StatusEffect, label: String) -> Dictionary:
	"""Process damage over time (poison, burn, bleed, continuous damage)"""
	var damage: int = 0
	if effect.damage_per_turn > 0:
		damage = int(unit.max_hp * effect.damage_per_turn * effect.stacks)
	if effect.dot_damage > 0:
		damage += effect.dot_damage * effect.stacks

	unit.take_damage(damage)

	return {
		"message": "%s takes %d %s damage" % [unit.display_name, damage, label],
		"damage": damage,
		"healing": 0
	}

func _process_hot_effect(unit: BattleUnit, effect: StatusEffect) -> Dictionary:
	"""Process healing over time"""
	var healing: int = 0
	if effect.heal_per_turn > 0:
		healing = int(unit.max_hp * effect.heal_per_turn * effect.stacks)

	unit.heal(healing)

	return {
		"message": "%s heals for %d HP" % [unit.display_name, healing],
		"damage": 0,
		"healing": healing
	}

func _process_shield_effect(unit: BattleUnit, _effect: StatusEffect) -> Dictionary:
	"""Process shield effect"""
	return {
		"message": "%s is protected by shield" % unit.display_name,
		"damage": 0,
		"healing": 0
	}

func _process_cc_effect(unit: BattleUnit, effect: StatusEffect) -> Dictionary:
	"""Process crowd control effect (stun, freeze, sleep, etc.)"""
	# CC prevention is handled by BattleUnit.can_act() checking prevents_action
	return {
		"message": "%s is %s" % [unit.display_name, effect.name.to_lower()],
		"damage": 0,
		"healing": 0
	}

func _remove_effect(unit: BattleUnit, effect: StatusEffect) -> void:
	"""Remove expired effect from unit"""
	unit.remove_status_effect(effect.id)
	status_effect_removed.emit(unit, effect.id)

# ==============================================================================
# EFFECT APPLICATION - Clean interface
# ==============================================================================

func apply_status_effect(target: BattleUnit, effect: StatusEffect) -> bool:
	"""Apply a status effect to target"""
	target.add_status_effect(effect)
	status_effect_applied.emit(target, effect)
	return true

func remove_status_effect(target: BattleUnit, effect_id: String) -> bool:
	"""Remove specific status effect from target"""
	var removed: bool = target.remove_status_effect(effect_id)
	if removed:
		status_effect_removed.emit(target, effect_id)
	return removed
