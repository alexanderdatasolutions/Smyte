# EnemyFactory.gd - Create and configure enemies for battles
class_name EnemyFactory
extends RefCounted

static func create_enemies_for_stage(territory: Territory, stage: int) -> Array:
	"""Create enemies using the Summoners War style system - matches your existing logic"""
	var enemies = []
	
	# Get enemy count and composition from the same system as TerritoryScreen preview
	var enemy_count = _get_stage_enemy_count(stage)
	var enemy_composition = _get_stage_enemy_composition(stage)
	
	# Base level calculation (gentler stage progression)
	var base_level = _get_base_level_for_territory_tier(territory.tier)
	var stage_level = base_level + (stage - 1) * 1  # Reduced from 2 to 1 per stage
	
	# Create enemies based on composition
	for i in range(enemy_count):
		var enemy = {}
		enemy.level = stage_level
		
		# Determine enemy type
		var enemy_type = "basic"
		if i < enemy_composition.size():
			enemy_type = enemy_composition[i]
		
		# Set enemy name and element based on territory
		var element_string = DataLoader.element_int_to_string(territory.element)
		var element_name = _get_element_display_name(element_string)
		match enemy_type:
			"boss":
				enemy.name = "%s Overlord" % element_name
			"elite":
				enemy.name = "%s Elite" % element_name
			"leader":
				enemy.name = "%s Commander" % element_name
			_:
				enemy.name = "%s Warrior" % element_name
		
		# Calculate stats using the same system as preview
		var stats = _calculate_enemy_stats(territory.element, enemy_type, stage_level, territory.tier)
		enemy.hp = stats.hp
		enemy.current_hp = stats.hp
		enemy.attack = stats.attack
		enemy.defense = stats.defense
		enemy.speed = stats.speed
		enemy.crit_rate = stats.crit_rate
		enemy.crit_damage = stats.crit_damage
		enemy.resistance = stats.resistance
		enemy.accuracy = stats.accuracy
		enemy.element = element_string  # Use proper element string
		enemy.type = enemy_type
		
		# Add status effects tracking for enemies
		enemy.status_effects = []
		enemy.shield_hp = 0
		
		# Add unique battle index for UI tracking
		enemy.battle_index = i
		
		# Add basic AI data
		enemy.ai_behavior = _get_enemy_ai_behavior(enemy_type)
		
		enemies.append(enemy)
	
	print("EnemyFactory created %d enemies for %s Stage %d:" % [enemies.size(), territory.name, stage])
	for enemy in enemies:
		print("  %s (Lv.%d) - HP:%d ATK:%d DEF:%d SPD:%d CR:%d%% CD:%d%% RES:%d%% ACC:%d%%" % [
			enemy.name, enemy.level, enemy.hp, enemy.attack, enemy.defense, enemy.speed, 
			enemy.get("crit_rate", 15), enemy.get("crit_damage", 50), enemy.get("resistance", 15), enemy.get("accuracy", 0)
		])
	
	return enemies

