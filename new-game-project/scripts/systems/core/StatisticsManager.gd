# scripts/systems/StatisticsManager.gd
extends Node
class_name StatisticsManager

signal achievement_unlocked(achievement_id: String)

# Battle Statistics
var battle_stats: Dictionary = {
	"battles_won": 0,
	"battles_lost": 0,
	"total_battles": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"total_healing_done": 0,
	"perfect_victories": 0,  # No god deaths
	"dungeon_clears": {},    # dungeon_id -> clear_count
	"territory_conquests": 0,
	"longest_win_streak": 0,
	"current_win_streak": 0
}

# God Performance Statistics  
var god_performance: Dictionary = {}  # god_id -> performance_data

# Resource Statistics
var resource_stats: Dictionary = {
	"total_mana_earned": 0,
	"total_essence_earned": 0,
	"total_crystals_spent": 0,
	"total_summons_performed": 0,
	"legendary_summons": 0,
	"epic_summons": 0
}

# Time-based Statistics
var time_stats: Dictionary = {
	"total_playtime": 0.0,
	"session_start_time": 0.0,
	"first_play_date": 0.0,
	"last_play_date": 0.0
}

func _ready():
	time_stats.session_start_time = Time.get_unix_time_from_system()
	if time_stats.first_play_date == 0.0:
		time_stats.first_play_date = Time.get_unix_time_from_system()

func _exit_tree():
	"""Update playtime when exiting"""
	_update_session_playtime()

# BATTLE STATISTICS

func record_battle_start(battle_type: String, enemy_count: int = 0):
	"""Record battle start for statistics"""
	battle_stats.total_battles += 1
	
	# Initialize battle tracking if needed
	if not has_meta("current_battle"):
		set_meta("current_battle", {
			"type": battle_type,
			"start_time": Time.get_unix_time_from_system(),
			"enemy_count": enemy_count,
			"gods_used": [],
			"damage_dealt": 0,
			"damage_taken": 0,
			"healing_done": 0
		})

func record_battle_end(victory: bool, gods_used: Array = []):
	"""Record battle completion"""
	if victory:
		battle_stats.battles_won += 1
		battle_stats.current_win_streak += 1
		battle_stats.longest_win_streak = max(battle_stats.longest_win_streak, battle_stats.current_win_streak)
		
		# Check for perfect victory (no god deaths)
		var perfect_victory = true
		for god in gods_used:
			if god is God and god.current_hp <= 0:
				perfect_victory = false
				break
		
		if perfect_victory and gods_used.size() > 0:
			battle_stats.perfect_victories += 1
	else:
		battle_stats.battles_lost += 1
		battle_stats.current_win_streak = 0
	
	# Update god performance stats
	for god in gods_used:
		if god is God:
			_update_god_performance(god, victory)
	
	# Clear battle tracking
	remove_meta("current_battle")

func record_dungeon_clear(dungeon_id: String):
	"""Record dungeon completion"""
	if not battle_stats.dungeon_clears.has(dungeon_id):
		battle_stats.dungeon_clears[dungeon_id] = 0
	battle_stats.dungeon_clears[dungeon_id] += 1

func record_territory_conquest():
	"""Record territory capture"""
	battle_stats.territory_conquests += 1

func record_damage_dealt(amount: int, god_id: String = ""):
	"""Record damage statistics"""
	battle_stats.total_damage_dealt += amount
	
	if god_id != "" and god_performance.has(god_id):
		god_performance[god_id]["damage_dealt"] += amount

func record_damage_taken(amount: int, god_id: String = ""):
	"""Record damage taken statistics"""  
	battle_stats.total_damage_taken += amount
	
	if god_id != "" and god_performance.has(god_id):
		god_performance[god_id]["damage_taken"] += amount

func record_healing_done(amount: int, god_id: String = ""):
	"""Record healing statistics"""
	battle_stats.total_healing_done += amount
	
	if god_id != "" and god_performance.has(god_id):
		god_performance[god_id]["healing_done"] += amount

# GOD PERFORMANCE TRACKING

func _update_god_performance(god: God, victory: bool):
	"""Update individual god performance statistics"""
	if not god_performance.has(god.id):
		god_performance[god.id] = {
			"battles_participated": 0,
			"victories": 0,
			"defeats": 0,
			"damage_dealt": 0,
			"damage_taken": 0,
			"healing_done": 0,
			"abilities_used": {},
			"mvp_count": 0
		}
	
	var stats = god_performance[god.id]
	stats.battles_participated += 1
	
	if victory:
		stats.victories += 1
	else:
		stats.defeats += 1

func record_ability_use(god_id: String, ability_name: String):
	"""Track ability usage for gods"""
	if not god_performance.has(god_id):
		return
	
	var stats = god_performance[god_id]
	if not stats.abilities_used.has(ability_name):
		stats.abilities_used[ability_name] = 0
	stats.abilities_used[ability_name] += 1

func get_god_win_rate(god_id: String) -> float:
	"""Calculate win rate for specific god"""
	if not god_performance.has(god_id):
		return 0.0
	
	var stats = god_performance[god_id]
	var total = stats.battles_participated
	if total == 0:
		return 0.0
	
	return float(stats.victories) / float(total) * 100.0

# RESOURCE STATISTICS

