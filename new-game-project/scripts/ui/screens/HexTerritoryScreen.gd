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
const NodeDetailScreenScript = preload("res://scripts/ui/screens/NodeDetailScreen.gd")
const GodSelectionPanelScript = preload("res://scripts/ui/territory/GodSelectionPanel.gd")
const BuildingSelectionPopupScript = preload("res://scripts/ui/territory/BuildingSelectionPopup.gd")

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
var territory_overview_screen: TerritoryOverviewScreen = null
var node_detail_screen: NodeDetailScreen = null
var god_selection_panel: GodSelectionPanel = null
var building_selection_popup = null  # BuildingSelectionPopup instance

# Slot selection context for god assignment
var _pending_slot_node: HexNode = null
var _pending_slot_type: String = ""  # "garrison" or "worker"
var _pending_slot_index: int = -1

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
	_setup_unified_header()

	# Fix size after everything is set up (when Control is child of Node2D)
	call_deferred("_fix_size_for_node2d_parent")

func _setup_unified_header():
	"""Configure the unified header for this screen"""
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_visibility_changed():
	"""Update header when this screen becomes visible"""
	if visible:
		_update_header_for_screen()

func _update_header_for_screen():
	"""Apply this screen's header settings"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("HEX TERRITORY")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

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

	# Clear old top bar references (unified header handles back + resources)
	_create_top_bar()

	# Center container for hex map
	_create_center_container()

	# Bottom/side panel container for node info
	_create_panel_container()

	# Floating buttons on top of everything
	_create_floating_buttons()

func _create_top_bar() -> void:
	"""Create floating UI elements (unified header handles back button and resources)"""
	# Old elements no longer needed - unified header handles back + resources
	top_bar = null
	back_button = null
	resource_display = null

func _create_floating_buttons() -> void:
	"""Create floating buttons that stay on top of other UI"""
	# Create a floating overview button on the left side, below the header
	var overview_button = Button.new()
	overview_button.name = "OverviewButton"
	overview_button.text = "📋"  # Icon-style button
	overview_button.tooltip_text = "Territory Overview"
	overview_button.custom_minimum_size = Vector2(50, 50)
	overview_button.pressed.connect(_on_territory_overview_pressed)

	# Position it on the left side, below the header
	overview_button.anchor_left = 0.0
	overview_button.anchor_top = 0.0
	overview_button.anchor_right = 0.0
	overview_button.anchor_bottom = 0.0
	overview_button.offset_left = 10
	overview_button.offset_top = 60  # Below the header
	overview_button.offset_right = 60
	overview_button.offset_bottom = 110

	# Style the button
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style.border_color = Color(0.5, 0.45, 0.6, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	overview_button.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.17, 0.28, 0.98)
	hover_style.border_color = Color(0.6, 0.55, 0.7, 1.0)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	overview_button.add_theme_stylebox_override("hover", hover_style)

	overview_button.add_theme_font_size_override("font_size", 24)

	# Add directly to self (not main_container) so it's on top of everything
	add_child(overview_button)

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
	_setup_territory_overview_screen()
	_setup_node_detail_screen()
	_setup_god_selection_panel()
	_setup_building_selection_popup()

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

func _setup_territory_overview_screen() -> void:
	"""Create and setup TerritoryOverviewScreen component"""
	var TerritoryOverviewScreenScript = load("res://scripts/ui/territory/TerritoryOverviewScreen.gd")
	territory_overview_screen = TerritoryOverviewScreenScript.new()
	territory_overview_screen.name = "TerritoryOverviewScreen"
	territory_overview_screen.visible = false
	main_container.add_child(territory_overview_screen)

func _setup_node_detail_screen() -> void:
	"""Create and setup NodeDetailScreen component"""
	node_detail_screen = NodeDetailScreenScript.new()
	node_detail_screen.name = "NodeDetailScreen"
	node_detail_screen.visible = false
	main_container.add_child(node_detail_screen)

func _setup_god_selection_panel() -> void:
	"""Create and setup GodSelectionPanel component (slides from LEFT)"""
	god_selection_panel = GodSelectionPanelScript.new()
	god_selection_panel.name = "GodSelectionPanel"
	god_selection_panel.visible = false
	main_container.add_child(god_selection_panel)

func _setup_building_selection_popup() -> void:
	"""Create and setup BuildingSelectionPopup component"""
	building_selection_popup = BuildingSelectionPopupScript.new()
	building_selection_popup.name = "BuildingSelectionPopup"
	building_selection_popup.visible = false
	main_container.add_child(building_selection_popup)

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
		node_info_panel.close_requested.connect(_on_node_info_close)
		node_info_panel.slot_tapped.connect(_on_node_info_slot_tapped)
		node_info_panel.filled_slot_tapped.connect(_on_node_info_filled_slot_tapped)
		node_info_panel.task_started.connect(_on_node_task_started)
		node_info_panel.select_building_requested.connect(_on_select_building_requested)

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

	# Territory overview screen signals
	if territory_overview_screen:
		territory_overview_screen.back_pressed.connect(_on_territory_overview_back)
		territory_overview_screen.manage_node_requested.connect(_on_overview_manage_node)
		territory_overview_screen.slot_tapped.connect(_on_overview_slot_tapped)
		territory_overview_screen.filled_slot_tapped.connect(_on_overview_filled_slot_tapped)

	# Node detail screen signals
	if node_detail_screen:
		node_detail_screen.close_requested.connect(_on_node_detail_close)
		node_detail_screen.garrison_changed.connect(_on_node_detail_garrison_changed)
		node_detail_screen.workers_changed.connect(_on_node_detail_workers_changed)

	# God selection panel signals (slides from left)
	if god_selection_panel:
		god_selection_panel.god_selected.connect(_on_god_selection_panel_selected)
		god_selection_panel.selection_cancelled.connect(_on_god_selection_panel_cancelled)
		god_selection_panel.panel_closed.connect(_on_god_selection_panel_closed)

	# Building selection popup signals
	if building_selection_popup:
		building_selection_popup.building_selected.connect(_on_building_selected)
		building_selection_popup.selection_cancelled.connect(_on_building_selection_cancelled)
		building_selection_popup.popup_closed.connect(_on_building_popup_closed)

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
		# Change to the screen
		if screen_manager.change_screen("battle_setup"):
			# Get the screen instance and configure it
			var battle_setup_screen = screen_manager.get_current_screen()
			if battle_setup_screen and battle_setup_screen.has_method("setup_for_hex_node_capture"):
				battle_setup_screen.setup_for_hex_node_capture(hex_node)
				# Connect to completion signal if not already connected
				if not battle_setup_screen.battle_setup_complete.is_connected(_on_battle_setup_complete):
					battle_setup_screen.battle_setup_complete.connect(_on_battle_setup_complete)

func _on_manage_workers_requested(hex_node: HexNode) -> void:
	"""Handle manage workers request - use NodeDetailScreen for owned nodes"""
	if hex_node and hex_node.is_controlled_by_player():
		_show_node_detail_screen(hex_node)
	elif worker_assignment_panel:
		worker_assignment_panel.show_panel(hex_node)

func _on_manage_garrison_requested(hex_node: HexNode) -> void:
	"""Handle manage garrison request - use NodeDetailScreen for owned nodes"""
	if hex_node and hex_node.is_controlled_by_player():
		_show_node_detail_screen(hex_node)
	elif garrison_management_panel:
		garrison_management_panel.show_garrison(hex_node)

func _on_node_info_close() -> void:
	"""Handle node info panel close"""
	_hide_node_info()

func _on_node_task_started(hex_node: HexNode, task_id: String) -> void:
	"""Handle task started from NodeInfoPanel crafting"""
	print("HexTerritoryScreen: Task started - node: %s, task: %s" % [hex_node.id, task_id])
	# Refresh displays to show updated state
	refresh()

func _on_node_info_slot_tapped(node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Handle slot tap from NodeInfoPanel - opens GodSelectionPanel"""
	if not god_selection_panel or not node:
		return

	print("HexTerritoryScreen: NodeInfoPanel slot tapped - node: %s, type: %s, index: %d" % [node.id, slot_type, slot_index])

	# Store context for when god is selected
	_pending_slot_node = node
	_pending_slot_type = slot_type
	_pending_slot_index = slot_index

	# Get currently assigned god IDs to exclude from selection
	# Include gods assigned to ANY node in EITHER role (garrison OR worker)
	# A god can't be both a garrison defender AND a worker!
	var excluded_ids: Array[String] = []

	# Get all owned nodes
	var owned_nodes = _get_all_owned_nodes()

	# Collect ALL assigned gods (both garrison and workers) from all nodes
	for hex_node in owned_nodes:
		for god_id in hex_node.garrison:
			if god_id not in excluded_ids:
				excluded_ids.append(god_id)
		for god_id in hex_node.assigned_workers:
			if god_id not in excluded_ids:
				excluded_ids.append(god_id)

	# Show GodSelectionPanel with appropriate context (pass node for element matching)
	if slot_type == "garrison":
		god_selection_panel.show_for_garrison(excluded_ids, node)
	else:
		god_selection_panel.show_for_worker(excluded_ids, node)

