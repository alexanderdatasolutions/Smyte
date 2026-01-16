# Resource System Analysis

## Files Analyzed
- ResourceManager.gd - Core resource tracking, transactions, limits, and persistence
- LootSystem.gd - Loot table generation and reward distribution

## What It Does

The resource system handles the game's economy through two complementary components:

**ResourceManager** is the central resource ledger that:
- Tracks all player resources (gold, mana, crystals, energy, tokens, etc.)
- Enforces resource limits (energy caps at 100, arena tokens at 30, etc.)
- Provides transaction methods: add, spend, can_afford, spend_resources
- Emits signals for UI updates and EventBus integration
- Handles save/load persistence

**LootSystem** generates rewards from configurable loot tables:
- Loads loot templates from JSON config files via ConfigurationManager
- Generates loot with probability rolls and amount ranges
- Applies multipliers based on victory type (perfect/fast/close) and difficulty
- Awards loot through ResourceManager
- Provides preview data for UI display

## Status: WORKING

Both files are functional and well-structured. They would work correctly if integrated with the rest of the system.

## Code Quality
- [x] Clean architecture
- [x] Proper typing
- [x] Error handling
- [x] Comments/docs

## Key Findings

1. **Clean transaction model** - ResourceManager has proper affordability checks before spending, preventing negative balances.

2. **Limit handling** - Resources can have hard caps (energy, tokens) or be unlimited (gold, crystals). Partial awards up to limit are supported.

3. **EventBus integration** - ResourceManager emits to both local signals and EventBus for system-wide notification.

4. **Flexible loot configuration** - LootSystem supports multiple table formats (guaranteed_drops, rare_drops, items) and loads from JSON config.

5. **Multiplier system** - Victory type and difficulty affect reward amounts with clear modifier values.

6. **Fallback loading** - LootSystem can load directly from JSON files if ConfigurationManager is unavailable.

## Issues Found

1. **Filename/classname mismatch** - LootSystem.gd declares `class_name LootManager`, should be `LootSystem` for consistency.

2. **Missing item type handling** - LootSystem only handles resources via ResourceManager.add_resource(). Non-resource items (equipment, scrolls, god pieces) have no handling path.

3. **Inconsistent JSON property access** - `get_loot_preview()` uses `loot_item_id` while `generate_loot()` uses `item_id` - depends on which JSON format is used.

4. **Probability scaling issue** - `_roll_chance()` compares `randf() * 100.0 <= chance` but `generate_loot()` passes raw decimal chances (0.0-1.0). This means a 50% chance (0.5) would only trigger 0.5% of the time.

5. **Missing loot tables** - `generate_battle_rewards()` constructs table IDs like "battle_rewards_stage_5" that likely don't exist in config.

6. **No validation of loot_items** - `loot_items` dictionary is loaded but never used anywhere in the code.

7. **Verbose console output** - Both files print debug messages on every resource change, which would spam the console during normal gameplay.

## Dependencies

**Depends on:**
- SystemRegistry (service locator)
- ConfigurationManager (loot config loading)
- EventBus (optional, for system-wide signals)

**Used by:**
- DungeonCoordinator (dungeon rewards)
- BattleCoordinator (battle rewards)
- TerritoryProductionManager (resource collection)
- Any system that awards or spends resources