static func create_enemies_for_dungeon(dungeon_id: String, difficulty: String) -> Array:
	"""Create enemies for dungeon battles - modular system"""
	var enemies = []
	
	# Determine element from dungeon ID
	var element_string = "fire"  # default
	if "_sanctum" in dungeon_id:
		element_string = dungeon_id.replace("_sanctum", "")
	elif dungeon_id == "magic_sanctum":
		element_string = "light"  # Magic sanctum uses light element
	
	# Fix magic_sanctum edge case
	if element_string == "magic":
		element_string = "light"
	
	# Convert element string to int for compatibility
	var element_int = DataLoader.element_string_to_int(element_string)
	
	# Get dungeon configuration
	var dungeon_config = _get_dungeon_config(dungeon_id, difficulty)
	var enemy_count = dungeon_config.enemy_count
	var enemy_level = dungeon_config.enemy_level
	var enemy_composition = dungeon_config.enemy_composition
	
	# Create enemies
	for i in range(enemy_count):
		var enemy = {}
		enemy.level = enemy_level
		
		# Determine enemy type
		var enemy_type = "basic"
		if i < enemy_composition.size():
			enemy_type = enemy_composition[i]
		
		# Set enemy name based on dungeon type and element
		var element_name = _get_element_display_name(element_string)
		if "sanctum" in dungeon_id:
			match enemy_type:
				"boss":
					enemy.name = "%s Sanctum Guardian" % element_name
				"elite":
					enemy.name = "%s Sanctum Sentinel" % element_name
				"leader":
					enemy.name = "%s Sanctum Keeper" % element_name
				_:
					enemy.name = "%s Sanctum Spirit" % element_name
		else:
			match enemy_type:
				"boss":
					enemy.name = "Ancient %s" % element_name
				"elite":
					enemy.name = "%s Champion" % element_name
				"leader":
					enemy.name = "%s Veteran" % element_name
				_:
					enemy.name = "%s Warrior" % element_name
		
		# Calculate stats for dungeon enemy
		var stats = _calculate_dungeon_enemy_stats(element_int, enemy_type, enemy_level, difficulty)
		enemy.hp = stats.hp
		enemy.current_hp = stats.hp
		enemy.attack = stats.attack
		enemy.defense = stats.defense
		enemy.speed = stats.speed
		enemy.crit_rate = stats.crit_rate
		enemy.crit_damage = stats.crit_damage
		enemy.resistance = stats.resistance
		enemy.accuracy = stats.accuracy
		enemy.element = element_string
		enemy.type = enemy_type
		
		# Add status effects tracking for enemies
		enemy.status_effects = []
		enemy.shield_hp = 0
		
		# Add unique battle index for UI tracking
		enemy.battle_index = i
		
		# Add basic AI data
		enemy.ai_behavior = _get_enemy_ai_behavior(enemy_type)
		
		enemies.append(enemy)
	
	print("EnemyFactory created %d enemies for dungeon %s (%s):" % [enemies.size(), dungeon_id, difficulty])
	for enemy in enemies:
		print("  %s (Lv.%d) - HP:%d ATK:%d DEF:%d SPD:%d CR:%d%% CD:%d%% RES:%d%% ACC:%d%%" % [
			enemy.name, enemy.level, enemy.hp, enemy.attack, enemy.defense, enemy.speed, 
			enemy.get("crit_rate", 15), enemy.get("crit_damage", 50), enemy.get("resistance", 15), enemy.get("accuracy", 0)
		])
	
	return enemies

static func _get_stage_enemy_count(stage: int) -> int:
	"""Get number of enemies for a stage - max 4 enemies for UI space"""
	match stage:
		1, 2:
			return 3  # Early stages: 3 basic enemies
		3, 4, 5:
			return 4  # Mid stages: 4 enemies
		6, 7, 8, 9:
			return 4  # Late stages: 4 enemies (reduced from 5)
		10:
			return 3  # Boss stage: fewer but stronger enemies
		_:
			return 4  # Default

static func _get_stage_enemy_composition(stage: int) -> Array:
	"""Get enemy type composition for a stage - matches TerritoryScreen logic"""
	var composition = []
	
	match stage:
		1, 2:
			# Early stages: all basic
			composition = ["basic", "basic", "basic"]
		3, 4:
			# Add a leader
			composition = ["basic", "basic", "leader", "basic"]
		5, 6, 7:
			# Mixed composition with elite (4 enemies)
			composition = ["basic", "leader", "elite", "basic"]
		8, 9:
			# Harder composition (4 enemies)
			composition = ["leader", "elite", "elite", "basic"]
		10:
			# Boss stage
			composition = ["elite", "boss", "elite"]
		_:
			# Default composition
			composition = ["basic", "basic", "leader", "basic"]
	
	return composition

