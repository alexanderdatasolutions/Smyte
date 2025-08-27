# scripts/ui/components/DungeonInfoDisplayManager.gd
# Single responsibility: Display dungeon information, difficulty selection, and rewards
class_name DungeonInfoDisplayManager extends Node

# Dungeon info signals
signal difficulty_selected(dungeon_id: String, difficulty: String)
signal rewards_display_updated

var dungeon_info_container: Control
var difficulty_buttons_container: Control
var rewards_container: Control

var current_dungeon_id: String = ""
var current_difficulty: String = ""
var difficulty_buttons: Array = []

func initialize(info_container: Control, difficulty_container: Control, rewards_display: Control):
	"""Initialize with the display containers"""
	dungeon_info_container = info_container
	difficulty_buttons_container = difficulty_container
	rewards_container = rewards_display
	print("DungeonInfoDisplayManager: Initialized")

func show_dungeon_info(dungeon_id: String, dungeon_data: Dictionary):
	"""Show dungeon information and setup difficulty selection - RULE 4: UI display only"""
	current_dungeon_id = dungeon_id
	
	# Clear existing displays
	clear_all_displays()
	
	await get_tree().process_frame
	
	# Display dungeon info
	display_dungeon_details(dungeon_data)
	
	# Setup difficulty buttons
	setup_difficulty_buttons(dungeon_id, dungeon_data)
	
	# Show default difficulty rewards
	var default_difficulty = get_default_difficulty(dungeon_data)
	if default_difficulty:
		current_difficulty = default_difficulty
		update_rewards_display(dungeon_id, default_difficulty)

func clear_all_displays():
	"""Clear all display containers"""
	if dungeon_info_container:
		for child in dungeon_info_container.get_children():
			child.queue_free()
	
	if difficulty_buttons_container:
		for child in difficulty_buttons_container.get_children():
			child.queue_free()
	
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()
	
	difficulty_buttons.clear()

