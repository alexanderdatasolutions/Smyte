# scripts/ui/territory/NodeCaptureHandler.gd
# Handles node capture battle flow
extends Node
class_name NodeCaptureHandler

"""
NodeCaptureHandler.gd - Handles territory node capture battles
RULE 2: Single responsibility - ONLY manages node capture flow
RULE 1: Under 500 lines
RULE 5: Uses SystemRegistry for all system access

Responsibilities:
	pass
- Initiate capture battles
- Create battle configs for territory capture
- Handle battle results (victory/defeat)
- Update node contested state
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal capture_initiated(hex_node: Variant)  # HexNode or PvPHexNode (duck typed)
signal capture_succeeded(hex_node: Variant, rewards: Dictionary)
signal capture_failed(hex_node: Variant)

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_capture_node: Variant = null  # HexNode or PvPHexNode (duck typed)
var hex_map_view = null  # Reference to HexMapView for animations
var is_pvp_mode: bool = false  # Track if we're in PvP mode

# System references
var territory_manager = null
var pvp_territory_manager = null  # For PvP hex battles
var collection_manager = null
var battle_coordinator = null
var screen_manager = null
var hex_grid_manager = null
var resource_manager = null

# Last capture rewards (for UI display)
var last_capture_rewards: Dictionary = {}

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if registry:
		territory_manager = registry.get_system("TerritoryManager")
		# Only get from registry if not already set (PvP screen passes its local manager)
		if not pvp_territory_manager:
			pvp_territory_manager = registry.get_system("PvPTerritoryManager")
		collection_manager = registry.get_system("CollectionManager")
		battle_coordinator = registry.get_system("BattleCoordinator")
		screen_manager = registry.get_system("ScreenManager")
		hex_grid_manager = registry.get_system("HexGridManager")
		resource_manager = registry.get_system("ResourceManager")

# ==============================================================================
# PUBLIC API
# ==============================================================================
func initiate_capture(hex_node: Variant, pvp_mode: bool = false) -> bool:
	"""Initiate capture battle for the given node (auto-selects team)
	hex_node: HexNode or PvPHexNode (duck typed)
	pvp_mode: True if this is a PvP territory capture"""
	if not hex_node:
		return false

	is_pvp_mode = pvp_mode

	# Create battle config
	var battle_config = _create_capture_battle_config(hex_node)
	if not battle_config:
		push_error("NodeCaptureHandler: Failed to create battle config")
		return false

	# Connect to battle result signal
	if battle_coordinator:
		if not battle_coordinator.battle_ended.is_connected(_on_capture_battle_ended):
			battle_coordinator.battle_ended.connect(_on_capture_battle_ended)

	# Store node being captured
	current_capture_node = hex_node

	# Emit signal
	capture_initiated.emit(hex_node)

	# Navigate to battle screen FIRST so BattleScreen._ready() runs
	# and can receive the battle_started signal
	if screen_manager:
		if screen_manager.change_screen("battle"):
			# Start the battle after screen is ready
			var battle_screen = screen_manager.get_current_screen()
			if battle_screen and battle_screen.has_method("start_battle"):
				battle_screen.start_battle(battle_config)
			elif battle_coordinator:
				battle_coordinator.start_battle(battle_config)
			return true
		else:
			push_error("NodeCaptureHandler: Failed to change to battle screen")
			return false

	return false

func initiate_capture_with_team(hex_node: Variant, team: Array, pvp_mode: bool = false) -> bool:
	"""Initiate capture battle with user-selected team
	hex_node: HexNode or PvPHexNode (duck typed)
	pvp_mode: True if this is a PvP territory capture"""
	print("[NodeCaptureHandler] initiate_capture_with_team called - pvp_mode: %s, hex_id: %s" % [pvp_mode, hex_node.id if hex_node else "null"])

	if not hex_node:
		return false

	is_pvp_mode = pvp_mode

	# Create battle config with custom team
	var battle_config = _create_capture_battle_config_with_team(hex_node, team)
	if not battle_config:
		push_error("NodeCaptureHandler: Failed to create battle config")
		return false

	# Connect to battle result signal
	print("[NodeCaptureHandler] battle_coordinator: %s" % (battle_coordinator != null))
	if battle_coordinator:
		if not battle_coordinator.battle_ended.is_connected(_on_capture_battle_ended):
			battle_coordinator.battle_ended.connect(_on_capture_battle_ended)
			print("[NodeCaptureHandler] Connected to battle_coordinator.battle_ended signal")

	# Store node being captured
	current_capture_node = hex_node

	# Emit signal
	capture_initiated.emit(hex_node)

	# Navigate to battle screen FIRST so BattleScreen._ready() runs
	# and can receive the battle_started signal
	if screen_manager:
		if screen_manager.change_screen("battle"):
			# Start the battle after screen is ready
			var battle_screen = screen_manager.get_current_screen()
			if battle_screen and battle_screen.has_method("start_battle"):
				battle_screen.start_battle(battle_config)
			elif battle_coordinator:
				battle_coordinator.start_battle(battle_config)
			return true
		else:
			push_error("NodeCaptureHandler: Failed to change to battle screen")
			return false

	return false

# ==============================================================================
# BATTLE CONFIG CREATION
# ==============================================================================
func _create_capture_battle_config(hex_node: Variant) -> BattleConfig:
	"""Create battle configuration for node capture
	hex_node: HexNode or PvPHexNode (duck typed)"""
	# Get player's battle team
	var attacker_gods = _get_player_battle_team()
	if attacker_gods.is_empty():
		push_error("NodeCaptureHandler: No gods available for battle")
		return null

	# Get node defenders
	var defender_gods = _get_node_defenders(hex_node)

	# Create battle config
	var config = BattleConfig.new()
	config.battle_type = BattleConfig.BattleType.TERRITORY
	config.attacker_team = attacker_gods
	config.defender_team = defender_gods
	config.territory_id = hex_node.id
	config.max_turns = 50
	config.allow_auto_battle = true
	config.allow_speed_up = true
	config.victory_condition = "defeat_all_enemies"
	config.defeat_condition = "all_gods_defeated"

	# Pre-calculate capture rewards and set on config so BattleCoordinator can display them
	config.base_rewards = _generate_capture_loot(hex_node)
	# Set loot table for territory tier
	config.loot_table_id = "territory_tier" + str(hex_node.tier)

	# Set PvP metadata if in PvP mode
	if is_pvp_mode:
		config.set_meta("is_pvp_territory", true)
		config.set_meta("pvp_hex_id", hex_node.id)

	# Store config in BattleCoordinator
	if battle_coordinator:
		battle_coordinator.current_battle_config = config

	return config

func _create_capture_battle_config_with_team(hex_node: Variant, team: Array) -> BattleConfig:
	"""Create battle configuration with user-selected team
	hex_node: HexNode or PvPHexNode (duck typed)"""
	# Filter out null values from team
	var filtered_team = []
	for god in team:
		if god != null:
			filtered_team.append(god)

	if filtered_team.is_empty():
		push_error("NodeCaptureHandler: No valid gods in team")
		return null

	# Get node defenders
	var defender_gods = _get_node_defenders(hex_node)

	# Create battle config with selected team
	var config = BattleConfig.new()
	config.battle_type = BattleConfig.BattleType.TERRITORY
	config.attacker_team = filtered_team
	config.defender_team = defender_gods
	config.territory_id = hex_node.id
	config.max_turns = 50
	config.allow_auto_battle = true
	config.allow_speed_up = true
	config.victory_condition = "defeat_all_enemies"
	config.defeat_condition = "all_gods_defeated"

	# Pre-calculate capture rewards and set on config so BattleCoordinator can display them
	config.base_rewards = _generate_capture_loot(hex_node)
	# Set loot table for territory tier
	config.loot_table_id = "territory_tier" + str(hex_node.tier)

	# Set PvP metadata if in PvP mode
	if is_pvp_mode:
		config.set_meta("is_pvp_territory", true)
		config.set_meta("pvp_hex_id", hex_node.id)

	# Store config in BattleCoordinator
	if battle_coordinator:
		battle_coordinator.current_battle_config = config

	return config

func _get_player_battle_team() -> Array:
	"""Get player's gods for battle team (first 4 eligible gods)"""
	if not collection_manager:
		return []

	var all_gods = collection_manager.get_all_gods()
	var battle_team = []

	for god in all_gods:
		# Filter out gods in garrison or working
		if not _is_god_available_for_battle(god.id):
			continue

		battle_team.append(god)
		if battle_team.size() >= 4:
			break

	return battle_team

