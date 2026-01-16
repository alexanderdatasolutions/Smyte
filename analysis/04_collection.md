# Collection System Analysis

## Files Analyzed
- CollectionManager.gd - Core god/equipment collection storage and CRUD operations
- GodCalculator.gd - Static stat calculation with equipment and role bonuses
- GodFactory.gd - God creation from JSON configuration data
- InventoryManager.gd - Consumables, materials, and quest items inventory
- SummonManager.gd - Gacha summoning system with pity mechanics

## What It Does
The collection system manages the player's owned gods (characters) and items. It consists of five components:

**CollectionManager** - Central storage for gods and equipment. Maintains array and dictionary lookup for fast access. Handles add/remove/update operations with EventBus notifications and auto-save on changes.

**GodCalculator** - Pure static utility for computing effective stats. Applies level scaling (10% HP/ATK/DEF per level, 5% speed), equipment bonuses (main stat + substats), territory role modifiers (defender/gatherer/crafter bonuses), and ascension bonuses (5% all stats per level).

**GodFactory** - Creates God instances from JSON configuration. Handles element/tier parsing from both numeric and string formats. Initializes 6 equipment slots per god.

**InventoryManager** - Manages non-equipment items in three categories (consumables, materials, quest items). Loads item definitions from `loot_items.json`. Supports consumable use with effects (heal, restore energy, add XP).

**SummonManager** - Full gacha implementation with multiple summon types (basic/mana, premium/crystals, free daily, soul-based). Implements pity system with soft pity (increased rates after 35/75 summons) and hard pity (guaranteed epic at 50, legendary at 100). Supports 10-pull with discount.

## Status: WORKING

## Code Quality
- [x] Clean architecture - Good separation into focused components
- [x] Proper typing - Uses type hints throughout
- [ ] Error handling - Has push_error calls but some silent failures
- [x] Comments/docs - Good rule compliance comments, docstrings present

## Key Findings
- Clean refactored architecture following stated rules (500 line limit, single responsibility)
- SystemRegistry pattern used consistently for cross-system communication
- Authentic Summoners War mechanics: pity system, multi-summon discounts, daily/weekly freebies
- GodCalculator properly separates data (God) from logic (calculations)
- Equipment stat aggregation includes main stat + all substats
- Save/load integration in all managers

## Issues Found
- **InventoryManager._apply_consumable_effect references undefined `GameManager`** (line 133-134) - Should use SystemRegistry pattern like other systems
- **GodCalculator preloads GodExperienceCalculator** (line 141) - Inconsistent with SystemRegistry pattern used elsewhere
- **CollectionManager.add_god auto-saves on every addition** (line 39-42) - Could cause performance issues with bulk operations
- **SummonManager multi_summon uses "premium_guaranteed" type** (line 326) but _get_summon_rates doesn't handle this type
- **InventoryManager loads JSON directly** (line 21-37) - Should use ConfigurationManager for consistency
- **God.tier_to_string called but method location unclear** (SummonManager line 87, 332) - May be calling wrong class method
- **weekly_premium_used tracked but never set to true** - Logic incomplete in can_use_weekly_premium_summon

## Dependencies
- **Depends on:** SystemRegistry, EventBus, SaveManager, ConfigurationManager, ResourceManager, God (data model), Equipment (data model), SaveLoadUtility
- **Used by:** Battle system (gods), Equipment system (god equipment slots), Progression system (experience), UI screens (collection display, summon screen)
