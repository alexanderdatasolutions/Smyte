# scripts/ui/components/TutorialHighlightOverlay.gd
extends Control
class_name TutorialHighlightOverlay

# ==============================================================================
# TUTORIAL HIGHLIGHT OVERLAY - Spotlight effect for tutorial guidance
# ==============================================================================
# Creates a darkened overlay with a transparent "cutout" around the target
# element, drawing attention to specific UI elements during tutorials.
# Follows UI_DESIGN_PATTERNS.md popup pattern.

signal target_clicked()
signal overlay_dismissed()
signal continue_pressed()

# Constants following UI_DESIGN_PATTERNS.md
const OVERLAY_COLOR := Color(0, 0, 0, 0.7)
const HIGHLIGHT_BORDER_COLOR := Color.GOLD
const PANEL_BG_COLOR := Color(0.12, 0.1, 0.16, 0.95)
const HEADER_TEXT_COLOR := Color(0.8, 0.8, 0.9)
const BODY_TEXT_COLOR := Color(0.7, 0.7, 0.8)
const PRIMARY_BUTTON_BG := Color(0.2, 0.5, 0.3, 0.9)
const PRIMARY_BUTTON_BORDER := Color(0.3, 0.7, 0.4, 0.8)

const PULSE_MIN := 0.6
const PULSE_MAX := 1.0
const PULSE_DURATION := 0.8
const CUTOUT_PADDING := 12.0

# Overlay rects (4 ColorRects around the cutout)
var _top_rect: ColorRect
var _bottom_rect: ColorRect
var _left_rect: ColorRect
var _right_rect: ColorRect

# Highlight border around target
var _highlight_border: Panel

# Message tooltip
var _message_panel: PanelContainer
var _title_label: Label
var _message_label: Label
var _continue_button: Button

# State
var _target_control: Control = null
var _target_rect: Rect2 = Rect2()
var _pulse_tween: Tween = null
var _allow_overlay_dismiss: bool = false
var _wait_for_target_click: bool = true
var _show_continue_button: bool = false

func _ready() -> void:
	name = "TutorialHighlightOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Use IGNORE so the cutout area allows clicks through to buttons underneath
	# The 4 ColorRects around the cutout use STOP to block clicks on dark areas
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100  # Same as popups per UI_DESIGN_PATTERNS.md
	visible = false

	_create_overlay_rects()
	_create_highlight_border()
	_create_message_panel()

# ==============================================================================
# SETUP
# ==============================================================================

func _create_overlay_rects() -> void:
	# Create 4 ColorRects that surround the cutout area
	_top_rect = ColorRect.new()
	_bottom_rect = ColorRect.new()
	_left_rect = ColorRect.new()
	_right_rect = ColorRect.new()

	for rect: ColorRect in [_top_rect, _bottom_rect, _left_rect, _right_rect]:
		rect.color = OVERLAY_COLOR
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(rect)

func _create_highlight_border() -> void:
	_highlight_border = Panel.new()
	_highlight_border.name = "HighlightBorder"

	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = HIGHLIGHT_BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	_highlight_border.add_theme_stylebox_override("panel", style)
	_highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight_border)

func _create_message_panel() -> void:
	_message_panel = PanelContainer.new()
	_message_panel.name = "MessagePanel"
	_message_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Style following UI_DESIGN_PATTERNS.md
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG_COLOR
	panel_style.border_color = HIGHLIGHT_BORDER_COLOR
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 15
	panel_style.content_margin_bottom = 15
	_message_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_message_panel.add_child(vbox)

	# Title label
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", HEADER_TEXT_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.visible = false
	vbox.add_child(_title_label)

	# Message label
	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.add_theme_color_override("font_color", BODY_TEXT_COLOR)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(_message_label)

	# Continue button
	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "Got it!"
	_continue_button.custom_minimum_size = Vector2(120, 40)
	_continue_button.pressed.connect(_on_continue_pressed)
	_style_continue_button()
	vbox.add_child(_continue_button)

	add_child(_message_panel)

func _style_continue_button() -> void:
	# Primary button style per UI_DESIGN_PATTERNS.md
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = PRIMARY_BUTTON_BG
	style_normal.border_color = PRIMARY_BUTTON_BORDER
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	_continue_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	style_hover.bg_color = PRIMARY_BUTTON_BG.lightened(0.15)
	_continue_button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = PRIMARY_BUTTON_BG.darkened(0.1)
	_continue_button.add_theme_stylebox_override("pressed", style_pressed)

	_continue_button.add_theme_color_override("font_color", Color.WHITE)
	_continue_button.add_theme_font_size_override("font_size", 16)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func highlight_target(
	target: Control,
	message: String,
	title: String = "",
	button_text: String = "Got it!",
	wait_for_click: bool = true,
	show_button: bool = false
) -> void:
	"""Highlight a target control with a spotlight effect and message."""
	if not target or not is_instance_valid(target):
		push_warning("TutorialHighlightOverlay: Invalid target control")
		return

	_target_control = target
	_wait_for_target_click = wait_for_click
	_show_continue_button = show_button or not wait_for_click

	# Set message content
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_message_label.text = message
	_continue_button.text = button_text
	_continue_button.visible = _show_continue_button

	# Show and update layout
	visible = true
	_update_layout()
	_start_pulse_animation()

