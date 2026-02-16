# scripts/ui/screens/ArenaScreen.gd
# PvP Arena screen - opponent list, player stats, defense setup
extends Control
class_name ArenaScreen

# Signals
signal back_pressed

# System references (types resolved at runtime via SystemRegistry)
var arena_manager = null  # ArenaManager instance
var screen_manager = null  # ScreenManager instance
var collection_manager = null  # CollectionManager instance

# UI References
var left_panel: PanelContainer
var right_panel: PanelContainer
var player_stats_section: VBoxContainer
var defense_section: VBoxContainer
var opponent_list_container: VBoxContainer
var leaderboard_popup: Control

# Player stats labels
var elo_label: Label
var league_label: Label
var win_rate_label: Label
var defense_power_label: Label
var defense_bonuses_container: VBoxContainer = null

# Defense team slots
var defense_team_slots: Array = []  # Array[Control]

# Opponent cards
var opponent_cards: Array = []  # Array[Control]

# Defense popup references
var defense_popup_overlay: Control = null
var defense_popup_team_slots: Array = []
var defense_popup_pending_team: Array = [null, null, null, null]
var defense_popup_gods_grid: GridContainer = null

# Defense popup sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var defense_popup_sort: SortType = SortType.POWER
var defense_popup_sort_ascending: bool = false
var defense_popup_sort_dropdown: OptionButton = null
var defense_popup_sort_btn: Button = null

# Defense popup stats display
var defense_popup_power_label: Label = null
var defense_popup_bonuses_container: VBoxContainer = null

# Current state
var selected_opponent: Dictionary = {}
var is_showing_leaderboard: bool = false

# System reference helper
func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func _ready() -> void:
	_setup_fullscreen()
	_init_systems()
	_build_ui()
	_setup_unified_header()
	_refresh_data()

func _setup_fullscreen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport_size = get_viewport().get_visible_rect().size
	set_size(viewport_size)
	position = Vector2.ZERO

func _init_systems() -> void:
	var registry = _get_system_registry()
	if not registry:
		push_error("[ArenaScreen] SystemRegistry not available")
		return

	arena_manager = registry.get_system("ArenaManager")
	screen_manager = registry.get_system("ScreenManager")
	collection_manager = registry.get_system("CollectionManager")

	# Connect to arena signals
	if arena_manager:
		arena_manager.opponents_loaded.connect(_on_opponents_loaded)
		arena_manager.defense_updated.connect(_on_defense_updated)
		arena_manager.leaderboard_loaded.connect(_on_leaderboard_loaded)
		arena_manager.battle_result_processed.connect(_on_battle_result_processed)

func _setup_unified_header() -> void:
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if visible:
		_update_header_for_screen()

func _on_visibility_changed() -> void:
	if visible:
		_update_header_for_screen()
		_refresh_data()

func _update_header_for_screen() -> void:
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("PVP ARENA")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

# ==============================================================================
# UI BUILDING
# ==============================================================================

func _build_ui() -> void:
	# Background
	var background = ColorRect.new()
	background.color = Color(0.08, 0.06, 0.12, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Main container with margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 60)  # Room for header
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	# Main horizontal split
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_hbox)

	# Left Panel (fixed width)
	left_panel = _create_left_panel()
	left_panel.custom_minimum_size = Vector2(320, 0)
	main_hbox.add_child(left_panel)

	# Right Panel (flexible)
	right_panel = _create_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

func _create_left_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	_style_panel(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Player Stats Section
	player_stats_section = _create_player_stats_section()
	vbox.add_child(player_stats_section)

	# Separator
	vbox.add_child(_create_separator())

	# Defense Team Section
	defense_section = _create_defense_section()
	vbox.add_child(defense_section)

	# Separator
	vbox.add_child(_create_separator())

	# Leaderboard Button
	var leaderboard_btn = Button.new()
	leaderboard_btn.text = "VIEW LEADERBOARD"
	leaderboard_btn.custom_minimum_size = Vector2(0, 40)
	_style_secondary_button(leaderboard_btn)
	leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	vbox.add_child(leaderboard_btn)

	# Edit Defense Button
	var edit_defense_btn = Button.new()
	edit_defense_btn.text = "SET DEFENSE TEAM"
	edit_defense_btn.custom_minimum_size = Vector2(0, 45)
	_style_primary_button(edit_defense_btn)
	edit_defense_btn.pressed.connect(_on_edit_defense_pressed)
	vbox.add_child(edit_defense_btn)

	# Post to Arena Button
	var post_btn = Button.new()
	post_btn.text = "📤 POST TO ARENA"
	post_btn.custom_minimum_size = Vector2(0, 40)
	_style_post_button(post_btn)
	post_btn.pressed.connect(_on_post_defense_pressed)
	vbox.add_child(post_btn)

	return panel

func _create_player_stats_section() -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	# Section header
	var header = Label.new()
	header.text = "YOUR STATS"
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)

	# ELO display
	var elo_hbox = HBoxContainer.new()
	var elo_title = Label.new()
	elo_title.text = "ELO Rating:"
	elo_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	elo_hbox.add_child(elo_title)

	elo_label = Label.new()
	elo_label.text = "1000"
	elo_label.add_theme_color_override("font_color", Color.GOLD)
	elo_label.add_theme_font_size_override("font_size", 18)
	elo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elo_hbox.add_child(elo_label)
	section.add_child(elo_hbox)

	# League display
	var league_hbox = HBoxContainer.new()
	var league_title = Label.new()
	league_title.text = "League:"
	league_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	league_hbox.add_child(league_title)

	league_label = Label.new()
	league_label.text = "Bronze"
	league_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.2))
	league_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	league_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	league_hbox.add_child(league_label)
	section.add_child(league_hbox)

	# Win rate
	var wr_hbox = HBoxContainer.new()
	var wr_title = Label.new()
	wr_title.text = "Win Rate:"
	wr_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	wr_hbox.add_child(wr_title)

	win_rate_label = Label.new()
	win_rate_label.text = "0%"
	win_rate_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	win_rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wr_hbox.add_child(win_rate_label)
	section.add_child(wr_hbox)

	return section

func _create_defense_section() -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	# Section header
	var header_hbox = HBoxContainer.new()
	var header = Label.new()
	header.text = "YOUR DEFENSE"
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.add_theme_font_size_override("font_size", 16)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)
	section.add_child(header_hbox)

	# Defense team slots
	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 8)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	for i in range(4):
		var slot = _create_god_slot(55, 70)
		defense_team_slots.append(slot)
		slots_hbox.add_child(slot)

	section.add_child(slots_hbox)

	# Defense power
	var power_hbox = HBoxContainer.new()
	power_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var power_label = Label.new()
	power_label.text = "Power: "
	power_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	power_hbox.add_child(power_label)

	defense_power_label = Label.new()
	defense_power_label.text = "0"
	defense_power_label.add_theme_color_override("font_color", Color.GOLD)
	power_hbox.add_child(defense_power_label)
	section.add_child(power_hbox)

	# Team bonuses display
	var bonuses_header = Label.new()
	bonuses_header.text = "Bonuses:"
	bonuses_header.add_theme_font_size_override("font_size", 11)
	bonuses_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	section.add_child(bonuses_header)

	defense_bonuses_container = VBoxContainer.new()
	defense_bonuses_container.add_theme_constant_override("separation", 2)
	section.add_child(defense_bonuses_container)

	return section

func _create_right_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	_style_panel(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header row
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)

	var header = Label.new()
	header.text = "OPPONENTS"
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.add_theme_font_size_override("font_size", 18)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(80, 30)
	_style_secondary_button(refresh_btn)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	header_hbox.add_child(refresh_btn)

	vbox.add_child(header_hbox)

	# Scroll container for opponent list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	opponent_list_container = VBoxContainer.new()
	opponent_list_container.add_theme_constant_override("separation", 10)
	opponent_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(opponent_list_container)

	vbox.add_child(scroll)

	return panel

