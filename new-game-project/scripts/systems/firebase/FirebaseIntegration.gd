# scripts/systems/firebase/FirebaseIntegration.gd
# Main Firebase coordinator - handles Auth, Analytics, and Cloud Saves
# Requires GodotFirebase addon: https://github.com/GodotNuts/GodotFirebase
class_name FirebaseIntegration extends Node

signal firebase_ready
signal sign_in_started
signal sign_in_completed(user_data: Dictionary)
signal sign_in_failed(error: String)
signal sign_out_completed
signal cloud_save_completed
signal cloud_save_failed(error: String)
signal cloud_load_completed(save_data: Dictionary)
signal cloud_load_failed(error: String)
signal cloud_save_not_found

enum AuthState { SIGNED_OUT, SIGNING_IN, SIGNED_IN }

var auth_state: AuthState = AuthState.SIGNED_OUT
var user_data: Dictionary = {}
var analytics: FirebaseAnalytics
var cloud_save_manager: CloudSaveManager

var _firebase_available: bool = false
var _event_bus: Node = null

# Throttling for high-frequency events
var _last_resource_log_time: float = 0.0
const RESOURCE_LOG_COOLDOWN: float = 5.0  # seconds between resource logs

# Steam authentication (uses Steam ID directly, no Cloud Function needed)
var _steam_id: int = 0
var _auth_provider: String = ""  # "google", "steam", "email"
var _firebase_auth_uid: String = ""  # Firebase Auth UID for Firestore access

func _ready() -> void:
	name = "FirebaseIntegration"

func initialize() -> void:
	"""Called by SystemRegistry after registration"""
	# Check if GodotFirebase addon is available
	_firebase_available = _check_firebase_addon()

	if not _firebase_available:
		push_warning("FirebaseIntegration: GodotFirebase addon not found. Analytics will be local-only.")

	# Initialize analytics (works even without Firebase - queues locally)
	analytics = FirebaseAnalytics.new()
	add_child(analytics)

	# Initialize cloud save manager
	cloud_save_manager = CloudSaveManager.new()
	cloud_save_manager.name = "CloudSaveManager"
	add_child(cloud_save_manager)
	_connect_cloud_save_signals()

	if _firebase_available:
		# Use call_deferred since _setup_firebase is async
		_setup_firebase.call_deferred()

	# Connect to EventBus for automatic analytics
	_connect_event_bus()

	firebase_ready.emit()

func _check_firebase_addon() -> bool:
	"""Check if GodotFirebase addon is installed and configured"""
	# GodotFirebase is an autoload, not an Engine singleton
	# Check if Firebase autoload exists in the scene tree
	return get_node_or_null("/root/Firebase") != null

func _get_firebase() -> Node:
	"""Get the Firebase autoload node"""
	return get_node_or_null("/root/Firebase")

func _setup_firebase() -> void:
	"""Configure Firebase connections"""
	# GodotFirebase addon uses @onready for Auth/Firestore, so we need to wait
	# for the scene tree to be ready before accessing them
	await get_tree().process_frame

	var firebase: Node = _get_firebase()

	if not firebase:
		push_warning("FirebaseIntegration: Firebase node NOT found!")
		return

	# Connect auth signals - GodotFirebase uses Firebase.Auth
	if firebase.Auth:
		_safe_connect(firebase.Auth, "login_succeeded", _on_login_succeeded)
		_safe_connect(firebase.Auth, "login_failed", _on_login_failed)
		_safe_connect(firebase.Auth, "signup_succeeded", _on_login_succeeded)
		_safe_connect(firebase.Auth, "signup_failed", _on_login_failed)
		_safe_connect(firebase.Auth, "logged_out", _on_logout_succeeded)
		_safe_connect(firebase.Auth, "token_refresh_succeeded", _on_token_refresh_succeeded)

		# Skip auth file check for Steam users - they use anonymous auth
		if is_steam_available():
			print("FirebaseIntegration: Skipping auth file check (Steam available)")
		else:
			# Check for saved auth file first (persistent login)
			if firebase.Auth.check_auth_file():
				pass
			# Fallback: check if already has auth in memory
			elif firebase.Auth.auth and not firebase.Auth.auth.is_empty():
				_restore_session(firebase.Auth.auth)
	else:
		push_warning("FirebaseIntegration: Firebase.Auth not ready")

	# Give Firestore reference to analytics
	if firebase.Firestore:
		analytics.set_firestore(firebase.Firestore)
		print("FirebaseIntegration: Analytics Firestore connected")
	else:
		print("FirebaseIntegration: WARNING - firebase.Firestore is null!")