func display_dungeon_details(dungeon_data: Dictionary):
	"""Display dungeon name, description, and basic info"""
	if not dungeon_info_container:
		return
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	dungeon_info_container.add_child(vbox)
	
	# Dungeon name header
	var name_label = Label.new()
	name_label.text = dungeon_data.get("name", "Unknown Dungeon")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = Color.CYAN
	vbox.add_child(name_label)
	
	# Element and type info
	var info_hbox = HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_hbox)
	
	var element_label = Label.new()
	element_label.text = "Element: %s" % dungeon_data.get("element", "Neutral")
	element_label.add_theme_font_size_override("font_size", 12)
	element_label.modulate = get_element_color(dungeon_data.get("element", "neutral"))
	info_hbox.add_child(element_label)
	
	info_hbox.add_child(VSeparator.new())
	
	var type_label = Label.new()
	type_label.text = "Type: %s" % dungeon_data.get("type", "Standard")
	type_label.add_theme_font_size_override("font_size", 12)
	info_hbox.add_child(type_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = dungeon_data.get("description", "A mysterious dungeon filled with challenges and rewards.")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(desc_label)

func setup_difficulty_buttons(_dungeon_id: String, dungeon_data: Dictionary):
	"""Setup difficulty selection buttons - RULE 4: UI creation only"""
	if not difficulty_buttons_container:
		return
	
	var difficulties = dungeon_data.get("difficulties", ["normal"])
	
	# Create button group for exclusive selection
	var button_group = ButtonGroup.new()
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	difficulty_buttons_container.add_child(hbox)
	
	for i in range(difficulties.size()):
		var difficulty = difficulties[i]
		var button = Button.new()
		button.text = difficulty.capitalize()
		button.toggle_mode = true
		button.button_group = button_group
		button.custom_minimum_size = Vector2(80, 35)
		
		# Style based on difficulty
		var button_style = get_difficulty_style(difficulty)
		button.add_theme_stylebox_override("normal", button_style)
		
		# Connect signal
		button.toggled.connect(_on_difficulty_button_toggled.bind(difficulty))
		
		hbox.add_child(button)
		difficulty_buttons.append(button)
		
		# Select first difficulty by default
		if i == 0:
			button.button_pressed = true

func get_difficulty_style(difficulty: String) -> StyleBoxFlat:
	"""Get styling for difficulty button"""
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	match difficulty.to_lower():
		"easy", "normal":
			style.bg_color = Color(0.3, 0.5, 0.3, 0.8)  # Green
		"hard":
			style.bg_color = Color(0.5, 0.4, 0.3, 0.8)  # Orange
		"hell", "nightmare":
			style.bg_color = Color(0.5, 0.3, 0.3, 0.8)  # Red
		_:
			style.bg_color = Color(0.4, 0.4, 0.4, 0.8)  # Gray
	
	return style

func _on_difficulty_button_toggled(difficulty: String, pressed: bool):
	"""Handle difficulty button toggle"""
	if pressed:
		current_difficulty = difficulty
		print("DungeonInfoDisplayManager: Difficulty selected - %s" % difficulty)
		update_rewards_display(current_dungeon_id, difficulty)
		difficulty_selected.emit(current_dungeon_id, difficulty)

func update_rewards_display(dungeon_id: String, difficulty: String):
	"""Update rewards display for selected difficulty - RULE 5: Use SystemRegistry"""
	if not rewards_container:
		return
	
	# Clear existing rewards
	for child in rewards_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get rewards through SystemRegistry
	var rewards_preview = get_rewards_from_system(dungeon_id, difficulty)
	display_rewards(rewards_preview)
	rewards_display_updated.emit()

func get_rewards_from_system(dungeon_id: String, difficulty: String) -> Array:
	"""Get reward preview through SystemRegistry - RULE 5 compliance"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		print("DungeonInfoDisplayManager: SystemRegistry not available")
		return []
	
	var loot_system = system_registry.get_system("LootSystem")
	if not loot_system:
		print("DungeonInfoDisplayManager: LootSystem not found")
		return []
	
	# Convert dungeon ID to loot table name
	var loot_table_name = convert_dungeon_id_to_loot_table_name(dungeon_id, difficulty)
	
	# Get reward preview
	return loot_system.preview_rewards(loot_table_name, 5)  # Preview 5 possible rewards

func convert_dungeon_id_to_loot_table_name(dungeon_id: String, difficulty: String) -> String:
	"""Convert dungeon ID and difficulty to loot table name"""
	# Convert dungeon selection to loot table naming convention
	var loot_table_name = ""
	
	match dungeon_id:
		"dragons_lair":
			loot_table_name = "dragon_dungeon"
		"giants_keep":
			loot_table_name = "giant_dungeon"
		"necromancer_tomb":
			loot_table_name = "necromancer_dungeon"
		"elemental_sanctum":
			loot_table_name = "elemental_dungeon"
		_:
			loot_table_name = "standard_dungeon"
	
	# Add difficulty suffix
	match difficulty.to_lower():
		"hard":
			loot_table_name += "_hard"
		"hell", "nightmare":
			loot_table_name += "_hell"
		# "normal" uses base name
	
	return loot_table_name

func display_rewards(rewards_preview: Array):
	"""Display reward preview - RULE 4: UI display only"""
	if not rewards_container:
		return
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	rewards_container.add_child(vbox)
	
	# Rewards header
	var header_label = Label.new()
	header_label.text = "🎁 Possible Rewards"
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.modulate = Color.YELLOW
	vbox.add_child(header_label)
	
	if rewards_preview.is_empty():
		var no_rewards_label = Label.new()
		no_rewards_label.text = "No reward preview available"
		no_rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_rewards_label.modulate = Color.GRAY
		vbox.add_child(no_rewards_label)
		return
	
	# Display reward items
	for reward in rewards_preview:
		var reward_item = create_reward_item(reward)
		vbox.add_child(reward_item)

func create_reward_item(reward_text: String) -> Control:
	"""Create a reward item display"""
	var item_hbox = HBoxContainer.new()
	item_hbox.add_theme_constant_override("separation", 5)
	
	# Reward icon (placeholder)
	var icon_label = Label.new()
	icon_label.text = "💎"
	icon_label.add_theme_font_size_override("font_size", 12)
	item_hbox.add_child(icon_label)
	
	# Reward text
	var reward_label = Label.new()
	reward_label.text = reward_text
	reward_label.add_theme_font_size_override("font_size", 11)
	item_hbox.add_child(reward_label)
	
	return item_hbox

func get_default_difficulty(dungeon_data: Dictionary) -> String:
	"""Get default difficulty for dungeon"""
	var difficulties = dungeon_data.get("difficulties", ["normal"])
	return difficulties[0] if not difficulties.is_empty() else "normal"

func get_element_color(element: String) -> Color:
	"""Get color for dungeon element"""
	match element.to_lower():
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.2, 0.6, 1.0)
		"earth": return Color(0.6, 0.4, 0.2)
		"air": return Color(0.8, 0.9, 1.0)
		"light": return Color(1.0, 1.0, 0.7)
		"dark": return Color(0.4, 0.2, 0.6)
		"nature": return Color(0.3, 0.7, 0.3)
		_: return Color.CYAN

func get_current_selection() -> Dictionary:
	"""Get current dungeon and difficulty selection"""
	return {
		"dungeon_id": current_dungeon_id,
		"difficulty": current_difficulty
	}
