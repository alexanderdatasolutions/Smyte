# scripts/ui/screens/SummonScreen.gd
# Summon Screen - Supports all summon types from summon_config.json
extends Control

const _SummonShowcaseClass = preload("res://scripts/ui/summon/SummonShowcase.gd")
const _SummonAnimationClass = preload("res://scripts/ui/summon/SummonAnimation.gd")
const _SummonResultOverlayClass = preload("res://scripts/ui/summon/SummonResultOverlay.gd")
const _SummonHistoryPanelClass = preload("res://scripts/ui/summon/SummonHistoryPanel.gd")

signal back_pressed

# UI Components
var summon_animation
var result_overlay
var history_panel
var showcase: SummonShowcase
var showcase_grid: GridContainer

# Tab system
var tab_buttons: Dictionary = {}  # tab_id -> Button
var tab_panels: Dictionary = {}   # tab_id -> Control
var current_tab: String = "crystal"

# Summon type selections
var selected_soul_type: String = "common_soul"
var selected_element: String = "fire"
var selected_pantheon: String = "greek"

# State
var is_processing_summon: bool = false
var pending_summon_results: Array[God] = []
var current_summon_was_multi: bool = false

# Summon config cache
var _summon_config: Dictionary = {}

func _ready():
	_load_summon_config()
	_setup_fullscreen()
	await get_tree().process_frame
	_create_ui()
	_setup_summon_animation()
	_setup_result_overlay()
	_setup_history_panel()
	_connect_signals()
	_setup_header()
	_switch_tab("crystal")

func _load_summon_config():
	var config_mgr = _get_config_manager()
	if config_mgr:
		_summon_config = config_mgr.get_summon_config()
	if _summon_config.is_empty():
		var file = FileAccess.open("res://data/summon_config.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_summon_config = json.get_data()
			file.close()

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
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 15
	main_vbox.offset_top = 60
	main_vbox.offset_right = -15
	main_vbox.offset_bottom = -15
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	var tab_bar = _create_tab_bar()
	main_vbox.add_child(tab_bar)

	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)

	var left_panel = _create_left_panel()
	left_panel.custom_minimum_size.x = 400
	content_hbox.add_child(left_panel)

	var right_panel = _create_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_panel)

func _create_tab_bar() -> Control:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 5)

	var tabs = [
		{"id": "crystal", "label": "Divine", "icon": ""},
		{"id": "soul", "label": "Soul", "icon": ""},
		{"id": "element", "label": "Element", "icon": ""},
		{"id": "pantheon", "label": "Pantheon", "icon": ""},
		{"id": "free", "label": "Free", "icon": ""},
		{"id": "mana", "label": "Mana", "icon": ""}
	]

	for tab in tabs:
		var btn = Button.new()
		btn.text = tab.label
		btn.custom_minimum_size = Vector2(90, 35)
		btn.pressed.connect(_switch_tab.bind(tab.id))
		_style_tab_button(btn, false)
		hbox.add_child(btn)
		tab_buttons[tab.id] = btn

	return hbox

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

	var container = Control.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(container)

	tab_panels["crystal"] = _create_crystal_panel()
	tab_panels["soul"] = _create_soul_panel()
	tab_panels["element"] = _create_element_panel()
	tab_panels["pantheon"] = _create_pantheon_panel()
	tab_panels["free"] = _create_free_panel()
	tab_panels["mana"] = _create_mana_panel()

	for tab_id in tab_panels:
		var p = tab_panels[tab_id]
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		container.add_child(p)

	return panel

func _create_crystal_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	vbox.add_child(_create_title_label("DIVINE SUMMON", "Use Divine Crystals for random gods"))
	var rates = _get_rates("crystal_summon")
	vbox.add_child(_create_rates_label(rates))
	vbox.add_child(HSeparator.new())

	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "Cost: 100 Crystals (x1) | 900 Crystals (x10)"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(cost_label)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_vbox)

	var single_btn = Button.new()
	single_btn.name = "SingleBtn"
	single_btn.text = "SUMMON x1  (100 Crystals)"
	single_btn.custom_minimum_size = Vector2(0, 50)
	single_btn.pressed.connect(_on_crystal_single_pressed)
	_style_button(single_btn, true)
	btn_vbox.add_child(single_btn)

	var multi_btn = Button.new()
	multi_btn.name = "MultiBtn"
	multi_btn.text = "SUMMON x10  (900 Crystals)  10% OFF"
	multi_btn.custom_minimum_size = Vector2(0, 50)
	multi_btn.pressed.connect(_on_crystal_multi_pressed)
	_style_button(multi_btn, true)
	btn_vbox.add_child(multi_btn)

	var pity_label = Label.new()
	pity_label.name = "PityLabel"
	pity_label.text = "Pity: Guaranteed Legendary at 100 summons"
	pity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pity_label.add_theme_font_size_override("font_size", 10)
	pity_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(pity_label)

	_add_spacer_and_history(vbox)
	return vbox

