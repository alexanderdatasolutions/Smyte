class_name GodExperienceCalculator
extends RefCounted

## Single source of truth for all god experience calculations
## Used by CollectionManager, CollectionScreen, and any other system needing XP logic

const BASE_XP = 100
const LEVEL_MULTIPLIER = 1.5
const MAX_LEVEL = 40

## Calculate what level a god should be based on total experience
static func calculate_level_from_experience(total_xp: int) -> int:
	if total_xp <= 0:
		return 1
	
	var level = 1
	var required_xp = 0
	
	while required_xp < total_xp and level < MAX_LEVEL:
		level += 1
		required_xp += int(BASE_XP * pow(LEVEL_MULTIPLIER, level - 2))
	
	return level - 1  # Return the last achieved level

## Calculate total experience needed to reach a specific level
static func get_total_experience_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	
	var total_xp = 0
	for level in range(2, target_level + 1):
		total_xp += int(BASE_XP * pow(LEVEL_MULTIPLIER, level - 2))
	
	return total_xp

## Calculate experience needed to reach next level from current level
static func get_experience_to_next_level(current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	
	return int(BASE_XP * pow(LEVEL_MULTIPLIER, current_level - 1))

## Calculate experience progress within current level (0.0 to 100.0)
static func get_experience_progress(god: God) -> float:
	if god.level >= MAX_LEVEL:
		return 100.0
	
	var current_level_xp = get_total_experience_for_level(god.level)
	var next_level_xp = get_total_experience_for_level(god.level + 1)
	var current_total_xp = god.experience
	
	# Calculate progress within current level
	var level_xp_needed = next_level_xp - current_level_xp
	var level_xp_progress = current_total_xp - current_level_xp
	
	if level_xp_needed <= 0:
		return 100.0
		
	return min(100.0, max(0.0, (float(level_xp_progress) / float(level_xp_needed)) * 100.0))

## Get experience remaining to next level
static func get_experience_remaining_to_next_level(god: God) -> int:
	if god.level >= MAX_LEVEL:
		return 0
	
	var next_level_total_xp = get_total_experience_for_level(god.level + 1)
	return max(0, next_level_total_xp - god.experience)

## Debug function to validate calculations
static func debug_experience_info(god: God) -> String:
	var current_level_xp = get_total_experience_for_level(god.level)
	var next_level_xp = get_total_experience_for_level(god.level + 1)
	var progress = get_experience_progress(god)
	var remaining = get_experience_remaining_to_next_level(god)
	
	return "God: %s | Level: %d | Total XP: %d | Current Level XP: %d | Next Level XP: %d | Progress: %.1f%% | Remaining: %d" % [
		god.name, god.level, god.experience, current_level_xp, next_level_xp, progress, remaining
	]
