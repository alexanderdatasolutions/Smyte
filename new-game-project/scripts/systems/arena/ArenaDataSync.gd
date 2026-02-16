# scripts/systems/arena/ArenaDataSync.gd
# Firebase synchronization for arena data
class_name ArenaDataSync extends Node

signal opponents_fetched(opponents: Array)
signal defense_uploaded(success: bool)
signal leaderboard_fetched(entries: Array)
signal player_stats_updated(success: bool)
signal battle_recorded(success: bool)

const COLLECTION_ARENA_PLAYERS = "arena_players"
const COLLECTION_ARENA_BATTLES = "arena_battles"

var _firestore = null
var _user_id: String = ""
var _display_name: String = ""

# System reference helper
func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func _ready() -> void:
	# Defer initialization to ensure Firebase is ready
	call_deferred("_initialize_firebase")

func _initialize_firebase() -> void:
	"""Initialize Firebase connection"""
	var system_registry = _get_system_registry()
	if not system_registry:
		return

	var firebase_integration = system_registry.get_system("FirebaseIntegration")
	if not firebase_integration:
		return

	# Get Firestore reference
	if firebase_integration.has_method("get_firestore"):
		_firestore = firebase_integration.get_firestore()

	# Get user ID
	if firebase_integration.has_method("get_user_id"):
		_user_id = firebase_integration.get_user_id()

	# Get display name
	if firebase_integration.has_method("get_user_display_name"):
		_display_name = firebase_integration.get_user_display_name()

	if is_ready():
		pass
func is_ready() -> bool:
	"""Check if Firebase sync is available"""
	return _firestore != null and not _user_id.is_empty()

func get_user_id() -> String:
	return _user_id

func get_display_name() -> String:
	return _display_name if not _display_name.is_empty() else "Player"

# ==============================================================================
# OPPONENT FETCHING
# ==============================================================================

func fetch_opponents_in_range(min_elo: int, max_elo: int, count: int) -> void:
	"""Fetch opponents within ELO range from Firestore"""
	if not is_ready():
		opponents_fetched.emit([])
		return

	_do_fetch_opponents.call_deferred(min_elo, max_elo, count)

func _do_fetch_opponents(min_elo: int, max_elo: int, count: int) -> void:
	"""Async opponent fetch operation"""
	var collection = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		opponents_fetched.emit([])
		return

	var query = collection.query() if collection.has_method("query") else null
	if not query:
		opponents_fetched.emit([])
		return

	var result = await query.get()

	if result == null:
		opponents_fetched.emit([])
		return

	var opponents: Array = _parse_opponent_results(result, min_elo, max_elo, count)
	opponents_fetched.emit(opponents)

func _parse_opponent_results(result, min_elo: int, max_elo: int, count: int) -> Array:
	"""Parse Firestore results into opponent array"""
	var opponents = []

	# Handle different result types from GodotFirebase
	var docs: Array = []
	if result is Array:
		docs = result
	elif result is Object and result.has_method("keys"):
		docs = [result]

	for doc in docs:
		var user_id = _get_doc_value(doc, "user_id")

		# Skip self
		if user_id == _user_id:
			continue

		var elo = _get_doc_value(doc, "elo")
		if typeof(elo) != TYPE_INT and typeof(elo) != TYPE_FLOAT:
			elo = 1000

		# Filter by ELO range
		if elo < min_elo or elo > max_elo:
			continue

		var opponent = {
			"user_id": user_id,
			"display_name": _get_doc_value(doc, "display_name"),
			"elo": int(elo),
			"league": _get_league_for_elo(int(elo)),
			"defense_team": _get_doc_value(doc, "defense_team"),
			"defense_power": _get_doc_value(doc, "defense_power"),
			"wins": _get_doc_value(doc, "wins"),
			"losses": _get_doc_value(doc, "losses")
		}

		# Validate defense team exists
		if opponent.defense_team == null or opponent.defense_team.is_empty():
			continue

		opponents.append(opponent)

	# Randomize and limit
	opponents.shuffle()
	return opponents.slice(0, count)

func _get_doc_value(doc, key: String):
	"""Safely get value from FirestoreDocument"""
	if doc == null:
		return null
	if doc.has_method("get_value"):
		return doc.get_value(key)
	if doc is Dictionary and doc.has(key):
		return doc[key]
	return null

func _get_league_for_elo(elo: int) -> String:
	"""Determine league from ELO"""
	const THRESHOLDS = {
		"legend": 2200,
		"diamond": 1800,
		"platinum": 1500,
		"gold": 1300,
		"silver": 1100,
		"bronze": 0
	}

	for league in ["legend", "diamond", "platinum", "gold", "silver", "bronze"]:
		if elo >= THRESHOLDS[league]:
			return league
	return "bronze"

