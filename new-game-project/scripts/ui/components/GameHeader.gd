# scripts/ui/components/GameHeader.gd
# Unified header component for all game screens
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - Unified header UI
extends Control

signal back_pressed

# UI References
var back_button: Button
var title_label: Label
var resource_display: Control
var background_panel: Panel

# Configuration
var _show_back: bool = true
var _title_text: String = ""

func _ready():
	"""Initialize the game header"""
	_setup_header_style()
	_create_header_layout()
	_setup_back_button_style()

func _setup_header_style():
	"""Apply dark fantasy styling to header"""
	# Use PASS so header receives input but also allows children to receive it
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Use Control (not PanelContainer) so we have full control over sizing
	# Add a Panel child for background
	background_panel = Panel.new()
	background_panel.name = "BackgroundPanel"
	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# CRITICAL: Allow mouse events to pass through to buttons
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.98)  # Darker, more opaque
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	background_panel.add_theme_stylebox_override("panel", style)
	add_child(background_panel)

	# Minimum size for the header
	custom_minimum_size = Vector2(0, 50)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _create_header_layout():
	"""Create the header layout: [Back] [Title] [Resources]"""
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# PASS: containers receive input but also allow children to receive it
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 15)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# PASS: containers receive input but also allow children to receive it
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(hbox)

	# Back button (left)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "< Back"
	back_button.custom_minimum_size = Vector2(80, 35)
	back_button.pressed.connect(_on_back_pressed)
	hbox.add_child(back_button)

	# Title label (center, expands)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	# Don't block clicks
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(title_label)

	# Resource display (right) - load from scene
	var resource_scene = load("res://scenes/ResourceDisplay.tscn")
	if resource_scene:
		resource_display = resource_scene.instantiate()
		resource_display.name = "HeaderResourceDisplay"

		# CRITICAL: Set layout_mode to 2 (SIZE_FLAGS) BEFORE adding to HBoxContainer
		# This makes it participate in the container's layout instead of using anchors
		resource_display.set("layout_mode", 2)

		# Reset anchors/offsets - the scene has top-right positioning we need to override
		resource_display.anchor_left = 0.0
		resource_display.anchor_top = 0.0
		resource_display.anchor_right = 0.0
		resource_display.anchor_bottom = 0.0
		resource_display.offset_left = 0
		resource_display.offset_top = 0
		resource_display.offset_right = 0
		resource_display.offset_bottom = 0

		# Let it size to content within HBoxContainer
		resource_display.size_flags_horizontal = Control.SIZE_SHRINK_END
		resource_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		resource_display.custom_minimum_size = Vector2(200, 30)

		hbox.add_child(resource_display)

func _setup_back_button_style():
	"""Style the back button to match dark fantasy theme"""
	if not back_button:
		return

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.1, 0.15, 0.9)
	style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.15, 0.22, 0.95)
	style_hover.border_color = Color(0.5, 0.45, 0.6, 1.0)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.08, 0.06, 0.1, 1.0)
	style_pressed.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style_pressed.set_border_width_all(1)
	style_pressed.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("pressed", style_pressed)

	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

# === PUBLIC API ===

func set_title(title: String):
	"""Set the screen title"""
	_title_text = title
	if title_label:
		title_label.text = title

func show_back_button(is_visible: bool):
	"""Show or hide the back button"""
	_show_back = is_visible
	if back_button:
		back_button.visible = is_visible

func connect_back_button(callback: Callable):
	"""Connect a callback to the back button"""
	if not back_pressed.is_connected(callback):
		back_pressed.connect(callback)

func disconnect_back_button(callback: Callable):
	"""Disconnect a callback from the back button"""
	if back_pressed.is_connected(callback):
		back_pressed.disconnect(callback)

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()
