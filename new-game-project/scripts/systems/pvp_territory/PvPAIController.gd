# scripts/systems/pvp_territory/PvPAIController.gd
# AI controller for PvP territory - makes AI players capture hexes dynamically
extends Node
class_name PvPAIController

"""
PvPAIController - Manages AI player actions in PvP territory
RULE 2: Single responsibility - AI decision making and execution
RULE 1: Under 500 lines

Features:
- Timer-based AI actions (configurable speed)
- Each AI expands towards center and towards enemies
- AI vs AI battles resolve based on team power
- Generates proper defense teams with bonuses
"""

# ==============================================================================
# SIGNALS
# ==============================================================================

signal ai_captured_hex(ai_uid: String, hex_id: String)
signal ai_battle_occurred(attacker_uid: String, defender_uid: String, hex_id: String, attacker_won: bool)
signal ai_tick_completed()

# ==============================================================================
# CONSTANTS
# ==============================================================================

const AI_TICK_INTERVAL := 3.0  # Seconds between AI actions (fast for testing)
const AI_CAPTURE_CHANCE := 0.7  # Chance an AI will try to capture each tick
const AI_VS_AI_POWER_VARIANCE := 0.2  # Random variance in power comparison
const AI_EXPANSION_PRIORITY_CENTER := 0.6  # Weight towards center hexes
const AI_EXPANSION_PRIORITY_ENEMY := 0.3  # Weight towards enemy hexes
const AI_EXPANSION_PRIORITY_NEUTRAL := 0.1  # Weight towards neutral hexes

# ==============================================================================
# STATE
# ==============================================================================

var _map_instance: PvPMapInstance = null
var _territory_manager: PvPTerritoryManager = null
var _ai_timer: Timer = null
var _is_active: bool = false
var _player_uid: String = ""  # The human player's UID (don't control this one)

# AI player data
var _ai_players: Array[Dictionary] = []  # {uid, name, team_power, aggression}

# Team generation
var _god_database: Array = []  # Available gods for AI teams
var _equipment_pool: Array = []  # Available equipment for AI


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func initialize(map_instance: PvPMapInstance, territory_manager: PvPTerritoryManager, player_uid: String) -> void:
	"""Initialize AI controller with map and player references"""
	_map_instance = map_instance
	_territory_manager = territory_manager
	_player_uid = player_uid

	# Load god database for team generation
	_load_god_database()
	_load_equipment_pool()

	# Identify AI players (everyone except the human player)
	_identify_ai_players()

	# Create timer
	_ai_timer = Timer.new()
	_ai_timer.wait_time = AI_TICK_INTERVAL
	_ai_timer.timeout.connect(_on_ai_tick)
	add_child(_ai_timer)

	print("[PvPAIController] Initialized with %d AI players" % _ai_players.size())


func _load_god_database() -> void:
	"""Load available gods for AI team generation"""
	var registry = _get_system_registry()
	if not registry:
		return

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return

	# Load from gods.json
	var gods_config: Dictionary = config_manager._load_json_file("res://data/gods.json")
	if gods_config.is_empty():
		return

	# Flatten all gods into an array
	for pantheon: String in gods_config:
		if pantheon.begins_with("_"):
			continue
		var pantheon_data: Variant = gods_config[pantheon]
		if not pantheon_data is Dictionary:
			continue
		var pantheon_gods: Dictionary = pantheon_data
		for god_id: String in pantheon_gods:
			var god_entry: Variant = pantheon_gods[god_id]
			if not god_entry is Dictionary:
				continue
			var god_data: Dictionary = god_entry.duplicate()
			god_data["id"] = god_id
			god_data["pantheon"] = pantheon
			_god_database.append(god_data)

	print("[PvPAIController] Loaded %d gods for AI teams" % _god_database.size())


