# scripts/ui/battle_setup/TeamSelectionManager.gd
# Single responsibility: Manage team selection UI and functionality
class_name TeamSelectionManager
extends Node

signal team_changed(team: Array)
signal battle_start_requested(team: Array)
signal setup_cancelled

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")

var team_slots_container: HBoxContainer = null
var available_gods_scroll: ScrollContainer = null
var available_gods_grid: GridContainer = null
var start_battle_button: Button = null
var cancel_button: Button = null

var selected_team: Array = []
var team_slots: Array = []
var max_team_size: int = 4
var battle_context: Dictionary = {}

func initialize(slots_container: HBoxContainer, gods_grid: GridContainer, start_btn: Button, cancel_btn: Button):
	"""Initialize with node references from the scene"""
	team_slots_container = slots_container
	available_gods_grid = gods_grid
	start_battle_button = start_btn
	cancel_button = cancel_btn

	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_create_team_slots()
	_load_available_gods()

func setup_for_context(context: Dictionary):
	battle_context = context
	_update_ui_for_context()

func _update_ui_for_context():
	match battle_context.get("type", ""):
		"territory":
			_setup_for_territory()
		"dungeon":
			_setup_for_dungeon()
		"pvp":
			_setup_for_pvp()
		"hex_capture":
			_setup_for_hex_capture()

func _setup_for_territory():
	max_team_size = 4  # Territory battles use 4-god teams
	_refresh_team_slots()

func _setup_for_dungeon():
	max_team_size = 4  # Dungeon battles use 4-god teams  
	_refresh_team_slots()

func _setup_for_pvp():
	max_team_size = 4  # PvP battles use 4-god teams
	_refresh_team_slots()

func _setup_for_hex_capture():
	max_team_size = 4  # Hex capture battles use 4-god teams
	_refresh_team_slots()

func _create_team_slots():
	team_slots.clear()
	
	for i in range(max_team_size):
		var slot = _create_team_slot(i)
		team_slots_container.add_child(slot)
		team_slots.append(slot)
		selected_team.append(null)

func _refresh_team_slots():
	# Clear existing slots
	for slot in team_slots:
		slot.queue_free()
	team_slots.clear()
	selected_team.clear()
	
	# Recreate with new team size
	_create_team_slots()

func _create_team_slot(index: int) -> Control:
	var slot = Panel.new()
	slot.name = "TeamSlot_" + str(index)
	slot.custom_minimum_size = Vector2(120, 150)
	
	var container = VBoxContainer.new()
	slot.add_child(container)
	
	# God display area
	var god_display = Control.new()
	god_display.name = "GodDisplay"
	god_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(god_display)
	
	# Clear button
	var clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_clear_slot.bind(index))
	container.add_child(clear_button)
	
	return slot

func _load_available_gods():
	# Clear existing gods
	for child in available_gods_grid.get_children():
		child.queue_free()

	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	if not collection_manager:
		push_error("TeamSelectionManager: CollectionManager not found")
		return

	var all_gods = collection_manager.get_all_gods()

	# Filter gods that are available for battle (not in garrison or working)
	var available_gods = []
	for god in all_gods:
		if _is_god_available_for_battle(god):
			available_gods.append(god)

	for god in available_gods:
		var god_button = _create_god_selection_button(god)
		available_gods_grid.add_child(god_button)

func _create_god_selection_button(god: God) -> Control:
	# Create a clickable card using GodCardFactory
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(120, 150)

	# Create the god card with BATTLE_SELECTION preset
	var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.BATTLE_SELECTION)
	god_card.set_god(god)
	card_container.add_child(god_card)

	# Make the card clickable by adding a button overlay
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(120, 150)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_god_selected.bind(god))
	card_container.add_child(button)

	return card_container

func _on_god_selected(god: God):
	# Find first empty slot
	for i in range(selected_team.size()):
		if selected_team[i] == null:
			_assign_god_to_slot(god, i)
			break

func _assign_god_to_slot(god: God, slot_index: int):
	selected_team[slot_index] = god
	_update_slot_display(slot_index)
	team_changed.emit(selected_team)

func _clear_slot(slot_index: int):
	selected_team[slot_index] = null
	_update_slot_display(slot_index)
	team_changed.emit(selected_team)

func _update_slot_display(slot_index: int):
	if slot_index < 0 or slot_index >= team_slots.size():
		return

	var slot = team_slots[slot_index]
	if not slot:
		return

	var god_display = slot.get_node_or_null("VBoxContainer/GodDisplay")
	if not god_display:
		push_warning("TeamSelectionManager: god_display not found for slot " + str(slot_index))
		return

	# Clear existing display
	for child in god_display.get_children():
		child.queue_free()

	var god = selected_team[slot_index]
	if god == null:
		var empty_label = Label.new()
		empty_label.text = "Empty Slot"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 100)
		god_display.add_child(empty_label)
	else:
		# Use GodCardFactory to create a card
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_card.set_god(god)
		god_display.add_child(god_card)

func _on_start_battle_pressed():
	# Validate team has at least one god
	var has_gods = false
	for god in selected_team:
		if god != null:
			has_gods = true
			break
	
	if not has_gods:
		var notification_manager = SystemRegistry.get_instance().get_system("NotificationManager")
		notification_manager.show_error("Please select at least one god for battle")
		return
	
	battle_start_requested.emit(selected_team)

func _on_cancel_pressed():
	setup_cancelled.emit()

func _is_god_available_for_battle(god: God) -> bool:
	"""Check if god is available for battle (not in garrison or working on a node)"""
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		return true

	# Check all controlled nodes to see if god is assigned
	var controlled_nodes = territory_manager.get_controlled_nodes()
	for node in controlled_nodes:
		# Check garrison
		if node.garrison.has(god.id):
			return false
		# Check workers
		if node.assigned_workers.has(god.id):
			return false

	return true
