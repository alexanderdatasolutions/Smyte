# scripts/ui/battle/AbilityBar.gd
# UI component for displaying and selecting battle abilities
# RULE 2: Single responsibility - ONLY displays skills and emits selection signal
# RULE 4: No logic in UI - just displays state from BattleUnit.skills
class_name AbilityBar extends PanelContainer

signal ability_selected(skill_index: int)
signal ability_hovered(skill_index: int, skill: Skill)
signal ability_unhovered()

# Configuration
const MAX_SKILLS := 4
const BUTTON_SIZE := Vector2(120, 80)
const ICON_SIZE := Vector2(48, 48)

# Internal state
var current_unit: BattleUnit = null
var skill_buttons: Array[Button] = []
var cooldown_overlays: Array[Panel] = []
var tooltip_panel: PanelContainer = null
var hovered_skill_index: int = -1

# UI elements
var buttons_container: HBoxContainer
var tooltip_label: RichTextLabel

func _ready():
	_setup_bar_structure()
	_setup_tooltip()
	hide()  # Hidden by default, shown when unit's turn is active

func setup_unit(unit: BattleUnit):
	"""Setup ability bar with a battle unit's skills"""
	current_unit = unit

	if not buttons_container:
		_setup_bar_structure()

	_populate_skills()
	_update_cooldowns()
	show()

func clear():
	"""Clear the ability bar and hide it"""
	current_unit = null
	hide()
	_hide_tooltip()

func update_cooldowns():
	"""Update cooldown overlays based on current unit state"""
	if current_unit:
		_update_cooldowns()

func _setup_bar_structure():
	"""Create the ability bar UI structure"""
	# Style the container
	custom_minimum_size = Vector2(520, 100)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	# Horizontal container for skill buttons
	buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_theme_constant_override("separation", 12)
	margin.add_child(buttons_container)

	# Create skill button slots
	for i in range(MAX_SKILLS):
		var button_wrapper = _create_skill_button_slot(i)
		buttons_container.add_child(button_wrapper)

func _create_skill_button_slot(index: int) -> Control:
	"""Create a skill button slot with overlay for cooldowns"""
	var wrapper = Control.new()
	wrapper.custom_minimum_size = BUTTON_SIZE

	# Main skill button
	var button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = "Skill %d" % (index + 1)
	button.pressed.connect(_on_skill_button_pressed.bind(index))
	button.mouse_entered.connect(_on_skill_button_hover.bind(index))
	button.mouse_exited.connect(_on_skill_button_unhover.bind(index))
	_style_skill_button(button, index)
	wrapper.add_child(button)
	skill_buttons.append(button)

	# Cooldown overlay (semi-transparent dark panel over button)
	var cooldown_overlay = Panel.new()
	cooldown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.hide()

	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	overlay_style.corner_radius_top_left = 6
	overlay_style.corner_radius_top_right = 6
	overlay_style.corner_radius_bottom_left = 6
	overlay_style.corner_radius_bottom_right = 6
	cooldown_overlay.add_theme_stylebox_override("panel", overlay_style)

	# Cooldown number label
	var cd_label = Label.new()
	cd_label.name = "CooldownLabel"
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_label.add_theme_font_size_override("font_size", 28)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cooldown_overlay.add_child(cd_label)

	wrapper.add_child(cooldown_overlay)
	cooldown_overlays.append(cooldown_overlay)

	return wrapper

func _style_skill_button(button: Button, index: int):
	"""Apply styling to a skill button based on skill slot"""
	# Different colors for different skill slots
	var colors = [
		Color(0.3, 0.5, 0.3, 1.0),  # Skill 1 - Green (usually basic attack)
		Color(0.3, 0.4, 0.6, 1.0),  # Skill 2 - Blue
		Color(0.5, 0.3, 0.5, 1.0),  # Skill 3 - Purple
		Color(0.6, 0.4, 0.2, 1.0),  # Skill 4 - Orange (usually ultimate)
	]

	var base_color = colors[index] if index < colors.size() else Color(0.3, 0.3, 0.3)

	# Normal style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = base_color
	normal_style.border_color = base_color.lightened(0.3)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover style
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = base_color.lightened(0.2)
	hover_style.border_color = Color.WHITE
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed style
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = base_color.darkened(0.2)
	button.add_theme_stylebox_override("pressed", pressed_style)

	# Disabled style
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	disabled_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	button.add_theme_stylebox_override("disabled", disabled_style)

	# Font settings
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color.WHITE)

func _setup_tooltip():
	"""Create the tooltip panel for skill descriptions"""
	tooltip_panel = PanelContainer.new()
	tooltip_panel.custom_minimum_size = Vector2(250, 80)
	tooltip_panel.hide()
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	tooltip_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	tooltip_style.border_width_left = 1
	tooltip_style.border_width_right = 1
	tooltip_style.border_width_top = 1
	tooltip_style.border_width_bottom = 1
	tooltip_style.corner_radius_top_left = 4
	tooltip_style.corner_radius_top_right = 4
	tooltip_style.corner_radius_bottom_left = 4
	tooltip_style.corner_radius_bottom_right = 4
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)

	var tooltip_margin = MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 8)
	tooltip_margin.add_theme_constant_override("margin_right", 8)
	tooltip_margin.add_theme_constant_override("margin_top", 6)
	tooltip_margin.add_theme_constant_override("margin_bottom", 6)
	tooltip_panel.add_child(tooltip_margin)

	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.custom_minimum_size = Vector2(230, 0)
	tooltip_margin.add_child(tooltip_label)

	add_child(tooltip_panel)

