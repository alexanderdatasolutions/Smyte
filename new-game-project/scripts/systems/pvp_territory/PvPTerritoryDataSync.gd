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
const COLLECTION_REALTIME_MAPS := "pvp_realtime_maps"  # 4-player matches from PvPSignupManager
const SUBCOLLECTION_HEXES := "hexes"
const SUBCOLLECTION_PLAYERS := "players"
const SUBCOLLECTION_BATTLES := "battles"

const MAX_PLAYERS := 8
const MAP_RESET_DAYS := 7  # Weekly reset

# ==============================================================================
# STATE
# ==============================================================================

var _firestore: Variant = null
var _user_id: String = ""
var _display_name: String = ""
var _current_map_id: String = ""
var _is_listening: bool = false

# Test/offline mode data
var _test_map_hexes: Dictionary = {}
var _test_map_players: Array = []
var _is_test_mode: bool = false
var _test_user_uid: String = ""  # User UID when in test mode


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null


func _ready() -> void:
	call_deferred("_initialize_firebase")


func _initialize_firebase() -> void:
	"""Initialize Firebase connection"""
	var system_registry: Variant = _get_system_registry()
	if not system_registry:
		return

	var firebase_integration: Variant = system_registry.get_system("FirebaseIntegration")
	if not firebase_integration:
		return

	if firebase_integration.has_method("get_firestore"):
		_firestore = firebase_integration.get_firestore()

	if firebase_integration.has_method("get_user_id"):
		_user_id = firebase_integration.get_user_id()

	# Get display name from SaveManager (where user sets it after signup)
	var save_manager: Variant = system_registry.get_system("SaveManager")
	if save_manager and save_manager.has_method("get_player_value"):
		_display_name = save_manager.get_player_value("display_name", "")

	# Fallback to email username if no display name in save
	if _display_name.is_empty() and firebase_integration.has_method("get_user_email"):
		var email: String = firebase_integration.get_user_email()
		if not email.is_empty() and "@" in email:
			_display_name = email.split("@")[0]


func is_ready() -> bool:
	"""Check if Firebase sync is available"""
	return _firestore != null and not _user_id.is_empty()


func ensure_firebase_ready() -> bool:
	"""Force Firebase initialization if not ready (for immediate use after scene load)"""
	if is_ready():
		return true

	# Try to initialize synchronously
	_initialize_firebase()

	# If still not ready, try getting Firebase directly
	if not is_ready():
		if Firebase and Firebase.Firestore:
			_firestore = Firebase.Firestore

		# Get user from FirebaseIntegration
		var system_registry: Variant = _get_system_registry()
		if system_registry:
			var firebase_integration: Variant = system_registry.get_system("FirebaseIntegration")
			if firebase_integration:
				if firebase_integration.has_method("get_user_id"):
					_user_id = firebase_integration.get_user_id()
				if _display_name.is_empty() and firebase_integration.has_method("get_user_email"):
					var email: String = firebase_integration.get_user_email()
					if not email.is_empty() and "@" in email:
						_display_name = email.split("@")[0]

	return is_ready()


func get_user_id() -> String:
	# In test mode, return the test user UID
	if _is_test_mode and not _test_user_uid.is_empty():
		return _test_user_uid
	# In offline mode, use fallback ID that matches mock data
	if _user_id.is_empty():
		return "player_1"
	return _user_id


func get_display_name() -> String:
	return _display_name if not _display_name.is_empty() else "Player"


func get_current_map_id() -> String:
	return _current_map_id


func is_test_mode() -> bool:
	return _is_test_mode


# ==============================================================================
# TEST/OFFLINE MODE
# ==============================================================================

func set_test_map_data(map_id: String, hexes: Dictionary, players: Array, test_user_uid: String = "") -> void:
	"""Store test map data for offline play"""
	_current_map_id = map_id
	_test_map_hexes = hexes
	_test_map_players = players
	_is_test_mode = true
	if not test_user_uid.is_empty():
		_test_user_uid = test_user_uid
	elif players.size() > 0:
		# Use first player's UID as the test user
		_test_user_uid = players[0].get("player_uid", players[0].get("uid", ""))
	print("PvPTerritoryDataSync: Test map data stored - %d hexes, %d players, user: %s" % [hexes.size(), players.size(), _test_user_uid])


func get_test_map_data() -> Dictionary:
	"""Get stored test map data"""
	return {
		"map_id": _current_map_id,
		"hexes": _test_map_hexes,
		"players": _test_map_players
	}


