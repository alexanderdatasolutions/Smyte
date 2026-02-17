# scripts/systems/dungeon/DungeonWaveHelper.gd
# RULE 2: Single responsibility - Wave data loading, enemy stat calculation, dungeon info enhancement
# RULE 3: No UI logic - pure battle config helpers
extends RefCounted

var _enemy_scaling: Dictionary = {}
var _dungeon_waves: Dictionary = {}

# Map dungeon IDs to wave category keys in dungeon_waves.json
const CATEGORY_MAP: Dictionary = {
	"fire_sanctum": "elemental_sanctums",
	"water_sanctum": "elemental_sanctums",
	"earth_sanctum": "elemental_sanctums",
	"lightning_sanctum": "elemental_sanctums",
	"light_sanctum": "elemental_sanctums",
	"dark_sanctum": "elemental_sanctums",
	"magic_sanctum": "special_sanctums",
	"titans_forge": "equipment_dungeons",
	"valhalla_armory": "equipment_dungeons",
	"oracle_sanctum": "equipment_dungeons",
	"greek_trials": "pantheon_trials",
	"norse_trials": "pantheon_trials",
	"egyptian_trials": "pantheon_trials",
	"hindu_trials": "pantheon_trials",
	"japanese_trials": "pantheon_trials",
	"celtic_trials": "pantheon_trials",
	"aztec_trials": "pantheon_trials",
	"slavic_trials": "pantheon_trials"
}

func initialize(dungeon_waves: Dictionary) -> void:
	_dungeon_waves = dungeon_waves
	_load_enemy_scaling_config()

func _load_enemy_scaling_config() -> void:
	var file := FileAccess.open("res://data/battle_config.json", FileAccess.READ)
	if not file:
		return
	var config: Variant = JSON.parse_string(file.get_as_text())
	if config is Dictionary:
		_enemy_scaling = config.get("enemy_scaling", {})

func update_waves(dungeon_waves: Dictionary) -> void:
	_dungeon_waves = dungeon_waves

# ===== Battle Configuration =====

func get_battle_configuration(dungeon_info: Dictionary, difficulty: String) -> Dictionary:
	if dungeon_info.is_empty():
		return {}

	var difficulty_info: Dictionary = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	if difficulty_info.is_empty():
		return {}

	var dungeon_id: String = dungeon_info.get("id", "")
	var wave_data: Array = _get_wave_data(dungeon_id, difficulty)
	var enemy_waves: Array = _convert_wave_data_to_battle_config(wave_data)

	return {
		"enemies": difficulty_info.get("enemies", []),
		"enemy_waves": enemy_waves,
		"boss": difficulty_info.get("boss", ""),
		"battle_type": "dungeon",
		"background": dungeon_info.get("background_theme", "default"),
		"special_conditions": difficulty_info.get("special_conditions", []),
		"wave_count": wave_data.size()
	}

func _get_wave_data(dungeon_id: String, difficulty: String) -> Array:
	var category: String = CATEGORY_MAP.get(dungeon_id, "")
	if category.is_empty():
		push_warning("DungeonWaveHelper: No wave category found for dungeon: " + dungeon_id)
		return []

	var category_data: Dictionary = _dungeon_waves.get(category, {})
	var dungeon_wave_data: Dictionary = category_data.get(dungeon_id, {})
	var difficulty_wave_data: Dictionary = dungeon_wave_data.get(difficulty, {})
	var waves: Array = difficulty_wave_data.get("waves", [])

	return waves

const MAX_ENEMIES_PER_WAVE: int = 4

func _convert_wave_data_to_battle_config(wave_data: Array) -> Array:
	var enemy_waves: Array = []

	for wave: Dictionary in wave_data:
		var wave_enemies: Array = []
		var enemies: Array = wave.get("enemies", [])

		for enemy_def: Dictionary in enemies:
			var count: int = enemy_def.get("count", 1)
			var level: int = enemy_def.get("level", 1)
			var tier: String = enemy_def.get("tier", "basic")
			var enemy_name: String = enemy_def.get("name", "Unknown Enemy")
			var element: String = enemy_def.get("type", "neutral")

			for i: int in range(count):
				# Enforce max 4 enemies per wave
				if wave_enemies.size() >= MAX_ENEMIES_PER_WAVE:
					break

				var stats: Dictionary = _calculate_enemy_stats(level, tier)
				wave_enemies.append({
					"name": enemy_name,
					"level": level,
					"hp": stats.hp,
					"attack": stats.attack,
					"defense": stats.defense,
					"speed": stats.speed,
					"element": element,
					"tier": tier
				})

			# Also check after processing each enemy type
			if wave_enemies.size() >= MAX_ENEMIES_PER_WAVE:
				break

		enemy_waves.append(wave_enemies)

	return enemy_waves

