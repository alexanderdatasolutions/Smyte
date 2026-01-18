# scripts/ui/summon/SummonBannerCard.gd
# RULE 1: UI component - displays summon banner with pity progress and resource checks
# RULE 2: Single responsibility - banner card display and interaction only
class_name SummonBannerCard
extends PanelContainer

signal single_summon_pressed(banner_data: Dictionary)
signal multi_summon_pressed(banner_data: Dictionary)

# Banner configuration
var banner_data: Dictionary = {}
var banner_type: String = "default"
var single_cost: Dictionary = {}
var multi_cost: Dictionary = {}
var multi_count: int = 10

# UI references
var title_label: Label
var description_label: Label
var rates_label: Label
var single_button: Button
var multi_button: Button
var pity_progress: ProgressBar
var pity_label: Label
var cost_label: Label
var free_badge: Label
var timer_label: Label
var _timer_update_active: bool = false

func _init():
	custom_minimum_size = Vector2(280, 220)

func _ready():
	_setup_ui()
	_apply_style()
	_update_display()

func _setup_ui():
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	# Title row with FREE badge
	var title_row = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(title_row)

	# Title
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 2)
	title_row.add_child(title_label)

	# FREE badge (shown when daily free is available)
	free_badge = Label.new()
	free_badge.text = " FREE!"
	free_badge.add_theme_font_size_override("font_size", 14)
	free_badge.add_theme_color_override("font_color", Color.LIME)
	free_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	free_badge.add_theme_constant_override("outline_size", 2)
	free_badge.visible = false
	title_row.add_child(free_badge)

	# Description with rates
	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(description_label)

	# Rates display
	rates_label = Label.new()
	rates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rates_label.add_theme_font_size_override("font_size", 10)
	rates_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	main_vbox.add_child(rates_label)

	# Pity progress section
	var pity_container = VBoxContainer.new()
	pity_container.add_theme_constant_override("separation", 2)
	main_vbox.add_child(pity_container)

	pity_label = Label.new()
	pity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pity_label.add_theme_font_size_override("font_size", 10)
	pity_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	pity_container.add_child(pity_label)

	pity_progress = ProgressBar.new()
	pity_progress.custom_minimum_size = Vector2(0, 12)
	pity_progress.show_percentage = false
	pity_progress.max_value = 100
	pity_progress.value = 0
	_style_progress_bar(pity_progress)
	pity_container.add_child(pity_progress)

	# Cost display
	cost_label = Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	main_vbox.add_child(cost_label)

	# Timer label for daily free (shows countdown when not available)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 11)
	timer_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	timer_label.visible = false
	main_vbox.add_child(timer_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	# Buttons container
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_container)

	# Single summon button
	single_button = Button.new()
	single_button.text = "Summon 1x"
	single_button.custom_minimum_size = Vector2(100, 36)
	single_button.pressed.connect(_on_single_pressed)
	_style_button(single_button, false)
	button_container.add_child(single_button)

	# Multi summon button
	multi_button = Button.new()
	multi_button.text = "Summon 10x"
	multi_button.custom_minimum_size = Vector2(100, 36)
	multi_button.pressed.connect(_on_multi_pressed)
	_style_button(multi_button, true)
	button_container.add_child(multi_button)

func _apply_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

func _style_progress_bar(bar: ProgressBar):
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	bg_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.6, 0.2, 0.9)
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)

func _style_button(button: Button, is_multi: bool):
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.15, 0.3) if is_multi else Color(0.15, 0.12, 0.2)
	normal.border_color = Color(0.5, 0.4, 0.6) if is_multi else Color(0.4, 0.35, 0.5)
	normal.set_border_width_all(2 if is_multi else 1)
	normal.set_corner_radius_all(8)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	normal.shadow_size = 2
	button.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = hover.bg_color.lightened(0.2)
	hover.border_color = Color(0.7, 0.6, 0.9) if is_multi else Color(0.6, 0.55, 0.7)
	hover.set_border_width_all(2)
	hover.shadow_color = Color(0.4, 0.3, 0.6, 0.4) if is_multi else Color(0.3, 0.25, 0.4, 0.3)
	hover.shadow_size = 4
	button.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	pressed.bg_color = pressed.bg_color.darkened(0.15)
	pressed.shadow_size = 0
	button.add_theme_stylebox_override("pressed", pressed)

	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	disabled.border_color = Color(0.2, 0.2, 0.2, 0.4)
	disabled.shadow_size = 0
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.85, 0.75))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	button.mouse_entered.connect(_on_button_hover.bind(button))
	button.mouse_exited.connect(_on_button_unhover.bind(button))

