# scripts/systems/leaderboard/LeaderboardDataSync.gd
# Simple Firebase sync for player stats and leaderboards
# Uploads player metrics to Firestore on key events
# BigQuery can query these for analytics
class_name LeaderboardDataSync extends Node

signal leaderboard_fetched(category: String, entries: Array)
signal upload_completed(success: bool)

const COLLECTION := "player_stats"

# All tracked metrics - uploaded to Firebase, queryable from BigQuery
const METRICS := {
	# Collection
	"highest_god_level": "Highest God Level",
	"highest_god_power": "Highest God Power",
	"highest_team_power": "Highest Team Power",
	"total_power": "Total Power",
	"gods_collected": "Gods Collected",
	"unique_gods_collected": "Unique Gods",
	"legendary_gods": "Legendary Gods",
	"epic_gods": "Epic Gods",
	"max_level_gods": "Max Level Gods",
	"legendary_gods_obtained": "Legendary Summons (Owned)",
	"epic_gods_obtained": "Epic Summons (Owned)",
	# Combat
	"battles_won": "Battles Won",
	"total_battles": "Total Battles",
	"perfect_victories": "Perfect Victories",
	"longest_win_streak": "Longest Win Streak",
	"total_enemies_killed": "Enemies Killed",
	"dungeons_cleared": "Dungeons Cleared",
	"tower_best_floor": "Tower Best Floor",
	"tower_floors_cleared": "Tower Floors Cleared",
	"arena_elo": "Arena Rating",
	# Territory & Buildings
	"territories_owned": "Territories Owned",
	"territory_conquests": "Territory Conquests",
	"buildings_placed": "Buildings Placed",
	"total_building_levels": "Building Levels",
	"highest_building_level": "Highest Building",
	# Economy & Resources
	"equipment_crafted": "Equipment Crafted",
	"total_summons": "Total Summons",
	"legendary_summons": "Legendary Summons",
	"epic_summons": "Epic Summons",
	"gods_sacrificed": "Gods Sacrificed",
	"gold_balance": "Gold Balance",
	"mana_balance": "Mana Balance",
	"crystals_balance": "Crystals Balance",
}

# Categories shown on the leaderboard screen (must match field names in stats)
const LEADERBOARD_CATEGORIES: Array[String] = [
	# Collection
	"total_power",
	"highest_team_power",
	"highest_god_power",
	"highest_god_level",
	"gods_collected",
	"unique_gods_collected",
	"legendary_gods",
	"epic_gods",
	"max_level_gods",
	"legendary_gods_obtained",
	"epic_gods_obtained",
	# Combat
	"battles_won",
	"total_battles",
	"perfect_victories",
	"longest_win_streak",
	"total_enemies_killed",
	"dungeons_cleared",
	"tower_best_floor",
	"tower_floors_cleared",
	"arena_elo",
	# Territory & Buildings
	"territories_owned",
	"territory_conquests",
	"buildings_placed",
	"total_building_levels",
	"highest_building_level",
	# Economy & Resources
	"equipment_crafted",
	"total_summons",
	"legendary_summons",
	"epic_summons",
	"gods_sacrificed",
	"gold_balance",
	"mana_balance",
	"crystals_balance",
]

var _firestore: Variant = null
var _user_id: String = ""
var _display_name: String = ""

# Cache
var _cached: Dictionary = {}
var _cache_time: Dictionary = {}
const CACHE_TTL := 60

# Throttle
var _last_upload: float = 0.0
const UPLOAD_COOLDOWN := 10.0

func _ready() -> void:
	call_deferred("_init")

func _init() -> void:
	_connect_firebase()
	_connect_events()
	_listen_for_sign_in()

