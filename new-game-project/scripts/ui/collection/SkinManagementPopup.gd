# scripts/ui/collection/SkinManagementPopup.gd
# Popup for managing god skins - shows gods with available skins
class_name SkinManagementPopup
extends Control

signal popup_closed

var _skin_manager: Node = null
var _collection_manager: Node = null
var _overlay: ColorRect = null
var _panel: Panel = null
var _god_list_container: VBoxContainer = null
var _skin_carousel: HBoxContainer = null
var _selected_god_id: String = ""
var _skins_title_label: Label = null

# Carousel state
var _all_skin_data: Array = []  # Array of {skin_id, skin_name, rarity, is_equipped, portrait_path}
var _carousel_index: int = 0
const CARDS_PER_PAGE: int = 3
var _prev_btn: Button = null
var _next_btn: Button = null
var _page_label: Label = null

func _ready() -> void:
	visible = false
	z_index = 100

func show_popup() -> void:
	var registry: Node = SystemRegistry.get_instance()
	_skin_manager = registry.get_system("SkinManager") if registry else null
	_collection_manager = registry.get_system("CollectionManager") if registry else null

	if not _skin_manager or not _collection_manager:
		push_error("SkinManagementPopup: Required systems not found")
		queue_free()
		return

	_build_popup()
	visible = true

func _build_popup() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	# Main panel - wider to fit 3 cards + nav buttons
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(950, 550)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = -_panel.custom_minimum_size / 2
	_panel.size = _panel.custom_minimum_size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

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

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Header with title and close button
	var header: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "GOD SKINS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(_close_popup)
	header.add_child(close_btn)

	# Subtitle
	var subtitle: Label = Label.new()
	subtitle.text = "Legendary gods at L40+ can equip skins"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	main_vbox.add_child(subtitle)

	main_vbox.add_child(HSeparator.new())

	# Main content - split into god list (left) and skin selection (right)
	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)

	# Left side - God list
	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(200, 0)
	content_hbox.add_child(left_panel)

	var gods_label: Label = Label.new()
	gods_label.text = "YOUR GODS"
	gods_label.add_theme_font_size_override("font_size", 14)
	gods_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	left_panel.add_child(gods_label)

	var god_scroll: ScrollContainer = ScrollContainer.new()
	god_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	god_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(god_scroll)

	_god_list_container = VBoxContainer.new()
	_god_list_container.add_theme_constant_override("separation", 5)
	_god_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	god_scroll.add_child(_god_list_container)

	# Vertical separator
	var vsep: VSeparator = VSeparator.new()
	content_hbox.add_child(vsep)

	# Right side - Skin selection
	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_panel)

	_skins_title_label = Label.new()
	_skins_title_label.name = "SkinsLabel"
	_skins_title_label.text = "SELECT A GOD"
	_skins_title_label.add_theme_font_size_override("font_size", 14)
	_skins_title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	right_panel.add_child(_skins_title_label)

	# Carousel container - navigation + cards + navigation
	var carousel_container: VBoxContainer = VBoxContainer.new()
	carousel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel_container.add_theme_constant_override("separation", 10)
	right_panel.add_child(carousel_container)

	# Carousel row with nav buttons
	var carousel_row: HBoxContainer = HBoxContainer.new()
	carousel_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_row.add_theme_constant_override("separation", 10)
	carousel_container.add_child(carousel_row)

	# Previous button
	_prev_btn = Button.new()
	_prev_btn.text = "◀"
	_prev_btn.custom_minimum_size = Vector2(40, 0)
	_prev_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prev_btn.pressed.connect(_on_prev_pressed)
	carousel_row.add_child(_prev_btn)

	# Skin cards container (centered)
	var cards_center: CenterContainer = CenterContainer.new()
	cards_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_row.add_child(cards_center)

	_skin_carousel = HBoxContainer.new()
	_skin_carousel.add_theme_constant_override("separation", 15)
	cards_center.add_child(_skin_carousel)

	# Next button
	_next_btn = Button.new()
	_next_btn.text = "▶"
	_next_btn.custom_minimum_size = Vector2(40, 0)
	_next_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_next_btn.pressed.connect(_on_next_pressed)
	carousel_row.add_child(_next_btn)

	# Page indicator
	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 12)
	_page_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	carousel_container.add_child(_page_label)

	# Populate god list
	_populate_god_list()

