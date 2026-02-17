# scripts/systems/core/DebugLogger.gd
# Centralized debug logging for tracking player issues
class_name DebugLogger extends Node

# In-memory log buffer (circular buffer)
const MAX_LOG_ENTRIES: int = 500
var _log_entries: Array[Dictionary] = []
var _log_index: int = 0

# Firebase reference for remote logging
var _analytics: Node = null

# Log levels
enum Level {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

const LEVEL_NAMES: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR", "CRIT"]

func _ready() -> void:
	name = "DebugLogger"

func initialize() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if registry:
		_analytics = registry.get_system("FirebaseAnalytics")

# ==============================================================================
# LOGGING METHODS
# ==============================================================================

func log_debug(category: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.DEBUG, category, message, data)

func log_info(category: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.INFO, category, message, data)

func log_warning(category: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.WARNING, category, message, data)
	push_warning("[%s] %s" % [category, message])

func log_error(category: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.ERROR, category, message, data)
	push_error("[%s] %s" % [category, message])

func log_critical(category: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.CRITICAL, category, message, data)
	push_error("[CRITICAL][%s] %s" % [category, message])
	# For critical errors, also send to analytics immediately
	_send_to_analytics(Level.CRITICAL, category, message, data)

func _log(level: Level, category: String, message: String, data: Dictionary) -> void:
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"time_str": Time.get_datetime_string_from_system(),
		"level": level,
		"level_name": LEVEL_NAMES[level],
		"category": category,
		"message": message,
		"data": data
	}

	# Add to circular buffer
	if _log_entries.size() < MAX_LOG_ENTRIES:
		_log_entries.append(entry)
	else:
		_log_entries[_log_index] = entry
		_log_index = (_log_index + 1) % MAX_LOG_ENTRIES

	# Print to console in debug builds
	if OS.is_debug_build():
		print("[%s][%s] %s: %s" % [entry.time_str, LEVEL_NAMES[level], category, message])
		if not data.is_empty():
			print("  Data: %s" % str(data))

# ==============================================================================
# BATTLE-SPECIFIC LOGGING
# ==============================================================================

func log_battle_start(battle_type: String, team_size: int, enemy_count: int, waves: int) -> void:
	log_info("Battle", "Battle started", {
		"battle_type": battle_type,
		"team_size": team_size,
		"enemy_count": enemy_count,
		"waves": waves
	})

func log_battle_end(victory: bool, duration: float, reason: String) -> void:
	log_info("Battle", "Battle ended", {
		"victory": victory,
		"duration_sec": duration,
		"reason": reason
	})

func log_battle_stuck(current_state: Dictionary) -> void:
	log_error("Battle", "Battle appears stuck", current_state)

func log_wave_transition(from_wave: int, to_wave: int, max_waves: int) -> void:
	log_info("Battle", "Wave transition", {
		"from": from_wave,
		"to": to_wave,
		"max": max_waves
	})

# ==============================================================================
# TUTORIAL LOGGING
# ==============================================================================

func log_tutorial_event(event: String, tutorial_name: String, step: int = -1, extra: Dictionary = {}) -> void:
	var data: Dictionary = {
		"tutorial": tutorial_name,
		"event": event
	}
	if step >= 0:
		data["step"] = step
	data.merge(extra)
	log_info("Tutorial", event, data)

# ==============================================================================
# SCREEN NAVIGATION LOGGING
# ==============================================================================

func log_screen_change(from_screen: String, to_screen: String) -> void:
	log_debug("Navigation", "Screen change", {
		"from": from_screen,
		"to": to_screen
	})

# ==============================================================================
# ERROR RECOVERY LOGGING
# ==============================================================================

func log_recovery_action(system: String, action: String, success: bool, details: Dictionary = {}) -> void:
	var data: Dictionary = {"action": action, "success": success}
	data.merge(details)
	if success:
		log_info(system, "Recovery action succeeded", data)
	else:
		log_warning(system, "Recovery action failed", data)

# ==============================================================================
# LOG RETRIEVAL
# ==============================================================================

func get_recent_logs(count: int = 50, min_level: Level = Level.DEBUG) -> Array[Dictionary]:
	"""Get the most recent log entries, filtered by level."""
	var result: Array[Dictionary] = []

	# Get entries in chronological order
	var entries: Array[Dictionary] = []
	if _log_entries.size() < MAX_LOG_ENTRIES:
		entries = _log_entries.duplicate()
	else:
		# Circular buffer - need to reconstruct order
		for i in range(MAX_LOG_ENTRIES):
			var idx: int = (_log_index + i) % MAX_LOG_ENTRIES
			entries.append(_log_entries[idx])

	# Filter and limit
	for entry in entries:
		if entry.level >= min_level:
			result.append(entry)

	# Return last N entries
	if result.size() > count:
		return result.slice(result.size() - count)
	return result

func get_logs_as_text(count: int = 50, min_level: Level = Level.DEBUG) -> String:
	"""Get recent logs formatted as text for display or export."""
	var logs: Array[Dictionary] = get_recent_logs(count, min_level)
	var lines: PackedStringArray = []

	for entry in logs:
		var line: String = "[%s][%s] %s: %s" % [
			entry.time_str,
			entry.level_name,
			entry.category,
			entry.message
		]
		lines.append(line)
		if not entry.data.is_empty():
			lines.append("  → %s" % str(entry.data))

	return "\n".join(lines)

func clear_logs() -> void:
	"""Clear all log entries."""
	_log_entries.clear()
	_log_index = 0

# ==============================================================================
# ANALYTICS INTEGRATION
# ==============================================================================

func _send_to_analytics(level: Level, category: String, message: String, data: Dictionary) -> void:
	"""Send critical errors to Firebase Analytics for remote debugging."""
	if not _analytics:
		return

	if _analytics.has_method("log_event"):
		_analytics.log_event("debug_log", {
			"level": LEVEL_NAMES[level],
			"category": category,
			"message": message.substr(0, 100),  # Truncate for analytics
			"has_data": not data.is_empty()
		})

# ==============================================================================
# SAVE STATE FOR DEBUGGING
# ==============================================================================

func get_debug_state() -> Dictionary:
	"""Get current game state for debugging purposes."""
	var state: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"recent_logs": get_recent_logs(20, Level.WARNING)
	}

	# Try to get battle state if active
	var registry: Node = SystemRegistry.get_instance()
	if registry:
		var battle_coord: Node = registry.get_system("BattleCoordinator")
		if battle_coord and battle_coord.is_in_battle():
			state["battle_active"] = true
			if battle_coord.battle_state:
				state["battle_stats"] = battle_coord.battle_state.get_battle_statistics()

		var screen_manager: Node = registry.get_system("ScreenManager")
		if screen_manager and screen_manager.has_method("get_current_screen_name"):
			state["current_screen"] = screen_manager.get_current_screen_name()

	return state
