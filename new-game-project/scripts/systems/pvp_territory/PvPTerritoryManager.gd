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
		print("[PvPTerritoryManager] Can't attack %s - it's yours" % hex.id)
		return {"can_attack": false, "reason": "This is your territory"}

	# Can't attack protected spawn nodes
	if hex.is_spawn_node and not hex.is_capturable:
		print("[PvPTerritoryManager] Can't attack %s - protected spawn" % hex.id)
		return {"can_attack": false, "reason": "Spawn nodes are protected"}

	# Check per-hex cooldown
	if hex.is_on_cooldown_for(_current_user_uid):
		var remaining := hex.get_cooldown_remaining_for(_current_user_uid)
		print("[PvPTerritoryManager] Can't attack %s - hex cooldown %.1fs" % [hex.id, remaining])
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
			print("[PvPTerritoryManager] Can't attack %s - player cooldown %.1fs" % [hex.id, remaining])
			return {
				"can_attack": false,
				"reason": "Recently attacked this player",
				"cooldown_remaining": remaining
			}

	# Must have adjacent hex to attack (expansion rule)
	if not _map_instance or not _map_instance.has_adjacent_controlled_hex(hex, _current_user_uid):
		print("[PvPTerritoryManager] Can't attack %s - no adjacent territory (user: %s)" % [hex.id, _current_user_uid])
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
	print("[PvPTerritoryManager] process_attack_result called - hex_id: %s, victory: %s" % [hex_id, victory])

	if not _map_instance:
		push_error("[PvPTerritoryManager] _map_instance is null!")
		return
	var hex: PvPHexNode = _map_instance.get_hex(hex_id)
	if hex == null:
		push_error("[PvPTerritoryManager] Hex not found: %s" % hex_id)
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

	print("[PvPTerritoryManager] _process_capture - hex: %s, new_owner: %s (%s)" % [hex.id, _current_user_uid, _current_user_name])

	# Update local state
	_map_instance.process_capture(hex.id, _current_user_uid, _current_user_name)

	# Sync to Firebase with real-time update
	if _data_sync:
		if _data_sync.is_ready():
			_data_sync.update_hex_capture_realtime(hex.id, _current_user_uid, _current_user_name)
		else:
			# Test mode - just log
			print("PvPTerritoryManager: Captured %s (test mode)" % hex.id)

	# Check if match ended (only one player remains)
	check_match_end()


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
	if not _map_instance:
		return
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
	if not _map_instance:
		return

	var hexes: Dictionary = {}
	for hex: PvPHexNode in _map_instance.get_all_hexes():
		hexes[hex.id] = hex

	var respawn_result: Dictionary = PvPSpawnManager.execute_respawn(
		_current_user_uid,
		_current_user_name,
		hexes,
		_map_instance.current_max_ring
	)

	if not respawn_result.get("success", false):
		return

	var spawn_node: PvPHexNode = respawn_result.get("spawn_node")
	var starter_hexes: Array = respawn_result.get("starter_hexes", [])
	var expansion_hexes: Array = respawn_result.get("expansion_hexes", [])

	if not spawn_node:
		return

	# Update local state
	_map_instance.process_respawn(_current_user_uid, spawn_node, starter_hexes)

	# Add any expansion hexes
	for hex: PvPHexNode in expansion_hexes:
		_map_instance.add_hex(hex)

	# Update max ring if expanded
	var new_max_ring: int = respawn_result.get("new_max_ring", _map_instance.current_max_ring)
	if new_max_ring > _map_instance.current_max_ring:
		_map_instance.current_max_ring = new_max_ring

	respawn_triggered.emit(_current_user_uid)


# ==============================================================================
# QUERIES
# ==============================================================================

func get_attackable_hexes() -> Array[PvPHexNode]:
	"""Get all hexes the current user can attack"""
	var result: Array[PvPHexNode] = []
	if not _map_instance:
		return result

	for hex: PvPHexNode in _map_instance.get_all_hexes():
		var validation: Dictionary = can_attack_hex(hex)
		if validation.get("can_attack", false):
			result.append(hex)

	return result


func get_my_hexes_needing_defense() -> Array[PvPHexNode]:
	"""Get player's hexes without defense teams set"""
	var result: Array[PvPHexNode] = []
	if not _map_instance:
		return result

	for hex: PvPHexNode in _map_instance.get_player_hexes(_current_user_uid):
		if not hex.has_defense_team() and hex.is_capturable:
			result.append(hex)

	return result


func get_my_hexes() -> Array[PvPHexNode]:
	"""Get all hexes controlled by current player"""
	if not _map_instance:
		return []
	return _map_instance.get_my_hexes()