func _on_button_hover(button: Button):
	if button.disabled:
		return
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_QUAD)

func _on_button_unhover(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD)

## Configure the banner card with data
func configure(data: Dictionary):
	banner_data = data
	banner_type = data.get("banner_type", "default")
	single_cost = data.get("single_cost", {})
	multi_cost = data.get("multi_cost", {})
	multi_count = data.get("multi_count", 10)
	_update_display()

func _update_display():
	if not is_inside_tree():
		return

	# Update title
	if title_label:
		title_label.text = banner_data.get("title", "SUMMON")

	# Update description
	if description_label:
		description_label.text = banner_data.get("description", "")

	# Update rates display
	if rates_label:
		var rates = banner_data.get("rates", {})
		if not rates.is_empty():
			var rate_text = "Rates: "
			var parts = []
			if rates.has("legendary") and rates.legendary > 0:
				parts.append("Leg %.1f%%" % rates.legendary)
			if rates.has("epic") and rates.epic > 0:
				parts.append("Epic %.1f%%" % rates.epic)
			if rates.has("rare") and rates.rare > 0:
				parts.append("Rare %.1f%%" % rates.rare)
			rates_label.text = rate_text + " | ".join(parts)
		else:
			rates_label.text = ""

	# Update cost display
	if cost_label:
		var cost_text = _format_cost(single_cost)
		if not multi_cost.is_empty():
			var discount = banner_data.get("multi_discount", "10% OFF")
			cost_text += " | 10x: " + _format_cost(multi_cost) + " (" + discount + ")"
		cost_label.text = cost_text

	# Update pity progress
	_update_pity_display()

	# Update button states
	_update_button_states()

func _format_cost(cost: Dictionary) -> String:
	var parts = []
	for resource in cost:
		var display_name = resource.replace("_", " ").capitalize()
		if resource == "divine_crystals":
			display_name = "Crystals"
		elif resource.ends_with("_soul"):
			display_name = resource.replace("_soul", "").capitalize() + " Soul"
		parts.append("%d %s" % [cost[resource], display_name])
	return ", ".join(parts) if parts.size() > 0 else "FREE"

func _update_pity_display():
	if not pity_label or not pity_progress:
		return

	var summon_manager = _get_summon_manager()
	if not summon_manager:
		pity_label.text = "Pity: --"
		pity_progress.value = 0
		return

	# Get legendary pity (most important)
	var legendary_pity = summon_manager.get_pity_counter(banner_type, "legendary")
	var legendary_threshold = 100

	# Get config for threshold
	var config = summon_manager.get_config()
	if config.has("summon_configuration"):
		var thresholds = config.summon_configuration.get("pity_system", {}).get("thresholds", {})
		legendary_threshold = thresholds.get("legendary", 100)

	pity_label.text = "Legendary Pity: %d/%d" % [legendary_pity, legendary_threshold]
	pity_progress.max_value = legendary_threshold
	pity_progress.value = legendary_pity

	# Color based on soft pity
	var soft_pity_start = 75
	if config.has("summon_configuration"):
		var soft = config.summon_configuration.get("pity_system", {}).get("soft_pity", {}).get("legendary", {})
		soft_pity_start = soft.get("starts_at", 75)

	var fill_style = StyleBoxFlat.new()
	fill_style.set_corner_radius_all(4)
	if legendary_pity >= soft_pity_start:
		fill_style.bg_color = Color(1.0, 0.6, 0.1, 0.9)  # Orange for soft pity
	elif legendary_pity >= legendary_threshold * 0.5:
		fill_style.bg_color = Color(0.9, 0.8, 0.2, 0.9)  # Yellow for halfway
	else:
		fill_style.bg_color = Color(0.4, 0.6, 0.8, 0.9)  # Blue for normal
	pity_progress.add_theme_stylebox_override("fill", fill_style)

