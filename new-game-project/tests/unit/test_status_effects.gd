# test_status_effects.gd - Unit tests for StatusEffectManager and StatusEffect
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# MOCK CLASSES
# ==============================================================================

class MockBattleUnit:
	var id: String
	var name: String
	var hp: int
	var max_health: int
	var base_attack: int
	var is_dead: bool = false
	var is_stunned: bool = false
	var status_effects: Array = []

	func _init(unit_id: String = "", unit_name: String = ""):
		id = unit_id if unit_id != "" else "unit_" + str(randi() % 10000)
		name = unit_name if unit_name != "" else "Mock Unit"
		hp = 1000
		max_health = 1000
		base_attack = 200

	func get_display_name() -> String:
		return name

	func get_status_effects() -> Array:
		return status_effects

	func add_status_effect(effect):
		status_effects.append(effect)

	func remove_status_effect(effect_id: String):
		for i in range(status_effects.size() - 1, -1, -1):
			if status_effects[i].id == effect_id:
				status_effects.remove_at(i)
				break

	func take_damage(amount: int):
		hp -= amount
		if hp <= 0:
			hp = 0
			is_dead = true

	func heal(amount: int):
		hp = min(hp + amount, max_health)

	func set_stunned(stunned: bool):
		is_stunned = stunned

class MockEffect:
	var id: String
	var effect_type: String
	var duration: int
	var damage_value: int
	var heal_value: int
	var trigger_timing: String
	var expired: bool = false

	func _init(effect_id: String = "", type: String = ""):
		id = effect_id if effect_id != "" else "effect_" + str(randi() % 10000)
		effect_type = type
		duration = 3
		damage_value = 100
		heal_value = 50
		trigger_timing = "turn_start"

	func should_trigger_on(timing: String) -> bool:
		return trigger_timing == timing

	func get_damage_amount() -> int:
		return damage_value

	func get_heal_amount() -> int:
		return heal_value

	func reduce_duration():
		duration -= 1
		if duration <= 0:
			expired = true

	func is_expired() -> bool:
		return expired

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_status_effect_manager() -> StatusEffectManager:
	return StatusEffectManager.new()

func create_mock_unit(unit_name: String = "TestUnit") -> MockBattleUnit:
	return MockBattleUnit.new("", unit_name)

func create_mock_effect(effect_id: String = "", effect_type: String = "poison") -> MockEffect:
	return MockEffect.new(effect_id, effect_type)

func create_mock_caster() -> MockBattleUnit:
	var caster = MockBattleUnit.new("caster_001", "Caster")
	caster.base_attack = 200
	caster.max_health = 1000
	return caster

# ==============================================================================
# TEST: Signal Existence
# ==============================================================================

func test_status_effect_applied_signal_exists():
	var manager = create_status_effect_manager()
	runner.assert_true(manager.has_signal("status_effect_applied"), "should have status_effect_applied signal")

func test_status_effect_removed_signal_exists():
	var manager = create_status_effect_manager()
	runner.assert_true(manager.has_signal("status_effect_removed"), "should have status_effect_removed signal")

func test_status_effect_triggered_signal_exists():
	var manager = create_status_effect_manager()
	runner.assert_true(manager.has_signal("status_effect_triggered"), "should have status_effect_triggered signal")

# ==============================================================================
# TEST: Process Turn Start Effects
# ==============================================================================

func test_process_turn_start_effects_returns_array():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()

	var messages = manager.process_turn_start_effects(unit)
	runner.assert_true(messages is Array, "should return an array")

func test_process_turn_start_effects_empty_for_no_effects():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()

	var messages = manager.process_turn_start_effects(unit)
	runner.assert_equal(messages.size(), 0, "should return empty for unit with no effects")

func test_process_turn_start_effects_returns_messages_for_poison():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	unit.add_status_effect(effect)

	var messages = manager.process_turn_start_effects(unit)
	runner.assert_true(messages.size() > 0, "should return message for poison effect")

