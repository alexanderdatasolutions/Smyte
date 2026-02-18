# scripts/systems/firebase/FirebaseAnalytics.gd
# Analytics event logging with batching and offline support
# BigQuery-friendly: Events stored flat for easy Tableau/BigQuery export
class_name FirebaseAnalytics extends Node

signal event_logged(event_name: String)
signal batch_sent(count: int)
signal batch_failed(error: String)

const BATCH_SIZE = 25
const BATCH_INTERVAL = 10.0  # seconds

# BigQuery-friendly flat events collection (one doc per event)
const FLAT_EVENTS_COLLECTION = "analytics_flat"
# Legacy batched collection (kept for backwards compatibility)
const BATCH_EVENTS_COLLECTION = "analytics_events"

var _event_queue: AnalyticsEventQueue
var _batch_timer: float = 0.0
var _session_id: String = ""
var _session_start_time: int = 0
var _user_id: String = "anonymous"
var _display_name: String = "Anonymous"
var _steam_id: String = ""  # Separate Steam ID for analytics
var _is_enabled: bool = true
var _use_flat_events: bool = true  # Enable BigQuery-friendly flat events
var _event_bus_connected: bool = false  # Guard against duplicate connections

# Reference to Firebase (set by FirebaseIntegration)
var _firestore = null

func _ready():
	_event_queue = AnalyticsEventQueue.new()
	_event_queue.load_from_disk()
	if not _event_queue.is_empty():
		print("FirebaseAnalytics: Loaded %d events from previous session" % _event_queue.size())
	_start_session()

func _process(delta):
	if not _is_enabled:
		return

	_batch_timer += delta
	if _batch_timer >= BATCH_INTERVAL:
		_batch_timer = 0.0
		_try_send_batch()

func _notification(what):
	# Save queue when app goes to background or closes
	# NOTIFICATION_APPLICATION_PAUSED is used on mobile for backgrounding
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_event_queue.save_to_disk()

func set_firestore(firestore):
	"""Set Firestore reference from FirebaseIntegration"""
	_firestore = firestore
	print("FirebaseAnalytics: Firestore reference set: %s" % (_firestore != null))

func set_user_id(user_id: String):
	"""Update user ID after sign-in"""
	_user_id = user_id if not user_id.is_empty() else "anonymous"
	# Update any events that were queued before sign-in
	if _event_queue and _user_id != "anonymous":
		_event_queue.update_user_id(_user_id)
	log_event("user_identified", {"user_id": _user_id})

func set_display_name(display_name: String):
	"""Update display name after sign-in - also updates any queued events"""
	var old_name: String = _display_name
	_display_name = display_name if not display_name.is_empty() else "Anonymous"
	print("FirebaseAnalytics: set_display_name('%s' -> '%s'), queue_size=%d" % [old_name, _display_name, _event_queue.size() if _event_queue else 0])
	# ALWAYS update queued events with the new name (catches any Anonymous events)
	if _event_queue and not _display_name.is_empty() and _display_name != "Anonymous":
		_event_queue.update_display_name(_display_name)
		print("FirebaseAnalytics: Queue updated with display_name '%s'" % _display_name)

func set_steam_id(steam_id: String):
	"""Set Steam ID for analytics tracking (separate from user_id)"""
	_steam_id = steam_id
	# Update any events that were queued before we knew the Steam ID
	if _event_queue and not _steam_id.is_empty():
		_event_queue.update_steam_id(_steam_id)

func set_enabled(enabled: bool):
	"""Enable/disable analytics"""
	_is_enabled = enabled

func set_flat_events_mode(use_flat: bool):
	"""Enable flat event mode for BigQuery/Tableau compatibility (default: true)"""
	_use_flat_events = use_flat

func _start_session():
	"""Start a new analytics session"""
	_session_id = _generate_uuid()
	_session_start_time = Time.get_unix_time_from_system()
	log_event("session_start", {
		"platform": OS.get_name(),
		"locale": OS.get_locale()
	})

