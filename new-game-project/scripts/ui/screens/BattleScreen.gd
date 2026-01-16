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
	# Connect back button (RULE 4: UI signals)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	"""Handle back button press - RULE 4: UI signals"""
	back_pressed.emit()

func start_battle(battle_config: Dictionary):
	"""Start a battle with given configuration - RULE 5: SystemRegistry"""
	# Delegate to battle system through SystemRegistry
	var battle_coordinator = SystemRegistry.get_instance().get_system("BattleCoordinator")
	if battle_coordinator:
		battle_coordinator.start_battle(battle_config)

func _on_battle_ended(_result: Dictionary):
	"""Handle battle end - RULE 4: UI listens to events"""
	# Update UI based on result
	# Individual UI components handle their own updates via EventBus
	pass
