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
	# Clear the container first
	if team_slots_container:
		for child in team_slots_container.get_children():
			child.queue_free()

	team_slots.clear()
	selected_team.clear()

	for i in range(max_team_size):
		var slot = _create_team_slot(i)
		team_slots_container.add_child(slot)
		team_slots.append(slot)
		selected_team.append(null)

	print("TeamSelectionManager: Created ", team_slots.size(), " team slots")

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
	container.name = "VBoxContainer"  # Give it a name for easier debugging
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

	print("TeamSelectionManager: Created slot ", index, " with structure: ", slot.name, "/", container.name, "/", god_display.name)

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
	# Create a button that contains the god card
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 150)
	button.flat = false  # Make it visible to test if it's there
	button.text = ""  # No text, just visual
	button.pressed.connect(_on_god_selected.bind(god))

	# Add the god card as the button's visual content
	var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.BATTLE_SELECTION)
	god_card.setup_god_card(god)
	god_card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass to button

	# Also disable all children of the god card to ensure they don't capture clicks
	_disable_mouse_on_children(god_card)

	button.add_child(god_card)

	return button

func _disable_mouse_on_children(node: Node):
	"""Recursively disable mouse filtering on all children"""
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disable_mouse_on_children(child)

func _on_god_selected(god: God):
	print("TeamSelectionManager: God selected - ", god.name)
	# Find first empty slot
	for i in range(selected_team.size()):
		if selected_team[i] == null:
			print("TeamSelectionManager: Assigning to slot ", i)
			_assign_god_to_slot(god, i)
			break

func _assign_god_to_slot(god: God, slot_index: int):
	selected_team[slot_index] = god
	_update_slot_display(slot_index)
	_load_available_gods()  # Refresh to remove selected god from available list
	team_changed.emit(selected_team)

func _clear_slot(slot_index: int):
	selected_team[slot_index] = null
	_update_slot_display(slot_index)
	_load_available_gods()  # Refresh to add god back to available list
	team_changed.emit(selected_team)

func _update_slot_display(slot_index: int):
	print("TeamSelectionManager: Updating slot display for slot ", slot_index)
	if slot_index < 0 or slot_index >= team_slots.size():
		print("TeamSelectionManager: Invalid slot index")
		return

	var slot = team_slots[slot_index]
	if not slot:
		print("TeamSelectionManager: Slot is null")
		return

	var god_display = slot.get_node_or_null("VBoxContainer/GodDisplay")
	if not god_display:
		push_warning("TeamSelectionManager: god_display not found for slot " + str(slot_index))
		print("TeamSelectionManager: Available children in slot: ", slot.get_children())
		return

	# Clear existing display
	for child in god_display.get_children():
		child.queue_free()

	var god = selected_team[slot_index]
	print("TeamSelectionManager: God for slot ", slot_index, " is ", god.name if god else "null")
	if god == null:
		var empty_label = Label.new()
		empty_label.text = "Empty Slot"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 100)
		god_display.add_child(empty_label)
		print("TeamSelectionManager: Added empty label to slot ", slot_index)
	else:
		# Use GodCardFactory to create a card
		var god_card = GodCardFactory.create_god_card(GodCardFactory.CardPreset.COMPACT_LIST)
		god_card.setup_god_card(god)
		god_display.add_child(god_card)
		print("TeamSelectionManager: Added god card for ", god.name, " to slot ", slot_index)

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
	# Check if already selected in this team
	for selected_god in selected_team:
		if selected_god != null and selected_god.id == god.id:
			return false

	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		return true

	# Check all controlled nodes to see if god is assigned
	var controlled_nodes = territory_manager.get_controlled_nodes()
	for node in controlled_nodes:
		# Check garrison - use find() instead of has() for typed arrays
		if node.garrison.find(god.id) != -1:
			return false
		# Check workers
		if node.assigned_workers.find(god.id) != -1:
			return false

	return true