func _create_god_slot(slot_width: float, slot_height: float) -> PanelContainer:
	var slot = PanelContainer.new()
	# Use larger size to fit god portraits
	slot.custom_minimum_size = Vector2(max(slot_width, 60), max(slot_height, 80))

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
	style.border_color = Color(0.3, 0.25, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	# Placeholder content
	var center = CenterContainer.new()
	slot.add_child(center)

	var plus_label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	plus_label.add_theme_font_size_override("font_size", 24)
	center.add_child(plus_label)

	return slot

func _create_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	return sep

func _create_opponent_card(opponent: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 110)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.9)
	style.border_color = Color(0.3, 0.25, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	card.add_child(main_vbox)

	# === TOP ROW: Basic info + buttons ===
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(top_hbox)

	# Left side: Player info
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Player name and league
	var name_hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = opponent.get("display_name", "Unknown")
	name_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	name_label.add_theme_font_size_override("font_size", 16)
	name_hbox.add_child(name_label)

	var league = opponent.get("league", "bronze")
	var league_badge = Label.new()
	league_badge.text = " [%s]" % league.capitalize()
	league_badge.add_theme_color_override("font_color", _get_league_color(league))
	league_badge.add_theme_font_size_override("font_size", 12)
	name_hbox.add_child(league_badge)
	info_vbox.add_child(name_hbox)

	# ELO and stats
	var stats_label = Label.new()
	var opp_elo = opponent.get("elo", 1000)
	var opp_wins = opponent.get("wins", 0)
	var opp_losses = opponent.get("losses", 0)
	stats_label.text = "ELO: %d  |  W/L: %d/%d" % [opp_elo, opp_wins, opp_losses]
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	stats_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(stats_label)

	# Defense team preview + Team bonuses (side by side)
	var team_row = HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 12)
	info_vbox.add_child(team_row)

	# Left: God previews
	var team_hbox = HBoxContainer.new()
	team_hbox.add_theme_constant_override("separation", 5)
	var defense_team = opponent.get("defense_team", [])
	for i in range(min(4, defense_team.size())):
		var god_data = defense_team[i]
		var mini_slot = _create_mini_god_preview(god_data)
		team_hbox.add_child(mini_slot)
	team_row.add_child(team_hbox)

	# Right: Team bonuses (vertical list with descriptions)
	var bonuses_vbox = VBoxContainer.new()
	bonuses_vbox.add_theme_constant_override("separation", 3)
	team_row.add_child(bonuses_vbox)

	# Calculate team bonuses
	var team_bonuses = _get_opponent_team_bonuses(defense_team)
	if team_bonuses.is_empty():
		var no_bonus = Label.new()
		no_bonus.text = "No bonuses"
		no_bonus.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		no_bonus.add_theme_font_size_override("font_size", 9)
		bonuses_vbox.add_child(no_bonus)
	else:
		for bonus in team_bonuses.slice(0, 3):  # Show max 3 bonuses
			var bonus_row = HBoxContainer.new()
			bonus_row.add_theme_constant_override("separation", 6)
			bonuses_vbox.add_child(bonus_row)

			var bonus_name = Label.new()
			bonus_name.text = "✦ " + bonus.get("name", "Bonus") + ":"
			bonus_name.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
			bonus_name.add_theme_font_size_override("font_size", 9)
			bonus_row.add_child(bonus_name)

			var bonus_desc = Label.new()
			bonus_desc.text = bonus.get("desc", "")
			bonus_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			bonus_desc.add_theme_font_size_override("font_size", 9)
			bonus_row.add_child(bonus_desc)

		if team_bonuses.size() > 3:
			var more_label = Label.new()
			more_label.text = "+%d more..." % (team_bonuses.size() - 3)
			more_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			more_label.add_theme_font_size_override("font_size", 8)
			bonuses_vbox.add_child(more_label)

	# Power row
	var power_label = Label.new()
	power_label.text = "⚔ Power: %s" % _format_number(opponent.get("defense_power", 0))
	power_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	power_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(power_label)

	top_hbox.add_child(info_vbox)

	# Right side: Buttons column
	var buttons_vbox = VBoxContainer.new()
	buttons_vbox.add_theme_constant_override("separation", 6)
	buttons_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# VIEW TEAM button (toggles expanded section)
	var view_btn = Button.new()
	view_btn.name = "ViewTeamBtn"
	view_btn.text = "▼ VIEW TEAM"
	view_btn.custom_minimum_size = Vector2(115, 32)
	_style_view_team_button(view_btn)
	buttons_vbox.add_child(view_btn)

	# FIGHT button
	var fight_btn = Button.new()
	fight_btn.text = "⚔️ FIGHT"
	fight_btn.custom_minimum_size = Vector2(115, 36)
	_style_fight_button(fight_btn)

	# Check cooldown
	var opp_uid = opponent.get("user_id", "")
	if arena_manager and not arena_manager.can_attack_opponent(opp_uid):
		fight_btn.disabled = true
		var remaining = arena_manager.get_attack_cooldown_remaining(opp_uid)
		fight_btn.text = "%ds" % int(remaining)

	fight_btn.pressed.connect(_on_fight_pressed.bind(opponent))
	buttons_vbox.add_child(fight_btn)

	top_hbox.add_child(buttons_vbox)

	# === EXPANDABLE DETAIL SECTION (hidden by default) ===
	var detail_section = _create_expandable_team_details(opponent)
	detail_section.name = "DetailSection"
	detail_section.visible = false
	main_vbox.add_child(detail_section)

	# Connect view button to toggle
	view_btn.pressed.connect(_toggle_opponent_details.bind(card, view_btn, detail_section))

	return card

func _toggle_opponent_details(card: PanelContainer, btn: Button, detail_section: Control) -> void:
	"""Toggle the expanded detail section visibility"""
	detail_section.visible = not detail_section.visible
	if detail_section.visible:
		btn.text = "▲ HIDE TEAM"
	else:
		btn.text = "▼ VIEW TEAM"

func _create_expandable_team_details(opponent: Dictionary) -> VBoxContainer:
	"""Create the expandable section showing full team details (god cards only, bonuses shown on collapsed card)"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	container.add_child(sep)

	# Header
	var gods_header = Label.new()
	gods_header.text = "⚔️ TEAM DETAILS"
	gods_header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.9))
	gods_header.add_theme_font_size_override("font_size", 11)
	container.add_child(gods_header)

	# Horizontal scroll for all gods
	var defense_team = opponent.get("defense_team", [])

	# Pre-calculate max set bonus lines across all gods for uniform card heights
	var max_set_lines = 0
	for god_data in defense_team:
		var god_set_lines = _count_god_set_bonus_lines(god_data)
		max_set_lines = max(max_set_lines, god_set_lines)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)  # Auto height
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(scroll)

	var gods_hbox = HBoxContainer.new()
	gods_hbox.add_theme_constant_override("separation", 10)
	scroll.add_child(gods_hbox)

	# Create compact detail card for each god with uniform set bonus space
	for god_data in defense_team:
		var god_card = _create_compact_god_detail_card(god_data, max_set_lines)
		gods_hbox.add_child(god_card)

	return container

func _get_opponent_team_bonuses(defense_team: Array) -> Array:
	"""Get team bonuses for opponent team - creates temporary God objects if needed"""
	if defense_team.is_empty():
		return []

	# Try to use TeamStatsCalculator directly with the dictionaries
	# First, create a fake array that mimics God objects for the calculator
	var fake_team = []
	for god_data in defense_team:
		var fake_god = _create_fake_god_for_bonus_calc(god_data)
		fake_team.append(fake_god)

	return TeamStatsCalculator.get_team_bonuses(fake_team)

func _create_fake_god_for_bonus_calc(god_data: Dictionary):
	"""Create a minimal object that TeamStatsCalculator can use"""
	# Return a simple object with the properties TeamStatsCalculator needs
	var fake = RefCounted.new()
	fake.set_meta("element", god_data.get("element", 0))
	fake.set_meta("tier", god_data.get("tier", 0))
	fake.set_meta("pantheon", god_data.get("pantheon", ""))
	fake.set_meta("id", god_data.get("id", god_data.get("template_id", "")))

	# Return a dictionary-like object that TeamStatsCalculator can access
	return {
		"element": god_data.get("element", 0),
		"tier": god_data.get("tier", 0),
		"pantheon": god_data.get("pantheon", ""),
		"id": god_data.get("id", god_data.get("template_id", ""))
	}

func _create_compact_god_detail_card(god_data: Dictionary, max_set_bonus_lines: int = 0) -> PanelContainer:
	"""Create a compact god card for the expandable section"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 0)  # Width only, height auto
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var element = god_data.get("element", 0)
	var style = StyleBoxFlat.new()
	style.bg_color = _get_element_color(element).darkened(0.8)
	style.border_color = _get_element_color(element)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Header: Portrait + Name
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	# Portrait
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(40, 40)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var template_id = god_data.get("template_id", god_data.get("id", ""))
	var sprite_path = "res://assets/gods/" + template_id + ".png"
	if ResourceLoader.exists(sprite_path):
		texture_rect.texture = load(sprite_path)
	header_hbox.add_child(texture_rect)

	# Name + Level
	var name_vbox = VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 0)
	header_hbox.add_child(name_vbox)

	var name_label = Label.new()
	name_label.text = god_data.get("name", "Unknown")
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	name_label.add_theme_font_size_override("font_size", 11)
	name_vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god_data.get("level", 1), _get_tier_name(god_data.get("tier", 0))]
	level_label.add_theme_color_override("font_color", _get_tier_color(god_data.get("tier", 0)))
	level_label.add_theme_font_size_override("font_size", 9)
	name_vbox.add_child(level_label)

	# Stats (compact 2-column)
	var stats_grid = GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 4)
	stats_grid.add_theme_constant_override("v_separation", 1)
	vbox.add_child(stats_grid)

	var base_stats = god_data.get("base_stats", {})
	var compact_stats = [
		["HP", base_stats.get("hp", god_data.get("hp", 100))],
		["ATK", base_stats.get("attack", god_data.get("attack", 10))],
		["DEF", base_stats.get("defense", god_data.get("defense", 5))],
		["SPD", base_stats.get("speed", god_data.get("speed", 100))]
	]

	for stat in compact_stats:
		var stat_name = Label.new()
		stat_name.text = stat[0]
		stat_name.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		stat_name.add_theme_font_size_override("font_size", 8)
		stats_grid.add_child(stat_name)

		var stat_val = Label.new()
		stat_val.text = str(stat[1])
		stat_val.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		stat_val.add_theme_font_size_override("font_size", 8)
		stats_grid.add_child(stat_val)

	# Equipment (compact list)
	var equip_label = Label.new()
	equip_label.text = "Equipment:"
	equip_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	equip_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(equip_label)

	var equipment = god_data.get("equipment", {})
	var slot_types = ["weapon", "armor", "helm", "boots", "amulet", "ring"]
	var slot_icons = {"weapon": "⚔", "armor": "🛡", "helm": "⛑", "boots": "👢", "amulet": "📿", "ring": "💍"}

	var equip_vbox = VBoxContainer.new()
	equip_vbox.add_theme_constant_override("separation", 1)
	vbox.add_child(equip_vbox)

	# Count sets for set bonuses
	var set_counts: Dictionary = {}

	for slot in slot_types:
		var eq_hbox = HBoxContainer.new()
		eq_hbox.add_theme_constant_override("separation", 4)

		var eq_text = Label.new()
		if equipment.has(slot) and equipment[slot] != null:
			var eq = equipment[slot]
			var eq_name: String = eq.get("name", slot)
			if eq_name.length() > 8:
				eq_name = eq_name.substr(0, 8)
			eq_text.text = "%s %s★%d" % [slot_icons.get(slot, "•"), eq_name, eq.get("tier", 0)]
			eq_text.add_theme_color_override("font_color", _get_equipment_tier_color(eq.get("tier", 0)))

			# Track set for set bonus calculation
			var eq_set = eq.get("equipment_set_name", eq.get("set", ""))
			if eq_set != "":
				set_counts[eq_set] = set_counts.get(eq_set, 0) + 1
		else:
			eq_text.text = "%s Empty" % slot_icons.get(slot, "•")
			eq_text.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		eq_text.add_theme_font_size_override("font_size", 8)
		eq_hbox.add_child(eq_text)

		equip_vbox.add_child(eq_hbox)

	# Set Bonuses section (below equipment) - only show if any god has set bonuses
	var this_god_lines = 0
	if not set_counts.is_empty():
		for set_name in set_counts:
			var count = set_counts[set_name]
			var set_info = _get_set_bonus_display(set_name, count)
			if set_info != "":
				this_god_lines += 1

	# Only show section if any god in the team has set bonuses (max_set_bonus_lines > 0)
	if max_set_bonus_lines > 0:
		var set_sep = HSeparator.new()
		set_sep.modulate = Color(0.4, 0.4, 0.5, 0.5)
		vbox.add_child(set_sep)

		var set_label = Label.new()
		set_label.text = "Set Bonuses:"
		set_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
		set_label.add_theme_font_size_override("font_size", 8)
		vbox.add_child(set_label)

		var sets_vbox = VBoxContainer.new()
		sets_vbox.add_theme_constant_override("separation", 1)
		vbox.add_child(sets_vbox)

		# Add actual set bonuses for this god
		for set_name in set_counts:
			var count = set_counts[set_name]
			var set_info = _get_set_bonus_display(set_name, count)
			if set_info != "":
				var set_text = Label.new()
				set_text.text = set_info
				set_text.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
				set_text.add_theme_font_size_override("font_size", 8)
				sets_vbox.add_child(set_text)

		# Add spacer lines if this god has fewer set bonuses than the max
		var spacer_count = max_set_bonus_lines - this_god_lines
		for i in range(spacer_count):
			var spacer = Label.new()
			spacer.text = " "  # Empty line to maintain height
			spacer.add_theme_font_size_override("font_size", 8)
			sets_vbox.add_child(spacer)

	return card

