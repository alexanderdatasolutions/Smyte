# scripts/ui/WorldView.gd - Main hub screen
extends Control

# Helper to get SystemRegistry without parse-time dependency
func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

@onready var summon_button = $ContentContainer/ButtonGrid/SummonButton
@onready var collection_button = $ContentContainer/ButtonGrid/CollectionButton
@onready var territory_button = $ContentContainer/ButtonGrid/TerritoryButton
@onready var sacrifice_button = $ContentContainer/ButtonGrid/SacrificeButton
@onready var dungeon_button = $ContentContainer/ButtonGrid/DungeonButton
@onready var equipment_button = $ContentContainer/ButtonGrid/EquipmentButton
@onready var shop_button = $ContentContainer/ButtonGrid/ShopButton
@onready var tower_button = $ContentContainer/ButtonGrid/TowerButton
@onready var arena_button = $ContentContainer/ButtonGrid/ArenaButton
@onready var pvp_territory_button = $ContentContainer/ButtonGrid/PvPTerritoryButton
@onready var leaderboard_button = $ContentContainer/ButtonGrid/LeaderboardButton

# Feature unlock tracking (MYTHOS ARCHITECTURE)
var feature_buttons: Dictionary = {}

# Production summary widget
const ProductionSummaryWidgetScript = preload("res://scripts/ui/components/ProductionSummaryWidget.gd")
var _production_widget = null

# Tutorial highlight overlay
const TutorialHighlightOverlayScript = preload("res://scripts/ui/components/TutorialHighlightOverlay.gd")
var _highlight_overlay: Control = null

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _ready():
	# Ensure this control fills the viewport (needed when parent is Node2D)
	_setup_fullscreen()

	# Style all buttons first
	_style_buttons()

	# Create production summary widget
	_create_production_widget()

	# Connect building buttons
	if summon_button:
		summon_button.pressed.connect(_on_summon_building_pressed)
	if collection_button:
		collection_button.pressed.connect(_on_collection_building_pressed)
	if territory_button:
		territory_button.pressed.connect(_on_territory_building_pressed)
	if sacrifice_button:
		sacrifice_button.pressed.connect(_on_sacrifice_building_pressed)
	if dungeon_button:
		dungeon_button.pressed.connect(_on_dungeon_building_pressed)
	if equipment_button:
		equipment_button.pressed.connect(_on_equipment_building_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_building_pressed)
		shop_button.visible = false  # Hide shop for now
	if tower_button:
		tower_button.pressed.connect(_on_tower_building_pressed)
	if arena_button:
		arena_button.pressed.connect(_on_arena_building_pressed)
	if pvp_territory_button:
		pvp_territory_button.pressed.connect(_on_pvp_territory_building_pressed)
	if leaderboard_button:
		leaderboard_button.pressed.connect(_on_leaderboard_building_pressed)

	# Setup feature tracking (MYTHOS ARCHITECTURE)
	_setup_feature_buttons()

	# Connect to progression system for feature unlocks (RULE 5: Use SystemRegistry)
	_connect_to_systems()

	# Update button visibility based on current level
	call_deferred("_update_button_visibility")

	# NOTE: Tutorial trigger moved to _on_game_loaded() so it fires AFTER sign-in

	# Setup unified header for main menu
	_setup_unified_header()

func _setup_unified_header():
	"""Configure header for main menu - no back button, no title"""
	# Connect to visibility changes
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)

	# Set up header immediately if visible
	if visible:
		_update_header_for_main_menu()

func _on_visibility_changed():
	"""Update header when main menu becomes visible"""
	if visible:
		_update_header_for_main_menu()
		# Check for pending tutorial highlights when returning to WorldView
		call_deferred("_check_pending_tutorial_highlight")