func clear_test_data() -> void:
	"""Clear test mode data"""
	_test_map_hexes.clear()
	_test_map_players.clear()
	_is_test_mode = false
	_current_map_id = ""
	_test_user_uid = ""


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
	if not _firestore:
		maps_fetched.emit([])
		return
	var collection: Variant = _firestore.collection(COLLECTION_PVP_MAPS)
	if not collection:
		maps_fetched.emit([])
		return
	var query: Variant = collection.query()
	if not query:
		maps_fetched.emit([])
		return
	var result: Variant = await query.get()

	if result == null:
		maps_fetched.emit([])
		return

	var maps: Array = _parse_map_results(result)
	maps_fetched.emit(maps)


func _parse_map_results(result: Variant) -> Array:
	"""Parse Firestore results into map list"""
	var maps: Array = []
	if result == null:
		return maps

	var docs: Array = []
	if result is Array:
		docs = result
	elif result is Object and result.has_method("keys"):
		docs = [result]
	else:
		return maps

	for doc: Variant in docs:
		var status: Variant = _get_doc_value(doc, "status")
		if status != "active":
			continue

		var player_count_val: Variant = _get_doc_value(doc, "current_player_count")
		var player_count: int = int(player_count_val) if player_count_val != null else 0
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
	maps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["player_count"] > b["player_count"])
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
		var mock_id: String = "mock_map_%d" % Time.get_unix_time_from_system()
		map_created.emit(mock_id, true)
		return

	_do_create_map.call_deferred()


func _do_create_map() -> void:
	"""Async map creation operation"""
	if not _firestore:
		map_created.emit("", false)
		return

	var map_id: String = "pvp_%d_%s" % [Time.get_unix_time_from_system(), _user_id.substr(0, 6)]
	var now: int = Time.get_unix_time_from_system()

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

	var collection: Variant = _firestore.collection(COLLECTION_PVP_MAPS)
	if not collection:
		map_created.emit("", false)
		return
	var result: Variant = await collection.add(map_id, map_data)

	if result != null:
		# Initialize map hexes
		var initial_map: Dictionary = PvPMapGenerator.generate_initial_map()
		await _upload_initial_hexes(map_id, initial_map.get("hexes", {}))
		map_created.emit(map_id, true)
	else:
		map_created.emit("", false)


func _upload_initial_hexes(map_id: String, hexes: Dictionary) -> void:
	"""Upload initial hex state for a new map"""
	if not _firestore:
		return
	var hex_collection_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_HEXES]
	var collection: Variant = _firestore.collection(hex_collection_path)
	if not collection:
		return

	for hex_id: String in hexes:
		var hex: PvPHexNode = hexes[hex_id]
		if hex:
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
	if not _firestore:
		map_joined.emit({}, false)
		return

	# First, fetch current map state
	var map_collection: Variant = _firestore.collection(COLLECTION_PVP_MAPS)
	if not map_collection:
		map_joined.emit({}, false)
		return
	var map_doc: Variant = await map_collection.get_doc(map_id)

	if map_doc == null:
		map_joined.emit({}, false)
		return

	# Check if map has space
	var player_count_val: Variant = _get_doc_value(map_doc, "current_player_count")
	var player_count: int = int(player_count_val) if player_count_val != null else 0
	if player_count >= MAX_PLAYERS:
		map_joined.emit({"error": "Map is full"}, false)
		return

	# Check if already in this map
	var players_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_PLAYERS]
	var players_collection: Variant = _firestore.collection(players_path)
	if not players_collection:
		map_joined.emit({}, false)
		return
	var existing_player: Variant = await players_collection.get_doc(_user_id)

	if existing_player != null:
		# Already in map, just load state
		_current_map_id = map_id
		var existing_state: Dictionary = await _fetch_full_map_state(map_id)
		map_joined.emit(existing_state, true)
		return

	# Add player to map
	var spawn_result: Dictionary = await _spawn_player_in_map(map_id, player_count)
	if not spawn_result["success"]:
		map_joined.emit({"error": spawn_result.get("error", "Spawn failed")}, false)
		return

	# Update player count
	await map_collection.add(map_id, {
		"current_player_count": player_count + 1
	})

	_current_map_id = map_id
	var new_state: Dictionary = await _fetch_full_map_state(map_id)
	map_joined.emit(new_state, true)