func connect_to_event_bus(event_bus: Node) -> void:
	"""Connect to EventBus signals for automatic tracking. Call this after systems init."""
	if not event_bus:
		return

	# Prevent duplicate connections
	if _event_bus_connected:
		print("FirebaseAnalytics: EventBus already connected, skipping duplicate")
		return
	_event_bus_connected = true

	# Battle events
	if event_bus.has_signal("battle_started"):
		event_bus.battle_started.connect(_on_battle_started)
	if event_bus.has_signal("battle_ended"):
		event_bus.battle_ended.connect(_on_battle_ended_analytics)
	if event_bus.has_signal("battle_team_entered"):
		event_bus.battle_team_entered.connect(_on_battle_team_entered)

	# Tower events
	if event_bus.has_signal("tower_floor_cleared"):
		event_bus.tower_floor_cleared.connect(_on_tower_floor_cleared)
	if event_bus.has_signal("tower_run_ended"):
		event_bus.tower_run_ended.connect(_on_tower_run_ended)

	# God events
	if event_bus.has_signal("god_obtained"):
		event_bus.god_obtained.connect(_on_god_obtained)
	if event_bus.has_signal("god_level_up"):
		event_bus.god_level_up.connect(_on_god_level_up)
	if event_bus.has_signal("god_sacrifice_completed"):
		event_bus.god_sacrifice_completed.connect(_on_god_sacrifice)
	if event_bus.has_signal("god_awakening_completed"):
		event_bus.god_awakening_completed.connect(_on_god_awakening)

	# Summon events
	if event_bus.has_signal("summon_completed_detailed"):
		event_bus.summon_completed_detailed.connect(_on_summon_completed)

	# Territory events
	if event_bus.has_signal("territory_captured"):
		event_bus.territory_captured.connect(_on_territory_captured)
	if event_bus.has_signal("garrison_updated"):
		event_bus.garrison_updated.connect(_on_garrison_updated)

	# Dungeon events
	if event_bus.has_signal("dungeon_completed"):
		event_bus.dungeon_completed.connect(_on_dungeon_completed)
	if event_bus.has_signal("dungeon_failed"):
		event_bus.dungeon_failed.connect(_on_dungeon_failed)

	# Arena events
	if event_bus.has_signal("arena_battle_completed"):
		event_bus.arena_battle_completed.connect(_on_arena_completed)
	if event_bus.has_signal("league_changed"):
		event_bus.league_changed.connect(_on_league_changed)

	# Equipment events
	if event_bus.has_signal("equipment_crafted"):
		event_bus.equipment_crafted.connect(_on_equipment_crafted)
	if event_bus.has_signal("equipment_equipped"):
		event_bus.equipment_equipped.connect(_on_equipment_equipped)

	# Screen changes
	if event_bus.has_signal("screen_changed"):
		event_bus.screen_changed.connect(_on_screen_changed)

	# Achievement
	if event_bus.has_signal("achievement_unlocked"):
		event_bus.achievement_unlocked.connect(_on_achievement_unlocked)

	# Errors
	if event_bus.has_signal("error_occurred"):
		event_bus.error_occurred.connect(_on_error_occurred)

	print("FirebaseAnalytics: Connected to EventBus signals")

# ==============================================================================
# EVENTBUS SIGNAL HANDLERS (automatic tracking)
# ==============================================================================

func _on_battle_started(config) -> void:
	var battle_type: String = ""
	if config and config is BattleConfig:
		battle_type = BattleConfig.BattleType.keys()[config.battle_type].to_lower()
	track("battle_started", battle_type)

func _on_battle_ended_analytics(result) -> void:
	if not result:
		return
	var battle_type: String = result.battle_type if "battle_type" in result else ""
	var victory: bool = result.victory if "victory" in result else false
	var duration: int = int(result.duration) if "duration" in result else 0
	track("battle_ended", battle_type, "", duration, "", victory)

func _on_battle_team_entered(data: Dictionary) -> void:
	track("battle_team_entered", data.get("battle_type", ""),
		str(data.get("god_ids", [])), data.get("team_power", 0))

func _on_tower_floor_cleared(floor_num: int) -> void:
	track("tower_floor_cleared", "tower", str(floor_num), floor_num)

func _on_tower_run_ended(final_floor: int, is_new_record: bool) -> void:
	track("tower_run_ended", "tower", str(final_floor), final_floor, "", is_new_record)

