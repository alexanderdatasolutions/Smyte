# scripts/data/Territory.gd - Enhanced for Modular Combat System
extends Resource
class_name Territory

enum ElementType { FIRE, WATER, EARTH, LIGHTNING, LIGHT, DARK }

@export var id: String
@export var name: String
@export var tier: int  # 1-3 for MVP
@export var element: ElementType
@export var required_power: int  # Minimum power to attack

# Control and resources
@export var controller: String = ""  # Player ID ("player" or "neutral")
@export var stationed_gods: Array = []  # God IDs
@export var base_resource_rate: int = 10  # Per hour
@export var last_resource_generation: float = 0.0  # Changed to float for precision

# Battle progress system - Summoners War style stages
@export var current_stage: int = 0        # Stages cleared (0-10)
@export var max_stages: int = 10          # Total stages to unlock
@export var is_unlocked: bool = false     # Territory fully cleared and unlocked

# New enhanced features
@export var territory_level: int = 1      # Upgrade level
@export var resource_upgrades: int = 0    # Resource generation upgrades
@export var defense_upgrades: int = 0     # Defense infrastructure upgrades
@export var zone_upgrades: int = 0        # Zone amplification upgrades
@export var max_god_slots: int = 3        # Maximum gods that can be stationed
@export var auto_collection_mode: String = "manual"  # Collection automation
@export var last_collection_time: float = 0.0  # When resources were last collected - changed to float

# Territory data from JSON
var territory_data: Dictionary = {}

# Temporary battle state
var current_battle_stage: int = 1          # Current stage being battled (not saved)

func get_total_defense_power() -> int:
	var base_power = required_power
	var stationed_power = get_stationed_gods_power()
	var upgrade_bonus = defense_upgrades * 0.1
	
	return int(base_power * (1.0 + upgrade_bonus) + stationed_power)

func get_stationed_gods_power() -> int:
	var total = 0
	for god_id in stationed_gods:
		var god = GameManager.get_god_by_id(god_id)
		if god:
			var base_power = god.get_total_power()
			# Element matching bonus
			if god.element == element:
				base_power = int(base_power * 1.2)
			total += base_power
	return total

func get_resource_rate() -> int:
	if not is_controlled_by_player() or not is_unlocked:
		return 0
		
	var base_rate = base_resource_rate
	
	# Upgrade bonuses
	var upgrade_multiplier = 1.0 + (resource_upgrades * 0.08)
	base_rate = int(base_rate * upgrade_multiplier)
	
	# God assignment bonuses
	var god_bonus = get_god_resource_bonus()
	base_rate += god_bonus
	
	# Territory level bonus
	var level_bonus = territory_level * 0.05
	base_rate = int(base_rate * (1.0 + level_bonus))
	
	return base_rate

func get_god_resource_bonus() -> int:
	var bonus = 0
	for god_id in stationed_gods:
		var god = GameManager.get_god_by_id(god_id)
		if god:
			# Base bonus per god
			var god_resource_bonus = base_resource_rate * 0.1
			
			# Element matching bonus
			if god.element == element:
				god_resource_bonus *= 1.3
			
			# Rarity bonus
			match god.tier:
				God.TierType.LEGENDARY:
					god_resource_bonus *= 1.2
				God.TierType.EPIC:
					god_resource_bonus *= 1.1
				
			bonus += int(god_resource_bonus)
	
	return bonus

func can_station_god(god_id: String) -> bool:
	if stationed_gods.size() >= max_god_slots:
		return false
	if stationed_gods.has(god_id):
		return false
	return true

func _find_god_by_id(god_id: String):
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			if god.id == god_id:
				return god
	return null

func is_controlled_by_player() -> bool:
	return controller == "player"

func get_element_name() -> String:
	match element:
		ElementType.FIRE:
			return "Fire"
		ElementType.WATER:
			return "Water"
		ElementType.EARTH:
			return "Earth"
		ElementType.LIGHTNING:
			return "Lightning"
		ElementType.LIGHT:
			return "Light"
		ElementType.DARK:
			return "Dark"
	return "Unknown"

func can_attack(player_power: int) -> bool:
	return player_power >= required_power

func station_god(god_id: String) -> bool:
	if can_station_god(god_id):
		stationed_gods.append(god_id)
		return true
	return false

func remove_stationed_god(god_id: String):
	if stationed_gods.has(god_id):
		stationed_gods.erase(god_id)

func clear_stationed_gods():
	stationed_gods.clear()

# New territory upgrade functions
func can_upgrade_territory() -> bool:
	return territory_level < 15

func upgrade_territory() -> bool:
	if can_upgrade_territory() and GameManager.can_afford_territory_upgrade(self):
		GameManager.spend_territory_upgrade_cost(self)
		territory_level += 1
		return true
	return false

