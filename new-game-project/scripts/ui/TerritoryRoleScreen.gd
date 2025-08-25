# scripts/ui/TerritoryRoleScreen.gd
extends Control
class_name TerritoryRoleScreen

signal back_pressed
signal role_assignments_changed

@onready var territory_info_panel = $VBoxContainer/TerritoryInfoPanel
@onready var role_slots_container = $VBoxContainer/ScrollContainer/RoleSlotsContainer
@onready var god_selection_panel = $VBoxContainer/GodSelectionPanel
@onready var back_button = $VBoxContainer/BackButton

var current_territory: Territory
var selected_role_slot: Dictionary = {}  # {role: "", slot_index: 0}
var role_assignments: Dictionary = {}  # Current assignments from TerritoryManager

func _ready():
	# Ensure UI nodes are connected
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	setup_ui()

func setup_ui():
	# Setup styling and basic UI structure
	custom_minimum_size = Vector2(1000, 700)
	
	# Verify essential UI components exist
	if not territory_info_panel:
		push_error("TerritoryRoleScreen: territory_info_panel not found")
	if not role_slots_container:
		push_error("TerritoryRoleScreen: role_slots_container not found")
	if not god_selection_panel:
		push_error("TerritoryRoleScreen: god_selection_panel not found")

func setup_for_territory(territory: Territory):
	"""Setup the screen for a specific territory"""
	current_territory = territory
	selected_role_slot = {}
	
	# Get current assignments from TerritoryManager
	role_assignments = GameManager.get_territory_role_assignments(territory)
	
	refresh_territory_display()
	refresh_role_slots()
	refresh_god_selection()

func refresh_territory_display():
	"""Update territory information display"""
	if not current_territory or not territory_info_panel:
		return
	
	# Clear existing territory info
	for child in territory_info_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create main territory info container
	var main_container = HBoxContainer.new()
	main_container.add_theme_constant_override("separation", 30)
	territory_info_panel.add_child(main_container)
	
	# Left side - Territory basic info
	var basic_info = create_territory_basic_info()
	main_container.add_child(basic_info)
	
	# Center - Current production breakdown
	var production_info = create_territory_production_info()
	main_container.add_child(production_info)
	
	# Right side - Territory bonuses and special effects
	var bonus_info = create_territory_bonus_info()
	main_container.add_child(bonus_info)