func _connect_event_bus() -> void:
	"""Hook into EventBus for automatic analytics logging"""
	var system_registry_script: GDScript = load("res://scripts/systems/core/SystemRegistry.gd") as GDScript
	if not system_registry_script:
		return

	var registry: Node = system_registry_script.get_instance()
	if not registry:
		return

	_event_bus = registry.get_system("EventBus")
	if not _event_bus:
		return

	# Delegate all event tracking to FirebaseAnalytics (centralized, clean format)
	if analytics:
		analytics.connect_to_event_bus(_event_bus)

	# Keep resource_changed here with throttling (high frequency event)
	_safe_connect(_event_bus, "resource_changed", _on_resource_changed)

func _safe_connect(source: Object, signal_name: String, callable: Callable) -> void:
	"""Safely connect to signal if it exists"""
	if source.has_signal(signal_name):
		if not source.is_connected(signal_name, callable):
			source.connect(signal_name, callable)

func _connect_cloud_save_signals() -> void:
	"""Connect cloud save manager signals to pass through"""
	if cloud_save_manager:
		cloud_save_manager.cloud_save_completed.connect(func() -> void: cloud_save_completed.emit())
		cloud_save_manager.cloud_save_failed.connect(func(err: String) -> void: cloud_save_failed.emit(err))
		cloud_save_manager.cloud_load_completed.connect(func(data: Dictionary) -> void: cloud_load_completed.emit(data))
		cloud_save_manager.cloud_load_failed.connect(func(err: String) -> void: cloud_load_failed.emit(err))
		cloud_save_manager.cloud_save_not_found.connect(func() -> void: cloud_save_not_found.emit())

# ==============================================================================
# AUTHENTICATION
# ==============================================================================

func _extract_user_data(auth_data: Dictionary) -> Dictionary:
	"""Extract normalized user data from Firebase auth result.
	GodotFirebase uses inconsistent key names across login/signup/token-refresh,
	so we try multiple variants for each field."""
	var provider: String = "email"
	if auth_data.has("providerid"):
		provider = auth_data.get("providerid")
	elif auth_data.has("provider_id"):
		provider = auth_data.get("provider_id")

	return {
		"uid": auth_data.get("localid", auth_data.get("local_id", auth_data.get("userid", auth_data.get("user_id", "")))),
		"email": auth_data.get("email", ""),
		"display_name": auth_data.get("displayname", auth_data.get("display_name", "")),
		"photo_url": auth_data.get("photourl", auth_data.get("photo_url", "")),
		"provider": provider
	}

func sign_in_with_google() -> void:
	"""Start Google Sign-In flow via Firebase Auth"""
	if auth_state == AuthState.SIGNING_IN:
		return

	if not _firebase_available:
		sign_in_failed.emit("Firebase not available")
		return

	var firebase: Node = _get_firebase()
	if not firebase or not firebase.Auth:
		sign_in_failed.emit("Firebase Auth not configured")
		return

	# GodotFirebase requires clientId and clientSecret for OAuth
	# Check if they're configured
	var google_provider: Variant = firebase.Auth.get_GoogleProvider()
	if not google_provider:
		sign_in_failed.emit("Google provider not configured. Set clientId and clientSecret in .env")
		return

	auth_state = AuthState.SIGNING_IN
	sign_in_started.emit()
	_auth_provider = "google"

	# GodotFirebase opens browser for OAuth, captures token via local server
	firebase.Auth.get_auth_localhost(google_provider)

