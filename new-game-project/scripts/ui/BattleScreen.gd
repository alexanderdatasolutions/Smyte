# InstantBattleScreen.gd - SNAPPY UI with instant feedback
extends Control

signal back_pressed

# Helper function to safely get stats from both God objects and dictionary enemies
static func _get_stat(unit, stat_name: String, default_value: Variant = 0):
	"""Safely get a stat from either God object or dictionary - UNIFIED APPROACH"""
	if unit is God:
		match stat_name:
			"name": return unit.name
			"hp", "current_hp": return unit.current_hp
			"max_hp": return unit.get_max_hp()
			_: return default_value
	elif stat_name == "current_hp":
		# UNIFIED: Always use current_hp for enemies
		return unit.get("current_hp", unit.get("hp", default_value))
	elif stat_name == "max_hp" and not unit.has("max_hp"):
		# For enemies, max HP is stored as "hp"
		return unit.get("hp", default_value)
	elif unit.has(stat_name):
		return unit[stat_name]
	elif unit.has("get") and unit.has_method("get"):
		return unit.get(stat_name, default_value)
	else:
		return default_value

# UI References
@onready var battle_title_label = $MainContainer/HeaderContainer/BattleTitleLabel
@onready var player_team_container = $MainContainer/BattleArenaContainer/PlayerTeamSide/PlayerTeamContainer
@onready var enemy_team_container = $MainContainer/BattleArenaContainer/EnemyTeamSide/EnemyTeamContainer
@onready var turn_indicator = $MainContainer/BattleArenaContainer/BattleCenter/TurnIndicator
@onready var action_label = $MainContainer/BattleArenaContainer/BattleCenter/ActionDisplay/ActionLabel
@onready var battle_status_label = $MainContainer/BottomContainer/BattleStatusLabel
@onready var back_button = $MainContainer/BottomContainer/ButtonContainer/BackButton

# Auto-battle and speed control UI (from scene)
@onready var auto_battle_button = $MainContainer/BottomContainer/ButtonContainer/AutoButton
@onready var speed_1x_button = $MainContainer/BottomContainer/ButtonContainer/SpeedControlContainer/Speed1xButton
@onready var speed_2x_button = $MainContainer/BottomContainer/ButtonContainer/SpeedControlContainer/Speed2xButton
@onready var speed_3x_button = $MainContainer/BottomContainer/ButtonContainer/SpeedControlContainer/Speed3xButton

# Battle Log
var battle_log_panel: PanelContainer = null
var battle_log_scroll: ScrollContainer = null
var battle_log_text: RichTextLabel = null
var battle_log_lines: Array[String] = []
var max_log_lines: int = 50

# Battle data
var selected_gods: Array = []
var current_territory: Territory = null
var current_battle_stage: int = 1

# Current action state
var current_god: God = null
var selected_ability: Dictionary = {}
var waiting_for_target: bool = false

# Display tracking
var god_displays: Dictionary = {}
var enemy_displays: Dictionary = {}

# Action buttons
var action_buttons_container: HBoxContainer = null

# Tooltip system
var ability_tooltip: PanelContainer = null
var tooltip_label: RichTextLabel = null
var tooltip_timer: Timer = null
var current_tooltip_button: Button = null

func _ready():
	_setup_ui()
	_connect_battle_system()

func _setup_ui():
	"""Setup UI - no timers, no complexity"""
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Connect existing auto-battle and speed control buttons
	_connect_auto_battle_buttons()
	
	# Create action buttons container
	var bottom_container = $MainContainer/BottomContainer/ButtonContainer
	if bottom_container:
		action_buttons_container = HBoxContainer.new()
		action_buttons_container.add_theme_constant_override("separation", 10)
		action_buttons_container.visible = false
		bottom_container.add_child(action_buttons_container)
	
	# Create ability tooltip
	_create_ability_tooltip()
	
	# Create battle log
	_create_battle_log()

func _create_ability_tooltip():
	"""Create floating tooltip for abilities"""
	ability_tooltip = PanelContainer.new()
	ability_tooltip.visible = false
	ability_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_tooltip.z_index = 100
	
	# Style the tooltip panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.9, 1.0)
	ability_tooltip.add_theme_stylebox_override("panel", style)
	
	# Create tooltip content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	ability_tooltip.add_child(margin)
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.fit_content = true
	tooltip_label.custom_minimum_size = Vector2(250, 0)
	tooltip_label.bbcode_enabled = true
	tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	tooltip_label.add_theme_color_override("default_color", Color.WHITE)
	margin.add_child(tooltip_label)
	
	# Create timer for delayed hiding
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 0.1
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_delayed_hide_tooltip)
	add_child(tooltip_timer)
	
	# Add to main UI
	add_child(ability_tooltip)

func _create_battle_log():
	"""Create a battle log display"""
	# Find a good place to put the battle log - next to the battle arena
	var main_container = $MainContainer
	var battle_arena = $MainContainer/BattleArenaContainer
	
	# Create battle log panel
	battle_log_panel = PanelContainer.new()
	battle_log_panel.custom_minimum_size = Vector2(250, 200)
	battle_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	battle_log_panel.add_theme_stylebox_override("panel", style)
	
	# Create scroll container
	battle_log_scroll = ScrollContainer.new()
	battle_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_panel.add_child(battle_log_scroll)
	
	# Create text display
	battle_log_text = RichTextLabel.new()
	battle_log_text.bbcode_enabled = true
	battle_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_text.add_theme_font_size_override("normal_font_size", 12)
	battle_log_text.add_theme_color_override("default_color", Color.WHITE)
	battle_log_scroll.add_child(battle_log_text)
	
	# Add to the battle arena as a side panel
	if battle_arena and battle_arena is HBoxContainer:
		battle_arena.add_child(battle_log_panel)
	elif main_container:
		# Fallback - add to main container
		main_container.add_child(battle_log_panel)
	
	# Initialize with welcome message
	_add_battle_log_line("[color=yellow]Battle begins![/color]")

func _connect_auto_battle_buttons():
	"""Connect existing auto-battle and speed control buttons from the scene"""
	# Connect auto-battle toggle
	if auto_battle_button:
		auto_battle_button.pressed.connect(_on_auto_battle_pressed)
	
	# Connect speed control buttons
	if speed_1x_button:
		speed_1x_button.pressed.connect(_on_speed_1x_pressed)
	if speed_2x_button:
		speed_2x_button.pressed.connect(_on_speed_2x_pressed)
	if speed_3x_button:
		speed_3x_button.pressed.connect(_on_speed_3x_pressed)

func _add_battle_log_line(message: String):
	"""Add a line to the battle log"""
	if not battle_log_text:
		return
	
	# Add to lines array
	battle_log_lines.append(message)
	
	# Limit number of lines
	if battle_log_lines.size() > max_log_lines:
		battle_log_lines.pop_front()
	
	# Update display
	var full_text = ""
	for line in battle_log_lines:
		full_text += line + "\n"
	
	battle_log_text.text = full_text
	
	# Auto-scroll to bottom
	if battle_log_scroll:
		await get_tree().process_frame
		battle_log_scroll.scroll_vertical = int(battle_log_scroll.get_v_scroll_bar().max_value)

