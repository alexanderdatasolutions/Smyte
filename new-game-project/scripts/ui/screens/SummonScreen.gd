# scripts/ui/SummonScreen.gd
# RULE 1: Coordinator pattern - delegates to specialized components
# Updated: Task 8 - SummonResultOverlay integration
extends Control

# Preload helper classes (prefixed to avoid class_name conflicts)
const _SummonButtonFactory = preload("res://scripts/ui/summon/SummonButtonFactory.gd")
const _SummonShowcaseClass = preload("res://scripts/ui/summon/SummonShowcase.gd")
const _SummonBannerCardClass = preload("res://scripts/ui/summon/SummonBannerCard.gd")
const _SummonAnimationClass = preload("res://scripts/ui/summon/SummonAnimation.gd")
const _SummonResultOverlayClass = preload("res://scripts/ui/summon/SummonResultOverlay.gd")

signal back_pressed

@onready var summon_container = $MainContainer/LeftPanel/SummonContainer
@onready var back_button = $BackButton
@onready var showcase_content = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent
@onready var default_message = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent/DefaultMessage

# Banner cards (new system with pity progress)
var banner_cards: Array = []

# Components (RULE 1 compliance - delegation)
var showcase: SummonShowcase
var summon_animation  # Type: SummonAnimation (preloaded)
var result_overlay  # Type: SummonResultOverlay (preloaded)

# State
var selected_element: int = 0
var is_processing_summon: bool = false
var cards_initialized: bool = false
var animations_enabled: bool = true
var pending_summon_results: Array[God] = []  # Collect results during animation
var current_banner_data: Dictionary = {}  # For "Summon Again" feature

func _ready():
	# Ensure fullscreen (needed when parent is Node2D)
	_setup_fullscreen()

	await get_tree().process_frame

	# Safety checks
	if not summon_container or not showcase_content or not default_message:
		return

	# Setup showcase grid
	_setup_showcase_grid()

	# Initialize showcase component
	if showcase_content is GridContainer:
		showcase = _SummonShowcaseClass.new(showcase_content)

	# Initialize summon animation overlay
	_setup_summon_animation()

	# Initialize result overlay
	_setup_result_overlay()

	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_style_back_button()

func _notification(what):
	# When screen becomes visible, ensure cards are using new system
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		if not cards_initialized and summon_container:
			_connect_summon_signals()
			_create_summon_cards()
			cards_initialized = true

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _setup_summon_animation():
	"""Initialize the summon animation overlay component"""
	summon_animation = _SummonAnimationClass.new()
	summon_animation.name = "SummonAnimation"
	summon_animation.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(summon_animation)
	# Move to top of draw order
	move_child(summon_animation, get_child_count() - 1)

	# Connect animation signals
	summon_animation.animation_completed.connect(_on_animation_completed)
	summon_animation.animation_skipped.connect(_on_animation_skipped)
	summon_animation.all_animations_completed.connect(_on_all_animations_completed)

func _setup_result_overlay():
	"""Initialize the summon result overlay component"""
	result_overlay = _SummonResultOverlayClass.new()
	result_overlay.name = "SummonResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(result_overlay)
	# Move above animation layer
	move_child(result_overlay, get_child_count() - 1)

	# Connect result overlay signals
	result_overlay.view_collection_pressed.connect(_on_view_collection_pressed)
	result_overlay.summon_again_pressed.connect(_on_summon_again_pressed)
	result_overlay.close_pressed.connect(_on_result_overlay_closed)

func _style_back_button():
	"""Style the back button to match dark fantasy theme"""
	if not back_button:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	hover.border_color = Color(0.5, 0.45, 0.6, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", hover)

	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

	# Connect to SummonManager
	_connect_summon_signals()

	# Create summon cards
	_create_summon_cards()
	cards_initialized = true

func _setup_showcase_grid():
	if not showcase_content or showcase_content is GridContainer:
		return

	var showcase_parent = showcase_content.get_parent()
	if not showcase_parent:
		return

	var showcase_pos = showcase_content.get_index()
	var showcase_name = showcase_content.name

	# Store existing children
	var existing_children = []
	for child in showcase_content.get_children():
		existing_children.append(child)
		showcase_content.remove_child(child)

	showcase_content.queue_free()

	# Create GridContainer (2 columns)
	var grid = GridContainer.new()
	grid.name = showcase_name
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)

	# Re-add children
	for child in existing_children:
		grid.add_child(child)

	showcase_parent.add_child(grid)
	showcase_parent.move_child(grid, showcase_pos)
	showcase_content = grid

func _connect_summon_signals():
	var summon_manager = SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null
	if not summon_manager:
		return

	# Disconnect first if already connected
	if summon_manager.summon_completed.is_connected(_on_god_summoned):
		summon_manager.summon_completed.disconnect(_on_god_summoned)
	if summon_manager.summon_failed.is_connected(_on_summon_failed):
		summon_manager.summon_failed.disconnect(_on_summon_failed)
	if summon_manager.multi_summon_completed.is_connected(_on_multi_summon_completed):
		summon_manager.multi_summon_completed.disconnect(_on_multi_summon_completed)

	# Connect signals
	summon_manager.summon_completed.connect(_on_god_summoned)
	summon_manager.summon_failed.connect(_on_summon_failed)
	summon_manager.multi_summon_completed.connect(_on_multi_summon_completed)