func create_territory_basic_info() -> Control:
	"""Create basic territory information section"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	
	# Territory header
	var header_label = Label.new()
	header_label.text = "%s" % current_territory.name
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.modulate = Color.WHITE
	vbox.add_child(header_label)
	
	# Territory tier and element with styled background
	var tier_panel = Panel.new()
	var tier_style = StyleBoxFlat.new()
	tier_style.bg_color = get_element_color(current_territory.get_element_name())
	tier_style.corner_radius_top_left = 5
	tier_style.corner_radius_top_right = 5
	tier_style.corner_radius_bottom_left = 5
	tier_style.corner_radius_bottom_right = 5
	tier_panel.add_theme_stylebox_override("panel", tier_style)
	tier_panel.custom_minimum_size = Vector2(0, 35)
	vbox.add_child(tier_panel)
	
	var tier_label = Label.new()
	tier_label.text = "Tier %d %s Territory" % [current_territory.tier, current_territory.get_element_name()]
	tier_label.add_theme_font_size_override("font_size", 14)
	tier_label.modulate = Color.BLACK
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tier_panel.add_child(tier_label)
	
	# Status and level
	var status_label = Label.new()
	status_label.text = "Status: %s | Level: %d" % [
		"CONTROLLED" if current_territory.is_controlled_by_player() else "NEUTRAL",
		current_territory.territory_level
	]
	status_label.modulate = Color.CYAN
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)
	
	# Territory description
	var desc_label = Label.new()
	desc_label.text = get_territory_description(current_territory)
	desc_label.modulate = Color.LIGHT_GRAY
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(desc_label)
	
	return vbox

func create_territory_production_info() -> Control:
	"""Create detailed production information section"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(350, 0)
	
	# Production header
	var prod_header = Label.new()
	prod_header.text = "🏭 Current Production"
	prod_header.add_theme_font_size_override("font_size", 16)
	prod_header.modulate = Color.GREEN
	vbox.add_child(prod_header)
	
	# Base production (without gods)
	var base_generation = {}
	if GameManager.territory_manager:
		base_generation = GameManager.territory_manager.get_base_territory_generation(current_territory)
	
	var base_label = Label.new()
	base_label.text = "Base Generation (no gods):"
	base_label.add_theme_font_size_override("font_size", 12)
	base_label.modulate = Color.YELLOW
	vbox.add_child(base_label)
	
	for resource_type in base_generation:
		var resource_label = Label.new()
		resource_label.text = "  • %s: %d/hr" % [resource_type.capitalize(), base_generation[resource_type]]
		resource_label.add_theme_font_size_override("font_size", 11)
		resource_label.modulate = Color.LIGHT_GRAY
		vbox.add_child(resource_label)
	
	# Current total production (with current gods)
	var total_generation = {}
	if GameManager.territory_manager:
		total_generation = GameManager.territory_manager.calculate_territory_passive_generation(current_territory)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var total_label = Label.new()
	total_label.text = "Current Total Generation:"
	total_label.add_theme_font_size_override("font_size", 12)
	total_label.modulate = Color.WHITE
	vbox.add_child(total_label)
	
	for resource_type in total_generation:
		var resource_label = Label.new()
		var base_amount = base_generation.get(resource_type, 0)
		var total_amount = total_generation[resource_type]
		var bonus_amount = total_amount - base_amount
		
		var bonus_text = ""
		if bonus_amount > 0:
			bonus_text = " (+%d from gods)" % bonus_amount
			resource_label.modulate = Color.GREEN
		else:
			resource_label.modulate = Color.WHITE
		
		resource_label.text = "  • %s: %d/hr%s" % [resource_type.capitalize(), total_amount, bonus_text]
		resource_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(resource_label)
	
	return vbox

func create_territory_bonus_info() -> Control:
	"""Create territory bonus and special effects section"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	
	# Bonuses header
	var bonus_header = Label.new()
	bonus_header.text = "⭐ Territory Effects"
	bonus_header.add_theme_font_size_override("font_size", 16)
	bonus_header.modulate = Color.YELLOW
	vbox.add_child(bonus_header)
	
	# Element bonuses
	var element_bonus_label = Label.new()
	element_bonus_label.text = "Element Bonuses:"
	element_bonus_label.add_theme_font_size_override("font_size", 12)
	element_bonus_label.modulate = Color.CYAN
	vbox.add_child(element_bonus_label)
	
	var element_name = current_territory.get_element_name()
	var element_desc = Label.new()
	element_desc.text = get_element_bonus_description(element_name)
	element_desc.add_theme_font_size_override("font_size", 10)
	element_desc.modulate = Color.LIGHT_GRAY
	element_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	element_desc.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(element_desc)
	
	# Tier bonuses
	var tier_bonus_label = Label.new()
	tier_bonus_label.text = "Tier %d Benefits:" % current_territory.tier
	tier_bonus_label.add_theme_font_size_override("font_size", 12)
	tier_bonus_label.modulate = Color.CYAN
	vbox.add_child(tier_bonus_label)
	
	var tier_desc = Label.new()
	tier_desc.text = get_tier_bonus_description(current_territory.tier)
	tier_desc.add_theme_font_size_override("font_size", 10)
	tier_desc.modulate = Color.LIGHT_GRAY
	tier_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_desc.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(tier_desc)
	
	return vbox

func refresh_role_slots():
	"""Update role slot displays"""
	if not current_territory or not role_slots_container:
		return
	
	# Clear existing slots
	for child in role_slots_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get slot configuration
	var slot_config = {}
	if GameManager.territory_manager:
		slot_config = GameManager.territory_manager.get_territory_slot_configuration(current_territory)
	else:
		slot_config = {"defender_slots": 1, "gatherer_slots": 2, "crafter_slots": 1}
	
	# Create role slot sections
	for role in ["defender", "gatherer", "crafter"]:
		var role_section = create_role_section(role, slot_config[role + "_slots"])
		role_slots_container.add_child(role_section)

func create_role_section(role: String, max_slots: int) -> Control:
	"""Create UI section for a specific role"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	
	# Role header
	var header = create_role_header(role, max_slots)
	section.add_child(header)
	
	# Role slots
	var slots_container = HBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 15)
	
	for slot_index in range(max_slots):
		var slot_panel = create_role_slot_panel(role, slot_index)
		slots_container.add_child(slot_panel)
	
	section.add_child(slots_container)
	
	return section

