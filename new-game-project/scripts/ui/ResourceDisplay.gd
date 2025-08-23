# scripts/ui/ResourceDisplay.gd
extends HBoxContainer

# References to scene nodes
@onready var essence_label = $EssenceLabel
@onready var crystal_label = $CrystalLabel
@onready var energy_label = get_node_or_null("EnergyLabel")
@onready var tickets_label = get_node_or_null("TicketsLabel")
@onready var materials_button = get_node_or_null("MaterialsButton")
@onready var materials_count_label = get_node_or_null("MaterialsCountLabel")

func _ready():
	# Connect to GameManager signals
	if GameManager:
		GameManager.resources_updated.connect(_update_display)
	
	# Connect the materials button
	if materials_button:
		materials_button.pressed.connect(_show_materials_table)
		# Add hover effects
		materials_button.mouse_entered.connect(func(): 
			materials_button.modulate = Color(1.2, 1.2, 1.2))
		materials_button.mouse_exited.connect(func(): 
			materials_button.modulate = Color.WHITE)
	else:
		print("Warning: MaterialsButton not found!")
	
	_update_display()

func _update_display():
	if GameManager and GameManager.player_data:
		# Update divine essence
		if essence_label:
			var essence_value = GameManager.player_data.divine_essence
			if essence_value > 1000000000:  # If over 1 billion, format nicely
				essence_label.text = "Divine Essence: " + format_large_number(essence_value)
			else:
				essence_label.text = "Divine Essence: " + str(essence_value)
		
		# Update premium crystals
		if crystal_label:
			crystal_label.text = "Crystals: " + str(GameManager.player_data.premium_crystals)
		
		# Update energy (with regeneration info)
		if energy_label:
			GameManager.player_data.update_energy()  # Make sure it's current
			var energy_status = GameManager.player_data.get_energy_status()
			var energy_text = "Energy: %d/%d" % [energy_status.current, energy_status.max]
			
			# Add time to full energy if not at max
			if energy_status.current < energy_status.max:
				var minutes_to_full = energy_status.minutes_to_full
				if minutes_to_full < 60:
					energy_text += " (%dm)" % minutes_to_full
				else:
					var hours = minutes_to_full / 60
					energy_text += " (%dh %dm)" % [hours, minutes_to_full % 60]
			
			energy_label.text = energy_text
		
		# Update summon tickets
		if tickets_label:
			tickets_label.text = "Tickets: " + str(GameManager.player_data.summon_tickets)
		else:
			print("Warning: TicketsLabel not found for update")
		
		# Update materials count
		if materials_count_label:
			var total_count = _get_total_materials_count()
			materials_count_label.text = "(%d)" % total_count
		else:
			print("Warning: MaterialsCountLabel not found for update")

func format_large_number(number: int) -> String:
	"""Format large numbers for display (e.g., 1.5B instead of 1500000000)"""
	if number >= 1000000000:
		return "%.1fB" % (float(number) / 1000000000.0)
	elif number >= 1000000:
		return "%.1fM" % (float(number) / 1000000.0)
	elif number >= 1000:
		return "%.1fK" % (float(number) / 1000.0)
	else:
		return str(number)

func _get_total_materials_count() -> int:
	"""Get total count of all materials for summary display"""
	if not GameManager or not GameManager.player_data:
		return 0
	
	var total = 0
	
	# Count all powders - using loot.json terminology
	for powder_type in GameManager.player_data.powders:
		total += GameManager.player_data.powders[powder_type]
	
	# Count all relics
	for relic_type in GameManager.player_data.relics:
		total += GameManager.player_data.relics[relic_type]
	
	# Count awakening stones
	total += GameManager.player_data.awakening_stones
	
	return total

func _show_materials_table():
	"""Show materials in a proper table popup"""
	print("Materials button clicked - opening table")
	
	var popup = AcceptDialog.new()
	popup.title = "Awakening Materials Inventory"
	popup.size = Vector2(700, 500)
	popup.position = Vector2(100, 100)
	
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
	
	# Add materials to grid
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
	
	# Add powders - using loot.json terminology
	var elements = ["Fire", "Water", "Earth", "Lightning", "Light", "Dark"]
	for element in elements:
		var element_key = element.to_lower()
		
		# Low tier
		var low_count = GameManager.player_data.powders.get(element_key + "_powder_low", 0)
		if low_count > 0:
			_add_table_row(grid, "Powder (Low)", element, str(low_count))
		
		# Mid tier
		var mid_count = GameManager.player_data.powders.get(element_key + "_powder_mid", 0)
		if mid_count > 0:
			_add_table_row(grid, "Powder (Mid)", element, str(mid_count))
		
		# High tier
		var high_count = GameManager.player_data.powders.get(element_key + "_powder_high", 0)
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
