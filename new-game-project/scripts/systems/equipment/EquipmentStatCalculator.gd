# scripts/systems/collection/EquipmentStatCalculator.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - equipment stat calculations only
# RULE 3 COMPLIANCE: All logic here, not in data classes
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name EquipmentStatCalculator

"""
Equipment Stat Calculator System
Handles all equipment stat calculations including bonuses, set effects, and god totals
Following RULE 3: All stat calculation logic is in systems, NOT in data classes
"""

# Equipment slot type names for display
static var SLOT_TYPE_NAMES = {
	Equipment.EquipmentType.WEAPON: "Weapon",
	Equipment.EquipmentType.ARMOR: "Armor", 
	Equipment.EquipmentType.HELM: "Helm",
	Equipment.EquipmentType.BOOTS: "Boots",
	Equipment.EquipmentType.AMULET: "Amulet",
	Equipment.EquipmentType.RING: "Ring"
}

# Rarity color coding
static var RARITY_COLORS = {
	Equipment.Rarity.COMMON: Color.GRAY,
	Equipment.Rarity.RARE: Color.GREEN,
	Equipment.Rarity.EPIC: Color.BLUE,
	Equipment.Rarity.LEGENDARY: Color.PURPLE,
	Equipment.Rarity.MYTHIC: Color.GOLD
}

func _ready():
	pass

# === GOD STAT CALCULATIONS ===

func calculate_god_total_stats(god: God) -> Dictionary:
	"""Calculate total stats for a god including all equipment bonuses - RULE 3 COMPLIANCE"""
	if not god:
		return {}
	
	var total_stats = {
		"hp": god.base_hp,
		"attack": god.base_attack,
		"defense": god.base_defense,
		"speed": god.base_speed,
		"crit_rate": god.base_crit_rate,
		"crit_damage": god.base_crit_damage,
		"resistance": god.base_resistance,
		"accuracy": god.base_accuracy
	}
	
	# Add equipment bonuses
	if god.equipment:
		for equipment_data in god.equipment:
			if equipment_data:
				# Handle both Equipment objects and String IDs
				var equipment_obj = null
				if equipment_data is Equipment:
					equipment_obj = equipment_data
				elif equipment_data is String:
					# Look up equipment by ID through EquipmentManager
					var equipment_manager = SystemRegistry.get_instance().get_system("EquipmentManager")
					if equipment_manager:
						equipment_obj = equipment_manager.get_equipment_by_id(equipment_data)
				
				if equipment_obj:
					_add_equipment_stats_to_total(equipment_obj, total_stats)
	
	return total_stats

func _add_equipment_stats_to_total(equipment: Equipment, total_stats: Dictionary):
	"""Add equipment stats to total - helper for god stats calculation"""
	if not equipment:
		return
	
	# Add main stat
	if equipment.main_stat_type in total_stats:
		total_stats[equipment.main_stat_type] += equipment.main_stat_value
	
	# Add substats
	for substat in equipment.substats:
		var stat_type = substat.get("type", "")
		var stat_value = substat.get("value", 0)
		if stat_type in total_stats:
			total_stats[stat_type] += stat_value

# === EQUIPMENT STAT CALCULATIONS ===

func calculate_equipment_power_rating(equipment: Equipment) -> int:
	"""Calculate overall power rating for equipment"""
	if not equipment:
		return 0
	
	var power = 0
	
	# Main stat contributes most to power
	power += equipment.main_stat_value * 2
	
	# Substats contribute to power
	for substat in equipment.substats:
		power += substat.get("value", 0)
	
	# Enhancement level multiplier
	var enhancement_multiplier = 1.0 + (equipment.level * 0.1)
	power = int(power * enhancement_multiplier)
	
	# Rarity multiplier
	match equipment.rarity:
		Equipment.Rarity.COMMON:
			power = int(power * 1.0)
		Equipment.Rarity.RARE:
			power = int(power * 1.2)
		Equipment.Rarity.EPIC:
			power = int(power * 1.5)
		Equipment.Rarity.LEGENDARY:
			power = int(power * 2.0)
		Equipment.Rarity.MYTHIC:
			power = int(power * 3.0)
	
	return power

