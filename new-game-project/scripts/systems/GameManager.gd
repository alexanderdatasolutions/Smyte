# scripts/systems/GameManager.gd
extends Node

signal god_summoned(god)
signal territory_captured(territory)
signal resources_updated()

var player_data
var territories: Array = []

# Timer for passive income
var resource_timer

# System references
var summon_system
var battle_system
var awakening_system
var sacrifice_system  # NEW: Sacrifice system for power-up mechanics
var loot_system  # NEW: Loot system for proper loot.json integration

# Preload the DataLoader class
const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

func _ready():
	print("DEBUG: GameManager._ready() starting...")
	initialize_game()
	print("DEBUG: GameManager._ready() completed")

func initialize_game():
	print("DEBUG: initialize_game() starting...")
	# Create player data
	print("DEBUG: Creating player data...")
	player_data = preload("res://scripts/data/PlayerData.gd").new()
	
	# Initialize systems
	print("DEBUG: Creating systems...")
	summon_system = preload("res://scripts/systems/SummonSystem.gd").new()
	battle_system = preload("res://scripts/systems/BattleManager.gd").new()  # Updated to BattleManager
	awakening_system = preload("res://scripts/systems/AwakeningSystem.gd").new()
	sacrifice_system = preload("res://scripts/systems/SacrificeSystem.gd").new()  # NEW: Sacrifice system
	loot_system = preload("res://scripts/systems/LootSystem.gd").new()  # NEW: Loot system
	print("DEBUG: Adding systems as children...")
	add_child(summon_system)
	add_child(battle_system)
	add_child(awakening_system)
	add_child(sacrifice_system)
	add_child(loot_system)
	
	# Connect system signals
	print("DEBUG: Connecting system signals...")
	summon_system.summon_completed.connect(_on_summon_completed)
	summon_system.summon_failed.connect(_on_summon_failed)
	battle_system.battle_completed.connect(_on_battle_completed)
	awakening_system.awakening_completed.connect(_on_awakening_completed)
	sacrifice_system.sacrifice_completed.connect(_on_sacrifice_completed)
	awakening_system.awakening_failed.connect(_on_awakening_failed)
	
	# Create resource generation timer
	print("DEBUG: Creating resource timer...")
	resource_timer = Timer.new()
	resource_timer.wait_time = 5.0  # 5 seconds = 1 hour in game time (for testing)
	resource_timer.timeout.connect(_on_resource_timer_timeout)
	resource_timer.autostart = true
	add_child(resource_timer)
	
	# Create auto-save timer (every 5 minutes)
	print("DEBUG: Creating auto-save timer...")
	var auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 300.0  # 5 minutes
	auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	auto_save_timer.autostart = true
	add_child(auto_save_timer)
	
	# Initialize territories
	print("DEBUG: Initializing territories...")
	initialize_territories()
	
	# Try to load existing save data first
	print("DEBUG: Loading or creating save data...")
	if not load_game():
		# If no save file exists, give player starter content
		give_starter_gods()
		generate_offline_resources()
		print("Starting new game with initial content")
	
	print("DEBUG: initialize_game() completed")

func give_starter_gods():
	# Give the player a few starting gods for testing using JSON system
	var ares = God.create_from_json("ares")
	var athena = God.create_from_json("athena")
	
	player_data.add_god(ares)
	player_data.add_god(athena)
	
	print("Started with ", player_data.gods.size(), " gods from JSON system")

# Use the proper SummonSystem
func summon_basic() -> bool:
	return summon_system.summon_basic()

func summon_element(element: int) -> bool:
	return summon_system.summon_element(element)

func summon_premium() -> bool:
	return summon_system.summon_premium()

# System signal handlers
func _on_summon_completed(god):
	print("DEBUG: _on_summon_completed signal handler called")
	god_summoned.emit(god)
	print("DEBUG: Emitting resources_updated signal")
	resources_updated.emit()
	# Auto-save after summoning
	save_game()

func _on_summon_failed(reason):
	print("Summon failed: ", reason)

