# scripts/ui/WorldView.gd - Main world view with floating buildings like Summoners War
extends Control

@onready var summon_button = $HBoxContainer/SummonButton
@onready var collection_button = $HBoxContainer/CollectionButton
@onready var territory_button = $HBoxContainer/TerritoryButton
@onready var sacrifice_button = $HBoxContainer/SacrificeButton
@onready var dungeon_button = $HBoxContainer/DungeonButton
@onready var equipment_button = $HBoxContainer/EquipmentButton

# Screen references (will be created dynamically or loaded)
var summon_screen_scene = preload("res://scenes/SummonScreen.tscn")
var collection_screen_scene = preload("res://scenes/CollectionScreen.tscn") 
var territory_screen_scene = preload("res://scenes/TerritoryScreen.tscn")
var sacrifice_screen_scene = preload("res://scenes/SacrificeScreen.tscn")
var dungeon_screen_scene = preload("res://scenes/DungeonScreen.tscn")
var equipment_screen_scene = preload("res://scenes/EquipmentScreen.tscn")

func _ready():
	# Connect building buttons
	if summon_button:
		summon_button.pressed.connect(_on_summon_building_pressed)
	if collection_button:
		collection_button.pressed.connect(_on_collection_building_pressed)
	if territory_button:
		territory_button.pressed.connect(_on_territory_building_pressed)
	if sacrifice_button:
		sacrifice_button.pressed.connect(_on_sacrifice_building_pressed)
	if dungeon_button:
		dungeon_button.pressed.connect(_on_dungeon_building_pressed)
	if equipment_button:
		equipment_button.pressed.connect(_on_equipment_building_pressed)

func _on_summon_building_pressed():
	print("Opening Summon Temple...")
	_open_screen(summon_screen_scene)

func _on_collection_building_pressed():
	print("Opening God Collection...")
	_open_screen(collection_screen_scene)

func _on_territory_building_pressed():
	print("Opening Territory Command...")
	_open_screen(territory_screen_scene)

func _on_sacrifice_building_pressed():
	print("Opening Power Up Altar...")
	_open_screen(sacrifice_screen_scene)

func _on_dungeon_building_pressed():
	print("Opening Dungeons Sanctum...")
	_open_screen(dungeon_screen_scene)

func _on_equipment_building_pressed():
	print("Opening Equipment Forge...")
	_open_screen(equipment_screen_scene)

func _open_screen(screen_scene: PackedScene):
	# This will transition to the specific screen
	# For now, just instantiate and add to scene tree
	if screen_scene:
		var screen_instance = screen_scene.instantiate()
		
		# Add to the scene tree root instead of current_scene
		get_tree().root.add_child(screen_instance)
		
		# Hide the world view
		visible = false
		
		# Connect back button if the screen has one
		if screen_instance.has_signal("back_pressed"):
			screen_instance.back_pressed.connect(_on_screen_back_pressed.bind(screen_instance))

func _on_screen_back_pressed(screen_instance: Node):
	# Return to world view
	visible = true
	screen_instance.queue_free()
