# JSON Data Files Analysis

## Files Analyzed
- abilities.json - God abilities and skill definitions (~106KB, 100+ abilities)
- arena_config.json - PvP arena seasons, matchmaking, rewards
- banners.json - Summon banner configurations and events
- battle_config.json - Combat mechanics, damage formulas, AI settings
- dungeons.json - Dungeon definitions with schedule and difficulty
- enemies.json - Enemy types, abilities, roles, AI behaviors
- equipment.json - Sample equipment items
- equipment_config.json - Equipment types, rarities, sets, enhancement
- gods.json - God definitions with stats, abilities, tiers (~59KB)
- loot_items.json - Loot item definitions with amounts/scaling
- loot_tables.json - Loot drop tables for various content
- quests.json - Daily/weekly quest definitions
- resource_config.json - Resource mappings, conversion rates
- resources.json - Full resource definitions (~17KB)
- shop_config.json - Shop items and special offers
- summon_config.json - Summoning costs, rates, pity system
- territories.json - Territory definitions with production
- territory_balance_config.json - Territory economy balancing
- territory_roles.json - God role definitions for territories

## What It Does
The data layer provides all static game configuration in JSON format. It covers:

**Game Entities:**
- 40+ gods across 8 pantheons (Greek, Norse, Egyptian, Hindu, Japanese, Celtic, Aztec, Slavic)
- 100+ unique abilities with detailed effect structures
- 6 elements (fire, water, earth, lightning, light, dark)
- 4 tiers (Common, Rare, Epic, Legendary)

**Combat System:**
- Summoners War-style damage calculation formulas
- Elemental advantage/disadvantage system (1.3x/0.7x)
- Turn bar speed system
- Status effects (stun, slow, heal_block, brand, etc.)
- Multi-hit abilities with per-hit effects

**Gacha/Summoning:**
- Pity system (soft pity at 35/75, hard pity at 50/100)
- Multiple summon types (soul-based, premium, element-focused)
- 10-pull guarantees
- Multiple banners with rate-ups

**Economy:**
- 3 currencies (mana, divine_crystals, energy)
- 50+ distinct resources (powders, souls, ores, gemstones)
- Resource conversion recipes
- Tiered material system (low/mid/high)

**Content:**
- 6 elemental sanctum dungeons (daily rotation)
- 8 pantheon trial dungeons (weekend)
- 3 equipment dungeons (always available)
- 6 territories with production systems
- Arena PvP with seasons

## Status: WORKING

The JSON data is well-structured and comprehensive. Most systems reference these files correctly.

## Code Quality
- [x] Clean architecture
- [x] Proper typing (consistent use of enums via integers)
- [x] Error handling (N/A - static data)
- [x] Comments/docs (metadata fields in some files)

## Key Findings

### Strengths
1. **Summoners War authenticity**: Mechanics closely mirror SW (turn bar, damage formula, pity system)
2. **Comprehensive coverage**: All game systems have data definitions
3. **Good structure**: Nested objects with clear hierarchies
4. **Element system**: 6-element cycle with clear relationships
5. **Resource economy**: Well-designed tiered materials
6. **Template system**: Loot tables use templates for reusability
7. **Metadata**: Some files include version and description metadata

### Notable Design Choices
- Gods use integer element IDs (0=fire, 1=water, 2=earth, 3=lightning, 4=light, 5=dark)
- Abilities have rich effect structures supporting complex mechanics
- Enemies have phase-based boss patterns
- Pity carries over between banners
- Territory production uses SW-style conservative balancing

## Issues Found

### Inconsistencies
1. **Element representation**: Gods use integers (0-5) while other files use strings ("fire", "water")
2. **Missing crystals_large**: Referenced in loot_tables.json but not defined in loot_items.json
3. **Missing divine_essence loot item**: Referenced in loot_tables.json but not defined in loot_items.json
4. **Missing legendary_soul loot item**: Referenced in loot_tables.json but not defined in loot_items.json
5. **Duplicate pity config**: Both banners.json and summon_config.json define pity_system

### Schema Inconsistencies
6. **Equipment type mismatch**: equipment.json uses `type: 0-5` integers while equipment_config.json uses `slot: 0-5`
7. **Production format mismatch**: territories.json uses `materials_per_day: {low: 10}` but resource system expects specific IDs
8. **Missing schedule handling**: dungeons.json `weekend_rotating` schedule has no clear rotation logic defined

### Missing Data
9. **Awakening requirements**: No config for god awakening material costs
10. **Level scaling formulas**: God stat growth per level not defined (hardcoded in GodCalculator)
11. **Sacrifice XP values**: Not defined in JSON (hardcoded in SacrificeSystem)
12. **Set bonus application**: equipment_config has sets but no clear activation logic data

### Stale/Unused
13. **old_jsons folder**: Contains outdated data files that may cause confusion
14. **quests.json**: Minimal (only 3 quests) - likely placeholder

## Dependencies
- **Depends on:** Nothing (static data)
- **Used by:** Nearly all systems
  - GodFactory.gd reads gods.json
  - BattleConfig.gd reads battle_config.json
  - DungeonManager.gd reads dungeons.json
  - EquipmentFactory.gd reads equipment.json / equipment_config.json
  - ResourceManager.gd reads resources.json
  - SummonManager.gd reads summon_config.json
  - TerritoryManager.gd reads territories.json
  - LootSystem.gd reads loot_tables.json

## Data Volume Summary
| File | Size | Entity Count |
|------|------|--------------|
| abilities.json | 106KB | ~100+ abilities |
| gods.json | 59KB | ~40+ gods |
| enemies.json | 17KB | 6 elements x 4 tiers |
| resources.json | 17KB | ~50+ resources |
| loot_tables.json | 16KB | ~20 templates |
| dungeons.json | 11KB | ~20 dungeons |
| equipment_config.json | 7KB | 6 types, 5 rarities |
| banners.json | 6KB | 5 banners |
| summon_config.json | 6KB | Full summon system |
| Others | <6KB each | Configuration |
