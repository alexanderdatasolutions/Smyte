# scripts/ui/screens/PvPHexTerritoryScreen.gd
# Main hex territory screen for 8-player PvP - follows HexTerritoryScreen patterns
class_name PvPHexTerritoryScreen
extends Control

"""
PvPHexTerritoryScreen - Unified PvP territory screen
Follows HexTerritoryScreen patterns with PvP-specific features:
- 8-player color system
- Leaderboard panel
- Attack/defense mechanics

Layout (matches HexTerritoryScreen):
- Top: Unified header via MainUIOverlay
- Left floating: Overview button + Leaderboard toggle
- Center: PvPHexMapView (pan/zoom hex grid)
- Right floating: Zoom controls
- Right panel (380px): PvPNodeInfoPanel (slides in on selection)
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal back_pressed

# ==============================================================================
# CONSTANTS
# ==============================================================================
const TOP_BAR_HEIGHT := 60
const INFO_PANEL_WIDTH := 380
const LEADERBOARD_WIDTH := 220

# Colors from UI_DESIGN_PATTERNS.md
const COLOR_BACKGROUND := Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG := Color(0.12, 0.1, 0.16, 0.95)
const COLOR_BORDER := Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER := Color(0.8, 0.8, 0.9)
const COLOR_TEXT := Color(0.7, 0.7, 0.8)
const COLOR_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)
const COLOR_GOLD := Color(1.0, 0.84, 0.0)

# Preloads
const GodSelectionPanelScript = preload("res://scripts/ui/territory/GodSelectionPanel.gd")
const BuildingSelectionPopupScript = preload("res://scripts/ui/territory/BuildingSelectionPopup.gd")

# ==============================================================================
# UI COMPONENTS
# ==============================================================================
var main_container: Control = null
var center_container: Control = null
var info_panel_container: Control = null

var zoom_controls: VBoxContainer = null
var overview_button: Button = null
var leaderboard_button: Button = null

var hex_map_view: PvPHexMapView = null
var node_info_panel: NodeInfoPanel = null  # Using unified NodeInfoPanel for consistency
var leaderboard_panel: Control = null
var leaderboard_container: VBoxContainer = null
var god_selection_panel: Control = null  # GodSelectionPanel for garrison/worker assignment
var building_selection_popup = null  # BuildingSelectionPopup for building selection

var _loading_overlay: Control = null
var _loading_label: Label = null

# Pending slot assignment context
var _pending_slot_node: Variant = null
var _pending_slot_type: String = ""
var _pending_slot_index: int = -1

# ==============================================================================
# STATE
# ==============================================================================
var _map_instance: PvPMapInstance = null
var _territory_manager: PvPTerritoryManager = null
var _data_sync: PvPTerritoryDataSync = null
var _capture_handler: NodeCaptureHandler = null  # Unified handler for both regular and PvP territory
var _ai_controller: PvPAIController = null  # AI for test mode

var _current_user_uid: String = ""
var _is_loading: bool = true
var is_info_panel_visible: bool = false
var is_leaderboard_visible: bool = true
var selected_node: PvPHexNode = null

# System references
var screen_manager = null
var _battle_coordinator = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_create_ui_structure()
	_setup_components()
	_connect_signals()
	_style_components()
	_setup_unified_header()

	# Fix size after everything is set up (when Control is child of Node2D)
	call_deferred("_fix_size_for_node2d_parent")

	# Auto-join a map when screen opens
	call_deferred("_auto_join_map")


func _fix_size_for_node2d_parent() -> void:
	"""Fix size when Control is child of Node2D - must be deferred"""
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size


func _setup_unified_header() -> void:
	"""Configure the unified header for this screen"""
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()


func _on_visibility_changed() -> void:
	"""Update header when this screen becomes visible"""
	if visible:
		_update_header_for_screen()


func _update_header_for_screen() -> void:
	"""Apply this screen's header settings"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("PVP TERRITORY")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)


func _init_systems() -> void:
	"""Initialize system references via SystemRegistry"""
	var registry = _get_system_registry()
	if registry:
		screen_manager = registry.get_system("ScreenManager")
		_battle_coordinator = registry.get_system("BattleCoordinator")


