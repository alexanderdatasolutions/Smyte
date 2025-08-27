# scripts/ui/ResourceDisplay.gd
# 
# ResourceDisplay manages the main resource UI shown across all game screens
# Displays: Mana (primary currency), Divine Crystals (premium), Energy (stamina), etc.
# 
# Architecture: Uses singleton pattern to sync all instances globally
# Data Source: GameManager.player_data via PlayerData.get_resource() method
#
extends HBoxContainer

# === SINGLETON PATTERN ===
# All ResourceDisplay instances sync updates globally when resources change
static var _instances: Array = []

# === UI ELEMENTS ===
# These correspond to nodes in ResourceDisplay.tscn
@onready var player_level_label: Label = null # Player level (new progression system) - will be created dynamically
@onready var mana_label: Label = $ManaLabel           # Primary currency (per prompt architecture)
@onready var crystal_label: Label = $CrystalLabel     # Premium currency  
@onready var energy_label: Label = $EnergyLabel       # Stamina for battles (regenerates)
@onready var tickets_label: Label = $TicketsLabel     # Summon tickets
@onready var materials_button: Button = $MaterialsButton           # Opens materials inventory
@onready var materials_count_label: Label = $MaterialsCountLabel   # Shows total materials count

# === SYSTEM REFERENCES ===
var resource_manager: Node = null  # Reference to ResourceManager for materials data

# === LIFECYCLE METHODS ===
	
func _ready():
	"""Initialize this ResourceDisplay instance"""
	print("ResourceDisplay: New instance created")
	
	# Add to instances list for global synchronization
	_instances.append(self)
	
	# Create player level label dynamically (MYTHOS ARCHITECTURE - robust system)
	_create_player_level_label()
	
	# Initialize ResourceManager reference
	_initialize_resource_manager()
	
	# Connect to global resource update signals (first instance only)
	_setup_signal_connections()
	
	# Connect to progression signals for player level updates
	_setup_progression_signals()
	
	# Setup UI interactions
	_setup_materials_button()
	
	# Perform initial display update
	call_deferred("_update_this_instance")

func _exit_tree():
	"""Clean up when leaving the scene tree"""
	# Remove from instances list
	_instances.erase(self)
	
	# Disconnect signals to prevent errors
	if GameManager and GameManager.resources_updated.is_connected(_update_all_instances):
		GameManager.resources_updated.disconnect(_update_all_instances)
		
	# Disconnect progression signals
	if GameManager and GameManager.progression_manager and GameManager.progression_manager.has_signal("player_leveled_up"):
		if GameManager.progression_manager.player_leveled_up.is_connected(_update_all_instances):
			GameManager.progression_manager.player_leveled_up.disconnect(_update_all_instances)
	
	print("ResourceDisplay: Instance destroyed, %d instances remaining" % _instances.size())

# === INITIALIZATION HELPERS ===

func _initialize_resource_manager():
	"""Get or create ResourceManager reference"""
	resource_manager = get_node("/root/ResourceManager") if has_node("/root/ResourceManager") else null
	
	if not resource_manager:
		# Create ResourceManager if it doesn't exist
		resource_manager = preload("res://scripts/systems/ResourceManager.gd").new()
		resource_manager.name = "ResourceManager"
		get_tree().root.add_child(resource_manager)
		print("ResourceDisplay: Created new ResourceManager instance")

func _setup_signal_connections():
	"""Connect to GameManager signals (first instance only to avoid duplicates)"""
	if _instances.size() == 1:
		if GameManager and GameManager.has_signal("resources_updated"):
			GameManager.resources_updated.connect(_update_all_instances)
			print("ResourceDisplay: Connected to GameManager.resources_updated signal")
		else:
			print("ResourceDisplay: Warning - GameManager.resources_updated signal not available")

func _setup_progression_signals():
	"""Connect to progression system signals for player level updates"""
	if not GameManager:
		return
		
	# Only connect once globally for all instances
	if _instances.size() > 1:
		return
		
	if GameManager.progression_manager and GameManager.progression_manager.has_signal("player_leveled_up"):
		if not GameManager.progression_manager.player_leveled_up.is_connected(_update_all_instances):
			GameManager.progression_manager.player_leveled_up.connect(_update_all_instances)
			print("ResourceDisplay: Connected to player level up signal")

func _setup_materials_button():
	"""Setup materials button interactions"""
	if materials_button:
		materials_button.pressed.connect(_show_materials_table)
		# Add hover effects for better UX
		materials_button.mouse_entered.connect(func(): materials_button.modulate = Color(1.2, 1.2, 1.2))
		materials_button.mouse_exited.connect(func(): materials_button.modulate = Color.WHITE)

