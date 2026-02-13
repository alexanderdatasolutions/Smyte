# scripts/utilities/GodCardFactory.gd
# Factory for creating standardized god cards across different screens
# RULE 2: Single responsibility - ONLY creates god cards with proper configuration
class_name GodCardFactory

const GodCardScript = preload("res://scripts/ui/components/GodCard.gd")

# Card configuration presets for different screens
enum CardPreset {
	COLLECTION_DETAILED,   # Large cards with full info for collection screen
	SACRIFICE_SELECTION,   # Medium cards for sacrifice selection  
	AWAKENING_SELECTION,  # Medium cards showing awakening readiness
	BATTLE_SELECTION,     # Medium cards for battle team selection
	COMPACT_LIST,         # Small cards for lists/grids
	TERRITORY_ASSIGNMENT  # Cards showing territory assignments
}

static func create_god_card(preset: CardPreset) -> Control:
	"""Create a god card configured for specific screen"""
	var card = GodCardScript.new()
	_configure_card_for_preset(card, preset)
	return card

static func _configure_card_for_preset(card: Control, preset: CardPreset):
	"""Configure card properties based on preset"""
	match preset:
		CardPreset.COLLECTION_DETAILED:
			card.card_size = GodCardScript.CardSize.LARGE
			card.show_experience_bar = true
			card.show_power_rating = true
			card.show_territory_assignment = true
			card.show_awakening_status = false
			card.clickable = true
		
		CardPreset.SACRIFICE_SELECTION:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_experience_bar = true
			card.show_power_rating = true
			card.show_territory_assignment = true
			card.show_awakening_status = false
			card.clickable = true
		
		CardPreset.AWAKENING_SELECTION:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_experience_bar = true
			card.show_power_rating = true
			card.show_territory_assignment = true
			card.show_awakening_status = true
			card.clickable = true
		
		CardPreset.BATTLE_SELECTION:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_experience_bar = false
			card.show_power_rating = true
			card.show_territory_assignment = false
			card.show_awakening_status = false
			card.clickable = true
		
		CardPreset.COMPACT_LIST:
			card.card_size = GodCardScript.CardSize.SMALL
			card.show_experience_bar = false
			card.show_power_rating = false
			card.show_territory_assignment = false
			card.show_awakening_status = false
			card.clickable = true
		
		CardPreset.TERRITORY_ASSIGNMENT:
			card.card_size = GodCardScript.CardSize.MEDIUM
			card.show_experience_bar = false
			card.show_power_rating = true
			card.show_territory_assignment = true
			card.show_awakening_status = false
			card.clickable = true