func _on_battle_completed(result):
	print("Battle completed with result: ", result)
	
	# Handle territory progress if this was a territory battle
	if battle_system and battle_system.current_battle_territory and result == battle_system.BattleResult.VICTORY:
		var territory = battle_system.current_battle_territory
		var stage_number = battle_system.current_battle_stage
		
		print("Updating territory progress: %s Stage %d" % [territory.name, stage_number])
		
		# Stage cleared - advance territory progress
		var territory_unlocked = territory.clear_stage(stage_number)
		
		if territory_unlocked:
			# Territory fully unlocked - add to player's controlled territories
			player_data.control_territory(territory.id)
			territory_captured.emit(territory)
			print("Territory %s FULLY UNLOCKED!" % territory.name)
		else:
			print("Stage %d cleared! Progress: %d/%d" % [stage_number, territory.current_stage, territory.max_stages])
		
		# Update resources
		resources_updated.emit()
	
	# Auto-save after battles
	save_game()

func _on_awakening_completed(god):
	print("%s has been awakened to %s!" % [god.name, god.get_display_name()])
	resources_updated.emit()
	# Auto-save after awakening
	save_game()

func _on_awakening_failed(god, reason):
	print("Failed to awaken %s: %s" % [god.name, reason])

func _on_sacrifice_completed(target_god, material_gods, xp_gained):
	print("%s gained %d XP from sacrificing %d gods" % [target_god.name, xp_gained, material_gods.size()])
	resources_updated.emit()
	# Auto-save after sacrifice
	save_game()

# Use BattleSystem for territory attacks
func attack_territory(territory: Territory, attacking_gods: Array) -> bool:
	var result = battle_system.start_territory_battle(attacking_gods, territory)
	# Using enum value directly since it's defined in BattleSystem
	if result == 0:  # VICTORY
		territory.capture_by_player()
		player_data.control_territory(territory.id)
		territory_captured.emit(territory)
		# Auto-save after capturing territory
		save_game()
		return true
	return false

# New territory battle system
func start_territory_assault(territory: Territory):
	# Begin assault on a territory
	if not territory.is_under_assault:
		territory.start_assault()
		print("Started assault on ", territory.name)

func auto_battle_territory(territory: Territory, attacking_gods: Array) -> bool:
	# Simplified auto-battle for territory farming
	var total_power = 0
	for god in attacking_gods:
		total_power += god.get_power_rating()
		# Add element advantage bonus
		if god.element == territory.element:
			total_power += int(god.get_power_rating() * 0.3)
	
	# Calculate enemy power based on territory
	var enemy_power = territory.required_power * 0.8  # Slightly easier than initial requirement
	
	var victory = total_power > enemy_power
	
	# Give experience to gods
	var base_xp = 50 if victory else 20
	for god in attacking_gods:
		var xp_gained = base_xp + randi_range(-5, 15)
		god.add_experience(xp_gained)
	
	# Give resources if victory
	if victory:
		var essence_gained = randi_range(25, 50)
		player_data.add_divine_essence(essence_gained)
		
		# Random crystal drops
		var crystal_drops = randi_range(0, 2)
		for i in range(crystal_drops):
			var element = randi_range(0, 5)
			player_data.add_crystals(element, 1)
		
		resources_updated.emit()
	
	return victory

# Modern reward system using DataLoader
func award_stage_rewards(stage_number: int, territory: Territory, is_final_stage: bool = false) -> Dictionary:
	"""Award stage completion rewards using LootSystem and loot.json"""
	if not loot_system:
		print("ERROR: LootSystem not initialized!")
		return {}
	
	# Get territory element for loot context
	var territory_element = ""
	if territory:
		# Convert territory element enum to string for loot system
		match territory.element:
			Territory.ElementType.FIRE:
				territory_element = "fire"
			Territory.ElementType.WATER:
				territory_element = "water"
			Territory.ElementType.EARTH:
				territory_element = "earth"
			Territory.ElementType.LIGHTNING:
				territory_element = "lightning"
			Territory.ElementType.LIGHT:
				territory_element = "light"
			Territory.ElementType.DARK:
				territory_element = "dark"
	
	var loot_table_name = "boss_stage" if is_final_stage else "stage_victory"
	var awarded_loot = loot_system.award_loot(loot_table_name, stage_number, territory_element)
	
	print("=== STAGE REWARDS (Stage %d) ===" % stage_number)
	for resource_type in awarded_loot:
		print("  %s: %d" % [resource_type.replace("_", " ").capitalize(), awarded_loot[resource_type]])
	
	# Convert to legacy format for BattleManager compatibility
	var rewards_summary = {
		"divine_essence": awarded_loot.get("divine_essence", 0),
		"divine_crystals": awarded_loot.get("divine_crystals", 0), 
		"awakening_stones": awarded_loot.get("awakening_stones", 0),
		"powders": 0,
		"relics": 0,
		"powder_details": {},
		"relic_details": {}
	}
	
	# Process powder details for display
	for resource_type in awarded_loot:
		if resource_type.ends_with("_powder_low") or resource_type.ends_with("_powder_mid") or resource_type.ends_with("_powder_high"):
			rewards_summary.powders += awarded_loot[resource_type]
			rewards_summary.powder_details[resource_type] = awarded_loot[resource_type]
		elif resource_type.ends_with("_relics"):
			rewards_summary.relics += awarded_loot[resource_type]
			rewards_summary.relic_details[resource_type] = awarded_loot[resource_type]
	
	resources_updated.emit()
	return rewards_summary

