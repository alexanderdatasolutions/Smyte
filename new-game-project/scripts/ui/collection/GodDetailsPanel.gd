class_name GodDetailsPanel
extends Control

"""
GodDetailsPanel.gd - Enhanced god details display panel
RULE 1: Stays under 300 lines by focusing on display only
RULE 2: Single responsibility - displays detailed god information
RULE 4: Read-only display with system delegation for actions
RULE 5: SystemRegistry for all system access

Features:
	pass
- Comprehensive god stats and information
- Equipment display and management interface
- Role assignment controls
- Action buttons (level up, evolve, etc.)
- Skills and abilities overview
"""

signal god_action_requested(action: String, god_id: String, data: Dictionary)

# Core systems
var god_manager
var equipment_manager
var awakening_system

# UI References
var main_container: VBoxContainer
var scroll_container: ScrollContainer
var content_container: VBoxContainer

# Current state
var current_god_id: String = ""
var current_god_data: Dictionary = {}

func _ready():
	_init_systems()
	_setup_ui()
	_show_no_selection()

func _init_systems():
	"""Initialize required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("GodDetailsPanel: SystemRegistry not available!")
		return
		
	god_manager = registry.get_system("CollectionManager")
	equipment_manager = registry.get_system("EquipmentManager")
	# awakening_system = registry.get_system("AwakeningSystem")  # Not implemented yet
	
	if not god_manager:
		push_error("GodDetailsPanel: CollectionManager not found!")
	if not equipment_manager:
		push_error("GodDetailsPanel: EquipmentManager not found!")
	# if not awakening_system:
	#	push_error("GodDetailsPanel: AwakeningSystem not found!")

func _setup_ui():
	"""Setup the UI layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Ensure panel is visible
	visible = true
	modulate = Color.WHITE
	
	# Main scrollable container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.visible = true
	add_child(scroll_container)
	
	# Content container
	content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.custom_minimum_size = Vector2(300, 0)
	content_container.add_theme_constant_override("separation", 10)
	content_container.visible = true
	scroll_container.add_child(content_container)

func display_god(god_id: String):
	"""Display detailed information for a specific god - RULE 4: Read-only data access"""
	
	if not god_manager:
		return
	
	current_god_id = god_id
	
	# Get god data
	var god = god_manager.get_god_by_id(god_id)
	if not god:
		_show_error("Failed to load god data")
		return
	
	# Convert God object to dictionary format for UI compatibility
	current_god_data = {
		"id": god.id,
		"template_id": god.template_id,
		"name": god.name,
		"pantheon": god.pantheon,
		"element": god.element,
		"tier": god.tier,
		"level": god.level,
		"experience": god.experience,
		"hp": god.base_hp,
		"attack": god.base_attack,
		"defense": god.base_defense,
		"speed": god.base_speed,
		"total_power": GodCalculator.get_combat_power(god),
		"stationed_territory": god.stationed_territory,
		"equipped_skin_id": god.equipped_skin_id,
		"abilities": god.active_abilities
	}
	_build_god_details()

func clear_display():
	"""Clear the current display"""
	current_god_id = ""
	current_god_data = {}
	_show_no_selection()

func refresh_current_display():
	"""Refresh the current god's display"""
	if current_god_id != "":
		display_god(current_god_id)

func _show_no_selection():
	"""Show the no selection message"""
	_clear_content()
	
	var no_selection_label: Label = Label.new()
	no_selection_label.text = "Select a god to view details"
	no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_selection_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(no_selection_label)

func _show_error(error_message: String):
	"""Show an error message"""
	_clear_content()
	
	var error_label: Label = Label.new()
	error_label.text = "Error: " + error_message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(error_label)

func _clear_content():
	"""Clear all content from the container"""
	for child in content_container.get_children():
		child.queue_free()

