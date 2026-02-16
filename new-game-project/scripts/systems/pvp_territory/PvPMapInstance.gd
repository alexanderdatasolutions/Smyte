# scripts/systems/pvp_territory/PvPMapInstance.gd
# Local state manager for an active PvP map session
extends RefCounted
class_name PvPMapInstance

"""
PvPMapInstance - Manages local state for a single PvP map session
RULE 2: Single responsibility - ONLY manages map instance state
RULE 1: Under 500 lines

Holds all hex nodes and player data for the current map.
Receives updates from PvPTerritoryDataSync and provides queries.
"""

# ==============================================================================
# SIGNALS
# ==============================================================================

signal hex_updated(hex_id: String, hex: PvPHexNode)
signal hex_captured(hex_id: String, old_owner: String, new_owner: String)
signal player_joined(player_uid: String, player_name: String)
signal player_eliminated(player_uid: String)
signal player_respawned(player_uid: String)
signal leaderboard_changed()

# ==============================================================================
# STATE
# ==============================================================================

var map_id: String = ""
var created_at: int = 0
var next_reset: int = 0
var current_max_ring: int = 3

var hexes: Dictionary = {}  # String -> PvPHexNode
var players: Dictionary = {}  # uid -> player data dict

var current_user_uid: String = ""

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func initialize(map_data: Dictionary, user_uid: String) -> void:
	"""Initialize instance from map data

	Args:
		map_data: Dictionary with hexes, players, map_id
		user_uid: Current user's Firebase UID
	"""
	map_id = map_data.get("map_id", "")
	current_user_uid = user_uid

	# Load hexes
	var hex_data: Dictionary = map_data.get("hexes", {})
	for hex_id: String in hex_data:
		var hex = hex_data[hex_id]
		if hex is PvPHexNode:
			hexes[hex_id] = hex
		elif hex is Dictionary:
			hexes[hex_id] = PvPHexNode.from_dict(hex)

	# Load players
	var player_list: Array = map_data.get("players", [])
	for player_data: Dictionary in player_list:
		var uid: String = player_data.get("player_uid", "")
		if not uid.is_empty():
			players[uid] = player_data

	# Extract map metadata
	created_at = map_data.get("created_at", 0)
	next_reset = map_data.get("next_reset", 0)
	current_max_ring = map_data.get("current_max_ring", 3)


func initialize_offline() -> void:
	"""Initialize with mock data for offline testing"""
	var mock_map := PvPMapGenerator.generate_initial_map()
	hexes = mock_map["hexes"]
	current_max_ring = mock_map["config"]["current_max_ring"]
	created_at = mock_map["config"]["created_at"]
	next_reset = created_at + (7 * 86400)


# ==============================================================================
# HEX QUERIES
# ==============================================================================

func get_hex(hex_id: String) -> PvPHexNode:
	"""Get hex by ID"""
	return hexes.get(hex_id)


func get_hex_at(coord: HexCoord) -> PvPHexNode:
	"""Get hex at coordinate"""
	var hex_id := PvPHexNode.coord_to_id(coord.q, coord.r)
	return hexes.get(hex_id)


func get_hex_at_qr(q: int, r: int) -> PvPHexNode:
	"""Get hex at q,r coordinates"""
	var hex_id := PvPHexNode.coord_to_id(q, r)
	return hexes.get(hex_id)


func get_all_hexes() -> Array[PvPHexNode]:
	"""Get all hexes as array"""
	var result: Array[PvPHexNode] = []
	for hex: PvPHexNode in hexes.values():
		result.append(hex)
	return result


func get_player_hexes(player_uid: String) -> Array[PvPHexNode]:
	"""Get all hexes controlled by a player"""
	var result: Array[PvPHexNode] = []
	for hex: PvPHexNode in hexes.values():
		if hex.controller_uid == player_uid:
			result.append(hex)
	return result


func get_neutral_hexes() -> Array[PvPHexNode]:
	"""Get all uncontrolled hexes"""
	var result: Array[PvPHexNode] = []
	for hex: PvPHexNode in hexes.values():
		if hex.is_neutral():
			result.append(hex)
	return result


func get_objective_hexes() -> Array[PvPHexNode]:
	"""Get all objective hexes"""
	var result: Array[PvPHexNode] = []
	for hex: PvPHexNode in hexes.values():
		if hex.is_objective:
			result.append(hex)
	return result


func get_adjacent_hexes(hex: PvPHexNode) -> Array[PvPHexNode]:
	"""Get all adjacent hexes to a given hex"""
	var result: Array[PvPHexNode] = []
	if hex.coord == null:
		return result

	var neighbors := HexRingGenerator.get_neighbors(Vector2i(hex.coord.q, hex.coord.r))
	for neighbor: Vector2i in neighbors:
		var neighbor_hex := get_hex_at_qr(neighbor.x, neighbor.y)
		if neighbor_hex:
			result.append(neighbor_hex)

	return result


func has_adjacent_controlled_hex(hex: PvPHexNode, player_uid: String) -> bool:
	"""Check if player has an adjacent hex to the target"""
	var adjacent := get_adjacent_hexes(hex)
	for adj_hex: PvPHexNode in adjacent:
		if adj_hex.controller_uid == player_uid:
			return true
	return false


