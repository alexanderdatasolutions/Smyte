# scripts/systems/pvp_territory/PvPTerritoryManager.gd
# Core PvP territory game logic - captures, cooldowns, respawns
extends Node
class_name PvPTerritoryManager

"""
PvPTerritoryManager - Core game logic for PvP hex territories
RULE 2: Single responsibility - Game logic coordination
RULE 1: Under 500 lines

Handles:
- Attack validation and cooldowns
- Capture processing
- Respawn triggering
- Defense team management
"""

# ==============================================================================
# SIGNALS
# ==============================================================================

signal attack_started(hex_id: String, defender_uid: String)
signal attack_completed(hex_id: String, victory: bool)
signal capture_success(hex_id: String)
signal capture_failed(hex_id: String)
signal respawn_triggered(player_uid: String)
signal defense_team_updated(hex_id: String)

# ==============================================================================
# CONSTANTS
# ==============================================================================

const HEX_ATTACK_COOLDOWN := 300.0  # 5 minutes per hex
const PLAYER_ATTACK_COOLDOWN := 60.0  # 1 minute between same-player attacks
const NEUTRAL_CAPTURE_COOLDOWN := 30.0  # Shorter cooldown for neutral hexes

# ==============================================================================
# STATE
# ==============================================================================

var _map_instance: PvPMapInstance = null
var _data_sync: PvPTerritoryDataSync = null
var _current_user_uid: String = ""
var _current_user_name: String = ""

# Per-player attack cooldowns (separate from per-hex cooldowns on nodes)
var _player_attack_cooldowns: Dictionary = {}  # {defender_uid: unix_timestamp}


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null


func initialize(map_instance: PvPMapInstance, data_sync: PvPTerritoryDataSync) -> void:
	"""Initialize manager with map instance and data sync"""
	_map_instance = map_instance
	_data_sync = data_sync

	_current_user_uid = data_sync.get_user_id() if data_sync else ""
	_current_user_name = data_sync.get_display_name() if data_sync else "Player"

	# Connect to map instance signals
	if _map_instance:
		_map_instance.player_eliminated.connect(_on_player_eliminated)


# ==============================================================================
# ATTACK VALIDATION
# ==============================================================================

func can_attack_hex(hex: PvPHexNode) -> Dictionary:
	"""Check if current user can attack a hex

	Returns:
		Dictionary with:
		- can_attack: bool
		- reason: String (if can't attack)
		- cooldown_remaining: float (if on cooldown)
	"""
	if hex == null:
		return {"can_attack": false, "reason": "Invalid hex"}

	# Can't attack your own hex
	if hex.controller_uid == _current_user_uid:
		return {"can_attack": false, "reason": "This is your territory"}

	# Can't attack protected spawn nodes
	if hex.is_spawn_node and not hex.is_capturable:
		return {"can_attack": false, "reason": "Spawn nodes are protected"}

	# Check per-hex cooldown
	if hex.is_on_cooldown_for(_current_user_uid):
		var remaining := hex.get_cooldown_remaining_for(_current_user_uid)
		return {
			"can_attack": false,
			"reason": "Hex on cooldown",
			"cooldown_remaining": remaining
		}

	# Check per-player cooldown (for non-neutral hexes)
	if not hex.is_neutral():
		var defender_uid := hex.controller_uid
		if _is_player_on_cooldown(defender_uid):
			var remaining := _get_player_cooldown_remaining(defender_uid)
			return {
				"can_attack": false,
				"reason": "Recently attacked this player",
				"cooldown_remaining": remaining
			}

	# Must have adjacent hex to attack (expansion rule)
	if not _map_instance.has_adjacent_controlled_hex(hex, _current_user_uid):
		return {"can_attack": false, "reason": "Must expand from adjacent territory"}

	return {"can_attack": true, "reason": ""}


func _is_player_on_cooldown(defender_uid: String) -> bool:
	"""Check if we're on cooldown for attacking a specific player"""
	if not _player_attack_cooldowns.has(defender_uid):
		return false
	var cooldown_until: int = _player_attack_cooldowns[defender_uid]
	return Time.get_unix_time_from_system() < cooldown_until


