# scripts/ui/summon/SummonResultOverlay.gd
# RULE 1: UI component - displays summon results as a modal overlay
# RULE 2: Single responsibility - only handles result display UI
class_name SummonResultOverlay
extends Control

signal view_collection_pressed
signal summon_again_pressed
signal close_pressed

# UI Components
var backdrop: ColorRect
var content_panel: Panel
var title_label: Label
var summary_label: Label
var gods_grid: GridContainer
var scroll_container: ScrollContainer
var button_container: HBoxContainer
var view_collection_button: Button
var summon_again_button: Button
var close_button: Button

# State
var displayed_gods: Array[God] = []
var god_cards: Array[Control] = []
var last_summon_banner_data: Dictionary = {}

# Animation
var _reveal_tween: Tween
var _is_animating: bool = false

# Constants
const CARD_SIZE := Vector2(140, 200)
const GRID_COLUMNS := 5
const RARITY_COLORS := {
	"common": Color(0.7, 0.7, 0.7, 1.0),
	"rare": Color(0.3, 0.5, 1.0, 1.0),
	"epic": Color(0.6, 0.2, 0.8, 1.0),
	"legendary": Color(1.0, 0.84, 0.0, 1.0)
}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_create_ui()

func _create_ui():
	# Semi-transparent backdrop
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Center container
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Main content panel
	content_panel = Panel.new()
	content_panel.name = "ContentPanel"
	content_panel.custom_minimum_size = Vector2(800, 550)
	_style_content_panel()
	center.add_child(content_panel)

	# Margin container for padding
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	content_panel.add_child(margin)

	# Main layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "SUMMON RESULTS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 2)
	main_vbox.add_child(title_label)

	# Summary (e.g., "You obtained 10 gods! 2 NEW")
	summary_label = Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	main_vbox.add_child(summary_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	main_vbox.add_child(sep)

	# Scroll container for gods grid
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.custom_minimum_size = Vector2(750, 340)
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)

	# Gods grid
	gods_grid = GridContainer.new()
	gods_grid.name = "GodsGrid"
	gods_grid.columns = GRID_COLUMNS
	gods_grid.add_theme_constant_override("h_separation", 12)
	gods_grid.add_theme_constant_override("v_separation", 12)
	gods_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(gods_grid)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	# Button container
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(button_container)

	# View Collection button
	view_collection_button = Button.new()
	view_collection_button.name = "ViewCollectionButton"
	view_collection_button.text = "View in Collection"
	view_collection_button.custom_minimum_size = Vector2(160, 45)
	view_collection_button.pressed.connect(_on_view_collection_pressed)
	_style_button(view_collection_button, Color(0.3, 0.5, 0.7))
	button_container.add_child(view_collection_button)

	# Summon Again button
	summon_again_button = Button.new()
	summon_again_button.name = "SummonAgainButton"
	summon_again_button.text = "Summon Again"
	summon_again_button.custom_minimum_size = Vector2(160, 45)
	summon_again_button.pressed.connect(_on_summon_again_pressed)
	_style_button(summon_again_button, Color(0.6, 0.4, 0.8))
	button_container.add_child(summon_again_button)

	# Close button
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 45)
	close_button.pressed.connect(_on_close_pressed)
	_style_button(close_button, Color(0.4, 0.4, 0.4))
	button_container.add_child(close_button)

func _style_content_panel():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.98)
	style.border_color = Color(0.5, 0.45, 0.6, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 10
	content_panel.add_theme_stylebox_override("panel", style)

func _style_button(btn: Button, accent_color: Color):
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = accent_color.darkened(0.3)
	normal_style.border_color = accent_color
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = accent_color.darkened(0.1)
	hover_style.border_color = accent_color.lightened(0.2)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = accent_color
	pressed_style.border_color = accent_color.lightened(0.3)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)

## Show result overlay with array of gods
func show_results(gods: Array, banner_data: Dictionary = {}):
	displayed_gods.clear()
	for god in gods:
		if god is God:
			displayed_gods.append(god)

	last_summon_banner_data = banner_data

	_clear_grid()
	_populate_grid()
	_update_summary()

	visible = true
	_animate_show()

## Show result for a single god
func show_single_result(god: God, banner_data: Dictionary = {}):
	show_results([god], banner_data)

func _clear_grid():
	for card in god_cards:
		if is_instance_valid(card):
			card.queue_free()
	god_cards.clear()

	for child in gods_grid.get_children():
		child.queue_free()

func _populate_grid():
	var collection_mgr = _get_collection_manager()

	for god in displayed_gods:
		var card = _create_god_card(god, collection_mgr)
		gods_grid.add_child(card)
		god_cards.append(card)
		# Start hidden for animation
		card.modulate.a = 0.0
		card.scale = Vector2(0.8, 0.8)