func _create_soul_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	vbox.add_child(_create_title_label("SOUL SUMMON", "Use souls for guaranteed rarity"))
	vbox.add_child(HSeparator.new())

	var soul_label = Label.new()
	soul_label.text = "SELECT SOUL TYPE:"
	soul_label.add_theme_font_size_override("font_size", 12)
	soul_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(soul_label)

	var soul_grid = GridContainer.new()
	soul_grid.columns = 2
	soul_grid.add_theme_constant_override("h_separation", 8)
	soul_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(soul_grid)

	var souls = [
		{"id": "common_soul", "label": "Common Soul", "color": Color(0.6, 0.6, 0.6), "desc": "Standard rates"},
		{"id": "rare_soul", "label": "Rare Soul", "color": Color(0.3, 0.6, 1.0), "desc": "Rare+ guaranteed"},
		{"id": "epic_soul", "label": "Epic Soul", "color": Color(0.7, 0.3, 0.9), "desc": "Epic+ guaranteed"},
		{"id": "legendary_soul", "label": "Legendary Soul", "color": Color(1.0, 0.8, 0.2), "desc": "Legendary guaranteed"}
	]

	for soul in souls:
		var btn = Button.new()
		btn.name = soul.id + "_btn"
		btn.text = soul.label
		btn.tooltip_text = soul.desc
		btn.custom_minimum_size = Vector2(150, 40)
		btn.pressed.connect(_on_soul_type_selected.bind(soul.id))
		_style_soul_button(btn, soul.color, soul.id == selected_soul_type)
		soul_grid.add_child(btn)

	var rates_label = Label.new()
	rates_label.name = "SoulRatesLabel"
	rates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rates_label.add_theme_font_size_override("font_size", 11)
	rates_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(rates_label)

	var summon_btn = Button.new()
	summon_btn.name = "SoulSummonBtn"
	summon_btn.text = "SUMMON WITH SOUL"
	summon_btn.custom_minimum_size = Vector2(0, 50)
	summon_btn.pressed.connect(_on_soul_summon_pressed)
	_style_button(summon_btn, true)
	vbox.add_child(summon_btn)

	_add_spacer_and_history(vbox)
	return vbox

func _create_element_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	vbox.add_child(_create_title_label("ELEMENT SUMMON", "Focus summons on a specific element"))
	var rates = _get_rates("element_summon")
	vbox.add_child(_create_rates_label(rates))
	vbox.add_child(HSeparator.new())

	var elem_label = Label.new()
	elem_label.text = "SELECT ELEMENT:"
	elem_label.add_theme_font_size_override("font_size", 12)
	elem_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(elem_label)

	var elem_row = HBoxContainer.new()
	elem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	elem_row.add_theme_constant_override("separation", 8)
	vbox.add_child(elem_row)

	var elements = [
		{"id": "fire", "icon": "F", "color": Color(1.0, 0.4, 0.3)},
		{"id": "water", "icon": "W", "color": Color(0.3, 0.6, 1.0)},
		{"id": "earth", "icon": "E", "color": Color(0.6, 0.4, 0.2)},
		{"id": "lightning", "icon": "L", "color": Color(1.0, 1.0, 0.3)},
		{"id": "light", "icon": "Lt", "color": Color(1.0, 1.0, 0.8)},
		{"id": "dark", "icon": "D", "color": Color(0.5, 0.3, 0.7)}
	]

	for elem in elements:
		var btn = Button.new()
		btn.name = elem.id + "_elem_btn"
		btn.text = elem.icon
		btn.tooltip_text = elem.id.capitalize() + " Element"
		btn.custom_minimum_size = Vector2(50, 45)
		btn.pressed.connect(_on_element_selected.bind(elem.id))
		_style_element_button(btn, elem.color, elem.id == selected_element)
		elem_row.add_child(btn)

	var cost_label = Label.new()
	cost_label.name = "ElementCostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(cost_label)

	var summon_btn = Button.new()
	summon_btn.name = "ElementSummonBtn"
	summon_btn.text = "SUMMON (150 Crystals + 10 Powder)"
	summon_btn.custom_minimum_size = Vector2(0, 50)
	summon_btn.pressed.connect(_on_element_summon_pressed)
	_style_button(summon_btn, true)
	vbox.add_child(summon_btn)

	_add_spacer_and_history(vbox)
	return vbox