func _on_god_obtained(god) -> void:
	if not god:
		return
	var tier_str: String = God.tier_to_string(god.tier) if god else ""
	var element_str: String = God.element_to_string(god.element) if god else ""
	track("god_obtained", "collection", god.template_id, god.level, tier_str,
		true, {"element": element_str})

func _on_god_level_up(god_id, new_level, old_level) -> void:
	track("god_leveled", "collection", str(god_id), new_level,
		str(new_level - old_level) + " levels")

func _on_god_sacrifice(data: Dictionary) -> void:
	track("god_sacrificed", "sacrifice", str(data.get("target_god_id", "")),
		int(data.get("total_xp", 0)), str(data.get("target_tier", "")))

func _on_god_awakening(data: Dictionary) -> void:
	track("god_awakened", "awakening", str(data.get("god_id", "")),
		0, str(data.get("new_tier", "")))

func _on_summon_completed(data: Dictionary) -> void:
	var gods: Array = data.get("gods_obtained", [])
	var legendary_count: int = gods.filter(func(g): return g.get("tier", "").to_lower() == "legendary").size()
	track("summon_completed", "summon", data.get("banner_id", ""),
		gods.size(), data.get("summon_type", ""), legendary_count > 0,
		{"legendary_count": legendary_count, "pity": data.get("pity_counters", {})})

func _on_territory_captured(territory_id: String) -> void:
	track("territory_captured", "territory", territory_id)

func _on_garrison_updated(data: Dictionary) -> void:
	track("garrison_assigned", "territory", data.get("node_id", ""),
		data.get("total_power", 0), str(data.get("node_tier", 0)))

func _on_dungeon_completed(dungeon_id: String, _rewards: Array) -> void:
	track("dungeon_completed", "dungeon", dungeon_id, 0, "", true)

func _on_dungeon_failed(dungeon_id: String) -> void:
	track("dungeon_failed", "dungeon", dungeon_id, 0, "", false)

func _on_arena_completed(data: Dictionary) -> void:
	track("arena_battle", "arena", str(data.get("opponent_elo", 0)),
		data.get("elo_change", 0), data.get("league", ""), data.get("victory", false))

func _on_league_changed(data: Dictionary) -> void:
	track("league_changed", "arena", data.get("new_league", ""),
		data.get("elo", 0), data.get("direction", ""))

func _on_equipment_crafted(equipment, recipe_id: String) -> void:
	var slot: String = equipment.slot_type if equipment and "slot_type" in equipment else ""
	var rarity: String = equipment.rarity if equipment and "rarity" in equipment else ""
	track("equipment_crafted", "crafting", recipe_id, 0, rarity, true, {"slot": slot})

func _on_equipment_equipped(god, equipment, slot) -> void:
	var god_id: String = god.id if god else ""
	var eq_id: String = equipment.id if equipment else ""
	track("equipment_equipped", "equipment", god_id + ":" + eq_id, slot)

func _on_screen_changed(old_screen: String, new_screen: String) -> void:
	track("screen_view", new_screen, old_screen)

func _on_achievement_unlocked(achievement_id: String) -> void:
	track("achievement_unlocked", "achievements", achievement_id)

func _on_error_occurred(error_msg: String, context: String) -> void:
	track("error", context, error_msg, 0, "", false)

func _generate_uuid() -> String:
	"""Generate a simple UUID v4"""
	var chars = "0123456789abcdef"
	var uuid = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		uuid += chars[randi() % 16]
	return uuid

# ==============================================================================
# EVENT LOGGING
# ==============================================================================

func track(event_name: String, screen: String = "", target: String = "", value: int = 0,
		str1: String = "", success: bool = true, extra: Dictionary = {}):
	"""Clean event tracking with standard columns.

	Args:
		event_name: What happened (battle_started, god_summoned, floor_cleared)
		screen: Where it happened (tower, dungeon, worldview, collection)
		target: What was affected (god_id, floor_5, fire_dungeon)
		value: Primary number (damage, level, floor number)
		str1: Extra context (tier, difficulty, element)
		success: Did it succeed? (victory, completed)
		extra: Any additional data (goes to metadata JSON)
	"""
	var params: Dictionary = {"screen": screen, "target": target, "value": value,
		"str1": str1, "success": success}
	params.merge(extra)
	log_event(event_name, params)

