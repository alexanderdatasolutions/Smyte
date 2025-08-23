# BattleSetupScreen.gd - Universal battle preparation screen
extends Control

signal battle_setup_complete(context: Dictionary)
signal setup_cancelled

# UI References
@onready var title_label = $MainContainer/HeaderContainer/TitleLabel
@onready var description_label = $MainContainer/HeaderContainer/DescriptionLabel
@onready var team_selection_container = $MainContainer/ContentContainer/TeamSelectionContainer
@onready var team_slots_container = $MainContainer/ContentContainer/TeamSelectionContainer/TeamSlotsContainer
@onready var available_gods_scroll = $MainContainer/ContentContainer/TeamSelectionContainer/AvailableGodsContainer/ScrollContainer
@onready var available_gods_grid = $MainContainer/ContentContainer/TeamSelectionContainer/AvailableGodsContainer/ScrollContainer/GodsGrid
@onready var battle_info_panel = $MainContainer/ContentContainer/BattleInfoPanel
@onready var enemy_preview_container = $MainContainer/ContentContainer/BattleInfoPanel/EnemyPreviewContainer
@onready var rewards_container = $MainContainer/ContentContainer/BattleInfoPanel/RewardsContainer
@onready var start_battle_button = $MainContainer/BottomContainer/StartBattleButton
@onready var cancel_button = $MainContainer/BottomContainer/CancelButton

# Battle context data
var battle_context: Dictionary = {}
var selected_team: Array = []
var team_slots: Array = []
var max_team_size: int = 4  # Match Summoners War team size

# Sorting state
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false  # Default to descending (highest first)

func _ready():
	# Add to group for easy cleanup
	add_to_group("battle_setup")
	
	# Connect UI signals
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Initialize team slots after ensuring we're in the scene tree
	call_deferred("_initialize_ui")

func _initialize_ui():
	"""Initialize UI components after scene is properly set up"""
	# Wait for scene tree to be available and UI to be ready
	if get_tree():
		await get_tree().process_frame
	
	# Initialize team slots after UI is ready
	_create_team_slots()

func _deferred_ui_update():
	"""Deferred UI update when components are ready"""
	print("=== BattleSetupScreen: _deferred_ui_update called ===")
	
	# Wait a bit more for UI to be fully ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Try to get nodes manually if @onready failed
	if not team_slots_container:
		team_slots_container = get_node("MainContainer/ContentContainer/TeamSelectionContainer/TeamSlotsContainer")
		print("Manually found team_slots_container: ", team_slots_container)
	
	if not available_gods_grid:
		available_gods_grid = get_node("MainContainer/ContentContainer/TeamSelectionContainer/AvailableGodsContainer/ScrollContainer/GodsGrid")
		print("Manually found available_gods_grid: ", available_gods_grid)
	
	if not start_battle_button:
		start_battle_button = get_node("MainContainer/BottomContainer/StartBattleButton")
		print("Manually found start_battle_button: ", start_battle_button)
	
	if not team_slots_container:
		print("ERROR: Could not find team_slots_container node")
		return
		
	if not available_gods_grid:
		print("ERROR: Could not find available_gods_grid node")
		return
	
	print("UI components ready, initializing...")
	setup_sorting_ui()
	_refresh_team_slots()
	_load_available_gods()

func setup_for_territory_battle(territory: Territory, stage: int):
	"""Setup screen for territory battle"""
	battle_context = {
		"type": "territory",
		"territory": territory,
		"stage": stage,
		"title": "%s - Stage %d" % [territory.name, stage],
		"description": "Select your team to assault this territory stage."
	}
	
	_update_ui_for_context()
	_load_enemy_preview()
	_load_territory_rewards()

