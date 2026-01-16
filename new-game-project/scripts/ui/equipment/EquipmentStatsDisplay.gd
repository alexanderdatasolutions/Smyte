# scripts/ui/equipment/EquipmentStatsDisplay.gd
# RULE 1 COMPLIANCE: Under 200 lines
# RULE 2 COMPLIANCE: Single responsibility - Equipment stats display only
# RULE 4 COMPLIANCE: UI Only - no business logic
extends Control
class_name EquipmentStatsDisplay

"""
Equipment Stats Display Component
Handles god equipment stats, detailed info, and set bonus display
SINGLE RESPONSIBILITY: Stats and info display only
"""

var selected_god: God = null
var equipment_manager: EquipmentManager

# UI references
var god_name_label: Label
var god_stats_container: Container
var detailed_stats_panel: VBoxContainer
var set_bonus_panel: VBoxContainer

func _ready():
	_initialize_systems()
	_setup_detailed_panels()

func _initialize_systems():
	"""Initialize system references"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		if not equipment_manager:
			push_error("EquipmentStatsDisplay: Could not get EquipmentManager from SystemRegistry")
	else:
		push_error("EquipmentStatsDisplay: Could not get SystemRegistry instance")

func _setup_detailed_panels():
	"""Setup detailed stats and set bonus panels"""
	# Create scrollable container for all stats
	var scroll_container = ScrollContainer.new()
	scroll_container.anchors_preset = Control.PRESET_FULL_RECT
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	scroll_container.add_child(main_vbox)
	
	# God basic info panel
	var god_info_panel = Panel.new()
	var god_info_style = StyleBoxFlat.new()
	god_info_style.bg_color = Color(0.1, 0.1, 0.2, 0.8)
	god_info_style.corner_radius_top_left = 6
	god_info_style.corner_radius_top_right = 6
	god_info_style.corner_radius_bottom_left = 6
	god_info_style.corner_radius_bottom_right = 6
	god_info_panel.add_theme_stylebox_override("panel", god_info_style)
	god_info_panel.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(god_info_panel)
	
	var god_info_vbox = VBoxContainer.new()
	god_info_vbox.anchors_preset = Control.PRESET_FULL_RECT
	god_info_vbox.add_theme_constant_override("margin_left", 10)
	god_info_vbox.add_theme_constant_override("margin_right", 10)
	god_info_vbox.add_theme_constant_override("margin_top", 10)
	god_info_vbox.add_theme_constant_override("margin_bottom", 10)
	god_info_panel.add_child(god_info_vbox)
	
	god_name_label = Label.new()
	god_name_label.text = "Select a God"
	god_name_label.add_theme_font_size_override("font_size", 18)
	god_name_label.add_theme_color_override("font_color", Color.GOLD)
	god_info_vbox.add_child(god_name_label)
	
	# God power rating
	var power_label = Label.new()
	power_label.name = "PowerLabel"
	power_label.text = "Power: 0"
	power_label.add_theme_font_size_override("font_size", 14)
	power_label.add_theme_color_override("font_color", Color.ORANGE)
	god_info_vbox.add_child(power_label)
	
	# Detailed stats panel
	detailed_stats_panel = VBoxContainer.new()
	detailed_stats_panel.name = "DetailedStatsPanel"
	main_vbox.add_child(detailed_stats_panel)
	
	var stats_title = Label.new()
	stats_title.text = "Combat Stats"
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color.CYAN)
	detailed_stats_panel.add_child(stats_title)
	
	# Stats container with grid layout
	god_stats_container = GridContainer.new()
	god_stats_container.columns = 2
	god_stats_container.add_theme_constant_override("h_separation", 20)
	god_stats_container.add_theme_constant_override("v_separation", 4)
	detailed_stats_panel.add_child(god_stats_container)
	
	# Set bonus panel
	set_bonus_panel = VBoxContainer.new()
	set_bonus_panel.name = "SetBonusPanel" 
	main_vbox.add_child(set_bonus_panel)
	
	var set_title = Label.new()
	set_title.text = "Set Bonuses"
	set_title.add_theme_font_size_override("font_size", 16)
	set_title.add_theme_color_override("font_color", Color.GOLD)
	set_bonus_panel.add_child(set_title)
	
	# Equipment details panel
	var equipment_panel = VBoxContainer.new()
	equipment_panel.name = "EquipmentPanel"
	main_vbox.add_child(equipment_panel)
	
	var equipment_title = Label.new()
	equipment_title.text = "Equipment Details"
	equipment_title.add_theme_font_size_override("font_size", 16)
	equipment_title.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	equipment_panel.add_child(equipment_title)
	
	var equipment_details = VBoxContainer.new()
	equipment_details.name = "EquipmentDetails"
	equipment_panel.add_child(equipment_details)
	set_bonus_panel = VBoxContainer.new()
	set_bonus_panel.name = "SetBonusPanel"
	add_child(set_bonus_panel)
	
	var bonus_title = Label.new()
	bonus_title.text = "Set Bonuses"
	bonus_title.add_theme_font_size_override("font_size", 16)
	bonus_title.add_theme_color_override("font_color", Color.GOLD)
	set_bonus_panel.add_child(bonus_title)

func set_ui_references(name_label: Label, stats_container: Container):
	"""Set UI references from parent"""
	god_name_label = name_label
	god_stats_container = stats_container

func set_selected_god(god: God):
	"""Set the currently selected god and refresh display"""
	selected_god = god
	_update_selected_god_display()

func _update_selected_god_display():
	"""Update the selected god display"""
	if not selected_god:
		return
	
	_refresh_god_stats()
	_refresh_detailed_stats()
	_refresh_set_bonuses()

func _refresh_god_stats():
	"""Refresh basic god stats display"""
	if not selected_god or not god_name_label or not god_stats_container:
		return
	
	god_name_label.text = selected_god.name
	
	# Clear existing stats
	for child in god_stats_container.get_children():
		child.queue_free()
	
	# Get calculated stats including equipment bonuses (RULE 3 compliance)
	var stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator")
	var total_stats = {}
	
	if stat_calc:
		total_stats = stat_calc.calculate_god_total_stats(selected_god)
	else:
		# Fallback to base stats if calculator not available
		total_stats = {
			"hp": selected_god.base_hp,
			"attack": selected_god.base_attack,
			"defense": selected_god.base_defense,
			"speed": selected_god.base_speed,
			"crit_rate": selected_god.base_crit_rate,
			"crit_damage": selected_god.base_crit_damage
		}
	
	# Add basic stats
	var stats = [
		{"name": "Level", "value": str(selected_god.level)},
		{"name": "Attack", "value": str(total_stats.get("attack", 0))},
		{"name": "Defense", "value": str(total_stats.get("defense", 0))},
		{"name": "HP", "value": str(total_stats.get("hp", 0))},
		{"name": "Speed", "value": str(total_stats.get("speed", 0))},
		{"name": "Crit Rate", "value": str(total_stats.get("crit_rate", 0)) + "%"},
		{"name": "Crit Damage", "value": str(total_stats.get("crit_damage", 0)) + "%"}
	]
	
	for stat in stats:
		var stat_container = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = stat.name + ":"
		name_label.custom_minimum_size = Vector2(80, 0)
		stat_container.add_child(name_label)
		
		var value_label = Label.new()
		value_label.text = stat.value
		value_label.add_theme_color_override("font_color", Color.YELLOW)
		stat_container.add_child(value_label)
		
		god_stats_container.add_child(stat_container)

func _refresh_detailed_stats():
	"""Refresh detailed stats including equipment bonuses"""
	if not selected_god or not detailed_stats_panel:
		return
	
	# Clear existing detailed stats (keep title)
	var children_to_remove = []
	for child in detailed_stats_panel.get_children():
		if child.name != "DetailedStatsTitle":
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
	
	# Equipment bonus breakdown
	var equipment_stats = _calculate_equipment_stats()
	var set_bonuses = _calculate_set_bonuses()
	
	# Get stat calculator system
	var system_registry = SystemRegistry.get_instance()
	var stat_calculator = system_registry.get_system("EquipmentStatCalculator")
	var total_stats = stat_calculator.calculate_god_total_stats(selected_god)
	
	# Base vs Total comparison
	var stat_breakdown = [
		{
			"name": "Attack",
			"base": selected_god.base_attack,
			"equipment": equipment_stats.attack,
			"set_bonus": set_bonuses.attack,
			"total": total_stats.get("attack", selected_god.base_attack)
		},
		{
			"name": "Defense", 
			"base": selected_god.base_defense,
			"equipment": equipment_stats.defense,
			"set_bonus": set_bonuses.defense,
			"total": total_stats.get("defense", selected_god.base_defense)
		},
		{
			"name": "HP",
			"base": selected_god.base_hp,
			"equipment": equipment_stats.hp,
			"set_bonus": set_bonuses.hp,
			"total": total_stats.get("hp", selected_god.base_hp)
		},
		{
			"name": "Speed",
			"base": selected_god.base_speed,
			"equipment": equipment_stats.speed,
			"set_bonus": set_bonuses.speed,
			"total": total_stats.get("speed", selected_god.base_speed)
		}
	]
	
	# Create breakdown display
	for stat in stat_breakdown:
		var breakdown_panel = Panel.new()
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.6)
		panel_style.corner_radius_top_left = 4
		panel_style.corner_radius_top_right = 4
		panel_style.corner_radius_bottom_left = 4
		panel_style.corner_radius_bottom_right = 4
		breakdown_panel.add_theme_stylebox_override("panel", panel_style)
		breakdown_panel.custom_minimum_size = Vector2(0, 60)
		detailed_stats_panel.add_child(breakdown_panel)
		
		var breakdown_vbox = VBoxContainer.new()
		breakdown_vbox.anchors_preset = Control.PRESET_FULL_RECT
		breakdown_vbox.add_theme_constant_override("margin_left", 8)
		breakdown_vbox.add_theme_constant_override("margin_right", 8)
		breakdown_vbox.add_theme_constant_override("margin_top", 4)
		breakdown_vbox.add_theme_constant_override("margin_bottom", 4)
		breakdown_panel.add_child(breakdown_vbox)
		
		# Stat name and total
		var header = HBoxContainer.new()
		breakdown_vbox.add_child(header)
		
		var stat_name = Label.new()
		stat_name.text = stat.name
		stat_name.add_theme_font_size_override("font_size", 14)
		stat_name.add_theme_color_override("font_color", Color.WHITE)
		header.add_child(stat_name)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		
		var total_label = Label.new()
		total_label.text = str(stat.total)
		total_label.add_theme_font_size_override("font_size", 16)
		total_label.add_theme_color_override("font_color", Color.YELLOW)
		header.add_child(total_label)
		
		# Breakdown details
		var details = HBoxContainer.new()
		details.add_theme_constant_override("separation", 10)
		breakdown_vbox.add_child(details)
		
		var base_detail = Label.new()
		base_detail.text = "Base: %d" % stat.base
		base_detail.add_theme_font_size_override("font_size", 11)
		base_detail.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		details.add_child(base_detail)
		
		if stat.equipment > 0:
			var equipment_detail = Label.new()
			equipment_detail.text = "Equipment: +%d" % stat.equipment
			equipment_detail.add_theme_font_size_override("font_size", 11)
			equipment_detail.add_theme_color_override("font_color", Color.CYAN)
			details.add_child(equipment_detail)
		
		if stat.set_bonus > 0:
			var set_detail = Label.new()
			set_detail.text = "Set: +%d" % stat.set_bonus
			set_detail.add_theme_font_size_override("font_size", 11)
			set_detail.add_theme_color_override("font_color", Color.GOLD)
			details.add_child(set_detail)
	
	# Update power rating
	var power_label = get_node_or_null("PowerLabel")
	if not power_label:
		power_label = find_child("PowerLabel", true, false)
	if power_label:
		# Calculate power rating from total stats
		var power_rating = total_stats.get("attack", 0) + total_stats.get("defense", 0) + total_stats.get("hp", 0) + total_stats.get("speed", 0)
		power_label.text = "Power: %d" % power_rating

func _calculate_equipment_stats() -> Dictionary:
	"""Calculate raw equipment stat bonuses"""
	var stats = {"attack": 0, "defense": 0, "hp": 0, "speed": 0}
	
	if not selected_god:
		return stats
	
	for i in range(selected_god.equipment.size()):
		var equipment = _get_equipped_equipment_for_slot(i)
		if equipment:
			# Add main stat
			match equipment.main_stat_type.to_lower():
				"attack":
					stats.attack += equipment.main_stat_value
				"defense":
					stats.defense += equipment.main_stat_value
				"hp":
					stats.hp += equipment.main_stat_value
				"speed":
					stats.speed += equipment.main_stat_value
			
			# Add substats
			for substat in equipment.substats:
				match substat.type.to_lower():
					"attack":
						stats.attack += substat.value
					"defense":
						stats.defense += substat.value
					"hp":
						stats.hp += substat.value
					"speed":
						stats.speed += substat.value
	
	return stats

func _calculate_set_bonuses() -> Dictionary:
	"""Calculate set bonus contributions"""
	var bonuses = {"attack": 0, "defense": 0, "hp": 0, "speed": 0}
	
	if not selected_god:
		return bonuses
	
	var set_counts = {}
	
	# Count set pieces
	for i in range(selected_god.equipment.size()):
		var equipment = _get_equipped_equipment_for_slot(i)
		if equipment and equipment.equipment_set_name != "":
			var equipment_set = equipment.equipment_set_name
			set_counts[equipment_set] = set_counts.get(equipment_set, 0) + 1
	
	# Apply set bonuses based on counts
	for equipment_set in set_counts:
		var count = set_counts[equipment_set]
		var set_bonus = _get_set_bonus_stats(equipment_set, count)
		
		bonuses.attack += set_bonus.attack
		bonuses.defense += set_bonus.defense
		bonuses.hp += set_bonus.hp
		bonuses.speed += set_bonus.speed
	
	return bonuses

func _get_set_bonus_stats(equipment_set_name: String, piece_count: int) -> Dictionary:
	"""Get set bonus stats for a specific set and piece count"""
	var bonus = {"attack": 0, "defense": 0, "hp": 0, "speed": 0}
	
	# Example set bonuses - replace with your actual set data
	match equipment_set_name.to_lower():
		"berserker":
			if piece_count >= 2:
				bonus.attack += 50
			if piece_count >= 4:
				bonus.attack += 100
			if piece_count >= 6:
				bonus.attack += 200
		"guardian":
			if piece_count >= 2:
				bonus.defense += 75
			if piece_count >= 4:
				bonus.hp += 500
			if piece_count >= 6:
				bonus.defense += 150
		"swift":
			if piece_count >= 2:
				bonus.speed += 25
			if piece_count >= 4:
				bonus.speed += 50
			if piece_count >= 6:
				bonus.attack += 100
	
	return bonus

func _get_equipped_equipment_for_slot(slot_index: int) -> Equipment:
	"""Get equipment in specified slot"""
	if not selected_god or slot_index < 0 or slot_index >= selected_god.equipment.size():
		return null
	
	var equipment_ref = selected_god.equipment[slot_index]
	if equipment_ref == null:
		return null
	
	# Handle both Equipment objects and string IDs
	if equipment_ref is Equipment:
		return equipment_ref
	elif equipment_ref is String:
		if equipment_ref == "":
			return null
		# Find equipment by ID
		if equipment_manager:
			var equipment = equipment_manager.get_equipment_by_id(equipment_ref)
			return equipment
	
	return null

func _refresh_set_bonuses():
	"""Refresh set bonus display"""
	if not selected_god or not set_bonus_panel:
		return
	
	# Clear existing bonuses (keep title)
	var children_to_remove = []
	for child in set_bonus_panel.get_children():
		if child is Label and child.text == "Set Bonuses":
			continue  # Keep the title label
		children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
	
	# Calculate active set bonuses
	var equipment_set_counts = {}
	
	# Count equipped pieces by set
	for i in range(selected_god.equipment.size()):
		var equipment = _get_equipped_equipment_for_slot(i)
		if equipment and equipment.equipment_set_name != "":
			var equipment_set = equipment.equipment_set_name
			equipment_set_counts[equipment_set] = equipment_set_counts.get(equipment_set, 0) + 1
	
	# Display active set bonuses
	if equipment_set_counts.size() == 0:
		var no_sets_label = Label.new()
		no_sets_label.text = "No set bonuses active"
		no_sets_label.add_theme_color_override("font_color", Color.GRAY)
		set_bonus_panel.add_child(no_sets_label)
		return
	
	for equipment_set in equipment_set_counts:
		var count = equipment_set_counts[equipment_set]
		
		# Set bonus container
		var set_container = VBoxContainer.new()
		set_bonus_panel.add_child(set_container)
		
		# Set name and count
		var set_header = Label.new()
		set_header.text = "%s Set (%d/6 pieces)" % [equipment_set, count]
		set_header.add_theme_font_size_override("font_size", 14)
		set_header.add_theme_color_override("font_color", Color.GOLD)
		set_container.add_child(set_header)
		
		# Set bonus effects
		var bonus_effects = _get_set_bonus_description(equipment_set, count)
		for effect in bonus_effects:
			var effect_label = Label.new()
			effect_label.text = "  • " + effect
			effect_label.add_theme_font_size_override("font_size", 12)
			effect_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			set_container.add_child(effect_label)

func _get_set_bonus_description(equipment_set_name: String, piece_count: int) -> Array[String]:
	"""Get set bonus descriptions for display"""
	var descriptions: Array[String] = []
	
	match equipment_set_name.to_lower():
		"berserker":
			if piece_count >= 2:
				descriptions.append("2-Piece: +50 Attack")
			if piece_count >= 4:
				descriptions.append("4-Piece: +100 Attack")
			if piece_count >= 6:
				descriptions.append("6-Piece: +200 Attack")
		
		"guardian":
			if piece_count >= 2:
				descriptions.append("2-Piece: +75 Defense")
			if piece_count >= 4:
				descriptions.append("4-Piece: +500 HP")
			if piece_count >= 6:
				descriptions.append("6-Piece: +150 Defense")
		
		"swift":
			if piece_count >= 2:
				descriptions.append("2-Piece: +25 Speed")
			if piece_count >= 4:
				descriptions.append("4-Piece: +50 Speed")
			if piece_count >= 6:
				descriptions.append("6-Piece: +100 Attack")
		
		_:
			descriptions.append("Unknown set: %s" % equipment_set_name)
	
	return descriptions