func get_equipment_display_info(equipment: Equipment) -> Dictionary:
	"""Get formatted display information for equipment"""
	if not equipment:
		return {}
	
	return {
		"name": equipment.name,
		"type": SLOT_TYPE_NAMES.get(equipment.type, "Unknown"),
		"rarity": Equipment.Rarity.keys()[equipment.rarity],
		"level": equipment.level,
		"power_rating": calculate_equipment_power_rating(equipment),
		"main_stat": "%s: +%d" % [equipment.main_stat_type, equipment.main_stat_value],
		"set_name": equipment.equipment_set_name,
		"rarity_color": RARITY_COLORS.get(equipment.rarity, Color.WHITE),
		"substats": _format_substats(equipment.substats)
	}

func _format_substats(substats: Array) -> Array:
	"""Format substats for display"""
	var formatted = []
	for substat in substats:
		var stat_type = substat.get("type", "")
		var stat_value = substat.get("value", 0)
		formatted.append("%s: +%d" % [stat_type, stat_value])
	return formatted

# === SET BONUS CALCULATIONS ===

func calculate_set_bonuses(god: God) -> Dictionary:
	"""Calculate set bonuses from equipped equipment"""
	if not god or not god.equipped_equipment:
		return {}
	
	# Count equipment by set
	var set_counts = {}
	for equipment in god.equipped_equipment:
		if equipment and equipment.equipment_set_name != "":
			var equipment_set = equipment.equipment_set_name
			set_counts[equipment_set] = set_counts.get(equipment_set, 0) + 1
	
	# Apply set bonuses based on counts
	var bonuses = {}
	for equipment_set in set_counts:
		var count = set_counts[equipment_set]
		var set_bonus = _get_set_bonus_effects(equipment_set, count)
		if not set_bonus.is_empty():
			bonuses[equipment_set] = set_bonus
	
	return bonuses

func _get_set_bonus_effects(equipment_set: String, piece_count: int) -> Dictionary:
	"""Get set bonus effects based on set name and piece count"""
	# This would normally load from configuration
	# For now, hardcoded examples
	match equipment_set:
		"warrior":
			if piece_count >= 2:
				return {"attack_bonus_percent": 20}
		"guardian":
			if piece_count >= 4:
				return {"defense_bonus_percent": 35}
		"swift":
			if piece_count >= 2:
				return {"speed_bonus": 25}
		"focus":
			if piece_count >= 2:
				return {"accuracy_bonus_percent": 20}
	
	return {}

# === ENHANCEMENT PREVIEW ===

func get_enhancement_preview(equipment: Equipment) -> Dictionary:
	"""Get preview of equipment enhancement effects"""
	if not equipment:
		return {}
	
	var current_level = equipment.level
	if current_level >= 15:  # Max enhancement level
		return {"can_enhance": false, "reason": "Max level reached"}
	
	var next_level = current_level + 1
	var main_stat_increase = _calculate_main_stat_increase(equipment, next_level)
	
	return {
		"can_enhance": true,
		"current_level": current_level,
		"next_level": next_level,
		"main_stat_increase": main_stat_increase,
		"success_rate": _get_enhancement_success_rate(equipment, next_level),
		"cost": _get_enhancement_cost(equipment, next_level)
	}

func _calculate_main_stat_increase(equipment: Equipment, _target_level: int) -> int:
	"""Calculate main stat increase from enhancement"""
	# Base increase per level varies by rarity and stat type
	var base_increase = equipment.main_stat_base * 0.05  # 5% per level
	return int(base_increase)

func _get_enhancement_success_rate(_equipment: Equipment, target_level: int) -> float:
	"""Get enhancement success rate"""
	# Success rate decreases with higher levels
	var base_rate = 100.0
	var level_penalty = target_level * 5.0
	return max(10.0, base_rate - level_penalty)

func _get_enhancement_cost(_equipment: Equipment, target_level: int) -> Dictionary:
	"""Get enhancement cost"""
	var base_cost = target_level * 1000
	return {
		"mana": base_cost,
		"materials": target_level * 2
	}
