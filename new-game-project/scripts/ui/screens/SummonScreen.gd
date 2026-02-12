# scripts/ui/screens/SummonScreen.gd
# Overhauled Summon Screen - Divine Crystals + Element Powder Boost
extends Control

const _SummonShowcaseClass = preload("res://scripts/ui/summon/SummonShowcase.gd")
const _SummonAnimationClass = preload("res://scripts/ui/summon/SummonAnimation.gd")
const _SummonResultOverlayClass = preload("res://scripts/ui/summon/SummonResultOverlay.gd")
const _SummonHistoryPanelClass = preload("res://scripts/ui/summon/SummonHistoryPanel.gd")

signal back_pressed

# UI Components
var summon_animation  # SummonAnimation
var result_overlay  # SummonResultOverlay
var history_panel  # SummonHistoryPanel
var showcase: SummonShowcase
var showcase_grid: GridContainer

# Element powder UI
var selected_powder_element: String = ""  # Empty = no powder boost
var powder_buttons: Dictionary = {}  # element -> Button
var powder_cost_label: Label
var powder_boost_label: Label

# Summon buttons
var single_summon_btn: Button
var multi_summon_btn: Button
var free_summon_btn: Button

# State
var is_processing_summon: bool = false
var pending_summon_results: Array[God] = []
var current_summon_was_multi: bool = false

# Constants
const SINGLE_COST = 100
const MULTI_COST = 900
const MULTI_COUNT = 10

func _ready():
	_setup_fullscreen()
	await get_tree().process_frame
	_create_ui()
	_setup_summon_animation()
	_setup_result_overlay()
	_setup_history_panel()
	_connect_signals()
	_setup_header()

func _setup_fullscreen():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(get_viewport().get_visible_rect().size)
	position = Vector2.ZERO

func _setup_header():
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("SUMMON TEMPLE")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_setup_header()
		_refresh_ui()

func _create_ui():
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main HBox layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 15
	main_hbox.offset_top = 60
	main_hbox.offset_right = -15
	main_hbox.offset_bottom = -15
	main_hbox.add_theme_constant_override("separation", 20)
	add_child(main_hbox)

	# Left panel - Summon controls
	var left_panel = _create_left_panel()
	left_panel.custom_minimum_size.x = 380
	main_hbox.add_child(left_panel)

	# Right panel - Showcase
	var right_panel = _create_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