func _get_set_bonus_display(set_name: String, piece_count: int) -> String:
	"""Get display text for set bonus"""
	var set_display = set_name.capitalize()

	# Common set bonus thresholds and effects
	match set_name.to_lower():
		"warrior":
			if piece_count >= 2:
				return "⚔ %s (%d): +20%% ATK" % [set_display, piece_count]
		"guardian":
			if piece_count >= 4:
				return "🛡 %s (%d): +35%% DEF" % [set_display, piece_count]
			elif piece_count >= 2:
				return "🛡 %s (%d/4)" % [set_display, piece_count]
		"swift":
			if piece_count >= 2:
				return "💨 %s (%d): +25 SPD" % [set_display, piece_count]
		"focus":
			if piece_count >= 2:
				return "🎯 %s (%d): +20%% ACC" % [set_display, piece_count]
		"energy":
			if piece_count >= 2:
				return "⚡ %s (%d): +15%% HP" % [set_display, piece_count]
		"blade":
			if piece_count >= 2:
				return "🗡 %s (%d): +12%% CRIT" % [set_display, piece_count]
		"rage":
			if piece_count >= 4:
				return "💢 %s (%d): +40%% CDMG" % [set_display, piece_count]
			elif piece_count >= 2:
				return "💢 %s (%d/4)" % [set_display, piece_count]
		"vampire":
			if piece_count >= 4:
				return "🩸 %s (%d): +35%% Lifesteal" % [set_display, piece_count]
			elif piece_count >= 2:
				return "🩸 %s (%d/4)" % [set_display, piece_count]
		"will":
			if piece_count >= 2:
				return "✨ %s (%d): Immunity 1 turn" % [set_display, piece_count]
		"revenge":
			if piece_count >= 2:
				return "⚡ %s (%d): +15%% Counter" % [set_display, piece_count]
		"endure":
			if piece_count >= 2:
				return "🛡 %s (%d): +20%% RES" % [set_display, piece_count]
		_:
			# Generic display for unknown sets
			return "• %s (%d)" % [set_display, piece_count]

	return ""

func _count_god_set_bonus_lines(god_data: Dictionary) -> int:
	"""Count how many set bonus lines this god will display"""
	var equipment = god_data.get("equipment", {})
	var set_counts: Dictionary = {}

	# Count pieces per set
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		if equipment.has(slot) and equipment[slot] != null:
			var eq = equipment[slot]
			var eq_set = eq.get("equipment_set_name", eq.get("set", ""))
			if eq_set != "":
				set_counts[eq_set] = set_counts.get(eq_set, 0) + 1

	# Count how many sets will actually display a bonus line
	var line_count = 0
	for set_name in set_counts:
		var count = set_counts[set_name]
		var set_info = _get_set_bonus_display(set_name, count)
		if set_info != "":
			line_count += 1

	return line_count

func _create_mini_god_preview(god_data: Dictionary) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(50, 60)

	var style = StyleBoxFlat.new()
	var element = god_data.get("element", 0)
	style.bg_color = _get_element_color(element).darkened(0.6)
	style.border_color = _get_element_color(element)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# God portrait
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(36, 36)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var template_id = god_data.get("template_id", god_data.get("id", ""))
	var sprite_path = "res://assets/gods/" + template_id + ".png"
	if ResourceLoader.exists(sprite_path):
		texture_rect.texture = load(sprite_path)
	else:
		# Fallback to element-colored placeholder
		var placeholder = Image.create(36, 36, false, Image.FORMAT_RGB8)
		placeholder.fill(_get_element_color(element))
		var placeholder_tex = ImageTexture.create_from_image(placeholder)
		texture_rect.texture = placeholder_tex

	var center = CenterContainer.new()
	center.add_child(texture_rect)
	vbox.add_child(center)

	# God name (short)
	var name_label = Label.new()
	var god_name = god_data.get("name", "?")
	name_label.text = god_name.substr(0, 5) if god_name.length() > 5 else god_name
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	return slot

# ==============================================================================
# STYLING
# ==============================================================================

func _style_panel(panel: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)

func _style_primary_button(button: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
	style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.25, 0.6, 0.35, 0.95)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.15, 0.4, 0.25, 0.95)
	button.add_theme_stylebox_override("pressed", style_pressed)

	button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	button.add_theme_font_size_override("font_size", 14)

func _style_secondary_button(button: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.17, 0.28, 0.95)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	button.add_theme_font_size_override("font_size", 12)

func _style_fight_button(button: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.6, 0.2, 0.2, 0.9)
	style_normal.border_color = Color(0.8, 0.3, 0.3, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.7, 0.25, 0.25, 0.95)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.2, 0.15, 0.2, 0.7)
	style_disabled.border_color = Color(0.3, 0.25, 0.3, 0.5)
	style_disabled.set_border_width_all(1)
	style_disabled.set_corner_radius_all(4)
	button.add_theme_stylebox_override("disabled", style_disabled)

	button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	button.add_theme_font_size_override("font_size", 14)

func _style_post_button(button: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.3, 0.6, 0.9)
	style_normal.border_color = Color(0.3, 0.5, 0.9, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.25, 0.4, 0.7, 0.95)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.15, 0.25, 0.5, 0.95)
	button.add_theme_stylebox_override("pressed", style_pressed)

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.15, 0.15, 0.2, 0.7)
	style_disabled.border_color = Color(0.25, 0.25, 0.35, 0.5)
	style_disabled.set_border_width_all(1)
	style_disabled.set_corner_radius_all(6)
	button.add_theme_stylebox_override("disabled", style_disabled)

	button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	button.add_theme_font_size_override("font_size", 13)