func _on_battle_log_updated(message: String):
	"""Handle battle log updates from battle system - now uses both old and new display"""
	print("Battle: %s" % message)
	
	# Update action label (old system)
	if action_label:
		action_label.text = message
	
	# Add to battle log (new system)
	_add_battle_log_line(message)

func _connect_battle_system():
	"""Connect to instant battle system"""
	print("=== BattleScreen: Connecting to battle system ===")
	if GameManager and GameManager.battle_system:
		print("=== BattleScreen: Found battle system, connecting ===")
		var bs = GameManager.battle_system
		
		# Only connect signals if not already connected
		if not bs.battle_completed.is_connected(_on_battle_completed):
			bs.battle_completed.connect(_on_battle_completed)
		if not bs.battle_log_updated.is_connected(_on_battle_log_updated):
			bs.battle_log_updated.connect(_on_battle_log_updated)
		
		# Always set battle screen reference (it's just a variable assignment)
		bs.battle_screen = self
		print("=== BattleScreen: Set battle_screen reference ===")
	else:
		print("ERROR: BattleScreen: GameManager or battle_system not found!")

func setup_territory_stage_battle(territory: Territory, stage: int, battle_gods: Array):
	"""Setup battle instantly"""
	print("Setting up instant battle: %s Stage %d" % [territory.name, stage])
	
	# Ensure connection is established
	_connect_battle_system()
	
	# Reset auto-battle when entering a new territory (but keep it for same territory stage progression)
	var is_new_territory = (current_territory != territory)
	
	current_territory = territory
	current_battle_stage = stage
	selected_gods = battle_gods.duplicate()
	
	# Reset auto-battle for new territories (but keep it for same territory stage progression)
	if GameManager.battle_system and is_new_territory:
		GameManager.battle_system.auto_battle_enabled = false
	
	# Update header
	if battle_title_label:
		battle_title_label.text = "%s - Stage %d" % [territory.name, stage]
	
	# Create displays immediately
	_create_god_displays()
	_create_enemy_displays()
	
	# Update auto-battle button state
	_update_auto_battle_button()
	
	# Update speed button state
	_update_speed_buttons()
	
	# Start battle immediately - no delays
	GameManager.battle_system.start_territory_assault(selected_gods, current_territory, current_battle_stage)

func _create_god_displays():
	"""Create god displays instantly"""
	# Clear existing
	if player_team_container:
		for child in player_team_container.get_children():
			child.queue_free()
	god_displays.clear()
	
	# Create new displays
	for god in selected_gods:
		var display = _create_god_display(god)
		player_team_container.add_child(display)
		god_displays[god.id] = display

func _create_enemy_displays():
	"""Create enemy displays instantly"""
	# Wait one frame for battle system to create enemies
	await get_tree().process_frame
	
	if not GameManager.battle_system:
		return
	
	var enemies = GameManager.battle_system.current_battle_enemies
	
	# Clear existing
	if enemy_team_container:
		for child in enemy_team_container.get_children():
			child.queue_free()
	enemy_displays.clear()
	
	# Create displays
	for i in range(enemies.size()):
		var enemy = enemies[i]
		var display = _create_enemy_display(enemy, i)
		enemy_team_container.add_child(display)
		enemy_displays[i] = display

func _create_god_display(god: God) -> Control:
	"""Create enhanced god display matching enemy style"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(150, 100)
	
	# Main clickable button - same style as enemies but blue
	var main_button = Button.new()
	main_button.custom_minimum_size = Vector2(150, 100)
	main_button.disabled = true  # Gods aren't clickable targets
	
	# Style the button like god panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0.4, 0.8, 0.8)  # Blue for gods
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.8, 1.0, 1.0)  # Light blue border
	main_button.add_theme_stylebox_override("normal", style)
	main_button.add_theme_stylebox_override("disabled", style)  # Same style when disabled
	
	container.add_child(main_button)
	
	# Content inside the button
	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_button.add_child(content)
	
	# Name with god indicator
	var name_label = Label.new()
	name_label.text = "⚡ %s" % god.name  # Lightning bolt for gods
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	
	# HP with color coding based on percentage
	var hp_label = Label.new()
	var current_hp = _get_stat(god, "hp", 0)
	var max_hp = _get_stat(god, "max_hp", 100)
	var hp_percentage = float(current_hp) / float(max_hp)
	var hp_color = Color.GREEN
	if hp_percentage < 0.75:
		hp_color = Color.YELLOW
	if hp_percentage < 0.5:
		hp_color = Color.ORANGE
	if hp_percentage < 0.25:
		hp_color = Color.RED
	if current_hp <= 0:
		hp_color = Color.DARK_RED
	
	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", hp_color)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hp_label)
	
	# Level with element color
	var level_label = Label.new()
	var element_string = DataLoader.element_int_to_string(god.element) if god.element != null else "fire"
	var element_color = _get_element_color_for_battle(element_string.to_lower())
	level_label.text = "Lv.%d" % god.level
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.add_theme_color_override("font_color", element_color)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(level_label)
	
	return container

func _create_enemy_display(enemy: Dictionary, _index: int) -> Control:
	"""Create enemy display with BIG, EASY-TO-CLICK buttons"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(150, 100)
	
	# Main clickable button - THIS IS THE WHOLE THING
	var main_button = Button.new()
	main_button.custom_minimum_size = Vector2(150, 100)
	main_button.pressed.connect(_on_enemy_clicked_instantly.bind(enemy))
	
	# Style the button to look like an enemy panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.2, 0, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.4, 0, 1.0)
	main_button.add_theme_stylebox_override("normal", style)
	
	# Hover effect
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.8, 0.3, 0, 0.9)
	hover_style.border_color = Color.YELLOW
	main_button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed effect
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.9, 0.4, 0, 1.0)
	main_button.add_theme_stylebox_override("pressed", pressed_style)
	
	container.add_child(main_button)
	
	# Content inside the button
	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to button
	main_button.add_child(content)
	
	# Name with type indicator
	var name_label = Label.new()
	var type_icon = _get_enemy_type_icon(enemy.get("type", "basic"))
	name_label.text = "%s %s" % [type_icon, _get_stat(enemy, "name", "Unknown")]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	
	# HP with color coding based on percentage
	var hp_label = Label.new()
	var current_hp = _get_stat(enemy, "hp", 0)
	var max_hp = _get_stat(enemy, "max_hp", _get_stat(enemy, "hp", 100))  # For enemies, max_hp might be stored as just 'hp'
	var hp_percentage = float(current_hp) / float(max_hp)
	var hp_color = Color.GREEN
	if hp_percentage < 0.75:
		hp_color = Color.YELLOW
	if hp_percentage < 0.5:
		hp_color = Color.ORANGE
	if hp_percentage < 0.25:
		hp_color = Color.RED
	
	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", hp_color)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hp_label)
	
	# Level with element color
	var level_label = Label.new()
	var element_color = _get_element_color_for_battle(enemy.get("element", ""))
	level_label.text = "Lv.%d" % enemy.level
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.add_theme_color_override("font_color", element_color)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(level_label)
	
	return container

