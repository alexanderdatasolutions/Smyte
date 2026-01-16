# scripts/systems/collection/EquipmentSocketManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - equipment socket/gem system only
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentSocketManager

"""
Equipment Socket Management System
Handles socket unlocking, gem socketing, and gem management
Part of the equipment system (like Summoners War gems/equipment socketing)
"""

# Signals for socket events
signal socket_unlocked(equipment: Equipment, socket_index: int)
signal gem_socketed(equipment: Equipment, socket_index: int, gem: Dictionary)
signal gem_unsocketed(equipment: Equipment, socket_index: int, gem: Dictionary)
signal socket_upgrade_failed(equipment: Equipment, socket_index: int, reason: String)

# Gem inventory
var gems_inventory: Array = []  # Array[Dictionary]

# Configuration cache
var equipment_config: Dictionary = {}

func _ready():
	"""Initialize equipment socket manager"""
	load_socket_config()

func load_socket_config():
	"""Load socket configuration - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var config_manager = system_registry.get_system("ConfigurationManager")
		if config_manager:
			equipment_config = config_manager.get_equipment_config()
			return
	
	# Fallback to direct loading
	_load_config_directly()

func _load_config_directly():
	"""Fallback method to load config directly"""
	var file = FileAccess.open("res://data/equipment_config.json", FileAccess.READ)
	if not file:
		push_error("EquipmentSocketManager: Failed to load equipment_config.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		equipment_config = json.get_data()
	else:
		push_error("EquipmentSocketManager: Failed to parse equipment_config.json")

# === SOCKET UNLOCKING ===

func unlock_socket(equipment: Equipment, socket_index: int) -> bool:
	"""Unlock a socket on equipment - RULE 2: Single responsibility"""
	if equipment == null:
		push_error("EquipmentSocketManager: Cannot unlock socket on null equipment")
		return false
	
	if not equipment.can_unlock_socket(socket_index):
		socket_upgrade_failed.emit(equipment, socket_index, "cannot_unlock")
		return false
	
	var unlock_cost = equipment.get_socket_unlock_cost(socket_index)
	if not _can_afford_socket_cost(unlock_cost):
		socket_upgrade_failed.emit(equipment, socket_index, "insufficient_resources")
		return false
	
	# Pay cost and unlock socket
	if not _pay_socket_cost(unlock_cost):
		socket_upgrade_failed.emit(equipment, socket_index, "payment_failed")
		return false
	
	# Add new socket to equipment
	var socket_type = _determine_socket_type(equipment)
	equipment.socket_slots.append({
		"type": socket_type,
		"gem": {},
		"unlocked": true
	})
	
	socket_unlocked.emit(equipment, socket_index)
	return true

func _determine_socket_type(equipment: Equipment) -> String:
	"""Determine socket type for equipment"""
	var type_name = Equipment.type_to_string(equipment.type)
	var socket_system = equipment_config.get("socket_system", {})
	var equipment_types = socket_system.get("equipment_types", {})
	var type_config = equipment_types.get(type_name, {})
	var socket_types = type_config.get("socket_types", ["universal"])
	
	# Randomly select socket type from available types
	return socket_types[randi() % socket_types.size()]

# === GEM SOCKETING ===

func socket_gem(equipment: Equipment, socket_index: int, gem_id: String) -> bool:
	"""Socket a gem into equipment - RULE 2: Single responsibility"""
	if equipment == null:
		push_error("EquipmentSocketManager: Cannot socket gem into null equipment")
		return false
	
	if socket_index >= equipment.socket_slots.size():
		push_error("EquipmentSocketManager: Socket index out of range")
		return false
	
	var socket = equipment.socket_slots[socket_index]
	if not socket.get("unlocked", false):
		return false

	if not socket.gem.is_empty():
		return false

	# Check if player has the gem
	if not _has_gem_in_inventory(gem_id):
		return false

	# Check compatibility
	if not _is_gem_compatible_with_socket(gem_id, socket.type):
		return false
	
	# Remove gem from inventory and socket it
	if not _consume_gem_from_inventory(gem_id):
		return false
	
	var gem_data = _get_gem_data(gem_id)
	socket.gem = gem_data
	
	gem_socketed.emit(equipment, socket_index, socket.gem)
	return true

func unsocket_gem(equipment: Equipment, socket_index: int) -> Dictionary:
	"""Remove gem from socket - RULE 2: Single responsibility"""
	if equipment == null or socket_index >= equipment.socket_slots.size():
		return {}
	
	var socket = equipment.socket_slots[socket_index]
	var gem = socket.get("gem", {})
	
	if gem.is_empty():
		return {}
	
	# Add gem back to inventory
	_add_gem_to_inventory(gem)
	
	# Clear socket
	socket.gem = {}
	
	gem_unsocketed.emit(equipment, socket_index, gem)
	return gem

# === GEM INVENTORY MANAGEMENT ===

func add_gem_to_inventory(gem_id: String, quantity: int = 1):
	"""Add gems to inventory"""
	for i in range(quantity):
		var gem_data = _get_gem_data(gem_id)
		gems_inventory.append(gem_data)

func _add_gem_to_inventory(gem_data: Dictionary):
	"""Add gem data to inventory"""
	gems_inventory.append(gem_data)

func _has_gem_in_inventory(gem_id: String) -> bool:
	"""Check if gem is available in inventory - RULE 5: Use SystemRegistry"""
	# First check our gem inventory
	for gem in gems_inventory:
		if gem.get("id", "") == gem_id:
			return true
	
	# Also check resource manager for gem materials
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager:
			return resource_manager.get_resource(gem_id) > 0
	
	return false

func _consume_gem_from_inventory(gem_id: String) -> bool:
	"""Remove gem from inventory - RULE 5: Use SystemRegistry"""
	# First try our gem inventory
	for i in range(gems_inventory.size()):
		var gem = gems_inventory[i]
		if gem.get("id", "") == gem_id:
			gems_inventory.remove_at(i)
			return true
	
	# Try resource manager
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager and resource_manager.get_resource(gem_id) > 0:
			return resource_manager.spend_resource(gem_id, 1)
	
	return false

func get_gem_inventory() -> Array:
	"""Get all gems in inventory"""
	return gems_inventory.duplicate()

func get_gem_count(gem_id: String) -> int:
	"""Get count of specific gem in inventory"""
	var count = 0
	
	# Count in gem inventory
	for gem in gems_inventory:
		if gem.get("id", "") == gem_id:
			count += 1
	
	# Check resource manager
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager:
			count += resource_manager.get_resource(gem_id)
	
	return count

# === GEM COMPATIBILITY ===

func _is_gem_compatible_with_socket(gem_id: String, socket_type: String) -> bool:
	"""Check if gem can be socketed into specific socket type"""
	var socket_system = equipment_config.get("socket_system", {})
	var gemstone_effects = socket_system.get("gemstone_effects", {})
	
	if not gemstone_effects.has(gem_id):
		# If not in config, check if it's a universal socket
		return socket_type == "universal"
	
	var gem_config = gemstone_effects[gem_id]
	var compatible_sockets = gem_config.get("compatible_sockets", ["universal"])
	
	return socket_type in compatible_sockets or "universal" in compatible_sockets

func get_compatible_gems_for_socket(socket_type: String) -> Array:
	"""Get list of gems compatible with socket type"""
	var compatible: Array = []
	
	var socket_system = equipment_config.get("socket_system", {})
	var gemstone_effects = socket_system.get("gemstone_effects", {})
	
	for gem_id in gemstone_effects:
		if _is_gem_compatible_with_socket(gem_id, socket_type):
			compatible.append(gem_id)
	
	return compatible

func get_socket_info(equipment: Equipment, socket_index: int) -> Dictionary:
	"""Get detailed information about a socket"""
	if equipment == null or socket_index >= equipment.socket_slots.size():
		return {}
	
	var socket = equipment.socket_slots[socket_index]
	
	return {
		"unlocked": socket.get("unlocked", false),
		"type": socket.get("type", "universal"),
		"gem": socket.get("gem", {}),
		"compatible_gems": get_compatible_gems_for_socket(socket.get("type", "universal"))
	}

# === COST MANAGEMENT ===

func _can_afford_socket_cost(cost: Dictionary) -> bool:
	"""Check if player can afford socket cost - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return false
	
	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return false
	
	for resource_id in cost:
		var amount_needed = cost[resource_id]
		var current_amount = resource_manager.get_resource(resource_id)
		if current_amount < amount_needed:
			return false
	
	return true

