# scripts/ui/screens/PvPMapSelectionScreen.gd
# Map browser/selection screen for PvP hex territory
extends Control
class_name PvPMapSelectionScreen

"""
PvPMapSelectionScreen - Browse and join PvP maps
Shows available maps with player counts and allows joining or creating new maps.
"""

# ==============================================================================
# CONSTANTS
# ==============================================================================

const COLOR_BACKGROUND := Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG := Color(0.12, 0.1, 0.16, 0.95)
const COLOR_CARD_BG := Color(0.15, 0.13, 0.2)
const COLOR_CARD_HOVER := Color(0.2, 0.18, 0.25)

# ==============================================================================
# STATE
# ==============================================================================

var _data_sync: PvPTerritoryDataSync = null
var _available_maps: Array = []
var _map_list_container: VBoxContainer = null
var _loading_label: Label = null
var _is_loading: bool = false

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_ui()
	_init_systems()
	_fetch_maps()


func _setup_ui() -> void:
	"""Build the screen layout"""
	# Ensure screen fills parent
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container with margins
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 70)  # Below header
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var main := VBoxContainer.new()
	main.name = "MainContainer"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 15)
	margin.add_child(main)

	# Header
	_create_header(main)

	# Action buttons
	_create_action_buttons(main)

	# Map list
	_create_map_list(main)

	# Back button
	_create_back_button(main)


func _create_header(parent: Control) -> void:
	"""Create header section"""
	var header_container := VBoxContainer.new()
	header_container.name = "HeaderContainer"
	header_container.add_theme_constant_override("separation", 8)
	parent.add_child(header_container)

	var header := Label.new()
	header.name = "Header"
	header.text = "PvP Territory Maps"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(header)

	var subheader := Label.new()
	subheader.text = "Join an existing map or create a new one"
	subheader.add_theme_font_size_override("font_size", 14)
	subheader.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(subheader)


func _create_action_buttons(parent: Control) -> void:
	"""Create quick action buttons"""
	var button_container := HBoxContainer.new()
	button_container.name = "ActionButtons"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	parent.add_child(button_container)

	# Quick Join button
	var quick_join_btn := _create_styled_button("Quick Join", Color(0.3, 0.6, 0.3))
	quick_join_btn.pressed.connect(_on_quick_join_pressed)
	button_container.add_child(quick_join_btn)

	# Create New button
	var create_btn := _create_styled_button("Create New Map", Color(0.3, 0.4, 0.7))
	create_btn.pressed.connect(_on_create_map_pressed)
	button_container.add_child(create_btn)

	# Refresh button
	var refresh_btn := _create_styled_button("Refresh", Color(0.4, 0.4, 0.5))
	refresh_btn.pressed.connect(_fetch_maps)
	button_container.add_child(refresh_btn)


func _create_styled_button(text: String, color: Color) -> Button:
	"""Create a styled button"""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 45)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn


func _create_map_list(parent: Control) -> void:
	"""Create scrollable map list"""
	# Section header
	var section_header := Label.new()
	section_header.name = "SectionHeader"
	section_header.text = "AVAILABLE MAPS"
	section_header.add_theme_font_size_override("font_size", 14)
	section_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	parent.add_child(section_header)

	# Use PanelContainer instead of Panel for better layout
	var list_panel := PanelContainer.new()
	list_panel.name = "MapListPanel"
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.custom_minimum_size = Vector2(0, 200)  # Minimum height

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.22, 0.35)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	list_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(list_panel)

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.name = "MapListScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)

	_map_list_container = VBoxContainer.new()
	_map_list_container.name = "MapListContainer"
	_map_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_list_container.add_theme_constant_override("separation", 12)
	scroll.add_child(_map_list_container)

	# Loading label
	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.text = "Loading maps..."
	_loading_label.add_theme_font_size_override("font_size", 16)
	_loading_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_list_container.add_child(_loading_label)


func _create_back_button(parent: Control) -> void:
	"""Create back button"""
	var button_row := HBoxContainer.new()
	button_row.name = "BackButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(button_row)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back to World"
	back_btn.custom_minimum_size = Vector2(180, 45)
	back_btn.pressed.connect(_on_back_pressed)

	# Style the back button
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.2, 0.35)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.35, 0.5)
	back_btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.35, 0.28, 0.45)
	back_btn.add_theme_stylebox_override("hover", hover_style)

	button_row.add_child(back_btn)


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = _get_system_registry()
	if not registry:
		return

	_data_sync = registry.get_system("PvPTerritoryDataSync")
	if _data_sync:
		_data_sync.maps_fetched.connect(_on_maps_fetched)
		_data_sync.map_joined.connect(_on_map_joined)
		_data_sync.map_created.connect(_on_map_created)


# ==============================================================================
# MAP FETCHING
# ==============================================================================

func _fetch_maps() -> void:
	"""Fetch available maps from Firebase"""
	_is_loading = true
	if is_instance_valid(_loading_label):
		_loading_label.visible = true
		_loading_label.text = "Loading maps..."

	if _data_sync:
		_data_sync.fetch_available_maps()
	else:
		# Mock data for offline
		_on_maps_fetched(_generate_mock_maps())


func _generate_mock_maps() -> Array:
	"""Generate mock maps for testing"""
	return [
		{
			"map_id": "mock_1",
			"player_count": 3,
			"max_players": 8,
			"next_reset": Time.get_unix_time_from_system() + 86400 * 5,
			"created_at": Time.get_unix_time_from_system() - 86400 * 2
		},
		{
			"map_id": "mock_2",
			"player_count": 7,
			"max_players": 8,
			"next_reset": Time.get_unix_time_from_system() + 86400 * 3,
			"created_at": Time.get_unix_time_from_system() - 86400 * 4
		}
	]