func _create_pantheon_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	vbox.add_child(_create_title_label("PANTHEON SUMMON", "Focus summons on a specific pantheon"))
	var rates = _get_rates("pantheon_summon")
	vbox.add_child(_create_rates_label(rates))
	vbox.add_child(HSeparator.new())

	var panth_label = Label.new()
	panth_label.text = "SELECT PANTHEON:"
	panth_label.add_theme_font_size_override("font_size", 12)
	panth_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(panth_label)

	var panth_grid = GridContainer.new()
	panth_grid.columns = 4
	panth_grid.add_theme_constant_override("h_separation", 6)
	panth_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(panth_grid)

	var pantheons = ["greek", "norse", "egyptian", "celtic", "japanese", "hindu", "aztec", "slavic"]
	var panth_abbr = {"greek": "GRK", "norse": "NRS", "egyptian": "EGY", "celtic": "CLT", "japanese": "JPN", "hindu": "HND", "aztec": "AZT", "slavic": "SLV"}

	for panth in pantheons:
		var btn = Button.new()
		btn.name = panth + "_panth_btn"
		btn.text = panth_abbr.get(panth, panth.substr(0, 3).to_upper())
		btn.tooltip_text = panth.capitalize()
		btn.custom_minimum_size = Vector2(60, 40)
		btn.pressed.connect(_on_pantheon_selected.bind(panth))
		_style_pantheon_button(btn, panth == selected_pantheon)
		panth_grid.add_child(btn)

	var cost_label = Label.new()
	cost_label.name = "PantheonCostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(cost_label)

	var summon_btn = Button.new()
	summon_btn.name = "PantheonSummonBtn"
	summon_btn.text = "SUMMON (150 Crystals + 1 Token)"
	summon_btn.custom_minimum_size = Vector2(0, 50)
	summon_btn.pressed.connect(_on_pantheon_summon_pressed)
	_style_button(summon_btn, true)
	vbox.add_child(summon_btn)

	_add_spacer_and_history(vbox)
	return vbox

func _create_free_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	vbox.add_child(_create_title_label("FREE DAILY SUMMON", "One free summon every 24 hours"))
	var rates = _get_rates("free_daily")
	vbox.add_child(_create_rates_label(rates))
	vbox.add_child(HSeparator.new())

	var status_label = Label.new()
	status_label.name = "FreeStatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(status_label)

	var summon_btn = Button.new()
	summon_btn.name = "FreeSummonBtn"
	summon_btn.text = "FREE SUMMON"
	summon_btn.custom_minimum_size = Vector2(0, 60)
	summon_btn.pressed.connect(_on_free_summon_pressed)
	_style_button(summon_btn, true)
	vbox.add_child(summon_btn)

	_add_spacer_and_history(vbox)
	return vbox

func _create_mana_panel() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	vbox.add_child(_create_title_label("MANA SUMMON", "Spend mana for basic summons - mainly for fodder"))
	var rates = _get_rates("mana_summon")
	vbox.add_child(_create_rates_label(rates))
	vbox.add_child(HSeparator.new())

	var cost_label = Label.new()
	cost_label.name = "ManaCostLabel"
	cost_label.text = "Cost: 10,000 Mana per summon"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(cost_label)

	var summon_btn = Button.new()
	summon_btn.name = "ManaSummonBtn"
	summon_btn.text = "SUMMON (10,000 Mana)"
	summon_btn.custom_minimum_size = Vector2(0, 50)
	summon_btn.pressed.connect(_on_mana_summon_pressed)
	_style_button(summon_btn, true)
	vbox.add_child(summon_btn)

	_add_spacer_and_history(vbox)
	return vbox