func create_role_header(role: String, max_slots: int) -> Control:
	"""Create enhanced header for role section"""
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 5)
	
	# Top row - role name and slots
	var header_container = HBoxContainer.new()
	
	# Role icon and name
	var role_label = Label.new()
	role_label.text = get_role_display_name(role) + " (%d slots)" % max_slots
	role_label.add_theme_font_size_override("font_size", 16)
	role_label.modulate = get_role_color(role)
	header_container.add_child(role_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(spacer)
	
	# Current efficiency display
	var efficiency_display = create_role_efficiency_display(role)
	header_container.add_child(efficiency_display)
	
	main_container.add_child(header_container)
	
	# Role description and impact
	var desc_container = VBoxContainer.new()
	desc_container.add_theme_constant_override("separation", 3)
	
	# Role description
	var desc_label = Label.new()
	desc_label.text = get_role_description(role)
	desc_label.modulate = Color.LIGHT_GRAY
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_container.add_child(desc_label)
	
	# Role impact on THIS territory
	var impact_label = Label.new()
	impact_label.text = get_role_territory_impact(role, current_territory)
	impact_label.modulate = Color.YELLOW
	impact_label.add_theme_font_size_override("font_size", 10)
	impact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_container.add_child(impact_label)
	
	main_container.add_child(desc_container)
	
	return main_container

func create_role_efficiency_display(role: String) -> Control:
	"""Create current efficiency display for a role"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	
	# Get current gods in this role
	var current_gods = role_assignments.get(role, [])
	var total_efficiency = 0.0
	
	for god in current_gods:
		if GameManager.territory_manager:
			total_efficiency += GameManager.territory_manager.get_god_role_efficiency(god, role)
	
	# Efficiency label
	var eff_label = Label.new()
	if current_gods.size() > 0:
		var avg_efficiency = total_efficiency / current_gods.size()
		eff_label.text = "Avg: %.0f%%" % (avg_efficiency * 100.0)
		eff_label.modulate = Color.GREEN if avg_efficiency >= 1.0 else Color.ORANGE
	else:
		eff_label.text = "Empty"
		eff_label.modulate = Color.GRAY
	
	eff_label.add_theme_font_size_override("font_size", 12)
	container.add_child(eff_label)
	
	return container

func create_role_slot_panel(role: String, slot_index: int) -> Control:
	"""Create individual role slot panel"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 120)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = get_role_color(role)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	# Content container
	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_top", 10)
	content.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(content)
	
	# Check if slot is occupied
	var assigned_god = get_god_in_role_slot(role, slot_index)
	
	if assigned_god:
		create_occupied_slot_content(content, assigned_god, role)
	else:
		create_empty_slot_content(content, role, slot_index)
	
	return panel

func get_god_in_role_slot(role: String, slot_index: int) -> God:
	"""Get god assigned to specific role slot"""
	if not role_assignments.has(role):
		return null
	
	var gods_in_role = role_assignments[role]
	if slot_index < gods_in_role.size():
		return gods_in_role[slot_index]
	
	return null

func create_occupied_slot_content(content: VBoxContainer, god: God, role: String):
	"""Create content for occupied slot"""
	# God name and level
	var name_label = Label.new()
	name_label.text = god.name + " (Lv.%d)" % god.level
	name_label.add_theme_font_size_override("font_size", 12)
	content.add_child(name_label)
	
	# God tier and element
	var info_label = Label.new()
	info_label.text = "%s %s" % [god.get_tier_name(), god.get_element_name()]
	info_label.modulate = Color.YELLOW
	info_label.add_theme_font_size_override("font_size", 10)
	content.add_child(info_label)
	
	# Role efficiency
	var efficiency = 1.0
	if GameManager.territory_manager:
		efficiency = GameManager.territory_manager.get_god_role_efficiency(god, role)
	
	var efficiency_label = Label.new()
	efficiency_label.text = "Efficiency: %.0f%%" % (efficiency * 100.0)
	efficiency_label.modulate = Color.GREEN if efficiency >= 1.0 else Color.ORANGE
	efficiency_label.add_theme_font_size_override("font_size", 10)
	content.add_child(efficiency_label)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_btn.pressed.connect(_on_remove_god_from_slot.bind(god))
	content.add_child(remove_btn)

func create_empty_slot_content(content: VBoxContainer, role: String, slot_index: int):
	"""Create content for empty slot"""
	# Empty slot indicator
	var empty_label = Label.new()
	empty_label.text = "Empty Slot"
	empty_label.modulate = Color.GRAY
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(empty_label)
	
	# Role requirements
	var req_label = Label.new()
	req_label.text = "Requires: %s role" % role.capitalize()
	req_label.modulate = Color.GRAY
	req_label.add_theme_font_size_override("font_size", 10)
	req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(req_label)
	
	# Assign button
	var assign_btn = Button.new()
	assign_btn.text = "Assign God"
	assign_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign_btn.pressed.connect(_on_select_role_slot.bind(role, slot_index))
	content.add_child(assign_btn)

func refresh_god_selection():
	"""Update god selection panel"""
	if not current_territory or not god_selection_panel:
		return
	
	# Clear existing gods
	for child in god_selection_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Header
	var header_label = Label.new()
	if selected_role_slot.is_empty():
		header_label.text = "Select a slot to assign gods"
		header_label.modulate = Color.GRAY
	else:
		header_label.text = "Available gods for %s role:" % selected_role_slot.get("role", "").capitalize()
		header_label.modulate = Color.CYAN
	
	god_selection_panel.add_child(header_label)
	
	# Show available gods if slot is selected
	if not selected_role_slot.is_empty():
		show_available_gods_for_role()

func show_available_gods_for_role():
	"""Show gods available for the selected role"""
	var role = selected_role_slot.get("role", "")
	
	if not GameManager or not GameManager.player_data:
		return
	
	# Create scrollable container
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	god_selection_panel.add_child(scroll)
	
	var god_list = VBoxContainer.new()
	god_list.add_theme_constant_override("separation", 5)
	scroll.add_child(god_list)
	
	# Add available gods
	for god in GameManager.player_data.gods:
		if can_god_be_assigned_to_role(god, role):
			var god_item = create_god_selection_item(god)
			god_list.add_child(god_item)

func can_god_be_assigned_to_role(god: God, role: String) -> bool:
	"""Check if god can be assigned to the role"""
	# God must not be stationed elsewhere
	if not god.stationed_territory.is_empty() and god.stationed_territory != current_territory.id:
		return false
	
	# God must be able to perform the role
	var available_roles = GameManager.get_god_available_roles(god)
	return available_roles.has(role)

func create_god_selection_item(god: God) -> Control:
	"""Create enhanced god selection item with predictions"""
	var item = Panel.new()
	item.custom_minimum_size = Vector2(0, 80)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.4, 0.7)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	item.add_theme_stylebox_override("panel", style)
	
	# Content
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("margin_left", 10)
	hbox.add_theme_constant_override("margin_right", 10)
	hbox.add_theme_constant_override("margin_top", 10)
	hbox.add_theme_constant_override("margin_bottom", 10)
	hbox.add_theme_constant_override("separation", 15)
	item.add_child(hbox)
	
	# Left - God info
	var god_info = VBoxContainer.new()
	god_info.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(god_info)
	
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [god.name, god.level]
	name_label.add_theme_font_size_override("font_size", 12)
	god_info.add_child(name_label)
	
	var details_label = Label.new()
	details_label.text = "%s %s" % [god.get_tier_name(), god.get_element_name()]
	details_label.modulate = Color.YELLOW
	details_label.add_theme_font_size_override("font_size", 10)
	god_info.add_child(details_label)
	
	# Center - Role performance prediction
	var prediction_info = create_god_role_prediction(god)
	hbox.add_child(prediction_info)
	
	# Right - Assign button
	var assign_btn = Button.new()
	assign_btn.text = "Assign"
	assign_btn.custom_minimum_size = Vector2(80, 0)
	assign_btn.pressed.connect(_on_assign_god_to_slot.bind(god))
	hbox.add_child(assign_btn)
	
	return item

