class_name CollectionDetailsPanel
extends RefCounted

"""
CollectionDetailsPanel.gd - Comprehensive god details display for collection screen
Features:
- Full stat breakdown (base + level + equipment = total)
- Equipment view with set bonuses
- Current assignments (garrison/worker)
- Hover/tap stat explanations
- Detailed abilities display
Following UI_DESIGN_PATTERNS.md styling conventions
"""

# =============================================================================
# COLOR PALETTE (from UI_DESIGN_PATTERNS.md)
# =============================================================================
const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)
const COLOR_SUCCESS = Color(0.5, 0.8, 0.5)
const COLOR_WARNING = Color(0.6, 0.4, 0.4)
const COLOR_INFO = Color(0.6, 0.8, 0.9)

# Stat-specific colors
const COLOR_HP = Color(0.4, 0.9, 0.4)
const COLOR_ATK = Color(1.0, 0.5, 0.4)
const COLOR_DEF = Color(0.4, 0.7, 1.0)
const COLOR_SPD = Color(0.9, 0.9, 0.4)
const COLOR_CRIT = Color(1.0, 0.6, 0.2)
const COLOR_RES = Color(0.7, 0.5, 0.9)
const COLOR_ACC = Color(0.5, 0.9, 0.9)

# Stat explanations for tooltips
const STAT_EXPLANATIONS = {
	"hp": "Hit Points - Total health. God is defeated when HP reaches 0.",
	"attack": "Attack - Determines damage dealt by skills that scale with ATK.",
	"defense": "Defense - Reduces incoming damage from attacks.",
	"speed": "Speed - Determines turn order. Higher speed = more frequent turns.",
	"crit_rate": "Critical Rate (%) - Chance to deal critical hits.",
	"crit_damage": "Critical Damage (%) - Bonus damage on critical hits.",
	"resistance": "Resistance (%) - Chance to resist debuffs.",
	"accuracy": "Accuracy (%) - Chance to land debuffs on enemies."
}

static func show_god_details(god: God, details_content: Control, no_selection_label: Label) -> void:
	"""Show comprehensive god details in the details panel"""

	# Clear existing content
	for child in details_content.get_children():
		if child != no_selection_label:
			child.queue_free()

	if no_selection_label:
		no_selection_label.visible = false

	await details_content.get_tree().process_frame

	# Add content directly to details_content (which is already inside a ScrollContainer)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "GodDetailsContent"
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 1. God Identity Section (Image + Name + Basic Info)
	var identity_section = _create_identity_section(god)
	content.add_child(identity_section)

	# 2. Level & Experience Section
	var xp_section = _create_xp_section(god)
	content.add_child(xp_section)

	# 3. Current Assignments Section
	var assignments_section = _create_assignments_section(god)
	content.add_child(assignments_section)

	# 4. Combat Stats Breakdown Section
	var stats_section = _create_stats_breakdown_section(god)
	content.add_child(stats_section)

	# 5. Equipment Section with Set Bonuses
	var equipment_section = _create_equipment_section(god)
	content.add_child(equipment_section)

	# 6. Abilities Section
	var abilities_section = _create_abilities_section(god)
	content.add_child(abilities_section)

	details_content.add_child(content)

# =============================================================================
# SECTION BUILDERS
# =============================================================================