func _create_summon_cards():
	if not summon_container:
		return

	# Convert to GridContainer if needed
	if not summon_container is GridContainer:
		_convert_summon_container_to_grid()

	# Clear any existing children (old buttons from previous code)
	for child in summon_container.get_children():
		child.queue_free()

	banner_cards.clear()

	# Create banner cards with full pity progress display
	var banners = _get_banner_configs()
	for banner in banners:
		var card = _SummonBannerCardClass.new()
		card.configure(banner)
		card.set_accent_color(banner.get("color", Color.WHITE))
		card.single_summon_pressed.connect(_on_banner_single_summon.bind(banner))
		card.multi_summon_pressed.connect(_on_banner_multi_summon.bind(banner))
		summon_container.add_child(card)
		banner_cards.append(card)

func _get_banner_configs() -> Array:
	var summon_mgr = _get_summon_system()
	var config = summon_mgr.get_config() if summon_mgr else {}
	var rates_cfg = config.get("summon_configuration", {}).get("rates", {})

	return [
		{
			"id": "basic",
			"title": "BASIC SUMMON",
			"description": "Common Soul Summon\nStandard rates for all gods",
			"banner_type": "default",
			"single_cost": {"common_soul": 1},
			"multi_cost": {"common_soul": 9},
			"multi_count": 10,
			"multi_discount": "10% OFF",
			"rates": rates_cfg.get("soul_based_rates", {}).get("common_soul", {"common": 70, "rare": 25, "epic": 4.5, "legendary": 0.5}),
			"color": Color.CYAN,
			"summon_type": "common_soul"
		},
		{
			"id": "premium",
			"title": "PREMIUM SUMMON",
			"description": "Divine Crystal Summon\nHigher legendary rates!",
			"banner_type": "premium",
			"single_cost": {"divine_crystals": 100},
			"multi_cost": {"divine_crystals": 900},
			"multi_count": 10,
			"multi_discount": "10% OFF",
			"rates": rates_cfg.get("premium_rates", {}).get("divine_crystals", {"common": 35, "rare": 40, "epic": 20, "legendary": 5}),
			"color": Color.GOLD,
			"summon_type": "divine_crystals"
		},
		{
			"id": "element",
			"title": "ELEMENT SUMMON",
			"description": "Element Soul Summon\n3x weight for matching element",
			"banner_type": "element",
			"single_cost": {"fire_soul": 1},
			"multi_cost": {"fire_soul": 9},
			"multi_count": 10,
			"multi_discount": "10% OFF",
			"rates": rates_cfg.get("element_soul_rates", {}).get("fire_soul", {"common": 50, "rare": 35, "epic": 13, "legendary": 2}),
			"color": Color.ORANGE_RED,
			"summon_type": "fire_soul"
		},
		{
			"id": "daily_free",
			"title": "DAILY FREE",
			"description": "One free summon per day\nBasic rates, no cost!",
			"banner_type": "default",
			"single_cost": {},
			"multi_cost": {},
			"multi_count": 0,
			"rates": rates_cfg.get("soul_based_rates", {}).get("common_soul", {"common": 70, "rare": 25, "epic": 4.5, "legendary": 0.5}),
			"color": Color.GREEN,
			"summon_type": "daily_free",
			"is_daily_free": true
		}
	]

func _convert_summon_container_to_grid():
	var parent = summon_container.get_parent()
	if not parent:
		return

	var pos = summon_container.get_index()
	summon_container.queue_free()

	var grid = GridContainer.new()
	grid.name = "SummonContainer"
	grid.columns = 2  # 2 columns for larger banner cards with pity progress
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)

	var grid_style = StyleBoxFlat.new()
	grid_style.bg_color = Color.BLACK
	grid_style.bg_color.a = 0.1
	grid_style.corner_radius_top_left = 8
	grid_style.corner_radius_top_right = 8
	grid_style.corner_radius_bottom_left = 8
	grid_style.corner_radius_bottom_right = 8
	grid_style.border_width_left = 1
	grid_style.border_width_top = 1
	grid_style.border_width_right = 1
	grid_style.border_width_bottom = 1
	grid_style.border_color = Color.GRAY
	grid_style.border_color.a = 0.3
	grid.add_theme_stylebox_override("panel", grid_style)

	parent.add_child(grid)
	parent.move_child(grid, pos)
	summon_container = grid

## Banner card event handlers

