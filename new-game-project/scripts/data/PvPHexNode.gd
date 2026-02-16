# scripts/data/PvPHexNode.gd
# Data class for PvP multiplayer hex territory nodes
extends RefCounted
class_name PvPHexNode

"""
PvPHexNode.gd - Data class for multiplayer PvP hex territories
RULE 3: NO LOGIC IN DATA CLASSES - Only properties and simple getters
RULE 1: Under 500 lines - Data only

Differences from HexNode:
- controller_uid (Firebase UID) instead of "player"/"neutral"/"enemy"
- Per-hex defense team storage (serialized gods)
- Per-player attack cooldowns
- Spawn node protection
- No building system (PvP uses fixed node types)
"""

# ==============================================================================
# CORE IDENTITY
# ==============================================================================
var id: String = ""
var name: String = ""
var node_type: String = ""  # "blank", "special", "spawn", "objective"
var tier: int = 1  # 1-4

# ==============================================================================
# POSITION DATA
# ==============================================================================
var coord: HexCoord = null

# ==============================================================================
# MULTIPLAYER OWNERSHIP
# ==============================================================================
var controller_uid: String = ""  # Firebase user ID (empty = neutral)
var controller_display_name: String = ""  # Cached display name for UI
var last_captured_at: int = 0  # Unix timestamp of last capture
var total_captures: int = 0  # How many times this hex has been captured

# ==============================================================================
# DEFENSE SYSTEM (Per-hex defense teams)
# ==============================================================================
var defense_team_serialized: Array = []  # Serialized god data (ArenaManager format)
var defense_power: int = 0  # Cached combat power for UI display
var garrison_god_ids: Array[String] = []  # God IDs for save/load reference

# ==============================================================================
# SPAWN NODE PROTECTION
# ==============================================================================
var is_spawn_node: bool = false  # Spawn nodes have special protection rules
var is_capturable: bool = true  # Can this node be captured?
var spawn_owner_uid: String = ""  # Original spawn owner (for respawn tracking)

# ==============================================================================
# ATTACK COOLDOWNS (Per-attacker)
# ==============================================================================
var attack_cooldown_per_player: Dictionary = {}  # {uid: unix_timestamp}

# ==============================================================================
# OBJECTIVE NODES (Center high-value targets)
# ==============================================================================
var is_objective: bool = false  # Center ring objectives
var objective_value: int = 0  # Points for controlling this objective
var fixed_production: Dictionary = {}  # {"resource_id": amount_per_hour}

# ==============================================================================
# NEUTRAL DEFENDERS (For unclaimed nodes)
# ==============================================================================
var neutral_defenders: Array = []  # Serialized defender data for neutral nodes
var capture_power_required: int = 5000  # Power needed to capture neutral

# ==============================================================================
# SIMPLE GETTERS ONLY - No calculation logic
# ==============================================================================

func get_display_name() -> String:
	"""Get display name with tier indication"""
	var stars := ""
	for i in range(tier):
		stars += "★"
	return "%s %s" % [name, stars]


func is_neutral() -> bool:
	"""Check if node has no player controller"""
	return controller_uid.is_empty()


func is_owned_by(uid: String) -> bool:
	"""Check if specific player owns this node"""
	return controller_uid == uid


func get_defense_team_size() -> int:
	"""Get number of gods in defense team"""
	return defense_team_serialized.size()


func has_defense_team() -> bool:
	"""Check if a defense team is set"""
	return not defense_team_serialized.is_empty()


func can_be_attacked() -> bool:
	"""Check if this node can be attacked"""
	if is_spawn_node and not is_capturable:
		return false
	return not is_neutral()


func get_node_type_display() -> String:
	"""Get human-readable node type"""
	match node_type:
		"spawn": return "Spawn Point"
		"objective": return "Objective"
		"special": return name if not name.is_empty() else "Special Node"
		"blank": return "Territory (T%d)" % tier
		_: return "Territory"


func is_on_cooldown_for(attacker_uid: String) -> bool:
	"""Check if specific attacker is on cooldown"""
	if not attack_cooldown_per_player.has(attacker_uid):
		return false
	var cooldown_until: int = attack_cooldown_per_player[attacker_uid]
	return Time.get_unix_time_from_system() < cooldown_until


func get_cooldown_remaining_for(attacker_uid: String) -> float:
	"""Get remaining cooldown seconds for specific attacker"""
	if not attack_cooldown_per_player.has(attacker_uid):
		return 0.0
	var cooldown_until: int = attack_cooldown_per_player[attacker_uid]
	var remaining := float(cooldown_until) - Time.get_unix_time_from_system()
	return maxf(0.0, remaining)


func set_attack_cooldown(attacker_uid: String, cooldown_seconds: float) -> void:
	"""Set attack cooldown for specific attacker"""
	var cooldown_until := int(Time.get_unix_time_from_system() + cooldown_seconds)
	attack_cooldown_per_player[attacker_uid] = cooldown_until


func clear_expired_cooldowns() -> void:
	"""Remove expired cooldown entries"""
	var current_time := Time.get_unix_time_from_system()
	var expired_uids: Array[String] = []
	for uid: String in attack_cooldown_per_player:
		if attack_cooldown_per_player[uid] < current_time:
			expired_uids.append(uid)
	for uid in expired_uids:
		attack_cooldown_per_player.erase(uid)


