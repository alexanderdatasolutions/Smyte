# scripts/ui/summon/SummonShowcase.gd
# Component for displaying summoned gods in a showcase panel
# RULE 1: Single responsibility - handles god card display only
class_name SummonShowcase
extends RefCounted

var showcase_content: GridContainer
var current_summons: Array = []
var is_processing_summon: bool = false

func _init(showcase_container: GridContainer):
	showcase_content = showcase_container

## Creates and displays a summoned god card with animation
func show_god(god: God, animate: bool = true):
	var god_button = _create_god_card(god)
	current_summons.append(god_button)

	# Keep only last 15 summons (to accommodate 10x summons + some history)
	if current_summons.size() > 15:
		var old_card = current_summons[0]
		current_summons.remove_at(0)
		if old_card and is_instance_valid(old_card):
			old_card.queue_free()

	# Add to showcase with optional animation
	if showcase_content:
		showcase_content.add_child(god_button)

		if animate:
			_animate_card_entrance(god_button)
		else:
			god_button.modulate.a = 1.0
			god_button.scale = Vector2(1.0, 1.0)

## Clears all invisible nodes from showcase (cleanup)
func clear_invisible_nodes():
	if not showcase_content:
		return

	# Count visible children first
	var visible_count = 0
	for child in showcase_content.get_children():
		if child.visible:
			visible_count += 1

	# Only clear if no visible children
	if visible_count == 0:
		for child in showcase_content.get_children():
			if not child.visible:
				child.queue_free()

## Creates a styled god card button
func _create_god_card(god: God) -> Button:
	var god_button = Button.new()
	god_button.custom_minimum_size = Vector2(200, 280)
	god_button.flat = false
	god_button.disabled = true
	god_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Style with tier color
	var tier_color = _get_tier_color(god.tier)
	var god_style = StyleBoxFlat.new()
	god_style.bg_color = tier_color.darkened(0.2)
	god_style.bg_color.a = 0.9
	god_style.corner_radius_top_left = 12
	god_style.corner_radius_top_right = 12
	god_style.corner_radius_bottom_left = 12
	god_style.corner_radius_bottom_right = 12
	god_style.border_width_left = 3
	god_style.border_width_top = 3
	god_style.border_width_right = 3
	god_style.border_width_bottom = 3
	god_style.border_color = tier_color.lightened(0.3)
	god_style.shadow_color = Color.BLACK
	god_style.shadow_color.a = 0.4
	god_style.shadow_size = 6
	god_style.shadow_offset = Vector2(3, 3)
	god_style.border_blend = true
	god_style.anti_aliasing = true

	god_button.add_theme_stylebox_override("normal", god_style)
	god_button.add_theme_stylebox_override("disabled", god_style)
	god_button.add_theme_color_override("font_color", Color.WHITE)

	# Create card content
	var content = _create_card_content(god, tier_color)
	god_button.add_child(content)

	return god_button

## Creates the visual content layout for a god card
func _create_card_content(god: God, tier_color: Color) -> VBoxContainer:
	var content_container = VBoxContainer.new()
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_container.offset_left = 10
	content_container.offset_top = 10
	content_container.offset_right = -10
	content_container.offset_bottom = -10
	content_container.add_theme_constant_override("separation", 5)

	# Announcement
	var announcement = Label.new()
	announcement.text = "✨ NEW GOD SUMMONED! ✨"
	announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement.add_theme_font_size_override("font_size", 12)
	announcement.add_theme_color_override("font_color", Color.YELLOW)
	content_container.add_child(announcement)

	# God image
	_add_god_image(content_container, god, tier_color)

	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(name_label)

	# Tier display
	var tier_label = Label.new()
	tier_label.text = "⭐ %s %s ⭐" % [God.tier_to_string(god.tier).to_upper(), God.element_to_string(god.element).to_upper()]
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", _get_tier_text_color(god.tier))
	tier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(tier_label)

	# Stats
	_add_stats_label(content_container, god)

	return content_container

## Adds god image or placeholder to content container
func _add_god_image(container: VBoxContainer, god: God, tier_color: Color):
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	var god_texture = null
	if ResourceLoader.exists(sprite_path):
		god_texture = load(sprite_path)

	if god_texture:
		var image_container = TextureRect.new()
		image_container.custom_minimum_size = Vector2(120, 120)
		image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		image_container.texture = god_texture
		container.add_child(image_container)
	else:
		# Fallback colored rectangle
		var placeholder = ColorRect.new()
		placeholder.color = tier_color.lightened(0.2)
		placeholder.custom_minimum_size = Vector2(120, 120)
		container.add_child(placeholder)

## Adds stats label to content container
func _add_stats_label(container: VBoxContainer, god: God):
	var stats_label = Label.new()

	# Get stats through EquipmentStatCalculator (RULE 3 compliance)
	var stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator")
	var hp: int
	var attack: int
	var defense: int
	var speed: int
	if stat_calc:
		var total_stats = stat_calc.calculate_god_total_stats(god)
		hp = total_stats.hp
		attack = total_stats.attack
		defense = total_stats.defense
		speed = total_stats.speed
	else:
		hp = god.base_hp
		attack = god.base_attack
		defense = god.base_defense
		speed = god.base_speed

	stats_label.text = "HP: %d | ATK: %d | DEF: %d | SPD: %d" % [hp, attack, defense, speed]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 9)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(stats_label)

## Animates card entrance with scale and fade
func _animate_card_entrance(card: Control):
	card.modulate.a = 0.0
	card.scale = Vector2(0.5, 0.5)

	var tween = card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Gets the color for a specific tier
func _get_tier_color(tier: int) -> Color:
	match tier:
		0:  # COMMON
			return Color.GRAY
		1:  # RARE
			return Color.ROYAL_BLUE
		2:  # EPIC
			return Color.MEDIUM_PURPLE
		3:  # LEGENDARY
			return Color.GOLD
		_:
			return Color.WHITE

## Gets the text color for a specific tier
func _get_tier_text_color(tier: int) -> Color:
	match tier:
		0:  # COMMON
			return Color.LIGHT_GRAY
		1:  # RARE
			return Color.DODGER_BLUE
		2:  # EPIC
			return Color.MEDIUM_PURPLE
		3:  # LEGENDARY
			return Color.GOLD
		_:
			return Color.WHITE