func _get_enemy_type_icon(enemy_type: String) -> String:
	"""Get icon/symbol for enemy type"""
	match enemy_type:
		"boss":
			return "👑"  # Crown for boss
		"elite":
			return "⚡"  # Lightning for elite
		"leader":
			return "🛡️"  # Shield for leader
		_:
			return "⚔️"  # Sword for basic

func _get_element_color_for_battle(element: String) -> Color:
	"""Get color for element display in battle"""
	match element.to_lower():
		"fire":
			return Color.ORANGE_RED
		"water":
			return Color.CYAN
		"earth":
			return Color.YELLOW_GREEN
		"lightning":
			return Color.LIGHT_YELLOW
		"light":
			return Color.WHITE
		"dark":
			return Color.PURPLE
		_:
			return Color.LIGHT_GRAY

func show_god_turn_ui(god: God):
	"""Show action buttons for god's turn - called by battle system"""
	
	# Clear previous god's state and set new current god
	current_god = god
	waiting_for_target = false
	selected_ability = {}
	
	# Update turn indicator
	if turn_indicator:
		turn_indicator.text = "%s's Turn" % god.name
		turn_indicator.modulate = Color.CYAN
	
	if battle_status_label:
		battle_status_label.text = "%s - Choose action!" % god.name
		battle_status_label.modulate = Color.WHITE
	
	# Clear any previous enemy highlighting
	_clear_enemy_highlighting()
	
	# Show action buttons instantly
	_show_action_buttons(god)

func _show_action_buttons(god: God):
	"""Show action buttons instantly"""
	print("=== BattleScreen: _show_action_buttons called for %s ===" % god.name)
	print("=== BattleScreen: action_buttons_container = %s ===" % action_buttons_container)
	
	if not action_buttons_container:
		print("ERROR: action_buttons_container is null!")
		return
	
	# Clear existing buttons
	print("=== BattleScreen: Clearing %d existing buttons ===" % action_buttons_container.get_child_count())
	for child in action_buttons_container.get_children():
		action_buttons_container.remove_child(child)
		child.queue_free()
	
	# Basic Attack button
	print("=== BattleScreen: Creating attack button ===")
	var attack_btn = Button.new()
	attack_btn.text = "⚔️ Attack"
	attack_btn.custom_minimum_size = Vector2(80, 35)
	attack_btn.pressed.connect(_on_attack_button_pressed)
	
	# Add hover tooltip for basic attack
	attack_btn.mouse_entered.connect(_show_basic_attack_tooltip.bind(attack_btn))
	attack_btn.mouse_exited.connect(_start_hide_tooltip_timer.bind(attack_btn))
	
	action_buttons_container.add_child(attack_btn)
	print("=== BattleScreen: Added attack button ===")
	
	# Ability buttons from JSON
	if god.active_abilities and god.active_abilities.size() > 0:
		print("=== BattleScreen: Creating %d ability buttons ===" % god.active_abilities.size())
		for ability in god.active_abilities:
			print("=== BattleScreen: Creating ability button: %s ===" % ability.get("name", "Ability"))
			var ability_btn = Button.new()
			ability_btn.text = ability.get("name", "Ability")
			ability_btn.custom_minimum_size = Vector2(80, 35)
			ability_btn.pressed.connect(_on_ability_pressed.bind(ability))
			
			# Add hover tooltip for ability
			ability_btn.mouse_entered.connect(_show_ability_tooltip.bind(ability_btn, ability))
			ability_btn.mouse_exited.connect(_start_hide_tooltip_timer.bind(ability_btn))
			
			action_buttons_container.add_child(ability_btn)
			print("=== BattleScreen: Added ability button: %s ===" % ability.get("name", "Ability"))
	else:
		print("=== BattleScreen: God has no active abilities ===")
	
	# Make visible
	print("=== BattleScreen: Setting action_buttons_container visible = true ===")
	action_buttons_container.visible = true
	print("=== BattleScreen: action_buttons_container.visible = %s ===" % action_buttons_container.visible)
	print("=== BattleScreen: Total buttons created: %d ===" % action_buttons_container.get_child_count())

func end_god_turn_ui():
	"""Called by BattleManager when a god's turn officially ends"""
	print("=== BattleScreen: end_god_turn_ui called ===")
	
	# Clear all god turn state
	current_god = null
	selected_ability = {}
	waiting_for_target = false
	
	# Hide action buttons
	_hide_action_buttons()
	
	# Clear any highlights
	_clear_enemy_highlighting()
	_remove_ally_highlights()
	
	# Clear status text
	if battle_status_label:
		battle_status_label.text = ""

func _on_attack_button_pressed():
	"""Basic attack selected - wait for target"""
	print("Attack button pressed!")
	
	# If auto-battle is on, turn it off and take manual control
	if GameManager.battle_system and GameManager.battle_system.auto_battle_enabled:
		print("Player taking manual control - disabling auto-battle")
		GameManager.battle_system.auto_battle_enabled = false
		_update_auto_battle_button()
	
	selected_ability = {"id": "basic_attack", "name": "Basic Attack", "damage_multiplier": 1.0}
	waiting_for_target = true
	
	if battle_status_label:
		battle_status_label.text = "Click enemy to attack!"
	
	_highlight_enemies()

func _on_ability_pressed(ability: Dictionary):
	"""Handle ability button press with proper targeting"""
	print("Ability pressed: %s" % ability.get("name", "Unknown"))
	
	# If auto-battle is on, turn it off and take manual control
	if GameManager.battle_system and GameManager.battle_system.auto_battle_enabled:
		print("Player taking manual control - disabling auto-battle")
		GameManager.battle_system.auto_battle_enabled = false
		_update_auto_battle_button()
	
	selected_ability = ability
	
	var targets = ability.get("targets", "single")
	var damage_type = ability.get("damage_type", "magical_damage")
	
	# Check if this ability should execute immediately (no target selection needed)
	match targets:
		"all_enemies":
			# Execute immediately - targets all enemies
			if battle_status_label:
				battle_status_label.text = "Targeting all enemies!"
			_execute_selected_ability_on_all_enemies()
			return
		"all_allies":
			# Execute immediately - targets all allies
			if battle_status_label:
				battle_status_label.text = "Targeting all allies!"
			_execute_selected_ability_on_all_allies()
			return
	
	# For abilities that need target selection
	waiting_for_target = true
	
	# Determine what to highlight based on ability
	match targets:
		"single":
			# Single target - could be enemy or ally depending on ability type
			if damage_type == "healing" or damage_type == "none":
				_highlight_targeting_options(ability)
			else:
				_highlight_enemies()
		"multiple":
			# Multiple target - highlight all enemies, executes on first click
			if battle_status_label:
				battle_status_label.text = "Will hit multiple enemies - Click any enemy to execute!"
			_highlight_enemies()
		"lowest_hp_ally":
			if battle_status_label:
				battle_status_label.text = "Will target lowest HP ally - Click any ally to confirm!"
			_highlight_allies()
		_:
			_highlight_enemies()

