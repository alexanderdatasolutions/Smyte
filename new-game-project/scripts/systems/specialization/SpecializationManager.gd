# SpecializationManager.gd - Manages god specialization tree system
# Gods can choose specializations at level 20/30/40 that enhance their abilities
# Specializations form a tree structure with roles at the root
extends Node
class_name SpecializationManager

# ==============================================================================
# SIGNALS
# ==============================================================================
signal specialization_unlocked(god_id: String, specialization_id: String)
signal specialization_path_changed(god_id: String, specialization_path: Array)
signal specializations_loaded()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const SPECIALIZATIONS_DATA_PATH = "res://data/specializations.json"
const MIN_TIER_1_LEVEL = 20
const MIN_TIER_2_LEVEL = 30
const MIN_TIER_3_LEVEL = 40

# ==============================================================================
# STATE
# ==============================================================================
var _specializations: Dictionary = {}  # spec_id -> GodSpecialization
var _god_specialization_paths: Dictionary = {}  # god_id -> [tier1_id, tier2_id, tier3_id]
var _is_loaded: bool = false

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	load_specializations_from_json()

func load_specializations_from_json() -> void:
	"""Load all specialization definitions from JSON"""
	if not FileAccess.file_exists(SPECIALIZATIONS_DATA_PATH):
		push_error("SpecializationManager: Specializations data file not found: " + SPECIALIZATIONS_DATA_PATH)
		return

	var file = FileAccess.open(SPECIALIZATIONS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("SpecializationManager: Failed to open specializations data file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("SpecializationManager: Failed to parse specializations JSON: " + json.get_error_message())
		return

	var data = json.get_data()

	# Load specialization definitions
	if data.has("specializations"):
		for spec_id in data.specializations:
			var spec_data = data.specializations[spec_id]
			spec_data["id"] = spec_id
			var spec = GodSpecialization.from_dict(spec_data)
			if spec:
				_specializations[spec_id] = spec

	_is_loaded = true
	specializations_loaded.emit()
	print("SpecializationManager: Loaded %d specializations" % _specializations.size())

# ==============================================================================
# SPECIALIZATION QUERIES
# ==============================================================================

func get_specialization(spec_id: String) -> GodSpecialization:
	"""Get a specialization by ID"""
	return _specializations.get(spec_id, null)

func get_all_specializations() -> Array[GodSpecialization]:
	"""Get all loaded specializations"""
	var result: Array[GodSpecialization] = []
	for spec in _specializations.values():
		result.append(spec)
	return result

func get_specializations_by_tier(tier_num: int) -> Array[GodSpecialization]:
	"""Get all specializations of a specific tier (1-3)"""
	var result: Array[GodSpecialization] = []
	for spec in _specializations.values():
		if spec.tier == tier_num:
			result.append(spec)
	return result

func get_specializations_by_role(role_id: String) -> Array[GodSpecialization]:
	"""Get all specializations for a specific role"""
	var result: Array[GodSpecialization] = []
	for spec in _specializations.values():
		if spec.role_required == role_id:
			result.append(spec)
	return result

func get_root_specializations(role_id: String = "") -> Array[GodSpecialization]:
	"""Get all tier 1 specializations, optionally filtered by role"""
	var result: Array[GodSpecialization] = []
	for spec in _specializations.values():
		if spec.is_root():
			if role_id == "" or spec.role_required == role_id:
				result.append(spec)
	return result

func get_children_specializations(parent_id: String) -> Array[GodSpecialization]:
	"""Get all child specializations of a parent"""
	var parent_spec = get_specialization(parent_id)
	if not parent_spec:
		return []

	var result: Array[GodSpecialization] = []
	for child_id in parent_spec.get_children_ids():
		var child = get_specialization(child_id)
		if child:
			result.append(child)
	return result

# ==============================================================================
# GOD SPECIALIZATION PATH
# ==============================================================================

func get_god_specialization_path(god_id: String) -> Array:
	"""Get a god's full specialization path [tier1_id, tier2_id, tier3_id]"""
	return _god_specialization_paths.get(god_id, [])

func get_god_current_specialization(god_id: String) -> String:
	"""Get the most advanced specialization a god has"""
	var path = get_god_specialization_path(god_id)
	if path.is_empty():
		return ""
	# Return the last non-empty entry
	for i in range(path.size() - 1, -1, -1):
		if path[i] != "":
			return path[i]
	return ""

func get_god_tier_specialization(god_id: String, tier_num: int) -> String:
	"""Get the specialization for a specific tier (1-3)"""
	var path = get_god_specialization_path(god_id)
	if tier_num < 1 or tier_num > 3:
		return ""
	var index = tier_num - 1
	if index < path.size():
		return path[index]
	return ""

func has_specialization(god_id: String) -> bool:
	"""Check if a god has chosen any specialization"""
	return not get_god_specialization_path(god_id).is_empty()

func get_god_specialization_tier(god_id: String) -> int:
	"""Get the highest tier a god has specialized to (0-3)"""
	var path = get_god_specialization_path(god_id)
	if path.is_empty():
		return 0
	for i in range(path.size() - 1, -1, -1):
		if path[i] != "":
			return i + 1
	return 0

# ==============================================================================
# SPECIALIZATION ELIGIBILITY
# ==============================================================================

func can_god_unlock_specialization(god: God, spec_id: String) -> bool:
	"""Check if a god meets all requirements to unlock a specialization"""
	if not god:
		return false

	var spec = get_specialization(spec_id)
	if not spec:
		return false

	# Check level requirement
	if god.level < spec.level_required:
		return false

	# Check role requirement (assume god has primary_role field - will be added in P5-01)
	if spec.role_required != "" and god.get("primary_role") != spec.role_required:
		return false

	# Check trait requirements (assume god has trait_ids field)
	var god_trait_ids = god.get("trait_ids", [])
	if not spec.meets_trait_requirements(god_trait_ids):
		return false

	# Check parent requirement (must have parent specialization if not root)
	if spec.has_parent():
		var parent_id = spec.get_parent_id()
		var god_path = get_god_specialization_path(god.id)
		var parent_tier = spec.tier - 1
		var has_parent_spec = false

		if parent_tier >= 1 and parent_tier <= 3:
			var index = parent_tier - 1
			if index < god_path.size() and god_path[index] == parent_id:
				has_parent_spec = true

		if not has_parent_spec:
			return false

	# Check if god already has a different specialization at this tier
	var current_tier_spec = get_god_tier_specialization(god.id, spec.tier)
	if current_tier_spec != "" and current_tier_spec != spec_id:
		return false

	return true

func get_available_specializations_for_god(god: God) -> Array[GodSpecialization]:
	"""Get all specializations a god can currently unlock"""
	var result: Array[GodSpecialization] = []

	if not god:
		return result

	# Determine which tier the god can unlock next
	var current_tier = get_god_specialization_tier(god.id)
	var next_tier = current_tier + 1

	if next_tier > 3:
		return result  # Already at max tier

	# Check level requirements for tier
	var min_level = MIN_TIER_1_LEVEL
	if next_tier == 2:
		min_level = MIN_TIER_2_LEVEL
	elif next_tier == 3:
		min_level = MIN_TIER_3_LEVEL

	if god.level < min_level:
		return result

	# Get candidates
	var candidates: Array[GodSpecialization] = []

	if next_tier == 1:
		# Tier 1: All root specializations for god's role
		var god_role = god.get("primary_role", "")
		candidates = get_root_specializations(god_role)
	else:
		# Tier 2/3: Children of current specialization
		var parent_tier = next_tier - 1
		var parent_id = get_god_tier_specialization(god.id, parent_tier)
		if parent_id != "":
			candidates = get_children_specializations(parent_id)

	# Filter by eligibility
	for spec in candidates:
		if can_god_unlock_specialization(god, spec.id):
			result.append(spec)

	return result

func can_god_specialize(god: God) -> bool:
	"""Check if a god is eligible to choose any specialization"""
	if not god:
		return false

	return get_available_specializations_for_god(god).size() > 0

# ==============================================================================
# SPECIALIZATION ASSIGNMENT
# ==============================================================================

func unlock_specialization(god: God, specialization_id: String) -> bool:
	"""Unlock a specialization for a god (assumes costs already paid)"""
	if not god:
		push_warning("SpecializationManager: Cannot specialize null god")
		return false

	var spec = get_specialization(specialization_id)
	if not spec:
		push_warning("SpecializationManager: Unknown specialization ID: " + specialization_id)
		return false

	# Check eligibility
	if not can_god_unlock_specialization(god, specialization_id):
		push_warning("SpecializationManager: God is not eligible for this specialization")
		return false

	# Update god's specialization path
	var path = get_god_specialization_path(god.id)

	# Ensure path array is the right size
	while path.size() < 3:
		path.append("")

	# Set the specialization at the appropriate tier
	var tier_index = spec.tier - 1
	path[tier_index] = specialization_id

	_god_specialization_paths[god.id] = path

	specialization_unlocked.emit(god.id, specialization_id)
	specialization_path_changed.emit(god.id, path)
	return true

func reset_specialization_path(god: God) -> bool:
	"""Remove all specializations from a god (may require special item in game)"""
	if not god:
		return false

	if not _god_specialization_paths.has(god.id):
		return false

	_god_specialization_paths.erase(god.id)
	specialization_path_changed.emit(god.id, [])
	return true

func reset_specialization_tier(god: God, tier_num: int) -> bool:
	"""Reset a specific tier and all higher tiers"""
	if not god or tier_num < 1 or tier_num > 3:
		return false

	var path = get_god_specialization_path(god.id)
	if path.is_empty():
		return false

	# Clear this tier and all higher tiers
	for i in range(tier_num - 1, 3):
		if i < path.size():
			path[i] = ""

	# Clean up trailing empty strings
	while not path.is_empty() and path[path.size() - 1] == "":
		path.pop_back()

	if path.is_empty():
		_god_specialization_paths.erase(god.id)
	else:
		_god_specialization_paths[god.id] = path

	specialization_path_changed.emit(god.id, path)
	return true

# ==============================================================================
# BONUS CALCULATIONS
# ==============================================================================

func get_total_stat_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined stat bonuses from all specializations in path"""
	var total_bonuses: Dictionary = {}

	if not god:
		return total_bonuses

	var path = get_god_specialization_path(god.id)
	for spec_id in path:
		if spec_id == "":
			continue

		var spec = get_specialization(spec_id)
		if not spec:
			continue

		var bonuses = spec.get_all_stat_bonuses()
		for stat_name in bonuses:
			var value = bonuses[stat_name]

			# Handle boolean bonuses (just take true if any spec grants it)
			if typeof(value) == TYPE_BOOL:
				if value:
					total_bonuses[stat_name] = true
			else:
				# Numeric bonuses stack additively
				total_bonuses[stat_name] = total_bonuses.get(stat_name, 0.0) + value

	return total_bonuses

func get_total_task_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined task bonuses from all specializations"""
	return _get_combined_bonuses(god, "task")

func get_total_resource_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined resource bonuses from all specializations"""
	return _get_combined_bonuses(god, "resource")

func get_total_crafting_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined crafting bonuses from all specializations"""
	return _get_combined_bonuses(god, "crafting")

func get_total_research_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined research bonuses from all specializations"""
	return _get_combined_bonuses(god, "research")

func get_total_combat_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined combat bonuses from all specializations"""
	return _get_combined_bonuses(god, "combat")

func get_total_aura_bonuses_for_god(god: God) -> Dictionary:
	"""Get combined aura bonuses from all specializations"""
	return _get_combined_bonuses(god, "aura")

func _get_combined_bonuses(god: God, bonus_type: String) -> Dictionary:
	"""Helper to combine bonuses of a specific type"""
	var total_bonuses: Dictionary = {}

	if not god:
		return total_bonuses

	var path = get_god_specialization_path(god.id)
	for spec_id in path:
		if spec_id == "":
			continue

		var spec = get_specialization(spec_id)
		if not spec:
			continue

		var bonuses: Dictionary = {}
		match bonus_type:
			"task":
				bonuses = spec.get_all_task_bonuses()
			"resource":
				bonuses = spec.get_all_resource_bonuses()
			"crafting":
				bonuses = spec.get_all_crafting_bonuses()
			"research":
				bonuses = spec.get_all_research_bonuses()
			"combat":
				bonuses = spec.get_all_combat_bonuses()
			"aura":
				bonuses = spec.get_all_aura_bonuses()

		for bonus_name in bonuses:
			total_bonuses[bonus_name] = total_bonuses.get(bonus_name, 0.0) + bonuses[bonus_name]

	return total_bonuses

func get_task_bonus(god: God, task_id: String) -> float:
	"""Get specific task bonus from god's specialization path"""
	var bonuses = get_total_task_bonuses_for_god(god)
	return bonuses.get(task_id, 0.0)

func get_unlocked_abilities_for_god(god: God) -> Array[String]:
	"""Get all abilities unlocked by god's specialization path"""
	var result: Array[String] = []

	if not god:
		return result

	var path = get_god_specialization_path(god.id)
	for spec_id in path:
		if spec_id == "":
			continue

		var spec = get_specialization(spec_id)
		if not spec:
			continue

		result.append_array(spec.get_unlocked_abilities())

	return result

func get_enhanced_abilities_for_god(god: God) -> Dictionary:
	"""Get all enhanced abilities from god's specialization path"""
	var result: Dictionary = {}

	if not god:
		return result

	var path = get_god_specialization_path(god.id)
	for spec_id in path:
		if spec_id == "":
			continue

		var spec = get_specialization(spec_id)
		if not spec:
			continue

		var enhanced = spec.get_enhanced_abilities()
		for ability_id in enhanced:
			# Stack enhancement levels
			result[ability_id] = result.get(ability_id, 0) + enhanced[ability_id]

	return result

# ==============================================================================
# UTILITY
# ==============================================================================

func is_loaded() -> bool:
	"""Check if specializations have been loaded"""
	return _is_loaded

func get_specialization_count() -> int:
	"""Get total number of loaded specializations"""
	return _specializations.size()

func get_tier_count(tier_num: int) -> int:
	"""Get number of specializations at a specific tier"""
	return get_specializations_by_tier(tier_num).size()

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get data for saving"""
	return {
		"god_specialization_paths": _god_specialization_paths.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	"""Load saved data"""
	if data.has("god_specialization_paths"):
		_god_specialization_paths = data.god_specialization_paths.duplicate(true)