func can_upgrade_resource_generation() -> bool:
	return resource_upgrades < 15

func upgrade_resource_generation() -> bool:
	if can_upgrade_resource_generation() and GameManager.can_afford_resource_upgrade(self):
		GameManager.spend_resource_upgrade_cost(self)
		resource_upgrades += 1
		return true
	return false

func can_upgrade_defense() -> bool:
	return defense_upgrades < 10

func upgrade_defense() -> bool:
	if can_upgrade_defense() and GameManager.can_afford_defense_upgrade(self):
		GameManager.spend_defense_upgrade_cost(self)
		defense_upgrades += 1
		return true
	return false

func can_upgrade_zone_amplification() -> bool:
	return zone_upgrades < 8

func upgrade_zone_amplification() -> bool:
	if can_upgrade_zone_amplification() and GameManager.can_afford_zone_upgrade(self):
		GameManager.spend_zone_upgrade_cost(self)
		zone_upgrades += 1
		return true
	return false

# Resource collection functions
func get_pending_resources() -> Dictionary:
	var current_time = Time.get_unix_time_from_system()
	var time_diff = current_time - last_resource_generation
	var hours_passed = time_diff / 3600.0
	
	# Use DataLoader to get proper resource generation with god bonuses
	var assigned_gods = []
	if GameManager:
		for god_id in stationed_gods:
			var god = GameManager.get_god_by_id(god_id)
			if god:
				assigned_gods.append(god)
	
	var base_generation = DataLoader.get_territory_passive_income(id, assigned_gods)
	var resources = {}
	
	# Calculate resources based on time passed and upgrade bonuses
	for resource_type in base_generation.keys():
		var base_hourly = base_generation[resource_type]
		var upgrade_multiplier = 1.0 + get_resource_upgrade_multiplier()
		var territory_level_bonus = 1.0 + (territory_level - 1) * 0.05
		
		var final_amount = int(base_hourly * hours_passed * upgrade_multiplier * territory_level_bonus)
		if final_amount > 0:
			resources[resource_type] = final_amount
	
	return resources

func get_resource_upgrade_multiplier() -> float:
	return resource_upgrades * 0.08

func collect_resources() -> Dictionary:
	var resources = get_pending_resources()
	last_resource_generation = Time.get_unix_time_from_system()
	return resources

func set_auto_collection_mode(mode: String):
	if mode in ["manual", "hourly", "every_4_hours", "daily"]:
		auto_collection_mode = mode

func should_auto_collect() -> bool:
	if auto_collection_mode == "manual":
		return false
		
	var current_time = Time.get_unix_time_from_system()
	var time_since_last = current_time - last_collection_time
	
	match auto_collection_mode:
		"hourly":
			return time_since_last >= 3600
		"every_4_hours":
			return time_since_last >= 14400
		"daily":
			return time_since_last >= 86400
	
	return false

func auto_collect_resources() -> Dictionary:
	if should_auto_collect():
		var resources = collect_resources()
		last_collection_time = Time.get_unix_time_from_system()
		
		# Apply efficiency modifier
		var efficiency = get_auto_collection_efficiency()
		for resource_type in resources.keys():
			resources[resource_type] = int(resources[resource_type] * efficiency)
		
		return resources
	
	return {}

func get_auto_collection_efficiency() -> float:
	match auto_collection_mode:
		"manual":
			return 1.0
		"hourly":
			return 0.9
		"every_4_hours":
			return 0.95
		"daily":
			return 1.1
	return 1.0

func capture_by_player():
	controller = "player"
	is_unlocked = true
	# Keep the attacking gods stationed
	
func capture_by_neutral():
	controller = "neutral"
	current_stage = 0
	is_unlocked = false
	clear_stationed_gods()

func clear_stage(stage_number: int):
	# Player clears a specific stage
	if stage_number > current_stage:
		current_stage = stage_number
		if current_stage >= max_stages:
			is_unlocked = true
			capture_by_player()
			return true  # Territory unlocked
	return false  # Still need to clear more stages

func reset_progress():
	# Reset if needed (optional - stages usually stay cleared)
	current_stage = 0
	is_unlocked = false

func get_progress_text() -> String:
	if is_controlled_by_player() and is_unlocked:
		return "UNLOCKED"
	elif current_stage > 0:
		return "CLEARED (%d/%d)" % [current_stage, max_stages]
	else:
		return "LOCKED"

func get_capture_progress() -> float:
	return float(current_stage) / float(max_stages)

func get_required_power() -> int:
	# Power requirement scales with stage
	var stage_multiplier = 1.0 + (current_stage * 0.2)
	return int(required_power * stage_multiplier)

func get_current_power() -> int:
	var total = 0
	for god_id in stationed_gods:
		var god = GameManager.get_god_by_id(god_id)
		if god:
			total += god.get_total_power()
	return total

