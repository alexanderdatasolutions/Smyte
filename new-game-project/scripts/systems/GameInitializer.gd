# scripts/systems/GameInitializer.gd - Handles all game initialization like Summoners War
extends Node

signal initialization_complete
signal initialization_progress(step: String, progress: float)

# Initialization state
var is_initialized: bool = false
var initialization_steps: Array = []
var current_step: int = 0

# UI Cache System
var cached_god_cards: Dictionary = {}  # god.id -> Card nodes for different screen types
var cached_ability_icons: Dictionary = {}  # ability.id -> TextureRect
var cached_enemy_sprites: Dictionary = {}  # enemy.id -> TextureRect

# Service references
var firebase_service = null
var update_service = null
var analytics_service = null

# Card templates for different screens
enum CardType { COLLECTION, SACRIFICE, AWAKENING, SELECTION, BATTLE }

func _ready():
	print("GameInitializer: Starting game initialization...")
	setup_initialization_steps()

func setup_initialization_steps():
	"""Define all initialization steps like Summoners War loading screen"""
	initialization_steps = [
		{"name": "Loading Core Systems", "function": init_core_systems},
		{"name": "Connecting to Services", "function": init_services},
		{"name": "Checking for Updates", "function": check_updates},
		{"name": "Loading User Data", "function": load_user_data},
		{"name": "Preloading UI Assets", "function": preload_ui_assets},
		{"name": "Caching God Cards", "function": cache_all_god_cards},
		{"name": "Preparing Battle Assets", "function": preload_battle_assets},
		{"name": "Finalizing Setup", "function": finalize_initialization}
	]

func start_initialization():
	"""Start the full initialization process"""
	if is_initialized:
		initialization_complete.emit()
		return
	
	current_step = 0
	process_next_step()

func process_next_step():
	"""Process the next initialization step"""
	if current_step >= initialization_steps.size():
		complete_initialization()
		return
	
	var step_data = initialization_steps[current_step]
	var step_name = step_data.name
	var step_function = step_data.function
	
	print("GameInitializer: %s..." % step_name)
	initialization_progress.emit(step_name, float(current_step) / float(initialization_steps.size()))
	
	# Execute the step
	await step_function.call()
	
	current_step += 1
	
	# Small delay to show progress (like Summoners War)
	await get_tree().create_timer(0.1).timeout
	process_next_step()

func complete_initialization():
	"""Mark initialization as complete"""
	is_initialized = true
	print("GameInitializer: Initialization complete!")
	initialization_progress.emit("Ready!", 1.0)
	
	# Small delay before signaling complete
	await get_tree().create_timer(0.2).timeout
	initialization_complete.emit()

# ===== INITIALIZATION STEPS =====

func init_core_systems():
	"""Initialize core game systems"""
	# This is already done by GameManager autoload
	pass

func init_services():
	"""Initialize external services (Firebase, etc.)"""
	# TODO: Initialize Firebase service
	# firebase_service = FirebaseService.new()
	# await firebase_service.initialize()
	
	# TODO: Initialize analytics
	# analytics_service = AnalyticsService.new()
	# await analytics_service.initialize()
	
	# For now, just simulate
	await get_tree().create_timer(0.3).timeout

func check_updates():
	"""Check for game updates"""
	# TODO: Check for app updates, asset updates, etc.
	# update_service = UpdateService.new()
	# await update_service.check_for_updates()
	
	# For now, just simulate
	await get_tree().create_timer(0.2).timeout

func load_user_data():
	"""Load user data from cloud/local"""
	# This is already done by GameManager
	# TODO: Sync with cloud data if logged in
	await get_tree().create_timer(0.1).timeout

func preload_ui_assets():
	"""Preload commonly used UI assets"""
	# TODO: Preload common textures, fonts, etc.
	# This reduces loading hitches during gameplay
	await get_tree().create_timer(0.2).timeout

func cache_all_god_cards():
	"""Pre-create all god UI cards for instant display"""
	if not GameManager or not GameManager.player_data:
		return
	
	var total_gods = GameManager.player_data.gods.size()
	var processed = 0
	
	# Create cards in small batches to avoid freezing
	var batch_size = 5
	
	for i in range(0, total_gods, batch_size):
		var end_idx = min(i + batch_size, total_gods)
		
		for j in range(i, end_idx):
			var god = GameManager.player_data.gods[j]
			cache_god_cards_for_all_screens(god)
			processed += 1
		
		# Update progress within this step
		var step_progress = float(processed) / float(total_gods)
		initialization_progress.emit("Caching God Cards (%d/%d)" % [processed, total_gods], 
									(float(current_step) + step_progress) / float(initialization_steps.size()))
		
		# Allow UI to update
		await get_tree().process_frame

