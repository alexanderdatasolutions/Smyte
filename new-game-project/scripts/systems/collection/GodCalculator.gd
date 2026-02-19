# scripts/systems/collection/GodCalculator.gd
# SINGLE SOURCE OF TRUTH for all god power calculations
# All power displays throughout the game should call these methods
extends RefCounted
class_name GodCalculator

# ==============================================================================
# GOD STAT & POWER CALCULATOR - Unified calculations for the entire game
# ==============================================================================

# Cached configs
static var _config: Dictionary = {}
static var _config_loaded: bool = false
static var _equipment_config: Dictionary = {}
static var _equipment_config_loaded: bool = false

static func _load_config() -> void:
	if _config_loaded:
		return
	var file := FileAccess.open("res://data/progression_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed as Dictionary
	_config_loaded = true

static func _load_equipment_config() -> void:
	if _equipment_config_loaded:
		return
	var file := FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_equipment_config = parsed as Dictionary
	_equipment_config_loaded = true

static func _get_level_scale(stat_name: String) -> float:
	_load_config()
	var scaling: Dictionary = _config.get("stat_scaling", {}).get("level_scaling_per_level", {})
	return scaling.get(stat_name, 0.1)

# ==============================================================================
# INDIVIDUAL STAT CALCULATIONS
# ==============================================================================

static func get_current_hp(god: God) -> int:
	var base: int = god.base_hp
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("hp"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "hp")
	var modifier: float = _get_stat_modifier(god, "hp")
	var ascension_bonus: float = get_ascension_bonus(god, "hp")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_max_hp(god: God) -> int:
	return get_current_hp(god)

static func get_current_attack(god: God) -> int:
	var base: int = god.base_attack
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("attack"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "attack")
	var modifier: float = _get_stat_modifier(god, "attack")
	var ascension_bonus: float = get_ascension_bonus(god, "attack")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_current_defense(god: God) -> int:
	var base: int = god.base_defense
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("defense"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "defense")
	var modifier: float = _get_stat_modifier(god, "defense")
	var ascension_bonus: float = get_ascension_bonus(god, "defense")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_current_speed(god: God) -> int:
	var base: int = god.base_speed
	var level_bonus: int = (god.level - 1) * int(base * _get_level_scale("speed"))
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "speed")
	var modifier: float = _get_stat_modifier(god, "speed")
	var ascension_bonus: float = get_ascension_bonus(god, "speed")
	var tier_mult: float = get_tier_multiplier(god)

	return int((base + level_bonus + equipment_bonus) * modifier * (1.0 + ascension_bonus) * tier_mult)

static func get_current_crit_rate(god: God) -> int:
	var base: int = god.base_crit_rate
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "crit_rate")
	var modifier: float = _get_stat_modifier(god, "crit_rate")
	return mini(100, int((base + equipment_bonus) * modifier))

static func get_current_crit_damage(god: God) -> int:
	var base: int = god.base_crit_damage
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "crit_damage")
	var modifier: float = _get_stat_modifier(god, "crit_damage")
	return int((base + equipment_bonus) * modifier)

static func get_current_accuracy(god: God) -> int:
	var base: int = god.base_accuracy
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "accuracy")
	var modifier: float = _get_stat_modifier(god, "accuracy")
	return mini(100, int((base + equipment_bonus) * modifier))

static func get_current_resistance(god: God) -> int:
	var base: int = god.base_resistance
	var equipment_bonus: int = _get_equipment_stat_bonus(god, "resistance")
	var modifier: float = _get_stat_modifier(god, "resistance")
	return mini(100, int((base + equipment_bonus) * modifier))

# ==============================================================================
# PRIVATE HELPER METHODS
# ==============================================================================

static func _get_equipment_stat_bonus(god: God, stat_type: String) -> int:
	var total_bonus: int = 0

	for i: int in range(god.equipment.size()):
		var eq: Variant = god.equipment[i]
		if eq and eq is Equipment:
			var typed_eq: Equipment = eq as Equipment
			# Main stat bonus
			if typed_eq.main_stat_type.to_lower() == stat_type.to_lower():
				total_bonus += typed_eq.main_stat_value if typed_eq.main_stat_value > 0 else typed_eq.main_stat_base

			# Substat bonuses
			for substat: Dictionary in typed_eq.substats:
				if substat.type.to_lower() == stat_type.to_lower():
					total_bonus += int(substat.value)

	return total_bonus

