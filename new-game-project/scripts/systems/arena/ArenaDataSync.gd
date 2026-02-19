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

var _firestore: Variant = null
var _user_id: String = ""
var _display_name: String = ""

# System reference helper
func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func _ready() -> void:
	# Defer initialization to ensure Firebase is ready
	call_deferred("_initialize_firebase")

func _initialize_firebase() -> void:
	"""Initialize Firebase connection"""
	print("[ArenaDataSync] _initialize_firebase called")
	var system_registry: Variant = _get_system_registry()
	if not system_registry:
		print("[ArenaDataSync] ERROR: SystemRegistry not available")
		return

	var firebase_integration: Variant = system_registry.get_system("FirebaseIntegration")
	if not firebase_integration:
		print("[ArenaDataSync] ERROR: FirebaseIntegration not found")
		return

	# Get Firestore reference
	if firebase_integration.has_method("get_firestore"):
		_firestore = firebase_integration.get_firestore()
		print("[ArenaDataSync] Firestore reference: %s" % ("obtained" if _firestore != null else "NULL"))

	# Get user ID
	if firebase_integration.has_method("get_user_id"):
		_user_id = firebase_integration.get_user_id()
		print("[ArenaDataSync] User ID: '%s'" % _user_id)

	# Get display name from SaveManager (where user sets it after signup)
	var save_manager: Variant = system_registry.get_system("SaveManager")
	if save_manager and save_manager.has_method("get_player_value"):
		_display_name = save_manager.get_player_value("display_name", "")
		print("[ArenaDataSync] Display name from SaveManager: '%s'" % _display_name)

	# Fallback to email username if no display name in save
	if _display_name.is_empty() and firebase_integration.has_method("get_user_email"):
		var email: String = firebase_integration.get_user_email()
		if not email.is_empty() and "@" in email:
			_display_name = email.split("@")[0]
			print("[ArenaDataSync] Display name from email: '%s'" % _display_name)

	print("[ArenaDataSync] is_ready(): %s" % is_ready())
func is_ready() -> bool:
	"""Check if Firebase sync is available"""
	return _firestore != null and not _user_id.is_empty()

func refresh_firebase_connection() -> void:
	"""Refresh Firebase connection - call this after user signs in"""
	print("[ArenaDataSync] refresh_firebase_connection called")
	_initialize_firebase()

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
	print("[ArenaDataSync] _do_fetch_opponents called (ELO: %d-%d, count: %d)" % [min_elo, max_elo, count])

	if not _firestore:
		print("[ArenaDataSync] ERROR: Firestore not available")
		opponents_fetched.emit([])
		return

	# Use list() to get all documents in collection (same as LeaderboardDataSync)
	print("[ArenaDataSync] Fetching via list()...")
	var result: Variant = await _firestore.list(COLLECTION_ARENA_PLAYERS)

	if result == null:
		print("[ArenaDataSync] ERROR: list() returned null")
		opponents_fetched.emit([])
		return

	# Log result details
	if result is Array:
		print("[ArenaDataSync] list() returned %d documents" % result.size())
	else:
		print("[ArenaDataSync] list() returned non-array: %s" % str(result).substr(0, 200))

	var opponents: Array = _parse_opponent_results(result, min_elo, max_elo, count)
	print("[ArenaDataSync] Parsed %d valid opponents" % opponents.size())
	opponents_fetched.emit(opponents)