# ==============================================================================
# UI STRUCTURE
# ==============================================================================
func _create_ui_structure() -> void:
	"""Create the main UI layout structure"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	_create_background()

	# Main container fills screen
	main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.visible = false  # Hidden until map loads
	add_child(main_container)

	# Center container for hex map
	_create_center_container()

	# Right panel container for node info (slides in from right)
	_create_panel_container()

	# Floating buttons on top of everything
	_create_floating_buttons()

	# Leaderboard panel (left side, toggleable)
	_create_leaderboard_panel()

	# Loading overlay (shown first)
	_create_loading_overlay()


func _create_background() -> void:
	"""Create dark background"""
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BACKGROUND
	add_child(bg)


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
	zoom_controls.offset_bottom = 130
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


func _create_floating_buttons() -> void:
	"""Create floating buttons on the left side"""
	# Overview/leaderboard toggle button
	leaderboard_button = Button.new()
	leaderboard_button.name = "LeaderboardButton"
	leaderboard_button.text = "🏆"
	leaderboard_button.tooltip_text = "Toggle Leaderboard"
	leaderboard_button.custom_minimum_size = Vector2(50, 50)
	leaderboard_button.pressed.connect(_on_leaderboard_toggle_pressed)

	leaderboard_button.anchor_left = 0.0
	leaderboard_button.anchor_top = 0.0
	leaderboard_button.anchor_right = 0.0
	leaderboard_button.anchor_bottom = 0.0
	leaderboard_button.offset_left = 10
	leaderboard_button.offset_top = 70
	leaderboard_button.offset_right = 60
	leaderboard_button.offset_bottom = 120

	main_container.add_child(leaderboard_button)


func _create_panel_container() -> void:
	"""Create panel container for node info (slides in from right)"""
	info_panel_container = Control.new()
	info_panel_container.name = "InfoPanelContainer"
	info_panel_container.anchor_left = 1.0
	info_panel_container.anchor_top = 0.0
	info_panel_container.anchor_right = 1.0
	info_panel_container.anchor_bottom = 1.0
	info_panel_container.offset_left = -INFO_PANEL_WIDTH
	info_panel_container.offset_top = TOP_BAR_HEIGHT
	info_panel_container.offset_right = 0
	info_panel_container.offset_bottom = 0
	info_panel_container.visible = false  # Start hidden
	main_container.add_child(info_panel_container)


func _create_leaderboard_panel() -> void:
	"""Create leaderboard panel on left side"""
	leaderboard_panel = Panel.new()
	leaderboard_panel.name = "LeaderboardPanel"
	leaderboard_panel.anchor_left = 0.0
	leaderboard_panel.anchor_top = 0.0
	leaderboard_panel.anchor_right = 0.0
	leaderboard_panel.anchor_bottom = 1.0
	leaderboard_panel.offset_left = 10
	leaderboard_panel.offset_top = 130  # Below floating button
	leaderboard_panel.offset_right = 10 + LEADERBOARD_WIDTH
	leaderboard_panel.offset_bottom = -10

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	leaderboard_panel.add_theme_stylebox_override("panel", style)

	main_container.add_child(leaderboard_panel)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.name = "LeaderboardScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	leaderboard_panel.add_child(scroll)

	leaderboard_container = VBoxContainer.new()
	leaderboard_container.name = "LeaderboardContainer"
	leaderboard_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(leaderboard_container)

	# Header
	var header = Label.new()
	header.text = "🏆 LEADERBOARD"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", COLOR_HEADER)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_container.add_child(header)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	leaderboard_container.add_child(sep)


func _create_loading_overlay() -> void:
	"""Create loading overlay shown while joining map"""
	_loading_overlay = Control.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_loading_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BACKGROUND
	_loading_overlay.add_child(bg)

	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_overlay.add_child(center)

	_loading_label = Label.new()
	_loading_label.text = "Joining PvP Territory..."
	_loading_label.add_theme_font_size_override("font_size", 24)
	_loading_label.add_theme_color_override("font_color", COLOR_HEADER)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_loading_label)

	var hint = Label.new()
	hint.text = "Preparing battlefield"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint)


# ==============================================================================
# SETUP COMPONENTS
# ==============================================================================
func _setup_components() -> void:
	"""Setup hex map view and info panels"""
	_setup_hex_map_view()
	_setup_node_info_panel()
	_setup_god_selection_panel()
	_setup_building_selection_popup()


func _setup_hex_map_view() -> void:
	"""Create and setup PvPHexMapView component"""
	hex_map_view = PvPHexMapView.new()
	hex_map_view.name = "HexMapView"
	hex_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hex_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hex_map_view.offset_right = 0
	center_container.add_child(hex_map_view)
	center_container.move_child(hex_map_view, 0)  # Behind zoom controls


func _setup_node_info_panel() -> void:
	"""Create and setup NodeInfoPanel component (unified for both regular and PvP territory)"""
	node_info_panel = NodeInfoPanel.new()
	node_info_panel.name = "NodeInfoPanel"
	node_info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_panel_container.add_child(node_info_panel)


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
	# Hex map view signals
	if hex_map_view:
		hex_map_view.hex_selected.connect(_on_hex_selected)
		hex_map_view.hex_hovered.connect(_on_hex_hovered)

	# Node info panel signals
	if node_info_panel:
		node_info_panel.attack_requested.connect(_on_attack_requested)
		node_info_panel.close_requested.connect(_on_node_info_close)
		node_info_panel.slot_tapped.connect(_on_garrison_slot_tapped)
		node_info_panel.filled_slot_tapped.connect(_on_filled_garrison_slot_tapped)
		node_info_panel.capture_requested.connect(_on_attack_requested)  # Alias for neutral captures
		node_info_panel.select_building_requested.connect(_on_select_building_requested)
		node_info_panel.demolish_building_requested.connect(_on_demolish_building_requested)

	# God selection panel signals
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
	_style_zoom_buttons()
	_style_floating_buttons()


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
			child.add_theme_font_size_override("font_size", 20)


func _style_floating_buttons() -> void:
	"""Style floating buttons"""
	for btn in [leaderboard_button]:
		if not btn:
			continue

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
		style.border_color = Color(0.5, 0.45, 0.6, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)

		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.2, 0.17, 0.28, 0.98)
		hover_style.border_color = Color(0.6, 0.55, 0.7, 1.0)
		hover_style.set_border_width_all(2)
		hover_style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.add_theme_font_size_override("font_size", 24)


# ==============================================================================
# AUTO-JOIN
# ==============================================================================
func _auto_join_map() -> void:
	"""Auto-join a map when screen opens"""
	var registry = _get_system_registry()
	if not registry:
		_show_error("System not ready")
		return

	# Get data sync
	_data_sync = registry.get_system("PvPTerritoryDataSync")
	if not _data_sync:
		# Create and register data sync if needed
		_data_sync = PvPTerritoryDataSync.new()
		_data_sync.name = "PvPTerritoryDataSync"
		add_child(_data_sync)

	_current_user_uid = _data_sync.get_user_id()

	# Check if we have test map data from PvPSignupManager
	if _data_sync.is_test_mode():
		print("PvPHexTerritoryScreen: Loading test map data")
		var test_data: Dictionary = _data_sync.get_test_map_data()
		if not test_data.is_empty():
			_loading_label.text = "Loading test map..."
			_on_test_map_ready(test_data)
			return

	# Connect to map joined signal
	if not _data_sync.map_joined.is_connected(_on_map_joined):
		_data_sync.map_joined.connect(_on_map_joined)

	# Check if we have a specific map_id from PvPSignupScreen (real multiplayer)
	if screen_manager and screen_manager.has_meta("pvp_map_id"):
		var map_id: String = screen_manager.get_meta("pvp_map_id")
		if not map_id.is_empty():
			print("PvPHexTerritoryScreen: Joining realtime map from signup: %s" % map_id)
			_loading_label.text = "Joining multiplayer match..."
			_data_sync.join_realtime_map(map_id)
			# Clear the meta so we don't rejoin on screen revisit
			screen_manager.remove_meta("pvp_map_id")
			return

	# Fetch available maps and join the first one (or create mock)
	_data_sync.maps_fetched.connect(_on_maps_fetched, CONNECT_ONE_SHOT)
	_data_sync.fetch_available_maps()


func _on_test_map_ready(map_data: Dictionary) -> void:
	"""Handle test map data loaded from PvPSignupManager"""
	_is_loading = false

	var hexes: Dictionary = map_data.get("hexes", {})
	var players: Array = map_data.get("players", [])
	var map_id: String = map_data.get("map_id", "test_map")

	print("PvPHexTerritoryScreen: Test map has %d hexes and %d players" % [hexes.size(), players.size()])

	# Build map_data in the format _initialize_with_map expects
	var formatted_data := {
		"map_id": map_id,
		"hexes": hexes,
		"players": players
	}

	_initialize_with_map(formatted_data)

	# Show content, hide loading
	_loading_overlay.visible = false
	main_container.visible = true


func _on_maps_fetched(maps: Array) -> void:
	"""Handle maps fetched - join the first available one"""
	if maps.is_empty():
		_loading_label.text = "Creating local map..."
		_data_sync.join_map("mock_map_1")
	else:
		var map_info: Dictionary = maps[0]
		_loading_label.text = "Joining map..."
		_data_sync.join_map(map_info.get("map_id", "mock_map_1"))


func _on_map_joined(map_data: Dictionary, success: bool) -> void:
	"""Handle map join result"""
	_is_loading = false

	if not success:
		_show_error(map_data.get("error", "Failed to join map"))
		return

	# Re-fetch user ID now that Firebase is confirmed ready (ensure_firebase_ready was called in join_realtime_map)
	if _data_sync:
		_current_user_uid = _data_sync.get_user_id()
		print("PvPHexTerritoryScreen: Using user_id=%s for map display" % _current_user_uid)

	# Initialize with map data
	_initialize_with_map(map_data)

	# Show content, hide loading
	_loading_overlay.visible = false
	main_container.visible = true


func _show_error(message: String) -> void:
	"""Show error message"""
	if is_instance_valid(_loading_label):
		_loading_label.text = message
		_loading_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _initialize_with_map(map_data: Dictionary) -> void:
	"""Initialize screen with map data after joining"""
	# Debug: log user ID being used
	print("PvPHexTerritoryScreen: Initializing map with user_id=%s" % _current_user_uid)

	# Create map instance
	_map_instance = PvPMapInstance.new()
	_map_instance.initialize(map_data, _current_user_uid)
	_map_instance.leaderboard_changed.connect(_update_leaderboard)
	_map_instance.hex_captured.connect(_on_hex_captured)

	# Debug: Check how many hexes user owns
	var my_hexes := _map_instance.get_my_hexes()
	print("PvPHexTerritoryScreen: User owns %d hexes" % my_hexes.size())
	if my_hexes.size() > 0:
		print("PvPHexTerritoryScreen: First owned hex: %s at (%d,%d)" % [my_hexes[0].id, my_hexes[0].coord.q, my_hexes[0].coord.r])

	# Create territory manager
	_territory_manager = PvPTerritoryManager.new()
	_territory_manager.initialize(_map_instance, _data_sync)
	_territory_manager.match_ended.connect(_on_match_ended)
	add_child(_territory_manager)

	# Create unified capture handler (works for both regular and PvP territory)
	_capture_handler = NodeCaptureHandler.new()
	_capture_handler.name = "NodeCaptureHandler"
	_capture_handler.hex_map_view = hex_map_view
	_capture_handler.pvp_territory_manager = _territory_manager  # Pass local manager
	add_child(_capture_handler)

	# Connect capture handler signals
	_capture_handler.capture_succeeded.connect(_on_capture_succeeded)
	_capture_handler.capture_failed.connect(_on_capture_failed)

	# Initialize UI components
	hex_map_view.initialize(_map_instance, _current_user_uid)
	node_info_panel.initialize_pvp(_territory_manager, _current_user_uid)

	# Connect real-time signals for multiplayer sync
	_connect_realtime_signals(map_data.get("map_id", ""))

	# Initialize AI controller for test mode
	_setup_ai_controller()

	# Update displays
	_update_leaderboard()

	# Center on player's territory (not map center)
	_center_on_player_territory()


func _setup_ai_controller() -> void:
	"""Setup AI controller for test/offline mode"""
	# Only enable AI in test mode (when data_sync says we're testing)
	if not _data_sync or not _data_sync.is_test_mode():
		return

	_ai_controller = PvPAIController.new()
	_ai_controller.name = "PvPAIController"
	add_child(_ai_controller)

	# Initialize with map and player data
	_ai_controller.initialize(_map_instance, _territory_manager, _current_user_uid)

	# Connect signals
	_ai_controller.ai_captured_hex.connect(_on_ai_captured_hex)
	_ai_controller.ai_battle_occurred.connect(_on_ai_battle_occurred)
	_ai_controller.ai_tick_completed.connect(_on_ai_tick_completed)

	# Start AI with a small delay so player can see the initial map
	await get_tree().create_timer(2.0).timeout
	_ai_controller.start()


func _on_ai_captured_hex(ai_uid: String, hex_id: String) -> void:
	"""Handle AI capturing a hex - refresh visuals"""
	# Refresh the map view
	if hex_map_view:
		hex_map_view.queue_redraw()

	# Update leaderboard
	_update_leaderboard()

	# Play animation on the captured hex
	var hex: PvPHexNode = _map_instance.get_hex(hex_id) if _map_instance else null
	if hex and hex_map_view and hex_map_view.has_method("play_capture_animation"):
		hex_map_view.play_capture_animation(hex)


func _on_ai_battle_occurred(attacker_uid: String, defender_uid: String, hex_id: String, attacker_won: bool) -> void:
	"""Handle AI vs AI (or AI vs player) battle notification"""
	# Could show a notification or animation here
	pass


func _on_ai_tick_completed() -> void:
	"""Handle AI tick completion - batch refresh"""
	if hex_map_view:
		hex_map_view.queue_redraw()
	_update_leaderboard()


# ==============================================================================
# REAL-TIME SYNC
# ==============================================================================
func _connect_realtime_signals(map_id: String) -> void:
	"""Connect real-time signals for multiplayer sync"""
	if not _data_sync:
		return

	# Connect remote capture signal
	if not _data_sync.hex_captured_remotely.is_connected(_on_remote_hex_captured):
		_data_sync.hex_captured_remotely.connect(_on_remote_hex_captured)

	# Connect player events
	if not _data_sync.player_joined_map.is_connected(_on_remote_player_joined):
		_data_sync.player_joined_map.connect(_on_remote_player_joined)
	if not _data_sync.player_left_map.is_connected(_on_remote_player_left):
		_data_sync.player_left_map.connect(_on_remote_player_left)

	# Start real-time listeners (uses RTDB for instant updates)
	if not map_id.is_empty():
		_data_sync.start_realtime_sync(map_id)
		_data_sync.update_player_presence(true)
		print("PvPHexTerritoryScreen: Started real-time sync for map %s" % map_id)


func _disconnect_realtime_signals() -> void:
	"""Disconnect real-time signals when leaving"""
	if not _data_sync:
		return

	_data_sync.update_player_presence(false)
	_data_sync.stop_realtime_sync()

	if _data_sync.hex_captured_remotely.is_connected(_on_remote_hex_captured):
		_data_sync.hex_captured_remotely.disconnect(_on_remote_hex_captured)
	if _data_sync.player_joined_map.is_connected(_on_remote_player_joined):
		_data_sync.player_joined_map.disconnect(_on_remote_player_joined)
	if _data_sync.player_left_map.is_connected(_on_remote_player_left):
		_data_sync.player_left_map.disconnect(_on_remote_player_left)


func _on_remote_hex_captured(hex_id: String, new_owner_uid: String, new_owner_name: String) -> void:
	"""Handle a hex captured by another player in real-time"""
	if not _map_instance:
		return

	var hex: PvPHexNode = _map_instance.get_hex(hex_id)
	if not hex:
		return

	# Skip if this is our own capture (already handled locally)
	if new_owner_uid == _current_user_uid:
		return

	print("PvPHexTerritoryScreen: Remote capture - %s (%s) captured by %s" % [hex_id, hex.name, new_owner_name])

	# Update local state via map instance
	_map_instance.process_capture(hex_id, new_owner_uid, new_owner_name)

	# Update map view with capture animation
	if hex_map_view and hex_map_view.has_method("play_remote_capture_animation"):
		hex_map_view.play_remote_capture_animation(hex_id, new_owner_uid)
	elif hex_map_view:
		hex_map_view.queue_redraw()

	# Update node info panel if viewing this hex
	if selected_node and selected_node.id == hex_id:
		node_info_panel.show_node(hex, false)


func _on_remote_player_joined(player_uid: String, player_data: Dictionary) -> void:
	"""Handle a player joining the map"""
	if not _map_instance:
		return

	_map_instance.update_player(player_uid, player_data)
	_update_leaderboard()

	var player_name: String = player_data.get("display_name", "Unknown")
	print("PvPHexTerritoryScreen: Player %s joined the map" % player_name)


func _on_remote_player_left(player_uid: String) -> void:
	"""Handle a player leaving/disconnecting"""
	print("PvPHexTerritoryScreen: Player %s left the map" % player_uid)
	_update_leaderboard()


func _on_hex_captured(hex_id: String, old_owner: String, new_owner: String) -> void:
	"""Handle any hex capture (local or remote) for UI update"""
	# Refresh map view
	if hex_map_view:
		hex_map_view.queue_redraw()


func _on_match_ended(winner_uid: String, winner_name: String, is_current_user_winner: bool) -> void:
	"""Handle match end - show victory/defeat overlay"""
	print("PvPHexTerritoryScreen: Match ended! Winner: %s, Is me: %s" % [winner_name, is_current_user_winner])

	# Create match end overlay
	_show_match_end_overlay(winner_name, is_current_user_winner)


func _show_match_end_overlay(winner_name: String, is_winner: bool) -> void:
	"""Show the match end overlay with victory/defeat message"""
	var overlay := ColorRect.new()
	overlay.name = "MatchEndOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.z_index = 200
	add_child(overlay)

	var container := VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 30)
	overlay.add_child(container)

	# Result title
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_winner:
		title.text = "🏆 VICTORY! 🏆"
		title.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		title.text = "MATCH ENDED"
		title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	title.add_theme_font_size_override("font_size", 48)
	container.add_child(title)

	# Winner name
	var winner_label := Label.new()
	winner_label.text = "Winner: %s" % winner_name
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 28)
	winner_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	container.add_child(winner_label)

	# Stats (if available)
	if _map_instance:
		var stats_label := Label.new()
		var rank: int = _map_instance.get_my_rank()
		var hex_count: int = _map_instance.get_my_hex_count()
		stats_label.text = "Your rank: #%d | Territories held: %d" % [rank, hex_count]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 18)
		stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		container.add_child(stats_label)

	# Return button
	var return_btn := Button.new()
	return_btn.text = "Return to World"
	return_btn.custom_minimum_size = Vector2(200, 50)
	return_btn.pressed.connect(_on_back_pressed)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.5, 0.8)
	btn_style.set_corner_radius_all(8)
	return_btn.add_theme_stylebox_override("normal", btn_style)
	return_btn.add_theme_font_size_override("font_size", 18)

	container.add_child(return_btn)


# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_back_pressed() -> void:
	"""Handle back button press"""
	# Stop AI controller
	if _ai_controller:
		_ai_controller.stop()

	# Disconnect real-time signals before leaving
	_disconnect_realtime_signals()

	if _data_sync:
		_data_sync.leave_current_map()

	back_pressed.emit()

	if screen_manager:
		screen_manager.change_screen("world_view")


func _on_zoom_in_pressed() -> void:
	"""Handle zoom in button"""
	if hex_map_view:
		hex_map_view.zoom_in()


func _on_zoom_out_pressed() -> void:
	"""Handle zoom out button"""
	if hex_map_view:
		hex_map_view.zoom_out()


func _on_center_pressed() -> void:
	"""Handle center button - center on player's territory"""
	_center_on_player_territory()


