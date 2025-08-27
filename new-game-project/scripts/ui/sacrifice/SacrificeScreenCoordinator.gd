# scripts/ui/sacrifice/SacrificeScreenCoordinator.gd
# Single responsibility: Coordinate the sacrifice screen with tabs
class_name SacrificeScreenCoordinator
extends Control

signal back_pressed

@onready var back_button = $BackButton
@onready var tab_container = $ContentContainer/TabContainer

var sacrifice_tab_manager: SacrificeTabManager
var awakening_tab_manager: AwakeningTabManager

func _ready():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	_setup_tab_managers()
	_setup_tabs()

func _setup_tab_managers():
	sacrifice_tab_manager = SacrificeTabManager.new()
	add_child(sacrifice_tab_manager)
	
	awakening_tab_manager = AwakeningTabManager.new()
	add_child(awakening_tab_manager)

func _setup_tabs():
	var sacrifice_tab = sacrifice_tab_manager.create_sacrifice_tab()
	tab_container.add_child(sacrifice_tab)
	
	var awakening_tab = awakening_tab_manager.create_awakening_tab()
	tab_container.add_child(awakening_tab)

func _on_back_pressed():
	back_pressed.emit()