func create_god_role_prediction(god: God) -> Control:
	"""Create prediction panel showing what this god will contribute"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 2)
	
	var role = selected_role_slot.get("role", "")
	if role.is_empty():
		return vbox
	
	# Efficiency for this role
	var efficiency = 1.0
	if GameManager.territory_manager:
		efficiency = GameManager.territory_manager.get_god_role_efficiency(god, role)
	
	var efficiency_label = Label.new()
	efficiency_label.text = "Efficiency: %.0f%%" % (efficiency * 100.0)
	efficiency_label.modulate = Color.GREEN if efficiency >= 1.0 else Color.ORANGE
	efficiency_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(efficiency_label)
	
	# Predicted resource contribution
	var contribution = {}
	if GameManager.territory_manager:
		contribution = GameManager.territory_manager.calculate_god_contribution(god, role, current_territory)
	
	if contribution.size() > 0:
		var contrib_label = Label.new()
		contrib_label.text = "Will generate:"
		contrib_label.add_theme_font_size_override("font_size", 10)
		contrib_label.modulate = Color.CYAN
		vbox.add_child(contrib_label)
		
		for resource_type in contribution:
			if contribution[resource_type] > 0:
				var resource_label = Label.new()
				resource_label.text = "  +%d %s/hr" % [contribution[resource_type], resource_type.capitalize()]
				resource_label.add_theme_font_size_override("font_size", 9)
				resource_label.modulate = Color.LIGHT_GRAY
				vbox.add_child(resource_label)
	
	# Special bonuses or notes
	var bonus_text = get_god_role_bonus_text(god, role, current_territory)
	if not bonus_text.is_empty():
		var bonus_label = Label.new()
		bonus_label.text = bonus_text
		bonus_label.add_theme_font_size_override("font_size", 9)
		bonus_label.modulate = Color.YELLOW
		bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus_label.custom_minimum_size = Vector2(280, 0)
		vbox.add_child(bonus_label)
	
	return vbox

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_back_pressed():
	back_pressed.emit()

func _on_select_role_slot(role: String, slot_index: int):
	"""Handle role slot selection"""
	selected_role_slot = {"role": role, "slot_index": slot_index}
	refresh_god_selection()
	print("Selected slot: ", role, " slot ", slot_index)

func _on_assign_god_to_slot(god: God):
	"""Handle god assignment to selected slot"""
	if selected_role_slot.is_empty():
		return
	
	var role = selected_role_slot.get("role", "")
	var success = GameManager.assign_god_to_territory_role(god, current_territory, role)
	
	if success:
		print("Assigned ", god.name, " to ", role, " role in ", current_territory.name)
		
		# Refresh displays
		role_assignments = GameManager.get_territory_role_assignments(current_territory)
		refresh_territory_display()
		refresh_role_slots()
		refresh_god_selection()
		role_assignments_changed.emit()
	else:
		print("Failed to assign ", god.name, " to ", role, " role")

func _on_remove_god_from_slot(god: God):
	"""Handle god removal from slot"""
	GameManager.remove_god_from_territory(god)
	print("Removed ", god.name, " from ", current_territory.name)
	
	# Refresh displays
	role_assignments = GameManager.get_territory_role_assignments(current_territory)
	refresh_territory_display()
	refresh_role_slots()
	refresh_god_selection()
	role_assignments_changed.emit()

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

func get_role_display_name(role: String) -> String:
	match role:
		"defender":
			return "🛡️ Defenders"
		"gatherer":
			return "⛏️ Gatherers"
		"crafter":
			return "🔨 Crafters"
		_:
			return role.capitalize()

func get_role_description(role: String) -> String:
	match role:
		"defender":
			return "Protect territory and provide combat bonuses"
		"gatherer":
			return "Collect resources and increase generation rates"
		"crafter":
			return "Convert materials and create special items"
		_:
			return "Unknown role"

func get_role_color(role: String) -> Color:
	match role:
		"defender":
			return Color.RED
		"gatherer":
			return Color.GREEN
		"crafter":
			return Color.BLUE
		_:
			return Color.WHITE

# ==============================================================================
# ENHANCED INFORMATION FUNCTIONS
# ==============================================================================

func get_element_color(element_name: String) -> Color:
	"""Get color associated with territory element"""
	match element_name.to_lower():
		"fire":
			return Color(1.0, 0.4, 0.2, 0.8)  # Orange-red
		"water":
			return Color(0.2, 0.6, 1.0, 0.8)  # Blue
		"earth":
			return Color(0.6, 0.4, 0.2, 0.8)  # Brown
		"air":
			return Color(0.8, 0.9, 1.0, 0.8)  # Light blue
		"light":
			return Color(1.0, 1.0, 0.7, 0.8)  # Light yellow
		"dark":
			return Color(0.4, 0.2, 0.6, 0.8)  # Purple
		"nature":
			return Color(0.3, 0.7, 0.3, 0.8)  # Green
		_:
			return Color(0.5, 0.5, 0.5, 0.8)  # Gray

func get_territory_description(territory: Territory) -> String:
	"""Get detailed territory description"""
	var element = territory.get_element_name().to_lower()
	var tier = territory.tier
	
	var base_desc = ""
	match element:
		"fire":
			base_desc = "A volcanic region with intense heat and molten flows. Fire-aligned gods gain significant bonuses here."
		"water":
			base_desc = "A realm of rushing rivers and deep lakes. Water-aligned gods feel at home in this environment."
		"earth":
			base_desc = "Rocky mountains and solid ground provide stability. Earth-aligned gods are most effective here."
		"air":
			base_desc = "High altitude winds and floating islands. Air-aligned gods can harness the atmospheric power."
		"light":
			base_desc = "Radiant plains where divine light shines brightest. Light-aligned gods are empowered by the energy."
		"dark":
			base_desc = "Shadow-touched lands where darkness holds sway. Dark-aligned gods thrive in this environment."
		"nature":
			base_desc = "Lush forests and vibrant ecosystems. Nature-aligned gods connect deeply with the living world."
		_:
			base_desc = "A mysterious territory with unknown properties."
	
	var tier_addition = ""
	match tier:
		1:
			tier_addition = " This is a basic territory with standard resource generation."
		2:
			tier_addition = " As a tier 2 territory, it offers improved resource diversity and better god efficiency."
		3:
			tier_addition = " This advanced tier 3 territory provides exceptional resources and maximum god potential."
		_:
			tier_addition = " This legendary territory offers unparalleled benefits."
	
	return base_desc + tier_addition

func get_element_bonus_description(element_name: String) -> String:
	"""Get description of element bonuses"""
	match element_name.to_lower():
		"fire":
			return "• Fire gods: +50 percent efficiency\n• Generates heat-based crafting materials\n• Bonus combat power for defenders"
		"water":
			return "• Water gods: +50 percent efficiency\n• Enhanced healing and regeneration\n• Improved resource flow rates"
		"earth":
			return "• Earth gods: +50 percent efficiency\n• Generates rare minerals and stones\n• Increased territory stability"
		"air":
			return "• Air gods: +50 percent efficiency\n• Enhanced mobility and speed bonuses\n• Generates wind-based energy"
		"light":
			# Get proper resource name from ResourceManager
			var mana_name = "Mana"
			if GameManager and GameManager.has_method("get_resource_manager"):
				var resource_mgr = GameManager.get_resource_manager()
				if resource_mgr:
					var mana_info = resource_mgr.get_resource_info("mana")
					mana_name = mana_info.get("name", "Mana")
			return "• Light gods: +50 percent efficiency\n• %s generation bonus\n• Purification and blessing effects" % mana_name
		"dark":
			return "• Dark gods: +50 percent efficiency\n• Shadow magic amplification\n• Curse and debuff generation"
		"nature":
			return "• Nature gods: +50 percent efficiency\n• Living resource regeneration\n• Ecosystem-based bonuses"
		_:
			return "• Neutral bonuses for all god types"

func get_tier_bonus_description(tier: int) -> String:
	"""Get description of tier bonuses"""
	match tier:
		1:
			return "• Basic resource generation\n• 1-2 role slots per type\n• Standard god efficiency"
		2:
			return "• Enhanced resource variety\n• 2-3 role slots per type\n• +25 percent base generation\n• Special materials access"
		3:
			return "• Premium resource generation\n• 3-4 role slots per type\n• +50 percent base generation\n• Rare materials and artifacts"
		_:
			return "• Legendary tier benefits\n• Maximum role slots\n• Exceptional generation rates"

func get_role_territory_impact(role: String, territory: Territory) -> String:
	"""Get specific impact description for role on this territory"""
	var base_generation = {}
	if GameManager.territory_manager:
		base_generation = GameManager.territory_manager.get_base_territory_generation(territory)
	
	match role:
		"gatherer":
			var total_base = 0
			for amount in base_generation.values():
				total_base += amount
			return "Gatherers will boost this territory's %d/hr base generation by 25 percent each. With good gods, could add +%d/hr per gatherer." % [total_base, int(total_base * 0.25)]
		
		"defender":
			# Get proper resource name from ResourceManager
			var mana_name = "Mana"
			if GameManager and GameManager.has_method("get_resource_manager"):
				var resource_mgr = GameManager.get_resource_manager()
				if resource_mgr:
					var mana_info = resource_mgr.get_resource_info("mana")
					mana_name = mana_info.get("name", "Mana")
			return "Defenders provide territory security and generate %d/hr %s. They also unlock combat bonuses for territory battles." % [10, mana_name.to_lower()]
		
		"crafter":
			var element_name = territory.get_element_name().to_lower()
			return "Crafters will generate %s powder and special materials. Essential for equipment upgrades and advanced crafting." % element_name
		
		_:
			return "This role provides specialized bonuses for the territory."

func get_god_role_bonus_text(god: God, role: String, territory: Territory) -> String:
	"""Get special bonus text for god in specific role"""
	var bonus_texts = []
	
	# Element matching bonus
	if god.get_element_name().to_lower() == territory.get_element_name().to_lower():
		bonus_texts.append("🔥 Element Match: +50 percent efficiency!")
	
	# Tier bonus
	match god.tier:
		God.TierType.LEGENDARY:
			bonus_texts.append("⭐ Legendary: +80 percent power bonus")
		God.TierType.EPIC:
			bonus_texts.append("💜 Epic: +40 percent power bonus")
		God.TierType.RARE:
			bonus_texts.append("🔵 Rare: +20 percent power bonus")
	
	# Role-specific bonuses
	match role:
		"gatherer":
			if god.level >= 50:
				bonus_texts.append("🏆 High Level: Extra resource generation")
		"defender":
			if god.get_element_name().to_lower() in ["fire", "earth", "dark"]:
				bonus_texts.append("⚔️ Combat Element: Superior defense")
		"crafter":
			if god.get_element_name().to_lower() == territory.get_element_name().to_lower():
				bonus_texts.append("🔨 Perfect Crafter: Premium materials")
	
	return "\n".join(bonus_texts)
