# scripts/systems/arena/ArenaMockData.gd
# Mock data generation for arena testing without Firebase
class_name ArenaMockData extends RefCounted


static func generate_mock_opponents(player_elo: int, count: int, get_league_func: Callable) -> Array[Dictionary]:
	"""Generate mock opponents for testing"""
	var mock_names: Array[String] = ["TestPlayer1", "ArenaKing", "GodSlayer", "Mythic_Mike", "DivineFury", "SkyGod99", "ElementalX", "TierLord", "BattleMage", "StormBringer"]
	var opponents: Array[Dictionary] = []

	for i: int in range(mini(count, mock_names.size())):
		var elo_variance: int = randi_range(-200, 200)
		var mock_elo: int = max(0, player_elo + elo_variance)

		opponents.append({
			"user_id": "mock_" + str(i),
			"display_name": mock_names[i],
			"elo": mock_elo,
			"league": get_league_func.call(mock_elo),
			"defense_team": _generate_mock_defense_team(),
			"defense_power": randi_range(8000, 20000),
			"wins": randi_range(10, 200),
			"losses": randi_range(5, 150)
		})

	return opponents


static func generate_mock_leaderboard(get_league_func: Callable) -> Array[Dictionary]:
	"""Generate mock leaderboard data"""
	var entries: Array[Dictionary] = []
	var names: Array[String] = ["#1_Champion", "EliteWarrior", "TopTierGod", "MythicPlayer", "ArenaLegend", "DivineMaster", "GodKiller99", "ProGamer", "ArenaKing", "BattleLord"]

	for i: int in range(10):
		var elo: int = 2500 - (i * 100) + randi_range(-20, 20)
		entries.append({
			"rank": i + 1,
			"user_id": "leader_" + str(i),
			"display_name": names[i],
			"elo": elo,
			"league": get_league_func.call(elo),
			"wins": 500 - (i * 30) + randi_range(-10, 10),
			"losses": 100 + (i * 10) + randi_range(-5, 5)
		})

	return entries


static func _generate_mock_defense_team() -> Array[Dictionary]:
	"""Generate mock defense team data"""
	var team: Array[Dictionary] = []
	var god_names: Array[String] = ["Zeus", "Athena", "Poseidon", "Hades", "Thor", "Odin", "Ra", "Anubis"]
	var elements: Array[int] = [0, 1, 2, 3, 4, 5]
	var set_names: Array[String] = ["warrior", "guardian", "swift", "vampire", "rage", "focus", "blade", "endure"]
	var slot_types: Array[String] = ["weapon", "armor", "helm", "boots", "amulet", "ring"]

	var team_size: int = randi_range(2, 4)
	for i: int in range(team_size):
		var equipment: Dictionary = {}
		var primary_set: String = set_names[randi() % set_names.size()]
		var secondary_set: String = set_names[randi() % set_names.size()]

		for slot: String in slot_types:
			if randf() < 0.7:
				var eq_set: String = primary_set
				if randf() >= 0.6:
					eq_set = secondary_set
				equipment[slot] = {
					"name": eq_set.capitalize() + " " + slot.capitalize(),
					"equipment_set_name": eq_set,
					"set": eq_set,
					"tier": randi_range(1, 5),
					"level": randi_range(1, 15),
					"main_stat": _get_mock_main_stat(slot),
					"substats": _get_mock_substats()
				}

		team.append({
			"god_id": "mock_god_" + str(i),
			"template_id": god_names[randi() % god_names.size()].to_lower(),
			"name": god_names[randi() % god_names.size()],
			"level": randi_range(20, 40),
			"tier": randi_range(1, 3),
			"element": elements[randi() % elements.size()],
			"is_awakened": randf() > 0.5,
			"base_hp": randi_range(8000, 15000),
			"base_attack": randi_range(800, 1500),
			"base_defense": randi_range(500, 1000),
			"base_speed": randi_range(100, 150),
			"abilities": ["basic_attack", "skill_1", "skill_2"],
			"equipment": equipment
		})

	return team


static func _get_mock_main_stat(slot: String) -> Dictionary:
	"""Generate a mock main stat based on slot type"""
	match slot:
		"weapon":
			return {"stat": "attack", "value": randi_range(50, 150)}
		"armor":
			return {"stat": "defense", "value": randi_range(40, 120)}
		"helm":
			return {"stat": "hp", "value": randi_range(500, 1500)}
		"boots":
			return {"stat": "speed", "value": randi_range(10, 30)}
		"amulet":
			var stats: Array[String] = ["attack%", "defense%", "hp%", "crit_rate"]
			return {"stat": stats[randi() % stats.size()], "value": randi_range(10, 40)}
		"ring":
			var stats: Array[String] = ["crit_damage", "accuracy", "resistance"]
			return {"stat": stats[randi() % stats.size()], "value": randi_range(10, 50)}
	return {"stat": "attack", "value": 50}


static func _get_mock_substats() -> Array[Dictionary]:
	"""Generate 2-4 random substats"""
	var possible: Array[String] = ["attack", "defense", "hp", "speed", "crit_rate", "crit_damage", "accuracy", "resistance"]
	var count: int = randi_range(2, 4)
	var substats: Array[Dictionary] = []
	for j: int in range(count):
		substats.append({
			"stat": possible[randi() % possible.size()],
			"value": randi_range(5, 25)
		})
	return substats