func cache_god_cards_for_all_screens(god: God):
	"""Create cached card variants for different screen types"""
	if not cached_god_cards.has(god.id):
		cached_god_cards[god.id] = {}
	
	# Create cards for each screen type
	cached_god_cards[god.id][CardType.COLLECTION] = create_collection_card(god)
	cached_god_cards[god.id][CardType.SACRIFICE] = create_sacrifice_card(god)
	cached_god_cards[god.id][CardType.AWAKENING] = create_awakening_card(god)
	cached_god_cards[god.id][CardType.SELECTION] = create_selection_card(god)

func preload_battle_assets():
	"""Preload battle-related assets"""
	# TODO: Preload enemy sprites, skill effects, etc.
	await get_tree().create_timer(0.2).timeout

func finalize_initialization():
	"""Final setup steps"""
	# Any final cleanup or setup
	await get_tree().create_timer(0.1).timeout

# ===== CARD CREATION FUNCTIONS =====

func create_collection_card(god: God) -> Control:
	"""Create a collection screen card"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	
	# Style with subtle tier colors
	var style = StyleBoxFlat.new()
	style.bg_color = get_subtle_tier_color(god.tier)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = get_tier_border_color(god.tier)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
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
	
	# God image (preloaded)
	var god_image = TextureRect.new()
	god_image.custom_minimum_size = Vector2(48, 48)
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
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
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Element and power
	var info_label = Label.new()
	info_label.text = "%s P:%d" % [get_element_short_name(god.element), god.get_power_rating()]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(info_label)
	
	# Add clickable button (will be reconnected by each screen)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	card.add_child(button)
	
	return card

func create_sacrifice_card(god: God) -> Control:
	"""Create a sacrifice screen card"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	
	# Style based on selection with subtle colors
	var style = StyleBoxFlat.new()
	style.bg_color = get_subtle_tier_color(god.tier)
	style.border_color = get_tier_border_color(god.tier)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
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
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
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
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Power rating
	var power_label = Label.new()
	power_label.text = "P:%d" % god.get_power_rating()
	power_label.add_theme_font_size_override("font_size", 9)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(power_label)
	
	# Add clickable button (will be reconnected by each screen)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	card.add_child(button)
	
	return card

func create_awakening_card(god: God) -> Control:
	"""Create an awakening screen card"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	
	# Style based on awakening status
	var style = StyleBoxFlat.new()
	if god.can_awaken():
		style.bg_color = get_subtle_tier_color(god.tier)
		style.border_color = Color(1.0, 0.8, 0.2, 1.0)  # Gold border for awakenable
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)  # Dark gray for not ready
		style.border_color = Color(0.4, 0.4, 0.4, 0.8)
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
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
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
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
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN if god.can_awaken() else Color.GRAY
	vbox.add_child(level_label)
	
	# Awakening materials needed
	var materials_needed = ""
	if god.can_awaken():
		materials_needed = "Ready!"
	else:
		# TODO: Show what materials are needed
		materials_needed = "Materials needed"
	
	var materials_label = Label.new()
	materials_label.text = materials_needed
	materials_label.add_theme_font_size_override("font_size", 9)
	materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	materials_label.modulate = Color.GOLD if god.can_awaken() else Color.GRAY
	vbox.add_child(materials_label)
	
	# Add clickable button (will be reconnected by each screen)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	card.add_child(button)
	
	return card

func create_selection_card(god: God) -> Control:
	"""Create a selection screen card (for sacrifice materials)"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)
	
	# Style with subtle colors
	var style = StyleBoxFlat.new()
	style.bg_color = get_subtle_tier_color(god.tier)
	style.border_color = get_tier_border_color(god.tier)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	
	# Add margin for better spacing
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
	var god_texture = god.get_sprite()
	if god_texture:
		god_image.texture = god_texture
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
	level_label.text = "Lv.%d %s" % [god.level, get_tier_short_name(god.tier)]
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.modulate = Color.CYAN
	vbox.add_child(level_label)
	
	# Sacrifice value
	var sacrifice_value = 0
	if GameManager and GameManager.sacrifice_system:
		sacrifice_value = GameManager.sacrifice_system.get_god_base_sacrifice_value(god)
	
	var value_label = Label.new()
	value_label.text = "XP:%d" % sacrifice_value
	value_label.add_theme_font_size_override("font_size", 9)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.modulate = Color.LIGHT_GRAY
	vbox.add_child(value_label)
	
	# Add clickable button (will be reconnected by each screen)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	card.add_child(button)
	
	return card