static func _create_identity_section(god: God) -> VBoxContainer:
	"""Create god identity section with image and basic info"""
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	# God Image
	var image_container: CenterContainer = CenterContainer.new()
	var image_rect: TextureRect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(180, 180)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	var god_template = god.template_id if god.template_id else god.id
	var sprite_path: String = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		image_rect.texture = load(sprite_path)

	image_container.add_child(image_rect)
	section.add_child(image_container)

	# Name with tier color
	var name_label: Label = Label.new()
	name_label.text = god.get_display_name().to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", GodUIHelpers.get_tier_color(god.tier))
	section.add_child(name_label)

	# Awakened title if applicable
	if god.is_awakened and god.awakened_title != "":
		var title_label: Label = Label.new()
		title_label.text = god.awakened_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 12)
		title_label.add_theme_color_override("font_color", Color.GOLD)
		section.add_child(title_label)

	# Basic info row
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 20)

	# Pantheon
	var pantheon_label = _create_info_chip(god.pantheon.capitalize(), COLOR_INFO)
	info_row.add_child(pantheon_label)

	# Element
	var element_info = _create_info_chip(GodUIHelpers.get_element_name(god.element), GodUIHelpers.get_element_color(god.element))
	info_row.add_child(element_info)

	# Tier
	var tier_label = _create_info_chip(GodUIHelpers.get_tier_stars(god.tier), GodUIHelpers.get_tier_color(god.tier))
	info_row.add_child(tier_label)

	section.add_child(info_row)

	# Power Rating
	var power_row: HBoxContainer = HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var power_label: Label = Label.new()
	power_label.text = "⚔ Combat Power: %s" % _format_number(GodCalculator.get_combat_power(god))
	power_label.add_theme_font_size_override("font_size", 14)
	power_label.add_theme_color_override("font_color", Color.GOLD)
	power_row.add_child(power_label)
	section.add_child(power_row)

	return section

static func _create_xp_section(god: God) -> VBoxContainer:
	"""Create level and experience section"""
	var section = _create_section_container("LEVEL & EXPERIENCE")

	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	var progress_percent = god_exp_calc.get_experience_progress(god)
	var remaining_xp = god_exp_calc.get_experience_remaining_to_next_level(god)

	# Level display
	var level_row: HBoxContainer = HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.add_theme_constant_override("separation", 20)

	var level_label: Label = Label.new()
	level_label.text = "Level %d" % god.level
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", COLOR_HEADER)
	level_row.add_child(level_label)

	if god.level < 40:
		var xp_label: Label = Label.new()
		xp_label.text = "(%d XP to next)" % remaining_xp
		xp_label.add_theme_font_size_override("font_size", 12)
		xp_label.add_theme_color_override("font_color", COLOR_MUTED)
		level_row.add_child(xp_label)
	else:
		var max_label: Label = Label.new()
		max_label.text = "MAX LEVEL"
		max_label.add_theme_font_size_override("font_size", 12)
		max_label.add_theme_color_override("font_color", Color.GOLD)
		level_row.add_child(max_label)

	section.add_child(level_row)

	# XP Progress Bar
	var bar_container: MarginContainer = MarginContainer.new()
	bar_container.add_theme_constant_override("margin_left", 20)
	bar_container.add_theme_constant_override("margin_right", 20)

	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 16)
	xp_bar.min_value = 0.0
	xp_bar.max_value = 100.0
	xp_bar.value = progress_percent
	xp_bar.show_percentage = false

	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.3, 0.5, 0.8, 0.9)
	bar_style.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("fill", bar_style)

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	bar_bg.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("background", bar_bg)

	bar_container.add_child(xp_bar)
	section.add_child(bar_container)

	# Ascension level if applicable
	if god.ascension_level > 0:
		var asc_label: Label = Label.new()
		asc_label.text = "✦ Ascension Level: %d (+%d%% all stats)" % [god.ascension_level, god.ascension_level * 5]
		asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		asc_label.add_theme_font_size_override("font_size", 11)
		asc_label.add_theme_color_override("font_color", Color.GOLD)
		section.add_child(asc_label)

	return section

static func _create_assignments_section(god: God) -> VBoxContainer:
	"""Create current assignments section showing where god is deployed"""
	var section = _create_section_container("CURRENT ASSIGNMENTS")

	var has_assignment: bool = false

	# Check territory assignment
	if god.stationed_territory != "" and god.stationed_territory != null:
		has_assignment = true
		var territory_row = _create_assignment_row(
			"🏰 Territory",
			god.stationed_territory,
			god.territory_role.capitalize() if god.territory_role else "Stationed"
		)
		section.add_child(territory_row)

	# Check if working on tasks
	if god.is_working_on_task():
		has_assignment = true
		for task_id in god.current_tasks:
			var task_row = _create_assignment_row("⚒ Task", task_id, "Working")
			section.add_child(task_row)

	# No assignments
	if not has_assignment:
		var none_label: Label = Label.new()
		none_label.text = "No current assignments - available for battle!"
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		section.add_child(none_label)

	return section