func sign_in_with_steam() -> void:
	"""Sign in using Steam - uses Steam ID directly as user identifier.
	Also signs in anonymously to Firebase for Firestore access."""
	if auth_state == AuthState.SIGNING_IN:
		return

	# Check if Steam is available
	if not Engine.has_singleton("Steam"):
		sign_in_failed.emit("Steam not available")
		return

	var steam: Object = Engine.get_singleton("Steam")

	# Check if Steam is initialized
	if not steam.isSteamRunning():
		sign_in_failed.emit("Steam is not running")
		return

	auth_state = AuthState.SIGNING_IN
	sign_in_started.emit()
	_auth_provider = "steam"

	# Get Steam ID and persona name
	_steam_id = steam.getSteamID()
	var persona_name: String = steam.getPersonaName()

	print("FirebaseIntegration: Steam sign-in for %s (ID: %d)" % [persona_name, _steam_id])

	# Create user data from Steam info
	user_data = {
		"uid": "steam_%d" % _steam_id,
		"email": "",
		"display_name": persona_name,
		"photo_url": "",
		"provider": "steam",
		"steam_id": str(_steam_id),
		"steam_name": persona_name
	}

	# Sign in anonymously to Firebase for Firestore access
	# Steam ID is used as document key, but we need Firebase Auth for write permissions
	_do_anonymous_firebase_auth.call_deferred()

func _do_anonymous_firebase_auth() -> void:
	"""Sign in anonymously to Firebase, then complete Steam sign-in"""
	var firebase: Node = _get_firebase()
	if firebase and firebase.Auth:
		print("FirebaseIntegration: Signing in anonymously to Firebase for Firestore access...")

		# Small delay to let any pending auth operations finish
		await get_tree().create_timer(0.5).timeout

		# login_anonymous doesn't return anything - signals will fire
		firebase.Auth.login_anonymous()

		# Wait a bit for the auth to complete
		await get_tree().create_timer(1.0).timeout
		print("FirebaseIntegration: Anonymous auth attempt completed")

	_complete_steam_sign_in()

func _complete_steam_sign_in() -> void:
	"""Complete the Steam sign-in process after Firebase auth attempt"""
	auth_state = AuthState.SIGNED_IN
	print("FirebaseIntegration: auth_state set to SIGNED_IN for Steam user")

	# user_data.uid already set to steam_{id} in sign_in_with_steam()
	if analytics:
		analytics.set_user_id(user_data.get("uid", ""))
		# Set Steam ID as a separate field for analytics tracking
		analytics.set_steam_id(str(_steam_id))
		# Set display name from Steam persona
		analytics.set_display_name(user_data.get("display_name", ""))

	# Initialize cloud saves with Steam ID
	_initialize_cloud_saves_for_steam()

	sign_in_completed.emit(user_data)

func _initialize_cloud_saves_for_steam() -> void:
	"""Initialize cloud saves using Steam ID (consistent across sessions)"""
	var firebase: Node = _get_firebase()
	print("FirebaseIntegration: _initialize_cloud_saves_for_steam - firebase=%s" % (firebase != null))
	if firebase:
		print("FirebaseIntegration: firebase.Firestore=%s" % (firebase.Firestore != null))
	print("FirebaseIntegration: cloud_save_manager=%s" % (cloud_save_manager != null))
	print("FirebaseIntegration: _steam_id=%d" % _steam_id)

	if firebase and firebase.Firestore and cloud_save_manager and _steam_id != 0:
		# Use Steam ID as document key (consistent across sessions)
		# Firebase rules must allow any authenticated user to write
		var steam_doc_id: String = "steam_%d" % _steam_id
		cloud_save_manager.initialize(firebase.Firestore, steam_doc_id)
		print("FirebaseIntegration: Cloud saves initialized with Steam ID %s" % steam_doc_id)
	else:
		print("FirebaseIntegration: WARNING - Could not initialize cloud saves!")