func _style_view_team_button(button: Button) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.25, 0.2, 0.4, 0.9)
	style_normal.border_color = Color(0.5, 0.4, 0.7, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.35, 0.28, 0.55, 0.95)
	style_hover.border_color = Color(0.6, 0.5, 0.85, 0.9)
	button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.2, 0.15, 0.35, 0.95)
	button.add_theme_stylebox_override("pressed", style_pressed)

	button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	button.add_theme_font_size_override("font_size", 11)

func _get_league_color(league: String) -> Color:
	if arena_manager:
		return arena_manager.get_league_color(league)
	match league:
		"bronze": return Color(0.6, 0.4, 0.2)
		"silver": return Color(0.7, 0.7, 0.75)
		"gold": return Color(1.0, 0.84, 0.0)
		"platinum": return Color(0.4, 0.8, 0.8)
		"diamond": return Color(0.4, 0.6, 1.0)
		"legend": return Color(0.7, 0.4, 0.9)
		_: return Color.WHITE

func _get_element_color(element: int) -> Color:
	match element:
		0: return Color(1.0, 0.3, 0.2)  # Fire
		1: return Color(0.2, 0.5, 1.0)  # Water
		2: return Color(0.5, 0.35, 0.2)  # Earth
		3: return Color(1.0, 0.9, 0.3)  # Lightning
		4: return Color(1.0, 1.0, 0.8)  # Light
		5: return Color(0.4, 0.2, 0.5)  # Dark
		_: return Color(0.5, 0.5, 0.5)

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _calculate_team_bonuses(defense_team: Array) -> String:
	"""Calculate and format team bonuses for display"""
	if defense_team.is_empty():
		return ""

	# Count elements
	var element_counts = {}
	for god_data in defense_team:
		var element = god_data.get("element", 0)
		element_counts[element] = element_counts.get(element, 0) + 1

	var bonuses = []

	# Check for element synergies
	for element in element_counts:
		var count = element_counts[element]
		if count >= 2:
			var element_name = _get_element_name(element)
			if count >= 4:
				bonuses.append("%s x4" % element_name)
			elif count >= 3:
				bonuses.append("%s x3" % element_name)
			else:
				bonuses.append("%s x2" % element_name)

	# Check for rainbow bonus (all different elements)
	if element_counts.size() >= 4:
		bonuses.append("Rainbow")

	if bonuses.is_empty():
		return ""

	return " | ".join(bonuses)

func _get_element_name(element: int) -> String:
	match element:
		0: return "🔥"  # Fire
		1: return "💧"  # Water
		2: return "🌍"  # Earth
		3: return "⚡"  # Lightning
		4: return "✨"  # Light
		5: return "🌑"  # Dark
		_: return "?"

# ==============================================================================
# DATA REFRESH
# ==============================================================================

func _refresh_data() -> void:
	_update_player_stats()
	_update_defense_display()

	if arena_manager:
		arena_manager.fetch_opponents()

func _update_player_stats() -> void:
	if not arena_manager:
		return

	var stats = arena_manager.get_player_stats()

	if elo_label:
		elo_label.text = str(stats.get("elo", 1000))

	if league_label:
		var league = stats.get("league", "bronze")
		league_label.text = league.capitalize()
		league_label.add_theme_color_override("font_color", _get_league_color(league))

	if win_rate_label:
		var wr = stats.get("win_rate", 0.0)
		var wins = stats.get("wins", 0)
		var losses = stats.get("losses", 0)
		win_rate_label.text = "%.1f%% (%d/%d)" % [wr, wins, losses]

	if defense_power_label:
		defense_power_label.text = _format_number(stats.get("defense_team_power", 0))

func _update_defense_display() -> void:
	if not arena_manager:
		return

	var defense_team = arena_manager.get_defense_team()

	for i in range(defense_team_slots.size()):
		var slot = defense_team_slots[i]

		# Clear existing content
		for child in slot.get_children():
			child.queue_free()

		if i < defense_team.size() and defense_team[i] != null:
			var god = defense_team[i]
			_populate_god_slot(slot, god)
		else:
			# Empty slot
			var center = CenterContainer.new()
			slot.add_child(center)
			var plus_label = Label.new()
			plus_label.text = "+"
			plus_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
			plus_label.add_theme_font_size_override("font_size", 24)
			center.add_child(plus_label)

	# Update bonuses display
	_update_defense_bonuses_display(defense_team)

func _update_defense_bonuses_display(defense_team: Array) -> void:
	"""Update the bonuses container on the main arena screen"""
	if not defense_bonuses_container:
		return

	# Clear existing bonuses
	for child in defense_bonuses_container.get_children():
		child.queue_free()

	# Calculate bonuses using TeamStatsCalculator
	var bonuses = TeamStatsCalculator.get_team_bonuses(defense_team)

	if bonuses.is_empty():
		var no_bonus = Label.new()
		no_bonus.text = "No active bonuses"
		no_bonus.add_theme_font_size_override("font_size", 10)
		no_bonus.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		defense_bonuses_container.add_child(no_bonus)
	else:
		for bonus in bonuses:
			var bonus_row = HBoxContainer.new()
			bonus_row.add_theme_constant_override("separation", 6)

			var name_label = Label.new()
			name_label.text = bonus.name
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bonus_row.add_child(name_label)

			var desc_label = Label.new()
			desc_label.text = bonus.desc
			desc_label.add_theme_font_size_override("font_size", 9)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			bonus_row.add_child(desc_label)

			defense_bonuses_container.add_child(bonus_row)

func _populate_god_slot(slot: PanelContainer, god: God) -> void:
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)

	# God portrait
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(40, 40)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var template_id = god.template_id if god.template_id else god.id
	var sprite_path = "res://assets/gods/" + template_id + ".png"
	if ResourceLoader.exists(sprite_path):
		texture_rect.texture = load(sprite_path)

	var img_center = CenterContainer.new()
	img_center.add_child(texture_rect)
	vbox.add_child(img_center)

	# God name (short)
	var name_label = Label.new()
	var display_name = god.name if god.name.length() <= 6 else god.name.substr(0, 5) + "."
	name_label.text = display_name
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	level_label.add_theme_font_size_override("font_size", 8)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Update slot border color based on element
	var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = _get_element_color(god.element)
	slot.add_theme_stylebox_override("panel", style)

func _update_opponent_list(opponents: Array) -> void:
	# Clear existing cards
	for card in opponent_cards:
		card.queue_free()
	opponent_cards.clear()

	# Clear container
	for child in opponent_list_container.get_children():
		child.queue_free()

	if opponents.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No opponents available.\nTry refreshing or check back later."
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		opponent_list_container.add_child(empty_label)
		return

	# Create cards for each opponent
	for opponent in opponents:
		var card = _create_opponent_card(opponent)
		opponent_cards.append(card)
		opponent_list_container.add_child(card)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_back_pressed() -> void:
	back_pressed.emit()

func _on_refresh_pressed() -> void:
	if arena_manager:
		arena_manager.fetch_opponents()

func _on_fight_pressed(opponent: Dictionary) -> void:
	selected_opponent = opponent

	if not arena_manager or not screen_manager:
		push_error("[ArenaScreen] Cannot start fight - systems not available")
		return

	var opp_uid = opponent.get("user_id", "")
	if not arena_manager.can_attack_opponent(opp_uid):
		return

	# Start PvP battle flow
	var battle_context = arena_manager.start_pvp_battle(opponent)

	# Navigate to battle setup
	if screen_manager.change_screen("battle_setup"):
		var battle_setup_screen = screen_manager.get_current_screen()
		if battle_setup_screen and battle_setup_screen.has_method("setup_for_pvp_battle"):
			battle_setup_screen.setup_for_pvp_battle(opponent)

			if not battle_setup_screen.battle_setup_complete.is_connected(_on_battle_setup_complete):
				battle_setup_screen.battle_setup_complete.connect(_on_battle_setup_complete)
			if not battle_setup_screen.setup_cancelled.is_connected(_on_battle_setup_cancelled):
				battle_setup_screen.setup_cancelled.connect(_on_battle_setup_cancelled)

func _on_edit_defense_pressed() -> void:
	# Show defense team selection popup on top of arena screen
	_show_defense_team_popup()

func _on_post_defense_pressed() -> void:
	"""Post current defense team to Firebase for other players to fight"""
	if not arena_manager:
		push_error("[ArenaScreen] ArenaManager not available")
		return

	var defense_team = arena_manager.get_defense_team()
	if defense_team.is_empty():
		_show_notification("No defense team set! Set your defense team first.", Color(0.9, 0.6, 0.3))
		return

	# Check if we have at least one god
	var valid_gods = 0
	for god in defense_team:
		if god != null:
			valid_gods += 1

	if valid_gods == 0:
		_show_notification("No defense team set! Set your defense team first.", Color(0.9, 0.6, 0.3))
		return

	# Upload to Firebase via ArenaDataSync
	arena_manager.post_defense_to_firebase()
	_show_notification("Defense team posted to arena!", Color(0.4, 0.8, 0.4))

func _show_notification(text: String, color: Color) -> void:
	"""Show a temporary notification popup"""
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 80)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.98)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)

	# Auto-close after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

	# Click to close
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)

func _on_leaderboard_pressed() -> void:
	if arena_manager:
		arena_manager.fetch_leaderboard()
	_show_leaderboard_popup()