func test_process_turn_start_effects_applies_poison_damage():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 1000
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	effect.damage_value = 100
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 900, "should apply poison damage")

func test_process_turn_start_effects_handles_unit_without_method():
	var manager = create_status_effect_manager()
	var simple_obj = {}  # Object without get_status_effects method

	var messages = manager.process_turn_start_effects(simple_obj)
	runner.assert_equal(messages.size(), 0, "should return empty for object without method")

# ==============================================================================
# TEST: Process Turn End Effects
# ==============================================================================

func test_process_turn_end_effects_returns_array():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()

	var messages = manager.process_turn_end_effects(unit)
	runner.assert_true(messages is Array, "should return an array")

func test_process_turn_end_effects_triggers_end_effects():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("burn_001", "burn")
	effect.trigger_timing = "turn_end"
	effect.damage_value = 150
	unit.add_status_effect(effect)

	var messages = manager.process_turn_end_effects(unit)
	runner.assert_true(messages.size() > 0, "should trigger turn end effects")

func test_process_turn_end_effects_applies_burn_damage():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 1000
	var effect = create_mock_effect("burn_001", "burn")
	effect.trigger_timing = "turn_end"
	effect.damage_value = 150
	unit.add_status_effect(effect)

	manager.process_turn_end_effects(unit)
	runner.assert_equal(unit.hp, 850, "should apply burn damage")

# ==============================================================================
# TEST: Effect Processing - Poison
# ==============================================================================

func test_process_poison_deals_damage():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 1000
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	effect.damage_value = 100
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_true(unit.hp < 1000, "poison should deal damage")

func test_process_poison_message_format():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit("Zeus")
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	effect.damage_value = 100
	unit.add_status_effect(effect)

	var messages = manager.process_turn_start_effects(unit)
	runner.assert_true(messages.size() > 0 and "poison" in messages[0].to_lower(), "should include poison in message")

# ==============================================================================
# TEST: Effect Processing - Burn
# ==============================================================================

func test_process_burn_deals_damage():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 1000
	var effect = create_mock_effect("burn_001", "burn")
	effect.trigger_timing = "turn_start"
	effect.damage_value = 150
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 850, "burn should deal damage")

# ==============================================================================
# TEST: Effect Processing - Heal Over Time
# ==============================================================================

func test_process_heal_over_time_heals_unit():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 500
	unit.max_health = 1000
	var effect = create_mock_effect("regen_001", "heal_over_time")
	effect.trigger_timing = "turn_start"
	effect.heal_value = 150
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 650, "heal over time should heal unit")

func test_process_heal_over_time_respects_max_health():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 950
	unit.max_health = 1000
	var effect = create_mock_effect("regen_001", "heal_over_time")
	effect.trigger_timing = "turn_start"
	effect.heal_value = 150
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 1000, "heal should not exceed max health")

# ==============================================================================
# TEST: Effect Processing - Stun
# ==============================================================================

func test_process_stun_sets_stunned():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("stun_001", "stun")
	effect.trigger_timing = "turn_start"
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_true(unit.is_stunned, "stun effect should set unit stunned")

# ==============================================================================
# TEST: Effect Duration
# ==============================================================================

func test_effect_duration_reduces():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	effect.duration = 3
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(effect.duration, 2, "effect duration should reduce by 1")

func test_expired_effect_removed():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	effect.duration = 1
	unit.add_status_effect(effect)

	runner.assert_equal(unit.status_effects.size(), 1, "should have 1 effect before processing")
	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.status_effects.size(), 0, "expired effect should be removed")

# ==============================================================================
# TEST: Apply Status Effect
# ==============================================================================

func test_apply_status_effect_adds_to_unit():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("stun_001", "stun")

	runner.assert_equal(unit.status_effects.size(), 0, "should start with no effects")
	manager.apply_status_effect(unit, effect)
	runner.assert_equal(unit.status_effects.size(), 1, "should have 1 effect after apply")

