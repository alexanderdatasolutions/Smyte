# scripts/ui/TerritoryRoleScreen.gd
# RULE 1 COMPLIANCE: 500-line limit enforced
# RULE 2 COMPLIANCE: Single responsibility - coordinate territory role UI components
# RULE 4 COMPLIANCE: UI layer - display only, no business logic
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Control

# Preload component classes
const TerritoryInfoDisplayManager = preload("res://scripts/ui/components/TerritoryInfoDisplayManager.gd")
const TerritoryRoleManager = preload("res://scripts/ui/components/TerritoryRoleManager.gd")
const TerritoryGodSelectionHelper = preload("res://scripts/ui/components/GodSelectionPanel.gd")

# Component managers for focused responsibilities
var info_display_manager: TerritoryInfoDisplayManager
var role_manager: TerritoryRoleManager
var god_selection_panel: TerritoryGodSelectionHelper

# UI references
@onready var territory_info_container: Control = $VBox/TopSection/TerritoryInfoPanel
@onready var roles_container: Control = $VBox/BottomSection/RolesPanel
@onready var back_button: Button = $VBox/HeaderSection/BackButton
@onready var refresh_button: Button = $VBox/HeaderSection/RefreshButton

# Current state
var current_territory: Territory
var screen_title_label: Label

func _ready():
	"""Initialize the territory role screen"""
	setup_ui_components()
	setup_component_managers()
	connect_signals()

func setup_ui_components():
	"""Setup basic UI structure and styling"""
	# Create main structure if not in scene
	if not has_node("VBox"):
		create_main_ui_structure()
	
	# Setup header
	setup_header_section()
	
	# Setup info panel styling
	setup_info_panel_styling()
	
	# Setup roles panel styling
	setup_roles_panel_styling()

func create_main_ui_structure():
	"""Create main UI structure programmatically if needed"""
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "VBox"
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)
	
	# Header section
	var header_section = HBoxContainer.new()
	header_section.name = "HeaderSection"
	header_section.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(header_section)
	
	# Back button
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "← Back to Territories"
	header_section.add_child(back_button)
	
	# Title
	screen_title_label = Label.new()
	screen_title_label.text = "Territory Role Management"
	screen_title_label.add_theme_font_size_override("font_size", 24)
	screen_title_label.modulate = Color.CYAN
	screen_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_section.add_child(screen_title_label)
	
	# Refresh button
	refresh_button = Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.text = "🔄 Refresh"
	header_section.add_child(refresh_button)
	
	# Top section - Territory info
	var top_section = HBoxContainer.new()
	top_section.name = "TopSection" 
	top_section.custom_minimum_size = Vector2(0, 200)
	main_vbox.add_child(top_section)
	
	territory_info_container = Control.new()
	territory_info_container.name = "TerritoryInfoPanel"
	territory_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_section.add_child(territory_info_container)
	
	# Bottom section - Roles
	var bottom_section = VBoxContainer.new()
	bottom_section.name = "BottomSection"
	bottom_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(bottom_section)
	
	roles_container = Control.new()
	roles_container.name = "RolesPanel" 
	roles_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_section.add_child(roles_container)

func setup_header_section():
	"""Setup header styling and behavior"""
	if screen_title_label:
		screen_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func setup_info_panel_styling():
	"""Setup territory info panel styling"""
	if territory_info_container:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		panel_style.border_color = Color.CYAN
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		
		# Apply to panel if it exists
		if territory_info_container is Panel:
			territory_info_container.add_theme_stylebox_override("panel", panel_style)

func setup_roles_panel_styling():
	"""Setup roles panel styling"""
	if roles_container:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.8)
		panel_style.border_color = Color.YELLOW
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		
		# Apply to panel if it exists
		if roles_container is Panel:
			roles_container.add_theme_stylebox_override("panel", panel_style)

func setup_component_managers():
	"""Initialize component managers - RULE 2: Focused responsibilities"""
	# Create territory info display manager
	info_display_manager = TerritoryInfoDisplayManager.new()
	add_child(info_display_manager)
	info_display_manager.initialize(territory_info_container)
	
	# Create role manager
	role_manager = TerritoryRoleManager.new()
	add_child(role_manager)
	role_manager.initialize(roles_container)
	
	# Create god selection panel
	god_selection_panel = GodSelectionPanel.new()
	add_child(god_selection_panel)
	god_selection_panel.initialize()

func connect_signals():
	"""Connect component signals"""
	# Button connections
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	# Component signal connections
	if role_manager:
		role_manager.role_assignment_changed.connect(_on_role_assignment_requested)
	
	if god_selection_panel:
		god_selection_panel.god_selected.connect(_on_god_selected)
		god_selection_panel.selection_cancelled.connect(_on_god_selection_cancelled)

func display_territory(territory: Territory):
	"""Display territory role management screen - RULE 4: UI display coordination only"""
	if not territory:
		return

	current_territory = territory
	
	# Update screen title
	if screen_title_label:
		screen_title_label.text = "%s - Role Management" % territory.name
	
	# Delegate display to component managers
	if info_display_manager:
		info_display_manager.refresh_display(territory)
	
	if role_manager:
		role_manager.refresh_roles_display(territory)

# === EVENT HANDLERS ===

func _on_back_button_pressed():
	"""Handle back to territories button press"""
	# Navigate back through GameCoordinator - RULE 5: SystemRegistry compliance
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var game_coordinator = system_registry.get_system("GameCoordinator")
		if game_coordinator:
			game_coordinator.show_territory_screen()

func _on_refresh_button_pressed():
	"""Handle refresh button press"""
	if current_territory:
		display_territory(current_territory)

func _on_role_assignment_requested(role: String, _god_id: String, slot_index: int):
	"""Handle role assignment request from role manager"""
	# Show god selection panel
	if god_selection_panel:
		god_selection_panel.show_god_selection(role, slot_index)

func _on_god_selected(god_id: String, role_name: String, slot_index: int):
	"""Handle god selection from selection panel"""
	# Process assignment through SystemRegistry - RULE 5 compliance
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			# This would need to be implemented in TerritoryManager
			# Refresh the role display to show changes
			if role_manager:
				role_manager.refresh_single_role_slots(role_name)

func _on_god_selection_cancelled():
	"""Handle god selection cancellation"""
	pass

# === CLEANUP ===

func _exit_tree():
	"""Clean up when screen is removed"""
	pass
	
	# Component managers are children and will be automatically freed
	# Just ensure any remaining connections are cleared
	if role_manager and role_manager.role_assignment_changed.is_connected(_on_role_assignment_requested):
		role_manager.role_assignment_changed.disconnect(_on_role_assignment_requested)
	
	if god_selection_panel:
		if god_selection_panel.god_selected.is_connected(_on_god_selected):
			god_selection_panel.god_selected.disconnect(_on_god_selected)
		if god_selection_panel.selection_cancelled.is_connected(_on_god_selection_cancelled):
			god_selection_panel.selection_cancelled.disconnect(_on_god_selection_cancelled)