func _is_god_available_for_battle(god_id: String) -> bool:
	"""Check if god is available (not in garrison or working)"""
	# Check regular territory
	if territory_manager:
		var controlled = territory_manager.get_controlled_nodes()
		for node in controlled:
			if node.garrison.find(god_id) != -1:
				return false
			if node.assigned_workers.find(god_id) != -1:
				return false

	# Check PvP territory
	if pvp_territory_manager:
		var pvp_hexes = pvp_territory_manager.get_my_hexes()
		for pvp_hex in pvp_hexes:
			if pvp_hex.garrison.find(god_id) != -1:
				return false
			if pvp_hex.assigned_workers.find(god_id) != -1:
				return false

	return true

const MAX_DEFENDERS: int = 4

func _get_node_defenders(hex_node: Variant) -> Array:
	"""Get defender gods from the node (max 4)
	hex_node: HexNode or PvPHexNode (duck typed)"""
	if not collection_manager:
		return []

	var defenders = []

	# Determine if node is neutral - check both regular and PvP properties
	var is_neutral = false
	if hex_node.get("controller") != null:
		is_neutral = hex_node.controller == "neutral"
	elif hex_node.get("controller_uid") != null:
		# PvP hex - empty controller_uid means neutral
		is_neutral = hex_node.controller_uid == ""

	# For neutral nodes, use base_defenders/neutral_defenders (PvE enemies from enemies.json)
	if is_neutral:
		# Duck type: HexNode uses base_defenders, PvPHexNode uses neutral_defenders
		var defender_list: Array = []
		if hex_node.get("base_defenders") != null:
			defender_list = hex_node.base_defenders
		elif hex_node.get("neutral_defenders") != null:
			defender_list = hex_node.neutral_defenders

		for defender_data in defender_list:
			if defenders.size() >= MAX_DEFENDERS:
				break
			# defender_data could be a string (enemy name) or a dictionary (serialized enemy)
			if defender_data is String:
				var enemy = _create_enemy_from_config(defender_data, hex_node.tier)
				if enemy:
					defenders.append(enemy)
			elif defender_data is Dictionary:
				# Already serialized enemy data
				defenders.append(defender_data)
	# For enemy nodes, use garrison (player gods)
	else:
		# Check for serialized defense team (PvP) or regular garrison
		var garrison_ids = []
		if hex_node.get("defense_team_serialized") != null and hex_node.defense_team_serialized.size() > 0:
			# PvP hex with serialized team - deserialize it
			for serialized_god in hex_node.defense_team_serialized:
				if defenders.size() >= MAX_DEFENDERS:
					break
				var defender = _deserialize_god(serialized_god)
				if defender:
					defenders.append(defender)
		else:
			# Regular hex with garrison god IDs
			for god_id in hex_node.garrison:
				if defenders.size() >= MAX_DEFENDERS:
					break
				var defender = collection_manager.get_god_by_id(god_id)
				if defender:
					defenders.append(defender)

	# If no defenders found, create a default enemy
	if defenders.is_empty():
		defenders.append(_create_default_defender(hex_node))

	return defenders

