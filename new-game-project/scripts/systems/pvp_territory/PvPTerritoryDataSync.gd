# scripts/systems/pvp_territory/PvPTerritoryDataSync.gd
# Firebase synchronization for PvP hex territory data
class_name PvPTerritoryDataSync extends Node

"""
PvPTerritoryDataSync - Firebase sync for multiplayer PvP hex maps
RULE 2: Single responsibility - ONLY handles Firebase sync
RULE 1: Under 500 lines

Firebase Collections:
- pvp_maps: Map instances (metadata, player list)
- pvp_maps/{map_id}/hexes: Individual hex states
- pvp_maps/{map_id}/players: Player data per map
- pvp_maps/{map_id}/battles: Battle history
"""

# ==============================================================================
# SIGNALS
# ==============================================================================

signal maps_fetched(maps: Array)
signal map_joined(map_data: Dictionary, success: bool)
signal map_created(map_id: String, success: bool)
signal hex_state_updated(hex_id: String, hex_data: Dictionary)
signal map_state_received(hexes: Dictionary, players: Array)
signal capture_recorded(hex_id: String, success: bool)
signal defense_updated(hex_id: String, success: bool)
signal player_joined_map(player_uid: String, player_data: Dictionary)

# ==============================================================================
# CONSTANTS
# ==============================================================================

const COLLECTION_PVP_MAPS := "pvp_maps"
const SUBCOLLECTION_HEXES := "hexes"
const SUBCOLLECTION_PLAYERS := "players"
const SUBCOLLECTION_BATTLES := "battles"

const MAX_PLAYERS := 8
const MAP_RESET_DAYS := 7  # Weekly reset

# ==============================================================================
# STATE
# ==============================================================================

var _firestore = null
var _user_id: String = ""
var _display_name: String = ""
var _current_map_id: String = ""
var _is_listening: bool = false


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null


func _ready() -> void:
	call_deferred("_initialize_firebase")


func _initialize_firebase() -> void:
	"""Initialize Firebase connection"""
	var system_registry = _get_system_registry()
	if not system_registry:
		print("[PvPTerritoryDataSync] SystemRegistry not available")
		return

	var firebase_integration = system_registry.get_system("FirebaseIntegration")
	if not firebase_integration:
		print("[PvPTerritoryDataSync] FirebaseIntegration not available - offline mode")
		return

	if firebase_integration.has_method("get_firestore"):
		_firestore = firebase_integration.get_firestore()

	if firebase_integration.has_method("get_user_id"):
		_user_id = firebase_integration.get_user_id()

	if firebase_integration.has_method("get_user_display_name"):
		_display_name = firebase_integration.get_user_display_name()

	if is_ready():
		print("[PvPTerritoryDataSync] Initialized with user: %s" % _user_id)
	else:
		print("[PvPTerritoryDataSync] Offline mode - using mock data")


func is_ready() -> bool:
	"""Check if Firebase sync is available"""
	return _firestore != null and not _user_id.is_empty()


func get_user_id() -> String:
	# In offline mode, use fallback ID that matches mock data
	if _user_id.is_empty():
		return "player_1"
	return _user_id


func get_display_name() -> String:
	return _display_name if not _display_name.is_empty() else "Player"


func get_current_map_id() -> String:
	return _current_map_id


# ==============================================================================
# MAP DISCOVERY
# ==============================================================================

func fetch_available_maps() -> void:
	"""Fetch list of joinable PvP maps"""
	if not is_ready():
		maps_fetched.emit(_generate_mock_maps())
		return

	_do_fetch_maps.call_deferred()


func _do_fetch_maps() -> void:
	"""Async map fetch operation"""
	var collection = _firestore.collection(COLLECTION_PVP_MAPS)
	var query = collection.query()
	var result = await query.get()

	if result == null:
		maps_fetched.emit([])
		return

	var maps := _parse_map_results(result)
	maps_fetched.emit(maps)


func _parse_map_results(result) -> Array:
	"""Parse Firestore results into map list"""
	var maps := []

	var docs := []
	if result is Array:
		docs = result
	elif result.has_method("keys"):
		docs = [result]

	for doc in docs:
		var status = _get_doc_value(doc, "status")
		if status != "active":
			continue

		var player_count: int = _get_doc_value(doc, "current_player_count")
		if player_count >= MAX_PLAYERS:
			continue

		maps.append({
			"map_id": _get_doc_value(doc, "map_id"),
			"created_at": _get_doc_value(doc, "created_at"),
			"next_reset": _get_doc_value(doc, "next_reset"),
			"player_count": player_count,
			"max_players": MAX_PLAYERS
		})

	# Sort by player count (join maps with more players first for activity)
	maps.sort_custom(func(a, b): return a["player_count"] > b["player_count"])
	return maps