func _build_god_details():
	"""Build the detailed god information display with beautiful styling"""
	
	_clear_content()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	
	# Create scrollable content container for beautiful detailed view
	var details_scroll: ScrollContainer = ScrollContainer.new()
	details_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(details_scroll)
	
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	details_scroll.add_child(content)
	
	
	# God Image with beautiful styling
	var image_container: TextureRect = TextureRect.new()
	image_container.custom_minimum_size = Vector2(200, 200)
	image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Load god image
	var god_texture = _get_god_sprite(current_god_data.get("id", ""))
	if god_texture:
		image_container.texture = god_texture
		content.add_child(image_container)
	else:
		# Beautiful fallback - create a colored rectangle with tier styling
		var placeholder: ColorRect = ColorRect.new()
		placeholder.color = GodUIHelpers.get_tier_border_color((current_god_data.get("tier", 1) - 1) as God.TierType)
		placeholder.custom_minimum_size = Vector2(200, 200)
		content.add_child(placeholder)
	
	
	# Basic Info Section with tier-colored header
	var info_section: VBoxContainer = VBoxContainer.new()
	var info_title: Label = Label.new()
	info_title.text = "═══ " + current_god_data.get("name", "Unknown").to_upper() + " ═══"
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 18)
	info_title.add_theme_color_override("font_color", GodUIHelpers.get_tier_border_color((current_god_data.get("tier", 1) - 1) as God.TierType))
	info_section.add_child(info_title)
	
	var basic_info: Label = Label.new()
	basic_info.text = """Pantheon: %s
Element: %s
Tier: %s  
Level: %d
Power: %d""" % [
		current_god_data.get("pantheon", "Unknown"), GodUIHelpers.get_element_name(current_god_data.get("element", 0) as God.ElementType),
		GodUIHelpers.get_tier_name_with_stars((current_god_data.get("tier", 1) - 1) as God.TierType), current_god_data.get("level", 1), current_god_data.get("total_power", 0)
	]
	basic_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_section.add_child(basic_info)
	content.add_child(info_section)
	
	# XP Section
	var xp_section: VBoxContainer = VBoxContainer.new()
	var xp_title: Label = Label.new()
	xp_title.text = "═══ EXPERIENCE ═══"
	xp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_title.add_theme_font_size_override("font_size", 14)
	xp_section.add_child(xp_title)
	
	var xp_needed = _get_experience_to_next_level(current_god_data.get("level", 1))
	var xp_progress = current_god_data.get("experience", 0)
	var xp_info: Label = Label.new()
	xp_info.text = """Current XP: %d
Next Level: %d
Progress: %.1f%%""" % [
		xp_progress, xp_needed, 
		(float(xp_progress) / float(xp_needed)) * 100.0 if xp_needed > 0 else 100.0
	]
	xp_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_section.add_child(xp_info)
	
	# XP Progress Bar
	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(300, 20)
	xp_bar.min_value = 0
	xp_bar.max_value = xp_needed
	xp_bar.value = xp_progress
	xp_bar.show_percentage = true
	
	# Style the XP bar
	var xp_bar_style: StyleBoxFlat = StyleBoxFlat.new()
	xp_bar_style.bg_color = Color(0.2, 0.2, 0.8, 0.8)
	xp_bar_style.corner_radius_top_left = 4
	xp_bar_style.corner_radius_top_right = 4
	xp_bar_style.corner_radius_bottom_left = 4
	xp_bar_style.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", xp_bar_style)
	
	xp_section.add_child(xp_bar)
	content.add_child(xp_section)
	
	# Combat Stats Section  
	var stats_section: VBoxContainer = VBoxContainer.new()
	var stats_title: Label = Label.new()
	stats_title.text = "═══ COMBAT STATS ═══"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_section.add_child(stats_title)
	
	var stats_info: Label = Label.new()
	stats_info.text = """HP: %d
Attack: %d
Defense: %d
Speed: %d
Territory: %s""" % [
		current_god_data.get("hp", 0), current_god_data.get("attack", 0), 
		current_god_data.get("defense", 0), current_god_data.get("speed", 0),
		current_god_data.get("stationed_territory", "Unassigned") if current_god_data.get("stationed_territory", "") != "" else "Unassigned"
	]
	stats_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_section.add_child(stats_info)
	content.add_child(stats_section)
	
	# Abilities Section
	if current_god_data.has("abilities") and current_god_data.abilities.size() > 0:
		var abilities_section: VBoxContainer = VBoxContainer.new()
		var abilities_title: Label = Label.new()
		abilities_title.text = "═══ ABILITIES ═══"
		abilities_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		abilities_title.add_theme_font_size_override("font_size", 14)
		abilities_section.add_child(abilities_title)
		
		for ability in current_god_data.abilities:
			var ability_container: VBoxContainer = VBoxContainer.new()
			ability_container.add_theme_constant_override("separation", 2)
			
			var ability_name: Label = Label.new()
			ability_name.text = "• " + ability.get("name", "Unknown Ability")
			ability_name.add_theme_font_size_override("font_size", 12)
			ability_name.add_theme_color_override("font_color", Color.YELLOW)
			ability_container.add_child(ability_name)
			
			var ability_desc: Label = Label.new()
			ability_desc.text = "  " + ability.get("description", "No description")
			ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ability_desc.custom_minimum_size.x = 300
			ability_desc.add_theme_font_size_override("font_size", 10)
			ability_container.add_child(ability_desc)
			
			abilities_section.add_child(ability_container)
		
		content.add_child(abilities_section)

	# Skin Selection Section (only if feature unlocked and skins available)
	_create_skin_section(content)


