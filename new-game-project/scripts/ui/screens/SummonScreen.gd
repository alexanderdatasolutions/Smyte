# scripts/ui/SummonScreen.gd
# RULE 1: Coordinator pattern - delegates to specialized components
extends Control

# Preload helper classes
const SummonButtonFactory = preload("res://scripts/ui/summon/SummonButtonFactory.gd")
const SummonShowcase = preload("res://scripts/ui/summon/SummonShowcase.gd")

signal back_pressed

@onready var summon_container = $MainContainer/LeftPanel/SummonContainer
@onready var back_button = $BackButton
@onready var showcase_content = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent
@onready var default_message = $MainContainer/RightPanel/ShowcaseContainer/ShowcaseContent/DefaultMessage

# Summon buttons
var basic_button: Button
var premium_button: Button
var element_button: Button
var crystal_button: Button
var daily_free_button: Button
var basic_10x_button: Button
var premium_10x_button: Button

# Components (RULE 1 compliance - delegation)
var showcase: SummonShowcase

# State
var selected_element: int = 0
var is_processing_summon: bool = false

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
		showcase = SummonShowcase.new(showcase_content)

	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_style_back_button()

func _setup_fullscreen():
	"""Make this control fill the entire viewport"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

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

	# Use SummonButtonFactory to create all buttons
	basic_button = SummonButtonFactory.create_summon_card(
		"BASIC SUMMON", "Common Soul Summon\nBetter than prayers!", "1 Common Soul", Color.CYAN)
	basic_button.pressed.connect(_on_basic_summon_pressed)
	SummonButtonFactory.add_special_effects(basic_button, Color.CYAN, "basic")
	summon_container.add_child(basic_button)

	basic_10x_button = SummonButtonFactory.create_summon_card(
		"BASIC 10x SUMMON", "10 Gods Guaranteed\n1 Rare or Better!", "9 Common Souls\n(10% OFF!)", Color.CYAN)
	basic_10x_button.pressed.connect(_on_basic_10x_summon_pressed)
	SummonButtonFactory.add_special_effects(basic_10x_button, Color.CYAN, "basic")
	summon_container.add_child(basic_10x_button)

	premium_button = SummonButtonFactory.create_summon_card(
		"PREMIUM SUMMON", "Premium Crystal Summon\nHigher Rates!", "50 Divine Crystals", Color.GOLD)
	premium_button.pressed.connect(_on_premium_summon_pressed)
	SummonButtonFactory.add_special_effects(premium_button, Color.GOLD, "premium")
	summon_container.add_child(premium_button)

	premium_10x_button = SummonButtonFactory.create_summon_card(
		"PREMIUM 10x SUMMON", "10 Premium Gods\n1 Epic or Better!", "450 Divine Crystals\n(10% OFF!)", Color.GOLD)
	premium_10x_button.pressed.connect(_on_premium_10x_summon_pressed)
	SummonButtonFactory.add_special_effects(premium_10x_button, Color.GOLD, "premium")
	summon_container.add_child(premium_10x_button)

	element_button = SummonButtonFactory.create_summon_card(
		"ELEMENT SUMMON", "Element Soul Summon\nTargeted Element!", "1 Element Soul", Color.ORANGE_RED)
	element_button.pressed.connect(_on_element_summon_pressed)
	SummonButtonFactory.add_special_effects(element_button, Color.ORANGE_RED, "element")
	summon_container.add_child(element_button)

	crystal_button = SummonButtonFactory.create_summon_card(
		"CRYSTAL SUMMON", "Premium Currency\nHigher Legendary Rates!", "100 Divine Crystals", Color.DEEP_PINK)
	crystal_button.pressed.connect(_on_crystal_summon_pressed)
	SummonButtonFactory.add_special_effects(crystal_button, Color.DEEP_PINK, "crystal")
	summon_container.add_child(crystal_button)

	daily_free_button = SummonButtonFactory.create_summon_card(
		"DAILY FREE SUMMON", "One per day\nBasic rates, no cost!", "FREE!", Color.GREEN)
	daily_free_button.pressed.connect(_on_daily_free_summon_pressed)
	SummonButtonFactory.add_special_effects(daily_free_button, Color.GREEN, "daily_free")
	summon_container.add_child(daily_free_button)

	var focus_button = SummonButtonFactory.create_summon_card(
		"ELEMENT FOCUS", "Choose your element\nfor targeted summons", "Select Below", Color.PURPLE)
	focus_button.pressed.connect(_on_element_focus_pressed)
	summon_container.add_child(focus_button)

	_update_daily_free_availability()

func _convert_summon_container_to_grid():
	var parent = summon_container.get_parent()
	if not parent:
		return

	var pos = summon_container.get_index()
	summon_container.queue_free()

	var grid = GridContainer.new()
	grid.name = "SummonContainer"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)

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

## Button event handlers

func _on_basic_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = true
		var success = summon_system.summon_with_soul("common_soul")
		if not success:
			_set_buttons_enabled(true)
	else:
		_show_error_message("SummonSystem not available")

func _on_premium_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = true
		summon_system.summon_premium()

func _on_basic_10x_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = false
		summon_system.summon_multi_with_soul("common_soul", 10)

func _on_premium_10x_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = false
		summon_system.summon_multi_premium(10)

func _on_element_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = true
		summon_system.summon_with_soul("element_soul")

func _on_element_focus_pressed():
	selected_element = (selected_element + 1) % 6
	_show_error_message("Element focus changed to: " + God.element_to_string(selected_element))

func _on_crystal_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = true
		summon_system.summon_with_soul("divine_crystal")

func _on_daily_free_summon_pressed():
	var summon_system = _get_summon_system()
	if summon_system:
		_set_buttons_enabled(false)
		is_processing_summon = true
		summon_system.summon_free_daily()

func _on_back_pressed():
	back_pressed.emit()

## Summon callbacks

func _on_god_summoned(god):
	if showcase:
		_clear_showcase_invisible_nodes()
		if default_message:
			default_message.visible = false
		showcase.show_god(god, is_processing_summon)
	_set_buttons_enabled(true)

func _on_multi_summon_completed(gods: Array):
	if showcase:
		_clear_showcase_invisible_nodes()
		if default_message:
			default_message.visible = false
		for god in gods:
			showcase.show_god(god, false)
	_set_buttons_enabled(true)

func _on_summon_failed(reason):
	_show_error_message(reason)
	_set_buttons_enabled(true)

func _on_duplicate_obtained(_god, _existing_count: int):
	pass

## Helper functions

func _get_summon_system():
	return SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null

func _set_buttons_enabled(enabled: bool):
	if basic_button:
		basic_button.disabled = not enabled
	if premium_button:
		premium_button.disabled = not enabled
	if element_button:
		element_button.disabled = not enabled
	if crystal_button:
		crystal_button.disabled = not enabled
	if daily_free_button and enabled:
		_update_daily_free_availability()
	if basic_10x_button:
		basic_10x_button.disabled = not enabled
	if premium_10x_button:
		premium_10x_button.disabled = not enabled

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

func _update_daily_free_availability():
	if not daily_free_button:
		return

	var summon_system = _get_summon_system()
	if summon_system and summon_system.has_method("can_use_daily_free"):
		daily_free_button.disabled = not summon_system.can_use_daily_free()
	else:
		daily_free_button.disabled = false