static func _get_base_level_for_territory_tier(tier: int) -> int:
	"""Get base level for territory tier"""
	match tier:
		1:
			return 5   # Tier 1: levels 5-25 (reduced from 10)
		2:
			return 20  # Tier 2: levels 20-40 (reduced from 25) 
		3:
			return 35  # Tier 3: levels 35-55 (reduced from 40)
		_:
			return 10 + (tier - 1) * 15  # Higher tiers

static func _get_element_display_name(element: String) -> String:
	"""Get display name for element"""
	match element.to_lower():
		"fire":
			return "Flame"
		"water":
			return "Frost"
		"earth":
			return "Stone"
		"lightning":
			return "Storm"
		"light":
			return "Divine"
		"dark":
			return "Shadow"
		_:
			return "Mystic"

static func _calculate_enemy_stats(_element: Territory.ElementType, enemy_type: String, level: int, tier: int) -> Dictionary:
	"""Calculate enemy stats using Summoners War scaling - matches your gods system"""
	# Base stats following SW conventions (similar to 2-3★ monsters)
	var base_hp = 800        # SW-style base HP
	var base_attack = 150    # SW-style base ATK  
	var base_defense = 120   # SW-style base DEF
	var base_speed = 90      # SW-style base SPD
	
	# Per-level growth (substantial like SW)
	var hp_per_level = 45    # HP grows significantly
	var attack_per_level = 8 # ATK grows moderately
	var defense_per_level = 6 # DEF grows moderately
	var speed_per_level = 2   # SPD grows slowly
	
	# Role multipliers based on enemy type (matching enemies.json design)
	var role_multipliers = _get_enemy_type_multipliers(enemy_type)
	
	# Territory tier scaling (higher tiers = stronger base stats)
	var tier_multiplier = 1.0 + (tier - 1) * 0.3  # Increased from 0.2
	
	# Calculate final stats using SW-style formula
	var stats = {}
	stats.hp = int((base_hp + level * hp_per_level) * role_multipliers.hp * tier_multiplier)
	stats.attack = int((base_attack + level * attack_per_level) * role_multipliers.attack * tier_multiplier)
	stats.defense = int((base_defense + level * defense_per_level) * role_multipliers.defense * tier_multiplier)
	stats.speed = int((base_speed + level * speed_per_level) * role_multipliers.speed * tier_multiplier)
	
	# Add SW-style secondary stats
	stats.crit_rate = 15 + (5 if enemy_type == "elite" else 0) + (10 if enemy_type == "boss" else 0)
	stats.crit_damage = 50 + (20 if enemy_type == "boss" else 0)
	stats.resistance = 15 + (tier - 1) * 10 + (25 if enemy_type == "boss" else 0)
	stats.accuracy = 0 + (20 if enemy_type == "leader" else 0) + (15 if enemy_type == "elite" else 0)
	
	return stats

static func _get_enemy_type_multipliers(enemy_type: String) -> Dictionary:
	"""Get stat multipliers for different enemy types - matches enemies.json design"""
	match enemy_type:
		"boss":
			return {"hp": 1.8, "attack": 1.5, "defense": 1.3, "speed": 1.2}
		"elite":
			return {"hp": 1.3, "attack": 1.1, "defense": 1.0, "speed": 1.1}
		"leader":
			return {"hp": 1.1, "attack": 1.0, "defense": 0.9, "speed": 1.0}
		_:  # basic
			return {"hp": 0.8, "attack": 0.9, "defense": 0.8, "speed": 1.0}

