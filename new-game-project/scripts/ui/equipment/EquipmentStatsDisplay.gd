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
	# Note: This component now uses UI references from the scene file
	# No need to create duplicate panels - they already exist in EquipmentScreen.tscn
	pass

func set_ui_references(name_label: Label, stats_container: Container):
	"""Set UI references from parent"""
	god_name_label = name_label
	god_stats_container = stats_container

	# Get set bonus panel from scene
	var parent = get_parent()
	if parent:
		set_bonus_panel = parent.get_node_or_null("VBox/SetBonusContainer/SetBonusList")

func set_selected_god(god: God):
	"""Set the currently selected god and refresh display"""
	selected_god = god
	_update_selected_god_display()

func _update_selected_god_display():
	"""Update the selected god display"""
	if not selected_god:
		return

	_refresh_god_stats()
	_refresh_set_bonuses()

func _refresh_god_stats():
	"""Refresh basic god stats display using scene StatsGrid"""
	if not selected_god or not god_name_label or not god_stats_container:
		return

	god_name_label.text = selected_god.name

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

	# Update existing stat labels in the scene's StatsGrid
	# god_stats_container IS the StatsGrid from the scene
	var hp_value = god_stats_container.get_node_or_null("HPValue")
	var attack_value = god_stats_container.get_node_or_null("AttackValue")
	var defense_value = god_stats_container.get_node_or_null("DefenseValue")
	var speed_value = god_stats_container.get_node_or_null("SpeedValue")
	var crit_rate_value = god_stats_container.get_node_or_null("CritRateValue")
	var crit_dmg_value = god_stats_container.get_node_or_null("CritDmgValue")

	if hp_value:
		hp_value.text = str(total_stats.get("hp", 0))
	if attack_value:
		attack_value.text = str(total_stats.get("attack", 0))
	if defense_value:
		defense_value.text = str(total_stats.get("defense", 0))
	if speed_value:
		speed_value.text = str(total_stats.get("speed", 0))
	if crit_rate_value:
		crit_rate_value.text = str(total_stats.get("crit_rate", 0)) + "%"
	if crit_dmg_value:
		crit_dmg_value.text = str(total_stats.get("crit_damage", 0)) + "%"

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