func _create_player_level_label():
	"""Create player level label dynamically (MYTHOS ARCHITECTURE - robust design)"""
	# Try to find existing node first
	if has_node("PlayerLevelLabel"):
		player_level_label = $PlayerLevelLabel
		print("ResourceDisplay: Found existing PlayerLevelLabel")
		return
	
	# Create label dynamically and add to the beginning of the container
	player_level_label = Label.new()
	player_level_label.name = "PlayerLevelLabel"
	player_level_label.text = "Level 1 (0/100 XP)"
	player_level_label.add_theme_font_size_override("font_size", 14)
	
	# Add it as the first child (leftmost position)
	add_child(player_level_label)
	move_child(player_level_label, 0)
	
	print("ResourceDisplay: Created PlayerLevelLabel dynamically")

# === DISPLAY UPDATE METHODS ===

static func _update_all_instances():
	"""Update all ResourceDisplay instances when resources change globally"""
	for instance in _instances:
		if instance and is_instance_valid(instance):
			instance._update_this_instance()

func _update_this_instance():
	"""Update this specific instance's display with current resource values"""
	if not GameManager or not GameManager.player_data:
		print("ResourceDisplay: Cannot update - GameManager or PlayerData not available")
		return
	
	# Update each resource display according to prompt architecture
	_update_player_level_display()
	_update_mana_display()
	_update_crystals_display()
	_update_energy_display()
	_update_tickets_display()
	_update_materials_count()

func _update_player_level_display():
	"""Update player level display (new progression system)"""
	if not player_level_label:
		print("ResourceDisplay: PlayerLevelLabel is null - this should not happen!")
		return
		
	var player_level = 1
	var player_xp = 0
	var xp_to_next = 100
	
	if GameManager and GameManager.player_data and GameManager.progression_manager:
		# Get level from ProgressionManager (MYTHOS ARCHITECTURE)
		player_level = GameManager.progression_manager.calculate_level_from_experience(GameManager.player_data.player_experience)
		player_xp = GameManager.player_data.player_experience
		xp_to_next = GameManager.progression_manager.get_experience_to_next_level(player_level, player_xp)
	
	# Format as "Level 5 (120/300 XP)"
	var level_text = "Level %d (%d/%d XP)" % [player_level, player_xp, xp_to_next]
	player_level_label.text = level_text

func _update_mana_display():
	"""Update mana display (primary currency per prompt architecture)"""
	if mana_label:
		var mana_value = _get_player_resource("mana")
		mana_label.text = "Mana: " + format_large_number(mana_value)

func _update_crystals_display():
	"""Update divine crystals display (premium currency)"""
	if crystal_label:
		var crystals_value = _get_player_resource("divine_crystals")
		crystal_label.text = "Crystals: " + str(crystals_value)

func _update_tickets_display():
	"""Update summon tickets display"""
	if tickets_label:
		var tickets_count = _get_player_resource("summon_tickets")
		tickets_label.text = "Tickets: " + str(tickets_count)

func _update_materials_count():
	"""Update materials count display"""
	if materials_count_label:
		var total_count = _get_total_materials_count()
		materials_count_label.text = "(%d)" % total_count

func _update_energy_display():
	"""Update energy display with regeneration timer (stamina for battles)"""
	if not energy_label:
		return
		
	if not GameManager.player_data.has_method("update_energy"):
		energy_label.text = "Energy: N/A"
		print("ResourceDisplay: PlayerData missing update_energy method")
		return
	
	# Update energy regeneration and get current status
	GameManager.player_data.update_energy()
	var energy_status = GameManager.player_data.get_energy_status()
	var energy_text = "Energy: %d/%d" % [energy_status.current, energy_status.max]
	
	# Add regeneration timer if not at maximum
	if energy_status.current < energy_status.max:
		var minutes_to_full = energy_status.minutes_to_full
		if minutes_to_full < 60:
			energy_text += " (%dm)" % minutes_to_full
		else:
			var hours = minutes_to_full / 60
			energy_text += " (%dh %dm)" % [hours, minutes_to_full % 60]
	
	energy_label.text = energy_text

# === UTILITY FUNCTIONS ===

func format_large_number(number: int) -> String:
	"""Format large numbers with suffixes for better readability (1.5K, 2.3M, 1.1B)"""
	if number >= 1000000000:
		return "%.1fB" % (float(number) / 1000000000.0)
	elif number >= 1000000:
		return "%.1fM" % (float(number) / 1000000.0)
	elif number >= 1000:
		return "%.1fK" % (float(number) / 1000.0)
	else:
		return str(number)

func _get_total_materials_count() -> int:
	"""Calculate total count of all materials in player inventory"""
	if not resource_manager or not GameManager or not GameManager.player_data:
		print("ResourceDisplay: Cannot get materials count - missing dependencies")
		return 0
	
	var total = 0
	var all_materials = resource_manager.get_all_materials()
	
	# Count all materials that the player currently owns
	for resource_id in all_materials:
		var count = _get_player_resource(resource_id)
		total += count
	
	return total