static func _get_enemy_ai_behavior(enemy_type: String) -> Dictionary:
	"""Get AI behavior data for enemy type"""
	match enemy_type:
		"boss":
			return {
				"aggression": 0.9,
				"target_priority": "highest_attack",
				"ability_usage": "always_use_best",
				"special_behavior": "enrage_when_low_hp"
			}
		"elite":
			return {
				"aggression": 0.7,
				"target_priority": "lowest_hp",
				"ability_usage": "smart_cooldown_management",
				"special_behavior": "focus_weakest"
			}
		"leader":
			return {
				"aggression": 0.6,
				"target_priority": "balanced",
				"ability_usage": "support_allies",
				"special_behavior": "buff_allies_when_possible"
			}
		_:  # basic
			return {
				"aggression": 0.5,
				"target_priority": "random",
				"ability_usage": "basic_attacks_mostly",
				"special_behavior": "none"
			}

# Enemy upgrade/enhancement methods for future expansion

static func create_enhanced_enemy(base_enemy: Dictionary, enhancement_level: int) -> Dictionary:
	"""Create an enhanced version of an enemy (for special events, etc.)"""
	var enhanced = base_enemy.duplicate(true)
	
	var multiplier = 1.0 + (enhancement_level * 0.15)  # 15% per enhancement level
	enhanced.hp = int(enhanced.hp * multiplier)
	enhanced.current_hp = enhanced.hp
	enhanced.attack = int(enhanced.attack * multiplier)
	enhanced.defense = int(enhanced.defense * multiplier)
	enhanced.speed = int(enhanced.speed * multiplier)
	
	enhanced.name = "Enhanced " + enhanced.name
	enhanced.enhancement_level = enhancement_level
	
	return enhanced

static func create_boss_variant(territory: Territory, stage: int, variant_name: String) -> Dictionary:
	"""Create a special boss variant (for events, challenges, etc.)"""
	var enemies = create_enemies_for_stage(territory, stage)
	var boss_enemy = null
	
	# Find the strongest enemy to make boss
	var highest_hp = 0
	for enemy in enemies:
		if enemy.hp > highest_hp:
			highest_hp = enemy.hp
			boss_enemy = enemy
	
	if boss_enemy:
		boss_enemy.name = variant_name
		boss_enemy.type = "special_boss"
		boss_enemy.hp = int(boss_enemy.hp * 1.5)
		boss_enemy.current_hp = boss_enemy.hp
		boss_enemy.attack = int(boss_enemy.attack * 1.3)
		boss_enemy.defense = int(boss_enemy.defense * 1.2)
		
		# Add special abilities or status effects
		boss_enemy.special_abilities = ["boss_rage", "area_attack", "summon_minions"]
	
	return boss_enemy if boss_enemy else {}

# Validation and utility methods

static func validate_enemy(enemy: Dictionary) -> bool:
	"""Validate that an enemy has all required fields"""
	var required_fields = ["name", "hp", "current_hp", "attack", "defense", "speed", "element", "type"]
	
	for field in required_fields:
		if not enemy.has(field):
			print("Enemy validation failed: missing field '%s'" % field)
			return false
	
	return true

static func get_enemy_power_rating(enemy: Dictionary) -> int:
	"""Calculate a power rating for an enemy (for matchmaking, etc.)"""
	var hp_weight = 0.4
	var attack_weight = 0.3
	var defense_weight = 0.2
	var speed_weight = 0.1
	
	var power = (enemy.get("hp", 0) * hp_weight + 
				enemy.get("attack", 0) * attack_weight +
				enemy.get("defense", 0) * defense_weight +
				enemy.get("speed", 0) * speed_weight)
	
	return int(power)

