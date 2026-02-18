# scripts/systems/firebase/AnalyticsEventQueue.gd
# Offline-capable event queue with disk persistence
class_name AnalyticsEventQueue extends RefCounted

const QUEUE_FILE_PATH = "user://analytics_queue.json"
const MAX_QUEUE_SIZE = 500
const MAX_EVENT_AGE_DAYS = 7

var _queue: Array = []

func enqueue(event: Dictionary):
	"""Add event to queue with size limit"""
	if _queue.size() >= MAX_QUEUE_SIZE:
		_queue.pop_front()  # Remove oldest if at capacity
	_queue.append(event)

func dequeue_batch(count: int) -> Array:
	"""Remove and return up to count events from front of queue"""
	var batch = []
	for i in range(mini(count, _queue.size())):
		batch.append(_queue.pop_front())
	return batch

func peek_batch(count: int) -> Array:
	"""Return up to count events without removing them"""
	return _queue.slice(0, mini(count, _queue.size()))

func size() -> int:
	return _queue.size()

func is_empty() -> bool:
	return _queue.is_empty()

func clear():
	_queue.clear()

func save_to_disk():
	"""Persist queue for offline resilience - call on app background/exit"""
	_prune_old_events()

	if _queue.is_empty():
		# Remove file if queue is empty
		if FileAccess.file_exists(QUEUE_FILE_PATH):
			DirAccess.remove_absolute(QUEUE_FILE_PATH)
		return

	var file = FileAccess.open(QUEUE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_queue))
		file.close()
		print("AnalyticsEventQueue: Saved %d events to disk" % _queue.size())

func load_from_disk():
	"""Restore queue from previous session"""
	if not FileAccess.file_exists(QUEUE_FILE_PATH):
		return

	var file = FileAccess.open(QUEUE_FILE_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			var data = json.get_data()
			if data is Array:
				_queue = data
				_prune_old_events()
				print("AnalyticsEventQueue: Loaded %d events from disk" % _queue.size())

		# Clear the file after loading
		DirAccess.remove_absolute(QUEUE_FILE_PATH)

func _prune_old_events():
	"""Remove events older than MAX_EVENT_AGE_DAYS"""
	var cutoff = Time.get_unix_time_from_system() - (MAX_EVENT_AGE_DAYS * 86400)
	_queue = _queue.filter(func(e): return e.get("timestamp", 0) > cutoff)

func get_all_events() -> Array:
	"""Get copy of all events (for debugging)"""
	return _queue.duplicate()

func update_display_name(new_name: String) -> void:
	"""Update display_name in all queued events (called when user identity is confirmed)"""
	var updated_count: int = 0
	for event in _queue:
		if not event.has("params"):
			continue
		var params: Dictionary = event["params"]
		if params.get("display_name", "") == "Anonymous":
			params["display_name"] = new_name
			updated_count += 1
	if updated_count > 0:
		print("AnalyticsEventQueue: Updated display_name to '%s' in %d events" % [new_name, updated_count])

func update_user_id(new_user_id: String) -> void:
	"""Update user_id in all queued events (called when user signs in)"""
	var updated_count: int = 0
	for event in _queue:
		if not event.has("params"):
			continue
		var params: Dictionary = event["params"]
		if params.get("user_id", "") == "anonymous":
			params["user_id"] = new_user_id
			updated_count += 1
	if updated_count > 0:
		print("AnalyticsEventQueue: Updated user_id to '%s' in %d events" % [new_user_id, updated_count])

func update_steam_id(new_steam_id: String) -> void:
	"""Update steam_id in all queued events (called when Steam user signs in)"""
	var updated_count: int = 0
	for event in _queue:
		if not event.has("params"):
			continue
		var params: Dictionary = event["params"]
		if params.get("steam_id", "").is_empty():
			params["steam_id"] = new_steam_id
			updated_count += 1
	if updated_count > 0:
		print("AnalyticsEventQueue: Updated steam_id to '%s' in %d events" % [new_steam_id, updated_count])
