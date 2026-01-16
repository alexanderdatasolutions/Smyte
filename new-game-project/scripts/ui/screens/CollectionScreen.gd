class_name CollectionScreen
extends Control

"""
CollectionScreen.gd - God collection management screen using SystemRegistry
RULE 1: Single responsibility - ONLY orchestrates collection UI display (now under 500 lines)
RULE 4: No data modification - delegates to systems through SystemRegistry
RULE 5: Uses SystemRegistry for all system access
Uses standardized GodCard component for consistent god display
Delegates sorting to CollectionSorter and details display to CollectionDetailsPanel
"""

# Preload helper components
const CollectionSorter = preload("res://scripts/ui/collection/CollectionSorter.gd")
const CollectionDetailsPanel = preload("res://scripts/ui/collection/CollectionDetailsPanel.gd")

signal back_pressed

@onready var grid_container = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer/GridContainer
@onready var back_button = $BackButton
@onready var details_content = $MainContainer/RightPanel/DetailsContainer/DetailsContent
@onready var no_selection_label = $MainContainer/RightPanel/DetailsContainer/DetailsContent/NoSelectionLabel

# SystemRegistry references
var collection_manager
var resource_manager

# Sorting helper (extracted to separate class)
var sorter: CollectionSorter

# Track selected god for visual highlight
var selected_god: God = null

func _ready():
	_init_systems()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Setup sorting UI using helper
	sorter = CollectionSorter.new()
	var left_panel_vbox = $MainContainer/LeftPanel/ScrollContainer/VBoxContainer
	if left_panel_vbox:
		sorter.setup_sorting_ui(left_panel_vbox, refresh_collection)

	refresh_collection()
	show_no_selection()

	# Connect to EventBus to listen for collection changes
	_connect_to_events()

func _connect_to_events():
	"""Connect to events that should trigger collection refresh"""
	var registry = SystemRegistry.get_instance()
	if registry:
		var event_bus = registry.get_system("EventBus")
		if event_bus:
			# Refresh when gods gain experience or level up
			if not event_bus.experience_gained.is_connected(_on_god_updated):
				event_bus.experience_gained.connect(_on_god_updated)
			if not event_bus.god_level_up.is_connected(_on_god_level_up):
				event_bus.god_level_up.connect(_on_god_level_up)
			if not event_bus.god_obtained.is_connected(_on_collection_changed):
				event_bus.god_obtained.connect(_on_collection_changed)
			# IMPORTANT: Listen to collection_updated for god removals (sacrifice)
			if not event_bus.collection_updated.is_connected(_on_collection_changed):
				event_bus.collection_updated.connect(_on_collection_changed)

func _on_god_updated(_god_id: String, _experience: int):
	"""Called when a god gains experience - refresh display"""
	refresh_collection()

func _on_god_level_up(_god, _new_level: int, _old_level: int):
	"""Called when a god levels up - refresh display"""
	refresh_collection()

func _on_collection_changed(_god):
	"""Called when collection changes - refresh display"""
	refresh_collection()

# Also add visibility change detection
func _notification(what: int):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# Screen became visible - refresh collection
		if collection_manager:
			refresh_collection()

func _init_systems():
	"""Initialize SystemRegistry systems - RULE 5"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("CollectionScreen: SystemRegistry not available!")
		return

	collection_manager = registry.get_system("CollectionManager")
	resource_manager = registry.get_system("ResourceManager")

	if not collection_manager:
		push_error("CollectionScreen: CollectionManager not found!")
	if not resource_manager:
		push_error("CollectionScreen: ResourceManager not found!")

func refresh_collection():
	"""Refresh the god collection display using standardized GodCard component"""

	if not collection_manager:
		return

	# Get gods from SystemRegistry
	var gods_data = collection_manager.get_all_gods()

	# Sort gods according to current settings using sorter helper
	if sorter:
		gods_data = sorter.sort_gods(gods_data, get_power_rating)

	# Clear existing god cards
	for child in grid_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	if gods_data.is_empty():
		var no_gods_label = Label.new()
		no_gods_label.text = "No gods in your collection yet!"
		no_gods_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_container.add_child(no_gods_label)
		return

	# Create god cards using factory for consistency
	for god in gods_data:
		if god != null:
			var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COLLECTION_DETAILED)
			grid_container.add_child(god_card)

			# Apply SELECTED style if this is the selected god
			var card_style = GodCard.CardStyle.SELECTED if (selected_god and selected_god.id == god.id) else GodCard.CardStyle.NORMAL
			god_card.setup_god_card(god, card_style)
			god_card.god_selected.connect(show_god_details)

func show_god_details(god: God):
	"""Show god details in right panel using helper class"""
	# Track selected god and refresh to update visual highlight
	selected_god = god
	CollectionDetailsPanel.show_god_details(god, details_content, no_selection_label)
	# Refresh cards to show selection highlight
	refresh_collection()

func show_no_selection():
	"""Show the no selection message"""
	if no_selection_label:
		no_selection_label.visible = true

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()

func get_power_rating(god) -> int:
	"""Get power rating using GodCalculator for consistency (RULE 3)"""
	return GodCalculator.get_power_rating(god)
