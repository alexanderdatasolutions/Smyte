# scripts/ui/pvp_territory/PvPNodeCaptureHandler.gd
# Handles PvP hex capture battle flow
extends RefCounted
class_name PvPNodeCaptureHandler

"""
PvPNodeCaptureHandler - Manages attack/capture battle flow for PvP hexes
RULE 2: Single responsibility - Battle initiation and result processing

Flow:
1. User selects hex and clicks Attack
2. Handler validates attack (via PvPTerritoryManager)
3. Opens team selection (BattleSetupCoordinator)
4. Deserializes defender team
5. Starts battle
6. Processes result
"""

# ==============================================================================
# SIGNALS
# ==============================================================================

signal battle_started(hex_id: String)
signal battle_completed(hex_id: String, victory: bool)
signal capture_success(hex_id: String)
signal capture_failed(hex_id: String)

# ==============================================================================
# STATE
# ==============================================================================

var _territory_manager: PvPTerritoryManager = null
var _map_instance: PvPMapInstance = null
var _current_hex: PvPHexNode = null
var _attacker_team: Array = []


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func initialize(territory_manager: PvPTerritoryManager, map_instance: PvPMapInstance) -> void:
	"""Initialize with manager references"""
	_territory_manager = territory_manager
	_map_instance = map_instance


# ==============================================================================
# ATTACK FLOW
# ==============================================================================

func initiate_attack(hex: PvPHexNode) -> bool:
	"""Start the attack flow for a hex

	Returns true if attack can proceed to team selection.
	"""
	if not _territory_manager:
		push_error("[PvPNodeCaptureHandler] No territory manager")
		return false

	var validation := _territory_manager.can_attack_hex(hex)
	if not validation["can_attack"]:
		push_warning("[PvPNodeCaptureHandler] Cannot attack: %s" % validation.get("reason", "Unknown"))
		return false

	_current_hex = hex

	# Start attack (sets cooldowns)
	if not _territory_manager.start_attack(hex):
		return false

	return true


func get_defender_team(hex: PvPHexNode) -> Array:
	"""Get defender team for battle

	For neutral hexes: Create PvE enemies based on tier
	For enemy hexes: Deserialize their defense team
	"""
	if not hex:
		return _create_pve_defenders(1)

	# Neutral hex = PvE enemies
	if hex.is_neutral():
		return _create_pve_defenders(hex.tier)

	# Enemy hex = deserialize their defense team
	if not _territory_manager:
		return _create_pve_defenders(hex.tier)

	var serialized_team := _territory_manager.get_defense_team_for_hex(hex)
	if serialized_team.is_empty():
		# No defense set, use PvE fallback
		return _create_pve_defenders(hex.tier)

	return _deserialize_defense_team(serialized_team, hex.tier)


func _deserialize_defense_team(serialized_team: Array, fallback_tier: int) -> Array:
	"""Deserialize god data into God objects for battle"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return _create_pve_defenders(fallback_tier)

	var arena_manager = registry.get_system("ArenaManager")
	if arena_manager and arena_manager.has_method("deserialize_god_for_battle"):
		var gods := []
		for god_data: Dictionary in serialized_team:
			var god = arena_manager.deserialize_god_for_battle(god_data)
			if god:
				gods.append(god)
		if not gods.is_empty():
			return gods

	# Fallback: create PvE defenders
	return _create_pve_defenders(fallback_tier)


func _create_pve_defenders(tier: int) -> Array:
	"""Create PvE defenders based on hex tier from enemies.json"""
	var defenders := []
	var num_enemies := mini(tier + 1, 4)  # Tier 1: 2, Tier 2: 3, Tier 3: 4, etc.

	# Get enemy names from enemies.json for this tier
	var enemy_names := _get_tier_enemy_names(tier)

	for i in range(num_enemies):
		var enemy_name: String = enemy_names[i % enemy_names.size()]
		var enemy := _create_enemy_from_config(enemy_name, tier)
		if not enemy.is_empty():
			defenders.append(enemy)
		else:
			# Fallback to default if enemy not found
			defenders.append(_create_default_defender(tier, i))

	return defenders


func _get_tier_enemy_names(tier: int) -> Array:
	"""Get available enemy names for a tier from enemies.json"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return _get_fallback_enemy_names(tier)

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return _get_fallback_enemy_names(tier)

	var enemies_config: Dictionary = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return _get_fallback_enemy_names(tier)

	var territory_defenders: Dictionary = enemies_config.get("territory_defenders", {})
	var tier_key := "tier_" + str(tier)
	if not territory_defenders.has(tier_key):
		return _get_fallback_enemy_names(tier)

	var tier_data: Dictionary = territory_defenders[tier_key]
	var names: Array = []

	# Collect all enemy names from all node types in this tier
	for node_type: String in tier_data:
		if node_type.begins_with("_"):  # Skip metadata keys
			continue
		var node_enemies: Dictionary = tier_data[node_type]
		if node_enemies is Dictionary:
			for enemy_name: String in node_enemies.keys():
				if enemy_name not in names:
					names.append(enemy_name)

	if names.is_empty():
		return _get_fallback_enemy_names(tier)

	return names


func _get_fallback_enemy_names(tier: int) -> Array:
	"""Fallback enemy names if enemies.json fails to load"""
	var names := {
		1: ["Kobold Miner", "Nisse", "Domovoi"],
		2: ["Jorogumo", "Kelpie", "Rusalka"],
		3: ["Oni Brute", "Baba Yaga's Guard", "Berserker"],
		4: ["Typhon Spawn", "Set's Champion", "Jormungandr Scion"],
		5: ["Apep", "Typhon", "Angra Mainyu"]
	}
	return names.get(tier, names[1])


