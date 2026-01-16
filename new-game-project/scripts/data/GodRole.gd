# scripts/data/GodRole.gd
# Data class for god roles - defines primary function and progression paths
# Roles determine stat bonuses, task efficiency, and specialization options
extends Resource
class_name GodRole

enum RoleType {
	FIGHTER,
	GATHERER,
	CRAFTER,
	SCHOLAR,
	SUPPORT
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var role_type: RoleType = RoleType.FIGHTER

# Visual
@export var icon_path: String = ""

# Stat bonuses (multiplicative)
# e.g., {"attack_percent": 0.15, "defense_percent": 0.10}
@export var stat_bonuses: Dictionary = {}

# Task efficiency bonuses (multiplicative)
# e.g., {"combat": 0.20, "defense": 0.20}
@export var task_bonuses: Dictionary = {}

# Task efficiency penalties (multiplicative, negative)
# e.g., {"crafting": -0.10, "research": -0.05}
@export var task_penalties: Dictionary = {}

# Resource gathering bonuses
# e.g., {"gather_yield_percent": 0.25, "rare_chance_percent": 0.10}
@export var resource_bonuses: Dictionary = {}

# Crafting-specific bonuses
# e.g., {"quality_percent": 0.30, "masterwork_chance": 0.05}
@export var crafting_bonuses: Dictionary = {}

# Aura/territory bonuses
# e.g., {"ally_efficiency_percent": 0.15, "territory_defense_percent": 0.10}
@export var aura_bonuses: Dictionary = {}

# Other misc bonuses
# e.g., {"xp_gain_percent": 0.25, "scouting_range_percent": 0.15}
@export var other_bonuses: Dictionary = {}

# Specialization trees available to this role
# e.g., ["berserker", "guardian", "tactician", "assassin"]
@export var specialization_trees: Array[String] = []

func _init(role_id: String = "", role_name: String = ""):
	id = role_id
	name = role_name

# === STAT BONUS CALCULATIONS ===

func get_stat_bonus(stat_name: String) -> float:
	"""Get bonus multiplier for a specific stat"""
	return stat_bonuses.get(stat_name, 0.0)

func has_stat_bonus(stat_name: String) -> bool:
	"""Check if this role provides a bonus for a stat"""
	return stat_bonuses.has(stat_name)

func get_all_stat_bonuses() -> Dictionary:
	"""Get all stat bonuses"""
	return stat_bonuses.duplicate()

# === TASK EFFICIENCY ===

func get_task_bonus(task_id: String) -> float:
	"""Get bonus multiplier for a specific task (can be negative for penalties)"""
	if task_bonuses.has(task_id):
		return task_bonuses[task_id]
	if task_penalties.has(task_id):
		return task_penalties[task_id]
	return 0.0

func has_task_bonus(task_id: String) -> bool:
	"""Check if this role provides a bonus for a task"""
	return task_bonuses.has(task_id)

func has_task_penalty(task_id: String) -> bool:
	"""Check if this role has a penalty for a task"""
	return task_penalties.has(task_id)

func get_all_task_bonuses() -> Dictionary:
	"""Get all task bonuses"""
	return task_bonuses.duplicate()

func get_all_task_penalties() -> Dictionary:
	"""Get all task penalties"""
	return task_penalties.duplicate()

# === RESOURCE BONUSES ===

func get_resource_bonus(resource_type: String) -> float:
	"""Get bonus multiplier for resource gathering"""
	return resource_bonuses.get(resource_type, 0.0)

func get_all_resource_bonuses() -> Dictionary:
	"""Get all resource bonuses"""
	return resource_bonuses.duplicate()

# === CRAFTING BONUSES ===

func get_crafting_bonus(bonus_type: String) -> float:
	"""Get crafting-specific bonus"""
	return crafting_bonuses.get(bonus_type, 0.0)

func get_all_crafting_bonuses() -> Dictionary:
	"""Get all crafting bonuses"""
	return crafting_bonuses.duplicate()

# === AURA BONUSES ===

func get_aura_bonus(bonus_type: String) -> float:
	"""Get aura/territory bonus"""
	return aura_bonuses.get(bonus_type, 0.0)

func get_all_aura_bonuses() -> Dictionary:
	"""Get all aura bonuses"""
	return aura_bonuses.duplicate()

# === OTHER BONUSES ===

func get_other_bonus(bonus_type: String) -> float:
	"""Get miscellaneous bonus"""
	return other_bonuses.get(bonus_type, 0.0)

func get_all_other_bonuses() -> Dictionary:
	"""Get all other bonuses"""
	return other_bonuses.duplicate()

# === SPECIALIZATION ===

func get_specialization_trees() -> Array[String]:
	"""Get list of available specialization trees"""
	return specialization_trees.duplicate()

func has_specialization_tree(tree_id: String) -> bool:
	"""Check if a specialization tree is available"""
	return tree_id in specialization_trees

# === ENUM HELPERS ===

static func role_type_to_string(role_enum: RoleType) -> String:
	match role_enum:
		RoleType.FIGHTER: return "fighter"
		RoleType.GATHERER: return "gatherer"
		RoleType.CRAFTER: return "crafter"
		RoleType.SCHOLAR: return "scholar"
		RoleType.SUPPORT: return "support"
		_: return "unknown"

static func string_to_role_type(role_string: String) -> RoleType:
	match role_string.to_lower():
		"fighter": return RoleType.FIGHTER
		"gatherer": return RoleType.GATHERER
		"crafter": return RoleType.CRAFTER
		"scholar": return RoleType.SCHOLAR
		"support": return RoleType.SUPPORT
		_: return RoleType.FIGHTER

# === DISPLAY ===

func get_display_name() -> String:
	"""Get formatted display name"""
	return name

func get_tooltip() -> String:
	"""Get full tooltip text"""
	var tooltip = "%s\n%s\n\n" % [name, description]

