# scripts/ui/battle_setup/TeamSelectionManager.gd
# Single responsibility: Manage team selection UI and functionality
class_name TeamSelectionManager
extends Control

signal team_changed(team: Array)
signal battle_start_requested(team: Array)
signal setup_cancelled

@onready var team_slots_container = $TeamSlotsContainer
@onready var available_gods_scroll = $AvailableGodsContainer/ScrollContainer
@onready var available_gods_grid = $AvailableGodsContainer/ScrollContainer/GodsGrid
@onready var start_battle_button = $BottomContainer/StartBattleButton
@onready var cancel_button = $BottomContainer/CancelButton

var selected_team: Array = []
var team_slots: Array = []
var max_team_size: int = 4
var battle_context: Dictionary = {}

func _ready():
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

func _setup_for_territory():
	max_team_size = 4  # Territory battles use 4-god teams
	_refresh_team_slots()

func _setup_for_dungeon():
	max_team_size = 4  # Dungeon battles use 4-god teams  
	_refresh_team_slots()

func _setup_for_pvp():
	max_team_size = 4  # PvP battles use 4-god teams
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
	var available_gods = collection_manager.get_available_gods_for_battle()
	
	for god in available_gods:
		var god_button = _create_god_selection_button(god)
		available_gods_grid.add_child(god_button)

func _create_god_selection_button(god: God) -> Control:
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 120)
	button.pressed.connect(_on_god_selected.bind(god))
	
	# Create god display
	var container = VBoxContainer.new()
	button.add_child(container)
	
	var name_label = Label.new()
	name_label.text = god.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = "Lv." + str(god.level)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(level_label)
	
	return button

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
	var slot = team_slots[slot_index]
	var god_display = slot.get_node("VBoxContainer/GodDisplay")
	
	# Clear existing display
	for child in god_display.get_children():
		child.queue_free()
	
	var god = selected_team[slot_index]
	if god == null:
		var empty_label = Label.new()
		empty_label.text = "Empty"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		god_display.add_child(empty_label)
	else:
		var ui_factory = SystemRegistry.get_instance().get_system("UICardFactory")
		var god_card = ui_factory.create_compact_god_card(god)
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