func _update_button_states():
	if not single_button or not multi_button:
		return

	var can_afford_single = _can_afford(single_cost)
	var can_afford_multi = _can_afford(multi_cost)
	var is_daily_free = banner_data.get("is_daily_free", false)
	var daily_free_available = true

	# Check daily free availability and update UI elements
	if is_daily_free:
		var summon_manager = _get_summon_manager()
		if summon_manager:
			daily_free_available = summon_manager.can_use_daily_free_summon()
			if not daily_free_available:
				can_afford_single = false
				can_afford_multi = false

			# Update FREE badge visibility
			if free_badge:
				free_badge.visible = daily_free_available

			# Update timer visibility and text
			_update_timer_display(summon_manager, daily_free_available)

	single_button.disabled = not can_afford_single
	multi_button.disabled = not can_afford_multi

	# Hide multi button for daily free (only single summon allowed)
	if is_daily_free:
		multi_button.visible = false

	# Update button text with cost hint if disabled
	if not can_afford_single:
		if is_daily_free and not daily_free_available:
			single_button.tooltip_text = "Already used today - resets at midnight UTC"
		else:
			single_button.tooltip_text = "Insufficient resources"
	else:
		single_button.tooltip_text = ""

	if not can_afford_multi:
		multi_button.tooltip_text = "Insufficient resources"
	else:
		multi_button.tooltip_text = ""

func _update_timer_display(summon_manager, is_available: bool):
	"""Update the timer label for daily free summon"""
	if not timer_label:
		return

	if is_available:
		timer_label.visible = false
		_stop_timer_updates()
	else:
		timer_label.visible = true
		if summon_manager and summon_manager.has_method("get_time_until_free_summon_formatted"):
			timer_label.text = "Next free in: " + summon_manager.get_time_until_free_summon_formatted()
			_start_timer_updates()
		else:
			timer_label.text = "Resets at midnight UTC"

func _start_timer_updates():
	"""Start updating the timer every second"""
	if _timer_update_active:
		return
	_timer_update_active = true
	_update_timer_loop()

func _stop_timer_updates():
	"""Stop the timer update loop"""
	_timer_update_active = false

func _update_timer_loop():
	"""Timer update loop - runs every second while timer is visible"""
	if not _timer_update_active or not is_inside_tree():
		return

	var summon_manager = _get_summon_manager()
	if summon_manager:
		if summon_manager.can_use_daily_free_summon():
			# Timer expired, refresh everything
			_timer_update_active = false
			refresh()
			return

		if summon_manager.has_method("get_time_until_free_summon_formatted"):
			timer_label.text = "Next free in: " + summon_manager.get_time_until_free_summon_formatted()

	# Schedule next update
	get_tree().create_timer(1.0).timeout.connect(_update_timer_loop)

func _can_afford(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true

	var resource_manager = _get_resource_manager()
	if not resource_manager:
		return false

	for resource in cost:
		if resource_manager.get_resource(resource) < cost[resource]:
			return false
	return true

func _get_summon_manager():
	var registry = SystemRegistry.get_instance()
	return registry.get_system("SummonManager") if registry else null

func _get_resource_manager():
	var registry = SystemRegistry.get_instance()
	return registry.get_system("ResourceManager") if registry else null

func _on_single_pressed():
	single_summon_pressed.emit(banner_data)

func _on_multi_pressed():
	multi_summon_pressed.emit(banner_data)

## Refresh resource availability (call when resources change)
func refresh():
	_update_pity_display()
	_update_button_states()

## Set banner accent color
func set_accent_color(color: Color):
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.border_color = color.darkened(0.3)
		add_theme_stylebox_override("panel", style)

	if title_label:
		title_label.add_theme_color_override("font_color", color.lightened(0.3))
