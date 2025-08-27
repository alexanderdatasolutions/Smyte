# scripts/systems/battle/BattleEffectProcessor.gd
# Battle effect processing system - handles effect application (150 lines max)
class_name BattleEffectProcessor extends Node

# Processes battle effects through clean architecture

signal effect_processed(effect_type: String, caster: BattleUnit, target: BattleUnit)
signal effect_failed(effect_type: String, reason: String)

## Process a single battle effect
func process_effect(effect_type: String, effect_data: Dictionary, caster: BattleUnit, target: BattleUnit = null) -> bool:
	print("BattleEffectProcessor: Processing ", effect_type)
	
	match effect_type:
		"damage":
			return _process_damage_effect(effect_data, caster, target)
		"heal":
			return _process_heal_effect(effect_data, caster, target)
		"buff":
			return _process_buff_effect(effect_data, caster, target)
		"debuff":
			return _process_debuff_effect(effect_data, caster, target)
		"shield":
			return _process_shield_effect(effect_data, caster, target)
		"cleanse":
			return _process_cleanse_effect(effect_data, caster, target)
		_:
			push_error("BattleEffectProcessor: Unknown effect type: " + effect_type)
			effect_failed.emit(effect_type, "Unknown effect type")
			return false

## Process damage effect
func _process_damage_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	if not target:
		return false
	
	var damage_amount = effect_data.get("amount", 0)
	
	# Use CombatCalculator for damage calculation
	var combat_calculator = SystemRegistry.get_instance().get_system("CombatCalculator") if SystemRegistry.get_instance() else null
	if combat_calculator:
		damage_amount = combat_calculator.calculate_damage(caster, target, effect_data)
	
	# Apply damage
	target.current_hp = max(0, target.current_hp - damage_amount)
	
	# Emit through EventBus
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("damage_dealt", caster, target, damage_amount)
	
	effect_processed.emit("damage", caster, target)
	return true

## Process heal effect
func _process_heal_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	if not target:
		return false
	
	var heal_amount = effect_data.get("amount", 0)
	var max_hp = target.get_max_hp()
	
	# Apply percentage healing if specified
	if effect_data.has("percentage"):
		heal_amount = int(max_hp * effect_data.percentage / 100.0)
	
	# Apply heal
	target.current_hp = min(max_hp, target.current_hp + heal_amount)
	
	# Emit through EventBus
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.emit_signal("unit_healed", target, heal_amount)
	
	effect_processed.emit("heal", caster, target)
	return true

## Process buff effect
func _process_buff_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	if not target:
		return false
	
	var buff_type = effect_data.get("type", "")
	var duration = effect_data.get("duration", 1)
	var value = effect_data.get("value", 0)
	
	# Use StatusEffectManager to apply buff
	var status_manager = SystemRegistry.get_instance().get_system("StatusEffectManager") if SystemRegistry.get_instance() else null
	if status_manager:
		status_manager.apply_buff(target, buff_type, duration, value)
	
	effect_processed.emit("buff", caster, target)
	return true

## Process debuff effect
func _process_debuff_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	if not target:
		return false
	
	var debuff_type = effect_data.get("type", "")
	var duration = effect_data.get("duration", 1)
	var value = effect_data.get("value", 0)
	
	# Use StatusEffectManager to apply debuff
	var status_manager = SystemRegistry.get_instance().get_system("StatusEffectManager") if SystemRegistry.get_instance() else null
	if status_manager:
		status_manager.apply_debuff(target, debuff_type, duration, value)
	
	effect_processed.emit("debuff", caster, target)
	return true

## Process shield effect
func _process_shield_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	if not target:
		return false
	
	var shield_amount = effect_data.get("amount", 0)
	var duration = effect_data.get("duration", 3)
	
	# Apply shield as a status effect
	var status_manager = SystemRegistry.get_instance().get_system("StatusEffectManager") if SystemRegistry.get_instance() else null
	if status_manager:
		status_manager.apply_shield(target, shield_amount, duration)
	
	effect_processed.emit("shield", caster, target)
	return true

## Process cleanse effect
func _process_cleanse_effect(effect_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	if not target:
		return false
	
	var cleanse_count = effect_data.get("count", 1)
	
	# Use StatusEffectManager to cleanse debuffs
	var status_manager = SystemRegistry.get_instance().get_system("StatusEffectManager") if SystemRegistry.get_instance() else null
	if status_manager:
		status_manager.cleanse_debuffs(target, cleanse_count)
	
	effect_processed.emit("cleanse", caster, target)
	return true