func _generate_mock_maps() -> Array:
	"""Generate mock maps for offline testing"""
	return [
		{
			"map_id": "mock_map_1",
			"created_at": Time.get_unix_time_from_system() - 86400,
			"next_reset": Time.get_unix_time_from_system() + 86400 * 6,
			"player_count": 3,
			"max_players": MAX_PLAYERS
		}
	]


# ==============================================================================
# MAP CREATION
# ==============================================================================

func create_new_map() -> void:
	"""Create a new PvP map instance"""
	if not is_ready():
		# Create mock map for offline
		var mock_id := "mock_map_%d" % Time.get_unix_time_from_system()
		map_created.emit(mock_id, true)
		return

	_do_create_map.call_deferred()


func _do_create_map() -> void:
	"""Async map creation operation"""
	var map_id := "pvp_%d_%s" % [Time.get_unix_time_from_system(), _user_id.substr(0, 6)]
	var now := Time.get_unix_time_from_system()

	var map_data := {
		"map_id": map_id,
		"created_at": now,
		"next_reset": now + (MAP_RESET_DAYS * 86400),
		"status": "active",
		"max_players": MAX_PLAYERS,
		"current_player_count": 0,
		"current_max_ring": 3,
		"creator_uid": _user_id
	}

	var collection = _firestore.collection(COLLECTION_PVP_MAPS)
	var result = await collection.add(map_id, map_data)

	if result != null:
		# Initialize map hexes
		var initial_map := PvPMapGenerator.generate_initial_map()
		await _upload_initial_hexes(map_id, initial_map["hexes"])
		map_created.emit(map_id, true)
	else:
		map_created.emit("", false)


func _upload_initial_hexes(map_id: String, hexes: Dictionary) -> void:
	"""Upload initial hex state for a new map"""
	var hex_collection_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_HEXES]
	var collection = _firestore.collection(hex_collection_path)

	for hex_id: String in hexes:
		var hex: PvPHexNode = hexes[hex_id]
		await collection.add(hex_id, hex.to_dict())


# ==============================================================================
# MAP JOINING
# ==============================================================================

func join_map(map_id: String) -> void:
	"""Join an existing PvP map"""
	if not is_ready():
		_current_map_id = map_id
		map_joined.emit(_generate_mock_map_data(), true)
		return

	_do_join_map.call_deferred(map_id)


func _do_join_map(map_id: String) -> void:
	"""Async map join operation"""
	# First, fetch current map state
	var map_collection = _firestore.collection(COLLECTION_PVP_MAPS)
	var map_doc = await map_collection.get_doc(map_id)

	if map_doc == null:
		map_joined.emit({}, false)
		return

	# Check if map has space
	var player_count: int = _get_doc_value(map_doc, "current_player_count")
	if player_count >= MAX_PLAYERS:
		map_joined.emit({"error": "Map is full"}, false)
		return

	# Check if already in this map
	var players_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_PLAYERS]
	var players_collection = _firestore.collection(players_path)
	var existing_player = await players_collection.get_doc(_user_id)

	if existing_player != null:
		# Already in map, just load state
		_current_map_id = map_id
		var existing_state := await _fetch_full_map_state(map_id)
		map_joined.emit(existing_state, true)
		return

	# Add player to map
	var spawn_result := await _spawn_player_in_map(map_id, player_count)
	if not spawn_result["success"]:
		map_joined.emit({"error": spawn_result.get("error", "Spawn failed")}, false)
		return

	# Update player count
	await map_collection.add(map_id, {
		"current_player_count": player_count + 1
	})

	_current_map_id = map_id
	var new_state := await _fetch_full_map_state(map_id)
	map_joined.emit(new_state, true)


