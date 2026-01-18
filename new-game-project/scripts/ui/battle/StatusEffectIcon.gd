# scripts/ui/battle/StatusEffectIcon.gd
# Single status effect icon with tooltip display
# RULE 2: Single responsibility - displays a single StatusEffect
class_name StatusEffectIcon extends Control

const ICON_SIZE := Vector2(32, 32)  # Increased from 18x18 for better visibility and hover area

var status_effect: StatusEffect = null
var tooltip_panel: Panel = null

func _init():
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(effect: StatusEffect):
	"""Setup the icon with a StatusEffect"""
	status_effect = effect
	_build_icon()

func _build_icon():
	"""Build the icon UI structure"""
	if not status_effect:
		return

	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Background panel with effect color
	var bg_panel = Panel.new()
	bg_panel.custom_minimum_size = ICON_SIZE
	bg_panel.size = ICON_SIZE
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through to parent
	add_child(bg_panel)

	# Style the background based on effect type and color
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = _get_effect_background_color()
	bg_style.border_color = _get_border_color()
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bg_panel.add_theme_stylebox_override("panel", bg_style)

	# Symbol label based on effect
	var symbol_label = Label.new()
	symbol_label.custom_minimum_size = ICON_SIZE
	symbol_label.size = ICON_SIZE
	symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol_label.add_theme_font_size_override("font_size", 10)
	symbol_label.text = _get_effect_symbol()
	symbol_label.modulate = _get_effect_type_color()
	symbol_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through to parent
	add_child(symbol_label)

	# Stack count label (if stackable and has stacks > 1)
	if status_effect.can_stack and status_effect.stacks > 1:
		_add_stack_indicator()

	# Duration indicator at bottom
	if status_effect.duration > 0:
		_add_duration_indicator()

	# Setup tooltip
	_setup_tooltip()

func _add_stack_indicator():
	"""Add stack count indicator in corner"""
	# Small dark background for readability
	var stack_bg = Panel.new()
	stack_bg.custom_minimum_size = Vector2(8, 8)
	stack_bg.size = Vector2(8, 8)
	stack_bg.position = Vector2(ICON_SIZE.x - 9, ICON_SIZE.y - 10)
	stack_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through to parent
	var stack_style = StyleBoxFlat.new()
	stack_style.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	stack_style.corner_radius_top_left = 2
	stack_style.corner_radius_top_right = 2
	stack_style.corner_radius_bottom_left = 2
	stack_style.corner_radius_bottom_right = 2
	stack_bg.add_theme_stylebox_override("panel", stack_style)
	add_child(stack_bg)

	var stack_label = Label.new()
	stack_label.text = str(status_effect.stacks)
	stack_label.add_theme_font_size_override("font_size", 7)
	stack_label.modulate = Color.WHITE
	stack_label.position = Vector2(ICON_SIZE.x - 7, ICON_SIZE.y - 9)
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through to parent
	add_child(stack_label)

func _add_duration_indicator():
	"""Add duration indicator at bottom-left"""
	var duration_label = Label.new()
	duration_label.text = str(status_effect.duration)
	duration_label.add_theme_font_size_override("font_size", 10)  # Increased from 6 to 10 for better visibility
	duration_label.modulate = Color.WHITE  # Changed from LIGHT_GRAY to WHITE for better visibility
	duration_label.position = Vector2(1, ICON_SIZE.y - 12)
	duration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow mouse events to pass through to parent
	add_child(duration_label)