func is_steam_available() -> bool:
	"""Check if Steam is available for authentication"""
	if not Engine.has_singleton("Steam"):
		return false
	var steam: Object = Engine.get_singleton("Steam")
	return steam.isSteamRunning()

func get_steam_id() -> int:
	"""Get the current Steam ID if signed in via Steam"""
	return _steam_id

func get_auth_provider() -> String:
	"""Get the provider used for current auth session"""
	return _auth_provider

func sign_in_with_email(email: String, password: String) -> void:
	"""Sign in with email and password"""
	if auth_state == AuthState.SIGNING_IN:
		return

	if not _firebase_available:
		sign_in_failed.emit("Firebase not available")
		return

	var firebase: Node = _get_firebase()
	if not firebase or not firebase.Auth:
		sign_in_failed.emit("Firebase Auth not configured")
		return

	auth_state = AuthState.SIGNING_IN
	sign_in_started.emit()
	_auth_provider = "email"

	# GodotFirebase email/password login
	firebase.Auth.login_with_email_and_password(email, password)

func sign_up_with_email(email: String, password: String) -> void:
	"""Create new account with email and password"""
	if auth_state == AuthState.SIGNING_IN:
		return

	if not _firebase_available:
		sign_in_failed.emit("Firebase not available")
		return

	var firebase: Node = _get_firebase()
	if not firebase or not firebase.Auth:
		sign_in_failed.emit("Firebase Auth not configured")
		return

	auth_state = AuthState.SIGNING_IN
	sign_in_started.emit()

	# GodotFirebase email/password signup
	firebase.Auth.signup_with_email_and_password(email, password)

func sign_out() -> void:
	"""Sign out of Firebase"""
	if auth_state != AuthState.SIGNED_IN:
		return

	# Flush analytics before signing out
	await analytics.flush_queue()

	var firebase: Node = _get_firebase()
	if firebase and firebase.Auth:
		firebase.Auth.logout()

func is_signed_in() -> bool:
	var result: bool = auth_state == AuthState.SIGNED_IN
	if not result:
		print("FirebaseIntegration: is_signed_in() = false (auth_state=%s, provider=%s)" % [auth_state, _auth_provider])
	return result

func get_user_id() -> String:
	return user_data.get("uid", "")

func get_user_display_name() -> String:
	return user_data.get("display_name", "")

func get_user_email() -> String:
	return user_data.get("email", "")

func get_user_photo_url() -> String:
	return user_data.get("photo_url", "")

func get_firestore() -> Variant:
	"""Get the Firestore reference for direct database access (used by ArenaDataSync)"""
	var firebase: Node = _get_firebase()
	if firebase and firebase.Firestore:
		return firebase.Firestore
	return null

func _on_login_succeeded(auth_result: Dictionary) -> void:
	"""Handle successful Firebase login"""
	# Skip if already signed in (e.g., from token refresh on session restore)
	if auth_state == AuthState.SIGNED_IN:
		return

	# For Steam users, DON'T overwrite user_data - keep Steam info
	# Just store the Firebase auth UID separately for Firestore access
	if _auth_provider == "steam":
		var firebase_data: Dictionary = _extract_user_data(auth_result)
		_firebase_auth_uid = firebase_data.get("uid", "")
		print("FirebaseIntegration: Steam user - stored Firebase UID: %s (keeping Steam user_data)" % _firebase_auth_uid)
		# Don't change auth_state or user_data - _complete_steam_sign_in handles that
		# Just save the auth file for Firestore access
		var fb: Node = _get_firebase()
		if fb and fb.Auth:
			print("FirebaseIntegration: Saving auth to file...")
			fb.Auth.save_auth(auth_result)
		return

	# Non-Steam auth - normal flow
	user_data = _extract_user_data(auth_result)
	auth_state = AuthState.SIGNED_IN
	analytics.set_user_id(user_data.get("uid", ""))
	_load_display_name_for_analytics()

	# Save auth for persistent login
	var firebase: Node = _get_firebase()
	if firebase and firebase.Auth:
		print("FirebaseIntegration: Saving auth to file...")
		firebase.Auth.save_auth(auth_result)
	else:
		print("FirebaseIntegration: Cannot save auth - firebase=%s" % (firebase != null))

	# Initialize cloud save manager with Firestore
	_initialize_cloud_saves()
	sign_in_completed.emit(user_data)