func setup_for_dungeon_battle(dungeon_id: String, difficulty: String):
	"""Setup screen for dungeon battle"""
	print("=== BattleSetupScreen: setup_for_dungeon_battle called with: ", dungeon_id, ", ", difficulty, " ===")
	
	var dungeon_system = GameManager.get_dungeon_system()
	var dungeon_info = {}
	var unlock_info = {}
	if dungeon_system:
		dungeon_info = dungeon_system.get_dungeon_info(dungeon_id)
		unlock_info = dungeon_system.get_difficulty_unlock_requirements(dungeon_id, difficulty)
		print("Got dungeon info: ", dungeon_info)
		print("Got unlock info: ", unlock_info)
	else:
		print("ERROR: DungeonSystem not found in GameManager!")
	
	# Create description with unlock info if needed
	var description_text = "Select your team for this dungeon challenge."
	if not unlock_info.get("is_unlocked", true):
		description_text += "\n\nTo unlock this difficulty: %s (%s)" % [unlock_info.get("requirement_text", ""), unlock_info.get("progress_text", "")]
	
	battle_context = {
		"type": "dungeon",
		"dungeon_id": dungeon_id,
		"difficulty": difficulty,
		"dungeon_info": dungeon_info,
		"unlock_info": unlock_info,
		"title": "%s - %s" % [dungeon_info.get("name", str(dungeon_id).capitalize()), str(difficulty).capitalize()],
		"description": description_text
	}
	
	print("Battle context set: ", battle_context)
	_update_ui_for_context()
	_load_dungeon_enemy_preview()
	_load_dungeon_rewards()

func setup_for_pvp_battle(opponent_data: Dictionary):
	"""Setup screen for PvP battle (future expansion)"""
	battle_context = {
		"type": "pvp",
		"opponent": opponent_data,
		"title": "PvP Battle vs %s" % opponent_data.get("name", "Unknown"),
		"description": "Select your team to battle another player."
	}
	
	_update_ui_for_context()
	_load_pvp_enemy_preview()
	_load_pvp_rewards()

func setup_for_raid_battle(raid_data: Dictionary):
	"""Setup screen for raid battle (future expansion)"""
	battle_context = {
		"type": "raid",
		"raid_data": raid_data,
		"title": "Raid: %s" % raid_data.get("name", "Unknown Raid"),
		"description": "Coordinate with your guild to take down this powerful boss."
	}
	
	_update_ui_for_context()
	_load_raid_enemy_preview()
	_load_raid_rewards()

func _update_ui_for_context():
	"""Update UI elements based on battle context"""
	if title_label:
		title_label.text = battle_context.get("title", "Battle Setup")
	
	if description_label:
		description_label.text = battle_context.get("description", "Select your team for battle.")
	
	# Update team size limits based on battle type
	match battle_context.get("type", ""):
		"territory":
			max_team_size = 4
		"dungeon":
			max_team_size = 4
		"pvp":
			max_team_size = 4
		"raid":
			max_team_size = 5  # Raids might allow larger teams
		_:
			max_team_size = 4
	
	# Always defer UI updates to ensure components are ready
	call_deferred("_deferred_ui_update")

func _create_team_slots():
	"""Create team selection slots"""
	if not team_slots_container:
		print("Warning: team_slots_container not ready yet")
		return
	
	# Clear existing slots
	for child in team_slots_container.get_children():
		child.queue_free()
	
	team_slots.clear()
	selected_team.clear()

func _refresh_team_slots():
	"""Refresh team slots based on max team size"""
	if not team_slots_container:
		print("Warning: team_slots_container not ready yet")
		return
	
	_create_team_slots()
	
	# Create new slots
	for i in range(max_team_size):
		var slot = _create_team_slot(i)
		team_slots.append(slot)
		team_slots_container.add_child(slot)
		selected_team.append(null)

func _create_team_slot(index: int) -> Control:
	"""Create a single team slot"""
	var slot_container = VBoxContainer.new()
	slot_container.custom_minimum_size = Vector2(120, 140)
	slot_container.add_theme_constant_override("separation", 5)
	
	# Main slot button with image container
	var slot_button = Button.new()
	slot_button.custom_minimum_size = Vector2(120, 120)
	slot_button.text = "SLOT %d" % (index + 1)
	slot_button.set_meta("slot_index", index)
	slot_button.pressed.connect(_on_team_slot_pressed.bind(index))
	
	# Style empty slot with improved design
	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	empty_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	empty_style.border_width_left = 3
	empty_style.border_width_right = 3
	empty_style.border_width_top = 3
	empty_style.border_width_bottom = 3
	empty_style.corner_radius_top_left = 10
	empty_style.corner_radius_top_right = 10
	empty_style.corner_radius_bottom_left = 10
	empty_style.corner_radius_bottom_right = 10
	slot_button.add_theme_stylebox_override("normal", empty_style)
	
	# Add hover effect
	var hover_style = empty_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.3, 0.9)
	hover_style.border_color = Color(0.6, 0.6, 0.7, 1.0)
	slot_button.add_theme_stylebox_override("hover", hover_style)
	
	# Create image container inside the button
	var image_container = TextureRect.new()
	image_container.name = "GodImage"
	image_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.visible = false
	slot_button.add_child(image_container)
	
	slot_container.add_child(slot_button)
	
	# God info labels (initially hidden)
	var name_label = Label.new()
	name_label.text = ""
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.visible = false
	slot_container.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = ""
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.modulate = Color.CYAN
	level_label.visible = false
	slot_container.add_child(level_label)
	
	return slot_container