func _setup_tooltip():
	"""Setup tooltip panel that shows on hover"""
	print("StatusEffectIcon: Setting up tooltip for effect: %s" % status_effect.name)
	tooltip_panel = Panel.new()
	tooltip_panel.name = "Tooltip"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100

	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	tooltip_style.border_color = _get_border_color()
	tooltip_style.border_width_left = 1
	tooltip_style.border_width_right = 1
	tooltip_style.border_width_top = 1
	tooltip_style.border_width_bottom = 1
	tooltip_style.corner_radius_top_left = 4
	tooltip_style.corner_radius_top_right = 4
	tooltip_style.corner_radius_bottom_left = 4
	tooltip_style.corner_radius_bottom_right = 4
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)

	# Tooltip content
	var tooltip_margin = MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 6)
	tooltip_margin.add_theme_constant_override("margin_right", 6)
	tooltip_margin.add_theme_constant_override("margin_top", 4)
	tooltip_margin.add_theme_constant_override("margin_bottom", 4)
	tooltip_panel.add_child(tooltip_margin)

	var tooltip_vbox = VBoxContainer.new()
	tooltip_vbox.add_theme_constant_override("separation", 2)
	tooltip_margin.add_child(tooltip_vbox)

	# Effect name
	var name_label = Label.new()
	name_label.text = status_effect.name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.modulate = _get_border_color()
	tooltip_vbox.add_child(name_label)

	# Effect description
	if status_effect.description != "":
		var desc_label = Label.new()
		desc_label.text = status_effect.description
		desc_label.add_theme_font_size_override("font_size", 8)
		desc_label.modulate = Color.LIGHT_GRAY
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size.x = 120
		tooltip_vbox.add_child(desc_label)

	# Duration and stacks info
	var info_label = Label.new()
	var info_text = "%d turns remaining" % status_effect.duration
	if status_effect.can_stack and status_effect.stacks > 1:
		info_text += " | %d stacks" % status_effect.stacks
	info_label.text = info_text
	info_label.add_theme_font_size_override("font_size", 7)
	info_label.modulate = Color.GRAY
	tooltip_vbox.add_child(info_label)

	# Position tooltip above the icon
	tooltip_panel.position = Vector2(-50, -70)
	tooltip_panel.custom_minimum_size = Vector2(140, 60)

	add_child(tooltip_panel)

	# Connect mouse events
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	print("StatusEffectIcon: Mouse entered on %s" % status_effect.name)
	if tooltip_panel:
		tooltip_panel.visible = true
		print("StatusEffectIcon: Showing tooltip")
	else:
		print("StatusEffectIcon: WARNING - No tooltip panel!")

func _on_mouse_exited():
	print("StatusEffectIcon: Mouse exited from %s" % status_effect.name)
	if tooltip_panel:
		tooltip_panel.visible = false

func _get_effect_background_color() -> Color:
	"""Get background color based on effect type"""
	match status_effect.effect_type:
		StatusEffect.EffectType.BUFF:
			return Color(0.1, 0.25, 0.1, 0.9)
		StatusEffect.EffectType.DEBUFF:
			return Color(0.25, 0.1, 0.1, 0.9)
		StatusEffect.EffectType.DOT:
			return Color(0.25, 0.15, 0.1, 0.9)
		StatusEffect.EffectType.HOT:
			return Color(0.1, 0.2, 0.15, 0.9)
		_:
			return Color(0.15, 0.15, 0.15, 0.9)

func _get_effect_type_color() -> Color:
	"""Get accent color based on effect type"""
	match status_effect.effect_type:
		StatusEffect.EffectType.BUFF:
			return Color.LIME_GREEN
		StatusEffect.EffectType.DEBUFF:
			return Color.INDIAN_RED
		StatusEffect.EffectType.DOT:
			return Color.ORANGE_RED
		StatusEffect.EffectType.HOT:
			return Color.MEDIUM_SEA_GREEN
		_:
			return Color.WHITE

func _get_border_color() -> Color:
	"""Get border color - use effect color if set, otherwise type color"""
	if status_effect.color != Color.WHITE:
		return status_effect.color
	return _get_effect_type_color()

func _get_effect_symbol() -> String:
	"""Get a visual symbol for the effect based on its id or type"""
	# Specific effect symbols based on effect id
	match status_effect.id:
		"stun": return "S"
		"burn", "burning": return "F"
		"poison", "poisoned": return "P"
		"freeze", "frozen": return "I"
		"sleep", "sleeping": return "Z"
		"bleed", "bleeding": return "B"
		"regeneration": return "R"
		"shield": return "D"
		"attack_boost": return "A"
		"defense_boost": return "D"
		"speed_boost": return "S"
		"slow", "slowed": return "W"
		"debuff_immunity": return "I"
		"damage_immunity": return "X"
		"blind", "blinded": return "E"
		"silence", "silenced": return "M"
		"fear", "feared": return "F"
		"charm", "charmed": return "H"
		"provoke", "provoked": return "T"
		"counter_attack": return "C"
		"reflect_damage": return "R"
		"curse", "cursed": return "K"
		"heal_block": return "X"
		"continuous_damage": return "!"
		"accuracy_boost": return "A"
		"evasion_boost": return "E"
		"crit_boost", "crit_damage_boost": return "C"
		"attack_reduction": return "a"
		"defense_reduction": return "d"
		"marked_for_death", "analyze_weakness": return "M"
		"untargetable": return "G"
		"immobilize", "immobilized": return "L"
		"wisdom_boost": return "W"

	# Fallback to type-based symbols
	match status_effect.effect_type:
		StatusEffect.EffectType.BUFF:
			return "+"
		StatusEffect.EffectType.DEBUFF:
			return "-"
		StatusEffect.EffectType.DOT:
			return "o"
		StatusEffect.EffectType.HOT:
			return "+"
		_:
			return "?"