# ===== CARD ACCESS FUNCTIONS =====

func get_cached_card(god: God, card_type: CardType) -> Control:
	"""Get a cached card for a god and screen type"""
	if not cached_god_cards.has(god.id):
		return null
	if not cached_god_cards[god.id].has(card_type):
		return null
	
	var card = cached_god_cards[god.id][card_type]
	
	# Duplicate the card so each screen gets its own instance
	return card.duplicate()

func update_cached_card_selection(god: God, card_type: CardType, is_selected: bool):
	"""Update the selection state of a cached card"""
	var card = get_cached_card(god, card_type)
	if not card:
		return
	
	# Update the card's styling based on selection
	var style = card.get_theme_stylebox("panel")
	if style and is_selected:
		style.bg_color = Color(0.2, 0.4, 0.8, 0.7)  # Blue for selected
		style.border_color = Color(0.4, 0.6, 1.0, 1.0)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	elif style:
		# Reset to default styling
		style.bg_color = get_subtle_tier_color(god.tier)
		style.border_color = get_tier_border_color(god.tier)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2

# ===== UTILITY FUNCTIONS =====

func get_subtle_tier_color(tier: int) -> Color:
	"""Get subtle background colors for tiers"""
	match tier:
		0:  # COMMON
			return Color(0.25, 0.25, 0.25, 0.7)  # Dark gray
		1:  # RARE
			return Color(0.2, 0.3, 0.2, 0.7)     # Dark green
		2:  # EPIC
			return Color(0.3, 0.2, 0.4, 0.7)     # Dark purple
		3:  # LEGENDARY
			return Color(0.4, 0.3, 0.1, 0.7)     # Dark gold
		_:
			return Color(0.2, 0.2, 0.3, 0.7)

func get_tier_border_color(tier: int) -> Color:
	"""Get border colors for tiers"""
	match tier:
		0:  # COMMON
			return Color(0.5, 0.5, 0.5, 0.8)     # Gray
		1:  # RARE
			return Color(0.4, 0.8, 0.4, 1.0)     # Green
		2:  # EPIC
			return Color(0.7, 0.4, 1.0, 1.0)     # Purple
		3:  # LEGENDARY
			return Color(1.0, 0.8, 0.2, 1.0)     # Gold
		_:
			return Color(0.6, 0.6, 0.6, 0.8)

func get_tier_short_name(tier: int) -> String:
	"""Get short tier names for compact display"""
	match tier:
		0: return "★"      # COMMON
		1: return "★★"     # RARE  
		2: return "★★★"    # EPIC
		3: return "★★★★"   # LEGENDARY
		_: return "?"

func get_element_short_name(element: int) -> String:
	"""Get short element names for compact display"""
	match element:
		0: return "🔥"  # FIRE
		1: return "💧"  # WATER
		2: return "🌍"  # EARTH
		3: return "⚡"  # LIGHTNING
		4: return "☀️"  # LIGHT
		5: return "🌙"  # DARK
		_: return "?"

# ===== CACHE MANAGEMENT =====

func refresh_cached_cards():
	"""Refresh all cached cards (call when gods are updated)"""
	cached_god_cards.clear()
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			cache_god_cards_for_all_screens(god)

func add_god_to_cache(god: God):
	"""Add a new god to the cache (call when new god is summoned)"""
	cache_god_cards_for_all_screens(god)

func remove_god_from_cache(god_id: String):
	"""Remove a god from the cache (call when god is sacrificed)"""
	if cached_god_cards.has(god_id):
		# Free all cached cards for this god
		for card_type in cached_god_cards[god_id]:
			var card = cached_god_cards[god_id][card_type]
			if card:
				card.queue_free()
		cached_god_cards.erase(god_id)

func get_cache_stats() -> Dictionary:
	"""Get cache statistics for debugging"""
	return {
		"cached_gods": cached_god_cards.size(),
		"cached_abilities": cached_ability_icons.size(),
		"cached_enemies": cached_enemy_sprites.size(),
		"is_initialized": is_initialized
	}