static func _create_stats_breakdown_section(god: God) -> VBoxContainer:
	"""Create comprehensive stats breakdown showing base + level + equipment = total"""
	var section = _create_section_container("COMBAT STATS")

	# Calculate all stat components
	var stats_data = _calculate_stat_breakdown(god)

	# Create stat rows with breakdown
	var stats_grid: VBoxContainer = VBoxContainer.new()
	stats_grid.add_theme_constant_override("separation", 6)

	# Main stats
	stats_grid.add_child(_create_stat_row("HP", stats_data.hp, COLOR_HP, STAT_EXPLANATIONS.hp, god))
	stats_grid.add_child(_create_stat_row("Attack", stats_data.attack, COLOR_ATK, STAT_EXPLANATIONS.attack, god))
	stats_grid.add_child(_create_stat_row("Defense", stats_data.defense, COLOR_DEF, STAT_EXPLANATIONS.defense, god))
	stats_grid.add_child(_create_stat_row("Speed", stats_data.speed, COLOR_SPD, STAT_EXPLANATIONS.speed, god))

	# Separator
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	stats_grid.add_child(sep)

	# Secondary stats
	stats_grid.add_child(_create_stat_row("Crit Rate", stats_data.crit_rate, COLOR_CRIT, STAT_EXPLANATIONS.crit_rate, god, true))
	stats_grid.add_child(_create_stat_row("Crit Damage", stats_data.crit_damage, COLOR_CRIT, STAT_EXPLANATIONS.crit_damage, god, true))
	stats_grid.add_child(_create_stat_row("Resistance", stats_data.resistance, COLOR_RES, STAT_EXPLANATIONS.resistance, god, true))
	stats_grid.add_child(_create_stat_row("Accuracy", stats_data.accuracy, COLOR_ACC, STAT_EXPLANATIONS.accuracy, god, true))

	section.add_child(stats_grid)
	return section

static func _create_equipment_section(god: God) -> VBoxContainer:
	"""Create equipment section with set bonuses"""
	var section = _create_section_container("EQUIPMENT")

	var slot_names: Array = ["Weapon", "Armor", "Helm", "Boots", "Amulet", "Ring"]

	# Equipment grid (2 columns)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)

	# Track sets for bonus display
	var set_counts: Dictionary = {}
	var equipped_count: int = 0

	for i in range(6):
		var slot_container: HBoxContainer = HBoxContainer.new()
		slot_container.add_theme_constant_override("separation", 4)
		slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Slot icon
		var icon_label: Label = Label.new()
		icon_label.text = _get_slot_icon(i)
		icon_label.add_theme_font_size_override("font_size", 14)
		slot_container.add_child(icon_label)

		# Slot name
		var slot_label: Label = Label.new()
		slot_label.text = slot_names[i] + ":"
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.add_theme_color_override("font_color", COLOR_MUTED)
		slot_label.custom_minimum_size.x = 50
		slot_container.add_child(slot_label)

		# Equipment info
		var equip_label: Label = Label.new()
		equip_label.add_theme_font_size_override("font_size", 11)
		equip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if god.equipment.size() > i and god.equipment[i] != null:
			var eq = god.equipment[i]
			if eq is Equipment:
				equip_label.text = eq.name
				equip_label.add_theme_color_override("font_color", GodUIHelpers.get_rarity_color(eq.rarity))
				equipped_count += 1

				# Track set
				if eq.equipment_set_type != "":
					var set_type = eq.equipment_set_type
					set_counts[set_type] = set_counts.get(set_type, 0) + 1
		else:
			equip_label.text = "Empty"
			equip_label.add_theme_color_override("font_color", COLOR_WARNING)

		slot_container.add_child(equip_label)
		grid.add_child(slot_container)

	section.add_child(grid)

	# Equipment summary
	var summary_label: Label = Label.new()
	summary_label.text = "%d/6 slots equipped" % equipped_count
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 10)
	summary_label.add_theme_color_override("font_color", COLOR_SUCCESS if equipped_count > 0 else COLOR_MUTED)
	section.add_child(summary_label)

	# Set Bonuses Section
	if not set_counts.is_empty():
		var set_title: Label = Label.new()
		set_title.text = "── SET BONUSES ──"
		set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_title.add_theme_font_size_override("font_size", 11)
		set_title.add_theme_color_override("font_color", COLOR_HEADER)
		section.add_child(set_title)

		# Load set bonus config
		var set_config = _load_equipment_set_config()

		for set_type in set_counts:
			var count = set_counts[set_type]
			var set_row = _create_set_bonus_row(set_type, count, set_config)
			if set_row:
				section.add_child(set_row)

	return section