func _deserialize_god(serialized: Dictionary) -> God:
	"""Convert serialized god data to actual God object for proper battle integration"""
	if serialized.is_empty():
		return null

	var god := God.new()

	# ID and template_id (important for portraits)
	god.id = serialized.get("id", "deserialized_%d" % randi())
	god.template_id = serialized.get("template_id", serialized.get("id", ""))
	god.name = serialized.get("name", "Unknown God")
	god.level = serialized.get("level", 1)
	god.pantheon = serialized.get("pantheon", "unknown")

	# Handle element (can be int or string)
	var element_val: Variant = serialized.get("element", 0)
	if element_val is int:
		god.element = element_val as God.ElementType
	elif element_val is String:
		god.element = GodFactory.string_to_element(element_val)
	else:
		god.element = God.ElementType.FIRE

	# Handle tier (can be int or string)
	var tier_val: Variant = serialized.get("tier", 0)
	if tier_val is int:
		god.tier = tier_val as God.TierType
	elif tier_val is String:
		god.tier = GodFactory.string_to_tier(tier_val)
	else:
		god.tier = God.TierType.COMMON

	# Stats
	god.base_hp = serialized.get("base_hp", serialized.get("hp", 100))
	god.base_attack = serialized.get("base_attack", serialized.get("attack", 50))
	god.base_defense = serialized.get("base_defense", serialized.get("defense", 50))
	god.base_speed = serialized.get("base_speed", serialized.get("speed", 50))
	god.base_crit_rate = serialized.get("base_crit_rate", God.get_default_crit_rate())
	god.base_crit_damage = serialized.get("base_crit_damage", God.get_default_crit_damage())
	god.base_resistance = serialized.get("base_resistance", God.get_default_resistance())
	god.base_accuracy = serialized.get("base_accuracy", God.get_default_accuracy())

	# Abilities
	god.abilities = serialized.get("abilities", serialized.get("ability_ids", []))
	god.active_abilities = serialized.get("active_abilities", [])
	god.passive_abilities = serialized.get("passive_abilities", [])

	# Leader skill (important for team bonuses)
	god.leader_skill = serialized.get("leader_skill", {})

	# Awakening
	god.is_awakened = serialized.get("is_awakened", false)
	god.awakened_name = serialized.get("awakened_name", god.name)

	return god