func _show_leaderboard_popup() -> void:
	# Create leaderboard popup
	if leaderboard_popup and is_instance_valid(leaderboard_popup):
		leaderboard_popup.queue_free()

	leaderboard_popup = _create_leaderboard_popup()
	add_child(leaderboard_popup)
	is_showing_leaderboard = true

func _create_leaderboard_popup() -> Control:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100

	# Click overlay to close
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close_leaderboard()
	)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	var header = Label.new()
	header.text = "LEADERBOARD"
	header.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	header.add_theme_font_size_override("font_size", 20)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_close_leaderboard)
	header_hbox.add_child(close_btn)
	vbox.add_child(header_hbox)

	# Leaderboard list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list = VBoxContainer.new()
	list.name = "LeaderboardList"
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	vbox.add_child(scroll)

	# Loading indicator
	var loading = Label.new()
	loading.text = "Loading..."
	loading.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(loading)

	return overlay

func _close_leaderboard() -> void:
	if leaderboard_popup and is_instance_valid(leaderboard_popup):
		leaderboard_popup.queue_free()
		leaderboard_popup = null
	is_showing_leaderboard = false

# ==============================================================================
# OPPONENT DETAILS POPUP
# ==============================================================================

func _show_opponent_details_popup(opponent: Dictionary) -> void:
	"""Show comprehensive view of opponent's team - all 4 gods with stats, equipment, abilities"""
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	# Click overlay to close
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)

	# Large panel to fit all 4 gods
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 620)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position = Vector2(-550, -310)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel)
	overlay.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# === HEADER ===
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(header_hbox)

	var header = Label.new()
	header.text = "👁 %s's Defense Team" % opponent.get("display_name", "Unknown")
	header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	header.add_theme_font_size_override("font_size", 20)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header)

	# League badge
	var league = opponent.get("league", "bronze")
	var league_badge = Label.new()
	league_badge.text = "[%s]" % league.capitalize()
	league_badge.add_theme_color_override("font_color", _get_league_color(league))
	league_badge.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(league_badge)

	# ELO
	var elo_label = Label.new()
	elo_label.text = "ELO: %d" % opponent.get("elo", 1000)
	elo_label.add_theme_color_override("font_color", Color.GOLD)
	elo_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(elo_label)

	# Power
	var power_label = Label.new()
	power_label.text = "⚔️ %s" % _format_number(opponent.get("defense_power", 0))
	power_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	power_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(power_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕ CLOSE"
	close_btn.custom_minimum_size = Vector2(80, 32)
	close_btn.pressed.connect(func(): overlay.queue_free())
	_style_secondary_button(close_btn)
	header_hbox.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	main_vbox.add_child(sep)

	# === GODS ROW - All 4 gods horizontally ===
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll)

	var gods_hbox = HBoxContainer.new()
	gods_hbox.add_theme_constant_override("separation", 15)
	gods_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gods_hbox)

	# Create a detailed panel for each god
	var defense_team = opponent.get("defense_team", [])
	for god_data in defense_team:
		var god_panel = _create_full_god_detail_panel(god_data)
		gods_hbox.add_child(god_panel)

	# If less than 4 gods, add empty slots
	for i in range(defense_team.size(), 4):
		var empty_panel = _create_empty_god_slot_panel()
		gods_hbox.add_child(empty_panel)

func _create_full_god_detail_panel(god_data: Dictionary) -> PanelContainer:
	"""Create a comprehensive god panel with portrait, stats, equipment, and abilities"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 480)

	var element = god_data.get("element", 0)
	var style = StyleBoxFlat.new()
	style.bg_color = _get_element_color(element).darkened(0.8)
	style.border_color = _get_element_color(element)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# === GOD HEADER: Portrait + Name/Level ===
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(header_hbox)

	# Portrait
	var portrait_panel = PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(70, 70)
	var portrait_style = StyleBoxFlat.new()
	portrait_style.bg_color = _get_element_color(element).darkened(0.5)
	portrait_style.border_color = _get_element_color(element).lightened(0.2)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(6)
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	header_hbox.add_child(portrait_panel)

	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(60, 60)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var template_id = god_data.get("template_id", god_data.get("id", ""))
	var sprite_path = "res://assets/gods/" + template_id + ".png"
	if ResourceLoader.exists(sprite_path):
		texture_rect.texture = load(sprite_path)
	var center = CenterContainer.new()
	center.add_child(texture_rect)
	portrait_panel.add_child(center)

	# Name/Level/Element info
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = god_data.get("name", "Unknown")
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = "Level %d" % god_data.get("level", 1)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	level_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(level_label)

	var tier_label = Label.new()
	tier_label.text = _get_tier_name(god_data.get("tier", 0))
	tier_label.add_theme_color_override("font_color", _get_tier_color(god_data.get("tier", 0)))
	tier_label.add_theme_font_size_override("font_size", 10)
	info_vbox.add_child(tier_label)

	var element_label = Label.new()
	element_label.text = "%s %s" % [_get_element_name(element), _get_element_text(element)]
	element_label.add_theme_color_override("font_color", _get_element_color(element))
	element_label.add_theme_font_size_override("font_size", 10)
	info_vbox.add_child(element_label)

	# === STATS SECTION ===
	vbox.add_child(_create_section_header("📊 STATS"))

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(stats_grid)

	# Get stats from god_data
	var base_stats = god_data.get("base_stats", {})
	var stat_list = [
		["HP", base_stats.get("hp", god_data.get("hp", 100)), Color(0.9, 0.4, 0.4)],
		["ATK", base_stats.get("attack", god_data.get("attack", 10)), Color(0.9, 0.6, 0.3)],
		["DEF", base_stats.get("defense", god_data.get("defense", 5)), Color(0.4, 0.7, 0.9)],
		["SPD", base_stats.get("speed", god_data.get("speed", 100)), Color(0.5, 0.9, 0.5)],
		["CRIT", "%d%%" % int(base_stats.get("crit_rate", god_data.get("crit_rate", 5)) * 100 if base_stats.get("crit_rate", god_data.get("crit_rate", 5)) < 1 else base_stats.get("crit_rate", god_data.get("crit_rate", 5))), Color(0.9, 0.8, 0.3)],
		["C.DMG", "%d%%" % int(base_stats.get("crit_damage", god_data.get("crit_damage", 150))), Color(0.9, 0.5, 0.5)]
	]

	for stat in stat_list:
		var stat_name = Label.new()
		stat_name.text = stat[0] + ":"
		stat_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		stat_name.add_theme_font_size_override("font_size", 10)
		stat_name.custom_minimum_size = Vector2(45, 0)
		stats_grid.add_child(stat_name)

		var stat_value = Label.new()
		stat_value.text = str(stat[1])
		stat_value.add_theme_color_override("font_color", stat[2])
		stat_value.add_theme_font_size_override("font_size", 10)
		stats_grid.add_child(stat_value)

	# === EQUIPMENT SECTION ===
	vbox.add_child(_create_section_header("🛡️ EQUIPMENT"))

	var equipment = god_data.get("equipment", {})
	var slot_types = ["weapon", "helmet", "armor", "boots", "accessory", "artifact"]
	var slot_icons = {"weapon": "⚔️", "helmet": "🪖", "armor": "🛡️", "boots": "👢", "accessory": "💍", "artifact": "📿"}

	var equip_vbox = VBoxContainer.new()
	equip_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(equip_vbox)

	for slot in slot_types:
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 6)

		var icon = Label.new()
		icon.text = slot_icons.get(slot, "❓")
		icon.add_theme_font_size_override("font_size", 10)
		icon.custom_minimum_size = Vector2(20, 0)
		slot_hbox.add_child(icon)

		var equip_info = Label.new()
		if equipment.has(slot) and equipment[slot] != null:
			var eq = equipment[slot]
			var eq_name = eq.get("name", slot.capitalize())
			var eq_tier = eq.get("tier", 0)
			equip_info.text = "%s ★%d" % [eq_name, eq_tier]
			equip_info.add_theme_color_override("font_color", _get_equipment_tier_color(eq_tier))
		else:
			equip_info.text = "— Empty —"
			equip_info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		equip_info.add_theme_font_size_override("font_size", 9)
		slot_hbox.add_child(equip_info)

		equip_vbox.add_child(slot_hbox)

	# === ABILITIES SECTION ===
	vbox.add_child(_create_section_header("⚡ ABILITIES"))

	var abilities = god_data.get("abilities", [])
	var abilities_vbox = VBoxContainer.new()
	abilities_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(abilities_vbox)

	if abilities.is_empty():
		var no_abilities = Label.new()
		no_abilities.text = "No abilities data"
		no_abilities.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		no_abilities.add_theme_font_size_override("font_size", 9)
		abilities_vbox.add_child(no_abilities)
	else:
		for ability in abilities:
			var ability_hbox = HBoxContainer.new()
			ability_hbox.add_theme_constant_override("separation", 6)

			var ability_name = Label.new()
			var ab_name = ability.get("name", "Unknown") if ability is Dictionary else str(ability)
			ability_name.text = "• " + ab_name
			ability_name.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
			ability_name.add_theme_font_size_override("font_size", 9)
			ability_hbox.add_child(ability_name)

			abilities_vbox.add_child(ability_hbox)

	return panel

func _create_empty_god_slot_panel() -> PanelContainer:
	"""Create an empty slot panel for teams with less than 4 gods"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 480)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.12, 0.5)
	style.border_color = Color(0.3, 0.25, 0.35, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var center = CenterContainer.new()
	panel.add_child(center)

	var empty_label = Label.new()
	empty_label.text = "Empty Slot"
	empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	empty_label.add_theme_font_size_override("font_size", 14)
	center.add_child(empty_label)

	return panel

func _create_section_header(text: String) -> Label:
	"""Create a styled section header label"""
	var header = Label.new()
	header.text = text
	header.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	header.add_theme_font_size_override("font_size", 11)
	return header

func _get_tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.6, 0.6, 0.65)  # Common
		1: return Color(0.4, 0.7, 0.4)   # Uncommon
		2: return Color(0.4, 0.6, 0.9)   # Rare
		3: return Color(0.7, 0.4, 0.8)   # Epic
		4: return Color(1.0, 0.84, 0.0)  # Legendary
		_: return Color(0.5, 0.5, 0.55)