# ==============================================================================
# SERIALIZATION (For Firebase/Save)
# ==============================================================================

func to_dict() -> Dictionary:
	"""Serialize to dictionary for Firebase storage"""
	return {
		"id": id,
		"name": name,
		"node_type": node_type,
		"tier": tier,
		"coord": coord.to_dict() if coord else {"q": 0, "r": 0},
		# Ownership
		"controller_uid": controller_uid,
		"controller_display_name": controller_display_name,
		"last_captured_at": last_captured_at,
		"total_captures": total_captures,
		# Defense
		"defense_team_serialized": defense_team_serialized,
		"defense_power": defense_power,
		"garrison_god_ids": Array(garrison_god_ids),
		# Spawn protection
		"is_spawn_node": is_spawn_node,
		"is_capturable": is_capturable,
		"spawn_owner_uid": spawn_owner_uid,
		# Cooldowns
		"attack_cooldown_per_player": attack_cooldown_per_player,
		# Objectives
		"is_objective": is_objective,
		"objective_value": objective_value,
		"fixed_production": fixed_production,
		# Neutral defenders
		"neutral_defenders": neutral_defenders,
		"capture_power_required": capture_power_required
	}


static func from_dict(data: Dictionary) -> PvPHexNode:
	"""Create PvPHexNode from dictionary"""
	var node := PvPHexNode.new()

	# Core identity
	node.id = data.get("id", "")
	node.name = data.get("name", "")
	node.node_type = data.get("node_type", "blank")
	node.tier = data.get("tier", 1)

	# Position
	var coord_data: Dictionary = data.get("coord", {"q": 0, "r": 0})
	node.coord = HexCoord.from_dict(coord_data)

	# Ownership
	node.controller_uid = data.get("controller_uid", "")
	node.controller_display_name = data.get("controller_display_name", "")
	node.last_captured_at = data.get("last_captured_at", 0)
	node.total_captures = data.get("total_captures", 0)

	# Defense
	node.defense_team_serialized = data.get("defense_team_serialized", [])
	node.defense_power = data.get("defense_power", 0)
	var garrison_data: Array = data.get("garrison_god_ids", [])
	node.garrison_god_ids.assign(garrison_data)

	# Spawn protection
	node.is_spawn_node = data.get("is_spawn_node", false)
	node.is_capturable = data.get("is_capturable", true)
	node.spawn_owner_uid = data.get("spawn_owner_uid", "")

	# Cooldowns
	node.attack_cooldown_per_player = data.get("attack_cooldown_per_player", {})

	# Objectives
	node.is_objective = data.get("is_objective", false)
	node.objective_value = data.get("objective_value", 0)
	node.fixed_production = data.get("fixed_production", {})

	# Neutral defenders
	node.neutral_defenders = data.get("neutral_defenders", [])
	node.capture_power_required = data.get("capture_power_required", 5000)

	return node


# ==============================================================================
# FACTORY METHODS
# ==============================================================================

static func create_spawn_node(coord_q: int, coord_r: int, owner_uid: String, owner_name: String) -> PvPHexNode:
	"""Create a protected spawn node for a player

	IMPORTANT: Uses coordinate-based ID (hex_q_r) so it properly replaces
	any existing hex at this position when added to the hexes dictionary.
	"""
	var node := PvPHexNode.new()
	node.id = coord_to_id(coord_q, coord_r)  # Use coordinate ID to replace existing hex
	node.name = "%s's Spawn" % owner_name
	node.node_type = "spawn"
	node.tier = 1
	node.coord = HexCoord.from_qr(coord_q, coord_r)
	node.controller_uid = owner_uid
	node.controller_display_name = owner_name
	node.is_spawn_node = true
	node.is_capturable = false  # Spawn nodes cannot be captured
	node.spawn_owner_uid = owner_uid
	node.last_captured_at = int(Time.get_unix_time_from_system())
	return node


static func create_objective_node(coord_q: int, coord_r: int, objective_name: String, value: int, production: Dictionary) -> PvPHexNode:
	"""Create a high-value center objective node"""
	var node := PvPHexNode.new()
	node.id = "objective_%d_%d" % [coord_q, coord_r]
	node.name = objective_name
	node.node_type = "objective"
	node.tier = 4
	node.coord = HexCoord.from_qr(coord_q, coord_r)
	node.is_objective = true
	node.objective_value = value
	node.fixed_production = production
	node.capture_power_required = 30000  # High requirement for objectives
	return node


static func create_blank_node(coord_q: int, coord_r: int, tier_level: int) -> PvPHexNode:
	"""Create a standard capturable territory node"""
	var node := PvPHexNode.new()
	node.id = "hex_%d_%d" % [coord_q, coord_r]
	node.name = "Territory"
	node.node_type = "blank"
	node.tier = tier_level
	node.coord = HexCoord.from_qr(coord_q, coord_r)
	# Capture power scales with tier
	node.capture_power_required = 2000 + (tier_level - 1) * 3000
	return node


static func coord_to_id(coord_q: int, coord_r: int) -> String:
	"""Generate hex ID from coordinates"""
	return "hex_%d_%d" % [coord_q, coord_r]
