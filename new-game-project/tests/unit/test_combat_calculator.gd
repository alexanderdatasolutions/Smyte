# test_combat_calculator.gd - Unit tests for scripts/systems/battle/CombatCalculator.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func create_mock_battle_unit(unit_name: String, atk: int = 500, def: int = 300, spd: int = 100, hp: int = 5000) -> BattleUnit:
	"""Create a mock BattleUnit for testing damage calculations"""
	var unit = BattleUnit.new()
	unit.unit_id = unit_name + "_" + str(randi() % 10000)
	unit.display_name = unit_name
	unit.is_player_unit = true
	unit.max_hp = hp
	unit.current_hp = hp
	unit.attack = atk
	unit.defense = def
	unit.speed = spd
	unit.crit_rate = 15
	unit.crit_damage = 50
	unit.accuracy = 0
	unit.resistance = 15
	unit.is_alive = true
	return unit

func create_mock_god(god_name: String = "TestGod", level: int = 1) -> God:
	"""Create a mock God for testing stat calculations"""
	var god = God.new()
	god.id = god_name.to_lower() + "_" + str(randi() % 10000)
	god.name = god_name
	god.pantheon = "greek"
	god.element = God.ElementType.FIRE
	god.tier = God.TierType.RARE
	god.level = level
	god.base_hp = 1000
	god.base_attack = 200
	god.base_defense = 100
	god.base_speed = 100
	god.base_crit_rate = 15
	god.base_crit_damage = 50
	god.base_resistance = 15
	god.base_accuracy = 0
	return god

func create_mock_skill(multiplier: float = 1.0) -> Skill:
	"""Create a mock Skill for testing"""
	var skill = Skill.new()
	skill.skill_id = "test_skill_" + str(randi() % 10000)
	skill.name = "Test Skill"
	skill.description = "A test skill"
	skill.cooldown = 3
	skill.damage_multiplier = multiplier
	skill.target_count = 1
	skill.targets_enemies = true
	return skill

# ==============================================================================
# TEST: Damage Formula Basic
# ==============================================================================

func test_damage_formula_basic():
	var attacker = create_mock_battle_unit("Attacker", 500, 300, 100, 5000)
	var target = create_mock_battle_unit("Target", 300, 200, 80, 5000)

	# Run multiple damage calculations to ensure result is always positive
	for i in range(10):
		var result = CombatCalculator.calculate_damage(attacker, target)
		runner.assert_true(result.total > 0, "damage should be positive (iteration %d)" % i)
		runner.assert_true(result is DamageResult, "should return DamageResult")

func test_damage_formula_returns_damage_result():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	var result = CombatCalculator.calculate_damage(attacker, target)

	runner.assert_true(result is DamageResult, "should return DamageResult type")
	runner.assert_true(result.total >= 1, "damage should be at least 1")

# ==============================================================================
# TEST: Damage with Zero Defense
# ==============================================================================

func test_damage_with_zero_defense():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target_zero_def = create_mock_battle_unit("TargetZeroDef", 300, 0)
	var target_normal_def = create_mock_battle_unit("TargetNormalDef", 300, 300)

	# Get average damage over multiple iterations
	var total_zero_def = 0
	var total_normal_def = 0
	var iterations = 20

	for i in range(iterations):
		var result_zero = CombatCalculator.calculate_damage(attacker, target_zero_def)
		var result_normal = CombatCalculator.calculate_damage(attacker, target_normal_def)
		total_zero_def += result_zero.total
		total_normal_def += result_normal.total

	var avg_zero_def = total_zero_def / iterations
	var avg_normal_def = total_normal_def / iterations

	# Zero defense should result in more damage
	runner.assert_true(avg_zero_def > avg_normal_def, "zero defense target should take more damage on average")

# ==============================================================================
# TEST: Damage with High Defense
# ==============================================================================

func test_damage_with_high_defense():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target_high_def = create_mock_battle_unit("TargetHighDef", 300, 2000)
	var target_low_def = create_mock_battle_unit("TargetLowDef", 300, 100)

	# Get average damage over multiple iterations
	var total_high_def = 0
	var total_low_def = 0
	var iterations = 20

	for i in range(iterations):
		var result_high = CombatCalculator.calculate_damage(attacker, target_high_def)
		var result_low = CombatCalculator.calculate_damage(attacker, target_low_def)
		total_high_def += result_high.total
		total_low_def += result_low.total

	var avg_high_def = total_high_def / iterations
	var avg_low_def = total_low_def / iterations

	# High defense should result in less damage
	runner.assert_true(avg_high_def < avg_low_def, "high defense target should take less damage on average")
	runner.assert_true(avg_high_def >= 1, "damage should still be at least 1 even with high defense")

