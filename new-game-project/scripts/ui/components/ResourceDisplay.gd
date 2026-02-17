# scripts/ui/ResourceDisplay.gd
#
# ResourceDisplay manages the main resource UI shown across all game screens
# Displays: Mana (primary currency), Divine Crystals (premium), etc.
#
# Architecture: Uses singleton pattern to sync all instances globally
# Data Source: ResourceManager via SystemRegistry
# Config Source: resources.json - all resource metadata loaded from JSON
#
extends PanelContainer

# Helper to get SystemRegistry without parse-time dependency
static func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

# === CONFIG CACHE ===
static var _resource_config: Dictionary = {}
static var _resource_config_loaded: bool = false

# === SINGLETON PATTERN ===
# All ResourceDisplay instances sync updates globally when resources change
static var _instances: Array = []

# === EXPANDED PANEL STATE ===
var is_expanded: bool = false
var expanded_panel: PanelContainer = null
var expand_indicator: Label = null
var _tween: Tween = null

# === UI ELEMENTS ===
# These correspond to nodes in ResourceDisplay.tscn (redesigned with containers)
@onready var player_level_label: Label = null # Player level - created dynamically if needed
@onready var mana_label: Label = $MarginContainer/HBoxContainer/ManaContainer/ManaLabel
@onready var crystal_label: Label = $MarginContainer/HBoxContainer/CrystalContainer/CrystalLabel
@onready var tickets_label: Label = $MarginContainer/HBoxContainer/TicketsContainer/TicketsLabel
@onready var materials_button: Button = $MarginContainer/HBoxContainer/MaterialsButton
@onready var materials_count_label: Label = $MarginContainer/HBoxContainer/MaterialsCountLabel

# === SYSTEM REFERENCES ===
var resource_manager: Node = null  # Reference to ResourceManager for materials data

# === LIFECYCLE METHODS ===
	
func _ready():
	"""Initialize this ResourceDisplay instance"""
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
	_setup_tap_to_expand()

	# Perform initial display update
	call_deferred("_update_this_instance")

func _exit_tree():
	"""Clean up when leaving the scene tree"""
	# Remove from instances list
	_instances.erase(self)

	# Disconnect signals to prevent errors
	var event_bus = _get_system_registry().get_system("EventBus") if _get_system_registry() else null
	if event_bus and event_bus.has_signal("resources_updated") and event_bus.resources_updated.is_connected(_update_all_instances):
		event_bus.resources_updated.disconnect(_update_all_instances)

func _input(event: InputEvent):
	"""Handle global input to close expanded panel when clicking outside"""
	if not is_expanded:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if click is outside the resource bar and expanded panel
			var click_pos = event.position
			var bar_rect = get_global_rect()

			# Expand bar_rect to include the expanded panel area
			if expanded_panel and expanded_panel.visible:
				bar_rect.size.y += expanded_panel.size.y

			if not bar_rect.has_point(click_pos):
				_collapse_panel()

# === INITIALIZATION HELPERS ===

func _initialize_resource_manager():
	"""Get ResourceManager reference through SystemRegistry"""
	var system_registry = _get_system_registry()
	if system_registry:
		resource_manager = system_registry.get_system("ResourceManager")

func _setup_signal_connections():
	"""Connect to ResourceManager's resource_changed signal for live updates"""
	# Defer connection to ensure systems are fully initialized
	call_deferred("_connect_to_resource_manager")

func _connect_to_resource_manager():
	"""Actually connect to ResourceManager - called deferred to ensure systems are ready"""
	var system_registry = _get_system_registry()
	if not system_registry:
		# Retry after a frame if SystemRegistry not ready
		get_tree().create_timer(0.1).timeout.connect(_connect_to_resource_manager)
		return

	var res_mgr = system_registry.get_system("ResourceManager")
	if res_mgr and res_mgr.has_signal("resource_changed"):
		if not res_mgr.resource_changed.is_connected(_on_resource_changed):
			res_mgr.resource_changed.connect(_on_resource_changed)
	else:
		# ResourceManager not ready yet, retry after a short delay
		get_tree().create_timer(0.1).timeout.connect(_connect_to_resource_manager)

func _on_resource_changed(resource_id: String, new_amount: int, delta: int):
	"""Handle resource change - update all displays"""
	_update_all_instances()

func _setup_progression_signals():
	"""Connect to progression system signals for player level updates"""
	# For now, disable progression signals since we don't have ProgressionManager yet
	# TODO: Re-enable when ProgressionManager is implemented in SystemRegistry
	pass