func _load_equipment_pool() -> void:
	"""Load available equipment for AI teams"""
	var registry = _get_system_registry()
	if not registry:
		return

	var config_manager = registry.get_system("ConfigurationManager")
	if not config_manager:
		return

	var equipment_config: Dictionary = config_manager._load_json_file("res://data/equipment.json")
	if equipment_config.is_empty():
		return

	# Flatten equipment into array
	for slot_type: String in equipment_config:
		if slot_type.begins_with("_"):
			continue
		var slot_data: Variant = equipment_config[slot_type]
		if not slot_data is Dictionary:
			continue
		var slot_items: Dictionary = slot_data
		for item_id: String in slot_items:
			var item_entry: Variant = slot_items[item_id]
			if not item_entry is Dictionary:
				continue
			var item_data: Dictionary = item_entry.duplicate()
			item_data["id"] = item_id
			item_data["slot"] = slot_type
			_equipment_pool.append(item_data)

	print("[PvPAIController] Loaded %d equipment items for AI teams" % _equipment_pool.size())


func _identify_ai_players() -> void:
	"""Identify AI players from the map"""
	_ai_players.clear()

	if not _map_instance:
		return

	for player_data: Dictionary in _map_instance.get_all_players():
		var uid: String = player_data.get("player_uid", player_data.get("uid", ""))
		if uid.is_empty() or uid == _player_uid:
			continue

		# Create AI profile with personality
		_ai_players.append({
			"uid": uid,
			"name": player_data.get("display_name", "AI Player"),
			"team_power": _calculate_ai_power(uid),
			"aggression": randf_range(0.3, 0.9),  # How likely to attack enemies vs neutrals
			"last_action_time": 0
		})

	# Shuffle for variety
	_ai_players.shuffle()


func _calculate_ai_power(ai_uid: String) -> int:
	"""Calculate AI's total power based on controlled hexes
	Uses actual defense_power which is calculated via GodCalculator"""
	var power: int = 1000  # Base power

	if not _map_instance:
		return power

	var hexes := _map_instance.get_player_hexes(ai_uid)
	for hex: PvPHexNode in hexes:
		# defense_power is now calculated using GodCalculator.get_garrison_power()
		# which includes proper team bonuses, equipment, etc.
		power += hex.defense_power
		# Small tier bonus for holding high-value territory
		power += hex.tier * 50

	return power


# ==============================================================================
# CONTROL
# ==============================================================================

func start() -> void:
	"""Start AI processing"""
	if _ai_timer and not _is_active:
		_is_active = true
		_ai_timer.start()
		print("[PvPAIController] Started - AI players will act every %.1fs" % AI_TICK_INTERVAL)


func stop() -> void:
	"""Stop AI processing"""
	if _ai_timer:
		_ai_timer.stop()
	_is_active = false
	print("[PvPAIController] Stopped")


func set_speed(interval: float) -> void:
	"""Set AI tick interval"""
	if _ai_timer:
		_ai_timer.wait_time = maxf(0.5, interval)


# ==============================================================================
# AI TICK
# ==============================================================================

func _on_ai_tick() -> void:
	"""Process one AI tick - each AI player may take an action"""
	if not _map_instance:
		return

	var actions_taken: int = 0

	for ai: Dictionary in _ai_players:
		# Random chance to act
		if randf() > AI_CAPTURE_CHANCE:
			continue

		var action_result := _process_ai_action(ai)
		if action_result:
			actions_taken += 1

	if actions_taken > 0:
		ai_tick_completed.emit()


func _process_ai_action(ai: Dictionary) -> bool:
	"""Process a single AI player's action - returns true if action taken"""
	var ai_uid: String = ai["uid"]

	# Get AI's current hexes
	var my_hexes := _map_instance.get_player_hexes(ai_uid)
	if my_hexes.is_empty():
		return false  # AI eliminated, can't act

	# Find capturable hexes (adjacent to AI's territory)
	var capturable := _get_capturable_hexes_for_ai(ai_uid, my_hexes)
	if capturable.is_empty():
		return false  # No valid targets

	# Choose target based on AI personality
	var target: PvPHexNode = _choose_target(ai, capturable)
	if not target:
		return false

	# Execute capture
	return _execute_ai_capture(ai, target)