func _create_left_panel() -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var margin = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DIVINE SUMMONING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	# Rates info
	var rates_label = Label.new()
	rates_label.text = "Common 50% | Rare 35% | Epic 12% | Legendary 3%"
	rates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rates_label.add_theme_font_size_override("font_size", 10)
	rates_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(rates_label)

	vbox.add_child(HSeparator.new())

	# Element Powder Section
	var powder_header = Label.new()
	powder_header.text = "ELEMENT BOOST (Optional)"
	powder_header.add_theme_font_size_override("font_size", 14)
	powder_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(powder_header)

	var powder_desc = Label.new()
	powder_desc.text = "Use element powder for 2x weight on matching gods"
	powder_desc.add_theme_font_size_override("font_size", 10)
	powder_desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	powder_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(powder_desc)

	# Element buttons row
	var elements_row = HBoxContainer.new()
	elements_row.alignment = BoxContainer.ALIGNMENT_CENTER
	elements_row.add_theme_constant_override("separation", 8)
	vbox.add_child(elements_row)

	var elements = [
		{"id": "fire", "color": Color(1.0, 0.4, 0.3), "icon": "🔥"},
		{"id": "water", "color": Color(0.3, 0.6, 1.0), "icon": "💧"},
		{"id": "earth", "color": Color(0.6, 0.4, 0.2), "icon": "🌍"},
		{"id": "lightning", "color": Color(1.0, 1.0, 0.3), "icon": "⚡"},
		{"id": "light", "color": Color(1.0, 1.0, 0.8), "icon": "✨"},
		{"id": "dark", "color": Color(0.5, 0.3, 0.7), "icon": "🌑"}
	]

	for elem in elements:
		var btn = Button.new()
		btn.text = elem.icon
		btn.custom_minimum_size = Vector2(45, 40)
		btn.tooltip_text = elem.id.capitalize() + " Powder"
		btn.pressed.connect(_on_element_powder_selected.bind(elem.id))
		_style_element_button(btn, elem.color, false)
		elements_row.add_child(btn)
		powder_buttons[elem.id] = btn

	# Powder cost/status
	powder_cost_label = Label.new()
	powder_cost_label.text = "No element selected"
	powder_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powder_cost_label.add_theme_font_size_override("font_size", 11)
	powder_cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(powder_cost_label)

	# Element Favor status
	powder_boost_label = Label.new()
	powder_boost_label.text = ""
	powder_boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powder_boost_label.add_theme_font_size_override("font_size", 10)
	powder_boost_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	vbox.add_child(powder_boost_label)

	vbox.add_child(HSeparator.new())

	# Summon Buttons
	var buttons_vbox = VBoxContainer.new()
	buttons_vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons_vbox)

	# Single summon button
	single_summon_btn = Button.new()
	single_summon_btn.text = "SUMMON x1  (100 Crystals)"
	single_summon_btn.custom_minimum_size = Vector2(0, 50)
	single_summon_btn.pressed.connect(_on_single_summon_pressed)
	_style_button(single_summon_btn, true)
	buttons_vbox.add_child(single_summon_btn)

	# Multi summon button
	multi_summon_btn = Button.new()
	multi_summon_btn.text = "SUMMON x10  (900 Crystals)  10% OFF"
	multi_summon_btn.custom_minimum_size = Vector2(0, 50)
	multi_summon_btn.pressed.connect(_on_multi_summon_pressed)
	_style_button(multi_summon_btn, true)
	buttons_vbox.add_child(multi_summon_btn)

	# Free daily summon
	free_summon_btn = Button.new()
	free_summon_btn.text = "FREE DAILY SUMMON"
	free_summon_btn.custom_minimum_size = Vector2(0, 45)
	free_summon_btn.pressed.connect(_on_free_summon_pressed)
	_style_button(free_summon_btn, false)
	buttons_vbox.add_child(free_summon_btn)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# History button
	var history_btn = Button.new()
	history_btn.text = "Summon History"
	history_btn.custom_minimum_size = Vector2(0, 35)
	history_btn.pressed.connect(_on_history_pressed)
	_style_button(history_btn, false)
	vbox.add_child(history_btn)

	return panel

func _create_right_panel() -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "RECENT SUMMONS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(header)

	# Showcase scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	showcase_grid = GridContainer.new()
	showcase_grid.columns = 3
	showcase_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase_grid.add_theme_constant_override("h_separation", 10)
	showcase_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(showcase_grid)

	showcase = _SummonShowcaseClass.new(showcase_grid)

	return panel

func _setup_summon_animation():
	summon_animation = _SummonAnimationClass.new()
	summon_animation.name = "SummonAnimation"
	summon_animation.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(summon_animation)
	summon_animation.animation_completed.connect(_on_animation_completed)
	summon_animation.animation_skipped.connect(_on_animation_skipped)
	summon_animation.all_animations_completed.connect(_on_all_animations_completed)

func _setup_result_overlay():
	result_overlay = _SummonResultOverlayClass.new()
	result_overlay.name = "SummonResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(result_overlay)
	result_overlay.view_collection_pressed.connect(_on_view_collection)
	result_overlay.summon_again_pressed.connect(_on_summon_again)
	result_overlay.close_pressed.connect(_on_result_closed)

func _setup_history_panel():
	history_panel = _SummonHistoryPanelClass.new()
	history_panel.name = "SummonHistoryPanel"
	history_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(history_panel)

func _connect_signals():
	var summon_mgr = _get_summon_manager()
	if summon_mgr:
		if summon_mgr.summon_completed.is_connected(_on_god_summoned):
			summon_mgr.summon_completed.disconnect(_on_god_summoned)
		if summon_mgr.summon_failed.is_connected(_on_summon_failed):
			summon_mgr.summon_failed.disconnect(_on_summon_failed)
		if summon_mgr.multi_summon_completed.is_connected(_on_multi_summon_completed):
			summon_mgr.multi_summon_completed.disconnect(_on_multi_summon_completed)
		summon_mgr.summon_completed.connect(_on_god_summoned)
		summon_mgr.summon_failed.connect(_on_summon_failed)
		summon_mgr.multi_summon_completed.connect(_on_multi_summon_completed)

	var resource_mgr = _get_resource_manager()
	if resource_mgr:
		if resource_mgr.resource_changed.is_connected(_on_resource_changed):
			resource_mgr.resource_changed.disconnect(_on_resource_changed)
		resource_mgr.resource_changed.connect(_on_resource_changed)

