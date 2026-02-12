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

func initialize(firestore, user_id: String):
	"""Initialize with Firestore reference and user ID"""
	_firestore = firestore
	_user_id = user_id
	print("CloudSaveManager: Initialized for user %s" % user_id)

func clear():
	"""Clear state when user signs out"""
	_firestore = null
	_user_id = ""
	_save_in_progress = false
	_load_in_progress = false

func is_ready() -> bool:
	"""Check if cloud saves are available"""
	return _firestore != null and not _user_id.is_empty()

# ==============================================================================
# SAVE TO CLOUD
# ==============================================================================

func save_to_cloud(save_data: Dictionary):
	"""Save game data to Firestore"""
	if not is_ready():
		cloud_save_failed.emit("Cloud save not configured")
		return

	if _save_in_progress:
		print("CloudSaveManager: Save already in progress, skipping")
		return

	_save_in_progress = true

	# Add cloud-specific metadata
	var cloud_data = save_data.duplicate(true)
	cloud_data["cloud_timestamp"] = Time.get_unix_time_from_system()
	cloud_data["user_id"] = _user_id

	# Run async save operation
	_do_save.call_deferred(cloud_data)

func _do_save(cloud_data: Dictionary):
	"""Perform the actual save operation (async)"""
	var collection = _firestore.collection(COLLECTION_NAME)

	# GodotFirebase's add() is a coroutine - await it directly
	var result = await collection.add(_user_id, cloud_data)

	_save_in_progress = false

	# FirestoreDocument is a Node - check if we got a valid result
	if result != null and result is FirestoreDocument:
		print("CloudSaveManager: Cloud save successful")
		cloud_save_completed.emit()
	else:
		var error_msg = "Save returned null or invalid result"
		print("CloudSaveManager: Cloud save failed - %s" % error_msg)
		cloud_save_failed.emit(error_msg)

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

func _do_load():
	"""Perform the actual load operation (async)"""
	var collection = _firestore.collection(COLLECTION_NAME)

	# GodotFirebase's get_doc() is a coroutine - await it directly
	var result = await collection.get_doc(_user_id)

	_load_in_progress = false

	if result == null:
		print("CloudSaveManager: No cloud save found for user")
		cloud_save_not_found.emit()
		return

	# FirestoreDocument is a Node - extract data from it
	if not result is FirestoreDocument:
		print("CloudSaveManager: Unexpected result type")
		cloud_save_not_found.emit()
		return

	# Extract document data
	var save_data = _extract_document_data(result)

	if save_data.is_empty():
		print("CloudSaveManager: Cloud save exists but is empty")
		cloud_save_not_found.emit()
		return

	print("CloudSaveManager: Cloud save loaded successfully")
	cloud_load_completed.emit(save_data)

func _extract_document_data(doc: FirestoreDocument) -> Dictionary:
	"""Extract plain Dictionary from FirestoreDocument"""
	var result = {}
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
