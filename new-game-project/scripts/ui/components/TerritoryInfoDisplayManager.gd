# scripts/ui/components/TerritoryInfoDisplayManager.gd
# Single responsibility: Display territory information UI
class_name TerritoryInfoDisplayManager extends Node

# Territory display signals
signal territory_display_refreshed

var territory_info_panel: Control
var current_territory: Territory

func initialize(info_panel: Control):
	"""Initialize with the territory info panel"""
	territory_info_panel = info_panel
	print("TerritoryInfoDisplayManager: Initialized")

func refresh_display(territory: Territory):
	"""Refresh territory information display - FOLLOWING RULE 4: UI ONLY"""
	current_territory = territory
	
	if not current_territory or not territory_info_panel:
		return
	
	# Clear existing territory info
	for child in territory_info_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create main territory info container
	var main_container = HBoxContainer.new()
	main_container.add_theme_constant_override("separation", 30)
	territory_info_panel.add_child(main_container)
	
	# Left side - Territory basic info
	var basic_info = create_territory_basic_info()
	main_container.add_child(basic_info)
	
	# Center - Current production breakdown
	var production_info = create_territory_production_info()
	main_container.add_child(production_info)
	
	# Right side - Territory bonuses and special effects
	var bonus_info = create_territory_bonus_info()
	main_container.add_child(bonus_info)
	
	territory_display_refreshed.emit()

func create_territory_basic_info() -> Control:
	"""Create basic territory information section"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	
	# Territory header
	var header_label = Label.new()
	header_label.text = "%s" % current_territory.name
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.modulate = Color.WHITE
	vbox.add_child(header_label)
	
	# Territory tier and element with styled background
	var tier_panel = Panel.new()
	var tier_style = StyleBoxFlat.new()
	tier_style.bg_color = get_element_color(current_territory.get_element_name())
	tier_style.corner_radius_top_left = 5
	tier_style.corner_radius_top_right = 5
	tier_style.corner_radius_bottom_left = 5
	tier_style.corner_radius_bottom_right = 5
	tier_panel.add_theme_stylebox_override("panel", tier_style)
	tier_panel.custom_minimum_size = Vector2(0, 35)
	vbox.add_child(tier_panel)
	
	var tier_label = Label.new()
	tier_label.text = "Tier %d %s Territory" % [current_territory.tier, current_territory.get_element_name()]
	tier_label.add_theme_font_size_override("font_size", 14)
	tier_label.modulate = Color.BLACK
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tier_panel.add_child(tier_label)
	
	# Status and level
	var status_label = Label.new()
	status_label.text = "Status: %s | Level: %d" % [
		"CONTROLLED" if current_territory.is_controlled_by_player() else "NEUTRAL",
		current_territory.territory_level
	]
	status_label.modulate = Color.CYAN
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)
	
	# Territory description
	var desc_label = Label.new()
	desc_label.text = get_territory_description(current_territory)
	desc_label.modulate = Color.LIGHT_GRAY
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(desc_label)
	
	return vbox

func create_territory_production_info() -> Control:
	"""Create territory production information section - RULE 5: Use SystemRegistry"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(350, 0)
	
	# Production header
	var header_label = Label.new()
	header_label.text = "Resource Generation"
	header_label.add_theme_font_size_override("font_size", 18)
	header_label.modulate = Color.CYAN
	vbox.add_child(header_label)
	
	# Get territory data through SystemRegistry - RULE 5 compliance
	var system_registry = SystemRegistry.get_instance()
	var base_generation = {}
	var total_generation = {}
	
	if system_registry:
		var territory_manager = system_registry.get_system("TerritoryManager")
		if territory_manager:
			base_generation = territory_manager.get_base_territory_generation(current_territory)
			total_generation = territory_manager.calculate_territory_passive_generation(current_territory)
		else:
			print("TerritoryInfoDisplayManager: TerritoryManager not found in SystemRegistry")
	
	# Fallback values if system not available
	if base_generation.is_empty():
		base_generation = {"mana": 25, "divine_crystals": 2, "energy": 15}
		total_generation = {"mana": 35, "divine_crystals": 3, "energy": 20}
	
	# Create generation display
	var generation_container = VBoxContainer.new()
	vbox.add_child(generation_container)
	
	# Show base vs enhanced generation
	for resource in ["mana", "divine_crystals", "energy"]:
		if base_generation.has(resource):
			var base_value = base_generation.get(resource, 0)
			var total_value = total_generation.get(resource, base_value)
			var bonus = total_value - base_value
			
			var resource_hbox = HBoxContainer.new()
			generation_container.add_child(resource_hbox)
			
			# Resource name
			var resource_label = Label.new()
			resource_label.text = resource.capitalize() + ":"
			resource_label.custom_minimum_size = Vector2(100, 0)
			resource_hbox.add_child(resource_label)
			
			# Base generation
			var base_label = Label.new()
			base_label.text = str(base_value)
			base_label.modulate = Color.GRAY
			resource_hbox.add_child(base_label)
			
			# Bonus (if any)
			if bonus > 0:
				var plus_label = Label.new()
				plus_label.text = " + "
				plus_label.modulate = Color.YELLOW
				resource_hbox.add_child(plus_label)
				
				var bonus_label = Label.new()
				bonus_label.text = str(bonus)
				bonus_label.modulate = Color.GREEN
				resource_hbox.add_child(bonus_label)
				
				var equals_label = Label.new()
				equals_label.text = " = "
				resource_hbox.add_child(equals_label)
				
				var total_label = Label.new()
				total_label.text = str(total_value) + "/hour"
				total_label.modulate = Color.CYAN
				resource_hbox.add_child(total_label)
			else:
				var per_hour_label = Label.new()
				per_hour_label.text = "/hour"
				resource_hbox.add_child(per_hour_label)
	
	return vbox