func _get_capturable_hexes_for_ai(ai_uid: String, my_hexes: Array[PvPHexNode]) -> Array[PvPHexNode]:
	"""Get all hexes the AI can capture"""
	var capturable: Array[PvPHexNode] = []
	var checked: Dictionary = {}

	for my_hex: PvPHexNode in my_hexes:
		var adjacent := _map_instance.get_adjacent_hexes(my_hex)
		for adj: PvPHexNode in adjacent:
			if checked.has(adj.id):
				continue
			checked[adj.id] = true

			# Can't capture own hexes
			if adj.controller_uid == ai_uid:
				continue

			# Can't capture protected spawns
			if adj.is_spawn_node and not adj.is_capturable:
				continue

			capturable.append(adj)

	return capturable


func _choose_target(ai: Dictionary, capturable: Array[PvPHexNode]) -> PvPHexNode:
	"""Choose which hex to capture based on AI personality"""
	if capturable.is_empty():
		return null

	var ai_uid: String = ai["uid"]
	var aggression: float = ai["aggression"]

	# Score each hex
	var scored: Array[Dictionary] = []
	for hex: PvPHexNode in capturable:
		var score: float = 0.0

		# Distance to center (lower = higher priority)
		var dist_to_center := hex.coord.distance_to(HexCoord.new(0, 0))
		score += (10.0 - dist_to_center) * AI_EXPANSION_PRIORITY_CENTER

		# Is it an enemy hex? (higher priority if aggressive)
		if not hex.is_neutral() and hex.controller_uid != _player_uid:
			score += aggression * 5.0 * AI_EXPANSION_PRIORITY_ENEMY
		elif hex.is_neutral():
			score += AI_EXPANSION_PRIORITY_NEUTRAL * 3.0

		# Higher tier = higher value
		score += hex.tier * 0.5

		# Add some randomness
		score += randf() * 2.0

		scored.append({"hex": hex, "score": score})

	# Sort by score descending
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])

	return scored[0]["hex"]


func _execute_ai_capture(ai: Dictionary, target: PvPHexNode) -> bool:
	"""Execute an AI capture of a hex"""
	var ai_uid: String = ai["uid"]
	var ai_name: String = ai["name"]
	var old_owner: String = target.controller_uid

	# Determine if capture succeeds
	var success: bool = true

	if not target.is_neutral():
		# AI vs AI or AI vs Player - compare power
		var attacker_power: int = ai["team_power"]
		var defender_power: int = target.defense_power if target.defense_power > 0 else 500

		# Add variance
		var variance: float = randf_range(-AI_VS_AI_POWER_VARIANCE, AI_VS_AI_POWER_VARIANCE)
		var effective_attacker: float = attacker_power * (1.0 + variance)

		success = effective_attacker > defender_power

		ai_battle_occurred.emit(ai_uid, old_owner, target.id, success)
		print("[PvPAIController] %s attacks %s's %s - %s (power: %d vs %d)" % [
			ai_name,
			target.controller_display_name if not target.controller_display_name.is_empty() else "Neutral",
			target.id,
			"WIN" if success else "LOSE",
			attacker_power,
			defender_power
		])

	if success:
		# Generate defense team for the captured hex
		var defense_team := _generate_ai_defense_team(ai_uid, target.tier)
		var defense_power := _calculate_defense_power(defense_team)

		# Update hex state
		target.controller_uid = ai_uid
		target.controller_display_name = ai_name
		target.last_captured_at = int(Time.get_unix_time_from_system())
		target.total_captures += 1
		target.defense_team_serialized = defense_team
		target.defense_power = defense_power

		# Update map instance
		_map_instance.hex_captured.emit(target.id, old_owner, ai_uid)
		_map_instance.leaderboard_changed.emit()

		# Update AI power
		ai["team_power"] = _calculate_ai_power(ai_uid)

		ai_captured_hex.emit(ai_uid, target.id)
		print("[PvPAIController] %s captured %s (defense power: %d)" % [ai_name, target.id, defense_power])

	return success


# ==============================================================================
# TEAM GENERATION - Uses actual God objects for proper bonus calculation
# ==============================================================================