# === MATERIALS TABLE UI ===

func _show_materials_table():
	"""Display comprehensive materials inventory in a popup window"""
	if not resource_manager:
		push_error("ResourceDisplay: ResourceManager not available for materials table")
		return
	
	print("ResourceDisplay: Opening materials inventory table")
	
	# Create popup dialog window
	var popup = AcceptDialog.new()
	popup.title = "Materials Inventory"
	popup.size = Vector2(700, 500)
	popup.position = Vector2(100, 100)
	
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)
	
	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	# Create table using GridContainer
	var grid = GridContainer.new()
	grid.columns = 4  # Resource Name, Category, Element/Type, Amount
	margin.add_child(grid)
	
	# Add headers
	_add_table_header(grid, "Resource")
	_add_table_header(grid, "Category")
	_add_table_header(grid, "Element/Type")
	_add_table_header(grid, "Amount")
	
	# Add materials dynamically
	_populate_materials_table(grid)
	
	# Add to scene and show
	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func(): popup.queue_free())

func _add_table_header(grid: GridContainer, text: String):
	"""Add a header to the materials table"""
	var header = Label.new()
	header.text = text
	header.add_theme_stylebox_override("normal", _create_header_style())
	grid.add_child(header)

func _populate_materials_table(grid: GridContainer):
	"""Populate materials table completely dynamically from ResourceManager"""
	if not GameManager or not GameManager.player_data:
		return
	
	var all_materials = resource_manager.get_all_materials()
	
	# Sort materials by category and name for better organization
	var sorted_materials = []
	for resource_id in all_materials:
		var resource_info = all_materials[resource_id]
		var player_count = _get_player_resource(resource_id)
		
		# Only show materials the player actually has (configurable)
		if player_count > 0:
			sorted_materials.append({
				"id": resource_id,
				"info": resource_info,
				"count": player_count
			})
	
	# Sort by category then by name
	sorted_materials.sort_custom(func(a, b):
		var cat_a = a.info.get("category", "unknown")
		var cat_b = b.info.get("category", "unknown")
		if cat_a != cat_b:
			return cat_a < cat_b
		return a.info.get("name", a.id) < b.info.get("name", b.id)
	)
	
	# Add sorted materials to grid
	for material_data in sorted_materials:
		_add_material_row(grid, material_data)

func _add_material_row(grid: GridContainer, material_data: Dictionary):
	"""Add a material row to the grid"""
	var resource_info = material_data.info
	var count = material_data.count
	
	# Name
	var name_label = Label.new()
	name_label.text = resource_info.get("name", material_data.id.capitalize().replace("_", " "))
	grid.add_child(name_label)
	
	# Category
	var category_label = Label.new()
	category_label.text = resource_info.get("category", "unknown").replace("_", " ").capitalize()
	grid.add_child(category_label)
	
	# Element/Type info
	var type_label = Label.new()
	var element = resource_info.get("element", "")
	var tier = resource_info.get("tier", "")
	var rarity = resource_info.get("rarity", "")
	
	var type_text = ""
	if element != "":
		type_text = element.capitalize()
	elif rarity != "":
		type_text = rarity.capitalize()
	elif tier != "":
		type_text = tier.capitalize()
	else:
		type_text = "General"
	
	type_label.text = type_text
	grid.add_child(type_label)
	
	# Amount
	var amount_label = Label.new()
	amount_label.text = str(count)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Color code based on amount
	if count == 0:
		amount_label.modulate = Color.GRAY
	elif count >= 1000:
		amount_label.modulate = Color.GREEN
	elif count >= 100:
		amount_label.modulate = Color.YELLOW
	
	grid.add_child(amount_label)

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

# === RESOURCE DATA ACCESS ===

func _get_player_resource(resource_id: String) -> int:
	"""Get resource amount from PlayerData using the modular resource system (prompt architecture)"""
	if not GameManager or not GameManager.player_data:
		print("ResourceDisplay: GameManager or PlayerData not available")
		return 0
	
	# Use PlayerData.get_resource() as defined in prompt architecture
	if GameManager.player_data.has_method("get_resource"):
		return GameManager.player_data.get_resource(resource_id)
	
	print("ResourceDisplay: ERROR - PlayerData missing get_resource method (required by prompt architecture)")
	return 0

# === DEBUG FUNCTIONS ===

func debug_print_resources():
	"""Debug helper to print all resource information"""
	if resource_manager:
		resource_manager.print_all_resources()
	else:
		print("ResourceDisplay: ResourceManager not available for debug")