func _create_god_card(god: God, collection_mgr) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE

	# Determine if this is a new god or duplicate
	var is_duplicate = false
	if collection_mgr:
		# Check if god exists in collection by counting occurrences
		var god_count = _count_god_in_collection(god.id, collection_mgr)
		is_duplicate = god_count > 1  # More than 1 means we already had it

	# Style card based on rarity
	var tier_string = God.tier_to_string(god.tier).to_lower()
	var tier_color = RARITY_COLORS.get(tier_string, RARITY_COLORS.common)
	_style_god_card(card, tier_color, is_duplicate)

	# Content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)

	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	content.add_child(margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(inner_vbox)

	# NEW or DUPLICATE badge
	var badge_label = Label.new()
	if is_duplicate:
		badge_label.text = "DUPLICATE"
		badge_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		badge_label.text = "NEW!"
		badge_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 10)
	inner_vbox.add_child(badge_label)

	# God portrait
	var portrait_container = CenterContainer.new()
	portrait_container.custom_minimum_size = Vector2(80, 80)
	inner_vbox.add_child(portrait_container)

	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(70, 70)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		# Placeholder
		var placeholder = ColorRect.new()
		placeholder.custom_minimum_size = Vector2(70, 70)
		placeholder.color = tier_color.darkened(0.3)
		portrait_container.add_child(placeholder)

	portrait_container.add_child(portrait)

	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = CARD_SIZE.x - 20
	inner_vbox.add_child(name_label)

	# Tier and element
	var tier_label = Label.new()
	var element_string = God.element_to_string(god.element).capitalize()
	tier_label.text = "%s %s" % [tier_string.capitalize(), element_string]
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 10)
	tier_label.add_theme_color_override("font_color", tier_color)
	inner_vbox.add_child(tier_label)

	# Stats preview (compact)
	var stats_label = Label.new()
	var stats = _get_god_stats(god)
	stats_label.text = "HP:%d ATK:%d" % [stats.hp, stats.attack]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 9)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	inner_vbox.add_child(stats_label)

	return card

func _style_god_card(card: PanelContainer, tier_color: Color, is_duplicate: bool):
	var style = StyleBoxFlat.new()

	if is_duplicate:
		# Muted style for duplicates
		style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		style.border_color = Color(0.4, 0.4, 0.4, 0.7)
	else:
		# Highlighted style for new gods
		style.bg_color = tier_color.darkened(0.7)
		style.bg_color.a = 0.95
		style.border_color = tier_color.lightened(0.2)

	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
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

func _count_god_in_collection(god_id: String, collection_mgr) -> int:
	# Since gods are unique by ID, check if it exists
	# For duplicate detection, we track in SummonManager
	# Here we just check if it existed before this summon session
	if collection_mgr.has_god(god_id):
		return 2  # Mark as duplicate
	return 1  # New god

func _update_summary():
	var total = displayed_gods.size()
	var legendary_count = 0
	var epic_count = 0

	for god in displayed_gods:
		# Count rarities
		if god.tier == God.TierType.LEGENDARY:
			legendary_count += 1
		elif god.tier == God.TierType.EPIC:
			epic_count += 1

	# Build summary text
	var parts: Array[String] = []
	parts.append("You obtained %d god%s!" % [total, "s" if total > 1 else ""])

	if legendary_count > 0:
		parts.append("%d LEGENDARY" % legendary_count)
	if epic_count > 0:
		parts.append("%d Epic" % epic_count)

	summary_label.text = " ".join(parts)

	# Color based on best pull
	if legendary_count > 0:
		summary_label.add_theme_color_override("font_color", RARITY_COLORS.legendary)
	elif epic_count > 0:
		summary_label.add_theme_color_override("font_color", RARITY_COLORS.epic)
	else:
		summary_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

func _animate_show():
	_is_animating = true
	content_panel.modulate.a = 0.0
	content_panel.scale = Vector2(0.9, 0.9)
	content_panel.pivot_offset = content_panel.size / 2

	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()

	_reveal_tween = create_tween()

	# Fade in panel
	_reveal_tween.set_parallel(true)
	_reveal_tween.tween_property(content_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(content_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Sequential card reveals
	_reveal_tween.chain()
	var delay = 0.0
	for card in god_cards:
		_reveal_tween.tween_property(card, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_delay(delay)
		_reveal_tween.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		delay += 0.05  # 50ms stagger between cards

	_reveal_tween.tween_callback(_on_animation_complete)

func _on_animation_complete():
	_is_animating = false

func hide_results():
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
	visible = false

func _get_collection_manager():
	return SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null

## Button callbacks
func _on_view_collection_pressed():
	hide_results()
	view_collection_pressed.emit()

func _on_summon_again_pressed():
	hide_results()
	summon_again_pressed.emit()

func _on_close_pressed():
	hide_results()
	close_pressed.emit()

## Set banner data for "Summon Again" functionality
func set_banner_data(data: Dictionary):
	last_summon_banner_data = data

## Get banner data for repeating summon
func get_last_banner_data() -> Dictionary:
	return last_summon_banner_data