func _pay_socket_cost(cost: Dictionary) -> bool:
	"""Pay the socket cost - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return false
	
	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return false
	
	# Double-check affordability
	if not _can_afford_socket_cost(cost):
		return false
	
	# Pay all resources
	for resource_id in cost:
		var amount = cost[resource_id]
		if not resource_manager.spend_resource(resource_id, amount):
			push_error("EquipmentSocketManager: Failed to spend resource: " + resource_id)
			return false
	
	return true

# === UTILITY METHODS ===

func _get_gem_data(gem_id: String) -> Dictionary:
	"""Get gem data from configuration"""
	var socket_system = equipment_config.get("socket_system", {})
	var gemstone_effects = socket_system.get("gemstone_effects", {})
	
	if gemstone_effects.has(gem_id):
		var gem_data = gemstone_effects[gem_id].duplicate()
		gem_data["id"] = gem_id
		return gem_data
	
	# Return basic gem data if not found
	return {
		"id": gem_id,
		"name": gem_id.replace("_", " ").capitalize(),
		"effects": {},
		"compatible_sockets": ["universal"]
	}

func get_gem_effects_on_equipment(equipment: Equipment) -> Dictionary:
	"""Get total gem effects applied to equipment"""
	var total_effects = {}
	
	if equipment == null:
		return total_effects
	
	for socket in equipment.socket_slots:
		var gem = socket.get("gem", {})
		if not gem.is_empty():
			var effects = gem.get("effects", {})
			for effect_type in effects:
				if not total_effects.has(effect_type):
					total_effects[effect_type] = 0
				total_effects[effect_type] += effects[effect_type]
	
	return total_effects

func get_socket_upgrade_cost_preview(equipment: Equipment) -> Dictionary:
	"""Get preview of socket upgrade costs"""
	if equipment == null:
		return {}
	
	var preview = {
		"current_sockets": equipment.socket_slots.size(),
		"max_sockets": equipment.max_sockets,
		"can_unlock": false,
		"next_socket_cost": {},
		"total_cost_to_max": {}
	}
	
	if preview.current_sockets < preview.max_sockets:
		preview.can_unlock = true
		preview.next_socket_cost = equipment.get_socket_unlock_cost(preview.current_sockets)
		
		# Calculate total cost to max sockets
		var total_cost = {}
		for socket_index in range(preview.current_sockets, preview.max_sockets):
			var cost = equipment.get_socket_unlock_cost(socket_index)
			for resource_id in cost:
				if not total_cost.has(resource_id):
					total_cost[resource_id] = 0
				total_cost[resource_id] += cost[resource_id]
		
		preview.total_cost_to_max = total_cost
	
	return preview

# === TESTING METHODS ===

func _test_socket_operations():
	"""Test socket operations"""
	# Create test equipment
	var test_equipment = Equipment.create_from_dungeon("test_weapon", "WEAPON", "COMMON", 1)
	if test_equipment:
		var _socket_preview = get_socket_upgrade_cost_preview(test_equipment)

		# Test gem inventory
		add_gem_to_inventory("test_gem", 1)
		var _gem_count = get_gem_count("test_gem")