func _setup_materials_button():
	"""Setup materials button interactions - HIDDEN, tap-to-expand replaces this"""
	if materials_button:
		# Hide the old materials button - tap-to-expand replaces it
		materials_button.visible = false
	if materials_count_label:
		materials_count_label.visible = false

func _setup_tap_to_expand():
	"""Make the entire resource bar tappable to expand/collapse"""
	# Set all children to ignore mouse so clicks reach this PanelContainer
	_set_children_mouse_ignore(self)

	# Add expand indicator (▼) to the HBoxContainer
	var hbox = get_node_or_null("MarginContainer/HBoxContainer")
	if hbox:
		expand_indicator = Label.new()
		expand_indicator.name = "ExpandIndicator"
		expand_indicator.text = " ▼"
		expand_indicator.add_theme_font_size_override("font_size", 12)
		expand_indicator.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		expand_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		expand_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(expand_indicator)

	# This PanelContainer receives clicks
	mouse_filter = Control.MOUSE_FILTER_STOP

func _set_children_mouse_ignore(node: Node):
	"""Recursively set all Control children to MOUSE_FILTER_IGNORE"""
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_ignore(child)

func _gui_input(event: InputEvent):
	"""Handle tap/click on the resource bar to expand/collapse"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_toggle_expanded_panel()
			accept_event()

func _toggle_expanded_panel():
	"""Toggle the expanded resources panel"""
	if is_expanded:
		_collapse_panel()
	else:
		_expand_panel()

func _expand_panel():
	"""Show the expanded resources panel with slide-down animation"""
	if is_expanded:
		return

	is_expanded = true
	if expand_indicator:
		expand_indicator.text = "▲"

	# Create expanded panel if it doesn't exist
	if not expanded_panel:
		_create_expanded_panel()

	# Position panel just below the resource bar
	var panel_height: int = 300  # Height of expanded content (scrollable)
	expanded_panel.position = Vector2(0, size.y)
	expanded_panel.size = Vector2(size.x, 0)
	expanded_panel.visible = true

	# Refresh content AFTER setting visible (so _update_expanded_panel_values doesn't skip)
	_update_expanded_panel_values()

	# Animate slide down
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(expanded_panel, "size:y", panel_height, 0.2)

func _collapse_panel():
	"""Hide the expanded resources panel with slide-up animation"""
	if not is_expanded:
		return

	is_expanded = false
	if expand_indicator:
		expand_indicator.text = "▼"

	if not expanded_panel:
		return

	# Animate slide up
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(expanded_panel, "size:y", 0, 0.15)
	_tween.tween_callback(func(): expanded_panel.visible = false)

func _create_expanded_panel():
	"""Create the expanded resources panel that slides down as overlay"""
	expanded_panel = PanelContainer.new()
	expanded_panel.name = "ExpandedResourcesPanel"
	expanded_panel.z_index = 100  # Above game UI
	expanded_panel.visible = false
	expanded_panel.clip_contents = true

	# Dark panel styling
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	panel_style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(0)
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	expanded_panel.add_theme_stylebox_override("panel", panel_style)

	# Content container with margins
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	expanded_panel.add_child(margin)

	# ScrollContainer for all content
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ResourceScroll"
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "ResourceContent"
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # Don't expand beyond content
	scroll.add_child(vbox)

	# Populate with all player resources
	_populate_expanded_panel(vbox)

	# Add as child of this control so it overlays correctly
	add_child(expanded_panel)

func _populate_expanded_panel(vbox: VBoxContainer) -> void:
	"""Populate expanded panel with all resources player has (non-zero only)"""
	var system_registry = _get_system_registry()
	var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
	if not resource_mgr:
		return

	var all_resources: Dictionary = resource_mgr.get_all_resources()
	var categories: Dictionary = _categorize_resources(all_resources)

	# Add each category section in order
	var section_order: Array[Array] = [
		["currency", "CURRENCIES"],
		["raw", "RAW MATERIALS"],
		["processed", "PROCESSED"],
		["special", "SPECIAL"],
	]

	var any_shown := false
	for entry in section_order:
		var key: String = entry[0]
		var header_text: String = entry[1]
		if categories.has(key) and not categories[key].is_empty():
			_add_category_section(vbox, header_text, categories[key])
			any_shown = true

	if not any_shown:
		var empty_label := Label.new()
		empty_label.text = "No resources yet"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(empty_label)

func _categorize_resources(all_resources: Dictionary) -> Dictionary:
	"""Sort resources into category buckets (only non-zero amounts)"""
	var resource_info: Dictionary = _get_resource_metadata()
	var result := {"currency": {}, "raw": {}, "processed": {}, "special": {}}

	for resource_id: String in all_resources:
		var amount: int = all_resources[resource_id]
		if amount <= 0:
			continue

		var info: Dictionary = resource_info.get(resource_id, {
			"name": resource_id.capitalize().replace("_", " "),
			"icon": "📦",
			"category": "special"
		})
		var category: String = info.get("category", "special")
		if not result.has(category):
			category = "special"
		result[category][resource_id] = {"amount": amount, "info": info}

	return result

func _add_category_section(vbox: VBoxContainer, header_text: String, resources: Dictionary) -> void:
	"""Add a category header and resource grid to the expanded panel"""
	vbox.add_child(_create_section_header(header_text))
	var grid := _create_resource_grid(3)
	vbox.add_child(grid)
	for res_id: String in resources:
		_add_resource_to_grid(grid, res_id, resources[res_id])

static func _load_resource_config() -> void:
	"""Load resource definitions from resources.json"""
	if _resource_config_loaded:
		return
	_resource_config_loaded = true

	var file: FileAccess = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if not file:
		push_warning("ResourceDisplay: Could not load resources.json")
		return
	var json_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		_resource_config = parsed as Dictionary

static func _get_resource_metadata() -> Dictionary:
	"""Build resource metadata from resources.json - config-driven"""
	_load_resource_config()

	var result: Dictionary = {}

	# Emoji fallbacks for common resources (JSON has icon names, we need emojis for display)
	var emoji_map: Dictionary = {
		"mana": "✦", "gold": "💰", "divine_crystals": "◆",
		"ore": "🪨", "wood": "🪵", "herbs": "🌿",
		"fine_ore": "🪨", "hardwood": "🪵", "exotic_herbs": "🌿",
		"arcane_ore": "🪨", "ancient_wood": "🪵", "mystic_herbs": "🌿",
		"celestial_ore": "⭐",
		"refined_metal": "⚙️", "quality_timber": "🪵", "rare_herbs": "🌿",
		"steel_ingot": "⚙️", "treated_lumber": "🪵", "alchemical_extract": "💧",
		"prometheum": "⚙️", "enchanted_wood": "🪵", "mystic_bloom": "🌸",
		"astral_shard": "💠", "divine_metal": "✨",
		"monster_parts": "🦴", "beast_scales": "🐉", "elemental_cores": "🔮", "dragon_parts": "🐲",
		"basic_flame": "🔥", "forging_flame": "🔥", "divine_flame": "🔥", "eternal_flame": "🔥",
		"magic_crystals": "💎", "socket_crystal": "💎", "blessed_oil": "🛢️",
		"divine_essence": "🌟", "mana_crystals": "💠",
		"awakening_essence": "✨", "ascension_crystal": "🌌",
		"common_soul": "👻", "rare_soul": "👻", "epic_soul": "👻", "legendary_soul": "👻",
		"fire_powder": "🔥", "water_powder": "💧", "earth_powder": "🌍",
		"lightning_powder": "⚡", "light_powder": "☀️", "dark_powder": "🌑",
		"ruby": "🔴", "sapphire": "🔵", "emerald": "🟢", "topaz": "🟡", "diamond": "⚪", "onyx": "⚫",
	}

	# Category mapping from JSON categories to display categories
	var category_map: Dictionary = {
		"currency": "currency",
		"premium_currency": "currency",
		"crafting_material": "raw",  # Will be overridden by material_type
		"enhancement_material": "special",
		"gemstone": "special",
		"awakening_material": "special",
		"summoning_material": "special",
		"element_powder": "special",
		"divine_material": "special",
		"pantheon_token": "special",
	}

	# Process each section of resources.json
	for section_key: String in _resource_config:
		if section_key.begins_with("_"):
			continue
		var section: Variant = _resource_config[section_key]
		if not section is Dictionary:
			continue

		for resource_id: String in section:
			if resource_id.begins_with("_"):
				continue
			var def: Variant = section[resource_id]
			if not def is Dictionary:
				continue

			var res_name: String = str(def.get("name", resource_id.capitalize().replace("_", " ")))
			var res_desc: String = str(def.get("description", ""))
			var json_category: String = str(def.get("category", ""))
			var material_type: String = str(def.get("material_type", ""))

			# Determine display category
			var display_category: String = category_map.get(json_category, "special")
			if json_category == "crafting_material":
				# Use material_type for more specific categorization
				if material_type == "raw":
					display_category = "raw"
				elif material_type == "processed":
					display_category = "processed"
				else:
					display_category = "special"  # flames, defense_drops, etc.

			# Get emoji (fallback to generic)
			var emoji: String = emoji_map.get(resource_id, "📦")

			result[resource_id] = {
				"name": res_name,
				"icon": emoji,
				"category": display_category,
				"desc": res_desc
			}

	# Add experience (player XP) which may not be in resources.json
	if not result.has("experience"):
		result["experience"] = {"name": "Experience", "icon": "📈", "category": "currency", "desc": "Player experience points for account level"}

	# Add summon_tickets if not present
	if not result.has("summon_tickets"):
		result["summon_tickets"] = {"name": "Summon Tickets", "icon": "★", "category": "currency", "desc": "Free summon attempts"}

	return result

func _create_resource_grid(columns: int) -> GridContainer:
	"""Create a grid for displaying resources"""
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	return grid

func _add_resource_to_grid(grid: GridContainer, resource_id: String, data: Dictionary):
	"""Add a single resource to the grid (tappable for description)"""
	var info = data.get("info", {})
	var amount = data.get("amount", 0)

	# Use a Button as the base for tap detection
	var item_btn: Button = Button.new()
	item_btn.flat = true
	item_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	item_btn.custom_minimum_size = Vector2(120, 24)

	# Style the button
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.2, 0.0)
	btn_style.set_corner_radius_all(4)
	item_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.25, 0.35, 0.5)
	btn_hover.set_corner_radius_all(4)
	item_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed: StyleBoxFlat = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.3, 0.4, 0.6)
	btn_pressed.set_corner_radius_all(4)
	item_btn.add_theme_stylebox_override("pressed", btn_pressed)

	# Content inside button
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", 4)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_btn.add_child(item)

	# Icon
	var icon_label: Label = Label.new()
	icon_label.text = info.get("icon", "📦")
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(icon_label)

	# Name and amount
	var text_label: Label = Label.new()
	text_label.name = "Resource_%s" % resource_id
	text_label.text = "%s: %s" % [info.get("name", resource_id), _format_amount(amount)]
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(text_label)

	# Connect tap to show description
	var description = info.get("desc", "No description available")
	var res_name = info.get("name", resource_id)
	item_btn.pressed.connect(_show_resource_description.bind(res_name, description))

	grid.add_child(item_btn)

var _description_popup: PanelContainer = null

func _show_resource_description(res_name: String, description: String):
	"""Show a small popup with the resource description"""
	# Remove existing popup if any
	if _description_popup and is_instance_valid(_description_popup):
		_description_popup.queue_free()

	_description_popup = PanelContainer.new()
	_description_popup.z_index = 200

	# Style
	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	popup_style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(8)
	popup_style.content_margin_left = 12
	popup_style.content_margin_right = 12
	popup_style.content_margin_top = 8
	popup_style.content_margin_bottom = 8
	_description_popup.add_theme_stylebox_override("panel", popup_style)

	# Content
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_description_popup.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = res_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 250
	vbox.add_child(desc_label)

	# Tap to close hint
	var hint: Label = Label.new()
	hint.text = "(tap anywhere to close)"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# Position in center of screen
	add_child(_description_popup)
	await get_tree().process_frame

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_description_popup.position = Vector2(
		(viewport_size.x - _description_popup.size.x) / 2,
		(viewport_size.y - _description_popup.size.y) / 2 - 50
	)

	# Auto-close after delay or on next click
	get_tree().create_timer(3.0).timeout.connect(func():
		if _description_popup and is_instance_valid(_description_popup):
			_description_popup.queue_free()
			_description_popup = null
	)

func _format_amount(amount) -> String:
	"""Format amount for display"""
	if amount is float:
		if amount >= 1000000:
			return "%.1fM" % (amount / 1000000.0)
		elif amount >= 1000:
			return "%.1fK" % (amount / 1000.0)
		elif amount >= 100:
			return "%d" % int(amount)
		else:
			return "%.1f" % amount
	else:
		if amount >= 1000000:
			return "%.1fM" % (float(amount) / 1000000.0)
		elif amount >= 1000:
			return "%.1fK" % (float(amount) / 1000.0)
		else:
			return str(amount)

func _create_section_header(text: String) -> Label:
	"""Create a styled section header label"""
	var header: Label = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	return header

func _update_expanded_panel_values():
	"""Rebuild expanded panel content when resources change"""
	if not expanded_panel or not expanded_panel.visible:
		return

	# Find the content container and rebuild it
	var scroll = expanded_panel.find_child("ResourceScroll", true, false)
	if not scroll:
		return

	var vbox = scroll.find_child("ResourceContent", true, false)
	if not vbox:
		return

	# Clear existing content
	for child in vbox.get_children():
		child.queue_free()

	# Repopulate with current resources
	call_deferred("_populate_expanded_panel", vbox)

func _create_player_level_label():
	"""Create player level label dynamically inside the HBoxContainer"""
	# Try to find existing node first
	var hbox = get_node_or_null("MarginContainer/HBoxContainer")
	if not hbox:
		return

	if hbox.has_node("PlayerLevelLabel"):
		player_level_label = hbox.get_node("PlayerLevelLabel")
		return

	# Create label dynamically and add to the beginning of the HBoxContainer
	player_level_label = Label.new()
	player_level_label.name = "PlayerLevelLabel"
	player_level_label.text = "Lv1"
	player_level_label.add_theme_font_size_override("font_size", 12)
	player_level_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	player_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Add it as the first child of HBoxContainer (leftmost position)
	hbox.add_child(player_level_label)
	hbox.move_child(player_level_label, 0)

# === DISPLAY UPDATE METHODS ===

static func _update_all_instances():
	"""Update all ResourceDisplay instances when resources change globally"""
	for instance in _instances:
		if instance and is_instance_valid(instance):
			instance._update_this_instance()

func _update_this_instance():
	"""Update this specific instance's display with current resource values"""
	var system_registry = _get_system_registry()
	if not system_registry:
		return

	var resource_mgr = system_registry.get_system("ResourceManager")
	if not resource_mgr:
		return
	
	# Update each resource display according to prompt architecture
	_update_player_level_display()
	_update_mana_display()
	_update_crystals_display()
	_update_tickets_display()
	_update_materials_count()
	_update_expanded_panel_values()