func _spawn_player_in_map(map_id: String, player_index: int) -> Dictionary:
	"""Spawn a new player in the map"""
	# Fetch current hex state
	var hexes := await _fetch_hexes(map_id)

	# Get existing players
	var players := await _fetch_players(map_id)

	# Allocate spawn
	var spawn_result := PvPSpawnManager.allocate_spawn(
		_user_id, get_display_name(),
		players, hexes
	)

	if not spawn_result["success"]:
		return spawn_result

	# Upload player data
	var players_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_PLAYERS]
	var players_collection = _firestore.collection(players_path)

	var player_data := {
		"player_uid": _user_id,
		"display_name": get_display_name(),
		"joined_at": Time.get_unix_time_from_system(),
		"spawn_coord": spawn_result["spawn_node"].coord.to_dict(),
		"controlled_nodes": [],
		"last_active": Time.get_unix_time_from_system()
	}

	await players_collection.add(_user_id, player_data)

	# Upload spawn and starter hexes
	var hex_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_HEXES]
	var hex_collection = _firestore.collection(hex_path)

	var spawn_node: PvPHexNode = spawn_result["spawn_node"]
	await hex_collection.add(spawn_node.id, spawn_node.to_dict())

	for starter_hex: PvPHexNode in spawn_result["starter_hexes"]:
		await hex_collection.add(starter_hex.id, starter_hex.to_dict())

	return {"success": true}


func _fetch_full_map_state(map_id: String) -> Dictionary:
	"""Fetch complete map state (hexes and players)"""
	var hexes := await _fetch_hexes(map_id)
	var players := await _fetch_players(map_id)

	return {
		"map_id": map_id,
		"hexes": hexes,
		"players": players
	}


func _fetch_hexes(map_id: String) -> Dictionary:
	"""Fetch all hexes for a map"""
	var hex_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_HEXES]
	var collection = _firestore.collection(hex_path)
	var result = await collection.query().get()

	var hexes := {}
	if result == null:
		return hexes

	var docs = result if result is Array else [result]
	for doc in docs:
		var hex_data = _doc_to_dict(doc)
		var hex := PvPHexNode.from_dict(hex_data)
		hexes[hex.id] = hex

	return hexes


func _fetch_players(map_id: String) -> Array:
	"""Fetch all players in a map"""
	var players_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_PLAYERS]
	var collection = _firestore.collection(players_path)
	var result = await collection.query().get()

	var players := []
	if result == null:
		return players

	var docs = result if result is Array else [result]
	for doc in docs:
		players.append(_doc_to_dict(doc))

	return players


func _generate_mock_map_data() -> Dictionary:
	"""Generate mock map data for offline testing with 8 players"""
	var initial := PvPMapGenerator.generate_initial_map()
	var hexes: Dictionary = initial["hexes"]
	var players: Array = []

	# Mock player names and colors
	var mock_players := [
		{"uid": "player_1", "name": "You", "color_index": 0},
		{"uid": "player_2", "name": "DragonSlayer", "color_index": 1},
		{"uid": "player_3", "name": "ShadowKnight", "color_index": 2},
		{"uid": "player_4", "name": "CrystalMage", "color_index": 3},
		{"uid": "player_5", "name": "StormBringer", "color_index": 4},
		{"uid": "player_6", "name": "IronFist", "color_index": 5},
		{"uid": "player_7", "name": "NightHawk", "color_index": 6},
		{"uid": "player_8", "name": "BlazeFury", "color_index": 7}
	]

	# Use local user ID for first player
	if not _user_id.is_empty():
		mock_players[0]["uid"] = _user_id
	if not _display_name.is_empty():
		mock_players[0]["name"] = _display_name

	# Get spawn positions for 8 players
	var spawn_positions := PvPMapGenerator._calculate_spawn_positions(8)

	# Spawn each player
	for i in range(mock_players.size()):
		var player_info: Dictionary = mock_players[i]
		var spawn_coord: Vector2i = spawn_positions[i]

		# Generate spawn hexes for this player
		var spawn_hexes := PvPMapGenerator.generate_spawn_hexes_for_player(
			spawn_coord,
			player_info["uid"],
			player_info["name"],
			hexes
		)

		# Add to hexes
		for hex_id: String in spawn_hexes:
			hexes[hex_id] = spawn_hexes[hex_id]

		# Also give each player some territory expanding inward
		_assign_mock_territory(hexes, player_info, spawn_coord, i)

		# Add player data
		players.append({
			"player_uid": player_info["uid"],
			"display_name": player_info["name"],
			"color_index": player_info["color_index"],
			"spawn_coord": {"q": spawn_coord.x, "r": spawn_coord.y},
			"joined_at": Time.get_unix_time_from_system() - (i * 3600)
		})

	return {
		"map_id": _current_map_id,
		"hexes": hexes,
		"players": players
	}