func _load_available_gods():
	"""Load available gods for selection"""
	if not available_gods_grid:
		print("Warning: available_gods_grid not ready yet")
		return
	
	# Clear existing gods
	for child in available_gods_grid.get_children():
		child.queue_free()
	
	if not GameManager or not GameManager.player_data:
		print("Warning: GameManager or player_data not available")
		return
	
	# Get and sort gods
	var gods_list = GameManager.player_data.gods.duplicate()
	sort_gods(gods_list)
	
	# Create god selection buttons
	for god in gods_list:
		var god_button = _create_god_selection_button(god)
		available_gods_grid.add_child(god_button)

func _create_god_selection_button(god: God) -> Control:
	"""Create a god selection button with collection screen styling"""
	# Create card panel instead of just a button
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	
	# Style with subtle tier colors like CollectionScreen
	var style = StyleBoxFlat.new()
	style.bg_color = _get_subtle_tier_color(god.tier)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = _get_tier_border_color(god.tier)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Create content container with margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	# God image
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load god image
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
	else:
		# Fallback colored rectangle
		var fallback = ColorRect.new()
		fallback.color = _get_element_color(god.get_element_name().to_lower())
		fallback.custom_minimum_size = Vector2(48, 48)
		god_image = fallback
	
	vbox.add_child(god_image)
	
	# God name
	var name_label = Label.new()
	name_label.text = god.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.level, _get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Element and power
	var info_label = Label.new()
	info_label.text = "%s P:%d" % [_get_element_short_name(god.element), god.get_power_rating()]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(info_label)
	
	# Make clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.set_meta("god", god)
	button.pressed.connect(_on_god_selected.bind(god))
	card.add_child(button)
	
	return card

func _on_god_selected(god: God):
	"""Handle god selection"""
	# Find first empty slot
	for i in range(selected_team.size()):
		if selected_team[i] == null:
			_assign_god_to_slot(god, i)
			break

func _assign_god_to_slot(god: God, slot_index: int):
	"""Assign a god to a specific slot"""
	if slot_index < 0 or slot_index >= selected_team.size():
		return
	
	# Remove god from any other slot first
	for i in range(selected_team.size()):
		if selected_team[i] == god:
			_clear_slot(i)
			break
	
	# Assign to new slot
	selected_team[slot_index] = god
	_update_slot_display(slot_index)
	_update_start_button_state()

func _clear_slot(slot_index: int):
	"""Clear a team slot"""
	if slot_index < 0 or slot_index >= selected_team.size():
		return
	
	selected_team[slot_index] = null
	_update_slot_display(slot_index)
	_update_start_button_state()