func _calculate_enemy_stats(level: int, tier: String) -> Dictionary:
	var base_stats: Dictionary = _enemy_scaling.get("base_stats", {})
	var base_hp: int = base_stats.get("hp", 120)
	var base_attack: int = base_stats.get("attack", 50)
	var base_defense: int = base_stats.get("defense", 60)
	var base_speed: int = base_stats.get("speed", 55)

	var tier_multipliers: Dictionary = _enemy_scaling.get("tier_multipliers", {})
	var tier_mult: float = tier_multipliers.get(tier, 1.0)

	var level_scale: float = _enemy_scaling.get("level_scaling_per_level", 0.1)
	var speed_per_level: int = _enemy_scaling.get("speed_per_level", 2)
	var level_mult: float = 1.0 + (level - 1) * level_scale

	return {
		"hp": int(base_hp * level_mult * tier_mult),
		"attack": int(base_attack * level_mult * tier_mult),
		"defense": int(base_defense * level_mult * tier_mult),
		"speed": int(base_speed + level * speed_per_level)
	}

# ===== Dungeon Info Enhancement =====

func enhance_dungeon_info(info: Dictionary) -> void:
	var difficulty_levels: Dictionary = info.get("difficulty_levels", {})

	for difficulty_name: String in difficulty_levels.keys():
		var difficulty_info: Dictionary = difficulty_levels[difficulty_name]

		var enemy_power: int = _calculate_enemy_power(info, difficulty_name)
		difficulty_info["enemy_power"] = enemy_power
		difficulty_info["recommended_team_power"] = int(enemy_power * 1.2)
		difficulty_info["difficulty_color"] = _get_difficulty_color(difficulty_name)
		difficulty_info["stage_count"] = 5
		difficulty_info["boss_power"] = int(enemy_power * 1.5)

func _calculate_enemy_power(dungeon_info: Dictionary, difficulty: String) -> int:
	var category_powers: Dictionary = _enemy_scaling.get("category_base_power", {})
	var difficulty_mults: Dictionary = _enemy_scaling.get("difficulty_multipliers", {})

	var category: String = dungeon_info.get("category", "elemental")
	var base_power: int = category_powers.get(category, 1000)
	var difficulty_multiplier: float = difficulty_mults.get(difficulty, 1.0)

	var difficulty_info: Dictionary = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	var recommended_level: int = difficulty_info.get("recommended_level", 10)
	var level_base: int = _enemy_scaling.get("power_level_base", 10)
	var level_scale: float = _enemy_scaling.get("power_level_scaling", 0.1)
	var level_multiplier: float = 1.0 + (recommended_level - level_base) * level_scale

	return int(base_power * difficulty_multiplier * level_multiplier)

func _get_difficulty_color(difficulty: String) -> Color:
	match difficulty:
		"beginner":
			return Color.GREEN
		"intermediate":
			return Color.YELLOW
		"advanced":
			return Color.ORANGE
		"expert":
			return Color.RED
		"master":
			return Color.PURPLE
		_:
			return Color.WHITE

# ===== Enemy Preview =====

func get_enemy_types_for_dungeon(dungeon_info: Dictionary) -> Array:
	var element: String = dungeon_info.get("element", "neutral")
	var category: String = dungeon_info.get("category", "elemental")

	var enemy_types: Array = []

	match category:
		"elemental":
			enemy_types = [
				element.capitalize() + " Guardian",
				element.capitalize() + " Warden",
				element.capitalize() + " Spirit"
			]
		"pantheon":
			enemy_types = [
				"Divine Guardian",
				"Sacred Protector",
				"Celestial Champion"
			]
		"equipment":
			enemy_types = [
				"Armored Sentinel",
				"Weapon Master",
				"Equipment Guardian"
			]

	return enemy_types

func get_dungeon_enemies(dungeon_info: Dictionary, difficulty: String) -> Array:
	var difficulty_info: Dictionary = dungeon_info.get("difficulty_levels", {}).get(difficulty, {})
	var waves: Array = difficulty_info.get("waves", [])

	var enemies: Array = []
	var enemy_types: Array = get_enemy_types_for_dungeon(dungeon_info)

	if not waves.is_empty():
		for wave: Array in waves:
			for enemy: Dictionary in wave:
				enemies.append({
					"name": enemy.get("name", "Enemy"),
					"level": enemy.get("level", 1)
				})
	else:
		var base_level: int = difficulty_info.get("recommended_level", 5)
		for enemy_type: String in enemy_types:
			enemies.append({
				"name": enemy_type,
				"level": base_level
			})

	return enemies
