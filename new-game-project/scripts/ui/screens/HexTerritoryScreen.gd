# scripts/ui/screens/HexTerritoryScreen.gd
# Main hex territory screen with map view and node management
class_name HexTerritoryScreen
extends Control

"""
HexTerritoryScreen.gd - Main hex territory screen coordinator
RULE 2: Single responsibility - ONLY orchestrates hex territory UI components
RULE 1: Under 500 lines
RULE 4: No data modification - delegates to systems
RULE 5: Uses SystemRegistry for all system access

Layout:
- Top: Resource bar, back button
- Center: HexMapView (hex grid with pan/zoom)
- Bottom/Side: NodeInfoPanel (slides in on node selection)

Follows coordinator pattern like TerritoryScreenCoordinator
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal back_pressed

# ==============================================================================
# PRELOADS
# ==============================================================================
const HexMapViewScript = preload("res://scripts/ui/territory/HexMapView.gd")
const NodeInfoPanelScript = preload("res://scripts/ui/territory/NodeInfoPanel.gd")
const NodeRequirementsPanelScript = preload("res://scripts/ui/territory/NodeRequirementsPanel.gd")
const NodeCaptureHandlerScript = preload("res://scripts/ui/territory/NodeCaptureHandler.gd")
const WorkerAssignmentPanelScript = preload("res://scripts/ui/territory/WorkerAssignmentPanel.gd")
const GarrisonManagementPanelScript = preload("res://scripts/ui/territory/GarrisonManagementPanel.gd")

# ==============================================================================
# UI COMPONENTS
# ==============================================================================
var main_container: Control = null
var top_bar: HBoxContainer = null
var center_container: Control = null
var bottom_panel_container: Control = null

var back_button: Button = null
var resource_display: HBoxContainer = null
var zoom_controls: VBoxContainer = null

var hex_map_view: HexMapView = null
var node_info_panel: NodeInfoPanel = null
var node_requirements_panel: NodeRequirementsPanel = null
var node_capture_handler: NodeCaptureHandler = null
var worker_assignment_panel: WorkerAssignmentPanel = null
var garrison_management_panel: GarrisonManagementPanel = null

# ==============================================================================
# PROPERTIES
# ==============================================================================
var selected_node: HexNode = null
var is_info_panel_visible: bool = false

# System references
var resource_manager = null
var territory_manager = null
var collection_manager = null
var screen_manager = null

# ==============================================================================
# CONSTANTS
# ==============================================================================
const TOP_BAR_HEIGHT = 60
const INFO_PANEL_WIDTH = 380
const RESOURCE_DISPLAY_HEIGHT = 50

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_create_ui_structure()
	_setup_components()
	_connect_signals()
	_style_components()
	_check_tutorial()

	# Fix size after everything is set up (when Control is child of Node2D)
	call_deferred("_fix_size_for_node2d_parent")

func _fix_size_for_node2d_parent() -> void:
	"""Fix size when Control is child of Node2D - must be deferred"""
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size

func _init_systems() -> void:
	"""Initialize system references via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		resource_manager = registry.get_system("ResourceManager")
		territory_manager = registry.get_system("TerritoryManager")
		collection_manager = registry.get_system("CollectionManager")
		screen_manager = registry.get_system("ScreenManager")

