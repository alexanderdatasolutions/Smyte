# scripts/ui/components/GenericPopup.gd
# Reusable popup dialog similar to victory/defeat screens
# Usage: GenericPopup.show_popup(parent, config)
extends Control
class_name GenericPopup

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Colors following UI_DESIGN_PATTERNS.md
const OVERLAY_COLOR := Color(0, 0, 0, 0.7)
const BG_COLOR := Color(0.12, 0.1, 0.16, 0.98)
const BORDER_COLOR := Color(0.3, 0.25, 0.4, 0.8)
const HEADER_COLOR := Color(0.8, 0.8, 0.9)
const TEXT_COLOR := Color(0.7, 0.7, 0.8)
const MUTED_COLOR := Color(0.5, 0.5, 0.55)

# Preset accent colors
const ACCENT_SUCCESS := Color(0.3, 0.7, 0.4)
const ACCENT_WARNING := Color(0.9, 0.7, 0.2)
const ACCENT_DANGER := Color(0.8, 0.3, 0.3)
const ACCENT_INFO := Color(0.4, 0.6, 0.9)
const ACCENT_FEATURE := Color(0.6, 0.4, 0.8)

const FADE_DURATION: float = 0.25
const SCALE_DURATION: float = 0.2

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

var _overlay: ColorRect
var _panel: PanelContainer
var _header_label: Label
var _icon_label: Label
var _content_container: VBoxContainer
var _message_label: Label
var _button_container: HBoxContainer
var _close_on_overlay_click: bool = true
var _accent_color: Color = ACCENT_INFO

signal popup_closed(button_id: String)
signal button_pressed(button_id: String)

# ==============================================================================
# STATIC FACTORY METHODS
# ==============================================================================

## Show a simple message popup with OK button
static func show_message(parent: Node, title: String, message: String, icon: String = "📢") -> GenericPopup:
	return show_popup(parent, {
		"title": title,
		"message": message,
		"icon": icon,
		"buttons": [{"id": "ok", "text": "OK", "primary": true}]
	})

## Show a confirmation popup with Yes/No buttons
static func show_confirm(parent: Node, title: String, message: String, icon: String = "❓") -> GenericPopup:
	return show_popup(parent, {
		"title": title,
		"message": message,
		"icon": icon,
		"accent": "warning",
		"buttons": [
			{"id": "no", "text": "No"},
			{"id": "yes", "text": "Yes", "primary": true}
		]
	})

## Show a feature unlock celebration popup
static func show_feature_unlock(parent: Node, feature_title: String, feature_description: String) -> GenericPopup:
	return show_popup(parent, {
		"title": "Feature Unlocked!",
		"message": feature_title + "\n\n" + feature_description,
		"icon": "🔓",
		"accent": "feature",
		"buttons": [{"id": "ok", "text": "Awesome!", "primary": true}]
	})

## Show an achievement popup
static func show_achievement(parent: Node, achievement_name: String, description: String, rewards: String = "") -> GenericPopup:
	var msg = description
	if not rewards.is_empty():
		msg += "\n\nRewards: " + rewards
	return show_popup(parent, {
		"title": "Achievement Unlocked!",
		"message": achievement_name + "\n\n" + msg,
		"icon": "🏆",
		"accent": "success",
		"buttons": [{"id": "ok", "text": "Claim", "primary": true}]
	})

## Show an error popup
static func show_error(parent: Node, title: String, message: String) -> GenericPopup:
	return show_popup(parent, {
		"title": title,
		"message": message,
		"icon": "⚠️",
		"accent": "danger",
		"buttons": [{"id": "ok", "text": "OK", "primary": true}]
	})

## Show reward summary popup
static func show_rewards(parent: Node, title: String, rewards_text: String) -> GenericPopup:
	return show_popup(parent, {
		"title": title,
		"message": rewards_text,
		"icon": "🎁",
		"accent": "success",
		"buttons": [{"id": "ok", "text": "Collect", "primary": true}]
	})

## Main factory method - full configuration
static func show_popup(parent: Node, config: Dictionary) -> GenericPopup:
	var popup = GenericPopup.new()
	parent.add_child(popup)
	popup._setup(config)
	popup._animate_in()
	return popup

# ==============================================================================
# SETUP
# ==============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

