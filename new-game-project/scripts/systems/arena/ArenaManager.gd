# scripts/systems/arena/ArenaManager.gd
# Core arena system - ELO, opponent matching, defense teams
class_name ArenaManager extends Node

# Preload dependencies
const ArenaDataSyncScript = preload("res://scripts/systems/arena/ArenaDataSync.gd")
const ArenaMockDataScript = preload("res://scripts/systems/arena/ArenaMockData.gd")

# Signals
signal opponents_loaded(opponents: Array)
signal defense_updated(success: bool)
signal battle_result_processed(result: Dictionary)
signal leaderboard_loaded(entries: Array)
signal elo_changed(old_elo: int, new_elo: int, change: int)

# Constants (loaded from data/arena_config.json)
var BASE_ELO: int = 1000
var K_FACTOR_BASE: int = 32
var K_FACTOR_NEW_PLAYER: int = 40
var NEW_PLAYER_GAMES: int = 30
var ATTACK_COOLDOWN: float = 86400.0  # 24 hours default
var MAX_ELO_RANGE: int = 300
var OPPONENTS_TO_FETCH: int = 10
var HIGH_ELO_K_FACTOR_MULT: float = 0.75
var MIN_ELO_CHANGE: int = 5

# League thresholds (loaded from config)
var LEAGUE_THRESHOLDS: Dictionary = {
	"bronze": 0, "silver": 1100, "gold": 1300,
	"platinum": 1500, "diamond": 1800, "legend": 2200
}

var LEAGUE_COLORS: Dictionary = {
	"bronze": Color(0.6, 0.4, 0.2), "silver": Color(0.7, 0.7, 0.75),
	"gold": Color(1.0, 0.84, 0.0), "platinum": Color(0.4, 0.8, 0.8),
	"diamond": Color(0.4, 0.6, 1.0), "legend": Color(0.7, 0.4, 0.9)
}

# Reward config (loaded from config)
var _arena_config: Dictionary = {}

# Player state
var player_elo: int = BASE_ELO
var player_rank: int = 0
var player_league: String = "bronze"
var defense_team: Array[God] = []
var defense_team_ids: Array[String] = []  # Persist these for save/load
var cached_opponents: Array[Dictionary] = []
var attack_cooldowns: Dictionary = {}  # {opponent_uid: {timestamp, team_version}}
var total_games: int = 0
var wins: int = 0
var losses: int = 0
var defense_wins: int = 0
var defense_losses: int = 0

# Firebase sync
var _data_sync: Node = null  # ArenaDataSync instance

# System reference helper
func _get_system_registry() -> Node:
	var registry_script: GDScript = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func initialize() -> void:
	_load_arena_config()
	_data_sync = ArenaDataSyncScript.new()
	_data_sync.name = "ArenaDataSync"
	add_child(_data_sync)
	_connect_signals()
	_update_league()

