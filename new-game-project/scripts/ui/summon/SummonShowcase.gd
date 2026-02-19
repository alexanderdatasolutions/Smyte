# scripts/ui/summon/SummonShowcase.gd
# Component for displaying summoned gods in a showcase panel
# Updated to match unified team selection UI patterns
class_name SummonShowcase
extends RefCounted

# UI Design Pattern Colors (matching TeamSelectionManager)
const COLOR_PANEL_BG = Color(0.12, 0.1, 0.16, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.25, 0.4, 0.8)
const COLOR_HEADER = Color(0.8, 0.8, 0.9)
const COLOR_TEXT = Color(0.7, 0.7, 0.8)
const COLOR_MUTED = Color(0.5, 0.5, 0.55)

# Tier colors
const TIER_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"rare": Color(0.3, 0.6, 1.0),
	"epic": Color(0.7, 0.3, 0.9),
	"legendary": Color(1.0, 0.84, 0.0)
}

var showcase_content: GridContainer
var current_summons: Array = []
var is_processing_summon: bool = false

func _init(showcase_container: GridContainer):
	showcase_content = showcase_container

## Creates and displays a summoned god card with animation
func show_god(god: God, animate: bool = true):
	var god_card = _create_god_card(god)
	current_summons.append(god_card)

	# Keep only last 15 summons (to accommodate 10x summons + some history)
	if current_summons.size() > 15:
		var old_card = current_summons[0]
		current_summons.remove_at(0)
		if old_card and is_instance_valid(old_card):
			old_card.queue_free()

	# Add to showcase at the TOP so newest appears first
	if showcase_content:
		showcase_content.add_child(god_card)
		showcase_content.move_child(god_card, 0)

		if animate:
			_animate_card_entrance(god_card)
		else:
			god_card.modulate.a = 1.0
			god_card.scale = Vector2(1.0, 1.0)

## Clears all summons from showcase (called when leaving screen)
func clear():
	current_summons.clear()
	if showcase_content:
		for child in showcase_content.get_children():
			child.queue_free()

## Clears all invisible nodes from showcase (cleanup)
func clear_invisible_nodes():
	if not showcase_content:
		return

	var visible_count = 0
	for child in showcase_content.get_children():
		if child.visible:
			visible_count += 1

	if visible_count == 0:
		for child in showcase_content.get_children():
			if not child.visible:
				child.queue_free()

## Creates a styled god card matching GodCard MEDIUM size (120x165, 118x118 portrait)
func _create_god_card(god: God) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 165)

	# Style with tier color border
	var tier_string = God.tier_to_string(god.tier).to_lower()
	var tier_color = TIER_COLORS.get(tier_string, TIER_COLORS.common)
	_style_god_card(card, tier_color)

	# Content VBox - tight spacing for compact card
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	card.add_child(vbox)

	# God portrait - match GodCard MEDIUM (118x118)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(118, 118)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var god_template = god.template_id if god.template_id else god.id
	var sprite_path = "res://assets/gods/" + god_template + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	vbox.add_child(portrait)

	# Info panel background (like GodCard)
	var info_panel = PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	info_style.set_corner_radius_all(4)
	info_style.content_margin_left = 4
	info_style.content_margin_right = 4
	info_style.content_margin_top = 2
	info_style.content_margin_bottom = 2
	info_panel.add_theme_stylebox_override("panel", info_style)
	vbox.add_child(info_panel)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 0)
	info_panel.add_child(info_vbox)

	# Name row: "Lv.1 Name" + colored stars (matching GodCard format)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 2)
	info_vbox.add_child(name_row)

	var name_label = Label.new()
	name_label.text = "Lv.%d %s" % [god.level, god.name]
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_row.add_child(name_label)

	var stars_label = Label.new()
	stars_label.text = GodUIHelpers.get_tier_stars(god.tier)
	stars_label.add_theme_font_size_override("font_size", 11)
	stars_label.add_theme_color_override("font_color", GodUIHelpers.get_tier_color(god.tier))
	name_row.add_child(stars_label)

	# Stats row: "⚔Power Element" (tier-colored)
	var power = GodCalculator.get_power_rating(god)
	var stats_label = Label.new()
	stats_label.text = "⚔%d %s" % [power, God.element_to_string(god.element)]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.add_theme_color_override("font_color", tier_color)
	info_vbox.add_child(stats_label)

	return card

func _style_god_card(card: PanelContainer, tier_color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.border_color = tier_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 1
	style.content_margin_right = 1
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	card.add_theme_stylebox_override("panel", style)

func _get_god_stats(god: God) -> Dictionary:
	var stat_calc = SystemRegistry.get_instance().get_system("EquipmentStatCalculator") if SystemRegistry.get_instance() else null
	if stat_calc:
		return stat_calc.calculate_god_total_stats(god)
	return {
		"hp": god.base_hp,
		"attack": god.base_attack,
		"defense": god.base_defense,
		"speed": god.base_speed
	}

## Animates card entrance with scale and fade
func _animate_card_entrance(card: Control):
	card.modulate.a = 0.0
	card.scale = Vector2(0.5, 0.5)

	var tween = card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