func _execute_selected_ability_on_all_enemies():
	"""Execute the selected ability on all enemies"""
	if not current_god or not selected_ability:
		return
	
	# Create action dictionary for BattleManager
	var action = {
		"action": "ability",
		"ability": selected_ability,
		"target": null  # null target means all enemies for AOE abilities
	}
	
	# Process the action through BattleManager
	GameManager.battle_system.process_god_action(current_god, action)
	
	# Clean up targeting state (but keep action buttons visible)
	_clear_targeting_state()

func _execute_selected_ability_on_all_allies():
	"""Execute the selected ability on all allies"""
	if not current_god or not selected_ability:
		return
	
	# Create action dictionary for BattleManager
	var action = {
		"action": "ability",
		"ability": selected_ability,
		"target": null  # null target means all allies for AOE abilities
	}
	
	# Process the action through BattleManager
	GameManager.battle_system.process_god_action(current_god, action)
	
	# Clean up targeting state (but keep action buttons visible)
	_clear_targeting_state()

func _highlight_targeting_options(ability: Dictionary):
	"""Highlight both allies and enemies for flexible targeting"""
	var damage_type = ability.get("damage_type", "magical_damage")
	
	if damage_type == "healing":
		if battle_status_label:
			battle_status_label.text = "Select ally to heal with %s!" % ability.get("name", "ability")
		_highlight_allies()
	elif damage_type == "none":
		# Utility ability - could target allies or enemies
		var status_effects = ability.get("status_effects", [])
		var is_beneficial = false
		for effect in status_effects:
			if effect in ["attack_boost", "defense_boost", "speed_boost", "shield", "regeneration", "debuff_immunity"]:
				is_beneficial = true
				break
		
		if is_beneficial:
			if battle_status_label:
				battle_status_label.text = "Select ally to buff with %s!" % ability.get("name", "ability")
			_highlight_allies()
		else:
			if battle_status_label:
				battle_status_label.text = "Select target for %s!" % ability.get("name", "ability")
			_highlight_enemies()
	else:
		if battle_status_label:
			battle_status_label.text = "Select enemy for %s!" % ability.get("name", "ability")
		_highlight_enemies()

func _highlight_allies():
	"""Highlight allies for targeting"""
	for god_id in god_displays:
		var display = god_displays[god_id]
		var main_button = display.get_child(0)  # The main button
		
		# Create highlighted style for allies (green)
		var highlight_style = StyleBoxFlat.new()
		highlight_style.bg_color = Color(0, 0.8, 0.2, 0.9)  # Bright green
		highlight_style.corner_radius_top_left = 8
		highlight_style.corner_radius_bottom_left = 8
		highlight_style.corner_radius_top_right = 8
		highlight_style.corner_radius_bottom_right = 8
		highlight_style.border_width_left = 4
		highlight_style.border_width_right = 4
		highlight_style.border_width_top = 4
		highlight_style.border_width_bottom = 4
		highlight_style.border_color = Color(0.4, 1.0, 0.6, 1.0)  # Light green border
		
		main_button.add_theme_stylebox_override("normal", highlight_style)
		main_button.add_theme_stylebox_override("disabled", highlight_style)
		main_button.disabled = false  # Enable clicking on allies
		
		# Connect or reconnect the button
		if not main_button.pressed.is_connected(_on_ally_target_selected):
			main_button.pressed.connect(_on_ally_target_selected.bind(god_id))

func _on_ally_target_selected(god_id: String):
	"""Handle ally being selected as target"""
	if not waiting_for_target or not selected_ability:
		return
	
	# Find the god
	var target_god = null
	for god in selected_gods:
		if god.id == god_id:
			target_god = god
			break
	
	if not target_god:
		return
	
	print("Selected ally target: %s" % target_god.name)
	
	# Execute ability on ally
	var action = {
		"action": "ability",
		"ability": selected_ability,
		"target": target_god  # Single target for abilities
	}
	
	# Process the action through BattleManager
	GameManager.battle_system.process_god_action(current_god, action)
	
	# Clean up
	_clear_targeting_state()

func _clear_targeting_state():
	"""Clear targeting UI state"""
	print("=== BattleScreen: _clear_targeting_state called ===")
	waiting_for_target = false
	selected_ability = {}
	# DON'T clear current_god - it should remain set during the god's turn
	# current_god = null  # <-- This was causing the issue!
	
	# Remove highlights from enemies
	_remove_enemy_highlights()
	# Remove highlights from allies  
	_remove_ally_highlights()
	
	# DON'T hide action buttons during a god's turn
	# Hide action buttons ONLY if no god is currently acting
	if not current_god:
		if action_buttons_container:
			print("=== BattleScreen: _clear_targeting_state hiding action buttons (no current god) ===")
			action_buttons_container.visible = false
	
	# Clear status text
	if battle_status_label:
		battle_status_label.text = ""

func _remove_ally_highlights():
	"""Remove highlights from ally displays"""
	for god_id in god_displays:
		var display = god_displays[god_id]
		var main_button = display.get_child(0)
		
		# Restore original style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0.4, 0.8, 0.8)  # Blue for gods
		style.corner_radius_top_left = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.8, 1.0, 1.0)  # Light blue border
		main_button.add_theme_stylebox_override("normal", style)
		main_button.add_theme_stylebox_override("disabled", style)
		
		# Disable clicking on allies again
		main_button.disabled = true
		
		# Disconnect ally targeting signal if connected
		if main_button.pressed.is_connected(_on_ally_target_selected):
			main_button.pressed.disconnect(_on_ally_target_selected)

func _remove_enemy_highlights():
	"""Remove highlights from enemy displays - matching existing pattern"""
	for i in enemy_displays:
		var display = enemy_displays[i]
		var main_button = display.get_child(0)  # The main button
		
		# Create normal style
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.8, 0, 0, 0.8)  # Red for enemies
		normal_style.corner_radius_top_left = 8
		normal_style.corner_radius_bottom_left = 8
		normal_style.corner_radius_top_right = 8
		normal_style.corner_radius_bottom_right = 8
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(1.0, 0.4, 0.4, 1.0)  # Light red border
		
		main_button.add_theme_stylebox_override("normal", normal_style)
		main_button.add_theme_stylebox_override("hover", normal_style)

func _highlight_enemies():
	"""Visual feedback for targetable enemies - highlight the main buttons"""
	for i in enemy_displays:
		var display = enemy_displays[i]
		var main_button = display.get_child(0)  # The main button
		
		# Create highlighted style
		var highlight_style = StyleBoxFlat.new()
		highlight_style.bg_color = Color(1.0, 0.6, 0, 0.9)  # Bright orange
		highlight_style.corner_radius_top_left = 8
		highlight_style.corner_radius_bottom_left = 8
		highlight_style.corner_radius_top_right = 8
		highlight_style.corner_radius_bottom_right = 8
		highlight_style.border_width_left = 4
		highlight_style.border_width_right = 4
		highlight_style.border_width_top = 4
		highlight_style.border_width_bottom = 4
		highlight_style.border_color = Color.YELLOW
		
		main_button.add_theme_stylebox_override("normal", highlight_style)
		
		# Also update hover to be even more obvious
		var hover_highlight = highlight_style.duplicate()
		hover_highlight.bg_color = Color.YELLOW
		hover_highlight.border_color = Color.WHITE
		main_button.add_theme_stylebox_override("hover", hover_highlight)

