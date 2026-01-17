# Territory System Analysis

## Files Analyzed
- TerritoryManager.gd (278 lines) - Territory ownership, capture/loss, upgrades, filtering for UI
- TerritoryProductionManager.gd (211 lines) - Resource generation from controlled territories
- Territory.gd (65 lines, data layer) - Pure data class for territory information

## What It Does
The territory system manages map control mechanics where players capture, upgrade, and extract resources from territories. It's modeled after idle/incremental game mechanics combined with strategy elements:

1. **Territory Control**: Players capture territories through battles, can lose them, and upgrade them for bonuses
2. **Resource Generation**: Controlled territories passively generate resources (mana, gold, element-specific materials) based on level, upgrades, and stationed gods
3. **God Stationing**: Gods can be assigned to territories for production bonuses, with element matching providing extra yield
4. **Progress Gating**: Maximum territories scale with player level (base 3, +1 per 5 levels)

## Status: PARTIAL

The system has solid structure but significant integration issues that would cause runtime errors.

## Code Quality
- [x] Clean architecture - Good separation between manager and production system
- [x] Proper typing - Strong typing with typed arrays and explicit types
- [ ] Error handling - Some null checks but missing in critical paths
- [x] Comments/docs - Good documentation following established rules

## Key Findings

1. **Two-layer design**: TerritoryManager handles ownership/state while TerritoryProductionManager handles resource generation. Clean separation of concerns.

2. **Dual data format support**: TerritoryManager's `get_territories_by_filter()` handles both array and dictionary config formats, showing defensive coding.

3. **Idle game mechanics**: Production system calculates offline progress using timestamps, with automatic 1-minute collection cycles.

4. **Element-based bonuses**: 30% production boost when stationed god's element matches territory element, similar to gacha game meta.

5. **Tiered resource distribution**: Higher tier territories produce premium resources (crystals at tier 2, divine essence at tier 3).

## Issues Found

1. **Class name mismatch**: TerritoryManager.gd declares `class_name TerritoryController` (line 3) but is registered and called as "TerritoryManager" throughout the codebase. This will cause class lookup failures.

2. **Type mismatch between files**:
   - TerritoryManager uses Dictionary-based territory data (line 211-224)
   - TerritoryProductionManager expects Territory Resource objects (line 50: `territory: Territory`)
   - `_get_territory_data()` calls `get_territory_by_id()` method that doesn't exist on TerritoryManager

3. **Missing method**: TerritoryProductionManager calls `territory_manager.get_territory_by_id()` (line 189) but TerritoryManager only has `get_territory_info()` which returns Dictionary, not Territory.

4. **Element type mismatch**: TerritoryProductionManager references `Territory.ElementType` enum (lines 145-154) but TerritoryManager uses string-based elements in dictionaries.

5. **Stub implementations**:
   - `get_pending_resources()` returns empty `{}` (line 247)
   - `collect_territory_resources()` returns `{"total": 0}` (line 252)
   - These stubs would prevent resource collection from working

6. **Config dependency undefined**: `config_manager.get_territories_config()` is called (line 20) but the ConfigurationManager's territory config loading is not verified.

7. **Missing Territory instantiation**: No code creates actual Territory Resource objects - the system works with dictionaries in TerritoryManager but expects typed Territory objects in ProductionManager.

## Dependencies

**Depends on:**
- SystemRegistry (core) - Service location
- ConfigurationManager (core) - Territory configuration data
- ResourceManager (resources) - Adding collected resources
- PlayerProgressionManager (progression) - Player level for territory caps
- CollectionManager (collection) - God data for stationed god bonuses
- EventBus (core) - Territory capture/loss notifications

**Used by:**
- UI screens (TerritoryScreen, various territory UI components)
- Battle system (territories can be battle locations)

## Architectural Notes

The system shows signs of being partially refactored:
- TerritoryManager has been enhanced with UI helper methods (`get_territories_by_filter`, `get_all_territories`)
- TerritoryProductionManager expects a cleaner typed API that doesn't exist
- The data model (Territory.gd) exists but isn't being used by TerritoryManager

To make this functional would require:
1. Fixing the class_name mismatch
2. Choosing one approach: either Dictionary-based (current TerritoryManager) or Resource-based (what ProductionManager expects)
3. Implementing the actual resource generation instead of stub methods
4. Creating Territory objects from config data
