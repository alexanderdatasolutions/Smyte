# scripts/systems/SacrificeSystem.gd
extends Node
class_name SacrificeSystem

signal sacrifice_completed(target_god, material_gods, xp_gained)
signal sacrifice_failed(reason)

func calculate_sacrifice_experience(material_gods: Array[God], target_god: God = null) -> Dictionary:
	"""Calculate total experience gain from sacrificing gods"""
	var result = {
		"total_xp": 0,
		"bonus_details": [],
		"god_values": []
	}
	
	for material_god in material_gods:
		var base_xp = get_god_base_sacrifice_value(material_god)
		var bonus_multiplier = 1.0
		var bonus_text = ""
		
		# Apply bonuses if we have a target god
		if target_god:
			# Same god bonus (3x XP)
			if material_god.id == target_god.id:
				bonus_multiplier = 3.0
				bonus_text = " (Same God Bonus: 3x)"
			# Same element bonus (1.5x XP)
			elif material_god.element == target_god.element:
				bonus_multiplier = 1.5
				bonus_text = " (Same Element Bonus: 1.5x)"
		
		var final_xp = int(base_xp * bonus_multiplier)
		result.total_xp += final_xp
		
		result.god_values.append({
			"god": material_god,
			"base_xp": base_xp,
			"bonus_multiplier": bonus_multiplier,
			"final_xp": final_xp,
			"bonus_text": bonus_text
		})
	
	return result

func get_god_base_sacrifice_value(god: God) -> int:
	"""Get the base sacrifice XP value for a god"""
	# Base XP based on level
	var base_xp = god.level * 50  # 50 XP per level
	
	# Add tier bonus
	var tier_bonus = get_tier_bonus(god.tier)
	base_xp += tier_bonus
	
	# Debug output to help track the issue
	print("DEBUG - Sacrifice Value for %s (Level %d):" % [god.name, god.level])
	print("  Tier: %s (%d)" % [god.get_tier_name(), god.tier])
	print("  Level XP: %d" % (god.level * 50))
	print("  Tier Bonus: %d" % tier_bonus)
	print("  Total Base XP: %d" % base_xp)
	
	return base_xp

func get_tier_bonus(tier: God.TierType) -> int:
	"""Get the XP bonus for a god's tier"""
	match tier:
		God.TierType.COMMON:
			return 100
		God.TierType.RARE:
			return 300
		God.TierType.EPIC:
			return 600
		God.TierType.LEGENDARY:
			return 1000
		_:
			print("Warning: Unknown tier type: %d" % tier)
			return 100

func calculate_levels_gained(target_god: God, xp_gain: int) -> int:
	"""Calculate how many levels the target god would gain"""
	if not target_god:
		return 0
	
	var current_level = target_god.level
	var current_xp = target_god.experience
	var remaining_xp = xp_gain
	var levels_gained = 0
	
	while remaining_xp > 0 and (current_level + levels_gained) < 30:
		# Calculate XP needed for the next level
		# XP formula: level * 100 (so level 2 needs 200, level 3 needs 300, etc.)
		var next_level = current_level + levels_gained + 1
		var total_xp_needed_for_next = next_level * 100
		var xp_needed_for_next = total_xp_needed_for_next - current_xp
		
		if remaining_xp >= xp_needed_for_next:
			remaining_xp -= xp_needed_for_next
			levels_gained += 1
			current_xp = 0  # Reset for next level calculation
		else:
			break
	
	return levels_gained

func perform_sacrifice(target_god: God, material_gods: Array[God], player_data) -> bool:
	"""Perform the sacrifice operation"""
	if not target_god or material_gods.is_empty() or not player_data:
		sacrifice_failed.emit("Invalid sacrifice parameters")
		return false
	
	# Calculate experience gain
	var sacrifice_result = calculate_sacrifice_experience(material_gods, target_god)
	var total_xp = sacrifice_result.total_xp
	
	# Give experience to target god
	target_god.add_experience(total_xp)
	
	# Remove material gods from player collection
	for material_god in material_gods:
		player_data.remove_god(material_god)
	
	print("Sacrifice complete! %s gained %d experience from %d gods" % [
		target_god.name, 
		total_xp, 
		material_gods.size()
	])
	
	# Emit success signal
	sacrifice_completed.emit(target_god, material_gods, total_xp)
	
	return true

func get_sacrifice_preview_text(target_god: God, material_gods: Array[God]) -> String:
	"""Generate preview text for sacrifice UI"""
	if not target_god or material_gods.is_empty():
		return "Select target and material gods to see experience gain"
	
	var sacrifice_result = calculate_sacrifice_experience(material_gods, target_god)
	var levels_gained = calculate_levels_gained(target_god, sacrifice_result.total_xp)
	
	var preview_text = "Total XP Gain: %d (+%d levels)\n\nBreakdown:\n" % [
		sacrifice_result.total_xp,
		levels_gained
	]
	
	for god_value in sacrifice_result.god_values:
		preview_text += "• %s: %d XP%s\n" % [
			god_value.god.name,
			god_value.final_xp,
			god_value.bonus_text
		]
	
	return preview_text

func validate_sacrifice(target_god: God, material_gods: Array[God]) -> Dictionary:
	"""Validate if a sacrifice can be performed"""
	var result = {
		"can_sacrifice": true,
		"errors": []
	}
	
	if not target_god:
		result.can_sacrifice = false
		result.errors.append("No target god selected")
	
	if material_gods.is_empty():
		result.can_sacrifice = false
		result.errors.append("No material gods selected")
	
	# Check if target god is in material list
	if target_god and material_gods.has(target_god):
		result.can_sacrifice = false
		result.errors.append("Cannot use target god as material")
	
	# Check if target is already max level
	if target_god and target_god.level >= 30:
		result.can_sacrifice = false
		result.errors.append("Target god is already max level")
	
	return result