static func _get_dungeon_config(dungeon_id: String, difficulty: String) -> Dictionary:
	"""Get dungeon configuration for enemy creation"""
	var config = {
		"enemy_count": 3,
		"enemy_level": 15,
		"enemy_composition": ["basic", "basic", "leader"],
		"waves": 1
	}
	
	# Try to get wave count from dungeons.json
	var dungeon_system = null
	if GameManager and GameManager.has_method("get_dungeon_system"):
		dungeon_system = GameManager.get_dungeon_system()
	
	if dungeon_system:
		var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
		var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
		if difficulty_info.has("waves"):
			config.waves = difficulty_info.waves
	
	# Adjust based on difficulty
	match difficulty:
		"beginner":
			config.enemy_level = 15
			config.enemy_count = 3
			config.enemy_composition = ["basic", "basic", "leader"]
		"intermediate":
			config.enemy_level = 25
			config.enemy_count = 4
			config.enemy_composition = ["basic", "leader", "elite", "basic"]
		"advanced":
			config.enemy_level = 35
			config.enemy_count = 4
			config.enemy_composition = ["leader", "elite", "elite", "basic"]
		"expert":
			config.enemy_level = 45
			config.enemy_count = 4
			config.enemy_composition = ["elite", "elite", "boss", "elite"]
		"master":
			config.enemy_level = 55
			config.enemy_count = 5
			config.enemy_composition = ["elite", "elite", "boss", "elite", "leader"]
		"heroic":
			config.enemy_level = 65
			config.enemy_count = 5
			config.enemy_composition = ["boss", "elite", "boss", "elite", "elite"]
		"legendary":
			config.enemy_level = 75
			config.enemy_count = 5
			config.enemy_composition = ["boss", "boss", "elite", "boss", "elite"]
	
	return config

static func _calculate_dungeon_enemy_stats(_element: Territory.ElementType, enemy_type: String, level: int, difficulty: String) -> Dictionary:
	"""Calculate stats for dungeon enemies with difficulty scaling"""
	# Base stats for dungeon enemies (stronger than territory enemies)
	var base_hp = 1200        # Higher than territory base
	var base_attack = 200     # Higher than territory base  
	var base_defense = 150    # Higher than territory base
	
	# Difficulty multipliers
	var difficulty_multiplier = 1.0
	match difficulty:
		"beginner": difficulty_multiplier = 1.0
		"intermediate": difficulty_multiplier = 1.3
		"advanced": difficulty_multiplier = 1.7
		"expert": difficulty_multiplier = 2.2
		"master": difficulty_multiplier = 2.8
		"heroic": difficulty_multiplier = 3.5
		"legendary": difficulty_multiplier = 4.5
	
	# Enemy type multipliers (same as territory system)
	var type_hp_multiplier = 1.0
	var type_attack_multiplier = 1.0
	var type_defense_multiplier = 1.0
	
	match enemy_type:
		"basic":
			type_hp_multiplier = 1.0
			type_attack_multiplier = 1.0
			type_defense_multiplier = 1.0
		"leader":
			type_hp_multiplier = 1.4
			type_attack_multiplier = 1.2
			type_defense_multiplier = 1.2
		"elite":
			type_hp_multiplier = 1.8
			type_attack_multiplier = 1.4
			type_defense_multiplier = 1.4
		"boss":
			type_hp_multiplier = 3.0
			type_attack_multiplier = 1.8
			type_defense_multiplier = 1.6
	
	# Level scaling (exponential growth like Summoners War)
	var level_multiplier = pow(1.06, level - 1)  # 6% per level
	
	# Calculate final stats
	var final_hp = int(base_hp * level_multiplier * type_hp_multiplier * difficulty_multiplier)
	var final_attack = int(base_attack * level_multiplier * type_attack_multiplier * difficulty_multiplier)
	var final_defense = int(base_defense * level_multiplier * type_defense_multiplier * difficulty_multiplier)
	
	# Speed doesn't scale as much
	var base_speed = 100 + randi_range(-15, 15)  # Random speed variation
	var final_speed = int(base_speed * (1.0 + (level - 1) * 0.02))  # 2% per level
	
	# Crit stats
	var crit_rate = 15 + randi_range(0, 10)  # 15-25%
	var crit_damage = 50 + randi_range(0, 20)  # 50-70%
	
	# Resistance and accuracy
	var resistance = 15 + randi_range(0, 15)  # 15-30%
	var accuracy = randi_range(0, 20)  # 0-20%
	
	# Boss bonuses
	if enemy_type == "boss":
		crit_rate += 10
		crit_damage += 20
		resistance += 20
		accuracy += 15
	
	return {
		"hp": final_hp,
		"attack": final_attack,
		"defense": final_defense,
		"speed": final_speed,
		"crit_rate": crit_rate,
		"crit_damage": crit_damage,
		"resistance": resistance,
		"accuracy": accuracy
	}