func log_event(event_name: String, params: Dictionary = {}):
	"""Log an analytics event (queued for batch sending)"""
	if not _is_enabled:
		return

	var enriched_params = _enrich_params(params)
	var event = {
		"name": event_name,
		"params": enriched_params,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Debug: log display_name for key events
	if event_name in ["god_obtained", "summon_completed", "battle_ended", "session_start"]:
		print("FirebaseAnalytics: log_event('%s') display_name='%s' (instance _display_name='%s')" % [
			event_name, enriched_params.get("display_name", "?"), _display_name])

	_event_queue.enqueue(event)
	event_logged.emit(event_name)

	# Send immediately if queue is large
	if _event_queue.size() >= BATCH_SIZE:
		_try_send_batch.call_deferred()

func _enrich_params(params: Dictionary) -> Dictionary:
	"""Add standard parameters to all events - captured at log time"""
	var enriched = params.duplicate()
	enriched["session_id"] = _session_id
	enriched["user_id"] = _user_id
	enriched["display_name"] = _display_name
	enriched["platform"] = OS.get_name()
	enriched["client_timestamp"] = Time.get_unix_time_from_system()
	# Capture local time at event logging (ISO 8601 format for BigQuery compatibility)
	var local_dt: Dictionary = Time.get_datetime_dict_from_system()
	enriched["local_time"] = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		local_dt.year, local_dt.month, local_dt.day,
		local_dt.hour, local_dt.minute, local_dt.second
	]
	if not _steam_id.is_empty():
		enriched["steam_id"] = _steam_id
	return enriched

# ==============================================================================
# BATCH SENDING
# ==============================================================================

func _try_send_batch(force_sync: bool = false) -> void:
	"""Attempt to send queued events to Firestore"""
	if _event_queue.is_empty():
		return

	if not _firestore:
		print("FirebaseAnalytics: Firestore not configured, events queued locally (queue size: %d)" % _event_queue.size())
		return

	print("FirebaseAnalytics: Sending batch of events (queue size: %d, sync: %s)" % [_event_queue.size(), force_sync])
	var events_to_send = _event_queue.dequeue_batch(BATCH_SIZE)
	if force_sync:
		# During shutdown, send synchronously (no call_deferred)
		await _send_to_firestore(events_to_send)
	else:
		_send_to_firestore.call_deferred(events_to_send)

func _send_to_firestore(events: Array) -> void:
	"""Send events to Firestore - flat format for BigQuery compatibility"""
	if events.is_empty():
		return

	if not _firestore:
		for event in events:
			_event_queue.enqueue(event)
		batch_failed.emit("Firestore collection unavailable")
		return

	# Send flat events (BigQuery-friendly, one doc per event)
	if _use_flat_events:
		await _send_flat_events(events)
	else:
		await _send_batched_events(events)

func _send_flat_events(events: Array) -> void:
	"""Send each event as a flat document for BigQuery/Tableau compatibility"""
	var collection = _firestore.collection(FLAT_EVENTS_COLLECTION) if _firestore else null
	if not collection:
		for event in events:
			_event_queue.enqueue(event)
		batch_failed.emit("Firestore flat collection unavailable")
		return

	var success_count: int = 0
	for event in events:
		var flat_doc: Dictionary = _flatten_event(event)
		var result = await collection.add("", flat_doc)
		if result != null and result is FirestoreDocument:
			success_count += 1
		else:
			_event_queue.enqueue(event)

	if success_count > 0:
		batch_sent.emit(success_count)
	if success_count < events.size():
		batch_failed.emit("Failed to send %d/%d events" % [events.size() - success_count, events.size()])