func _create_enemy_from_config(enemy_name: String, tier: int) -> Dictionary:
	"""Create an enemy from enemies.json config based on name and tier"""
	# Load enemies config
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	if not config_manager:
		return {}

	var enemies_config = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return {}

	# Search for enemy by name - first in territory_defenders, then in enemy_types
	var enemy_data = {}
	var enemy_element = "neutral"
	var enemy_role = "basic"

	# First: Search territory_defenders (organized by tier/node_type)
	var territory_defenders = enemies_config.get("territory_defenders", {})
	var tier_key = "tier_" + str(tier)
	if territory_defenders.has(tier_key):
		var tier_data = territory_defenders[tier_key]
		for node_type in tier_data:
			if node_type.begins_with("_"):  # Skip metadata keys like _description
				continue
			var node_enemies = tier_data[node_type]
			if node_enemies is Dictionary and node_enemies.has(enemy_name):
				enemy_data = node_enemies[enemy_name]
				enemy_element = enemy_data.get("element", "neutral")
				enemy_role = enemy_data.get("role", "basic")
				break

	# Fallback: Search enemy_types (dungeon enemies)
	if enemy_data.is_empty():
		var enemy_types = enemies_config.get("enemy_types", {})
		for element in enemy_types:
			var roles = enemy_types[element]
			for role in roles:
				if roles[role] is Dictionary and roles[role].has(enemy_name):
					enemy_data = roles[role][enemy_name]
					enemy_element = element
					enemy_role = role
					break
			if not enemy_data.is_empty():
				break

	if enemy_data.is_empty():
		return {}

	# Get role multipliers and base stats from config
	var role_config = enemies_config.get("enemy_roles", {}).get(enemy_role, {})
	var stat_multipliers = role_config.get("stat_multipliers", {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0})
	var base_stats = enemies_config.get("enemy_scaling", {}).get("base_stats", {})
	var per_level = enemies_config.get("enemy_scaling", {}).get("per_level_growth", {})
	var tier_bonus = enemies_config.get("enemy_scaling", {}).get("stat_calculation", {}).get("territory_tier_bonus", {})

	# Calculate level based on tier (T1=8, T2=15, T3=25, T4=35, T5=50)
	# Progression: early tiers are easier, later tiers ramp up
	var level_by_tier: Dictionary = {1: 8, 2: 15, 3: 25, 4: 35, 5: 50}
	var level: int = level_by_tier.get(tier, tier * 8)

	# Calculate stats
	var tier_mult = float(tier_bonus.get(str(tier), 1.0))
	var hp = int((base_stats.get("hp", 100) + level * per_level.get("hp", 6)) * stat_multipliers.get("hp", 1.0) * tier_mult)
	var atk = int((base_stats.get("attack", 45) + level * per_level.get("attack", 2)) * stat_multipliers.get("attack", 1.0) * tier_mult)
	var def = int((base_stats.get("defense", 35) + level * per_level.get("defense", 1)) * stat_multipliers.get("defense", 1.0) * tier_mult)
	var spd = int((base_stats.get("speed", 50) + level * per_level.get("speed", 1)) * stat_multipliers.get("speed", 1.0) * tier_mult)

	return {
		"id": enemy_name.to_lower().replace(" ", "_") + "_" + str(tier),
		"name": enemy_name,
		"level": level,
		"pantheon": enemy_data.get("pantheon", "enemy"),
		"element": enemy_element,
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": enemy_data.get("abilities", [])
	}