func _assign_mock_territory(hexes: Dictionary, player_info: Dictionary, spawn_coord: Vector2i, _player_index: int) -> void:
	"""Assign contiguous territory to a mock player using BFS expansion

	Uses adjacency-based expansion to ensure all territory is connected to spawn.
	"""
	var uid: String = player_info["uid"]
	var player_name: String = player_info["name"]

	var max_claims := 20  # Each player gets ~20 hexes beyond spawn
	var claimed := 0

	# Start from spawn and expand via BFS (breadth-first) to ensure connectivity
	var frontier: Array[Vector2i] = [spawn_coord]
	var visited: Dictionary = {"%d,%d" % [spawn_coord.x, spawn_coord.y]: true}

	while claimed < max_claims and not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var neighbors := HexRingGenerator.get_neighbors(current)

		# Shuffle neighbors for variety
		neighbors.shuffle()

		for neighbor: Vector2i in neighbors:
			if claimed >= max_claims:
				break

			var key := "%d,%d" % [neighbor.x, neighbor.y]
			if visited.has(key):
				continue
			visited[key] = true

			var hex_id := PvPHexNode.coord_to_id(neighbor.x, neighbor.y)
			if not hexes.has(hex_id):
				continue

			var hex: PvPHexNode = hexes[hex_id]
			if hex.is_neutral() and not hex.is_spawn_node:
				hex.controller_uid = uid
				hex.controller_display_name = player_name
				hex.last_captured_at = int(Time.get_unix_time_from_system()) - (randi() % 86400)
				claimed += 1
				frontier.append(neighbor)  # Add to frontier for further expansion


# ==============================================================================
# HEX STATE UPDATES
# ==============================================================================

func update_hex_capture(hex_id: String, new_owner_uid: String, new_owner_name: String) -> void:
	"""Update hex ownership after capture"""
	if not is_ready() or _current_map_id.is_empty():
		capture_recorded.emit(hex_id, false)
		return

	_do_update_capture.call_deferred(hex_id, new_owner_uid, new_owner_name)


func _do_update_capture(hex_id: String, new_owner_uid: String, new_owner_name: String) -> void:
	"""Async capture update operation"""
	var hex_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, _current_map_id, SUBCOLLECTION_HEXES]
	var collection = _firestore.collection(hex_path)

	var update_data := {
		"controller_uid": new_owner_uid,
		"controller_display_name": new_owner_name,
		"last_captured_at": Time.get_unix_time_from_system()
	}

	var result = await collection.add(hex_id, update_data)
	capture_recorded.emit(hex_id, result != null)

	# Record battle in history
	await _record_capture_battle(hex_id, new_owner_uid)


func _record_capture_battle(hex_id: String, attacker_uid: String) -> void:
	"""Record capture in battle history"""
	var battles_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, _current_map_id, SUBCOLLECTION_BATTLES]
	var collection = _firestore.collection(battles_path)

	var battle_data := {
		"hex_id": hex_id,
		"attacker_uid": attacker_uid,
		"timestamp": Time.get_unix_time_from_system(),
		"type": "capture"
	}

	await collection.add("", battle_data)


func update_hex_defense(hex_id: String, defense_team: Array, defense_power: int) -> void:
	"""Update defense team for a hex"""
	if not is_ready() or _current_map_id.is_empty():
		defense_updated.emit(hex_id, false)
		return

	_do_update_defense.call_deferred(hex_id, defense_team, defense_power)


func _do_update_defense(hex_id: String, defense_team: Array, defense_power: int) -> void:
	"""Async defense update operation"""
	var hex_path := "%s/%s/%s" % [COLLECTION_PVP_MAPS, _current_map_id, SUBCOLLECTION_HEXES]
	var collection = _firestore.collection(hex_path)

	var update_data := {
		"defense_team_serialized": defense_team,
		"defense_power": defense_power
	}

	var result = await collection.add(hex_id, update_data)
	defense_updated.emit(hex_id, result != null)


# ==============================================================================
# UTILITIES
# ==============================================================================

func _get_doc_value(doc, key: String):
	"""Safely get value from FirestoreDocument"""
	if doc == null:
		return null
	if doc.has_method("get_value"):
		return doc.get_value(key)
	if doc is Dictionary and doc.has(key):
		return doc[key]
	return null


func _doc_to_dict(doc) -> Dictionary:
	"""Convert FirestoreDocument to Dictionary"""
	if doc is Dictionary:
		return doc
	if doc.has_method("keys"):
		var result := {}
		for key in doc.keys():
			result[key] = _get_doc_value(doc, key)
		return result
	return {}


func leave_current_map() -> void:
	"""Leave the current map (stop listening)"""
	_current_map_id = ""
	_is_listening = false