func _on_node_info_filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Handle filled slot tap from NodeInfoPanel - show confirmation popup to remove god"""
	if not node or not god:
		return

	print("HexTerritoryScreen: NodeInfoPanel filled slot tapped - node: %s, type: %s, god: %s" % [node.id, slot_type, god.name])

	# Show confirmation popup (reuse existing method)
	_show_remove_god_confirmation(node, slot_type, slot_index, god)

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

	# If node has no more workers, cancel any active crafts (for forges)
	if node.assigned_workers.is_empty() and node.type == "forge":
		var hex_grid_mgr = hex_map_view.hex_grid_manager if hex_map_view else null
		if hex_grid_mgr:
			var cancelled = hex_grid_mgr.cancel_all_crafts_for_node(node.id)
			if cancelled > 0:
				print("Cancelled %d crafts due to worker removal from forge" % cancelled)

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

func _on_territory_overview_pressed() -> void:
	"""Handle territory overview button press"""
	if territory_overview_screen:
		# Hide hex map and other panels
		if hex_map_view:
			hex_map_view.visible = false
		if bottom_panel_container:
			bottom_panel_container.visible = false
		if zoom_controls:
			zoom_controls.visible = false

		# Show overview screen
		territory_overview_screen.visible = true
		territory_overview_screen._refresh_display()

func _on_territory_overview_back() -> void:
	"""Handle back from territory overview"""
	if territory_overview_screen:
		territory_overview_screen.visible = false

	# Restore hex map and controls
	if hex_map_view:
		hex_map_view.visible = true
	if zoom_controls:
		zoom_controls.visible = true

func _on_overview_manage_node(node: HexNode) -> void:
	"""Handle manage node request from overview screen"""
	# Close overview
	_on_territory_overview_back()

	# Show node detail screen for the node
	_show_node_detail_screen(node)

func _on_overview_slot_tapped(node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Handle slot tap from TerritoryOverviewScreen - opens GodSelectionPanel"""
	if not god_selection_panel or not node:
		return

	print("HexTerritoryScreen: Slot tapped - node: %s, type: %s, index: %d" % [node.id, slot_type, slot_index])

	# Store context for when god is selected
	_pending_slot_node = node
	_pending_slot_type = slot_type
	_pending_slot_index = slot_index

	# Get currently assigned god IDs to exclude from selection
	# Include gods assigned to ANY node in EITHER role (garrison OR worker)
	# A god can't be both a garrison defender AND a worker!
	var excluded_ids: Array[String] = []

	# Get all owned nodes
	var owned_nodes = _get_all_owned_nodes()

	# Collect ALL assigned gods (both garrison and workers) from all nodes
	for hex_node in owned_nodes:
		for god_id in hex_node.garrison:
			if god_id not in excluded_ids:
				excluded_ids.append(god_id)
		for god_id in hex_node.assigned_workers:
			if god_id not in excluded_ids:
				excluded_ids.append(god_id)

	# Show GodSelectionPanel with appropriate context (pass node for element matching)
	if slot_type == "garrison":
		god_selection_panel.show_for_garrison(excluded_ids, node)
	else:
		god_selection_panel.show_for_worker(excluded_ids, node)