func _generate_ai_defense_team(ai_uid: String, tier: int) -> Array:
	"""Generate a proper defense team for an AI player's hex using actual God objects
	Returns serialized team dictionaries for Firebase storage"""
	var team_size: int = mini(tier + 1, 4)  # 2-4 gods based on tier

	if _god_database.is_empty():
		# Fallback: generate basic defenders
		return _generate_fallback_team(tier, team_size)

	# Select god template IDs for the team - try to build synergies
	var god_team := _build_god_team_with_synergies(tier, team_size)

	if god_team.is_empty():
		return _generate_fallback_team(tier, team_size)

	# Serialize the God objects for Firebase storage
	var serialized_team: Array = []
	for god: God in god_team:
		serialized_team.append(_serialize_god_for_storage(god))

	return serialized_team


func _build_god_team_with_synergies(tier: int, team_size: int) -> Array[God]:
	"""Build a team of actual God objects, trying to maximize synergies like a real player"""
	var team: Array[God] = []

	# Get available god template IDs
	var available_ids: Array[String] = []
	for god_data: Dictionary in _god_database:
		var god_id: String = god_data.get("id", "")
		if not god_id.is_empty():
			available_ids.append(god_id)

	if available_ids.is_empty():
		return team

	available_ids.shuffle()

	# Try to build a synergistic team
	# Strategy: Start with a random god, then pick gods that have synergy
	for i in range(team_size):
		var god: God = null

		if team.is_empty():
			# First god - pick randomly, prefer gods with leader skills
			god = _create_ai_god(available_ids.pop_front(), tier)
		else:
			# Try to find a god with good synergy
			god = _pick_synergistic_god(team, available_ids, tier)
			if not god:
				# No synergy options left, just pick randomly
				if not available_ids.is_empty():
					god = _create_ai_god(available_ids.pop_front(), tier)

		if god:
			team.append(god)

	return team


func _create_ai_god(template_id: String, tier: int) -> God:
	"""Create an actual God object using GodFactory, scaled for the hex tier"""
	var god: God = GodFactory.create_from_json(template_id)
	if not god:
		return null

	# Scale god level based on hex tier (like a real player would have)
	god.level = tier * 10 + randi_range(1, 10)

	# Equip some equipment (AI has gear like real players)
	_equip_ai_god(god, tier)

	return god


func _equip_ai_god(god: God, tier: int) -> void:
	"""Equip a god with tier-appropriate equipment"""
	if _equipment_pool.is_empty():
		return

	# Equipment slots in Summoners War style: 1=Weapon, 2=Armor, 3=Helm, 4=Boots, 5=Amulet, 6=Ring
	var slot_indices := [0, 1, 2, 3, 4, 5]

	for slot_idx: int in slot_indices:
		# 60-80% chance to have equipment based on tier
		var equip_chance: float = 0.4 + (tier * 0.1)
		if randf() > equip_chance:
			continue

		# Try to find valid equipment for this slot
		var slot_type: String = _get_slot_type_name(slot_idx)
		var valid_items: Array = _equipment_pool.filter(func(item: Dictionary) -> bool:
			var item_slot: String = item.get("slot", "")
			var item_tier: int = item.get("tier", 1)
			return item_slot == slot_type and item_tier <= tier + 1 and item_tier >= maxi(1, tier - 1)
		)

		if valid_items.is_empty():
			continue

		var chosen: Dictionary = valid_items[randi() % valid_items.size()]
		var equipment := _create_equipment_from_data(chosen, tier)
		if equipment:
			god.equipment[slot_idx] = equipment


func _get_slot_type_name(slot_idx: int) -> String:
	"""Map slot index to equipment slot type name"""
	match slot_idx:
		0: return "weapon"
		1: return "armor"
		2: return "helm"
		3: return "boots"
		4: return "amulet"
		5: return "ring"
		_: return "weapon"