func _on_login_failed(error_code: Variant, error_message: Variant) -> void:
	"""Handle failed Firebase login"""
	print("FirebaseIntegration: _on_login_failed called - provider=%s, auth_state=%s" % [_auth_provider, auth_state])
	# Don't reset auth state if we're already signed in via Steam
	# (Firebase Auth failures don't affect Steam-based auth)
	if _auth_provider == "steam" and auth_state == AuthState.SIGNED_IN:
		print("FirebaseIntegration: Ignoring Firebase Auth failure (using Steam auth)")
		return

	# Also ignore if we're using Steam but haven't completed sign-in yet
	# (check_auth_file may trigger failures before Steam sign-in completes)
	if _auth_provider == "steam":
		print("FirebaseIntegration: Ignoring Firebase Auth failure (Steam auth in progress)")
		return

	auth_state = AuthState.SIGNED_OUT
	var error_str: String = "%s: %s" % [error_code, error_message]
	sign_in_failed.emit(error_str)
	analytics.log_error("auth_failed", error_str)

func _on_logout_succeeded() -> void:
	"""Handle Firebase logout"""
	user_data.clear()
	auth_state = AuthState.SIGNED_OUT
	analytics.set_user_id("anonymous")
	analytics.set_display_name("Anonymous")
	if cloud_save_manager:
		cloud_save_manager.clear()
	# Remove saved auth file
	var firebase: Node = _get_firebase()
	if firebase and firebase.Auth:
		firebase.Auth.remove_auth()
	sign_out_completed.emit()

func _on_token_refresh_succeeded(auth_result: Dictionary) -> void:
	"""Handle token refresh from saved auth file"""
	if auth_state == AuthState.SIGNED_IN:
		return  # Already signed in, just a token refresh

	# Skip for Steam users - we handle auth in _complete_steam_sign_in
	if _auth_provider == "steam":
		print("FirebaseIntegration: Skipping token refresh restore (Steam auth)")
		return

	# This is a session restore from saved auth
	_restore_session(auth_result)

func _initialize_cloud_saves(load_from_cloud_on_init: bool = true) -> void:
	"""Initialize cloud save manager with Firestore and user ID"""
	var firebase: Node = _get_firebase()
	if firebase and firebase.Firestore and cloud_save_manager:
		cloud_save_manager.initialize(firebase.Firestore, user_data.get("uid", ""))

		# On fresh sign-in, try to load from cloud
		if load_from_cloud_on_init:
			# Defer to allow SaveManager to connect signals first
			_load_cloud_save_deferred.call_deferred()

func _load_cloud_save_deferred() -> void:
	"""Load from cloud after a short delay to allow systems to initialize"""
	await get_tree().create_timer(0.5).timeout
	if cloud_save_manager and cloud_save_manager.is_ready():
		cloud_save_manager.load_from_cloud()

# ==============================================================================
# CLOUD SAVES
# ==============================================================================

func save_to_cloud(save_data: Dictionary) -> void:
	"""Save game data to cloud (Firestore)"""
	if cloud_save_manager and cloud_save_manager.is_ready():
		cloud_save_manager.save_to_cloud(save_data)
	else:
		cloud_save_failed.emit("Cloud save not available")

