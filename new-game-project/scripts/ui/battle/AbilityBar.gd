# scripts/ui/battle/AbilityBar.gd
# UI component for displaying and selecting battle abilities
# RULE 2: Single responsibility - ONLY displays skills and emits selection signal
# RULE 4: No logic in UI - just displays state from BattleUnit.skills
class_name AbilityBar extends PanelContainer

signal ability_selected(skill_index: int)

# Configuration
const MAX_SKILLS := 4
const BUTTON_SIZE := Vector2(100, 70)
const ICON_SIZE := Vector2(40, 40)

# Internal state
var current_unit: BattleUnit = null
var skill_buttons: Array[Button] = []
var cooldown_overlays: Array[Panel] = []

# UI elements
var buttons_container: HBoxContainer

func _ready():
	_setup_bar_structure()
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
	_style_skill_button(button, index)

	# Add icon (TextureRect for PNG or Label for emoji) at top of button
	var icon_container = TextureRect.new()
	icon_container.name = "IconTexture"
	icon_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.custom_minimum_size = Vector2(40, 40)
	icon_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	icon_container.offset_top = 5
	icon_container.offset_left = -20
	icon_container.offset_right = 20
	icon_container.offset_bottom = 45
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_container)

	# Fallback emoji label (used if no texture)
	var icon_label = Label.new()
	icon_label.name = "IconLabel"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	icon_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	icon_label.offset_top = 5
	icon_label.offset_bottom = 35
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.text = "⚔️"  # Default icon
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_label.visible = false  # Hidden by default, shown only if no texture
	button.add_child(icon_label)

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
	var icon_texture = button.get_node_or_null("IconTexture")
	var icon_label = button.get_node_or_null("IconLabel")

	# Try to load PNG texture first
	var texture_loaded = false
	if icon_texture and "icon_path" in skill and skill.icon_path:
		# Check if file exists before attempting to load
		if ResourceLoader.exists(skill.icon_path):
			var texture = load(skill.icon_path)
			if texture:
				icon_texture.texture = texture
				icon_texture.visible = true
				if icon_label:
					icon_label.visible = false
				texture_loaded = true

	# Fallback to emoji icon if no texture
	if not texture_loaded:
		if icon_texture:
			icon_texture.visible = false
		if icon_label:
			icon_label.visible = true
			# Check if skill has icon property (emoji)
			if "icon" in skill and skill.icon:
				icon_label.text = skill.icon
			else:
				# Default icons based on skill type
				var default_icon = "⚔️"
				if "damage" in skill.name.to_lower():
					default_icon = "⚔️"
				elif "heal" in skill.name.to_lower():
					default_icon = "❤️"
				elif "shield" in skill.name.to_lower() or "defend" in skill.name.to_lower():
					default_icon = "🛡️"
				elif "buff" in skill.name.to_lower():
					default_icon = "✨"
				icon_label.text = default_icon

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