# ==============================================================================
# DEFENSE TEAM UPLOAD
# ==============================================================================

func upload_defense_team(serialized_team: Array) -> void:
	"""Upload defense team to Firestore"""
	if not is_ready():
		defense_uploaded.emit(false)
		return

	_do_upload_defense.call_deferred(serialized_team)

func _do_upload_defense(serialized_team: Array) -> void:
	"""Async defense upload operation"""
	var collection = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		defense_uploaded.emit(false)
		return

	var data: Dictionary = {
		"user_id": _user_id,
		"display_name": get_display_name(),
		"defense_team": serialized_team,
		"defense_power": _calculate_serialized_team_power(serialized_team),
		"last_defense_update": Time.get_unix_time_from_system()
	}

	var result = await collection.add(_user_id, data)
	defense_uploaded.emit(result != null)

func _calculate_serialized_team_power(team: Array) -> int:
	"""Calculate power from serialized god data"""
	var power = 0
	for god_data in team:
		power += god_data.get("base_hp", 0) / 10
		power += god_data.get("base_attack", 0)
		power += god_data.get("base_defense", 0)
		power += god_data.get("base_speed", 0) * 2
		power += god_data.get("level", 1) * 100
	return power

# ==============================================================================
# PLAYER STATS
# ==============================================================================

func update_player_stats(elo: int, wins: int, losses: int) -> void:
	"""Update player arena stats in Firestore"""
	if not is_ready():
		player_stats_updated.emit(false)
		return

	_do_update_stats.call_deferred(elo, wins, losses)

func _do_update_stats(elo: int, wins: int, losses: int) -> void:
	"""Async stats update operation"""
	var collection = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		player_stats_updated.emit(false)
		return

	var data: Dictionary = {
		"user_id": _user_id,
		"display_name": get_display_name(),
		"elo": elo,
		"league": _get_league_for_elo(elo),
		"wins": wins,
		"losses": losses,
		"last_active": Time.get_unix_time_from_system()
	}

	var result = await collection.add(_user_id, data)
	player_stats_updated.emit(result != null)

# ==============================================================================
# BATTLE RECORDING
# ==============================================================================

func record_battle(opponent_uid: String, victory: bool, elo_change: int) -> void:
	"""Record a battle result in Firestore"""
	if not is_ready():
		battle_recorded.emit(false)
		return

	_do_record_battle.call_deferred(opponent_uid, victory, elo_change)

func _do_record_battle(opponent_uid: String, victory: bool, elo_change: int) -> void:
	"""Async battle recording operation"""
	var collection = _firestore.collection(COLLECTION_ARENA_BATTLES) if _firestore else null
	if not collection:
		battle_recorded.emit(false)
		return

	var battle_data: Dictionary = {
		"attacker_uid": _user_id,
		"defender_uid": opponent_uid,
		"winner": "attacker" if victory else "defender",
		"attacker_elo_change": elo_change,
		"timestamp": Time.get_unix_time_from_system()
	}

	var result = await collection.add("", battle_data)
	battle_recorded.emit(result != null)

# ==============================================================================
# LEADERBOARD
# ==============================================================================

func fetch_leaderboard() -> void:
	"""Fetch top players leaderboard"""
	if not is_ready():
		leaderboard_fetched.emit([])
		return

	_do_fetch_leaderboard.call_deferred()

func _do_fetch_leaderboard() -> void:
	"""Async leaderboard fetch operation"""
	var collection = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		leaderboard_fetched.emit([])
		return

	var query = collection.query() if collection.has_method("query") else null
	if not query:
		leaderboard_fetched.emit([])
		return

	var result = await query.get()

	if result == null:
		leaderboard_fetched.emit([])
		return

	var entries: Array = _parse_leaderboard_results(result)
	leaderboard_fetched.emit(entries)

func _parse_leaderboard_results(result) -> Array:
	"""Parse leaderboard results and sort by ELO"""
	var entries = []

	var docs: Array = []
	if result is Array:
		docs = result
	elif result is Object and result.has_method("keys"):
		docs = [result]

	for doc in docs:
		var elo = _get_doc_value(doc, "elo")
		if typeof(elo) != TYPE_INT and typeof(elo) != TYPE_FLOAT:
			continue

		entries.append({
			"user_id": _get_doc_value(doc, "user_id"),
			"display_name": _get_doc_value(doc, "display_name"),
			"elo": int(elo),
			"league": _get_league_for_elo(int(elo)),
			"wins": _get_doc_value(doc, "wins"),
			"losses": _get_doc_value(doc, "losses")
		})

	# Sort by ELO descending
	entries.sort_custom(func(a, b): return a.elo > b.elo)

	# Assign ranks and limit to top 100
	for i in range(min(100, entries.size())):
		entries[i]["rank"] = i + 1

	return entries.slice(0, 100)
