# scripts/ui/battle_setup/TeamStatsPanel.gd
# Creates and manages the left-side stats panel (team header, combat power, bonuses, equipment, enemies, rewards)
extends RefCounted

var team_slots_container: HBoxContainer = null
var team_power_label: Label = null
var team_bonuses_container: VBoxContainer = null
var leader_skill_container: VBoxContainer = null  # Leader skill display
var enemy_preview_container: VBoxContainer = null
var enemy_section_separator: HSeparator = null  # For hiding enemy section
var enemy_section_header: Label = null  # For hiding enemy section
var rewards_preview_container: VBoxContainer = null
var stats_panel: Control = null
var custom_section_container: VBoxContainer = null  # Container for dynamic top section updates

# Saved teams dropdown
var saved_teams_dropdown: OptionButton = null

# Callbacks for team actions
var on_clear_team: Callable
var on_save_team: Callable
var on_load_team: Callable  # Now takes team_name as parameter

func create_stats_panel(
	clear_callback: Callable,
	show_equipment: bool = true,
	show_enemies: bool = true,
	show_rewards: bool = true,
	custom_top_section: Control = null,
	save_callback: Callable = Callable(),
	load_callback: Callable = Callable()
) -> Control:
	on_clear_team = clear_callback
	on_save_team = save_callback
	on_load_team = load_callback

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 0)
	_style_panel(panel)

	# Wrap content in ScrollContainer for overflow handling
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Team header with clear button
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	var team_title: Label = Label.new()
	team_title.text = "YOUR TEAM"
	team_title.add_theme_font_size_override("font_size", 14)
	team_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	team_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(team_title)

	var clear_btn: Button = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(50, 28)
	clear_btn.pressed.connect(func() -> void: on_clear_team.call())
	_style_button(clear_btn)
	header_row.add_child(clear_btn)

	# Saved teams row (dropdown + save button)
	if on_save_team.is_valid() or on_load_team.is_valid():
		var saved_row: HBoxContainer = HBoxContainer.new()
		saved_row.add_theme_constant_override("separation", 6)
		vbox.add_child(saved_row)

		var saved_label: Label = Label.new()
		saved_label.text = "Saved:"
		saved_label.add_theme_font_size_override("font_size", 11)
		saved_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		saved_row.add_child(saved_label)

		saved_teams_dropdown = OptionButton.new()
		saved_teams_dropdown.custom_minimum_size = Vector2(140, 28)
		saved_teams_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		saved_teams_dropdown.add_theme_font_size_override("font_size", 11)
		saved_teams_dropdown.item_selected.connect(_on_saved_team_selected)
		_refresh_saved_teams_dropdown()
		_connect_to_team_save_manager()
		saved_row.add_child(saved_teams_dropdown)

		if on_save_team.is_valid():
			var save_btn: Button = Button.new()
			save_btn.text = "💾"
			save_btn.tooltip_text = "Save current team"
			save_btn.custom_minimum_size = Vector2(32, 28)
			save_btn.pressed.connect(func() -> void: on_save_team.call())
			_style_button(save_btn)
			saved_row.add_child(save_btn)

	# Team slots container
	team_slots_container = HBoxContainer.new()
	team_slots_container.add_theme_constant_override("separation", 6)
	team_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(team_slots_container)

	# Leader skill display (below team slots)
	leader_skill_container = VBoxContainer.new()
	leader_skill_container.add_theme_constant_override("separation", 4)
	vbox.add_child(leader_skill_container)

	# Container for custom top section (e.g., tower floor info) - always created for dynamic updates
	custom_section_container = VBoxContainer.new()
	custom_section_container.add_theme_constant_override("separation", 0)
	vbox.add_child(custom_section_container)
	if custom_top_section:
		custom_section_container.add_child(custom_top_section)

	# Combat power display
	var power_hbox: HBoxContainer = HBoxContainer.new()
	power_hbox.add_theme_constant_override("separation", 10)
	power_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(power_hbox)

	var power_title: Label = Label.new()
	power_title.text = "Combat Power:"
	power_title.add_theme_font_size_override("font_size", 13)
	power_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	power_hbox.add_child(power_title)

	team_power_label = Label.new()
	team_power_label.text = "0"
	team_power_label.add_theme_font_size_override("font_size", 18)
	team_power_label.add_theme_color_override("font_color", Color.GOLD)
	power_hbox.add_child(team_power_label)

	# Team bonuses section
	var bonuses_header: Label = Label.new()
	bonuses_header.text = "TEAM BONUSES"
	bonuses_header.add_theme_font_size_override("font_size", 12)
	bonuses_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(bonuses_header)

	team_bonuses_container = VBoxContainer.new()
	team_bonuses_container.add_theme_constant_override("separation", 4)
	vbox.add_child(team_bonuses_container)

	# Equipment summary section (conditional)
	if show_equipment:
		var equip_header: Label = Label.new()
		equip_header.text = "EQUIPMENT"
		equip_header.add_theme_font_size_override("font_size", 12)
		equip_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		vbox.add_child(equip_header)

		var equip_container: VBoxContainer = VBoxContainer.new()
		equip_container.name = "EquipmentContainer"
		equip_container.add_theme_constant_override("separation", 4)
		vbox.add_child(equip_container)

	# Enemy preview section (conditional)
	if show_enemies:
		enemy_section_separator = HSeparator.new()
		enemy_section_separator.add_theme_constant_override("separation", 8)
		vbox.add_child(enemy_section_separator)

		enemy_section_header = Label.new()
		enemy_section_header.text = "ENEMIES"
		enemy_section_header.add_theme_font_size_override("font_size", 12)
		enemy_section_header.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		vbox.add_child(enemy_section_header)

		enemy_preview_container = VBoxContainer.new()
		enemy_preview_container.add_theme_constant_override("separation", 4)
		vbox.add_child(enemy_preview_container)

	# Battle rewards section (conditional)
	if show_rewards:
		var sep2: HSeparator = HSeparator.new()
		sep2.add_theme_constant_override("separation", 8)
		vbox.add_child(sep2)

		var rewards_header: Label = Label.new()
		rewards_header.text = "BATTLE REWARDS"
		rewards_header.add_theme_font_size_override("font_size", 12)
		rewards_header.add_theme_color_override("font_color", Color(0.4, 0.7, 0.9))
		vbox.add_child(rewards_header)

		rewards_preview_container = VBoxContainer.new()
		rewards_preview_container.add_theme_constant_override("separation", 4)
		vbox.add_child(rewards_preview_container)

	stats_panel = panel
	return panel

