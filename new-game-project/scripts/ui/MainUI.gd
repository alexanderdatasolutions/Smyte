# scripts/ui/MainUI.gd
extends Control

@onready var collection_screen = $MainPanel/TabContainer/Collection
@onready var summon_screen = $MainPanel/TabContainer/Summon
@onready var territory_screen = $MainPanel/TabContainer/Territory
@onready var dungeon_screen = $"MainPanel/TabContainer/Dungeons"
@onready var resource_display = $ResourcePanel/ResourceDisplay

# Dungeon system reference
var dungeon_system: Node

func _ready():
	# Initialize dungeon system
	_initialize_dungeon_system()
	
	# Connect to GameManager signals
	if GameManager:
		GameManager.god_summoned.connect(_on_god_summoned)
		GameManager.territory_captured.connect(_on_territory_captured)
		GameManager.resources_updated.connect(_on_resources_updated)
	
	# Connect to level up signals for all existing gods
	_connect_to_existing_gods()
	
	# Connect to tab container changes
	var tab_container = $MainPanel/TabContainer
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)

func _initialize_dungeon_system():
	"""Initialize the dungeon system"""
	# Create dungeon system if it doesn't exist
	dungeon_system = get_node_or_null("/root/DungeonSystem")
	if not dungeon_system:
		var dungeon_system_script = preload("res://scripts/systems/DungeonSystem.gd")
		dungeon_system = dungeon_system_script.new()
		dungeon_system.name = "DungeonSystem"
		get_tree().root.add_child(dungeon_system)

func _connect_to_existing_gods():
	"""Connect to level up signals for all current gods"""
	if GameManager and GameManager.player_data:
		for god in GameManager.player_data.gods:
			if not god.level_up.is_connected(_on_god_level_up):
				god.level_up.connect(_on_god_level_up)

func _on_god_summoned(god):
	collection_screen.refresh_collection()
	# Connect to level up signal for new god
	if not god.level_up.is_connected(_on_god_level_up):
		god.level_up.connect(_on_god_level_up)

func _on_territory_captured(_territory):
	territory_screen.refresh_territories()

func _on_resources_updated():
	# Refresh resource display and collection when resources/XP update
	if resource_display:
		resource_display.update_resources()
	if collection_screen:
		collection_screen.refresh_collection()

func _on_tab_changed(tab_index: int):
	"""Handle tab changes to refresh content when needed"""
	match tab_index:
		3:  # Dungeons tab
			if dungeon_screen and dungeon_screen.has_method("refresh_dungeons"):
				dungeon_screen.refresh_dungeons()

func _on_god_level_up(god):
	"""Show level up notification"""
	show_level_up_notification(god)

func show_level_up_notification(god: God):
	"""Display a level up notification popup"""
	var popup = AcceptDialog.new()
	popup.title = "LEVEL UP!"
	popup.size = Vector2(300, 200)
	
	var content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(280, 150)
	
	var title_label = Label.new()
	title_label.text = "🎉 LEVEL UP! 🎉"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	content.add_child(title_label)
	
	var god_info = Label.new()
	god_info.text = """%s reached Level %d!

Power Rating: %d
HP: %d | ATK: %d
DEF: %d | SPD: %d

%s has been fully healed!""" % [
		god.name, god.level, god.get_power_rating(),
		god.get_max_hp(), god.get_current_attack(),
		god.get_current_defense(), god.get_current_speed(),
		god.name
	]
	god_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(god_info)
	
	popup.add_child(content)
	get_tree().root.add_child(popup)
	popup.popup_centered()
	
	# Auto-close after 3 seconds
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func(): popup.queue_free())
	popup.add_child(timer)
	timer.start()