static func _create_abilities_section(god: God) -> VBoxContainer:
	"""Create detailed abilities section"""
	var section = _create_section_container("ABILITIES")

	var abilities_data = _load_abilities_data()
	var god_config = _load_god_config(god.template_id if god.template_id else god.id)
	var ability_ids = god_config.get("ability_ids", [])

	if ability_ids.is_empty():
		var no_skills: Label = Label.new()
		no_skills.text = "No abilities data available"
		no_skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_skills.add_theme_font_size_override("font_size", 11)
		no_skills.add_theme_color_override("font_color", COLOR_MUTED)
		section.add_child(no_skills)
		return section

	for i in range(ability_ids.size()):
		var ability_id = ability_ids[i]
		var skill_level = god.skill_levels[i] if i < god.skill_levels.size() else 1
		var ability_data = abilities_data.get(ability_id, {})

		var ability_panel = _create_ability_panel(ability_data, ability_id, skill_level, i + 1)
		section.add_child(ability_panel)

	return section

# =============================================================================
# HELPER CREATORS
# =============================================================================

static func _create_section_container(title: String) -> VBoxContainer:
	"""Create a styled section container with title"""
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var title_label: Label = Label.new()
	title_label.text = "══ %s ══" % title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", COLOR_HEADER)
	section.add_child(title_label)

	return section

static func _create_info_chip(text: String, color: Color) -> PanelContainer:
	"""Create a small info chip/badge"""
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.2)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)

	return panel

static func _create_assignment_row(type: String, location: String, role: String) -> HBoxContainer:
	"""Create an assignment info row"""
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var type_label: Label = Label.new()
	type_label.text = type
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", COLOR_INFO)
	type_label.custom_minimum_size.x = 80
	row.add_child(type_label)

	var loc_label: Label = Label.new()
	loc_label.text = location
	loc_label.add_theme_font_size_override("font_size", 11)
	loc_label.add_theme_color_override("font_color", COLOR_TEXT)
	loc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(loc_label)

	var role_chip = _create_info_chip(role, COLOR_SUCCESS)
	row.add_child(role_chip)

	return row

static func _create_stat_row(stat_name: String, stat_data: Dictionary, color: Color, explanation: String, god: God, is_percent: bool = false) -> PanelContainer:
	"""Create an interactive stat row with breakdown"""
	var panel: PanelContainer = PanelContainer.new()
	panel.tooltip_text = explanation

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.6)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Stat name with color indicator
	var name_container: HBoxContainer = HBoxContainer.new()
	name_container.add_theme_constant_override("separation", 4)

	var color_indicator: ColorRect = ColorRect.new()
	color_indicator.custom_minimum_size = Vector2(4, 16)
	color_indicator.color = color
	name_container.add_child(color_indicator)

	var name_label: Label = Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.custom_minimum_size.x = 80
	name_container.add_child(name_label)
	row.add_child(name_container)

	# Breakdown (base + level + equip)
	var breakdown: HBoxContainer = HBoxContainer.new()
	breakdown.add_theme_constant_override("separation", 4)
	breakdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var base_label: Label = Label.new()
	base_label.text = str(stat_data.base)
	base_label.add_theme_font_size_override("font_size", 10)
	base_label.add_theme_color_override("font_color", COLOR_MUTED)
	breakdown.add_child(base_label)

	if stat_data.level_bonus > 0:
		var plus1: Label = Label.new()
		plus1.text = "+"
		plus1.add_theme_font_size_override("font_size", 10)
		plus1.add_theme_color_override("font_color", COLOR_MUTED)
		breakdown.add_child(plus1)

		var level_label: Label = Label.new()
		level_label.text = str(stat_data.level_bonus)
		level_label.add_theme_font_size_override("font_size", 10)
		level_label.add_theme_color_override("font_color", COLOR_INFO)
		level_label.tooltip_text = "Level bonus"
		breakdown.add_child(level_label)

	if stat_data.equipment_bonus > 0:
		var plus2: Label = Label.new()
		plus2.text = "+"
		plus2.add_theme_font_size_override("font_size", 10)
		plus2.add_theme_color_override("font_color", COLOR_MUTED)
		breakdown.add_child(plus2)

		var equip_label: Label = Label.new()
		equip_label.text = str(stat_data.equipment_bonus)
		equip_label.add_theme_font_size_override("font_size", 10)
		equip_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		equip_label.tooltip_text = "Equipment bonus"
		breakdown.add_child(equip_label)

	row.add_child(breakdown)

	# Total value
	var total_label: Label = Label.new()
	var suffix: String = "%" if is_percent else ""
	total_label.text = str(stat_data.total) + suffix
	total_label.add_theme_font_size_override("font_size", 13)
	total_label.add_theme_color_override("font_color", color)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.custom_minimum_size.x = 50
	row.add_child(total_label)

	# Info button
	var info_btn: Label = Label.new()
	info_btn.text = "ⓘ"
	info_btn.add_theme_font_size_override("font_size", 12)
	info_btn.add_theme_color_override("font_color", COLOR_MUTED)
	info_btn.tooltip_text = explanation
	row.add_child(info_btn)

	panel.add_child(row)
	return panel

