# scripts/ui/components/GodCard.gd
# Reusable God Card UI Component - RULE 2: Single Responsibility
# Handles god display across Collection, Sacrifice, Awakening, Battle Setup, etc.
class_name GodCard extends Panel

signal god_selected(god: God)

# Card configuration
enum CardSize { SMALL, MEDIUM, LARGE }
enum CardStyle { NORMAL, SELECTED, AWAKENING_READY, BATTLE_READY }

# Card properties
@export var card_size: CardSize = CardSize.MEDIUM
@export var show_experience_bar: bool = true
@export var show_power_rating: bool = true
@export var show_territory_assignment: bool = false
@export var show_awakening_status: bool = false
@export var clickable: bool = true

# Internal references
var god_data: God = null
var current_style: CardStyle = CardStyle.NORMAL

# UI Elements (created dynamically)
var god_image: TextureRect
var name_label: Label
var level_tier_label: Label
var info_label: Label
var experience_container: VBoxContainer
var experience_bar: ProgressBar
var territory_indicator: Label
var awakening_indicator: Label

func _ready():
	# Only setup structure if not already done (to avoid clearing nodes created before adding to tree)
	if not god_image:
		_setup_card_structure()
		_apply_card_size()

func setup_god_card(god: God, style: CardStyle = CardStyle.NORMAL):
	"""Setup card with god data and style"""
	god_data = god
	current_style = style
	
	# Ensure structure is ready
	if not god_image:
		_setup_card_structure()
		
	# Apply card size immediately after structure setup
	_apply_card_size()
	
	# Populate data and apply style
	_populate_god_data()
	_apply_card_style()

func _setup_card_structure():
	"""Create the card UI structure based on size"""
	# Clear existing children
	for child in get_children():
		child.queue_free()
	
	# Main container with margins
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	# God image
	god_image = TextureRect.new()
	god_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	god_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(god_image)
	
	# God name
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)
	
	# Level and tier
	level_tier_label = Label.new()
	level_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_tier_label)
	
	# Experience bar (conditionally shown)
	if show_experience_bar:
		experience_container = VBoxContainer.new()
		experience_container.add_theme_constant_override("separation", 2)
		
		experience_bar = ProgressBar.new()
		experience_bar.min_value = 0.0
		experience_bar.max_value = 100.0
		experience_bar.show_percentage = false
		experience_container.add_child(experience_bar)
		
		vbox.add_child(experience_container)
	
	# Info label (power, element, etc.)
	if show_power_rating:
		info_label = Label.new()
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.modulate = Color.LIGHT_GRAY
		vbox.add_child(info_label)
	
	# Territory assignment indicator
	if show_territory_assignment:
		territory_indicator = Label.new()
		territory_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		territory_indicator.add_theme_font_size_override("font_size", 8)
		territory_indicator.modulate = Color.YELLOW
		vbox.add_child(territory_indicator)
	
	# Awakening status indicator
	if show_awakening_status:
		awakening_indicator = Label.new()
		awakening_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awakening_indicator.add_theme_font_size_override("font_size", 8)
		awakening_indicator.modulate = Color.GREEN
		vbox.add_child(awakening_indicator)
	
	# Make clickable if enabled - add button to margin container, not directly to card
	if clickable:
		var button = Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_card_clicked)
		margin.add_child(button)  # Add to margin instead of card root

func _apply_card_size():
	"""Apply size settings based on card_size"""
	# Don't apply if structure isn't set up yet
	if not god_image:
		return
		
	match card_size:
		CardSize.SMALL:
			custom_minimum_size = Vector2(70, 90)
			_set_margins(4, 4, 4, 4)
			god_image.custom_minimum_size = Vector2(40, 40)
			name_label.add_theme_font_size_override("font_size", 9)
			level_tier_label.add_theme_font_size_override("font_size", 8)
			if info_label:
				info_label.add_theme_font_size_override("font_size", 10)
		
		CardSize.MEDIUM:
			custom_minimum_size = Vector2(140, 200)
			_set_margins(7, 7, 7, 7)
			god_image.custom_minimum_size = Vector2(70, 70)
			name_label.add_theme_font_size_override("font_size", 12)
			level_tier_label.add_theme_font_size_override("font_size", 10)
			if info_label:
				info_label.add_theme_font_size_override("font_size", 11)
			if experience_bar:
				experience_bar.custom_minimum_size = Vector2(120, 10)
		
		CardSize.LARGE:
			custom_minimum_size = Vector2(160, 220)
			_set_margins(8, 8, 8, 8)
			god_image.custom_minimum_size = Vector2(80, 80)
			name_label.add_theme_font_size_override("font_size", 13)
			level_tier_label.add_theme_font_size_override("font_size", 11)
			if info_label:
				info_label.add_theme_font_size_override("font_size", 8)
			if experience_bar:
				experience_bar.custom_minimum_size = Vector2(140, 12)