func record_resource_earned(resource_id: String, amount: int):
	"""Record resource acquisition"""
	match resource_id:
		"mana":
			resource_stats.total_mana_earned += amount
		"divine_essence":
			resource_stats.total_essence_earned += amount

func record_crystal_spending(amount: int):
	"""Record crystal spending"""
	resource_stats.total_crystals_spent += amount

func record_summon(god: God):
	"""Record summon statistics"""
	resource_stats.total_summons_performed += 1
	
	match god.tier:
		God.TierType.LEGENDARY:
			resource_stats.legendary_summons += 1
		God.TierType.EPIC:
			resource_stats.epic_summons += 1

# ACHIEVEMENTS & MILESTONES

func check_achievements():
	"""Check for achievement unlocks"""
	_check_battle_achievements()
	_check_collection_achievements()
	_check_progression_achievements()

func _check_battle_achievements():
	"""Check battle-related achievements"""
	# Win streak achievements
	if battle_stats.current_win_streak == 10:
		_unlock_achievement("win_streak_10")
	elif battle_stats.current_win_streak == 25:
		_unlock_achievement("win_streak_25")
	
	# Total victory achievements
	if battle_stats.battles_won == 100:
		_unlock_achievement("hundred_victories")
	elif battle_stats.battles_won == 1000:
		_unlock_achievement("thousand_victories")
	
	# Perfect victory achievements
	if battle_stats.perfect_victories == 50:
		_unlock_achievement("perfect_warrior")

func _check_collection_achievements():
	"""Check god collection achievements"""
	if GameManager and GameManager.player_data:
		var god_count = GameManager.player_data.gods.size()
		if god_count >= 50:
			_unlock_achievement("collector")
		elif god_count >= 100:
			_unlock_achievement("master_collector")

func _check_progression_achievements():
	"""Check progression achievements"""
	if battle_stats.territory_conquests >= 10:
		_unlock_achievement("conqueror")

func _unlock_achievement(achievement_id: String):
	"""Unlock achievement and emit signal"""
	print("Achievement unlocked: %s" % achievement_id)
	achievement_unlocked.emit(achievement_id)

# ANALYTICS & INSIGHTS  

func get_battle_summary() -> Dictionary:
	"""Get comprehensive battle statistics summary"""
	var win_rate = 0.0
	if battle_stats.total_battles > 0:
		win_rate = float(battle_stats.battles_won) / float(battle_stats.total_battles) * 100.0
	
	return {
		"total_battles": battle_stats.total_battles,
		"victories": battle_stats.battles_won,
		"defeats": battle_stats.battles_lost,
		"win_rate": win_rate,
		"current_streak": battle_stats.current_win_streak,
		"longest_streak": battle_stats.longest_win_streak,
		"perfect_victories": battle_stats.perfect_victories,
		"damage_dealt": battle_stats.total_damage_dealt,
		"damage_taken": battle_stats.total_damage_taken,
		"healing_done": battle_stats.total_healing_done
	}

func get_top_performing_gods(limit: int = 5) -> Array:
	"""Get list of top performing gods by win rate"""
	var god_rankings = []
	
	for god_id in god_performance:
		var stats = god_performance[god_id]
		if stats.battles_participated >= 5:  # Minimum battles for ranking
			god_rankings.append({
				"god_id": god_id,
				"win_rate": get_god_win_rate(god_id),
				"battles": stats.battles_participated,
				"victories": stats.victories
			})
	
	# Sort by win rate
	god_rankings.sort_custom(func(a, b): return a.win_rate > b.win_rate)
	
	# Return top performers
	return god_rankings.slice(0, limit)

# TIME TRACKING

func _update_session_playtime():
	"""Update total playtime"""
	var session_time = Time.get_unix_time_from_system() - time_stats.session_start_time
	time_stats.total_playtime += session_time
	time_stats.last_play_date = Time.get_unix_time_from_system()

func get_playtime_summary() -> Dictionary:
	"""Get playtime statistics"""
	_update_session_playtime()
	
	var hours = int(time_stats.total_playtime / 3600)
	var minutes = int((time_stats.total_playtime % 3600) / 60)
	
	return {
		"total_hours": hours,
		"total_minutes": minutes,
		"session_start": time_stats.session_start_time,
		"first_play": time_stats.first_play_date,
		"last_play": time_stats.last_play_date
	}

# SAVE/LOAD SYSTEM

func save_statistics_data() -> Dictionary:
	"""Save statistics for game save"""
	_update_session_playtime()
	
	return {
		"battle_stats": battle_stats.duplicate(),
		"god_performance": god_performance.duplicate(),
		"resource_stats": resource_stats.duplicate(),
		"time_stats": time_stats.duplicate()
	}

func load_statistics_data(data: Dictionary):
	"""Load statistics from game save"""
	battle_stats = data.get("battle_stats", battle_stats)
	god_performance = data.get("god_performance", {})
	resource_stats = data.get("resource_stats", resource_stats)
	time_stats = data.get("time_stats", time_stats)
	
	# Reset session start time
	time_stats.session_start_time = Time.get_unix_time_from_system()
	
	print("StatisticsManager: Loaded statistics - %d battles, %d gods tracked" % [
		battle_stats.total_battles, god_performance.size()
	])