func _add_spacer_and_history(vbox: VBoxContainer):
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var history_btn = Button.new()
	history_btn.text = "Summon History"
	history_btn.custom_minimum_size = Vector2(0, 35)
	history_btn.pressed.connect(_on_history_pressed)
	_style_button(history_btn, false)
	vbox.add_child(history_btn)

func _create_title_label(title: String, subtitle: String) -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(sub_lbl)

	return vbox

func _create_rates_label(rates: Dictionary) -> Label:
	var label = Label.new()
	var parts = []
	if rates.has("common"): parts.append("Common %.0f%%" % rates.common)
	if rates.has("rare"): parts.append("Rare %.0f%%" % rates.rare)
	if rates.has("epic"): parts.append("Epic %.1f%%" % rates.epic)
	if rates.has("legendary"): parts.append("Legendary %.1f%%" % rates.legendary)
	label.text = " | ".join(parts)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	return label

func _get_rates(summon_type: String) -> Dictionary:
	var default = {"common": 60.0, "rare": 30.0, "epic": 8.5, "legendary": 1.5}
	if _summon_config.has("summon_types"):
		var type_data = _summon_config.summon_types.get(summon_type, {})
		if type_data.has("rates"):
			return type_data.rates
	return default

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

	var header = Label.new()
	header.text = "RECENT SUMMONS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(header)

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

func _switch_tab(tab_id: String):
	current_tab = tab_id
	for id in tab_buttons:
		_style_tab_button(tab_buttons[id], id == tab_id)
	for id in tab_panels:
		tab_panels[id].visible = (id == tab_id)
	_refresh_ui()

# === SUMMON ACTIONS ===

func _on_crystal_single_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()
	if summon_mgr.has_method("clear_duplicate_tracking"):
		summon_mgr.clear_duplicate_tracking()
	if not summon_mgr.summon_premium():
		is_processing_summon = false
		_refresh_ui()

func _on_crystal_multi_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	is_processing_summon = true
	current_summon_was_multi = true
	pending_summon_results.clear()
	if summon_mgr.has_method("clear_duplicate_tracking"):
		summon_mgr.clear_duplicate_tracking()
	if not summon_mgr.multi_summon_premium(10):
		is_processing_summon = false
		_refresh_ui()

func _on_soul_summon_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()
	if not summon_mgr.summon_with_soul(selected_soul_type):
		is_processing_summon = false
		_refresh_ui()

func _on_element_summon_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()
	if not summon_mgr.summon_premium_with_powder(selected_element):
		is_processing_summon = false
		_refresh_ui()

func _on_pantheon_summon_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	if summon_mgr.has_method("summon_with_pantheon_token"):
		is_processing_summon = true
		current_summon_was_multi = false
		pending_summon_results.clear()
		if not summon_mgr.summon_with_pantheon_token(selected_pantheon):
			is_processing_summon = false
			_refresh_ui()
	else:
		_show_message("Pantheon summon coming soon!")

func _on_free_summon_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	if not summon_mgr.can_use_daily_free_summon():
		var time_str = summon_mgr.get_time_until_free_summon_formatted()
		_show_message("Available in: " + time_str)
		return
	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()
	if not summon_mgr.summon_free_daily():
		is_processing_summon = false
		_refresh_ui()

func _on_mana_summon_pressed():
	if is_processing_summon: return
	var summon_mgr = _get_summon_manager()
	if not summon_mgr:
		_show_message("Summon system not available")
		return
	is_processing_summon = true
	current_summon_was_multi = false
	pending_summon_results.clear()
	if not summon_mgr.summon_basic():
		is_processing_summon = false
		_refresh_ui()

func _on_soul_type_selected(soul_type: String):
	selected_soul_type = soul_type
	_update_soul_panel()

func _on_element_selected(element: String):
	selected_element = element
	_update_element_panel()

func _on_pantheon_selected(pantheon: String):
	selected_pantheon = pantheon
	_update_pantheon_panel()

func _on_history_pressed():
	if history_panel:
		history_panel.show_panel()

# === SUMMON CALLBACKS ===