# ==============================================================================
# PLAYER QUERIES
# ==============================================================================

func get_player_data(player_uid: String) -> Dictionary:
	"""Get player data by UID"""
	return players.get(player_uid, {})


func get_all_players() -> Array:
	"""Get all player data as array"""
	return players.values()


func get_player_count() -> int:
	"""Get number of players in map"""
	return players.size()


func get_my_hexes() -> Array[PvPHexNode]:
	"""Get current user's hexes"""
	return get_player_hexes(current_user_uid)


func get_my_hex_count() -> int:
	"""Get current user's hex count"""
	return get_player_hexes(current_user_uid).size()


# ==============================================================================
# LEADERBOARD
# ==============================================================================

func get_leaderboard() -> Array[Dictionary]:
	"""Get sorted leaderboard of players

	Returns array of dictionaries with:
	- uid: String
	- display_name: String
	- hex_count: int
	- objective_score: int
	- rank: int
	"""
	var entries: Array[Dictionary] = []

	for uid: String in players:
		var player_data: Dictionary = players[uid]
		var hex_count := get_player_hexes(uid).size()
		var objective_score := PvPMapGenerator.get_player_objective_score(uid, hexes)

		entries.append({
			"uid": uid,
			"display_name": player_data.get("display_name", "Unknown"),
			"hex_count": hex_count,
			"objective_score": objective_score,
			"total_score": hex_count + (objective_score * 2),
			"is_current_user": uid == current_user_uid
		})

	# Sort by total score descending
	entries.sort_custom(func(a, b): return a["total_score"] > b["total_score"])

	# Assign ranks
	for i in range(entries.size()):
		entries[i]["rank"] = i + 1

	return entries


func get_my_rank() -> int:
	"""Get current user's rank"""
	var leaderboard := get_leaderboard()
	for entry: Dictionary in leaderboard:
		if entry["uid"] == current_user_uid:
			return entry["rank"]
	return 0


# ==============================================================================
# STATE UPDATES
# ==============================================================================

func update_hex(hex: PvPHexNode) -> void:
	"""Update a hex in local state"""
	var old_hex = hexes.get(hex.id)
	var old_owner: String = old_hex.controller_uid if old_hex else ""

	hexes[hex.id] = hex
	hex_updated.emit(hex.id, hex)

	if old_owner != hex.controller_uid:
		hex_captured.emit(hex.id, old_owner, hex.controller_uid)
		leaderboard_changed.emit()

		# Check if old owner was eliminated
		if not old_owner.is_empty():
			if PvPSpawnManager.check_needs_respawn(old_owner, hexes):
				player_eliminated.emit(old_owner)


func add_hex(hex: PvPHexNode) -> void:
	"""Add a new hex to the map (expansion)"""
	hexes[hex.id] = hex
	hex_updated.emit(hex.id, hex)


func update_player(player_uid: String, data: Dictionary) -> void:
	"""Update player data"""
	var is_new := not players.has(player_uid)
	players[player_uid] = data

	if is_new:
		player_joined.emit(player_uid, data.get("display_name", "Unknown"))
		leaderboard_changed.emit()


func process_capture(hex_id: String, new_owner_uid: String, new_owner_name: String) -> void:
	"""Process a hex capture"""
	var hex := get_hex(hex_id)
	if hex == null:
		return

	var old_owner := hex.controller_uid

	hex.controller_uid = new_owner_uid
	hex.controller_display_name = new_owner_name
	hex.last_captured_at = Time.get_unix_time_from_system()
	hex.total_captures += 1
	hex.defense_team_serialized = []  # Clear old defense
	hex.defense_power = 0

	hex_updated.emit(hex_id, hex)
	hex_captured.emit(hex_id, old_owner, new_owner_uid)
	leaderboard_changed.emit()

	# Check if old owner was eliminated
	if not old_owner.is_empty():
		if PvPSpawnManager.check_needs_respawn(old_owner, hexes):
			player_eliminated.emit(old_owner)


func process_respawn(player_uid: String, spawn_node: PvPHexNode, starter_hexes: Array) -> void:
	"""Process a player respawn"""
	# Add spawn node
	add_hex(spawn_node)

	# Add starter hexes
	for hex: PvPHexNode in starter_hexes:
		add_hex(hex)

	player_respawned.emit(player_uid)
	leaderboard_changed.emit()


# ==============================================================================
# MAP INFO
# ==============================================================================

func get_time_until_reset() -> int:
	"""Get seconds until map resets"""
	var now := Time.get_unix_time_from_system()
	return maxi(0, next_reset - now)


func get_reset_time_string() -> String:
	"""Get human-readable time until reset"""
	var seconds := get_time_until_reset()

	if seconds <= 0:
		return "Reset imminent"

	var days := seconds / 86400
	var hours := (seconds % 86400) / 3600
	var minutes := (seconds % 3600) / 60

	if days > 0:
		return "%dd %dh" % [days, hours]
	elif hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes


func is_map_valid() -> bool:
	"""Check if map is still valid (not past reset)"""
	return Time.get_unix_time_from_system() < next_reset