func _parse_opponent_results(result: Variant, min_elo: int, max_elo: int, count: int) -> Array:
	"""Parse Firestore results into opponent array"""
	var opponents: Array = []

	# Handle different result types from GodotFirebase
	var docs: Array = []
	if result is Array:
		docs = result
	elif result is Object and result.has_method("keys"):
		docs = [result]

	print("[ArenaDataSync] Parsing %d docs (my user_id: %s)" % [docs.size(), _user_id])

	for doc: Variant in docs:
		var user_id: Variant = _get_doc_value(doc, "user_id")
		var display_name: Variant = _get_doc_value(doc, "display_name")
		print("[ArenaDataSync] Doc: user_id=%s, display_name=%s" % [str(user_id), str(display_name)])

		# Skip self
		if user_id == _user_id:
			print("[ArenaDataSync]   -> Skipped (self)")
			continue

		var elo: Variant = _get_doc_value(doc, "elo")
		if typeof(elo) != TYPE_INT and typeof(elo) != TYPE_FLOAT:
			elo = 1000

		# Filter by ELO range
		if elo < min_elo or elo > max_elo:
			print("[ArenaDataSync]   -> Skipped (ELO %s out of range %d-%d)" % [str(elo), min_elo, max_elo])
			continue

		var defense_team: Variant = _get_doc_value(doc, "defense_team")
		print("[ArenaDataSync]   -> ELO=%s, defense_team=%s" % [str(elo), str(defense_team).substr(0, 100) if defense_team else "null"])

			# Get values with proper null handling
		var defense_power: Variant = _get_doc_value(doc, "defense_power")
		var opp_wins: Variant = _get_doc_value(doc, "wins")
		var opp_losses: Variant = _get_doc_value(doc, "losses")
		var last_defense_update: Variant = _get_doc_value(doc, "last_defense_update")

		var opponent: Dictionary = {
			"user_id": user_id,
			"display_name": display_name,
			"elo": int(elo),
			"league": _get_league_for_elo(int(elo)),
			"defense_team": defense_team,
			"defense_power": int(defense_power) if defense_power != null else 0,
			"wins": int(opp_wins) if opp_wins != null else 0,
			"losses": int(opp_losses) if opp_losses != null else 0,
			"last_defense_update": float(last_defense_update) if last_defense_update != null else 0.0
		}

		# Validate defense team exists
		if opponent.defense_team == null or opponent.defense_team.is_empty():
			print("[ArenaDataSync]   -> Skipped (no defense team)")
			continue

		print("[ArenaDataSync]   -> VALID opponent added!")
		opponents.append(opponent)

	# Randomize and limit
	opponents.shuffle()
	return opponents.slice(0, count)

func _get_doc_value(doc: Variant, key: String) -> Variant:
	"""Safely get value from FirestoreDocument"""
	if doc == null:
		return null
	if doc.has_method("get_value"):
		return doc.get_value(key)
	if doc is Dictionary and doc.has(key):
		return doc[key]
	return null

func _get_league_for_elo(elo: int) -> String:
	"""Determine league from ELO using arena_config.json thresholds"""
	var thresholds: Dictionary = _get_league_thresholds()

	for league: String in ["legend", "diamond", "platinum", "gold", "silver", "bronze"]:
		if elo >= thresholds.get(league, 0):
			return league
	return "bronze"

static var _arena_config: Dictionary = {}
static var _arena_config_loaded: bool = false