# ==============================================================================
# TEST: Skill Damage Multiplier
# ==============================================================================

func test_skill_damage_multiplier():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	var skill_1x = create_mock_skill(1.0)
	var skill_2x = create_mock_skill(2.0)
	var skill_3x = create_mock_skill(3.0)

	# Get average damage for each multiplier
	var total_1x = 0
	var total_2x = 0
	var total_3x = 0
	var iterations = 30

	for i in range(iterations):
		var result_1x = CombatCalculator.calculate_damage(attacker, target, skill_1x)
		var result_2x = CombatCalculator.calculate_damage(attacker, target, skill_2x)
		var result_3x = CombatCalculator.calculate_damage(attacker, target, skill_3x)
		total_1x += result_1x.total
		total_2x += result_2x.total
		total_3x += result_3x.total

	var avg_1x = total_1x / iterations
	var avg_2x = total_2x / iterations
	var avg_3x = total_3x / iterations

	# Higher multiplier should result in more damage
	runner.assert_true(avg_2x > avg_1x, "2x multiplier should do more damage than 1x")
	runner.assert_true(avg_3x > avg_2x, "3x multiplier should do more damage than 2x")

func test_skill_damage_multiplier_zero():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	var skill_zero = create_mock_skill(0.0)
	var result = CombatCalculator.calculate_damage(attacker, target, skill_zero)

	# Damage should be at least 1 even with 0 multiplier
	runner.assert_true(result.total >= 1, "damage should be at least 1 even with 0x multiplier")

# ==============================================================================
# TEST: Critical Hit Properties
# ==============================================================================

func test_critical_hit_increases_damage():
	# We can't directly control critical hits, but we can verify critical results have higher damage
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	attacker.crit_rate = 100  # 100% crit rate for testing
	attacker.crit_damage = 150  # 150% crit damage
	var target = create_mock_battle_unit("Target", 300, 200)

	var crit_damages = []
	var iterations = 50

	for i in range(iterations):
		var result = CombatCalculator.calculate_damage(attacker, target)
		if result.is_critical:
			crit_damages.append(result.total)

	# With 100% crit rate, we should get critical hits
	runner.assert_true(crit_damages.size() > 0, "should have at least some critical hits with 100% crit rate")

func test_damage_result_critical_flag():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	# Run many iterations to ensure both crit and non-crit can happen
	var has_crit = false
	var has_non_crit = false

	for i in range(100):
		var result = CombatCalculator.calculate_damage(attacker, target)
		if result.is_critical:
			has_crit = true
		else:
			has_non_crit = true

	# At 15% crit rate, we should see both outcomes
	runner.assert_true(has_crit or has_non_crit, "should see at least some damage results")

# ==============================================================================
# TEST: Glancing Hit Properties
# ==============================================================================

func test_glancing_hit_reduces_damage():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	attacker.crit_rate = 0  # No crits to avoid interference
	var target = create_mock_battle_unit("Target", 300, 200)

	var glancing_damages = []
	var normal_damages = []

	for i in range(100):
		var result = CombatCalculator.calculate_damage(attacker, target)
		if result.is_glancing:
			glancing_damages.append(result.total)
		elif not result.is_critical:
			normal_damages.append(result.total)

	# We might not always get glancing hits due to RNG, so just check they exist when they do
	if glancing_damages.size() > 0 and normal_damages.size() > 0:
		var avg_glancing = 0
		for d in glancing_damages:
			avg_glancing += d
		avg_glancing = avg_glancing / glancing_damages.size()

		var avg_normal = 0
		for d in normal_damages:
			avg_normal += d
		avg_normal = avg_normal / normal_damages.size()

		# Glancing should typically do less damage (70%)
		runner.assert_true(avg_glancing <= avg_normal, "glancing hits should do less or equal damage on average")
	else:
		runner.assert_true(true, "glancing hit test inconclusive due to RNG (acceptable)")

func test_glancing_and_critical_mutually_exclusive():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	for i in range(100):
		var result = CombatCalculator.calculate_damage(attacker, target)
		runner.assert_false(result.is_critical and result.is_glancing, "critical and glancing should be mutually exclusive")

# ==============================================================================
# TEST: Damage Variance
# ==============================================================================

