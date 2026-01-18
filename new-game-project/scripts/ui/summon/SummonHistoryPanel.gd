# scripts/ui/summon/SummonHistoryPanel.gd
# RULE 1 COMPLIANCE: Under 500-line limit | RULE 2: Single responsibility (UI only)
extends Control
class_name SummonHistoryPanel

signal close_pressed

const MAX_DISPLAY_ENTRIES: int = 50
const ENTRY_HEIGHT: int = 40
const RARITY_COLORS: Dictionary = {
	"common": Color(0.7, 0.7, 0.7),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.6, 0.2, 0.8),
	"legendary": Color(1.0, 0.8, 0.2)
}

var backdrop: ColorRect
var main_panel: PanelContainer
var title_label: Label
var close_button: Button
var tabs_container: HBoxContainer
var stats_tab_btn: Button
var history_tab_btn: Button
var content_container: Control
var stats_panel: VBoxContainer
var history_panel: VBoxContainer
var history_scroll: ScrollContainer
var history_list: VBoxContainer

var current_tab: String = "stats"

func _init():
	_create_ui()

func _create_ui():
	# Fullscreen backdrop
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	# Main panel - centered
	main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.custom_minimum_size = Vector2(500, 550)
	main_panel.offset_left = -250
	main_panel.offset_right = 250
	main_panel.offset_top = -275
	main_panel.offset_bottom = 275
	add_child(main_panel)
	_style_main_panel()

	# Content VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(vbox)

	# Header with title and close button
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	title_label = Label.new()
	title_label.text = "SUMMON HISTORY"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.pressed.connect(_on_close_pressed)
	_style_close_button()
	header.add_child(close_button)

	# Tab buttons
	tabs_container = HBoxContainer.new()
	tabs_container.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs_container)

	stats_tab_btn = Button.new()
	stats_tab_btn.text = "Statistics"
	stats_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_tab_btn.pressed.connect(_on_stats_tab_pressed)
	tabs_container.add_child(stats_tab_btn)

	history_tab_btn = Button.new()
	history_tab_btn.text = "Recent Summons"
	history_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_tab_btn.pressed.connect(_on_history_tab_pressed)
	tabs_container.add_child(history_tab_btn)

	_style_tab_buttons()

	# Content area
	content_container = Control.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(content_container)

	# Stats panel
	stats_panel = VBoxContainer.new()
	stats_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_panel.add_theme_constant_override("separation", 16)
	content_container.add_child(stats_panel)

	# History panel (with scroll)
	history_panel = VBoxContainer.new()
	history_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	history_panel.visible = false
	content_container.add_child(history_panel)

	history_scroll = ScrollContainer.new()
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_panel.add_child(history_scroll)

	history_list = VBoxContainer.new()
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_list.add_theme_constant_override("separation", 4)
	history_scroll.add_child(history_list)

	# Initially hidden
	visible = false

func _style_main_panel():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.98)
	style.border_color = Color(0.5, 0.4, 0.6, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	main_panel.add_theme_stylebox_override("panel", style)

func _style_close_button():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.15, 0.15, 0.9)
	style.border_color = Color(0.6, 0.3, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	close_button.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.5, 0.2, 0.2, 0.95)
	hover.border_color = Color(0.8, 0.4, 0.4)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	close_button.add_theme_stylebox_override("hover", hover)

	close_button.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))

func _style_tab_buttons():
	for btn in [stats_tab_btn, history_tab_btn]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
		style.border_color = Color(0.4, 0.35, 0.5, 0.6)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)

		var hover = StyleBoxFlat.new()
		hover.bg_color = Color(0.22, 0.18, 0.28, 0.9)
		hover.border_color = Color(0.5, 0.45, 0.6, 0.8)
		hover.set_border_width_all(1)
		hover.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", hover)

		btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
		btn.add_theme_color_override("font_hover_color", Color(0.95, 0.9, 0.85))

func _update_tab_styles():
	"""Highlight the active tab"""
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.25, 0.2, 0.35, 0.95)
	active_style.border_color = Color(0.6, 0.5, 0.7, 1.0)
	active_style.set_border_width_all(2)
	active_style.set_corner_radius_all(6)

	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
	inactive_style.border_color = Color(0.4, 0.35, 0.5, 0.6)
	inactive_style.set_border_width_all(1)
	inactive_style.set_corner_radius_all(6)

	if current_tab == "stats":
		stats_tab_btn.add_theme_stylebox_override("normal", active_style)
		history_tab_btn.add_theme_stylebox_override("normal", inactive_style)
	else:
		stats_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		history_tab_btn.add_theme_stylebox_override("normal", active_style)

