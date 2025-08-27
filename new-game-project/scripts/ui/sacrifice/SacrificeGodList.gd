# scripts/ui/sacrifice/SacrificeGodList.gd
# Single responsibility: Display and manage the list of gods for sacrifice
class_name SacrificeGodList
extends Node

signal god_selected(god: God)

var god_grid: GridContainer
var scroll_container: ScrollContainer
var sort_controls: Control

func create_god_list() -> Control:
	var container = VBoxContainer.new()
	container.name = "GodListContainer"
	
	# Add sorting controls
	sort_controls = _create_sort_controls()
	container.add_child(sort_controls)
	
	# Add scrollable god grid
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll_container)
	
	god_grid = GridContainer.new()
	god_grid.columns = 4
	scroll_container.add_child(god_grid)
	
	refresh_list()
	return container

func refresh_list():
	_clear_grid()
	_populate_gods()

func _clear_grid():
	if not god_grid:
		return
	for child in god_grid.get_children():
		child.queue_free()

func _populate_gods():
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	var sacrificeable_gods = collection_manager.get_sacrificeable_gods()
	
	for god in sacrificeable_gods:
		var god_card = _create_god_card(god)
		god_grid.add_child(god_card)

func _create_god_card(god: God) -> Control:
	var ui_factory = SystemRegistry.get_instance().get_system("UICardFactory") 
	var card = ui_factory.create_god_card(god)
	
	# Make it selectable
	var button = card.get_node("SelectButton") # Assumes UICardFactory creates this
	if button:
		button.pressed.connect(_on_god_card_selected.bind(god))
	
	return card

func _on_god_card_selected(god: God):
	god_selected.emit(god)

func _create_sort_controls() -> Control:
	var controls = HBoxContainer.new()
	
	# Sort dropdown
	var sort_option = OptionButton.new()
	sort_option.add_item("Power")
	sort_option.add_item("Level") 
	sort_option.add_item("Tier")
	sort_option.add_item("Element")
	sort_option.add_item("Name")
	sort_option.item_selected.connect(_on_sort_changed)
	controls.add_child(sort_option)
	
	# Sort direction button
	var direction_btn = Button.new()
	direction_btn.text = "↓ Desc"
	direction_btn.pressed.connect(_on_sort_direction_changed)
	controls.add_child(direction_btn)
	
	return controls

func _on_sort_changed(_index: int):
	refresh_list()  # For now, just refresh. Later add actual sorting

func _on_sort_direction_changed():
	refresh_list()  # For now, just refresh. Later add actual sorting