	if not stat_bonuses.is_empty():
		tooltip += "Stat Bonuses:\n"
		for stat_name in stat_bonuses:
			var value = stat_bonuses[stat_name]
			var sign = "+" if value >= 0 else ""
			tooltip += "  • %s: %s%d%%\n" % [stat_name.replace("_percent", "").replace("_", " ").capitalize(), sign, int(value * 100)]

	if not task_bonuses.is_empty():
		tooltip += "\nTask Bonuses:\n"
		for task_id in task_bonuses:
			tooltip += "  • %s: +%d%%\n" % [task_id.replace("_", " ").capitalize(), int(task_bonuses[task_id] * 100)]

	if not task_penalties.is_empty():
		tooltip += "\nTask Penalties:\n"
		for task_id in task_penalties:
			tooltip += "  • %s: %d%%\n" % [task_id.replace("_", " ").capitalize(), int(task_penalties[task_id] * 100)]

	if not resource_bonuses.is_empty():
		tooltip += "\nResource Bonuses:\n"
		for bonus_name in resource_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(resource_bonuses[bonus_name] * 100)]

	if not crafting_bonuses.is_empty():
		tooltip += "\nCrafting Bonuses:\n"
		for bonus_name in crafting_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(crafting_bonuses[bonus_name] * 100)]

	if not aura_bonuses.is_empty():
		tooltip += "\nAura Effects:\n"
		for bonus_name in aura_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(aura_bonuses[bonus_name] * 100)]

	if not other_bonuses.is_empty():
		tooltip += "\nOther Bonuses:\n"
		for bonus_name in other_bonuses:
			tooltip += "  • %s: +%d%%\n" % [bonus_name.replace("_percent", "").replace("_", " ").capitalize(), int(other_bonuses[bonus_name] * 100)]

	if not specialization_trees.is_empty():
		tooltip += "\nAvailable Specializations:\n"
		for tree_id in specialization_trees:
			tooltip += "  • %s\n" % tree_id.capitalize()

	return tooltip

# === SERIALIZATION ===

func to_dict() -> Dictionary:
	"""Serialize role to dictionary"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"role_type": role_type_to_string(role_type),
		"icon_path": icon_path,
		"stat_bonuses": stat_bonuses.duplicate(),
		"task_bonuses": task_bonuses.duplicate(),
		"task_penalties": task_penalties.duplicate(),
		"resource_bonuses": resource_bonuses.duplicate(),
		"crafting_bonuses": crafting_bonuses.duplicate(),
		"aura_bonuses": aura_bonuses.duplicate(),
		"other_bonuses": other_bonuses.duplicate(),
		"specialization_trees": specialization_trees.duplicate()
	}

static func from_dict(data: Dictionary):
	"""Create role from dictionary - using load().new() pattern for Godot 4.5"""
	var script = load("res://scripts/data/GodRole.gd")
	var new_role = script.new()
	new_role.id = data.get("id", "")
	new_role.name = data.get("name", "")
	new_role.description = data.get("description", "")
	new_role.role_type = string_to_role_type(data.get("role_type", "fighter"))
	new_role.icon_path = data.get("icon", "")  # JSON uses "icon", class uses "icon_path"
	new_role.stat_bonuses = data.get("stat_bonuses", {})
	new_role.task_bonuses = data.get("task_bonuses", {})
	new_role.task_penalties = data.get("task_penalties", {})
	new_role.resource_bonuses = data.get("resource_bonuses", {})
	new_role.crafting_bonuses = data.get("crafting_bonuses", {})
	new_role.aura_bonuses = data.get("aura_bonuses", {})
	new_role.other_bonuses = data.get("other_bonuses", {})

	# Convert Array to Array[String] for specialization_trees
	var trees_array: Array[String] = []
	var trees_data = data.get("specialization_trees", [])
	for tree_element in trees_data:
		trees_array.append(str(tree_element))
	new_role.specialization_trees = trees_array

	return new_role