func _clear_enemy_highlighting():
	"""Remove highlighting from all enemy buttons"""
	for i in enemy_displays:
		var display = enemy_displays[i]
		var main_button = display.get_child(0)  # The main button
		
		# Restore normal enemy button styling
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.6, 0.2, 0, 0.8)
		normal_style.corner_radius_top_left = 8
		normal_style.corner_radius_bottom_left = 8
		normal_style.corner_radius_top_right = 8
		normal_style.corner_radius_bottom_right = 8
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.8, 0.4, 0, 1.0)
		main_button.add_theme_stylebox_override("normal", normal_style)
		
		# Restore normal hover
		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.8, 0.3, 0, 0.9)
		hover_style.border_color = Color.YELLOW
		main_button.add_theme_stylebox_override("hover", hover_style)

func _on_enemy_clicked_instantly(enemy: Dictionary):
	"""Enemy clicked - execute action INSTANTLY"""
	if not waiting_for_target or not current_god or selected_ability.is_empty():
		print("Not ready for enemy click - waiting:%s god:%s ability:%s" % [waiting_for_target, current_god != null, !selected_ability.is_empty()])
		return
	
	if _get_stat(enemy, "hp", 0) <= 0:
		print("Enemy already dead!")
		return
	
	print("INSTANT ATTACK: %s using %s on %s" % [
		current_god.name, 
		selected_ability.get("name", "Attack"), 
		_get_stat(enemy, "name", "Enemy")
	])
	
	# Remove enemy highlighting first
	_clear_enemy_highlighting()
	
	# Store action details but DON'T clear current_god yet
	var acting_god = current_god
	var ability = selected_ability
	
	# Clear only the targeting state (not current_god)
	selected_ability = {}
	waiting_for_target = false
	
	# Execute action through BattleManager
	if ability.get("id") == "basic_attack":
		# Basic attack action
		var action = {
			"action": "attack",
			"target": enemy
		}
		GameManager.battle_system.process_god_action(acting_god, action)
	else:
		# Ability action  
		var action = {
			"action": "ability",
			"ability": ability,
			"target": enemy
		}
		GameManager.battle_system.process_god_action(acting_god, action)

func _hide_action_buttons():
	"""Hide action buttons"""
	print("=== BattleScreen: _hide_action_buttons called ===")
	if action_buttons_container:
		print("=== BattleScreen: Hiding action_buttons_container ===")
		action_buttons_container.visible = false
	# Also hide tooltip when buttons are hidden
	_hide_tooltip()

func _show_basic_attack_tooltip(button: Button):
	"""Show tooltip for basic attack"""
	if not ability_tooltip or not tooltip_label:
		return
	
	# Cancel any pending hide
	if tooltip_timer:
		tooltip_timer.stop()
	
	current_tooltip_button = button
	
	var tooltip_content = "[b]⚔️ Basic Attack[/b]\n"
	tooltip_content += "[color=gray]Deal physical damage to target enemy[/color]\n"
	tooltip_content += "[color=yellow]Damage: 100% of Attack[/color]\n"
	tooltip_content += "[color=green]Cost: None[/color]"
	
	tooltip_label.text = tooltip_content
	_position_tooltip(button)
	ability_tooltip.visible = true

func _show_ability_tooltip(button: Button, ability: Dictionary):
	"""Show tooltip for ability with detailed information"""
	if not ability_tooltip or not tooltip_label:
		return
	
	# Cancel any pending hide
	if tooltip_timer:
		tooltip_timer.stop()
	
	current_tooltip_button = button
	
	var tooltip_content = "[b]%s[/b]\n" % ability.get("name", "Ability")
	tooltip_content += "[color=gray]%s[/color]\n\n" % ability.get("description", "No description available")
	
	# Damage or healing information
	var damage_mult = ability.get("damage_multiplier", 0.0)
	var healing_mult = ability.get("healing_multiplier", 0.0)
	var damage_type = ability.get("damage_type", "magical_damage")
	
	if healing_mult > 0:
		tooltip_content += "[color=green]Healing: %.0f%% of Attack[/color]\n" % (healing_mult * 100)
	elif damage_mult > 0:
		tooltip_content += "[color=yellow]Damage: %.0f%% of Attack[/color]\n" % (damage_mult * 100)
	elif damage_type == "none":
		tooltip_content += "[color=cyan]Utility Ability[/color]\n"
	
	# Target information
	var targets = ability.get("targets", "single")
	match targets:
		"single":
			if damage_type == "healing":
				tooltip_content += "[color=cyan]Target: Single Ally[/color]\n"
			else:
				tooltip_content += "[color=cyan]Target: Single Enemy[/color]\n"
		"multiple":
			tooltip_content += "[color=cyan]Target: Multiple Enemies[/color]\n"
		"all_enemies":
			tooltip_content += "[color=cyan]Target: All Enemies[/color]\n"
		"all_allies":
			tooltip_content += "[color=cyan]Target: All Allies[/color]\n"
		"lowest_hp_ally":
			tooltip_content += "[color=cyan]Target: Most Injured Ally[/color]\n"
	
	# Status effects
	var status_effects = ability.get("status_effects", [])
	if status_effects.size() > 0:
		tooltip_content += "[color=orange]Effects: %s[/color]\n" % ", ".join(status_effects)
	
	# Special effects
	var special_effects = ability.get("special_effects", [])
	if special_effects.size() > 0:
		tooltip_content += "[color=purple]Special: %s[/color]\n" % ", ".join(special_effects)
	
	# Cooldown
	var cooldown = ability.get("cooldown", 0)
	if cooldown > 0:
		tooltip_content += "[color=red]Cooldown: %d turns[/color]" % cooldown
	else:
		tooltip_content += "[color=green]Cooldown: None[/color]"
	
	tooltip_label.text = tooltip_content
	_position_tooltip(button)
	ability_tooltip.visible = true

func _start_hide_tooltip_timer(button: Button):
	"""Start timer to hide tooltip with delay"""
	if current_tooltip_button == button and tooltip_timer:
		tooltip_timer.start()

func _delayed_hide_tooltip():
	"""Hide tooltip after delay"""
	if ability_tooltip:
		ability_tooltip.visible = false
	current_tooltip_button = null

func _position_tooltip(button: Button):
	"""Position tooltip relative to button"""
	if not ability_tooltip or not button:
		return
	
	# Wait a frame to ensure tooltip content is rendered
	await get_tree().process_frame
	
	# Get button's global position and size
	var button_rect = button.get_global_rect()
	var tooltip_size = ability_tooltip.get_size()
	
	# Position tooltip above button, centered horizontally
	var tooltip_pos = Vector2()
	tooltip_pos.x = button_rect.position.x + (button_rect.size.x / 2) - (tooltip_size.x / 2)
	tooltip_pos.y = button_rect.position.y - tooltip_size.y - 10  # Above button with some padding
	
	# Keep tooltip on screen
	var screen_size = get_viewport().get_visible_rect().size
	if tooltip_pos.x < 10:
		tooltip_pos.x = 10
	elif tooltip_pos.x + tooltip_size.x > screen_size.x - 10:
		tooltip_pos.x = screen_size.x - tooltip_size.x - 10
	
	if tooltip_pos.y < 10:
		tooltip_pos.y = button_rect.position.y + button_rect.size.y + 10  # Below button instead
	
	ability_tooltip.position = tooltip_pos

