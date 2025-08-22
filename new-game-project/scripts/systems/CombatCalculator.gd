# CombatCalculator.gd - Enhanced for Summoners War clone
class_name CombatCalculator
extends RefCounted

# Main calculation methods that match your existing battle system

static func execute_basic_attack(attacker, target) -> Dictionary:
	"""Execute basic attack with full Summoners War breakdown - matches your existing system"""
	var result = {
		"damage": 0,
		"is_critical": false,
		"hit_success": true,
		"breakdown": {
			"attacker_stats": {},
			"defender_stats": {},
			"calculation_steps": []
		}
	}
	
	# Null checks
	if not attacker or not target:
		print("CombatCalculator: Invalid parameters - attacker:", attacker, " target:", target)
		return result
	
	# Get detailed breakdowns (matching your existing system)
	var attack_breakdown = get_detailed_attack_breakdown(attacker)
	var defense_breakdown = get_detailed_defense_breakdown(target)
	
	result.breakdown.attacker_stats = attack_breakdown
	result.breakdown.defender_stats = defense_breakdown
	
	var final_attack = attack_breakdown.final_value
	var final_defense = defense_breakdown.final_value
	
	# Check for miss (physical attacks only)
	result.hit_success = check_hit_accuracy(attacker, target)
	if not result.hit_success:
		result.damage = 0
		return result
	
	# Check for critical hit
	var crit_result = check_critical_hit(attacker, target, "physical_damage")
	result.is_critical = crit_result.is_critical
	var crit_multiplier = crit_result.multiplier
	
	# Summoners War damage formula: ATK * (100 / (100 + DEF))
	var base_damage = final_attack * (100.0 / (100.0 + final_defense))
	var crit_damage = base_damage * crit_multiplier
	
	# Apply damage multipliers from status effects
	var damage_multiplier = get_damage_multiplier(target)
	var final_damage = max(5, int(crit_damage * damage_multiplier))
	
	# Add variance
	var damage_variance = randi_range(-5, 15)  # -5% to +15% variance
	final_damage += damage_variance
	final_damage = max(5, final_damage)
	
	result.damage = final_damage
	result.breakdown.calculation_steps = [
		"ATK(%d) × Defense Reduction(%.3f) = Base: %.1f" % [final_attack, 100.0/(100.0+final_defense), base_damage],
		"Critical Hit: %s (×%.1f)" % ["YES" if result.is_critical else "NO", crit_multiplier],
		"Damage Multiplier: ×%.2f" % damage_multiplier,
		"Variance: %+d" % damage_variance,
		"Final Damage: %d" % final_damage
	]
	
	return result

static func execute_ability_damage(caster, ability: Dictionary, target) -> Dictionary:
	"""Execute ability damage with full breakdown"""
	var result = {
		"damage": 0,
		"is_critical": false,
		"hit_success": true,
		"breakdown": {
			"attacker_stats": {},
			"defender_stats": {},
			"calculation_steps": []
		}
	}
	
	# Null checks
	if not caster or not ability or not target:
		print("CombatCalculator: Invalid parameters - caster:", caster, " ability:", ability, " target:", target)
		return result
	
	var damage_mult = ability.get("damage_multiplier", 1.5)
	var damage_type = ability.get("damage_type", "magical_damage")
	
	# Get detailed breakdowns
	var attack_breakdown = get_detailed_attack_breakdown(caster)
	var defense_breakdown = get_detailed_defense_breakdown(target)
	
	result.breakdown.attacker_stats = attack_breakdown
	result.breakdown.defender_stats = defense_breakdown
	
	var final_attack = attack_breakdown.final_value
	var final_defense = defense_breakdown.final_value
	
	# Check for miss (only physical abilities)
	if damage_type == "physical_damage":
		result.hit_success = check_hit_accuracy(caster, target)
		if not result.hit_success:
			result.damage = 0
			return result
	
	# Check for guaranteed crit from special effects
	var guaranteed_crit = ability.get("special_effects", []).has("guaranteed_crit")
	
	# Check for critical hit
	var crit_result = check_critical_hit(caster, target, damage_type, guaranteed_crit)
	result.is_critical = crit_result.is_critical
	var crit_multiplier = crit_result.multiplier
	
	# Calculate damage with ability multiplier
	var raw_damage = final_attack * damage_mult
	var defense_reduction = 100.0 / (100.0 + final_defense)
	var base_damage = raw_damage * defense_reduction
	var crit_damage = base_damage * crit_multiplier
	
	# Apply damage multipliers from status effects
	var damage_multiplier = get_damage_multiplier(target)
	var final_damage = max(10, int(crit_damage * damage_multiplier))
	
	result.damage = final_damage
	result.breakdown.calculation_steps = [
		"ATK(%d) × Ability Mult(%.1fx) = Raw: %.1f" % [final_attack, damage_mult, raw_damage],
		"Raw(%.1f) × Defense Reduction(%.3f) = Base: %.1f" % [raw_damage, defense_reduction, base_damage],
		"Critical Hit: %s (×%.1f)" % ["YES" if result.is_critical else "NO", crit_multiplier],
		"Damage Multiplier: ×%.2f" % damage_multiplier,
		"Final Damage: %d" % final_damage
	]
	
	return result