func _create_god_header():
	"""Create the god header with name and basic info"""
	var header_panel: Panel = Panel.new()
	header_panel.name = "HeaderPanel"
	header_panel.custom_minimum_size = Vector2(0, 100)
	content_container.add_child(header_panel)
	
	var header_container: HBoxContainer = HBoxContainer.new()
	header_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_container.add_theme_constant_override("separation", 10)
	header_panel.add_child(header_container)
	
	# God image (placeholder)
	var image_panel: Panel = Panel.new()
	image_panel.custom_minimum_size = Vector2(80, 80)
	header_container.add_child(image_panel)
	
	# God info
	var info_container: VBoxContainer = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(info_container)
	
	# Name and tier
	var name_label: Label = Label.new()
	name_label.text = current_god_data.get("name", "Unknown God")
	name_label.add_theme_font_size_override("font_size", 18)
	info_container.add_child(name_label)
	
	var tier_value: int = current_god_data.get("tier", 0)
	var tier_enum: God.TierType = tier_value as God.TierType

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 4)
	info_container.add_child(tier_row)

	var tier_stars_label := Label.new()
	tier_stars_label.text = GodUIHelpers.get_tier_stars(tier_enum)
	tier_stars_label.add_theme_color_override("font_color", GodUIHelpers.get_tier_color(tier_enum))
	tier_row.add_child(tier_stars_label)

	var tier_name_label := Label.new()
	tier_name_label.text = "(%s)" % GodUIHelpers.get_tier_name(tier_enum)
	tier_name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	tier_row.add_child(tier_name_label)
	
	# Element and level
	var element_label: Label = Label.new()
	element_label.text = "Element: " + current_god_data.get("element", "None")
	info_container.add_child(element_label)
	
	var level_label: Label = Label.new()
	level_label.text = "Level: " + str(current_god_data.get("level", 1)) + "/" + str(God.get_max_level())
	info_container.add_child(level_label)

func _create_stats_section():
	"""Create the stats display section"""
	var stats_label: Label = Label.new()
	stats_label.text = "Stats"
	stats_label.add_theme_font_size_override("font_size", 16)
	content_container.add_child(stats_label)
	
	var stats_panel: Panel = Panel.new()
	stats_panel.custom_minimum_size = Vector2(0, 120)
	content_container.add_child(stats_panel)
	
	var stats_container: VBoxContainer = VBoxContainer.new()
	stats_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_container.add_theme_constant_override("separation", 5)
	stats_panel.add_child(stats_container)
	
	# Power stats
	var power_label: Label = Label.new()
	power_label.text = "Total Power: " + str(current_god_data.get("total_power", 0))
	stats_container.add_child(power_label)
	
	var hp_label: Label = Label.new()
	hp_label.text = "HP: " + str(current_god_data.get("hp", 0))
	stats_container.add_child(hp_label)
	
	var attack_label: Label = Label.new()
	attack_label.text = "Attack: " + str(current_god_data.get("attack", 0))
	stats_container.add_child(attack_label)
	
	var defense_label: Label = Label.new()
	defense_label.text = "Defense: " + str(current_god_data.get("defense", 0))
	stats_container.add_child(defense_label)
	
	var speed_label: Label = Label.new()
	speed_label.text = "Speed: " + str(current_god_data.get("speed", 0))
	stats_container.add_child(speed_label)

func _create_equipment_section():
	"""Create the equipment display and management section"""
	var equipment_label: Label = Label.new()
	equipment_label.text = "Equipment"
	equipment_label.add_theme_font_size_override("font_size", 16)
	content_container.add_child(equipment_label)
	
	var equipment_panel: Panel = Panel.new()
	equipment_panel.custom_minimum_size = Vector2(0, 100)
	content_container.add_child(equipment_panel)
	
	var equipment_grid: GridContainer = GridContainer.new()
	equipment_grid.columns = 3
	equipment_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipment_grid.add_theme_constant_override("h_separation", 5)
	equipment_grid.add_theme_constant_override("v_separation", 5)
	equipment_panel.add_child(equipment_grid)
	
	# Equipment slots
	var equipment_slots: Array = ["weapon", "armor", "accessory"]
	var equipped_items = current_god_data.get("equipment", {})
	
	for slot in equipment_slots:
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(80, 60)
		
		if equipped_items.has(slot) and equipped_items[slot] != "":
			slot_button.text = slot.capitalize() + "\n[Equipped]"
		else:
			slot_button.text = slot.capitalize() + "\n[Empty]"
		
		slot_button.pressed.connect(_on_equipment_slot_pressed.bind(slot))
		equipment_grid.add_child(slot_button)

