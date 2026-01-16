# scripts/utilities/UICardFactory.gd
# Eliminates 150+ lines of duplicate UI card creation code from GameInitializer
class_name UICardFactory extends RefCounted

# Preloaded card scenes for performance
# Scene references - TODO: Create actual scene files
# const GOD_CARD_SCENE = preload("res://scenes/ui/GodCard.tscn")
# const EQUIPMENT_CARD_SCENE = preload("res://scenes/ui/EquipmentCard.tscn") 
# const TERRITORY_CARD_SCENE = preload("res://scenes/ui/TerritoryCard.tscn")

# Card style configurations
enum CardStyle {
	COLLECTION,  # Standard collection view
	BATTLE_SETUP,  # Battle team selection
	SUMMON_RESULT,  # Summon animation result
	SMALL_ICON,  # Compact icon view
	DETAILED_VIEW  # Full stat display
}

## Create a god card with specified style
static func create_god_card(god: God, style: CardStyle = CardStyle.COLLECTION) -> Control:
	if not god:
		push_error("UICardFactory: Cannot create card for null god")
		return null
	
	# Create card structure with proper UI elements
	var card = Control.new()
	card.name = "GodCard_" + god.name
	card.set_meta("god_data", god)
	card.custom_minimum_size = Vector2(120, 150)
	
	# Create background panel
	var background = Panel.new()
	background.anchors_preset = Control.PRESET_FULL_RECT
	card.add_child(background)
	
	# Create vertical layout for card content
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	
	# Add god name label
	var name_label = Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Add tier/level info
	var info_label = Label.new()
	info_label.text = "Tier " + str(god.tier) + " | Lv." + str(god.level)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(info_label)
	
	# Add select button (needed for sacrifice/awakening screens)
	var select_button = Button.new()
	select_button.name = "SelectButton"
	select_button.text = "Select"
	vbox.add_child(select_button)
	
	# Apply style-specific configurations
	match style:
		CardStyle.COLLECTION:
			_apply_collection_style(card, god)
		CardStyle.BATTLE_SETUP:
			_apply_battle_setup_style(card, god)
		CardStyle.SUMMON_RESULT:
			_apply_summon_result_style(card, god)
		CardStyle.SMALL_ICON:
			_apply_small_icon_style(card, god)
		CardStyle.DETAILED_VIEW:
			_apply_detailed_view_style(card, god)
	
	return card

## Create an equipment card with specified style
static func create_equipment_card(equipment: Equipment, style: CardStyle = CardStyle.COLLECTION) -> Control:
	if not equipment:
		push_error("UICardFactory: Cannot create card for null equipment")
		return null
	
	# TODO: Replace with actual scene instantiation when scenes are created
	var card = Control.new()
	card.name = "EquipmentCard_" + equipment.name
	card.set_meta("equipment_data", equipment)
	
	# Apply style-specific configurations
	match style:
		CardStyle.COLLECTION:
			_apply_equipment_collection_style(card, equipment)
		CardStyle.DETAILED_VIEW:
			_apply_equipment_detailed_style(card, equipment)
		CardStyle.SMALL_ICON:
			_apply_equipment_icon_style(card, equipment)
	
	return card

## Create a territory card
static func create_territory_card(territory: Dictionary, _style: CardStyle = CardStyle.COLLECTION) -> Control:
	if territory.is_empty():
		push_error("UICardFactory: Cannot create card for empty territory data")
		return null
	
	# TODO: Replace with actual scene instantiation when scenes are created
	var card = Control.new()
	card.name = "TerritoryCard_" + territory.get("name", "Unknown")
	card.set_meta("territory_data", territory)
	return card

## Create a compact god card for battle/team displays
static func create_compact_god_card(god: God) -> Control:
	return create_god_card(god, CardStyle.SMALL_ICON)

## Create multiple god cards in a grid layout
static func create_god_grid(gods: Array, style: CardStyle = CardStyle.COLLECTION, columns: int = 3) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = columns
	
	for god in gods:
		var card = create_god_card(god, style)
		if card:
			grid.add_child(card)
	
	return grid

## Create a team selection layout (5 slots for battle teams)
static func create_team_layout(team_gods: Array = []) -> HBoxContainer:
	var team_container = HBoxContainer.new()
	team_container.name = "TeamLayout"
	
	for i in range(5):  # Standard team size
		var slot = Control.new()
		slot.name = "TeamSlot" + str(i + 1)
		slot.custom_minimum_size = Vector2(80, 100)
		
		# Add background for empty slots
		var bg = ColorRect.new()
		bg.color = Color(0.2, 0.2, 0.2, 0.5)
		bg.anchors_preset = Control.PRESET_FULL_RECT
		slot.add_child(bg)
		
		# Add god card if available
		if i < team_gods.size() and team_gods[i] != null:
			var card = create_god_card(team_gods[i], CardStyle.BATTLE_SETUP)
			if card:
				slot.add_child(card)
		
		team_container.add_child(slot)
	
	return team_container

# Private style application methods

static func _apply_collection_style(card: Control, god: God):
	"""Standard collection view style"""
	if card.has_method("set_show_level"):
		card.set_show_level(true)
	if card.has_method("set_show_element"):
		card.set_show_element(true)
	if card.has_method("set_interactive"):
		card.set_interactive(true)

static func _apply_battle_setup_style(card: Control, god: God):
	"""Battle team selection style"""
	if card.has_method("set_show_stats"):
		card.set_show_stats(true)
	if card.has_method("set_show_hp"):
		card.set_show_hp(true)
	if card.has_method("set_compact_mode"):
		card.set_compact_mode(false)

static func _apply_summon_result_style(card: Control, god: God):
	"""Summon result animation style"""
	if card.has_method("set_animated"):
		card.set_animated(true)
	if card.has_method("set_highlight_new"):
		card.set_highlight_new(true)
	if card.has_method("set_scale"):
		card.set_scale(Vector2(1.2, 1.2))

static func _apply_small_icon_style(card: Control, god: God):
	"""Compact icon style"""
	if card.has_method("set_compact_mode"):
		card.set_compact_mode(true)
	if card.has_method("set_show_details"):
		card.set_show_details(false)
	card.custom_minimum_size = Vector2(40, 50)

static func _apply_detailed_view_style(card: Control, god: God):
	"""Full detailed view style"""
	if card.has_method("set_show_all_stats"):
		card.set_show_all_stats(true)
	if card.has_method("set_show_skills"):
		card.set_show_skills(true)
	if card.has_method("set_show_equipment"):
		card.set_show_equipment(true)

static func _apply_equipment_collection_style(card: Control, equipment: Equipment):
	"""Equipment collection style"""
	if card.has_method("set_show_level"):
		card.set_show_level(true)
	if card.has_method("set_show_main_stat"):
		card.set_show_main_stat(true)

static func _apply_equipment_detailed_style(card: Control, equipment: Equipment):
	"""Equipment detailed view style"""
	if card.has_method("set_show_all_stats"):
		card.set_show_all_stats(true)
	if card.has_method("set_show_sub_stats"):
		card.set_show_sub_stats(true)

static func _apply_equipment_icon_style(card: Control, equipment: Equipment):
	"""Equipment icon style"""
	if card.has_method("set_compact_mode"):
		card.set_compact_mode(true)
	card.custom_minimum_size = Vector2(32, 32)
