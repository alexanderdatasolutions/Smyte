# scripts/systems/firebase/CloudSaveManager.gd
# Handles cloud save/load to Firestore for authenticated users
class_name CloudSaveManager extends Node

signal cloud_save_completed
signal cloud_save_failed(error: String)
signal cloud_load_completed(save_data: Dictionary)
signal cloud_load_failed(error: String)
signal cloud_save_not_found

const COLLECTION_NAME = "user_saves"

var _firestore = null
var _user_id: String = ""
var _save_in_progress: bool = false
var _load_in_progress: bool = false
var _pending_save_data: Dictionary = {}  # Queue the latest save if one is in progress

# Debouncing - prevent save spam while ensuring data isn't lost
const SAVE_DEBOUNCE_SECONDS: float = 2.5  # Minimum time between saves
var _last_save_time: float = 0.0
var _debounce_timer: Timer = null
var _debounced_data: Dictionary = {}  # Data waiting for debounce timer

func initialize(firestore, user_id: String):
	"""Initialize with Firestore reference and user ID"""
	_firestore = firestore
	_user_id = user_id
	print("CloudSaveManager: Initialized for user '%s'" % user_id)
	print("CloudSaveManager: Firestore=%s, collection=%s" % [firestore != null, COLLECTION_NAME])

func clear():
	"""Clear state when user signs out"""
	print("CloudSaveManager: clear() called - wiping state")
	_firestore = null
	_user_id = ""
	_save_in_progress = false
	_load_in_progress = false
	_pending_save_data = {}
	_debounced_data = {}
	if _debounce_timer:
		_debounce_timer.stop()

func force_save_now() -> void:
	"""Force immediate save, bypassing debounce. Call on app exit."""
	if _debounce_timer:
		_debounce_timer.stop()

	# Save any debounced data immediately
	if not _debounced_data.is_empty():
		var data: Dictionary = _debounced_data
		_debounced_data = {}
		if not _save_in_progress:
			_execute_save(data)
		else:
			_pending_save_data = data

func is_ready() -> bool:
	"""Check if cloud saves are available"""
	var is_available = _firestore != null and not _user_id.is_empty()
	if not is_available:
		print("CloudSaveManager.is_ready: firestore=%s, user_id=%s" % [_firestore != null, _user_id])
	return is_available

# ==============================================================================
# SAVE TO CLOUD
# ==============================================================================

func save_to_cloud(save_data: Dictionary):
	"""Save game data to Firestore with debouncing to prevent spam"""
	if not is_ready():
		cloud_save_failed.emit("Cloud save not configured")
		return

	# Add cloud-specific metadata
	var cloud_data = save_data.duplicate(true)
	cloud_data["cloud_timestamp"] = Time.get_unix_time_from_system()
	cloud_data["user_id"] = _user_id

	# Debouncing: if we saved recently, queue this save for later
	var now: float = Time.get_unix_time_from_system()
	var time_since_last: float = now - _last_save_time

	if time_since_last < SAVE_DEBOUNCE_SECONDS:
		# Too soon - queue data and start/reset debounce timer
		_debounced_data = cloud_data
		_ensure_debounce_timer()
		return

	# If a save is already in progress, queue for after it completes
	if _save_in_progress:
		_pending_save_data = cloud_data
		return

	_execute_save(cloud_data)

func _execute_save(cloud_data: Dictionary) -> void:
	"""Actually execute the save (called after debounce check passes)"""
	_save_in_progress = true
	_last_save_time = Time.get_unix_time_from_system()
	_do_save.call_deferred(cloud_data)

func _ensure_debounce_timer() -> void:
	"""Create or reset the debounce timer"""
	if _debounce_timer == null:
		_debounce_timer = Timer.new()
		_debounce_timer.one_shot = true
		_debounce_timer.timeout.connect(_on_debounce_timeout)
		add_child(_debounce_timer)

	# Reset timer to fire after remaining debounce time
	var remaining: float = SAVE_DEBOUNCE_SECONDS - (Time.get_unix_time_from_system() - _last_save_time)
	_debounce_timer.start(maxf(0.1, remaining))

func _on_debounce_timeout() -> void:
	"""Debounce timer fired - execute the queued save"""
	if _debounced_data.is_empty():
		return

	var data_to_save: Dictionary = _debounced_data
	_debounced_data = {}

	if _save_in_progress:
		# Another save started while we were waiting - queue this one
		_pending_save_data = data_to_save
	else:
		_execute_save(data_to_save)