func _load_arena_config() -> void:
	"""Load arena balance values from data/arena_config.json"""
	var file := FileAccess.open("res://data/arena_config.json", FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed or not (parsed is Dictionary):
		push_warning("[ArenaManager] arena_config.json parse failed or not a Dictionary")
		return
	var config: Dictionary = parsed as Dictionary
	_arena_config = config

	var elo_cfg: Dictionary = config.get("elo", {})
	BASE_ELO = elo_cfg.get("base_elo", BASE_ELO)
	K_FACTOR_BASE = elo_cfg.get("k_factor_base", K_FACTOR_BASE)
	K_FACTOR_NEW_PLAYER = elo_cfg.get("k_factor_new_player", K_FACTOR_NEW_PLAYER)
	NEW_PLAYER_GAMES = elo_cfg.get("new_player_games", NEW_PLAYER_GAMES)
	HIGH_ELO_K_FACTOR_MULT = elo_cfg.get("high_elo_k_factor_multiplier", HIGH_ELO_K_FACTOR_MULT)
	MIN_ELO_CHANGE = elo_cfg.get("min_elo_change", MIN_ELO_CHANGE)
	MAX_ELO_RANGE = elo_cfg.get("max_elo_range", MAX_ELO_RANGE)
	OPPONENTS_TO_FETCH = elo_cfg.get("opponents_to_fetch", OPPONENTS_TO_FETCH)

	var cooldowns: Dictionary = config.get("cooldowns", {})
	ATTACK_COOLDOWN = cooldowns.get("attack_cooldown_seconds", ATTACK_COOLDOWN)
	print("[ArenaManager] Config loaded - attack cooldown: %d seconds (%.1f hours)" % [int(ATTACK_COOLDOWN), ATTACK_COOLDOWN / 3600.0])

	var leagues: Dictionary = config.get("leagues", {})
	var thresholds: Dictionary = leagues.get("thresholds", {})
	if not thresholds.is_empty():
		LEAGUE_THRESHOLDS = thresholds
	var colors: Dictionary = leagues.get("colors", {})
	for league_name: String in colors:
		var c_val: Variant = colors[league_name]
		if c_val is Array and (c_val as Array).size() >= 3:
			var c: Array = c_val as Array
			LEAGUE_COLORS[league_name] = Color(c[0], c[1], c[2])

func _connect_signals() -> void:
	if _data_sync != null:
		_data_sync.opponents_fetched.connect(_on_opponents_fetched)
		_data_sync.defense_uploaded.connect(_on_defense_uploaded)
		_data_sync.leaderboard_fetched.connect(_on_leaderboard_fetched)
		_data_sync.player_stats_updated.connect(_on_player_stats_updated)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func fetch_opponents() -> void:
	"""Fetch opponents within ELO range from Firebase"""
	print("[ArenaManager] fetch_opponents called")

	# Try to refresh connection if not ready
	if _data_sync != null and not _data_sync.is_ready():
		print("[ArenaManager] DataSync not ready for fetch, attempting refresh")
		_data_sync.refresh_firebase_connection()

	if _data_sync != null and _data_sync.is_ready():
		print("[ArenaManager] Fetching opponents from Firebase (ELO range: %d-%d)" % [player_elo - MAX_ELO_RANGE, player_elo + MAX_ELO_RANGE])
		_data_sync.fetch_opponents_in_range(
			player_elo - MAX_ELO_RANGE,
			player_elo + MAX_ELO_RANGE,
			OPPONENTS_TO_FETCH
		)
	else:
		# Generate mock opponents for testing without Firebase
		print("[ArenaManager] DataSync not ready, using mock opponents")
		_generate_mock_opponents()

func update_defense_team(team: Array) -> void:
	"""Update the player's defense team locally (does NOT upload to Firebase)
	Use post_defense_to_firebase() to explicitly post to arena"""
	defense_team.clear()
	for god: God in team:
		defense_team.append(god)
	defense_team_ids.clear()
	for god: God in team:
		if god != null:
			defense_team_ids.append(god.id)
	# Just emit success - team is saved locally only
	# User must click "Post to Arena" to upload to Firebase
	defense_updated.emit(true)

func get_defense_team() -> Array[God]:
	"""Get the current defense team"""
	return defense_team

func withdraw_from_arena() -> void:
	"""Withdraw from arena - clears defense team so you can't be attacked"""
	print("[ArenaManager] Withdrawing from arena")
	defense_team.clear()
	defense_team_ids.clear()

	if _data_sync != null and _data_sync.is_ready():
		_data_sync.withdraw_from_arena()
	else:
		defense_updated.emit(true)

func has_defense_team() -> bool:
	"""Check if player has an active defense team"""
	return not defense_team.is_empty()

func post_defense_to_firebase() -> void:
	"""Explicitly upload current defense team to Firebase for PvP arena"""
	print("[ArenaManager] post_defense_to_firebase called with %d gods" % defense_team.size())
	if defense_team.is_empty():
		push_warning("[ArenaManager] No defense team to post")
		return

	# Try to refresh connection if not ready (user may have signed in after initialization)
	if _data_sync != null and not _data_sync.is_ready():
		print("[ArenaManager] DataSync not ready, attempting refresh")
		_data_sync.refresh_firebase_connection()

	if _data_sync != null and _data_sync.is_ready():
		print("[ArenaManager] DataSync ready, uploading defense team")
		_data_sync.upload_defense_team(_serialize_defense_team(defense_team))
	else:
		push_warning("[ArenaManager] DataSync still not ready after refresh, defense not posted")
		defense_updated.emit(false)

func can_attack_opponent(opponent_uid: String, opponent_data: Dictionary = {}) -> bool:
	"""Check if attack cooldown has expired OR if opponent updated their team"""
	if not attack_cooldowns.has(opponent_uid):
		return true

	# Handle migration from old format (float timestamp) to new format (Dictionary)
	var raw_data: Variant = attack_cooldowns[opponent_uid]
	var last_attack_time: float = 0.0
	var last_team_version: float = 0.0

	if raw_data is Dictionary:
		last_attack_time = raw_data.get("timestamp", 0.0)
		last_team_version = raw_data.get("team_version", 0.0)
	else:
		# Old format - just a timestamp (float/int)
		last_attack_time = float(raw_data) if raw_data else 0.0
		# Migrate to new format
		attack_cooldowns[opponent_uid] = {"timestamp": last_attack_time, "team_version": 0.0}

	# Check if 24h cooldown has expired
	var elapsed: float = Time.get_unix_time_from_system() - last_attack_time
	if elapsed > ATTACK_COOLDOWN:
		return true

	# Check if opponent updated their defense team since last attack
	var current_team_version: float = opponent_data.get("last_defense_update", 0.0)
	if current_team_version > last_team_version:
		return true  # Team changed, can attack again

	return false

func get_attack_cooldown_remaining(opponent_uid: String, opponent_data: Dictionary = {}) -> float:
	"""Get remaining cooldown time in seconds (0 if team changed)"""
	if not attack_cooldowns.has(opponent_uid):
		return 0.0

	# Handle migration from old format (float timestamp) to new format (Dictionary)
	var raw_data: Variant = attack_cooldowns[opponent_uid]
	var last_attack_time: float = 0.0
	var last_team_version: float = 0.0

	if raw_data is Dictionary:
		last_attack_time = raw_data.get("timestamp", 0.0)
		last_team_version = raw_data.get("team_version", 0.0)
	else:
		# Old format - just a timestamp
		last_attack_time = float(raw_data) if raw_data else 0.0
		attack_cooldowns[opponent_uid] = {"timestamp": last_attack_time, "team_version": 0.0}

	# If team changed, no cooldown
	var current_team_version: float = opponent_data.get("last_defense_update", 0.0)
	if current_team_version > last_team_version:
		return 0.0

	var elapsed: float = Time.get_unix_time_from_system() - last_attack_time
	return max(0.0, ATTACK_COOLDOWN - elapsed)

func start_pvp_battle(opponent_data: Dictionary) -> Dictionary:
	"""Prepare battle context for PvP - returns context for BattleSetupCoordinator"""
	var opponent_uid: String = opponent_data.get("user_id", "")
	if opponent_uid.is_empty():
		push_warning("[ArenaManager] Opponent has no user_id")

	# Store both timestamp and team version for cooldown tracking
	attack_cooldowns[opponent_uid] = {
		"timestamp": Time.get_unix_time_from_system(),
		"team_version": opponent_data.get("last_defense_update", 0.0)
	}
	return {
		"type": "pvp",
		"opponent": opponent_data,
		"opponent_name": opponent_data.get("display_name", "Opponent"),
		"opponent_elo": opponent_data.get("elo", BASE_ELO),
		"opponent_league": opponent_data.get("league", "bronze")
	}

func process_battle_result(victory: bool, opponent_data: Dictionary) -> Dictionary:
	"""Process battle result, update ELO, return rewards"""
	print("[ArenaManager] process_battle_result called - victory: %s" % victory)
	if opponent_data.is_empty():
		push_warning("[ArenaManager] Empty opponent data in process_battle_result")
		return {"victory": victory, "elo_change": 0, "rewards": {}}
	var opponent_elo: int = opponent_data.get("elo", BASE_ELO)
	var elo_change: int = _calculate_elo_change(player_elo, opponent_elo, victory)

	var old_elo: int = player_elo
	player_elo = max(0, player_elo + elo_change)
	total_games += 1

	if victory:
		wins += 1
	else:
		losses += 1

	print("[ArenaManager] ELO: %d -> %d (change: %+d), W/L: %d/%d" % [old_elo, player_elo, elo_change, wins, losses])

	var old_league: String = player_league
	_update_league()

	# Sync to Firebase
	if _data_sync != null and _data_sync.is_ready():
		_data_sync.update_player_stats(player_elo, wins, losses)
		_data_sync.record_battle(opponent_data.get("user_id", ""), victory, elo_change)
		# Symmetric ELO: update opponent's ELO and defense stats
		_data_sync.update_opponent_after_battle(opponent_data.get("user_id", ""), victory, elo_change)

	elo_changed.emit(old_elo, player_elo, elo_change)

	# Emit to EventBus for analytics
	var registry: Node = _get_system_registry()
	var event_bus: Node = registry.get_system("EventBus") if registry else null
	if event_bus:
		event_bus.arena_battle_completed.emit({
			"victory": victory,
			"old_elo": old_elo,
			"new_elo": player_elo,
			"elo_change": elo_change,
			"opponent_elo": opponent_elo,
			"league": player_league,
			"old_league": old_league,
			"new_league": player_league
		})
		# Emit league change if applicable
		if old_league != player_league:
			var new_threshold: int = LEAGUE_THRESHOLDS.get(player_league, 0)
			var old_threshold: int = LEAGUE_THRESHOLDS.get(old_league, 0)
			var direction: String = "promoted" if new_threshold > old_threshold else "demoted"
			event_bus.league_changed.emit({
				"old_league": old_league,
				"new_league": player_league,
				"elo": player_elo,
				"direction": direction
			})

	var rewards: Dictionary = _calculate_pvp_rewards(victory, opponent_elo)
	_award_rewards(rewards)

	var result: Dictionary = {
		"victory": victory,
		"elo_change": elo_change,
		"old_elo": old_elo,
		"new_elo": player_elo,
		"old_league": old_league,
		"new_league": player_league,
		"league_changed": old_league != player_league,
		"rewards": rewards
	}

	battle_result_processed.emit(result)

	# Trigger save to persist ELO changes locally
	if event_bus:
		event_bus.save_requested.emit()

	return result

func fetch_leaderboard() -> void:
	"""Fetch top players leaderboard"""
	if _data_sync != null and _data_sync.is_ready():
		_data_sync.fetch_leaderboard()
	else:
		_generate_mock_leaderboard()

func get_player_stats() -> Dictionary:
	"""Get current player arena stats"""
	return {
		"elo": player_elo,
		"rank": player_rank,
		"league": player_league,
		"league_color": LEAGUE_COLORS.get(player_league, Color.WHITE),
		"wins": wins,
		"losses": losses,
		"total_games": total_games,
		"win_rate": _calculate_win_rate(),
		"defense_team_power": _calculate_team_power(defense_team),
		"defense_wins": defense_wins,
		"defense_losses": defense_losses
	}

func get_league_color(league: String) -> Color:
	"""Get the display color for a league"""
	return LEAGUE_COLORS.get(league, Color.WHITE)

func get_league_for_elo(elo: int) -> String:
	"""Determine league from ELO"""
	for league: String in ["legend", "diamond", "platinum", "gold", "silver", "bronze"]:
		if elo >= LEAGUE_THRESHOLDS.get(league, 0):
			return league
	return "bronze"

# ==============================================================================
# ELO CALCULATION
# ==============================================================================

func _calculate_elo_change(p_elo: int, opp_elo: int, victory: bool) -> int:
	"""Standard ELO formula with adjustments"""
	# Expected score
	var expected: float = 1.0 / (1.0 + pow(10.0, (opp_elo - p_elo) / 400.0))
	var actual: float = 1.0 if victory else 0.0

	# K-factor adjustment
	var k_factor: int = K_FACTOR_NEW_PLAYER if total_games < NEW_PLAYER_GAMES else K_FACTOR_BASE

	# Reduce K at high ELO for stability
	if p_elo > LEAGUE_THRESHOLDS.get("diamond", 1800):
		k_factor = int(k_factor * HIGH_ELO_K_FACTOR_MULT)

	var change: int = int(k_factor * (actual - expected))

	# Minimum change to feel meaningful
	if change > 0:
		change = max(MIN_ELO_CHANGE, change)
	elif change < 0:
		change = min(-MIN_ELO_CHANGE, change)

	return change

func _update_league() -> void:
	"""Update league based on current ELO"""
	player_league = get_league_for_elo(player_elo)

func _calculate_win_rate() -> float:
	"""Calculate win rate percentage"""
	if total_games == 0:
		return 0.0
	return (float(wins) / float(total_games)) * 100.0

func _calculate_pvp_rewards(victory: bool, opponent_elo: int) -> Dictionary:
	"""Calculate rewards based on victory and opponent ELO"""
	var rcfg: Dictionary = _arena_config.get("rewards", {})
	var base_gold: int = rcfg.get("victory_gold", 300) if victory else rcfg.get("defeat_gold", 100)
	var base_mana: int = rcfg.get("victory_mana", 600) if victory else rcfg.get("defeat_mana", 200)

	# Bonus for defeating higher-rated opponents
	var elo_diff: int = opponent_elo - player_elo
	var elo_bonus: float = 1.0 + (max(0, elo_diff) / rcfg.get("elo_bonus_divisor", 500.0))

	var rewards: Dictionary = {
		"gold": int(base_gold * elo_bonus),
		"mana": int(base_mana * elo_bonus)
	}

	# Divine crystals for high-league wins
	var crystal_leagues: Array = rcfg.get("divine_crystal_leagues", ["platinum", "diamond", "legend"])
	if victory and player_league in crystal_leagues:
		var league_index: int = ["bronze", "silver", "gold", "platinum", "diamond", "legend"].find(player_league)
		if league_index >= 0:
			rewards["divine_crystals"] = rcfg.get("divine_crystal_base", 3) + maxi(0, league_index - 3)

	return rewards

func _award_rewards(rewards: Dictionary) -> void:
	"""Award resources to player"""
	var system_registry: Node = _get_system_registry()
	if not system_registry:
		return

	var resource_manager: Node = system_registry.get_system("ResourceManager")
	if not resource_manager:
		push_warning("[ArenaManager] ResourceManager not found, cannot award rewards")
		return
	for resource_id: String in rewards:
		var amount: Variant = rewards[resource_id]
		if amount is int or amount is float:
			resource_manager.add_resource(resource_id, int(amount))

func _calculate_team_power(team: Array[God]) -> int:
	"""Calculate total team combat power"""
	return TeamStatsCalculator.calculate_team_power(team)

# ==============================================================================
# SERIALIZATION
# ==============================================================================

func _serialize_defense_team(team: Array[God]) -> Array[Dictionary]:
	"""Serialize defense team for Firebase storage"""
	var serialized: Array[Dictionary] = []
	for god: God in team:
		if god == null:
			continue
		serialized.append(_serialize_god_for_pvp(god))
	return serialized

func _serialize_god_for_pvp(god: God) -> Dictionary:
	"""Serialize a god with all data needed to recreate in battle"""
	var system_registry: Node = _get_system_registry()
	var equipment_manager: Node = system_registry.get_system("EquipmentManager") if system_registry else null

	# Get equipped items
	var equipped: Dictionary = {}
	if equipment_manager and equipment_manager.has_method("get_equipped_items_for_god"):
		var god_equipment: Variant = equipment_manager.get_equipped_items_for_god(god.id)
		if god_equipment is Dictionary:
			for slot_idx: Variant in god_equipment:
				var eq: Variant = god_equipment[slot_idx]
				if eq is Equipment:
					equipped[str(slot_idx)] = _serialize_equipment(eq as Equipment)

	return {
		"god_id": god.id,
		"template_id": god.template_id,
		"name": god.name,
		"pantheon": god.pantheon,
		"level": god.level,
		"tier": god.tier,
		"element": god.element,
		"is_awakened": god.is_awakened,
		"awakened_name": god.awakened_name,
		"equipped_skin_id": god.equipped_skin_id,  # God skin - visible to opponents
		"base_hp": god.base_hp,
		"base_attack": god.base_attack,
		"base_defense": god.base_defense,
		"base_speed": god.base_speed,
		"base_crit_rate": god.base_crit_rate,
		"base_crit_damage": god.base_crit_damage,
		"base_resistance": god.base_resistance,
		"base_accuracy": god.base_accuracy,
		"equipment": equipped,
		"abilities": god.abilities,
		"active_abilities": god.active_abilities,
		"passive_abilities": god.passive_abilities,
		"innate_traits": god.innate_traits
	}

func _serialize_equipment(eq: Equipment) -> Dictionary:
	"""Serialize equipment for PvP"""
	return {
		"id": eq.id,
		"name": eq.name,
		"type": eq.type,
		"rarity": eq.rarity,
		"level": eq.level,
		"main_stat_type": eq.main_stat_type,
		"main_stat_value": eq.main_stat_value,
		"substats": eq.substats,
		"equipment_set_type": eq.equipment_set_type
	}

func deserialize_god_for_battle(data: Dictionary) -> God:
	"""Create a God object from serialized PvP data"""
	if data.is_empty():
		push_warning("[ArenaManager] Empty data passed to deserialize_god_for_battle")
		return null
	var god: God = God.new()
	god.id = data.get("god_id", "pvp_" + str(randi()))
	god.template_id = data.get("template_id", "")
	god.name = data.get("name", "Opponent God")
	god.pantheon = data.get("pantheon", "")
	god.level = data.get("level", 1)
	god.tier = data.get("tier", 0)
	god.element = data.get("element", 0)
	god.is_awakened = data.get("is_awakened", false)
	god.awakened_name = data.get("awakened_name", "")
	god.equipped_skin_id = data.get("equipped_skin_id", "")  # God skin
	god.base_hp = data.get("base_hp", 1000)
	god.base_attack = data.get("base_attack", 100)
	god.base_defense = data.get("base_defense", 100)
	god.base_speed = data.get("base_speed", 100)
	god.base_crit_rate = data.get("base_crit_rate", God.get_default_crit_rate())
	god.base_crit_damage = data.get("base_crit_damage", God.get_default_crit_damage())
	god.base_resistance = data.get("base_resistance", God.get_default_resistance())
	god.base_accuracy = data.get("base_accuracy", God.get_default_accuracy())
	god.abilities = data.get("abilities", [])
	god.active_abilities = data.get("active_abilities", [])
	god.passive_abilities = data.get("passive_abilities", [])

	# Handle typed arrays - must assign element by element
	var traits_data: Array = data.get("innate_traits", [])
	for trait_id: Variant in traits_data:
		god.innate_traits.append(str(trait_id))

	# Equipment stats are baked into base stats for PvP opponents
	# This ensures equipment effects apply even though we can't reconstruct Equipment objects
	var equipment_data: Dictionary = data.get("equipment", {})
	for slot_key: String in equipment_data:
		var eq_data: Dictionary = equipment_data[slot_key]
		_apply_equipment_stats_to_god(god, eq_data)

	return god

func _apply_equipment_stats_to_god(god: God, eq_data: Dictionary) -> void:
	"""Apply equipment stat bonuses directly to god base stats"""
	var main_stat: String = eq_data.get("main_stat_type", "")
	var main_value: int = eq_data.get("main_stat_value", 0)

	# Apply main stat
	_apply_stat_to_god(god, main_stat, main_value)

	# Apply substats
	var substats: Array = eq_data.get("substats", [])
	for substat: Dictionary in substats:
		var stat_type: String = substat.get("type", "")
		var stat_value: int = substat.get("value", 0)
		_apply_stat_to_god(god, stat_type, stat_value)

func _apply_stat_to_god(god: God, stat_type: String, value: int) -> void:
	"""Apply a stat bonus to god's base stats"""
	match stat_type:
		"hp", "health":
			god.base_hp += value
		"attack", "atk":
			god.base_attack += value
		"defense", "def":
			god.base_defense += value
		"speed", "spd":
			god.base_speed += value
		"crit_rate", "critical_rate":
			god.base_crit_rate += value
		"crit_damage", "critical_damage":
			god.base_crit_damage += value
		"resistance", "res":
			god.base_resistance += value
		"accuracy", "acc":
			god.base_accuracy += value

# ==============================================================================
# MOCK DATA (delegated to ArenaMockData.gd)
# ==============================================================================

func _generate_mock_opponents() -> void:
	"""Generate mock opponents for testing (Firebase fallback)"""
	var opponents: Array[Dictionary] = ArenaMockDataScript.generate_mock_opponents(
		player_elo, OPPONENTS_TO_FETCH, get_league_for_elo
	)
	cached_opponents = opponents
	opponents_loaded.emit(opponents)

func _generate_mock_leaderboard() -> void:
	"""Generate mock leaderboard data (Firebase fallback)"""
	var entries: Array[Dictionary] = ArenaMockDataScript.generate_mock_leaderboard(get_league_for_elo)
	leaderboard_loaded.emit(entries)

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_opponents_fetched(opponents: Array) -> void:
	print("[ArenaManager] _on_opponents_fetched received %d opponents" % opponents.size())
	cached_opponents.clear()
	for opp: Variant in opponents:
		if opp is Dictionary:
			cached_opponents.append(opp as Dictionary)
	print("[ArenaManager] Emitting opponents_loaded with %d cached opponents" % cached_opponents.size())
	opponents_loaded.emit(cached_opponents)

func _on_defense_uploaded(success: bool) -> void:
	defense_updated.emit(success)

func _on_leaderboard_fetched(entries: Array) -> void:
	leaderboard_loaded.emit(entries)

func _on_player_stats_updated(success: bool) -> void:
	if not success:
		push_warning("[ArenaManager] Failed to update player stats in Firebase")

# ==============================================================================
# SAVE / LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get data for saving"""
	return {
		"elo": player_elo,
		"rank": player_rank,
		"league": player_league,
		"wins": wins,
		"losses": losses,
		"defense_wins": defense_wins,
		"defense_losses": defense_losses,
		"total_games": total_games,
		"defense_team_ids": defense_team_ids,
		"attack_cooldowns": attack_cooldowns
	}

func load_save_data(data: Dictionary) -> void:
	"""Load saved data"""
	player_elo = data.get("elo", BASE_ELO)
	player_rank = data.get("rank", 0)
	player_league = data.get("league", "bronze")
	wins = data.get("wins", 0)
	losses = data.get("losses", 0)
	defense_wins = data.get("defense_wins", 0)
	defense_losses = data.get("defense_losses", 0)
	total_games = data.get("total_games", 0)
	# Properly convert loaded array to typed array
	var loaded_ids: Array = data.get("defense_team_ids", [])
	defense_team_ids.clear()
	for id: Variant in loaded_ids:
		defense_team_ids.append(str(id))
	attack_cooldowns = data.get("attack_cooldowns", {})

	_update_league()

func restore_defense_team_from_ids() -> void:
	"""Restore defense team references from saved god IDs"""
	var system_registry: Node = _get_system_registry()
	if not system_registry:
		return

	var collection_manager: Node = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return

	defense_team.clear()
	for god_id: String in defense_team_ids:
		var god: God = collection_manager.get_god_by_id(god_id)
		if god != null:
			defense_team.append(god)
