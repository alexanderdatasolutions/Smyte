# scripts/ui/components/TerritoryRoleManager.gd
# Single responsibility: Manage territory role assignments
class_name TerritoryRoleManager extends Node

# Role management signals
signal role_assignment_changed(role: String, god_id: String, slot_index: int)
signal role_slots_refreshed(role: String)

var role_container: Control
var current_territory: Territory

# Cache role sections for efficient updates
var role_sections: Dictionary = {}

func initialize(role_panel: Control):
	"""Initialize with the role management panel"""
	role_container = role_panel
	print("TerritoryRoleManager: Initialized")

func refresh_roles_display(territory: Territory):
	"""Refresh all role slots display - FOLLOWING RULE 4: UI ONLY"""
	current_territory = territory
	
	if not current_territory or not role_container:
		return
	
	# Clear existing role display
	for child in role_container.get_children():
		child.queue_free()
	role_sections.clear()
	
	await get_tree().process_frame
	
	# Create main roles container
	var main_roles_vbox = VBoxContainer.new()
	main_roles_vbox.add_theme_constant_override("separation", 15)
	role_container.add_child(main_roles_vbox)
	
	# Get territory roles through SystemRegistry - RULE 5 compliance
	var system_registry = SystemRegistry.get_instance()
	var territory_roles = []
	
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			territory_roles = territory_manager.get_available_territory_roles(current_territory)
		else:
			print("TerritoryRoleManager: TerritoryManager not found in SystemRegistry")
	
	# Fallback if system not available
	if territory_roles.is_empty():
		territory_roles = ["Guardian", "Producer", "Scout"]
	
	# Create each role section
	for role in territory_roles:
		var role_section = create_role_section(role)
		main_roles_vbox.add_child(role_section)
		role_sections[role] = role_section

func create_role_section(role_name: String) -> Control:
	"""Create a role section with slots and god assignments"""
	var role_vbox = VBoxContainer.new()
	role_vbox.add_theme_constant_override("separation", 8)
	
	# Role header with background
	var role_header_panel = Panel.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = get_role_color(role_name)
	header_style.corner_radius_top_left = 5
	header_style.corner_radius_top_right = 5
	header_style.corner_radius_bottom_left = 5
	header_style.corner_radius_bottom_right = 5
	role_header_panel.add_theme_stylebox_override("panel", header_style)
	role_header_panel.custom_minimum_size = Vector2(0, 40)
	role_vbox.add_child(role_header_panel)
	
	# Role title and description
	var header_hbox = HBoxContainer.new()
	header_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	role_header_panel.add_child(header_hbox)
	
	var role_title = Label.new()
	role_title.text = "⚔️ %s" % role_name
	role_title.add_theme_font_size_override("font_size", 16)
	role_title.modulate = Color.WHITE
	header_hbox.add_child(role_title)
	
	header_hbox.add_child(VSeparator.new())
	
	var role_desc = Label.new()
	role_desc.text = get_role_description(role_name)
	role_desc.add_theme_font_size_override("font_size", 11)
	role_desc.modulate = Color.LIGHT_GRAY
	role_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(role_desc)
	
	# Role slots container
	var slots_container = HBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 10)
	role_vbox.add_child(slots_container)
	
	# Create role slots based on territory tier
	var slot_count = get_role_slot_count(role_name, current_territory.tier)
	for slot_index in slot_count:
		var slot_panel = create_role_slot(role_name, slot_index)
		slots_container.add_child(slot_panel)
	
	return role_vbox