func _get_player_cooldown_remaining(defender_uid: String) -> float:
	"""Get remaining player cooldown seconds"""
	if not _player_attack_cooldowns.has(defender_uid):
		return 0.0
	var cooldown_until: int = _player_attack_cooldowns[defender_uid]
	var remaining := float(cooldown_until) - Time.get_unix_time_from_system()
	return maxf(0.0, remaining)


# ==============================================================================
# ATTACK EXECUTION
# ==============================================================================

func start_attack(hex: PvPHexNode) -> bool:
	"""Start an attack on a hex

	This sets cooldowns and emits attack_started signal.
	The UI should then initiate the battle via BattleSetupCoordinator.

	Returns true if attack can proceed.
	"""
	var validation: Dictionary = can_attack_hex(hex)
	if not validation["can_attack"]:
		return false

	# Set cooldowns immediately (even if attack fails)
	_set_attack_cooldowns(hex)

	attack_started.emit(hex.id, hex.controller_uid)
	return true


func _set_attack_cooldowns(hex: PvPHexNode) -> void:
	"""Set all relevant cooldowns for an attack"""
	var cooldown_duration := HEX_ATTACK_COOLDOWN
	if hex.is_neutral():
		cooldown_duration = NEUTRAL_CAPTURE_COOLDOWN

	# Set per-hex cooldown
	hex.set_attack_cooldown(_current_user_uid, cooldown_duration)

	# Set per-player cooldown (for non-neutral)
	if not hex.is_neutral():
		var cooldown_until := int(Time.get_unix_time_from_system() + PLAYER_ATTACK_COOLDOWN)
		_player_attack_cooldowns[hex.controller_uid] = cooldown_until


func process_attack_result(hex_id: String, victory: bool) -> void:
	"""Process the result of an attack battle

	Args:
		hex_id: The hex that was attacked
		victory: True if attacker won
	"""
	var hex: PvPHexNode = _map_instance.get_hex(hex_id)
	if hex == null:
		return

	if victory:
		_process_capture(hex)
		capture_success.emit(hex_id)
	else:
		capture_failed.emit(hex_id)

	attack_completed.emit(hex_id, victory)


func _process_capture(hex: PvPHexNode) -> void:
	"""Process successful hex capture"""
	var old_owner: String = hex.controller_uid

	# Update local state
	_map_instance.process_capture(hex.id, _current_user_uid, _current_user_name)

	# Sync to Firebase
	if _data_sync and _data_sync.is_ready():
		_data_sync.update_hex_capture(hex.id, _current_user_uid, _current_user_name)


# ==============================================================================
# DEFENSE TEAM MANAGEMENT
# ==============================================================================

func get_defense_team_for_hex(hex: PvPHexNode) -> Array:
	"""Get the defense team for a hex (for battle setup)

	Priority:
	1. Per-hex defense team
	2. Owner's arena defense team (fallback)
	3. Neutral defenders (for unclaimed hexes)
	"""
	if hex.is_neutral():
		return hex.neutral_defenders

	if not hex.defense_team_serialized.is_empty():
		return hex.defense_team_serialized

	# Fallback: try to get player's arena defense
	return _get_player_arena_defense(hex.controller_uid)


func _get_player_arena_defense(_player_uid: String) -> Array:
	"""Get a player's arena defense team as fallback"""
	var system_registry: Variant = _get_system_registry()
	if not system_registry:
		return []

	var arena_manager: Variant = system_registry.get_system("ArenaManager")
	if not arena_manager:
		return []

	# This would need the arena manager to expose opponent data
	# For now, return empty and rely on per-hex defense
	return []