func _spawn_player_in_map(map_id: String, player_index: int) -> Dictionary:
	"""Spawn a new player in the map"""
	if not _firestore:
		return {"success": false, "error": "Firestore unavailable"}

	# Fetch current hex state
	var hexes: Dictionary = await _fetch_hexes(map_id)

	# Get existing players
	var players: Array = await _fetch_players(map_id)

	# Allocate spawn
	var spawn_result: Dictionary = PvPSpawnManager.allocate_spawn(
		_user_id, get_display_name(),
		players, hexes
	)

	if not spawn_result.get("success", false):
		return spawn_result

	var spawn_node: PvPHexNode = spawn_result.get("spawn_node")
	if not spawn_node or not spawn_node.coord:
		return {"success": false, "error": "Invalid spawn node"}

	# Upload player data
	var players_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_PLAYERS]
	var players_collection: Variant = _firestore.collection(players_path)
	if not players_collection:
		return {"success": false, "error": "Cannot access players collection"}

	var player_data := {
		"player_uid": _user_id,
		"display_name": get_display_name(),
		"joined_at": Time.get_unix_time_from_system(),
		"spawn_coord": spawn_node.coord.to_dict(),
		"controlled_nodes": [],
		"last_active": Time.get_unix_time_from_system()
	}

	await players_collection.add(_user_id, player_data)

	# Upload spawn and starter hexes
	var hex_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_HEXES]
	var hex_collection: Variant = _firestore.collection(hex_path)
	if not hex_collection:
		return {"success": false, "error": "Cannot access hex collection"}

	await hex_collection.add(spawn_node.id, spawn_node.to_dict())

	var starter_hexes: Array = spawn_result.get("starter_hexes", [])
	for starter_hex: PvPHexNode in starter_hexes:
		if starter_hex:
			await hex_collection.add(starter_hex.id, starter_hex.to_dict())

	return {"success": true}


func _fetch_full_map_state(map_id: String) -> Dictionary:
	"""Fetch complete map state (hexes and players)"""
	var hexes: Dictionary = await _fetch_hexes(map_id)
	var players: Array = await _fetch_players(map_id)

	return {
		"map_id": map_id,
		"hexes": hexes,
		"players": players
	}


# ==============================================================================
# REALTIME MAP JOINING (for 4-player matches from PvPSignupManager)
# ==============================================================================

func join_realtime_map(map_id: String) -> void:
	"""Join a specific realtime map (4-player match from signup queue)"""
	# Try to ensure Firebase is ready before joining
	if not ensure_firebase_ready():
		push_warning("PvPTerritoryDataSync: Firebase not ready after ensure, cannot join realtime map")
		map_joined.emit({}, false)
		return

	_do_join_realtime_map.call_deferred(map_id)


func _do_join_realtime_map(map_id: String) -> void:
	"""Async realtime map join operation"""
	if not _firestore:
		map_joined.emit({}, false)
		return

	print("PvPTerritoryDataSync: Joining realtime map %s" % map_id)

	# Fetch from pvp_realtime_maps collection
	var map_collection: Variant = _firestore.collection(COLLECTION_REALTIME_MAPS)
	if not map_collection:
		map_joined.emit({}, false)
		return

	var map_doc: Variant = await map_collection.get_doc(map_id)
	if map_doc == null:
		push_error("PvPTerritoryDataSync: Map %s not found" % map_id)
		map_joined.emit({"error": "Map not found"}, false)
		return

	# Parse the map document
	var map_data: Dictionary = _doc_to_dict(map_doc)
	if map_data.is_empty():
		map_joined.emit({"error": "Empty map data"}, false)
		return

	# Convert hexes from dictionary format to PvPHexNode objects
	var hexes_raw: Dictionary = map_data.get("hexes", {})
	var hexes: Dictionary = {}
	var owned_count: int = 0
	var user_owned_count: int = 0
	for hex_id: String in hexes_raw:
		var hex_data: Dictionary = hexes_raw[hex_id]
		if hex_data is Dictionary:
			var hex: PvPHexNode = PvPHexNode.from_dict(hex_data)
			if hex:
				hexes[hex_id] = hex
				if not hex.controller_uid.is_empty():
					owned_count += 1
					if hex.controller_uid == _user_id:
						user_owned_count += 1

	print("PvPTerritoryDataSync: Hex ownership - total owned: %d, user owns: %d (user_id=%s)" % [owned_count, user_owned_count, _user_id])

	var players: Array = map_data.get("players", [])

	_current_map_id = map_id
	_is_test_mode = false  # Real multiplayer mode

	var result := {
		"map_id": map_id,
		"hexes": hexes,
		"players": players
	}

	print("PvPTerritoryDataSync: Loaded realtime map - %d hexes, %d players" % [hexes.size(), players.size()])
	map_joined.emit(result, true)