func _create_equipment_from_data(item_data: Dictionary, tier: int) -> Equipment:
	"""Create an Equipment object from data dictionary"""
	var equipment := Equipment.new()
	equipment.id = item_data.get("id", "ai_equip_%d" % randi())
	equipment.name = item_data.get("name", "Equipment")

	# Set equipment type - both the string and enum versions
	var slot_name: String = item_data.get("slot", "weapon")
	equipment.equipment_type = slot_name  # String version
	equipment.type = Equipment.string_to_type(slot_name)  # Enum version

	# Set rarity based on tier (COMMON=0, RARE=1, EPIC=2, LEGENDARY=3, MYTHIC=4)
	equipment.rarity = mini(tier, Equipment.Rarity.LEGENDARY) as Equipment.Rarity

	# Set main stat based on slot
	var main_stat_options: Dictionary = {
		"weapon": ["attack"],
		"armor": ["defense", "hp"],
		"helm": ["hp", "defense"],
		"boots": ["speed", "hp"],
		"amulet": ["crit_damage", "attack"],
		"ring": ["crit_rate", "accuracy"]
	}
	var stat_options: Array = main_stat_options.get(slot_name, ["attack"])
	equipment.main_stat_type = stat_options[randi() % stat_options.size()]
	equipment.main_stat_base = (tier + 1) * 20 + randi_range(0, 20)
	equipment.main_stat_value = equipment.main_stat_base

	return equipment


func _pick_synergistic_god(current_team: Array[God], available_ids: Array[String], tier: int) -> God:
	"""Pick a god that has synergy with the current team"""
	var best_god: God = null
	var best_score: float = -1.0
	var best_id_index: int = -1

	# Score each available god
	for i in range(mini(available_ids.size(), 10)):  # Check up to 10 candidates
		var candidate_id: String = available_ids[i]
		var candidate: God = _create_ai_god(candidate_id, tier)
		if not candidate:
			continue

		# Use GodCalculator's synergy scoring (same as real players)
		var score: float = GodCalculator.calculate_synergy_score(candidate, current_team)

		if score > best_score:
			best_score = score
			best_god = candidate
			best_id_index = i

	# Remove chosen god from available pool
	if best_id_index >= 0:
		available_ids.remove_at(best_id_index)

	return best_god


func _serialize_god_for_storage(god: God) -> Dictionary:
	"""Serialize a God object to dictionary for Firebase storage"""
	var equipment_data: Array = []
	for i in range(god.equipment.size()):
		var eq: Variant = god.equipment[i]
		if eq and eq is Equipment:
			var typed_eq: Equipment = eq as Equipment
			equipment_data.append({
				"id": typed_eq.id,
				"name": typed_eq.name,
				"slot": i,
				"equipment_type": typed_eq.equipment_type,
				"rarity": typed_eq.rarity,
				"main_stat_type": typed_eq.main_stat_type,
				"main_stat_value": typed_eq.main_stat_value
			})
		else:
			equipment_data.append(null)

	return {
		"id": god.id,
		"template_id": god.template_id,
		"name": god.name,
		"level": god.level,
		"tier": god.tier,
		"pantheon": god.pantheon,
		"element": god.element,
		"base_hp": god.base_hp,
		"base_attack": god.base_attack,
		"base_defense": god.base_defense,
		"base_speed": god.base_speed,
		"base_crit_rate": god.base_crit_rate,
		"base_crit_damage": god.base_crit_damage,
		"is_awakened": god.is_awakened,
		"awakened_name": god.awakened_name,
		"ascension_level": god.ascension_level,
		"leader_skill": god.leader_skill,
		"equipment": equipment_data
	}


func _generate_fallback_team(tier: int, team_size: int) -> Array:
	"""Generate fallback team when god database unavailable - returns serialized format"""
	var team: Array = []
	var names := ["Guardian", "Sentinel", "Warden", "Defender"]
	var elements := [God.ElementType.FIRE, God.ElementType.WATER, God.ElementType.EARTH, God.ElementType.LIGHTNING]
	var pantheons := ["greek", "norse", "egyptian", "celtic"]

	for i in range(team_size):
		var level: int = tier * 10 + i * 2
		var is_leader: bool = (i == 0)
		var mult: float = 1.15 if is_leader else 1.0

		team.append({
			"id": "ai_defender_%d_%d_%d" % [tier, i, randi()],
			"template_id": "ai_defender",
			"name": names[i % names.size()],
			"level": level,
			"tier": mini(tier, God.TierType.LEGENDARY),
			"pantheon": pantheons[i % pantheons.size()],
			"element": elements[i % elements.size()],
			"base_hp": int((150 + tier * 50 + i * 20) * mult),
			"base_attack": int((50 + tier * 15 + i * 5) * mult),
			"base_defense": int((40 + tier * 12 + i * 4) * mult),
			"base_speed": int((50 + tier * 5 + i * 2) * mult),
			"base_crit_rate": God.DEFAULT_CRIT_RATE,
			"base_crit_damage": God.DEFAULT_CRIT_DAMAGE,
			"is_awakened": false,
			"ascension_level": 0,
			"leader_skill": {} if not is_leader else {"type": "attack", "value": 15, "area": "all"},
			"equipment": []
		})

	return team