static func _create_set_bonus_row(set_type: String, count: int, config: Dictionary) -> HBoxContainer:
	"""Create a set bonus display row"""
	var set_info = config.get("sets", {}).get(set_type, {})
	if set_info.is_empty():
		return null

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Set name with count
	var set_color: Color = Color(set_info.get("color", "#FFFFFF"))
	var name_label: Label = Label.new()
	name_label.text = "%s (%d)" % [set_info.get("name", set_type.capitalize()), count]
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", set_color)
	name_label.custom_minimum_size.x = 100
	row.add_child(name_label)

	# Show active bonuses
	var bonuses_container: VBoxContainer = VBoxContainer.new()
	var bonuses = set_info.get("bonuses", {})

	for threshold in ["2", "4", "6"]:
		if bonuses.has(threshold):
			var bonus_data = bonuses[threshold]
			var threshold_int: int = int(threshold)
			var is_active = count >= threshold_int

			var bonus_label: Label = Label.new()
			bonus_label.text = "%s-pc: %s" % [threshold, bonus_data.get("description", "Bonus")]
			bonus_label.add_theme_font_size_override("font_size", 9)
			bonus_label.add_theme_color_override("font_color", COLOR_SUCCESS if is_active else COLOR_MUTED)
			bonuses_container.add_child(bonus_label)

	row.add_child(bonuses_container)
	return row