func _center_on_player_territory() -> void:
	"""Center the camera on the player's territory"""
	if not hex_map_view or not _map_instance:
		return

	# Get player's hexes
	var my_hexes := _map_instance.get_my_hexes()
	if my_hexes.is_empty():
		# Fallback to map center if no hexes
		hex_map_view.center_on_center()
		return

	# Find spawn node first, or use first hex
	var target_hex: PvPHexNode = null
	for hex: PvPHexNode in my_hexes:
		if hex.is_spawn_node:
			target_hex = hex
			break

	# If no spawn found, use first hex
	if not target_hex:
		target_hex = my_hexes[0]

	# Center on the target hex
	if target_hex and target_hex.coord:
		hex_map_view.center_on_coord(target_hex.coord)


func _on_leaderboard_toggle_pressed() -> void:
	"""Toggle leaderboard visibility"""
	is_leaderboard_visible = not is_leaderboard_visible
	leaderboard_panel.visible = is_leaderboard_visible


func _on_hex_selected(hex_node: PvPHexNode) -> void:
	"""Handle hex node selection from map"""
	selected_node = hex_node
	_show_node_info(hex_node)


func _on_hex_hovered(_hex_node: PvPHexNode) -> void:
	"""Handle hex node hover"""
	pass  # Could show tooltip in future


