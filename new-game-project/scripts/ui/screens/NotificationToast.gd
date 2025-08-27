# scripts/ui/NotificationToast.gd
# Simple notification toast following MYTHOS ARCHITECTURE
extends Control
class_name NotificationToast

@onready var title_label: Label = $Content/TextContainer/TitleLabel
@onready var message_label: Label = $Content/TextContainer/MessageLabel
@onready var icon_label: Label = $Content/IconContainer/Icon

var notification_duration: float = 3.0
var fade_duration: float = 0.5

signal notification_completed()

func _ready():
	"""Initialize notification toast"""
	modulate = Color.TRANSPARENT
	print("NotificationToast: Initialized")

func show_notification(config: Dictionary):
	"""Show notification with configuration"""
	# Set content
	if title_label:
		title_label.text = config.get("title", "Notification")
	if message_label:
		message_label.text = config.get("message", "")
	if icon_label:
		icon_label.text = config.get("icon", "🔔")
	
	# Set duration
	notification_duration = config.get("duration", 3.0)
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, fade_duration)
	
	# Auto-close after duration
	await get_tree().create_timer(notification_duration).timeout
	hide_notification()

func hide_notification():
	"""Hide notification with fade out"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_duration)
	await tween.finished
	
	notification_completed.emit()
	queue_free()