func _create_detailed_god_card(god_data: Dictionary) -> PanelContainer:
	"""Create a detailed card showing god info with equipment (simplified version)"""
	var card = PanelContainer.new()

	var style = StyleBoxFlat.new()
	var element = god_data.get("element", 0)
	style.bg_color = _get_element_color(element).darkened(0.75)
	style.border_color = _get_element_color(element)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	card.add_child(hbox)

	# Left: God portrait and basic info
	var god_info = VBoxContainer.new()
	god_info.add_theme_constant_override("separation", 4)
	god_info.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(god_info)

	# Portrait
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(60, 60)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var template_id = god_data.get("template_id", god_data.get("id", ""))
	var sprite_path = "res://assets/gods/" + template_id + ".png"
	if ResourceLoader.exists(sprite_path):
		texture_rect.texture = load(sprite_path)
	god_info.add_child(texture_rect)

	# Name
	var name_label = Label.new()
	name_label.text = god_data.get("name", "Unknown")
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	name_label.add_theme_font_size_override("font_size", 14)
	god_info.add_child(name_label)

	# Level and tier
	var level_label = Label.new()
	var tier_name = _get_tier_name(god_data.get("tier", 0))
	level_label.text = "Lv.%d | %s" % [god_data.get("level", 1), tier_name]
	level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	level_label.add_theme_font_size_override("font_size", 11)
	god_info.add_child(level_label)

	# Element
	var element_label = Label.new()
	element_label.text = "%s %s" % [_get_element_name(element), _get_element_text(element)]
	element_label.add_theme_color_override("font_color", _get_element_color(element))
	element_label.add_theme_font_size_override("font_size", 10)
	god_info.add_child(element_label)

	# Right: Equipment list
	var equip_vbox = VBoxContainer.new()
	equip_vbox.add_theme_constant_override("separation", 4)
	equip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(equip_vbox)

	var equip_header = Label.new()
	equip_header.text = "Equipment:"
	equip_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	equip_header.add_theme_font_size_override("font_size", 11)
	equip_vbox.add_child(equip_header)

	# Equipment slots
	var equipment = god_data.get("equipment", {})
	var slot_types = ["weapon", "helmet", "armor", "boots", "accessory", "artifact"]
	var slot_icons = {"weapon": "⚔️", "helmet": "🪖", "armor": "🛡️", "boots": "👢", "accessory": "💍", "artifact": "📿"}

	var equip_grid = GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override("h_separation", 12)
	equip_grid.add_theme_constant_override("v_separation", 3)
	equip_vbox.add_child(equip_grid)

	for slot in slot_types:
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 4)

		var icon = Label.new()
		icon.text = slot_icons.get(slot, "❓")
		icon.add_theme_font_size_override("font_size", 10)
		slot_hbox.add_child(icon)

		var equip_info = Label.new()
		if equipment.has(slot) and equipment[slot] != null:
			var eq = equipment[slot]
			var eq_name = eq.get("name", slot.capitalize())
			var eq_tier = eq.get("tier", 0)
			equip_info.text = "%s ★%d" % [eq_name, eq_tier]
			equip_info.add_theme_color_override("font_color", _get_equipment_tier_color(eq_tier))
		else:
			equip_info.text = "Empty"
			equip_info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		equip_info.add_theme_font_size_override("font_size", 10)
		slot_hbox.add_child(equip_info)

		equip_grid.add_child(slot_hbox)

	return card

func _get_tier_name(tier: int) -> String:
	match tier:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		3: return "Epic"
		4: return "Legendary"
		_: return "Unknown"

func _get_element_text(element: int) -> String:
	match element:
		0: return "Fire"
		1: return "Water"
		2: return "Earth"
		3: return "Lightning"
		4: return "Light"
		5: return "Dark"
		_: return "Unknown"

func _get_equipment_tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.6, 0.6, 0.65)  # Common - gray
		1: return Color(0.4, 0.7, 0.4)   # Uncommon - green
		2: return Color(0.4, 0.6, 0.9)   # Rare - blue
		3: return Color(0.7, 0.4, 0.8)   # Epic - purple
		4: return Color(1.0, 0.84, 0.0)  # Legendary - gold
		_: return Color(0.5, 0.5, 0.55)

# ==============================================================================
# DEFENSE TEAM POPUP
# ==============================================================================

func _show_defense_team_popup() -> void:
	"""Show inline defense team selection popup - matches TeamSelectionManager quality"""
	# Close existing popup if any
	if defense_popup_overlay and is_instance_valid(defense_popup_overlay):
		defense_popup_overlay.queue_free()

	# Reset pending team
	defense_popup_pending_team = [null, null, null, null]
	defense_popup_team_slots.clear()
	defense_popup_power_label = null
	defense_popup_bonuses_container = null
	defense_popup_sort_dropdown = null
	defense_popup_sort_btn = null

	# Create overlay
	defense_popup_overlay = ColorRect.new()
	defense_popup_overlay.name = "DefensePopupOverlay"
	defense_popup_overlay.color = Color(0, 0, 0, 0.8)
	defense_popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defense_popup_overlay.z_index = 100
	add_child(defense_popup_overlay)

	# Click overlay to close
	defense_popup_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close_defense_popup()
	)

	# Main popup panel - larger to fit all content
	var popup_panel = PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(850, 600)
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.position = Vector2(-425, -300)
	_style_panel(popup_panel)
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	defense_popup_overlay.add_child(popup_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	popup_panel.add_child(margin)

	# Main horizontal layout (left stats panel + right gods grid)
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_hbox)

	# === LEFT PANEL: Team slots, power, bonuses ===
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(260, 0)
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.1, 0.08, 0.14, 0.95)
	left_style.border_color = Color(0.25, 0.2, 0.35, 0.8)
	left_style.set_border_width_all(1)
	left_style.set_corner_radius_all(6)
	left_style.set_content_margin_all(12)
	left_panel.add_theme_stylebox_override("panel", left_style)
	main_hbox.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_panel.add_child(left_vbox)

	# Header with clear button
	var header_row = HBoxContainer.new()
	left_vbox.add_child(header_row)

	var team_title = Label.new()
	team_title.text = "YOUR DEFENSE"
	team_title.add_theme_font_size_override("font_size", 14)
	team_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	team_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(team_title)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(60, 26)
	clear_btn.pressed.connect(_clear_defense_popup_team)
	_style_secondary_button(clear_btn)
	header_row.add_child(clear_btn)

	# Team slots
	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 8)
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_child(slots_hbox)

	for i in range(4):
		var slot = _create_defense_popup_slot(i)
		defense_popup_team_slots.append(slot)
		slots_hbox.add_child(slot)

	# Combat power display
	var power_hbox = HBoxContainer.new()
	power_hbox.add_theme_constant_override("separation", 8)
	power_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_child(power_hbox)

	var power_icon = Label.new()
	power_icon.text = "⚔️"
	power_icon.add_theme_font_size_override("font_size", 16)
	power_hbox.add_child(power_icon)

	var power_title = Label.new()
	power_title.text = "Combat Power:"
	power_title.add_theme_font_size_override("font_size", 12)
	power_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	power_hbox.add_child(power_title)

	defense_popup_power_label = Label.new()
	defense_popup_power_label.text = "0"
	defense_popup_power_label.add_theme_font_size_override("font_size", 16)
	defense_popup_power_label.add_theme_color_override("font_color", Color.GOLD)
	power_hbox.add_child(defense_popup_power_label)

	# Separator
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 6)
	left_vbox.add_child(sep1)

	# Team bonuses header
	var bonuses_header = Label.new()
	bonuses_header.text = "TEAM BONUSES"
	bonuses_header.add_theme_font_size_override("font_size", 12)
	bonuses_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left_vbox.add_child(bonuses_header)

	# Team bonuses container
	defense_popup_bonuses_container = VBoxContainer.new()
	defense_popup_bonuses_container.add_theme_constant_override("separation", 4)
	left_vbox.add_child(defense_popup_bonuses_container)

	# Spacer to push buttons to bottom
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(spacer)

	# Separator before buttons
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 6)
	left_vbox.add_child(sep2)

	# Action buttons
	var buttons_vbox = VBoxContainer.new()
	buttons_vbox.add_theme_constant_override("separation", 8)
	left_vbox.add_child(buttons_vbox)

	var set_btn = Button.new()
	set_btn.text = "SET DEFENSE"
	set_btn.custom_minimum_size = Vector2(0, 40)
	set_btn.pressed.connect(_confirm_defense_team)
	_style_primary_button(set_btn)
	buttons_vbox.add_child(set_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(0, 35)
	cancel_btn.pressed.connect(_close_defense_popup)
	_style_secondary_button(cancel_btn)
	buttons_vbox.add_child(cancel_btn)

	# === RIGHT PANEL: Gods selection grid with sorting ===
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.1, 0.08, 0.14, 0.95)
	right_style.border_color = Color(0.25, 0.2, 0.35, 0.8)
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(6)
	right_style.set_content_margin_all(12)
	right_panel.add_theme_stylebox_override("panel", right_style)
	main_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	# Header with sorting controls
	var gods_header_row = HBoxContainer.new()
	gods_header_row.add_theme_constant_override("separation", 12)
	right_vbox.add_child(gods_header_row)

	var gods_title = Label.new()
	gods_title.text = "SELECT GODS"
	gods_title.add_theme_font_size_override("font_size", 14)
	gods_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	gods_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gods_header_row.add_child(gods_title)

	# Sorting controls
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 11)
	sort_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	gods_header_row.add_child(sort_label)

	defense_popup_sort_dropdown = OptionButton.new()
	defense_popup_sort_dropdown.custom_minimum_size = Vector2(90, 28)
	defense_popup_sort_dropdown.add_item("Power", SortType.POWER)
	defense_popup_sort_dropdown.add_item("Level", SortType.LEVEL)
	defense_popup_sort_dropdown.add_item("Tier", SortType.TIER)
	defense_popup_sort_dropdown.add_item("Element", SortType.ELEMENT)
	defense_popup_sort_dropdown.add_item("Name", SortType.NAME)
	defense_popup_sort_dropdown.selected = 0
	defense_popup_sort_dropdown.item_selected.connect(_on_defense_popup_sort_changed)
	gods_header_row.add_child(defense_popup_sort_dropdown)

	defense_popup_sort_btn = Button.new()
	defense_popup_sort_btn.text = "▼"
	defense_popup_sort_btn.custom_minimum_size = Vector2(30, 28)
	defense_popup_sort_btn.tooltip_text = "Toggle sort direction"
	defense_popup_sort_btn.pressed.connect(_toggle_defense_popup_sort_direction)
	_style_secondary_button(defense_popup_sort_btn)
	gods_header_row.add_child(defense_popup_sort_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_close_defense_popup)
	_style_secondary_button(close_btn)
	gods_header_row.add_child(close_btn)

	# Scrollable gods grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	defense_popup_gods_grid = GridContainer.new()
	defense_popup_gods_grid.columns = 5
	defense_popup_gods_grid.add_theme_constant_override("h_separation", 8)
	defense_popup_gods_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(defense_popup_gods_grid)

	# Load current defense team into popup if exists
	if arena_manager:
		var current_defense = arena_manager.get_defense_team()
		for i in range(min(4, current_defense.size())):
			if current_defense[i] != null:
				defense_popup_pending_team[i] = current_defense[i]
				_update_defense_popup_slot(i)

	_refresh_defense_popup_gods()
	_update_defense_popup_stats()