func _get_league_thresholds() -> Dictionary:
	"""Load league thresholds from arena_config.json (single source of truth)"""
	if not _arena_config_loaded:
		var file := FileAccess.open("res://data/arena_config.json", FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				_arena_config = parsed
		_arena_config_loaded = true
	return _arena_config.get("leagues", {}).get("thresholds", {"legend": 2200, "diamond": 1800, "platinum": 1500, "gold": 1300, "silver": 1100, "bronze": 0})

# ==============================================================================
# DEFENSE TEAM UPLOAD
# ==============================================================================

func upload_defense_team(serialized_team: Array) -> void:
	"""Upload defense team to Firestore"""
	print("[ArenaDataSync] upload_defense_team called with %d gods" % serialized_team.size())
	if not is_ready():
		print("[ArenaDataSync] ERROR: Not ready! firestore=%s, user_id='%s'" % [_firestore != null, _user_id])
		defense_uploaded.emit(false)
		return

	print("[ArenaDataSync] Calling _do_upload_defense deferred")
	_do_upload_defense.call_deferred(serialized_team)

func _do_upload_defense(serialized_team: Array) -> void:
	"""Async defense upload operation"""
	print("[ArenaDataSync] _do_upload_defense starting")
	var collection: Variant = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		print("[ArenaDataSync] ERROR: Could not get collection '%s'" % COLLECTION_ARENA_PLAYERS)
		defense_uploaded.emit(false)
		return

	print("[ArenaDataSync] Got collection reference: %s" % collection)

	# Debug: Check if collection has auth (use 'in' operator for Node properties)
	if "auth" in collection:
		var auth_dict: Variant = collection.auth
		if auth_dict is Dictionary:
			print("[ArenaDataSync] Collection auth keys: %s" % (auth_dict as Dictionary).keys())
			if (auth_dict as Dictionary).has("idtoken"):
				print("[ArenaDataSync] Auth has idtoken (length: %d)" % (auth_dict as Dictionary).get("idtoken", "").length())
			else:
				print("[ArenaDataSync] WARNING: Auth does NOT have idtoken!")
		else:
			print("[ArenaDataSync] WARNING: collection.auth is not a Dictionary: %s" % typeof(auth_dict))
	else:
		print("[ArenaDataSync] WARNING: collection has no 'auth' property")

	var data: Dictionary = {
		"user_id": _user_id,
		"display_name": get_display_name(),
		"defense_team": serialized_team,
		"defense_power": _calculate_serialized_team_power(serialized_team),
		"last_defense_update": Time.get_unix_time_from_system()
	}

	print("[ArenaDataSync] Uploading data for user '%s' with %d gods, power=%d" % [_user_id, serialized_team.size(), data.defense_power])

	# Use set_doc instead of add - set_doc creates or overwrites the document
	# add() uses POST which fails if document already exists
	await collection.set_doc(_user_id, data)

	# set_doc returns void, so verify by fetching the document
	var verify: Variant = await collection.get_doc(_user_id)
	var success: bool = verify != null

	print("[ArenaDataSync] Upload verify result: %s (success: %s)" % [verify, success])
	if not success:
		print("[ArenaDataSync] ERROR: Upload verification failed")
	defense_uploaded.emit(success)

func _calculate_serialized_team_power(team: Array) -> int:
	"""Calculate power from serialized god data using pre-calculated combat_power"""
	var power: int = 0
	for god_data: Dictionary in team:
		# Use pre-calculated combat power if available (from ArenaManager._serialize_god_for_pvp)
		if god_data.has("combat_power"):
			power += int(god_data.get("combat_power", 0))
		else:
			# Fallback for legacy data without combat_power
			power += god_data.get("base_hp", 0) + god_data.get("base_attack", 0) + god_data.get("base_defense", 0) + god_data.get("base_speed", 0)
	return power

func withdraw_from_arena() -> void:
	"""Remove defense team from arena - makes player unattackable"""
	if not is_ready():
		defense_uploaded.emit(false)
		return

	_do_withdraw.call_deferred()

func _do_withdraw() -> void:
	"""Async withdraw operation - clears defense team so player won't appear in opponent lists"""
	var collection: Variant = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		defense_uploaded.emit(false)
		return

	# Clear the defense team (empty array means not attackable)
	var data: Dictionary = {
		"user_id": _user_id,
		"display_name": get_display_name(),
		"defense_team": [],  # Empty = withdrawn
		"defense_power": 0,
		"withdrawn": true,
		"last_defense_update": Time.get_unix_time_from_system()
	}

	print("[ArenaDataSync] Withdrawing from arena (clearing defense team)")
	await collection.set_doc(_user_id, data)
	var verify: Variant = await collection.get_doc(_user_id)
	defense_uploaded.emit(verify != null)

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
	var collection: Variant = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
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

	# Use set_doc to update existing document (same as defense team posting)
	await collection.set_doc(_user_id, data)
	var verify: Variant = await collection.get_doc(_user_id)
	player_stats_updated.emit(verify != null)

# ==============================================================================
# OPPONENT ELO UPDATE (Symmetric ELO)
# ==============================================================================

func update_opponent_after_battle(opponent_uid: String, attacker_won: bool, elo_change: int) -> void:
	"""Update opponent's ELO and defense stats after a battle (symmetric ELO)"""
	if not is_ready() or opponent_uid.is_empty():
		return

	_do_update_opponent.call_deferred(opponent_uid, attacker_won, elo_change)

func _do_update_opponent(opponent_uid: String, attacker_won: bool, elo_change: int) -> void:
	"""Async opponent update - adjusts their ELO inversely and tracks defense W/L"""
	var collection: Variant = _firestore.collection(COLLECTION_ARENA_PLAYERS) if _firestore else null
	if not collection:
		return

	# Fetch opponent's current stats
	var doc: Variant = await collection.get_doc(opponent_uid)
	if not doc:
		print("[ArenaDataSync] Could not fetch opponent %s for ELO update" % opponent_uid)
		return

	var current_elo: int = int(_get_doc_value(doc, "elo")) if _get_doc_value(doc, "elo") else 1000
	var defense_wins: int = int(_get_doc_value(doc, "defense_wins")) if _get_doc_value(doc, "defense_wins") else 0
	var defense_losses: int = int(_get_doc_value(doc, "defense_losses")) if _get_doc_value(doc, "defense_losses") else 0

	# Symmetric ELO: opponent loses/gains the inverse
	var opponent_elo_change: int = -elo_change if attacker_won else abs(elo_change)
	var new_elo: int = max(0, current_elo + opponent_elo_change)

	# Update defense W/L
	if attacker_won:
		defense_losses += 1
	else:
		defense_wins += 1

	print("[ArenaDataSync] Updating opponent %s: ELO %d -> %d (%+d), Defense W/L: %d/%d" % [
		opponent_uid, current_elo, new_elo, opponent_elo_change, defense_wins, defense_losses
	])

	# Update opponent's record
	var update_data: Dictionary = {
		"elo": new_elo,
		"league": _get_league_for_elo(new_elo),
		"defense_wins": defense_wins,
		"defense_losses": defense_losses,
		"last_defense_battle": Time.get_unix_time_from_system()
	}

	await collection.set_doc(opponent_uid, update_data)

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
	var collection: Variant = _firestore.collection(COLLECTION_ARENA_BATTLES) if _firestore else null
	if not collection:
		battle_recorded.emit(false)
		return

	# Generate unique battle ID using timestamp and user IDs
	var timestamp: int = int(Time.get_unix_time_from_system() * 1000)
	var battle_id: String = "%s_%s_%d" % [_user_id, opponent_uid, timestamp]

	var battle_data: Dictionary = {
		"attacker_uid": _user_id,
		"defender_uid": opponent_uid,
		"winner": "attacker" if victory else "defender",
		"attacker_elo_change": elo_change,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Use add with unique ID for battle records
	var result: Variant = await collection.add(battle_id, battle_data)
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
	if not _firestore:
		leaderboard_fetched.emit([])
		return

	# Use list() to get all documents in collection
	var result: Variant = await _firestore.list(COLLECTION_ARENA_PLAYERS)

	if result == null:
		leaderboard_fetched.emit([])
		return

	var entries: Array = _parse_leaderboard_results(result)
	leaderboard_fetched.emit(entries)

func _parse_leaderboard_results(result: Variant) -> Array:
	"""Parse leaderboard results and sort by ELO"""
	var entries: Array = []

	var docs: Array = []
	if result is Array:
		docs = result
	elif result is Object and result.has_method("keys"):
		docs = [result]

	for doc: Variant in docs:
		var elo: Variant = _get_doc_value(doc, "elo")
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
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.elo > b.elo)

	# Assign ranks and limit to top 100
	for i: int in range(mini(100, entries.size())):
		entries[i]["rank"] = i + 1

	return entries.slice(0, 100)