func _hide_tooltip():
	"""Hide ability tooltip immediately"""
	if ability_tooltip:
		ability_tooltip.visible = false
	if tooltip_timer:
		tooltip_timer.stop()
	current_tooltip_button = null

func update_god_hp_instantly(god: God):
	"""Update god HP display INSTANTLY with new enhanced structure"""
	if god_displays.has(god.id):
		var display = god_displays[god.id]
		var main_button = display.get_child(0)  # The main button
		var content = main_button.get_child(0)  # The content VBox
		var hp_label = content.get_child(1)  # HP label (name=0, hp=1, level=2)
		
		# Calculate HP percentage and color
		var current_hp = _get_stat(god, "hp", 0)
		var max_hp = _get_stat(god, "max_hp", 100)
		var hp_percentage = float(current_hp) / float(max_hp)
		var hp_color = Color.GREEN
		if hp_percentage < 0.75:
			hp_color = Color.YELLOW
		if hp_percentage < 0.5:
			hp_color = Color.ORANGE
		if hp_percentage < 0.25:
			hp_color = Color.RED
		if current_hp <= 0:
			hp_color = Color.DARK_RED
		
		# Update HP text and color
		hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
		hp_label.add_theme_color_override("font_color", hp_color)
		
		print("Updated god %s HP display: %s" % [god.name, hp_label.text])
	else:
		print("No display found for god %s" % god.name)

func update_enemy_hp_instantly(enemy: Dictionary):
	"""Update enemy HP display INSTANTLY - UNIFIED APPROACH"""
	var current_hp = _get_stat(enemy, "current_hp", 0)
	var max_hp = _get_stat(enemy, "max_hp", 100)
	print("Updating enemy HP: %s - %d/%d" % [_get_stat(enemy, "name", "Unknown"), current_hp, max_hp])
	
	# Find the correct enemy by matching the exact enemy reference in battle system
	if not GameManager.battle_system:
		print("No battle system found!")
		return
	
	var battle_enemies = GameManager.battle_system.current_battle_enemies
	var enemy_index = -1
	
	# Find which index this enemy is in the battle system array
	# Check if enemy has a unique battle_index property we can use
	if enemy.has("battle_index"):
		enemy_index = enemy.battle_index
		print("Using enemy battle_index: %d" % enemy_index)
	else:
		# Fallback to reference comparison
		for i in range(battle_enemies.size()):
			if battle_enemies[i] == enemy:  # Direct reference comparison
				enemy_index = i
				break
		print("Found enemy at index %d via reference comparison" % enemy_index)
	
	if enemy_index == -1:
		print("Could not find enemy in battle system array!")
		print("Battle enemies: %s" % battle_enemies.map(func(e): return "%s(%d/%d)" % [_get_stat(e, "name", "Unknown"), _get_stat(e, "current_hp", 0), _get_stat(e, "max_hp", 100)]))
		return
	
	# Update the display for this specific enemy index
	if enemy_displays.has(enemy_index):
		var display = enemy_displays[enemy_index]
		var main_button = display.get_child(0)  # The main button
		var content = main_button.get_child(0)  # The content VBox
		var hp_label = content.get_child(1)  # HP label (name=0, hp=1, level=2)
		
		print("Found enemy display at index %d, updating HP label" % enemy_index)
		
		# Calculate HP percentage and color using the already calculated values
		var hp_percentage = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		var hp_color = Color.GREEN
		if hp_percentage < 0.75:
			hp_color = Color.YELLOW
		if hp_percentage < 0.5:
			hp_color = Color.ORANGE
		if hp_percentage < 0.25:
			hp_color = Color.RED
		if current_hp <= 0:
			hp_color = Color.DARK_RED
			
		# Update HP text and color
		hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
		hp_label.add_theme_color_override("font_color", hp_color)
		
		# Disable button if enemy is dead
		if current_hp <= 0:
			main_button.disabled = true
			var dead_style = StyleBoxFlat.new()
			dead_style.bg_color = Color(0.3, 0.1, 0.1, 0.6)
			dead_style.corner_radius_top_left = 8
			dead_style.corner_radius_bottom_left = 8
			dead_style.corner_radius_top_right = 8
			dead_style.corner_radius_bottom_right = 8
			main_button.add_theme_stylebox_override("disabled", dead_style)
		
		print("Updated enemy %d HP display: %s" % [enemy_index, hp_label.text])
	else:
		print("No display found for enemy index %d" % enemy_index)

func _on_battle_completed(result):
	"""Handle battle completion with proper victory UI"""
	print("Battle completed: %s" % ("VICTORY" if result == 0 else "DEFEAT"))
	
	var result_text = "VICTORY!" if result == 0 else "DEFEAT!"
	var result_color = Color.GREEN if result == 0 else Color.RED
	
	# Add territory progress info for victories
	if result == 0 and current_territory:
		if current_territory.is_unlocked and current_territory.current_stage >= current_territory.max_stages:
			result_text = "TERRITORY UNLOCKED!\n%s Conquered!" % current_territory.name
			result_color = Color.GOLD
		else:
			result_text = "STAGE %d CLEARED!\nProgress: %d/%d" % [current_battle_stage, current_territory.current_stage, current_territory.max_stages]
	
	# Only show in battle_status_label (main display)
	if battle_status_label:
		battle_status_label.text = result_text
		battle_status_label.modulate = result_color
	
	# Keep turn_indicator simple
	if turn_indicator:
		turn_indicator.text = "Battle Complete"
		turn_indicator.modulate = result_color
	
	_hide_action_buttons()
	
	# Show victory/defeat options after short delay for impact
	await get_tree().create_timer(1.0).timeout
	_show_battle_result_options(result == 0)

func _show_battle_result_options(is_victory: bool):
	"""Show options after battle completion"""
	if not action_buttons_container:
		return
	
	# Clear any existing buttons
	for child in action_buttons_container.get_children():
		child.queue_free()
	
	if is_victory:
		# Check if there's a next stage available
		if current_territory and current_battle_stage < current_territory.max_stages:
			# Next Stage button
			var next_stage_btn = Button.new()
			next_stage_btn.text = "Next Stage (%d)" % (current_battle_stage + 1)
			next_stage_btn.custom_minimum_size = Vector2(120, 40)
			next_stage_btn.pressed.connect(_on_continue_to_next_stage)
			action_buttons_container.add_child(next_stage_btn)
			
		# Retry Stage button (for farming)
		var retry_btn = Button.new()
		retry_btn.text = "Retry Stage"
		retry_btn.custom_minimum_size = Vector2(100, 40)
		retry_btn.pressed.connect(_on_retry_current_stage)
		action_buttons_container.add_child(retry_btn)
	else:
		# Retry button for defeat
		var retry_btn = Button.new()
		retry_btn.text = "Try Again"
		retry_btn.custom_minimum_size = Vector2(100, 40)
		retry_btn.pressed.connect(_on_retry_current_stage)
		action_buttons_container.add_child(retry_btn)
	
	# Always show Return button
	var return_btn = Button.new()
	return_btn.text = "Return"
	return_btn.custom_minimum_size = Vector2(80, 40)
	return_btn.pressed.connect(_on_back_pressed)
	action_buttons_container.add_child(return_btn)
	
	# Make visible
	action_buttons_container.visible = true