func _update_slot_display(slot_index: int):
	"""Update the visual display of a team slot"""
	if slot_index >= team_slots.size() or not team_slots_container:
		return
	
	var slot_container = team_slots[slot_index]
	if not slot_container or slot_container.get_child_count() < 3:
		return
		
	var slot_button = slot_container.get_child(0) as Button
	var name_label = slot_container.get_child(1) as Label
	var level_label = slot_container.get_child(2) as Label
	var god = selected_team[slot_index]
	
	if not slot_button or not name_label or not level_label:
		return
	
	# Get the god image container
	var image_container = slot_button.get_node_or_null("GodImage") as TextureRect
	
	if god:
		# Show god in slot
		slot_button.text = ""  # Clear text to show god image
		name_label.text = god.name
		name_label.visible = true
		level_label.text = "Lv.%d %s" % [god.level, _get_tier_short_name(god.tier)]
		level_label.visible = true
		
		# Show god image
		if image_container:
			var god_texture = god.get_sprite()
			if god_texture:
				image_container.texture = god_texture
				image_container.visible = true
			else:
				image_container.visible = false
		
		# Style based on god tier
		var filled_style = StyleBoxFlat.new()
		filled_style.bg_color = _get_subtle_tier_color(god.tier)
		filled_style.border_color = _get_tier_border_color(god.tier)
		filled_style.border_width_left = 3
		filled_style.border_width_right = 3
		filled_style.border_width_top = 3
		filled_style.border_width_bottom = 3
		filled_style.corner_radius_top_left = 10
		filled_style.corner_radius_top_right = 10
		filled_style.corner_radius_bottom_left = 10
		filled_style.corner_radius_bottom_right = 10
		slot_button.add_theme_stylebox_override("normal", filled_style)
		
		# Add hover effect
		var hover_style = filled_style.duplicate()
		hover_style.bg_color = hover_style.bg_color.lightened(0.2)
		slot_button.add_theme_stylebox_override("hover", hover_style)
	else:
		# Show empty slot
		slot_button.text = "SLOT %d" % (slot_index + 1)
		name_label.text = ""
		name_label.visible = false
		level_label.text = ""
		level_label.visible = false
		
		# Hide god image
		if image_container:
			image_container.visible = false
			image_container.texture = null
		
		# Reset to empty style
		var empty_style = StyleBoxFlat.new()
		empty_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		empty_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
		empty_style.border_width_left = 3
		empty_style.border_width_right = 3
		empty_style.border_width_top = 3
		empty_style.border_width_bottom = 3
		empty_style.corner_radius_top_left = 10
		empty_style.corner_radius_top_right = 10
		empty_style.corner_radius_bottom_left = 10
		empty_style.corner_radius_bottom_right = 10
		slot_button.add_theme_stylebox_override("normal", empty_style)

func _get_element_color(element: String) -> Color:
	"""Get color for element"""
	match element:
		"fire": return Color.ORANGE_RED
		"water": return Color.CYAN
		"earth": return Color.SADDLE_BROWN
		"lightning": return Color.YELLOW
		"light": return Color.WHITE
		"dark": return Color.PURPLE
		_: return Color.GRAY

func _get_subtle_tier_color(tier: int) -> Color:
	"""Get subtle background colors for tiers"""
	match tier:
		1: return Color(0.3, 0.3, 0.3, 0.8)  # Common - gray
		2: return Color(0.2, 0.4, 0.2, 0.8)  # Uncommon - green
		3: return Color(0.2, 0.2, 0.4, 0.8)  # Rare - blue
		4: return Color(0.4, 0.2, 0.4, 0.8)  # Epic - purple
		5: return Color(0.5, 0.3, 0.1, 0.8)  # Legendary - orange
		_: return Color(0.2, 0.2, 0.2, 0.8)

func _get_tier_border_color(tier: int) -> Color:
	"""Get border colors for tiers"""
	match tier:
		1: return Color(0.6, 0.6, 0.6, 1.0)  # Common
		2: return Color(0.4, 0.8, 0.4, 1.0)  # Uncommon
		3: return Color(0.4, 0.4, 0.8, 1.0)  # Rare
		4: return Color(0.8, 0.4, 0.8, 1.0)  # Epic
		5: return Color(1.0, 0.6, 0.2, 1.0)  # Legendary
		_: return Color(0.5, 0.5, 0.5, 1.0)

func _get_tier_short_name(tier: int) -> String:
	"""Get short tier names for compact display"""
	match tier:
		1: return "C"   # Common
		2: return "UC"  # Uncommon
		3: return "R"   # Rare
		4: return "E"   # Epic
		5: return "L"   # Legendary
		_: return "?"

func _get_element_short_name(element: God.ElementType) -> String:
	"""Get short element names for compact display"""
	match element:
		God.ElementType.FIRE: return "Fire"
		God.ElementType.WATER: return "Water"
		God.ElementType.EARTH: return "Earth"
		God.ElementType.LIGHTNING: return "Lightning"
		God.ElementType.LIGHT: return "Light"
		God.ElementType.DARK: return "Dark"
		_: return "None"

func sort_gods(gods: Array):
	"""Sort gods array based on current sort settings"""
	gods.sort_custom(func(a, b):
		var result = false
		match current_sort:
			SortType.POWER:
				result = a.get_power_rating() > b.get_power_rating()
			SortType.LEVEL:
				result = a.level > b.level
			SortType.TIER:
				result = a.tier > b.tier
			SortType.ELEMENT:
				result = a.get_element_name() < b.get_element_name()
			SortType.NAME:
				result = a.name < b.name
			_:
				result = a.get_power_rating() > b.get_power_rating()
		
		return result if not sort_ascending else !result
	)

