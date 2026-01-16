# scripts/ui/screens/ShopScreen.gd
# Main shop UI - handles crystal packs, skins, and special offers
extends Control

signal back_pressed

enum ShopTab { CRYSTALS, SKINS, OFFERS }

@onready var title_label = $MainContainer/Header/TitleLabel
@onready var crystal_amount = $MainContainer/Header/CrystalDisplay/CrystalAmount
@onready var crystals_tab = $MainContainer/TabContainer/CrystalsTab
@onready var skins_tab = $MainContainer/TabContainer/SkinsTab
@onready var offers_tab = $MainContainer/TabContainer/OffersTab
@onready var content_grid = $MainContainer/ContentPanel/ScrollContainer/ContentGrid
@onready var content_panel = $MainContainer/ContentPanel
@onready var back_button = $BackButton

# Current state
var current_tab: ShopTab = ShopTab.CRYSTALS

# System references
var _shop_manager: Node = null
var _skin_manager: Node = null
var _resource_manager: Node = null
var _collection_manager: Node = null

func _ready():
	_setup_fullscreen()
	_cache_system_references()
	_setup_ui()
	_connect_signals()
	_style_ui()
	_show_crystals_tab()

func _setup_fullscreen():
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_size(viewport_size)
	position = Vector2.ZERO

func _cache_system_references():
	var registry = SystemRegistry.get_instance()
	if registry:
		_shop_manager = registry.get_system("ShopManager")
		_skin_manager = registry.get_system("SkinManager")
		_resource_manager = registry.get_system("ResourceManager")
		_collection_manager = registry.get_system("CollectionManager")

func _setup_ui():
	_update_crystal_display()

func _connect_signals():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if crystals_tab:
		crystals_tab.pressed.connect(_on_crystals_tab_pressed)
	if skins_tab:
		skins_tab.pressed.connect(_on_skins_tab_pressed)
	if offers_tab:
		offers_tab.pressed.connect(_on_offers_tab_pressed)

	# Connect to resource changes
	if _resource_manager and _resource_manager.has_signal("resource_changed"):
		_resource_manager.resource_changed.connect(_on_resource_changed)

func _style_ui():
	_style_back_button()
	_style_tabs()
	_style_content_panel()

func _style_back_button():
	if not back_button:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.15, 0.22, 0.98)
	hover.border_color = Color(0.5, 0.45, 0.6, 1.0)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("hover", hover)

	back_button.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	back_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))

func _style_tabs():
	var tabs = [crystals_tab, skins_tab, offers_tab]
	for tab in tabs:
		if not tab:
			continue

		var normal = StyleBoxFlat.new()
		normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
		normal.border_color = Color(0.4, 0.35, 0.5, 0.6)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(6)
		tab.add_theme_stylebox_override("normal", normal)

		var hover = StyleBoxFlat.new()
		hover.bg_color = Color(0.2, 0.17, 0.28, 0.95)
		hover.border_color = Color(0.6, 0.5, 0.4, 0.8)
		hover.set_border_width_all(1)
		hover.set_corner_radius_all(6)
		tab.add_theme_stylebox_override("hover", hover)

		var pressed = StyleBoxFlat.new()
		pressed.bg_color = Color(0.25, 0.2, 0.35, 1.0)
		pressed.border_color = Color(0.95, 0.85, 0.6, 1.0)
		pressed.set_border_width_all(2)
		pressed.set_corner_radius_all(6)
		tab.add_theme_stylebox_override("pressed", pressed)

		tab.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
		tab.add_theme_color_override("font_hover_color", Color(0.9, 0.85, 0.75))
		tab.add_theme_color_override("font_pressed_color", Color(0.95, 0.85, 0.6))

