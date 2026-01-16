# scripts/ui/summon/SummonButtonFactory.gd
# Factory for creating and styling summon buttons with visual effects
# RULE 1: Single responsibility - handles button creation/styling only
class_name SummonButtonFactory
extends RefCounted

## Creates a styled summon button with title, description, and cost
static func create_summon_card(title: String, description: String, cost: String, color: Color) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(180, 180)  # Uniform height for all buttons
	button.text = ""  # Remove built-in text to prevent overlap

	# Button visual style
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color.darkened(0.6)
	style_normal.border_color = Color(0.2, 0.2, 0.2, 1.0)  # Pure neutral gray, zero glow
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = color.darkened(0.4)
	style_hover.border_color = Color(0.3, 0.3, 0.3, 1.0)  # Slightly lighter gray for hover, zero glow
	style_hover.border_width_left = 3
	style_hover.border_width_right = 3
	style_hover.border_width_top = 3
	style_hover.border_width_bottom = 3

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = color.darkened(0.7)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_normal.duplicate())

	# Create custom label layout inside button
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)

	# Title label at top
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	# Cost label in center
	var cost_label = Label.new()
	cost_label.text = cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color.WHITE)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)

	# Spacer to push description down (fixed height for consistency)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_FILL
	spacer.custom_minimum_size = Vector2(0, 40)  # Fixed height for uniform button layout
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# Description label at bottom
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 13)  # Increased from 9px to 13px for readability
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# Add top/bottom margin
	vbox.add_theme_constant_override("margin_top", 8)
	vbox.add_theme_constant_override("margin_bottom", 8)

	button.add_child(vbox)

	return button

## Adds special visual effects to a summon button based on type
static func add_special_effects(button: Button, color: Color, summon_type: String):
	match summon_type:
		"basic":
			add_shimmer_effect(button, color.lightened(0.3))
		"premium":
			add_sparkle_effect(button, Color.GOLD)
			add_pulse_effect(button, Color.GOLD)
		"element":
			add_swirl_effect(button, color)
		"crystal":
			add_sparkle_effect(button, Color.CYAN)
			add_shimmer_effect(button, Color.CYAN)
		"daily_free":
			add_sparkle_effect(button, Color.GREEN)

## Adds a shimmer gradient effect to a button
static func add_shimmer_effect(button: Button, shimmer_color: Color):
	var shimmer = ColorRect.new()
	shimmer.color = shimmer_color
	shimmer.color.a = 0.1
	shimmer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shimmer.size = Vector2(20, button.custom_minimum_size.y)
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shimmer)
	shimmer.move_to_front()

## Adds sparkle particles effect to a button
static func add_sparkle_effect(button: Button, sparkle_color: Color):
	var sparkle = ColorRect.new()
	sparkle.color = sparkle_color
	sparkle.color.a = 0.3
	sparkle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sparkle.size = Vector2(10, 10)
	sparkle.position = Vector2(button.custom_minimum_size.x - 15, 5)
	sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(sparkle)

## Adds a pulsing border effect to a button
static func add_pulse_effect(_button: Button, _pulse_color: Color):
	# Pulse effect is handled by hover states
	pass

## Adds a swirl gradient effect to a button
static func add_swirl_effect(button: Button, swirl_color: Color):
	var swirl = ColorRect.new()
	swirl.color = swirl_color
	swirl.color.a = 0.15
	swirl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	swirl.size = Vector2(button.custom_minimum_size.x, 30)
	swirl.position.y = button.custom_minimum_size.y - 30
	swirl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(swirl)