func _on_god_summoned(god: God):
	_add_to_showcase(god)
	pending_summon_results.clear()
	is_processing_summon = false
	_refresh_ui()

func _on_multi_summon_completed(gods: Array):
	for god in gods:
		_add_to_showcase(god)
		pending_summon_results.append(god)
	is_processing_summon = false
	_refresh_ui()
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
	match current_tab:
		"crystal":
			if current_summon_was_multi: _on_crystal_multi_pressed()
			else: _on_crystal_single_pressed()
		"soul": _on_soul_summon_pressed()
		"element": _on_element_summon_pressed()
		"pantheon": _on_pantheon_summon_pressed()
		"free": _on_free_summon_pressed()
		"mana": _on_mana_summon_pressed()

func _on_result_closed():
	_refresh_ui()

func _on_back_pressed():
	if showcase:
		showcase.clear()
	back_pressed.emit()

# === REFRESH ===

func _add_to_showcase(god: God):
	if showcase:
		showcase.show_god(god, false)

func _refresh_ui():
	match current_tab:
		"crystal": _update_crystal_panel()
		"soul": _update_soul_panel()
		"element": _update_element_panel()
		"pantheon": _update_pantheon_panel()
		"free": _update_free_panel()
		"mana": _update_mana_panel()

func _update_crystal_panel():
	var panel = tab_panels.get("crystal")
	if not panel: return
	var resource_mgr = _get_resource_manager()
	var crystals = resource_mgr.get_resource("divine_crystals") if resource_mgr else 0
	var single_btn = panel.find_child("SingleBtn", true, false)
	if single_btn:
		single_btn.disabled = crystals < 100 or is_processing_summon
	var multi_btn = panel.find_child("MultiBtn", true, false)
	if multi_btn:
		multi_btn.disabled = crystals < 900 or is_processing_summon

func _update_soul_panel():
	var panel = tab_panels.get("soul")
	if not panel: return
	var resource_mgr = _get_resource_manager()
	var souls = ["common_soul", "rare_soul", "epic_soul", "legendary_soul"]
	var soul_colors = {
		"common_soul": Color(0.6, 0.6, 0.6),
		"rare_soul": Color(0.3, 0.6, 1.0),
		"epic_soul": Color(0.7, 0.3, 0.9),
		"legendary_soul": Color(1.0, 0.8, 0.2)
	}
	for soul_type in souls:
		var btn = panel.find_child(soul_type + "_btn", true, false)
		if btn:
			_style_soul_button(btn, soul_colors[soul_type], soul_type == selected_soul_type)
	var rates_label = panel.find_child("SoulRatesLabel", true, false)
	if rates_label:
		var rates = {}
		if _summon_config.has("summon_types"):
			var soul_cfg = _summon_config.summon_types.get("soul_summon", {})
			var variants = soul_cfg.get("variants", {})
			rates = variants.get(selected_soul_type, {}).get("rates", {})
		if rates.is_empty():
			rates_label.text = ""
		else:
			var parts = []
			if rates.has("common"): parts.append("Common %.0f%%" % rates.common)
			if rates.has("rare"): parts.append("Rare %.0f%%" % rates.rare)
			if rates.has("epic"): parts.append("Epic %.1f%%" % rates.epic)
			if rates.has("legendary"): parts.append("Legendary %.1f%%" % rates.legendary)
			rates_label.text = " | ".join(parts)
	var summon_btn = panel.find_child("SoulSummonBtn", true, false)
	if summon_btn:
		var owned = resource_mgr.get_resource(selected_soul_type) if resource_mgr else 0
		summon_btn.text = "SUMMON WITH %s (%d owned)" % [selected_soul_type.replace("_", " ").capitalize(), owned]
		summon_btn.disabled = owned < 1 or is_processing_summon

