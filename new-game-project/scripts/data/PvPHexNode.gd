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
# MEGA NODES (T6/T7 special objectives in 4-player maps)
# ==============================================================================
var is_mega_node: bool = false  # T6/T7 mega objectives
var passive_bonuses: Dictionary = {}  # {"garrison_xp_per_hour": 500, "garrison_power_boost": 0.1, etc.}

# ==============================================================================
# NEUTRAL DEFENDERS (For unclaimed nodes)
# ==============================================================================
var neutral_defenders: Array = []  # Serialized defender data for neutral nodes
var capture_power_required: int = 5000  # Power needed to capture neutral

# ==============================================================================
# BUILDING SYSTEM (Same as HexNode - full territory features)
# ==============================================================================
var placed_building: String = ""  # Building ID from buildings.json (empty = no building)
var building_level: int = 1  # Building upgrade level (1-5)
var is_buildable: bool = true  # Can player place a building?

# ==============================================================================
# PRODUCTION & WORKERS (Same as HexNode - full territory features)
# ==============================================================================
var garrison: Array[String] = []  # God IDs defending this node (matches HexNode)
var max_garrison: int = 4  # Maximum garrison slots
var assigned_workers: Array[String] = []  # God IDs working on tasks
var max_workers: int = 3  # Maximum worker slots (tier-based)
var active_tasks: Array[String] = []  # Task IDs in progress
var base_production: Dictionary = {}  # {"resource_id": amount_per_hour}
var available_tasks: Array[String] = []  # Task IDs available at this node type
var last_production_time: int = 0  # Unix timestamp of last production tick
var accumulated_resources: Dictionary = {}  # {"resource_id": amount} - pending resources

# ==============================================================================
# UPGRADES (Same as HexNode)
# ==============================================================================
var production_level: int = 1  # Upgrade level (1-5)
var defense_level: int = 1  # Defense upgrade level (1-5)

# ==============================================================================
# ATTACK TIMER SYSTEM (Same as HexNode)
# ==============================================================================
var attack_timer_hours: float = 8.0  # Base timer duration
var attack_timer_remaining: float = -1.0  # Current remaining seconds (-1 = inactive)
var last_attack_check_time: int = 0  # Unix timestamp of last timer update
var defense_drops: Dictionary = {}  # {"resource_id": {"min": X, "max": Y}}

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


func get_garrison_count() -> int:
	"""Get number of gods in garrison"""
	return garrison.size()


func get_worker_count() -> int:
	"""Get number of gods working"""
	return assigned_workers.size()


func has_garrison_space() -> bool:
	"""Check if there's room for more garrison"""
	return garrison.size() < max_garrison


func has_worker_space() -> bool:
	"""Check if there's room for more workers"""
	return assigned_workers.size() < max_workers


func has_building() -> bool:
	"""Check if this tile has a building placed on it"""
	return not placed_building.is_empty()


func can_place_building() -> bool:
	"""Check if a building can be placed on this tile"""
	return is_buildable and not is_spawn_node and placed_building.is_empty() and is_controlled_by_player()


# Compatibility property for HexNode duck typing
var is_special_node: bool:
	get:
		return node_type == "special" or is_objective or is_mega_node


# Current viewer UID - set by the screen to enable is_controlled_by_player()
var _current_viewer_uid: String = ""


func set_current_viewer(uid: String) -> void:
	"""Set the current viewer's UID for ownership checks"""
	_current_viewer_uid = uid


func is_controlled_by_player() -> bool:
	"""Check if current viewer controls this node (for NodeInfoPanel compat)"""
	if _current_viewer_uid.is_empty():
		return false
	return controller_uid == _current_viewer_uid


# HexNode compatibility - controller property that returns "player", "neutral", or "enemy_xxx"
var controller: String:
	get:
		if controller_uid.is_empty():
			return "neutral"
		elif _current_viewer_uid.is_empty():
			return "neutral"  # Can't determine without viewer context
		elif controller_uid == _current_viewer_uid:
			return "player"
		else:
			return "enemy_" + controller_uid


