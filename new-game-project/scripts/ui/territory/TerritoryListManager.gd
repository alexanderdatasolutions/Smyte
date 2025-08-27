# scripts/ui/territory/TerritoryListManager.gd
# Single responsibility: Manage the scrollable list of territory cards
class_name TerritoryListManager
extends Node

signal territory_action_requested(territory: Territory, action: String, data: Dictionary)

# Load component scripts
const TerritoryCardFactoryScript = preload("res://scripts/ui/territory/TerritoryCardFactory.gd")

var territory_list: VBoxContainer
var current_filter: String = "all"

func create_territory_list() -> Control:
	territory_list = VBoxContainer.new()
	territory_list.name = "TerritoryList"
	
	refresh_territories()
	return territory_list

func refresh_territories():
	_clear_list()
	_populate_territories()

func on_filter_changed(filter_id: String):
	current_filter = filter_id
	refresh_territories()

func _clear_list():
	if not territory_list:
		return
	for child in territory_list.get_children():
		child.queue_free()

func _populate_territories():
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var territories = territory_manager.get_territories_by_filter(current_filter)
	
	for territory in territories:
		var territory_card = _create_territory_card(territory)
		territory_list.add_child(territory_card)

func _create_territory_card(territory: Territory) -> Control:
	var card_factory = TerritoryCardFactoryScript.new()
	var card = card_factory.create_territory_card(territory)
	
	# Connect card signals
	if card.has_signal("collect_resources"):
		card.collect_resources.connect(_on_collect_resources.bind(territory))
	if card.has_signal("manage_territory"):
		card.manage_territory.connect(_on_manage_territory.bind(territory))
	if card.has_signal("attack_territory"):
		card.attack_territory.connect(_on_attack_territory.bind(territory))
	
	return card

func _on_collect_resources(territory: Territory):
	territory_action_requested.emit(territory, "collect_resources", {})

func _on_manage_territory(territory: Territory):
	territory_action_requested.emit(territory, "manage_gods", {})

func _on_attack_territory(territory: Territory):
	territory_action_requested.emit(territory, "attack", {})