func _update_header_for_main_menu():
	"""Apply main menu header settings - show SMYTE title, no back button"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("SMYTE")
		main_ui.show_header_back_button(false)
		main_ui.disconnect_header_back_button()

func _style_buttons():
	"""Apply dark fantasy styling to navigation buttons"""
	var buttons_data = [
		{"button": summon_button, "color": Color(0.6, 0.5, 0.2)},      # Gold - premium feel
		{"button": collection_button, "color": Color(0.4, 0.5, 0.6)},  # Steel blue
		{"button": territory_button, "color": Color(0.5, 0.35, 0.2)},  # Bronze/copper
		{"button": sacrifice_button, "color": Color(0.5, 0.2, 0.25)},  # Dark red
		{"button": dungeon_button, "color": Color(0.3, 0.4, 0.35)},    # Forest green
		{"button": equipment_button, "color": Color(0.45, 0.4, 0.5)},  # Purple/steel
		{"button": shop_button, "color": Color(0.3, 0.6, 0.7)},        # Crystal blue - shop
		{"button": tower_button, "color": Color(0.7, 0.4, 0.2)},  # Orange/fire - tower
		{"button": arena_button, "color": Color(0.6, 0.2, 0.2)},   # Red - PvP arena
		{"button": pvp_territory_button, "color": Color(0.7, 0.3, 0.5)},  # Magenta - PvP territory
		{"button": leaderboard_button, "color": Color(0.3, 0.5, 0.7)}   # Blue - leaderboard
	]

	for data in buttons_data:
		var button = data["button"]
		var accent = data["color"]
		if not button:
			continue

		# Normal state - dark with colored accent border
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.12, 0.1, 0.15, 0.95)
		style_normal.border_color = accent * 0.7
		style_normal.set_border_width_all(2)
		style_normal.set_corner_radius_all(8)
		style_normal.shadow_color = Color(0, 0, 0, 0.5)
		style_normal.shadow_size = 4
		style_normal.shadow_offset = Vector2(2, 2)

		# Hover state - brighter, glow effect
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
		style_hover.border_color = accent
		style_hover.set_border_width_all(2)
		style_hover.set_corner_radius_all(8)
		style_hover.shadow_color = accent * 0.5
		style_hover.shadow_size = 8
		style_hover.shadow_offset = Vector2(0, 0)

		# Pressed state - inset look
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.08, 0.06, 0.1, 1.0)
		style_pressed.border_color = accent * 0.5
		style_pressed.set_border_width_all(2)
		style_pressed.set_corner_radius_all(8)

		# Focus state (keyboard nav)
		var style_focus = StyleBoxFlat.new()
		style_focus.bg_color = Color(0.15, 0.12, 0.18, 0.98)
		style_focus.border_color = Color(0.9, 0.8, 0.5)
		style_focus.set_border_width_all(3)
		style_focus.set_corner_radius_all(8)

		# Apply styles
		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_stylebox_override("focus", style_focus)

		# Typography
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
		button.add_theme_color_override("font_pressed_color", Color(0.6, 0.55, 0.5))

func _setup_feature_buttons():
	"""Map feature names to their buttons (MYTHOS ARCHITECTURE)"""
	feature_buttons = {
		"territories": territory_button,      # Always available (level 1)
		"collection": collection_button,      # Always available (level 1)
		"summon": summon_button,             # Level 2
		"sacrifice": sacrifice_button,        # Level 3
		"territory_management": territory_button,  # Level 4 (enhanced)
		"equipment": equipment_button,        # Level 8
		"dungeons": dungeon_button,          # Level 10
		"shop": shop_button,                 # Always available
		"tower": tower_button,               # Infinite tower - always available
		"arena": arena_button,               # PvP Arena - Level 15
		"leaderboard": leaderboard_button    # Leaderboard - T3 unlock
	}

func _connect_to_systems():
	"""Connect to game systems through SystemRegistry - following RULE 5"""
	var system_registry = _get_system_registry()
	if not system_registry:
		push_warning("WorldView: SystemRegistry not available")
		return

	# Connect to FeatureUnlockManager for feature unlocks
	var feature_manager = system_registry.get_system("FeatureUnlockManager")
	if feature_manager and feature_manager.has_signal("feature_unlocked"):
		feature_manager.feature_unlocked.connect(_on_feature_unlocked)

	# Connect to AchievementManager for achievement unlocks
	var achievement_manager = system_registry.get_system("AchievementManager")
	if achievement_manager and achievement_manager.has_signal("achievement_completed"):
		achievement_manager.achievement_completed.connect(_on_achievement_completed)

	# Connect to EventBus game_loaded signal to refresh after cloud data loads
	var event_bus = system_registry.get_system("EventBus")
	if event_bus and event_bus.has_signal("game_loaded"):
		if not event_bus.game_loaded.is_connected(_on_game_loaded):
			event_bus.game_loaded.connect(_on_game_loaded)

func _on_game_loaded():
	"""Handle game loaded - refresh button visibility and check tutorial after sign-in"""
	print("WorldView: Game loaded signal received, refreshing button visibility")
	_update_button_visibility()

	# Check if we need to start the first-time tutorial (fires AFTER sign-in completes)
	call_deferred("_check_tutorial_trigger")

func _on_feature_unlocked(_feature_name: String, _feature_data: Dictionary):
	"""Handle feature unlock"""
	_update_button_visibility()

func _on_achievement_completed(achievement_id: String, _achievement_data: Dictionary):
	"""Handle achievement completion - may unlock features"""
	print("WorldView: Achievement completed received: %s" % achievement_id)
	_update_button_visibility()
	# Note: Free skin popup is now handled by MainUIOverlay (always visible)

func _update_button_visibility():
	"""Update button visibility based on unlocked features"""
	var system_registry = _get_system_registry()
	if not system_registry:
		print("WorldView: SystemRegistry not available for button visibility")
		return

	var feature_manager = system_registry.get_system("FeatureUnlockManager")
	if not feature_manager:
		print("WorldView: FeatureUnlockManager not available")
		return

	# Debug: Check what features are unlocked
	var _dbg_territory = feature_manager.is_feature_unlocked("territory")
	var _dbg_sacrifice = feature_manager.is_feature_unlocked("sacrifice")
	print("WorldView: Feature check - territory=%s, sacrifice=%s" % [_dbg_territory, _dbg_sacrifice])

	# Summon and Collection are always available
	if summon_button:
		summon_button.visible = true
	if collection_button:
		collection_button.visible = true

	# Territory - unlocked by first_summon achievement
	if territory_button:
		var territory_unlocked = feature_manager and feature_manager.is_feature_unlocked("territory")
		territory_button.visible = territory_unlocked

	# Sacrifice - unlocked by first_territory achievement
	if sacrifice_button:
		var sacrifice_unlocked = feature_manager and feature_manager.is_feature_unlocked("sacrifice")
		sacrifice_button.visible = sacrifice_unlocked

	# Dungeon - unlocked by tier2_territory achievement
	if dungeon_button:
		var dungeon_unlocked = feature_manager and feature_manager.is_feature_unlocked("dungeon")
		dungeon_button.visible = dungeon_unlocked

	# Equipment - unlocked by tier2_territory achievement
	if equipment_button:
		var equipment_unlocked = feature_manager and feature_manager.is_feature_unlocked("equipment")
		equipment_button.visible = equipment_unlocked

	# Tower - unlocked by tier3_territory achievement
	if tower_button:
		var tower_unlocked = feature_manager and feature_manager.is_feature_unlocked("tower")
		tower_button.visible = tower_unlocked

	# PvP Territory - unlocked by tier4_territory achievement
	if pvp_territory_button:
		var pvp_unlocked = feature_manager and feature_manager.is_feature_unlocked("pvp")
		pvp_territory_button.visible = pvp_unlocked

	# Arena - unlocked by tier3_territory achievement
	if arena_button:
		var arena_unlocked = feature_manager and feature_manager.is_feature_unlocked("arena")
		arena_button.visible = arena_unlocked

	# Leaderboard - unlocked by tier3_territory achievement (same as arena/tower)
	if leaderboard_button:
		var leaderboard_unlocked = feature_manager and feature_manager.is_feature_unlocked("arena")
		leaderboard_button.visible = leaderboard_unlocked

	# Keep shop hidden for now
	if shop_button:
		shop_button.visible = false

func _navigate_to_screen(screen_name: String):
	"""Helper function to navigate to a screen"""
	var screen_manager = _get_system_registry().get_system("ScreenManager")
	if screen_manager:
		screen_manager.change_screen(screen_name)
	else:
		push_error("WorldView: ScreenManager not found")

func _on_summon_building_pressed():
	_emit_tutorial_action("summon_button_pressed")
	_navigate_to_screen("summon")

func _on_collection_building_pressed():
	_emit_tutorial_action("collection_button_pressed")
	_navigate_to_screen("collection")

func _on_territory_building_pressed():
	_emit_tutorial_action("territory_button_pressed")
	_navigate_to_screen("hex_territory")

func _on_sacrifice_building_pressed():
	_emit_tutorial_action("sacrifice_button_pressed")
	_navigate_to_screen("sacrifice")

func _on_dungeon_building_pressed():
	_emit_tutorial_action("dungeon_button_pressed")
	_navigate_to_screen("dungeon")

func _on_equipment_building_pressed():
	_emit_tutorial_action("equipment_button_pressed")
	_navigate_to_screen("equipment")

func _on_shop_building_pressed():
	_emit_tutorial_action("shop_button_pressed")
	_navigate_to_screen("shop")

func _on_tower_building_pressed():
	_emit_tutorial_action("tower_button_pressed")
	_navigate_to_screen("tower")

func _on_arena_building_pressed():
	_emit_tutorial_action("arena_button_pressed")
	_navigate_to_screen("arena")

func _on_pvp_territory_building_pressed():
	_emit_tutorial_action("pvp_territory_button_pressed")
	_navigate_to_screen("pvp_territory")

func _on_leaderboard_building_pressed():
	_emit_tutorial_action("leaderboard_button_pressed")
	_navigate_to_screen("leaderboard")

func _emit_tutorial_action(action_id: String) -> void:
	"""Emit a tutorial action via EventBus."""
	var system_registry = _get_system_registry()
	if not system_registry:
		return
	var event_bus: Node = system_registry.get_system("EventBus")
	if event_bus and event_bus.has_signal("tutorial_action_completed"):
		event_bus.tutorial_action_completed.emit(action_id)

# ==============================================================================
# PRODUCTION WIDGET
# ==============================================================================

func _create_production_widget() -> void:
	"""Create and add the production summary widget"""
	_production_widget = ProductionSummaryWidgetScript.new()
	_production_widget.name = "ProductionSummaryWidget"

	# Add it to ContentContainer, after the Spacer but before ButtonGrid
	var content_container = $ContentContainer
	if content_container:
		var spacer = content_container.get_node_or_null("Spacer")
		if spacer:
			var spacer_idx = spacer.get_index()
			content_container.add_child(_production_widget)
			content_container.move_child(_production_widget, spacer_idx + 1)
		else:
			content_container.add_child(_production_widget)

	# Connect to collection event
	_production_widget.resources_collected.connect(_on_resources_collected)

func _on_resources_collected(_total: Dictionary) -> void:
	"""Handle resources collected from widget"""
	# Resources are already awarded by ProductionSummaryWidget

# ==============================================================================
# TUTORIAL SYSTEM INTEGRATION (MYTHOS ARCHITECTURE)
# ==============================================================================

func _check_tutorial_trigger():
	"""Check if we need to trigger the first-time tutorial (MYTHOS ARCHITECTURE)"""
	var system_registry = _get_system_registry()
	if not system_registry:
		return

	var tutorial_orch: Node = system_registry.get_system("TutorialOrchestrator")
	if not tutorial_orch:
		return

	# Connect to tutorial orchestrator signals if not already connected
	_connect_tutorial_signals(tutorial_orch)

	# Check if we should show onboarding
	if tutorial_orch.should_show_onboarding():
		tutorial_orch.start_tutorial("new_user_welcome")

func _check_pending_tutorial_highlight() -> void:
	"""Check if there's a pending tutorial highlight for WorldView."""
	var system_registry = _get_system_registry()
	if not system_registry:
		return

	var tutorial_orch: Node = system_registry.get_system("TutorialOrchestrator")
	if not tutorial_orch or not tutorial_orch.is_tutorial_active():
		return

	# Connect signals if not already connected
	_connect_tutorial_signals(tutorial_orch)

	# Use the orchestrator's method to check and re-emit pending highlights
	tutorial_orch.check_pending_highlight_for_screen("worldview")