static func execute_healing(healer, ability: Dictionary, target) -> Dictionary:
	"""Execute healing with breakdown"""
	var result = {
		"heal_amount": 0,
		"actual_heal": 0,
		"is_overheal": false,
		"breakdown": {
			"calculation_steps": []
		}
	}
	
	# Null checks
	if not healer or not ability or not target:
		print("CombatCalculator: Invalid healing parameters - healer:", healer, " ability:", ability, " target:", target)
		return result
	
	var healing_mult = ability.get("healing_multiplier", 1.0)
	var attack = get_attack(healer)
	
	# Calculate healing amount
	var base_healing = int(attack * healing_mult)
	
	# Apply healing modifications (curse reduces healing by 50%)
	var modified_healing = modify_healing(target, base_healing)
	
	# Apply actual healing
	if target is God and target.current_hp > 0:
		var max_hp = target.get_max_hp()
		var current_hp = target.current_hp
		var available_heal = max_hp - current_hp
		
		if modified_healing > available_heal:
			result.is_overheal = true
			result.heal_amount = modified_healing
			result.actual_heal = available_heal
		else:
			result.heal_amount = modified_healing
			result.actual_heal = modified_healing
		
		result.breakdown.calculation_steps = [
			"Healer ATK: %d" % attack,
			"Healing Multiplier: %.1fx" % healing_mult,
			"Base Healing: %d" % base_healing,
			"Modified Healing: %d" % modified_healing,
			"Actual Heal: %d" % result.actual_heal
		]
	
	return result

static func get_detailed_attack_breakdown(unit) -> Dictionary:
	"""Get step-by-step attack calculation breakdown - matches your existing system"""
	var breakdown = {"steps": [], "final_value": 0}
	
	# Null check
	if not unit:
		print("CombatCalculator: Null unit passed to get_detailed_attack_breakdown")
		breakdown.steps.append("ERROR: Null unit")
		return breakdown
	
	if unit is God:
		var base_stat = unit.base_attack
		var level_bonus = unit.level * 8
		var tier_bonus = int(unit.tier) * 40
		var base_total = base_stat + level_bonus + tier_bonus
		
		breakdown.steps.append("Base ATK: %d" % base_stat)
		breakdown.steps.append("+ Level(%d) × 8 = +%d" % [unit.level, level_bonus])
		breakdown.steps.append("+ Tier(%s) × 40 = +%d" % [unit.tier, tier_bonus])
		breakdown.steps.append("= Base Total: %d" % base_total)
		
		# Get status effect modifiers
		var total_modifier = 0.0
		for effect in unit.status_effects:
			var modifier = effect.get_stat_modifier("attack")
			if modifier != 0.0:
				var percent = int(modifier * 100)
				var sign_text = "+" if modifier > 0 else ""
				breakdown.steps.append("+ %s: %s%d%% = ×%.2f" % [effect.name, sign_text, abs(percent), 1.0 + modifier])
				total_modifier += modifier
		
		var final_value = int(base_total * (1.0 + total_modifier))
		breakdown.steps.append("× Total Modifier(%.2f) = %d" % [1.0 + total_modifier, final_value])
		breakdown.final_value = final_value
	else:
		# Enemy - simple attack value - with null check
		if unit == null:
			breakdown.steps.append("ERROR: Null enemy unit")
			breakdown.final_value = 20
		else:
			var attack_val = unit.get("attack", 20)
			breakdown.steps.append("Enemy ATK: %d" % attack_val)
			breakdown.final_value = attack_val
	
	return breakdown

