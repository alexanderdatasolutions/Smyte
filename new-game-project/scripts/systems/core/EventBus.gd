# scripts/systems/core/EventBus.gd
# Global event bus for decoupled communication between systems
extends Node

# ============================================================================
# COMBAT EVENTS
# ============================================================================
signal damage_dealt(attacker, target, damage)
signal unit_defeated(unit)
signal battle_started(config)
signal battle_ended(result)
signal skill_used(caster, skill, targets)
signal status_effect_applied(target, effect)
signal status_effect_removed(target, effect_id)
signal turn_started(unit)
signal turn_ended(unit)
signal wave_started(wave_number)
signal wave_completed(wave_number)

# ============================================================================
# PROGRESSION EVENTS
# ============================================================================
signal god_obtained(god)
signal god_level_up(god, new_level, old_level)
signal god_awakened(god)
signal skill_upgraded(god, skill_index, new_level)
signal experience_gained(god, amount)
signal equipment_obtained(equipment)
signal equipment_equipped(god, equipment, slot)
signal equipment_unequipped(god, equipment, slot)

# ============================================================================
# RESOURCE EVENTS
# ============================================================================
signal resource_gained(resource_id, amount, source)
signal resource_spent(resource_id, amount, purpose)
signal resource_changed(resource_id, new_amount, delta)
signal insufficient_resources(resource_id, required, available)

# ============================================================================
# COLLECTION EVENTS
# ============================================================================
signal summon_performed(banner_id, results)
signal god_sacrificed(sacrificed_god, target_god)
signal collection_updated(collection_type)

# ============================================================================
# TERRITORY EVENTS
# ============================================================================
signal territory_captured(territory, capturing_guild)
signal territory_attacked(territory: Dictionary, attacker: String)
signal territory_defended(territory: Dictionary, defender: String)
signal role_assigned(god, territory: Dictionary, role: String)  # god: God - untyped for autoload compatibility
signal role_unassigned(god, territory: Dictionary, role: String)  # god: God - untyped for autoload compatibility

# ============================================================================
# QUEST & ACHIEVEMENT EVENTS
# ============================================================================
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_progress_updated(quest_id: String, progress: int, target: int)
signal achievement_unlocked(achievement_id: String)

# ============================================================================
# UI EVENTS
# ============================================================================
signal screen_changed(old_screen: String, new_screen: String)
signal notification_requested(message: String, type: String, duration: float)
signal popup_requested(popup_type: String, data: Dictionary)
signal tutorial_step_completed(step_id: String)
signal loading_started(operation: String)
signal loading_completed(operation: String)

# ============================================================================
# DUNGEON EVENTS
# ============================================================================
signal dungeon_entered(dungeon_id: String)
signal dungeon_completed(dungeon_id: String, rewards: Array)
signal dungeon_failed(dungeon_id: String)
signal boss_encountered(boss_id: String)
signal loot_obtained(loot: Array, source: String)

# ============================================================================
# SOCIAL EVENTS
# ============================================================================
signal guild_joined(guild_id: String)
signal guild_left(guild_id: String)
signal friend_added(friend_id: String)
signal friend_removed(friend_id: String)
signal message_received(sender: String, message: String)

# ============================================================================
# SYSTEM EVENTS
# ============================================================================
signal game_paused()
signal game_resumed()
signal game_saved()
signal game_loaded()
signal save_requested()  # Request to save game state
signal settings_changed(setting_key: String, new_value: Variant)
signal error_occurred(error_message: String, context: String)

# ============================================================================
# EVENT BUS MANAGEMENT
# ============================================================================

var _event_history: Array = []  # Array[Dictionary]
var _max_history_size: int = 100
var _debug_mode: bool = false

## Enable/disable debug logging for events
func set_debug_mode(enabled: bool):
	_debug_mode = enabled

## Log an event to history (for debugging)
func _log_event(event_name: String, data: Dictionary = {}):
	if not _debug_mode:
		return
	
	var log_entry = {
		"event": event_name,
		"timestamp": Time.get_ticks_msec(),
		"data": data
	}
	
	_event_history.append(log_entry)
	
	# Keep history size manageable
	while _event_history.size() > _max_history_size:
		_event_history.pop_front()

## Get recent event history for debugging
func get_event_history(count: int = 10) -> Array:
	var recent_events = []
	var start_index = max(0, _event_history.size() - count)
	
	for i in range(start_index, _event_history.size()):
		recent_events.append(_event_history[i])
	
	return recent_events

## Clear event history
func clear_history():
	_event_history.clear()

# ============================================================================
# CONVENIENCE METHODS FOR COMMON EVENTS
# ============================================================================

## Emit a resource change event with proper logging
func emit_resource_change(resource_id: String, new_amount: int, delta: int):
	_log_event("resource_changed", {
		"resource": resource_id,
		"new_amount": new_amount,
		"delta": delta
	})
	resource_changed.emit(resource_id, new_amount, delta)

## Emit a god level up event with proper logging
func emit_god_level_up(god, new_level: int, old_level: int):  # god: God - untyped for autoload compatibility
	_log_event("god_level_up", {
		"god_id": god.id,
		"new_level": new_level,
		"old_level": old_level
	})
	god_level_up.emit(god, new_level, old_level)

## Emit battle result with comprehensive data
func emit_battle_ended(result):  # result: BattleResult - untyped for autoload compatibility
	_log_event("battle_ended", {
		"victory": result.victory,
		"battle_type": result.battle_type,
		"duration": result.duration,
		"rewards": result.rewards
	})
	battle_ended.emit(result)

## Emit notification request
func emit_notification(message: String, type: String = "info", duration: float = 3.0):
	_log_event("notification_requested", {
		"message": message,
		"type": type,
		"duration": duration
	})
	notification_requested.emit(message, type, duration)