func _setup(config: Dictionary) -> void:
	# Determine accent color
	var accent_str: String = config.get("accent", "info")
	match accent_str:
		"success": _accent_color = ACCENT_SUCCESS
		"warning": _accent_color = ACCENT_WARNING
		"danger": _accent_color = ACCENT_DANGER
		"feature": _accent_color = ACCENT_FEATURE
		_: _accent_color = ACCENT_INFO

	_close_on_overlay_click = config.get("close_on_overlay", true)

	# Create overlay
	_overlay = ColorRect.new()
	_overlay.color = Color.TRANSPARENT  # Will fade in
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if _close_on_overlay_click:
		_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	# Create centered panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(400, 200)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.pivot_offset = Vector2(200, 100)  # Center pivot for scale animation
	_panel.scale = Vector2(0.8, 0.8)  # Start smaller
	_panel.modulate = Color.TRANSPARENT  # Start invisible
	_style_panel(_panel)
	add_child(_panel)

	# Main VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(main_vbox)

	# Margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(content_vbox)

	# Header row (icon + title)
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(header_hbox)

	# Icon
	var icon = config.get("icon", "")
	if not icon.is_empty():
		_icon_label = Label.new()
		_icon_label.text = icon
		_icon_label.add_theme_font_size_override("font_size", 40)
		header_hbox.add_child(_icon_label)

	# Title
	_header_label = Label.new()
	_header_label.text = config.get("title", "")
	_header_label.add_theme_font_size_override("font_size", 24)
	_header_label.add_theme_color_override("font_color", _accent_color)
	header_hbox.add_child(_header_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _create_separator_style())
	content_vbox.add_child(sep)

	# Content container (for message or custom content)
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(_content_container)

	# Message
	var message = config.get("message", "")
	if not message.is_empty():
		_message_label = Label.new()
		_message_label.text = message
		_message_label.add_theme_font_size_override("font_size", 16)
		_message_label.add_theme_color_override("font_color", TEXT_COLOR)
		_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message_label.custom_minimum_size = Vector2(350, 0)
		_content_container.add_child(_message_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	content_vbox.add_child(spacer)

	# Button row
	_button_container = HBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 16)
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(_button_container)

	# Create buttons
	var buttons: Array = config.get("buttons", [{"id": "ok", "text": "OK", "primary": true}])
	for btn_config in buttons:
		var btn = Button.new()
		btn.text = btn_config.get("text", "Button")
		btn.custom_minimum_size = Vector2(100, 40)
		var btn_id: String = btn_config.get("id", "button")
		var is_primary: bool = btn_config.get("primary", false)
		_style_button(btn, is_primary)
		btn.pressed.connect(_on_button_pressed.bind(btn_id))
		_button_container.add_child(btn)

func _style_panel(panel: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = _accent_color.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool) -> void:
	var style_normal = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = _accent_color.darkened(0.2)
		style_normal.border_color = _accent_color
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = style_normal.bg_color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", style_pressed)

	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color.WHITE if primary else TEXT_COLOR)

func _create_separator_style() -> StyleBoxLine:
	var style = StyleBoxLine.new()
	style.color = BORDER_COLOR
	style.thickness = 1
	return style

# ==============================================================================
# ANIMATION
# ==============================================================================

func _animate_in() -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	# Overlay fade in
	tween.tween_property(_overlay, "color", OVERLAY_COLOR, FADE_DURATION)

	# Panel scale + fade in
	tween.tween_property(_panel, "scale", Vector2.ONE, SCALE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "modulate", Color.WHITE, FADE_DURATION)

func _animate_out(button_id: String) -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	# Overlay fade out
	tween.tween_property(_overlay, "color", Color.TRANSPARENT, FADE_DURATION)

	# Panel scale + fade out
	tween.tween_property(_panel, "scale", Vector2(0.8, 0.8), SCALE_DURATION * 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate", Color.TRANSPARENT, FADE_DURATION * 0.5)

	await tween.finished
	popup_closed.emit(button_id)
	queue_free()

# ==============================================================================
# INPUT HANDLING
# ==============================================================================

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close("overlay")

func _on_button_pressed(button_id: String) -> void:
	button_pressed.emit(button_id)
	close(button_id)

## Close the popup manually
func close(button_id: String = "close") -> void:
	_animate_out(button_id)

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Add custom content to the popup
func add_content(node: Control) -> void:
	if _content_container:
		_content_container.add_child(node)

## Get the content container for custom layouts
func get_content_container() -> VBoxContainer:
	return _content_container

## Update the message text
func set_message(text: String) -> void:
	if _message_label:
		_message_label.text = text
