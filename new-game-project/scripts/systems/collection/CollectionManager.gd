# scripts/systems/collection/CollectionManager.gd
# Simple collection management - gods and equipment only (RULE 2: Single Responsibility)
extends Node
class_name CollectionManager

# Core collections (RULE 3: Data only, no logic)
var gods: Array = []  # Array[God]
var equipment: Array = []  # Array[Equipment]

# Fast lookup indices
var gods_by_id: Dictionary = {}  # god_id -> God

func _ready():
	pass

func initialize():
	"""Initialize system - called by SystemRegistry"""
	pass

## Add god to collection
func add_god(god: God) -> bool:
	if not god or has_god(god.id):
		return false
	
	gods.append(god)
	gods_by_id[god.id] = god
	
	# Emit event (RULE 4: No UI, use events)
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.god_obtained.emit(god)
		event_bus.collection_updated.emit()

	# Save changes
	var save_manager = SystemRegistry.get_instance().get_system("SaveManager")
	if save_manager:
		save_manager.save_game()

	return true

## Check if player has god
func has_god(god_id: String) -> bool:
	return gods_by_id.has(god_id)

## Remove god from collection
func remove_god(god: God) -> bool:
	if not god:
		return false

	var index = gods.find(god)
	if index == -1:
		return false

	# DEBUG: Log god removal with stack trace
	print("CollectionManager: REMOVING GOD - ", god.name, " (", god.id, ")")
	print("CollectionManager: Stack trace:")
	print_stack()

	gods.remove_at(index)
	gods_by_id.erase(god.id)

	# Emit event (RULE 4: No UI, use events)
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.collection_updated.emit()

	return true

## Get god by ID
func get_god_by_id(god_id: String) -> God:
	return gods_by_id.get(god_id, null)

## Get all gods
func get_all_gods() -> Array:
	return gods.duplicate()

## Update god in collection (for progression changes)
func update_god(god: God) -> bool:
	if not god or not gods_by_id.has(god.id):
		return false
	
	# God object is already updated by reference, just emit events
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.collection_updated.emit()
	
	return true

## Get god equipment array (for equipment system)
func get_god_equipment(god_id: String) -> Array:
	"""Get equipment array for specific god - RULE 3 compliant data access"""
	var god = get_god_by_id(god_id)
	if god and god.equipment:
		return god.equipment
	return []

## Add equipment to collection (for persistence)
func add_equipment(eq: Equipment) -> bool:
	"""Add equipment to collection for save/load persistence"""
	if not eq:
		return false

	# Check if already exists
	for existing in equipment:
		if existing.id == eq.id:
			return false

	equipment.append(eq)
	print("[CollectionManager] Added equipment: %s (total: %d)" % [eq.name, equipment.size()])

	# Emit event
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.collection_updated.emit()

	return true

## Remove equipment from collection
func remove_equipment(eq: Equipment) -> bool:
	"""Remove equipment from collection"""
	if not eq:
		return false

	var index = -1
	for i in range(equipment.size()):
		if equipment[i].id == eq.id:
			index = i
			break

	if index == -1:
		return false

	equipment.remove_at(index)
	return true

## Get all equipment
func get_all_equipment() -> Array:
	"""Get all equipment in collection"""
	return equipment.duplicate()

## Update god equipment slot (called by EquipmentInventoryManager)
func update_god_equipment(god_id: String, slot: int, equipment_item: Equipment) -> bool:
	"""Update equipment in specific slot for god - RULE 3 compliant"""
	var god = get_god_by_id(god_id)
	if not god:
		return false
	
	# Ensure god has equipment array
	if not god.equipment:
		god.equipment = []
	
	# Resize array if needed (6 equipment slots)
	while god.equipment.size() < 6:
		god.equipment.append(null)
	
	# Update equipment slot
	god.equipment[slot] = equipment_item
	
	# Emit update event
	var event_bus = SystemRegistry.get_instance().get_system("EventBus")
	if event_bus:
		event_bus.collection_updated.emit()
	
	return true

# ==============================================================================
# SAVE/LOAD - Simple data only (RULE 2: Single responsibility)
# ==============================================================================

## Get save data - called by SaveManager
func get_save_data() -> Dictionary:
	print("[CollectionManager] get_save_data() called - current gods: %d, equipment: %d" % [gods.size(), equipment.size()])

	var save_data = {
		"gods": [],
		"equipment": []
	}

	# Serialize gods using utility (RULE 3: Logic in utilities)
	for god in gods:
		save_data.gods.append(SaveLoadUtility.serialize_god(god))

	# Serialize equipment using utility
	for eq in equipment:
		save_data.equipment.append(SaveLoadUtility.serialize_equipment(eq))

	print("[CollectionManager] Serialized %d gods, %d equipment" % [save_data.gods.size(), save_data.equipment.size()])
	return save_data

## Load save data - called by SaveManager
func load_save_data(data: Dictionary):
	print("[CollectionManager] load_save_data() called")
	print("[CollectionManager] BEFORE clear: %d gods, %d equipment" % [gods.size(), equipment.size()])
	print("[CollectionManager] Input data keys: %s" % str(data.keys()))

	# Clear current data
	gods.clear()
	equipment.clear()
	gods_by_id.clear()

	# Load gods using utility (RULE 3: Logic in utilities)
	var gods_data = data.get("gods", [])
	print("[CollectionManager] Loading %d gods from save data" % gods_data.size())

	for god_data in gods_data:
		var god = SaveLoadUtility.deserialize_god(god_data)
		if god:
			# Use internal add to avoid triggering save during load
			gods.append(god)
			gods_by_id[god.id] = god
			print("[CollectionManager] Loaded god: %s" % god.name)
		else:
			print("[CollectionManager] ERROR: Failed to deserialize god")

	# Load equipment
	var equipment_data = data.get("equipment", [])
	print("[CollectionManager] Loading %d equipment from save data" % equipment_data.size())

	for eq_data in equipment_data:
		var eq = SaveLoadUtility.deserialize_equipment(eq_data)
		if eq:
			equipment.append(eq)

	print("[CollectionManager] AFTER load: %d gods, %d equipment" % [gods.size(), equipment.size()])
