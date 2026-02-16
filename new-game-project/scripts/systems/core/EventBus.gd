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
signal battle_team_entered(team_data: Dictionary)  # {battle_type, god_ids, team_power, enemy_power}

# ============================================================================
# PROGRESSION EVENTS
# ============================================================================
signal god_obtained(god)
signal god_level_up(god, new_level, old_level)
signal god_awakened(god)
signal skill_upgraded(god, skill_index, new_level)
signal experience_gained(god, amount)
signal god_sacrifice_completed(sacrifice_data: Dictionary)  # {target_god_id, target_tier, material_count, total_xp, levels_gained}
signal god_awakening_completed(awakening_data: Dictionary)  # {god_id, god_name, element, old_tier, new_tier}
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
signal summon_completed_detailed(summon_data: Dictionary)  # {banner_id, summon_type, cost_type, powder_element, pity_counters, gods_obtained}
signal god_sacrificed(sacrificed_god, target_god)
signal collection_updated(collection_type)

# ============================================================================
# TERRITORY EVENTS
# ============================================================================
signal territory_captured(territory, capturing_guild)
signal garrison_updated(garrison_data: Dictionary)  # {node_id, node_tier, god_ids, total_power}
signal workers_updated(worker_data: Dictionary)  # {node_id, node_tier, god_ids, task_ids}

# ============================================================================
# SPECIALIZATION EVENTS
# ============================================================================
signal specialization_unlocked(god_id: String, spec_id: String)

# ============================================================================
# ACHIEVEMENT EVENTS
# ============================================================================
signal achievement_unlocked(achievement_id: String)

# ============================================================================
# ARENA/PVP EVENTS
# ============================================================================
signal arena_battle_completed(arena_data: Dictionary)  # {victory, old_elo, new_elo, elo_change, opponent_elo, league}
signal league_changed(league_data: Dictionary)  # {old_league, new_league, elo, direction}

# ============================================================================
# UI EVENTS
# ============================================================================
signal screen_changed(old_screen: String, new_screen: String)
signal notification_requested(message: String, type: String, duration: float)
signal show_tutorial_requested(tutorial_data: Dictionary)
signal loading_started(operation: String)
signal loading_completed(operation: String)

# ============================================================================
# DUNGEON EVENTS
# ============================================================================
signal dungeon_entered(dungeon_id: String)
signal dungeon_completed(dungeon_id: String, rewards: Array)
signal dungeon_failed(dungeon_id: String)
signal loot_obtained(loot: Array, source: String)

# ============================================================================
# SYSTEM EVENTS
# ============================================================================
signal game_saved()
signal game_loaded()
signal save_requested()  # Request to save game state
signal error_occurred(error_message: String, context: String)

# ============================================================================
# CONVENIENCE METHODS FOR COMMON EVENTS
# ============================================================================

## Emit notification request
func emit_notification(message: String, type: String = "info", duration: float = 3.0) -> void:
	notification_requested.emit(message, type, duration)