func get_garrison_combat_power(garrison_gods: Array) -> int:
	"""Get total combat power of garrison gods"""
	var total := 0
	for god in garrison_gods:
		if god and god is God:
			total += GodCalculator.get_combat_power(god)
	return total


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
		# Defense (legacy serialized format for enemy preview)
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
		# Neutral defenders
		"neutral_defenders": neutral_defenders,
		"capture_power_required": capture_power_required,
		# Building system
		"placed_building": placed_building,
		"building_level": building_level,
		"is_buildable": is_buildable,
		# Production & workers
		"garrison": Array(garrison),
		"max_garrison": max_garrison,
		"assigned_workers": Array(assigned_workers),
		"max_workers": max_workers,
		"active_tasks": active_tasks,
		"base_production": base_production,
		"available_tasks": available_tasks,
		"last_production_time": last_production_time,
		"accumulated_resources": accumulated_resources,
		"fixed_production": fixed_production,
		# Upgrades
		"production_level": production_level,
		"defense_level": defense_level,
		# Attack timer
		"attack_timer_hours": attack_timer_hours,
		"attack_timer_remaining": attack_timer_remaining,
		"last_attack_check_time": last_attack_check_time,
		"defense_drops": defense_drops
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

	# Defense (legacy serialized format)
	node.defense_team_serialized = data.get("defense_team_serialized", [])
	node.defense_power = data.get("defense_power", 0)
	var garrison_id_data: Array = data.get("garrison_god_ids", [])
	for gid in garrison_id_data:
		node.garrison_god_ids.append(str(gid))

	# Spawn protection
	node.is_spawn_node = data.get("is_spawn_node", false)
	node.is_capturable = data.get("is_capturable", true)
	node.spawn_owner_uid = data.get("spawn_owner_uid", "")

	# Cooldowns
	node.attack_cooldown_per_player = data.get("attack_cooldown_per_player", {})

	# Objectives
	node.is_objective = data.get("is_objective", false)
	node.objective_value = data.get("objective_value", 0)

	# Neutral defenders
	node.neutral_defenders = data.get("neutral_defenders", [])
	node.capture_power_required = data.get("capture_power_required", 5000)

	# Building system
	node.placed_building = data.get("placed_building", "")
	node.building_level = data.get("building_level", 1)
	node.is_buildable = data.get("is_buildable", true)

	# Production & workers
	var garrison_data: Array = data.get("garrison", [])
	for g in garrison_data:
		node.garrison.append(str(g))
	node.max_garrison = data.get("max_garrison", 4)
	var workers_data: Array = data.get("assigned_workers", [])
	for w in workers_data:
		node.assigned_workers.append(str(w))
	node.max_workers = data.get("max_workers", 3)
	var active_tasks_data: Array = data.get("active_tasks", [])
	for t in active_tasks_data:
		node.active_tasks.append(str(t))
	node.base_production = data.get("base_production", {})
	var available_tasks_data: Array = data.get("available_tasks", [])
	for t in available_tasks_data:
		node.available_tasks.append(str(t))
	node.last_production_time = data.get("last_production_time", 0)
	node.accumulated_resources = data.get("accumulated_resources", {})
	node.fixed_production = data.get("fixed_production", {})

	# Upgrades
	node.production_level = data.get("production_level", 1)
	node.defense_level = data.get("defense_level", 1)

	# Attack timer
	node.attack_timer_hours = data.get("attack_timer_hours", 8.0)
	node.attack_timer_remaining = data.get("attack_timer_remaining", -1.0)
	node.last_attack_check_time = data.get("last_attack_check_time", 0)
	node.defense_drops = data.get("defense_drops", {})

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
	# Worker slots scale with tier (same as HexNode)
	node.max_workers = mini(tier_level + 1, 5)  # T1=2, T2=3, T3=4, T4+=5
	node.max_garrison = mini(tier_level + 1, 4)  # T1=2, T2=3, T3=4, T4+=4
	return node


static func coord_to_id(coord_q: int, coord_r: int) -> String:
	"""Generate hex ID from coordinates"""
	return "hex_%d_%d" % [coord_q, coord_r]
