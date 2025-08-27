# scripts/systems/collection/CollectionManager.gd
# Manages player's god and equipment collections - extracted from GameManager
class_name CollectionManager extends Node

# Collections
var gods: Array = []  # Array[God]
var equipment: Array = []  # Array[Equipment]

# Indices for fast lookups
var gods_by_id: Dictionary = {}  # god_id -> God
var gods_by_element: Dictionary = {}  # element -> Array[God]
var equipment_by_slot: Dictionary = {}  # slot -> Array[Equipment]

# Team configurations
var arena_team: Array = []  # Array[God]
var defense_team: Array = []  # Array[God]
var favorite_gods: Array = []  # Array[String] - God IDs

# Filters and sorting
enum SortType {
	LEVEL_DESC,
	LEVEL_ASC,
	ELEMENT,
	TIER,
	NAME,
	RECENTLY_OBTAINED
}

# Collection statistics
var collection_stats: Dictionary = {}

func initialize():
	"""Initialize the collection manager"""
	print("CollectionManager: Initializing...")
	
	# Initialize indices
	gods_by_element = {
		"fire": [],
		"water": [],
		"earth": [],
		"lightning": [],
		"light": [],
		"dark": []
	}
	
	equipment_by_slot = {}
	for i in range(1, 7):  # Slots 1-6
		equipment_by_slot[i] = []
	
	# Connect to events
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.god_obtained.connect(_on_god_obtained)
		event_bus.equipment_obtained.connect(_on_equipment_obtained)
		event_bus.god_level_up.connect(_on_god_level_up)
	
	_update_collection_stats()
	print("CollectionManager: Initialization complete")

# ============================================================================
# GOD COLLECTION MANAGEMENT
# ============================================================================

## Add a god to the collection
func add_god(god: God):
	if not god:
		push_error("CollectionManager: Cannot add null god")
		return
	
	# Check for duplicates
	if gods_by_id.has(god.id):
		push_warning("CollectionManager: God " + god.id + " already in collection")
		return
	
	# Add to main collection
	gods.append(god)
	
	# Update indices
	gods_by_id[god.id] = god
	var element_string = God.element_to_string(god.element)
	gods_by_element[element_string].append(god)
	
	# Update statistics
	_update_collection_stats()
	
	# Emit event
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.god_obtained.emit(god)
	
	print("CollectionManager: Added god ", god.name, " (", god.id, ") to collection")

## Remove a god from the collection
func remove_god(god: God) -> bool:
	if not god:
		return false
	
	var index = gods.find(god)
	if index == -1:
		return false
	
	# Remove from main collection
	gods.remove_at(index)
	
	# Update indices
	gods_by_id.erase(god.id)
	var element_string = God.element_to_string(god.element)
	gods_by_element[element_string].erase(god)
	
	# Remove from teams
	arena_team.erase(god)
	defense_team.erase(god)
	favorite_gods.erase(god.id)
	
	# Update statistics
	_update_collection_stats()
	
	print("CollectionManager: Removed god ", god.name, " from collection")
	return true

## Get god by ID
func get_god_by_id(god_id: String) -> God:
	return gods_by_id.get(god_id, null)

## Get all gods in the collection
func get_all_gods() -> Array:  # Array[God]
	return gods.duplicate()

## Get all gods of a specific element
func get_gods_by_element(element: String) -> Array:  # Array[God]
	return gods_by_element.get(element, []).duplicate()

## Get gods filtered by criteria
func get_gods_filtered(filter: Callable) -> Array:  # Array[God]
	return gods.filter(filter)

## Get gods sorted by specified criteria
func get_gods_sorted(sort_type: SortType) -> Array:  # Array[God]
	var sorted_gods = gods.duplicate()
	
	match sort_type:
		SortType.LEVEL_DESC:
			sorted_gods.sort_custom(func(a, b): return a.level > b.level)
		SortType.LEVEL_ASC:
			sorted_gods.sort_custom(func(a, b): return a.level < b.level)
		SortType.ELEMENT:
			sorted_gods.sort_custom(func(a, b): return a.element < b.element)
		SortType.TIER:
			sorted_gods.sort_custom(func(a, b): return _get_tier_value(God.tier_to_string(a.tier)) > _get_tier_value(God.tier_to_string(b.tier)))
		SortType.NAME:
			sorted_gods.sort_custom(func(a, b): return a.name < b.name)
	
	return sorted_gods

## Get total god count
func get_god_count() -> int:
	return gods.size()

## Get god count by element
func get_god_count_by_element(element: String) -> int:
	return gods_by_element.get(element, []).size()

# ============================================================================
# EQUIPMENT COLLECTION MANAGEMENT  
# ============================================================================