func _connect_firebase() -> void:
	var registry := SystemRegistry.get_instance()
	if not registry:
		return
	var fb := registry.get_system("FirebaseIntegration")
	if not fb:
		return
	if fb.has_method("get_firestore"):
		_firestore = fb.get_firestore()
	if fb.has_method("get_user_id"):
		_user_id = fb.get_user_id()

	# Get display name from SaveManager (where user sets it after signup)
	var save_manager := registry.get_system("SaveManager")
	if save_manager and save_manager.has_method("get_player_value"):
		_display_name = save_manager.get_player_value("display_name", "")

	# Fallback to email username if no display name in save
	if _display_name.is_empty() and fb.has_method("get_user_email"):
		var email: String = fb.get_user_email()
		if not email.is_empty() and "@" in email:
			_display_name = email.split("@")[0]

	if is_ready():
		print("LeaderboardDataSync: Connected - user=%s, name=%s" % [_user_id, _display_name])
	else:
		print("LeaderboardDataSync: Not ready yet - firestore=%s, user_id=%s" % [_firestore != null, _user_id])

func _listen_for_sign_in() -> void:
	var registry := SystemRegistry.get_instance()
	if not registry:
		return
	var fb := registry.get_system("FirebaseIntegration")
	if fb and fb.has_signal("sign_in_completed"):
		if not fb.is_connected("sign_in_completed", _on_sign_in_completed):
			fb.sign_in_completed.connect(_on_sign_in_completed)

func _on_sign_in_completed(_user_data: Dictionary) -> void:
	print("LeaderboardDataSync: Sign-in detected, refreshing connection...")
	_connect_firebase()
	# Don't upload immediately - wait for game_loaded event which fires AFTER
	# cloud save data is loaded (so display name will be available)

func _connect_events() -> void:
	var registry := SystemRegistry.get_instance()
	if not registry:
		return
	var bus := registry.get_system("EventBus")
	if not bus:
		return

	# Upload on any of these events
	var events := [
		"battle_ended", "tower_run_ended", "territory_captured",
		"god_obtained", "summon_performed", "arena_battle_completed",
		"dungeon_completed", "player_level_up", "game_loaded",
		"equipment_crafted"
	]
	for ev in events:
		if bus.has_signal(ev) and not bus.is_connected(ev, _on_event):
			bus.connect(ev, _on_event)

func _on_event(_a1: Variant = null, _a2: Variant = null, _a3: Variant = null) -> void:
	# Try to reconnect if not ready
	if not is_ready():
		_connect_firebase()
	_throttled_upload()

func _throttled_upload() -> void:
	var now := Time.get_unix_time_from_system()
	if now - _last_upload < UPLOAD_COOLDOWN:
		return
	_last_upload = now
	upload_stats()

func is_ready() -> bool:
	return _firestore != null and not _user_id.is_empty()

func refresh_connection() -> void:
	_connect_firebase()

# ==============================================================================
# UPLOAD STATS
# ==============================================================================

func upload_stats() -> void:
	if not is_ready():
		upload_completed.emit(false)
		return

	# Always get fresh display name from SaveManager (may have loaded since last check)
	var registry := SystemRegistry.get_instance()
	if registry:
		var save_manager := registry.get_system("SaveManager")
		if save_manager and save_manager.has_method("get_player_value"):
			var fresh_name: String = save_manager.get_player_value("display_name", "")
			if not fresh_name.is_empty():
				_display_name = fresh_name

	var stats := _collect_stats()
	stats["user_id"] = _user_id
	stats["display_name"] = _display_name if not _display_name.is_empty() else "Player"
	stats["last_updated"] = Time.get_unix_time_from_system()

	var coll: Variant = _firestore.collection(COLLECTION)
	if not coll:
		upload_completed.emit(false)
		return

	await coll.set_doc(_user_id, stats)
	upload_completed.emit(true)
	print("LeaderboardDataSync: Stats uploaded for %s" % stats["display_name"])