func create_territory_bonus_info() -> Control:
	"""Create territory bonus and special effects section"""
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	
	# Bonuses header
	var bonus_header = Label.new()
	bonus_header.text = "⭐ Territory Effects"
	bonus_header.add_theme_font_size_override("font_size", 16)
	bonus_header.modulate = Color.YELLOW
	vbox.add_child(bonus_header)
	
	# Element bonuses
	var element_bonus_label = Label.new()
	element_bonus_label.text = "Element Bonuses:"
	element_bonus_label.add_theme_font_size_override("font_size", 12)
	element_bonus_label.modulate = Color.CYAN
	vbox.add_child(element_bonus_label)
	
	var element_name = current_territory.get_element_name()
	var element_desc = Label.new()
	element_desc.text = get_element_bonus_description(element_name)
	element_desc.add_theme_font_size_override("font_size", 10)
	element_desc.modulate = Color.LIGHT_GRAY
	element_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	element_desc.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(element_desc)
	
	# Tier bonuses
	var tier_bonus_label = Label.new()
	tier_bonus_label.text = "Tier %d Benefits:" % current_territory.tier
	tier_bonus_label.add_theme_font_size_override("font_size", 12)
	tier_bonus_label.modulate = Color.CYAN
	vbox.add_child(tier_bonus_label)
	
	var tier_desc = Label.new()
	tier_desc.text = get_tier_bonus_description(current_territory.tier)
	tier_desc.add_theme_font_size_override("font_size", 10)
	tier_desc.modulate = Color.LIGHT_GRAY
	tier_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tier_desc.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(tier_desc)
	
	return vbox

# === UTILITY FUNCTIONS ===

func get_element_color(element_name: String) -> Color:
	"""Get color associated with territory element"""
	match element_name.to_lower():
		"fire": return Color(1.0, 0.4, 0.2, 0.8)
		"water": return Color(0.2, 0.6, 1.0, 0.8)
		"earth": return Color(0.6, 0.4, 0.2, 0.8)
		"air": return Color(0.8, 0.9, 1.0, 0.8)
		"light": return Color(1.0, 1.0, 0.7, 0.8)
		"dark": return Color(0.4, 0.2, 0.6, 0.8)
		"nature": return Color(0.3, 0.7, 0.3, 0.8)
		_: return Color(0.5, 0.5, 0.5, 0.8)

func get_territory_description(territory: Territory) -> String:
	"""Get detailed territory description"""
	var element = territory.get_element_name().to_lower()
	var tier = territory.tier
	
	var base_desc = ""
	match element:
		"fire": base_desc = "A volcanic region with intense heat and molten flows. Fire-aligned gods gain significant bonuses here."
		"water": base_desc = "A realm of rushing rivers and deep lakes. Water-aligned gods feel at home in this environment."
		"earth": base_desc = "Rocky mountains and solid ground provide stability. Earth-aligned gods are most effective here."
		_: base_desc = "A mystical territory with unique properties and elemental affinities."
	
	var tier_addition = ""
	match tier:
		1: tier_addition = " This is a basic territory with standard resource generation."
		2: tier_addition = " As a tier 2 territory, it offers improved resource diversity and better god efficiency."
		3: tier_addition = " This advanced tier 3 territory provides exceptional resources and maximum god potential."
		_: tier_addition = " A territory of moderate power and resource potential."
	
	return base_desc + tier_addition

func get_element_bonus_description(element_name: String) -> String:
	"""Get description of element bonuses"""
	match element_name.to_lower():
		"fire": return "• Fire gods: +50% efficiency\n• Generates heat-based crafting materials\n• Bonus combat power for defenders"
		"water": return "• Water gods: +50% efficiency\n• Enhanced healing and regeneration\n• Improved resource flow rates"
		"earth": return "• Earth gods: +50% efficiency\n• Generates rare minerals and stones\n• Increased territory stability"
		_: return "• Element gods: +25% efficiency\n• Generates elemental materials\n• Special affinity bonuses"

func get_tier_bonus_description(tier: int) -> String:
	"""Get description of tier bonuses"""
	match tier:
		1: return "• Basic resource generation\n• 1-2 role slots per type\n• Standard god efficiency"
		2: return "• Enhanced resource variety\n• 2-3 role slots per type\n• +25% base generation\n• Special materials access"
		3: return "• Premium resource generation\n• 3-4 role slots per type\n• +50% base generation\n• Rare materials and artifacts"
		_: return "• Moderate resource generation\n• Standard role slots\n• Basic territory benefits"