# Award XP to participating gods (separate method for clarity)
func award_experience_to_gods(xp_amount: int):
	"""Award experience to current battle gods"""
	if battle_system and battle_system.current_battle_gods.size() > 0:
		var xp_per_god = int(float(xp_amount) / float(battle_system.current_battle_gods.size()))
		for god in battle_system.current_battle_gods:
			god.add_experience(xp_per_god)
	
func battle_territory_stage(territory: Territory, stage_number: int, attacking_gods: Array) -> bool:
	# Legacy function - kept for backward compatibility but redirects to new system
	return start_territory_stage_battle(territory, stage_number, attacking_gods)

func start_territory_stage_battle(territory: Territory, stage_number: int, attacking_gods: Array) -> bool:
	# Start a proper battle using the battle system for a territory stage
	print("Starting territory stage battle: %s - Stage %d with %d gods" % [territory.name, stage_number, attacking_gods.size()])
	
	# Prepare gods for battle
	for god in attacking_gods:
		god.prepare_for_battle()
	
	# Set up the battle system for territory assault with stage information
	battle_system.start_territory_assault(attacking_gods, territory, stage_number)
	
	# Return true to indicate battle was started successfully
	# The actual result will be handled asynchronously via _on_battle_completed
	return true

func battle_in_territory(territory: Territory, attacking_gods: Array):
	# Battle in a specific territory for conquest progress
	battle_system.current_territory = territory
	battle_system.start_pve_battle(attacking_gods)

# Use BattleSystem for PvE battles
func start_pve_battle(gods: Array):
	# Don't return the result immediately - let the signal handle it
	battle_system.start_pve_battle(gods)

# Awakening System Methods
func can_awaken_god(god: God) -> Dictionary:
	"""Check if a god can be awakened"""
	return awakening_system.can_awaken_god(god)

func get_awakening_requirements(god: God) -> Dictionary:
	"""Get awakening requirements for a god"""
	return awakening_system.get_awakening_requirements(god)

func attempt_god_awakening(god: God) -> bool:
	"""Try to awaken a god"""
	return awakening_system.attempt_awakening(god, player_data)

func upgrade_god_skill(god: God, skill_index: int) -> bool:
	"""Upgrade a god's skill level"""
	if god.upgrade_skill(skill_index):
		resources_updated.emit()
		save_game()
		return true
	return false

func ascend_god(god: God, new_level: int) -> bool:
	"""Ascend a god to higher tier"""
	if god.ascend(new_level):
		resources_updated.emit()
		save_game()
		return true
	return false

func _on_resource_timer_timeout():
	print("DEBUG: Resource timer timeout - generating resources...")
	generate_resources()
	print("DEBUG: Resource generation completed")

func _on_auto_save_timer_timeout():
	# Periodic auto-save (less frequent, only if there's meaningful progress)
	save_game()
	print("Auto-saved game progress")

