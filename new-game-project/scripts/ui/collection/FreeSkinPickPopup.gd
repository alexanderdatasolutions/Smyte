# scripts/ui/collection/FreeSkinPickPopup.gd
# Popup for selecting a free skin when a legendary god reaches level 40
class_name FreeSkinPickPopup
extends Control

signal skin_selected(god_id: String, skin_id: String)
signal popup_closed

var _god_id: String = ""
var _god_name: String = ""
var _available_skins: Array = []
var _skin_manager: Node = null
var _overlay: ColorRect = null
var _panel: Panel = null

func _ready() -> void:
	visible = false
	z_index = 100

func show_for_god(god_id: String) -> void:
	"""Show the popup for a specific god"""
	_god_id = god_id

	var registry: Node = SystemRegistry.get_instance()
	_skin_manager = registry.get_system("SkinManager") if registry else null
	var collection_manager: Node = registry.get_system("CollectionManager") if registry else null

	if not _skin_manager or not collection_manager:
		push_error("FreeSkinPickPopup: Required systems not found")
		return

	var god: God = collection_manager.get_god_by_id(god_id)
	if not god:
		push_error("FreeSkinPickPopup: God not found: %s" % god_id)
		return

	_god_name = god.name
	_available_skins = _skin_manager.get_skins_for_god(god_id)

	if _available_skins.is_empty():
		push_warning("FreeSkinPickPopup: No skins available for god: %s" % god_id)
		_skin_manager.clear_pending_free_skin_god()
		return

	_build_popup()
	visible = true

func _build_popup() -> void:
	"""Build the popup UI"""
	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Get viewport size for manual positioning
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Make this control fill the screen
	position = Vector2.ZERO
	size = viewport_size

	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.position = Vector2.ZERO
	_overlay.size = viewport_size
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Main panel - manually centered (BIG for this special moment)
	var panel_size: Vector2 = Vector2(750, 550)
	_panel = Panel.new()
	_panel.size = panel_size
	_panel.position = (viewport_size - panel_size) / 2
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	panel_style.border_color = Color.GOLD
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Content margin
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "LEGENDARY CHAMPION!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	# Subtitle
	var subtitle: Label = Label.new()
	subtitle.text = "%s has reached Level 40!" % _god_name
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	vbox.add_child(subtitle)

	# Message
	var message: Label = Label.new()
	message.text = "Choose a FREE skin as your reward!"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 12)
	message.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(message)

	# Separator
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Skins row - centered, 1 row of up to 3 big cards
	var skins_center: CenterContainer = CenterContainer.new()
	skins_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(skins_center)

	var skins_row: HBoxContainer = HBoxContainer.new()
	skins_row.add_theme_constant_override("separation", 20)
	skins_center.add_child(skins_row)

	# Track added skins to avoid duplicates
	var added_skins: Dictionary = {}
	for skin_id: String in _available_skins:
		if added_skins.has(skin_id):
			continue
		added_skins[skin_id] = true
		var skin_data: Dictionary = _skin_manager.get_skin(skin_id)
		_create_skin_card(skins_row, skin_id, skin_data)

	# Skip button (if player doesn't want to choose now)
	var skip_btn: Button = Button.new()
	skip_btn.text = "Choose Later"
	skip_btn.custom_minimum_size = Vector2(150, 35)
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_btn.pressed.connect(_on_skip_pressed)
	vbox.add_child(skip_btn)

func _create_skin_card(parent: Control, skin_id: String, skin_data: Dictionary) -> void:
	"""Create a BIG skin selection card with portrait preview"""
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(210, 320)

	var rarity: String = skin_data.get("rarity", "common")
	var border_color: Color = Color.WHITE
	match rarity:
		"epic":
			border_color = Color(0.7, 0.3, 0.9)
		"legendary":
			border_color = Color(1.0, 0.7, 0.0)

	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.12, 0.2, 0.9)
	card_style.border_color = border_color
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 8)
	card_margin.add_theme_constant_override("margin_right", 8)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(card_margin)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card_margin.add_child(card_vbox)

	# Portrait image - BIG for this special moment
	var portrait_container: CenterContainer = CenterContainer.new()
	portrait_container.custom_minimum_size = Vector2(0, 180)
	card_vbox.add_child(portrait_container)

	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(170, 170)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var portrait_path: String = skin_data.get("portrait_path", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	else:
		portrait.modulate = Color(0.5, 0.5, 0.5)

	portrait_container.add_child(portrait)

	# Skin name - bigger text
	var name_label: Label = Label.new()
	name_label.text = skin_data.get("name", skin_id)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", border_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(name_label)

	# Rarity
	var rarity_label: Label = Label.new()
	rarity_label.text = rarity.capitalize()
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(rarity_label)

	# Select button - bigger
	var select_btn: Button = Button.new()
	select_btn.text = "SELECT"
	select_btn.custom_minimum_size = Vector2(120, 35)
	select_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_btn.pressed.connect(_on_skin_chosen.bind(skin_id))
	card_vbox.add_child(select_btn)

func _on_skin_chosen(skin_id: String) -> void:
	"""Handle skin selection"""
	if not _skin_manager:
		return

	# Grant the skin for free
	_skin_manager.grant_skin(skin_id)

	# Equip it
	_skin_manager.equip_skin(_god_id, skin_id)

	# Clear pending
	_skin_manager.clear_pending_free_skin_god()

	print("FreeSkinPickPopup: Player chose skin '%s' for god '%s'" % [skin_id, _god_id])

	skin_selected.emit(_god_id, skin_id)
	_close_popup()

func _on_skip_pressed() -> void:
	"""Handle skip button - player can choose later from collection"""
	if _skin_manager:
		_skin_manager.clear_pending_free_skin_god()

	popup_closed.emit()
	_close_popup()

func _close_popup() -> void:
	"""Close and clean up the popup"""
	visible = false
	queue_free()
