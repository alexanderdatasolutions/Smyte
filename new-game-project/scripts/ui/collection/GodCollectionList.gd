class_name GodCollectionList
extends Control

"""
GodCollectionList.gd - Enhanced god collection list component
RULE 1: Stays under 300 lines by focusing on list display only
RULE 2: Single responsibility - displays gods in a filterable list
RULE 4: Read-only display - no data modification
RULE 5: SystemRegistry for all system access

Features:
- Rich god cards with stats preview
- Multiple sorting options (power, level, tier, element, name)
- Advanced filtering (tier, element, role, owned status)
- Efficient scrolling with large collections
"""

signal god_selected(god_id: String)
signal god_action_requested(action: String, god_id: String, data: Dictionary)

# Core systems
var collection_manager
var god_manager

# UI References
var main_container: VBoxContainer
var sort_container: HBoxContainer
var scroll_container: ScrollContainer
var god_grid: GridContainer

# State
enum SortType { POWER, LEVEL, TIER, ELEMENT, NAME }
var current_sort: SortType = SortType.POWER
var sort_ascending: bool = false
var current_filters: Dictionary = {}

# UI Components
var sort_buttons: Array = []
var direction_button: Button

func _ready():
	print("GodCollectionList: Initializing god collection list...")
	_init_systems()
	_setup_ui()
	# Wait a frame for UI to be fully set up before refreshing
	await get_tree().process_frame
	refresh_display()

func _init_systems():
	"""Initialize required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("GodCollectionList: SystemRegistry not available!")
		return
		
	collection_manager = registry.get_system("CollectionManager")
	god_manager = registry.get_system("CollectionManager")
	
	if not collection_manager:
		push_error("GodCollectionList: CollectionManager not found!")
	if not god_manager:
		push_error("GodCollectionList: CollectionManager not found!")

func _setup_ui():
	"""Setup the UI layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Main container
	main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Sort controls
	_setup_sort_controls()
	
	# God list
	_setup_god_list()

func _setup_sort_controls():
	"""Setup sorting control buttons"""
	sort_container = HBoxContainer.new()
	sort_container.name = "SortContainer"
	sort_container.custom_minimum_size = Vector2(0, 40)
	main_container.add_child(sort_container)
	
	# Sort type buttons
	var sort_options = [
		{"text": "Power", "type": SortType.POWER},
		{"text": "Level", "type": SortType.LEVEL},
		{"text": "Tier", "type": SortType.TIER},
		{"text": "Element", "type": SortType.ELEMENT},
		{"text": "Name", "type": SortType.NAME}
	]
	
	for option in sort_options:
		var button = Button.new()
		button.text = option.text
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(80, 30)
		# Use wrapper function to handle toggled signal correctly
		button.toggled.connect(_create_sort_toggle_handler(option.type))
		sort_container.add_child(button)
		sort_buttons.append(button)
	
	# Set initial sort button (but defer to avoid early trigger)
	if sort_buttons.size() > 0:
		# Use call_deferred to avoid triggering during initialization
		sort_buttons[0].set_pressed_no_signal(true)
	
	# Direction button
	direction_button = Button.new()
	direction_button.text = "↓" if not sort_ascending else "↑"
	direction_button.custom_minimum_size = Vector2(40, 30)
	direction_button.pressed.connect(_on_sort_direction_pressed)
	sort_container.add_child(direction_button)

func _setup_god_list():
	"""Setup the scrollable god grid"""
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(scroll_container)
	
	god_grid = GridContainer.new()
	god_grid.name = "GodGrid"
	god_grid.columns = 3  # Adjust based on card size
	scroll_container.add_child(god_grid)

func refresh_display():
	"""Refresh the god list display - RULE 4: Read-only data access"""
	print("GodCollectionList: Refreshing display...")
	
	if not collection_manager:
		return
	
	# Make sure UI is ready
	if not god_grid:
		print("GodCollectionList: god_grid not ready yet, skipping refresh")
		return
	
	# Clear existing cards
	for child in god_grid.get_children():
		child.queue_free()
	
	# Get gods from collection manager
	var gods_result = collection_manager.get_owned_gods()
	if not gods_result.success:
		print("GodCollectionList: Failed to get owned gods: ", gods_result.error)
		return
	
	var gods = gods_result.data
	
	# Apply current filters
	gods = _apply_filters(gods)
	
	# Sort gods
	gods = _sort_gods(gods)
	
	# Create god cards
	for god in gods:
		var card = _create_god_card(god)
		if card:
			god_grid.add_child(card)
	
	print("GodCollectionList: Displayed ", gods.size(), " gods")

