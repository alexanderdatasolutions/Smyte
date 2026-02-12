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

	# Load god image based on template ID (id is unique instance)
	var god_template = god.template_id if god.template_id else god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
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

	# Equipment Section
	var equipment_section = _create_equipment_section(god)
	if equipment_section:
		content.add_child(equipment_section)

	# Skills/Abilities Section
	var skills_section = _create_skills_section(god)
	if skills_section:
		content.add_child(skills_section)

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

static func _create_equipment_section(god: God) -> VBoxContainer:
	"""Create equipment section showing all 6 slots"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var title = Label.new()
	title.text = "═══ EQUIPMENT ═══"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	section.add_child(title)

	# Equipment slot names
	var slot_names = ["Weapon", "Armor", "Helm", "Boots", "Amulet", "Ring"]

	# Create grid for equipment
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)

	for i in range(6):
		var slot_container = HBoxContainer.new()
		slot_container.add_theme_constant_override("separation", 4)

		# Slot icon/name
		var slot_label = Label.new()
		slot_label.text = slot_names[i] + ":"
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		slot_label.custom_minimum_size.x = 60
		slot_container.add_child(slot_label)

		# Equipment info
		var equip_label = Label.new()
		equip_label.add_theme_font_size_override("font_size", 11)

		if god.equipment.size() > i and god.equipment[i] != null:
			var eq = god.equipment[i]
			equip_label.text = eq.name if eq.name else "Unknown"
			equip_label.add_theme_color_override("font_color", _get_rarity_color(eq.rarity if "rarity" in eq else 0))
		else:
			equip_label.text = "Empty"
			equip_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		slot_container.add_child(equip_label)
		grid.add_child(slot_container)

	section.add_child(grid)
	return section

static func _create_skills_section(god: God) -> VBoxContainer:
	"""Create skills section showing abilities with damage, scaling, cooldown"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title = Label.new()
	title.text = "═══ SKILLS ═══"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	section.add_child(title)

	# Load abilities data and god config
	var abilities_data = _load_abilities_data()
	var god_config = _load_god_config(god.id)
	var ability_ids = god_config.get("ability_ids", [])

	# Show abilities from config
	if not ability_ids.is_empty():
		for i in range(ability_ids.size()):
			var ability_id = ability_ids[i]
			var skill_level = god.skill_levels[i] if i < god.skill_levels.size() else 1
			var ability_data = abilities_data.get(ability_id, {})

			var ability_container = VBoxContainer.new()
			ability_container.add_theme_constant_override("separation", 2)

			# Ability name row with level and cooldown
			var name_row = HBoxContainer.new()
			name_row.add_theme_constant_override("separation", 6)

			var ability_name = Label.new()
			ability_name.text = "• " + ability_data.get("name", ability_id.capitalize().replace("_", " "))
			ability_name.add_theme_font_size_override("font_size", 12)
			ability_name.add_theme_color_override("font_color", Color.YELLOW)
			name_row.add_child(ability_name)

			var level_label = Label.new()
			level_label.text = "[Lv.%d]" % skill_level
			level_label.add_theme_font_size_override("font_size", 10)
			level_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			name_row.add_child(level_label)

			ability_container.add_child(name_row)

			# Stats row: Damage, Scaling, Targets, Cooldown
			var stats_row = HBoxContainer.new()
			stats_row.add_theme_constant_override("separation", 12)

			var dmg_mult = ability_data.get("damage_multiplier", 0)
			var scaling = ability_data.get("scaling_stat", "ATK")
			var targets = ability_data.get("targets", "single")
			var cooldown = ability_data.get("cooldown", 0)
			var hits = ability_data.get("hits", 1)

			# Damage multiplier
			if dmg_mult > 0:
				var dmg_label = Label.new()
				var dmg_text = "%.0f%% %s" % [dmg_mult * 100, scaling]
				if hits > 1:
					dmg_text += " x%d" % hits
				dmg_label.text = dmg_text
				dmg_label.add_theme_font_size_override("font_size", 10)
				dmg_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
				stats_row.add_child(dmg_label)

			# Target type
			var target_label = Label.new()
			var target_text = _format_target_type(targets)
			target_label.text = target_text
			target_label.add_theme_font_size_override("font_size", 10)
			target_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			stats_row.add_child(target_label)

			# Cooldown
			if cooldown > 0:
				var cd_label = Label.new()
				cd_label.text = "CD: %d" % cooldown
				cd_label.add_theme_font_size_override("font_size", 10)
				cd_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
				stats_row.add_child(cd_label)
			else:
				var cd_label = Label.new()
				cd_label.text = "No CD"
				cd_label.add_theme_font_size_override("font_size", 10)
				cd_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
				stats_row.add_child(cd_label)

			ability_container.add_child(stats_row)

			# Ability description
			var desc = ability_data.get("description", "No description available")
			var ability_desc = Label.new()
			ability_desc.text = "  " + desc
			ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ability_desc.custom_minimum_size.x = 280
			ability_desc.add_theme_font_size_override("font_size", 10)
			ability_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			ability_container.add_child(ability_desc)

			section.add_child(ability_container)
	else:
		var no_skills = Label.new()
		no_skills.text = "No skills available"
		no_skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_skills.add_theme_font_size_override("font_size", 11)
		no_skills.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		section.add_child(no_skills)

	return section

static func _get_rarity_color(rarity: int) -> Color:
	"""Get color for equipment rarity"""
	match rarity:
		0: return Color(0.6, 0.6, 0.6)      # Common - Gray
		1: return Color(0.4, 0.8, 0.4)      # Rare - Green
		2: return Color(0.6, 0.4, 0.9)      # Epic - Purple
		3: return Color(1.0, 0.8, 0.2)      # Legendary - Gold
		4: return Color(1.0, 0.4, 0.4)      # Mythic - Red
		_: return Color(0.7, 0.7, 0.7)

static var _cached_abilities: Dictionary = {}

static func _load_abilities_data() -> Dictionary:
	"""Load and cache abilities from JSON"""
	if not _cached_abilities.is_empty():
		return _cached_abilities

	var file = FileAccess.open("res://data/abilities.json", FileAccess.READ)
	if not file:
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}

	var data = json.get_data()
	if data.has("abilities"):
		_cached_abilities = data.abilities

	return _cached_abilities

static var _cached_gods: Dictionary = {}

static func _load_god_config(god_id: String) -> Dictionary:
	"""Load god config from JSON to get ability_ids"""
	if _cached_gods.has(god_id):
		return _cached_gods[god_id]

	# Try via SystemRegistry first
	var registry_class = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_class and registry_class.has_method("get_instance"):
		var registry = registry_class.get_instance()
		if registry:
			var config_manager = registry.get_system("ConfigurationManager")
			if config_manager and config_manager.has_method("get_god_config"):
				var config = config_manager.get_god_config(god_id)
				if config:
					_cached_gods[god_id] = config
					return config

	# Fallback: Load directly from JSON
	var file = FileAccess.open("res://data/gods.json", FileAccess.READ)
	if not file:
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}

	var data = json.get_data()
	if data.has("gods") and data.gods.has(god_id):
		_cached_gods[god_id] = data.gods[god_id]
		return _cached_gods[god_id]

	return {}

static func _format_target_type(targets: String) -> String:
	"""Format target type for display"""
	match targets:
		"single": return "Single"
		"all_enemies": return "All Enemies"
		"all_allies": return "All Allies"
		"self": return "Self"
		"random_enemy": return "Random"
		_: return targets.capitalize().replace("_", " ")
