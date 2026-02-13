# scripts/utilities/UICardFactory.gd
# Reusable UI card creation for god displays across screens
class_name UICardFactory extends RefCounted

enum CardStyle {
	COLLECTION,
	BATTLE_SETUP,
}

## Create a god card with specified style
static func create_god_card(god: God, style: CardStyle = CardStyle.COLLECTION) -> Control:
	if not god:
		push_error("UICardFactory: Cannot create card for null god")
		return null

	var card := Control.new()
	card.name = "GodCard_" + god.name
	card.set_meta("god_data", god)
	card.custom_minimum_size = Vector2(120, 150)

	var background := Panel.new()
	background.anchors_preset = Control.PRESET_FULL_RECT
	card.add_child(background)

	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_label := Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var info_label := Label.new()
	info_label.text = "Tier " + str(god.tier) + " | Lv." + str(god.level)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(info_label)

	var select_button := Button.new()
	select_button.name = "SelectButton"
	select_button.text = "Select"
	vbox.add_child(select_button)

	match style:
		CardStyle.COLLECTION:
			_apply_collection_style(card)
		CardStyle.BATTLE_SETUP:
			_apply_battle_setup_style(card)

	return card

# Private style application methods

static func _apply_collection_style(card: Control) -> void:
	if card.has_method("set_show_level"):
		card.set_show_level(true)
	if card.has_method("set_show_element"):
		card.set_show_element(true)
	if card.has_method("set_interactive"):
		card.set_interactive(true)

static func _apply_battle_setup_style(card: Control) -> void:
	if card.has_method("set_show_stats"):
		card.set_show_stats(true)
	if card.has_method("set_show_hp"):
		card.set_show_hp(true)
	if card.has_method("set_compact_mode"):
		card.set_compact_mode(false)