static func _get_stat_modifier(god: God, stat_name: String) -> float:
	_load_config()
	var modifier: float = 1.0
	var role_modifiers: Dictionary = _config.get("stat_scaling", {}).get("role_modifiers", {})

	var role_data: Dictionary = role_modifiers.get(god.territory_role, {})
	if not role_data.is_empty():
		var affected_stats: Array = role_data.get("stats", [])
		if stat_name in affected_stats:
			modifier += role_data.get("bonus", 0.0)

	return modifier

static func get_ascension_bonus(god: God, _stat_name: String) -> float:
	_load_config()
	var bonus_per_level: float = _config.get("stat_scaling", {}).get("ascension_bonus_per_level", 0.05)
	return god.ascension_level * bonus_per_level

static func get_tier_multiplier(god: God) -> float:
	_load_config()
	var tier_mults: Dictionary = _config.get("stat_scaling", {}).get("tier_multipliers", {})
	var tier_name: String = God.tier_to_string(god.tier).to_lower()
	return tier_mults.get(tier_name, 1.0)

# ==============================================================================
# POWER CALCULATIONS - UNIFIED SYSTEM
# ==============================================================================

## Basic power rating: HP + ATK + DEF + SPD (includes equipment, tier, ascension)
## Use this for simple displays where team context doesn't matter
static func get_power_rating(god: God) -> int:
	return get_current_hp(god) + get_current_attack(god) + get_current_defense(god) + get_current_speed(god)

## Combat power: Full individual combat potential including crit effectiveness and set bonuses
## Use this for comparing gods' individual strength
static func get_combat_power(god: God) -> int:
	var base_power: int = get_power_rating(god)

	# Add crit effectiveness: crit_rate * crit_damage / 100 gives expected damage multiplier
	var crit_rate: int = get_current_crit_rate(god)
	var crit_damage: int = get_current_crit_damage(god)
	# Crit effectiveness = (crit_rate/100) * (crit_damage/100) * base_attack
	# This represents average bonus damage from crits
	var crit_bonus: int = int(get_current_attack(god) * (crit_rate / 100.0) * (crit_damage / 100.0))

	# Add accuracy/resistance contribution (smaller impact)
	var accuracy_bonus: int = int(get_current_accuracy(god) * 0.5)
	var resistance_bonus: int = int(get_current_resistance(god) * 0.5)

	# Add equipment set stat bonuses
	var set_bonus: int = _calculate_equipment_set_stat_bonus(god)

	return base_power + crit_bonus + accuracy_bonus + resistance_bonus + set_bonus

## Get equipment set stat bonuses (not special effects, just flat stats)
static func _calculate_equipment_set_stat_bonus(god: God) -> int:
	_load_equipment_config()

	# Count equipment by set
	var set_counts: Dictionary = {}
	for i: int in range(god.equipment.size()):
		var eq: Variant = god.equipment[i]
		if eq and eq is Equipment:
			var typed_eq: Equipment = eq as Equipment
			var set_name: String = typed_eq.equipment_set_type.to_lower() if typed_eq.equipment_set_type else ""
			if set_name != "":
				set_counts[set_name] = set_counts.get(set_name, 0) + 1

	var total_bonus: int = 0
	var sets_data: Dictionary = _equipment_config.get("equipment_sets", {})

	for set_name: String in set_counts:
		var count: int = set_counts[set_name]
		var set_data: Dictionary = sets_data.get(set_name, {})
		var bonuses: Dictionary = set_data.get("bonuses", {})

		# Check each threshold (2, 4, 6 piece)
		for threshold: String in ["2", "4", "6"]:
			if count >= int(threshold) and bonuses.has(threshold):
				var tier_bonus: Dictionary = bonuses[threshold]
				# Sum all stat bonuses (ignore special_effect, effect_value, etc.)
				for stat_key: String in tier_bonus:
					if stat_key in ["attack", "defense", "hp", "speed", "crit_rate", "crit_damage", "accuracy", "resistance"]:
						total_bonus += int(tier_bonus[stat_key])

	return total_bonus

## Team power: Total power of a team including team bonuses and leader skills
## Use this for battle team composition screens and battle predictions
static func get_team_power(team: Array) -> int:
	if team.is_empty():
		return 0

	var base_team_power: int = 0
	for god in team:
		if god and god is God:
			base_team_power += get_combat_power(god)

	# Apply team bonus multiplier
	var team_bonus_mult: float = _calculate_team_bonus_multiplier(team)

	# Apply leader skill multiplier
	var leader_skill_mult: float = _calculate_leader_skill_multiplier(team)

	return int(base_team_power * (1.0 + team_bonus_mult) * (1.0 + leader_skill_mult))

