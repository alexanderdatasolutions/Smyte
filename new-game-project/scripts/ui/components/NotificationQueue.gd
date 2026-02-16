# scripts/ui/components/NotificationQueue.gd
# Manages queued slide notifications with stacking and priority
extends Node
class_name NotificationQueue

# ==============================================================================
# SINGLETON PATTERN
# ==============================================================================

static var _instance: NotificationQueue = null

static func get_instance() -> NotificationQueue:
	if not _instance:
		_instance = NotificationQueue.new()
		_instance.name = "NotificationQueue"
		# Add to root when first accessed
		if Engine.get_main_loop() and Engine.get_main_loop().current_scene:
			Engine.get_main_loop().current_scene.add_child(_instance)
	return _instance

# ==============================================================================
# CONFIGURATION
# ==============================================================================

const MAX_VISIBLE: int = 3  # Max notifications visible at once
const STACK_SPACING: float = 100.0  # Vertical space between notifications (accounts for variable height)
const TOP_MARGIN: float = 100.0  # Starting Y position

# Priority levels (higher = more important, shown first)
enum Priority {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
	CRITICAL = 3
}

# ==============================================================================
# STATE
# ==============================================================================

var _queue: Array = []  # Pending notifications
var _active: Array = []  # Currently visible notifications
var _is_processing: bool = false

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Queue a notification with priority
static func queue(config: Dictionary) -> void:
	get_instance()._queue_notification(config)

## Quick methods matching SlideNotification API
static func show_unlock(title: String, message: String = "") -> void:
	queue({
		"type": "unlock",
		"title": title,
		"message": message,
		"icon": "🔓",
		"priority": Priority.HIGH
	})

static func show_achievement(title: String, message: String = "") -> void:
	queue({
		"type": "achievement",
		"title": title,
		"message": message,
		"icon": "🏆",
		"priority": Priority.HIGH
	})

static func show_reward(title: String, message: String = "") -> void:
	queue({
		"type": "reward",
		"title": title,
		"message": message,
		"icon": "🎁",
		"priority": Priority.NORMAL
	})

static func show_message(title: String, message: String = "", priority: int = Priority.NORMAL) -> void:
	queue({
		"type": "message",
		"title": title,
		"message": message,
		"icon": "📢",
		"priority": priority
	})

static func show_level_up(god_name: String, new_level: int, levels_gained: int = 1) -> void:
	var msg = "%s is now Level %d!" % [god_name, new_level]
	if levels_gained > 1:
		msg = "%s gained %d levels! Now Level %d" % [god_name, levels_gained, new_level]
	queue({
		"type": "level_up",
		"title": "Level Up!",
		"message": msg,
		"icon": "⬆️",
		"priority": Priority.NORMAL
	})

static func show_territory(node_name: String, tier: int, rewards: Dictionary = {}) -> void:
	var reward_text = ""
	for resource_id in rewards:
		if not reward_text.is_empty():
			reward_text += ", "
		reward_text += "%d %s" % [rewards[resource_id], resource_id.replace("_", " ").capitalize()]

	# Keep message compact - no newlines
	var msg = "%s (T%d)" % [node_name, tier]
	if not reward_text.is_empty():
		msg += " - " + reward_text

	queue({
		"type": "territory",
		"title": "Territory Captured!",
		"message": msg,
		"icon": "🏴",
		"priority": Priority.NORMAL
	})

# ==============================================================================
# INTERNAL
# ==============================================================================

func _queue_notification(config: Dictionary) -> void:
	# Add to queue sorted by priority
	var priority: int = config.get("priority", Priority.NORMAL)
	var inserted = false

	for i in range(_queue.size()):
		if _queue[i].get("priority", Priority.NORMAL) < priority:
			_queue.insert(i, config)
			inserted = true
			break

	if not inserted:
		_queue.append(config)

	_process_queue()

func _process_queue() -> void:
	if _is_processing:
		return

	_is_processing = true

	# Show notifications up to MAX_VISIBLE
	while not _queue.is_empty() and _active.size() < MAX_VISIBLE:
		var config = _queue.pop_front()
		_show_notification(config)

	_is_processing = false

func _show_notification(config: Dictionary) -> void:
	var root = Engine.get_main_loop().current_scene
	if not root:
		return

	# Create the notification
	var notification = _create_notification(config)
	if not notification:
		return

	root.add_child(notification)
	_active.append(notification)

	# Position based on current stack
	var slot = _active.size() - 1
	notification.set_slot(slot, TOP_MARGIN + slot * STACK_SPACING)

	# Connect to closure signal
	notification.notification_closed.connect(_on_notification_closed.bind(notification))

func _create_notification(config: Dictionary) -> Control:
	var notification = StackedNotification.new()
	notification.setup(config)
	return notification

func _on_notification_closed(notification: Control) -> void:
	var index = _active.find(notification)
	if index != -1:
		_active.remove_at(index)

	# Shift remaining notifications up
	_reposition_active()

	# Process more from queue
	_process_queue()

