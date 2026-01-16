# scripts/ui/territory/TerritoryListManager.gd
# Single responsibility: Manage the scrollable list of territory cards
class_name TerritoryListManager
extends Node

signal territory_action_requested(territory_id: String, action: String, data: Dictionary)
signal territories_refreshed(territory_count: int, controlled_count: int)

# Load component scripts
const TerritoryCardBuilderScript = preload("res://scripts/ui/territory/TerritoryCardBuilder.gd")

var territory_list: VBoxContainer
var current_filter: String = "all"

func create_territory_list() -> Control:
	territory_list = VBoxContainer.new()
	territory_list.name = "TerritoryList"
	
	refresh_territories()
	return territory_list

func refresh_territories():
	"""Refresh the territory list display"""
	print("TerritoryListManager: Refreshing territory list...")
	_clear_list()
	_populate_territories()

func on_filter_changed(filter_id: String):
	"""Handle filter changes from header"""
	print("TerritoryListManager: Filter changed to: %s" % filter_id)
	current_filter = filter_id
	refresh_territories()

func _clear_list():
	"""Clear existing territory cards"""
	if not territory_list:
		return
	for child in territory_list.get_children():
		child.queue_free()

func _populate_territories():
	"""Populate territory list using TerritoryManager's enhanced method"""
	print("TerritoryListManager: Populating territories...")
	
	# Get territories through TerritoryManager's enhanced method
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	if not territory_manager:
		print("TerritoryListManager: ERROR - TerritoryManager not found")
		return
	
	# Use TerritoryManager's filter method
	var territories_list = territory_manager.get_territories_by_filter(current_filter)
	
	var total_count = 0
	var controlled_count = 0
	
	# Create cards for filtered territories
	for territory_data in territories_list:
		var territory_id = territory_data.get("id", "unknown")
		
		total_count += 1
		
		# Check if controlled
		if territory_manager.is_territory_controlled(territory_id):
			controlled_count += 1
		
		# Create territory card
		var territory_card = _create_territory_card_from_data(territory_id, territory_data)
		territory_list.add_child(territory_card)
	
	print("TerritoryListManager: Created %d territory cards" % total_count)
	
	# Emit refresh signal for header updates
	territories_refreshed.emit(total_count, controlled_count)

func _create_territory_card_from_data(territory_id: String, territory_data: Dictionary) -> Control:
	"""Create enhanced territory card with all rich UI features from old implementation"""
	
	# Build enhanced territory card with full details using static method
	var enhanced_card = TerritoryCardBuilderScript.create_enhanced_territory_card(territory_id, territory_data)
	
	return enhanced_card

func _on_collect_resources(territory_id: String):
	"""Handle collect resources action"""
	print("TerritoryListManager: Collect resources from territory: %s" % territory_id)
	territory_action_requested.emit(territory_id, "collect_resources", {})

func _on_manage_territory(territory_id: String):
	"""Handle manage territory action"""
	print("TerritoryListManager: Manage territory: %s" % territory_id)
	territory_action_requested.emit(territory_id, "manage_gods", {})

func _on_attack_territory(territory_id: String):
	"""Handle attack territory action"""
	print("TerritoryListManager: Attack territory: %s" % territory_id)
	territory_action_requested.emit(territory_id, "attack", {})