func _set_margins(left: int, top: int, right: int, bottom: int):
	"""Set margins on the margin container"""
	var margin_container = get_child(0) as MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", left)
		margin_container.add_theme_constant_override("margin_right", right)
		margin_container.add_theme_constant_override("margin_top", top)
		margin_container.add_theme_constant_override("margin_bottom", bottom)

func _populate_god_data():
	"""Fill card with god data"""
	if not god_data:
		return
	
	# Load god image
	if god_image:
		var sprite_path = "res://assets/gods/" + god_data.id + ".png"
		if ResourceLoader.exists(sprite_path):
			god_image.texture = load(sprite_path)
		else:
			# Create a colorful placeholder instead of just null
			var placeholder_image = ImageTexture.new()
			var image = Image.create(100, 100, false, Image.FORMAT_RGB8)
			# Use element color for placeholder
			var element_color = _get_element_color(god_data.element)
			image.fill(element_color)
			placeholder_image.set_image(image)
			god_image.texture = placeholder_image
	
	# Set name with better styling
	if name_label:
		name_label.text = god_data.name
	
	# Set level and tier with better styling
	if level_tier_label:
		level_tier_label.text = "Lv.%d %s" % [god_data.level, _get_tier_short_name(god_data.tier)]
		level_tier_label.modulate = _get_tier_color(god_data.tier)
	
	# Set experience bar
	if experience_bar and god_data:
		var progress = _get_experience_progress(god_data)
		experience_bar.value = progress
		
		# Style experience bar
		var exp_fill_style = StyleBoxFlat.new()
		if god_data.level >= 40:
			exp_fill_style.bg_color = Color.GOLD
		else:
			exp_fill_style.bg_color = Color(0.2, 0.6, 1.0, 0.9)
		exp_fill_style.corner_radius_top_left = 3
		exp_fill_style.corner_radius_top_right = 3
		exp_fill_style.corner_radius_bottom_left = 3
		exp_fill_style.corner_radius_bottom_right = 3
		experience_bar.add_theme_stylebox_override("fill", exp_fill_style)
	
	# Set info label with enhanced information
	if info_label:
		var power = _get_power_rating(god_data)
		var element = _get_element_name(god_data.element)
		var tier_stars = _get_tier_stars(god_data.tier)
		
		# Get current stats through GodCalculator (RULE 3 compliance)
		var attack = GodCalculator.get_current_attack(god_data)
		var defense = GodCalculator.get_current_defense(god_data)
		var hp = GodCalculator.get_current_hp(god_data)
		var speed = GodCalculator.get_current_speed(god_data)
		
		# Get equipment count
		var equipped_count = 0
		for equipment in god_data.equipment:
			if equipment != null:
				equipped_count += 1
		
		var stats_text = "ATK:%d DEF:%d HP:%d SPD:%d" % [attack, defense, hp, speed]
		var equipment_text = "Equipment: %d/6" % equipped_count
		info_label.text = "%s %s | Power: %d\n%s\n%s" % [element, tier_stars, power, stats_text, equipment_text]
	
	# Set territory assignment
	if territory_indicator and god_data.stationed_territory != "":
		territory_indicator.text = "📍 " + god_data.stationed_territory.capitalize()
		territory_indicator.visible = true
	elif territory_indicator:
		territory_indicator.visible = false
	
	# Set awakening status
	if awakening_indicator:
		if god_data.tier >= God.TierType.EPIC and god_data.level >= 40:
			awakening_indicator.text = "✨ Ready to Awaken"
			awakening_indicator.visible = true
		else:
			awakening_indicator.visible = false

func _apply_card_style():
	"""Apply visual style based on current_style"""
	var style = StyleBoxFlat.new()
	
	match current_style:
		CardStyle.NORMAL:
			style.bg_color = _get_subtle_tier_color(god_data.tier if god_data else 0)
			style.border_color = _get_tier_border_color(god_data.tier if god_data else 0)
		
		CardStyle.SELECTED:
			style.bg_color = Color(0.4, 0.2, 0.6, 0.8)  # Purple for selected
			style.border_color = Color(0.8, 0.4, 1.0, 1.0)
		
		CardStyle.AWAKENING_READY:
			style.bg_color = Color(0.2, 0.4, 0.2, 0.8)  # Green for awakenable
			style.border_color = Color(1.0, 0.8, 0.2, 1.0)  # Gold border
		
		CardStyle.BATTLE_READY:
			style.bg_color = Color(0.2, 0.2, 0.4, 0.8)  # Blue for battle
			style.border_color = Color(0.2, 0.8, 1.0, 1.0)  # Cyan border
	
	# Apply border and corner radius
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	add_theme_stylebox_override("panel", style)

