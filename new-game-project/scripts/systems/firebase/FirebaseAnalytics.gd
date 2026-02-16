# scripts/systems/firebase/FirebaseAnalytics.gd
# Analytics event logging with batching and offline support
class_name FirebaseAnalytics extends Node

signal event_logged(event_name: String)
signal batch_sent(count: int)
signal batch_failed(error: String)

const BATCH_SIZE = 25
const BATCH_INTERVAL = 30.0  # seconds

var _event_queue: AnalyticsEventQueue
var _batch_timer: float = 0.0
var _session_id: String = ""
var _session_start_time: int = 0
var _user_id: String = "anonymous"
var _is_enabled: bool = true

# Reference to Firebase (set by FirebaseIntegration)
var _firestore = null

func _ready():
	_event_queue = AnalyticsEventQueue.new()
	_event_queue.load_from_disk()
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

func set_user_id(user_id: String):
	"""Update user ID after sign-in"""
	_user_id = user_id if not user_id.is_empty() else "anonymous"
	log_event("user_identified", {"user_id": _user_id})

func set_enabled(enabled: bool):
	"""Enable/disable analytics"""
	_is_enabled = enabled

func _start_session():
	"""Start a new analytics session"""
	_session_id = _generate_uuid()
	_session_start_time = Time.get_unix_time_from_system()
	log_event("session_start", {
		"platform": OS.get_name(),
		"locale": OS.get_locale()
	})

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

func log_event(event_name: String, params: Dictionary = {}):
	"""Log an analytics event (queued for batch sending)"""
	if not _is_enabled:
		return

	var event = {
		"name": event_name,
		"params": _enrich_params(params),
		"timestamp": Time.get_unix_time_from_system()
	}

	_event_queue.enqueue(event)
	event_logged.emit(event_name)

	# Send immediately if queue is large
	if _event_queue.size() >= BATCH_SIZE:
		_try_send_batch.call_deferred()

func _enrich_params(params: Dictionary) -> Dictionary:
	"""Add standard parameters to all events"""
	var enriched = params.duplicate()
	enriched["session_id"] = _session_id
	enriched["user_id"] = _user_id
	enriched["platform"] = OS.get_name()
	enriched["client_timestamp"] = Time.get_unix_time_from_system()
	return enriched

# ==============================================================================
# BATCH SENDING
# ==============================================================================

func _try_send_batch():
	"""Attempt to send queued events to Firestore"""
	if _event_queue.is_empty():
		return

	if not _firestore:
		print("FirebaseAnalytics: Firestore not configured, events queued locally")
		return

	var events_to_send = _event_queue.dequeue_batch(BATCH_SIZE)
	_send_to_firestore.call_deferred(events_to_send)

func _send_to_firestore(events: Array):
	"""Send events batch to Firestore analytics_events collection"""
	if events.is_empty():
		return

	# Create batch document
	var batch_doc = {
		"user_id": _user_id,
		"session_id": _session_id,
		"batch_timestamp": Time.get_unix_time_from_system(),
		"event_count": events.size(),
		"events": events
	}

	# Use GodotFirebase addon's Firestore - await the coroutine directly
	var collection = _firestore.collection("analytics_events")
	var result = await collection.add("", batch_doc)

	# FirestoreDocument is a Node - check if we got a valid result
	if result != null and result is FirestoreDocument:
		batch_sent.emit(events.size())
		print("FirebaseAnalytics: Sent %d events" % events.size())
	else:
		# Re-queue failed events
		for event in events:
			_event_queue.enqueue(event)
		batch_failed.emit("Failed to send analytics batch")
		print("FirebaseAnalytics: Batch failed, re-queued %d events" % events.size())

func flush_queue():
	"""Force send all queued events (call before sign-out or app exit)"""
	while not _event_queue.is_empty() and _firestore:
		_try_send_batch()
		await get_tree().create_timer(0.5).timeout

	# Save any remaining events that couldn't be sent
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

func log_specialization(spec_data: Dictionary):
	"""Log god specialization unlock"""
	log_event("specialization_unlocked", spec_data)

func log_equipment_change(change_data: Dictionary):
	"""Log equipment equip/unequip"""
	log_event("equipment_changed", change_data)

func _count_tier(gods: Array, tier_name: String) -> int:
	"""Helper to count gods of a specific tier in summon results"""
	return gods.filter(func(g): return g.get("tier", "").to_lower() == tier_name).size()
