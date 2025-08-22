# scripts/ui/ResourceDisplay.gd
extends HBoxContainer

@onready var essence_label = $EssenceLabel
var crystal_label: Label = null
var tickets_label: Label = null
var materials_label: Label = null
var materials_button: Button = null

func _ready():
	# Ensure this container doesn't block mouse input to its children
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Try to get existing labels from the scene first
	setup_resource_labels()
	
	# Connect to GameManager signals for modular communication
	if GameManager:
		GameManager.resources_updated.connect(_update_display)
	
	_update_display()

func setup_resource_labels():
	# Try to find existing CrystalLabel in the scene
	if has_node("CrystalLabel"):
		crystal_label = $CrystalLabel
	
	# Create additional resource displays for new currencies
	create_additional_resource_displays()

func create_additional_resource_displays():
	# Only create if they don't exist
	if crystal_label == null:
		# Add separator
		var separator1 = Label.new()
		separator1.text = " | "
		separator1.add_theme_color_override("font_color", Color.GRAY)
		add_child(separator1)
		
		# Add crystals display
		crystal_label = Label.new()
		crystal_label.text = "Crystals: 0"
		crystal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(crystal_label)
	
	# Add summon tickets
	if tickets_label == null:
		var separator2 = Label.new()
		separator2.text = " | "
		separator2.add_theme_color_override("font_color", Color.GRAY)
		add_child(separator2)
		
		tickets_label = Label.new()
		tickets_label.text = "Tickets: 0"
		tickets_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tickets_label)
	
	# Add ascension materials with table display
	if materials_label == null:
		var separator3 = Label.new()
		separator3.text = " | "
		separator3.add_theme_color_override("font_color", Color.GRAY)
		add_child(separator3)
		
		# Create a clickable button that opens a materials table
		materials_button = Button.new()
		materials_button.text = "Materials"
		materials_button.flat = false  # Make it clearly visible as a button
		materials_button.custom_minimum_size = Vector2(80, 25)  # Ensure minimum size
		materials_button.disabled = false  # Ensure it's not disabled
		materials_button.mouse_filter = Control.MOUSE_FILTER_PASS  # Ensure it receives mouse events
		materials_button.focus_mode = Control.FOCUS_ALL  # Allow focus
		materials_button.pressed.connect(_show_materials_table)
		# Also try gui_input as a fallback
		materials_button.gui_input.connect(_on_materials_button_input)
		# Add styling to make it stand out and clearly clickable
		materials_button.add_theme_color_override("font_color", Color.WHITE)
		materials_button.add_theme_color_override("font_hover_color", Color.YELLOW)
		materials_button.add_theme_color_override("font_pressed_color", Color.GREEN)
		# Add hover effect
		materials_button.mouse_entered.connect(func(): 
			print("Mouse entered materials button")
			materials_button.modulate = Color(1.2, 1.2, 1.2)
		)
		materials_button.mouse_exited.connect(func(): 
			print("Mouse exited materials button")
			materials_button.modulate = Color.WHITE
		)
		print("Created materials button")  # Debug
		add_child(materials_button)
		
		# Keep the label for compatibility but make it a small summary
		materials_label = Label.new()
		materials_label.text = "(0)"
		materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		materials_label.add_theme_color_override("font_color", Color.GRAY)
		add_child(materials_label)

func _update_display():
	if GameManager and GameManager.player_data:
		# Update essence
		if essence_label:
			essence_label.text = "Divine Essence: " + str(GameManager.player_data.divine_essence)
		
		# Update premium crystals
		if crystal_label:
			crystal_label.text = "Crystals: " + str(GameManager.player_data.premium_crystals)
		
		# Update summon tickets
		if tickets_label:
			tickets_label.text = "Tickets: " + str(GameManager.player_data.summon_tickets)
		
		# Update awakening materials (show count summary)
		if materials_label:
			var total_count = _get_total_materials_count()
			materials_label.text = "(%d)" % total_count

func _get_total_materials_count() -> int:
	"""Get total count of all materials for summary display"""
	if not GameManager or not GameManager.player_data:
		return 0
	
	var total = 0
	
	# Count all powders
	for powder_type in GameManager.player_data.essences:
		total += GameManager.player_data.essences[powder_type]
	
	# Count all relics
	for relic_type in GameManager.player_data.relics:
		total += GameManager.player_data.relics[relic_type]
	
	# Count awakening stones
	total += GameManager.player_data.awakening_stones
	
	return total