func create_role_slot(role_name: String, slot_index: int) -> Control:
	"""Create a single role slot that can hold a god"""
	var slot_panel = Panel.new()
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	slot_style.border_color = Color.CYAN
	slot_style.border_width_left = 2
	slot_style.border_width_right = 2
	slot_style.border_width_top = 2
	slot_style.border_width_bottom = 2
	slot_style.corner_radius_top_left = 8
	slot_style.corner_radius_top_right = 8
	slot_style.corner_radius_bottom_left = 8
	slot_style.corner_radius_bottom_right = 8
	slot_panel.add_theme_stylebox_override("panel", slot_style)
	slot_panel.custom_minimum_size = Vector2(200, 120)
	
	var slot_vbox = VBoxContainer.new()
	slot_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	slot_panel.add_child(slot_vbox)
	
	# Get assigned god through SystemRegistry - RULE 5 compliance
	var assigned_god = get_assigned_god_for_slot(role_name, slot_index)
	
	if assigned_god:
		# Show assigned god
		create_assigned_god_display(slot_vbox, assigned_god, role_name, slot_index)
	else:
		# Show empty slot
		create_empty_slot_display(slot_vbox, role_name, slot_index)
	
	return slot_panel

func create_assigned_god_display(container: Control, god_data, role_name: String, slot_index: int):
	"""Create display for an assigned god in a role slot"""
	# God name and element
	var god_label = Label.new()
	god_label.text = god_data.name
	god_label.add_theme_font_size_override("font_size", 14)
	god_label.modulate = Color.CYAN
	god_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(god_label)
	
	var element_label = Label.new()
	element_label.text = "Element: %s" % god_data.get_element_name()
	element_label.add_theme_font_size_override("font_size", 11)
	element_label.modulate = Color.YELLOW
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(element_label)
	
	# God effectiveness in this role
	var effectiveness = calculate_god_role_effectiveness(god_data, role_name)
	var effectiveness_label = Label.new()
	effectiveness_label.text = "Effectiveness: %d%%" % effectiveness
	effectiveness_label.add_theme_font_size_override("font_size", 10)
	effectiveness_label.modulate = get_effectiveness_color(effectiveness)
	effectiveness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(effectiveness_label)
	
	# Action buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(button_hbox)
	
	var reassign_button = Button.new()
	reassign_button.text = "Reassign"
	reassign_button.add_theme_font_size_override("font_size", 10)
	reassign_button.pressed.connect(_on_reassign_god_pressed.bind(role_name, slot_index))
	button_hbox.add_child(reassign_button)
	
	var remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.add_theme_font_size_override("font_size", 10)
	remove_button.pressed.connect(_on_remove_god_pressed.bind(role_name, slot_index))
	button_hbox.add_child(remove_button)

func create_empty_slot_display(container: Control, role_name: String, slot_index: int):
	"""Create display for an empty role slot"""
	var empty_label = Label.new()
	empty_label.text = "Empty Slot"
	empty_label.add_theme_font_size_override("font_size", 14)
	empty_label.modulate = Color.GRAY
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(empty_label)
	
	var slot_desc = Label.new()
	slot_desc.text = "Click to assign a god to this %s role" % role_name.to_lower()
	slot_desc.add_theme_font_size_override("font_size", 10)
	slot_desc.modulate = Color.LIGHT_GRAY
	slot_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_desc.custom_minimum_size = Vector2(180, 0)
	container.add_child(slot_desc)
	
	# Add spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer)
	
	# Assign button
	var assign_button = Button.new()
	assign_button.text = "Assign God"
	assign_button.add_theme_font_size_override("font_size", 12)
	assign_button.pressed.connect(_on_assign_god_pressed.bind(role_name, slot_index))
	container.add_child(assign_button)

# === EVENT HANDLERS ===

func _on_assign_god_pressed(role_name: String, slot_index: int):
	"""Handle assign god button press"""
	print("TerritoryRoleManager: Assign god to %s slot %d" % [role_name, slot_index])
	role_assignment_changed.emit(role_name, "", slot_index)

func _on_reassign_god_pressed(role_name: String, slot_index: int):
	"""Handle reassign god button press"""
	print("TerritoryRoleManager: Reassign god in %s slot %d" % [role_name, slot_index])
	role_assignment_changed.emit(role_name, "", slot_index)

