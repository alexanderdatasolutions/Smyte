# scripts/systems/collection/EquipmentManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - coordinate equipment systems
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentManager

"""
Equipment Management Coordinator
Coordinates between equipment subsystems: inventory and sockets
This is the main entry point for the equipment system (like Summoners War equipment)
Note: Time-based crafting is handled by HexCraftManager in the territory system
"""

# Main equipment system signals
signal equipment_equipped(god: God, equipment: Equipment, slot: int)
signal equipment_unequipped(god: God, slot: int)
signal socket_unlocked(equipment: Equipment, socket_index: int)
signal gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary)

# Component managers for focused responsibilities
var inventory_manager: EquipmentInventoryManager
var socket_manager: EquipmentSocketManager
var stat_calculator

# Cached config
var _equipment_config: Dictionary = {}
var _max_equipment_slots: int = 6  # Default fallback

func _ready():
	"""Initialize the equipment management system"""
	setup_component_managers()
	connect_component_signals()
	load_equipment_configuration()

func setup_component_managers():
	"""Initialize all equipment component managers - RULE 2: Focused responsibilities"""
	# Create inventory manager
	inventory_manager = EquipmentInventoryManager.new()
	add_child(inventory_manager)

	# Create socket manager
	socket_manager = EquipmentSocketManager.new()
	add_child(socket_manager)

	# Create stat calculator
	stat_calculator = preload("res://scripts/systems/equipment/EquipmentStatCalculator.gd").new()
	add_child(stat_calculator)

func connect_component_signals():
	"""Connect all component manager signals"""
	# Inventory manager signals
	if inventory_manager:
		inventory_manager.equipment_equipped.connect(_on_equipment_equipped)
		inventory_manager.equipment_unequipped.connect(_on_equipment_unequipped)

	# Socket manager signals
	if socket_manager:
		socket_manager.socket_unlocked.connect(_on_socket_unlocked)
		socket_manager.gem_socketed.connect(_on_gem_socketed)

func load_equipment_configuration():
	"""Load equipment configuration through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var config_manager = system_registry.get_system("ConfigurationManager")
		if config_manager:
			_equipment_config = config_manager.get_equipment_config()
			var slots_cfg: Dictionary = _equipment_config.get("equipment_slots", {})
			_max_equipment_slots = int(slots_cfg.get("max_slots", 6))

	# Fallback: load config directly if SystemRegistry wasn't available
	if _equipment_config.is_empty():
		var file := FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				_equipment_config = parsed
				var slots_cfg: Dictionary = _equipment_config.get("equipment_slots", {})
				_max_equipment_slots = int(slots_cfg.get("max_slots", 6))

	# Load existing equipment from equipment.json
	_load_existing_equipment()

# === INVENTORY OPERATIONS ===

func add_equipment_to_inventory(equipment: Equipment):
	"""Add equipment to inventory - delegate to inventory manager"""
	if inventory_manager:
		inventory_manager.add_equipment_to_inventory(equipment)

func remove_equipment_from_inventory(equipment: Equipment) -> bool:
	"""Remove equipment from inventory - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.remove_equipment_from_inventory(equipment)
	return false

func get_equipment_by_id(equipment_id: String) -> Equipment:
	"""Find equipment by ID - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.get_equipment_by_id(equipment_id)
	return null

func get_equipped_equipment(god: God) -> Array:
	"""Get all equipment equipped by a god"""
	if god and god.equipment:
		return god.equipment
	return []

func get_unequipped_equipment() -> Array:
	"""Get all unequipped equipment - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.get_unequipped_equipment()
	return []

func equip_equipment_to_god(god: God, equipment: Equipment, slot: int) -> bool:
	"""Equip equipment to a god at specific slot"""
	if not god or not equipment:
		return false

	# Ensure god has equipment array
	if not god.equipment:
		god.equipment = []

	# Resize array if needed (slots from config)
	while god.equipment.size() < _max_equipment_slots:
		god.equipment.append(null)

	# Unequip existing equipment in this slot
	if god.equipment[slot] != null:
		var old_equipment = god.equipment[slot]
		if old_equipment is Equipment:
			old_equipment.equipped_by_god_id = ""

	# Equip new equipment - ensure it's an Equipment object
	if equipment is Equipment:
		god.equipment[slot] = equipment
		equipment.equipped_by_god_id = god.id
		equipment_equipped.emit(god, equipment, slot)
		# Also emit to EventBus for global listeners (AchievementManager, etc.)
		var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
		if event_bus:
			event_bus.equipment_equipped.emit(god, equipment, slot)
		_trigger_save()
		return true
	else:
		push_error("EquipmentManager: equipment parameter is not an Equipment object: %s" % str(typeof(equipment)))
		return false