func get_current_user_uid() -> String:
	return _current_user_uid


# ==============================================================================
# MATCH END LOGIC
# ==============================================================================

signal match_ended(winner_uid: String, winner_name: String, is_current_user_winner: bool)

var _match_ended: bool = false


func check_match_end() -> void:
	"""Check if match has ended (only one player with territory remaining)"""
	if _match_ended:
		return

	if not _map_instance:
		return

	var active_players: Array = _get_active_players()

	# Match ends when only 1 player remains with territory
	if active_players.size() <= 1:
		var winner_uid: String = ""
		var winner_name: String = ""

		if active_players.size() == 1:
			winner_uid = active_players[0].get("uid", "")
			winner_name = active_players[0].get("name", "Unknown")
		else:
			# Shouldn't happen, but handle no winners case
			winner_name = "No one"

		_end_match(winner_uid, winner_name)


func _get_active_players() -> Array:
	"""Get list of players who still have territory"""
	var active: Array = []
	var player_hex_counts: Dictionary = {}

	if not _map_instance:
		return active

	# Count hexes per player
	for hex: PvPHexNode in _map_instance.get_all_hexes():
		if hex.controller_uid.is_empty():
			continue
		if not player_hex_counts.has(hex.controller_uid):
			player_hex_counts[hex.controller_uid] = 0
		player_hex_counts[hex.controller_uid] += 1

	# Get players with at least 1 hex
	for player: Dictionary in _map_instance.get_all_players():
		var uid: String = player.get("player_uid", player.get("uid", ""))
		if player_hex_counts.get(uid, 0) > 0:
			active.append({
				"uid": uid,
				"name": player.get("display_name", "Unknown"),
				"hex_count": player_hex_counts[uid]
			})

	return active


func _end_match(winner_uid: String, winner_name: String) -> void:
	"""Process match end"""
	_match_ended = true

	var is_winner: bool = winner_uid == _current_user_uid

	print("PvPTerritoryManager: Match ended! Winner: %s (%s)" % [winner_name, winner_uid])

	# Award rewards
	_award_match_rewards(is_winner, winner_uid)

	# Update match status in Firebase
	_update_match_status_ended(winner_uid)

	# Emit signal for UI
	match_ended.emit(winner_uid, winner_name, is_winner)


func _award_match_rewards(is_winner: bool, winner_uid: String) -> void:
	"""Award rewards based on match performance"""
	var system_registry: Variant = _get_system_registry()
	if not system_registry:
		return

	var resource_manager: Variant = system_registry.get_system("ResourceManager")
	var event_bus: Variant = system_registry.get_system("EventBus")
	if not resource_manager:
		return

	# Calculate rewards based on placement
	var my_hex_count: int = 0
	var my_rank: int = 1

	if _map_instance:
		my_hex_count = _map_instance.get_my_hex_count()
		my_rank = _map_instance.get_my_rank()

	# Base reward: participation + territory held
	var crystal_reward: int = 50 + (my_hex_count * 5)

	# Placement bonus
	var placement_bonus: Dictionary = {
		1: 500,  # Winner
		2: 250,
		3: 150,
		4: 100
	}
	crystal_reward += placement_bonus.get(my_rank, 50)

	# Victory bonus
	if is_winner:
		crystal_reward += 200

	# Award resources
	if resource_manager.has_method("add_resource"):
		resource_manager.add_resource("divine_crystals", crystal_reward)

	# Show notification
	if event_bus and event_bus.has_method("emit_notification"):
		var msg: String = ""
		if is_winner:
			msg = "🏆 VICTORY! +%d Divine Crystals" % crystal_reward
			event_bus.emit_notification(msg, "success", 5.0)
		else:
			msg = "Match ended (Rank #%d) +%d Divine Crystals" % [my_rank, crystal_reward]
			event_bus.emit_notification(msg, "info", 4.0)


func _update_match_status_ended(winner_uid: String) -> void:
	"""Update match status to ended in Firebase"""
	if not _data_sync or not _data_sync.is_ready():
		return

	# This would update the pvp_maps document status to "ended"
	# For now, just log it - full implementation depends on Firebase structure
	print("PvPTerritoryManager: Would update match status to ended with winner: %s" % winner_uid)


func is_match_ended() -> bool:
	"""Check if current match has ended"""
	return _match_ended


func get_match_status() -> Dictionary:
	"""Get current match status info"""
	var active_players := _get_active_players()

	return {
		"ended": _match_ended,
		"active_player_count": active_players.size(),
		"active_players": active_players,
		"current_user_rank": _map_instance.get_my_rank() if _map_instance else 0,
		"current_user_hexes": _map_instance.get_my_hex_count() if _map_instance else 0
	}
