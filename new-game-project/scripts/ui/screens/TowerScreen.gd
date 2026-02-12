# scripts/ui/screens/TowerScreen.gd
# Infinite Tower UI Screen - BattleSetupScreen-style layout
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - Tower UI and navigation
extends Control

signal back_pressed

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")
const TeamStatsCalculator = preload("res://scripts/utilities/TeamStatsCalculator.gd")

# UI References
var floor_label: Label
var best_floor_label: Label
var difficulty_label: Label
var team_container: HBoxContainer
var team_power_label: Label
var team_bonuses_container: VBoxContainer
var gods_grid: GridContainer
var start_button: Button
var back_button: Button
var sort_buttons: Dictionary = {}

# System references
var tower_manager: Node
var collection_manager: Node
var battle_coordinator: Node
var screen_manager: Node

# State
var selected_team: Array = []  # Selected gods (up to 4)
var available_gods: Array = []  # All gods to choose from
var is_in_run: bool = false

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false

func _ready():
	_init_systems()
	_create_ui()
	_setup_header()
	_load_available_gods()
	_refresh_gods_grid()
	_update_team_display()
	_update_display()
	_connect_signals()
	# Apply full screen size after layout is ready
	call_deferred("_apply_fullscreen_size")

func _setup_header():
	"""Configure the unified GameHeader via MainUIOverlay"""
	var main_ui = get_node_or_null("/root/Main/MainUIOverlay")
	if main_ui:
		main_ui.set_screen_title("INFINITE TOWER")
		main_ui.show_header_back_button(true)
		main_ui.connect_header_back_button(_on_back_pressed)

func _apply_fullscreen_size():
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size
	position = Vector2.ZERO

func _init_systems():
	var registry = SystemRegistry.get_instance()
	if registry:
		tower_manager = registry.get_system("TowerManager")
		collection_manager = registry.get_system("CollectionManager")
		battle_coordinator = registry.get_system("BattleCoordinator")
		screen_manager = registry.get_system("ScreenManager")

func _create_ui():
	# Force this Control to fill entire viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dark background - fill entire screen
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout container with margins
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 10
	main_hbox.offset_top = 55
	main_hbox.offset_right = -10
	main_hbox.offset_bottom = -10
	main_hbox.add_theme_constant_override("separation", 15)
	add_child(main_hbox)

	# Left panel - tower info and team (fixed width)
	var left_panel = _create_left_panel()
	left_panel.custom_minimum_size.x = 400
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(left_panel)

	# Right panel - gods grid (scrollable, expands to fill)
	var right_panel = _create_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

