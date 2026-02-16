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
var node_info_panel: PvPNodeInfoPanel = null
var leaderboard_panel: Control = null
var leaderboard_container: VBoxContainer = null

var _loading_overlay: Control = null
var _loading_label: Label = null

# ==============================================================================
# STATE
# ==============================================================================
var _map_instance: PvPMapInstance = null
var _territory_manager: PvPTerritoryManager = null
var _data_sync: PvPTerritoryDataSync = null
var _capture_handler: PvPNodeCaptureHandler = null

var _current_user_uid: String = ""
var _is_loading: bool = true
var is_info_panel_visible: bool = false
var is_leaderboard_visible: bool = true
var selected_node: PvPHexNode = null

# System references
var screen_manager = null

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
	"""Create and setup PvPNodeInfoPanel component"""
	node_info_panel = PvPNodeInfoPanel.new()
	node_info_panel.name = "NodeInfoPanel"
	node_info_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_panel_container.add_child(node_info_panel)


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
		node_info_panel.set_defense_requested.connect(_on_set_defense_requested)
		node_info_panel.close_requested.connect(_on_node_info_close)


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

	# Connect to map joined signal
	if not _data_sync.map_joined.is_connected(_on_map_joined):
		_data_sync.map_joined.connect(_on_map_joined)

	# Fetch available maps and join the first one (or create mock)
	_data_sync.maps_fetched.connect(_on_maps_fetched, CONNECT_ONE_SHOT)
	_data_sync.fetch_available_maps()


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
	# Create map instance
	_map_instance = PvPMapInstance.new()
	_map_instance.initialize(map_data, _current_user_uid)
	_map_instance.leaderboard_changed.connect(_update_leaderboard)

	# Create territory manager
	_territory_manager = PvPTerritoryManager.new()
	_territory_manager.initialize(_map_instance, _data_sync)
	add_child(_territory_manager)

	# Create capture handler
	_capture_handler = PvPNodeCaptureHandler.new()
	_capture_handler.initialize(_territory_manager, _map_instance)

	# Initialize UI components
	hex_map_view.initialize(_map_instance, _current_user_uid)
	node_info_panel.initialize(_territory_manager, _current_user_uid)

	# Update displays
	_update_leaderboard()

	# Center on player's territory (not map center)
	_center_on_player_territory()


# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_back_pressed() -> void:
	"""Handle back button press"""
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
	if not _capture_handler:
		return

	if _capture_handler.initiate_attack(hex):
		_open_battle_setup(hex)


func _on_set_defense_requested(hex: PvPHexNode) -> void:
	"""Handle defense team setup request"""
	_open_defense_setup(hex)


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
func _open_battle_setup(_hex: PvPHexNode) -> void:
	"""Open battle setup for attacking a hex"""
	# Navigate to battle setup screen
	if screen_manager:
		if screen_manager.change_screen("battle_setup"):
			var battle_setup_screen = screen_manager.get_current_screen()
			if battle_setup_screen and battle_setup_screen.has_method("setup_for_pvp_attack"):
				battle_setup_screen.setup_for_pvp_attack(_hex)


func _open_defense_setup(_hex: PvPHexNode) -> void:
	"""Open team selection for setting defense"""
	# Navigate to battle setup screen for defense configuration
	if screen_manager:
		if screen_manager.change_screen("battle_setup"):
			var battle_setup_screen = screen_manager.get_current_screen()
			if battle_setup_screen and battle_setup_screen.has_method("setup_for_pvp_defense"):
				battle_setup_screen.setup_for_pvp_defense(_hex)


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