func update_hex_defense(hex_id: String, team: Array) -> void:
	"""Update defense team for a hex owned by current user

	Args:
		hex_id: The hex to update
		team: Array of God objects to serialize
	"""
	var hex: PvPHexNode = _map_instance.get_hex(hex_id)
	if hex == null:
		return

	# Verify ownership
	if hex.controller_uid != _current_user_uid:
		push_warning("[PvPTerritoryManager] Cannot update defense for hex you don't own")
		return

	# Serialize team
	var serialized_team: Array = _serialize_defense_team(team)
	var defense_power: int = _calculate_team_power(serialized_team)

	# Update local state
	hex.defense_team_serialized = serialized_team
	hex.defense_power = defense_power
	hex.garrison_god_ids.clear()
	for god in team:
		if god and god.id:
			hex.garrison_god_ids.append(god.id)

	# Sync to Firebase
	if _data_sync and _data_sync.is_ready():
		_data_sync.update_hex_defense(hex_id, serialized_team, defense_power)

	defense_team_updated.emit(hex_id)


func _serialize_defense_team(team: Array) -> Array:
	"""Serialize god objects for storage

	Uses ArenaManager's serialization format for compatibility.
	"""
	var system_registry: Variant = _get_system_registry()
	if not system_registry:
		return []

	var arena_manager: Variant = system_registry.get_system("ArenaManager")
	if arena_manager and arena_manager.has_method("_serialize_god_for_pvp"):
		var serialized: Array = []
		for god: Variant in team:
			if god:
				serialized.append(arena_manager._serialize_god_for_pvp(god))
		return serialized

	# Fallback: basic serialization
	var serialized: Array = []
	for god: Variant in team:
		if god:
			serialized.append({
				"god_id": god.id,
				"name": god.name,
				"level": god.level,
				"base_hp": god.base_hp,
				"base_attack": god.base_attack,
				"base_defense": god.base_defense,
				"base_speed": god.base_speed
			})
	return serialized


func _calculate_team_power(serialized_team: Array) -> int:
	"""Calculate combat power from serialized team"""
	var power: int = 0
	for god_data: Dictionary in serialized_team:
		power += god_data.get("base_hp", 0) / 10
		power += god_data.get("base_attack", 0)
		power += god_data.get("base_defense", 0)
		power += god_data.get("base_speed", 0) * 2
		power += god_data.get("level", 1) * 100
	return power


# ==============================================================================
# RESPAWN
# ==============================================================================

func _on_player_eliminated(player_uid: String) -> void:
	"""Handle player elimination"""
	if player_uid == _current_user_uid:
		_trigger_respawn()


func _trigger_respawn() -> void:
	"""Trigger respawn for current user"""
	var hexes: Dictionary = {}
	for hex: PvPHexNode in _map_instance.get_all_hexes():
		hexes[hex.id] = hex

	var respawn_result: Dictionary = PvPSpawnManager.execute_respawn(
		_current_user_uid,
		_current_user_name,
		hexes,
		_map_instance.current_max_ring
	)

	if respawn_result["success"]:
		var spawn_node: PvPHexNode = respawn_result["spawn_node"]
		var starter_hexes: Array = respawn_result["starter_hexes"]
		var expansion_hexes: Array = respawn_result["expansion_hexes"]

		# Update local state
		_map_instance.process_respawn(_current_user_uid, spawn_node, starter_hexes)

		# Add any expansion hexes
		for hex: PvPHexNode in expansion_hexes:
			_map_instance.add_hex(hex)

		# Update max ring if expanded
		if respawn_result["new_max_ring"] > _map_instance.current_max_ring:
			_map_instance.current_max_ring = respawn_result["new_max_ring"]

		respawn_triggered.emit(_current_user_uid)


# ==============================================================================
# QUERIES
# ==============================================================================

func get_attackable_hexes() -> Array[PvPHexNode]:
	"""Get all hexes the current user can attack"""
	var result: Array[PvPHexNode] = []

	for hex: PvPHexNode in _map_instance.get_all_hexes():
		var validation: Dictionary = can_attack_hex(hex)
		if validation["can_attack"]:
			result.append(hex)

	return result


func get_my_hexes_needing_defense() -> Array[PvPHexNode]:
	"""Get player's hexes without defense teams set"""
	var result: Array[PvPHexNode] = []

	for hex: PvPHexNode in _map_instance.get_player_hexes(_current_user_uid):
		if not hex.has_defense_team() and hex.is_capturable:
			result.append(hex)

	return result


func get_current_user_uid() -> String:
	return _current_user_uid