## Garrison power: Team power with synergies but NO leader skills
## Use this for territory garrison defense calculations
static func get_garrison_power(team: Array) -> int:
	if team.is_empty():
		return 0

	var base_team_power: int = 0
	for god in team:
		if god and god is God:
			base_team_power += get_combat_power(god)

	# Apply team bonus multiplier (element/pantheon synergies still help defense)
	var team_bonus_mult: float = _calculate_team_bonus_multiplier(team)

	# NO leader skill - garrisons don't have an active battle leader
	return int(base_team_power * (1.0 + team_bonus_mult))

## Calculate team bonus multiplier from element/pantheon/tier/special synergies
static func _calculate_team_bonus_multiplier(team: Array) -> float:
	var bonuses: Array = TeamStatsCalculator.get_team_bonuses(team)
	var total_mult: float = 0.0

	for bonus: Dictionary in bonuses:
		var bonus_stats: Dictionary = bonus.get("bonuses", {})
		# Sum relevant combat multipliers
		if bonus_stats.has("attack"):
			total_mult += float(bonus_stats.attack) / 100.0
		if bonus_stats.has("defense"):
			total_mult += float(bonus_stats.defense) / 200.0  # Defense is half as impactful
		if bonus_stats.has("hp"):
			total_mult += float(bonus_stats.hp) / 200.0
		if bonus_stats.has("all_stats"):
			total_mult += float(bonus_stats.all_stats) / 100.0
		if bonus_stats.has("skill_damage"):
			total_mult += float(bonus_stats.skill_damage) / 150.0

	return total_mult

## Calculate leader skill contribution to team power
static func _calculate_leader_skill_multiplier(team: Array) -> float:
	if team.is_empty():
		return 0.0

	var leader: God = team[0] if team[0] is God else null
	if not leader or leader.leader_skill.is_empty():
		return 0.0

	var skill: Dictionary = leader.leader_skill
	var area: String = skill.get("area", "all")

	# Count how many team members benefit
	var benefiting_count: int = 0
	for god in team:
		if god and god is God:
			if area == "all" or _god_matches_area(god, area):
				benefiting_count += 1

	if benefiting_count == 0:
		return 0.0

	# Calculate multiplier
	var mult: float = 0.0

	# Old format: single type/value
	if skill.has("type") and skill.has("value"):
		var stat_type: String = skill.get("type", "")
		var value: float = float(skill.get("value", 0))
		if stat_type in ["attack", "all_stats"]:
			mult += (value / 100.0) * (float(benefiting_count) / team.size())
		elif stat_type in ["defense", "hp"]:
			mult += (value / 200.0) * (float(benefiting_count) / team.size())

	# New format: multiple bonuses
	if skill.has("bonuses"):
		var bonuses: Dictionary = skill.get("bonuses", {})
		for stat_key: String in bonuses:
			var value: float = float(bonuses[stat_key])
			if stat_key in ["attack"]:
				mult += (value / 100.0) * (float(benefiting_count) / team.size())
			elif stat_key in ["defense", "hp"]:
				mult += (value / 200.0) * (float(benefiting_count) / team.size())

	return mult

static func _god_matches_area(god: God, area: String) -> bool:
	if area == "all":
		return true
	# Check element
	var element_name: String = God.element_to_string(god.element).to_lower()
	if element_name == area.to_lower():
		return true
	return false

# ==============================================================================
# SYNERGY SCORING - For smart recommendations
# ==============================================================================