func _on_overview_filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Handle filled slot tap - show confirmation popup to remove god"""
	if not node or not god:
		return

	print("HexTerritoryScreen: Filled slot tapped - node: %s, type: %s, god: %s" % [node.id, slot_type, god.name])

	# Show confirmation popup
	_show_remove_god_confirmation(node, slot_type, slot_index, god)

func _show_remove_god_confirmation(node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Show confirmation popup for removing a god from a slot"""
	var role_text = "garrison" if slot_type == "garrison" else "worker slot"
	var dialog = ConfirmationDialog.new()
	dialog.title = "Remove God"
	dialog.dialog_text = "Remove %s from %s?\n\nNode: %s" % [god.name, role_text, node.name]
	dialog.ok_button_text = "Remove"
	dialog.cancel_button_text = "Cancel"

	# Style the dialog
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.15, 0.98)
	panel_style.border_color = Color(0.8, 0.4, 0.3)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	dialog.add_theme_stylebox_override("panel", panel_style)

	# Add to main container
	main_container.add_child(dialog)

	# Center and show
	dialog.popup_centered(Vector2(320, 180))

	# Connect signals
	dialog.confirmed.connect(_on_remove_god_confirmed.bind(node, slot_type, slot_index, god.id))
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _on_remove_god_confirmed(node: HexNode, slot_type: String, _slot_index: int, god_id: String) -> void:
	"""Handle confirmed god removal from slot"""
	print("HexTerritoryScreen: Removing %s from %s of %s" % [god_id, slot_type, node.id])

	var success = false
	if slot_type == "garrison":
		success = _remove_god_from_garrison(node, god_id)
	else:
		success = _remove_god_from_workers(node, god_id)

	if success:
		# Refresh TerritoryOverviewScreen to show updated slots
		if territory_overview_screen and territory_overview_screen.visible:
			territory_overview_screen._refresh_display()
		# Refresh NodeInfoPanel if it's showing
		if node_info_panel and node_info_panel.visible:
			node_info_panel.refresh()
		refresh()

