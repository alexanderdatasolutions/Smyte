# scripts/ui/screens/EquipmentGodDisplay.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - God display only
# RULE 4 COMPLIANCE: UI Only - no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control
class_name EquipmentGodDisplay

"""
Equipment God Display Component
Handles god selection, stats display, and set bonus visualization
Pure UI component for god-related displays
"""

signal god_selected(god: God)

# UI References
@onready var god_grid = $GodContainer/ScrollContainer/GodGrid
@onready var god_name_label = $SelectedGodPanel/VBox/GodNameLabel  
@onready var god_stats_container = $SelectedGodPanel/VBox/StatsContainer
var detailed_stats_panel: VBoxContainer
var set_bonus_panel: VBoxContainer

# Selected state
var selected_god: God = null

# Systems - accessed through SystemRegistry (RULE 5)
var collection_manager: CollectionManager

func _ready():
	"""Initialize god display component"""
	_initialize_systems()
	_setup_detailed_panels()

func _initialize_systems():
	"""Get system references through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		collection_manager = system_registry.get_system("CollectionManager")
		
		if not collection_manager:
			push_error("EquipmentGodDisplay: Could not get CollectionManager from SystemRegistry")
	else:
		push_error("EquipmentGodDisplay: Could not get SystemRegistry instance")

func _setup_detailed_panels():
	"""Setup additional detailed information panels"""
	var selected_god_panel = get_node("SelectedGodPanel")
	if selected_god_panel and god_stats_container:
		# Insert after god name but before stats container
		var vbox = selected_god_panel.get_child(0) as VBoxContainer
		if vbox:
			# Find the position to insert - after god name label
			var insert_position = -1
			for i in range(vbox.get_child_count()):
				if vbox.get_child(i) == god_name_label:
					insert_position = i + 1
					break
			
			if insert_position > 0:
				# Detailed stats panel
				detailed_stats_panel = VBoxContainer.new()
				detailed_stats_panel.name = "DetailedStatsPanel"
				detailed_stats_panel.add_theme_constant_override("separation", 4)
				vbox.add_child(detailed_stats_panel)
				vbox.move_child(detailed_stats_panel, insert_position)
				
				# Set bonus panel
				set_bonus_panel = VBoxContainer.new()
				set_bonus_panel.name = "SetBonusPanel"
				set_bonus_panel.add_theme_constant_override("separation", 4)
				vbox.add_child(set_bonus_panel)
				vbox.move_child(set_bonus_panel, insert_position + 1)

func populate_god_grid():
	"""Populate god grid with GodCard components - RULE 4: UI only"""
	if not god_grid or not collection_manager:
		return
	
	# Clear existing gods
	for child in god_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get gods from collection
	var gods_raw = collection_manager.get_all_gods()
	var gods: Array[God] = []
	
	# Convert to properly typed array
	for god in gods_raw:
		if god is God:
			gods.append(god)
	
	# Clear existing cards
	for child in god_grid.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Use ONLY the standardized GodCardFactory for consistency
	for god in gods:
		if god != null:
			# Create card using factory
			var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.BATTLE_SELECTION)
			god_grid.add_child(god_card)
			god_card.setup_god_card(god)
			god_card.god_selected.connect(_on_god_selected)

func _on_god_selected(god: God):
	"""Handle god selection - RULE 4: UI updates only"""
	selected_god = god
	update_selected_god_display()
	god_selected.emit(god)

func update_selected_god_display():
	"""Update selected god panel display - RULE 4: UI updates only"""
	var selected_god_panel = get_node("SelectedGodPanel")
	if not selected_god:
		selected_god_panel.visible = false
		return
	selected_god_panel.visible = true
	god_name_label.text = "%s (Level %d)" % [selected_god.name, selected_god.level]
	
	refresh_god_stats()
	refresh_detailed_stats()
	refresh_set_bonuses()

func refresh_god_stats():
	"""Refresh god stats display with detailed breakdown - RULE 4: UI display only"""
	if not selected_god or not god_stats_container:
		return
	
	# Clear existing stats
	for child in god_stats_container.get_children():
		child.queue_free()
	
	# Get detailed stats from GodCalculator (RULE 5: system handles logic)
	var base_stats = {
		"HP": selected_god.base_hp,
		"Attack": selected_god.base_attack,
		"Defense": selected_god.base_defense,
		"Speed": selected_god.base_speed,
		"Crit Rate": selected_god.base_crit_rate,
		"Crit Damage": selected_god.base_crit_damage,
		"Accuracy": selected_god.base_accuracy,
		"Resistance": selected_god.base_resistance
	}
	
	var current_stats = {
		"HP": GodCalculator.get_current_hp(selected_god),
		"Attack": GodCalculator.get_current_attack(selected_god),
		"Defense": GodCalculator.get_current_defense(selected_god),
		"Speed": GodCalculator.get_current_speed(selected_god),
		"Crit Rate": GodCalculator.get_current_crit_rate(selected_god),
		"Crit Damage": GodCalculator.get_current_crit_damage(selected_god),
		"Accuracy": GodCalculator.get_current_accuracy(selected_god),
		"Resistance": GodCalculator.get_current_resistance(selected_god)
	}
	
	# Display main combat stats (compact)
	var main_stats = ["HP", "Attack", "Defense", "Speed"]
	var main_stats_grid = GridContainer.new()
	main_stats_grid.columns = 2
	main_stats_grid.add_theme_constant_override("h_separation", 10)
	main_stats_grid.add_theme_constant_override("v_separation", 2)
	
	for stat_name in main_stats:
		var base_val = base_stats[stat_name]
		var current_val = current_stats[stat_name]
		var bonus = current_val - base_val
		
		var stat_label = Label.new()
		stat_label.text = stat_name + ":"
		stat_label.add_theme_font_size_override("font_size", 12)
		
		var value_label = Label.new()
		if bonus > 0:
			value_label.text = "%d (+%d)" % [current_val, bonus]
			value_label.modulate = Color.GREEN
		else:
			value_label.text = str(current_val)
		value_label.add_theme_font_size_override("font_size", 12)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		main_stats_grid.add_child(stat_label)
		main_stats_grid.add_child(value_label)
	
	god_stats_container.add_child(main_stats_grid)

func refresh_detailed_stats():
	"""Refresh detailed combat stats - RULE 4: UI display only"""
	if not selected_god or not detailed_stats_panel:
		return
	
	# Clear existing detailed stats
	for child in detailed_stats_panel.get_children():
		child.queue_free()
	
	# Get detailed stats
	var base_stats = {
		"Crit Rate": selected_god.base_crit_rate,
		"Crit Damage": selected_god.base_crit_damage,
		"Accuracy": selected_god.base_accuracy,
		"Resistance": selected_god.base_resistance
	}
	
	var current_stats = {
		"Crit Rate": GodCalculator.get_current_crit_rate(selected_god),
		"Crit Damage": GodCalculator.get_current_crit_damage(selected_god),
		"Accuracy": GodCalculator.get_current_accuracy(selected_god),
		"Resistance": GodCalculator.get_current_resistance(selected_god)
	}
	
	# Secondary stats grid
	var secondary_stats_label = Label.new()
	secondary_stats_label.text = "Advanced Stats"
	secondary_stats_label.add_theme_font_size_override("font_size", 12)
	secondary_stats_label.modulate = Color(0.8, 0.8, 0.8)
	detailed_stats_panel.add_child(secondary_stats_label)
	
	var secondary_stats_grid = GridContainer.new()
	secondary_stats_grid.columns = 2
	secondary_stats_grid.add_theme_constant_override("h_separation", 8)
	secondary_stats_grid.add_theme_constant_override("v_separation", 1)
	
	for stat_name in ["Crit Rate", "Crit Damage", "Accuracy", "Resistance"]:
		var base_val = base_stats[stat_name]
		var current_val = current_stats[stat_name]
		var bonus = current_val - base_val
		
		var stat_label = Label.new()
		stat_label.text = stat_name + ":"
		stat_label.add_theme_font_size_override("font_size", 10)
		
		var value_label = Label.new()
		if stat_name in ["Crit Rate", "Accuracy", "Resistance"]:
			# Percentage stats
			if bonus > 0:
				value_label.text = "%.1f%% (+%.1f%%)" % [current_val, bonus]
				value_label.modulate = Color.GREEN
			else:
				value_label.text = "%.1f%%" % current_val
		else:
			# Crit Damage 
			if bonus > 0:
				value_label.text = "%.1f%% (+%.1f%%)" % [current_val, bonus]
				value_label.modulate = Color.GREEN
			else:
				value_label.text = "%.1f%%" % current_val
		
		value_label.add_theme_font_size_override("font_size", 10)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		secondary_stats_grid.add_child(stat_label)
		secondary_stats_grid.add_child(value_label)
	
	detailed_stats_panel.add_child(secondary_stats_grid)

func refresh_set_bonuses():
	"""Display equipment set bonuses - RULE 4: UI display only"""
	if not selected_god or not set_bonus_panel:
		return
	
	# Clear existing set info
	for child in set_bonus_panel.get_children():
		child.queue_free()
	
	# Get equipped items from EquipmentManager
	var system_registry = SystemRegistry.get_instance()
	var equipment_manager = system_registry.get_system("EquipmentManager") if system_registry else null
	if not equipment_manager:
		return
	
	# Count equipment sets
	var set_counts = {}
	for slot in range(6):  # 6 equipment slots
		var equipped = equipment_manager.get_equipped_equipment(selected_god, slot)
		if equipped and not equipped.equipment_set.is_empty():
			if equipped.equipment_set in set_counts:
				set_counts[equipped.equipment_set] += 1
			else:
				set_counts[equipped.equipment_set] = 1
	
	if set_counts.is_empty():
		return
	
	# Display set bonuses
	var set_title = Label.new()
	set_title.text = "Set Bonuses"
	set_title.add_theme_font_size_override("font_size", 12)
	set_title.modulate = Color(0.8, 0.8, 0.8)
	set_bonus_panel.add_child(set_title)
	
	for equipment_set in set_counts.keys():
		var piece_count = set_counts[equipment_set]
		var set_label = Label.new()
		set_label.text = "%s Set (%d/6)" % [equipment_set, piece_count]
		set_label.add_theme_font_size_override("font_size", 10)
		
		# Color based on set completion
		if piece_count >= 4:
			set_label.modulate = Color.GOLD
		elif piece_count >= 2:
			set_label.modulate = Color.GREEN
		else:
			set_label.modulate = Color.GRAY
		
		set_bonus_panel.add_child(set_label)
		
		# Add set bonus description
		var bonus_desc = get_set_bonus_description(equipment_set, piece_count)
		if not bonus_desc.is_empty():
			var desc_label = Label.new()
			desc_label.text = "  " + bonus_desc
			desc_label.add_theme_font_size_override("font_size", 9)
			desc_label.modulate = Color(0.9, 0.9, 0.9)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			set_bonus_panel.add_child(desc_label)

func get_set_bonus_description(equipment_set: String, _piece_count: int) -> String:
	"""Get description of set bonus effects - RULE 4: UI helper only"""
	# Simple set bonus descriptions (would normally come from data)
	var bonuses = {
		"Swift": "2-piece: +25% Speed",
		"Violent": "4-piece: +22% chance for extra turn", 
		"Despair": "2-piece: +25% Accuracy",
		"Energy": "2-piece: +15% HP",
		"Blade": "2-piece: +12% Crit Rate"
	}
	
	if equipment_set in bonuses:
		return bonuses[equipment_set]
	return ""
