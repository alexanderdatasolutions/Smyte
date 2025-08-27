# CombatCalculator.gd - Authentic Summoners War Combat System
class_name CombatCalculator
extends RefCounted

# AUTHENTIC SUMMONERS WAR DAMAGE FORMULAS:
# 
# Skill Damage: Damage = TotalAttack * Multiplier * (100% + SkillUp + CritDamage)
# Defense Reduction: DamageReductionFactor = 1000/(1140 + 3.5 * Defense)
# Critical Balance: CR should equal CD for optimal damage (CR = CD)
# Attack Bar: Each tick increases ATB by 7% of Attack Speed
# 
# Source: Summoners War Wiki - https://summonerswar.fandom.com/wiki/Equations

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
	
	# Authentic SW Damage Formula: Damage = TotalAttack * Multiplier * (100% + SkillUp + CritDamage)
	# For basic attacks, multiplier is 1.0, skill up is 0
	var skill_multiplier = 1.0
	var skill_up_bonus = 0.0  # Basic attacks don't have skill ups
	var crit_damage_bonus = 0.0
	
	if result.is_critical:
		# Get crit damage as percentage (e.g., 150% = 150)
		if attacker is God:
			crit_damage_bonus = attacker.get_current_crit_damage()
		else:
			crit_damage_bonus = attacker.get("crit_damage", 50)
	
	# SW Formula: ATK * Multiplier * (100% + SkillUp + CritDamage)
	var raw_damage = final_attack * skill_multiplier * (1.0 + skill_up_bonus/100.0 + crit_damage_bonus/100.0)
	
	# Authentic SW Defense Reduction: DamageReductionFactor = 1000/(1140 + 3.5 * Defense)
	var defense_reduction_factor = 1000.0 / (1140.0 + 3.5 * final_defense)
	var base_damage = raw_damage * defense_reduction_factor
	
	# Apply damage multipliers from status effects
	var damage_multiplier = get_damage_multiplier(target)
	var final_damage = max(5, int(base_damage * damage_multiplier))
	
	# Add variance (SW has some RNG variance)
	var damage_variance = randi_range(-5, 15)  # -5% to +15% variance
	final_damage += damage_variance
	final_damage = max(5, final_damage)
	
	result.damage = final_damage
	result.breakdown.calculation_steps = [
		"ATK(%d) × Multiplier(%.1f) × (100%% + CritDmg(%.1f%%)) = Raw: %.1f" % [final_attack, skill_multiplier, crit_damage_bonus, raw_damage],
		"Raw(%.1f) × Defense Reduction(%.3f) = Base: %.1f" % [raw_damage, defense_reduction_factor, base_damage],
		"Critical Hit: %s" % ["YES" if result.is_critical else "NO"],
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
	
	# Authentic SW Damage Formula: Damage = TotalAttack * Multiplier * (100% + SkillUp + CritDamage)
	var skill_multiplier = damage_mult
	var skill_up_bonus = ability.get("skill_up_damage_bonus", 0.0)  # Skill damage bonus from upgrades
	var crit_damage_bonus = 0.0
	
	if result.is_critical:
		# Get crit damage as percentage (e.g., 150% = 150)
		if caster is God:
			crit_damage_bonus = caster.get_current_crit_damage()
		else:
			crit_damage_bonus = caster.get("crit_damage", 50)
	
	# SW Formula: ATK * Multiplier * (100% + SkillUp + CritDamage)
	var raw_damage = final_attack * skill_multiplier * (1.0 + skill_up_bonus/100.0 + crit_damage_bonus/100.0)
	
	# Authentic SW Defense Reduction: DamageReductionFactor = 1000/(1140 + 3.5 * Defense)
	var defense_reduction_factor = 1000.0 / (1140.0 + 3.5 * final_defense)
	var base_damage = raw_damage * defense_reduction_factor
	
	# Apply damage multipliers from status effects
	var damage_multiplier = get_damage_multiplier(target)
	var final_damage = max(10, int(base_damage * damage_multiplier))
	
	result.damage = final_damage
	result.breakdown.calculation_steps = [
		"ATK(%d) × Multiplier(%.1fx) × (100%% + SkillUp(%.1f%%) + CritDmg(%.1f%%)) = Raw: %.1f" % [final_attack, skill_multiplier, skill_up_bonus, crit_damage_bonus, raw_damage],
		"Raw(%.1f) × Defense Reduction(%.3f) = Base: %.1f" % [raw_damage, defense_reduction_factor, base_damage],
		"Critical Hit: %s" % ["YES" if result.is_critical else "NO"],
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

static func calculate_weighted_stats_constant(unit) -> Dictionary:
	"""Calculate SW Weighted Stats Constant: ATK + DEF + HP/15 = 1317 + 165*(natural_grade)"""
	var attack = get_attack(unit)
	var defense = get_defense(unit) 
	var hp = get_max_hp(unit)
	
	var constitution = hp / 15.0  # HP/15 is called Constitution (CON)
	var weighted_sum = attack + defense + constitution
	
	# Determine natural grade based on weighted sum
	# SW Formula: 1317 + 165 * natural_grade
	# Solving for natural_grade: (weighted_sum - 1317) / 165
	var calculated_grade = (weighted_sum - 1317.0) / 165.0
	calculated_grade = max(1.0, calculated_grade)  # Minimum 1-star
	
	var tier_multiplier = 1.0
	if unit is God:
		match unit.tier:
			"common":
				tier_multiplier = 2.0  # 2 star equivalent
			"rare":
				tier_multiplier = 3.0  # 3 star equivalent  
			"epic":
				tier_multiplier = 4.0  # 4 star equivalent
			"legendary":
				tier_multiplier = 5.0  # 5 star equivalent
	
	return {
		"attack": attack,
		"defense": defense,
		"hp": hp,
		"constitution": constitution,
		"weighted_sum": weighted_sum,
		"calculated_grade": calculated_grade,
		"tier_multiplier": tier_multiplier,
		"is_balanced": abs(calculated_grade - tier_multiplier) < 0.5
	}

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
		var level_bonus = int(unit.level * 1.5)  # Updated scaling
		var tier_bonus = int(unit.tier) * 10     # Updated scaling
		var base_total = base_stat + level_bonus + tier_bonus
		
		breakdown.steps.append("Base ATK: %d" % base_stat)
		breakdown.steps.append("+ Level(%d) × 1.5 = +%d" % [unit.level, level_bonus])
		breakdown.steps.append("+ Tier(%s) × 10 = +%d" % [unit.tier, tier_bonus])
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
		var level_bonus = unit.level * 1          # Updated scaling
		var tier_bonus = int(unit.tier) * 8       # Updated scaling
		var base_total = base_stat + level_bonus + tier_bonus
		
		breakdown.steps.append("Base DEF: %d" % base_stat)
		breakdown.steps.append("+ Level(%d) × 1 = +%d" % [unit.level, level_bonus])
		breakdown.steps.append("+ Tier(%s) × 8 = +%d" % [unit.tier, tier_bonus])
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
	"""Check for critical hit - Authentic SW system handles crit damage in main formula"""
	var base_crit_chance = get_critical_chance(attacker)
	var element_bonus = get_element_crit_bonus(attacker, target)
	
	var total_crit_chance = base_crit_chance + element_bonus
	total_crit_chance = clamp(total_crit_chance, 0.0, 1.0)  # Cap at 100%
	
	var roll = randf()
	var is_critical = guaranteed_crit or (roll <= total_crit_chance)
	
	return {
		"is_critical": is_critical
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

static func get_max_hp(unit) -> int:
	"""Get maximum HP for weighted stats calculation"""
	if not unit:
		print("CombatCalculator: Null unit passed to get_max_hp")
		return 100
	if unit is God:
		return unit.get_max_hp()
	else:
		return unit.get("max_hp", 100)

static func get_accuracy(unit) -> int:
	if not unit:
		print("CombatCalculator: Null unit passed to get_accuracy")
		return 85
	if unit is God:
		return unit.get_current_accuracy()
	else:
		return unit.get("accuracy", 0)  # Enemies start with 0 base accuracy

static func get_evasion(unit) -> int:
	if not unit:
		print("CombatCalculator: Null unit passed to get_evasion")
		return 15
	if unit is God:
		return unit.get_current_resistance()  # In SW, resistance acts as evasion for debuffs
	else:
		return unit.get("evasion", 15)

static func get_critical_chance(unit) -> float:
	if not unit:
		print("CombatCalculator: Null unit passed to get_critical_chance")
		return 0.05
	if unit is God:
		return unit.get_current_crit_rate() / 100.0  # Convert percentage to decimal
	else:
		return unit.get("crit_rate", 15) / 100.0  # Convert from percentage to decimal

static func get_critical_damage_multiplier(unit) -> float:
	"""Legacy function - kept for compatibility"""
	if not unit:
		print("CombatCalculator: Null unit passed to get_critical_damage_multiplier")
		return 1.3
	if unit is God:
		return 1.0 + (unit.get_current_crit_damage() / 100.0)  # Convert percentage bonus to multiplier
	else:
		return 1.0 + (unit.get("crit_damage", 50) / 100.0)  # Convert from percentage bonus

static func get_critical_damage_percentage(unit) -> float:
	"""Get critical damage as percentage for authentic SW formula (e.g., 150% = 150.0)"""
	if not unit:
		print("CombatCalculator: Null unit passed to get_critical_damage_percentage")
		return 50.0
	if unit is God:
		return unit.get_current_crit_damage()  # Already in percentage format
	else:
		return unit.get("crit_damage", 50)  # Already in percentage format

static func get_element_crit_bonus(_attacker, _target) -> float:
	# TODO: Implement elemental advantage system
	# SW gives +15% crit chance for elemental advantage
	# Elements: fire > earth > lightning > water > fire
	# Light/Dark are neutral but strong against each other
	return 0.0

static func analyze_critical_balance(unit) -> Dictionary:
	"""Analyze CR vs CD balance for optimal damage (SW Wiki: CR should equal CD)"""
	var crit_rate = get_critical_chance(unit) * 100  # Convert to percentage
	var crit_damage = get_critical_damage_percentage(unit)
	
	var balance_ratio = crit_rate / max(crit_damage, 1.0)
	var recommendation = ""
	
	if balance_ratio < 0.8:
		recommendation = "Increase Critical Rate - too low compared to Critical Damage"
	elif balance_ratio > 1.2:
		recommendation = "Increase Critical Damage - too low compared to Critical Rate"
	else:
		recommendation = "Good balance between Critical Rate and Critical Damage"
	
	return {
		"crit_rate": crit_rate,
		"crit_damage": crit_damage,
		"balance_ratio": balance_ratio,
		"recommendation": recommendation,
		"optimal_cr_cd_equal": abs(crit_rate - crit_damage) < 10  # Within 10% is considered balanced
	}

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