# === ELEMENT POWDER SELECTION ===

func _on_element_powder_selected(element: String):
	if selected_powder_element == element:
		# Deselect
		selected_powder_element = ""
	else:
		selected_powder_element = element

	_update_powder_buttons()
	_update_powder_cost_label()

func _update_powder_buttons():
	var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
	var element_colors = {
		"fire": Color(1.0, 0.4, 0.3),
		"water": Color(0.3, 0.6, 1.0),
		"earth": Color(0.6, 0.4, 0.2),
		"lightning": Color(1.0, 1.0, 0.3),
		"light": Color(1.0, 1.0, 0.8),
		"dark": Color(0.5, 0.3, 0.7)
	}

	for elem in elements:
		if powder_buttons.has(elem):
			var is_selected = (elem == selected_powder_element)
			_style_element_button(powder_buttons[elem], element_colors[elem], is_selected)

func _update_powder_cost_label():
	if not powder_cost_label:
		return

	if selected_powder_element.is_empty():
		powder_cost_label.text = "No element selected"
		powder_cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	else:
		var summon_mgr = _get_summon_manager()
		var powder_cost = summon_mgr.get_powder_cost() if summon_mgr else 10
		var powder_id = selected_powder_element + "_powder"
		var resource_mgr = _get_resource_manager()
		var owned = resource_mgr.get_resource(powder_id) if resource_mgr else 0

		powder_cost_label.text = "%s Powder: %d cost, %d owned" % [selected_powder_element.capitalize(), powder_cost, owned]
		if owned >= powder_cost:
			powder_cost_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		else:
			powder_cost_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))

	# Update element favor status
	_update_favor_label()

func _update_favor_label():
	if not powder_boost_label:
		return

	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		powder_boost_label.text = ""
		return

	var favor_status = summon_mgr.get_element_favor_status()
	var active_favors = []
	for element in favor_status:
		if favor_status[element].active:
			active_favors.append("%s (%s)" % [element.capitalize(), favor_status[element].time_formatted])

	if active_favors.is_empty():
		powder_boost_label.text = ""
	else:
		powder_boost_label.text = "Active Favors: " + ", ".join(active_favors)

# === SUMMON ACTIONS ===

func _on_single_summon_pressed():
	if is_processing_summon:
		return

	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return

	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()

	if summon_mgr.has_method("clear_duplicate_tracking"):
		summon_mgr.clear_duplicate_tracking()

	var success: bool
	if selected_powder_element.is_empty():
		success = summon_mgr.summon_premium()
	else:
		success = summon_mgr.summon_premium_with_powder(selected_powder_element)

	if not success:
		is_processing_summon = false
		_refresh_ui()

func _on_multi_summon_pressed():
	if is_processing_summon:
		return

	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return

	is_processing_summon = true
	current_summon_was_multi = true
	pending_summon_results.clear()

	if summon_mgr.has_method("clear_duplicate_tracking"):
		summon_mgr.clear_duplicate_tracking()

	# Note: multi_summon_premium doesn't support powder yet
	# TODO: Add multi_summon_premium_with_powder if needed
	var success = summon_mgr.multi_summon_premium(MULTI_COUNT)

	if not success:
		is_processing_summon = false
		_refresh_ui()

func _on_free_summon_pressed():
	if is_processing_summon:
		return

	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return

	if not summon_mgr.can_use_daily_free_summon():
		var time_str = summon_mgr.get_time_until_free_summon_formatted()
		_show_message("Daily summon resets in: " + time_str)
		return

	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()

	var success = summon_mgr.summon_free_daily()
	if not success:
		is_processing_summon = false
		_refresh_ui()

func _on_history_pressed():
	if history_panel:
		history_panel.show_panel()

# === SUMMON CALLBACKS ===