# Wave-based enemy creation methods
static func create_enemies_for_dungeon_wave(dungeon_id: String, difficulty: String, wave_number: int) -> Array:
	"""Create enemies for a specific dungeon wave"""
	var enemies = []
	
	# Get dungeon info
	var dungeon_system = GameManager.get_dungeon_system() if GameManager else null
	if not dungeon_system:
		return []
	
	var dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
	var difficulty_info = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	
	# Wave-based enemy scaling
	var base_enemy_count = 3  # Base enemies per wave
	var wave_enemy_count = base_enemy_count + (wave_number - 1)  # More enemies in later waves
	
	# Get enemy level based on difficulty
	var base_level = _get_dungeon_enemy_level(difficulty)
	var wave_level = base_level + (wave_number - 1) * 2  # +2 levels per wave
	
	# Create enemies
	for i in range(wave_enemy_count):
		var enemy = _create_dungeon_enemy(dungeon_id, difficulty, wave_level, i, wave_enemy_count)
		enemies.append(enemy)
	
	return enemies

static func create_enemies_for_territory_wave(territory: Territory, stage: int, wave_number: int) -> Array:
	"""Create enemies for a specific territory wave"""
	var enemies = []
	
	# Base enemy count per wave
	var base_count = 2 + wave_number  # Wave 1 = 3, Wave 2 = 4, Wave 3 = 5
	
	# Create enemies using existing territory logic
	var base_level = _get_base_level_for_territory_tier(territory.tier)
	var enemy_level = base_level + (stage - 1) + (wave_number - 1) * 2
	
	for i in range(base_count):
		var enemy_type = "basic"
		if i == base_count - 1 and wave_number == 3:  # Last enemy in final wave
			enemy_type = "boss"
		elif i >= base_count - 2:  # Last two enemies
			enemy_type = "elite"
		
		var enemy = _create_territory_enemy(territory, enemy_level, enemy_type)
		enemies.append(enemy)
	
	return enemies

static func create_enemies_for_raid_wave(raid_id: String, difficulty: String, wave_number: int, enemy_count: int) -> Array:
	"""Create enemies for a specific raid wave"""
	var enemies = []
	
	# Raids have progressively stronger waves
	var base_level = 50 + (wave_number - 1) * 5
	
	for i in range(enemy_count):
		var enemy_type = "elite" if i < enemy_count - 1 else "boss"  # Last enemy is always boss
		var enemy = _create_raid_enemy(raid_id, difficulty, base_level, enemy_type)
		enemies.append(enemy)
	
	return enemies

static func _create_dungeon_enemy(dungeon_id: String, difficulty: String, level: int, enemy_index: int, total_enemies: int) -> Dictionary:
	"""Create a single dungeon enemy"""
	var enemy = {}
	
	# Get dungeon element for naming
	var element = _get_dungeon_element(dungeon_id)
	var element_name = _get_element_display_name(element)
	
	# Determine enemy type based on position
	var enemy_type = "basic"
	if enemy_index == total_enemies - 1:  # Last enemy
		enemy_type = "boss"
	elif enemy_index >= total_enemies - 2:  # Second to last
		enemy_type = "elite"
	
	# Set name
	match enemy_type:
		"boss":
			enemy.name = "%s Dungeon Guardian" % element_name
		"elite":
			enemy.name = "%s Elite Guardian" % element_name
		_:
			enemy.name = "%s Guardian" % element_name
	
	# Calculate stats
	var element_int = DataLoader.element_string_to_int(element)
	var stats = _calculate_enemy_stats(element_int, enemy_type, level, 3)  # Tier 3 for dungeons
	
	enemy.hp = stats.hp
	enemy.current_hp = stats.hp
	enemy.attack = stats.attack
	enemy.defense = stats.defense
	enemy.speed = stats.speed
	enemy.crit_rate = stats.crit_rate
	enemy.crit_damage = stats.crit_damage
	enemy.resistance = stats.resistance
	enemy.accuracy = stats.accuracy
	enemy.level = level
	enemy.element = element_int
	enemy.type = enemy_type
	
	return enemy

