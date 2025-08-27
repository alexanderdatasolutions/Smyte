class_name Territory
extends Resource

"""
Territory.gd - Pure data class for territory information
RULE 3: NO LOGIC IN DATA CLASSES - Only properties and simple getters
RULE 1: Under 150 lines - Data only

Following prompt.prompt.md architecture:
- DATA LAYER: Think database tables
- ONLY properties, NO complex methods
"""

enum ElementType { FIRE, WATER, EARTH, LIGHTNING, LIGHT, DARK }

# Core territory data
@export var id: String
@export var name: String  
@export var tier: int = 1  # 1-3 for difficulty tiers
@export var element: ElementType
@export var required_power: int = 1000  # Base power requirement

# Territory control
@export var controller: String = ""  # "player" or "neutral"
@export var current_stage: int = 0  # Stages cleared (0-10)
@export var max_stages: int = 10  # Total stages in territory
@export var is_unlocked: bool = false  # Fully captured

# Resource generation data
@export var base_resource_rate: int = 10  # Base resources per hour
@export var last_resource_generation: float = 0.0  # Last generation timestamp
@export var last_collection_time: float = 0.0  # Last manual collection

# Territory upgrades
@export var territory_level: int = 1
@export var resource_upgrades: int = 0
@export var defense_upgrades: int = 0
@export var zone_upgrades: int = 0

# God assignments
@export var stationed_gods: Array[String] = []  # God IDs
@export var max_god_slots: int = 3

# Configuration
@export var auto_collection_mode: String = "manual"
@export var territory_data: Dictionary = {}  # JSON data

# Simple getters only (RULE 3: No complex logic)
func get_element_name() -> String:
	match element:
		ElementType.FIRE: return "Fire"
		ElementType.WATER: return "Water" 
		ElementType.EARTH: return "Earth"
		ElementType.LIGHTNING: return "Lightning"
		ElementType.LIGHT: return "Light"
		ElementType.DARK: return "Dark"
		_: return "Unknown"

func is_controlled_by_player() -> bool:
	return controller == "player"

func get_progress_ratio() -> float:
	if max_stages <= 0: return 0.0
	return float(current_stage) / float(max_stages)
