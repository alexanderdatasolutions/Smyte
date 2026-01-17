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
@export var node_type: String = ""  # "mine", "forest", "coast", "hunting_ground", "forge", "library", "temple", "fortress"
@export var tier: int = 1  # 1-5 (difficulty/reward level)

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
# PRODUCTION & WORKERS
# ==============================================================================
@export var assigned_workers: Array[String] = []  # God IDs working on tasks
@export var max_workers: int = 3  # Maximum worker slots
@export var active_tasks: Array[String] = []  # Task IDs in progress
@export var base_production: Dictionary = {}  # {"resource_id": amount_per_hour}
@export var available_tasks: Array[String] = []  # Task IDs available at this node type

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
	"player_level": 1,
	"specialization_tier": 0,  # 0=none, 1=tier1, 2=tier2, 3=tier3
	"specialization_role": ""  # Empty or "fighter", "gatherer", etc.
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
	match node_type:
		"mine": return "Mine"
		"forest": return "Forest"
		"coast": return "Coast"
		"hunting_ground": return "Hunting Ground"
		"forge": return "Forge"
		"library": return "Library"
		"temple": return "Temple"
		"fortress": return "Fortress"
		_: return "Unknown"

func get_required_spec_tier() -> int:
	"""Get required specialization tier from unlock requirements"""
	return unlock_requirements.get("specialization_tier", 0)

func get_required_spec_role() -> String:
	"""Get required specialization role from unlock requirements"""
	return unlock_requirements.get("specialization_role", "")

func get_required_level() -> int:
	"""Get required player level from unlock requirements"""
	return unlock_requirements.get("player_level", 1)

# ==============================================================================
# SERIALIZATION
# ==============================================================================

func to_dict() -> Dictionary:
	"""Serialize to dictionary for saving"""
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
		"assigned_workers": assigned_workers,
		"max_workers": max_workers,
		"active_tasks": active_tasks,
		"base_production": base_production,
		"available_tasks": available_tasks,
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
	var defenders_data = data.get("base_defenders", [])
	node.base_defenders.assign(defenders_data)
	node.capture_power_required = data.get("capture_power_required", 5000)

	# Production - Convert to typed arrays
	var workers_data = data.get("assigned_workers", [])
	node.assigned_workers.assign(workers_data)
	node.max_workers = data.get("max_workers", 3)
	var tasks_data = data.get("active_tasks", [])
	node.active_tasks.assign(tasks_data)
	node.base_production = data.get("base_production", {})
	var available_tasks_data = data.get("available_tasks", [])
	node.available_tasks.assign(available_tasks_data)

	# Upgrades
	node.production_level = data.get("production_level", 1)
	node.defense_level = data.get("defense_level", 1)

	# Raid system
	node.last_raid_time = data.get("last_raid_time", 0)
	node.raid_cooldown = data.get("raid_cooldown", 0)

	# Unlock requirements
	node.unlock_requirements = data.get("unlock_requirements", {
		"player_level": 1,
		"specialization_tier": 0,
		"specialization_role": ""
	})

	return node
