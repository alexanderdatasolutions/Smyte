# scripts/data/BattleResult.gd  
# Battle result data class - contains outcome and statistics
class_name BattleResult extends Resource

# Core result data
@export var victory: bool = false
@export var defeat_reason: String = ""
@export var victory_condition: String = ""

# Battle metadata
@export var battle_type: String = ""
@export var duration: float = 0.0
@export var turns_taken: int = 0

# Performance statistics
@export var damage_dealt: int = 0
@export var damage_received: int = 0
@export var units_defeated: int = 0
@export var units_lost: int = 0
@export var skills_used: int = 0
@export var critical_hits: int = 0

# Rewards and progression
@export var rewards: Dictionary = {}
@export var experience_gained: Dictionary = {}  # god_id -> exp_amount
@export var loot_obtained: Array = []

# Battle statistics per unit
@export var unit_statistics: Dictionary = {}

# Special achievements during battle
@export var achievements_unlocked: Array = []  # Array[String]

## Create a victory result
static func create_victory(condition: String = "All enemies defeated") -> BattleResult:
	var result = BattleResult.new()
	result.victory = true
	result.victory_condition = condition
	return result

## Create a defeat result
static func create_defeat(reason: String = "All units defeated") -> BattleResult:
	var result = BattleResult.new()
	result.victory = false
	result.defeat_reason = reason
	return result

## Add statistics for a specific unit
func add_unit_statistics(unit_id: String, stats: Dictionary):
	unit_statistics[unit_id] = stats

## Add experience gained for a god
func add_experience_gained(god_id: String, experience: int):
	experience_gained[god_id] = experience_gained.get(god_id, 0) + experience

## Add a reward to the result
func add_reward(resource_id: String, amount: int):
	rewards[resource_id] = rewards.get(resource_id, 0) + amount

## Add loot item to the result
func add_loot_item(item: Dictionary):
	loot_obtained.append(item)

## Check if this was a perfect victory (no units lost)
func is_perfect_victory() -> bool:
	return victory and units_lost == 0

## Get victory/defeat message for UI display
func get_result_message() -> String:
	if victory:
		var message = "Victory! " + victory_condition
		if is_perfect_victory():
			message += " (Perfect!)"
		return message
	else:
		return "Defeat: " + defeat_reason

## Get battle efficiency rating (S, A, B, C, D)
func get_efficiency_rating() -> String:
	if not victory:
		return "D"
	
	var score = 0
	
	# Perfect victory bonus
	if is_perfect_victory():
		score += 40
	
	# Speed bonus (fewer turns = better)
	if turns_taken <= 5:
		score += 30
	elif turns_taken <= 10:
		score += 20
	elif turns_taken <= 20:
		score += 10
	
	# Damage efficiency
	var damage_ratio = float(damage_dealt) / max(damage_received, 1)
	if damage_ratio >= 3.0:
		score += 30
	elif damage_ratio >= 2.0:
		score += 20
	elif damage_ratio >= 1.5:
		score += 10
	
	# Assign rating based on score
	if score >= 90:
		return "S"
	elif score >= 70:
		return "A"
	elif score >= 50:
		return "B"
	elif score >= 30:
		return "C"
	else:
		return "D"

## Get formatted duration string
func get_duration_string() -> String:
	var total_seconds = int(duration)
	@warning_ignore("integer_division")
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

## Get reward summary string for UI
func get_reward_summary() -> String:
	if rewards.is_empty():
		return "No rewards"
	
	var reward_strings = []
	for resource in rewards:
		reward_strings.append(str(rewards[resource]) + " " + resource)
	
	return ", ".join(reward_strings)

## Get complete battle statistics
func get_statistics_summary() -> Dictionary:
	return {
		"result": "Victory" if victory else "Defeat",
		"duration": get_duration_string(),
		"turns": turns_taken,
		"damage_dealt": damage_dealt,
		"damage_received": damage_received,
		"units_defeated": units_defeated,
		"units_lost": units_lost,
		"efficiency": get_efficiency_rating(),
		"perfect": is_perfect_victory()
	}

## Export result data for save/analytics
func export_data() -> Dictionary:
	return {
		"victory": victory,
		"battle_type": battle_type,
		"duration": duration,
		"turns": turns_taken,
		"damage_dealt": damage_dealt,
		"damage_received": damage_received,
		"units_defeated": units_defeated,
		"units_lost": units_lost,
		"skills_used": skills_used,
		"critical_hits": critical_hits,
		"rewards": rewards.duplicate(),
		"experience": experience_gained.duplicate(),
		"efficiency_rating": get_efficiency_rating(),
		"timestamp": Time.get_ticks_msec()
	}