func initialize_territories():
	territories.clear()
	
	# Load territory data from JSON
	GameDataLoader.load_all_data()
	var territory_configs = GameDataLoader.get_all_territory_configs()
	
	for config in territory_configs:
		var territory = Territory.new()
		territory.id = config.get("id", "")
		territory.name = config.get("name", "Unknown Territory")
		territory.tier = config.get("tier", 1)
		territory.element = GameDataLoader.element_string_to_int(config.get("element", "fire"))
		territory.required_power = config.get("required_power", 500)
		territory.base_resource_rate = config.get("base_resource_rate", 20)
		territory.max_stages = config.get("max_stages", 10)
		territory.controller = "neutral"
		territory.current_stage = 0
		territory.is_unlocked = false
		
		# Load the full territory data for resource generation
		territory.load_territory_data(config)
		
		territories.append(territory)
		
	print("Initialized ", territories.size(), " territories from JSON data")

func get_territory_by_id(territory_id: String):
	for territory in territories:
		if territory.id == territory_id:
			return territory
	return null

func get_god_by_id(god_id: String):
	return player_data.get_god_by_id(god_id)

func generate_resources():
	"""Summoners War style territory passive income generation using proper integration"""
	print("DEBUG: generate_resources() starting...")
	
	# Safety check - make sure player_data exists
	if not player_data:
		print("ERROR: player_data is null in generate_resources!")
		return
		
	if not player_data.controlled_territories:
		print("DEBUG: No controlled territories, skipping resource generation")
		return
		
	var territories_producing = 0
	var resource_summary = {}
	
	print("DEBUG: Checking controlled territories: ", player_data.controlled_territories.size())
	for territory_id in player_data.controlled_territories:
		print("DEBUG: Processing territory: ", territory_id)
		var territory = get_territory_by_id(territory_id)
		if territory and territory.is_controlled_by_player() and territory.is_unlocked:
			print("DEBUG: Territory is valid and unlocked, collecting resources...")
			# Use Territory class method for resource collection - integrates with loot.json
			var territory_resources = territory.collect_resources()
			
			if territory_resources.size() > 0:
				territories_producing += 1
				
				# Award each resource type to player
				for resource_type in territory_resources:
					var amount = territory_resources[resource_type]
					if amount > 0:
						player_data.add_resource(resource_type, amount)
						resource_summary[resource_type] = resource_summary.get(resource_type, 0) + amount
				
				print("- %s: Generated %s (%d gods assigned)" % [
					territory.name, 
					str(territory_resources),
					territory.stationed_gods.size()
				])
			
			# Also check for auto-collection
			var auto_resources = territory.auto_collect_resources()
			if auto_resources.size() > 0:
				for resource_type in auto_resources:
					var amount = auto_resources[resource_type]
					if amount > 0:
						player_data.add_resource(resource_type, amount)
						resource_summary[resource_type] = resource_summary.get(resource_type, 0) + amount
				
				print("- %s: Auto-collected %s" % [territory.name, str(auto_resources)])
	
	if territories_producing > 0:
		resources_updated.emit()
		print("TERRITORY INCOME: %s from %d territories" % [str(resource_summary), territories_producing])
		print("Current totals - Essence: %d, Crystals: %d" % [
			player_data.divine_essence, player_data.premium_crystals
		])

func calculate_territory_passive_income(territory) -> Dictionary:
	"""Calculate hourly passive income from a territory based on assigned gods"""
	var income = {"divine_essence": 0, "crystals": 0}
	
	# Get base generation rates from territory tier
	var base_rates = get_territory_base_income(territory.tier)
	income = base_rates.duplicate()
	
	# Calculate god bonuses
	var god_multiplier = 1.0
	var stationed_count = 0
	
	# Count stationed gods and calculate bonuses
	for god in territory.stationed_gods:
		if god:
			stationed_count += 1
			
			# Element match bonus
			if god.element == territory.element:
				god_multiplier *= 1.5
			
			# Tier bonus
			match god.tier:
				God.TierType.RARE:
					god_multiplier *= 1.2
				God.TierType.EPIC:
					god_multiplier *= 1.4
				God.TierType.LEGENDARY:
					god_multiplier *= 1.8
			
			# Awakening bonus
			if god.is_awakened:
				god_multiplier *= 1.3
				# Awakened gods produce special materials
				if territory.tier >= 2:
					income["essence_high"] = income.get("essence_high", 0) + 1
	
	# Multiple gods bonus
	match stationed_count:
		2:
			god_multiplier *= 1.3
		3:
			god_multiplier *= 1.6
		4:
			god_multiplier *= 2.0
		5:
			god_multiplier *= 2.5
	
	# Apply multipliers
	income.divine_essence = int(income.divine_essence * god_multiplier)
	income.crystals = int(income.crystals * god_multiplier)
	
	return income

