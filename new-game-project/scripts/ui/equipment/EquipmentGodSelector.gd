# scripts/ui/equipment/EquipmentGodSelector.gd
# RULE 1 COMPLIANCE: Under 200 lines
# RULE 2 COMPLIANCE: Single responsibility - God selection only
# RULE 4 COMPLIANCE: UI Only - no business logic
extends Control
class_name EquipmentGodSelector

"""
Equipment God Selector Component
Handles god grid display and selection for equipment screen
SINGLE RESPONSIBILITY: God selection interface only
Uses existing GodCard component for proper display
"""

signal god_selected(god: God)

@onready var god_grid: GridContainer
var collection_manager: CollectionManager
var selected_god: God = null

func _ready():
	_initialize_systems()
	# Don't populate grid here - wait for set_god_grid to be called

func _initialize_systems():
	"""Initialize system references"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		collection_manager = system_registry.get_system("CollectionManager")
		if not collection_manager:
			push_error("EquipmentGodSelector: Could not get CollectionManager from SystemRegistry")
	else:
		push_error("EquipmentGodSelector: Could not get SystemRegistry instance")

func _populate_god_grid():
	"""Fill god grid with collected gods using proper GodCard components"""
	if not god_grid or not collection_manager:
		return
	
	# Clear existing children
	for child in god_grid.get_children():
		child.queue_free()
	
	var gods = collection_manager.get_all_gods()
	print("EquipmentGodSelector: Found %d gods to display" % gods.size())
	
	for god in gods:
		var god_card = _create_god_card(god)
		god_grid.add_child(god_card)
	
	# Force a layout update to ensure proper sizing
	call_deferred("_ensure_card_layout")

func _create_god_card(god: God) -> GodCard:
	"""Create a GodCard for god selection"""
	print("EquipmentGodSelector: Creating card for god %s" % god.name)
	var god_card = preload("res://scripts/ui/components/GodCard.gd").new()
	
	# Configure card for equipment screen use
	god_card.card_size = GodCard.CardSize.MEDIUM
	god_card.show_experience_bar = false  # Keep it cleaner for selection
	god_card.show_power_rating = true
	god_card.show_territory_assignment = true  # Show if god is stationed
	god_card.show_awakening_status = false
	god_card.clickable = true
	
	# Set up the god data and style
	var style = GodCard.CardStyle.NORMAL
	if selected_god and selected_god.id == god.id:
		style = GodCard.CardStyle.SELECTED
	
	print("EquipmentGodSelector: Calling setup_god_card for %s" % god.name)
	# Call setup_god_card which handles structure initialization
	god_card.setup_god_card(god, style)
	
	# Connect selection signal
	god_card.god_selected.connect(_on_god_card_selected)
	
	print("EquipmentGodSelector: Card created for %s" % god.name)
	return god_card

func _on_god_card_selected(god: God):
	"""Handle god card selection"""
	print("EquipmentGodSelector: Selected god %s" % god.name)
	selected_god = god
	_refresh_card_styles()
	god_selected.emit(god)

func _refresh_card_styles():
	"""Refresh all god card styles to show selection"""
	if not god_grid:
		return
		
	for child in god_grid.get_children():
		if child is GodCard:
			var god_card = child as GodCard
			var style = GodCard.CardStyle.NORMAL
			if selected_god and god_card.god_data and selected_god.id == god_card.god_data.id:
				style = GodCard.CardStyle.SELECTED
			god_card.setup_god_card(god_card.god_data, style)

func set_god_grid(grid: GridContainer):
	"""Set the god grid reference and populate it"""
	god_grid = grid
	# Now that we have the grid reference, populate it
	call_deferred("_populate_god_grid")  # Deferred to ensure UI is ready

func _ensure_card_layout():
	"""Ensure god cards have proper layout and sizing"""
	if not god_grid:
		return
	
	# Force layout calculations
	for child in god_grid.get_children():
		if child is GodCard:
			var god_card = child as GodCard
			# Force size recalculation
			god_card.size = god_card.custom_minimum_size
			god_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

func refresh():
	"""Refresh the god grid display"""
	_populate_god_grid()