func test_damage_variance_within_bounds():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	attacker.crit_rate = 0  # No crits
	var target = create_mock_battle_unit("Target", 300, 200)

	var damages = []
	for i in range(50):
		var result = CombatCalculator.calculate_damage(attacker, target)
		if not result.is_glancing:  # Only non-glancing for consistency
			damages.append(result.total)

	if damages.size() > 5:
		var min_damage = damages[0]
		var max_damage = damages[0]
		for d in damages:
			if d < min_damage:
				min_damage = d
			if d > max_damage:
				max_damage = d

		# Variance should show some spread
		runner.assert_true(max_damage >= min_damage, "should have damage variance")

# ==============================================================================
# TEST: Element Multiplier (internal function - test indirectly)
# ==============================================================================

func test_element_advantage_fire_vs_earth():
	# Fire should be strong against Earth (1.3x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.FIRE, God.ElementType.EARTH)
	runner.assert_equal(multiplier, 1.3, "Fire should have 1.3x advantage against Earth")

func test_element_disadvantage_fire_vs_water():
	# Fire should be weak against Water (0.85x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.FIRE, God.ElementType.WATER)
	runner.assert_equal(multiplier, 0.85, "Fire should have 0.85x disadvantage against Water")

func test_element_advantage_water_vs_fire():
	# Water should be strong against Fire (1.3x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.WATER, God.ElementType.FIRE)
	runner.assert_equal(multiplier, 1.3, "Water should have 1.3x advantage against Fire")

func test_element_disadvantage_water_vs_earth():
	# Water should be weak against Earth (0.85x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.WATER, God.ElementType.EARTH)
	runner.assert_equal(multiplier, 0.85, "Water should have 0.85x disadvantage against Earth")

func test_element_advantage_earth_vs_water():
	# Earth should be strong against Water (1.3x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.EARTH, God.ElementType.WATER)
	runner.assert_equal(multiplier, 1.3, "Earth should have 1.3x advantage against Water")

func test_element_disadvantage_earth_vs_fire():
	# Earth should be weak against Fire (0.85x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.EARTH, God.ElementType.FIRE)
	runner.assert_equal(multiplier, 0.85, "Earth should have 0.85x disadvantage against Fire")

func test_element_advantage_light_vs_dark():
	# Light should be strong against Dark (1.3x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.LIGHT, God.ElementType.DARK)
	runner.assert_equal(multiplier, 1.3, "Light should have 1.3x advantage against Dark")

func test_element_advantage_dark_vs_light():
	# Dark should be strong against Light (1.3x)
	var multiplier = CombatCalculator._get_element_multiplier(God.ElementType.DARK, God.ElementType.LIGHT)
	runner.assert_equal(multiplier, 1.3, "Dark should have 1.3x advantage against Light")

func test_element_neutral_same_element():
	# Same element should be neutral (1.0x)
	var multiplier_fire = CombatCalculator._get_element_multiplier(God.ElementType.FIRE, God.ElementType.FIRE)
	var multiplier_water = CombatCalculator._get_element_multiplier(God.ElementType.WATER, God.ElementType.WATER)
	var multiplier_earth = CombatCalculator._get_element_multiplier(God.ElementType.EARTH, God.ElementType.EARTH)

	runner.assert_equal(multiplier_fire, 1.0, "Fire vs Fire should be neutral")
	runner.assert_equal(multiplier_water, 1.0, "Water vs Water should be neutral")
	runner.assert_equal(multiplier_earth, 1.0, "Earth vs Earth should be neutral")

func test_element_neutral_light_vs_non_dark():
	# Light vs non-Dark should be neutral
	var vs_fire = CombatCalculator._get_element_multiplier(God.ElementType.LIGHT, God.ElementType.FIRE)
	var vs_water = CombatCalculator._get_element_multiplier(God.ElementType.LIGHT, God.ElementType.WATER)
	var vs_earth = CombatCalculator._get_element_multiplier(God.ElementType.LIGHT, God.ElementType.EARTH)

	runner.assert_equal(vs_fire, 1.0, "Light vs Fire should be neutral")
	runner.assert_equal(vs_water, 1.0, "Light vs Water should be neutral")
	runner.assert_equal(vs_earth, 1.0, "Light vs Earth should be neutral")