func _fetch_hexes(map_id: String) -> Dictionary:
	"""Fetch all hexes for a map"""
	var hexes: Dictionary = {}
	if not _firestore:
		return hexes

	var hex_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_HEXES]
	var collection: Variant = _firestore.collection(hex_path)
	if not collection:
		return hexes
	var query: Variant = collection.query()
	if not query:
		return hexes
	var result: Variant = await query.get()

	if result == null:
		return hexes

	var docs: Array = result if result is Array else [result]
	for doc: Variant in docs:
		var hex_data: Dictionary = _doc_to_dict(doc)
		if hex_data.is_empty():
			continue
		var hex: PvPHexNode = PvPHexNode.from_dict(hex_data)
		if hex:
			hexes[hex.id] = hex

	return hexes


func _fetch_players(map_id: String) -> Array:
	"""Fetch all players in a map"""
	var players: Array = []
	if not _firestore:
		return players

	var players_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, map_id, SUBCOLLECTION_PLAYERS]
	var collection: Variant = _firestore.collection(players_path)
	if not collection:
		return players
	var query: Variant = collection.query()
	if not query:
		return players
	var result: Variant = await query.get()

	if result == null:
		return players

	var docs: Array = result if result is Array else [result]
	for doc: Variant in docs:
		var doc_dict: Dictionary = _doc_to_dict(doc)
		if not doc_dict.is_empty():
			players.append(doc_dict)

	return players