func setup_sorting_ui():
	"""Add sorting controls to the gods selection area"""
	if not team_selection_container:
		return
		
	# Check if sorting UI already exists
	var existing_sort = team_selection_container.get_node_or_null("SortContainer")
	if existing_sort:
		return
	
	# Find the AvailableGodsContainer
	var available_gods_container = team_selection_container.get_node_or_null("AvailableGodsContainer")
	if not available_gods_container:
		return
	
	# Create sorting controls container
	var sort_container = HBoxContainer.new()
	sort_container.name = "SortContainer"
	sort_container.add_theme_constant_override("separation", 10)
	
	# Add sort label
	var sort_label = Label.new()
	sort_label.text = "Sort by:"
	sort_label.add_theme_font_size_override("font_size", 14)
	sort_container.add_child(sort_label)
	
	# Create sort buttons
	var button_configs = [
		["Power", SortType.POWER],
		["Level", SortType.LEVEL], 
		["Tier", SortType.TIER],
		["Element", SortType.ELEMENT],
		["Name", SortType.NAME]
	]
	
	for button_data in button_configs:
		var button = Button.new()
		button.text = button_data[0]
		button.custom_minimum_size = Vector2(60, 30)
		button.pressed.connect(_on_sort_changed.bind(button_data[1]))
		sort_container.add_child(button)
	
	# Add sort direction button
	var direction_button = Button.new()
	direction_button.text = "↓" if not sort_ascending else "↑"
	direction_button.custom_minimum_size = Vector2(30, 30)
	direction_button.pressed.connect(_on_sort_direction_changed)
	sort_container.add_child(direction_button)
	
	# Insert sorting controls at the top of the AvailableGodsContainer
	available_gods_container.add_child(sort_container)
	available_gods_container.move_child(sort_container, 0)

func _on_sort_changed(sort_type: SortType):
	"""Handle sort type change"""
	current_sort = sort_type
	_load_available_gods()

func _on_sort_direction_changed():
	"""Toggle sort direction"""
	sort_ascending = !sort_ascending
	_load_available_gods()
	# Update direction arrow
	var sort_container = team_selection_container.get_node_or_null("AvailableGodsContainer/SortContainer")
	if sort_container and sort_container.get_child_count() > 6:
		var direction_button = sort_container.get_child(-1) as Button
		if direction_button:
			direction_button.text = "↓" if not sort_ascending else "↑"

func _on_team_slot_pressed(slot_index: int):
	"""Handle team slot button press"""
	if selected_team[slot_index] != null:
		_clear_slot(slot_index)

func _load_enemy_preview():
	"""Load enemy preview for territory battles"""
	if not enemy_preview_container:
		return
	
	# Clear existing preview
	for child in enemy_preview_container.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "ENEMIES"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_preview_container.add_child(title)
	
	# Create enemy previews using EnemyFactory
	var territory = battle_context.get("territory")
	var stage = battle_context.get("stage", 1)
	
	if territory:
		var enemies = EnemyFactory.create_enemies_for_stage(territory, stage)
		for enemy in enemies:
			var enemy_label = Label.new()
			enemy_label.text = "• %s (Lv.%d)" % [enemy.get("name", "Unknown"), enemy.get("level", 1)]
			enemy_preview_container.add_child(enemy_label)

func _load_dungeon_enemy_preview():
	"""Load enemy preview for dungeon battles"""
	if not enemy_preview_container:
		print("Warning: enemy_preview_container not available for dungeon preview")
		return
	
	# Clear existing preview
	for child in enemy_preview_container.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "DUNGEON ENEMIES"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_preview_container.add_child(title)
	
	# Create enemy previews using EnemyFactory
	var dungeon_id = battle_context.get("dungeon_id", "")
	var difficulty = battle_context.get("difficulty", "beginner")
	
	print("Loading dungeon enemy preview for: ", dungeon_id, " (", difficulty, ")")
	
	if dungeon_id:
		var enemies = EnemyFactory.create_enemies_for_dungeon(dungeon_id, difficulty)
		print("EnemyFactory returned ", enemies.size(), " enemies")
		
		if enemies.size() == 0:
			var no_enemies_label = Label.new()
			no_enemies_label.text = "• No enemy data available"
			no_enemies_label.modulate = Color.YELLOW
			enemy_preview_container.add_child(no_enemies_label)
		else:
			for enemy in enemies:
				var enemy_label = Label.new()
				enemy_label.text = "• %s (Lv.%d)" % [enemy.get("name", "Unknown"), enemy.get("level", 1)]
				enemy_preview_container.add_child(enemy_label)
	else:
		var error_label = Label.new()
		error_label.text = "• Error: No dungeon ID"
		error_label.modulate = Color.RED
		enemy_preview_container.add_child(error_label)

