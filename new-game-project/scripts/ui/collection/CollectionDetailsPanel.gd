class_name CollectionDetailsPanel
extends RefCounted

"""
CollectionDetailsPanel.gd - Handles god details display for collection screen
RULE 1: Single responsibility - ONLY handles details panel display
Extracted from CollectionScreen.gd to reduce file size and improve maintainability
"""

static func show_god_details(god: God, details_content: Control, no_selection_label: Label) -> void:
	"""Show god details in the details panel - EXACTLY like old version with full styling"""

	# Clear existing content
	for child in details_content.get_children():
		if child != no_selection_label:
			child.queue_free()

	# Hide no selection label
	if no_selection_label:
		no_selection_label.visible = false

	# Wait a frame for cleanup
	await details_content.get_tree().process_frame

	# Create content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)

	# God Image
	var image_container = TextureRect.new()
	image_container.custom_minimum_size = Vector2(200, 200)
	image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	# Load god image based on god ID
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		image_container.texture = load(sprite_path)
	else:
		# Fallback - create a colored rectangle
		var placeholder = ColorRect.new()
		placeholder.color = _get_tier_border_color(god.tier)
		placeholder.custom_minimum_size = Vector2(200, 200)
		content.add_child(placeholder)
		image_container = null

	if image_container:
		content.add_child(image_container)

	# Basic Info Section
	var info_section = VBoxContainer.new()
	var info_title = Label.new()
	info_title.text = "═══ " + god.name.to_upper() + " ═══"
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 18)
	info_title.add_theme_color_override("font_color", _get_tier_border_color(god.tier))
	info_section.add_child(info_title)

	var basic_info = Label.new()
	basic_info.text = """Pantheon: %s
Element: %s
Tier: %s
Level: %d
Power: %d""" % [
		god.pantheon, _get_element_name(god.element),
		_get_tier_name(god.tier), god.level, GodCalculator.get_power_rating(god)
	]
	basic_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_section.add_child(basic_info)
	content.add_child(info_section)

	# XP Section
	var xp_section = VBoxContainer.new()
	var xp_title = Label.new()
	xp_title.text = "═══ EXPERIENCE ═══"
	xp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_title.add_theme_font_size_override("font_size", 14)
	xp_section.add_child(xp_title)

	# Use centralized experience calculator
	var god_exp_calc = preload("res://scripts/utilities/GodExperienceCalculator.gd")
	var current_xp = god.experience
	var remaining_xp = god_exp_calc.get_experience_remaining_to_next_level(god)
	var progress_percent = god_exp_calc.get_experience_progress(god)
	var next_level_total = god_exp_calc.get_total_experience_for_level(god.level + 1)

	var xp_info = Label.new()
	if god.level >= 40:
		xp_info.text = """Current XP: %d
Level: MAX
Status: Maximum Level Reached""" % [current_xp]
	else:
		xp_info.text = """Current XP: %d
Next Level Total: %d
Remaining: %d
Progress: %.1f%%""" % [current_xp, next_level_total, remaining_xp, progress_percent]
	xp_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_section.add_child(xp_info)

	# XP Progress Bar
	var xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(300, 20)
	xp_bar.min_value = 0.0
	xp_bar.max_value = 100.0
	xp_bar.value = progress_percent
	xp_bar.show_percentage = true

	# Style the XP bar
	var xp_bar_style = StyleBoxFlat.new()
	xp_bar_style.bg_color = Color(0.2, 0.2, 0.8, 0.8)
	xp_bar_style.corner_radius_top_left = 4
	xp_bar_style.corner_radius_top_right = 4
	xp_bar_style.corner_radius_bottom_left = 4
	xp_bar_style.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", xp_bar_style)

	xp_section.add_child(xp_bar)
	content.add_child(xp_section)

	# Combat Stats Section
	var stats_section = VBoxContainer.new()
	var stats_title = Label.new()
	stats_title.text = "═══ COMBAT STATS ═══"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_section.add_child(stats_title)

	var stats_info = Label.new()
	stats_info.text = """HP: %d
Attack: %d
Defense: %d
Speed: %d
Territory: %s""" % [
		god.base_hp, god.base_attack,
		god.base_defense, god.base_speed,
		god.stationed_territory if "stationed_territory" in god and god.stationed_territory != "" else "Unassigned"
	]
	stats_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_section.add_child(stats_info)
	content.add_child(stats_section)

	# Abilities Section
	if _has_valid_abilities(god):
		var abilities_section = VBoxContainer.new()
		var abilities_title = Label.new()
		abilities_title.text = "═══ ABILITIES ═══"
		abilities_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		abilities_title.add_theme_font_size_override("font_size", 14)
		abilities_section.add_child(abilities_title)

		for ability in god.active_abilities:
			var ability_container = VBoxContainer.new()
			ability_container.add_theme_constant_override("separation", 2)

			var ability_name = Label.new()
			ability_name.text = "• " + ability.get("name", "Unknown")
			ability_name.add_theme_font_size_override("font_size", 12)
			ability_name.add_theme_color_override("font_color", Color.YELLOW)
			ability_container.add_child(ability_name)

			var ability_desc = Label.new()
			ability_desc.text = "  " + ability.get("description", "No description")
			ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ability_desc.custom_minimum_size.x = 300
			ability_desc.add_theme_font_size_override("font_size", 10)
			ability_container.add_child(ability_desc)

			abilities_section.add_child(ability_container)

		content.add_child(abilities_section)

	# Add content to details panel
	details_content.add_child(content)

# =============================================================================
# PRIVATE HELPER FUNCTIONS
# =============================================================================

static func _get_element_name(element_id: int) -> String:
	match element_id:
		0: return "Fire"
		1: return "Water"
		2: return "Wind"
		3: return "Lightning"
		4: return "Light"
		5: return "Dark"
		_: return "Unknown"

static func _get_tier_name(tier: int) -> String:
	match tier:
		0: return "⭐ Common"
		1: return "⭐⭐ Rare"
		2: return "⭐⭐⭐ Epic"
		3: return "⭐⭐⭐⭐ Legendary"
		_: return "Unknown"

static func _get_tier_border_color(tier: int) -> Color:
	match tier:
		0:  # COMMON
			return Color(0.5, 0.5, 0.5, 0.8)     # Gray
		1:  # RARE
			return Color(0.4, 0.8, 0.4, 1.0)     # Green
		2:  # EPIC
			return Color(0.7, 0.4, 1.0, 1.0)     # Purple
		3:  # LEGENDARY
			return Color(1.0, 0.8, 0.2, 1.0)     # Gold
		_:
			return Color(0.6, 0.6, 0.6, 0.8)

static func _has_valid_abilities(god: God) -> bool:
	return "ability_ids" in god and god.ability_ids.size() > 0