func _generate_mock_map_data() -> Dictionary:
	"""Generate mock map data for offline testing with 8 players"""
	var initial: Dictionary = PvPMapGenerator.generate_initial_map()
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
	var spawn_positions: Array[Vector2i] = PvPMapGenerator._calculate_spawn_positions(8)

	# Spawn each player
	for i in range(mock_players.size()):
		var player_info: Dictionary = mock_players[i]
		var spawn_coord: Vector2i = spawn_positions[i]

		# Generate spawn hexes for this player
		var spawn_hexes: Dictionary = PvPMapGenerator.generate_spawn_hexes_for_player(
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

	var max_claims: int = 20  # Each player gets ~20 hexes beyond spawn
	var claimed: int = 0

	# Start from spawn and expand via BFS (breadth-first) to ensure connectivity
	var frontier: Array[Vector2i] = [spawn_coord]
	var visited: Dictionary = {"%d,%d" % [spawn_coord.x, spawn_coord.y]: true}

	while claimed < max_claims and not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var neighbors: Array[Vector2i] = HexRingGenerator.get_neighbors(current)

		# Shuffle neighbors for variety
		neighbors.shuffle()

		for neighbor: Vector2i in neighbors:
			if claimed >= max_claims:
				break

			var key: String = "%d,%d" % [neighbor.x, neighbor.y]
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

				# Generate defense team for AI players (not player_1 which is the human)
				if uid != "player_1" and uid != _user_id:
					var defense_result := _generate_mock_defense_team(hex.tier)
					hex.defense_team_serialized = defense_result["team"]
					hex.defense_power = defense_result["power"]

				claimed += 1
				frontier.append(neighbor)  # Add to frontier for further expansion


func _generate_mock_defense_team(tier: int) -> Dictionary:
	"""Generate a defense team for AI mock territory using real god templates"""
	var team: Array = []
	var team_size: int = mini(tier + 1, 4)  # 2-4 gods based on tier

	# Try to use real god templates for proper portraits
	var template_ids := _get_available_god_templates()
	template_ids.shuffle()

	var total_power: int = 0

	for i in range(team_size):
		var level: int = tier * 10 + i * 2
		var is_leader: bool = (i == 0)

		# Try to create from real template
		var god: God = null
		if i < template_ids.size():
			god = _create_god_from_template(template_ids[i], level)

		if god:
			# Use real god data with proper template_id for portraits
			var god_data := {
				"id": god.id,
				"template_id": god.template_id,  # Critical for portraits!
				"name": god.name,
				"level": level,
				"tier": god.tier,
				"pantheon": god.pantheon,
				"element": god.element,
				"base_hp": god.base_hp,
				"base_attack": god.base_attack,
				"base_defense": god.base_defense,
				"base_speed": god.base_speed,
				"base_crit_rate": god.base_crit_rate,
				"base_crit_damage": god.base_crit_damage,
				"hp": god.base_hp,
				"attack": god.base_attack,
				"defense": god.base_defense,
				"speed": god.base_speed,
				"is_leader": is_leader,
				"leader_skill": god.leader_skill,
				"abilities": god.abilities,
				"is_awakened": god.is_awakened,
				"awakened_name": god.awakened_name,
				"equipment": _generate_mock_equipment(tier),
				"skills": []
			}
			team.append(god_data)

			# Calculate power
			total_power += god.base_hp / 10
			total_power += god.base_attack
			total_power += god.base_defense
			total_power += god.base_speed * 2
			total_power += level * 50
			if is_leader:
				total_power += 200
		else:
			# Fallback to generated data if no template available
			var names := ["Guardian", "Sentinel", "Warden", "Defender"]
			var elements := ["fire", "water", "earth", "lightning", "light", "dark"]
			var pantheons := ["greek", "norse", "egyptian", "celtic", "japanese"]
			var mult: float = 1.15 if is_leader else 1.0

			var hp: int = int((150 + tier * 50 + i * 20) * mult)
			var atk: int = int((50 + tier * 15 + i * 5) * mult)
			var def: int = int((40 + tier * 12 + i * 4) * mult)
			var spd: int = int((50 + tier * 5 + i * 2) * mult)

			var god_data := {
				"id": "ai_defender_%d_%d_%d" % [tier, i, randi()],
				"template_id": "ai_defender",  # Generic fallback
				"name": names[i % names.size()],
				"level": level,
				"tier": tier,
				"pantheon": pantheons[randi() % pantheons.size()],
				"element": elements[randi() % elements.size()],
				"base_hp": hp,
				"base_attack": atk,
				"base_defense": def,
				"base_speed": spd,
				"hp": hp,
				"attack": atk,
				"defense": def,
				"speed": spd,
				"is_leader": is_leader,
				"equipment": _generate_mock_equipment(tier),
				"skills": []
			}
			team.append(god_data)

			total_power += hp / 10
			total_power += atk
			total_power += def
			total_power += spd * 2
			total_power += level * 50
			if is_leader:
				total_power += 200

	return {"team": team, "power": total_power}


func _generate_mock_equipment(tier: int) -> Dictionary:
	"""Generate mock equipment for an AI defender"""
	var equipment: Dictionary = {}
	var slots := ["weapon", "armor", "accessory"]

	for slot: String in slots:
		# 60% chance to have equipment in each slot
		if randf() > 0.6:
			continue

		var stat_base: int = tier * 5 + randi_range(0, 10)
		equipment[slot] = {
			"id": "mock_%s_t%d" % [slot, tier],
			"name": "%s T%d" % [slot.capitalize(), tier],
			"tier": tier,
			"hp_bonus": stat_base * 3 if slot == "armor" else stat_base,
			"attack_bonus": stat_base * 2 if slot == "weapon" else stat_base / 2,
			"defense_bonus": stat_base if slot == "armor" else stat_base / 2,
			"speed_bonus": stat_base / 2 if slot == "accessory" else 0
		}

	return equipment


func _get_available_god_templates() -> Array:
	"""Get list of god template IDs that can be used for AI defenders"""
	var template_ids: Array = []

	var registry: Variant = _get_system_registry()
	if not registry:
		return template_ids

	var config_manager: Variant = registry.get_system("ConfigurationManager")
	if not config_manager:
		return template_ids

	var gods_config: Dictionary = config_manager.get_gods_config()
	if gods_config.is_empty():
		return template_ids

	# Handle dictionary format
	if gods_config.has("gods") and gods_config.gods is Dictionary:
		for god_id: String in gods_config.gods:
			template_ids.append(god_id)
	# Handle legacy array format
	elif gods_config.has("gods") and gods_config.gods is Array:
		for god_data: Dictionary in gods_config.gods:
			var god_id: String = god_data.get("id", "")
			if not god_id.is_empty():
				template_ids.append(god_id)

	return template_ids


func _create_god_from_template(template_id: String, level: int) -> God:
	"""Create a God instance from template with specified level"""
	var god: God = GodFactory.create_from_json(template_id)
	if not god:
		return null

	# Set level and scale stats accordingly
	god.level = level

	return god


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
	if not _firestore:
		capture_recorded.emit(hex_id, false)
		return

	var hex_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, _current_map_id, SUBCOLLECTION_HEXES]
	var collection: Variant = _firestore.collection(hex_path)
	if not collection:
		capture_recorded.emit(hex_id, false)
		return

	var update_data: Dictionary = {
		"controller_uid": new_owner_uid,
		"controller_display_name": new_owner_name,
		"last_captured_at": Time.get_unix_time_from_system()
	}

	var result: Variant = await collection.add(hex_id, update_data)
	capture_recorded.emit(hex_id, result != null)

	# Record battle in history
	await _record_capture_battle(hex_id, new_owner_uid)