func _on_attack_requested(hex: PvPHexNode) -> void:
	"""Handle attack request"""
	if not _territory_manager or not hex:
		return

	# Validate attack via PvPTerritoryManager
	var validation := _territory_manager.can_attack_hex(hex)
	if not validation["can_attack"]:
		# Show error message
		var reason: String = validation.get("reason", "Cannot attack")
		_show_attack_error(reason)
		return

	# Start attack (sets cooldowns)
	if not _territory_manager.start_attack(hex):
		return

	# Navigate to battle setup
	_open_battle_setup(hex)


func _show_attack_error(reason: String) -> void:
	"""Show attack error notification"""
	var event_bus = _get_system_registry().get_system("EventBus") if _get_system_registry() else null
	if event_bus and event_bus.has_method("emit_notification"):
		event_bus.emit_notification(reason, "warning", 3.0)
	else:
		print("PvPHexTerritoryScreen: Attack error - %s" % reason)


func _on_capture_succeeded(hex_node: Variant, rewards: Dictionary) -> void:
	"""Handle successful capture from NodeCaptureHandler"""
	# Refresh UI
	refresh()

	# Update leaderboard
	_update_leaderboard()


func _on_capture_failed(hex_node: Variant) -> void:
	"""Handle failed capture from NodeCaptureHandler"""
	# Just refresh UI
	refresh()