func apply_filters(filters: Dictionary):
	"""Apply new filters and refresh display"""
	print("GodCollectionList: Applying filters: ", filters)
	current_filters = filters
	refresh_display()

func _apply_filters(gods: Array) -> Array:
	"""Apply current filters to god list"""
	if current_filters.is_empty():
		return gods
	
	var filtered_gods = []
	
	for god in gods:
		var include = true
		
		# Filter by tier
		if current_filters.has("tier") and current_filters.tier != "":
			if god.get("tier", 0) != int(current_filters.tier):
				include = false
		
		# Filter by element
		if current_filters.has("element") and current_filters.element != "":
			if god.get("element", "") != current_filters.element:
				include = false
		
		# Filter by role
		if current_filters.has("role") and current_filters.role != "":
			if god.get("assigned_role", "") != current_filters.role:
				include = false
		
		# Filter by awakening status
		if current_filters.has("awakened") and current_filters.awakened != "all":
			var is_awakened = god.get("awakening_level", 0) > 0
			if current_filters.awakened == "awakened" and not is_awakened:
				include = false
			elif current_filters.awakened == "unawakened" and is_awakened:
				include = false
		
		if include:
			filtered_gods.append(god)
	
	return filtered_gods

func _sort_gods(gods: Array) -> Array:
	"""Sort gods based on current sort settings"""
	gods.sort_custom(_compare_gods)
	return gods

func _compare_gods(a: Dictionary, b: Dictionary) -> bool:
	"""Compare two gods for sorting"""
	var value_a
	var value_b
	
	match current_sort:
		SortType.POWER:
			value_a = a.get("total_power", 0)
			value_b = b.get("total_power", 0)
		SortType.LEVEL:
			value_a = a.get("level", 1)
			value_b = b.get("level", 1)
		SortType.TIER:
			value_a = a.get("tier", 1)
			value_b = b.get("tier", 1)
		SortType.ELEMENT:
			value_a = a.get("element", "")
			value_b = b.get("element", "")
		SortType.NAME:
			value_a = a.get("name", "")
			value_b = b.get("name", "")
		_:
			return false
	
	if sort_ascending:
		return value_a < value_b
	else:
		return value_a > value_b