func _load_pvp_enemy_preview():
	"""Load enemy preview for PvP battles"""
	# Placeholder for future PvP implementation
	pass

func _load_raid_enemy_preview():
	"""Load enemy preview for raid battles"""
	# Placeholder for future raid implementation
	pass

func _load_territory_rewards():
	"""Load rewards preview for territory battles"""
	if not rewards_container:
		return
	
	_clear_rewards_display()
	
	var title = Label.new()
	title.text = "STAGE REWARDS"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_container.add_child(title)
	
	# Add generic territory rewards
	_add_reward_item("Experience Points")
	_add_reward_item("Divine Essence")
	_add_reward_item("Random Loot")

func _load_dungeon_rewards():
	"""Load rewards preview for dungeon battles"""
	if not rewards_container:
		return
	
	_clear_rewards_display()
	
	var title = Label.new()
	title.text = "DUNGEON REWARDS"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_container.add_child(title)
	
	# Add dungeon-specific rewards
	var dungeon_id = battle_context.get("dungeon_id", "")
	var difficulty = battle_context.get("difficulty", "beginner")
	
	if "_sanctum" in dungeon_id:
		var element = dungeon_id.replace("_sanctum", "")
		_add_reward_item("%s Powder (%s)" % [str(element).capitalize(), str(difficulty).capitalize()])
	elif dungeon_id == "magic_sanctum":
		_add_reward_item("Magic Powder (%s)" % str(difficulty).capitalize())
	
	_add_reward_item("Divine Essence")
	_add_reward_item("Experience Points")
	
	if difficulty in ["expert", "master", "legendary"]:
		_add_reward_item("Awakening Stones")

func _load_pvp_rewards():
	"""Load rewards preview for PvP battles"""
	# Placeholder for future PvP implementation
	pass

func _load_raid_rewards():
	"""Load rewards preview for raid battles"""
	# Placeholder for future raid implementation
	pass

func _clear_rewards_display():
	"""Clear rewards display"""
	for child in rewards_container.get_children():
		child.queue_free()

func _add_reward_item(reward_text: String):
	"""Add a reward item to the display"""
	var item = Label.new()
	item.text = "• " + reward_text
	item.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	rewards_container.add_child(item)

func _update_start_button_state():
	"""Update start battle button enabled state"""
	if not start_battle_button:
		return
	
	var team_count = 0
	for god in selected_team:
		if god != null:
			team_count += 1
	
	start_battle_button.disabled = (team_count == 0)
	
	if team_count == 0:
		start_battle_button.text = "SELECT TEAM FIRST"
	else:
		start_battle_button.text = "START BATTLE (%d Gods)" % team_count

func _on_start_battle_pressed():
	"""Handle start battle button press"""
	# Validate team
	var final_team = []
	for god in selected_team:
		if god != null:
			final_team.append(god)
	
	if final_team.size() == 0:
		print("No team selected")
		return
	
	# Add team to battle context
	battle_context["team"] = final_team
	
	print("=== BattleSetupScreen: Starting battle with context ===")
	print("Battle type: %s" % battle_context.get("type", "unknown"))
	print("Team size: %d" % final_team.size())
	
	# Emit signal with complete battle context
	battle_setup_complete.emit(battle_context)

func _on_cancel_pressed():
	"""Handle cancel button press"""
	setup_cancelled.emit()

# Utility method to get current team
func get_selected_team() -> Array:
	"""Get currently selected team (non-null gods only)"""
	var team = []
	for god in selected_team:
		if god != null:
			team.append(god)
	return team

func get_battle_context() -> Dictionary:
	"""Get current battle context"""
	return battle_context.duplicate()