func _on_select_building_requested(hex_node: Variant) -> void:
	"""Handle select building request from node info panel"""
	if hex_node and building_selection_popup:
		building_selection_popup.show_for_node(hex_node)


func _on_demolish_building_requested(hex_node: Variant) -> void:
	"""Handle demolish/change building request"""
	if hex_node and building_selection_popup:
		building_selection_popup.show_for_node(hex_node)


func _on_building_selected(building_type: String, hex_node: Variant) -> void:
	"""Handle building selection from popup"""
	if not hex_node:
		return

	var building_manager = SystemRegistry.get_instance().get_system("BuildingManager") if SystemRegistry.get_instance() else null
	if building_manager:
		building_manager.place_building(hex_node, building_type)

	# Refresh the node info panel
	if node_info_panel:
		node_info_panel.update_node(hex_node)


func _on_building_selection_cancelled() -> void:
	"""Handle building selection cancelled"""
	pass


func _on_building_popup_closed() -> void:
	"""Handle building popup closed"""
	pass


func _on_node_info_close() -> void:
	"""Handle node info panel close"""
	_hide_node_info()


# ==============================================================================
# PANEL MANAGEMENT
# ==============================================================================
func _show_node_info(hex_node: PvPHexNode) -> void:
	"""Show node info panel with node details"""
	if not node_info_panel or not hex_node:
		return

	# Update panel with node data
	node_info_panel.show_hex(hex_node)

	# Show panel container
	info_panel_container.visible = true
	is_info_panel_visible = true

	# Adjust hex map view width to make room for panel
	if hex_map_view:
		hex_map_view.offset_right = -INFO_PANEL_WIDTH