func _show_materials_table():
	"""Show materials in a proper table popup"""
	print("=== MATERIALS BUTTON CLICKED SUCCESSFULLY ===")
	print("Materials button clicked - opening table")
	
	# Simple test first - just show a basic popup
	var popup = AcceptDialog.new()
	popup.title = "Materials Test"
	popup.dialog_text = "Button is working! Materials count: " + str(_get_total_materials_count())
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())
	
	return  # Exit early for testing
	
	# Original table code (disabled for testing)
	popup = AcceptDialog.new()
	popup.title = "Awakening Materials Inventory"
	popup.size = Vector2(700, 500)
	popup.position = Vector2(100, 100)  # Set explicit position
	
	# Create main container with margins
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	# Add some padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	# Create table using GridContainer
	var grid = GridContainer.new()
	grid.columns = 3
	margin.add_child(grid)
	
	# Add headers
	var header1 = Label.new()
	header1.text = "Material Type"
	header1.add_theme_stylebox_override("normal", _create_header_style())
	grid.add_child(header1)
	
	var header2 = Label.new()
	header2.text = "Element/Pantheon"
	header2.add_theme_stylebox_override("normal", _create_header_style())
	grid.add_child(header2)
	
	var header3 = Label.new()
	header3.text = "Amount"
	header3.add_theme_stylebox_override("normal", _create_header_style())
	grid.add_child(header3)
	
	# Add powder entries
	_add_materials_to_grid(grid)
	
	# Add to scene and show
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func _create_header_style() -> StyleBoxFlat:
	"""Create header style for table"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color.WHITE
	return style

func _add_materials_to_grid(grid: GridContainer):
	"""Add all materials to the grid table"""
	if not GameManager or not GameManager.player_data:
		return
	
	# Add powders
	var elements = ["Fire", "Water", "Earth", "Lightning", "Light", "Dark"]
	for element in elements:
		var element_key = element.to_lower()
		
		# Low tier
		var low_count = GameManager.player_data.essences.get(element_key + "_powder_low", 0)
		if low_count > 0:
			_add_table_row(grid, "Powder (Low)", element, str(low_count))
		
		# Mid tier
		var mid_count = GameManager.player_data.essences.get(element_key + "_powder_mid", 0)
		if mid_count > 0:
			_add_table_row(grid, "Powder (Mid)", element, str(mid_count))
		
		# High tier
		var high_count = GameManager.player_data.essences.get(element_key + "_powder_high", 0)
		if high_count > 0:
			_add_table_row(grid, "Powder (High)", element, str(high_count))
	
	# Add relics
	var pantheons = ["Greek", "Norse", "Egyptian", "Hindu", "Celtic", "Japanese", "Aztec"]
	for pantheon in pantheons:
		var pantheon_key = pantheon.to_lower() + "_relics"
		var count = GameManager.player_data.relics.get(pantheon_key, 0)
		if count > 0:
			_add_table_row(grid, "Relics", pantheon, str(count))
	
	# Add awakening stones
	if GameManager.player_data.awakening_stones > 0:
		_add_table_row(grid, "Awakening Stones", "Universal", str(GameManager.player_data.awakening_stones))

func _add_table_row(grid: GridContainer, material_type: String, element_pantheon: String, amount: String):
	"""Add a row to the materials table"""
	var type_label = Label.new()
	type_label.text = material_type
	grid.add_child(type_label)
	
	var element_label = Label.new()
	element_label.text = element_pantheon
	grid.add_child(element_label)
	
	var amount_label = Label.new()
	amount_label.text = amount
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(amount_label)


func _get_powder_breakdown() -> Dictionary:
	"""Get detailed powder breakdown by tier following Summoners War style"""
	var breakdown = {"low": 0, "mid": 0, "high": 0, "by_element": {}}
	
	if not GameManager or not GameManager.player_data:
		return breakdown
	
	# Initialize element tracking
	var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
	for element in elements:
		breakdown.by_element[element] = {"low": 0, "mid": 0, "high": 0}
	
	# Count powders by type
	for powder_type in GameManager.player_data.essences:
		var amount = GameManager.player_data.essences[powder_type]
		if amount <= 0:
			continue
			
		# Parse powder type (e.g., "fire_powder_low")
		var parts = powder_type.split("_")
		if parts.size() >= 3 and parts[1] == "powder":
			var element = parts[0]
			var tier = parts[2]  # low, mid, high
			
			# Add to tier totals
			if tier in breakdown:
				breakdown[tier] += amount
			
			# Add to element breakdown
			if element in breakdown.by_element and tier in breakdown.by_element[element]:
				breakdown.by_element[element][tier] += amount
	
	return breakdown

func _get_relic_breakdown() -> Dictionary:
	"""Get detailed relic breakdown by pantheon"""
	var breakdown = {"total": 0, "by_pantheon": {}}
	
	if not GameManager or not GameManager.player_data:
		return breakdown
	
	for relic_type in GameManager.player_data.relics:
		var amount = GameManager.player_data.relics[relic_type]
		if amount <= 0:
			continue
			
		breakdown.total += amount
		
		# Parse relic type (e.g., "greek_relics")
		var parts = relic_type.split("_")
		if parts.size() >= 2:
			var pantheon = parts[0]
			if not breakdown.by_pantheon.has(pantheon):
				breakdown.by_pantheon[pantheon] = 0
			breakdown.by_pantheon[pantheon] += amount
	
	return breakdown

func _on_materials_button_input(event: InputEvent):
	"""Handle direct input on materials button as fallback"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("Materials button clicked via input event")
			_show_materials_table()