# Status Effect Display Methods
func update_god_status_effects(god: God):
	"""Update status effect display for a god"""
	if not god_displays.has(god.id):
		return
	
	var display = god_displays[god.id]
	_update_god_status_effect_display(display, god)

func update_enemy_status_effects(enemy: Dictionary):
	"""Update status effect display for an enemy"""
	# Find the index of this enemy in the battle system
	if not GameManager.battle_system:
		return
		
	var enemies = GameManager.battle_system.current_battle_enemies
	var enemy_index = -1
	
	# Find the index of this specific enemy
	for i in range(enemies.size()):
		if enemies[i] == enemy:
			enemy_index = i
			break
	
	# Update the display for this specific enemy
	if enemy_index >= 0 and enemy_displays.has(enemy_index):
		var display = enemy_displays[enemy_index]
		_update_enemy_status_effect_display(display, enemy)

func _update_god_status_effect_display(display: Control, god: God):
	"""Update the status effect indicators for a god display"""
	var main_button = display.get_child(0)
	var content = main_button.get_child(0)  # VBoxContainer inside button
	
	# Look for or create status effect container
	var status_container = null
	for child in content.get_children():
		if child.has_meta("status_effects"):
			status_container = child
			break
	
	if not status_container:
		# Create status effects display
		status_container = HBoxContainer.new()
		status_container.set_meta("status_effects", true)
		status_container.add_theme_constant_override("separation", 2)
		content.add_child(status_container)
	else:
		# Clear existing effects
		for child in status_container.get_children():
			child.queue_free()
	
	# Add status effect icons
	var buffs = god.get_buffs()
	var debuffs = god.get_debuffs()
	
	# Show up to 6 effects (3 buffs, 3 debuffs)
	var effects_shown = 0
	
	# Show buffs first
	for effect in buffs:
		if effects_shown >= 3:
			break
		_create_status_effect_indicator(status_container, effect, true)
		effects_shown += 1
	
	# Show debuffs
	for effect in debuffs:
		if effects_shown >= 6:
			break
		_create_status_effect_indicator(status_container, effect, false)
		effects_shown += 1

func _update_enemy_status_effect_display(display: Control, enemy: Dictionary):
	"""Update the status effect indicators for an enemy display"""
	var main_button = display.get_child(0)
	var content = main_button.get_child(0)  # VBoxContainer inside button
	
	# Look for or create status effect container
	var status_container = null
	for child in content.get_children():
		if child.has_meta("status_effects"):
			status_container = child
			break
	
	if not status_container:
		status_container = HBoxContainer.new()
		status_container.set_meta("status_effects", true)
		status_container.add_theme_constant_override("separation", 2)
		content.add_child(status_container)
	else:
		for child in status_container.get_children():
			child.queue_free()
	
	# Add enemy status effects
	var status_effects = enemy.get("status_effects", [])
	var effects_shown = 0
	
	for effect in status_effects:
		if effects_shown >= 4:  # Fewer for enemies to save space
			break
		var is_buff = effect.effect_type == StatusEffect.EffectType.BUFF or effect.effect_type == StatusEffect.EffectType.HOT
		_create_status_effect_indicator(status_container, effect, is_buff)
		effects_shown += 1

func _create_status_effect_indicator(container: Container, effect, is_buff: bool):
	"""Create a small status effect indicator with enhanced tooltip"""
	var indicator = PanelContainer.new()
	indicator.custom_minimum_size = Vector2(28, 24)  # Slightly larger for better visibility
	
	# Style the indicator with better visual hierarchy
	var style = StyleBoxFlat.new()
	var base_color = effect.color
	if base_color == Color.WHITE:
		base_color = Color.GREEN if is_buff else Color.RED
	
	# Make the background slightly transparent and add depth
	style.bg_color = base_color.darkened(0.2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	# Add subtle border with the effect color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = base_color
	
	indicator.add_theme_stylebox_override("panel", style)
	
	# Add hover effect
	indicator.mouse_entered.connect(func(): _on_status_effect_hover_start(indicator))
	indicator.mouse_exited.connect(func(): _on_status_effect_hover_end(indicator))
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	indicator.add_child(vbox)
	
	# Effect initial/icon - make it more prominent
	var label = Label.new()
	var effect_name = effect.name if effect.name else "?"
	label.text = effect_name[0].to_upper()  # First letter of effect name, uppercase
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# Duration indicator (small number at bottom)
	var duration = effect.duration
	if duration > 0:
		var duration_label = Label.new()
		duration_label.text = str(duration)
		duration_label.add_theme_font_size_override("font_size", 9)
		duration_label.add_theme_color_override("font_color", Color.YELLOW)
		duration_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		duration_label.add_theme_constant_override("shadow_offset_x", 1)
		duration_label.add_theme_constant_override("shadow_offset_y", 1)
		duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(duration_label)
	
	# Add stacks indicator if applicable
	var stacks = effect.stacks
	if stacks > 1:
		var stack_indicator = Label.new()
		stack_indicator.text = "x%d" % stacks
		stack_indicator.add_theme_font_size_override("font_size", 8)
		stack_indicator.add_theme_color_override("font_color", Color.CYAN)
		stack_indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
		stack_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stack_indicator)
	
	# Enhanced tooltip with detailed information
	var effect_tooltip = _build_status_effect_tooltip(effect, is_buff)
	indicator.tooltip_text = effect_tooltip
	
	container.add_child(indicator)

func _on_status_effect_hover_start(indicator: PanelContainer):
	"""Add visual feedback when hovering over status effect"""
	var tween = create_tween()
	tween.tween_property(indicator, "modulate", Color.WHITE.lightened(0.2), 0.1)

func _on_status_effect_hover_end(indicator: PanelContainer):
	"""Remove visual feedback when stopping hover"""
	var tween = create_tween()
	tween.tween_property(indicator, "modulate", Color.WHITE, 0.1)

