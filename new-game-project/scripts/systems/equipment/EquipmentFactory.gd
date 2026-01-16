# scripts/systems/collection/EquipmentFactory.gd
# Single responsibility: Create and initialize Equipment instances
extends RefCounted
class_name EquipmentFactory

# ==============================================================================
# EQUIPMENT FACTORY - Handle equipment creation and initialization
# ==============================================================================

static func create_from_json(equipment_id: String) -> Equipment:
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	var equipment_config = config_manager.get_equipment_config()
	
	if not equipment_config.has("equipment"):
		push_error("Equipment config missing 'equipment' section")
		return null
	
	var equipment_data = equipment_config["equipment"].get(equipment_id)
	if not equipment_data:
		push_error("Equipment data not found for ID: " + equipment_id)
		return null
	
	var equipment = Equipment.new()
	equipment.id = equipment_id
	equipment.name = equipment_data.get("name", "Unknown Equipment")
	equipment.type = equipment_data.get("type", 0) as Equipment.EquipmentType
	equipment.rarity = equipment_data.get("rarity", 0) as Equipment.Rarity
	equipment.slot = equipment_data.get("slot", 1)
	
	# Set information
	equipment.equipment_set_name = equipment_data.get("equipment_set_name", "")
	equipment.equipment_set_type = equipment_data.get("equipment_set_type", "")
	
	# Main stat
	equipment.main_stat_type = equipment_data.get("main_stat_type", "")
	equipment.main_stat_base = equipment_data.get("main_stat_base", 0)
	equipment.main_stat_value = equipment.main_stat_base  # Start at base value
	
	# Substats
	equipment.substats = equipment_data.get("substats", []).duplicate()
	
	# Sockets
	equipment.max_sockets = equipment_data.get("max_sockets", 0)
	equipment.sockets = []
	for i in range(equipment.max_sockets):
		equipment.sockets.append({"type": "empty", "gem": null})
	
	# Initialize level
	equipment.level = 0
	
	return equipment