func _connect_tutorial_signals(tutorial_orch: Node) -> void:
	"""Connect to tutorial orchestrator signals for highlighting."""
	if not tutorial_orch.highlight_requested.is_connected(_on_highlight_requested):
		tutorial_orch.highlight_requested.connect(_on_highlight_requested)
	if not tutorial_orch.highlight_cleared.is_connected(_on_highlight_cleared):
		tutorial_orch.highlight_cleared.connect(_on_highlight_cleared)

func _on_highlight_requested(target_id: String, message: String, title: String, show_button: bool = true) -> void:
	"""Handle highlight request from tutorial orchestrator."""
	# Only show highlight if WorldView is visible
	if not visible:
		print("WorldView: _on_highlight_requested called but not visible, ignoring")
		return

	var target_button: Control = get_button_for_tutorial(target_id)
	if not target_button or not target_button.visible:
		# If button not found or not visible, advance tutorial to avoid getting stuck
		var system_registry = _get_system_registry()
		if system_registry:
			var tutorial_orch: Node = system_registry.get_system("TutorialOrchestrator")
			if tutorial_orch and tutorial_orch.is_tutorial_active():
				push_warning("WorldView: Tutorial target '%s' not found or not visible, advancing tutorial" % target_id)
				tutorial_orch.advance_tutorial()
		return

	# Create highlight overlay if needed
	if not _highlight_overlay or not is_instance_valid(_highlight_overlay):
		_highlight_overlay = TutorialHighlightOverlayScript.new()
		_highlight_overlay.name = "TutorialHighlight"
		# Add to a high z-index layer
		var main_ui: Node = get_node_or_null("/root/Main/MainUIOverlay")
		if main_ui and main_ui.has_method("add_to_tutorial_layer"):
			main_ui.add_to_tutorial_layer(_highlight_overlay)
		else:
			add_child(_highlight_overlay)

	# Connect overlay signals
	if not _highlight_overlay.target_clicked.is_connected(_on_highlight_target_clicked):
		_highlight_overlay.target_clicked.connect(_on_highlight_target_clicked)
	if not _highlight_overlay.continue_pressed.is_connected(_on_highlight_continue):
		_highlight_overlay.continue_pressed.connect(_on_highlight_continue)

	# Show the highlight with button option
	_highlight_overlay.highlight_target(target_button, message, title, "Got it!", true, show_button)