func test_apply_status_effect_returns_true_on_success():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect()

	var result = manager.apply_status_effect(unit, effect)
	runner.assert_true(result, "should return true on success")

func test_apply_status_effect_returns_false_for_invalid_target():
	var manager = create_status_effect_manager()
	var invalid_target = {}  # Object without add_status_effect method
	var effect = create_mock_effect()

	var result = manager.apply_status_effect(invalid_target, effect)
	runner.assert_false(result, "should return false for invalid target")

# ==============================================================================
# TEST: Remove Status Effect
# ==============================================================================

func test_remove_status_effect_removes_from_unit():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("stun_001", "stun")
	unit.add_status_effect(effect)

	runner.assert_equal(unit.status_effects.size(), 1, "should have effect")
	manager.remove_status_effect(unit, "stun_001")
	runner.assert_equal(unit.status_effects.size(), 0, "effect should be removed")

func test_remove_status_effect_returns_true_on_success():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	var effect = create_mock_effect("burn_001", "burn")
	unit.add_status_effect(effect)

	var result = manager.remove_status_effect(unit, "burn_001")
	runner.assert_true(result, "should return true on success")

func test_remove_status_effect_returns_false_for_invalid_target():
	var manager = create_status_effect_manager()
	var invalid_target = {}

	var result = manager.remove_status_effect(invalid_target, "some_effect")
	runner.assert_false(result, "should return false for invalid target")

# ==============================================================================
# TEST: StatusEffect Data Class - Enums
# ==============================================================================

func test_effect_type_buff_exists():
	runner.assert_equal(StatusEffect.EffectType.BUFF, 0, "BUFF should be 0")

func test_effect_type_debuff_exists():
	runner.assert_equal(StatusEffect.EffectType.DEBUFF, 1, "DEBUFF should be 1")

func test_effect_type_dot_exists():
	runner.assert_equal(StatusEffect.EffectType.DOT, 2, "DOT should be 2")

func test_effect_type_hot_exists():
	runner.assert_equal(StatusEffect.EffectType.HOT, 3, "HOT should be 3")

# ==============================================================================
# TEST: StatusEffect Data Class - Properties
# ==============================================================================

func test_status_effect_init():
	var effect = StatusEffect.new("test_effect", "Test Effect")
	runner.assert_equal(effect.id, "test_effect", "id should match")
	runner.assert_equal(effect.name, "Test Effect", "name should match")

func test_status_effect_default_duration():
	var effect = StatusEffect.new()
	runner.assert_equal(effect.duration, 3, "default duration should be 3")

func test_status_effect_default_stacks():
	var effect = StatusEffect.new()
	runner.assert_equal(effect.stacks, 1, "default stacks should be 1")

func test_status_effect_can_stack_default():
	var effect = StatusEffect.new()
	runner.assert_false(effect.can_stack, "can_stack should default to false")

func test_status_effect_max_stacks_default():
	var effect = StatusEffect.new()
	runner.assert_equal(effect.max_stacks, 5, "max_stacks should default to 5")

func test_status_effect_is_expired():
	var effect = StatusEffect.new()
	effect.duration = 0
	runner.assert_true(effect.is_expired(), "should be expired when duration is 0")

func test_status_effect_not_expired():
	var effect = StatusEffect.new()
	effect.duration = 1
	runner.assert_false(effect.is_expired(), "should not be expired when duration > 0")

func test_get_stat_modifier_returns_value():
	var effect = StatusEffect.new()
	effect.stat_modifier["attack"] = 0.5
	effect.stacks = 1
	runner.assert_equal(effect.get_stat_modifier("attack"), 0.5, "should return modifier value")

func test_get_stat_modifier_scales_with_stacks():
	var effect = StatusEffect.new()
	effect.stat_modifier["attack"] = 0.5
	effect.stacks = 2
	runner.assert_equal(effect.get_stat_modifier("attack"), 1.0, "should scale with stacks")

