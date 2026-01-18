# scripts/ui/summon/SummonPopupHelper.gd
# RULE 1: Under 500 lines | RULE 2: Single responsibility - popup display helpers
class_name SummonPopupHelper
extends RefCounted

## Show insufficient resources popup on parent node
static func show_insufficient_resources(parent: Control, message: String, resource_id: String):
	# Create popup overlay
	var overlay = ColorRect.new()
	overlay.name = "InsufficientResourcesOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	parent.move_child(overlay, parent.get_child_count() - 1)

	# Create popup panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(350, 150)
	overlay.add_child(panel)

	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.12, 0.2, 0.98)
	panel_style.border_color = _get_resource_color(resource_id)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Create content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Warning icon/title
	var title = Label.new()
	title.text = "INSUFFICIENT RESOURCES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(title)

	# Message
	var msg_label = Label.new()
	msg_label.text = message
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 14)
	msg_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_label)

	# OK button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(100, 36)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(ok_btn)

	# Style the button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.25, 0.4)
	btn_style.border_color = Color(0.5, 0.45, 0.6)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	ok_btn.add_theme_stylebox_override("normal", btn_style)
	ok_btn.add_theme_color_override("font_color", Color.WHITE)

	# Close on button or background click
	ok_btn.pressed.connect(func(): overlay.queue_free())
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)

	# Auto-close after 3 seconds
	var timer = parent.get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

## Get color associated with resource type
static func _get_resource_color(resource_id: String) -> Color:
	match resource_id:
		"divine_crystals":
			return Color(1.0, 0.85, 0.3)  # Gold
		"mana":
			return Color(0.5, 0.7, 1.0)  # Blue
		"fire_soul":
			return Color(1.0, 0.4, 0.2)  # Orange-red
		"water_soul":
			return Color(0.3, 0.6, 1.0)  # Blue
		"earth_soul":
			return Color(0.6, 0.5, 0.3)  # Brown
		"lightning_soul":
			return Color(1.0, 0.9, 0.3)  # Yellow
		"light_soul":
			return Color(1.0, 1.0, 0.8)  # White-yellow
		"dark_soul":
			return Color(0.5, 0.3, 0.7)  # Purple
		_:
			return Color(0.8, 0.6, 0.3)  # Default amber

## Convert resource_id to user-friendly display name
static func get_resource_display_name(resource_id: String) -> String:
	match resource_id:
		"divine_crystals":
			return "Divine Crystals"
		"mana":
			return "Mana"
		"common_soul":
			return "Common Souls"
		"fire_soul":
			return "Fire Souls"
		"water_soul":
			return "Water Souls"
		"earth_soul":
			return "Earth Souls"
		"lightning_soul":
			return "Lightning Souls"
		"light_soul":
			return "Light Souls"
		"dark_soul":
			return "Dark Souls"
		_:
			return resource_id.replace("_", " ").capitalize()
