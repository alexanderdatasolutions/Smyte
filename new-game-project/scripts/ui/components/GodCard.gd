# scripts/ui/components/GodCard.gd
# Reusable God Card UI Component - Compact layout with big PNG
# Layout: Image -> "Lv.X Name ★★" -> "⚔Power 🛡Equip" -> "📍Location"
class_name GodCard extends Panel

signal god_selected(god: God)

# Card configuration
enum CardSize { SMALL, MEDIUM, LARGE }
enum CardStyle { NORMAL, SELECTED, AWAKENING_READY, BATTLE_READY }

# Card properties
@export var card_size: CardSize = CardSize.MEDIUM
@export var show_power_rating: bool = true
@export var show_territory_assignment: bool = true
@export var show_equipment_status: bool = true
@export var show_awakening_status: bool = false
@export var clickable: bool = true

# Internal references
var god_data: God = null
var current_style: CardStyle = CardStyle.NORMAL

# UI Elements
var god_image: TextureRect
var info_panel: PanelContainer  # Container for text info
var name_row_label: Label      # "Lv.X Name ★★★"
var stats_row_label: Label     # "⚔Power 🛡X/6"
var location_label: Label      # "📍Location"
var awakening_indicator: Label

func _ready():
	if not god_image:
		_setup_card_structure()
		_apply_card_size()

func setup_god_card(god: God, style: CardStyle = CardStyle.NORMAL):
	god_data = god
	current_style = style

	if not god_image:
		_setup_card_structure()

	_apply_card_size()
	_populate_god_data()
	_apply_card_style()

func _setup_card_structure():
	for child in get_children():
		child.queue_free()

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	margin.add_child(vbox)

	# God image - no extra container, just the image
	god_image = TextureRect.new()
	god_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(god_image)

	# Info panel - wraps all text labels
	info_panel = PanelContainer.new()
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

	# Name row: "Lv.X Name ★★★"
	name_row_label = Label.new()
	name_row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_row_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_row_label)

	# Stats row: "⚔Power 🛡X/6"
	if show_power_rating or show_equipment_status:
		stats_row_label = Label.new()
		stats_row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(stats_row_label)

	# Location row: "📍Location"
	if show_territory_assignment:
		location_label = Label.new()
		location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(location_label)

	# Awakening indicator
	if show_awakening_status:
		awakening_indicator = Label.new()
		awakening_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awakening_indicator.modulate = Color(0.5, 1.0, 0.5)
		info_vbox.add_child(awakening_indicator)

	# Clickable button overlay
	if clickable:
		var button = Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_card_clicked)
		margin.add_child(button)

func _apply_card_size():
	if not god_image:
		return

	match card_size:
		CardSize.SMALL:
			custom_minimum_size = Vector2(100, 140)
			_set_margins(1, 1, 1, 1)
			god_image.custom_minimum_size = Vector2(98, 98)
			name_row_label.add_theme_font_size_override("font_size", 10)
			if stats_row_label:
				stats_row_label.add_theme_font_size_override("font_size", 9)
			if location_label:
				location_label.add_theme_font_size_override("font_size", 9)

		CardSize.MEDIUM:
			custom_minimum_size = Vector2(120, 165)
			_set_margins(1, 1, 1, 1)
			god_image.custom_minimum_size = Vector2(118, 118)
			name_row_label.add_theme_font_size_override("font_size", 11)
			if stats_row_label:
				stats_row_label.add_theme_font_size_override("font_size", 10)
			if location_label:
				location_label.add_theme_font_size_override("font_size", 10)

		CardSize.LARGE:
			custom_minimum_size = Vector2(145, 195)
			_set_margins(1, 1, 1, 1)
			god_image.custom_minimum_size = Vector2(143, 143)
			name_row_label.add_theme_font_size_override("font_size", 13)
			if stats_row_label:
				stats_row_label.add_theme_font_size_override("font_size", 11)
			if location_label:
				location_label.add_theme_font_size_override("font_size", 11)

func _set_margins(left: int, top: int, right: int, bottom: int):
	var margin_container = get_child(0) as MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", left)
		margin_container.add_theme_constant_override("margin_right", right)
		margin_container.add_theme_constant_override("margin_top", top)
		margin_container.add_theme_constant_override("margin_bottom", bottom)

func _populate_god_data():
	if not god_data:
		return

	# Load god image (with skin support)
	if god_image:
		var sprite_path: String = GodPortraitHelper.get_portrait_path(god_data)
		if ResourceLoader.exists(sprite_path):
			god_image.texture = load(sprite_path)
		else:
			var placeholder_image = ImageTexture.new()
			var image = Image.create(100, 100, false, Image.FORMAT_RGB8)
			var element_color := GodUIHelpers.get_element_color(god_data.element)
			image.fill(element_color)
			placeholder_image.set_image(image)
			god_image.texture = placeholder_image

	# Name row: "Lv.X Name ★★★"
	if name_row_label:
		var tier_stars: String = GodUIHelpers.get_tier_stars(god_data.tier)
		name_row_label.text = "Lv.%d %s %s" % [god_data.level, god_data.name, tier_stars]

	# Stats row: "⚔Power 🛡X/6"
	if stats_row_label:
		var parts: Array = []
		if show_power_rating:
			var power = GodCalculator.get_power_rating(god_data)
			parts.append("⚔%d" % power)
		if show_equipment_status:
			var equipped_count: int = 0
			for equipment in god_data.equipment:
				if equipment != null:
					equipped_count += 1
			parts.append("🛡%d/6" % equipped_count)
		stats_row_label.text = " ".join(parts)
		stats_row_label.modulate = Color(0.75, 0.75, 0.8)

	# Location row
	if location_label:
		if god_data.stationed_territory != "":
			location_label.text = "📍%s" % god_data.stationed_territory.capitalize()
			location_label.modulate = Color(0.9, 0.8, 0.5)
		else:
			location_label.text = "📍Available"
			location_label.modulate = Color(0.5, 0.7, 0.5)

	# Awakening - use soft cap from config
	if awakening_indicator:
		if god_data.tier >= God.TierType.EPIC and god_data.level >= God.get_soft_cap_level():
			awakening_indicator.text = "✨ Awaken"
			awakening_indicator.visible = true
		else:
			awakening_indicator.visible = false

func _apply_card_style():
	var style = StyleBoxFlat.new()
	var element: God.ElementType = god_data.element if god_data else God.ElementType.FIRE

	match current_style:
		CardStyle.NORMAL:
			style.bg_color = GodUIHelpers.get_subtle_element_color(element)
			style.border_color = GodUIHelpers.get_element_border_color(element)

		CardStyle.SELECTED:
			style.bg_color = GodUIHelpers.get_subtle_element_color(element)
			style.border_color = Color(1.0, 0.85, 0.2, 1.0)

		CardStyle.AWAKENING_READY:
			var base: Color = GodUIHelpers.get_subtle_element_color(element)
			style.bg_color = base.lerp(Color(0.2, 0.4, 0.2, 0.8), 0.3)
			style.border_color = Color(0.5, 0.9, 0.4, 1.0)

		CardStyle.BATTLE_READY:
			var base: Color = GodUIHelpers.get_subtle_element_color(element)
			style.bg_color = base.lerp(Color(0.2, 0.3, 0.4, 0.8), 0.3)
			style.border_color = Color(0.3, 0.8, 1.0, 1.0)

	var border_width: int = 3 if current_style == CardStyle.SELECTED else 2
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	add_theme_stylebox_override("panel", style)

func _on_card_clicked():
	if god_data:
		god_selected.emit(god_data)