func get_territory_base_income(tier: int) -> Dictionary:
	"""Get base hourly income for territory tier"""
	match tier:
		1:
			return {"divine_essence": 50, "crystals": 1}
		2:
			return {"divine_essence": 120, "crystals": 3, "essence_low": 2}
		3:
			return {"divine_essence": 300, "crystals": 8, "essence_mid": 3, "awakening_stone": 1}
		_:
			return {"divine_essence": 25, "crystals": 0}


func generate_offline_resources():
	var current_time = Time.get_unix_time_from_system()
	var time_passed = current_time - player_data.last_save_time
	var hours_passed = time_passed / 60.0  # 1 minute = 1 hour for quick testing
	
	# Cap offline hours to prevent overflow (max 24 hours)
	hours_passed = min(hours_passed, 24.0)
	
	if hours_passed > 0:
		for territory_id in player_data.controlled_territories:
			var territory = get_territory_by_id(territory_id)
			if territory:
				# Get assigned gods for this territory
				var assigned_gods = []
				for god in player_data.gods:
					if god.stationed_territory == territory_id:
						assigned_gods.append(god)
				
				# Get passive income from loot system
				var passive_income = DataLoader.get_territory_passive_income(territory_id, assigned_gods)
				
				# Apply the time multiplier and add resources with overflow protection
				for resource_type in passive_income.keys():
					var hourly_amount = passive_income[resource_type]
					
					# Use float for calculation to prevent overflow, then cap the result
					var total_amount_float = hours_passed * float(hourly_amount)
					var total_amount = int(min(total_amount_float, 2147483647))  # Cap at max int32 to be safe
					
					if total_amount > 0:
						player_data.add_resource(resource_type, total_amount)
						print("Territory ", territory_id, " generated: ", total_amount, " ", resource_type)
		
		print("Offline generation complete: ", hours_passed, " hours processed")

# Save/Load System
func save_game() -> bool:
	player_data.update_last_save_time()
	
	var save_file = FileAccess.open("user://savegame.dat", FileAccess.WRITE)
	if not save_file:
		print("Error: Could not create save file")
		return false
	
	# Create comprehensive save data
	var save_data = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"player_data": {
			"player_name": player_data.player_name,
			"level": player_data.level,
			"experience": player_data.experience,
			"divine_essence": player_data.divine_essence,
			"crystals": player_data.crystals,
			"premium_crystals": player_data.premium_crystals,
			"awakening_stones": player_data.awakening_stones,
			"summon_tickets": player_data.summon_tickets,
			"ascension_materials": player_data.ascension_materials,
			"total_summons": player_data.total_summons,
			"controlled_territories": player_data.controlled_territories,
			"last_save_time": player_data.last_save_time,
			"powders": player_data.powders,  # FIXED: Save awakening powders
			"relics": player_data.relics      # FIXED: Save pantheon relics
		},
		"gods_data": [],
		"territories_data": []
	}
	
	# Save gods data - only save progress, not base config (comes from JSON)
	for god in player_data.gods:
		var god_data = {
			"id": god.id,  # Essential for reloading from JSON
			"level": god.level,
			"experience": god.experience,
			"stationed_territory": god.stationed_territory
		}
		save_data.gods_data.append(god_data)
	
	# Save territories data
	for territory in territories:
		var territory_data = {
			"id": territory.id,
			"name": territory.name,
			"tier": territory.tier,
			"element": territory.element,
			"controller": territory.controller,
			"current_stage": territory.current_stage,
			"is_unlocked": territory.is_unlocked,
			"stationed_gods": territory.stationed_gods
		}
		save_data.territories_data.append(territory_data)
	
	# Write save data
	var json_string = JSON.stringify(save_data)
	save_file.store_string(json_string)
	save_file.close()
	
	print("Game saved successfully - ", player_data.gods.size(), " gods, ", player_data.divine_essence, " essence")
	return true