static func _create_ability_panel(ability_data: Dictionary, ability_id: String, skill_level: int, _slot_num: int) -> PanelContainer:
	"""Create a detailed ability panel with icon"""
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.7)
	style.border_color = Color(0.25, 0.2, 0.35, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# Ability Icon - fixed 50x50 size
	var icon_container: PanelContainer = PanelContainer.new()
	icon_container.custom_minimum_size = Vector2(54, 54)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.15, 0.12, 0.2, 0.8)
	icon_style.border_color = Color.YELLOW.darkened(0.3)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(4)
	icon_container.add_theme_stylebox_override("panel", icon_style)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.size = Vector2(50, 50)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	# Try to load ability icon
	var icon_path: String = "res://assets/abilities/%s.png" % ability_id
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		# Try with _nobg suffix
		icon_path = "res://assets/abilities/%s_nobg.png" % ability_id
		if ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)

	icon_container.add_child(icon_rect)
	content.add_child(icon_container)

	# Right side - ability info
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Header row: Name, Level, Cooldown
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	# Ability name
	var name_label: Label = Label.new()
	name_label.text = ability_data.get("name", ability_id.capitalize().replace("_", " "))
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.YELLOW)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	# Level badge
	var level_chip = _create_info_chip("Lv.%d" % skill_level, Color(0.4, 0.8, 1.0))
	header.add_child(level_chip)

	# Cooldown
	var cooldown = ability_data.get("cooldown", 0)
	var cd_label: Label = Label.new()
	cd_label.text = "CD: %d" % cooldown if cooldown > 0 else "No CD"
	cd_label.add_theme_font_size_override("font_size", 10)
	cd_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4) if cooldown > 0 else COLOR_SUCCESS)
	header.add_child(cd_label)

	info_vbox.add_child(header)

	# Stats row: Damage, Scaling, Targets
	var stats_row: HBoxContainer = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)

	var dmg_mult = ability_data.get("damage_multiplier", 0)
	var scaling = ability_data.get("scaling_stat", "ATK")
	var targets = ability_data.get("targets", "single")
	var hits = ability_data.get("hits", 1)

	if dmg_mult > 0:
		var dmg_container: HBoxContainer = HBoxContainer.new()
		dmg_container.add_theme_constant_override("separation", 4)

		var dmg_icon: Label = Label.new()
		dmg_icon.text = "⚔"
		dmg_icon.add_theme_font_size_override("font_size", 11)
		dmg_container.add_child(dmg_icon)

		var dmg_text: Label = Label.new()
		var dmg_str: String = "%.0f%% %s" % [dmg_mult * 100, scaling]
		if hits > 1:
			dmg_str += " x%d" % hits
		dmg_text.text = dmg_str
		dmg_text.add_theme_font_size_override("font_size", 10)
		dmg_text.add_theme_color_override("font_color", COLOR_ATK)
		dmg_container.add_child(dmg_text)

		stats_row.add_child(dmg_container)

	# Target type
	var target_container: HBoxContainer = HBoxContainer.new()
	target_container.add_theme_constant_override("separation", 4)

	var target_icon: Label = Label.new()
	target_icon.text = "🎯"
	target_icon.add_theme_font_size_override("font_size", 11)
	target_container.add_child(target_icon)

	var target_text: Label = Label.new()
	target_text.text = _format_target_type(targets)
	target_text.add_theme_font_size_override("font_size", 10)
	target_text.add_theme_color_override("font_color", COLOR_INFO)
	target_container.add_child(target_text)

	stats_row.add_child(target_container)
	info_vbox.add_child(stats_row)

	# Description
	var desc = ability_data.get("description", "No description available")
	var desc_label: Label = Label.new()
	desc_label.text = desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT)
	info_vbox.add_child(desc_label)

	# Effects (if any special effects)
	var effects = ability_data.get("effects", [])
	for effect in effects:
		if effect.get("type") == "debuff":
			var effect_label: Label = Label.new()
			var debuff_name = effect.get("debuff", "effect").capitalize()
			var chance = effect.get("chance", 100)
			var duration = effect.get("duration", 1)
			effect_label.text = "• %d%% chance: %s for %d turn(s)" % [chance, debuff_name, duration]
			effect_label.add_theme_font_size_override("font_size", 9)
			effect_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
			info_vbox.add_child(effect_label)

	content.add_child(info_vbox)
	panel.add_child(content)
	return panel

# =============================================================================
# DATA HELPERS
# =============================================================================

