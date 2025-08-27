# scripts/ui/components/GodSelectionPanel.gd
# Single responsibility: Handle god selection for territory roles
class_name GodSelectionPanel extends Node

# God selection signals
signal god_selected(god_id: String, role_name: String, slot_index: int)
signal selection_cancelled

var selection_popup: PopupPanel
var god_list_container: Control
var current_role: String
var current_slot_index: int
var available_gods: Array = []

func initialize():
	"""Initialize the god selection panel"""
	create_selection_popup()
	print("GodSelectionPanel: Initialized")

func create_selection_popup():
	"""Create the god selection popup window"""
	selection_popup = PopupPanel.new()
	selection_popup.set_flag(Window.FLAG_BORDERLESS, false)
	selection_popup.set_flag(Window.FLAG_RESIZE_DISABLED, true)
	selection_popup.popup_hide.connect(_on_selection_popup_closed)
	
	# Set popup size and make it modal
	selection_popup.size = Vector2(800, 600)
	selection_popup.set_flag(Window.FLAG_POPUP, true)
	add_child(selection_popup)
	
	# Create main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	selection_popup.add_child(main_vbox)
	
	# Header
	var header_label = Label.new()
	header_label.text = "Select God for Role"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.modulate = Color.CYAN
	main_vbox.add_child(header_label)
	
	# Filters and sorting (placeholder for now)
	var filter_hbox = HBoxContainer.new()
	main_vbox.add_child(filter_hbox)
	
	var filter_label = Label.new()
	filter_label.text = "Filter by Element:"
	filter_hbox.add_child(filter_label)
	
	var element_filter = OptionButton.new()
	element_filter.add_item("All Elements")
	element_filter.add_item("Fire")
	element_filter.add_item("Water")
	element_filter.add_item("Earth")
	element_filter.add_item("Air")
	element_filter.add_item("Light")
	element_filter.add_item("Dark")
	element_filter.item_selected.connect(_on_element_filter_changed)
	filter_hbox.add_child(element_filter)
	
	# Scroll container for god list
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)
	
	god_list_container = VBoxContainer.new()
	god_list_container.add_theme_constant_override("separation", 5)
	scroll_container.add_child(god_list_container)
	
	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_button)

func show_god_selection(role_name: String, slot_index: int):
	"""Show god selection popup for a specific role and slot"""
	current_role = role_name
	current_slot_index = slot_index
	
	# Update header
	var header = selection_popup.get_child(0).get_child(0) as Label
	header.text = "Select God for %s Role (Slot %d)" % [role_name, slot_index + 1]
	
	# Load available gods
	load_available_gods()
	refresh_god_list()
	
	# Show popup centered on screen
	selection_popup.popup_centered()

func load_available_gods():
	"""Load available gods from CollectionManager - RULE 5: Use SystemRegistry"""
	available_gods.clear()
	
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var collection_manager = system_registry.get_system("CollectionManager")
		if collection_manager:
			available_gods = collection_manager.get_all_gods()
		else:
			print("GodSelectionPanel: CollectionManager not found in SystemRegistry")
	
	# Filter out gods already assigned to this territory
	available_gods = filter_available_gods(available_gods)

func filter_available_gods(gods: Array) -> Array:
	"""Filter out gods that are already assigned to territory roles"""
	var filtered_gods = []
	
	var system_registry = SystemRegistry.get_instance()
	var territory_manager = null
	if system_registry:
		territory_manager = system_registry.get_system("TerritoryManager")
	
	for god in gods:
		var is_available = true
		
		# Check if god is already assigned to a territory role
		if territory_manager:
			is_available = not territory_manager.is_god_assigned_to_territory(god.id)
		
		if is_available:
			filtered_gods.append(god)
	
	return filtered_gods

func refresh_god_list():
	"""Refresh the displayed god list"""
	# Clear existing god items
	for child in god_list_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	if available_gods.is_empty():
		var no_gods_label = Label.new()
		no_gods_label.text = "No available gods found. All gods may already be assigned to territories."
		no_gods_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_gods_label.modulate = Color.YELLOW
		god_list_container.add_child(no_gods_label)
		return
	
	# Create god selection items
	for god in available_gods:
		var god_item = create_god_selection_item(god)
		god_list_container.add_child(god_item)