func _populate_skills():
	"""Populate skill buttons with unit's skills"""
	if not current_unit:
		return

	for i in range(MAX_SKILLS):
		var button = skill_buttons[i]

		if i < current_unit.skills.size():
			var skill = current_unit.skills[i]
			button.visible = true
			_update_button_for_skill(button, skill, i)
		else:
			# No skill for this slot
			button.visible = false
			if i < cooldown_overlays.size():
				cooldown_overlays[i].hide()

func _update_button_for_skill(button: Button, skill: Skill, index: int):
	"""Update a button to display a skill"""
	# Build button text with skill name and cooldown info
	var text = skill.name
	if skill.cooldown > 0:
		text += "\n[CD: %d]" % skill.cooldown
	button.text = text

	# Tooltip data is handled in hover

func _update_cooldowns():
	"""Update all cooldown overlays based on current skill cooldowns"""
	if not current_unit:
		return

	for i in range(min(MAX_SKILLS, current_unit.skills.size())):
		var cooldown = 0
		if i < current_unit.skill_cooldowns.size():
			cooldown = current_unit.skill_cooldowns[i]

		var overlay = cooldown_overlays[i]
		var button = skill_buttons[i]

		if cooldown > 0:
			# Skill on cooldown - show overlay
			overlay.show()
			var cd_label = overlay.get_node("CooldownLabel")
			if cd_label:
				cd_label.text = str(cooldown)
			button.disabled = true
		else:
			# Skill available
			overlay.hide()
			button.disabled = false

func _on_skill_button_pressed(index: int):
	"""Handle skill button click"""
	if not current_unit:
		return

	# Check if skill is available (not on cooldown)
	if current_unit.can_use_skill(index):
		ability_selected.emit(index)
	else:
		# Could play a "not available" sound/effect here
		pass

func _on_skill_button_hover(index: int):
	"""Show tooltip when hovering over skill button"""
	if not current_unit or index >= current_unit.skills.size():
		return

	hovered_skill_index = index
	var skill = current_unit.skills[index]

	_show_tooltip(skill, index)
	ability_hovered.emit(index, skill)

func _on_skill_button_unhover(index: int):
	"""Hide tooltip when mouse leaves button"""
	hovered_skill_index = -1
	_hide_tooltip()
	ability_unhovered.emit()

func _show_tooltip(skill: Skill, index: int):
	"""Display the tooltip with skill information"""
	if not tooltip_panel or not tooltip_label:
		return

	var cooldown_text = ""
	if skill.cooldown > 0:
		var current_cd = 0
		if index < current_unit.skill_cooldowns.size():
			current_cd = current_unit.skill_cooldowns[index]
		if current_cd > 0:
			cooldown_text = " [color=red](CD: %d turns)[/color]" % current_cd
		else:
			cooldown_text = " [color=gray](CD: %d)[/color]" % skill.cooldown

	var target_text = ""
	if skill.target_count >= 99:
		target_text = "Targets: All"
	elif skill.target_count > 1:
		target_text = "Targets: %d" % skill.target_count
	else:
		target_text = "Targets: Single"

	if not skill.targets_enemies:
		target_text += " (Allies)"

	var damage_text = ""
	if skill.damage_multiplier > 0:
		damage_text = "Damage: %d%%" % int(skill.damage_multiplier * 100)

	# Build tooltip BBCode
	var bbcode = "[b][color=white]%s[/color][/b]%s\n" % [skill.name, cooldown_text]
	bbcode += "[color=gray]%s[/color]\n" % skill.description
	bbcode += "[color=cyan]%s[/color]" % target_text
	if damage_text != "":
		bbcode += " | [color=orange]%s[/color]" % damage_text

	tooltip_label.text = bbcode

	# Position tooltip above the ability bar
	tooltip_panel.show()
	tooltip_panel.position = Vector2(
		(custom_minimum_size.x - tooltip_panel.size.x) / 2,
		-tooltip_panel.size.y - 8
	)

func _hide_tooltip():
	"""Hide the tooltip panel"""
	if tooltip_panel:
		tooltip_panel.hide()

# =============================================================================
# PUBLIC API
# =============================================================================

func is_skill_available(index: int) -> bool:
	"""Check if a skill at given index is available (not on cooldown)"""
	if not current_unit or index >= current_unit.skills.size():
		return false
	return current_unit.can_use_skill(index)

func get_skill_at_index(index: int) -> Skill:
	"""Get the skill at given index"""
	if not current_unit or index >= current_unit.skills.size():
		return null
	return current_unit.skills[index]

func highlight_skill(index: int, should_highlight: bool):
	"""Highlight a specific skill button (e.g., for AI suggestion)"""
	if index < 0 or index >= skill_buttons.size():
		return

	var button = skill_buttons[index]
	if should_highlight:
		button.modulate = Color(1.2, 1.2, 0.8, 1.0)  # Slight glow
	else:
		button.modulate = Color.WHITE
