# scripts/systems/collection/EquipmentEnhancementManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - equipment enhancement only
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentEnhancementManager

"""
Equipment Enhancement Management System
Handles equipment upgrading, success/failure mechanics, and enhancement costs
Part of the equipment system (like Summoners War equipment enhancement)
"""

# Signals for enhancement events
signal equipment_enhanced(equipment: Equipment, success: bool)
signal enhancement_failed(equipment: Equipment, failure_type: String)
signal blessed_oil_used(equipment: Equipment)

# Configuration cache
var equipment_config: Dictionary = {}

func _ready():
	"""Initialize equipment enhancement manager"""
	load_enhancement_config()

func load_enhancement_config():
	"""Load enhancement configuration - RULE 5: Use SystemRegistry"""
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
		push_error("EquipmentEnhancementManager: Failed to load equipment_config.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		equipment_config = json.get_data()
	else:
		push_error("EquipmentEnhancementManager: Failed to parse equipment_config.json")

# === ENHANCEMENT OPERATIONS ===

func enhance_equipment(equipment: Equipment, use_blessed_oil: bool = false) -> bool:
	"""Attempt to enhance equipment - RULE 2: Single responsibility"""
	if equipment == null:
		push_error("EquipmentEnhancementManager: Cannot enhance null equipment")
		return false
	
	if not equipment.can_be_enhanced():
		return false
	
	var enhancement_cost = equipment.get_enhancement_cost()
	if not _can_afford_enhancement_cost(enhancement_cost):
		return false
	
	var success_rate = equipment.get_enhancement_success_rate()
	
	# Apply blessed oil bonus
	var oil_bonus = 0.0
	if use_blessed_oil:
		if not _has_blessed_oil():
			return false
		
		oil_bonus = equipment_config.get("enhancement_system", {}).get("blessed_oil_bonus", 20) / 100.0
		success_rate += oil_bonus
		success_rate = min(success_rate, 1.0)
	
	# Pay the cost
	if not _pay_enhancement_cost(enhancement_cost):
		return false
	
	if use_blessed_oil:
		_consume_blessed_oil()
		blessed_oil_used.emit(equipment)
	
	# Roll for success
	var success = randf() <= success_rate
	
	if success:
		equipment.enhancement_level += 1
	else:
		_handle_enhancement_failure(equipment, use_blessed_oil)
	
	equipment_enhanced.emit(equipment, success)
	return success

func _handle_enhancement_failure(equipment: Equipment, used_blessed_oil: bool):
	"""Handle what happens when enhancement fails - RULE 2: Single responsibility"""
	if used_blessed_oil:
		# Blessed oil prevents negative consequences
		enhancement_failed.emit(equipment, "protected_failure")
		return
	
	var failure_consequences = equipment_config.get("enhancement_system", {}).get("failure_consequences", {})
	var rarity_name = Equipment.rarity_to_string(equipment.rarity)
	var consequence = failure_consequences.get(rarity_name, "none")
	
	if consequence == "none":
		enhancement_failed.emit(equipment, "safe_failure")
		return
	
	# Parse and apply consequence
	if consequence.begins_with("level_reset_chance_"):
		var chance_str = consequence.replace("level_reset_chance_", "")
		var chance = int(chance_str) / 100.0
		
		if randf() <= chance:
			equipment.enhancement_level = 0
			enhancement_failed.emit(equipment, "level_reset")
			return
	
	elif consequence.begins_with("level_down_chance_"):
		var chance_str = consequence.replace("level_down_chance_", "")
		var chance = int(chance_str) / 100.0
		
		if randf() <= chance:
			equipment.enhancement_level = max(0, equipment.enhancement_level - 1)
			enhancement_failed.emit(equipment, "level_down")
			return
	
	elif consequence == "destroy":
		# Mark equipment as destroyed (would need to be removed from inventory)
		equipment.is_destroyed = true
		enhancement_failed.emit(equipment, "destroyed")
		return
	
	# Default safe failure
	enhancement_failed.emit(equipment, "safe_failure")

# === COST MANAGEMENT ===

func _can_afford_enhancement_cost(cost: Dictionary) -> bool:
	"""Check if player can afford enhancement cost - RULE 5: Use SystemRegistry"""
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

func _pay_enhancement_cost(cost: Dictionary) -> bool:
	"""Pay the enhancement cost - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return false
	
	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return false
	
	# Double-check affordability
	if not _can_afford_enhancement_cost(cost):
		return false
	
	# Pay all resources
	for resource_id in cost:
		var amount = cost[resource_id]
		if not resource_manager.spend_resource(resource_id, amount):
			push_error("EquipmentEnhancementManager: Failed to spend resource: " + resource_id)
			return false
	
	return true

func _has_blessed_oil() -> bool:
	"""Check if player has blessed oil - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return false
	
	var resource_manager = system_registry.get_system("ResourceManager")
	if not resource_manager:
		return false
	
	return resource_manager.get_resource("blessed_oil") > 0

func _consume_blessed_oil():
	"""Consume one blessed oil - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager:
			resource_manager.spend_resource("blessed_oil", 1)

# === ENHANCEMENT ANALYSIS ===

func get_enhancement_preview(equipment: Equipment, use_blessed_oil: bool = false) -> Dictionary:
	"""Get preview of enhancement attempt without executing"""
	if equipment == null:
		return {}
	
	var preview = {
		"can_enhance": equipment.can_be_enhanced(),
		"current_level": equipment.enhancement_level,
		"next_level": equipment.enhancement_level + 1,
		"max_level": equipment.get_max_enhancement_level(),
		"success_rate": 0.0,
		"cost": {},
		"blessed_oil_available": false,
		"blessed_oil_bonus": 0.0,
		"consequences": {}
	}
	
	if not preview.can_enhance:
		return preview
	
	# Get success rate and cost
	preview.success_rate = equipment.get_enhancement_success_rate()
	preview.cost = equipment.get_enhancement_cost()
	
	# Check blessed oil
	preview.blessed_oil_available = _has_blessed_oil()
	if use_blessed_oil and preview.blessed_oil_available:
		preview.blessed_oil_bonus = equipment_config.get("enhancement_system", {}).get("blessed_oil_bonus", 20) / 100.0
		preview.success_rate = min(preview.success_rate + preview.blessed_oil_bonus, 1.0)
	
	# Get failure consequences
	var failure_consequences = equipment_config.get("enhancement_system", {}).get("failure_consequences", {})
	var rarity_name = Equipment.rarity_to_string(equipment.rarity)
	preview.consequences = failure_consequences.get(rarity_name, "none")
	
	return preview

func get_enhancement_statistics(equipment: Equipment) -> Dictionary:
	"""Get detailed enhancement statistics"""
	if equipment == null:
		return {}
	
	var stats = {
		"current_level": equipment.enhancement_level,
		"max_level": equipment.get_max_enhancement_level(),
		"enhancement_progress": 0.0,
		"stat_bonuses": equipment.get_enhancement_stat_bonuses(),
		"total_enhancement_cost": {},
		"remaining_enhancement_cost": {}
	}
	
	# Calculate progress percentage
	if stats.max_level > 0:
		stats.enhancement_progress = float(stats.current_level) / float(stats.max_level)
	
	# Calculate total cost to max enhancement
	var total_cost = {}
	var remaining_cost = {}
	
	for level in range(stats.current_level + 1, stats.max_level + 1):
		var level_cost = equipment.get_enhancement_cost_for_level(level)
		
		# Add to remaining cost
		for resource_id in level_cost:
			if not remaining_cost.has(resource_id):
				remaining_cost[resource_id] = 0
			remaining_cost[resource_id] += level_cost[resource_id]
	
	# Calculate total cost from level 0
	for level in range(1, stats.max_level + 1):
		var level_cost = equipment.get_enhancement_cost_for_level(level)
		
		# Add to total cost
		for resource_id in level_cost:
			if not total_cost.has(resource_id):
				total_cost[resource_id] = 0
			total_cost[resource_id] += level_cost[resource_id]
	
	stats.total_enhancement_cost = total_cost
	stats.remaining_enhancement_cost = remaining_cost
	
	return stats

# === BULK ENHANCEMENT ===

func enhance_equipment_bulk(equipment: Equipment, target_level: int, use_blessed_oil: bool = false) -> Dictionary:
	"""Attempt to enhance equipment to target level"""
	var result = {
		"success": false,
		"start_level": equipment.enhancement_level,
		"final_level": equipment.enhancement_level,
		"attempts": 0,
		"successes": 0,
		"failures": 0,
		"total_cost": {},
		"stopped_reason": ""
	}
	
	if equipment == null:
		result.stopped_reason = "null_equipment"
		return result
	
	target_level = min(target_level, equipment.get_max_enhancement_level())
	
	while equipment.enhancement_level < target_level:
		result.attempts += 1
		
		# Check if we can still afford enhancement
		var enhancement_cost = equipment.get_enhancement_cost()
		if not _can_afford_enhancement_cost(enhancement_cost):
			result.stopped_reason = "insufficient_resources"
			break
		
		# Attempt enhancement
		var enhanced = enhance_equipment(equipment, use_blessed_oil)
		if enhanced:
			result.successes += 1
		else:
			result.failures += 1
			
			# Check if equipment was destroyed
			if equipment.is_destroyed:
				result.stopped_reason = "equipment_destroyed"
				break
		
		# Add cost to total
		for resource_id in enhancement_cost:
			if not result.total_cost.has(resource_id):
				result.total_cost[resource_id] = 0
			result.total_cost[resource_id] += enhancement_cost[resource_id]
	
	result.final_level = equipment.enhancement_level
	result.success = result.final_level >= target_level
	
	if result.stopped_reason.is_empty():
		result.stopped_reason = "target_reached" if result.success else "max_level_reached"
	
	return result

# === TESTING METHODS ===

func _test_enhancement_operations():
	"""Test enhancement operations"""
	# Create test equipment
	var test_equipment = Equipment.create_from_dungeon("test_weapon", "WEAPON", "COMMON", 1)
	if test_equipment:
		var _preview = get_enhancement_preview(test_equipment)
		var _stats = get_enhancement_statistics(test_equipment)
