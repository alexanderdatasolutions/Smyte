class_name TerritoryScreen
extends Control

"""
TerritoryScreen.gd - Enhanced territory management screen with rich UI functionality
RULE 2: Single responsibility - ONLY orchestrates territory UI display
RULE 4: No data modification - delegates to systems through SystemRegistry  
RULE 5: Uses SystemRegistry for all system access

Following prompt.prompt.md architecture:
- UI LAYER: Only display, no data modification
- Restores all rich functionality from old_territory_role_screen.gd while maintaining clean architecture
"""

signal back_pressed

# Enhanced UI coordinator with full functionality
const TerritoryScreenCoordinatorScript = preload("res://scripts/ui/territory/TerritoryScreenCoordinator.gd")
var territory_coordinator: TerritoryScreenCoordinator

func _ready():
	# Create the enhanced territory UI coordinator
	_setup_enhanced_territory_interface()

func _setup_enhanced_territory_interface():
	"""Setup the full-featured territory interface using the coordinator pattern"""
	# Create the enhanced coordinator (this replaces all the old complex logic)
	territory_coordinator = TerritoryScreenCoordinatorScript.new()
	territory_coordinator.name = "TerritoryCoordinator"

	# Set coordinator to fill the entire screen
	territory_coordinator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Add coordinator to scene tree
	add_child(territory_coordinator)

	# Connect the coordinator's back signal
	territory_coordinator.back_pressed.connect(_on_back_pressed)

func _on_back_pressed():
	"""Handle back button press - RULE 4: UI signals"""
	back_pressed.emit()
