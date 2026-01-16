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
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus and event_bus.has_signal("resources_updated") and event_bus.resources_updated.is_connected(_update_all_instances):
		event_bus.resources_updated.disconnect(_update_all_instances)
	
	print("ResourceDisplay: Instance destroyed, %d instances remaining" % _instances.size())

# === INITIALIZATION HELPERS ===

func _initialize_resource_manager():
	"""Get ResourceManager reference through SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		resource_manager = system_registry.get_system("ResourceManager")
		if resource_manager:
			print("ResourceDisplay: Connected to ResourceManager through SystemRegistry")
		else:
			print("ResourceDisplay: ResourceManager not found in SystemRegistry")
	else:
		print("ResourceDisplay: SystemRegistry not available")

func _setup_signal_connections():
	"""Connect to system signals through SystemRegistry (first instance only to avoid duplicates)"""
	if _instances.size() == 1:
		var system_registry = SystemRegistry.get_instance()
		if system_registry:
			var event_bus = system_registry.get_system("EventBus")
			if event_bus and event_bus.has_signal("resources_updated"):
				event_bus.resources_updated.connect(_update_all_instances)
				print("ResourceDisplay: Connected to EventBus.resources_updated")
			else:
				print("ResourceDisplay: EventBus or resources_updated signal not found")
		else:
			print("ResourceDisplay: SystemRegistry not available")
		var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
		if event_bus and event_bus.has_signal("resources_updated"):
			event_bus.resources_updated.connect(_update_all_instances)
			print("ResourceDisplay: Connected to EventBus.resources_updated signal")
		else:
			print("ResourceDisplay: Warning - EventBus.resources_updated signal not available")

func _setup_progression_signals():
	"""Connect to progression system signals for player level updates"""
	# For now, disable progression signals since we don't have ProgressionManager yet
	# TODO: Re-enable when ProgressionManager is implemented in SystemRegistry
	print("ResourceDisplay: Progression signals temporarily disabled")

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
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		print("ResourceDisplay: SystemRegistry not available")
		return
	
	var resource_mgr = system_registry.get_system("ResourceManager")
	if not resource_mgr:
		print("ResourceDisplay: Cannot update - ResourceManager not available")
		return
	
	# Update each resource display according to prompt architecture
	_update_player_level_display()
	_update_mana_display()
	_update_crystals_display()
	_update_energy_display()
	_update_tickets_display()
	_update_materials_count()

func _update_player_level_display():
	"""Update player level display (using ResourceManager)"""
	if not player_level_label:
		print("ResourceDisplay: PlayerLevelLabel is null - this should not happen!")
		return
		
	var player_level = 1
	var player_xp = 0
	var xp_to_next = 100
	
	# Get experience from ResourceManager instead of PlayerData
	var resource_mgr = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if resource_mgr:
		player_xp = resource_mgr.get_resource("experience")
		# Simple level calculation: every 1000 XP = 1 level
		player_level = max(1, int(player_xp / 1000) + 1)
		xp_to_next = (player_level * 1000) - player_xp
	
	# Format as "Level 5 (120/300 XP)"
	var level_text = "Level %d (%d/%d XP)" % [player_level, player_xp, xp_to_next]
	player_level_label.text = level_text

func _update_mana_display():
	"""Update mana display (primary currency per prompt architecture)"""
	if mana_label:
		var system_registry = SystemRegistry.get_instance()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var mana_value = resource_mgr.get_resource("mana") if resource_mgr else 0
		mana_label.text = "Mana: " + format_large_number(mana_value)

func _update_crystals_display():
	"""Update divine crystals display (premium currency)"""
	if crystal_label:
		var system_registry = SystemRegistry.get_instance()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var crystals_value = resource_mgr.get_resource("divine_crystals") if resource_mgr else 0
		crystal_label.text = "Crystals: " + str(crystals_value)

func _update_tickets_display():
	"""Update summon tickets display"""
	if tickets_label:
		var system_registry = SystemRegistry.get_instance()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var tickets_count = resource_mgr.get_resource("summon_tickets") if resource_mgr else 0
		tickets_label.text = "Tickets: " + str(tickets_count)

func _update_materials_count():
	"""Update materials count display"""
	if materials_count_label:
		var materials_total = _get_total_materials_count()
		materials_count_label.text = "(%d)" % materials_total

func _update_energy_display():
	"""Update energy display (stamina for battles)"""
	if energy_label:
		var system_registry = SystemRegistry.get_instance()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var energy_value = resource_mgr.get_resource("energy") if resource_mgr else 0
		var energy_limit = resource_mgr.get_resource_limit("energy") if resource_mgr else 100
		energy_label.text = "Energy: %d/%d" % [energy_value, energy_limit]

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
	var resource_mgr = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_mgr:
		print("ResourceDisplay: Cannot get materials count - ResourceManager not available")
		return 0
	
	var total = 0
	# Simple count of common materials for now
	var material_types = ["iron", "wood", "stone", "cloth", "crystal_shards"]
	
	for material_id in material_types:
		var count = resource_mgr.get_resource(material_id) if resource_mgr.has_method("get_resource") else 0
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
	"""Populate materials table through SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return

	var resource_mgr = system_registry.get_system("ResourceManager")
	if not resource_mgr:
		return
	
	# TODO: Implement get_all_materials method in ResourceManager
	# For now, show placeholder
	var placeholder_label = Label.new()
	placeholder_label.text = "Materials system integration in progress..."
	grid.add_child(placeholder_label)

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

func _get_player_resource(_resource_id: String) -> int:
	"""Get player resource through SystemRegistry pattern"""
	var system_registry = SystemRegistry.get_instance()
	if not system_registry:
		return 0

	var resource_mgr = system_registry.get_system("ResourceManager")
	if not resource_mgr:
		return 0

	# TODO: Implement proper player data access through SystemRegistry
	# For now return 0 as placeholder
	return 0

func _get_resource_from_manager(resource_id: String) -> int:
	"""Helper function to get resource from ResourceManager"""
	return _get_player_resource(resource_id)

# === DEBUG FUNCTIONS ===

func debug_print_resources():
	"""Debug helper to print all resource information"""
	if resource_manager:
		resource_manager.print_all_resources()
	else:
		print("ResourceDisplay: ResourceManager not available for debug")