func _flatten_event(event: Dictionary) -> Dictionary:
	"""Convert event to clean flat structure for BigQuery/Tableau.

	All params become top-level fields. No prefixes, no nesting.
	"""
	var params: Dictionary = event.get("params", {})
	var ts: int = event.get("timestamp", Time.get_unix_time_from_system())

	# Start with core fields - use captured values from params (logged at event time)
	var flat: Dictionary = {
		"event_name": event.get("name", "unknown"),
		"timestamp": ts,
		"date": _timestamp_to_date(ts),
		"local_time": params.get("local_time", ""),
		"user_id": params.get("user_id", _user_id),
		"steam_id": params.get("steam_id", ""),
		"player": params.get("display_name", _display_name),
		"session_id": params.get("session_id", _session_id),
		"platform": params.get("platform", OS.get_name()),
	}

	# Flatten ALL params directly to top level (skip already-added core fields)
	var skip_keys: Array = ["user_id", "steam_id", "session_id", "platform", "client_timestamp", "display_name", "local_time"]
	for key in params:
		if key in skip_keys:
			continue
		var value = params[key]
		# Convert dictionaries/arrays to JSON strings for BigQuery compatibility
		if value is Dictionary or value is Array:
			flat[key] = JSON.stringify(value)
		else:
			flat[key] = value

	return flat

func _timestamp_to_date(timestamp: int) -> String:
	"""Convert Unix timestamp to YYYY-MM-DD for BigQuery date partitioning"""
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]

func _send_batched_events(events: Array) -> void:
	"""Legacy batched format (kept for backwards compatibility)"""
	var batch_doc: Dictionary = {
		"user_id": _user_id,
		"session_id": _session_id,
		"batch_timestamp": Time.get_unix_time_from_system(),
		"event_count": events.size(),
		"events": events
	}

	var collection = _firestore.collection(BATCH_EVENTS_COLLECTION) if _firestore else null
	if not collection:
		for event in events:
			_event_queue.enqueue(event)
		batch_failed.emit("Firestore collection unavailable")
		return

	var result = await collection.add("", batch_doc)

	if result != null and result is FirestoreDocument:
		batch_sent.emit(events.size())
	else:
		for event in events:
			_event_queue.enqueue(event)
		batch_failed.emit("Failed to send analytics batch")

func flush_queue() -> void:
	"""Force send all queued events (call before sign-out or app exit)"""
	print("FirebaseAnalytics: flush_queue() called, queue size: %d, firestore: %s" % [_event_queue.size(), _firestore != null])
	var max_retries: int = 10
	var attempts: int = 0
	while not _event_queue.is_empty() and _firestore and attempts < max_retries:
		await _try_send_batch(true)  # Use sync mode during flush
		if _event_queue.is_empty():
			break
		await get_tree().create_timer(0.3).timeout
		attempts += 1

	if not _event_queue.is_empty():
		print("FirebaseAnalytics: %d events remaining after flush, saving to disk" % _event_queue.size())
		_event_queue.save_to_disk()

func get_pending_event_count() -> int:
	"""Get number of events waiting to be sent"""
	return _event_queue.size()

# ==============================================================================
# CONVENIENCE METHODS FOR COMMON EVENTS
# ==============================================================================

func log_battle_completed(victory: bool, battle_type: String, duration: float, team_power: int, extra_params: Dictionary = {}):
	var params = {
		"victory": victory,
		"battle_type": battle_type,
		"duration": duration,
		"team_power": team_power
	}
	params.merge(extra_params)
	log_event("battle_completed", params)

func log_god_obtained(god_id: String, tier: String, element: String, source: String):
	log_event("god_obtained", {
		"god_id": god_id,
		"tier": tier,
		"element": element,
		"source": source
	})

func log_summon_performed(banner_id: String, results_count: int, legendary_count: int):
	log_event("summon_performed", {
		"banner_id": banner_id,
		"results_count": results_count,
		"legendary_count": legendary_count
	})

func log_dungeon_completed(dungeon_id: String, difficulty: String, rewards: Dictionary):
	log_event("dungeon_completed", {
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"rewards": rewards
	})

func log_resource_transaction(resource_id: String, delta: int, source: String):
	log_event("resource_transaction", {
		"resource_id": resource_id,
		"delta": delta,
		"source": source
	})

func log_god_leveled(god_id: String, old_level: int, new_level: int):
	log_event("god_leveled", {
		"god_id": god_id,
		"old_level": old_level,
		"new_level": new_level
	})