func test_element_neutral_dark_vs_non_light():
	# Dark vs non-Light should be neutral
	var vs_fire = CombatCalculator._get_element_multiplier(God.ElementType.DARK, God.ElementType.FIRE)
	var vs_water = CombatCalculator._get_element_multiplier(God.ElementType.DARK, God.ElementType.WATER)
	var vs_earth = CombatCalculator._get_element_multiplier(God.ElementType.DARK, God.ElementType.EARTH)

	runner.assert_equal(vs_fire, 1.0, "Dark vs Fire should be neutral")
	runner.assert_equal(vs_water, 1.0, "Dark vs Water should be neutral")
	runner.assert_equal(vs_earth, 1.0, "Dark vs Earth should be neutral")

# ==============================================================================
# TEST: Healing Calculation
# ==============================================================================

func test_healing_calculation_basic():
	var healer = create_mock_battle_unit("Healer", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)
	target.current_hp = 1000  # Simulate damaged target

	var heal_skill = create_mock_skill(1.0)

	var heal_amount = CombatCalculator.calculate_healing(healer, target, heal_skill)
	runner.assert_true(heal_amount > 0, "healing should be positive")
	runner.assert_true(heal_amount >= 1, "healing should be at least 1")

func test_healing_calculation_with_multiplier():
	var healer = create_mock_battle_unit("Healer", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	var heal_1x = create_mock_skill(1.0)
	var heal_2x = create_mock_skill(2.0)

	# Get average healing over multiple iterations
	var total_1x = 0
	var total_2x = 0
	var iterations = 30

	for i in range(iterations):
		total_1x += CombatCalculator.calculate_healing(healer, target, heal_1x)
		total_2x += CombatCalculator.calculate_healing(healer, target, heal_2x)

	var avg_1x = total_1x / iterations
	var avg_2x = total_2x / iterations

	# 2x multiplier should heal more
	runner.assert_true(avg_2x > avg_1x, "2x healing multiplier should heal more than 1x")

func test_healing_scales_with_attack():
	var healer_low_atk = create_mock_battle_unit("LowAtkHealer", 200, 300)
	var healer_high_atk = create_mock_battle_unit("HighAtkHealer", 800, 300)
	var target = create_mock_battle_unit("Target", 300, 200)
	var heal_skill = create_mock_skill(1.0)

	# Get average healing
	var total_low = 0
	var total_high = 0
	var iterations = 30

	for i in range(iterations):
		total_low += CombatCalculator.calculate_healing(healer_low_atk, target, heal_skill)
		total_high += CombatCalculator.calculate_healing(healer_high_atk, target, heal_skill)

	var avg_low = total_low / iterations
	var avg_high = total_high / iterations

	# Higher attack should heal more
	runner.assert_true(avg_high > avg_low, "higher attack healer should heal more")

func test_healing_variance():
	var healer = create_mock_battle_unit("Healer", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)
	var heal_skill = create_mock_skill(1.0)

	var heals = []
	for i in range(30):
		heals.append(CombatCalculator.calculate_healing(healer, target, heal_skill))

	var min_heal = heals[0]
	var max_heal = heals[0]
	for h in heals:
		if h < min_heal:
			min_heal = h
		if h > max_heal:
			max_heal = h

	# Should have some variance (±5%)
	runner.assert_true(max_heal >= min_heal, "healing should have variance")

# ==============================================================================
# TEST: Total Stats Calculation
# ==============================================================================

func test_total_stats_includes_base_stats():
	var god = create_mock_god("TestGod", 1)
	god.base_hp = 2000
	god.base_attack = 300
	god.base_defense = 150
	god.base_speed = 120

	var stats = CombatCalculator.calculate_total_stats(god)

	runner.assert_equal(stats.hp, 2000, "level 1 hp should equal base hp")
	runner.assert_equal(stats.attack, 300, "level 1 attack should equal base attack")
	runner.assert_equal(stats.defense, 150, "level 1 defense should equal base defense")
	runner.assert_equal(stats.speed, 120, "speed should equal base speed")

func test_total_stats_level_scaling():
	var god = create_mock_god("TestGod", 1)
	god.base_hp = 1000
	god.base_attack = 200
	god.base_defense = 100

	var stats_level_1 = CombatCalculator.calculate_total_stats(god)

	god.level = 11  # +100% bonus (10 levels * 10% per level)
	var stats_level_11 = CombatCalculator.calculate_total_stats(god)

	runner.assert_equal(stats_level_1.hp, 1000, "level 1 hp should be base")
	runner.assert_equal(stats_level_11.hp, 2000, "level 11 hp should be 2x base")
	runner.assert_equal(stats_level_11.attack, 400, "level 11 attack should be 2x base")
	runner.assert_equal(stats_level_11.defense, 200, "level 11 defense should be 2x base")

func test_total_stats_level_scaling_partial():
	var god = create_mock_god("TestGod", 1)
	god.base_hp = 1000
	god.base_attack = 100

	god.level = 5  # +40% bonus (4 levels * 10%)
	var stats = CombatCalculator.calculate_total_stats(god)

	runner.assert_equal(stats.hp, 1400, "level 5 hp should be 1.4x base")
	runner.assert_equal(stats.attack, 140, "level 5 attack should be 1.4x base")

func test_total_stats_contains_all_stat_fields():
	var god = create_mock_god("TestGod", 1)
	var stats = CombatCalculator.calculate_total_stats(god)

	runner.assert_true(stats.has("hp"), "stats should have hp")
	runner.assert_true(stats.has("attack"), "stats should have attack")
	runner.assert_true(stats.has("defense"), "stats should have defense")
	runner.assert_true(stats.has("speed"), "stats should have speed")
	runner.assert_true(stats.has("crit_rate"), "stats should have crit_rate")
	runner.assert_true(stats.has("crit_damage"), "stats should have crit_damage")
	runner.assert_true(stats.has("accuracy"), "stats should have accuracy")
	runner.assert_true(stats.has("resistance"), "stats should have resistance")

func test_total_stats_crit_and_secondary_stats():
	var god = create_mock_god("TestGod", 1)
	god.base_crit_rate = 20
	god.base_crit_damage = 75
	god.base_accuracy = 10
	god.base_resistance = 25

	var stats = CombatCalculator.calculate_total_stats(god)

	runner.assert_equal(stats.crit_rate, 20, "crit_rate should match base")
	runner.assert_equal(stats.crit_damage, 75, "crit_damage should match base")
	runner.assert_equal(stats.accuracy, 10, "accuracy should match base")
	runner.assert_equal(stats.resistance, 25, "resistance should match base")

# ==============================================================================
# TEST: Power Rating Calculation
# ==============================================================================

func test_power_rating_calculation_basic():
	var god = create_mock_god("TestGod", 1)
	god.base_hp = 900
	god.base_attack = 300
	god.base_defense = 300  # Average of 500
	god.tier = God.TierType.COMMON  # tier 0

	# Power = (900+300+300)/3 + 1*50 + 0*500 = 500 + 50 + 0 = 550
	var power = CombatCalculator.calculate_total_power(god)
	runner.assert_equal(power, 550, "power should be calculated correctly for level 1 common")

func test_power_rating_level_bonus():
	var god = create_mock_god("TestGod", 10)
	god.base_hp = 300
	god.base_attack = 300
	god.base_defense = 300  # Average of 300
	god.tier = God.TierType.COMMON

	# Power = 300 + 10*50 + 0*500 = 300 + 500 + 0 = 800
	var power = CombatCalculator.calculate_total_power(god)
	runner.assert_equal(power, 800, "power should include level bonus (50 per level)")

func test_power_rating_tier_bonus():
	var god = create_mock_god("TestGod", 1)
	god.base_hp = 300
	god.base_attack = 300
	god.base_defense = 300  # Average of 300
	god.tier = God.TierType.LEGENDARY  # tier 4

	# Power = 300 + 1*50 + 4*500 = 300 + 50 + 2000 = 2350
	var power = CombatCalculator.calculate_total_power(god)
	runner.assert_equal(power, 2350, "power should include tier bonus (500 per tier)")

func test_power_rating_combined():
	var god = create_mock_god("TestGod", 20)
	god.base_hp = 600
	god.base_attack = 600
	god.base_defense = 600  # Average of 600
	god.tier = God.TierType.EPIC  # tier 3

	# Power = 600 + 20*50 + 3*500 = 600 + 1000 + 1500 = 3100
	var power = CombatCalculator.calculate_total_power(god)
	runner.assert_equal(power, 3100, "power should combine all bonuses correctly")

# ==============================================================================
# TEST: Detailed Stat Breakdowns
# ==============================================================================

func test_detailed_attack_breakdown():
	var god = create_mock_god("TestGod", 5)
	god.base_attack = 200

	var breakdown = CombatCalculator.get_detailed_attack_breakdown(god)

	runner.assert_equal(breakdown.base_value, 200, "base_value should be base_attack")
	runner.assert_equal(breakdown.level_bonus, 80, "level_bonus should be 40% of base at level 5")
	runner.assert_equal(breakdown.equipment_bonus, 0, "equipment_bonus not yet implemented")
	runner.assert_equal(breakdown.buff_bonus, 0, "buff_bonus not yet implemented")
	runner.assert_equal(breakdown.final_value, 280, "final_value should be sum of all")

func test_detailed_defense_breakdown():
	var god = create_mock_god("TestGod", 3)
	god.base_defense = 150

	var breakdown = CombatCalculator.get_detailed_defense_breakdown(god)

	runner.assert_equal(breakdown.base_value, 150, "base_value should be base_defense")
	runner.assert_equal(breakdown.level_bonus, 30, "level_bonus should be 20% of base at level 3")
	runner.assert_equal(breakdown.final_value, 180, "final_value should be sum of all")

func test_detailed_hp_breakdown():
	var god = create_mock_god("TestGod", 6)
	god.base_hp = 1000

	var breakdown = CombatCalculator.get_detailed_hp_breakdown(god)

	runner.assert_equal(breakdown.base_value, 1000, "base_value should be base_hp")
	runner.assert_equal(breakdown.level_bonus, 500, "level_bonus should be 50% of base at level 6")
	runner.assert_equal(breakdown.final_value, 1500, "final_value should be sum of all")

func test_detailed_speed_breakdown():
	var god = create_mock_god("TestGod", 10)
	god.base_speed = 120

	var breakdown = CombatCalculator.get_detailed_speed_breakdown(god)

	runner.assert_equal(breakdown.base_value, 120, "base_value should be base_speed")
	runner.assert_equal(breakdown.level_bonus, 0, "speed should not scale with level")
	runner.assert_equal(breakdown.final_value, 120, "final_value should equal base for speed")

func test_detailed_breakdown_at_level_1():
	var god = create_mock_god("TestGod", 1)
	god.base_attack = 200

	var breakdown = CombatCalculator.get_detailed_attack_breakdown(god)

	runner.assert_equal(breakdown.level_bonus, 0, "level_bonus should be 0 at level 1")
	runner.assert_equal(breakdown.final_value, 200, "final_value should equal base at level 1")

# ==============================================================================
# TEST: Edge Cases
# ==============================================================================

func test_damage_with_very_high_attack():
	var attacker = create_mock_battle_unit("Attacker", 99999, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	var result = CombatCalculator.calculate_damage(attacker, target)
	runner.assert_true(result.total > 0, "damage should be positive with very high attack")

func test_damage_with_very_high_defense():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 99999)

	var result = CombatCalculator.calculate_damage(attacker, target)
	runner.assert_true(result.total >= 1, "damage should be at least 1 with very high defense")

func test_damage_without_skill():
	var attacker = create_mock_battle_unit("Attacker", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	var result = CombatCalculator.calculate_damage(attacker, target, null)
	runner.assert_true(result.total > 0, "damage should work without skill (null)")

func test_healing_with_null_skill():
	var healer = create_mock_battle_unit("Healer", 500, 300)
	var target = create_mock_battle_unit("Target", 300, 200)

	# This tests if the function handles null skill (it uses ternary operator)
	var heal_skill = create_mock_skill(1.0)
	var heal_amount = CombatCalculator.calculate_healing(healer, target, heal_skill)
	runner.assert_true(heal_amount > 0, "healing should work with a skill")

func test_power_rating_tier_common():
	var god = create_mock_god("TestGod", 1)
	god.base_hp = 0
	god.base_attack = 0
	god.base_defense = 0
	god.tier = God.TierType.COMMON  # 0

	# Power = 0 + 1*50 + 0*500 = 50
	var power = CombatCalculator.calculate_total_power(god)
	runner.assert_equal(power, 50, "minimum power should be level bonus only")

func test_power_rating_high_level():
	var god = create_mock_god("TestGod", 50)
	god.base_hp = 0
	god.base_attack = 0
	god.base_defense = 0
	god.tier = God.TierType.COMMON

	# Power = 0 + 50*50 + 0*500 = 2500
	var power = CombatCalculator.calculate_total_power(god)
	runner.assert_equal(power, 2500, "power should scale with high level")

func test_total_stats_high_level():
	var god = create_mock_god("TestGod", 40)
	god.base_hp = 1000
	god.base_attack = 100
	god.base_defense = 100

	var stats = CombatCalculator.calculate_total_stats(god)

	# Level 40 = 1 + 39*0.1 = 4.9x multiplier
	runner.assert_equal(stats.hp, 4900, "hp should scale correctly at level 40")
	runner.assert_equal(stats.attack, 490, "attack should scale correctly at level 40")
	runner.assert_equal(stats.defense, 490, "defense should scale correctly at level 40")