static func _create_territory_enemy(territory: Territory, level: int, enemy_type: String) -> Dictionary:
	"""Create a single territory enemy"""
	var enemy = {}
	
	var element_string = DataLoader.element_int_to_string(territory.element)
	var element_name = _get_element_display_name(element_string)
	
	match enemy_type:
		"boss":
			enemy.name = "%s Overlord" % element_name
		"elite":
			enemy.name = "%s Elite" % element_name
		_:
			enemy.name = "%s Warrior" % element_name
	
	var stats = _calculate_enemy_stats(territory.element, enemy_type, level, territory.tier)
	
	enemy.hp = stats.hp
	enemy.current_hp = stats.hp
	enemy.attack = stats.attack
	enemy.defense = stats.defense
	enemy.speed = stats.speed
	enemy.crit_rate = stats.crit_rate
	enemy.crit_damage = stats.crit_damage
	enemy.resistance = stats.resistance
	enemy.accuracy = stats.accuracy
	enemy.level = level
	enemy.element = territory.element
	enemy.type = enemy_type
	
	return enemy

static func _create_raid_enemy(raid_id: String, difficulty: String, level: int, enemy_type: String) -> Dictionary:
	"""Create a single raid enemy"""
	var enemy = {}
	
	# Raids can have mixed elements - cycle through them
	var elements = [God.ElementType.FIRE, God.ElementType.WATER, God.ElementType.LIGHTNING, God.ElementType.EARTH, God.ElementType.LIGHT, God.ElementType.DARK]
	var element = elements[randi() % elements.size()]
	var element_name = _get_element_display_name(DataLoader.element_int_to_string(element))
	
	match enemy_type:
		"boss":
			enemy.name = "%s Raid Boss" % element_name
		"elite":
			enemy.name = "%s Raid Elite" % element_name
		_:
			enemy.name = "%s Raid Monster" % element_name
	
	var stats = _calculate_enemy_stats(element, enemy_type, level, 4)  # Tier 4 for raids
	
	enemy.hp = stats.hp
	enemy.current_hp = stats.hp
	enemy.attack = stats.attack
	enemy.defense = stats.defense
	enemy.speed = stats.speed
	enemy.crit_rate = stats.crit_rate
	enemy.crit_damage = stats.crit_damage
	enemy.resistance = stats.resistance
	enemy.accuracy = stats.accuracy
	enemy.level = level
	enemy.element = element
	enemy.type = enemy_type
	
	return enemy

static func _get_dungeon_element(dungeon_id: String) -> String:
	"""Get element string from dungeon ID"""
	if dungeon_id.begins_with("fire"):
		return "fire"
	elif dungeon_id.begins_with("water"):
		return "water"
	elif dungeon_id.begins_with("lightning"):
		return "lightning"
	elif dungeon_id.begins_with("earth"):
		return "earth"
	elif dungeon_id.begins_with("light"):
		return "light"
	elif dungeon_id.begins_with("dark"):
		return "dark"
	else:
		return "fire"  # Default

static func _get_dungeon_enemy_level(difficulty: String) -> int:
	"""Get base enemy level for dungeon difficulty"""
	match difficulty:
		"beginner":
			return 15
		"intermediate":
			return 25
		"advanced":
			return 35
		"expert":
			return 45
		"master":
			return 55
		"heroic":
			return 65
		"legendary":
			return 75
		_:
			return 15
