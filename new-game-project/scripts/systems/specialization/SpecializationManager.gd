# SpecializationManager.gd - Manages god specialization paths
# At level 20+, gods can choose specializations that enhance their abilities
extends Node
class_name SpecializationManager

# ==============================================================================
# SIGNALS
# ==============================================================================
signal specialization_chosen(god_id: String, specialization_id: String)
signal specialization_reset(god_id: String)
signal specializations_loaded()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const SPECIALIZATIONS_DATA_PATH = "res://data/specializations.json"
const MIN_SPECIALIZATION_LEVEL = 20

# ==============================================================================
# STATE
# ==============================================================================
var _specializations: Dictionary = {}  # spec_id -> Specialization
var _spec_types: Dictionary = {}  # type_id -> type_data
var _god_specializations: Dictionary = {}  # god_id -> specialization_id
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
			var spec = Specialization.from_dict(spec_data)
			if spec:
				_specializations[spec_id] = spec

	# Load type definitions
	if data.has("specialization_types"):
		_spec_types = data.specialization_types.duplicate(true)

	_is_loaded = true
	specializations_loaded.emit()
	print("SpecializationManager: Loaded %d specializations" % _specializations.size())

# ==============================================================================
# SPECIALIZATION QUERIES
# ==============================================================================

func get_specialization(spec_id: String) -> Specialization:
	"""Get a specialization by ID"""
	return _specializations.get(spec_id, null)

func get_all_specializations() -> Array[Specialization]:
	"""Get all loaded specializations"""
	var result: Array[Specialization] = []
	for spec in _specializations.values():
		result.append(spec)
	return result

func get_specializations_by_type(type: Specialization.SpecializationType) -> Array[Specialization]:
	"""Get all specializations of a specific type"""
	var result: Array[Specialization] = []
	for spec in _specializations.values():
		if spec.type == type:
			result.append(spec)
	return result

func get_available_specializations_for_god(god: God) -> Array[Specialization]:
	"""Get all specializations a god is eligible for"""
	var result: Array[Specialization] = []

	if not god or god.level < MIN_SPECIALIZATION_LEVEL:
		return result

	for spec in _specializations.values():
		if spec.can_god_specialize(god):
			# Check prerequisite
			if spec.prerequisite_specialization_id != "":
				var current_spec = get_god_specialization(god.id)
				if current_spec != spec.prerequisite_specialization_id:
					continue
			result.append(spec)

	return result

# ==============================================================================
# SPECIALIZATION ASSIGNMENT
# ==============================================================================

func choose_specialization(god: God, specialization_id: String) -> bool:
	"""Assign a specialization to a god"""
	if not god:
		push_warning("SpecializationManager: Cannot specialize null god")
		return false

	var spec = get_specialization(specialization_id)
	if not spec:
		push_warning("SpecializationManager: Unknown specialization ID: " + specialization_id)
		return false

	# Check eligibility
	if not spec.can_god_specialize(god):
		push_warning("SpecializationManager: God is not eligible for this specialization")
		return false

	# Check prerequisite
	if spec.prerequisite_specialization_id != "":
		var current_spec = get_god_specialization(god.id)
		if current_spec != spec.prerequisite_specialization_id:
			push_warning("SpecializationManager: God does not have prerequisite specialization")
			return false

	# Assign the specialization
	_god_specializations[god.id] = specialization_id

	specialization_chosen.emit(god.id, specialization_id)
	return true

func reset_specialization(god: God) -> bool:
	"""Remove a god's specialization (may require special item in game)"""
	if not god:
		return false

	if not _god_specializations.has(god.id):
		return false

	_god_specializations.erase(god.id)
	specialization_reset.emit(god.id)
	return true

func get_god_specialization(god_id: String) -> String:
	"""Get a god's current specialization ID"""
	return _god_specializations.get(god_id, "")

func has_specialization(god_id: String) -> bool:
	"""Check if a god has chosen a specialization"""
	return _god_specializations.has(god_id)

# ==============================================================================
# BONUS CALCULATIONS
# ==============================================================================

func get_stat_bonuses_for_god(god: God) -> Dictionary:
	"""Get stat bonuses from god's specialization"""
	if not god:
		return {}

	var spec_id = get_god_specialization(god.id)
	if spec_id == "":
		return {}

	var spec = get_specialization(spec_id)
	if not spec:
		return {}

	return spec.stat_bonuses.duplicate()

func get_task_bonuses_for_god(god: God) -> Dictionary:
	"""Get task bonuses from god's specialization"""
	if not god:
		return {}

	var spec_id = get_god_specialization(god.id)
	if spec_id == "":
		return {}

	var spec = get_specialization(spec_id)
	if not spec:
		return {}

	return spec.task_bonuses.duplicate()

func get_task_bonus(god: God, task_id: String) -> float:
	"""Get specific task bonus from god's specialization"""
	var bonuses = get_task_bonuses_for_god(god)
	return bonuses.get(task_id, 0.0)

func get_skill_xp_bonus(god: God, skill_id: String) -> float:
	"""Get skill XP bonus from god's specialization"""
	if not god:
		return 0.0

	var spec_id = get_god_specialization(god.id)
	if spec_id == "":
		return 0.0

	var spec = get_specialization(spec_id)
	if not spec:
		return 0.0

	return spec.skill_xp_bonuses.get(skill_id, 0.0)

func get_unlocked_abilities_for_god(god: God) -> Array[String]:
	"""Get abilities unlocked by god's specialization"""
	var result: Array[String] = []

	if not god:
		return result

	var spec_id = get_god_specialization(god.id)
	if spec_id == "":
		return result

	var spec = get_specialization(spec_id)
	if not spec:
		return result

	result.append_array(spec.unlocked_ability_ids)
	return result

# ==============================================================================
# UTILITY
# ==============================================================================

func can_god_specialize(god: God) -> bool:
	"""Check if a god is eligible to choose any specialization"""
	if not god or god.level < MIN_SPECIALIZATION_LEVEL:
		return false

	# Check if already specialized (would need reset)
	if has_specialization(god.id):
		return false

	# Check if any specializations are available
	return get_available_specializations_for_god(god).size() > 0

func is_loaded() -> bool:
	"""Check if specializations have been loaded"""
	return _is_loaded

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	"""Get data for saving"""
	return {
		"god_specializations": _god_specializations.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	"""Load saved data"""
	if data.has("god_specializations"):
		_god_specializations = data.god_specializations.duplicate()