func _populate_god_list() -> void:
	# Clear existing
	for child in _god_list_container.get_children():
		child.queue_free()

	var gods: Array = _collection_manager.get_all_gods()
	var eligible_gods: Array = []

	# Only show legendary gods at level 40+ (skin-eligible)
	for god: God in gods:
		if god.tier != God.TierType.LEGENDARY or god.level < 40:
			continue  # Must be legendary L40+ to use skins

		var owned_skins: Array = _skin_manager.get_owned_skins_for_god(god.id)
		if not owned_skins.is_empty():
			eligible_gods.append(god)

	if eligible_gods.is_empty():
		var no_gods_label: Label = Label.new()
		no_gods_label.text = "No eligible gods\n(Legendary L40+ with skins)"
		no_gods_label.add_theme_font_size_override("font_size", 12)
		no_gods_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_god_list_container.add_child(no_gods_label)
		return

	# Sort by name for consistent display
	eligible_gods.sort_custom(func(a: God, b: God) -> bool: return a.name < b.name)

	for god: God in eligible_gods:
		var god_btn: Button = Button.new()
		god_btn.text = god.name
		god_btn.custom_minimum_size = Vector2(180, 40)
		god_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Show tier color
		match god.tier:
			God.TierType.LEGENDARY:
				god_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
			God.TierType.EPIC:
				god_btn.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))

		# Show equipped skin indicator
		if god.equipped_skin_id != "":
			god_btn.text += " ★"

		god_btn.pressed.connect(_on_god_clicked.bind(god.id))
		_god_list_container.add_child(god_btn)

func _on_god_clicked(god_id: String) -> void:
	_selected_god_id = god_id
	var god: God = _collection_manager.get_god_by_id(god_id)
	if god:
		_skins_title_label.text = "%s - SKINS" % god.name.to_upper()
	_populate_skin_grid(god_id)

func _populate_skin_grid(god_id: String) -> void:
	# Clear existing carousel
	for child in _skin_carousel.get_children():
		child.queue_free()
	_all_skin_data.clear()
	_carousel_index = 0

	var god: God = _collection_manager.get_god_by_id(god_id)
	if not god:
		return

	var current_skin_id: String = god.equipped_skin_id

	# Get default portrait path
	var default_portrait: String = "res://assets/gods/%s.png" % (god.template_id if god.template_id else god.id)

	# Add default skin to data
	_all_skin_data.append({
		"skin_id": "",
		"skin_name": "Default",
		"rarity": "",
		"is_equipped": current_skin_id == "",
		"portrait_path": default_portrait
	})

	# Only show OWNED skins (unowned skins are secret/hidden)
	var owned_skins: Array = _skin_manager.get_owned_skins_for_god(god_id)

	# Track which skins we've added to avoid duplicates
	var added_skins: Dictionary = {}

	for skin_id: String in owned_skins:
		if added_skins.has(skin_id):
			continue
		added_skins[skin_id] = true

		var skin_data: Dictionary = _skin_manager.get_skin(skin_id)
		_all_skin_data.append({
			"skin_id": skin_id,
			"skin_name": skin_data.get("name", skin_id),
			"rarity": skin_data.get("rarity", "common"),
			"is_equipped": skin_id == current_skin_id,
			"portrait_path": skin_data.get("portrait_path", "")
		})

	_refresh_carousel()