func log_territory_captured(territory_id: String, team_power: int):
	log_event("territory_captured", {
		"territory_id": territory_id,
		"team_power": team_power
	})

func log_screen_view(screen_name: String):
	log_event("screen_view", {
		"screen_name": screen_name
	})

func log_error(error_type: String, error_message: String, context: Dictionary = {}):
	var params = {
		"error_type": error_type,
		"error_message": error_message
	}
	params.merge(context)
	log_event("error", params)

# ==============================================================================
# EXTENDED ANALYTICS METHODS
# ==============================================================================

func log_summon_detailed(summon_data: Dictionary):
	"""Log detailed summon event with pity and cost info"""
	log_event("summon_detailed", {
		"banner_id": summon_data.get("banner_id", ""),
		"summon_type": summon_data.get("summon_type", ""),
		"cost_type": summon_data.get("cost_type", ""),
		"powder_element": summon_data.get("powder_element", ""),
		"pity_legendary": summon_data.get("pity_legendary", 0),
		"pity_epic": summon_data.get("pity_epic", 0),
		"gods_count": summon_data.get("gods_obtained", []).size(),
		"legendary_count": _count_tier(summon_data.get("gods_obtained", []), "legendary"),
		"epic_count": _count_tier(summon_data.get("gods_obtained", []), "epic")
	})

func log_sacrifice(sacrifice_data: Dictionary):
	"""Log god sacrifice with materials and XP gain"""
	log_event("sacrifice_performed", sacrifice_data)

func log_awakening(awakening_data: Dictionary):
	"""Log god awakening event"""
	log_event("awakening_performed", awakening_data)

func log_battle_team(team_data: Dictionary):
	"""Log which gods entered battle"""
	log_event("battle_team", team_data)

func log_garrison(garrison_data: Dictionary):
	"""Log garrison assignment to territory node"""
	log_event("garrison_assigned", garrison_data)

func log_workers(worker_data: Dictionary):
	"""Log worker assignment to territory node"""
	log_event("workers_assigned", worker_data)

func log_achievement(achievement_id: String, rewards: Dictionary):
	"""Log achievement unlock with rewards"""
	log_event("achievement_completed", {"achievement_id": achievement_id, "rewards": rewards})

func log_arena_battle(arena_data: Dictionary):
	"""Log arena/PvP battle result"""
	log_event("arena_battle", arena_data)

func log_league_change(league_data: Dictionary):
	"""Log league promotion/demotion"""
	log_event("league_changed", league_data)

func log_equipment_change(change_data: Dictionary):
	"""Log equipment equip/unequip"""
	log_event("equipment_changed", change_data)

func _count_tier(gods: Array, tier_name: String) -> int:
	"""Helper to count gods of a specific tier in summon results"""
	return gods.filter(func(g): return g.get("tier", "").to_lower() == tier_name).size()

# ==============================================================================
# GAME KPI ANALYTICS (for Tableau dashboards)
# ==============================================================================

func log_daily_login(consecutive_days: int, total_logins: int, rewards_claimed: Dictionary):
	"""Track daily login for retention analysis"""
	log_event("daily_login", {
		"consecutive_days": consecutive_days,
		"total_logins": total_logins,
		"rewards_claimed": rewards_claimed
	})

func log_player_progression(player_level: int, total_gods: int, total_power: int, total_battles: int, playtime_hours: float):
	"""Periodic snapshot of player progression state"""
	log_event("player_progression", {
		"player_level": player_level,
		"total_gods": total_gods,
		"total_power": total_power,
		"total_battles": total_battles,
		"playtime_hours": playtime_hours
	})

func log_currency_balance(gold: int, gems: int, arena_tokens: int, territory_tokens: int):
	"""Track economy health via currency snapshots"""
	log_event("currency_balance", {
		"gold": gold,
		"gems": gems,
		"arena_tokens": arena_tokens,
		"territory_tokens": territory_tokens
	})

func log_feature_engagement(feature_name: String, time_spent_seconds: float, actions_taken: int):
	"""Track how much time/engagement each feature gets"""
	log_event("feature_engagement", {
		"feature_name": feature_name,
		"time_spent_seconds": time_spent_seconds,
		"actions_taken": actions_taken
	})

