# scripts/ui/pvp_territory/PvPSignupScreen.gd
# UI screen for 4-player PvP territory matchmaking queue
extends Control
class_name PvPSignupScreen

"""
PvPSignupScreen.gd - Matchmaking queue UI for 4-player PvP territory
RULE 2: Single responsibility - ONLY displays queue state and handles join/leave
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal back_pressed
signal match_started(map_id: String, spawn_index: int)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PLAYER_CARD_SIZE := Vector2(140, 100)
const REQUIRED_PLAYERS := 4

# Colors - matching UI_DESIGN_PATTERNS.md
const COLOR_BG := Color(0.08, 0.06, 0.12, 1.0)
const COLOR_PANEL := Color(0.12, 0.1, 0.16, 0.95)
const COLOR_BORDER := Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER := Color(0.8, 0.8, 0.9)
const COLOR_TEXT := Color(0.7, 0.7, 0.8)
const COLOR_MUTED := Color(0.5, 0.5, 0.55)
const COLOR_ACCENT := Color(0.4, 0.6, 0.9)
const COLOR_SUCCESS := Color(0.5, 0.8, 0.5)
const COLOR_WARNING := Color(0.6, 0.4, 0.4)

const PLAYER_COLORS := [
	Color(0.3, 0.5, 0.9),   # Blue
	Color(0.9, 0.3, 0.3),   # Red
	Color(0.3, 0.8, 0.4),   # Green
	Color(0.9, 0.8, 0.3)    # Yellow
]

# ==============================================================================
# UI REFERENCES
# ==============================================================================
var _main_container: VBoxContainer = null
var _center_panel: PanelContainer = null
var _title_label: Label = null
var _status_label: Label = null
var _player_count_label: Label = null
var _timer_label: Label = null
var _players_container: HBoxContainer = null
var _player_cards: Array[Control] = []
var _buttons_container: HBoxContainer = null
var _cancel_button: Button = null
var _join_button: Button = null
var _view_map_button: Button = null
var _test_button: Button = null
var _autofill_button: Button = null

# ==============================================================================
# STATE
# ==============================================================================
var _signup_manager: Variant = null
var _data_sync: Variant = null
var _is_in_queue: bool = false
var _update_timer: float = 0.0
var _active_map_id: String = ""
var _current_queue_players: Array = []  # Track players currently in queue

# ==============================================================================
# SYSTEM HELPER
# ==============================================================================

func _get_system_registry() -> Variant:
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_setup_fullscreen()
	_build_ui()
	_init_systems()
	_setup_unified_header()
	_check_active_match()
	_update_ui_state()


func _setup_fullscreen() -> void:
	"""Ensure screen fills the viewport properly"""
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	set_size(viewport_size)
	position = Vector2.ZERO


func _setup_unified_header() -> void:
	"""Configure header via MainUIOverlay"""
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()


func _on_visibility_changed() -> void:
	if visible:
		_update_header_for_screen()
		# Refresh Firebase connection in case sign-in completed after initial load
		if _signup_manager and _signup_manager.has_method("refresh_firebase_connection"):
			_signup_manager.refresh_firebase_connection()
		_check_active_match()
		_update_ui_state()


func _update_header_for_screen() -> void:
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("PVP TERRITORY")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)


func _process(delta: float) -> void:
	if not _is_in_queue:
		return

	_update_timer += delta
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_update_timer_display()


func _init_systems() -> void:
	var registry = _get_system_registry()
	if not registry:
		return

	_signup_manager = registry.get_system("PvPSignupManager")
	_data_sync = registry.get_system("PvPTerritoryDataSync")

	if _signup_manager:
		if not _signup_manager.queue_joined.is_connected(_on_queue_joined):
			_signup_manager.queue_joined.connect(_on_queue_joined)
		if not _signup_manager.queue_left.is_connected(_on_queue_left):
			_signup_manager.queue_left.connect(_on_queue_left)
		if not _signup_manager.queue_updated.is_connected(_on_queue_updated):
			_signup_manager.queue_updated.connect(_on_queue_updated)
		if not _signup_manager.match_found.is_connected(_on_match_found):
			_signup_manager.match_found.connect(_on_match_found)
		if not _signup_manager.queue_error.is_connected(_on_queue_error):
			_signup_manager.queue_error.connect(_on_queue_error)


func _check_active_match() -> void:
	"""Check if player is already in an active PvP match or queue"""
	# First check in-memory state
	if _data_sync and _data_sync.has_method("get_current_map_id"):
		_active_map_id = _data_sync.get_current_map_id()
		if not _active_map_id.is_empty():
			print("PvPSignupScreen: Found active map (in memory): %s" % _active_map_id)
			return

	# Always check Firebase for queue status and active match
	# This also verifies saved map IDs are still valid
	_check_firebase_queue_status()


func _check_firebase_queue_status() -> void:
	"""Query Firebase to find if player is in queue or active match"""
	print("PvPSignupScreen: _check_firebase_queue_status called")
	var registry := SystemRegistry.get_instance()
	if not registry:
		print("PvPSignupScreen: No registry")
		return

	var firebase_integration := registry.get_system("FirebaseIntegration")
	if not firebase_integration:
		print("PvPSignupScreen: No firebase_integration")
		return

	var firestore: Variant = firebase_integration.get_firestore()
	var user_id: String = firebase_integration.get_user_id()
	print("PvPSignupScreen: firestore=%s, user_id=%s" % [firestore != null, user_id])
	if not firestore or user_id.is_empty():
		print("PvPSignupScreen: Firestore or user_id not ready, skipping")
		return

	# First, check pvp_realtime_maps for active matches where we're a player
	var found_active_map: bool = await _check_active_maps_in_firebase(firestore, user_id)
	if found_active_map:
		_update_ui_state()
		return

	# Check queue status
	var queue_ref: Variant = firestore.collection("pvp_queues")
	if not queue_ref:
		return

	var doc: Variant = await queue_ref.get_doc("4player_queue")
	if doc == null or not doc is FirestoreDocument:
		return

	var data: Dictionary = _extract_doc_data(doc)
	var status: String = str(data.get("status", ""))
	var map_id: String = str(data.get("map_id", ""))
	var players_raw: Variant = data.get("players", [])
	var players: Array = players_raw if players_raw is Array else []

	# Check if we're in the players list
	var is_in_queue: bool = false
	for player: Variant in players:
		if player is Dictionary and player.get("uid", "") == user_id:
			is_in_queue = true
			break

	if is_in_queue:
		if status == "starting" and not map_id.is_empty():
			# Match already started, set active map
			_active_map_id = map_id
			print("PvPSignupScreen: Found active match in Firebase: %s" % map_id)
		else:
			# Still in queue, restore queue state
			_is_in_queue = true
			print("PvPSignupScreen: Restored queue state - %d players" % players.size())
			# Update UI with current queue state
			_on_queue_updated(players.size(), players)
			# Start polling via signup manager
			if _signup_manager and _signup_manager.has_method("restore_queue_state"):
				_signup_manager.restore_queue_state()

		_update_ui_state()


func _check_active_maps_in_firebase(firestore: Variant, user_id: String) -> bool:
	"""Check pvp_realtime_maps for active matches where current user is a player"""
	print("PvPSignupScreen: _check_active_maps_in_firebase called, user_id=%s" % user_id)

	var maps_ref: Variant = firestore.collection("pvp_realtime_maps")
	if not maps_ref:
		print("PvPSignupScreen: Could not get pvp_realtime_maps collection")
		return false

	# We need to fetch maps and check for the user's participation
	# Since Firestore queries by nested array fields are complex, we'll check recent maps
	# The user's active_pvp_map_id should have been saved, but as a fallback we query

	# Try to get saved map ID first and verify it still exists/is active
	var registry: Variant = _get_system_registry()
	if registry:
		var save_manager = registry.get_system("SaveManager")
		if save_manager and save_manager.has_method("get_player_value"):
			var saved_map_id: String = save_manager.get_player_value("active_pvp_map_id", "")
			print("PvPSignupScreen: Saved map ID from SaveManager: '%s'" % saved_map_id)
			if not saved_map_id.is_empty():
				# Verify this map is still active
				print("PvPSignupScreen: Fetching map doc: %s" % saved_map_id)
				var map_doc: Variant = await maps_ref.get_doc(saved_map_id)
				print("PvPSignupScreen: map_doc result: %s" % [map_doc != null])
				if map_doc and map_doc is FirestoreDocument:
					var map_data: Dictionary = _extract_doc_data(map_doc)
					var map_status: String = str(map_data.get("status", ""))
					print("PvPSignupScreen: Map status: %s" % map_status)
					if map_status == "active":
						# Check if user is actually in this map
						var players_raw: Variant = map_data.get("players", [])
						var players: Array = players_raw if players_raw is Array else []
						print("PvPSignupScreen: Map has %d players" % players.size())
						for player: Variant in players:
							if player is Dictionary:
								var player_uid: String = str(player.get("uid", player.get("player_uid", "")))
								print("PvPSignupScreen: Checking player uid: %s vs user_id: %s" % [player_uid, user_id])
								if player_uid == user_id:
									_active_map_id = saved_map_id
									print("PvPSignupScreen: Found active map from save: %s" % saved_map_id)
									return true
					elif map_status == "ended":
						# Clear stale map ID
						save_manager.set_player_value("active_pvp_map_id", "")
						print("PvPSignupScreen: Cleared ended map ID: %s" % saved_map_id)
				else:
					print("PvPSignupScreen: Map doc not found or invalid")
		else:
			print("PvPSignupScreen: SaveManager not available")
	else:
		print("PvPSignupScreen: Registry not available")

	# If no saved map ID, we'd need to do a more complex Firestore query
	# For now, rely on the saved map ID approach above
	print("PvPSignupScreen: No active map found in Firebase")
	return false


func _extract_doc_data(doc: FirestoreDocument) -> Dictionary:
	"""Extract plain Dictionary from FirestoreDocument"""
	var result: Dictionary = {}
	if not doc.has_method("keys") or not doc.has_method("get_value"):
		return result
	for key in doc.keys():
		result[key] = doc.get_value(key)
	return result


# ==============================================================================
# UI BUILDING
# ==============================================================================

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main vertical container with margins
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 80)  # Below header
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	_main_container = VBoxContainer.new()
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_container.add_theme_constant_override("separation", 20)
	margin.add_child(_main_container)

	# Center the content
	var center_container := CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_container.add_child(center_container)

	# Main panel
	_center_panel = _create_styled_panel()
	_center_panel.custom_minimum_size = Vector2(600, 450)
	center_container.add_child(_center_panel)

	var panel_content := VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 25)
	_center_panel.add_child(panel_content)

	# Title
	_title_label = Label.new()
	_title_label.text = "4-PLAYER PVP TERRITORY"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", COLOR_HEADER)
	panel_content.add_child(_title_label)

	# Status section
	var status_section := VBoxContainer.new()
	status_section.add_theme_constant_override("separation", 8)
	panel_content.add_child(status_section)

	_status_label = Label.new()
	_status_label.text = "Click JOIN to find a match"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT)
	status_section.add_child(_status_label)

	_player_count_label = Label.new()
	_player_count_label.text = "Players: 0/4"
	_player_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_count_label.add_theme_font_size_override("font_size", 22)
	_player_count_label.add_theme_color_override("font_color", COLOR_ACCENT)
	status_section.add_child(_player_count_label)

	_timer_label = Label.new()
	_timer_label.text = ""
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 13)
	_timer_label.add_theme_color_override("font_color", COLOR_MUTED)
	status_section.add_child(_timer_label)

	# Players container
	_players_container = HBoxContainer.new()
	_players_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_players_container.add_theme_constant_override("separation", 15)
	panel_content.add_child(_players_container)

	# Create 4 player card slots
	for i in range(REQUIRED_PLAYERS):
		var card := _create_player_card(i)
		_player_cards.append(card)
		_players_container.add_child(card)

	# Buttons container
	_buttons_container = HBoxContainer.new()
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_container.add_theme_constant_override("separation", 20)
	panel_content.add_child(_buttons_container)

	# Join button
	_join_button = _create_styled_button("JOIN QUEUE", true)
	_join_button.pressed.connect(_on_join_pressed)
	_buttons_container.add_child(_join_button)

	# Cancel button
	_cancel_button = _create_styled_button("CANCEL", false)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_cancel_button.visible = false
	_buttons_container.add_child(_cancel_button)

	# View Map button
	_view_map_button = _create_styled_button("VIEW MAP", true)
	_view_map_button.pressed.connect(_on_view_map_pressed)
	_view_map_button.visible = false
	_buttons_container.add_child(_view_map_button)

	# Test Match button (for offline testing) - orange colored
	_test_button = Button.new()
	_test_button.text = "TEST MATCH"
	_test_button.custom_minimum_size = Vector2(150, 45)
	_test_button.add_theme_font_size_override("font_size", 16)
	var test_style := StyleBoxFlat.new()
	test_style.bg_color = Color(0.6, 0.4, 0.15, 0.9)
	test_style.border_color = Color(0.8, 0.6, 0.2, 0.8)
	test_style.set_border_width_all(1)
	test_style.set_corner_radius_all(6)
	_test_button.add_theme_stylebox_override("normal", test_style)
	var test_hover := test_style.duplicate() as StyleBoxFlat
	test_hover.bg_color = test_style.bg_color.lightened(0.15)
	_test_button.add_theme_stylebox_override("hover", test_hover)
	_test_button.pressed.connect(_on_test_pressed)
	_buttons_container.add_child(_test_button)

	# Autofill button (fills remaining slots with bots) - purple colored
	_autofill_button = Button.new()
	_autofill_button.text = "AUTOFILL & START"
	_autofill_button.custom_minimum_size = Vector2(170, 45)
	_autofill_button.add_theme_font_size_override("font_size", 16)
	var autofill_style := StyleBoxFlat.new()
	autofill_style.bg_color = Color(0.5, 0.3, 0.6, 0.9)
	autofill_style.border_color = Color(0.7, 0.5, 0.8, 0.8)
	autofill_style.set_border_width_all(1)
	autofill_style.set_corner_radius_all(6)
	_autofill_button.add_theme_stylebox_override("normal", autofill_style)
	var autofill_hover := autofill_style.duplicate() as StyleBoxFlat
	autofill_hover.bg_color = autofill_style.bg_color.lightened(0.15)
	_autofill_button.add_theme_stylebox_override("hover", autofill_hover)
	_autofill_button.pressed.connect(_on_autofill_pressed)
	_autofill_button.visible = false  # Only visible when in queue with < 4 players
	_buttons_container.add_child(_autofill_button)


func _create_styled_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_styled_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 45)
	button.add_theme_font_size_override("font_size", 16)

	var style_normal := StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = style_normal.bg_color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", style_pressed)

	return button


func _create_player_card(index: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = PLAYER_CARD_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.9)
	style.border_color = PLAYER_COLORS[index].darkened(0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Player number
	var num_label := Label.new()
	num_label.name = "NumberLabel"
	num_label.text = "Player %d" % (index + 1)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.add_theme_font_size_override("font_size", 11)
	num_label.add_theme_color_override("font_color", PLAYER_COLORS[index])
	vbox.add_child(num_label)

	# Player name
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "..."
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(name_label)

	# Status
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Waiting"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(status_label)

	return card


# ==============================================================================
# UI UPDATES
# ==============================================================================

func _update_ui_state() -> void:
	var has_active_match := not _active_map_id.is_empty()
	var has_players_in_queue := _is_in_queue and _current_queue_players.size() > 0 and _current_queue_players.size() < REQUIRED_PLAYERS

	# Show View Map button if in active match
	_view_map_button.visible = has_active_match
	_join_button.visible = not has_active_match and not _is_in_queue
	_cancel_button.visible = _is_in_queue
	_test_button.visible = not has_active_match and not _is_in_queue
	# Show autofill when in queue but not full
	_autofill_button.visible = has_players_in_queue

	if has_active_match:
		_status_label.text = "You are in an active match!"
		_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_player_count_label.text = "Map: %s" % _active_map_id
		_timer_label.text = "Click VIEW MAP to continue playing"
	elif _is_in_queue:
		_status_label.text = "Finding match..."
		_status_label.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		_status_label.text = "Click JOIN to find a match"
		_status_label.add_theme_color_override("font_color", COLOR_TEXT)
		_player_count_label.text = "Players: 0/4"
		_timer_label.text = ""
		_current_queue_players.clear()
		for i in range(_player_cards.size()):
			_update_player_card(i, null)


func _update_player_card(index: int, player_data: Variant) -> void:
	if index >= _player_cards.size():
		return

	var card: Control = _player_cards[index]
	var vbox: VBoxContainer = card.get_child(0) as VBoxContainer
	if not vbox:
		return

	var name_label: Label = vbox.get_node_or_null("NameLabel") as Label
	var status_label: Label = vbox.get_node_or_null("StatusLabel") as Label

	if player_data and player_data is Dictionary:
		var display_name: String = player_data.get("display_name", "Unknown")
		if name_label:
			name_label.text = display_name
			name_label.add_theme_color_override("font_color", PLAYER_COLORS[index])
		if status_label:
			status_label.text = "Ready"
			status_label.add_theme_color_override("font_color", COLOR_SUCCESS)

		# Update card border
		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = PLAYER_COLORS[index]
		card.add_theme_stylebox_override("panel", style)
	else:
		if name_label:
			name_label.text = "..."
			name_label.add_theme_color_override("font_color", COLOR_MUTED)
		if status_label:
			status_label.text = "Waiting"
			status_label.add_theme_color_override("font_color", COLOR_MUTED)

		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = PLAYER_COLORS[index].darkened(0.5)
		card.add_theme_stylebox_override("panel", style)


func _update_timer_display() -> void:
	if not _signup_manager or not _is_in_queue:
		return

	var queue_time: int = _signup_manager.get_queue_time()
	var minutes: int = queue_time / 60
	var seconds: int = queue_time % 60
	_timer_label.text = "Time in queue: %d:%02d" % [minutes, seconds]


# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_join_pressed() -> void:
	if _signup_manager:
		_signup_manager.join_queue()


func _on_cancel_pressed() -> void:
	if _signup_manager:
		_signup_manager.leave_queue()


func _on_view_map_pressed() -> void:
	_navigate_to_territory()


func _on_test_pressed() -> void:
	"""Start a test match with simulated players"""
	if _signup_manager and _signup_manager.has_method("start_test_match"):
		_signup_manager.start_test_match()


func _on_autofill_pressed() -> void:
	"""Autofill remaining slots with bots and start match"""
	if _signup_manager and _signup_manager.has_method("autofill_and_start"):
		_signup_manager.autofill_and_start(_current_queue_players)


func _on_back_pressed() -> void:
	if _is_in_queue and _signup_manager:
		_signup_manager.leave_queue()
	back_pressed.emit()


func _on_queue_joined() -> void:
	_is_in_queue = true
	_update_ui_state()


func _on_queue_left() -> void:
	_is_in_queue = false
	_update_ui_state()


func _on_queue_updated(player_count: int, players: Array) -> void:
	_current_queue_players = players.duplicate()
	_player_count_label.text = "Players: %d/%d" % [player_count, REQUIRED_PLAYERS]

	if player_count >= REQUIRED_PLAYERS:
		_player_count_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		_status_label.text = "Match found! Starting..."
		_autofill_button.visible = false
	else:
		_player_count_label.add_theme_color_override("font_color", COLOR_ACCENT)
		# Show autofill button if at least 1 player is in queue
		_autofill_button.visible = player_count > 0

	for i in range(REQUIRED_PLAYERS):
		if i < players.size():
			_update_player_card(i, players[i])
		else:
			_update_player_card(i, null)


func _on_match_found(map_id: String, spawn_index: int, _players: Array) -> void:
	_is_in_queue = false
	_active_map_id = map_id
	_status_label.text = "Match starting!"
	_status_label.add_theme_color_override("font_color", COLOR_SUCCESS)

	# Persist active map to SaveManager IMMEDIATELY (before any async operations)
	var registry = _get_system_registry()
	if registry:
		var save_manager = registry.get_system("SaveManager")
		if save_manager:
			if save_manager.has_method("set_player_value"):
				save_manager.set_player_value("active_pvp_map_id", map_id)
				print("PvPSignupScreen: Saved active map ID: %s" % map_id)
			# Force save to disk if supported
			if save_manager.has_method("save_game"):
				save_manager.save_game()
				print("PvPSignupScreen: Force saved to disk")
			elif save_manager.has_method("save"):
				save_manager.save()

		# Store match data for the territory screen
		var screen_manager = registry.get_system("ScreenManager")
		if screen_manager:
			screen_manager.set_meta("pvp_map_id", map_id)
			screen_manager.set_meta("pvp_spawn_index", spawn_index)

	# Brief delay before transition
	await get_tree().create_timer(1.0).timeout

	match_started.emit(map_id, spawn_index)
	_navigate_to_territory()


func _on_queue_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", COLOR_WARNING)

	await get_tree().create_timer(3.0).timeout
	_update_ui_state()


# ==============================================================================
# NAVIGATION
# ==============================================================================

func _navigate_to_territory() -> void:
	var registry = _get_system_registry()
	if not registry:
		return

	var screen_manager = registry.get_system("ScreenManager")
	if screen_manager:
		if not _active_map_id.is_empty():
			screen_manager.set_meta("pvp_map_id", _active_map_id)
		screen_manager.change_screen("pvp_territory")
