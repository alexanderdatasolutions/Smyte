# scripts/systems/core/SteamManager.gd
# Manages Steam integration: initialization, achievements, stats
extends Node
class_name SteamManager

"""
SteamManager - Steam SDK Integration via GodotSteam
RULE 2: Single responsibility - Steam API only
RULE 5: SystemRegistry integration

Handles:
- Steam initialization on startup
- Achievement unlocking (synced with in-game achievements)
- Steam stats tracking
- Steam overlay detection
"""

# ==============================================================================
# CONSTANTS
# ==============================================================================
const STEAM_APP_ID: int = 4440530

# ==============================================================================
# STATE
# ==============================================================================
var _steam_running: bool = false
var _is_initialized: bool = false
var _steam: Object = null  # Reference to Steam singleton
var _stats_received: bool = false  # True after Steam stats are loaded

# Debug log for troubleshooting (since console may not be visible)
var _debug_log: Array[String] = []
const MAX_DEBUG_LOG: int = 50
var _log_file_path: String = "user://steam_debug.log"

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	name = "SteamManager"
	# Initialize Steam after a short delay to let overlay inject
	_delayed_init()

func _delayed_init() -> void:
	# Wait 2 frames for Steam overlay to fully inject
	await get_tree().process_frame
	await get_tree().process_frame
	_init_steam()

# ==============================================================================
# DEBUG LOGGING
# ==============================================================================

func _log(message: String) -> void:
	"""Log message to console, debug array, and file"""
	var timestamp: String = Time.get_datetime_string_from_system()
	var full_msg: String = "[%s] %s" % [timestamp, message]
	print(full_msg)

	_debug_log.append(full_msg)
	if _debug_log.size() > MAX_DEBUG_LOG:
		_debug_log.remove_at(0)

	# Write to file
	var file := FileAccess.open(_log_file_path, FileAccess.WRITE)
	if file:
		for log_line: String in _debug_log:
			file.store_line(log_line)
		file.close()

func get_debug_status() -> String:
	"""Get current Steam status for in-game display"""
	var lines: Array[String] = []
	lines.append("=== STEAM DEBUG STATUS ===")
	lines.append("Steam singleton exists: %s" % Engine.has_singleton("Steam"))
	lines.append("Steam running: %s" % _steam_running)
	lines.append("Stats received: %s" % _stats_received)
	lines.append("Initialized: %s" % _is_initialized)

	if _steam_running and _steam:
		lines.append("Steam ID: %d" % _steam.getSteamID())
		lines.append("Persona: %s" % _steam.getPersonaName())

	lines.append("")
	lines.append("=== RECENT LOG ===")
	var start_idx: int = maxi(0, _debug_log.size() - 10)
	for i in range(start_idx, _debug_log.size()):
		lines.append(_debug_log[i])

	return "\n".join(lines)

func get_debug_log() -> Array[String]:
	"""Get full debug log"""
	return _debug_log

func initialize() -> void:
	"""Called by SystemRegistry after all systems registered."""
	if _is_initialized:
		return
	_is_initialized = true

	# Steam is already initialized in _ready(), just connect to events
	_connect_to_achievement_events()

func _init_steam() -> void:
	"""Initialize Steam SDK"""
	_log("_init_steam() called")

	if not Engine.has_singleton("Steam"):
		_log("Steam singleton not found - running without Steam")
		return

	_steam = Engine.get_singleton("Steam")
	_log("Steam singleton obtained")

	# Use steamInitEx with no app ID - let Steam detect it
	_log("Calling steamInitEx()...")
	var init_result: Dictionary = _steam.steamInitEx()
	_log("steamInitEx result: %s" % str(init_result))

	# Check status: 0 = OK, 1 = failed, 2 = no client
	var status: int = init_result.get("status", 1)
	var verbal: String = init_result.get("verbal", "Unknown error")

	if status == 0:
		_steam_running = true
		var steam_id: int = _steam.getSteamID()
		var persona_name: String = _steam.getPersonaName()
		_log("Steam initialized successfully!")
		_log("Logged in as: %s (ID: %d)" % [persona_name, steam_id])

		# Connect to stats received callback (signal name varies by GodotSteam version)
		if _steam.has_signal("current_stats_received"):
			_steam.current_stats_received.connect(_on_stats_received)
			_log("Connected to current_stats_received signal")
		else:
			_log("current_stats_received signal not found - stats will work without callback")
			_stats_received = true  # Assume stats are ready

		# Request current stats from Steam (required before setting achievements)
		# Method name varies by GodotSteam version
		if _steam.has_method("requestCurrentStats"):
			_steam.requestCurrentStats()
			_log("requestCurrentStats() called")
		elif _steam.has_method("requestUserStats"):
			_steam.requestUserStats(_steam.getSteamID())
			_log("requestUserStats() called")
		else:
			_log("No stats request method found - assuming stats ready")
			_stats_received = true

		# Set a fallback timeout - if callback doesn't fire in 2 seconds, proceed anyway
		_start_stats_timeout()
	else:
		_steam_running = false
		_log("Steam init failed - %s" % verbal)