func log_funnel_step(funnel_name: String, step_name: String, step_index: int):
	"""Track conversion funnels (onboarding, first summon, etc.)"""
	log_event("funnel_step", {
		"funnel_name": funnel_name,
		"step_name": step_name,
		"step_index": step_index
	})

func log_battle_stats(battle_type: String, difficulty: String, victory: bool, turns_taken: int,
		damage_dealt: int, damage_received: int, gods_died: int, enemy_count: int, team_power: int = 0):
	"""Detailed battle statistics for balance analysis"""
	log_event("battle_stats", {
		"battle_type": battle_type,
		"difficulty": difficulty,
		"victory": victory,
		"turns_taken": turns_taken,
		"damage_dealt": damage_dealt,
		"damage_received": damage_received,
		"gods_died": gods_died,
		"enemy_count": enemy_count,
		"team_power": team_power
	})

func log_god_usage(god_id: String, god_tier: String, god_element: String, battle_type: String,
		damage_dealt: int, damage_received: int, kills: int, died: bool):
	"""Track individual god performance for balance tuning"""
	log_event("god_usage", {
		"god_id": god_id,
		"god_tier": god_tier,
		"god_element": god_element,
		"battle_type": battle_type,
		"damage_dealt": damage_dealt,
		"damage_received": damage_received,
		"kills": kills,
		"died": died
	})

func log_hex_activity(hex_id: String, hex_type: String, action: String, resources_produced: Dictionary):
	"""Track territory/hex node activity"""
	log_event("hex_activity", {
		"hex_id": hex_id,
		"hex_type": hex_type,
		"action": action,
		"resources_produced": resources_produced
	})

func log_equipment_crafted(equipment_type: String, rarity: String, materials_used: Dictionary, slot: String):
	"""Track crafting activity"""
	log_event("equipment_crafted", {
		"equipment_type": equipment_type,
		"rarity": rarity,
		"materials_used": materials_used,
		"slot": slot
	})

func log_tower_progress(floor_reached: int, highest_floor: int, team_power: int, victory: bool):
	"""Track tower progression"""
	log_event("tower_progress", {
		"floor_reached": floor_reached,
		"highest_floor": highest_floor,
		"team_power": team_power,
		"victory": victory
	})

func log_session_end(session_duration_seconds: float, battles_fought: int, resources_earned: Dictionary):
	"""Log session summary on app close/background"""
	log_event("session_end", {
		"session_duration_seconds": session_duration_seconds,
		"battles_fought": battles_fought,
		"resources_earned": resources_earned
	})

# ==============================================================================
# TUTORIAL ANALYTICS
# ==============================================================================

func log_tutorial_started(tutorial_id: String, display_name: String, total_steps: int):
	"""Log when a tutorial begins"""
	log_event("tutorial_started", {
		"tutorial_id": tutorial_id,
		"tutorial_name": display_name,
		"total_steps": total_steps
	})

func log_tutorial_step_completed(tutorial_id: String, step_index: int, step_title: String, total_steps: int):
	"""Log when a tutorial step is completed"""
	log_event("tutorial_step_completed", {
		"tutorial_id": tutorial_id,
		"step_index": step_index,
		"step_title": step_title,
		"total_steps": total_steps,
		"progress_percent": int((step_index + 1) * 100.0 / total_steps) if total_steps > 0 else 100
	})

func log_tutorial_completed(tutorial_id: String, display_name: String, steps_completed: int):
	"""Log when a tutorial is fully completed"""
	log_event("tutorial_completed", {
		"tutorial_id": tutorial_id,
		"tutorial_name": display_name,
		"steps_completed": steps_completed
	})

func log_tutorial_skipped(tutorial_id: String, display_name: String, step_index: int, total_steps: int):
	"""Log when a tutorial is skipped before completion"""
	log_event("tutorial_skipped", {
		"tutorial_id": tutorial_id,
		"tutorial_name": display_name,
		"skipped_at_step": step_index,
		"total_steps": total_steps,
		"progress_percent": int(step_index * 100.0 / total_steps) if total_steps > 0 else 0
	})
