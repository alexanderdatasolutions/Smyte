class_name BattleScreen
extends Control

"""
BattleScreen.gd - Main battle screen coordinator
RULE 2: Single responsibility - ONLY coordinates battle UI components
RULE 4: No logic in UI - delegates to systems through SystemRegistry
RULE 5: Uses SystemRegistry for all system access

Following prompt.prompt.md architecture:
- UI LAYER: Only display, no data modification
- Coordinates battle UI components (BattleUICoordinator, etc.)
"""

# UI Components (following RULE 2: Single responsibility)
@onready var battle_ui_coordinator = $BattleUICoordinator
@onready var back_button = $BackButton

# Signal for screen navigation (RULE 4: UI signals)
signal back_pressed

func _ready():
	print("BattleScreen: Initializing battle screen coordinator")
	
	# Connect back button (RULE 4: UI signals)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Initialize battle UI coordinator if available
	if battle_ui_coordinator:
		print("BattleScreen: Battle UI coordinator found")
	else:
		print("BattleScreen: No battle UI coordinator - battle UI split into separate files")
	
	print("BattleScreen: Battle screen ready")

func _on_back_pressed():
	"""Handle back button press - RULE 4: UI signals"""
	print("BattleScreen: Back button pressed")
	back_pressed.emit()

func start_battle(battle_config: Dictionary):
	"""Start a battle with given configuration - RULE 5: SystemRegistry"""
	print("BattleScreen: Starting battle with config: %s" % battle_config)
	
	# Delegate to battle system through SystemRegistry
	var battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")
	if battle_coordinator:
		battle_coordinator.start_battle(battle_config)
	else:
		print("BattleScreen: ERROR - BattleCoordinator not found")

func _on_battle_ended(result: Dictionary):
	"""Handle battle end - RULE 4: UI listens to events"""
	print("BattleScreen: Battle ended with result: %s" % result)
	
	# Update UI based on result
	# Individual UI components handle their own updates via EventBus