const MAX_RETRY_ATTEMPTS: int = 3
const INITIAL_BACKOFF_SECONDS: float = 1.0

func _do_save(cloud_data: Dictionary, retry_attempt: int = 0) -> void:
	"""Perform the actual save operation (async) with retry and exponential backoff"""
	print("CloudSaveManager: _do_save called, firestore=%s" % (_firestore != null))
	var collection = _firestore.collection(COLLECTION_NAME) if _firestore else null
	if not collection:
		_save_in_progress = false
		print("CloudSaveManager: ERROR - Firestore collection unavailable!")
		cloud_save_failed.emit("Firestore collection unavailable")
		_check_pending_save()
		return

	# Use set_doc instead of add - set_doc creates or overwrites the document
	# add() uses POST which fails if document exists, set_doc() uses PATCH
	if retry_attempt == 0:
		print("CloudSaveManager: Saving to collection '%s', document '%s'" % [COLLECTION_NAME, _user_id])
	else:
		print("CloudSaveManager: Retry attempt %d for document '%s'" % [retry_attempt, _user_id])

	await collection.set_doc(_user_id, cloud_data)

	# set_doc returns void, so verify by fetching the document
	var verify = await collection.get_doc(_user_id)

	if verify != null and verify is FirestoreDocument:
		_save_in_progress = false
		print("CloudSaveManager: Cloud save verified successfully")
		cloud_save_completed.emit()
		_check_pending_save()
	else:
		# Save failed - retry with exponential backoff
		if retry_attempt < MAX_RETRY_ATTEMPTS:
			var backoff: float = INITIAL_BACKOFF_SECONDS * pow(2.0, retry_attempt)
			print("CloudSaveManager: Save verification failed, retrying in %.1fs..." % backoff)
			await get_tree().create_timer(backoff).timeout
			# Still in progress, retry
			_do_save(cloud_data, retry_attempt + 1)
		else:
			_save_in_progress = false
			print("CloudSaveManager: Cloud save failed after %d attempts" % MAX_RETRY_ATTEMPTS)
			cloud_save_failed.emit("Save verification failed after retries")
			_check_pending_save()

func _check_pending_save():
	"""Check if there's a queued save and process it"""
	if not _pending_save_data.is_empty():
		print("CloudSaveManager: Processing queued save")
		var queued_data = _pending_save_data
		_pending_save_data = {}
		save_to_cloud(queued_data)

# ==============================================================================
# LOAD FROM CLOUD
# ==============================================================================

func load_from_cloud():
	"""Load game data from Firestore"""
	if not is_ready():
		cloud_load_failed.emit("Cloud load not configured")
		return

	if _load_in_progress:
		print("CloudSaveManager: Load already in progress, skipping")
		return

	_load_in_progress = true
	_do_load.call_deferred()

func _do_load() -> void:
	"""Perform the actual load operation (async)"""
	var collection = _firestore.collection(COLLECTION_NAME) if _firestore else null
	if not collection:
		_load_in_progress = false
		cloud_load_failed.emit("Firestore collection unavailable")
		return

	var result = await collection.get_doc(_user_id)

	_load_in_progress = false

	if result == null:
		cloud_save_not_found.emit()
		return

	if not result is FirestoreDocument:
		cloud_save_not_found.emit()
		return

	var save_data: Dictionary = _extract_document_data(result)

	if save_data.is_empty():
		cloud_save_not_found.emit()
		return

	cloud_load_completed.emit(save_data)

func _extract_document_data(doc: FirestoreDocument) -> Dictionary:
	"""Extract plain Dictionary from FirestoreDocument"""
	var result: Dictionary = {}
	if not doc.has_method("keys") or not doc.has_method("get_value"):
		return result
	for key in doc.keys():
		result[key] = doc.get_value(key)
	return result

# ==============================================================================
# UTILITIES
# ==============================================================================

func get_cloud_timestamp(save_data: Dictionary) -> int:
	"""Get the cloud timestamp from save data"""
	return save_data.get("cloud_timestamp", 0)

func get_local_timestamp(save_data: Dictionary) -> int:
	"""Get the local timestamp from save data"""
	return save_data.get("timestamp", 0)