func _hide_node_info() -> void:
	"""Hide node info panel"""
	info_panel_container.visible = false
	is_info_panel_visible = false
	selected_node = null

	# Restore hex map view width
	if hex_map_view:
		hex_map_view.offset_right = 0

	# Deselect node on map
	if hex_map_view:
		hex_map_view.select_node(null)


# ==============================================================================
# LEADERBOARD
# ==============================================================================
func _update_leaderboard() -> void:
	"""Update leaderboard display"""
	if not _map_instance or not leaderboard_container:
		return

	# Clear existing entries (except header and separator)
	var children = leaderboard_container.get_children()
	for i in range(2, children.size()):
		children[i].queue_free()

	# Add entries
	var leaderboard = _map_instance.get_leaderboard()
	for entry: Dictionary in leaderboard:
		var entry_panel = _create_leaderboard_entry(entry)
		leaderboard_container.add_child(entry_panel)


func _create_leaderboard_entry(entry: Dictionary) -> Control:
	"""Create a leaderboard entry row"""
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(LEADERBOARD_WIDTH - 30, 60)

	var style = StyleBoxFlat.new()
	if entry.get("is_current_user", false):
		style.bg_color = Color(0.2, 0.3, 0.4, 0.5)
		style.border_color = COLOR_GOLD
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.15, 0.15, 0.2, 0.3)
		style.set_border_width_all(0)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	panel.add_child(vbox)

	# Rank and name row
	var top_row = HBoxContainer.new()
	vbox.add_child(top_row)

	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(8, 8)
	color_rect.color = entry.get("color", Color.GRAY)
	top_row.add_child(color_rect)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	top_row.add_child(spacer)

	var rank_label = Label.new()
	rank_label.text = "#%d" % entry.get("rank", 0)
	rank_label.add_theme_font_size_override("font_size", 14)
	rank_label.add_theme_color_override("font_color", COLOR_GOLD)
	rank_label.custom_minimum_size = Vector2(30, 0)
	top_row.add_child(rank_label)

	var name_label = Label.new()
	var display_name: String = entry.get("display_name", "Unknown")
	if entry.get("is_current_user", false):
		display_name += " (You)"
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_row.add_child(name_label)

	# Stats row
	var stats_label = Label.new()
	stats_label.text = "🏰 %d hexes  •  ⭐ %d pts" % [entry.get("hex_count", 0), entry.get("objective_score", 0)]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(stats_label)

	return panel