func _start_stats_timeout() -> void:
	"""Fallback if stats callback doesn't fire"""
	await get_tree().create_timer(2.0).timeout
	if not _stats_received:
		_log("Stats timeout - proceeding without callback")
		_stats_received = true

func _connect_to_achievement_events() -> void:
	"""Connect to AchievementManager to sync Steam achievements"""
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		_log("SystemRegistry not found!")
		return

	var achievement_manager: Node = registry.get_system("AchievementManager")
	if achievement_manager:
		achievement_manager.achievement_completed.connect(_on_achievement_completed)
		_log("Connected to AchievementManager")
	else:
		_log("AchievementManager not found!")

# ==============================================================================
# STEAM CALLBACKS
# ==============================================================================

func _process(_delta: float) -> void:
	"""Run Steam callbacks"""
	if _steam_running and _steam:
		_steam.run_callbacks()

func _on_stats_received(game_id: int, result: int) -> void:
	"""Called when Steam stats are received - must happen before setting achievements"""
	if result == 1:  # k_EResultOK
		_stats_received = true
		_log("Stats received successfully for game %d" % game_id)
	else:
		_log("Failed to receive stats (result: %d)" % result)

# ==============================================================================
# ACHIEVEMENTS
# ==============================================================================

func _on_achievement_completed(achievement_id: String, _achievement_data: Dictionary) -> void:
	"""When in-game achievement completes, unlock on Steam too"""
	_log("Received achievement_completed signal for: %s" % achievement_id)
	unlock_achievement(achievement_id)

func unlock_achievement(achievement_id: String) -> bool:
	"""Unlock a Steam achievement by API name"""
	_log("unlock_achievement called with: %s" % achievement_id)

	if not _steam_running or not _steam:
		_log("Steam not running, skipping achievement: %s" % achievement_id)
		return false

	if not _stats_received:
		_log("Stats not received yet, trying anyway: %s" % achievement_id)
		# Try anyway - some games don't have stats configured

	_log("Attempting to unlock Steam achievement: %s" % achievement_id)

	# Set the achievement
	var success: bool = _steam.setAchievement(achievement_id)
	_log("setAchievement returned: %s" % success)

	if success:
		# Store stats to Steam servers
		var store_success: bool = _steam.storeStats()
		_log("Unlocked Steam achievement: %s (storeStats: %s)" % [achievement_id, store_success])
	else:
		# Check if it's already unlocked
		var status: Dictionary = _steam.getAchievement(achievement_id)
		_log("Failed to unlock '%s' - current status: %s" % [achievement_id, status])

	return success

func clear_achievement(achievement_id: String) -> bool:
	"""Clear a Steam achievement (for testing only)"""
	if not _steam_running or not _steam:
		return false

	var success: bool = _steam.clearAchievement(achievement_id)
	if success:
		_steam.storeStats()
		_log("Cleared achievement: %s" % achievement_id)
	return success

func get_achievement_status(achievement_id: String) -> Dictionary:
	"""Get achievement unlock status from Steam"""
	if not _steam_running or not _steam:
		return {"unlocked": false, "error": "Steam not running"}

	var achieved: Dictionary = _steam.getAchievement(achievement_id)
	return achieved

func reset_all_achievements() -> void:
	"""Reset all Steam achievements (for testing only)"""
	if not _steam_running or not _steam:
		return

	_steam.resetAllStats(true)  # true = also reset achievements
	_log("Reset all stats and achievements")

# ==============================================================================
# STATS
# ==============================================================================

func set_stat_int(stat_name: String, value: int) -> void:
	"""Set an integer stat on Steam"""
	if not _steam_running or not _steam:
		return
	_steam.setStatInt(stat_name, value)

func set_stat_float(stat_name: String, value: float) -> void:
	"""Set a float stat on Steam"""
	if not _steam_running or not _steam:
		return
	_steam.setStatFloat(stat_name, value)

func store_stats() -> void:
	"""Push stat changes to Steam servers"""
	if not _steam_running or not _steam:
		return
	_steam.storeStats()

# ==============================================================================
# UTILITY
# ==============================================================================

func is_steam_running() -> bool:
	"""Check if Steam is initialized and running"""
	return _steam_running

func get_steam_id() -> int:
	"""Get the current user's Steam ID"""
	if not _steam_running or not _steam:
		return 0
	return _steam.getSteamID()

func get_persona_name() -> String:
	"""Get the current user's Steam display name"""
	if not _steam_running or not _steam:
		return ""
	return _steam.getPersonaName()
