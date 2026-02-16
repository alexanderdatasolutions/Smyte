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

	# Connect to core gameplay signals
	_safe_connect(_event_bus, "battle_ended", _on_battle_ended)
	_safe_connect(_event_bus, "god_obtained", _on_god_obtained)
	_safe_connect(_event_bus, "god_level_up", _on_god_level_up)
	_safe_connect(_event_bus, "dungeon_completed", _on_dungeon_completed)
	_safe_connect(_event_bus, "resource_changed", _on_resource_changed)
	_safe_connect(_event_bus, "territory_captured", _on_territory_captured)
	_safe_connect(_event_bus, "screen_changed", _on_screen_changed)
	_safe_connect(_event_bus, "error_occurred", _on_error_occurred)

	# Extended analytics signals
	_safe_connect(_event_bus, "summon_completed_detailed", _on_summon_detailed)
	_safe_connect(_event_bus, "god_sacrifice_completed", _on_sacrifice)
	_safe_connect(_event_bus, "god_awakening_completed", _on_awakening)
	_safe_connect(_event_bus, "battle_team_entered", _on_battle_team)
	_safe_connect(_event_bus, "garrison_updated", _on_garrison)
	_safe_connect(_event_bus, "workers_updated", _on_workers)
	_safe_connect(_event_bus, "achievement_unlocked", _on_achievement)
	_safe_connect(_event_bus, "arena_battle_completed", _on_arena_battle)
	_safe_connect(_event_bus, "league_changed", _on_league_change)
	_safe_connect(_event_bus, "specialization_unlocked", _on_specialization)
	_safe_connect(_event_bus, "equipment_equipped", _on_equipment_equipped)
	_safe_connect(_event_bus, "equipment_unequipped", _on_equipment_unequipped)

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

	# GodotFirebase opens browser for OAuth, captures token via local server
	firebase.Auth.get_auth_localhost(google_provider)

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
	return auth_state == AuthState.SIGNED_IN

func get_user_id() -> String:
	return user_data.get("uid", "")

func get_user_display_name() -> String:
	return user_data.get("display_name", "")

func get_user_email() -> String:
	return user_data.get("email", "")

func get_user_photo_url() -> String:
	return user_data.get("photo_url", "")

func _on_login_succeeded(auth_result: Dictionary) -> void:
	"""Handle successful Firebase login"""
	# Skip if already signed in (e.g., from token refresh on session restore)
	if auth_state == AuthState.SIGNED_IN:
		return

	user_data = _extract_user_data(auth_result)
	auth_state = AuthState.SIGNED_IN
	analytics.set_user_id(user_data.get("uid", ""))

	# Save auth for persistent login
	var firebase: Node = _get_firebase()
	if firebase and firebase.Auth:
		firebase.Auth.save_auth(auth_result)

	# Initialize cloud save manager with Firestore
	_initialize_cloud_saves()

	sign_in_completed.emit(user_data)

func _on_login_failed(error_code: Variant, error_message: Variant) -> void:
	"""Handle failed Firebase login"""
	auth_state = AuthState.SIGNED_OUT
	var error_str: String = "%s: %s" % [error_code, error_message]
	sign_in_failed.emit(error_str)
	analytics.log_error("auth_failed", error_str)

func _on_logout_succeeded() -> void:
	"""Handle Firebase logout"""
	user_data.clear()
	auth_state = AuthState.SIGNED_OUT
	analytics.set_user_id("anonymous")
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
	return cloud_save_manager != null and cloud_save_manager.is_ready()

func _restore_session(auth_data: Dictionary) -> void:
	"""Restore session from cached credentials (token refresh or saved auth)"""
	user_data = _extract_user_data(auth_data)

	if not user_data.get("uid", "").is_empty():
		auth_state = AuthState.SIGNED_IN
		analytics.set_user_id(user_data.get("uid", ""))
		# Don't auto-load from cloud on session restore - local save is current
		_initialize_cloud_saves(false)
		sign_in_completed.emit(user_data)

# ==============================================================================
# EVENTBUS SIGNAL HANDLERS -> ANALYTICS
# ==============================================================================

func _on_battle_ended(result: Variant) -> void:
	"""Log battle completion"""
	if result is Dictionary:
		analytics.log_battle_completed(
			result.get("victory", false),
			result.get("battle_type", "unknown"),
			result.get("duration", 0.0),
			result.get("team_power", 0),
			{
				"enemy_count": result.get("enemy_count", 0),
				"rewards": result.get("rewards", {})
			}
		)