func update_team_stats(selected_team: Array) -> void:
	if not team_power_label:
		return

	var total_power: int = TeamStatsCalculator.calculate_team_power(selected_team)
	team_power_label.text = _format_number(total_power)

	_update_leader_skill_display(selected_team)
	_update_team_bonuses_display(selected_team)

func _update_leader_skill_display(selected_team: Array) -> void:
	if not leader_skill_container:
		return

	for child: Node in leader_skill_container.get_children():
		child.queue_free()

	var leader_info: Dictionary = TeamStatsCalculator.get_leader_skill_info(selected_team)

	if leader_info.is_empty():
		# Show "No leader skill" when first slot is empty or god has no leader skill
		var no_skill: Label = Label.new()
		no_skill.text = "No leader skill"
		no_skill.add_theme_font_size_override("font_size", 11)
		no_skill.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		leader_skill_container.add_child(no_skill)
		return

	# Leader skill header row with crown icon
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	leader_skill_container.add_child(header_row)

	var crown_label: Label = Label.new()
	crown_label.text = "👑"  # Crown emoji for leader
	crown_label.add_theme_font_size_override("font_size", 14)
	header_row.add_child(crown_label)

	var leader_label: Label = Label.new()
	leader_label.text = "%s" % leader_info.leader_name
	leader_label.add_theme_font_size_override("font_size", 12)
	leader_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))  # Gold color
	leader_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(leader_label)

	# Skill name row
	var skill_name_row: HBoxContainer = HBoxContainer.new()
	skill_name_row.add_theme_constant_override("separation", 6)
	leader_skill_container.add_child(skill_name_row)

	var skill_name_label: Label = Label.new()
	skill_name_label.text = "「%s」" % leader_info.skill_name
	skill_name_label.add_theme_font_size_override("font_size", 11)
	skill_name_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))  # Orange-gold
	skill_name_row.add_child(skill_name_label)

	# Skill description row
	var desc_row: HBoxContainer = HBoxContainer.new()
	desc_row.add_theme_constant_override("separation", 6)
	leader_skill_container.add_child(desc_row)

	var desc_label: Label = Label.new()
	desc_label.text = leader_info.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))  # Green for bonus
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_row.add_child(desc_label)

	# Show applicability if not all team members
	if leader_info.applicable_count < leader_info.total_count:
		var applies_label: Label = Label.new()
		applies_label.text = "(%d/%d)" % [leader_info.applicable_count, leader_info.total_count]
		applies_label.add_theme_font_size_override("font_size", 10)
		applies_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		applies_label.tooltip_text = "Applies to %d of %d team members" % [leader_info.applicable_count, leader_info.total_count]
		desc_row.add_child(applies_label)