func show_panel():
	"""Show the history panel and populate data"""
	visible = true
	current_tab = "stats"
	_update_tab_styles()
	_populate_stats()
	stats_panel.visible = true
	history_panel.visible = false

	# Animate in
	main_panel.modulate = Color(1, 1, 1, 0)
	main_panel.scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(main_panel, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(main_panel, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT)

func hide_panel():
	"""Animate out and hide"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(main_panel, "modulate", Color(1, 1, 1, 0), 0.15)
	tween.tween_property(main_panel, "scale", Vector2(0.9, 0.9), 0.15)
	tween.chain().tween_callback(func(): visible = false)

func _populate_stats():
	"""Populate the statistics panel with rarity distribution and pity info"""
	# Clear existing
	for child in stats_panel.get_children():
		child.queue_free()

	var summon_manager = _get_summon_manager()
	if not summon_manager:
		var error_label = Label.new()
		error_label.text = "Unable to load summon data"
		error_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		stats_panel.add_child(error_label)
		return

	# Total summons
	var total_label = Label.new()
	total_label.text = "Total Summons: %d" % summon_manager.total_summons
	total_label.add_theme_font_size_override("font_size", 18)
	total_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	stats_panel.add_child(total_label)

	# Rarity distribution section
	var rarity_title = Label.new()
	rarity_title.text = "Rarity Distribution (Last %d)" % MAX_DISPLAY_ENTRIES
	rarity_title.add_theme_font_size_override("font_size", 16)
	rarity_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	stats_panel.add_child(rarity_title)

	var rarity_stats = summon_manager.get_rarity_stats()
	var total_in_history = 0
	for tier in rarity_stats:
		total_in_history += rarity_stats[tier]

	var rarity_container = VBoxContainer.new()
	rarity_container.add_theme_constant_override("separation", 8)
	stats_panel.add_child(rarity_container)

	for tier in ["legendary", "epic", "rare", "common"]:
		var count = rarity_stats.get(tier, 0)
		var percent = (float(count) / max(total_in_history, 1)) * 100.0
		_create_rarity_bar(rarity_container, tier, count, percent)

	# Pity counters section
	var pity_title = Label.new()
	pity_title.text = "Current Pity Progress"
	pity_title.add_theme_font_size_override("font_size", 16)
	pity_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	stats_panel.add_child(pity_title)

	var pity_container = VBoxContainer.new()
	pity_container.add_theme_constant_override("separation", 6)
	stats_panel.add_child(pity_container)

	# Get pity thresholds from config
	var config = summon_manager.get_config()
	var pity_cfg = config.get("summon_configuration", {}).get("pity_system", {})
	var thresholds = pity_cfg.get("thresholds", {"rare": 10, "epic": 50, "legendary": 100})

	for banner_type in ["default", "premium", "element"]:
		_create_pity_row(pity_container, banner_type, summon_manager, thresholds)

func _create_rarity_bar(parent: VBoxContainer, tier: String, count: int, percent: float):
	"""Create a horizontal bar showing rarity count and percentage"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Tier label
	var tier_label = Label.new()
	tier_label.text = tier.capitalize()
	tier_label.custom_minimum_size = Vector2(80, 0)
	tier_label.add_theme_color_override("font_color", RARITY_COLORS.get(tier, Color.WHITE))
	row.add_child(tier_label)

	# Progress bar background
	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(200, 20)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.15, 0.12, 0.2, 0.8)
	row.add_child(bar_bg)

	# Progress bar fill
	var bar_fill = ColorRect.new()
	bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar_fill.custom_minimum_size = Vector2(max(2, 200 * (percent / 100.0)), 20)
	bar_fill.color = RARITY_COLORS.get(tier, Color.WHITE)
	bar_fill.color.a = 0.8
	bar_bg.add_child(bar_fill)

	# Count/percent label
	var count_label = Label.new()
	count_label.text = "%d (%.1f%%)" % [count, percent]
	count_label.custom_minimum_size = Vector2(90, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7))
	row.add_child(count_label)