## Calculate how much adding a candidate god would improve team synergies
## Higher score = better recommendation
static func calculate_synergy_score(candidate: God, current_team: Array, node_element: int = -1) -> float:
	if not candidate:
		return 0.0

	var score: float = 0.0

	# 1. Team bonus improvement (most important)
	var current_bonuses: Array = TeamStatsCalculator.get_team_bonuses(current_team) if not current_team.is_empty() else []
	var current_bonus_value: float = _sum_bonus_combat_value(current_bonuses)

	var test_team: Array = current_team.duplicate()
	test_team.append(candidate)
	var new_bonuses: Array = TeamStatsCalculator.get_team_bonuses(test_team)
	var new_bonus_value: float = _sum_bonus_combat_value(new_bonuses)

	var bonus_improvement: float = new_bonus_value - current_bonus_value
	score += bonus_improvement * 50.0  # Weight bonus improvement heavily

	# 2. Check for new special synergies unlocked
	var new_special_count: int = _count_special_synergies(new_bonuses) - _count_special_synergies(current_bonuses)
	score += new_special_count * 200.0  # Big bonus for unlocking named combos

	# 3. Element matching bonus (for territory nodes)
	if node_element >= 0 and candidate.element == node_element:
		score += 100.0  # Matching element is valuable

	# 4. Pantheon synergy - does this god match existing pantheons?
	var pantheon_bonus: float = _calculate_pantheon_fit(candidate, current_team)
	score += pantheon_bonus * 30.0

	# 5. Role diversity - avoid stacking same role
	var role_penalty: float = _calculate_role_penalty(candidate, current_team)
	score -= role_penalty * 20.0

	# 6. Base power contribution - weight more heavily when team is empty
	var power_weight: float = 0.05 if current_team.is_empty() else 0.01
	score += get_combat_power(candidate) * power_weight

	# 7. Leader skill potential - if team has no leader, prefer gods with good leader skills
	# But don't let this override raw power completely
	if current_team.is_empty() and not candidate.leader_skill.is_empty():
		var leader_value: float = _estimate_leader_skill_value(candidate.leader_skill)
		score += leader_value * 15.0  # Reduced from 40 to balance with power

	return score

static func _sum_bonus_combat_value(bonuses: Array) -> float:
	var total: float = 0.0
	for bonus: Dictionary in bonuses:
		var stats: Dictionary = bonus.get("bonuses", {})
		if stats.has("attack"):
			total += float(stats.attack)
		if stats.has("defense"):
			total += float(stats.defense) * 0.5
		if stats.has("hp"):
			total += float(stats.hp) * 0.5
		if stats.has("all_stats"):
			total += float(stats.all_stats) * 2.0
		if stats.has("skill_damage"):
			total += float(stats.skill_damage)
		if stats.has("crit_damage"):
			total += float(stats.crit_damage)
		if stats.has("life_steal"):
			total += float(stats.life_steal) * 50.0
	return total

static func _count_special_synergies(bonuses: Array) -> int:
	var count: int = 0
	for bonus: Dictionary in bonuses:
		# Special synergies typically have named combos
		var name: String = bonus.get("name", "")
		if name != "" and not name.contains("Match") and not name.contains("Bonus"):
			count += 1
	return count

static func _calculate_pantheon_fit(candidate: God, team: Array) -> float:
	if team.is_empty():
		return 0.0

	var pantheon_counts: Dictionary = {}
	for god in team:
		if god and god is God and god.pantheon:
			var p: String = god.pantheon.to_lower()
			pantheon_counts[p] = pantheon_counts.get(p, 0) + 1

	if candidate.pantheon:
		var candidate_pantheon: String = candidate.pantheon.to_lower()
		if pantheon_counts.has(candidate_pantheon):
			# Matches existing pantheon - good synergy potential
			return float(pantheon_counts[candidate_pantheon])

	return 0.0

static func _calculate_role_penalty(candidate: God, team: Array) -> float:
	if team.is_empty():
		return 0.0

	var role_counts: Dictionary = {}
	for god in team:
		if god and god is God:
			var role: String = god.territory_role if god.territory_role else "none"
			role_counts[role] = role_counts.get(role, 0) + 1

	var candidate_role: String = candidate.territory_role if candidate.territory_role else "none"
	if role_counts.has(candidate_role) and role_counts[candidate_role] >= 2:
		# Already have 2+ of this role, penalize
		return float(role_counts[candidate_role])

	return 0.0

static func _estimate_leader_skill_value(skill: Dictionary) -> float:
	if skill.is_empty():
		return 0.0

	var value: float = 0.0
	var area: String = skill.get("area", "all")

	# "all" area is more valuable
	var area_mult: float = 1.0 if area == "all" else 0.6

	if skill.has("value"):
		value = float(skill.get("value", 0)) * area_mult
	elif skill.has("bonuses"):
		var bonuses: Dictionary = skill.get("bonuses", {})
		for stat_key: String in bonuses:
			value += float(bonuses[stat_key])
		value *= area_mult

	return value

# ==============================================================================
# PROGRESSION
# ==============================================================================

static func get_experience_to_next_level(god: God) -> int:
	var god_exp_calc: GDScript = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	return god_exp_calc.get_experience_to_next_level(god.level)