func _on_god_obtained(god: Variant) -> void:
	"""Log god obtained"""
	if god:
		var tier_str: String = "unknown"
		var element_str: String = "unknown"

		# Handle God object
		if god.has_method("get"):
			tier_str = str(god.tier) if "tier" in god else "unknown"
			element_str = str(god.element) if "element" in god else "unknown"
		elif god is Dictionary:
			tier_str = str(god.get("tier", "unknown"))
			element_str = str(god.get("element", "unknown"))

		analytics.log_god_obtained(
			god.id if "id" in god else str(god),
			tier_str,
			element_str,
			"summon"  # Could be passed as parameter
		)

func _on_god_level_up(god_id: String, new_level: int, old_level: int) -> void:
	"""Log god level up"""
	analytics.log_god_leveled(god_id, old_level, new_level)

func _on_dungeon_completed(dungeon_id: String, rewards: Variant = null) -> void:
	"""Log dungeon completion"""
	var rewards_dict: Dictionary = {}
	if rewards is Dictionary:
		rewards_dict = rewards
	analytics.log_dungeon_completed(dungeon_id, "normal", rewards_dict)

func _on_resource_changed(resource_id: String, _new_amount: int, delta: int) -> void:
	"""Log significant resource changes (filter noise + throttle)"""
	# Throttle to prevent spam
	var now: float = Time.get_unix_time_from_system()
	if now - _last_resource_log_time < RESOURCE_LOG_COOLDOWN:
		return

	# Only log significant changes to avoid spam
	if abs(delta) >= 100 or resource_id in ["divine_crystals", "legendary_soul", "epic_soul"]:
		_last_resource_log_time = now
		var source: String = "gained" if delta > 0 else "spent"
		analytics.log_resource_transaction(resource_id, delta, source)

func _on_territory_captured(territory: Variant) -> void:
	"""Log territory capture"""
	var territory_id: String = ""
	if territory is Dictionary:
		territory_id = territory.get("id", str(territory))
	elif "id" in territory:
		territory_id = territory.id
	else:
		territory_id = str(territory)

	analytics.log_territory_captured(territory_id, 0)

func _on_screen_changed(_old_screen: String, new_screen: String) -> void:
	"""Log screen navigation"""
	analytics.log_screen_view(new_screen)

func _on_error_occurred(error_message: String, context: Variant = null) -> void:
	"""Log errors"""
	var context_dict: Dictionary = {}
	if context is Dictionary:
		context_dict = context
	elif context:
		context_dict = {"context": str(context)}
	analytics.log_error("game_error", error_message, context_dict)

# ==============================================================================
# EXTENDED ANALYTICS HANDLERS
# ==============================================================================

func _on_summon_detailed(summon_data: Dictionary) -> void:
	"""Log detailed summon event"""
	analytics.log_summon_detailed(summon_data)

func _on_sacrifice(sacrifice_data: Dictionary) -> void:
	"""Log god sacrifice"""
	analytics.log_sacrifice(sacrifice_data)

func _on_awakening(awakening_data: Dictionary) -> void:
	"""Log god awakening"""
	analytics.log_awakening(awakening_data)

func _on_battle_team(team_data: Dictionary) -> void:
	"""Log battle team composition"""
	analytics.log_battle_team(team_data)

func _on_garrison(garrison_data: Dictionary) -> void:
	"""Log garrison assignment"""
	analytics.log_garrison(garrison_data)

func _on_workers(worker_data: Dictionary) -> void:
	"""Log worker assignment"""
	analytics.log_workers(worker_data)

func _on_achievement(achievement_id: String) -> void:
	"""Log achievement unlock"""
	analytics.log_achievement(achievement_id, {})

func _on_arena_battle(arena_data: Dictionary) -> void:
	"""Log arena battle result"""
	analytics.log_arena_battle(arena_data)

func _on_league_change(league_data: Dictionary) -> void:
	"""Log league promotion/demotion"""
	analytics.log_league_change(league_data)

func _on_specialization(god_id: String, spec_id: String) -> void:
	"""Log specialization unlock"""
	analytics.log_specialization({"god_id": god_id, "spec_id": spec_id})

func _on_equipment_equipped(god: Variant, equipment: Variant, slot: int) -> void:
	"""Log equipment equip"""
	if not god or not equipment:
		return
	analytics.log_equipment_change({
		"action": "equip",
		"god_id": god.id if "id" in god else str(god),
		"slot": slot,
		"equipment_id": equipment.id if "id" in equipment else str(equipment)
	})

func _on_equipment_unequipped(god: Variant, equipment: Variant, slot: int) -> void:
	"""Log equipment unequip"""
	if not god:
		return
	analytics.log_equipment_change({
		"action": "unequip",
		"god_id": god.id if "id" in god else str(god),
		"slot": slot,
		"equipment_id": equipment.id if equipment and "id" in equipment else ""
	})

# ==============================================================================
# SHUTDOWN
# ==============================================================================

func shutdown() -> void:
	"""Called by SystemRegistry on shutdown"""
	if analytics:
		await analytics.flush_queue()