func _remove_god_from_garrison(node: HexNode, god_id: String) -> bool:
	"""Remove a god from the node's garrison"""
	if not territory_manager:
		push_error("HexTerritoryScreen: TerritoryManager not available")
		return false

	# Remove god from garrison
	var new_garrison: Array = []
	for id in node.garrison:
		if id != god_id:
			new_garrison.append(id)

	# Update via TerritoryManager
	var success = territory_manager.update_node_garrison(node.id, new_garrison)
	if success:
		print("HexTerritoryScreen: Removed %s from garrison of %s" % [god_id, node.id])
	return success

func _remove_god_from_workers(node: HexNode, god_id: String) -> bool:
	"""Remove a god from the node's workers"""
	if not territory_manager:
		push_error("HexTerritoryScreen: TerritoryManager not available")
		return false

	# Remove god from workers
	var new_workers: Array = []
	for id in node.assigned_workers:
		if id != god_id:
			new_workers.append(id)

	# Update via TerritoryManager
	var success = territory_manager.update_node_workers(node.id, new_workers)
	if success:
		print("HexTerritoryScreen: Removed %s from workers of %s" % [god_id, node.id])
	return success

func _on_god_selection_panel_selected(god: God) -> void:
	"""Handle god selection from GodSelectionPanel - assigns god to pending slot"""
	if not god or not _pending_slot_node:
		_clear_pending_slot()
		return

	print("HexTerritoryScreen: God selected - %s for %s slot %d on %s" % [
		god.name, _pending_slot_type, _pending_slot_index, _pending_slot_node.id
	])

	# Assign god to the appropriate slot
	var success = false
	if _pending_slot_type == "garrison":
		success = _assign_god_to_garrison(_pending_slot_node, god.id, _pending_slot_index)
	else:
		success = _assign_god_to_worker(_pending_slot_node, god.id, _pending_slot_index)

	if success:
		# Refresh TerritoryOverviewScreen to show updated slots
		if territory_overview_screen and territory_overview_screen.visible:
			territory_overview_screen._refresh_display()
		# Refresh NodeInfoPanel if it's showing
		if node_info_panel and node_info_panel.visible:
			node_info_panel.refresh()
		refresh()

	_clear_pending_slot()