func _create_skills_section():
	"""Create the skills display section"""
	var skills_label: Label = Label.new()
	skills_label.text = "Skills & Abilities"
	skills_label.add_theme_font_size_override("font_size", 16)
	content_container.add_child(skills_label)
	
	var skills_panel: Panel = Panel.new()
	skills_panel.custom_minimum_size = Vector2(0, 80)
	content_container.add_child(skills_panel)
	
	var skills_container: VBoxContainer = VBoxContainer.new()
	skills_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills_panel.add_child(skills_container)
	
	# Basic skill info
	var skills_info: Label = Label.new()
	var awakening_level = current_god_data.get("awakening_level", 0)
	if awakening_level > 0:
		skills_info.text = "Awakened (Level " + str(awakening_level) + ")\nSpecial abilities unlocked"
	else:
		skills_info.text = "Not awakened\nBasic abilities only"
	skills_container.add_child(skills_info)

func _create_actions_section():
	"""Create the action buttons section"""
	var actions_label: Label = Label.new()
	actions_label.text = "Actions"
	actions_label.add_theme_font_size_override("font_size", 16)
	content_container.add_child(actions_label)
	
	var actions_container: HBoxContainer = HBoxContainer.new()
	actions_container.add_theme_constant_override("separation", 10)
	content_container.add_child(actions_container)
	
	# Level up button
	var level_up_button: Button = Button.new()
	level_up_button.text = "Level Up"
	level_up_button.custom_minimum_size = Vector2(80, 30)
	level_up_button.pressed.connect(_on_level_up_pressed)
	actions_container.add_child(level_up_button)
	
	# Evolve button (if applicable)
	if current_god_data.get("can_evolve", false):
		var evolve_button: Button = Button.new()
		evolve_button.text = "Evolve"
		evolve_button.custom_minimum_size = Vector2(80, 30)
		evolve_button.pressed.connect(_on_evolve_pressed)
		actions_container.add_child(evolve_button)
	
	# Awaken button (if not fully awakened)
	var awakening_level = current_god_data.get("awakening_level", 0)
	var max_awakening = current_god_data.get("max_awakening_level", 6)
	if awakening_level < max_awakening:
		var awaken_button: Button = Button.new()
		awaken_button.text = "Awaken"
		awaken_button.custom_minimum_size = Vector2(80, 30)
		awaken_button.pressed.connect(_on_awaken_pressed)
		actions_container.add_child(awaken_button)

func _on_equipment_slot_pressed(slot: String):
	"""Handle equipment slot button press - RULE 4: Delegate to systems"""
	god_action_requested.emit("change_equipment", current_god_id, {"slot": slot})

func _on_level_up_pressed():
	"""Handle level up button press - RULE 4: Delegate to systems"""
	god_action_requested.emit("level_up", current_god_id, {})

func _on_evolve_pressed():
	"""Handle evolve button press - RULE 4: Delegate to systems"""
	god_action_requested.emit("evolve", current_god_id, {})

func _on_awaken_pressed():
	"""Handle awaken button press - RULE 4: Delegate to systems"""
	god_action_requested.emit("awaken", current_god_id, {})

# Helper functions for beautiful styling
func _get_god_sprite(god_id: String) -> Texture2D:
	"""Load god sprite texture with skin support"""
	# Check for equipped skin first
	var skin_id: String = current_god_data.get("equipped_skin_id", "")
	if skin_id != "":
		var registry: Node = SystemRegistry.get_instance()
		var skin_manager: Node = registry.get_system("SkinManager") if registry else null
		if skin_manager:
			var skin: Dictionary = skin_manager.get_skin(skin_id)
			var skin_path: String = skin.get("portrait_path", "")
			if skin_path != "" and ResourceLoader.exists(skin_path):
				return load(skin_path)

	# Try to load from assets/gods/ folder
	var sprite_path: String = "res://assets/gods/" + god_id + ".png"
	if ResourceLoader.exists(sprite_path):
		return load(sprite_path)

	# Try alternative paths
	sprite_path = "res://assets/gods/" + god_id + ".jpg"
	if ResourceLoader.exists(sprite_path):
		return load(sprite_path)

	# No sprite found
	return null