## Add equipment to the collection
func add_equipment(new_equipment: Equipment):
	if not new_equipment:
		push_error("CollectionManager: Cannot add null equipment")
		return
	
	# Add to main collection
	equipment.append(new_equipment)
	
	# Update indices
	equipment_by_slot[new_equipment.slot].append(new_equipment)
	
	# Emit event
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.equipment_obtained.emit(new_equipment)
	
	print("CollectionManager: Added equipment ", new_equipment.id, " to collection")

## Remove equipment from the collection
func remove_equipment(target_equipment: Equipment) -> bool:
	if not target_equipment:
		return false
	
	var index = equipment.find(target_equipment)
	if index == -1:
		return false
	
	# Remove from main collection
	equipment.remove_at(index)
	
	# Update indices
	equipment_by_slot[target_equipment.slot].erase(target_equipment)
	
	print("CollectionManager: Removed equipment ", target_equipment.id, " from collection")
	return true

## Get all equipment for a specific slot
func get_equipment_by_slot(slot: int) -> Array:  # Array[Equipment]
	return equipment_by_slot.get(slot, []).duplicate()

## Get equipment filtered by criteria
func get_equipment_filtered(filter: Callable) -> Array:  # Array[Equipment]
	return equipment.filter(filter)

## Get total equipment count
func get_equipment_count() -> int:
	return equipment.size()

# ============================================================================
# TEAM MANAGEMENT
# ============================================================================

## Set the arena team (for PvP battles)
func set_arena_team(team: Array):  # Array[God]
	if team.size() > 5:
		push_warning("CollectionManager: Arena team cannot exceed 5 gods")
		team = team.slice(0, 5)
	
	# Validate all gods are owned
	for god in team:
		if not gods_by_id.has(god.id):
			push_error("CollectionManager: Cannot add unowned god to arena team: " + god.id)
			return
	
	arena_team = team.duplicate()
	print("CollectionManager: Arena team updated with ", arena_team.size(), " gods")

## Get the current arena team
func get_arena_team() -> Array:  # Array[God]
	return arena_team.duplicate()

## Set the defense team (for defending against attacks)
func set_defense_team(team: Array):  # Array[God]
	if team.size() > 5:
		push_warning("CollectionManager: Defense team cannot exceed 5 gods")
		team = team.slice(0, 5)
	
	# Validate all gods are owned
	for god in team:
		if not gods_by_id.has(god.id):
			push_error("CollectionManager: Cannot add unowned god to defense team: " + god.id)
			return
	
	defense_team = team.duplicate()
	print("CollectionManager: Defense team updated with ", defense_team.size(), " gods")

## Get the current defense team
func get_defense_team() -> Array:  # Array[God]
	return defense_team.duplicate()

## Add a god to favorites
func add_favorite_god(god_id: String):
	if not gods_by_id.has(god_id):
		push_error("CollectionManager: Cannot favorite unowned god: " + god_id)
		return
	
	if not favorite_gods.has(god_id):
		favorite_gods.append(god_id)
		print("CollectionManager: Added god ", god_id, " to favorites")

## Remove a god from favorites
func remove_favorite_god(god_id: String):
	if favorite_gods.has(god_id):
		favorite_gods.erase(god_id)
		print("CollectionManager: Removed god ", god_id, " from favorites")

## Check if a god is favorited
func is_favorite_god(god_id: String) -> bool:
	return favorite_gods.has(god_id)

## Get all favorite gods
func get_favorite_gods() -> Array:  # Array[God]
	var favorites: Array = []  # Array[God]
	for god_id in favorite_gods:
		var god = get_god_by_id(god_id)
		if god:
			favorites.append(god)
	return favorites

# ============================================================================
# STATISTICS AND ANALYTICS
# ============================================================================

func _update_collection_stats():
	"""Update collection statistics"""
	collection_stats = {
		"total_gods": gods.size(),
		"total_equipment": equipment.size(),
		"gods_by_element": {},
		"gods_by_tier": {},
		"max_level_gods": 0,
		"awakened_gods": 0
	}
	
	# Count gods by element
	for element in gods_by_element:
		collection_stats.gods_by_element[element] = gods_by_element[element].size()
	
	# Count gods by tier and other stats
	var tier_counts = {}
	for god in gods:
		# Tier counting
		var tier = God.tier_to_string(god.tier) if god.tier != null else "unknown"
		tier_counts[tier] = tier_counts.get(tier, 0) + 1
		
		# Max level counting
		if god.level >= 40:  # Assuming max level is 40
			collection_stats.max_level_gods += 1
		
		# Awakened counting - check if god is awakened
		if god.is_awakened:
			collection_stats.awakened_gods += 1
	
	collection_stats.gods_by_tier = tier_counts