func _create_default_defender(hex_node: Variant) -> Dictionary:
	"""Create a default defender based on node tier
	hex_node: HexNode or PvPHexNode (duck typed)"""
	var hp = 120 + (hex_node.tier * 30)  # Tier 1: 150, Tier 2: 180, Tier 3: 210
	var atk = 60 + (hex_node.tier * 10)  # Tier 1: 70, Tier 2: 80, Tier 3: 90
	var def = 70 + (hex_node.tier * 10)  # Tier 1: 80, Tier 2: 90, Tier 3: 100
	var spd = 50 + (hex_node.tier * 5)  # Tier 1: 55, Tier 2: 60, Tier 3: 65

	var defender = {
		"id": "default_defender_" + hex_node.id,
		"name": "Territory Guardian",
		"level": hex_node.tier * 5,
		"pantheon": "neutral",
		"element": "neutral",
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": []
	}
	return defender

# ==============================================================================
# BATTLE RESULT HANDLING
# ==============================================================================
func _on_capture_battle_ended(result: BattleResult) -> void:
	"""Handle capture battle result"""
	print("[NodeCaptureHandler] _on_capture_battle_ended called - victory: %s, is_pvp_mode: %s, has_node: %s" % [result.victory, is_pvp_mode, current_capture_node != null])

	# Disconnect signal
	if battle_coordinator and battle_coordinator.battle_ended.is_connected(_on_capture_battle_ended):
		battle_coordinator.battle_ended.disconnect(_on_capture_battle_ended)

	# Check if victory
	if result.victory and current_capture_node:
		_handle_capture_victory(current_capture_node, result)
	else:
		_handle_capture_defeat()

	# Clear current capture node
	current_capture_node = null

func _handle_capture_victory(hex_node: Variant, result: BattleResult) -> void:
	"""Handle successful capture of node
	hex_node: HexNode or PvPHexNode (duck typed)"""

	if is_pvp_mode:
		# PvP territory capture
		_handle_pvp_capture_victory(hex_node, result)
	else:
		# Regular territory capture
		_handle_regular_capture_victory(hex_node, result)

func _handle_regular_capture_victory(hex_node: Variant, result: BattleResult) -> void:
	"""Handle regular (PvE) territory capture"""
	if not territory_manager or not hex_grid_manager:
		return

	# Get the node from hex grid to update it
	var node = hex_grid_manager.get_node_at(hex_node.coord)
	if node:
		# Mark node as contested (claim after contest period)
		node.is_contested = true
		# Contest period: 5 minutes (300 seconds)
		node.contested_until = Time.get_unix_time_from_system() + 300
		node.controller = "player"  # Mark as contested by player

	# Capture the node in TerritoryManager
	territory_manager.capture_node(hex_node.coord)

	# Use rewards from BattleResult (already awarded by BattleCoordinator)
	last_capture_rewards = result.rewards.duplicate()

	# Play capture animation
	if hex_map_view:
		hex_map_view.play_capture_animation(hex_node)

	# Emit success signal with rewards
	capture_succeeded.emit(hex_node, last_capture_rewards)

	# Show capture notification
	_show_capture_notification(hex_node, last_capture_rewards)