func _collect_stats() -> Dictionary:
	var stats: Dictionary = {}
	var reg := SystemRegistry.get_instance()
	if not reg:
		return stats

	# Tower
	var tw := reg.get_system("TowerManager")
	if tw and "best_floor" in tw:
		stats["tower_best_floor"] = tw.best_floor

	# Arena
	var ar := reg.get_system("ArenaManager")
	if ar and ar.has_method("get_player_elo"):
		stats["arena_elo"] = ar.get_player_elo()

	# Statistics - battle stats
	var sm := reg.get_system("StatisticsManager")
	if sm and "battle_stats" in sm:
		var bs: Dictionary = sm.battle_stats
		stats["battles_won"] = bs.get("battles_won", 0)
		stats["total_battles"] = bs.get("total_battles", 0)
		stats["perfect_victories"] = bs.get("perfect_victories", 0)
		stats["longest_win_streak"] = bs.get("longest_win_streak", 0)
		stats["territory_conquests"] = bs.get("territory_conquests", 0)
		stats["total_enemies_killed"] = bs.get("total_enemies_killed", 0)
		stats["tower_floors_cleared"] = bs.get("tower_floors_cleared", 0)
		stats["gold_earned"] = bs.get("gold_earned", 0)
		stats["mana_earned"] = bs.get("mana_earned", 0)
	if sm and sm.has_method("get_total_dungeon_clears"):
		stats["dungeons_cleared"] = sm.get_total_dungeon_clears()
	# Statistics - resource stats
	if sm and "resource_stats" in sm:
		var rs: Dictionary = sm.resource_stats
		stats["gods_sacrificed"] = rs.get("gods_sacrificed", 0)
		stats["equipment_crafted"] = rs.get("equipment_crafted", 0)
		stats["total_summons"] = rs.get("total_summons_performed", 0)
		stats["legendary_summons"] = rs.get("legendary_summons", 0)
		stats["epic_summons"] = rs.get("epic_summons", 0)
		stats["legendary_gods_obtained"] = rs.get("legendary_gods_obtained", 0)
		stats["epic_gods_obtained"] = rs.get("epic_gods_obtained", 0)

	# Collection - gods collected, total power, highest level god, highest god power, highest team power
	var cm := reg.get_system("CollectionManager")
	if cm and cm.has_method("get_all_gods"):
		var gods: Array = cm.get_all_gods()
		stats["gods_collected"] = gods.size()
		var total_power: int = 0
		var highest_level: int = 0
		var highest_god_power: int = 0
		var god_powers: Array[int] = []
		var unique_templates: Dictionary = {}
		var legendary_count: int = 0
		var epic_count: int = 0
		var max_level_count: int = 0
		const MAX_GOD_LEVEL: int = 100  # Adjust if your cap is different
		for god in gods:
			if god:
				var god_power: int = GodCalculator.get_power_rating(god)
				total_power += god_power
				god_powers.append(god_power)
				if god_power > highest_god_power:
					highest_god_power = god_power
				var god_level: int = god.level if "level" in god else 1
				if god_level > highest_level:
					highest_level = god_level
				if god_level >= MAX_GOD_LEVEL:
					max_level_count += 1
				# Track unique templates
				var template_id: String = god.template_id if "template_id" in god and god.template_id else god.id
				unique_templates[template_id] = true
				# Track tier-based counts (COMMON=0, RARE=1, EPIC=2, LEGENDARY=3)
				var god_tier: int = god.tier if "tier" in god else 0
				if god_tier == God.TierType.LEGENDARY:
					legendary_count += 1
				if god_tier >= God.TierType.EPIC:  # Epic or higher
					epic_count += 1
		stats["total_power"] = total_power
		stats["highest_god_level"] = highest_level
		stats["highest_god_power"] = highest_god_power
		stats["unique_gods_collected"] = unique_templates.size()
		stats["legendary_gods"] = legendary_count
		stats["epic_gods"] = epic_count
		stats["max_level_gods"] = max_level_count
		# Highest team power = sum of top 4 gods
		god_powers.sort()
		god_powers.reverse()
		var team_power: int = 0
		for i in range(mini(4, god_powers.size())):
			team_power += god_powers[i]
		stats["highest_team_power"] = team_power

	# Territories & Buildings
	var hg := reg.get_system("HexGridManager")
	if hg and hg.has_method("get_player_nodes"):
		var player_nodes: Array = hg.get_player_nodes()
		stats["territories_owned"] = player_nodes.size()
		# Count buildings
		var buildings_count: int = 0
		var total_levels: int = 0
		var highest_level: int = 0
		for node in player_nodes:
			if node and "placed_building" in node and not node.placed_building.is_empty():
				buildings_count += 1
				var level: int = node.building_level if "building_level" in node else 1
				total_levels += level
				if level > highest_level:
					highest_level = level
		stats["buildings_placed"] = buildings_count
		stats["total_building_levels"] = total_levels
		stats["highest_building_level"] = highest_level

	# Current resource balances
	var rm := reg.get_system("ResourceManager")
	if rm and rm.has_method("get_resource"):
		stats["gold_balance"] = rm.get_resource("gold")
		stats["mana_balance"] = rm.get_resource("mana")
		stats["crystals_balance"] = rm.get_resource("divine_crystals")

	return stats