func _get_experience_to_next_level(level: int) -> int:
	"""Calculate experience needed for next level"""
	# Simple formula - can be made more complex later
	return level * 100

func _create_skin_section(parent_container: VBoxContainer) -> void:
	"""Create the skin selection section"""
	var registry: Node = SystemRegistry.get_instance()
	var feature_unlock_manager: Node = registry.get_system("FeatureUnlockManager") if registry else null
	var skin_manager: Node = registry.get_system("SkinManager") if registry else null

	# Check if skin_selection feature is unlocked
	if not feature_unlock_manager or not feature_unlock_manager.is_feature_unlocked("skin_selection"):
		return

	if not skin_manager:
		return

	# Get skins for this god's template
	var available_skins: Array = skin_manager.get_skins_for_god(current_god_id)

	if available_skins.is_empty():
		return  # No skins available for this god

	# Create section container
	var skin_section: VBoxContainer = VBoxContainer.new()
	skin_section.add_theme_constant_override("separation", 5)
	parent_container.add_child(skin_section)

	# Section header
	var skin_title: Label = Label.new()
	skin_title.text = "═══ SKINS ═══"
	skin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skin_title.add_theme_font_size_override("font_size", 14)
	skin_section.add_child(skin_title)

	# Current skin display
	var current_skin_id: String = current_god_data.get("equipped_skin_id", "")
	var current_skin_label: Label = Label.new()
	if current_skin_id == "":
		current_skin_label.text = "Current: Default"
	else:
		var skin_data: Dictionary = skin_manager.get_skin(current_skin_id)
		current_skin_label.text = "Current: %s" % skin_data.get("name", current_skin_id)
	current_skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_skin_label.add_theme_color_override("font_color", Color.GOLD)
	skin_section.add_child(current_skin_label)

	# Skin selector grid
	var skin_grid: HBoxContainer = HBoxContainer.new()
	skin_grid.add_theme_constant_override("separation", 8)
	skin_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	skin_section.add_child(skin_grid)

	# Default skin button
	var default_btn: Button = Button.new()
	default_btn.text = "Default"
	default_btn.custom_minimum_size = Vector2(80, 35)
	default_btn.disabled = (current_skin_id == "")
	default_btn.pressed.connect(_on_skin_selected.bind(""))
	skin_grid.add_child(default_btn)

	# Available skin buttons
	for skin_id: String in available_skins:
		var skin_data: Dictionary = skin_manager.get_skin(skin_id)
		var is_owned: bool = skin_manager.is_skin_owned(skin_id)
		var is_equipped: bool = (skin_id == current_skin_id)

		var skin_btn: Button = Button.new()
		skin_btn.custom_minimum_size = Vector2(100, 35)

		if is_owned:
			skin_btn.text = skin_data.get("name", skin_id)
			skin_btn.disabled = is_equipped
			skin_btn.pressed.connect(_on_skin_selected.bind(skin_id))
			if is_equipped:
				skin_btn.modulate = Color.GOLD
		else:
			var cost: int = int(skin_data.get("cost_crystals", 0))
			skin_btn.text = "%s (%d)" % [skin_data.get("name", skin_id), cost]
			skin_btn.pressed.connect(_on_skin_purchase_requested.bind(skin_id))
			skin_btn.modulate = Color(0.6, 0.6, 0.6)

		# Color border by rarity
		var rarity: String = skin_data.get("rarity", "common")
		match rarity:
			"epic":
				if is_owned:
					skin_btn.add_theme_color_override("font_color", Color(0.7, 0.3, 0.9))
			"legendary":
				if is_owned:
					skin_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))

		skin_grid.add_child(skin_btn)

func _on_skin_selected(skin_id: String) -> void:
	"""Handle skin selection"""
	var registry: Node = SystemRegistry.get_instance()
	var skin_manager: Node = registry.get_system("SkinManager") if registry else null
	if not skin_manager:
		return

	if skin_id == "":
		skin_manager.unequip_skin(current_god_id)
	else:
		skin_manager.equip_skin(current_god_id, skin_id)

	# Refresh display to show new skin
	refresh_current_display()

func _on_skin_purchase_requested(skin_id: String) -> void:
	"""Handle skin purchase request"""
	god_action_requested.emit("purchase_skin", current_god_id, {"skin_id": skin_id})