func _on_remove_god_pressed(role_name: String, slot_index: int):
	"""Handle remove god button press"""
	print("TerritoryRoleManager: Remove god from %s slot %d" % [role_name, slot_index])
	
	# Remove god assignment through SystemRegistry - RULE 5 compliance
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			territory_manager.unassign_god_from_role(current_territory.id, role_name, slot_index)
			refresh_single_role_slots(role_name)
		else:
			print("TerritoryRoleManager: TerritoryManager not found in SystemRegistry")

func refresh_single_role_slots(role_name: String):
	"""Refresh slots for a specific role"""
	if role_sections.has(role_name):
		var role_section = role_sections[role_name]
		# Find and refresh the slots container
		for child in role_section.get_children():
			if child is HBoxContainer:
				# This is the slots container
				for slot_child in child.get_children():
					slot_child.queue_free()
				
				await get_tree().process_frame
				
				# Recreate slots
				var slot_count = get_role_slot_count(role_name, current_territory.tier)
				for slot_index in slot_count:
					var slot_panel = create_role_slot(role_name, slot_index)
					child.add_child(slot_panel)
				break
	
	role_slots_refreshed.emit(role_name)

# === UTILITY FUNCTIONS ===

func get_assigned_god_for_slot(role_name: String, slot_index: int):
	"""Get god assigned to specific role slot - RULE 5: Use SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			return territory_manager.get_assigned_god_for_role(current_territory.id, role_name, slot_index)
		else:
			print("TerritoryRoleManager: TerritoryManager not found in SystemRegistry")
	
	return null

func get_role_slot_count(role_name: String, territory_tier: int) -> int:
	"""Calculate number of slots for a role based on territory tier"""
	var base_slots = 1
	match role_name:
		"Guardian": base_slots = 2
		"Producer": base_slots = 1
		"Scout": base_slots = 1
		_: base_slots = 1
	
	# Add tier bonus slots
	var bonus_slots = territory_tier - 1
	return base_slots + bonus_slots

func calculate_god_role_effectiveness(god_data, role_name: String) -> int:
	"""Calculate how effective a god is in a specific role"""
	var base_effectiveness = 70
	
	# Element matching bonus
	var god_element = god_data.get_element_name()
	var territory_element = current_territory.get_element_name()
	if god_element == territory_element:
		base_effectiveness += 30
	
	# Role-specific bonuses based on god stats
	match role_name:
		"Guardian":
			# Guardians benefit from high HP and Defense
			if god_data.base_hp > 15000:
				base_effectiveness += 15
			if god_data.base_defense > 800:
				base_effectiveness += 10
		"Producer":
			# Producers benefit from balanced stats
			var stat_balance = (god_data.base_attack + god_data.base_defense + god_data.base_hp / 100.0) / 3.0
			if stat_balance > 1000:
				base_effectiveness += 20
		"Scout":
			# Scouts benefit from speed and critical rate
			if god_data.base_speed > 120:
				base_effectiveness += 20
			# Note: Would need critical_rate from god data for full calculation
	
	return min(base_effectiveness, 100)

func get_role_color(role_name: String) -> Color:
	"""Get color associated with role type"""
	match role_name:
		"Guardian": return Color(0.8, 0.4, 0.2, 0.8)  # Orange-red
		"Producer": return Color(0.2, 0.6, 0.8, 0.8)  # Blue
		"Scout": return Color(0.6, 0.8, 0.3, 0.8)     # Green
		_: return Color(0.5, 0.5, 0.5, 0.8)          # Gray

func get_role_description(role_name: String) -> String:
	"""Get description of role function"""
	match role_name:
		"Guardian": return "Protects territory from attacks and increases defense"
		"Producer": return "Boosts resource generation and efficiency"
		"Scout": return "Provides territory intelligence and exploration bonuses"
		_: return "A specialized role with unique territory benefits"

func get_effectiveness_color(effectiveness: int) -> Color:
	"""Get color for effectiveness percentage"""
	if effectiveness >= 90:
		return Color.GREEN
	elif effectiveness >= 70:
		return Color.YELLOW
	elif effectiveness >= 50:
		return Color.ORANGE
	else:
		return Color.RED