# ==============================================================================
# BATTLE SETUP
# ==============================================================================
func _open_battle_setup(hex: PvPHexNode) -> void:
	"""Open battle setup for attacking a hex"""
	# Store the hex in capture handler for result processing
	if _capture_handler:
		_capture_handler.current_capture_node = hex

	# Navigate to battle setup screen
	if screen_manager:
		if screen_manager.change_screen("battle_setup"):
			var battle_setup_screen = screen_manager.get_current_screen()
			if battle_setup_screen and battle_setup_screen.has_method("setup_for_pvp_attack"):
				battle_setup_screen.setup_for_pvp_attack(hex)
				# Connect to completion signal if not already connected
				if not battle_setup_screen.battle_setup_complete.is_connected(_on_battle_setup_complete):
					battle_setup_screen.battle_setup_complete.connect(_on_battle_setup_complete)


func _on_battle_setup_complete(context: Dictionary) -> void:
	"""Handle battle setup completion - start the capture battle with selected team"""
	# Only handle PvP territory attack context
	var context_type: String = context.get("type", "")
	if context_type != "pvp_territory_attack":
		return

	if not _capture_handler or not context.has("selected_team"):
		return

	# Get the hex node and selected team
	var hex_node = context.get("pvp_hex")  # PvP uses pvp_hex in context
	var selected_team = context.get("selected_team")

	if hex_node and selected_team:
		# Start the capture battle with the selected team (pvp_mode=true)
		_capture_handler.initiate_capture_with_team(hex_node, selected_team, true)


func _open_defense_setup(_hex: PvPHexNode) -> void:
	"""Open team selection for setting defense"""
	# Navigate to battle setup screen for defense configuration
	if screen_manager:
		if screen_manager.change_screen("battle_setup"):
			var battle_setup_screen = screen_manager.get_current_screen()
			if battle_setup_screen and battle_setup_screen.has_method("setup_for_pvp_defense"):
				battle_setup_screen.setup_for_pvp_defense(_hex)


# ==============================================================================
# GARRISON SLOT HANDLERS
# ==============================================================================
func _on_garrison_slot_tapped(node: Variant, slot_type: String, slot_index: int) -> void:
	"""Handle empty garrison/worker slot tap - opens GodSelectionPanel"""
	if not god_selection_panel or not node:
		return

	# Store context for when god is selected
	_pending_slot_node = node
	_pending_slot_type = slot_type
	_pending_slot_index = slot_index

	# Get currently assigned god IDs to exclude from selection
	var excluded_ids: Array[String] = []

	# Collect ALL assigned gods from all player's nodes
	if _map_instance:
		for hex: PvPHexNode in _map_instance.get_my_hexes():
			for god_id: String in hex.garrison:
				if god_id not in excluded_ids:
					excluded_ids.append(god_id)
			for god_id: String in hex.assigned_workers:
				if god_id not in excluded_ids:
					excluded_ids.append(god_id)

	# Show GodSelectionPanel with appropriate context
	if slot_type == "garrison":
		god_selection_panel.show_for_garrison(excluded_ids, node)
	else:
		god_selection_panel.show_for_worker(excluded_ids, node)