func _create_enemy_from_config(enemy_name: String, tier: int) -> Dictionary:
	"""Create an enemy from enemies.json config based on name and tier"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		return {}

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return {}

	var enemies_config: Dictionary = config_manager._load_json_file("res://data/enemies.json")
	if enemies_config.is_empty():
		return {}

	# Search for enemy by name - first in territory_defenders, then in enemy_types
	var enemy_data: Dictionary = {}
	var enemy_element := "neutral"
	var enemy_role := "basic"

	# First: Search territory_defenders (organized by tier/node_type)
	var territory_defenders: Dictionary = enemies_config.get("territory_defenders", {})
	var tier_key := "tier_" + str(tier)
	if territory_defenders.has(tier_key):
		var tier_data: Dictionary = territory_defenders[tier_key]
		for node_type: String in tier_data:
			if node_type.begins_with("_"):  # Skip metadata keys
				continue
			var node_enemies = tier_data[node_type]
			if node_enemies is Dictionary and node_enemies.has(enemy_name):
				enemy_data = node_enemies[enemy_name]
				enemy_element = enemy_data.get("element", "neutral")
				enemy_role = enemy_data.get("role", "basic")
				break

	# Fallback: Search enemy_types (dungeon enemies)
	if enemy_data.is_empty():
		var enemy_types: Dictionary = enemies_config.get("enemy_types", {})
		for element: String in enemy_types:
			var roles: Dictionary = enemy_types[element]
			for role: String in roles:
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
	var role_config: Dictionary = enemies_config.get("enemy_roles", {}).get(enemy_role, {})
	var stat_multipliers: Dictionary = role_config.get("stat_multipliers", {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0})
	var base_stats: Dictionary = enemies_config.get("enemy_scaling", {}).get("base_stats", {})
	var per_level: Dictionary = enemies_config.get("enemy_scaling", {}).get("per_level_growth", {})
	var tier_bonus: Dictionary = enemies_config.get("enemy_scaling", {}).get("stat_calculation", {}).get("territory_tier_bonus", {})

	# Calculate level based on tier
	var level := tier * 10

	# Calculate stats
	var tier_mult := float(tier_bonus.get(str(tier), 1.0))
	var hp := int((base_stats.get("hp", 100) + level * per_level.get("hp", 6)) * stat_multipliers.get("hp", 1.0) * tier_mult)
	var atk := int((base_stats.get("attack", 45) + level * per_level.get("attack", 2)) * stat_multipliers.get("attack", 1.0) * tier_mult)
	var def := int((base_stats.get("defense", 35) + level * per_level.get("defense", 1)) * stat_multipliers.get("defense", 1.0) * tier_mult)
	var spd := int((base_stats.get("speed", 50) + level * per_level.get("speed", 1)) * stat_multipliers.get("speed", 1.0) * tier_mult)

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


func _create_default_defender(tier: int, index: int) -> Dictionary:
	"""Create a default defender based on tier if enemies.json lookup fails"""
	var level := tier * 10 + index * 2
	var hp := 100 + (tier * 50) + (index * 20)
	var atk := 40 + (tier * 15) + (index * 5)
	var def := 30 + (tier * 12) + (index * 4)
	var spd := 45 + (tier * 8) + (index * 3)

	return {
		"id": "pvp_defender_%d_%d" % [tier, index],
		"name": "Territory Guardian",
		"level": level,
		"pantheon": "enemy",
		"element": "neutral",
		"hp": hp,
		"attack": atk,
		"defense": def,
		"speed": spd,
		"skills": []
	}


func create_battle_config(attacker_team: Array) -> Object:
	"""Create BattleConfig for the PvP battle"""
	_attacker_team = attacker_team

	var registry = SystemRegistry.get_instance()
	if not registry:
		return null

	# Load BattleConfig
	var BattleConfigClass = load("res://scripts/data/BattleConfig.gd")
	if not BattleConfigClass:
		push_error("[PvPNodeCaptureHandler] Could not load BattleConfig")
		return null

	var config = BattleConfigClass.new()

	# Use TERRITORY battle type for PvP territory battles
	config.battle_type = BattleConfigClass.BattleType.TERRITORY
	config.attacker_team = attacker_team
	config.defender_team = get_defender_team(_current_hex)

	# Add PvP context metadata so BattleScreen knows to return to PvP territory
	if config.has_method("set_meta"):
		config.set_meta("pvp_hex_id", _current_hex.id)
		config.set_meta("pvp_defender_uid", _current_hex.controller_uid)
		config.set_meta("is_pvp_territory", true)  # Flag to distinguish from regular territory

	return config


func process_battle_result(result: Dictionary) -> void:
	"""Process the battle result

	Args:
		result: Dictionary with "result" key ("victory" or "defeat")
	"""
	if not _current_hex:
		return

	var victory: bool = result.get("result", "") == "victory"

	# Process in territory manager
	_territory_manager.process_attack_result(_current_hex.id, victory)

	battle_completed.emit(_current_hex.id, victory)

	if victory:
		capture_success.emit(_current_hex.id)
	else:
		capture_failed.emit(_current_hex.id)

	# Clear state
	_current_hex = null
	_attacker_team = []


func get_current_hex() -> PvPHexNode:
	"""Get the hex currently being attacked"""
	return _current_hex


func cancel_attack() -> void:
	"""Cancel current attack (user backed out of team selection)"""
	_current_hex = null
	_attacker_team = []


# ==============================================================================
# HELPERS
# ==============================================================================

func _get_system_registry():
	"""Get SystemRegistry instance - use the global class directly"""
	return SystemRegistry.get_instance()