func _on_god_selection_panel_cancelled() -> void:
	"""Handle god selection cancelled"""
	print("HexTerritoryScreen: God selection cancelled")
	_clear_pending_slot()

func _on_god_selection_panel_closed() -> void:
	"""Handle god selection panel fully closed"""
	pass  # Panel handles its own hide animation

func _get_all_owned_nodes() -> Array:
	"""Get all player-owned nodes from the hex grid"""
	if not hex_map_view or not hex_map_view.hex_grid_manager:
		push_error("HexTerritoryScreen: hex_map_view or hex_grid_manager not available")
		return []

	return hex_map_view.hex_grid_manager.get_player_nodes()

func _clear_pending_slot() -> void:
	"""Clear pending slot context"""
	_pending_slot_node = null
	_pending_slot_type = ""
	_pending_slot_index = -1

func _assign_god_to_garrison(node: HexNode, god_id: String, _slot_index: int) -> bool:
	"""Assign a god to the node's garrison"""
	if not territory_manager:
		push_error("HexTerritoryScreen: TerritoryManager not available")
		return false

	# Check if node is controlled by player
	if not node.is_controlled_by_player():
		push_warning("HexTerritoryScreen: Cannot assign garrison to uncontrolled node")
		return false

	# Check if there's room in garrison
	if node.garrison.size() >= 4:  # MAX_GARRISON_SLOTS
		push_warning("HexTerritoryScreen: Garrison is full")
		return false

	# Add god to garrison (appends to end)
	var new_garrison = node.garrison.duplicate()
	new_garrison.append(god_id)

	# Update via TerritoryManager
	var success = territory_manager.update_node_garrison(node.id, new_garrison)
	if success:
		print("HexTerritoryScreen: Assigned %s to garrison of %s" % [god_id, node.id])
	return success

func _assign_god_to_worker(node: HexNode, god_id: String, _slot_index: int) -> bool:
	"""Assign a god as a worker to the node"""
	if not territory_manager:
		push_error("HexTerritoryScreen: TerritoryManager not available")
		return false

	# Check if node is controlled by player
	if not node.is_controlled_by_player():
		push_warning("HexTerritoryScreen: Cannot assign workers to uncontrolled node")
		return false

	# Check if there's room for workers
	var max_workers = mini(node.tier, 5)
	if node.assigned_workers.size() >= max_workers:
		push_warning("HexTerritoryScreen: Worker slots are full")
		return false

	# Add god to workers (appends to end)
	var new_workers = node.assigned_workers.duplicate()
	new_workers.append(god_id)

	# Update via TerritoryManager
	var success = territory_manager.update_node_workers(node.id, new_workers)
	if success:
		print("HexTerritoryScreen: Assigned %s as worker at %s" % [god_id, node.id])
	return success

func _on_node_detail_close() -> void:
	"""Handle close from node detail screen"""
	_hide_node_detail_screen()

func _on_node_detail_garrison_changed(_node: HexNode, _garrison_ids: Array) -> void:
	"""Handle garrison change notification from node detail screen"""
	refresh()

func _on_node_detail_workers_changed(_node: HexNode, _worker_ids: Array) -> void:
	"""Handle workers change notification from node detail screen"""
	refresh()

# ==============================================================================
# PANEL MANAGEMENT
# ==============================================================================

