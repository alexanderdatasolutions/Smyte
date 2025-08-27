# scripts/ui/sacrifice/AwakeningGodList.gd
# Single responsibility: Display and manage the list of gods for awakening
class_name AwakeningGodList
extends Node

signal god_selected(god: God)

var god_grid: GridContainer
var scroll_container: ScrollContainer

func create_god_list() -> Control:
	var container = VBoxContainer.new()
	container.name = "AwakeningGodListContainer"
	
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
	var awakenable_gods = collection_manager.get_awakenable_gods()
	
	for god in awakenable_gods:
		var god_card = _create_god_card(god)
		god_grid.add_child(god_card)

func _create_god_card(god: God) -> Control:
	var ui_factory = SystemRegistry.get_instance().get_system("UICardFactory") 
	var card = ui_factory.create_god_card(god)
	
	# Make it selectable
	var button = card.get_node("SelectButton")
	if button:
		button.pressed.connect(_on_god_card_selected.bind(god))
	
	return card

func _on_god_card_selected(god: God):
	god_selected.emit(god)