func load_from_cloud() -> void:
	"""Load game data from cloud (Firestore)"""
	if cloud_save_manager and cloud_save_manager.is_ready():
		cloud_save_manager.load_from_cloud()
	else:
		cloud_load_failed.emit("Cloud load not available")

func is_cloud_save_ready() -> bool:
	"""Check if cloud saves are available"""
	# Auto-reinitialize if signed in but CloudSaveManager lost its state (scene reload)
	if cloud_save_manager and not cloud_save_manager.is_ready():
		if auth_state == AuthState.SIGNED_IN:
			print("FirebaseIntegration: Re-initializing cloud saves (scene reload fix)")
			# Use correct init method based on auth provider
			if _auth_provider == "steam" and _steam_id != 0:
				_initialize_cloud_saves_for_steam()
			elif not user_data.get("uid", "").is_empty():
				_initialize_cloud_saves(false)
	return cloud_save_manager != null and cloud_save_manager.is_ready()

func _restore_session(auth_data: Dictionary) -> void:
	"""Restore session from cached credentials (token refresh or saved auth)"""
	# Skip for Steam users - they have their own sign-in flow
	if _auth_provider == "steam":
		print("FirebaseIntegration: Skipping session restore (Steam auth)")
		return

	user_data = _extract_user_data(auth_data)

	if not user_data.get("uid", "").is_empty():
		auth_state = AuthState.SIGNED_IN
		analytics.set_user_id(user_data.get("uid", ""))
		_load_display_name_for_analytics()
		# Don't auto-load from cloud on session restore - local save is current
		_initialize_cloud_saves(false)
		sign_in_completed.emit(user_data)

func _load_display_name_for_analytics() -> void:
	"""Load display name from SaveManager and set on analytics"""
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	var save_manager: Node = registry.get_system("SaveManager")
	if not save_manager:
		return

	# Try to get display name now (if save already loaded)
	if save_manager.has_method("get_player_value"):
		var display_name: String = save_manager.get_player_value("display_name", "")
		if not display_name.is_empty():
			analytics.set_display_name(display_name)
			return

	# If not loaded yet, wait for load_completed signal
	if save_manager.has_signal("load_completed") and not save_manager.load_completed.is_connected(_on_save_loaded_for_display_name):
		save_manager.load_completed.connect(_on_save_loaded_for_display_name, CONNECT_ONE_SHOT)

func _on_save_loaded_for_display_name(_success: bool, _data: Dictionary) -> void:
	"""Called when SaveManager finishes loading - get display name"""
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	var save_manager: Node = registry.get_system("SaveManager")
	if save_manager and save_manager.has_method("get_player_value"):
		var display_name: String = save_manager.get_player_value("display_name", "")
		if not display_name.is_empty():
			analytics.set_display_name(display_name)

# ==============================================================================
# EVENTBUS SIGNAL HANDLERS (kept here for throttling)
# ==============================================================================

func _on_resource_changed(resource_id: String, _new_amount: int, delta: int) -> void:
	"""Log significant resource changes (filter noise + throttle)"""
	# Throttle to prevent spam
	var now: float = Time.get_unix_time_from_system()
	if now - _last_resource_log_time < RESOURCE_LOG_COOLDOWN:
		return

	# Only log significant changes to avoid spam
	if abs(delta) >= 100 or resource_id in ["divine_crystals", "legendary_soul", "epic_soul"]:
		_last_resource_log_time = now
		analytics.track("resource_changed", "economy", resource_id, delta)

# ==============================================================================
# SHUTDOWN
# ==============================================================================

func shutdown() -> void:
	"""Called by SystemRegistry on shutdown"""
	print("FirebaseIntegration: shutdown() called")

	# Force any pending cloud saves to execute immediately (bypass debounce)
	if cloud_save_manager:
		print("FirebaseIntegration: Forcing cloud save...")
		cloud_save_manager.force_save_now()

	if analytics:
		print("FirebaseIntegration: Flushing analytics queue...")
		await analytics.flush_queue()
		print("FirebaseIntegration: Analytics flush complete")