## Get collection statistics
func get_collection_stats() -> Dictionary:
	return collection_stats.duplicate()

## Get collection completion percentage
func get_completion_percentage() -> float:
	# Load total available gods from data
	var gods_data = JSONLoader.load_file("res://data/gods.json")
	if gods_data.is_empty():
		return 0.0
	
	var total_available = gods_data.get("gods", []).size()
	var owned = gods.size()
	
	return (float(owned) / float(total_available)) * 100.0

# ============================================================================
# SPECIALIZED QUERIES FOR UI COMPONENTS 
# ============================================================================

## Get gods available for sacrifice (not in teams, not max level, etc.)
func get_sacrificeable_gods() -> Array:  # Array[God]
	var sacrificeable = []
	for god in gods:
		# Can't sacrifice gods in current teams
		if arena_team.has(god) or defense_team.has(god):
			continue
		# Can't sacrifice favorited gods
		if favorite_gods.has(god.id):
			continue
		# Can sacrifice
		sacrificeable.append(god)
	return sacrificeable

## Get gods available for awakening (max level 5* gods)
func get_awakenable_gods() -> Array:  # Array[God]
	var awakenable = []
	for god in gods:
		# Must be max level and 5* to awaken
		if god.level >= 35 and god.tier >= God.TierType.LEGENDARY and not god.is_awakened:
			awakenable.append(god)
	return awakenable

## Get gods available for battle (not stationed, not in other teams)
func get_available_gods_for_battle() -> Array:  # Array[God]
	var available = []
	for god in gods:
		# Can't use stationed gods
		if god.stationed_territory != "":
			continue
		# Available for battle
		available.append(god)
	return available

## Get total player power (sum of all god power)
func get_total_player_power() -> int:
	var total_power = 0
	var god_calculator = SystemRegistry.get_instance().get_system("GodCalculator")
	for god in gods:
		total_power += god_calculator.calculate_total_power(god)
	return total_power

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_god_obtained(god: God):
	"""Handle god obtained event (in case it comes from other systems)"""
	if not gods_by_id.has(god.id):
		# God was obtained through another system, add it here
		gods.append(god)
		gods_by_id[god.id] = god
		gods_by_element[god.element].append(god)
		_update_collection_stats()

func _on_equipment_obtained(obtained_equipment: Equipment):
	"""Handle equipment obtained event"""
	# Equipment was obtained, make sure it's in our collection
	if not equipment.has(obtained_equipment):
		equipment.append(obtained_equipment)
		equipment_by_slot[obtained_equipment.slot].append(obtained_equipment)

func _on_god_level_up(_god: God, _new_level: int, _old_level: int):
	"""Handle god level up event"""
	_update_collection_stats()  # May affect max level count

# ============================================================================
# HELPER METHODS
# ============================================================================

func _get_tier_value(tier: String) -> int:
	"""Convert tier string to numeric value for sorting"""
	match tier.to_lower():
		"legendary": return 5
		"epic": return 4
		"rare": return 3
		"uncommon": return 2
		"common": return 1
		_: return 0

## Save collection state
func save_state() -> Dictionary:
	return {
		"gods": gods.map(func(god): return SaveLoadUtility.serialize_god(god)),
		"equipment": equipment.map(func(eq): return SaveLoadUtility.serialize_equipment(eq)),
		"arena_team": arena_team.map(func(god): return god.id),
		"defense_team": defense_team.map(func(god): return god.id),
		"favorite_gods": favorite_gods.duplicate()
	}

## Load collection state
func load_state(state: Dictionary):
	# Clear existing collections
	gods.clear()
	equipment.clear()
	gods_by_id.clear()
	for element in gods_by_element:
		gods_by_element[element].clear()
	for slot in equipment_by_slot:
		equipment_by_slot[slot].clear()
	
	# Load gods
	for god_data in state.get("gods", []):
		var god = SaveLoadUtility.deserialize_god(god_data)
		if god:
			add_god(god)
	
	# Load equipment
	for equipment_data in state.get("equipment", []):
		var eq = SaveLoadUtility.deserialize_equipment(equipment_data)
		if eq:
			add_equipment(eq)
	
	# Load teams
	var arena_team_ids = state.get("arena_team", [])
	arena_team.clear()
	for god_id in arena_team_ids:
		var god = get_god_by_id(god_id)
		if god:
			arena_team.append(god)
	
	var defense_team_ids = state.get("defense_team", [])
	defense_team.clear()
	for god_id in defense_team_ids:
		var god = get_god_by_id(god_id)
		if god:
			defense_team.append(god)
	
	favorite_gods = state.get("favorite_gods", []).duplicate()

func shutdown():
	"""Shutdown collection manager"""
	print("CollectionManager: Shutdown complete")