func unequip_equipment_from_god(god: God, slot: int) -> bool:
	"""Unequip equipment from god at specific slot"""
	if not god or not god.equipment or slot >= god.equipment.size():
		return false

	var slot_content = god.equipment[slot]
	if slot_content == null:
		return false

	# Handle both Equipment objects and string IDs
	var equipment: Equipment = null
	if slot_content is Equipment:
		equipment = slot_content
	elif slot_content is String and slot_content != "":
		# If stored as string ID, find it in inventory
		if inventory_manager:
			equipment = inventory_manager.get_equipment_by_id(slot_content)

	if equipment:
		equipment.equipped_by_god_id = ""
		god.equipment[slot] = null
		equipment_unequipped.emit(god, slot)
		return true
	else:
		# Clear the slot even if we couldn't find the equipment object
		god.equipment[slot] = null
		equipment_unequipped.emit(god, slot)
		return true

func get_equipment_stats(equipment: Equipment) -> Dictionary:
	"""Calculate equipment stats"""
	return stat_calculator.get_equipment_display_info(equipment)

func get_god_total_stats(god: God) -> Dictionary:
	"""Calculate total stats for a god including all equipment bonuses - LOGIC IN SYSTEM NOT DATA"""
	return stat_calculator.calculate_god_total_stats(god)

func get_set_bonuses(god: God) -> Dictionary:
	"""Calculate set bonuses from god's equipped equipment"""
	return stat_calculator.calculate_set_bonuses(god)

func get_equipment_by_slot_type(slot_type: Equipment.EquipmentType) -> Array:
	"""Get equipment by slot type - delegate to inventory manager"""
	if inventory_manager:
		return inventory_manager.get_equipment_by_slot_type(slot_type)
	return []

func auto_equip_god(god: God) -> int:
	"""Auto-equip best available equipment to a god. Returns number of items equipped."""
	if not god:
		return 0

	var equipped_count: int = 0
	var slot_types: Array = [
		Equipment.EquipmentType.WEAPON,
		Equipment.EquipmentType.ARMOR,
		Equipment.EquipmentType.HELM,
		Equipment.EquipmentType.BOOTS,
		Equipment.EquipmentType.AMULET,
		Equipment.EquipmentType.RING
	]

	for slot_index in range(_max_equipment_slots):
		var slot_type = slot_types[slot_index]
		var best_equipment = _find_best_equipment_for_slot(god, slot_type)

		if best_equipment:
			var success = equip_equipment_to_god(god, best_equipment, slot_index)
			if success:
				equipped_count += 1

	return equipped_count

func _find_best_equipment_for_slot(_god: God, slot_type: Equipment.EquipmentType) -> Equipment:
	"""Find the best unequipped equipment for a given slot type"""
	var candidates: Array = get_unequipped_equipment().filter(func(e): return e.type == slot_type)

	if candidates.is_empty():
		return null

	# Sort by: rarity (desc), then main stat value (desc), then enhancement level (desc)
	candidates.sort_custom(func(a, b):
		# First compare rarity (higher is better)
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		# Then compare main stat value
		if a.main_stat_value != b.main_stat_value:
			return a.main_stat_value > b.main_stat_value
		# Finally compare enhancement level
		return a.enhancement_level > b.enhancement_level
	)

	return candidates[0]

# === SOCKET OPERATIONS ===

func unlock_socket(equipment: Equipment, socket_index: int) -> bool:
	"""Unlock socket - delegate to socket manager"""
	if socket_manager:
		return socket_manager.unlock_socket(equipment, socket_index)
	return false

func socket_gem(equipment: Equipment, socket_index: int, gem_id: String) -> bool:
	"""Socket gem - delegate to socket manager"""
	if socket_manager:
		return socket_manager.socket_gem(equipment, socket_index, gem_id)
	return false

func unsocket_gem(equipment: Equipment, socket_index: int) -> Dictionary:
	"""Unsocket gem - delegate to socket manager"""
	if socket_manager:
		return socket_manager.unsocket_gem(equipment, socket_index)
	return {}

func add_gem_to_inventory(gem_id: String, quantity: int = 1):
	"""Add gems to inventory - delegate to socket manager"""
	if socket_manager:
		socket_manager.add_gem_to_inventory(gem_id, quantity)

# === EVENT HANDLERS ===

func _on_equipment_equipped(god: God, equipment: Equipment, slot: int):
	"""Handle equipment equipped event"""
	equipment_equipped.emit(god, equipment, slot)
	# Also emit to EventBus for global listeners (AchievementManager, etc.)
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.equipment_equipped.emit(god, equipment, slot)
	_trigger_save()

func _on_equipment_unequipped(god: God, slot: int):
	"""Handle equipment unequipped event"""
	equipment_unequipped.emit(god, slot)
	_trigger_save()

func _on_socket_unlocked(equipment: Equipment, socket_index: int):
	"""Handle socket unlocked event"""
	socket_unlocked.emit(equipment, socket_index)
	_trigger_save()

func _on_gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary):
	"""Handle gem socketed event"""
	gem_socketed.emit(equipment, socket_index, gem)
	_trigger_save()

func _trigger_save():
	"""Trigger a game save after important equipment changes"""
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus:
		event_bus.save_requested.emit()