func _create_defense_popup_slot(index: int) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(80, 100)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style.border_color = Color(0.4, 0.35, 0.5, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", style)

	# Placeholder content
	var center = CenterContainer.new()
	center.name = "Content"
	slot.add_child(center)

	var plus_label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	plus_label.add_theme_font_size_override("font_size", 28)
	center.add_child(plus_label)

	# Make clickable to remove
	slot.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_defense_slot_clicked(index)
	)

	return slot

func _update_defense_popup_slot(index: int) -> void:
	if index < 0 or index >= defense_popup_team_slots.size():
		return

	var slot = defense_popup_team_slots[index]
	var content = slot.get_node_or_null("Content")
	if not content:
		return

	# Clear existing content
	for child in content.get_children():
		child.queue_free()

	var god = defense_popup_pending_team[index]
	if god == null:
		# Empty slot
		var plus_label = Label.new()
		plus_label.text = "+"
		plus_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		plus_label.add_theme_font_size_override("font_size", 28)
		content.add_child(plus_label)

		# Reset border
		var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = Color(0.4, 0.35, 0.5, 0.6)
		slot.add_theme_stylebox_override("panel", style)
	else:
		# Show god
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(vbox)

		# Portrait
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(48, 48)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var template_id = god.template_id if god.template_id else god.id
		var sprite_path = "res://assets/gods/" + template_id + ".png"
		if ResourceLoader.exists(sprite_path):
			texture_rect.texture = load(sprite_path)

		var img_center = CenterContainer.new()
		img_center.add_child(texture_rect)
		vbox.add_child(img_center)

		# Name
		var name_label = Label.new()
		var display_name = god.name.substr(0, 7) if god.name.length() > 7 else god.name
		name_label.text = display_name
		name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		# Level
		var level_label = Label.new()
		level_label.text = "Lv.%d" % god.level
		level_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		level_label.add_theme_font_size_override("font_size", 9)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(level_label)

		# Update border to element color
		var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = _get_element_color(god.element)
		slot.add_theme_stylebox_override("panel", style)

func _on_defense_slot_clicked(index: int) -> void:
	if defense_popup_pending_team[index] != null:
		defense_popup_pending_team[index] = null
		_update_defense_popup_slot(index)
		_refresh_defense_popup_gods()
		_update_defense_popup_stats()

func _refresh_defense_popup_gods() -> void:
	if not defense_popup_gods_grid:
		return

	# Clear existing
	for child in defense_popup_gods_grid.get_children():
		child.queue_free()

	# Get all gods from collection
	if not collection_manager:
		return

	var all_gods = collection_manager.get_all_gods()

	# Sort based on current sort settings
	all_gods = _sort_defense_popup_gods(all_gods)

	# Create cards for each god
	for god in all_gods:
		# Check if already in pending team
		var already_selected = false
		for selected in defense_popup_pending_team:
			if selected != null and selected.id == god.id:
				already_selected = true
				break

		var card = _create_defense_popup_god_card(god, already_selected)
		defense_popup_gods_grid.add_child(card)

func _sort_defense_popup_gods(gods: Array) -> Array:
	"""Sort gods based on current popup sort settings"""
	var sorted = gods.duplicate()

	match defense_popup_sort:
		SortType.POWER:
			sorted.sort_custom(func(a, b):
				var pa = GodCalculator.get_power_rating(a)
				var pb = GodCalculator.get_power_rating(b)
				return pa < pb if defense_popup_sort_ascending else pa > pb)
		SortType.LEVEL:
			sorted.sort_custom(func(a, b):
				return a.level < b.level if defense_popup_sort_ascending else a.level > b.level)
		SortType.TIER:
			sorted.sort_custom(func(a, b):
				return a.tier < b.tier if defense_popup_sort_ascending else a.tier > b.tier)
		SortType.ELEMENT:
			sorted.sort_custom(func(a, b):
				return a.element < b.element if defense_popup_sort_ascending else a.element > b.element)
		SortType.NAME:
			sorted.sort_custom(func(a, b):
				return a.name < b.name if defense_popup_sort_ascending else a.name > b.name)

	return sorted

func _on_defense_popup_sort_changed(index: int) -> void:
	defense_popup_sort = index as SortType
	_refresh_defense_popup_gods()

func _toggle_defense_popup_sort_direction() -> void:
	defense_popup_sort_ascending = not defense_popup_sort_ascending
	if defense_popup_sort_btn:
		defense_popup_sort_btn.text = "▲" if defense_popup_sort_ascending else "▼"
	_refresh_defense_popup_gods()

func _update_defense_popup_stats() -> void:
	"""Update power and bonuses display for the pending defense team"""
	# Calculate total power
	var total_power = 0
	for god in defense_popup_pending_team:
		if god != null:
			total_power += GodCalculator.get_power_rating(god)

	if defense_popup_power_label:
		defense_popup_power_label.text = _format_number(total_power)

	# Update bonuses display
	if not defense_popup_bonuses_container:
		return

	# Clear existing
	for child in defense_popup_bonuses_container.get_children():
		child.queue_free()

	# Calculate bonuses using TeamStatsCalculator if available, else manual calculation
	var bonuses = _get_defense_popup_team_bonuses()

	if bonuses.is_empty():
		var no_bonus = Label.new()
		no_bonus.text = "No active bonuses"
		no_bonus.add_theme_font_size_override("font_size", 10)
		no_bonus.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		defense_popup_bonuses_container.add_child(no_bonus)
	else:
		for bonus in bonuses:
			var bonus_row = HBoxContainer.new()
			bonus_row.add_theme_constant_override("separation", 6)

			var name_label = Label.new()
			name_label.text = bonus.name
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bonus_row.add_child(name_label)

			var desc_label = Label.new()
			desc_label.text = bonus.desc
			desc_label.add_theme_font_size_override("font_size", 9)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			bonus_row.add_child(desc_label)

			defense_popup_bonuses_container.add_child(bonus_row)