func _on_banner_single_summon(_banner_data: Dictionary, banner: Dictionary):
	var summon_system = _get_summon_system()
	if not summon_system:
		_show_error_message("Summon system not available")
		return

	_set_cards_enabled(false)
	is_processing_summon = true
	current_banner_data = banner  # Store for "Summon Again"
	pending_summon_results.clear()  # Clear previous results
	if summon_system.has_method("clear_duplicate_tracking"):
		summon_system.clear_duplicate_tracking()  # Fresh duplicate tracking for this session

	var success = false
	if banner.get("is_daily_free", false):
		success = summon_system.summon_free_daily()
	elif banner.summon_type == "divine_crystals":
		success = summon_system.summon_premium()
	else:
		success = summon_system.summon_with_soul(banner.summon_type)

	if not success:
		_set_cards_enabled(true)

func _on_banner_multi_summon(_banner_data: Dictionary, banner: Dictionary):
	var summon_system = _get_summon_system()
	if not summon_system:
		_show_error_message("Summon system not available")
		return

	if banner.multi_count <= 0:
		_show_error_message("Multi-summon not available for this banner")
		return

	_set_cards_enabled(false)
	is_processing_summon = true
	current_banner_data = banner  # Store for "Summon Again"
	pending_summon_results.clear()  # Clear previous results
	if summon_system.has_method("clear_duplicate_tracking"):
		summon_system.clear_duplicate_tracking()  # Fresh duplicate tracking for this session

	var success = false
	if banner.summon_type == "divine_crystals":
		success = summon_system.multi_summon_premium(banner.multi_count)
	elif summon_system.has_method("summon_multi_with_soul"):
		success = summon_system.summon_multi_with_soul(banner.summon_type, banner.multi_count)
	else:
		# Fallback: perform multiple single summons
		for i in range(banner.multi_count):
			success = summon_system.summon_with_soul(banner.summon_type)
			if not success:
				break

	if not success:
		_set_cards_enabled(true)

func _on_back_pressed():
	back_pressed.emit()

## Summon callbacks

func _on_god_summoned(god):
	# Play animation if enabled, otherwise show directly
	if animations_enabled and summon_animation:
		summon_animation.queue_summon(god)
	else:
		_show_god_in_showcase(god)
		_set_cards_enabled(true)
		_refresh_all_cards()

func _on_multi_summon_completed(gods: Array):
	# Play animations for all gods if enabled
	if animations_enabled and summon_animation:
		summon_animation.queue_multi_summon(gods)
	else:
		for god in gods:
			_show_god_in_showcase(god)
		_set_cards_enabled(true)
		_refresh_all_cards()

func _on_summon_failed(reason):
	_show_error_message(reason)
	_set_cards_enabled(true)
	_refresh_all_cards()

func _on_duplicate_obtained(_god, _existing_count: int):
	pass

## Animation callbacks

func _on_animation_completed(god):
	"""Called when a single summon animation finishes"""
	_show_god_in_showcase(god)
	pending_summon_results.append(god)

func _on_animation_skipped(god):
	"""Called when animation is skipped"""
	_show_god_in_showcase(god)
	pending_summon_results.append(god)

func _on_all_animations_completed():
	"""Called when all queued animations are done"""
	_set_cards_enabled(true)
	_refresh_all_cards()

	# Show result overlay if we have results
	if pending_summon_results.size() > 0 and result_overlay:
		result_overlay.show_results(pending_summon_results, current_banner_data)

func _show_god_in_showcase(god: God):
	"""Display god in the showcase panel"""
	if showcase:
		_clear_showcase_invisible_nodes()
		if default_message:
			default_message.visible = false
		showcase.show_god(god, false)  # Don't animate showcase cards, animation already played

## Result overlay callbacks

func _on_view_collection_pressed():
	"""Navigate to collection screen when 'View in Collection' is pressed"""
	var screen_mgr = SystemRegistry.get_instance().get_system("ScreenManager") if SystemRegistry.get_instance() else null
	if screen_mgr and screen_mgr.has_method("show_screen"):
		screen_mgr.show_screen("collection")

func _on_summon_again_pressed():
	"""Repeat the last summon when 'Summon Again' is pressed"""
	if current_banner_data.is_empty():
		return

	# Determine if it was single or multi summon based on pending results
	var was_multi = pending_summon_results.size() > 1

	if was_multi:
		_on_banner_multi_summon(current_banner_data, current_banner_data)
	else:
		_on_banner_single_summon(current_banner_data, current_banner_data)

func _on_result_overlay_closed():
	"""Handle result overlay close"""
	# Nothing special needed, just refresh cards
	_refresh_all_cards()

## Helper functions

func _get_summon_system():
	return SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null

func _set_cards_enabled(enabled: bool):
	for card in banner_cards:
		if card and card.has_method("refresh"):
			if enabled:
				card.refresh()
			# Cards handle their own disabled state based on resources

func _show_error_message(message: String):
	if not default_message:
		return

	default_message.visible = true
	default_message.text = message
	default_message.add_theme_color_override("font_color", Color.ORANGE_RED)

	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func():
		if default_message:
			default_message.visible = false
			default_message.text = "Select a summon type to begin"
			default_message.remove_theme_color_override("font_color")
	)

func _clear_showcase_invisible_nodes():
	if showcase:
		showcase.clear_invisible_nodes()

func _refresh_all_cards():
	for card in banner_cards:
		if card and card.has_method("refresh"):
			card.refresh()
