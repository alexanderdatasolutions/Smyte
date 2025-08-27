# BattleDisplayManager.gd - Manages god/enemy displays in battle
# Single responsibility: Create and update battle unit displays
class_name BattleDisplayManager extends Node

signal displays_created
signal display_updated(unit_id: String)

# Display containers
var god_displays: Dictionary = {}
var enemy_displays: Dictionary = {}
var active_unit_highlight: Control = null

# UI references (will be connected to actual UI nodes)
var player_team_container: Control = null
var enemy_team_container: Control = null

func initialize_containers(player_container: Control, enemy_container: Control):
	"""Set the UI containers for displays"""
	player_team_container = player_container
	enemy_team_container = enemy_container

func create_battle_displays(player_team: Array, enemy_team: Array):
	"""Create displays for all battle units"""
	_create_god_displays(player_team)
	_create_enemy_displays(enemy_team)
	displays_created.emit()

func _create_god_displays(gods: Array):
	"""Create displays for player gods"""
	if not player_team_container:
		push_error("BattleDisplayManager: Player container not set")
		return
		
	# Clear existing displays
	_clear_displays(god_displays, player_team_container)
	
	for god in gods:
		if god is God:
			var display = _create_god_display(god)
			god_displays[god.id] = display
			player_team_container.add_child(display)

func _create_enemy_displays(enemies: Array):
	"""Create displays for enemy units"""
	if not enemy_team_container:
		push_error("BattleDisplayManager: Enemy container not set")
		return
		
	# Clear existing displays
	_clear_displays(enemy_displays, enemy_team_container)
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		var enemy_id = "enemy_" + str(i)
		var display = _create_enemy_display(enemy)
		enemy_displays[enemy_id] = display
		enemy_team_container.add_child(display)

func _create_god_display(god: God) -> Control:
	"""Create display for a god using UICardFactory"""
	var display = UICardFactory.create_god_card(god, UICardFactory.CardStyle.BATTLE_SETUP)
	if display:
		_setup_unit_display(display, god)
	return display

func _create_enemy_display(enemy_data) -> Control:
	"""Create display for an enemy unit"""
	# Create a simple enemy display (fallback if scene doesn't exist)
	var display = Label.new()
	display.text = enemy_data.get("name", "Enemy")
	return display

func _setup_unit_display(display: Control, unit):
	"""Setup common display properties"""
	if not display:
		return
		
	# Add click handling for targeting
	if display.has_signal("clicked"):
		display.clicked.connect(_on_unit_clicked.bind(unit))
	
	# Setup HP bar if available
	if display.has_method("update_hp"):
		_update_display_hp(display, unit)

func _update_display_hp(display: Control, unit):
	"""Update HP display for a unit"""
	if not display or not display.has_method("update_hp"):
		return
		
	var current_hp: int
	var max_hp: int
	
	if unit is God:
		current_hp = unit.current_hp
		max_hp = unit.get_max_hp()
	else:
		# Enemy dictionary
		current_hp = unit.get("current_hp", unit.get("hp", 0))
		max_hp = unit.get("max_hp", unit.get("hp", 100))
	
	display.update_hp(current_hp, max_hp)

func highlight_active_unit(unit):
	"""Highlight the currently active unit"""
	# Remove previous highlight
	if active_unit_highlight:
		active_unit_highlight.modulate = Color.WHITE
	
	# Find and highlight new active unit
	var display = _find_unit_display(unit)
	if display:
		display.modulate = Color.YELLOW  # Highlight color
		active_unit_highlight = display

func update_unit_hp(unit):
	"""Update HP display for a specific unit"""
	var display = _find_unit_display(unit)
	if display:
		_update_display_hp(display, unit)
		display_updated.emit(_get_unit_id(unit))

func _find_unit_display(unit) -> Control:
	"""Find the display for a specific unit"""
	if unit is God:
		return god_displays.get(unit.id, null)
	else:
		# For enemies, search by reference or index
		for enemy_id in enemy_displays:
			var display = enemy_displays[enemy_id]
			if display and display.has_meta("unit_data") and display.get_meta("unit_data") == unit:
				return display
	return null

func _get_unit_id(unit) -> String:
	"""Get ID for a unit"""
	if unit is God:
		return unit.id
	else:
		return "enemy_" + str(unit.get("id", "unknown"))

func _clear_displays(displays: Dictionary, container: Control):
	"""Clear existing displays from container"""
	for display in displays.values():
		if is_instance_valid(display):
			display.queue_free()
	displays.clear()
	
	# Clear container children
	for child in container.get_children():
		child.queue_free()

func _on_unit_clicked(unit):
	"""Handle unit clicked for targeting"""
	print("Unit clicked: ", unit.name if unit is God else unit.get("name", "Unknown"))
