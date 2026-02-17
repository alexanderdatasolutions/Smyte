# scripts/data/HexNode.gd
# Data class for hex territory nodes
extends Resource
class_name HexNode

"""
HexNode.gd - Pure data class for hex territory nodes
RULE 3: NO LOGIC IN DATA CLASSES - Only properties and simple getters
RULE 1: Under 500 lines - Data only

Following CLAUDE.md architecture:
- DATA LAYER: Think database tables
- ONLY properties, NO complex methods
- Logic belongs in HexGridManager and TerritoryManager
"""

# ==============================================================================
# CORE IDENTITY
# ==============================================================================
@export var id: String = ""
@export var name: String = ""
@export var node_type: String = ""  # "blank", "special", "base" - tile type, not building
@export var tier: int = 1  # 1-4 (tile tier, determines max building tier)

# ==============================================================================
# BUILDING SYSTEM (New - player chooses what to build on blank tiles)
# ==============================================================================
@export var placed_building: String = ""  # Building ID from buildings.json (empty = no building)
@export var building_level: int = 1  # Building upgrade level (1-5)
@export var is_buildable: bool = true  # Can player place a building? (false for special nodes)
@export var is_special_node: bool = false  # Special fixed-production PvP nodes
@export var fixed_production: Dictionary = {}  # For special nodes only - bypasses building system

# ==============================================================================
# POSITION DATA
# ==============================================================================
@export var coord: HexCoord  # Position on hex grid

# ==============================================================================
# OWNERSHIP & CONTROL
# ==============================================================================
@export var controller: String = "neutral"  # "player", "neutral", "enemy_<player_id>"
@export var is_revealed: bool = false  # Has player scouted this node?
@export var is_contested: bool = false  # Currently being contested?
@export var contested_until: int = 0  # Unix timestamp when contest ends

# ==============================================================================
# COMBAT & DEFENSE
# ==============================================================================
@export var garrison: Array[String] = []  # God IDs defending this node
@export var max_garrison: int = 2  # Maximum garrison slots
@export var base_defenders: Array[String] = []  # PvE defender IDs (neutral nodes)
@export var capture_power_required: int = 5000  # Combat power needed to capture

# ==============================================================================
# ATTACK TIMER SYSTEM (Defense mechanic)
# ==============================================================================
@export var attack_timer_hours: float = 8.0  # Base timer duration (from JSON)
@export var attack_timer_remaining: float = -1.0  # Current remaining seconds (-1 = inactive)
@export var last_attack_check_time: int = 0  # Unix timestamp of last timer update
@export var defense_drops: Dictionary = {}  # {"resource_id": {"min": X, "max": Y}}
@export var is_pvp_territory: bool = false  # T4 nodes only available in PvP expansion
@export var is_capturable: bool = true  # Can this node be captured? (base = false)

# ==============================================================================
# PRODUCTION & WORKERS
# ==============================================================================
@export var assigned_workers: Array[String] = []  # God IDs working on tasks
@export var max_workers: int = 3  # Maximum worker slots
@export var active_tasks: Array[String] = []  # Task IDs in progress
@export var base_production: Dictionary = {}  # {"resource_id": amount_per_hour}
@export var available_tasks: Array[String] = []  # Task IDs available at this node type
@export var last_production_time: int = 0  # Unix timestamp of last production tick
@export var accumulated_resources: Dictionary = {}  # {"resource_id": amount} - pending resources to claim

# ==============================================================================
# UPGRADES
# ==============================================================================
@export var production_level: int = 1  # Upgrade level (1-5)
@export var defense_level: int = 1  # Defense upgrade level (1-5)

# ==============================================================================
# RAID SYSTEM
# ==============================================================================
@export var last_raid_time: int = 0  # Unix timestamp of last raid
@export var raid_cooldown: int = 0  # Unix timestamp when can raid again

# ==============================================================================
# UNLOCK REQUIREMENTS (from JSON)
# ==============================================================================
@export var unlock_requirements: Dictionary = {
	"player_level": 1
}

# ==============================================================================
# SIMPLE GETTERS ONLY - No calculation logic
# ==============================================================================

func get_display_name() -> String:
	"""Get display name with tier indication"""
	var stars = ""
	for i in range(tier):
		stars += "★"
	return "%s %s" % [name, stars]

func is_controlled_by_player() -> bool:
	"""Check if player controls this node"""
	return controller == "player"

func is_neutral() -> bool:
	"""Check if node is neutral (uncaptured)"""
	return controller == "neutral"

func is_enemy_controlled() -> bool:
	"""Check if node is controlled by enemy"""
	return controller.begins_with("enemy_")