func _create_left_panel() -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var margin = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "⚔️ INFINITE TOWER ⚔️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	# Floor info row
	var info_hbox = HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(info_hbox)

	# Floor
	var floor_vbox = VBoxContainer.new()
	info_hbox.add_child(floor_vbox)
	var floor_title = Label.new()
	floor_title.text = "FLOOR"
	floor_title.add_theme_font_size_override("font_size", 10)
	floor_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	floor_vbox.add_child(floor_title)
	floor_label = Label.new()
	floor_label.text = "1"
	floor_label.add_theme_font_size_override("font_size", 28)
	floor_vbox.add_child(floor_label)

	# Best
	var best_vbox = VBoxContainer.new()
	info_hbox.add_child(best_vbox)
	var best_title = Label.new()
	best_title.text = "BEST"
	best_title.add_theme_font_size_override("font_size", 10)
	best_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	best_vbox.add_child(best_title)
	best_floor_label = Label.new()
	best_floor_label.text = "0"
	best_floor_label.add_theme_font_size_override("font_size", 28)
	best_floor_label.add_theme_color_override("font_color", Color.GOLD)
	best_vbox.add_child(best_floor_label)

	# Difficulty
	var diff_vbox = VBoxContainer.new()
	info_hbox.add_child(diff_vbox)
	var diff_title = Label.new()
	diff_title.text = "DIFFICULTY"
	diff_title.add_theme_font_size_override("font_size", 10)
	diff_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	diff_vbox.add_child(diff_title)
	difficulty_label = Label.new()
	difficulty_label.text = "Normal"
	difficulty_label.add_theme_font_size_override("font_size", 16)
	difficulty_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	diff_vbox.add_child(difficulty_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Team section header
	var team_header = HBoxContainer.new()
	vbox.add_child(team_header)
	var team_title = Label.new()
	team_title.text = "YOUR TEAM"
	team_title.add_theme_font_size_override("font_size", 14)
	team_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	team_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_header.add_child(team_title)
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(60, 25)
	clear_btn.pressed.connect(_clear_team)
	_style_button(clear_btn)
	team_header.add_child(clear_btn)

	# Team slots
	team_container = HBoxContainer.new()
	team_container.add_theme_constant_override("separation", 8)
	team_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(team_container)

	# Team power display
	var power_hbox = HBoxContainer.new()
	power_hbox.add_theme_constant_override("separation", 10)
	power_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(power_hbox)

	var power_icon = Label.new()
	power_icon.text = "⚔️"
	power_icon.add_theme_font_size_override("font_size", 16)
	power_hbox.add_child(power_icon)

	var power_title = Label.new()
	power_title.text = "Combat Power:"
	power_title.add_theme_font_size_override("font_size", 12)
	power_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	power_hbox.add_child(power_title)

	team_power_label = Label.new()
	team_power_label.text = "0"
	team_power_label.add_theme_font_size_override("font_size", 16)
	team_power_label.add_theme_color_override("font_color", Color.GOLD)
	power_hbox.add_child(team_power_label)

	# Team bonuses container
	team_bonuses_container = VBoxContainer.new()
	team_bonuses_container.add_theme_constant_override("separation", 2)
	vbox.add_child(team_bonuses_container)

	# Separator
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	# Rewards info (compact)
	var rewards_title = Label.new()
	rewards_title.text = "FLOOR REWARDS"
	rewards_title.add_theme_font_size_override("font_size", 12)
	rewards_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(rewards_title)

	var rewards_info = Label.new()
	rewards_info.text = "• Mana, Gold & Materials\n• Higher floors = better loot\n• Boss (10th): 2.5x + Souls\n• Milestones: Crystals & Rare"
	rewards_info.add_theme_font_size_override("font_size", 10)
	rewards_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(rewards_info)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Start button
	start_button = Button.new()
	start_button.text = "⚔️ START CLIMB"
	start_button.custom_minimum_size = Vector2(0, 50)
	start_button.pressed.connect(_on_start_pressed)
	_style_button(start_button, true)
	vbox.add_child(start_button)

	return panel

func _create_right_panel() -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(panel)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	vbox.add_child(header_row)

	var header = Label.new()
	header.text = "SELECT GODS"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	# Sorting controls
	var sort_container = HBoxContainer.new()
	sort_container.add_theme_constant_override("separation", 5)
	header_row.add_child(sort_container)

	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 11)
	sort_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	sort_container.add_child(sort_label)

	# Create sort buttons
	var sort_options = [
		{"text": "⚔️", "tooltip": "Power", "type": SortType.POWER},
		{"text": "Lv", "tooltip": "Level", "type": SortType.LEVEL},
		{"text": "★", "tooltip": "Tier", "type": SortType.TIER},
		{"text": "◆", "tooltip": "Element", "type": SortType.ELEMENT},
		{"text": "Az", "tooltip": "Name", "type": SortType.NAME}
	]
	for option in sort_options:
		var btn = Button.new()
		btn.text = option.text
		btn.tooltip_text = option.tooltip
		btn.custom_minimum_size = Vector2(28, 24)
		btn.pressed.connect(_on_sort_changed.bind(option.type))
		_style_sort_button(btn, option.type == current_sort)
		sort_buttons[option.type] = btn
		sort_container.add_child(btn)

	# Sort direction button
	var dir_btn = Button.new()
	dir_btn.text = "↓" if not sort_ascending else "↑"
	dir_btn.tooltip_text = "Toggle sort direction"
	dir_btn.custom_minimum_size = Vector2(24, 24)
	dir_btn.pressed.connect(_on_sort_direction_changed)
	_style_sort_button(dir_btn, false)
	sort_buttons["direction"] = dir_btn
	sort_container.add_child(dir_btn)

	# Scrollable gods grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	gods_grid = GridContainer.new()
	gods_grid.columns = 5
	gods_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gods_grid.add_theme_constant_override("h_separation", 10)
	gods_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(gods_grid)

	return panel

func _load_available_gods():
	available_gods.clear()
	if collection_manager:
		available_gods = collection_manager.get_all_gods()
		_sort_gods()