func test_get_stat_modifier_missing_returns_zero():
	var effect = StatusEffect.new()
	runner.assert_equal(effect.get_stat_modifier("nonexistent"), 0.0, "should return 0 for missing stat")

# ==============================================================================
# TEST: StatusEffect Factory - Stun
# ==============================================================================

func test_create_stun_effect():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_stun(caster, 1)

	runner.assert_equal(effect.id, "stun", "stun id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.DEBUFF, "should be DEBUFF")
	runner.assert_true(effect.prevents_action, "should prevent action")

func test_create_stun_default_duration():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_stun(caster)
	runner.assert_equal(effect.duration, 1, "default stun duration should be 1")

func test_create_stun_custom_duration():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_stun(caster, 2)
	runner.assert_equal(effect.duration, 2, "custom stun duration should be applied")

# ==============================================================================
# TEST: StatusEffect Factory - Burn
# ==============================================================================

func test_create_burn_effect():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_burn(caster, 3)

	runner.assert_equal(effect.id, "burn", "burn id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.DOT, "should be DOT")
	runner.assert_equal(effect.damage_per_turn, 0.15, "should deal 15% HP per turn")

func test_create_burn_default_duration():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_burn(caster)
	runner.assert_equal(effect.duration, 3, "default burn duration should be 3")

func test_create_burn_cannot_stack():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_burn(caster)
	runner.assert_false(effect.can_stack, "burn should not stack")

# ==============================================================================
# TEST: StatusEffect Factory - Continuous Damage
# ==============================================================================

func test_create_continuous_damage():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_continuous_damage(caster)

	runner.assert_equal(effect.id, "continuous_damage", "id should match")
	runner.assert_equal(effect.damage_per_turn, 0.15, "should deal 15% HP per turn")
	runner.assert_true(effect.can_stack, "continuous damage should stack")

# ==============================================================================
# TEST: StatusEffect Factory - Regeneration
# ==============================================================================

func test_create_regeneration_effect():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_regeneration(caster)

	runner.assert_equal(effect.id, "regeneration", "id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.HOT, "should be HOT")
	runner.assert_equal(effect.heal_per_turn, 0.15, "should heal 15% HP per turn")

# ==============================================================================
# TEST: StatusEffect Factory - Stat Buffs
# ==============================================================================

func test_create_attack_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_attack_boost(caster)

	runner.assert_equal(effect.id, "attack_boost", "id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.BUFF, "should be BUFF")
	runner.assert_equal(effect.stat_modifier["attack"], 0.5, "should boost attack by 50%")

func test_create_defense_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_defense_boost(caster)

	runner.assert_equal(effect.id, "defense_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["defense"], 0.5, "should boost defense by 50%")

func test_create_speed_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_speed_boost(caster)

	runner.assert_equal(effect.id, "speed_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["speed"], 0.3, "should boost speed by 30%")
	runner.assert_equal(effect.duration, 2, "default duration should be 2")

# ==============================================================================
# TEST: StatusEffect Factory - Stat Debuffs
# ==============================================================================

func test_create_slow():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_slow(caster)

	runner.assert_equal(effect.id, "slow", "id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.DEBUFF, "should be DEBUFF")
	runner.assert_equal(effect.stat_modifier["speed"], -0.5, "should reduce speed by 50%")

func test_create_attack_reduction():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_attack_reduction(caster)

	runner.assert_equal(effect.id, "attack_reduction", "id should match")
	runner.assert_equal(effect.stat_modifier["attack"], -0.3, "should reduce attack by 30%")

func test_create_defense_reduction():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_defense_reduction(caster)

	runner.assert_equal(effect.id, "defense_reduction", "id should match")
	runner.assert_equal(effect.stat_modifier["defense"], -0.3, "should reduce defense by 30%")

func test_create_blind():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_blind(caster)

	runner.assert_equal(effect.id, "blind", "id should match")
	runner.assert_equal(effect.stat_modifier["accuracy"], -0.5, "should reduce accuracy by 50%")

# ==============================================================================
# TEST: StatusEffect Factory - Shield
# ==============================================================================

func test_create_shield():
	var caster = create_mock_caster()
	caster.base_attack = 200
	var effect = StatusEffect.create_shield(caster)

	runner.assert_equal(effect.id, "shield", "id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.BUFF, "should be BUFF")
	runner.assert_equal(effect.shield_value, 100, "shield should be 50% of caster attack")

# ==============================================================================
# TEST: StatusEffect Factory - Control Effects
# ==============================================================================

func test_create_fear():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_fear(caster)

	runner.assert_equal(effect.id, "fear", "id should match")
	runner.assert_true(effect.prevents_action, "should prevent action")

func test_create_freeze():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_freeze(caster)

	runner.assert_equal(effect.id, "freeze", "id should match")
	runner.assert_true(effect.prevents_action, "should prevent action")
	runner.assert_true(effect.frozen, "should set frozen flag")

func test_create_sleep():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_sleep(caster)

	runner.assert_equal(effect.id, "sleep", "id should match")
	runner.assert_true(effect.prevents_action, "should prevent action")
	runner.assert_true(effect.sleeping, "should set sleeping flag")

func test_create_silence():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_silence(caster)

	runner.assert_equal(effect.id, "silence", "id should match")
	runner.assert_true(effect.silenced, "should set silenced flag")

func test_create_provoke():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_provoke(caster)

	runner.assert_equal(effect.id, "provoke", "id should match")
	runner.assert_true(effect.provoked, "should set provoked flag")

func test_create_charm():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_charm(caster)

	runner.assert_equal(effect.id, "charm", "id should match")
	runner.assert_true(effect.charmed, "should set charmed flag")

func test_create_immobilize():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_immobilize(caster)

	runner.assert_equal(effect.id, "immobilize", "id should match")
	runner.assert_true(effect.prevents_action, "should prevent action")

# ==============================================================================
# TEST: StatusEffect Factory - Immunity Effects
# ==============================================================================

func test_create_debuff_immunity():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_debuff_immunity(caster)

	runner.assert_equal(effect.id, "debuff_immunity", "id should match")
	runner.assert_true(effect.immune_to_debuffs, "should grant debuff immunity")

func test_create_damage_immunity():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_damage_immunity(caster)

	runner.assert_equal(effect.id, "damage_immunity", "id should match")
	runner.assert_true(effect.damage_immunity, "should grant damage immunity")

func test_create_untargetable():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_untargetable(caster)

	runner.assert_equal(effect.id, "untargetable", "id should match")
	runner.assert_true(effect.untargetable, "should set untargetable flag")

# ==============================================================================
# TEST: StatusEffect Factory - DOT Effects
# ==============================================================================

func test_create_bleed():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_bleed(caster)

	runner.assert_equal(effect.id, "bleed", "id should match")
	runner.assert_equal(effect.effect_type, StatusEffect.EffectType.DOT, "should be DOT")
	runner.assert_equal(effect.damage_per_turn, 0.10, "should deal 10% HP per turn")

func test_create_curse():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_curse(caster)

	runner.assert_equal(effect.id, "curse", "id should match")
	runner.assert_equal(effect.stat_modifier["healing_received"], -0.5, "should reduce healing by 50%")

func test_create_heal_block():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_heal_block(caster)

	runner.assert_equal(effect.id, "heal_block", "id should match")
	runner.assert_equal(effect.stat_modifier["healing_received"], -1.0, "should block all healing")

# ==============================================================================
# TEST: StatusEffect Factory - Special Effects
# ==============================================================================

func test_create_counter_attack():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_counter_attack(caster)

	runner.assert_equal(effect.id, "counter_attack", "id should match")
	runner.assert_true(effect.counter_attack, "should enable counter attack")

func test_create_reflect_damage():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_reflect_damage(caster)

	runner.assert_equal(effect.id, "reflect_damage", "id should match")
	runner.assert_equal(effect.reflect_damage, 0.30, "should reflect 30% damage")

func test_create_accuracy_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_accuracy_boost(caster)

	runner.assert_equal(effect.id, "accuracy_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["accuracy"], 0.5, "should boost accuracy by 50%")

func test_create_evasion_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_evasion_boost(caster)

	runner.assert_equal(effect.id, "evasion_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["evasion"], 0.3, "should boost evasion by 30%")

func test_create_crit_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_crit_boost(caster)

	runner.assert_equal(effect.id, "crit_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["critical_chance"], 0.3, "should boost crit chance by 30%")
	runner.assert_equal(effect.stat_modifier["critical_damage"], 0.2, "should boost crit damage by 20%")

func test_create_critical_damage_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_critical_damage_boost(caster)

	runner.assert_equal(effect.id, "crit_damage_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["critical_damage"], 0.5, "should boost crit damage by 50%")

func test_create_wisdom_boost():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_wisdom_boost(caster)

	runner.assert_equal(effect.id, "wisdom_boost", "id should match")
	runner.assert_equal(effect.stat_modifier["magic_power"], 0.20, "should boost magic power by 20%")
	runner.assert_equal(effect.stat_modifier["cooldown_reduction"], 0.10, "should reduce cooldown by 10%")

func test_create_analyze_weakness():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_analyze_weakness(caster)

	runner.assert_equal(effect.id, "analyze_weakness", "id should match")
	runner.assert_equal(effect.stat_modifier["damage_taken"], 0.25, "should increase damage taken by 25%")

func test_create_marked_for_death():
	var caster = create_mock_caster()
	var effect = StatusEffect.create_marked_for_death(caster)

	runner.assert_equal(effect.id, "marked_for_death", "id should match")
	runner.assert_equal(effect.stat_modifier["damage_taken"], 0.25, "should increase damage taken by 25%")

# ==============================================================================
# TEST: Multiple Effects
# ==============================================================================

func test_multiple_effects_on_unit():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()

	var poison = create_mock_effect("poison_001", "poison")
	poison.trigger_timing = "turn_start"
	poison.damage_value = 100

	var burn = create_mock_effect("burn_001", "burn")
	burn.trigger_timing = "turn_start"
	burn.damage_value = 150

	unit.add_status_effect(poison)
	unit.add_status_effect(burn)

	runner.assert_equal(unit.status_effects.size(), 2, "should have 2 effects")

func test_multiple_dots_stack_damage():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 1000

	var poison = create_mock_effect("poison_001", "poison")
	poison.trigger_timing = "turn_start"
	poison.damage_value = 100

	var burn = create_mock_effect("burn_001", "burn")
	burn.trigger_timing = "turn_start"
	burn.damage_value = 150

	unit.add_status_effect(poison)
	unit.add_status_effect(burn)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 750, "both DOTs should deal damage: 1000 - 100 - 150 = 750")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_null_unit_turn_start():
	var manager = create_status_effect_manager()
	# Should not crash with null
	var messages = manager.process_turn_start_effects(null)
	runner.assert_equal(messages.size(), 0, "should return empty for null unit")

func test_effect_not_triggered_on_wrong_timing():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 1000
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_end"
	effect.damage_value = 100
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 1000, "effect should not trigger on wrong timing")

func test_unit_death_from_dot():
	var manager = create_status_effect_manager()
	var unit = create_mock_unit()
	unit.hp = 50
	var effect = create_mock_effect("poison_001", "poison")
	effect.trigger_timing = "turn_start"
	effect.damage_value = 100
	unit.add_status_effect(effect)

	manager.process_turn_start_effects(unit)
	runner.assert_equal(unit.hp, 0, "HP should not go below 0")
	runner.assert_true(unit.is_dead, "unit should be dead")
