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

static func populate_god_grid(grid: GridContainer, gods: Array[God], preset: CardPreset, filter_func: Callable = Callable()):
	"""Populate a grid container with god cards"""
	# Clear existing cards
	for child in grid.get_children():
		child.queue_free()
	
	await Engine.get_main_loop().process_frame
	
	# Filter gods if filter function provided
	var filtered_gods = gods
	if filter_func.is_valid():
		filtered_gods = gods.filter(filter_func)
	
	# Create cards for each god
	for god in filtered_gods:
		var card = create_god_card(preset)
		card.setup_god_card(god)
		grid.add_child(card)

static func get_awakening_filter() -> Callable:
	"""Filter for gods that can be awakened (Epic/Legendary at level 40+)"""
	return func(god: God) -> bool:
		return god.tier >= God.TierType.EPIC and god.level >= 40

static func get_sacrificeable_filter() -> Callable:
	"""Filter for gods that can be sacrificed (not max level legendaries)"""
	return func(god: God) -> bool:
		return not (god.tier == God.TierType.LEGENDARY and god.level >= 40)

static func get_battle_ready_filter() -> Callable:
	"""Filter for gods that are battle ready (level 10+)"""
	return func(god: God) -> bool:
		return god.level >= 10
