# scripts/ui/tower/TowerInfoSection.gd
# Creates tower-specific info section for the left panel in team selection
class_name TowerInfoSection
extends RefCounted

static func create(tower_manager: TowerManager) -> Control:
	# Two-column layout: Floor info on left, Rewards on right
	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)

	# Left column: Floor info
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_col)

	# FLOOR: X
	var floor_row: HBoxContainer = _create_info_row(
		"FLOOR:",
		str(tower_manager.get_current_floor()) if tower_manager.is_run_active() else "1"
	)
	left_col.add_child(floor_row)

	# BEST: X (gold color)
	var best_row: HBoxContainer = _create_info_row(
		"BEST:",
		str(tower_manager.get_best_floor()),
		Color.GOLD
	)
	left_col.add_child(best_row)

	# DIFFICULTY: Easy/Medium/Hard (colored)
	var floor_num: int = tower_manager.get_current_floor() if tower_manager.is_run_active() else 1
	var difficulty: String = tower_manager.get_floor_difficulty_rating(floor_num)
	var diff_color: Color = _get_difficulty_color(difficulty)
	var diff_row: HBoxContainer = _create_info_row("DIFFICULTY:", difficulty, diff_color)
	left_col.add_child(diff_row)

	# Vertical separator
	var sep: VSeparator = VSeparator.new()
	main_hbox.add_child(sep)

	# Right column: Rewards info
	var right_col: VBoxContainer = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 2)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_col)

	var rewards_label: Label = Label.new()
	rewards_label.text = "FLOOR REWARDS"
	rewards_label.add_theme_font_size_override("font_size", 11)
	rewards_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	right_col.add_child(rewards_label)

	var rewards_info: Label = Label.new()
	rewards_info.text = "Mana, Gold & Materials\nHigher floors = better loot\nBoss (10th): 2.5x + Souls"
	rewards_info.add_theme_font_size_override("font_size", 10)
	rewards_info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	right_col.add_child(rewards_info)

	return main_hbox


static func _create_info_row(label_text: String, value_text: String, value_color: Color = Color(0.8, 0.8, 0.9)) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", value_color)
	row.add_child(value)

	return row


static func _get_difficulty_color(difficulty: String) -> Color:
	match difficulty.to_lower():
		"easy":
			return Color(0.4, 0.8, 0.4)
		"normal":
			return Color(0.8, 0.8, 0.4)
		"hard":
			return Color(0.9, 0.6, 0.2)
		"very hard":
			return Color(0.9, 0.3, 0.3)
		"extreme":
			return Color(0.8, 0.2, 0.8)
		"nightmare":
			return Color(0.6, 0.1, 0.1)
		_:
			return Color(0.8, 0.8, 0.9)