func _calculate_defense_power(serialized_team: Array) -> int:
	"""Calculate total defense power from a serialized team
	Deserializes to God objects to use GodCalculator for proper bonus calculation"""

	# Convert serialized data back to God objects for accurate calculation
	var god_team: Array[God] = []
	for god_data: Dictionary in serialized_team:
		var god: God = _deserialize_god(god_data)
		if god:
			god_team.append(god)

	if god_team.is_empty():
		# Fallback for invalid data
		return _calculate_fallback_power(serialized_team)

	# Use GodCalculator.get_garrison_power for defense (no active leader skill in garrison)
	return GodCalculator.get_garrison_power(god_team)


func _calculate_fallback_power(team: Array) -> int:
	"""Fallback power calculation when deserialization fails"""
	var power: int = 0
	for god: Dictionary in team:
		power += god.get("base_hp", 0) / 10
		power += god.get("base_attack", 0)
		power += god.get("base_defense", 0)
		power += god.get("base_speed", 0) * 2
		power += god.get("level", 1) * 50
	return power


func _deserialize_god(data: Dictionary) -> God:
	"""Deserialize a god dictionary back to a God object"""
	var god := God.new()
	god.id = data.get("id", "deserialized_%d" % randi())
	god.template_id = data.get("template_id", data.get("id", ""))
	god.name = data.get("name", "Unknown")
	god.level = data.get("level", 1)

	# Handle tier as int or enum
	var tier_val: Variant = data.get("tier", 0)
	if tier_val is int:
		god.tier = tier_val as God.TierType
	else:
		god.tier = GodFactory.parse_tier(tier_val)

	god.pantheon = data.get("pantheon", "unknown")

	# Handle element as int or enum
	var element_val: Variant = data.get("element", 0)
	if element_val is int:
		god.element = element_val as God.ElementType
	else:
		god.element = GodFactory.parse_element(element_val)

	god.base_hp = data.get("base_hp", 100)
	god.base_attack = data.get("base_attack", 50)
	god.base_defense = data.get("base_defense", 40)
	god.base_speed = data.get("base_speed", 50)
	god.base_crit_rate = data.get("base_crit_rate", God.DEFAULT_CRIT_RATE)
	god.base_crit_damage = data.get("base_crit_damage", God.DEFAULT_CRIT_DAMAGE)
	god.is_awakened = data.get("is_awakened", false)
	god.awakened_name = data.get("awakened_name", "")
	god.ascension_level = data.get("ascension_level", 0)
	god.leader_skill = data.get("leader_skill", {})

	# Deserialize equipment
	var equipment_data: Array = data.get("equipment", [])
	for i in range(mini(equipment_data.size(), 6)):
		var eq_data: Variant = equipment_data[i]
		if eq_data and eq_data is Dictionary:
			var eq := Equipment.new()
			eq.id = eq_data.get("id", "eq_%d" % i)
			eq.name = eq_data.get("name", "Equipment")
			eq.equipment_type = eq_data.get("equipment_type", "weapon")
			eq.rarity = eq_data.get("rarity", 1)
			eq.main_stat_type = eq_data.get("main_stat_type", "attack")
			eq.main_stat_value = eq_data.get("main_stat_value", 0)
			eq.main_stat_base = eq_data.get("main_stat_value", 0)
			god.equipment[i] = eq

	return god


# ==============================================================================
# UTILITIES
# ==============================================================================

func _get_system_registry() -> Variant:
	var registry_script: Variant = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null


func get_ai_players() -> Array[Dictionary]:
	"""Get list of AI players"""
	return _ai_players


func is_active() -> bool:
	return _is_active
