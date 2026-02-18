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

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	name = "SteamManager"

func initialize() -> void:
	"""Called by SystemRegistry after all systems registered."""
	if _is_initialized:
		return
	_is_initialized = true

	_init_steam()
	_connect_to_achievement_events()

func _init_steam() -> void:
	"""Initialize Steam SDK"""
	if not Engine.has_singleton("Steam"):
		print("SteamManager: Steam singleton not found - running without Steam")
		return

	_steam = Engine.get_singleton("Steam")

	# Initialize Steam
	var init_result: Dictionary = _steam.steamInitEx(true, STEAM_APP_ID)

	# Check status: 0 = OK, 1 = failed, 2 = no client
	var status: int = init_result.get("status", 1)
	var verbal: String = init_result.get("verbal", "Unknown error")

	if status == 0:
		_steam_running = true
		var steam_id: int = _steam.getSteamID()
		var persona_name: String = _steam.getPersonaName()
		print("SteamManager: Steam initialized successfully!")
		print("SteamManager: Logged in as: %s (ID: %d)" % [persona_name, steam_id])

		# Connect to stats received callback
		_steam.current_stats_received.connect(_on_stats_received)

		# Request current stats from Steam (required before setting achievements)
		_steam.requestCurrentStats()
		print("SteamManager: Requesting stats from Steam...")
	else:
		_steam_running = false
		print("SteamManager: Steam init failed - %s" % verbal)

func _connect_to_achievement_events() -> void:
	"""Connect to AchievementManager to sync Steam achievements"""
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return

	var achievement_manager: Node = registry.get_system("AchievementManager")
	if achievement_manager:
		achievement_manager.achievement_completed.connect(_on_achievement_completed)
		print("SteamManager: Connected to AchievementManager")

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
		print("SteamManager: Stats received successfully for game %d" % game_id)
	else:
		print("SteamManager: Failed to receive stats (result: %d)" % result)

# ==============================================================================
# ACHIEVEMENTS
# ==============================================================================

func _on_achievement_completed(achievement_id: String, _achievement_data: Dictionary) -> void:
	"""When in-game achievement completes, unlock on Steam too"""
	unlock_achievement(achievement_id)

func unlock_achievement(achievement_id: String) -> bool:
	"""Unlock a Steam achievement by API name"""
	if not _steam_running or not _steam:
		print("SteamManager: Steam not running, skipping achievement: %s" % achievement_id)
		return false

	if not _stats_received:
		print("SteamManager: Stats not received yet, cannot unlock: %s" % achievement_id)
		return false

	print("SteamManager: Attempting to unlock Steam achievement: %s" % achievement_id)

	# Set the achievement
	var success: bool = _steam.setAchievement(achievement_id)

	if success:
		# Store stats to Steam servers
		var store_success: bool = _steam.storeStats()
		print("SteamManager: Unlocked Steam achievement: %s (storeStats: %s)" % [achievement_id, store_success])
	else:
		# Check if it's already unlocked
		var status: Dictionary = _steam.getAchievement(achievement_id)
		print("SteamManager: Failed to unlock '%s' - current status: %s" % [achievement_id, status])

	return success

func clear_achievement(achievement_id: String) -> bool:
	"""Clear a Steam achievement (for testing only)"""
	if not _steam_running or not _steam:
		return false

	var success: bool = _steam.clearAchievement(achievement_id)
	if success:
		_steam.storeStats()
		print("SteamManager: Cleared achievement: %s" % achievement_id)
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
	print("SteamManager: Reset all stats and achievements")

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