func _sort_gods():
	"""Sort available gods based on current sort settings"""
	available_gods.sort_custom(func(a, b):
		var value_a
		var value_b
		match current_sort:
			SortType.POWER:
				value_a = TeamStatsCalculator.calculate_god_power(a)
				value_b = TeamStatsCalculator.calculate_god_power(b)
			SortType.LEVEL:
				value_a = a.level
				value_b = b.level
			SortType.TIER:
				value_a = a.tier
				value_b = b.tier
			SortType.ELEMENT:
				value_a = a.element
				value_b = b.element
			SortType.NAME:
				value_a = a.name
				value_b = b.name
		if sort_ascending:
			return value_a < value_b
		else:
			return value_a > value_b
	)

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change"""
	current_sort = sort_type
	_update_sort_button_styles()
	_sort_gods()
	_refresh_gods_grid()

func _on_sort_direction_changed():
	"""Handle sort direction toggle"""
	sort_ascending = not sort_ascending
	if sort_buttons.has("direction"):
		sort_buttons["direction"].text = "↑" if sort_ascending else "↓"
	_sort_gods()
	_refresh_gods_grid()

func _update_sort_button_styles():
	"""Update sort button visual states"""
	for key in sort_buttons:
		# Skip the direction button (string key)
		if typeof(key) == TYPE_STRING:
			continue
		var btn = sort_buttons[key]
		_style_sort_button(btn, key == current_sort)

func _style_sort_button(button: Button, is_active: bool):
	"""Style a sort button"""
	var style = StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.3, 0.25, 0.15, 0.95)
		style.border_color = Color(0.8, 0.65, 0.3, 1.0)
	else:
		style.bg_color = Color(0.12, 0.1, 0.15, 0.9)
		style.border_color = Color(0.3, 0.25, 0.4, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_font_size_override("font_size", 11)
	if is_active:
		button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	else:
		button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))

func _refresh_gods_grid():
	# Clear existing
	for child in gods_grid.get_children():
		child.queue_free()

	# Add god cards
	for god in available_gods:
		var card_container = _create_god_card_for_grid(god)
		gods_grid.add_child(card_container)

func _create_god_card_for_grid(god) -> Control:
	# Use a Panel container to hold the card
	var container = Panel.new()
	container.custom_minimum_size = Vector2(160, 200)

	# Transparent background for container
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0, 0, 0, 0)
	container.add_theme_stylebox_override("panel", container_style)

	# God card - use BATTLE_SELECTION for detailed cards
	var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.BATTLE_SELECTION)
	god_card.setup_god_card(god)
	god_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	god_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disable_mouse_on_children(god_card)
	container.add_child(god_card)

	# Selection overlay (shown when selected)
	var selection_overlay = ColorRect.new()
	selection_overlay.name = "SelectionOverlay"
	selection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_overlay.color = Color(0.2, 0.8, 0.3, 0.3)
	selection_overlay.visible = god in selected_team
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(selection_overlay)

	# Selection checkmark (top-right corner)
	var checkmark = Label.new()
	checkmark.name = "Checkmark"
	checkmark.text = "✓"
	checkmark.position = Vector2(132, 5)
	checkmark.add_theme_font_size_override("font_size", 24)
	checkmark.add_theme_color_override("font_color", Color.LIME_GREEN)
	checkmark.add_theme_constant_override("outline_size", 2)
	checkmark.add_theme_color_override("font_outline_color", Color.BLACK)
	checkmark.visible = god in selected_team
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(checkmark)

	# Click button
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.pressed.connect(_on_god_card_clicked.bind(god, container))
	container.add_child(click_btn)

	# Hover effect
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(1.0, 0.9, 0.5, 0.15)
	hover_style.set_corner_radius_all(8)
	click_btn.add_theme_stylebox_override("hover", hover_style)

	return container

func _on_god_card_clicked(god, container: Control):
	if god in selected_team:
		# Remove from team
		selected_team.erase(god)
	else:
		# Add to team if not full
		if selected_team.size() < 4:
			selected_team.append(god)

	# Update visuals
	var overlay = container.get_node_or_null("SelectionOverlay")
	var checkmark = container.get_node_or_null("Checkmark")
	if overlay:
		overlay.visible = god in selected_team
	if checkmark:
		checkmark.visible = god in selected_team

	_update_team_display()
	_update_display()

func _update_team_display():
	# Clear existing slots
	for child in team_container.get_children():
		child.queue_free()

	# Create 4 slots
	for i in range(4):
		var slot = _create_team_slot(i)
		team_container.add_child(slot)

	# Update team stats
	_update_team_stats()

func _update_team_stats():
	"""Update combat power and team bonuses display"""
	# Update combat power
	var total_power = TeamStatsCalculator.calculate_team_power(selected_team)
	if team_power_label:
		team_power_label.text = _format_number(total_power)

	# Update team bonuses
	if team_bonuses_container:
		# Clear existing bonuses
		for child in team_bonuses_container.get_children():
			child.queue_free()

		var bonuses = TeamStatsCalculator.get_team_bonuses(selected_team)
		if bonuses.is_empty():
			var no_bonus = Label.new()
			no_bonus.text = "No team bonuses"
			no_bonus.add_theme_font_size_override("font_size", 10)
			no_bonus.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			no_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			team_bonuses_container.add_child(no_bonus)
		else:
			for bonus in bonuses:
				var bonus_row = HBoxContainer.new()
				bonus_row.add_theme_constant_override("separation", 5)
				bonus_row.alignment = BoxContainer.ALIGNMENT_CENTER

				var name_label = Label.new()
				name_label.text = bonus.name + ":"
				name_label.add_theme_font_size_override("font_size", 10)
				name_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
				bonus_row.add_child(name_label)

				var desc_label = Label.new()
				desc_label.text = bonus.desc
				desc_label.add_theme_font_size_override("font_size", 10)
				desc_label.add_theme_color_override("font_color", Color.LIME_GREEN)
				bonus_row.add_child(desc_label)

				team_bonuses_container.add_child(bonus_row)

func _format_number(num: int) -> String:
	"""Format large numbers with K/M suffix"""
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _create_team_slot(index: int) -> Control:
	var container = Panel.new()
	container.custom_minimum_size = Vector2(85, 110)

	# Transparent container background
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0, 0, 0, 0)
	container.add_theme_stylebox_override("panel", container_style)

	if index < selected_team.size():
		var god = selected_team[index]
		# Compact god card for team slots
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_card.setup_god_card(god)
		god_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		god_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(god_card)
		container.add_child(god_card)

		# X button to remove
		var remove_btn = Button.new()
		remove_btn.text = "✕"
		remove_btn.position = Vector2(65, 2)
		remove_btn.custom_minimum_size = Vector2(18, 18)
		remove_btn.add_theme_font_size_override("font_size", 10)
		remove_btn.pressed.connect(_remove_from_team.bind(god))
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.6, 0.15, 0.15, 0.9)
		btn_style.set_corner_radius_all(9)
		remove_btn.add_theme_stylebox_override("normal", btn_style)
		container.add_child(remove_btn)
	else:
		# Empty slot
		var empty = Panel.new()
		empty.set_anchors_preset(Control.PRESET_FULL_RECT)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.2, 0.6)
		style.border_color = Color(0.3, 0.25, 0.4, 0.5)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		empty.add_theme_stylebox_override("panel", style)
		container.add_child(empty)

		var plus = Label.new()
		plus.text = "+"
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus.add_theme_font_size_override("font_size", 32)
		plus.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5, 0.6))
		container.add_child(plus)

	return container

func _remove_from_team(god):
	selected_team.erase(god)
	_refresh_gods_grid()  # Update checkmarks
	_update_team_display()
	_update_display()

func _clear_team():
	selected_team.clear()
	_refresh_gods_grid()
	_update_team_display()
	_update_display()

func _disable_mouse_on_children(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(child)

func _update_display():
	if not tower_manager:
		return

	var next_floor = 1
	if tower_manager.is_run_active():
		next_floor = tower_manager.get_current_floor() + 1
		is_in_run = true
		if start_button:
			start_button.text = "⚔️ CONTINUE CLIMB"
	else:
		is_in_run = false
		if start_button:
			if selected_team.size() > 0:
				start_button.text = "⚔️ START CLIMB (%d)" % selected_team.size()
			else:
				start_button.text = "⚔️ SELECT GODS"

	if floor_label:
		floor_label.text = str(next_floor)
	if best_floor_label:
		best_floor_label.text = str(tower_manager.get_best_floor())
	if difficulty_label:
		var diff = tower_manager.get_floor_difficulty_rating(next_floor)
		difficulty_label.text = diff
		match diff:
			"Normal": difficulty_label.add_theme_color_override("font_color", Color.LIME_GREEN)
			"Hard": difficulty_label.add_theme_color_override("font_color", Color.YELLOW)
			"Expert": difficulty_label.add_theme_color_override("font_color", Color.ORANGE)
			"Master": difficulty_label.add_theme_color_override("font_color", Color.RED)
			_: difficulty_label.add_theme_color_override("font_color", Color.PURPLE)

func _connect_signals():
	if tower_manager:
		if not tower_manager.floor_completed.is_connected(_on_floor_completed):
			tower_manager.floor_completed.connect(_on_floor_completed)
		if not tower_manager.tower_run_ended.is_connected(_on_run_ended):
			tower_manager.tower_run_ended.connect(_on_run_ended)

func _on_start_pressed():
	if selected_team.is_empty():
		_show_message("Select at least 1 god!")
		return

	if not tower_manager:
		return

	if not tower_manager.is_run_active():
		tower_manager.start_tower_run(selected_team)

	if battle_coordinator:
		var config = tower_manager.create_tower_battle_config()
		battle_coordinator.current_battle_config = config
		if not battle_coordinator.battle_ended.is_connected(_on_battle_ended):
			battle_coordinator.battle_ended.connect(_on_battle_ended)
		battle_coordinator.start_battle(config)
		if screen_manager:
			screen_manager.change_screen("battle")

func _on_battle_ended(result):
	if not tower_manager or not tower_manager.is_run_active():
		return

	# Save HP state from battle before advancing
	if battle_coordinator and battle_coordinator.battle_state:
		tower_manager.save_team_hp_from_battle(battle_coordinator.battle_state)

	if result.victory:
		tower_manager.complete_current_floor()
		tower_manager.advance_to_next_floor()
		_update_display()
		get_tree().create_timer(1.0).timeout.connect(func():
			if tower_manager.is_run_active():
				_on_start_pressed()
		)
	else:
		# Defeat - end the run (signal will trigger _on_run_ended which handles UI)
		tower_manager.end_tower_run(false)

func _on_floor_completed(_floor_num: int, _rewards: Dictionary):
	_update_display()

func _on_run_ended(final_floor: int, is_new_record: bool, total_rewards: Dictionary):
	# Navigate back to tower screen first (we might be on battle screen)
	if screen_manager:
		screen_manager.change_screen("tower")

	_update_display()

	# Show result popup after a short delay (to let screen transition complete)
	get_tree().create_timer(0.3).timeout.connect(func():
		_show_run_result(final_floor, is_new_record, total_rewards)
	)

func _show_run_result(final_floor: int, is_new_record: bool, total_rewards: Dictionary):
	var popup = PanelContainer.new()
	popup.z_index = 100
	_style_panel(popup)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "🏆 NEW RECORD! 🏆" if is_new_record else "RUN ENDED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.GOLD if is_new_record else Color.WHITE)
	vbox.add_child(title)

	# Floor reached
	var floor_text = Label.new()
	floor_text.text = "Reached Floor %d" % final_floor
	floor_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_text.add_theme_font_size_override("font_size", 18)
	vbox.add_child(floor_text)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Rewards section
	if not total_rewards.is_empty():
		var rewards_title = Label.new()
		rewards_title.text = "TOTAL LOOT EARNED"
		rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rewards_title.add_theme_font_size_override("font_size", 14)
		rewards_title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		vbox.add_child(rewards_title)

		# Scrollable rewards container (in case of many rewards)
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(300, 150)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vbox.add_child(scroll)

		var rewards_grid = GridContainer.new()
		rewards_grid.columns = 2
		rewards_grid.add_theme_constant_override("h_separation", 20)
		rewards_grid.add_theme_constant_override("v_separation", 5)
		scroll.add_child(rewards_grid)

		# Sort rewards by importance (currencies first, then materials)
		var sorted_rewards = _sort_rewards_for_display(total_rewards)
		for item in sorted_rewards:
			var name_label = Label.new()
			name_label.text = _get_resource_display_name(item.id)
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.add_theme_color_override("font_color", _get_resource_color(item.id))
			rewards_grid.add_child(name_label)

			var amount_label = Label.new()
			amount_label.text = "x%s" % _format_number(item.amount)
			amount_label.add_theme_font_size_override("font_size", 12)
			amount_label.add_theme_color_override("font_color", Color.WHITE)
			amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rewards_grid.add_child(amount_label)
	else:
		var no_loot = Label.new()
		no_loot.text = "No loot earned (defeated on floor 1)"
		no_loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_loot.add_theme_font_size_override("font_size", 12)
		no_loot.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		vbox.add_child(no_loot)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.pressed.connect(func(): popup.queue_free())
	_style_button(close_btn)
	vbox.add_child(close_btn)

	add_child(popup)
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	popup.position = (viewport_size - popup.size) / 2

func _sort_rewards_for_display(rewards: Dictionary) -> Array:
	"""Sort rewards into display order: currencies, souls, materials"""
	var currency_order = ["mana", "gold", "divine_crystals", "energy"]
	var soul_order = ["common_soul", "rare_soul", "epic_soul", "legendary_soul"]

	var sorted = []
	# Add currencies first
	for currency in currency_order:
		if rewards.has(currency):
			sorted.append({"id": currency, "amount": rewards[currency]})

	# Add souls
	for soul in soul_order:
		if rewards.has(soul):
			sorted.append({"id": soul, "amount": rewards[soul]})

	# Add remaining items (materials, etc.)
	for key in rewards:
		if key not in currency_order and key not in soul_order:
			sorted.append({"id": key, "amount": rewards[key]})

	return sorted

func _get_resource_display_name(resource_id: String) -> String:
	"""Get a display-friendly name for a resource"""
	var names = {
		"mana": "Mana",
		"gold": "Gold",
		"divine_crystals": "Divine Crystals",
		"common_soul": "Common Soul",
		"rare_soul": "Rare Soul",
		"epic_soul": "Epic Soul",
		"legendary_soul": "Legendary Soul",
		"awakening_essence": "Awakening Essence",
		"divine_essence": "Divine Essence",
		"ore": "Ore",
		"wood": "Wood",
		"herbs": "Herbs",
		"refined_metal": "Refined Metal",
		"fine_ore": "Fine Ore",
		"steel_ingot": "Steel Ingot",
		"arcane_ore": "Arcane Ore",
		"prometheum": "Prometheum",
		"monster_parts": "Monster Parts",
		"beast_scales": "Beast Scales",
		"elemental_cores": "Elemental Cores",
		"basic_flame": "Basic Flame",
		"forging_flame": "Forging Flame",
		"divine_flame": "Divine Flame",
		"eternal_flame": "Eternal Flame",
		"socket_crystal": "Socket Crystal",
		"astral_shard": "Astral Shard",
		"divine_metal": "Divine Metal",
		"ascension_crystal": "Ascension Crystal"
	}
	# Handle element powders
	if resource_id.ends_with("_powder"):
		var element = resource_id.replace("_powder", "").capitalize()
		return element + " Powder"
	return names.get(resource_id, resource_id.capitalize().replace("_", " "))

func _get_resource_color(resource_id: String) -> Color:
	"""Get color for resource display"""
	if resource_id == "mana":
		return Color(0.4, 0.6, 1.0)
	elif resource_id == "gold":
		return Color.GOLD
	elif resource_id == "divine_crystals":
		return Color(0.8, 0.5, 1.0)
	elif resource_id.ends_with("_soul"):
		match resource_id:
			"common_soul": return Color(0.7, 0.7, 0.7)
			"rare_soul": return Color(0.3, 0.7, 1.0)
			"epic_soul": return Color(0.8, 0.4, 1.0)
			"legendary_soul": return Color(1.0, 0.8, 0.2)
	elif resource_id.ends_with("_powder"):
		# Element colors
		if "fire" in resource_id: return Color(1.0, 0.4, 0.3)
		if "water" in resource_id: return Color(0.3, 0.6, 1.0)
		if "earth" in resource_id: return Color(0.6, 0.4, 0.2)
		if "lightning" in resource_id: return Color(1.0, 1.0, 0.3)
		if "light" in resource_id: return Color(1.0, 1.0, 0.8)
		if "dark" in resource_id: return Color(0.5, 0.3, 0.7)
	elif resource_id.ends_with("_flame"):
		return Color(1.0, 0.6, 0.2)
	elif "essence" in resource_id:
		return Color(0.6, 0.9, 0.6)
	return Color(0.8, 0.8, 0.85)

func _on_back_pressed():
	back_pressed.emit()
	if screen_manager:
		screen_manager.change_screen("worldview")

func _show_message(text: String):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.z_index = 100
	add_child(label)
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2((viewport_size.x - label.size.x) / 2, viewport_size.y / 2)
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _style_panel(panel: PanelContainer):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool = false):
	var style_normal = StyleBoxFlat.new()
	if primary:
		style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
		style_normal.border_color = Color(0.3, 0.7, 0.4, 1.0)
	else:
		style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.1)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_font_size_override("font_size", 14)