func can_be_attacked() -> bool:
	# Can always attack stages that aren't cleared yet
	return current_stage < max_stages

func get_hourly_resource_rate() -> int:
	return get_resource_rate()

# Combat system integration functions
func get_zone_bonuses_for_combat() -> Array:
	var combat_bonuses = []
	
	if territory_data.has("zone_bonuses") and territory_data["zone_bonuses"].has("passive_effects"):
		var passive_effects = territory_data["zone_bonuses"]["passive_effects"]
		
		for effect in passive_effects:
			if effect.has("combat_system_mapping"):
				var combat_effect = effect["combat_system_mapping"].duplicate()
				
				# Apply zone upgrade bonuses
				if combat_effect.has("multiplier"):
					combat_effect["multiplier"] = combat_effect["multiplier"] * (1.0 + zone_upgrades * 0.12)
				if combat_effect.has("value"):
					combat_effect["value"] = combat_effect["value"] * (1.0 + zone_upgrades * 0.12)
				
				combat_bonuses.append(combat_effect)
	
	return combat_bonuses

func get_enemy_data_for_stage(stage_num: int) -> Dictionary:
	var enemy_data = {}
	
	if territory_data.has("enemy_modifiers") and territory_data["enemy_modifiers"].has("stage_enemies"):
		var stage_enemies = territory_data["enemy_modifiers"]["stage_enemies"]
		var stage_key = str(stage_num)
		
		# Find the right stage range
		for key in stage_enemies.keys():
			if "-" in key:
				var parts = key.split("-")
				var min_stage = int(parts[0])
				var max_stage = int(parts[1])
				if stage_num >= min_stage and stage_num <= max_stage:
					enemy_data = stage_enemies[key]
					break
			elif key == stage_key:
				enemy_data = stage_enemies[key]
				break
	
	return enemy_data

func get_stationed_god_battle_bonuses() -> Dictionary:
	var bonuses = {}
	
	for god_id in stationed_gods:
		var god = GameManager.get_god_by_id(god_id)
		if god:
			# Pre-battle resource blessing
			if not bonuses.has("pre_battle_buffs"):
				bonuses["pre_battle_buffs"] = []
			
			bonuses["pre_battle_buffs"].append({
				"type": "resource_blessing",
				"duration": 3,
				"source_god": god_id
			})
			
			# Territorial knowledge bonus
			if god.element == element:
				bonuses["pre_battle_buffs"].append({
					"type": "territorial_knowledge", 
					"accuracy_bonus": 0.1,
					"crit_bonus": 0.05,
					"source_god": god_id
				})
	
	return bonuses

func apply_stationed_god_experience(battle_result: Dictionary):
	# Give stationed gods some experience when battles happen in their territory
	for god_id in stationed_gods:
		var god = GameManager.get_god_by_id(god_id)
		if god:
			var exp_gain = battle_result.get("base_experience", 100) * 0.1
			
			# Bonus for element matching
			if god.element == element:
				exp_gain *= 1.05
			
			god.gain_experience(int(exp_gain))
			
			# Small chance for skill points
			if randf() < 0.02:
				god.skill_points += 1

# Data initialization
func load_territory_data(data: Dictionary):
	territory_data = data
	
	# Set max god slots from data
	if data.has("resource_generation") and data["resource_generation"].has("god_assignment_slots"):
		max_god_slots = data["resource_generation"]["god_assignment_slots"]
	
	# Set max stages from data
	if data.has("stages") and data["stages"].has("max"):
		max_stages = data["stages"]["max"]

# Utility functions for UI and management
func get_upgrade_cost(upgrade_type: String) -> Dictionary:
	var base_cost = 1000 * tier
	var level_multiplier = 1.0
	
	match upgrade_type:
		"territory":
			level_multiplier = pow(territory_level, 1.5)
		"resource":
			level_multiplier = pow(resource_upgrades + 1, 1.5)
		"defense":
			level_multiplier = pow(defense_upgrades + 1, 1.3) * 2
		"zone":
			level_multiplier = pow(zone_upgrades + 1, 2.0)
	
	var cost = int(base_cost * level_multiplier)
	
	return {
		"gold": cost,
		"divine_essence": int(cost / 10.0)
	}

func get_territory_status_summary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"tier": tier,
		"element": get_element_name(),
		"controller": controller,
		"is_unlocked": is_unlocked,
		"progress": "%d/%d" % [current_stage, max_stages],
		"stationed_gods": stationed_gods.size(),
		"max_gods": max_god_slots,
		"resource_rate": get_resource_rate(),
		"defense_power": get_total_defense_power(),
		"territory_level": territory_level,
		"pending_resources": get_pending_resources()
	}