func _on_maps_fetched(maps: Array) -> void:
	"""Handle maps data received"""
	_is_loading = false
	_available_maps = maps
	_update_map_list()


func _update_map_list() -> void:
	"""Update the map list display"""
	# Clear existing entries (but keep loading label)
	for child in _map_list_container.get_children():
		if child != _loading_label:
			child.queue_free()

	# Hide loading label when updating list
	if is_instance_valid(_loading_label):
		_loading_label.visible = false

	if _available_maps.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No maps available. Create a new one!"
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_map_list_container.add_child(empty_label)
		return

	# Add map cards
	for map_data: Dictionary in _available_maps:
		var card := _create_map_card(map_data)
		_map_list_container.add_child(card)


func _create_map_card(map_data: Dictionary) -> Control:
	"""Create a map card for the list"""
	var card := Panel.new()
	card.name = "MapCard_%s" % map_data.get("map_id", "unknown")
	card.custom_minimum_size = Vector2(0, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4)
	card.add_theme_stylebox_override("panel", style)

	# Content container
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	card.add_child(content)

	# Map info section
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(info)

	# Map ID
	var id_label := Label.new()
	id_label.text = "Map: %s" % map_data.get("map_id", "Unknown")
	id_label.add_theme_font_size_override("font_size", 16)
	info.add_child(id_label)

	# Player count
	var player_count: int = map_data.get("player_count", 0)
	var max_players: int = map_data.get("max_players", 8)
	var players_label := Label.new()
	players_label.text = "Players: %d / %d" % [player_count, max_players]
	players_label.add_theme_font_size_override("font_size", 12)
	if player_count >= max_players:
		players_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	else:
		players_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	info.add_child(players_label)

	# Reset timer
	var next_reset: int = map_data.get("next_reset", 0)
	var reset_text := _format_reset_time(next_reset)
	var reset_label := Label.new()
	reset_label.text = "Resets in: %s" % reset_text
	reset_label.add_theme_font_size_override("font_size", 11)
	reset_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info.add_child(reset_label)

	# Join button
	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.custom_minimum_size = Vector2(80, 40)
	join_btn.disabled = player_count >= max_players
	join_btn.pressed.connect(_on_join_map_pressed.bind(map_data.get("map_id", "")))
	content.add_child(join_btn)

	return card


func _format_reset_time(timestamp: int) -> String:
	"""Format reset time as human readable string"""
	var now := int(Time.get_unix_time_from_system())
	var remaining := timestamp - now

	if remaining <= 0:
		return "Soon"

	var days := remaining / 86400
	var hours := (remaining % 86400) / 3600

	if days > 0:
		return "%dd %dh" % [days, hours]
	else:
		var minutes := (remaining % 3600) / 60
		return "%dh %dm" % [hours, minutes]


# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_quick_join_pressed() -> void:
	"""Quick join the first available map"""
	if _available_maps.is_empty():
		# Create new map instead
		_on_create_map_pressed()
		return

	# Find map with space
	for map_data: Dictionary in _available_maps:
		var player_count: int = map_data.get("player_count", 0)
		var max_players: int = map_data.get("max_players", 8)
		if player_count < max_players:
			_join_map(map_data.get("map_id", ""))
			return

	# All full, create new
	_on_create_map_pressed()


func _on_create_map_pressed() -> void:
	"""Create a new PvP map"""
	_is_loading = true
	if is_instance_valid(_loading_label):
		_loading_label.visible = true
		_loading_label.text = "Creating map..."

	if _data_sync:
		_data_sync.create_new_map()
	else:
		# Mock creation
		var mock_id := "mock_%d" % Time.get_unix_time_from_system()
		_on_map_created(mock_id, true)


func _on_join_map_pressed(map_id: String) -> void:
	"""Join a specific map"""
	_join_map(map_id)


func _join_map(map_id: String) -> void:
	"""Join a map by ID"""
	_is_loading = true
	if is_instance_valid(_loading_label):
		_loading_label.visible = true
		_loading_label.text = "Joining map..."

	if _data_sync:
		_data_sync.join_map(map_id)
	else:
		# Mock join
		var mock_data := PvPMapGenerator.generate_initial_map()
		mock_data["map_id"] = map_id
		_on_map_joined(mock_data, true)


func _on_map_created(map_id: String, success: bool) -> void:
	"""Handle map creation result"""
	_is_loading = false

	if success:
		# Join the newly created map
		_join_map(map_id)
	else:
		if is_instance_valid(_loading_label):
			_loading_label.text = "Failed to create map"


func _on_map_joined(map_data: Dictionary, success: bool) -> void:
	"""Handle map join result"""
	_is_loading = false

	if not success:
		if is_instance_valid(_loading_label):
			_loading_label.text = map_data.get("error", "Failed to join map")
		return

	# Navigate to territory screen
	var registry = _get_system_registry()
	if registry:
		var screen_manager = registry.get_system("ScreenManager")
		if screen_manager:
			# Store map data for the territory screen
			screen_manager.set_meta("pvp_map_data", map_data)
			screen_manager.change_screen("pvp_territory")


func _on_back_pressed() -> void:
	"""Return to world view"""
	var registry = _get_system_registry()
	if registry:
		var screen_manager = registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.change_screen("world_view")


# ==============================================================================
# HELPERS
# ==============================================================================

func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null