func _reposition_active() -> void:
	for i in range(_active.size()):
		var notification = _active[i]
		if notification and is_instance_valid(notification):
			notification.animate_to_slot(i, TOP_MARGIN + i * STACK_SPACING)

# ==============================================================================
# STACKED NOTIFICATION (Inner Class)
# ==============================================================================

class StackedNotification extends Control:
	const SLIDE_DURATION: float = 0.3
	const DISPLAY_DURATION: float = 4.0
	const BANNER_WIDTH: float = 350.0
	const BANNER_HEIGHT: float = 80.0

	# Colors
	const BG_COLOR := Color(0.12, 0.1, 0.16, 0.95)
	const BORDER_COLOR := Color(0.3, 0.25, 0.4, 0.8)
	const HEADER_COLOR := Color(0.8, 0.8, 0.9)
	const TEXT_COLOR := Color(0.7, 0.7, 0.8)
	const ACCENT_COLOR := Color(0.4, 0.7, 0.5)

	var _panel: PanelContainer
	var _target_y: float = 0.0
	var _auto_close_timer: Timer
	var _is_showing: bool = false

	signal notification_closed()

	func setup(config: Dictionary) -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Create panel with fixed size
		_panel = PanelContainer.new()
		_panel.custom_minimum_size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
		_panel.size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)  # Fixed size
		_panel.clip_contents = true  # Clip any overflow
		_panel.position = Vector2(-BANNER_WIDTH, 0)  # Start off-screen
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_panel)

		# Style panel
		var accent = _get_accent_color(config.get("type", "message"))
		var style = StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_color = accent
		style.set_border_width_all(2)
		style.border_width_left = 4
		style.set_corner_radius_all(8)
		style.corner_radius_top_left = 0
		style.corner_radius_bottom_left = 0
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 8
		style.shadow_offset = Vector2(4, 4)
		_panel.add_theme_stylebox_override("panel", style)

		# Content layout
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		_panel.add_child(hbox)

		var left_margin = Control.new()
		left_margin.custom_minimum_size = Vector2(8, 0)
		hbox.add_child(left_margin)

		# Icon
		var icon_label = Label.new()
		icon_label.text = config.get("icon", "📢")
		icon_label.add_theme_font_size_override("font_size", 32)
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(icon_label)

		# Text container (clips overflow)
		var text_vbox = VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_vbox.add_theme_constant_override("separation", 2)
		text_vbox.clip_contents = true
		hbox.add_child(text_vbox)

		# Title
		var title_label = Label.new()
		title_label.text = config.get("title", "Notification")
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.add_theme_color_override("font_color", HEADER_COLOR)
		text_vbox.add_child(title_label)

		# Message (single line, clips if too long)
		var message = config.get("message", "")
		if not message.is_empty():
			var message_label = Label.new()
			message_label.text = message
			message_label.add_theme_font_size_override("font_size", 14)
			message_label.add_theme_color_override("font_color", TEXT_COLOR)
			message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			message_label.clip_text = true
			message_label.custom_minimum_size.x = 200  # Ensure minimum width for clipping
			text_vbox.add_child(message_label)

		# OK button
		var ok_button = Button.new()
		ok_button.text = "OK"
		ok_button.custom_minimum_size = Vector2(50, 36)
		ok_button.pressed.connect(_on_ok_pressed)
		_style_button(ok_button, accent)
		hbox.add_child(ok_button)

		var right_margin = Control.new()
		right_margin.custom_minimum_size = Vector2(8, 0)
		hbox.add_child(right_margin)

		# Auto-close timer
		_auto_close_timer = Timer.new()
		_auto_close_timer.one_shot = true
		_auto_close_timer.wait_time = DISPLAY_DURATION
		_auto_close_timer.timeout.connect(_slide_out)
		add_child(_auto_close_timer)

	func _get_accent_color(type: String) -> Color:
		match type:
			"unlock", "achievement":
				return Color(0.4, 0.7, 0.5)  # Green
			"reward":
				return Color(1.0, 0.8, 0.2)  # Gold
			"level_up":
				return Color(0.4, 0.6, 0.9)  # Blue
			"territory":
				return Color(0.6, 0.4, 0.2)  # Bronze
			_:
				return Color(0.5, 0.5, 0.6)  # Gray

	func _style_button(button: Button, accent: Color) -> void:
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = accent.darkened(0.3)
		style_normal.border_color = accent
		style_normal.set_border_width_all(1)
		style_normal.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal", style_normal)

		var style_hover = style_normal.duplicate()
		style_hover.bg_color = accent.darkened(0.1)
		button.add_theme_stylebox_override("hover", style_hover)

		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color.WHITE)

	func set_slot(slot: int, y_position: float) -> void:
		_target_y = y_position
		_panel.position.y = y_position
		_slide_in()

	func animate_to_slot(slot: int, y_position: float) -> void:
		_target_y = y_position
		var tween = create_tween()
		tween.tween_property(_panel, "position:y", y_position, 0.2).set_ease(Tween.EASE_OUT)

	func _slide_in() -> void:
		_is_showing = true
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(_panel, "position:x", 0.0, SLIDE_DURATION)
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
		_auto_close_timer.stop()
		_slide_out()