func navigate_to_node(node_id: String, open_crafting: bool = false) -> void:
	"""Public method to navigate to and open a specific node's info panel.
	Called externally (e.g., from forge button to open forge node with crafting tab)."""
	var hex_grid_mgr = SystemRegistry.get_instance().get_system("HexGridManager")
	if not hex_grid_mgr:
		return

	var hex_node = hex_grid_mgr.get_node_by_id(node_id)
	if not hex_node:
		print("HexTerritoryScreen: Node not found: %s" % node_id)
		return

	# Center map on node
	if hex_map_view:
		hex_map_view.center_on_coord(hex_node.coord)
		hex_map_view.select_node(hex_node)

	# Set as selected
	selected_node = hex_node

	# Show info panel
	_show_node_info(hex_node)

	# Open crafting tab if requested
	if open_crafting and node_info_panel:
		# Call deferred to ensure panel is fully shown first
		call_deferred("_open_crafting_tab_on_node_panel")

func _open_crafting_tab_on_node_panel() -> void:
	"""Open the crafting tab on the current node info panel"""
	if node_info_panel and node_info_panel.has_method("show_crafting_tab"):
		node_info_panel.show_crafting_tab()

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

func _show_node_detail_screen(hex_node: HexNode) -> void:
	"""Show node detail screen for owned node management"""
	if not node_detail_screen or not hex_node:
		return

	# Only show detail screen for player-controlled nodes
	if not hex_node.is_controlled_by_player():
		return

	# Hide other panels
	_hide_node_info()

	# Show detail screen
	node_detail_screen.show_node(hex_node)

func _hide_node_detail_screen() -> void:
	"""Hide node detail screen"""
	if node_detail_screen:
		node_detail_screen.hide_screen()

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

	# Show building selection popup for blank buildable tiles
	if hex_node and hex_node.can_place_building() and building_selection_popup:
		# Small delay to let battle screen transition complete
		await get_tree().create_timer(0.5).timeout
		building_selection_popup.show_for_node(hex_node)

func _on_capture_failed(hex_node: HexNode) -> void:
	"""Handle failed node capture from NodeCaptureHandler"""
	refresh()

# ==============================================================================
# BUILDING SELECTION HANDLERS
# ==============================================================================
func _on_building_selected(hex_node: HexNode, building_id: String) -> void:
	"""Handle building selected from popup - building already placed by popup"""
	print("HexTerritoryScreen: Building '%s' placed on node '%s'" % [building_id, hex_node.id])
	refresh()

	# Show success feedback
	_show_building_placed_feedback(hex_node, building_id)

func _on_building_selection_cancelled(hex_node: HexNode) -> void:
	"""Handle building selection cancelled - tile remains blank"""
	print("HexTerritoryScreen: Building selection cancelled for node '%s'" % hex_node.id)
	# Player can select a building later from node info panel

func _on_building_popup_closed() -> void:
	"""Handle building popup fully closed"""
	pass

func _on_select_building_requested(hex_node: HexNode) -> void:
	"""Handle select building request from node info panel"""
	if hex_node and building_selection_popup:
		building_selection_popup.show_for_node(hex_node)

func _show_building_placed_feedback(hex_node: HexNode, building_id: String) -> void:
	"""Show feedback that a building was placed"""
	var building_manager = SystemRegistry.get_instance().get_system("BuildingManager")
	var building_name = building_id.replace("_", " ").capitalize()
	if building_manager:
		var building = building_manager.get_building(building_id)
		building_name = building.get("name", building_name)

	# Create floating feedback panel
	var feedback = PanelContainer.new()
	feedback.z_index = 150

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.3, 0.95)
	style.border_color = Color(0.4, 0.7, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	feedback.add_theme_stylebox_override("panel", style)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	feedback.add_child(content)

	var title_label = Label.new()
	title_label.text = "🏗️ Building Placed!"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var name_label = Label.new()
	name_label.text = building_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var node_label = Label.new()
	node_label.text = "at %s" % hex_node.name
	node_label.add_theme_font_size_override("font_size", 12)
	node_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(node_label)

	# Add to main container
	main_container.add_child(feedback)

	# Position at center of screen
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	feedback.custom_minimum_size = Vector2(280, 100)

	# Fade out and remove after 2.5 seconds
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

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
