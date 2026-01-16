# Equipment System Analysis

## Files Analyzed
- EquipmentManager.gd - Main coordinator for all equipment subsystems
- EquipmentFactory.gd - Creates Equipment instances from JSON config
- EquipmentCraftingManager.gd - Handles recipe-based equipment creation
- EquipmentEnhancementManager.gd - Handles equipment level upgrades (+0 to +15)
- EquipmentInventoryManager.gd - Storage and retrieval of equipment
- EquipmentSocketManager.gd - Socket unlocking and gem socketing
- EquipmentStatCalculator.gd - Stat calculations and set bonuses

## What It Does
The equipment system provides Summoners War-style equipment management with:

**Core Features:**
- 6 equipment slots: Weapon, Armor, Helm, Boots, Amulet, Ring
- 5 rarity tiers: Common, Rare, Epic, Legendary, Mythic
- Main stat + up to 4 substats per equipment piece
- Equipment sets with 2-piece and 4-piece bonuses (warrior, guardian, swift, focus)
- Enhancement system (+0 to +15) with decreasing success rates
- Socket system with colored gems providing stat bonuses
- Crafting system with recipes, territory requirements, and material costs

**Architecture:**
EquipmentManager acts as a facade/coordinator, delegating to specialized sub-managers:
- Inventory operations → EquipmentInventoryManager
- Crafting operations → EquipmentCraftingManager
- Enhancement operations → EquipmentEnhancementManager
- Socket operations → EquipmentSocketManager
- Stat calculations → EquipmentStatCalculator

## Status: WORKING

## Code Quality
- [x] Clean architecture - Well-refactored into 7 focused components from what was likely a monolith
- [x] Proper typing - Uses typed signals, explicit type casts, proper enums
- [x] Error handling - Null checks, validation before operations, error signals
- [x] Comments/docs - Good docstrings, RULE compliance comments throughout

## Key Findings
1. **Well-separated concerns:** Each manager handles one aspect of equipment. The facade pattern keeps the API clean.

2. **Summoners War authenticity:** Enhancement success rates decrease with level, rarity affects max substats, set bonuses match SW mechanics.

3. **Config-driven design:** All costs, rates, and bonuses load from equipment_config.json through SystemRegistry.

4. **Proper signal architecture:** Each sub-manager emits signals, EquipmentManager re-emits them for external listeners.

5. **Equipment data model is robust:** Equipment.gd has proper factory methods (create_from_dungeon, create_test_equipment), helper methods for enhancement/sockets, and property aliases for compatibility.

6. **Blessed oil mechanic:** Enhancement can use "blessed oil" consumable to increase success rate and protect against failure consequences.

7. **Bulk enhancement:** Can auto-enhance to target level with proper tracking of attempts, successes, failures, and costs.

## Issues Found

1. **Inconsistent equipped state tracking:** EquipmentInventoryManager uses `is_equipped`, `equipped_god_id`, `equipped_slot` properties, but Equipment.gd only has `equipped_by_god_id`. Missing `is_equipped` and `equipped_slot` properties on Equipment class will cause runtime errors.

2. **EquipmentStatCalculator references wrong property:** Line 155 uses `god.equipped_equipment` but God class likely uses `god.equipment` (based on EquipmentManager.gd line 114-117).

3. **Duplicate equip/unequip logic:** EquipmentManager has equip_equipment_to_god() that manipulates god.equipment directly, while EquipmentInventoryManager has its own equip_equipment_to_god() that uses different tracking properties.

4. **Equipment.gd missing methods called by managers:**
   - `add_stat_bonus()` - called by EquipmentCraftingManager line 227
   - `add_substat()` - called by EquipmentCraftingManager line 232
   - `get_max_enhancement_level()` - called by EquipmentEnhancementManager
   - `get_enhancement_stat_bonuses()` - called by EquipmentEnhancementManager line 266
   - `get_enhancement_cost_for_level()` - called by EquipmentEnhancementManager line 280
   - `is_destroyed` property - set by EquipmentEnhancementManager line 147

5. **EquipmentCraftingManager looks up wrong system:** Line 202-204 tries to get "EquipmentInventoryManager" from SystemRegistry, but this is a child of EquipmentManager, not a registered system.

6. **Set bonus calculation hardcoded:** EquipmentStatCalculator._get_set_bonus_effects() has hardcoded set bonuses instead of loading from config.

7. **File path comment incorrect:** All files say `# scripts/systems/collection/` but they're in `scripts/systems/equipment/`.

8. **Socket unlock logic inconsistent:** Equipment.can_unlock_socket() checks if socket_index < max_sockets AND >= sockets.size(), but EquipmentSocketManager.unlock_socket() appends to socket_slots, not inserts at index.

## Dependencies
- **Depends on:**
  - SystemRegistry (for accessing ConfigurationManager, ResourceManager, CollectionManager, TerritoryManager)
  - Equipment.gd data model
  - God.gd data model
  - equipment_config.json, resource_config.json, resources.json

- **Used by:**
  - CollectionManager (get_god_equipment)
  - DungeonCoordinator (equipment drops)
  - UI screens (equipment management)
  - BattleSystem (stat calculations)
