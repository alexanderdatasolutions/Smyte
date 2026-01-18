# scripts/systems/NotificationManager.gd
# RULE 1 COMPLIANCE: Under 500 lines (currently 102)
# RULE 4 COMPLIANCE: System layer - business logic only, no UI creation
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name NotificationManager

"""
Simple notification system for progression-related events
Shows level ups, feature unlocks, and other important progression milestones
"""

signal notification_shown(type: String, message: String)
signal notification_cleared()

var active_notifications: Array = []

func _ready():
	"""Initialize notification manager"""
	# Connect to progression events through SystemRegistry - RULE 5 COMPLIANCE
	_connect_to_progression_events()

func _connect_to_progression_events():
	"""Connect to progression manager signals"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var prog_mgr = system_registry.get_system("PlayerProgressionManager")
	if not prog_mgr:
		return
	
	if prog_mgr.has_signal("player_leveled_up"):
		prog_mgr.player_leveled_up.connect(_on_player_level_up)
		
	if prog_mgr.has_signal("feature_unlocked"):
		prog_mgr.feature_unlocked.connect(_on_feature_unlocked)

func _on_player_level_up(new_level: int):
	"""Handle player level up notification"""
	var message = "🎉 Level Up! You are now level %d!" % new_level
	show_notification("level_up", message, 3.0)

func _on_feature_unlocked(feature_name: String):
	"""Handle feature unlock notification"""
	var display_name = get_feature_display_name(feature_name)
	var message = "✨ New Feature Unlocked: %s!" % display_name
	show_notification("feature_unlock", message, 5.0)

func get_feature_display_name(feature_name: String) -> String:
	"""Convert internal feature names to user-friendly display names"""
	match feature_name:
		"summon":
			return "God Summoning"
		"sacrifice":
			return "God Sacrifice"
		"territory_management":
			return "Territory Management"
		"equipment":
			return "Equipment System"
		"awakening":
			return "God Awakening"
		"dungeons":
			return "Dungeon Exploration"
		_:
			return feature_name.replace("_", " ").capitalize()

func show_notification(type: String, message: String, duration: float = 3.0):
	"""Show a notification with automatic dismissal"""
	var notif_data = {
		"type": type,
		"message": message,
		"timestamp": Time.get_unix_time_from_system(),
		"duration": duration
	}

	active_notifications.append(notif_data)
	notification_shown.emit(type, message)

	# Auto-dismiss after duration
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		clear_notification(notif_data)

func show_error(message: String, duration: float = 2.5):
	"""Show an error notification - quick method for errors"""
	show_notification("error", message, duration)

func clear_notification(notif_data: Dictionary):
	"""Clear a specific notification"""
	if notif_data in active_notifications:
		active_notifications.erase(notif_data)
		notification_cleared.emit()

func clear_all_notifications():
	"""Clear all active notifications"""
	active_notifications.clear()
	notification_cleared.emit()

func get_active_notifications() -> Array:
	"""Get all currently active notifications"""
	return active_notifications.duplicate()

# Quick test method
func test_notifications():
	"""Test the notification system"""
	show_notification("test", "This is a test notification!", 2.0)
	await get_tree().create_timer(1.0).timeout
	show_notification("level_up", "🎉 Level Up! You are now level 5!", 3.0)
	await get_tree().create_timer(1.0).timeout
	show_notification("feature_unlock", "✨ New Feature Unlocked: God Summoning!", 4.0)