static func _calculate_stat_breakdown(god: God) -> Dictionary:
	"""Calculate breakdown for all stats showing base, level bonus, equipment bonus, total"""
	var breakdown: Dictionary = {}

	# HP
	var hp_base = god.base_hp
	var hp_level = (god.level - 1) * int(hp_base * 0.1)
	var hp_equip = _get_equipment_stat_bonus(god, "hp")
	breakdown.hp = {"base": hp_base, "level_bonus": hp_level, "equipment_bonus": hp_equip, "total": GodCalculator.get_current_hp(god)}

	# Attack
	var atk_base = god.base_attack
	var atk_level = (god.level - 1) * int(atk_base * 0.1)
	var atk_equip = _get_equipment_stat_bonus(god, "attack")
	breakdown.attack = {"base": atk_base, "level_bonus": atk_level, "equipment_bonus": atk_equip, "total": GodCalculator.get_current_attack(god)}

	# Defense
	var def_base = god.base_defense
	var def_level = (god.level - 1) * int(def_base * 0.1)
	var def_equip = _get_equipment_stat_bonus(god, "defense")
	breakdown.defense = {"base": def_base, "level_bonus": def_level, "equipment_bonus": def_equip, "total": GodCalculator.get_current_defense(god)}

	# Speed
	var spd_base = god.base_speed
	var spd_level = (god.level - 1) * int(spd_base * 0.05)
	var spd_equip = _get_equipment_stat_bonus(god, "speed")
	breakdown.speed = {"base": spd_base, "level_bonus": spd_level, "equipment_bonus": spd_equip, "total": GodCalculator.get_current_speed(god)}

	# Crit Rate (no level bonus)
	var cr_base = god.base_crit_rate
	var cr_equip = _get_equipment_stat_bonus(god, "crit_rate")
	breakdown.crit_rate = {"base": cr_base, "level_bonus": 0, "equipment_bonus": cr_equip, "total": GodCalculator.get_current_crit_rate(god)}

	# Crit Damage (no level bonus)
	var cd_base = god.base_crit_damage
	var cd_equip = _get_equipment_stat_bonus(god, "crit_damage")
	breakdown.crit_damage = {"base": cd_base, "level_bonus": 0, "equipment_bonus": cd_equip, "total": GodCalculator.get_current_crit_damage(god)}

	# Resistance (no level bonus)
	var res_base = god.base_resistance
	var res_equip = _get_equipment_stat_bonus(god, "resistance")
	breakdown.resistance = {"base": res_base, "level_bonus": 0, "equipment_bonus": res_equip, "total": GodCalculator.get_current_resistance(god)}

	# Accuracy (no level bonus)
	var acc_base = god.base_accuracy
	var acc_equip = _get_equipment_stat_bonus(god, "accuracy")
	breakdown.accuracy = {"base": acc_base, "level_bonus": 0, "equipment_bonus": acc_equip, "total": GodCalculator.get_current_accuracy(god)}

	return breakdown

static func _get_equipment_stat_bonus(god: God, stat_type: String) -> int:
	"""Get total equipment bonus for a stat"""
	var total: int = 0
	for equipment in god.equipment:
		if equipment and equipment is Equipment:
			if equipment.main_stat_type.to_lower() == stat_type.to_lower():
				total += equipment.main_stat_value if equipment.main_stat_value > 0 else equipment.main_stat_base
			for substat in equipment.substats:
				if substat.type.to_lower() == stat_type.to_lower():
					total += substat.value
	return total

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

static func _get_slot_icon(slot: int) -> String:
	match slot:
		0: return "⚔"   # Weapon
		1: return "🛡"   # Armor
		2: return "⛑"   # Helm
		3: return "👢"   # Boots
		4: return "📿"   # Amulet
		5: return "💍"   # Ring
		_: return "?"

static func _format_target_type(targets: String) -> String:
	match targets:
		"single": return "Single Target"
		"all_enemies": return "All Enemies"
		"all_allies": return "All Allies"
		"self": return "Self"
		"random_enemy": return "Random Enemy"
		_: return targets.capitalize().replace("_", " ")

static func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

# =============================================================================
# DATA LOADERS (with caching)
# =============================================================================

static var _cached_abilities: Dictionary = {}

static func _load_abilities_data() -> Dictionary:
	if not _cached_abilities.is_empty():
		return _cached_abilities

	var file = FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if not file:
		return {}

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		if data.has("abilities"):
			_cached_abilities = data.abilities
	file.close()

	return _cached_abilities

static var _cached_gods: Dictionary = {}

static func _load_god_config(god_id: String) -> Dictionary:
	if _cached_gods.has(god_id):
		return _cached_gods[god_id]

	var file = FileAccess.open("res://data/gods.json", FileAccess.READ)
	if not file:
		return {}

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		if data.has("gods") and data.gods.has(god_id):
			_cached_gods[god_id] = data.gods[god_id]
			file.close()
			return _cached_gods[god_id]
	file.close()
	return {}

static var _cached_set_config: Dictionary = {}

static func _load_equipment_set_config() -> Dictionary:
	if not _cached_set_config.is_empty():
		return _cached_set_config

	var file = FileAccess.open("res://data/equipment_set_bonuses.json", FileAccess.READ)
	if not file:
		return {}

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_cached_set_config = json.get_data()
	file.close()

	return _cached_set_config