func _on_card_clicked():
	"""Handle card click"""
	if god_data:
		god_selected.emit(god_data)

# =============================================================================
# UTILITY FUNCTIONS - God data helpers
# =============================================================================

func _get_tier_short_name(tier: God.TierType) -> String:
	match tier:
		God.TierType.COMMON: return "Common"
		God.TierType.RARE: return "Rare"
		God.TierType.EPIC: return "Epic"
		God.TierType.LEGENDARY: return "Legend"
		_: return "Unknown"

func _get_tier_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.6, 0.6, 0.6, 1.0)    # Gray
		God.TierType.RARE: return Color(0.2, 0.6, 0.2, 1.0)      # Green
		God.TierType.EPIC: return Color(0.5, 0.3, 0.8, 1.0)      # Purple
		God.TierType.LEGENDARY: return Color(0.9, 0.7, 0.1, 1.0) # Gold
		_: return Color.WHITE

func _get_subtle_tier_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.2, 0.2, 0.2, 0.8)    # Dark gray
		God.TierType.RARE: return Color(0.1, 0.25, 0.1, 0.8)     # Dark green
		God.TierType.EPIC: return Color(0.2, 0.1, 0.3, 0.8)      # Dark purple
		God.TierType.LEGENDARY: return Color(0.3, 0.25, 0.05, 0.8) # Dark gold
		_: return Color(0.15, 0.15, 0.15, 0.8)

func _get_tier_border_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.4, 0.4, 0.4, 1.0)    # Gray
		God.TierType.RARE: return Color(0.2, 0.6, 0.2, 1.0)      # Green
		God.TierType.EPIC: return Color(0.5, 0.3, 0.8, 1.0)      # Purple
		God.TierType.LEGENDARY: return Color(0.9, 0.7, 0.1, 1.0) # Gold
		_: return Color.GRAY

func _get_element_name(element: God.ElementType) -> String:
	match element:
		God.ElementType.FIRE: return "🔥 Fire"
		God.ElementType.WATER: return "💧 Water"  
		God.ElementType.EARTH: return "🌍 Earth"
		God.ElementType.LIGHTNING: return "⚡ Lightning"
		God.ElementType.LIGHT: return "✨ Light"
		God.ElementType.DARK: return "🌙 Dark"
		_: return "⚪ Neutral"

func _get_element_color(element: God.ElementType) -> Color:
	"""Get color for element"""
	match element:
		God.ElementType.FIRE: return Color(1.0, 0.4, 0.2, 1.0)
		God.ElementType.WATER: return Color(0.2, 0.6, 1.0, 1.0) 
		God.ElementType.EARTH: return Color(0.6, 0.8, 0.2, 1.0)
		God.ElementType.LIGHTNING: return Color(1.0, 1.0, 0.2, 1.0)
		God.ElementType.LIGHT: return Color(1.0, 1.0, 0.8, 1.0)
		God.ElementType.DARK: return Color(0.4, 0.2, 0.6, 1.0)
		_: return Color(0.5, 0.5, 0.5, 1.0)

func _get_tier_stars(tier: int) -> String:
	"""Get star display for god tier (0-based)"""
	match tier:
		0: return "⭐"           # Common - 1 star
		1: return "⭐⭐"         # Rare - 2 stars  
		2: return "⭐⭐⭐"       # Epic - 3 stars
		3: return "⭐⭐⭐⭐"     # Legendary - 4 stars
		_: return "⭐"           # Default to 1 star

func _get_power_rating(god: God) -> int:
	"""Calculate power rating using GodCalculator - RULE 3 compliance"""
	if not god:
		return 0
	
	# Use GodCalculator for proper stat calculation (RULE 3: no logic in data classes)
	return GodCalculator.get_power_rating(god)

func _get_experience_progress(god: God) -> float:
	"""Get experience progress percentage"""
	if not god or god.level >= 40:
		return 100.0
	
	# Simple progress calculation - can be enhanced with proper exp tables
	var current_level_base = god.level * 100
	var next_level_base = (god.level + 1) * 100
	var level_exp_needed = next_level_base - current_level_base
	var current_level_progress = god.experience - current_level_base
	
	if level_exp_needed <= 0:
		return 100.0
	
	return (float(current_level_progress) / float(level_exp_needed)) * 100.0
