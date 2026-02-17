# scripts/utilities/UICardFactory.gd
# Reusable UI card creation using standardized GodCard component
# All cards show: Big PNG, "Lv.X Name ★★★", "⚔Power 🛡Equip", "📍Location"
class_name UICardFactory extends RefCounted

const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

enum CardStyle {
	STANDARD,   # Medium size
	COMPACT,    # Small size
	LARGE,      # Large size
	AWAKENING,  # Medium + awakening indicator
}

static func create_god_card(god: God, style: CardStyle = CardStyle.STANDARD) -> Control:
	if not god:
		push_error("UICardFactory: Cannot create card for null god")
		return null

	var card: GodCard = GodCardScript.new()

	card.show_power_rating = true
	card.show_territory_assignment = true
	card.show_equipment_status = true
	card.clickable = true

	match style:
		CardStyle.STANDARD:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_awakening_status = false

		CardStyle.COMPACT:
			card.card_size = GodCardScript.CardSize.SMALL
			card.show_awakening_status = false

		CardStyle.LARGE:
			card.card_size = GodCardScript.CardSize.LARGE
			card.show_awakening_status = false

		CardStyle.AWAKENING:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_awakening_status = true

	card.setup_god_card(god, GodCardScript.CardStyle.NORMAL)
	return card

static func create_god_card_styled(god: God, style: CardStyle, card_style: GodCard.CardStyle) -> Control:
	if not god:
		push_error("UICardFactory: Cannot create card for null god")
		return null

	var card: GodCard = GodCardScript.new()

	card.show_power_rating = true
	card.show_territory_assignment = true
	card.show_equipment_status = true
	card.clickable = true

	match style:
		CardStyle.STANDARD:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_awakening_status = false

		CardStyle.COMPACT:
			card.card_size = GodCardScript.CardSize.SMALL
			card.show_awakening_status = false

		CardStyle.LARGE:
			card.card_size = GodCardScript.CardSize.LARGE
			card.show_awakening_status = false

		CardStyle.AWAKENING:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_awakening_status = true

	card.setup_god_card(god, card_style)
	return card