# ==============================================================================
# FETCH LEADERBOARD
# ==============================================================================

func get_categories() -> Array:
	return LEADERBOARD_CATEGORIES.duplicate()

func get_category_display(category: String) -> String:
	return METRICS.get(category, category.capitalize())

func fetch_leaderboard(category: String, force: bool = false) -> void:
	if not force and _is_cached(category):
		leaderboard_fetched.emit(category, _cached.get(category, []))
		return

	# Try to reconnect if not ready
	if not is_ready():
		_connect_firebase()

	if not is_ready():
		print("LeaderboardDataSync: Not ready - firestore=%s, user=%s" % [_firestore != null, _user_id])
		leaderboard_fetched.emit(category, [])
		return

	_do_fetch(category)

func _is_cached(category: String) -> bool:
	if not _cached.has(category):
		return false
	var age: int = int(Time.get_unix_time_from_system()) - int(_cache_time.get(category, 0))
	return age < CACHE_TTL

func _do_fetch(category: String) -> void:
	print("LeaderboardDataSync: _do_fetch(%s) - using list()" % category)

	# Use list() to get all documents in the collection
	var result: Variant = await _firestore.list(COLLECTION)

	if result == null:
		print("LeaderboardDataSync: list() returned null for %s" % category)
		leaderboard_fetched.emit(category, [])
		return

	print("LeaderboardDataSync: list() returned %d documents" % (result.size() if result is Array else 1))
	var entries: Array = _parse(result, category)
	_cached[category] = entries
	_cache_time[category] = int(Time.get_unix_time_from_system())
	print("LeaderboardDataSync: Parsed %d entries for %s" % [entries.size(), category])
	leaderboard_fetched.emit(category, entries)

func _parse(result: Variant, category: String) -> Array:
	var entries: Array = []
	var docs: Array = result if result is Array else [result]

	for doc: Variant in docs:
		if doc == null:
			continue
		var val: Variant = _field(doc, category)
		if val == null:
			continue
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_FLOAT:
			continue

		entries.append({
			"user_id": _field(doc, "user_id"),
			"display_name": _field(doc, "display_name"),
			"value": int(val),
			"player_level": _field(doc, "player_level"),
		})

	entries.sort_custom(func(a, b): return a.get("value", 0) > b.get("value", 0))

	for i in range(mini(100, entries.size())):
		entries[i]["rank"] = i + 1

	return entries.slice(0, 100)

func _field(doc: Variant, key: String) -> Variant:
	if doc == null:
		return null
	if doc.has_method("get_value"):
		return doc.get_value(key)
	if doc is Dictionary:
		return doc.get(key)
	return null

func get_user_id() -> String:
	return _user_id