func _on_highlight_cleared() -> void:
	"""Handle highlight clear request."""
	if _highlight_overlay and is_instance_valid(_highlight_overlay):
		_highlight_overlay.clear_highlight()

func _on_highlight_target_clicked() -> void:
	"""Handle when user clicks the highlighted target."""
	# The button's own pressed handler will emit the tutorial action
	pass

func _on_highlight_continue() -> void:
	"""Handle when user clicks continue on highlight overlay."""
	var system_registry = _get_system_registry()
	if not system_registry:
		return
	var tutorial_orch: Node = system_registry.get_system("TutorialOrchestrator")
	if tutorial_orch:
		tutorial_orch.advance_tutorial()

func get_button_for_tutorial(button_id: String) -> Control:
	"""Get a button reference by tutorial target ID."""
	match button_id:
		"summon":
			return summon_button
		"collection":
			return collection_button
		"territory":
			return territory_button
		"sacrifice":
			return sacrifice_button
		"dungeon":
			return dungeon_button
		"equipment":
			return equipment_button
		"shop":
			return shop_button
		"tower":
			return tower_button
		"arena":
			return arena_button
		"pvp_territory":
			return pvp_territory_button
		"leaderboard":
			return leaderboard_button
	return null

# ==============================================================================
# SKIN SYSTEM
# ==============================================================================

func _show_free_skin_popup() -> void:
	"""Show the free skin selection popup when legendary_champion achievement is completed"""
	print("WorldView: _show_free_skin_popup called")
	var system_registry = _get_system_registry()
	if not system_registry:
		print("WorldView: No system registry!")
		return

	var skin_manager: Node = system_registry.get_system("SkinManager")
	if not skin_manager:
		print("WorldView: No skin manager!")
		return

	var pending_god_id: String = skin_manager.get_pending_free_skin_god()
	print("WorldView: Pending god ID = '%s'" % pending_god_id)
	if pending_god_id.is_empty():
		print("WorldView: No pending god ID, aborting popup")
		return

	# Create and show the popup
	print("WorldView: Creating FreeSkinPickPopup for god '%s'" % pending_god_id)
	var popup: FreeSkinPickPopup = FreeSkinPickPopup.new()
	add_child(popup)
	popup.show_for_god(pending_god_id)