# ==============================================================================
# UI STRUCTURE
# ==============================================================================
func _create_ui_structure() -> void:
	"""Create the main UI layout structure"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Main container fills screen
	main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)

	# Top bar for back button and resources
	_create_top_bar()

	# Center container for hex map
	_create_center_container()

	# Bottom/side panel container for node info
	_create_panel_container()

func _create_top_bar() -> void:
	"""Create top bar with back button and resource display"""
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_bottom = TOP_BAR_HEIGHT
	top_bar.add_theme_constant_override("separation", 20)
	main_container.add_child(top_bar)

	# Back button
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "← BACK"
	back_button.custom_minimum_size = Vector2(120, 40)
	top_bar.add_child(back_button)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	# Resource display
	resource_display = HBoxContainer.new()
	resource_display.name = "ResourceDisplay"
	resource_display.add_theme_constant_override("separation", 15)
	top_bar.add_child(resource_display)

	_create_resource_labels()

func _create_resource_labels() -> void:
	"""Create labels for key resources (gold, mana, divine crystals)"""
	var resources_to_show = ["gold", "mana", "divine_crystals"]

	for resource_id in resources_to_show:
		var resource_label = Label.new()
		resource_label.name = resource_id + "_label"
		resource_label.text = _get_resource_display_text(resource_id)
		resource_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		resource_display.add_child(resource_label)

func _get_resource_display_text(resource_id: String) -> String:
	"""Get formatted resource display text"""
	if not resource_manager:
		return resource_id.capitalize() + ": 0"

	var amount = resource_manager.get_resource(resource_id)
	var icon = _get_resource_icon(resource_id)
	return icon + " " + resource_id.capitalize() + ": " + str(amount)

func _get_resource_icon(resource_id: String) -> String:
	"""Get emoji icon for resource"""
	match resource_id:
		"gold": return "💰"
		"mana": return "✨"
		"divine_crystals": return "💎"
		_: return "•"

func _create_center_container() -> void:
	"""Create center container for hex map view"""
	center_container = Control.new()
	center_container.name = "CenterContainer"
	center_container.anchor_left = 0.0
	center_container.anchor_top = 0.0
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	center_container.offset_top = TOP_BAR_HEIGHT
	center_container.offset_left = 0
	center_container.offset_right = 0
	center_container.offset_bottom = 0
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(center_container)

	# Zoom controls in top-right of map
	_create_zoom_controls()

func _create_zoom_controls() -> void:
	"""Create zoom in/out buttons"""
	zoom_controls = VBoxContainer.new()
	zoom_controls.name = "ZoomControls"
	zoom_controls.anchor_left = 1.0
	zoom_controls.anchor_top = 0.0
	zoom_controls.offset_left = -60
	zoom_controls.offset_top = 10
	zoom_controls.offset_right = -10
	zoom_controls.offset_bottom = 100
	zoom_controls.add_theme_constant_override("separation", 5)
	center_container.add_child(zoom_controls)

	var zoom_in_btn = Button.new()
	zoom_in_btn.name = "ZoomInButton"
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(40, 40)
	zoom_controls.add_child(zoom_in_btn)

	var zoom_out_btn = Button.new()
	zoom_out_btn.name = "ZoomOutButton"
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(40, 40)
	zoom_controls.add_child(zoom_out_btn)

	var center_btn = Button.new()
	center_btn.name = "CenterButton"
	center_btn.text = "⌂"
	center_btn.custom_minimum_size = Vector2(40, 40)
	zoom_controls.add_child(center_btn)

	# Connect zoom buttons
	zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
	zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
	center_btn.pressed.connect(_on_center_pressed)

func _create_panel_container() -> void:
	"""Create panel container for node info (slides in from right)"""
	bottom_panel_container = Control.new()
	bottom_panel_container.name = "PanelContainer"
	bottom_panel_container.anchor_left = 1.0
	bottom_panel_container.anchor_top = 0.0
	bottom_panel_container.anchor_right = 1.0
	bottom_panel_container.anchor_bottom = 1.0
	bottom_panel_container.offset_left = -INFO_PANEL_WIDTH
	bottom_panel_container.offset_top = TOP_BAR_HEIGHT
	bottom_panel_container.offset_right = 0
	bottom_panel_container.offset_bottom = 0
	bottom_panel_container.visible = false  # Start hidden
	main_container.add_child(bottom_panel_container)

# ==============================================================================
# SETUP COMPONENTS
# ==============================================================================
func _setup_components() -> void:
	"""Setup hex map view and info panels"""
	_setup_hex_map_view()
	_setup_node_info_panel()
	_setup_node_requirements_panel()
	_setup_node_capture_handler()
	_setup_worker_assignment_panel()
	_setup_garrison_management_panel()

func _setup_hex_map_view() -> void:
	"""Create and setup HexMapView component"""
	hex_map_view = HexMapViewScript.new()
	hex_map_view.name = "HexMapView"
	hex_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hex_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Adjust right edge if info panel is visible
	hex_map_view.offset_right = 0
	center_container.add_child(hex_map_view)
	center_container.move_child(hex_map_view, 0)  # Behind zoom controls

	# Initialize and center on base
	call_deferred("_initialize_hex_map")

func _initialize_hex_map() -> void:
	"""Initialize hex map after ready"""
	if hex_map_view:
		hex_map_view.refresh()
		hex_map_view.center_on_base()

func _setup_node_info_panel() -> void:
	"""Create and setup NodeInfoPanel component"""
	node_info_panel = NodeInfoPanelScript.new()
	node_info_panel.name = "NodeInfoPanel"
	node_info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom_panel_container.add_child(node_info_panel)

func _setup_node_requirements_panel() -> void:
	"""Create and setup NodeRequirementsPanel component"""
	node_requirements_panel = NodeRequirementsPanelScript.new()
	node_requirements_panel.name = "NodeRequirementsPanel"
	node_requirements_panel.anchor_left = 0.5
	node_requirements_panel.anchor_top = 0.5
	node_requirements_panel.anchor_right = 0.5
	node_requirements_panel.anchor_bottom = 0.5
	node_requirements_panel.offset_left = -200  # Center 400px wide panel
	node_requirements_panel.offset_top = -175   # Center 350px tall panel
	node_requirements_panel.offset_right = 200
	node_requirements_panel.offset_bottom = 175
	node_requirements_panel.visible = false
	main_container.add_child(node_requirements_panel)

func _setup_node_capture_handler() -> void:
	"""Create and setup NodeCaptureHandler"""
	node_capture_handler = NodeCaptureHandlerScript.new()
	node_capture_handler.name = "NodeCaptureHandler"
	add_child(node_capture_handler)

	# Pass hex map view reference for animations
	if node_capture_handler and hex_map_view:
		node_capture_handler.hex_map_view = hex_map_view

	# Connect signals
	if node_capture_handler:
		node_capture_handler.capture_succeeded.connect(_on_capture_succeeded)
		node_capture_handler.capture_failed.connect(_on_capture_failed)

func _setup_worker_assignment_panel() -> void:
	"""Create and setup WorkerAssignmentPanel component"""
	worker_assignment_panel = WorkerAssignmentPanelScript.new()
	worker_assignment_panel.name = "WorkerAssignmentPanel"
	worker_assignment_panel.anchor_left = 0.5
	worker_assignment_panel.anchor_top = 0.5
	worker_assignment_panel.anchor_right = 0.5
	worker_assignment_panel.anchor_bottom = 0.5
	worker_assignment_panel.offset_left = -300  # Center 600px wide panel
	worker_assignment_panel.offset_top = -250   # Center 500px tall panel
	worker_assignment_panel.offset_right = 300
	worker_assignment_panel.offset_bottom = 250
	worker_assignment_panel.visible = false
	main_container.add_child(worker_assignment_panel)

func _setup_garrison_management_panel() -> void:
	"""Create and setup GarrisonManagementPanel component"""
	garrison_management_panel = GarrisonManagementPanelScript.new()
	garrison_management_panel.name = "GarrisonManagementPanel"
	garrison_management_panel.anchor_left = 0.5
	garrison_management_panel.anchor_top = 0.5
	garrison_management_panel.anchor_right = 0.5
	garrison_management_panel.anchor_bottom = 0.5
	garrison_management_panel.offset_left = -300  # Center 600px wide panel
	garrison_management_panel.offset_top = -250   # Center 500px tall panel
	garrison_management_panel.offset_right = 300
	garrison_management_panel.offset_bottom = 250
	garrison_management_panel.visible = false
	main_container.add_child(garrison_management_panel)

# ==============================================================================
# CONNECT SIGNALS
# ==============================================================================
func _connect_signals() -> void:
	"""Connect component signals"""
	# Back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Hex map view signals
	if hex_map_view:
		hex_map_view.hex_selected.connect(_on_hex_selected)
		hex_map_view.hex_hovered.connect(_on_hex_hovered)

	# Node info panel signals
	if node_info_panel:
		node_info_panel.capture_requested.connect(_on_capture_requested)
		node_info_panel.manage_workers_requested.connect(_on_manage_workers_requested)
		node_info_panel.manage_garrison_requested.connect(_on_manage_garrison_requested)
		node_info_panel.close_requested.connect(_on_node_info_close)

	# Node requirements panel signals
	if node_requirements_panel:
		node_requirements_panel.close_requested.connect(_on_requirements_panel_close)

	# Worker assignment panel signals
	if worker_assignment_panel:
		worker_assignment_panel.close_requested.connect(_on_worker_panel_close)
		worker_assignment_panel.worker_assigned.connect(_on_worker_assigned)
		worker_assignment_panel.worker_unassigned.connect(_on_worker_unassigned)

	# Garrison management panel signals
	if garrison_management_panel:
		garrison_management_panel.close_requested.connect(_on_garrison_panel_close)
		garrison_management_panel.garrison_assigned.connect(_on_garrison_assigned)
		garrison_management_panel.garrison_unassigned.connect(_on_garrison_unassigned)

# ==============================================================================
# STYLING
# ==============================================================================
func _style_components() -> void:
	"""Apply dark fantasy styling to components"""
	_style_back_button()
	_style_zoom_buttons()
	_style_top_bar()

func _style_back_button() -> void:
	"""Style the back button"""
	if not back_button:
		return

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style_normal.border_color = Color(0.4, 0.35, 0.5)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	style_hover.border_color = Color(0.5, 0.45, 0.6)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", style_hover)

	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

func _style_zoom_buttons() -> void:
	"""Style zoom control buttons"""
	if not zoom_controls:
		return

	for child in zoom_controls.get_children():
		if child is Button:
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(0.12, 0.1, 0.15, 0.9)
			style_normal.border_color = Color(0.4, 0.35, 0.5)
			style_normal.set_border_width_all(2)
			style_normal.set_corner_radius_all(6)
			child.add_theme_stylebox_override("normal", style_normal)

			var style_hover = StyleBoxFlat.new()
			style_hover.bg_color = Color(0.18, 0.15, 0.22, 0.95)
			style_hover.border_color = Color(0.5, 0.45, 0.6)
			style_hover.set_border_width_all(2)
			style_hover.set_corner_radius_all(6)
			child.add_theme_stylebox_override("hover", style_hover)

			child.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
			child.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

func _style_top_bar() -> void:
	"""Style the top bar background"""
	if not top_bar:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.25, 0.35)
	style.set_border_width_all(0)
	style.set_border_width(SIDE_BOTTOM, 2)
	top_bar.add_theme_stylebox_override("panel", style)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_back_pressed() -> void:
	"""Handle back button press"""
	back_pressed.emit()

func _on_zoom_in_pressed() -> void:
	"""Handle zoom in button"""
	if hex_map_view:
		hex_map_view.zoom_in()

func _on_zoom_out_pressed() -> void:
	"""Handle zoom out button"""
	if hex_map_view:
		hex_map_view.zoom_out()

func _on_center_pressed() -> void:
	"""Handle center on base button"""
	if hex_map_view:
		hex_map_view.center_on_base()

func _on_hex_selected(hex_node: HexNode) -> void:
	"""Handle hex node selection from map"""
	selected_node = hex_node
	_show_node_info(hex_node)

func _on_hex_hovered(hex_node: HexNode) -> void:
	"""Handle hex node hover (optional tooltip in future)"""
	pass  # Could show tooltip in future

func _on_capture_requested(hex_node: HexNode) -> void:
	"""Handle capture request from info panel - P6-01: Full capture flow"""
	# Check requirements first
	var node_checker = SystemRegistry.get_instance().get_system("NodeRequirementChecker")
	if node_checker and not node_checker.can_player_capture_node(hex_node):
		_show_requirements_panel(hex_node)
		return

	# Requirements met - navigate to battle setup for team selection
	# Store the node being captured for later
	if node_capture_handler:
		node_capture_handler.current_capture_node = hex_node

	# Navigate to battle setup screen
	if screen_manager:
		var battle_setup_screen = screen_manager.change_screen("battle_setup")
		if battle_setup_screen and battle_setup_screen.has_method("setup_for_hex_node_capture"):
			battle_setup_screen.setup_for_hex_node_capture(hex_node)
			# Connect to completion signal if not already connected
			if not battle_setup_screen.battle_setup_complete.is_connected(_on_battle_setup_complete):
				battle_setup_screen.battle_setup_complete.connect(_on_battle_setup_complete)

func _on_manage_workers_requested(hex_node: HexNode) -> void:
	"""Handle manage workers request - P6-02: Worker assignment UI"""
	if worker_assignment_panel:
		worker_assignment_panel.show_panel(hex_node)

func _on_manage_garrison_requested(hex_node: HexNode) -> void:
	"""Handle manage garrison request - P6-03: Garrison management UI"""
	if garrison_management_panel:
		garrison_management_panel.show_garrison(hex_node)

func _on_node_info_close() -> void:
	"""Handle node info panel close"""
	_hide_node_info()

func _on_requirements_panel_close() -> void:
	"""Handle requirements panel close"""
	_hide_requirements_panel()

func _on_worker_panel_close() -> void:
	"""Handle worker assignment panel close"""
	if worker_assignment_panel:
		worker_assignment_panel.hide_panel()
	# Refresh displays
	refresh()

func _on_worker_assigned(node: HexNode, god_id: String, task_id: String) -> void:
	"""Handle worker assignment notification"""
	print("Worker assigned: god=%s task=%s at node=%s" % [god_id, task_id, node.id])
	# Refresh displays
	refresh()

func _on_worker_unassigned(node: HexNode, god_id: String) -> void:
	"""Handle worker unassignment notification"""
	print("Worker unassigned: god=%s from node=%s" % [god_id, node.id])
	# Refresh displays
	refresh()

func _on_garrison_panel_close() -> void:
	"""Handle garrison management panel close"""
	if garrison_management_panel:
		garrison_management_panel.hide_panel()
	# Refresh displays
	refresh()

func _on_garrison_assigned(node: HexNode, god_id: String) -> void:
	"""Handle garrison assignment notification"""
	print("Garrison assigned: god=%s at node=%s" % [god_id, node.id])
	# Refresh displays
	refresh()

func _on_garrison_unassigned(node: HexNode, god_id: String) -> void:
	"""Handle garrison unassignment notification"""
	print("Garrison unassigned: god=%s from node=%s" % [god_id, node.id])
	# Refresh displays
	refresh()

# ==============================================================================
# PANEL MANAGEMENT
# ==============================================================================
func _show_node_info(hex_node: HexNode) -> void:
	"""Show node info panel with node details"""
	if not node_info_panel or not hex_node:
		return

	# Update panel with node data
	node_info_panel.show_node(hex_node)

	# Show panel container
	bottom_panel_container.visible = true
	is_info_panel_visible = true

	# Adjust hex map view width to make room for panel
	if hex_map_view:
		hex_map_view.offset_right = -INFO_PANEL_WIDTH

func _hide_node_info() -> void:
	"""Hide node info panel"""
	bottom_panel_container.visible = false
	is_info_panel_visible = false
	selected_node = null

	# Restore hex map view width
	if hex_map_view:
		hex_map_view.offset_right = 0

	# Deselect node on map
	if hex_map_view:
		hex_map_view.select_node(null)

func _show_requirements_panel(hex_node: HexNode) -> void:
	"""Show requirements panel for locked node"""
	if not node_requirements_panel or not hex_node:
		return

	node_requirements_panel.show_requirements(hex_node)

func _hide_requirements_panel() -> void:
	"""Hide requirements panel"""
	if node_requirements_panel:
		node_requirements_panel.hide_panel()

# ==============================================================================
# CAPTURE HANDLERS - P6-01
# ==============================================================================
func _on_battle_setup_complete(context: Dictionary) -> void:
	"""Handle battle setup completion - start the capture battle with selected team"""
	if not node_capture_handler or not context.has("selected_team"):
		return

	# Get the hex node and selected team
	var hex_node = context.get("hex_node")
	var selected_team = context.get("selected_team")

	if hex_node and selected_team:
		# Start the capture battle with the selected team
		node_capture_handler.initiate_capture_with_team(hex_node, selected_team)

func _on_capture_succeeded(hex_node: HexNode) -> void:
	"""Handle successful node capture from NodeCaptureHandler"""
	refresh()

func _on_capture_failed(hex_node: HexNode) -> void:
	"""Handle failed node capture from NodeCaptureHandler"""
	refresh()

# ==============================================================================
# REFRESH
# ==============================================================================
func refresh() -> void:
	"""Refresh the entire screen (map and panels)"""
	# Refresh resource display
	_refresh_resource_display()

	# Refresh hex map
	if hex_map_view:
		hex_map_view.refresh()

	# Refresh node info if visible
	if is_info_panel_visible and selected_node and node_info_panel:
		node_info_panel.show_node(selected_node)

func _refresh_resource_display() -> void:
	"""Update resource display labels"""
	if not resource_display:
		return

	var resources_to_show = ["gold", "mana", "divine_crystals"]
	for resource_id in resources_to_show:
		var label = resource_display.get_node_or_null(resource_id + "_label")
		if label:
			label.text = _get_resource_display_text(resource_id)

# ==============================================================================
# TUTORIAL INTEGRATION
# ==============================================================================
func _check_tutorial() -> void:
	"""Check if tutorial should be shown for first time opening hex map"""
	var tutorial_orchestrator = SystemRegistry.get_instance().get_system("TutorialOrchestrator")
	if not tutorial_orchestrator:
		return

	# Start hex territory intro tutorial on first time opening
	if not tutorial_orchestrator.is_tutorial_completed("hex_territory_intro"):
		# Use call_deferred to ensure screen is fully loaded
		call_deferred("_start_hex_territory_tutorial")

func _start_hex_territory_tutorial() -> void:
	"""Start the hex territory introduction tutorial"""
	var tutorial_orchestrator = SystemRegistry.get_instance().get_system("TutorialOrchestrator")
	if tutorial_orchestrator:
		tutorial_orchestrator.start_tutorial("hex_territory_intro")
