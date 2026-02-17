# scripts/utilities/GodCardFactory.gd
# Factory for creating standardized god cards across different screens
# All cards show: Big PNG, "Lv.X Name ★★★", "⚔Power 🛡Equip", "📍Location"
class_name GodCardFactory

const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

# Card configuration presets - different sizes, same info
enum CardPreset {
	STANDARD,   # Medium size (default)
	LARGE,      # Larger for detailed views
	COMPACT,    # Smaller for grids
	AWAKENING   # Standard + awakening indicator
}

static func create_god_card(preset: CardPreset = CardPreset.STANDARD) -> Control:
	var card = GodCardScript.new()
	_configure_card_for_preset(card, preset)
	return card

static func _configure_card_for_preset(card: Control, preset: CardPreset):
	# All cards show same info
	card.show_power_rating = true
	card.show_territory_assignment = true
	card.show_equipment_status = true
	card.clickable = true

	match preset:
		CardPreset.STANDARD:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_awakening_status = false

		CardPreset.LARGE:
			card.card_size = GodCardScript.CardSize.LARGE
			card.show_awakening_status = false

		CardPreset.COMPACT:
			card.card_size = GodCardScript.CardSize.SMALL
			card.show_awakening_status = false

		CardPreset.AWAKENING:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_awakening_status = true