func create_god_selection_item(god_data) -> Control:
	"""Create a selectable item for a god"""
	var item_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	panel_style.border_color = Color.GRAY
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	item_panel.add_theme_stylebox_override("panel", panel_style)
	item_panel.custom_minimum_size = Vector2(750, 80)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	main_hbox.add_theme_constant_override("separation", 15)
	item_panel.add_child(main_hbox)
	
	# God basic info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = god_data.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.modulate = Color.CYAN
	info_vbox.add_child(name_label)
	
	var element_awakened_hbox = HBoxContainer.new()
	info_vbox.add_child(element_awakened_hbox)
	
	var element_label = Label.new()
	element_label.text = "Element: %s" % god_data.get_element_name()
	element_label.add_theme_font_size_override("font_size", 12)
	element_label.modulate = Color.YELLOW
	element_awakened_hbox.add_child(element_label)
	
	var awakened_label = Label.new()
	awakened_label.text = "★ Awakened" if god_data.is_awakened else "☆ Unawakened"
	awakened_label.add_theme_font_size_override("font_size", 12)
	awakened_label.modulate = Color.GREEN if god_data.is_awakened else Color.GRAY
	element_awakened_hbox.add_child(awakened_label)
	
	# God stats summary
	var stats_vbox = VBoxContainer.new()
	stats_vbox.custom_minimum_size = Vector2(150, 0)
	main_hbox.add_child(stats_vbox)
	
	var stats_header = Label.new()
	stats_header.text = "Stats"
	stats_header.add_theme_font_size_override("font_size", 12)
	stats_header.modulate = Color.LIGHT_GRAY
	stats_vbox.add_child(stats_header)
	
	var hp_label = Label.new()
	hp_label.text = "HP: %d" % god_data.base_hp
	hp_label.add_theme_font_size_override("font_size", 10)
	stats_vbox.add_child(hp_label)
	
	var attack_label = Label.new()
	attack_label.text = "ATK: %d" % god_data.base_attack
	attack_label.add_theme_font_size_override("font_size", 10)
	stats_vbox.add_child(attack_label)
	
	var defense_label = Label.new()
	defense_label.text = "DEF: %d" % god_data.base_defense
	defense_label.add_theme_font_size_override("font_size", 10)
	stats_vbox.add_child(defense_label)
	
	var speed_label = Label.new()
	speed_label.text = "SPD: %d" % god_data.base_speed
	speed_label.add_theme_font_size_override("font_size", 10)
	stats_vbox.add_child(speed_label)
	
	# Role effectiveness
	var effectiveness_vbox = VBoxContainer.new()
	effectiveness_vbox.custom_minimum_size = Vector2(120, 0)
	main_hbox.add_child(effectiveness_vbox)
	
	var eff_header = Label.new()
	eff_header.text = "Role Fit"
	eff_header.add_theme_font_size_override("font_size", 12)
	eff_header.modulate = Color.LIGHT_GRAY
	effectiveness_vbox.add_child(eff_header)
	
	var effectiveness = calculate_role_effectiveness(god_data, current_role)
	var eff_label = Label.new()
	eff_label.text = "%d%%" % effectiveness
	eff_label.add_theme_font_size_override("font_size", 14)
	eff_label.modulate = get_effectiveness_color(effectiveness)
	effectiveness_vbox.add_child(eff_label)
	
	var eff_desc = Label.new()
	eff_desc.text = get_effectiveness_description(effectiveness)
	eff_desc.add_theme_font_size_override("font_size", 9)
	eff_desc.modulate = Color.LIGHT_GRAY
	effectiveness_vbox.add_child(eff_desc)
	
	# Select button
	var select_button = Button.new()
	select_button.text = "Select"
	select_button.custom_minimum_size = Vector2(80, 50)
	select_button.pressed.connect(_on_god_selected.bind(god_data))
	main_hbox.add_child(select_button)
	
	return item_panel

# === EVENT HANDLERS ===

func _on_god_selected(god_data):
	"""Handle god selection"""
	print("GodSelectionPanel: Selected god %s for %s role slot %d" % [god_data.name, current_role, current_slot_index])
	
	# Assign god through SystemRegistry - RULE 5 compliance
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			# This would need to be implemented in TerritoryManager
			# territory_manager.assign_god_to_role(territory_id, current_role, current_slot_index, god_data.id)
			pass
		else:
			print("GodSelectionPanel: TerritoryManager not found in SystemRegistry")
	
	god_selected.emit(god_data.id, current_role, current_slot_index)
	selection_popup.hide()

func _on_cancel_pressed():
	"""Handle cancel button press"""
	selection_popup.hide()
	selection_cancelled.emit()

func _on_selection_popup_closed():
	"""Handle popup close event"""
	print("GodSelectionPanel: Selection popup closed")

func _on_element_filter_changed(index: int):
	"""Handle element filter change"""
	print("GodSelectionPanel: Filter changed to index %d" % index)
	# TODO: Implement filtering by element
	# For now, just refresh the list
	refresh_god_list()

# === UTILITY FUNCTIONS ===

func calculate_role_effectiveness(god_data, role_name: String) -> int:
	"""Calculate how effective a god would be in the specified role"""
	var base_effectiveness = 60
	
	# Role-specific stat preferences
	match role_name:
		"Guardian":
			# Guardians prefer high HP and Defense
			var hp_score = min(god_data.base_hp / 200, 25)  # Up to 25 points from HP
			var def_score = min(god_data.base_defense / 40, 15)  # Up to 15 points from Defense
			base_effectiveness += hp_score + def_score
		"Producer":
			# Producers prefer balanced stats
			var avg_stat = (god_data.base_attack + god_data.base_defense + (god_data.base_hp / 100)) / 3
			var balance_score = min(avg_stat / 50, 30)
			base_effectiveness += balance_score
		"Scout":
			# Scouts prefer speed and attack
			var speed_score = min(god_data.base_speed / 10, 20)  # Up to 20 points from Speed
			var attack_score = min(god_data.base_attack / 60, 15)  # Up to 15 points from Attack
			base_effectiveness += speed_score + attack_score
	
	# Awakening bonus
	if god_data.is_awakened:
		base_effectiveness += 10
	
	return min(base_effectiveness, 100)

func get_effectiveness_color(effectiveness: int) -> Color:
	"""Get color for effectiveness percentage"""
	if effectiveness >= 85:
		return Color.GREEN
	elif effectiveness >= 70:
		return Color.YELLOW
	elif effectiveness >= 55:
		return Color.ORANGE
	else:
		return Color.RED

func get_effectiveness_description(effectiveness: int) -> String:
	"""Get description for effectiveness level"""
	if effectiveness >= 85:
		return "Excellent"
	elif effectiveness >= 70:
		return "Good"
	elif effectiveness >= 55:
		return "Fair"
	else:
		return "Poor"
