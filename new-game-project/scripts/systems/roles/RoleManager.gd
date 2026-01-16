# RoleManager.gd - Manages god roles and their effects
# Handles role loading, assignment, and role-based bonuses
extends Node
class_name RoleManager

# ==============================================================================
# SIGNALS
# ==============================================================================
signal role_assigned(god_id: String, role_id: String, is_primary: bool)
signal role_removed(god_id: String, role_id: String)
signal roles_loaded()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const ROLES_DATA_PATH = "res://data/roles.json"

# ==============================================================================
# STATE
# ==============================================================================
var _roles: Dictionary = {}  # role_id -> GodRole
var _is_loaded: bool = false

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	load_roles_from_json()

func load_roles_from_json() -> void:
	"""Load all role definitions from JSON"""
	if not FileAccess.file_exists(ROLES_DATA_PATH):
		push_error("RoleManager: Roles data file not found: " + ROLES_DATA_PATH)
		return

	var file = FileAccess.open(ROLES_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("RoleManager: Failed to open roles data file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("RoleManager: Failed to parse roles JSON: " + json.get_error_message())
		return

	var data = json.get_data()

	# Load role definitions
	if data.has("roles"):
		for role_id in data.roles:
			var role_data = data.roles[role_id]
			role_data["id"] = role_id  # Ensure ID is set
			var loaded_role = GodRole.from_dict(role_data)
			if loaded_role:
				_roles[role_id] = loaded_role

	_is_loaded = true
	roles_loaded.emit()
	print("RoleManager: Loaded %d roles" % [_roles.size()])

# ==============================================================================
# ROLE QUERIES
# ==============================================================================

func get_role(role_id: String) -> GodRole:
	"""Get a role by ID"""
	return _roles.get(role_id, null)

func get_all_roles() -> Array[GodRole]:
	"""Get all loaded roles"""
	var result: Array[GodRole] = []
	for role_ref in _roles.values():
		result.append(role_ref)
	return result

func get_role_by_type(role_type: GodRole.RoleType) -> GodRole:
	"""Get role by enum type"""
	for role_ref in _roles.values():
		if role_ref.role_type == role_type:
			return role_ref
	return null

func get_role_ids() -> Array[String]:
	"""Get all role IDs"""
	var result: Array[String] = []
	for role_id in _roles.keys():
		result.append(role_id)
	return result

# ==============================================================================
# ROLE ASSIGNMENT
# ==============================================================================

func assign_primary_role(god: God, role_id: String) -> bool:
	"""Assign a primary role to a god"""
	if not god:
		return false

	if not _roles.has(role_id):
		push_warning("RoleManager: Unknown role ID: " + role_id)
		return false

	god.primary_role = role_id
	role_assigned.emit(god.id, role_id, true)
	return true

func assign_secondary_role(god: God, role_id: String) -> bool:
	"""Assign a secondary role to a god"""
	if not god:
		return false

	if not _roles.has(role_id):
		push_warning("RoleManager: Unknown role ID: " + role_id)
		return false

	# Can't have same primary and secondary
	if god.primary_role == role_id:
		push_warning("RoleManager: Cannot assign same role as primary and secondary")
		return false

	god.secondary_role = role_id
	role_assigned.emit(god.id, role_id, false)
	return true

func remove_secondary_role(god: God) -> bool:
	"""Remove secondary role from a god"""
	if not god:
		return false

	if god.secondary_role.is_empty():
		return false

	var old_role = god.secondary_role
	god.secondary_role = ""
	role_removed.emit(god.id, old_role)
	return true

func get_god_roles(god: God) -> Array[GodRole]:
	"""Get all roles assigned to a god (primary + secondary)"""
	var result: Array[GodRole] = []

	if not god:
		return result

	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		result.append(_roles[god.primary_role])

	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		result.append(_roles[god.secondary_role])

	return result

# ==============================================================================
# BONUS CALCULATIONS
# ==============================================================================

func get_stat_bonus_for_god(god: God, stat_name: String) -> float:
	"""Calculate total stat bonus from all roles"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		total_bonus += primary_role.get_stat_bonus(stat_name)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		total_bonus += secondary_role.get_stat_bonus(stat_name) * 0.5

	return total_bonus

func get_all_stat_bonuses_for_god(god: God) -> Dictionary:
	"""Calculate combined stat bonuses from all roles"""
	if not god:
		return {}

	var combined: Dictionary = {}

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		for stat_name in primary_role.get_all_stat_bonuses():
			if not combined.has(stat_name):
				combined[stat_name] = 0.0
			combined[stat_name] += primary_role.get_stat_bonus(stat_name)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		for stat_name in secondary_role.get_all_stat_bonuses():
			if not combined.has(stat_name):
				combined[stat_name] = 0.0
			combined[stat_name] += secondary_role.get_stat_bonus(stat_name) * 0.5

	return combined

func get_task_bonus_for_god(god: God, task_id: String) -> float:
	"""Calculate total task bonus from all roles (includes penalties)"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		total_bonus += primary_role.get_task_bonus(task_id)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		total_bonus += secondary_role.get_task_bonus(task_id) * 0.5

	return total_bonus

func get_resource_bonus_for_god(god: God, resource_type: String) -> float:
	"""Calculate total resource bonus from all roles"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		total_bonus += primary_role.get_resource_bonus(resource_type)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		total_bonus += secondary_role.get_resource_bonus(resource_type) * 0.5

	return total_bonus

func get_crafting_bonus_for_god(god: God, bonus_type: String) -> float:
	"""Calculate total crafting bonus from all roles"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		total_bonus += primary_role.get_crafting_bonus(bonus_type)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		total_bonus += secondary_role.get_crafting_bonus(bonus_type) * 0.5

	return total_bonus

func get_aura_bonus_for_god(god: God, bonus_type: String) -> float:
	"""Calculate total aura bonus from all roles"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		total_bonus += primary_role.get_aura_bonus(bonus_type)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		total_bonus += secondary_role.get_aura_bonus(bonus_type) * 0.5

	return total_bonus

func get_other_bonus_for_god(god: God, bonus_type: String) -> float:
	"""Calculate total other bonus from all roles"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	# Primary role at 100%
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		total_bonus += primary_role.get_other_bonus(bonus_type)

	# Secondary role at 50%
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		total_bonus += secondary_role.get_other_bonus(bonus_type) * 0.5

	return total_bonus

# ==============================================================================
# SPECIALIZATION SUPPORT
# ==============================================================================

func get_available_specializations_for_god(god: God) -> Array[String]:
	"""Get all specialization trees available to a god based on their roles"""
	var result: Array[String] = []

	if not god:
		return result

	# Get trees from primary role
	if not god.primary_role.is_empty() and _roles.has(god.primary_role):
		var primary_role = _roles[god.primary_role]
		for tree_id in primary_role.get_specialization_trees():
			if not tree_id in result:
				result.append(tree_id)

	# Get trees from secondary role (if unlocked via progression)
	if not god.secondary_role.is_empty() and _roles.has(god.secondary_role):
		var secondary_role = _roles[god.secondary_role]
		for tree_id in secondary_role.get_specialization_trees():
			if not tree_id in result:
				result.append(tree_id)

	return result

func can_god_access_specialization(god: God, spec_tree_id: String) -> bool:
	"""Check if a god can access a specific specialization tree"""
	if not god:
		return false

	var available_trees = get_available_specializations_for_god(god)
	return spec_tree_id in available_trees

# ==============================================================================
# UTILITY
# ==============================================================================

func get_best_role_for_task(task_id: String) -> GodRole:
	"""Find the role with the highest bonus for a specific task"""
	var best_role: GodRole = null
	var best_bonus: float = -999.0

	for role_ref in _roles.values():
		var bonus = role_ref.get_task_bonus(task_id)
		if bonus > best_bonus:
			best_bonus = bonus
			best_role = role_ref

	return best_role

func get_gods_with_role(role_id: String, gods: Array) -> Array:
	"""Filter a list of gods to those with a specific primary role"""
	var result: Array = []
	for god in gods:
		if god and god.primary_role == role_id:
			result.append(god)
	return result

func is_loaded() -> bool:
	"""Check if roles have been loaded"""
	return _is_loaded