func _refresh_carousel() -> void:
	"""Refresh the carousel to show current page of skins"""
	# Clear existing cards
	for child in _skin_carousel.get_children():
		child.queue_free()

	# Calculate which skins to show
	var start_idx: int = _carousel_index * CARDS_PER_PAGE
	var end_idx: int = mini(start_idx + CARDS_PER_PAGE, _all_skin_data.size())

	for i in range(start_idx, end_idx):
		var data: Dictionary = _all_skin_data[i]
		_create_skin_card(data.skin_id, data.skin_name, data.rarity, data.is_equipped, data.portrait_path)

	# Update navigation
	var total_pages: int = ceili(float(_all_skin_data.size()) / CARDS_PER_PAGE)
	_prev_btn.disabled = _carousel_index <= 0
	_next_btn.disabled = _carousel_index >= total_pages - 1
	_page_label.text = "%d / %d" % [_carousel_index + 1, total_pages] if total_pages > 1 else ""
	_page_label.visible = total_pages > 1

func _on_prev_pressed() -> void:
	if _carousel_index > 0:
		_carousel_index -= 1
		_refresh_carousel()

func _on_next_pressed() -> void:
	var total_pages: int = ceili(float(_all_skin_data.size()) / CARDS_PER_PAGE)
	if _carousel_index < total_pages - 1:
		_carousel_index += 1
		_refresh_carousel()

func _create_skin_card(skin_id: String, skin_name: String, rarity: String, is_equipped: bool, portrait_path: String) -> void:
	"""Create a BIG skin card for the carousel"""
	var card: Panel = Panel.new()
	card.custom_minimum_size = Vector2(160, 280)

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
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", card_style)
	_skin_carousel.add_child(card)

	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 8)
	card_margin.add_theme_constant_override("margin_right", 8)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(card_margin)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card_margin.add_child(card_vbox)

	# Portrait image - BIG
	var portrait_container: CenterContainer = CenterContainer.new()
	portrait_container.custom_minimum_size = Vector2(0, 140)
	card_vbox.add_child(portrait_container)

	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(130, 130)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	else:
		portrait.modulate = Color(0.5, 0.5, 0.5)

	portrait_container.add_child(portrait)

	# Skin name - bigger
	var name_label: Label = Label.new()
	name_label.text = skin_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", border_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(name_label)

	# Status label
	var status_label: Label = Label.new()
	if is_equipped:
		status_label.text = "✓ Equipped"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	else:
		status_label.text = rarity.capitalize() if rarity else ""
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(status_label)

	# Action button - bigger
	var action_btn: Button = Button.new()
	action_btn.custom_minimum_size = Vector2(100, 30)
	action_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if is_equipped:
		action_btn.text = "Equipped"
		action_btn.disabled = true
	else:
		action_btn.text = "EQUIP"
		action_btn.pressed.connect(_on_equip_skin.bind(skin_id))

	card_vbox.add_child(action_btn)

func _on_equip_skin(skin_id: String) -> void:
	if _selected_god_id.is_empty():
		return

	if skin_id == "":
		_skin_manager.unequip_skin(_selected_god_id)
	else:
		_skin_manager.equip_skin(_selected_god_id, skin_id)

	# Refresh the display
	_populate_god_list()
	_populate_skin_grid(_selected_god_id)

	print("SkinManagementPopup: Equipped skin '%s' on god '%s'" % [skin_id if skin_id else "default", _selected_god_id])

func _on_buy_skin(skin_id: String) -> void:
	if _skin_manager.purchase_skin(skin_id):
		# Auto-equip after purchase
		if not _selected_god_id.is_empty():
			_skin_manager.equip_skin(_selected_god_id, skin_id)
		_populate_god_list()
		_populate_skin_grid(_selected_god_id)
		print("SkinManagementPopup: Purchased and equipped skin '%s'" % skin_id)
	else:
		print("SkinManagementPopup: Failed to purchase skin '%s'" % skin_id)

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _close_popup() -> void:
	popup_closed.emit()
	visible = false
	queue_free()
