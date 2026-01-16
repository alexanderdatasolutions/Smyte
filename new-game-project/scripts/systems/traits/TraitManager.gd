# TraitManager.gd - Manages god traits and their effects
# Handles trait loading, assignment, and bonus calculations
extends Node
class_name TraitManager

# ==============================================================================
# SIGNALS
# ==============================================================================
signal trait_assigned(god_id: String, trait_id: String)
signal trait_removed(god_id: String, trait_id: String)
signal traits_loaded()

# ==============================================================================
# CONSTANTS
# ==============================================================================
const TRAITS_DATA_PATH = "res://data/traits.json"
const MAX_LEARNED_TRAITS = 4  # Max traits a god can learn beyond innate

# ==============================================================================
# STATE
# ==============================================================================
var _traits: Dictionary = {}  # trait_id -> GodTrait
var _god_innate_traits: Dictionary = {}  # god_base_id -> [trait_ids]
var _is_loaded: bool = false

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	load_traits_from_json()

func load_traits_from_json() -> void:
	"""Load all trait definitions from JSON"""
	if not FileAccess.file_exists(TRAITS_DATA_PATH):
		push_error("TraitManager: Traits data file not found: " + TRAITS_DATA_PATH)
		return

	var file = FileAccess.open(TRAITS_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("TraitManager: Failed to open traits data file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("TraitManager: Failed to parse traits JSON: " + json.get_error_message())
		return

	var data = json.get_data()

	# Load trait definitions
	if data.has("traits"):
		for trait_id in data.traits:
			var trait_data = data.traits[trait_id]
			trait_data["id"] = trait_id  # Ensure ID is set
			var loaded_trait = GodTrait.from_dict(trait_data)
			if loaded_trait:
				_traits[trait_id] = loaded_trait

	# Load god innate traits mapping
	if data.has("god_innate_traits"):
		_god_innate_traits = data.god_innate_traits.duplicate(true)

	_is_loaded = true
	traits_loaded.emit()
	print("TraitManager: Loaded %d traits, %d god mappings" % [_traits.size(), _god_innate_traits.size()])

# ==============================================================================
# TRAIT QUERIES
# ==============================================================================

func get_trait(trait_id: String) -> GodTrait:
	"""Get a trait by ID"""
	return _traits.get(trait_id, null)

func get_all_traits() -> Array[GodTrait]:
	"""Get all loaded traits"""
	var result: Array[GodTrait] = []
	for t in _traits.values():
		result.append(t)
	return result

func get_traits_by_category(category: GodTrait.TraitCategory) -> Array[GodTrait]:
	"""Get all traits in a specific category"""
	var result: Array[GodTrait] = []
	for t in _traits.values():
		if t.category == category:
			result.append(t)
	return result

func get_traits_by_rarity(rarity: GodTrait.TraitRarity) -> Array[GodTrait]:
	"""Get all traits of a specific rarity"""
	var result: Array[GodTrait] = []
	for t in _traits.values():
		if t.rarity == rarity:
			result.append(t)
	return result

func get_innate_traits_for_god(god_base_id: String) -> Array[String]:
	"""Get the innate trait IDs for a god based on their base ID (e.g., 'zeus', 'hephaestus')"""
	var traits = _god_innate_traits.get(god_base_id, [])
	var result: Array[String] = []
	for trait_id in traits:
		result.append(trait_id)
	return result

# ==============================================================================
# TRAIT ASSIGNMENT
# ==============================================================================

func initialize_god_traits(god: God, god_base_id: String) -> void:
	"""Initialize a god's innate traits based on their base ID"""
	if not god:
		return

	var innate_trait_ids = get_innate_traits_for_god(god_base_id)
	god.innate_traits.clear()

	for trait_id in innate_trait_ids:
		if _traits.has(trait_id):
			god.innate_traits.append(trait_id)

func add_learned_trait(god: God, trait_id: String) -> bool:
	"""Add a learned trait to a god"""
	if not god:
		return false

	if not _traits.has(trait_id):
		push_warning("TraitManager: Unknown trait ID: " + trait_id)
		return false

	# Check if already has trait
	if god.has_trait(trait_id):
		return false

	# Check max learned traits
	if god.learned_traits.size() >= MAX_LEARNED_TRAITS:
		return false

	god.learned_traits.append(trait_id)
	trait_assigned.emit(god.id, trait_id)
	return true

func remove_learned_trait(god: God, trait_id: String) -> bool:
	"""Remove a learned trait from a god"""
	if not god:
		return false

	var idx = god.learned_traits.find(trait_id)
	if idx == -1:
		return false

	god.learned_traits.remove_at(idx)
	trait_removed.emit(god.id, trait_id)
	return true

# ==============================================================================
# BONUS CALCULATIONS
# ==============================================================================

func get_task_bonus_for_god(god: God, task_id: String) -> float:
	"""Calculate the total task bonus for a god performing a specific task"""
	if not god:
		return 0.0

	var total_bonus: float = 0.0

	for trait_id in god.get_all_traits():
		var god_trait = _traits.get(trait_id)
		if god_trait:
			total_bonus += god_trait.get_task_bonus(task_id)

	return total_bonus

func get_combat_stat_bonuses_for_god(god: God) -> Dictionary:
	"""Calculate combined combat stat bonuses from all traits"""
	if not god:
		return {}

	var combined: Dictionary = {}

	for trait_id in god.get_all_traits():
		var god_trait = _traits.get(trait_id)
		if god_trait:
			for stat in god_trait.combat_stat_bonuses:
				if not combined.has(stat):
					combined[stat] = 0.0
				combined[stat] += god_trait.combat_stat_bonuses[stat]

	return combined

func can_god_multitask(god: God) -> bool:
	"""Check if god has a multitasking trait"""
	if not god:
		return false

	for trait_id in god.get_all_traits():
		var god_trait = _traits.get(trait_id)
		if god_trait and god_trait.can_multitask():
			return true

	return false

func get_multitask_info(god: God) -> Dictionary:
	"""Get multitask count and efficiency for a god"""
	if not god:
		return {"count": 1, "efficiency": 1.0}

	var best_count: int = 1
	var best_efficiency: float = 1.0

	for trait_id in god.get_all_traits():
		var god_trait = _traits.get(trait_id)
		if god_trait and god_trait.can_multitask():
			if god_trait.multitask_count > best_count:
				best_count = god_trait.multitask_count
				best_efficiency = god_trait.multitask_efficiency

	return {"count": best_count, "efficiency": best_efficiency}

# ==============================================================================
# UTILITY
# ==============================================================================

func get_gods_with_trait(trait_id: String, gods: Array) -> Array:
	"""Filter a list of gods to those with a specific trait"""
	var result: Array = []
	for god in gods:
		if god and god.has_trait(trait_id):
			result.append(god)
	return result

func get_best_god_for_task(task_id: String, gods: Array) -> God:
	"""Find the god with the highest bonus for a specific task"""
	var best_god: God = null
	var best_bonus: float = -1.0

	for god in gods:
		if not god:
			continue
		var bonus = get_task_bonus_for_god(god, task_id)
		if bonus > best_bonus:
			best_bonus = bonus
			best_god = god

	return best_god

func is_loaded() -> bool:
	"""Check if traits have been loaded"""
	return _is_loaded
