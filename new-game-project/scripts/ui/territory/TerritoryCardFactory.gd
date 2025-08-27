# scripts/ui/territory/TerritoryCardFactory.gd
# Single responsibility: Create territory cards with proper Summoners War styling
class_name TerritoryCardFactory
extends RefCounted

func create_territory_card(territory: Territory) -> Control:
	var card = Panel.new()
	card.name = "TerritoryCard_" + territory.id
	card.custom_minimum_size = Vector2(0, 200)
	
	# Main container
	var main_container = VBoxContainer.new()
	card.add_child(main_container)
	
	# Header with name and element
	var header = _create_card_header(territory)
	main_container.add_child(header)
	
	# Body with stats and actions
	var body = HBoxContainer.new()
	main_container.add_child(body)
	
	# Left side - territory info
	var info_section = _create_info_section(territory)
	body.add_child(info_section)
	
	# Right side - actions
	var actions_section = _create_actions_section(territory)
	body.add_child(actions_section)
	
	# Style the card based on territory status
	_style_card_by_status(card, territory)
	
	return card

func _create_card_header(territory: Territory) -> Control:
	var header = HBoxContainer.new()
	
	# Territory name
	var name_label = Label.new()
	name_label.text = territory.name
	name_label.add_theme_font_size_override("font_size", 18)
	header.add_child(name_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Element badge
	var element_badge = _create_element_badge(territory.element)
	header.add_child(element_badge)
	
	return header

func _create_element_badge(element: Territory.ElementType) -> Control:
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(60, 25)
	
	var label = Label.new()
	label.text = Territory.ElementType.keys()[element].capitalize()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	
	# Color based on element
	var color = _get_element_color(element)
	badge.modulate = color
	
	return badge

func _create_info_section(territory: Territory) -> Control:
	var info = VBoxContainer.new()
	
	# Control status
	var status_label = Label.new()
	if territory.controller == "player":
		status_label.text = "CONTROLLED"
		status_label.modulate = Color.GREEN
	elif territory.required_power <= _get_player_power():
		status_label.text = "AVAILABLE"
		status_label.modulate = Color.YELLOW
	else:
		status_label.text = "LOCKED"
		status_label.modulate = Color.RED
	
	info.add_child(status_label)
	
	# Resource production
	if territory.controller == "player":
		var production_label = Label.new()
		production_label.text = "Produces: %d/hr" % territory.base_resource_rate
		info.add_child(production_label)
	
	return info

func _create_actions_section(territory: Territory) -> Control:
	var actions = VBoxContainer.new()
	
	if territory.controller == "player":
		# Collect resources button
		var collect_btn = Button.new()
		collect_btn.text = "Collect"
		collect_btn.pressed.connect(_on_collect_pressed)
		actions.add_child(collect_btn)
		
		# Manage button
		var manage_btn = Button.new()
		manage_btn.text = "Manage"
		manage_btn.pressed.connect(_on_manage_pressed)
		actions.add_child(manage_btn)
		
		# Store references for signal emission
		collect_btn.set_meta("territory", territory)
		manage_btn.set_meta("territory", territory)
		
	else:
		# Attack button
		var attack_btn = Button.new()
		if territory.required_power <= _get_player_power():
			attack_btn.text = "Attack"
			attack_btn.disabled = false
		else:
			attack_btn.text = "Power: %d" % territory.required_power
			attack_btn.disabled = true
		
		attack_btn.pressed.connect(_on_attack_pressed)
		attack_btn.set_meta("territory", territory)
		actions.add_child(attack_btn)
	
	return actions

func _style_card_by_status(card: Panel, territory: Territory):
	# Add visual styling based on territory status
	if territory.controller == "player":
		card.modulate = Color(0.8, 1.0, 0.8)  # Light green tint
	elif territory.required_power <= _get_player_power():
		card.modulate = Color(1.0, 1.0, 0.8)  # Light yellow tint
	else:
		card.modulate = Color(1.0, 0.8, 0.8)  # Light red tint

func _get_element_color(element: Territory.ElementType) -> Color:
	match element:
		Territory.ElementType.FIRE: return Color.RED
		Territory.ElementType.WATER: return Color.BLUE
		Territory.ElementType.EARTH: return Color(0.8, 0.5, 0.2)
		Territory.ElementType.LIGHTNING: return Color.YELLOW
		Territory.ElementType.LIGHT: return Color.WHITE
		Territory.ElementType.DARK: return Color(0.3, 0.3, 0.3)
		_: return Color.WHITE

func _get_player_power() -> int:
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
	return collection_manager.get_total_player_power()

# Signal handlers that need to be connected to the card
func _on_collect_pressed():
	# This will be handled by the card itself through meta data
	pass

func _on_manage_pressed():
	# This will be handled by the card itself through meta data
	pass

func _on_attack_pressed():
	# This will be handled by the card itself through meta data
	pass