func _update_element_panel():
	var panel = tab_panels.get("element")
	if not panel: return
	var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
	var elem_colors = {
		"fire": Color(1.0, 0.4, 0.3), "water": Color(0.3, 0.6, 1.0),
		"earth": Color(0.6, 0.4, 0.2), "lightning": Color(1.0, 1.0, 0.3),
		"light": Color(1.0, 1.0, 0.8), "dark": Color(0.5, 0.3, 0.7)
	}
	for elem in elements:
		var btn = panel.find_child(elem + "_elem_btn", true, false)
		if btn:
			_style_element_button(btn, elem_colors[elem], elem == selected_element)
	var resource_mgr = _get_resource_manager()
	var crystals = resource_mgr.get_resource("divine_crystals") if resource_mgr else 0
	var powder_id = selected_element + "_powder"
	var powder = resource_mgr.get_resource(powder_id) if resource_mgr else 0
	var cost_label = panel.find_child("ElementCostLabel", true, false)
	if cost_label:
		cost_label.text = "Cost: 150 Crystals + 10 %s Powder (%d owned)" % [selected_element.capitalize(), powder]
	var summon_btn = panel.find_child("ElementSummonBtn", true, false)
	if summon_btn:
		summon_btn.disabled = crystals < 150 or powder < 10 or is_processing_summon

func _update_pantheon_panel():
	var panel = tab_panels.get("pantheon")
	if not panel: return
	var pantheons = ["greek", "norse", "egyptian", "celtic", "japanese", "hindu", "aztec", "slavic"]
	for panth in pantheons:
		var btn = panel.find_child(panth + "_panth_btn", true, false)
		if btn:
			_style_pantheon_button(btn, panth == selected_pantheon)
	var resource_mgr = _get_resource_manager()
	var crystals = resource_mgr.get_resource("divine_crystals") if resource_mgr else 0
	var token_id = selected_pantheon + "_token"
	var tokens = resource_mgr.get_resource(token_id) if resource_mgr else 0
	var cost_label = panel.find_child("PantheonCostLabel", true, false)
	if cost_label:
		cost_label.text = "Cost: 150 Crystals + 1 %s Token (%d owned)" % [selected_pantheon.capitalize(), tokens]
	var summon_btn = panel.find_child("PantheonSummonBtn", true, false)
	if summon_btn:
		summon_btn.disabled = crystals < 150 or tokens < 1 or is_processing_summon

func _update_free_panel():
	var panel = tab_panels.get("free")
	if not panel: return
	var summon_mgr = _get_summon_manager()
	var can_use = summon_mgr.can_use_daily_free_summon() if summon_mgr else false
	var status_label = panel.find_child("FreeStatusLabel", true, false)
	if status_label:
		if can_use:
			status_label.text = "Available Now!"
			status_label.add_theme_color_override("font_color", Color.LIME_GREEN)
		else:
			var time_str = summon_mgr.get_time_until_free_summon_formatted() if summon_mgr else "?"
			status_label.text = "Resets in: " + time_str
			status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	var summon_btn = panel.find_child("FreeSummonBtn", true, false)
	if summon_btn:
		summon_btn.disabled = not can_use or is_processing_summon

func _update_mana_panel():
	var panel = tab_panels.get("mana")
	if not panel: return
	var resource_mgr = _get_resource_manager()
	var mana = resource_mgr.get_resource("mana") if resource_mgr else 0
	var summon_btn = panel.find_child("ManaSummonBtn", true, false)
	if summon_btn:
		summon_btn.disabled = mana < 10000 or is_processing_summon

# === HELPERS ===

func _show_message(text: String):
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

func _get_config_manager():
	return SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null

# === STYLING ===

func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_tab_button(button: Button, is_active: bool):
	var style = StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.25, 0.2, 0.35, 1.0)
		style.border_color = Color.GOLD
		style.set_border_width_all(2)
		button.add_theme_color_override("font_color", Color.GOLD)
	else:
		style.bg_color = Color(0.12, 0.1, 0.16, 0.9)
		style.border_color = Color(0.3, 0.25, 0.4, 0.8)
		style.set_border_width_all(1)
		button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_font_size_override("font_size", 12)

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

func _style_soul_button(button: Button, color: Color, is_selected: bool):
	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = color.darkened(0.5)
		style.border_color = color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style.border_color = color.darkened(0.6)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_font_size_override("font_size", 11)

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
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_font_size_override("font_size", 14)

func _style_pantheon_button(button: Button, is_selected: bool):
	var style = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.3, 0.25, 0.4, 1.0)
		style.border_color = Color.GOLD
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style.border_color = Color(0.3, 0.25, 0.4, 0.8)
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_font_size_override("font_size", 11)