func _style_content_panel():
	if not content_panel:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.8)
	style.border_color = Color(0.3, 0.25, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	content_panel.add_theme_stylebox_override("panel", style)

# ==============================================================================
# TAB HANDLING
# ==============================================================================

func _on_crystals_tab_pressed():
	_show_crystals_tab()

func _on_skins_tab_pressed():
	_show_skins_tab()

func _on_offers_tab_pressed():
	_show_offers_tab()

func _show_crystals_tab():
	current_tab = ShopTab.CRYSTALS
	_update_tab_states()
	_clear_content()
	_populate_crystal_packs()

func _show_skins_tab():
	current_tab = ShopTab.SKINS
	_update_tab_states()
	_clear_content()
	_populate_skins()

func _show_offers_tab():
	current_tab = ShopTab.OFFERS
	_update_tab_states()
	_clear_content()
	_populate_offers()

func _update_tab_states():
	if crystals_tab:
		crystals_tab.button_pressed = current_tab == ShopTab.CRYSTALS
	if skins_tab:
		skins_tab.button_pressed = current_tab == ShopTab.SKINS
	if offers_tab:
		offers_tab.button_pressed = current_tab == ShopTab.OFFERS

func _clear_content():
	if not content_grid:
		return
	for child in content_grid.get_children():
		child.queue_free()

# ==============================================================================
# CRYSTAL PACKS
# ==============================================================================

func _populate_crystal_packs():
	if not _shop_manager or not content_grid:
		return

	var packs = _shop_manager.get_crystal_packs()
	for pack in packs:
		var card = _create_crystal_pack_card(pack)
		content_grid.add_child(card)

func _create_crystal_pack_card(pack: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 250)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.95)
	style.border_color = Color(0.4, 0.6, 0.8, 0.8) if pack.get("best_value", false) else Color(0.4, 0.35, 0.5, 0.6)
	style.set_border_width_all(2 if pack.get("best_value", false) else 1)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Best value badge
	if pack.get("best_value", false):
		var badge = Label.new()
		badge.text = "BEST VALUE"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		badge.add_theme_font_size_override("font_size", 12)
		vbox.add_child(badge)

	# Pack name
	var name_label = Label.new()
	name_label.text = pack.get("name", "Crystal Pack")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Crystal amount
	var crystals = pack.get("crystals", 0)
	var bonus = pack.get("bonus", 0)
	var crystal_label = Label.new()
	crystal_label.text = "💎 %d" % crystals
	crystal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crystal_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	crystal_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(crystal_label)

	# Bonus
	if bonus > 0:
		var bonus_label = Label.new()
		bonus_label.text = "+%d BONUS" % bonus
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		bonus_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(bonus_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = pack.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buy button
	var buy_button = Button.new()
	buy_button.text = "$%.2f" % pack.get("price_usd", 0.0)
	buy_button.custom_minimum_size = Vector2(120, 40)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_buy_button(buy_button, Color(0.3, 0.6, 0.4))
	buy_button.pressed.connect(_on_crystal_pack_purchased.bind(pack.get("id", "")))
	vbox.add_child(buy_button)

	return card

func _on_crystal_pack_purchased(pack_id: String):
	if _shop_manager:
		var success = _shop_manager.purchase_crystal_pack(pack_id)
		if success:
			_update_crystal_display()
			_show_purchase_feedback("Crystals added!")

# ==============================================================================
# SKINS
# ==============================================================================

func _populate_skins():
	if not _skin_manager or not content_grid:
		return

	var skins = _skin_manager.get_all_skins()
	for skin in skins:
		var card = _create_skin_card(skin)
		content_grid.add_child(card)

func _create_skin_card(skin: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 280)

	var rarity = skin.get("rarity", "common")
	var rarity_color = _get_rarity_color(rarity)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.18, 0.95)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Rarity badge
	var rarity_label = Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", rarity_color)
	rarity_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(rarity_label)

	# Portrait placeholder
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.color = Color(0.2, 0.18, 0.25, 1.0)
	vbox.add_child(portrait)

	# Skin name
	var name_label = Label.new()
	name_label.text = skin.get("name", "Skin")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# God name
	var god_label = Label.new()
	god_label.text = skin.get("god_id", "").capitalize()
	god_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	god_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(god_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = skin.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buy/Equip button
	var skin_id = skin.get("id", "")
	var is_owned = _skin_manager.is_skin_owned(skin_id)
	var button = Button.new()

	if is_owned:
		button.text = "OWNED"
		button.disabled = true
		_style_buy_button(button, Color(0.3, 0.3, 0.3))
	else:
		var cost = skin.get("cost_crystals", 0)
		button.text = "💎 %d" % cost
		_style_buy_button(button, rarity_color * 0.7)
		button.pressed.connect(_on_skin_purchase_pressed.bind(skin_id))

	button.custom_minimum_size = Vector2(120, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(button)

	return card

func _on_skin_purchase_pressed(skin_id: String):
	if _skin_manager:
		var success = _skin_manager.purchase_skin(skin_id)
		if success:
			_update_crystal_display()
			_show_skins_tab()  # Refresh to show owned state
			_show_purchase_feedback("Skin unlocked!")

# ==============================================================================
# SPECIAL OFFERS
# ==============================================================================

func _populate_offers():
	if not _shop_manager or not content_grid:
		return

	var offers = _shop_manager.get_special_offers()
	for offer in offers:
		var card = _create_offer_card(offer)
		content_grid.add_child(card)

func _create_offer_card(offer: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 200)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style.border_color = Color(0.9, 0.7, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Offer name
	var name_label = Label.new()
	name_label.text = offer.get("name", "Special Offer")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = offer.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Rewards preview
	var rewards_text = ""
	if offer.has("rewards"):
		for key in offer.rewards:
			rewards_text += "%s: %d\n" % [key.capitalize().replace("_", " "), offer.rewards[key]]
	if offer.has("immediate_reward"):
		for key in offer.immediate_reward:
			rewards_text += "%s: %d\n" % [key.capitalize().replace("_", " "), offer.immediate_reward[key]]
	if offer.has("daily_reward"):
		for key in offer.daily_reward:
			rewards_text += "Daily: %d %s\n" % [offer.daily_reward[key], key.capitalize().replace("_", " ")]

	if not rewards_text.is_empty():
		var rewards_label = Label.new()
		rewards_label.text = rewards_text.strip_edges()
		rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rewards_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		rewards_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(rewards_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Buy button
	var offer_id = offer.get("id", "")
	var check = _shop_manager.can_purchase_offer(offer_id)
	var button = Button.new()

	if check.can_purchase:
		button.text = "$%.2f" % offer.get("price_usd", 0.0)
		_style_buy_button(button, Color(0.6, 0.5, 0.2))
		button.pressed.connect(_on_offer_purchase_pressed.bind(offer_id))
	else:
		button.text = check.get("reason", "Unavailable")
		button.disabled = true
		_style_buy_button(button, Color(0.3, 0.3, 0.3))

	button.custom_minimum_size = Vector2(140, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(button)

	return card

func _on_offer_purchase_pressed(offer_id: String):
	if _shop_manager:
		var success = _shop_manager.purchase_special_offer(offer_id)
		if success:
			_update_crystal_display()
			_show_offers_tab()  # Refresh to show updated state
			_show_purchase_feedback("Offer claimed!")

# ==============================================================================
# HELPERS
# ==============================================================================

func _style_buy_button(button: Button, accent_color: Color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = accent_color
	normal.border_color = accent_color * 1.3
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = accent_color * 1.2
	hover.border_color = accent_color * 1.5
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", hover)

	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(6)
	button.add_theme_stylebox_override("disabled", disabled)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common": return Color(0.7, 0.7, 0.7)
		"rare": return Color(0.3, 0.5, 1.0)
		"epic": return Color(0.7, 0.3, 1.0)
		"legendary": return Color(1.0, 0.7, 0.0)
		_: return Color.WHITE

func _update_crystal_display():
	if not crystal_amount or not _resource_manager:
		return
	var crystals = _resource_manager.get_resource("divine_crystals")
	crystal_amount.text = str(int(crystals))

func _show_purchase_feedback(message: String):
	# Simple feedback - could be enhanced with notification system
	if title_label:
		var original_text = title_label.text
		title_label.text = message
		title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(func():
			if title_label:
				title_label.text = original_text
				title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		)

func _on_resource_changed(_resource_type: String, _new_amount):
	_update_crystal_display()

func _on_back_pressed():
	back_pressed.emit()