func _record_capture_battle(hex_id: String, attacker_uid: String) -> void:
	"""Record capture in battle history"""
	if not _firestore:
		return
	var battles_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, _current_map_id, SUBCOLLECTION_BATTLES]
	var collection: Variant = _firestore.collection(battles_path)
	if not collection:
		return

	var battle_data: Dictionary = {
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
	if not _firestore:
		defense_updated.emit(hex_id, false)
		return

	var hex_path: String = "%s/%s/%s" % [COLLECTION_PVP_MAPS, _current_map_id, SUBCOLLECTION_HEXES]
	var collection: Variant = _firestore.collection(hex_path)
	if not collection:
		defense_updated.emit(hex_id, false)
		return

	var update_data: Dictionary = {
		"defense_team_serialized": defense_team,
		"defense_power": defense_power
	}

	var result: Variant = await collection.add(hex_id, update_data)
	defense_updated.emit(hex_id, result != null)


# ==============================================================================
# UTILITIES
# ==============================================================================

func _get_doc_value(doc: Variant, key: String) -> Variant:
	"""Safely get value from FirestoreDocument"""
	if doc == null:
		return null
	if doc.has_method("get_value"):
		return doc.get_value(key)
	if doc is Dictionary and doc.has(key):
		return doc[key]
	return null


func _doc_to_dict(doc: Variant) -> Dictionary:
	"""Convert FirestoreDocument to Dictionary"""
	if doc == null:
		return {}
	if doc is Dictionary:
		return doc
	if doc is Object and doc.has_method("keys"):
		var result: Dictionary = {}
		for key: String in doc.keys():
			result[key] = _get_doc_value(doc, key)
		return result
	return {}


func leave_current_map() -> void:
	"""Leave the current map (stop listening)"""
	stop_realtime_sync()
	_current_map_id = ""
	_is_listening = false


# ==============================================================================
# REAL-TIME SYNC (Using RTDB for instant updates)
# ==============================================================================

# New signals for real-time updates
signal hex_captured_remotely(hex_id: String, new_owner_uid: String, new_owner_name: String)
signal player_left_map(player_uid: String)
signal map_status_changed(new_status: String)

# RTDB path for lightweight real-time triggers
const RTDB_SYNC_PATH := "pvp_maps_sync"

var _rtdb_hex_listener: Variant = null
var _rtdb_players_listener: Variant = null
var _is_realtime_active: bool = false


func start_realtime_sync(map_id: String) -> void:
	"""Start listening for real-time hex ownership changes via RTDB"""
	if _is_realtime_active:
		stop_realtime_sync()

	_current_map_id = map_id
	_is_realtime_active = true

	# Get RTDB reference
	var rtdb: Variant = _get_rtdb()
	if not rtdb:
		print("PvPTerritoryDataSync: RTDB not available, falling back to polling")
		return

	print("PvPTerritoryDataSync: Setting up RTDB listeners for map %s" % map_id)

	# Listen for hex changes
	var hex_path: String = "%s/%s/hexes" % [RTDB_SYNC_PATH, map_id]
	print("PvPTerritoryDataSync: Hex listener path: %s" % hex_path)
	_rtdb_hex_listener = rtdb.get_database_reference(hex_path, {})
	if _rtdb_hex_listener:
		var has_new: bool = _rtdb_hex_listener.has_signal("new_data_update")
		var has_patch: bool = _rtdb_hex_listener.has_signal("patch_data_update")
		print("PvPTerritoryDataSync: Listener signals - new_data_update: %s, patch_data_update: %s" % [has_new, has_patch])
		if has_new:
			_rtdb_hex_listener.new_data_update.connect(_on_rtdb_hex_update)
		if has_patch:
			_rtdb_hex_listener.patch_data_update.connect(_on_rtdb_hex_update)
		print("PvPTerritoryDataSync: Started real-time hex listener for map %s" % map_id)
	else:
		print("PvPTerritoryDataSync: Failed to create hex listener!")

	# Listen for player changes
	var players_path: String = "%s/%s/players" % [RTDB_SYNC_PATH, map_id]
	_rtdb_players_listener = rtdb.get_database_reference(players_path, {})
	if _rtdb_players_listener:
		if _rtdb_players_listener.has_signal("new_data_update"):
			_rtdb_players_listener.new_data_update.connect(_on_rtdb_player_update)


func stop_realtime_sync() -> void:
	"""Stop all real-time listeners"""
	if _rtdb_hex_listener:
		if _rtdb_hex_listener.has_signal("new_data_update"):
			if _rtdb_hex_listener.new_data_update.is_connected(_on_rtdb_hex_update):
				_rtdb_hex_listener.new_data_update.disconnect(_on_rtdb_hex_update)
		if _rtdb_hex_listener.has_signal("patch_data_update"):
			if _rtdb_hex_listener.patch_data_update.is_connected(_on_rtdb_hex_update):
				_rtdb_hex_listener.patch_data_update.disconnect(_on_rtdb_hex_update)
		_rtdb_hex_listener = null

	if _rtdb_players_listener:
		if _rtdb_players_listener.has_signal("new_data_update"):
			if _rtdb_players_listener.new_data_update.is_connected(_on_rtdb_player_update):
				_rtdb_players_listener.new_data_update.disconnect(_on_rtdb_player_update)
		_rtdb_players_listener = null

	_is_realtime_active = false
	print("PvPTerritoryDataSync: Stopped real-time listeners")


func _get_rtdb() -> Variant:
	"""Get Firebase Realtime Database reference"""
	if not Firebase:
		return null
	if not Firebase.Database:
		return null
	return Firebase.Database


func _on_rtdb_hex_update(resource: Variant) -> void:
	"""Handle real-time hex update from RTDB"""
	if not resource:
		return

	print("PvPTerritoryDataSync: RTDB update received - type: %s" % typeof(resource))

	var hex_id: String = ""
	var data: Dictionary = {}

	# Handle different resource formats
	# FirebaseResource has .key and .data properties
	if resource is Dictionary:
		hex_id = resource.get("key", "")
		data = resource.get("data", {})
	elif "key" in resource and "data" in resource:
		# FirebaseResource object - access properties directly
		hex_id = str(resource.key) if resource.key else ""
		data = resource.data if resource.data is Dictionary else {}
	else:
		print("PvPTerritoryDataSync: Unknown resource format: %s" % resource)
		return

	print("PvPTerritoryDataSync: Parsed RTDB update - hex_id: %s, data keys: %s" % [hex_id, data.keys() if data else "empty"])

	if hex_id.is_empty() or data.is_empty():
		return

	var new_owner_uid: String = data.get("controller_uid", "")
	var new_owner_name: String = data.get("controller_name", "")

	# Don't emit if this is our own capture
	if new_owner_uid == _user_id:
		print("PvPTerritoryDataSync: Ignoring own capture for %s" % hex_id)
		return

	print("PvPTerritoryDataSync: Remote capture - %s now owned by %s" % [hex_id, new_owner_name])
	hex_captured_remotely.emit(hex_id, new_owner_uid, new_owner_name)


func _on_rtdb_player_update(resource: Variant) -> void:
	"""Handle real-time player update from RTDB"""
	if not resource:
		return

	var player_uid: String = ""
	var data: Dictionary = {}

	if resource is Dictionary:
		player_uid = resource.get("key", "")
		data = resource.get("data", {})
	elif "key" in resource and "data" in resource:
		# FirebaseResource object - access properties directly
		player_uid = str(resource.key) if resource.key else ""
		data = resource.data if resource.data is Dictionary else {}
	else:
		return

	if player_uid.is_empty():
		return

	# Check if player left
	if data.get("left", false) or data.get("disconnected", false):
		player_left_map.emit(player_uid)
	else:
		player_joined_map.emit(player_uid, data)


func update_hex_capture_realtime(hex_id: String, new_owner_uid: String, new_owner_name: String, defense_team: Array = []) -> void:
	"""Update hex capture with real-time sync to all players

	This writes to BOTH:
	1. Firestore (full data for persistence)
	2. RTDB (lightweight trigger for instant sync)
	"""
	if _current_map_id.is_empty():
		capture_recorded.emit(hex_id, false)
		return

	# Determine which collection to use based on map ID
	var collection_name: String = COLLECTION_REALTIME_MAPS if _current_map_id.begins_with("pvp4_") or _current_map_id.begins_with("test_pvp4_") else COLLECTION_PVP_MAPS

	# Write to Firestore for persistence
	if is_ready():
		_do_update_capture_to_collection(hex_id, new_owner_uid, new_owner_name, collection_name)

	# Write to RTDB for real-time trigger
	var rtdb: Variant = _get_rtdb()
	if rtdb:
		var rtdb_path: String = "%s/%s/hexes/%s" % [RTDB_SYNC_PATH, _current_map_id, hex_id]
		var rtdb_ref: Variant = rtdb.get_database_reference(rtdb_path, {})
		if not rtdb_ref or not rtdb_ref.has_method("put"):
			return
		var rtdb_data: Dictionary = {
			"controller_uid": new_owner_uid,
			"controller_name": new_owner_name,
			"captured_at": Time.get_unix_time_from_system(),
			"has_defense": defense_team.size() > 0
		}
		rtdb_ref.put("", rtdb_data)


func _do_update_capture_to_collection(hex_id: String, new_owner_uid: String, new_owner_name: String, collection_name: String) -> void:
	"""Async capture update to specific collection

	GodotFirebase API:
	- collection.update(document: FirestoreDocument) - takes a document object, not ID+dict
	- document.add_or_update_field(field_path, value) - sets top-level fields

	For nested fields like hexes.hex_1_1.controller_uid, we must:
	1. Fetch the full document
	2. Extract and modify the hexes dictionary
	3. Set the whole hexes field back
	4. Call collection.update(document)
	"""
	if not _firestore:
		capture_recorded.emit(hex_id, false)
		return

	var map_collection: Variant = _firestore.collection(collection_name)
	if not map_collection:
		capture_recorded.emit(hex_id, false)
		return

	# Fetch the document first
	var doc: Variant = await map_collection.get_doc(_current_map_id)
	if not doc:
		print("PvPTerritoryDataSync: Failed to fetch document %s for capture update" % _current_map_id)
		capture_recorded.emit(hex_id, false)
		return

	# Extract hexes dictionary from document
	var hexes: Variant = doc.get_value("hexes")
	if hexes == null or not (hexes is Dictionary):
		print("PvPTerritoryDataSync: No hexes found in document %s" % _current_map_id)
		capture_recorded.emit(hex_id, false)
		return

	# Update the specific hex in the hexes dictionary
	if not hexes.has(hex_id):
		print("PvPTerritoryDataSync: Hex %s not found in document" % hex_id)
		capture_recorded.emit(hex_id, false)
		return

	hexes[hex_id]["controller_uid"] = new_owner_uid
	hexes[hex_id]["controller_display_name"] = new_owner_name
	hexes[hex_id]["last_captured_at"] = int(Time.get_unix_time_from_system())

	# Set the entire hexes field back on the document
	doc.add_or_update_field("hexes", hexes)

	# Call collection.update(document) to persist
	var result: Variant = await map_collection.update(doc)
	if result:
		print("PvPTerritoryDataSync: Firestore capture saved for %s -> %s" % [hex_id, new_owner_name])
		capture_recorded.emit(hex_id, true)
	else:
		print("PvPTerritoryDataSync: Firestore update failed for hex %s" % hex_id)
		capture_recorded.emit(hex_id, false)


func update_player_presence(is_online: bool) -> void:
	"""Update player presence in RTDB for disconnect detection"""
	if _current_map_id.is_empty() or _user_id.is_empty():
		return

	var rtdb: Variant = _get_rtdb()
	if not rtdb:
		return

	var presence_path: String = "%s/%s/players/%s" % [RTDB_SYNC_PATH, _current_map_id, _user_id]
	var presence_ref: Variant = rtdb.get_database_reference(presence_path, {})
	if presence_ref and presence_ref.has_method("set_value"):
		var presence_data: Dictionary = {
			"online": is_online,
			"last_seen": Time.get_unix_time_from_system(),
			"display_name": _display_name
		}
		presence_ref.set_value(presence_data)

		# Set on_disconnect behavior (mark as offline when connection lost)
		if presence_ref.has_method("on_disconnect_set_value"):
			presence_ref.on_disconnect_set_value({
				"online": false,
				"last_seen": Time.get_unix_time_from_system(),
				"disconnected": true
			})


func is_realtime_active() -> bool:
	return _is_realtime_active