func load_game() -> bool:
	var save_file = FileAccess.open("user://savegame.dat", FileAccess.READ)
	if not save_file:
		print("No save file found, starting fresh")
		return false
	
	var save_data_text = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(save_data_text)
	if parse_result != OK:
		print("Error parsing save file: ", json.error_string)
		return false
	
	var save_data = json.get_data()
	
	# Verify save data version
	var version = save_data.get("version", "unknown")
	print("Loading save file version: ", version)
	
	# Load player data
	var player_info = save_data.get("player_data", {})
	player_data.player_name = player_info.get("player_name", "Player")
	player_data.level = player_info.get("level", 1)
	player_data.experience = player_info.get("experience", 0)
	player_data.divine_essence = player_info.get("divine_essence", 1000)
	player_data.crystals = player_info.get("crystals", {})
	player_data.premium_crystals = player_info.get("premium_crystals", 0)
	player_data.awakening_stones = player_info.get("awakening_stones", 0)
	player_data.summon_tickets = player_info.get("summon_tickets", 0)
	player_data.ascension_materials = player_info.get("ascension_materials", 0)
	player_data.total_summons = player_info.get("total_summons", 0)
	player_data.powders = player_info.get("powders", {})  # FIXED: Load awakening powders
	player_data.relics = player_info.get("relics", {})    # FIXED: Load pantheon relics
	player_data.controlled_territories = player_info.get("controlled_territories", [])
	player_data.last_save_time = player_info.get("last_save_time", Time.get_unix_time_from_system())
	
	# Load gods data
	player_data.gods.clear()
	var gods_data = save_data.get("gods_data", [])
	for god_info in gods_data:
		# Create god from JSON config first to get all abilities and base data
		var god = God.create_from_json(god_info.get("id", ""))
		if god == null:
			print("Warning: Could not recreate god with ID: ", god_info.get("id", ""))
			continue
		
		# Override with saved progress data
		god.level = god_info.get("level", 1)
		god.experience = god_info.get("experience", 0)
		god.stationed_territory = god_info.get("stationed_territory", "")
		
		# Initialize battle HP for loaded gods
		god.heal_full()
		player_data.gods.append(god)
	
	# Load territories data
	var territories_data = save_data.get("territories_data", [])
	for territory_info in territories_data:
		var territory = get_territory_by_id(territory_info.get("id", ""))
		if territory:
			territory.controller = territory_info.get("controller", "neutral")
			territory.current_stage = territory_info.get("current_stage", 0)
			territory.is_unlocked = territory_info.get("is_unlocked", false)
			territory.stationed_gods = territory_info.get("stationed_gods", [])
	
	print("Game loaded successfully - ", player_data.gods.size(), " gods, ", player_data.divine_essence, " essence")
	
	# Generate offline resources
	generate_offline_resources()
	
	return true

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

# Territory upgrade cost methods
func can_afford_territory_upgrade(territory: Territory) -> bool:
	var cost = territory.get_upgrade_cost("territory")
	return player_data.can_afford_upgrade_cost(cost)

func spend_territory_upgrade_cost(territory: Territory):
	var cost = territory.get_upgrade_cost("territory")
	for resource_type in cost:
		player_data.add_resource(resource_type, -cost[resource_type])

func can_afford_resource_upgrade(territory: Territory) -> bool:
	var cost = territory.get_upgrade_cost("resource")
	return player_data.can_afford_upgrade_cost(cost)

func spend_resource_upgrade_cost(territory: Territory):
	var cost = territory.get_upgrade_cost("resource")
	for resource_type in cost:
		player_data.add_resource(resource_type, -cost[resource_type])

func can_afford_defense_upgrade(territory: Territory) -> bool:
	var cost = territory.get_upgrade_cost("defense")
	return player_data.can_afford_upgrade_cost(cost)

func spend_defense_upgrade_cost(territory: Territory):
	var cost = territory.get_upgrade_cost("defense")
	for resource_type in cost:
		player_data.add_resource(resource_type, -cost[resource_type])

func can_afford_zone_upgrade(territory: Territory) -> bool:
	var cost = territory.get_upgrade_cost("zone")
	return player_data.can_afford_upgrade_cost(cost)

func spend_zone_upgrade_cost(territory: Territory):
	var cost = territory.get_upgrade_cost("zone")
	for resource_type in cost:
		player_data.add_resource(resource_type, -cost[resource_type])