func _update_team_bonuses_display(selected_team: Array) -> void:
	if not team_bonuses_container:
		return

	for child: Node in team_bonuses_container.get_children():
		child.queue_free()

	var bonuses: Array = TeamStatsCalculator.get_team_bonuses(selected_team)

	if bonuses.is_empty():
		var no_bonus: Label = Label.new()
		no_bonus.text = "No active bonuses"
		no_bonus.add_theme_font_size_override("font_size", 11)
		no_bonus.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		team_bonuses_container.add_child(no_bonus)
	else:
		for bonus: Dictionary in bonuses:
			var bonus_row: HBoxContainer = HBoxContainer.new()
			bonus_row.add_theme_constant_override("separation", 6)

			var name_label: Label = Label.new()
			name_label.text = bonus.name
			name_label.add_theme_font_size_override("font_size", 11)
			name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bonus_row.add_child(name_label)

			var desc_label: Label = Label.new()
			desc_label.text = bonus.desc
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			bonus_row.add_child(desc_label)

			team_bonuses_container.add_child(bonus_row)

func update_custom_top_section(new_content: Control) -> void:
	"""Replace the content of the custom top section (e.g., tower floor info refresh)."""
	if not custom_section_container:
		return

	# Remove old content
	for child: Node in custom_section_container.get_children():
		child.queue_free()

	# Add new content
	if new_content:
		custom_section_container.add_child(new_content)

# ============================================================================
# HELPERS
# ============================================================================

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

func _style_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button) -> void:
	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover: StyleBoxFlat = style_normal.duplicate()
	style_hover.bg_color = style_normal.bg_color.lightened(0.15)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_font_size_override("font_size", 11)

# ============================================================================
# SAVED TEAMS DROPDOWN
# ============================================================================

func _connect_to_team_save_manager() -> void:
	"""Connect to TeamSaveManager's teams_changed signal to refresh dropdown when cloud data loads."""
	var registry: Node = SystemRegistry.get_instance()
	var team_save_manager: Node = registry.get_system("TeamSaveManager") if registry else null
	if team_save_manager and team_save_manager.has_signal("teams_changed"):
		if not team_save_manager.teams_changed.is_connected(_refresh_saved_teams_dropdown):
			team_save_manager.teams_changed.connect(_refresh_saved_teams_dropdown)

func _refresh_saved_teams_dropdown() -> void:
	"""Refresh the saved teams dropdown with current saved teams."""
	if not saved_teams_dropdown:
		return

	saved_teams_dropdown.clear()
	saved_teams_dropdown.add_item("-- Select Team --")
	saved_teams_dropdown.set_item_disabled(0, true)

	var registry: Node = SystemRegistry.get_instance()
	var team_save_manager: Node = registry.get_system("TeamSaveManager") if registry else null
	if not team_save_manager:
		return

	var saved_names: Array = team_save_manager.get_saved_team_names()
	for team_name: String in saved_names:
		saved_teams_dropdown.add_item(team_name)

	saved_teams_dropdown.selected = 0

func _on_saved_team_selected(index: int) -> void:
	"""Handle selection from the saved teams dropdown."""
	if index <= 0:  # Skip the "-- Select Team --" placeholder
		return

	if not on_load_team.is_valid():
		return

	var team_name: String = saved_teams_dropdown.get_item_text(index)
	on_load_team.call(team_name)

	# Reset dropdown to placeholder after loading
	saved_teams_dropdown.selected = 0

func refresh_saved_teams() -> void:
	"""Public method to refresh the dropdown (call after save/delete)."""
	_refresh_saved_teams_dropdown()

func set_enemy_section_visible(visible: bool) -> void:
	"""Show or hide the enemies section dynamically."""
	if enemy_section_separator:
		enemy_section_separator.visible = visible
	if enemy_section_header:
		enemy_section_header.visible = visible
	if enemy_preview_container:
		enemy_preview_container.visible = visible