func _get_defense_popup_team_bonuses() -> Array:
	"""Calculate team bonuses for the pending defense team"""
	# Use TeamStatsCalculator static method
	return TeamStatsCalculator.get_team_bonuses(defense_popup_pending_team)

func _create_defense_popup_god_card(god: God, is_selected: bool) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(90, 110)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95) if not is_selected else Color(0.15, 0.25, 0.15, 0.95)
	style.border_color = _get_element_color(god.element)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Portrait
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(50, 50)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var template_id = god.template_id if god.template_id else god.id
	var sprite_path = "res://assets/gods/" + template_id + ".png"
	if ResourceLoader.exists(sprite_path):
		texture_rect.texture = load(sprite_path)

	var img_center = CenterContainer.new()
	img_center.add_child(texture_rect)
	vbox.add_child(img_center)

	# Name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level and power
	var info_label = Label.new()
	var power = GodCalculator.get_power_rating(god)
	info_label.text = "Lv.%d | %s" % [god.level, _format_number(power)]
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# Dimmed if already selected
	if is_selected:
		var selected_overlay = ColorRect.new()
		selected_overlay.color = Color(0.1, 0.3, 0.1, 0.5)
		selected_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		selected_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(selected_overlay)

		var check_label = Label.new()
		check_label.text = "✓"
		check_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		check_label.add_theme_font_size_override("font_size", 20)
		check_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		check_label.offset_left = -25
		check_label.offset_top = 5
		card.add_child(check_label)
	else:
		# Make clickable to add
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_defense_popup_god_clicked(god)
		)

	return card

func _on_defense_popup_god_clicked(god: God) -> void:
	# Find first empty slot
	for i in range(defense_popup_pending_team.size()):
		if defense_popup_pending_team[i] == null:
			defense_popup_pending_team[i] = god
			_update_defense_popup_slot(i)
			_refresh_defense_popup_gods()
			_update_defense_popup_stats()
			break

func _clear_defense_popup_team() -> void:
	for i in range(defense_popup_pending_team.size()):
		defense_popup_pending_team[i] = null
		_update_defense_popup_slot(i)
	_refresh_defense_popup_gods()
	_update_defense_popup_stats()

func _confirm_defense_team() -> void:
	# Filter out nulls
	var valid_team = []
	for god in defense_popup_pending_team:
		if god != null:
			valid_team.append(god)

	if arena_manager:
		arena_manager.update_defense_team(valid_team)

	_close_defense_popup()
	_update_defense_display()
	_update_player_stats()

func _close_defense_popup() -> void:
	if defense_popup_overlay and is_instance_valid(defense_popup_overlay):
		defense_popup_overlay.queue_free()
		defense_popup_overlay = null
	defense_popup_team_slots.clear()
	defense_popup_gods_grid = null
	defense_popup_power_label = null
	defense_popup_bonuses_container = null
	defense_popup_sort_dropdown = null
	defense_popup_sort_btn = null

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_opponents_loaded(opponents: Array) -> void:
	_update_opponent_list(opponents)

func _on_defense_updated(success: bool) -> void:
	if success:
		_update_defense_display()
		_update_player_stats()

func _on_leaderboard_loaded(entries: Array) -> void:
	if not leaderboard_popup or not is_instance_valid(leaderboard_popup):
		return

	var list = leaderboard_popup.get_node_or_null("PanelContainer/VBoxContainer/ScrollContainer/LeaderboardList")
	if not list:
		return

	# Clear loading indicator
	for child in list.get_children():
		child.queue_free()

	# Populate leaderboard
	for entry in entries:
		var row = _create_leaderboard_row(entry)
		list.add_child(row)

func _create_leaderboard_row(entry: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var rank_label = Label.new()
	rank_label.text = "#%d" % entry.get("rank", 0)
	rank_label.custom_minimum_size = Vector2(40, 0)
	rank_label.add_theme_color_override("font_color", Color.GOLD if entry.get("rank", 0) <= 3 else Color(0.6, 0.6, 0.65))
	row.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = entry.get("display_name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	row.add_child(name_label)

	var league = entry.get("league", "bronze")
	var league_label = Label.new()
	league_label.text = league.capitalize()
	league_label.custom_minimum_size = Vector2(70, 0)
	league_label.add_theme_color_override("font_color", _get_league_color(league))
	row.add_child(league_label)

	var elo_lbl = Label.new()
	elo_lbl.text = str(entry.get("elo", 1000))
	elo_lbl.custom_minimum_size = Vector2(50, 0)
	elo_lbl.add_theme_color_override("font_color", Color.GOLD)
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(elo_lbl)

	return row

func _on_battle_result_processed(result: Dictionary) -> void:
	# Show result and refresh data
	_show_battle_result_popup(result)
	_refresh_data()

func _show_battle_result_popup(result: Dictionary) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 250)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Victory/Defeat header
	var victory = result.get("victory", false)
	var header = Label.new()
	header.text = "VICTORY!" if victory else "DEFEAT"
	header.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3) if victory else Color(0.8, 0.3, 0.3))
	header.add_theme_font_size_override("font_size", 28)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# ELO change
	var elo_change = result.get("elo_change", 0)
	var elo_text = Label.new()
	var change_str = "+%d" % elo_change if elo_change >= 0 else str(elo_change)
	elo_text.text = "ELO: %d (%s)" % [result.get("new_elo", 1000), change_str]
	elo_text.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5) if elo_change >= 0 else Color(0.8, 0.5, 0.5))
	elo_text.add_theme_font_size_override("font_size", 18)
	elo_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(elo_text)

	# League change notification
	if result.get("league_changed", false):
		var league_text = Label.new()
		var old_league = result.get("old_league", "bronze")
		var new_league = result.get("new_league", "bronze")
		league_text.text = "League: %s -> %s" % [old_league.capitalize(), new_league.capitalize()]
		league_text.add_theme_color_override("font_color", Color.GOLD)
		league_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(league_text)

	# Rewards
	var rewards = result.get("rewards", {})
	if not rewards.is_empty():
		var rewards_label = Label.new()
		var rewards_text = "Rewards: "
		var parts = []
		for resource in rewards:
			parts.append("%d %s" % [rewards[resource], resource])
		rewards_label.text = rewards_text + ", ".join(parts)
		rewards_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
		rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rewards_label)

	# OK button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(100, 40)
	_style_primary_button(ok_btn)
	ok_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(ok_btn)

func _on_battle_setup_complete(context: Dictionary) -> void:
	if selected_opponent.is_empty():
		return

	if not screen_manager or not arena_manager:
		return

	# Get battle coordinator
	var registry = _get_system_registry()
	var battle_coordinator = registry.get_system("BattleCoordinator") if registry else null
	if not battle_coordinator:
		push_error("[ArenaScreen] BattleCoordinator not available")
		return

	var selected_team = context.get("selected_team", [])

	# Filter valid gods
	var valid_team = []
	for god in selected_team:
		if god != null:
			valid_team.append(god)

	if valid_team.is_empty():
		push_error("[ArenaScreen] No valid gods in selected team")
		return

	# Create defender gods from opponent data
	var defender_team = []
	var defense_data = selected_opponent.get("defense_team", [])
	for god_data in defense_data:
		var defender_god = arena_manager.deserialize_god_for_battle(god_data)
		defender_team.append(defender_god)

	# Build battle config
	var battle_config = BattleConfig.new()
	battle_config.battle_type = BattleConfig.BattleType.ARENA
	battle_config.attacker_team = valid_team
	battle_config.defender_team = defender_team
	battle_config.opponent_player_id = selected_opponent.get("user_id", "")
	battle_config.arena_tier = selected_opponent.get("league", "bronze")

	# Navigate to battle
	if screen_manager.change_screen("battle"):
		var battle_screen = screen_manager.get_current_screen()
		if battle_screen and battle_screen.has_method("start_battle"):
			battle_screen.start_battle(battle_config)

			# Connect to battle end
			if battle_coordinator.has_signal("battle_ended"):
				if not battle_coordinator.battle_ended.is_connected(_on_pvp_battle_ended):
					battle_coordinator.battle_ended.connect(_on_pvp_battle_ended.bind(selected_opponent))
		else:
			battle_coordinator.start_battle(battle_config)

func _on_pvp_battle_ended(result: Dictionary, opponent: Dictionary) -> void:
	var victory = result.get("result", "") == "victory"

	if arena_manager:
		arena_manager.process_battle_result(victory, opponent)

	# Disconnect to avoid duplicate handling
	var registry = _get_system_registry()
	var battle_coordinator = registry.get_system("BattleCoordinator") if registry else null
	if battle_coordinator and battle_coordinator.has_signal("battle_ended"):
		if battle_coordinator.battle_ended.is_connected(_on_pvp_battle_ended):
			battle_coordinator.battle_ended.disconnect(_on_pvp_battle_ended)

func _on_battle_setup_cancelled() -> void:
	selected_opponent = {}

func _on_defense_setup_complete(context: Dictionary) -> void:
	var selected_team = context.get("selected_team", [])

	# Filter valid gods
	var valid_team = []
	for god in selected_team:
		if god != null:
			valid_team.append(god)

	if arena_manager:
		arena_manager.update_defense_team(valid_team)

	# Return to arena screen
	if screen_manager:
		screen_manager.change_screen("arena")