func _handle_pvp_capture_victory(hex_node: Variant, result: BattleResult) -> void:
	"""Handle PvP territory capture"""
	print("[NodeCaptureHandler] _handle_pvp_capture_victory called for hex: %s" % hex_node.id)

	if not pvp_territory_manager:
		push_error("NodeCaptureHandler: PvPTerritoryManager not available for PvP capture")
		return

	print("[NodeCaptureHandler] Calling pvp_territory_manager.process_attack_result")
	# Process the attack result (victory = true)
	pvp_territory_manager.process_attack_result(hex_node.id, true)

	# Use rewards from BattleResult
	last_capture_rewards = result.rewards.duplicate()

	# Play capture animation
	if hex_map_view:
		hex_map_view.play_capture_animation(hex_node)

	# Emit success signal with rewards
	capture_succeeded.emit(hex_node, last_capture_rewards)

	# Show capture notification
	_show_capture_notification(hex_node, last_capture_rewards)

func _handle_capture_defeat() -> void:
	"""Handle failed capture attempt"""
	if current_capture_node:
		capture_failed.emit(current_capture_node)


func _show_capture_notification(hex_node: Variant, rewards: Dictionary) -> void:
	"""Show territory capture notification using NotificationQueue
	hex_node: HexNode or PvPHexNode (duck typed)"""
	var NotificationQueueClass = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		NotificationQueueClass.show_territory(hex_node.name, hex_node.tier, rewards)

# ==============================================================================
# CAPTURE LOOT SYSTEM
# ==============================================================================
func _generate_capture_loot(hex_node: Variant) -> Dictionary:
	"""Generate loot from node's defense_drops based on tier
	hex_node: HexNode or PvPHexNode (duck typed)"""
	var loot: Dictionary = {}

	# Get defense_drops from the node (format: {"resource_id": {"min": X, "max": Y}})
	var defense_drops = hex_node.defense_drops
	if defense_drops.is_empty():
		# Fallback: generate default loot based on tier
		defense_drops = _get_default_defense_drops(hex_node.tier)

	# Roll amounts for each drop
	for resource_id in defense_drops:
		var drop_config = defense_drops[resource_id]
		if drop_config is Dictionary:
			var min_amount = drop_config.get("min", 1)
			var max_amount = drop_config.get("max", 1)
			var amount = randi_range(min_amount, max_amount)
			if amount > 0:
				loot[resource_id] = amount
		elif drop_config is int:
			# Simple format: {"resource_id": amount}
			if drop_config > 0:
				loot[resource_id] = drop_config

	# Add bonus mana based on tier
	var mana_bonus = hex_node.tier * 200
	loot["mana"] = loot.get("mana", 0) + mana_bonus

	return loot

func _get_default_defense_drops(tier: int) -> Dictionary:
	"""Get default defense drops based on tier if none specified"""
	match tier:
		1:
			return {"monster_parts": {"min": 5, "max": 15}}
		2:
			return {"monster_parts": {"min": 10, "max": 25}, "beast_scales": {"min": 3, "max": 8}}
		3:
			return {"monster_parts": {"min": 20, "max": 40}, "beast_scales": {"min": 8, "max": 18}, "elemental_cores": {"min": 2, "max": 6}}
		4:
			return {"dragon_parts": {"min": 5, "max": 15}, "beast_scales": {"min": 15, "max": 35}, "elemental_cores": {"min": 5, "max": 12}}
		_:
			return {"monster_parts": {"min": 5, "max": 15}}

func _award_capture_loot(loot: Dictionary) -> void:
	"""Award loot to player through ResourceManager"""
	if not resource_manager:
		# Try to get resource_manager if not initialized
		var registry = SystemRegistry.get_instance()
		if registry:
			resource_manager = registry.get_system("ResourceManager")

	if not resource_manager:
		push_error("NodeCaptureHandler: ResourceManager not available to award loot")
		return

	for resource_id in loot:
		var amount = loot[resource_id]
		resource_manager.add_resource(resource_id, amount)

func get_last_capture_rewards() -> Dictionary:
	"""Get rewards from last capture (for UI display)"""
	return last_capture_rewards
