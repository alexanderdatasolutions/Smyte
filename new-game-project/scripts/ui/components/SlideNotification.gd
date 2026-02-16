# scripts/ui/components/SlideNotification.gd
# Slide-in notification banner from the left side
# Usage: SlideNotification.show_notification("You've unlocked Territory!")
extends Control
class_name SlideNotification

# ==============================================================================
# CONFIGURATION
# ==============================================================================

const SLIDE_DURATION: float = 0.3
const DISPLAY_DURATION: float = 4.0
const BANNER_WIDTH: float = 350.0
const BANNER_HEIGHT: float = 80.0
const TOP_MARGIN: float = 100.0  # Below header

# Colors following UI_DESIGN_PATTERNS.md
const BG_COLOR := Color(0.12, 0.1, 0.16, 0.95)
const BORDER_COLOR := Color(0.3, 0.25, 0.4, 0.8)
const HEADER_COLOR := Color(0.8, 0.8, 0.9)
const TEXT_COLOR := Color(0.7, 0.7, 0.8)
const ACCENT_COLOR := Color(0.4, 0.7, 0.5)  # Green accent for unlocks

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

var _panel: PanelContainer
var _icon_label: Label
var _title_label: Label
var _message_label: Label
var _ok_button: Button
var _auto_close_timer: Timer
var _is_showing: bool = false

signal notification_closed()

# ==============================================================================
# STATIC FACTORY
# ==============================================================================

## Create and show a notification with custom message
static func create(parent: Node, title: String, message: String = "", icon: String = "🔓", auto_close: bool = true) -> SlideNotification:
	var notification = SlideNotification.new()
	parent.add_child(notification)
	notification._setup(title, message, icon, auto_close)
	notification._slide_in()
	return notification

## Shorthand for feature unlock notifications
static func show_unlock(parent: Node, feature_name: String) -> SlideNotification:
	return create(parent, "Feature Unlocked!", feature_name, "🔓", true)

## Shorthand for achievement notifications
static func show_achievement(parent: Node, achievement_name: String) -> SlideNotification:
	return create(parent, "Achievement!", achievement_name, "🏆", true)

## Shorthand for reward notifications
static func show_reward(parent: Node, reward_text: String) -> SlideNotification:
	return create(parent, "Rewards!", reward_text, "🎁", true)

## Generic notification
static func show_message(parent: Node, title: String, message: String = "") -> SlideNotification:
	return create(parent, title, message, "📢", true)

# ==============================================================================
# SETUP
# ==============================================================================

func _ready() -> void:
	# Set up as full-screen overlay for positioning
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup(title: String, message: String, icon: String, auto_close: bool) -> void:
	# Create panel container
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	_panel.position = Vector2(-BANNER_WIDTH, TOP_MARGIN)  # Start off-screen left
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.border_width_left = 4
	style.border_color = ACCENT_COLOR  # Left accent stripe
	style.set_corner_radius_all(8)
	style.corner_radius_top_left = 0
	style.corner_radius_bottom_left = 0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(4, 4)
	_panel.add_theme_stylebox_override("panel", style)

	# Main HBox layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_panel.add_child(hbox)

	# Left margin
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(left_margin)

	# Icon
	_icon_label = Label.new()
	_icon_label.text = icon
	_icon_label.add_theme_font_size_override("font_size", 32)
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_icon_label)

	# Text container
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(text_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", HEADER_COLOR)
	text_vbox.add_child(_title_label)

	# Message (optional)
	if not message.is_empty():
		_message_label = Label.new()
		_message_label.text = message
		_message_label.add_theme_font_size_override("font_size", 14)
		_message_label.add_theme_color_override("font_color", TEXT_COLOR)
		_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		text_vbox.add_child(_message_label)

	# OK button
	_ok_button = Button.new()
	_ok_button.text = "OK"
	_ok_button.custom_minimum_size = Vector2(50, 36)
	_ok_button.pressed.connect(_on_ok_pressed)
	_style_button(_ok_button)
	hbox.add_child(_ok_button)

	# Right margin
	var right_margin = Control.new()
	right_margin.custom_minimum_size = Vector2(8, 0)
	hbox.add_child(right_margin)

	# Auto-close timer
	if auto_close:
		_auto_close_timer = Timer.new()
		_auto_close_timer.one_shot = true
		_auto_close_timer.wait_time = DISPLAY_DURATION
		_auto_close_timer.timeout.connect(_slide_out)
		add_child(_auto_close_timer)

func _style_button(button: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
	style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = style_normal.bg_color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", style_pressed)

	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)

# ==============================================================================
# ANIMATION
# ==============================================================================

func _slide_in() -> void:
	_is_showing = true
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "position:x", 0.0, SLIDE_DURATION)

	# Start auto-close timer after slide-in completes
	if _auto_close_timer:
		await tween.finished
		_auto_close_timer.start()

func _slide_out() -> void:
	if not _is_showing:
		return
	_is_showing = false

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "position:x", -BANNER_WIDTH - 20, SLIDE_DURATION)

	await tween.finished
	notification_closed.emit()
	queue_free()

func _on_ok_pressed() -> void:
	if _auto_close_timer:
		_auto_close_timer.stop()
	_slide_out()
