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
		print("  %s (Lv.%d) - HP:%d ATK:%d DEF:%d SPD:%d" % [
			enemy.name, enemy.level, enemy.hp, enemy.attack, enemy.defense, enemy.speed
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
	"""Calculate enemy stats using enemies.json structure (reduced for easier difficulty)"""
	# Base stats from enemies.json structure (reduced for easier difficulty)
	var base_hp = 150        # Reduced from 200
	var base_attack = 35     # Reduced from 50  
	var base_defense = 15    # Reduced from 25
	var base_speed = 70
	
	# Per-level growth (slightly reduced)
	var hp_per_level = 20    # Reduced from 25
	var attack_per_level = 4 # Reduced from 6
	var defense_per_level = 2 # Reduced from 3
	var speed_per_level = 2
	
	# Role multipliers based on enemy type
	var role_multipliers = _get_enemy_type_multipliers(enemy_type)
	
	# Territory tier scaling (higher tiers = stronger base stats)
	var tier_multiplier = 1.0 + (tier - 1) * 0.2
	
	# Calculate final stats
	var stats = {}
	stats.hp = int((base_hp + level * hp_per_level) * role_multipliers.hp * tier_multiplier)
	stats.attack = int((base_attack + level * attack_per_level) * role_multipliers.attack * tier_multiplier)
	stats.defense = int((base_defense + level * defense_per_level) * role_multipliers.defense * tier_multiplier)
	stats.speed = int((base_speed + level * speed_per_level) * role_multipliers.speed * tier_multiplier)
	
	return stats

static func _get_enemy_type_multipliers(enemy_type: String) -> Dictionary:
	"""Get stat multipliers for different enemy types"""
	match enemy_type:
		"boss":
			return {"hp": 2.5, "attack": 1.8, "defense": 1.6, "speed": 1.0}
		"elite":
			return {"hp": 1.8, "attack": 1.4, "defense": 1.3, "speed": 1.1}
		"leader":
			return {"hp": 1.4, "attack": 1.2, "defense": 1.1, "speed": 1.2}
		_:  # basic
			return {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0}

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