func _on_god_summoned(god: God):
	# Direct showcase - no animation, no popup for single summons
	_add_to_showcase(god)
	pending_summon_results.clear()
	is_processing_summon = false
	_refresh_ui()

func _on_multi_summon_completed(gods: Array):
	# Direct showcase - no animation
	for god in gods:
		_add_to_showcase(god)
		pending_summon_results.append(god)
	is_processing_summon = false
	_refresh_ui()

	# Show result overlay for multi summon
	if result_overlay and pending_summon_results.size() > 0:
		var banner_data = {"id": "premium", "title": "DIVINE SUMMONING"}
		result_overlay.show_results(pending_summon_results, banner_data)
		pending_summon_results.clear()

func _on_summon_failed(reason: String):
	_show_message(reason)
	is_processing_summon = false
	_refresh_ui()

func _on_animation_completed(god: God):
	_add_to_showcase(god)
	pending_summon_results.append(god)

func _on_animation_skipped(god: God):
	_add_to_showcase(god)
	pending_summon_results.append(god)

func _on_all_animations_completed():
	is_processing_summon = false
	_refresh_ui()

	if pending_summon_results.size() > 0 and result_overlay:
		var banner_data = {"id": "premium", "title": "DIVINE SUMMONING"}
		result_overlay.show_results(pending_summon_results, banner_data)
		pending_summon_results.clear()

func _on_resource_changed(_resource_id: String, _new_amount: int, _delta: int):
	_refresh_ui()

func _on_view_collection():
	var screen_mgr = SystemRegistry.get_instance().get_system("ScreenManager") if SystemRegistry.get_instance() else null
	if screen_mgr:
		screen_mgr.change_screen("collection")

func _on_summon_again():
	if current_summon_was_multi:
		_on_multi_summon_pressed()
	else:
		_on_single_summon_pressed()

func _on_result_closed():
	_refresh_ui()

func _on_back_pressed():
	back_pressed.emit()

# === HELPERS ===

func _add_to_showcase(god: God):
	if showcase:
		showcase.show_god(god, false)

func _refresh_ui():
	_update_powder_cost_label()
	_update_summon_buttons()

func _update_summon_buttons():
	var resource_mgr = _get_resource_manager()
	var summon_mgr = _get_summon_manager()
	var crystals = resource_mgr.get_resource("divine_crystals") if resource_mgr else 0

	# Update single button
	if single_summon_btn:
		var cost = SINGLE_COST
		if not selected_powder_element.is_empty() and summon_mgr:
			cost = SINGLE_COST  # Powder cost is separate
		single_summon_btn.disabled = crystals < SINGLE_COST or is_processing_summon

	# Update multi button
	if multi_summon_btn:
		multi_summon_btn.disabled = crystals < MULTI_COST or is_processing_summon

	# Update free button
	if free_summon_btn and summon_mgr:
		var can_use_free = summon_mgr.can_use_daily_free_summon()
		free_summon_btn.disabled = not can_use_free or is_processing_summon
		if can_use_free:
			free_summon_btn.text = "FREE DAILY SUMMON"
			free_summon_btn.add_theme_color_override("font_color", Color.LIME_GREEN)
		else:
			free_summon_btn.text = "Free: " + summon_mgr.get_time_until_free_summon_formatted()
			free_summon_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))

func _show_message(text: String):
	# Simple toast message
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.ORANGE)
	label.z_index = 200
	add_child(label)
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2((viewport_size.x - label.size.x) / 2, viewport_size.y * 0.4)
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _get_summon_manager():
	return SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null

func _get_resource_manager():
	return SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null

# === STYLING ===

func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool = false):
	var style_normal = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.4, 0.5, 0.9)
		style_normal.border_color = Color(0.3, 0.6, 0.7, 0.8)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(0.1, 0.08, 0.12, 0.7)
	style_disabled.border_color = Color(0.2, 0.18, 0.25, 0.5)
	button.add_theme_stylebox_override("disabled", style_disabled)

	button.add_theme_font_size_override("font_size", 14)

func _style_element_button(button: Button, element_color: Color, is_selected: bool):
	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = element_color.darkened(0.3)
		style.border_color = element_color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style.border_color = element_color.darkened(0.5)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)

	var style_hover = style.duplicate()
	style_hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_font_size_override("font_size", 18)