static func get_detailed_defense_breakdown(unit) -> Dictionary:
	"""Get step-by-step defense calculation breakdown - matches your existing system"""
	var breakdown = {"steps": [], "final_value": 0}
	
	# Null check
	if not unit:
		print("CombatCalculator: Null unit passed to get_detailed_defense_breakdown")
		breakdown.steps.append("ERROR: Null unit")
		return breakdown
	
	if unit is God:
		var base_stat = unit.base_defense
		var level_bonus = unit.level * 6
		var tier_bonus = int(unit.tier) * 30
		var base_total = base_stat + level_bonus + tier_bonus
		
		breakdown.steps.append("Base DEF: %d" % base_stat)
		breakdown.steps.append("+ Level(%d) × 6 = +%d" % [unit.level, level_bonus])
		breakdown.steps.append("+ Tier(%s) × 30 = +%d" % [unit.tier, tier_bonus])
		breakdown.steps.append("= Base Total: %d" % base_total)
		
		# Get status effect modifiers
		var total_modifier = 0.0
		for effect in unit.status_effects:
			var modifier = effect.get_stat_modifier("defense")
			if modifier != 0.0:
				var percent = int(modifier * 100)
				var sign_text = "+" if modifier > 0 else ""
				breakdown.steps.append("+ %s: %s%d%% = ×%.2f" % [effect.name, sign_text, abs(percent), 1.0 + modifier])
				total_modifier += modifier
		
		var final_value = int(base_total * (1.0 + total_modifier))
		breakdown.steps.append("× Total Modifier(%.2f) = %d" % [1.0 + total_modifier, final_value])
		breakdown.final_value = final_value
	else:
		# Enemy - simple defense value - with null check
		if unit == null:
			breakdown.steps.append("ERROR: Null enemy unit")
			breakdown.final_value = 10
		else:
			var defense_val = unit.get("defense", 10)
			breakdown.steps.append("Enemy DEF: %d" % defense_val)
			breakdown.final_value = defense_val
	
	return breakdown

static func check_hit_accuracy(attacker, target) -> bool:
	"""Check if attack hits based on accuracy vs evasion - matches your core system"""
	var attacker_accuracy = get_accuracy(attacker)
	var target_evasion = get_evasion(target)
	
	# Core system formula: accuracy - evasion
	var hit_chance = (attacker_accuracy - target_evasion) / 100.0
	hit_chance = clamp(hit_chance, 0.15, 1.0)  # Min 15% hit chance, max 100%
	
	var roll = randf()
	return roll <= hit_chance

static func check_critical_hit(attacker, target, _damage_type: String, guaranteed_crit: bool = false) -> Dictionary:
	"""Check for critical hit and calculate multiplier - matches your core system"""
	var base_crit_chance = get_critical_chance(attacker)
	var element_bonus = get_element_crit_bonus(attacker, target)
	
	var total_crit_chance = base_crit_chance + element_bonus
	total_crit_chance = clamp(total_crit_chance, 0.0, 1.0)  # Cap at 100%
	
	var roll = randf()
	var is_critical = guaranteed_crit or (roll <= total_crit_chance)
	
	var crit_damage_multiplier = 1.0
	if is_critical:
		crit_damage_multiplier = get_critical_damage_multiplier(attacker)
		# Cap at 3.0x as per core systems
		crit_damage_multiplier = clamp(crit_damage_multiplier, 1.0, 3.0)
	
	return {
		"is_critical": is_critical,
		"multiplier": crit_damage_multiplier
	}

