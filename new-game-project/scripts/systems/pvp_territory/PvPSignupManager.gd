# scripts/systems/pvp_territory/PvPSignupManager.gd
# Manages 4-player PvP territory matchmaking queue
extends Node
class_name PvPSignupManager

"""
PvPSignupManager.gd - Handles matchmaking queue for 4-player PvP territory
RULE 2: Single responsibility - ONLY manages queue joining/leaving and match creation

Flow:
1. Player calls join_queue() -> added to Firestore queue document
2. Poll timer checks queue status every 2 seconds
3. When 4 players present -> create match and notify all
4. Match creation generates map and assigns spawn positions
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal queue_joined()
signal queue_left()
signal queue_updated(player_count: int, players: Array)
signal match_found(map_id: String, spawn_index: int, players: Array)
signal queue_error(message: String)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const QUEUE_COLLECTION := "pvp_queues"
const QUEUE_DOC_ID := "4player_queue"
const MAPS_COLLECTION := "pvp_realtime_maps"
const REQUIRED_PLAYERS := 4
const POLL_INTERVAL := 2.0  # Check queue every 2 seconds
const QUEUE_TIMEOUT := 300  # 5 minutes max in queue

# ==============================================================================
# STATE
# ==============================================================================
var _is_in_queue: bool = false
var _queue_join_time: int = 0
var _poll_timer: Timer = null
var _current_user_uid: String = ""
var _current_display_name: String = ""
var _firestore: Variant = null
var _is_creating_match: bool = false

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_setup_poll_timer()
	_init_firebase()


func _setup_poll_timer() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_timer)
	add_child(_poll_timer)


func _init_firebase() -> void:
	refresh_firebase_connection()


func refresh_firebase_connection() -> void:
	"""Refresh Firebase connection - call this when sign-in state may have changed"""
	var registry := SystemRegistry.get_instance()
	if not registry:
		return

	var firebase_integration := registry.get_system("FirebaseIntegration")
	if firebase_integration:
		_firestore = firebase_integration.get_firestore()
		_current_user_uid = firebase_integration.get_user_id()

		# Listen for future sign-in events
		if firebase_integration.has_signal("sign_in_completed"):
			if not firebase_integration.sign_in_completed.is_connected(_on_sign_in_completed):
				firebase_integration.sign_in_completed.connect(_on_sign_in_completed)

		# Get display name from SaveManager
		var save_manager := registry.get_system("SaveManager")
		if save_manager and save_manager.has_method("get_player_value"):
			_current_display_name = save_manager.get_player_value("display_name", "")

		# Fallback to email username if no display name
		if _current_display_name.is_empty() and firebase_integration.has_method("get_user_email"):
			var email: String = firebase_integration.get_user_email()
			if not email.is_empty() and "@" in email:
				_current_display_name = email.split("@")[0]

		print("PvPSignupManager: Firebase connection - firestore=%s, user_uid=%s, display_name=%s" % [
			_firestore != null, _current_user_uid, _current_display_name
		])


func _on_sign_in_completed(_user_data: Dictionary) -> void:
	"""Called when Firebase sign-in completes - refresh our connection"""
	print("PvPSignupManager: Sign-in completed, refreshing Firebase connection")
	refresh_firebase_connection()


# ==============================================================================
# PUBLIC API
# ==============================================================================

func join_queue() -> void:
	"""Join the 4-player matchmaking queue"""
	if _is_in_queue:
		push_warning("PvPSignupManager: Already in queue")
		return

	# Allow offline/test mode
	if not _firestore or _current_user_uid.is_empty():
		print("PvPSignupManager: Firebase not available, use START TEST MATCH for offline testing")
		queue_error.emit("Not connected. Use TEST MATCH for offline play.")
		return

	_queue_join_time = int(Time.get_unix_time_from_system())
	_add_to_queue()


func start_test_match() -> void:
	"""Start a test match with simulated players (for offline testing)"""
	print("PvPSignupManager: Starting test match with simulated players")

	# Ensure we have a user ID for testing
	if _current_user_uid.is_empty():
		_current_user_uid = "test_player_1"
	if _current_display_name.is_empty():
		_current_display_name = "You"

	# Simulate joining queue
	_is_in_queue = true
	queue_joined.emit()

	# Create mock players
	var mock_players: Array = [
		{"uid": _current_user_uid, "display_name": _current_display_name, "ready": true},
		{"uid": "bot_2", "display_name": "DragonSlayer", "ready": true},
		{"uid": "bot_3", "display_name": "ShadowKnight", "ready": true},
		{"uid": "bot_4", "display_name": "CrystalMage", "ready": true}
	]

	# Simulate queue filling up with delays
	_simulate_queue_fill(mock_players)


func autofill_and_start(current_players: Array) -> void:
	"""Fill remaining slots with bots and start match immediately"""
	print("PvPSignupManager: Autofilling match with %d real players" % current_players.size())

	if current_players.is_empty():
		queue_error.emit("No players in queue to autofill")
		return

	# Bot names pool
	var bot_names: Array[String] = [
		"DragonSlayer", "ShadowKnight", "CrystalMage", "StormBringer",
		"IronWarden", "FlameHeart", "FrostQueen", "ThunderLord"
	]
	bot_names.shuffle()

	# Build full player list with real players + bots
	var full_players: Array = current_players.duplicate()
	var bot_index: int = 0

	while full_players.size() < REQUIRED_PLAYERS:
		var bot_name: String = bot_names[bot_index % bot_names.size()]
		full_players.append({
			"uid": "bot_%d_%d" % [bot_index + 1, int(Time.get_unix_time_from_system())],
			"display_name": bot_name,
			"ready": true,
			"is_bot": true
		})
		bot_index += 1

	# Show the filled queue
	queue_updated.emit(full_players.size(), full_players)

	# Brief pause then create match
	await get_tree().create_timer(0.5).timeout

	# Decide whether to use Firebase or local test match
	if _firestore and not _current_user_uid.is_empty() and not _current_user_uid.begins_with("test_"):
		# Real match with Firebase (real players + bots stored in Firebase)
		_create_match_with_bots(full_players)
	else:
		# Local test match
		_create_test_match(full_players)


func _create_match_with_bots(players: Array) -> void:
	"""Create a Firebase match with mix of real players and bots"""
	if _is_creating_match:
		return

	_is_creating_match = true
	# Stop polling so we don't race with map creation
	_poll_timer.stop()
	print("PvPSignupManager: Creating match with %d players (including bots)" % players.size())

	var map_id: String = "pvp4_%d" % int(Time.get_unix_time_from_system())

	var update_data := {
		"players": players,
		"status": "starting",
		"map_id": map_id,
		"updated_at": Time.get_unix_time_from_system()
	}

	# Update queue status to "starting"
	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_set_queue_doc(queue_ref, update_data, _on_queue_marked_starting.bind(map_id, players))


func _simulate_queue_fill(players: Array) -> void:
	"""Simulate players joining one by one"""
	# Show 1 player (you)
	queue_updated.emit(1, [players[0]])

	# Create timer to add more players
	var timer := get_tree().create_timer(0.8)
	await timer.timeout
	queue_updated.emit(2, players.slice(0, 2))

	timer = get_tree().create_timer(0.6)
	await timer.timeout
	queue_updated.emit(3, players.slice(0, 3))

	timer = get_tree().create_timer(0.5)
	await timer.timeout
	queue_updated.emit(4, players)

	# Brief pause then create match
	timer = get_tree().create_timer(0.5)
	await timer.timeout
	_create_test_match(players)


func _create_test_match(players: Array) -> void:
	"""Create a test match locally without Firebase"""
	var map_id: String = "test_pvp4_%d" % int(Time.get_unix_time_from_system())

	# Generate the map
	var map_data: Dictionary = PvPMapGenerator.generate_4player_map()
	var hexes: Dictionary = map_data.get("hexes", {})
	var config: Dictionary = map_data.get("config", {})
	var spawn_positions: Array = config.get("spawn_positions", [])

	# Assign players to spawn positions
	var player_assignments: Array = []
	for i: int in range(mini(players.size(), spawn_positions.size())):
		var player: Dictionary = players[i]
		var spawn_coord: Vector2i = spawn_positions[i] if i < spawn_positions.size() else Vector2i.ZERO
		var player_uid: String = player.get("uid", "")

		player_assignments.append({
			"player_uid": player_uid,  # PvPMapInstance expects player_uid
			"uid": player_uid,  # Keep for backwards compat
			"display_name": player.get("display_name", ""),
			"spawn_coord": {"q": spawn_coord.x, "r": spawn_coord.y},
			"spawn_index": i,
			"color_index": i
		})

		# Claim spawn hexes for player
		if hexes.size() > 0:
			var spawn_hexes: Dictionary = PvPMapGenerator.generate_spawn_hexes_for_player(
				spawn_coord,
				player.get("uid", ""),
				player.get("display_name", ""),
				hexes
			)
			for hex_id: String in spawn_hexes:
				hexes[hex_id] = spawn_hexes[hex_id]

	# Generate defense teams for bot players
	_generate_bot_defense_teams(players, hexes)

	# Store map data in data sync for later retrieval
	var registry := SystemRegistry.get_instance()
	if registry:
		var data_sync = registry.get_system("PvPTerritoryDataSync")
		if data_sync and data_sync.has_method("set_test_map_data"):
			data_sync.set_test_map_data(map_id, hexes, player_assignments, _current_user_uid)

	print("PvPSignupManager: Test match created: %s with user %s" % [map_id, _current_user_uid])

	_is_in_queue = false
	match_found.emit(map_id, 0, player_assignments)


func leave_queue() -> void:
	"""Leave the matchmaking queue"""
	if not _is_in_queue:
		return

	_remove_from_queue()
	_is_in_queue = false
	_poll_timer.stop()
	queue_left.emit()


func is_in_queue() -> bool:
	return _is_in_queue


func restore_queue_state() -> void:
	"""Restore queue state from Firebase (called when screen reopens)"""
	if _is_in_queue:
		return  # Already in queue

	_is_in_queue = true
	_queue_join_time = int(Time.get_unix_time_from_system())  # Reset timer
	_poll_timer.start()
	queue_joined.emit()
	print("PvPSignupManager: Queue state restored, polling started")


func get_queue_time() -> int:
	"""Get seconds spent in queue"""
	if not _is_in_queue:
		return 0
	return int(Time.get_unix_time_from_system()) - _queue_join_time


# ==============================================================================
# QUEUE OPERATIONS
# ==============================================================================

func _add_to_queue() -> void:
	"""Add current player to Firestore queue"""
	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)

	# First, fetch current queue state
	_do_get_queue_doc(queue_ref, _on_queue_fetch_for_join)


func _on_queue_fetch_for_join(result: Variant) -> void:
	var players: Array = []
	var status: String = "waiting"

	if result and result is FirestoreDocument:
		var data: Dictionary = _extract_document_data(result)
		var players_raw: Variant = data.get("players", [])
		if players_raw is Array:
			players = players_raw
		status = str(data.get("status", "waiting"))

	# Check if match already starting
	if status == "starting":
		queue_error.emit("A match is already starting. Please wait.")
		return

	# Check if already in queue
	for player: Dictionary in players:
		if player.get("uid", "") == _current_user_uid:
			# Already in queue, just start polling
			_is_in_queue = true
			_poll_timer.start()
			queue_joined.emit()
			return

	# Check if queue full
	if players.size() >= REQUIRED_PLAYERS:
		queue_error.emit("Queue is full. Please wait for current match to start.")
		return

	# Add self to queue
	players.append({
		"uid": _current_user_uid,
		"display_name": _current_display_name,
		"joined_at": Time.get_unix_time_from_system(),
		"ready": true
	})

	# Update queue document
	var update_data := {
		"players": players,
		"status": "waiting",
		"updated_at": Time.get_unix_time_from_system()
	}

	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_set_queue_doc(queue_ref, update_data, _on_queue_join_complete)


func _on_queue_join_complete(_result: Variant) -> void:
	_is_in_queue = true
	_poll_timer.start()
	queue_joined.emit()
	print("PvPSignupManager: Joined queue")


func _remove_from_queue() -> void:
	"""Remove current player from Firestore queue"""
	if not _firestore:
		return

	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_get_queue_doc(queue_ref, _on_queue_fetch_for_leave)


func _on_queue_fetch_for_leave(result: Variant) -> void:
	if not result or not result is FirestoreDocument:
		return

	var data: Dictionary = _extract_document_data(result)
	var players_raw: Variant = data.get("players", [])
	var players: Array = players_raw if players_raw is Array else []

	# Remove self from players
	var new_players: Array = []
	for player: Dictionary in players:
		if player.get("uid", "") != _current_user_uid:
			new_players.append(player)

	var update_data := {
		"players": new_players,
		"status": "waiting" if new_players.size() < REQUIRED_PLAYERS else data.get("status", "waiting"),
		"updated_at": Time.get_unix_time_from_system()
	}

	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_set_queue_doc(queue_ref, update_data, func(_r: Variant) -> void: pass)
	print("PvPSignupManager: Left queue")


# ==============================================================================
# POLL TIMER
# ==============================================================================

func _on_poll_timer() -> void:
	"""Poll queue status periodically"""
	if not _is_in_queue or not _firestore:
		return

	# Check for timeout
	if get_queue_time() > QUEUE_TIMEOUT:
		leave_queue()
		queue_error.emit("Queue timed out. Please try again.")
		return

	_fetch_queue_status()


func _fetch_queue_status() -> void:
	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_get_queue_doc(queue_ref, _on_queue_status_received)


func _on_queue_status_received(result: Variant) -> void:
	if not result or not result is FirestoreDocument:
		return

	var data: Dictionary = _extract_document_data(result)
	var players_raw: Variant = data.get("players", [])
	var players: Array = players_raw if players_raw is Array else []
	var status: String = str(data.get("status", "waiting"))
	var map_id: String = str(data.get("map_id", ""))

	# Emit update for UI
	queue_updated.emit(players.size(), players)

	# Check if match already created by another player
	if status == "starting" and not map_id.is_empty():
		_handle_match_started(map_id, players)
		return

	# Check if we should create the match (first player to see 4 creates it)
	if players.size() >= REQUIRED_PLAYERS and status == "waiting" and not _is_creating_match:
		_create_match(players)


# ==============================================================================
# MATCH CREATION
# ==============================================================================

func _create_match(players: Array) -> void:
	"""Create the match - only one player should do this"""
	if _is_creating_match:
		return

	_is_creating_match = true
	# Stop polling so we don't race with map creation
	_poll_timer.stop()
	print("PvPSignupManager: Creating match for %d players" % players.size())

	var map_id: String = "pvp4_%d" % int(Time.get_unix_time_from_system())

	var update_data := {
		"players": players,
		"status": "starting",
		"map_id": map_id,
		"updated_at": Time.get_unix_time_from_system()
	}

	# First, update queue status to "starting" to prevent others from creating
	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_set_queue_doc(queue_ref, update_data, _on_queue_marked_starting.bind(map_id, players))


func _on_queue_marked_starting(result: Variant, map_id: String, players: Array) -> void:
	if not result:
		_is_creating_match = false
		return

	# Generate the map
	var map_data: Dictionary = PvPMapGenerator.generate_4player_map()
	var hexes: Dictionary = map_data.get("hexes", {})
	var config: Dictionary = map_data.get("config", {})
	var spawn_positions: Array = config.get("spawn_positions", [])

	# Assign players to spawn positions
	var player_assignments: Array = []
	for i: int in range(mini(players.size(), spawn_positions.size())):
		var player: Dictionary = players[i]
		var spawn_coord: Vector2i = spawn_positions[i] if i < spawn_positions.size() else Vector2i.ZERO
		var player_uid: String = player.get("uid", "")

		player_assignments.append({
			"player_uid": player_uid,  # PvPMapInstance expects player_uid
			"uid": player_uid,  # Keep for backwards compat
			"display_name": player.get("display_name", ""),
			"spawn_coord": {"q": spawn_coord.x, "r": spawn_coord.y},
			"spawn_index": i,
			"color_index": i
		})

		# Claim spawn hexes for player
		if hexes.size() > 0:
			var spawn_hexes: Dictionary = PvPMapGenerator.generate_spawn_hexes_for_player(
				spawn_coord,
				player.get("uid", ""),
				player.get("display_name", ""),
				hexes
			)
			# Merge spawn node into hexes
			for hex_id: String in spawn_hexes:
				hexes[hex_id] = spawn_hexes[hex_id]

	# Generate defense teams for bot players
	_generate_bot_defense_teams(players, hexes)

	# Create map document in Firestore
	_create_map_document(map_id, hexes, player_assignments)


func _create_map_document(map_id: String, hexes: Dictionary, players: Array) -> void:
	"""Create the map document in Firestore"""
	# Serialize hexes for Firestore
	var hexes_data: Dictionary = {}
	for hex_id: String in hexes:
		var hex: PvPHexNode = hexes[hex_id]
		hexes_data[hex_id] = _serialize_hex(hex)

	var map_data := {
		"map_id": map_id,
		"status": "active",
		"player_count": players.size(),
		"max_players": 4,
		"players": players,
		"hexes": hexes_data,
		"created_at": Time.get_unix_time_from_system(),
		"map_type": "4player"
	}

	var maps_ref: Variant = _firestore.collection(MAPS_COLLECTION)
	_do_set_map_doc(maps_ref, map_id, map_data, _on_map_created.bind(map_id, players))


func _serialize_hex(hex: PvPHexNode) -> Dictionary:
	"""Serialize hex for Firestore storage"""
	return {
		"id": hex.id,
		"name": hex.name,
		"tier": hex.tier,
		"coord": {"q": hex.coord.q, "r": hex.coord.r} if hex.coord else {"q": 0, "r": 0},
		"controller_uid": hex.controller_uid,
		"controller_display_name": hex.controller_display_name,
		"is_spawn_node": hex.is_spawn_node,
		"is_objective": hex.is_objective,
		"is_mega_node": hex.is_mega_node,
		"objective_value": hex.objective_value,
		"fixed_production": hex.fixed_production,
		"passive_bonuses": hex.passive_bonuses,
		"capture_power_required": hex.capture_power_required,
		"defense_power": hex.defense_power,
		"defense_team_serialized": hex.defense_team_serialized
	}


func _on_map_created(result: Variant, map_id: String, players: Array) -> void:
	_is_creating_match = false

	if not result:
		queue_error.emit("Failed to create match")
		return

	print("PvPSignupManager: Map created: %s" % map_id)

	# Clear the queue for next match
	_clear_queue()

	# Notify self about match
	_handle_match_started(map_id, players)


func _clear_queue() -> void:
	"""Reset queue for next match"""
	var empty_data := {
		"players": [],
		"status": "waiting",
		"map_id": "",
		"updated_at": Time.get_unix_time_from_system()
	}

	var queue_ref: Variant = _firestore.collection(QUEUE_COLLECTION)
	_do_set_queue_doc(queue_ref, empty_data, func(_r: Variant) -> void: pass)


func _handle_match_started(map_id: String, players: Array) -> void:
	"""Handle when a match has been created"""
	_is_in_queue = false
	_poll_timer.stop()

	# Find my spawn index
	var my_spawn_index: int = 0
	for i: int in range(players.size()):
		var player: Dictionary = players[i]
		if player.get("uid", "") == _current_user_uid:
			my_spawn_index = player.get("spawn_index", i)
			break

	print("PvPSignupManager: Match found! Map: %s, Spawn: %d" % [map_id, my_spawn_index])
	match_found.emit(map_id, my_spawn_index, players)


# ==============================================================================
# FIREBASE HELPERS
# ==============================================================================

func _extract_document_data(doc: FirestoreDocument) -> Dictionary:
	"""Extract plain Dictionary from FirestoreDocument"""
	var result: Dictionary = {}
	if not doc.has_method("keys") or not doc.has_method("get_value"):
		return result
	for key in doc.keys():
		result[key] = doc.get_value(key)
	return result


func _do_get_queue_doc(queue_ref: Variant, callback: Callable) -> void:
	"""Fetch queue document from Firestore and call callback with result"""
	var result: Variant = await queue_ref.get_doc(QUEUE_DOC_ID)
	callback.call(result)


func _do_set_queue_doc(queue_ref: Variant, data: Dictionary, callback: Callable) -> void:
	"""Set queue document in Firestore and call callback with result"""
	await queue_ref.set_doc(QUEUE_DOC_ID, data)
	# set_doc returns void, so verify by fetching
	var result: Variant = await queue_ref.get_doc(QUEUE_DOC_ID)
	callback.call(result)


func _do_set_map_doc(maps_ref: Variant, map_id: String, data: Dictionary, callback: Callable) -> void:
	"""Set map document in Firestore and call callback with result"""
	await maps_ref.set_doc(map_id, data)
	# set_doc returns void, so verify by fetching
	var result: Variant = await maps_ref.get_doc(map_id)
	callback.call(result)


# ==============================================================================
# BOT DEFENSE TEAM GENERATION
# ==============================================================================

func _generate_bot_defense_teams(players: Array, hexes: Dictionary) -> void:
	"""Generate defense teams for all hexes controlled by bot players"""
	# Identify bot player UIDs
	var bot_uids: Array[String] = []
	for player: Dictionary in players:
		var uid: String = player.get("uid", "")
		var is_bot: bool = player.get("is_bot", false)
		# Also treat any player that's not the current user as a bot for defense gen
		if is_bot or (uid.begins_with("bot_") and uid != _current_user_uid):
			bot_uids.append(uid)

	if bot_uids.is_empty():
		return

	print("PvPSignupManager: Generating defense teams for %d bots" % bot_uids.size())

	# Generate defense teams for each hex owned by bots
	for hex_id: String in hexes:
		var hex: PvPHexNode = hexes[hex_id]
		if hex.controller_uid in bot_uids:
			var defense_data: Dictionary = _generate_defense_team_for_tier(hex.tier)
			hex.defense_team_serialized = defense_data.get("team", [])
			hex.defense_power = defense_data.get("power", 0)


func _generate_defense_team_for_tier(tier: int) -> Dictionary:
	"""Generate a defense team appropriate for the hex tier"""
	var team: Array = []
	var team_size: int = mini(tier + 1, 4)  # 2-4 gods based on tier
	var total_power: int = 0

	# Try to use real god templates for proper portraits
	var template_ids: Array = _get_available_god_templates()
	template_ids.shuffle()

	for i: int in range(team_size):
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
				"equipment": {},
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
				"equipment": {},
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


func _get_available_god_templates() -> Array:
	"""Get list of god template IDs that can be used for AI defenders"""
	var template_ids: Array = []

	var registry := SystemRegistry.get_instance()
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
# CLEANUP
# ==============================================================================

func _exit_tree() -> void:
	if _is_in_queue:
		leave_queue()
