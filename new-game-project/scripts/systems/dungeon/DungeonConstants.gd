# scripts/systems/dungeon/DungeonConstants.gd
# Shared constants and utility functions for dungeon systems
extends RefCounted
class_name DungeonConstants

const MAX_TEAM_SIZE: int = 4

static func get_difficulty_reward_multiplier(difficulty: String) -> float:
	match difficulty:
		"beginner":
			return 1.0
		"intermediate":
			return 1.2
		"advanced":
			return 1.5
		"expert":
			return 2.0
		"master":
			return 2.5
		"heroic":
			return 2.0
		"legendary":
			return 3.0
		_:
			return 1.0