func _update_player_level_display():
	"""Update player level display (using ResourceManager)"""
	if not player_level_label:
		return

	var player_level: int = 1
	var player_xp: int = 0

	# Get experience from ResourceManager instead of PlayerData
	var resource_mgr = _get_system_registry().get_system("ResourceManager") if _get_system_registry() else null
	if resource_mgr:
		player_xp = resource_mgr.get_resource("experience")
		# Simple level calculation: every 1000 XP = 1 level
		player_level = max(1, int(player_xp / 1000.0) + 1)

	# Compact format: "Lv73"
	player_level_label.text = "Lv%d" % player_level

func _update_mana_display():
	"""Update mana display (primary currency per prompt architecture)"""
	if mana_label:
		var system_registry = _get_system_registry()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var mana_value = resource_mgr.get_resource("mana") if resource_mgr else 0
		mana_label.text = format_large_number(mana_value)

func _update_crystals_display():
	"""Update divine crystals display (premium currency)"""
	if crystal_label:
		var system_registry = _get_system_registry()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var crystals_value = resource_mgr.get_resource("divine_crystals") if resource_mgr else 0
		crystal_label.text = str(crystals_value)

func _update_tickets_display():
	"""Update summon tickets display"""
	if tickets_label:
		var system_registry = _get_system_registry()
		var resource_mgr = system_registry.get_system("ResourceManager") if system_registry else null
		var tickets_count = resource_mgr.get_resource("summon_tickets") if resource_mgr else 0
		tickets_label.text = str(tickets_count)

func _update_materials_count():
	"""Update materials count display"""
	if materials_count_label:
		var materials_total = _get_total_materials_count()
		materials_count_label.text = "(%d)" % materials_total

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
	"""Calculate total count of all crafting materials in player inventory (config-driven)"""
	var resource_mgr = _get_system_registry().get_system("ResourceManager") if _get_system_registry() else null
	if not resource_mgr:
		return 0

	_load_resource_config()

	var total: int = 0
	# Count all crafting materials from resources.json crafting_materials section
	var crafting_section: Variant = _resource_config.get("crafting_materials", {})
	if crafting_section is Dictionary:
		for material_id: String in crafting_section:
			if material_id.begins_with("_"):
				continue
			var count: int = resource_mgr.get_resource(material_id) if resource_mgr.has_method("get_resource") else 0
			total += count

	return total