func get_garrison_count() -> int:
	"""Get number of gods in garrison"""
	return garrison.size()

func get_garrison_combat_power(garrison_gods: Array) -> int:
	"""Get total combat power of garrison gods

	NOTE: Caller must resolve god IDs to God objects and pass them in.
	This keeps data class free of system dependencies (RULE 3).
	Uses GodCalculator.get_power_rating() for each god.

	Args:
		garrison_gods: Array of God resources corresponding to garrison IDs

	Returns:
		Total combat power (HP + Attack + Defense + Speed for all gods)
	"""
	var total = 0
	for god in garrison_gods:
		if god and god is God:
			total += GodCalculator.get_power_rating(god)
	return total

func get_worker_count() -> int:
	"""Get number of gods working"""
	return assigned_workers.size()

func has_garrison_space() -> bool:
	"""Check if there's room for more garrison"""
	return garrison.size() < max_garrison

func has_worker_space() -> bool:
	"""Check if there's room for more workers"""
	return assigned_workers.size() < max_workers

func get_node_type_display() -> String:
	"""Get human-readable node type"""
	# New building system - show building name if one is placed
	if not placed_building.is_empty():
		return placed_building.replace("_", " ").capitalize()

	# Special nodes show their name
	if is_special_node:
		return name if not name.is_empty() else "Special Node"

	# Blank tiles
	if node_type == "blank" or node_type.is_empty():
		return "Empty Tile (T%d)" % tier

	match node_type:
		"base": return "Home Base"
		"special": return "Special Node"
		"blank": return "Empty Tile"
		# Legacy types for backwards compatibility
		"resource_node": return "Resource Node"
		"forge": return "Forge"
		"shrine": return "Shrine"
		"mine": return "Mine"
		"forest": return "Forest"
		"coast": return "Coast"
		"hunting_ground": return "Hunting Ground"
		"library": return "Library"
		"temple": return "Temple"
		"fortress": return "Fortress"
		_: return "Unknown"

func has_building() -> bool:
	"""Check if this tile has a building placed on it"""
	return not placed_building.is_empty()

func can_place_building() -> bool:
	"""Check if a building can be placed on this tile"""
	return is_buildable and not is_special_node and placed_building.is_empty() and controller == "player"

func get_max_building_tier() -> int:
	"""Get the maximum building tier this tile can support (equals tile tier)"""
	return tier

func is_under_attack() -> bool:
	"""Check if attack timer has expired (defense battle needed)"""
	return attack_timer_remaining == 0.0

func needs_garrison() -> bool:
	"""Check if node needs garrison to avoid losing it"""
	return is_capturable and garrison.size() == 0 and controller == "player"

func get_attack_timer_percent() -> float:
	"""Get attack timer as percentage (1.0 = full, 0.0 = expired)"""
	if attack_timer_hours <= 0 or attack_timer_remaining < 0:
		return 1.0
	var max_seconds = attack_timer_hours * 3600.0
	return clampf(attack_timer_remaining / max_seconds, 0.0, 1.0)

func get_required_level() -> int:
	"""Get required player level from unlock requirements"""
	return unlock_requirements.get("player_level", 1)

# ==============================================================================
# SERIALIZATION
# ==============================================================================

func to_save_dict() -> Dictionary:
	"""Serialize ONLY dynamic player state for cloud/local saves.
	Static template data (name, tier, coords, base_production, etc.) is NOT saved -
	it's loaded from hex_tiles.json on startup. This reduces save size by ~90%."""
	return {
		# Core dynamic state
		"controller": controller,
		"is_revealed": is_revealed,
		"is_contested": is_contested,
		"contested_until": contested_until,
		# Player assignments
		"garrison": garrison,
		"assigned_workers": assigned_workers,
		"active_tasks": active_tasks,
		# Building state
		"placed_building": placed_building,
		"building_level": building_level,
		# Production state
		"accumulated_resources": accumulated_resources,
		"last_production_time": last_production_time,
		"production_level": production_level,
		"defense_level": defense_level,
		# Timers
		"attack_timer_remaining": attack_timer_remaining,
		"last_attack_check_time": last_attack_check_time,
		"last_raid_time": last_raid_time,
		"raid_cooldown": raid_cooldown,
	}

func has_player_modifications() -> bool:
	"""Check if node has any player-related state worth saving."""
	if controller == "player":
		return true
	if is_revealed:
		return true
	if not garrison.is_empty():
		return true
	if not assigned_workers.is_empty():
		return true
	if not placed_building.is_empty():
		return true
	if not accumulated_resources.is_empty():
		return true
	if is_contested:
		return true
	return false