func _create_god_card(god: Dictionary):
	"""Create a rich god card with beautiful styling like the original collection screen"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	card.name = "GodCard_" + god.get("id", "")
	
	# Beautiful tier-based styling
	var tier = god.get("tier", 1)
	var style = StyleBoxFlat.new()
	style.bg_color = _get_subtle_tier_color(tier)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = _get_tier_border_color(tier)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Create main layout with proper margins
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	# God image (compact but beautiful)
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Try to load god sprite
	var god_texture = _get_god_sprite(god.get("id", ""))
	if god_texture:
		god_image.texture = god_texture
		vbox.add_child(god_image)
	else:
		# Beautiful placeholder with tier color
		var placeholder = ColorRect.new()
		placeholder.color = _get_tier_border_color(tier)
		placeholder.custom_minimum_size = Vector2(48, 48)
		vbox.add_child(placeholder)
	
	# God name (beautiful typography)
	var name_label = Label.new()
	name_label.text = god.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier (compact, SW style)
	var level_label = Label.new()
	level_label.text = "Lv.%d %s" % [god.get("level", 1), _get_tier_short_name(tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Element and power (compact with emojis)
	var info_label = Label.new()
	var element_value = god.get("element", 0)
	var power_value = god.get("total_power", 0)
	info_label.text = "%s P:%d" % [_get_element_emoji(element_value), power_value]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(info_label)
	
	# Make clickable with invisible button
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_god_card_clicked.bind(god.get("id", "")))
	card.add_child(button)
	
	return card

func _on_sort_type_toggled(button_pressed: bool, sort_type: SortType):
	"""Handle sort type button toggle"""
	if not button_pressed:
		return  # Ignore button release
		
	print("GodCollectionList: Sort type changed to: ", sort_type)
	current_sort = sort_type
	
	# Update button states - only this button should be pressed
	for i in range(sort_buttons.size()):
		var button_type = [SortType.POWER, SortType.LEVEL, SortType.TIER, SortType.ELEMENT, SortType.NAME][i]
		sort_buttons[i].button_pressed = (button_type == sort_type)
	
	refresh_display()

# Create a wrapper function to handle the toggled signal correctly
func _create_sort_toggle_handler(sort_type: SortType) -> Callable:
	return func(button_pressed: bool):
		_on_sort_type_toggled(button_pressed, sort_type)

func _on_sort_direction_pressed():
	"""Handle sort direction button press"""
	sort_ascending = not sort_ascending
	direction_button.text = "↓" if not sort_ascending else "↑"
	print("GodCollectionList: Sort direction changed to: ", "ascending" if sort_ascending else "descending")
	refresh_display()

func _on_god_card_input(event: InputEvent, god_id: String):
	"""Handle god card input events"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("GodCollectionList: God card clicked: ", god_id)
			god_selected.emit(god_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("GodCollectionList: God card right-clicked: ", god_id)
			god_action_requested.emit("context_menu", god_id, {})

func _get_element_name(element_id) -> String:
	"""Convert integer element ID to string name"""
	if element_id is int:
		match element_id:
			0: return "fire"
			1: return "water"
			2: return "earth"
			3: return "lightning"
			4: return "light"
			5: return "dark"
			_: return "unknown"
	else:
		return str(element_id)

func _get_subtle_tier_color(tier: int) -> Color:
	"""Get subtle background colors for tiers"""
	match tier:
		1:  # COMMON
			return Color(0.25, 0.25, 0.25, 0.7)  # Dark gray
		2:  # RARE
			return Color(0.2, 0.3, 0.2, 0.7)     # Dark green
		3:  # EPIC
			return Color(0.3, 0.2, 0.4, 0.7)     # Dark purple
		4:  # LEGENDARY
			return Color(0.4, 0.3, 0.1, 0.7)     # Dark gold
		_:
			return Color(0.2, 0.2, 0.3, 0.7)

func _get_tier_border_color(tier: int) -> Color:
	"""Get border colors for tiers"""
	match tier:
		1:  # COMMON
			return Color(0.5, 0.5, 0.5, 0.8)     # Gray
		2:  # RARE
			return Color(0.4, 0.8, 0.4, 1.0)     # Green
		3:  # EPIC
			return Color(0.7, 0.4, 1.0, 1.0)     # Purple
		4:  # LEGENDARY
			return Color(1.0, 0.8, 0.2, 1.0)     # Gold
		_:
			return Color(0.6, 0.6, 0.6, 0.8)

func _get_tier_short_name(tier: int) -> String:
	"""Get short tier names for compact display"""
	match tier:
		1: return "★"      # COMMON
		2: return "★★"     # RARE  
		3: return "★★★"    # EPIC
		4: return "★★★★"   # LEGENDARY
		_: return "?"

func _get_element_emoji(element: int) -> String:
	"""Get element emojis for compact display"""
	match element:
		0: return "🔥"  # FIRE
		1: return "💧"  # WATER
		2: return "🌍"  # EARTH
		3: return "⚡"  # LIGHTNING
		4: return "☀️"  # LIGHT
		5: return "🌙"  # DARK
		_: return "?"

func _get_god_sprite(god_id: String) -> Texture2D:
	"""Load god sprite texture"""
	# Try to load from assets/gods/ folder
	var sprite_path = "res://assets/gods/" + god_id + ".png"
	if ResourceLoader.exists(sprite_path):
		return load(sprite_path)
	
	# Try alternative paths
	sprite_path = "res://assets/gods/" + god_id + ".jpg"
	if ResourceLoader.exists(sprite_path):
		return load(sprite_path)
	
	# No sprite found
	return null

func _on_god_card_clicked(god_id: String):
	"""Handle god card click"""
	print("GodCollectionList: God card clicked: ", god_id)
	god_selected.emit(god_id)