func _create_pity_row(parent: VBoxContainer, banner_type: String, summon_manager, thresholds: Dictionary):
	"""Create a row showing pity progress for a banner type"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Banner name
	var banner_names = {"default": "Basic", "premium": "Premium", "element": "Element"}
	var name_label = Label.new()
	name_label.text = banner_names.get(banner_type, banner_type.capitalize())
	name_label.custom_minimum_size = Vector2(70, 0)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	row.add_child(name_label)

	# Pity counters
	var legendary_count = summon_manager.get_pity_counter(banner_type, "legendary")
	var legendary_threshold = thresholds.get("legendary", 100)
	var leg_progress = float(legendary_count) / float(legendary_threshold)

	var pity_text = Label.new()
	pity_text.text = "Legendary: %d/%d" % [legendary_count, legendary_threshold]
	pity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Color based on progress
	var color = Color(0.7, 0.7, 0.7)
	if leg_progress >= 0.75:
		color = Color(1.0, 0.5, 0.2)  # Orange - soft pity
	elif leg_progress >= 0.5:
		color = Color(1.0, 0.8, 0.2)  # Yellow - halfway

	pity_text.add_theme_color_override("font_color", color)
	row.add_child(pity_text)

func _populate_history():
	"""Populate the history list with recent summons"""
	# Clear existing entries
	for child in history_list.get_children():
		child.queue_free()

	var summon_manager = _get_summon_manager()
	if not summon_manager:
		var error_label = Label.new()
		error_label.text = "Unable to load summon history"
		error_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		history_list.add_child(error_label)
		return

	var history = summon_manager.get_summon_history()
	if history.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No summons recorded yet.\nStart summoning to see history!"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		history_list.add_child(empty_label)
		return

	# Display up to MAX_DISPLAY_ENTRIES
	var display_count = min(history.size(), MAX_DISPLAY_ENTRIES)
	for i in range(display_count):
		var entry = history[i]
		_create_history_entry(entry, i)

func _create_history_entry(entry: Dictionary, index: int):
	"""Create a single history entry row"""
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ENTRY_HEIGHT)

	# Alternate row colors
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.6) if index % 2 == 0 else Color(0.14, 0.11, 0.18, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	row.add_theme_stylebox_override("panel", style)
	history_list.add_child(row)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	# Index number
	var idx_label = Label.new()
	idx_label.text = "#%d" % (index + 1)
	idx_label.custom_minimum_size = Vector2(35, 0)
	idx_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	hbox.add_child(idx_label)

	# God name
	var name_label = Label.new()
	name_label.text = entry.get("god_name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	hbox.add_child(name_label)

	# Tier badge
	var tier = entry.get("tier", "Common").to_lower()
	var tier_label = Label.new()
	tier_label.text = tier.capitalize()
	tier_label.custom_minimum_size = Vector2(80, 0)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_color_override("font_color", RARITY_COLORS.get(tier, Color.WHITE))
	hbox.add_child(tier_label)

	# Element
	var element = entry.get("element", "")
	if not element.is_empty():
		var elem_label = Label.new()
		elem_label.text = element.capitalize()
		elem_label.custom_minimum_size = Vector2(70, 0)
		elem_label.add_theme_color_override("font_color", _get_element_color(element))
		hbox.add_child(elem_label)

	# Date/time
	var date_label = Label.new()
	date_label.text = entry.get("date", "")
	date_label.custom_minimum_size = Vector2(85, 0)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	hbox.add_child(date_label)

func _get_element_color(element: String) -> Color:
	match element.to_lower():
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.3, 0.6, 1.0)
		"earth": return Color(0.6, 0.4, 0.2)
		"lightning": return Color(1.0, 0.9, 0.3)
		"light": return Color(1.0, 0.95, 0.8)
		"dark": return Color(0.5, 0.3, 0.6)
		_: return Color(0.7, 0.7, 0.7)

func _get_summon_manager():
	return SystemRegistry.get_instance().get_system("SummonManager") if SystemRegistry.get_instance() else null

func _on_stats_tab_pressed():
	current_tab = "stats"
	_update_tab_styles()
	_populate_stats()
	stats_panel.visible = true
	history_panel.visible = false

func _on_history_tab_pressed():
	current_tab = "history"
	_update_tab_styles()
	_populate_history()
	stats_panel.visible = false
	history_panel.visible = true

func _on_close_pressed():
	hide_panel()
	close_pressed.emit()

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()