func _build_status_effect_tooltip(effect, is_buff: bool) -> String:
	"""Build a comprehensive tooltip for status effects (plain text version)"""
	var tooltip_parts = []
	
	# Title with type indicator
	var type_text = "[BUFF]" if is_buff else "[DEBUFF]"
	if effect.effect_type == StatusEffect.EffectType.DOT:
		type_text = "[DOT]"
	elif effect.effect_type == StatusEffect.EffectType.HOT:
		type_text = "[HOT]"
	
	var effect_name = effect.name if effect.name else "Unknown Effect"
	tooltip_parts.append("%s %s" % [effect_name, type_text])
	
	if effect.description and effect.description != "":
		tooltip_parts.append("%s" % effect.description)
	
	# Duration and stacks
	if effect.duration > 0:
		tooltip_parts.append("Duration: %d turns" % effect.duration)
	else:
		tooltip_parts.append("Permanent")
	
	if effect.stacks > 1:
		tooltip_parts.append("Stacks: %d" % effect.stacks)
	
	# Show specific effect values
	var effect_details = []
	
	# Stat modifications
	if effect.stat_modifier.size() > 0:
		for stat_name in effect.stat_modifier.keys():
			var modifier = effect.stat_modifier[stat_name]
			var sign_text = "+" if modifier > 0 else ""
			var percent = int(modifier * 100)
			effect_details.append("%s %s%d%%" % [stat_name.capitalize(), sign_text, percent])
	
	# Damage/Healing per turn
	if effect.damage_per_turn > 0:
		var percent = int(effect.damage_per_turn * 100)
		effect_details.append("Damage: %d%% max HP per turn" % percent)
	
	if effect.heal_per_turn > 0:
		var percent = int(effect.heal_per_turn * 100)
		effect_details.append("Healing: %d%% max HP per turn" % percent)
	
	# Shield value
	if effect.shield_value > 0:
		effect_details.append("Shield: %d HP" % effect.shield_value)
	
	# Special properties
	if effect.prevents_action:
		effect_details.append("Prevents actions")
	if effect.immune_to_debuffs:
		effect_details.append("Debuff immunity")
	if effect.damage_immunity:
		effect_details.append("Damage immunity")
	
	if effect.reflect_damage > 0:
		var percent = int(effect.reflect_damage * 100)
		effect_details.append("Reflects %d%% damage" % percent)
	
	# Additional special states - check if properties exist first
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "stunned") and effect.stunned:
		effect_details.append("Stunned")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "frozen") and effect.frozen:
		effect_details.append("Frozen")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "sleeping") and effect.sleeping:
		effect_details.append("Sleeping")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "silenced") and effect.silenced:
		effect_details.append("Silenced")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "charmed") and effect.charmed:
		effect_details.append("Charmed")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "provoked") and effect.provoked:
		effect_details.append("Provoked")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "untargetable") and effect.untargetable:
		effect_details.append("Untargetable")
	if effect.get_script() and effect.get_script().get_property_list().any(func(p): return p.name == "counter_attack") and effect.counter_attack:
		effect_details.append("Counter Attack")
	
	if effect_details.size() > 0:
		tooltip_parts.append("")  # Empty line
		tooltip_parts.append_array(effect_details)
	
	return "\n".join(tooltip_parts)

func _on_continue_to_next_stage():
	"""Continue to next stage with same team"""
	if current_territory and selected_gods.size() > 0:
		var next_stage = current_battle_stage + 1
		print("Continuing to stage %d" % next_stage)
		setup_territory_stage_battle(current_territory, next_stage, selected_gods)

func _on_retry_current_stage():
	"""Retry current stage with same team"""
	if current_territory and selected_gods.size() > 0:
		print("Retrying stage %d" % current_battle_stage)
		setup_territory_stage_battle(current_territory, current_battle_stage, selected_gods)

func _on_back_pressed():
	# Reset auto-battle when leaving battle
	if GameManager.battle_system:
		GameManager.battle_system.auto_battle_enabled = false
	
	back_pressed.emit()

func _on_auto_battle_pressed():
	"""Toggle auto-battle mode"""
	if not GameManager.battle_system:
		return
	
	# Check if we're turning auto-battle ON and there's a current god waiting for action
	var was_auto_enabled = GameManager.battle_system.auto_battle_enabled
	
	# Toggle auto-battle in battle system
	GameManager.battle_system.toggle_auto_battle()
	
	# If we just turned auto-battle ON and there's a god waiting for action, execute AI action immediately
	if not was_auto_enabled and GameManager.battle_system.auto_battle_enabled and current_god:
		print("Auto-battle activated - executing AI action for %s immediately" % current_god.name)
		
		# Get AI action for current god
		var action = BattleAI.choose_god_auto_action(current_god, GameManager.battle_system.current_battle_enemies, GameManager.battle_system.current_battle_gods)
		
		# Execute the action immediately
		GameManager.battle_system.process_god_action(current_god, action)
	
	# Update button appearance
	_update_auto_battle_button()

func _update_auto_battle_button():
	"""Update auto-battle button text and style based on current state"""
	if not auto_battle_button or not GameManager.battle_system:
		return
	
	var is_auto_enabled = GameManager.battle_system.auto_battle_enabled
	
	if is_auto_enabled:
		auto_battle_button.text = "🤖 Auto: ON"
		# Green tint for active
		var style_active = StyleBoxFlat.new()
		style_active.bg_color = Color(0.2, 0.4, 0.2, 0.9)
		style_active.corner_radius_top_left = 6
		style_active.corner_radius_top_right = 6
		style_active.corner_radius_bottom_left = 6
		style_active.corner_radius_bottom_right = 6
		style_active.border_width_left = 2
		style_active.border_width_right = 2
		style_active.border_width_top = 2
		style_active.border_width_bottom = 2
		style_active.border_color = Color(0.4, 0.8, 0.4, 1.0)
		auto_battle_button.add_theme_stylebox_override("normal", style_active)
	else:
		auto_battle_button.text = "🤖 Auto: OFF"
		# Default gray tint for inactive
		var style_inactive = StyleBoxFlat.new()
		style_inactive.bg_color = Color(0.2, 0.2, 0.3, 0.9)
		style_inactive.corner_radius_top_left = 6
		style_inactive.corner_radius_top_right = 6
		style_inactive.corner_radius_bottom_left = 6
		style_inactive.corner_radius_bottom_right = 6
		style_inactive.border_width_left = 2
		style_inactive.border_width_right = 2
		style_inactive.border_width_top = 2
		style_inactive.border_width_bottom = 2
		style_inactive.border_color = Color(0.5, 0.5, 0.6, 1.0)
		auto_battle_button.add_theme_stylebox_override("normal", style_inactive)

func _on_speed_1x_pressed():
	"""Set auto-battle speed to 1x (2 seconds per turn)"""
	if GameManager.battle_system:
		GameManager.battle_system.set_auto_battle_speed(1)
		_update_speed_buttons()

func _on_speed_2x_pressed():
	"""Set auto-battle speed to 2x (1 second per turn)"""
	if GameManager.battle_system:
		GameManager.battle_system.set_auto_battle_speed(2)
		_update_speed_buttons()

func _on_speed_3x_pressed():
	"""Set auto-battle speed to 3x (0.5 seconds per turn)"""
	if GameManager.battle_system:
		GameManager.battle_system.set_auto_battle_speed(3)
		_update_speed_buttons()

func _update_speed_buttons():
	"""Update speed button appearance based on current speed"""
	if not GameManager.battle_system:
		return
	
	var current_speed = GameManager.battle_system.get_auto_battle_speed()
	
	# Reset all buttons to unpressed state
	speed_1x_button.button_pressed = (current_speed == 1)
	speed_2x_button.button_pressed = (current_speed == 2)
	speed_3x_button.button_pressed = (current_speed == 3)
