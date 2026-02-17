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

	Equipment.load_equipment_config()
	var power_config: Dictionary = Equipment.equipment_config.get("power_calculation", {})
	var main_stat_weight: int = int(power_config.get("main_stat_weight", 2))
	var enh_mult_per_level: float = power_config.get("enhancement_multiplier_per_level", 0.1)
	var rarity_mults: Dictionary = power_config.get("rarity_multipliers", {})

	var power: int = 0

	# Main stat contributes most to power
	power += equipment.main_stat_value * main_stat_weight

	# Substats contribute to power
	for substat: Dictionary in equipment.substats:
		power += int(substat.get("value", 0))

	# Enhancement level multiplier
	var enhancement_multiplier: float = 1.0 + (equipment.level * enh_mult_per_level)
	power = int(power * enhancement_multiplier)

	# Rarity multiplier from config
	var rarity_key: String = Equipment.rarity_to_string(equipment.rarity)
	var rarity_mult: float = rarity_mults.get(rarity_key, 1.0)
	power = int(power * rarity_mult)

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
	if not god or not god.equipment:
		return {}

	# Count equipment by set
	var set_counts: Dictionary = {}
	for equip in god.equipment:
		if equip and equip is Equipment and equip.equipment_set_name != "":
			var equip_set: String = equip.equipment_set_name
			set_counts[equip_set] = set_counts.get(equip_set, 0) + 1

	# Apply set bonuses based on counts
	var bonuses: Dictionary = {}
	for equipment_set in set_counts:
		var count = set_counts[equipment_set]
		var set_bonus = _get_set_bonus_effects(equipment_set, count)
		if not set_bonus.is_empty():
			bonuses[equipment_set] = set_bonus
	
	return bonuses

func _get_set_bonus_effects(equipment_set: String, piece_count: int) -> Dictionary:
	"""Get set bonus effects based on set name and piece count from config"""
	Equipment.load_equipment_config()
	var sets: Dictionary = Equipment.equipment_config.get("equipment_sets", {})
	var set_data: Dictionary = sets.get(equipment_set.to_lower(), {})
	var bonuses: Dictionary = set_data.get("bonuses", {})

	# Find highest threshold met
	var best_bonus: Dictionary = {}
	for threshold_str: String in bonuses:
		var threshold: int = int(threshold_str)
		if piece_count >= threshold:
			best_bonus = bonuses[threshold_str]

	return best_bonus

func get_set_special_effects(god: God) -> Array:
	"""Get all active special effects from god's equipped set bonuses"""
	if not god or not god.equipment:
		return []

	# Count equipment by set
	var set_counts: Dictionary = {}
	for equip in god.equipment:
		if equip and equip is Equipment and equip.equipment_set_type != "":
			var equip_set: String = equip.equipment_set_type.to_lower()
			set_counts[equip_set] = set_counts.get(equip_set, 0) + 1

	# Collect special effects from qualifying set bonuses
	var effects: Array = []
	Equipment.load_equipment_config()
	var sets: Dictionary = Equipment.equipment_config.get("equipment_sets", {})

	for equipment_set: String in set_counts:
		var count: int = set_counts[equipment_set]
		var set_data: Dictionary = sets.get(equipment_set, {})
		var bonuses: Dictionary = set_data.get("bonuses", {})

		# Check each threshold for special effects
		for threshold_str: String in bonuses:
			var threshold: int = int(threshold_str)
			if count >= threshold:
				var bonus: Dictionary = bonuses[threshold_str]
				if bonus.has("special_effect"):
					effects.append({
						"set": equipment_set,
						"set_name": set_data.get("name", equipment_set),
						"pieces": count,
						"threshold": threshold,
						"effect": bonus.get("special_effect", ""),
						"effect_value": bonus.get("effect_value", 0.0),
						"effect_chance": bonus.get("effect_chance", 1.0)
					})

	return effects

# === ENHANCEMENT PREVIEW ===

func get_enhancement_preview(equipment: Equipment) -> Dictionary:
	"""Get preview of equipment enhancement effects"""
	if not equipment:
		return {}

	var max_level: int = equipment.get_max_enhancement_level()
	var current_level: int = equipment.level
	if current_level >= max_level:
		return {"can_enhance": false, "reason": "Max level reached"}

	var next_level: int = current_level + 1
	var main_stat_increase: int = _calculate_main_stat_increase(equipment)

	return {
		"can_enhance": true,
		"current_level": current_level,
		"next_level": next_level,
		"main_stat_increase": main_stat_increase,
		"success_rate": equipment.get_enhancement_chance() * 100.0,
		"cost": equipment.get_enhancement_cost_for_level(next_level)
	}

func _calculate_main_stat_increase(equipment: Equipment) -> int:
	"""Calculate main stat increase from enhancement using config"""
	Equipment.load_equipment_config()
	var enhancement: Dictionary = Equipment.equipment_config.get("enhancement_system", {})
	var bonus_pct: float = enhancement.get("stat_bonus_percent_per_level", 0.05)
	var base_increase: float = equipment.main_stat_base * bonus_pct
	return int(base_increase)