# === EQUIPMENT LOADING ===

func _load_existing_equipment():
	"""Load equipment from the existing equipment.json file"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var config_manager = system_registry.get_system("ConfigurationManager")
	if not config_manager:
		return

	var equipment_data = config_manager.get_equipment_config()
	if not equipment_data or not equipment_data.has("equipment"):
		return

	var equipment_items = equipment_data["equipment"]

	for equipment_id in equipment_items:
		var item_data = equipment_items[equipment_id]
		var equipment = _create_equipment_from_data(item_data)
		if equipment:
			add_equipment_to_inventory(equipment)

func _create_equipment_from_data(data: Dictionary) -> Equipment:
	"""Create an Equipment object from JSON data"""
	var equipment = Equipment.new()
	
	# Basic properties
	equipment.id = data.get("id", "")
	equipment.name = data.get("name", "Unknown Equipment")
	equipment.type = data.get("type", 0)
	equipment.rarity = data.get("rarity", 0)
	equipment.slot = data.get("slot", 1)
	equipment.level = data.get("level", 0)
	
	# Set information
	equipment.equipment_set_name = data.get("equipment_set_name", "")
	equipment.equipment_set_type = data.get("equipment_set_type", "")
	
	# Main stat
	equipment.main_stat_type = data.get("main_stat_type", "")
	equipment.main_stat_base = data.get("main_stat_base", 0)
	equipment.main_stat_value = equipment.main_stat_base
	
	# Substats
	if data.has("substats"):
		equipment.substats = data["substats"].duplicate()
	
	# Sockets
	equipment.max_sockets = data.get("max_sockets", 0)
	equipment.sockets = []
	
	# Generate empty sockets based on max_sockets
	for i in range(equipment.max_sockets):
		equipment.sockets.append({
			"type": "empty",
			"gem": null,
			"unlocked": i == 0  # First socket is always unlocked
		})
	
	return equipment

# === UTILITY METHODS ===

func get_equipment_summary() -> Dictionary:
	"""Get summary of all equipment systems"""
	var summary = {
		"inventory": {},
		"sockets": {}
	}

	if inventory_manager:
		summary.inventory = inventory_manager.get_inventory_summary()

	if socket_manager:
		summary.sockets = {
			"total_gems": socket_manager.get_gem_inventory().size()
		}

	return summary

# === SAVE/LOAD INTEGRATION ===

func get_save_data() -> Dictionary:
	"""Save all equipment data for SaveManager"""
	var data: Dictionary = {
		"inventory": [],
		"gems": []
	}

	if inventory_manager:
		for eq in inventory_manager.get_all_equipment():
			# Only save unequipped equipment - equipped items are saved with their gods
			if not eq.is_equipped:
				data.inventory.append(SaveLoadUtility.serialize_equipment(eq))

	if socket_manager:
		data.gems = socket_manager.get_gem_inventory().duplicate(true)

	return data

func load_save_data(data: Dictionary) -> void:
	"""Load all equipment data from SaveManager"""
	if data.has("inventory") and inventory_manager:
		inventory_manager.clear_inventory()
		# Load unequipped equipment from save data
		for eq_data in data.inventory:
			if eq_data is Dictionary:
				var eq: Equipment = SaveLoadUtility.deserialize_equipment(eq_data)
				if eq:
					inventory_manager.add_equipment_to_inventory(eq)

		# Also add equipped equipment from gods to inventory tracker
		# Gods are loaded before EquipmentManager, so their equipment exists
		_restore_equipped_equipment_to_inventory()

	if data.has("gems") and socket_manager:
		socket_manager.gems_inventory.clear()
		for gem_data in data.gems:
			if gem_data is Dictionary:
				socket_manager.gems_inventory.append(gem_data.duplicate())

func _restore_equipped_equipment_to_inventory() -> void:
	"""Add equipped equipment from gods to inventory tracker after load"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var collection_manager = system_registry.get_system("CollectionManager")
	if not collection_manager:
		return

	var gods: Array = collection_manager.get_all_gods()
	for god in gods:
		if not god or not god.equipment:
			continue
		for i in range(god.equipment.size()):
			var eq = god.equipment[i]
			if eq != null and eq is Equipment:
				# Ensure equipped state is set and add to inventory tracker
				eq.equipped_by_god_id = god.id
				eq.equipped_slot = i
				inventory_manager.equipment_inventory.append(eq)

# === CLEANUP ===

func _exit_tree():
	"""Clean up when equipment manager is removed"""
	# Component managers are children and will be automatically freed
	# Just ensure any remaining connections are cleared
	if inventory_manager and inventory_manager.equipment_equipped.is_connected(_on_equipment_equipped):
		inventory_manager.equipment_equipped.disconnect(_on_equipment_equipped)

	if socket_manager and socket_manager.socket_unlocked.is_connected(_on_socket_unlocked):
		socket_manager.socket_unlocked.disconnect(_on_socket_unlocked)