# Helper functions to get stats from different unit types
static func get_attack(unit) -> int:
	if not unit:
		print("CombatCalculator: Null unit passed to get_attack")
		return 20
	if unit is God:
		return unit.get_current_attack()
	else:
		return unit.get("attack", 20)

static func get_defense(unit) -> int:
	if not unit:
		print("CombatCalculator: Null unit passed to get_defense")
		return 10
	if unit is God:
		return unit.get_current_defense()
	else:
		return unit.get("defense", 10)

static func get_accuracy(unit) -> int:
	if not unit:
		print("CombatCalculator: Null unit passed to get_accuracy")
		return 85
	if unit is God:
		var base_accuracy = 85
		var accuracy_modifier = 0.0
		for effect in unit.status_effects:
			accuracy_modifier += effect.get_stat_modifier("accuracy")
		return int(base_accuracy * (1.0 + accuracy_modifier))
	else:
		return unit.get("accuracy", 85)

static func get_evasion(unit) -> int:
	if not unit:
		print("CombatCalculator: Null unit passed to get_evasion")
		return 15
	if unit is God:
		var base_evasion = 15
		var evasion_modifier = 0.0
		for effect in unit.status_effects:
			evasion_modifier += effect.get_stat_modifier("evasion")
		return int(base_evasion * (1.0 + evasion_modifier))
	else:
		return unit.get("evasion", 15)

static func get_critical_chance(unit) -> float:
	if not unit:
		print("CombatCalculator: Null unit passed to get_critical_chance")
		return 0.05
	if unit is God:
		var base_crit = 0.15  # 15% base crit chance
		var crit_modifier = 0.0
		for effect in unit.status_effects:
			crit_modifier += effect.get_stat_modifier("critical_chance")
		return clamp(base_crit + crit_modifier, 0.0, 1.0)
	else:
		return unit.get("crit_chance", 0.05)

static func get_critical_damage_multiplier(unit) -> float:
	if not unit:
		print("CombatCalculator: Null unit passed to get_critical_damage_multiplier")
		return 1.3
	if unit is God:
		var base_crit_damage = 1.5
		var crit_damage_modifier = 0.0
		for effect in unit.status_effects:
			crit_damage_modifier += effect.get_stat_modifier("critical_damage")
		return base_crit_damage + crit_damage_modifier
	else:
		return unit.get("crit_damage", 1.3)

static func get_element_crit_bonus(_attacker, _target) -> float:
	# For now, return 0 - can implement elemental system later
	# Core system says +15% crit chance for elemental advantage
	return 0.0

static func get_damage_multiplier(target) -> float:
	"""Get damage multiplier from status effects like marked_for_death"""
	if not target:
		print("CombatCalculator: Null target passed to get_damage_multiplier")
		return 1.0
		
	var multiplier = 1.0
	
	if target is God:
		for effect in target.status_effects:
			var damage_taken_modifier = effect.get_stat_modifier("damage_taken")
			if damage_taken_modifier > 0:
				multiplier += damage_taken_modifier
	else:
		if target.has("damage_taken_multiplier"):
			multiplier += target.damage_taken_multiplier
	
	return multiplier

static func modify_healing(target, base_healing: int) -> int:
	"""Apply healing modifications based on status effects"""
	if not target:
		print("CombatCalculator: Null target passed to modify_healing")
		return base_healing
		
	var modified_healing = base_healing
	
	if target is God:
		# Curse reduces healing by 50%
		if target.has_status_effect("cursed"):
			modified_healing = int(modified_healing * 0.5)
	
	return modified_healing
