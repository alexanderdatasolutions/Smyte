# scripts/systems/dungeon/DungeonConstants.gd
# Shared constants and utility functions for dungeon systems
extends RefCounted
class_name DungeonConstants

const MAX_TEAM_SIZE: int = 4

# Cached config data
static var _battle_config: Dictionary = {}
static var _config_loaded: bool = false

static func _load_battle_config() -> void:
	"""Load battle config once and cache it"""
	if _config_loaded:
		return

	var file := FileAccess.open("res://data/battle_config.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_battle_config = parsed
	_config_loaded = true

static func get_difficulty_reward_multiplier(difficulty: String) -> float:
	"""Get reward multiplier for difficulty from battle_config.json"""
	_load_battle_config()

	var enemy_scaling: Dictionary = _battle_config.get("enemy_scaling", {})
	var reward_mults: Dictionary = enemy_scaling.get("reward_multipliers", {})

	# Return from config, with sensible fallback
	if reward_mults.has(difficulty):
		return float(reward_mults[difficulty])

	# Fallback for unknown difficulties
	return 1.0