func _on_filled_garrison_slot_tapped(node: Variant, slot_type: String, slot_index: int, god: God) -> void:
	"""Handle filled garrison/worker slot tap - show confirmation popup to remove god"""
	if not node:
		return

	# Handle null god (stale reference)
	if not god:
		_remove_stale_slot(node, slot_type, slot_index)
		return

	# Show confirmation popup
	_show_remove_god_confirmation(node, slot_type, slot_index, god)


func _remove_stale_slot(node: Variant, slot_type: String, slot_index: int) -> void:
	"""Remove a stale god_id at the given slot index"""
	if slot_type == "garrison":
		if slot_index < node.garrison.size():
			node.garrison.remove_at(slot_index)
	else:
		if slot_index < node.assigned_workers.size():
			node.assigned_workers.remove_at(slot_index)
	refresh()


func _show_remove_god_confirmation(node: Variant, slot_type: String, slot_index: int, god: God) -> void:
	"""Show confirmation popup to remove a god from slot"""
	var popup := ConfirmationDialog.new()
	popup.title = "Remove %s?" % god.name
	popup.dialog_text = "Remove %s from %s?" % [god.name, slot_type]
	popup.ok_button_text = "Remove"
	popup.cancel_button_text = "Cancel"

	popup.confirmed.connect(func():
		_remove_god_from_slot(node, slot_type, slot_index)
		popup.queue_free()
	)
	popup.canceled.connect(func():
		popup.queue_free()
	)

	add_child(popup)
	popup.popup_centered()


func _remove_god_from_slot(node: Variant, slot_type: String, slot_index: int) -> void:
	"""Remove god from the specified slot"""
	if slot_type == "garrison":
		if slot_index < node.garrison.size():
			node.garrison.remove_at(slot_index)
	else:
		if slot_index < node.assigned_workers.size():
			node.assigned_workers.remove_at(slot_index)

	# Sync defense team if garrison changed
	if slot_type == "garrison" and _territory_manager:
		# Get the God objects for the remaining garrison
		var registry = _get_system_registry()
		var collection_manager = registry.get_system("CollectionManager") if registry else null
		if collection_manager:
			var team: Array = []
			for god_id: String in node.garrison:
				var god = collection_manager.get_god_by_id(god_id)
				if god:
					team.append(god)
			_territory_manager.update_hex_defense(node.id, team)

	refresh()


func _on_god_selection_panel_selected(god: God) -> void:
	"""Handle god selection from GodSelectionPanel - assigns god to pending slot"""
	if not _pending_slot_node or not god:
		return

	var node: Variant = _pending_slot_node
	var slot_type: String = _pending_slot_type

	# Add god to appropriate slot
	if slot_type == "garrison":
		if node.garrison.size() < node.max_garrison:
			node.garrison.append(god.id)

			# Update defense team in territory manager
			if _territory_manager:
				var registry = _get_system_registry()
				var collection_manager = registry.get_system("CollectionManager") if registry else null
				if collection_manager:
					var team: Array = []
					for god_id: String in node.garrison:
						var g = collection_manager.get_god_by_id(god_id)
						if g:
							team.append(g)
					_territory_manager.update_hex_defense(node.id, team)
	else:
		if node.assigned_workers.size() < node.max_workers:
			node.assigned_workers.append(god.id)

	# Clear pending context
	_pending_slot_node = null
	_pending_slot_type = ""
	_pending_slot_index = -1

	# Hide panel and refresh
	if god_selection_panel:
		god_selection_panel.hide()
	refresh()


func _on_god_selection_panel_cancelled() -> void:
	"""Handle god selection cancelled"""
	_pending_slot_node = null
	_pending_slot_type = ""
	_pending_slot_index = -1


func _on_god_selection_panel_closed() -> void:
	"""Handle god selection panel closed"""
	_pending_slot_node = null
	_pending_slot_type = ""
	_pending_slot_index = -1


# ==============================================================================
# REFRESH
# ==============================================================================
func refresh() -> void:
	"""Refresh the entire screen"""
	if hex_map_view:
		hex_map_view.refresh()

	if is_info_panel_visible and selected_node and node_info_panel:
		node_info_panel.show_hex(selected_node)

	_update_leaderboard()


# ==============================================================================
# HELPERS
# ==============================================================================
func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null