func to_dict() -> Dictionary:
	"""Full serialization (used for debugging/inspection, NOT for saves)"""
	return {
		"id": id,
		"name": name,
		"node_type": node_type,
		"tier": tier,
		"coord": coord.to_dict() if coord else {"q": 0, "r": 0},
		"controller": controller,
		"is_revealed": is_revealed,
		"is_contested": is_contested,
		"contested_until": contested_until,
		"garrison": garrison,
		"max_garrison": max_garrison,
		"base_defenders": base_defenders,
		"capture_power_required": capture_power_required,
		# Attack timer system
		"attack_timer_hours": attack_timer_hours,
		"attack_timer_remaining": attack_timer_remaining,
		"last_attack_check_time": last_attack_check_time,
		"defense_drops": defense_drops,
		"is_pvp_territory": is_pvp_territory,
		"is_capturable": is_capturable,
		# Building system (new)
		"placed_building": placed_building,
		"building_level": building_level,
		"is_buildable": is_buildable,
		"is_special_node": is_special_node,
		"fixed_production": fixed_production,
		# Production
		"assigned_workers": assigned_workers,
		"max_workers": max_workers,
		"active_tasks": active_tasks,
		"base_production": base_production,
		"available_tasks": available_tasks,
		"last_production_time": last_production_time,
		"accumulated_resources": accumulated_resources,
		"production_level": production_level,
		"defense_level": defense_level,
		"last_raid_time": last_raid_time,
		"raid_cooldown": raid_cooldown,
		"unlock_requirements": unlock_requirements
	}

static func from_dict(data: Dictionary):
	"""Create HexNode from dictionary"""
	var script = load("res://scripts/data/HexNode.gd")
	var node = script.new()

	# Core identity
	node.id = data.get("id", "")
	node.name = data.get("name", "")
	node.node_type = data.get("type", "")  # JSON uses "type" not "node_type"
	node.tier = data.get("tier", 1)

	# Position
	var coord_data = data.get("coord", {"q": 0, "r": 0})
	node.coord = HexCoord.from_dict(coord_data)

	# Ownership
	node.controller = data.get("controller", "neutral")
	node.is_revealed = data.get("is_revealed", false)
	node.is_contested = data.get("is_contested", false)
	node.contested_until = data.get("contested_until", 0)

	# Combat - Convert to typed arrays
	var garrison_data = data.get("garrison", [])
	node.garrison.assign(garrison_data)
	node.max_garrison = data.get("max_garrison", 2)

	# Handle base_defenders - can be array of strings OR array of dictionaries
	var defenders_data = data.get("base_defenders", [])
	var defender_ids: Array[String] = []
	for defender in defenders_data:
		if defender is String:
			defender_ids.append(defender)
		elif defender is Dictionary:
			# Convert dictionary format {"element": "earth", "role": "basic", "name": "Earth Guardian"}
			# to just the name string for compatibility
			defender_ids.append(defender.get("name", "Unknown Guardian"))
	node.base_defenders.assign(defender_ids)
	node.capture_power_required = data.get("capture_power_required", 5000)

	# Attack timer system
	node.attack_timer_hours = data.get("attack_timer_hours", 8.0)
	node.attack_timer_remaining = data.get("attack_timer_remaining", -1.0)
	node.last_attack_check_time = data.get("last_attack_check_time", 0)
	node.defense_drops = data.get("defense_drops", {})
	node.is_pvp_territory = data.get("is_pvp_territory", false)
	node.is_capturable = data.get("is_capturable", true)

	# Building system (new)
	node.placed_building = data.get("placed_building", "")
	node.building_level = data.get("building_level", 1)
	node.is_buildable = data.get("is_buildable", true)
	node.is_special_node = data.get("is_special_node", false)
	node.fixed_production = data.get("fixed_production", {})

	# Production - Convert to typed arrays
	var workers_data = data.get("assigned_workers", [])
	node.assigned_workers.assign(workers_data)
	node.max_workers = data.get("max_workers", 3)
	var tasks_data = data.get("active_tasks", [])
	node.active_tasks.assign(tasks_data)
	node.base_production = data.get("base_production", {})
	var available_tasks_data = data.get("available_tasks", [])
	node.available_tasks.assign(available_tasks_data)
	node.last_production_time = data.get("last_production_time", 0)
	node.accumulated_resources = data.get("accumulated_resources", {})

	# Upgrades
	node.production_level = data.get("production_level", 1)
	node.defense_level = data.get("defense_level", 1)

	# Raid system
	node.last_raid_time = data.get("last_raid_time", 0)
	node.raid_cooldown = data.get("raid_cooldown", 0)

	# Unlock requirements
	node.unlock_requirements = data.get("unlock_requirements", {
		"player_level": 1
	})

	return node