func highlight_rect(
	rect: Rect2,
	message: String,
	title: String = "",
	button_text: String = "Got it!"
) -> void:
	"""Highlight a specific rect area (for non-Control targets)."""
	_target_control = null
	_target_rect = rect.grow(CUTOUT_PADDING)
	_wait_for_target_click = false
	_show_continue_button = true

	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_message_label.text = message
	_continue_button.text = button_text
	_continue_button.visible = true

	visible = true
	_update_layout_with_rect(_target_rect)
	_start_pulse_animation()

func clear_highlight() -> void:
	"""Clear the highlight and hide the overlay."""
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null

	_target_control = null
	_target_rect = Rect2()
	visible = false

func set_allow_overlay_dismiss(allow: bool) -> void:
	"""Allow clicking the dark overlay to dismiss (skip)."""
	_allow_overlay_dismiss = allow

# ==============================================================================
# LAYOUT
# ==============================================================================

func _update_layout() -> void:
	if not _target_control or not is_instance_valid(_target_control):
		return

	# Get target's global rect and add padding
	var target_global_rect := _target_control.get_global_rect()
	_target_rect = target_global_rect.grow(CUTOUT_PADDING)

	_update_layout_with_rect(_target_rect)

func _update_layout_with_rect(cutout_rect: Rect2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	# Position the 4 overlay rects around the cutout
	# Top rect: full width, from top to cutout top
	_top_rect.position = Vector2.ZERO
	_top_rect.size = Vector2(viewport_size.x, cutout_rect.position.y)

	# Bottom rect: full width, from cutout bottom to viewport bottom
	_bottom_rect.position = Vector2(0, cutout_rect.end.y)
	_bottom_rect.size = Vector2(viewport_size.x, viewport_size.y - cutout_rect.end.y)

	# Left rect: from cutout top to cutout bottom, left edge to cutout left
	_left_rect.position = Vector2(0, cutout_rect.position.y)
	_left_rect.size = Vector2(cutout_rect.position.x, cutout_rect.size.y)

	# Right rect: from cutout top to cutout bottom, cutout right to viewport right
	_right_rect.position = Vector2(cutout_rect.end.x, cutout_rect.position.y)
	_right_rect.size = Vector2(viewport_size.x - cutout_rect.end.x, cutout_rect.size.y)

	# Position highlight border exactly on cutout
	_highlight_border.position = cutout_rect.position
	_highlight_border.size = cutout_rect.size

	# Position message panel below or above the cutout
	_position_message_panel(cutout_rect, viewport_size)

func _position_message_panel(cutout_rect: Rect2, viewport_size: Vector2) -> void:
	# Wait for message panel to calculate its size
	_message_panel.reset_size()
	await get_tree().process_frame

	var panel_size := _message_panel.size
	var margin := 20.0

	# Try to position below the cutout
	var below_y := cutout_rect.end.y + margin

	# If not enough space below, position above
	if below_y + panel_size.y > viewport_size.y - margin:
		below_y = cutout_rect.position.y - panel_size.y - margin

	# Center horizontally
	var center_x := (viewport_size.x - panel_size.x) / 2.0

	_message_panel.position = Vector2(center_x, below_y)

# ==============================================================================
# ANIMATION
# ==============================================================================

func _start_pulse_animation() -> void:
	if _pulse_tween:
		_pulse_tween.kill()

	_highlight_border.modulate.a = PULSE_MAX

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_highlight_border, "modulate:a", PULSE_MIN, PULSE_DURATION / 2.0)
	_pulse_tween.tween_property(_highlight_border, "modulate:a", PULSE_MAX, PULSE_DURATION / 2.0)

# ==============================================================================
# INPUT HANDLING
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var click_pos := mouse_event.position

	# Check if click is within the cutout (target) area
	if _target_rect.has_area() and _target_rect.has_point(click_pos):
		if _wait_for_target_click:
			target_clicked.emit()
			clear_highlight()
			# DON'T consume the input - let the click pass through to the button underneath
		return

	# Click is on the dark overlay
	if _allow_overlay_dismiss:
		overlay_dismissed.emit()
		clear_highlight()
		get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	continue_pressed.emit()
	clear_highlight()

# ==============================================================================
# PROCESS (for dynamic target tracking)
# ==============================================================================

func _process(_delta: float) -> void:
	if not visible or not _target_control:
		return

	# Update layout if target moved
	if is_instance_valid(_target_control):
		var current_rect := _target_control.get_global_rect().grow(CUTOUT_PADDING)
		if not current_rect.is_equal_approx(_target_rect):
			_update_layout()
