# Dungeon System - Implementation Plan

## Analysis

### Current State

#### Data Layer - MOSTLY COMPLETE
- **`data/dungeons.json`** - Comprehensive dungeon definitions with:
  - 6 elemental sanctums (fire, water, earth, lightning, light, dark) with 4 difficulty tiers
  - 8 pantheon trials (Greek, Norse, Egyptian, Hindu, Japanese, Celtic, Aztec, Slavic)
  - 3 equipment dungeons (Titan's Forge, Valhalla Armory, Oracle Sanctum)
  - 1 special sanctum (Hall of Magic)
  - Daily rotation schedule
  - Unlock requirements by category

- **`data/dungeon_waves.json`** - Multi-wave enemy configurations with:
  - 3 waves per dungeon (beginner-advanced), 4 waves for legendary
  - Enemy tiers: basic -> leader -> elite -> boss
  - Level scaling across difficulties
  - Element-themed enemies per sanctum

- **`data/loot_tables.json`** - Reward templates defined:
  - `elemental_dungeon_beginner/intermediate/advanced/expert/master`
  - `pantheon_trial_heroic/legendary`
  - `equipment_dungeon_beginner/intermediate/advanced`
  - Guaranteed drops + rare drops with chances
  - Element-specific materials

- **`data/loot_items.json`** - Individual loot item definitions with amounts

#### System Layer - PARTIALLY COMPLETE
- **`DungeonManager.gd`** - Core dungeon data manager
  - Loads and parses dungeon data
  - Category filtering, schedule info
  - Difficulty validation
  - MISSING: `get_battle_configuration()` doesn't load waves from `dungeon_waves.json`
  - MISSING: `get_completion_rewards()` returns empty dict (no loot table integration)

- **`DungeonCoordinator.gd`** - Battle coordination
  - Energy validation and spending
  - Team validation
  - Victory/defeat handling structure
  - MISSING: Wave data not passed to BattleCoordinator
  - MISSING: Loot generation not triggered on victory

- **`WaveManager.gd`** - Wave battle progression
  - Wave setup and tracking
  - Wave completion detection
  - Signals for wave events
  - MISSING: Not being used - BattleCoordinator doesn't call wave advancement

- **`BattleCoordinator.gd`** - Main battle orchestration
  - Battle flow, turn management
  - Wave manager exists but underutilized
  - MISSING: Wave advancement on enemy defeat
  - MISSING: Wave transition handling between waves

- **`LootSystem.gd`** - Loot generation
  - Loads loot tables and items
  - Generate loot from templates
  - Award loot to ResourceManager
  - MISSING: Not integrated into dungeon victory flow
  - MISSING: Element-specific material generation

- **`CollectionManager.gd`** - God collection
  - Debug logging for remove_god()
  - No code removes gods on battle defeat (BUG VERIFIED NOT PRESENT IN CODE)

#### UI Layer - PARTIALLY COMPLETE
- **`DungeonScreen.gd`** - Dungeon selection
  - Category tabs, dungeon list
  - Difficulty selection
  - Reward preview framework
  - MISSING: Wave count display
  - MISSING: First-clear bonus indicator

- **`BattleResultOverlay.gd`** - Victory/defeat display
  - Result display with rating
  - Rewards display
  - Loot display
  - MISSING: Animated loot reveal
  - MISSING: First-clear celebration

- **`BattleScreen.gd`** - Battle UI
  - MISSING: Wave indicator (Wave 1/3)
  - MISSING: Wave transition animation

### Gaps

1. **Data Connection Gap**: `dungeon_waves.json` exists but isn't loaded by `DungeonManager.get_battle_configuration()`
2. **Loot Integration Gap**: `LootSystem` exists but isn't called from `DungeonCoordinator._handle_dungeon_victory()`
3. **Wave Execution Gap**: `WaveManager` exists but `BattleCoordinator` doesn't advance waves properly
4. **Daily Reset Gap**: No system tracks daily completions or resets
5. **First-Clear Gap**: No tracking for first-time completion bonuses
6. **Polish Gap**: No wave transition animations or loot reveal effects

### Integration Points

1. **Dungeon -> Crafting**: Materials from dungeons enable crafting recipes
   - `crafting_recipes.json` requires materials like `forging_flame`, `steel_ingots`, `mythril_ore`
   - Loot tables already define these as drops

2. **Dungeon -> Equipment**: Equipment dungeons drop gear directly
   - `equipment_drop` loot item with rarity weights
   - Links to `EquipmentFactory` for generation

3. **Dungeon -> Progression**: Dungeon clears can unlock content
   - `unlock_requirements` in dungeons.json specifies `territories_completed`
   - Could unlock hex territory nodes

4. **Dungeon -> Resources**: All rewards flow through `ResourceManager`
   - Mana, crystals, powders, souls, etc.

---

## Task List

```json
[
  {
    "id": "DATA-001",
    "category": "data",
    "priority": "critical",
    "description": "Connect dungeon_waves.json to DungeonManager",
    "steps": [
      "Load dungeon_waves.json in DungeonManager._ready()",
      "Store wave data in dungeon_waves Dictionary",
      "Update get_battle_configuration() to lookup waves by dungeon_id + difficulty",
      "Convert wave enemy format to BattleConfig.enemy_waves format",
      "Add fallback for dungeons without wave data"
    ],
    "acceptance_criteria": [
      "DungeonManager.get_battle_configuration() returns populated enemy_waves array",
      "Wave enemies have correct stats (level, hp, attack, defense, speed)",
      "All 6 elemental sanctums return 3-wave configurations"
    ],
    "files_to_modify": [
      "scripts/systems/dungeon/DungeonManager.gd"
    ],
    "passes": true
  },
  {
    "id": "DATA-002",
    "category": "data",
    "priority": "critical",
    "description": "Wire loot tables to dungeon rewards",
    "steps": [
      "Update DungeonManager.get_completion_rewards() to use loot_table_name",
      "Call LootSystem.generate_loot() with correct table ID",
      "Handle element-specific material substitution",
      "Return rewards Dictionary with resource_id -> amount mapping"
    ],
    "acceptance_criteria": [
      "get_completion_rewards() returns non-empty rewards dict",
      "Fire Sanctum drops fire_powder_low, not generic powder",
      "Difficulty affects reward quantities (expert > beginner)"
    ],
    "files_to_modify": [
      "scripts/systems/dungeon/DungeonManager.gd"
    ],
    "passes": true
  },
  {
    "id": "DATA-003",
    "category": "data",
    "priority": "medium",
    "description": "Add first-clear bonus definitions to dungeons",
    "steps": [
      "Add first_clear_rewards field to dungeon difficulty_levels in JSON",
      "Define bonus crystals/mana for first clears",
      "Add is_first_clear flag to completion tracking"
    ],
    "acceptance_criteria": [
      "First clear of fire_sanctum beginner grants bonus 50 crystals",
      "Subsequent clears don't grant first-clear bonus",
      "First-clear tracked per difficulty level"
    ],
    "files_to_modify": [
      "data/dungeons.json",
      "scripts/systems/dungeon/DungeonManager.gd"
    ],
    "passes": true
  },
  {
    "id": "SYS-001",
    "category": "systems",
    "priority": "critical",
    "description": "Implement wave progression in BattleCoordinator",
    "steps": [
      "Detect when all enemies in current wave are defeated",
      "Call WaveManager.complete_current_wave() to advance",
      "Spawn next wave enemies from battle_state",
      "Update turn order to include new enemies",
      "Emit wave_completed signal for UI"
    ],
    "acceptance_criteria": [
      "Defeating all wave 1 enemies spawns wave 2 enemies",
      "Wave 2 enemies appear in turn order",
      "Final wave defeat triggers battle victory",
      "Wave counter increments correctly (1/3 -> 2/3 -> 3/3)"
    ],
    "files_to_modify": [
      "scripts/systems/battle/BattleCoordinator.gd",
      "scripts/data/BattleState.gd"
    ],
    "passes": true
  },
  {
    "id": "SYS-002",
    "category": "systems",
    "priority": "critical",
    "description": "Integrate LootSystem into dungeon victory flow",
    "steps": [
      "Get loot_table_id from DungeonManager in _handle_dungeon_victory()",
      "Call LootSystem.generate_loot() with table ID",
      "Merge generated loot with base rewards",
      "Add loot to BattleResult.rewards and BattleResult.loot_obtained",
      "Call LootSystem.award_loot() to give resources to player"
    ],
    "acceptance_criteria": [
      "Dungeon victory generates loot from correct table",
      "LootSystem.loot_awarded signal emitted",
      "ResourceManager resources increase after victory",
      "BattleResult contains generated loot for UI display"
    ],
    "files_to_modify": [
      "scripts/systems/dungeon/DungeonCoordinator.gd"
    ],
    "passes": true
  },
  {
    "id": "SYS-003",
    "category": "systems",
    "priority": "high",
    "description": "Implement daily dungeon reset mechanic",
    "steps": [
      "Add daily_completions tracking to DungeonManager.player_progress",
      "Track completion count per dungeon per day",
      "Add daily_limit field to dungeon definitions (default: 10)",
      "Check daily limit in validate_dungeon_entry()",
      "Reset daily_completions on date change"
    ],
    "acceptance_criteria": [
      "Each dungeon can be completed 10 times per day",
      "11th attempt shows 'Daily limit reached' error",
      "At midnight (local), daily count resets to 0",
      "Progress persists through save/load"
    ],
    "files_to_modify": [
      "scripts/systems/dungeon/DungeonManager.gd"
    ],
    "passes": true
  },
  {
    "id": "SYS-004",
    "category": "systems",
    "priority": "high",
    "description": "Add dungeon completion tracking for first-clear bonuses",
    "steps": [
      "Add completed_dungeons Dictionary to player_progress",
      "Key format: dungeon_id + '_' + difficulty",
      "Update record_completion() to track first clears",
      "Check completion status in get_completion_rewards()",
      "Include first_clear_rewards only on first completion"
    ],
    "acceptance_criteria": [
      "First clear triggers first_clear_rewards addition",
      "Second clear of same difficulty doesn't grant bonus",
      "Different difficulties tracked separately",
      "Completion status persists through save/load"
    ],
    "files_to_modify": [
      "scripts/systems/dungeon/DungeonManager.gd"
    ],
    "passes": false
  },
  {
    "id": "SYS-005",
    "category": "systems",
    "priority": "medium",
    "description": "Connect dungeon completion to hex territory progression",
    "steps": [
      "Emit dungeon_completed signal with dungeon_id after victory",
      "TerritoryManager listens for dungeon completions",
      "Check if completion unlocks any territory nodes",
      "Mark nodes as unlocked based on dungeon clear requirements"
    ],
    "acceptance_criteria": [
      "Completing 'greek_trials' could unlock specific hex node",
      "TerritoryManager.is_node_unlocked() reflects dungeon progress",
      "Unlock requirements defined in hex_nodes.json"
    ],
    "files_to_modify": [
      "scripts/systems/dungeon/DungeonCoordinator.gd",
      "scripts/systems/territory/TerritoryManager.gd"
    ],
    "passes": false
  },
  {
    "id": "UI-001",
    "category": "polish",
    "priority": "high",
    "description": "Add wave indicator to BattleScreen",
    "steps": [
      "Create WaveIndicator node in BattleScreen scene",
      "Display 'Wave X/Y' during dungeon battles",
      "Connect to BattleCoordinator.wave_started signal",
      "Update display when wave changes",
      "Hide for non-wave battles (arena)"
    ],
    "acceptance_criteria": [
      "Wave indicator shows 'Wave 1/3' at battle start",
      "Indicator updates to 'Wave 2/3' after wave 1 cleared",
      "Indicator not visible in arena battles"
    ],
    "files_to_modify": [
      "scripts/ui/screens/BattleScreen.gd",
      "scenes/ui/screens/BattleScreen.tscn"
    ],
    "passes": false
  },
  {
    "id": "UI-002",
    "category": "polish",
    "priority": "high",
    "description": "Implement wave transition animation",
    "steps": [
      "Create wave transition overlay effect",
      "Show 'Wave X Complete!' text with fade",
      "Brief pause (0.5-1s) between waves",
      "Animate new enemies spawning in",
      "Play sound effect for wave clear"
    ],
    "acceptance_criteria": [
      "Wave completion shows celebratory text",
      "New wave enemies slide/fade in",
      "Transition duration feels satisfying (~1.5s total)",
      "Player units remain visible throughout"
    ],
    "files_to_modify": [
      "scripts/ui/screens/BattleScreen.gd",
      "scripts/systems/battle/BattleCoordinator.gd"
    ],
    "passes": false
  },
  {
    "id": "UI-003",
    "category": "polish",
    "priority": "medium",
    "description": "Enhance loot reveal animation on victory",
    "steps": [
      "Animate reward items appearing one by one",
      "Add glow effect for rare/epic drops",
      "Show resource icons next to amounts",
      "Play sound effects for loot reveal",
      "Special animation for first-clear bonus"
    ],
    "acceptance_criteria": [
      "Rewards appear sequentially (100ms delay each)",
      "Rare drops have distinct visual treatment",
      "First-clear bonus shows as 'FIRST CLEAR BONUS!' header"
    ],
    "files_to_modify": [
      "scripts/ui/battle/BattleResultOverlay.gd"
    ],
    "passes": false
  },
  {
    "id": "UI-004",
    "category": "polish",
    "priority": "medium",
    "description": "Add wave count and first-clear indicator to DungeonScreen",
    "steps": [
      "Show 'Waves: 3' in dungeon info panel",
      "Add 'First Clear Bonus!' badge for uncleared difficulties",
      "Gray out/checkmark completed difficulties",
      "Show daily completion count (3/10 today)"
    ],
    "acceptance_criteria": [
      "Player can see wave count before entering dungeon",
      "Uncleared dungeons show first-clear indicator",
      "Daily progress visible (7/10 remaining)"
    ],
    "files_to_modify": [
      "scripts/ui/screens/DungeonScreen.gd",
      "scripts/ui/dungeon/DungeonInfoDisplay.gd"
    ],
    "passes": false
  },
  {
    "id": "UI-005",
    "category": "polish",
    "priority": "low",
    "description": "Add particle effects for wave clear rewards",
    "steps": [
      "Create mana orb particle effect",
      "Create crystal sparkle effect",
      "Particles fly toward resource counter",
      "Trigger on wave completion (mid-battle rewards)"
    ],
    "acceptance_criteria": [
      "Defeating a wave shows resource particles",
      "Particles animate toward UI resource display",
      "Effect is subtle, doesn't obscure gameplay"
    ],
    "files_to_modify": [
      "scripts/ui/screens/BattleScreen.gd",
      "scenes/ui/battle/WaveRewardEffect.tscn (new)"
    ],
    "passes": false
  },
  {
    "id": "TEST-001",
    "category": "testing",
    "priority": "critical",
    "description": "Verify multi-wave progression works correctly",
    "steps": [
      "Start fire_sanctum beginner dungeon",
      "Defeat all wave 1 enemies",
      "Verify wave 2 enemies spawn",
      "Defeat all wave 2 enemies",
      "Verify wave 3 enemies spawn",
      "Defeat wave 3, verify victory"
    ],
    "acceptance_criteria": [
      "3 distinct waves spawn sequentially",
      "Wave indicator updates correctly",
      "Final wave defeat triggers victory screen",
      "No crash or stuck state during transitions"
    ],
    "files_to_modify": [],
    "passes": false
  },
  {
    "id": "TEST-002",
    "category": "testing",
    "priority": "critical",
    "description": "Verify rewards granted properly on victory",
    "steps": [
      "Note player resources before dungeon",
      "Complete dungeon successfully",
      "Check BattleResult.rewards is populated",
      "Verify resources increased by reward amounts",
      "Verify loot table used matches dungeon difficulty"
    ],
    "acceptance_criteria": [
      "Mana increased by 500+ after beginner dungeon",
      "Element-specific powders dropped from correct sanctum",
      "Rare drops appear at configured chance rates"
    ],
    "files_to_modify": [],
    "passes": false
  },
  {
    "id": "TEST-003",
    "category": "testing",
    "priority": "critical",
    "description": "Verify gods NOT deleted on defeat (bug verification)",
    "steps": [
      "Note gods in collection before battle",
      "Start dungeon with full team",
      "Deliberately lose the battle (let all gods die)",
      "Return to collection screen",
      "Verify all gods still present"
    ],
    "acceptance_criteria": [
      "All gods remain in collection after defeat",
      "No remove_god() calls logged in console",
      "Gods have full HP after battle ends (reset)",
      "Gods can be used in next battle immediately"
    ],
    "files_to_modify": [],
    "passes": false
  },
  {
    "id": "TEST-004",
    "category": "testing",
    "priority": "high",
    "description": "Test save/load persistence of dungeon progress",
    "steps": [
      "Complete fire_sanctum beginner (first clear)",
      "Save game",
      "Close and reopen game",
      "Load save",
      "Verify fire_sanctum beginner shows as completed",
      "Verify no first-clear bonus on re-run"
    ],
    "acceptance_criteria": [
      "Completion status persists through save/load",
      "Clear counts persist",
      "Best times persist",
      "First-clear tracking persists"
    ],
    "files_to_modify": [],
    "passes": false
  },
  {
    "id": "TEST-005",
    "category": "testing",
    "priority": "high",
    "description": "Test daily reset functionality",
    "steps": [
      "Complete dungeon 10 times in one day",
      "Verify 11th attempt blocked",
      "Change system date to next day",
      "Verify dungeon completable again",
      "Verify count reset to 0/10"
    ],
    "acceptance_criteria": [
      "Daily limit enforced correctly",
      "Error message shown when limit reached",
      "Reset occurs on date change",
      "Energy not consumed if limit reached"
    ],
    "files_to_modify": [],
    "passes": false
  },
  {
    "id": "INTEGRATE-001",
    "category": "integration",
    "priority": "medium",
    "description": "Verify material drops enable crafting recipes",
    "steps": [
      "Farm fire_sanctum for forging_flame drops",
      "Check CraftingScreen shows recipe as craftable",
      "Craft steel_greatsword using dropped materials",
      "Verify equipment added to inventory"
    ],
    "acceptance_criteria": [
      "Dungeon materials count toward crafting requirements",
      "Craft button enabled when materials sufficient",
      "Crafted equipment functional in battle"
    ],
    "files_to_modify": [],
    "passes": false
  },
  {
    "id": "INTEGRATE-002",
    "category": "integration",
    "priority": "medium",
    "description": "Verify equipment drops from equipment dungeons",
    "steps": [
      "Run titans_forge dungeon multiple times",
      "Check for equipment_drop loot",
      "Verify equipment generated with correct rarity weights",
      "Equip dropped equipment on a god"
    ],
    "acceptance_criteria": [
      "Equipment dungeons drop equipment items",
      "Rarity distribution matches loot table weights",
      "Dropped equipment fully functional"
    ],
    "files_to_modify": [],
    "passes": false
  }
]
```

---

## Implementation Priority Order

### Phase 1: Core Functionality (Critical)
1. **DATA-001** - Connect wave data
2. **DATA-002** - Wire loot tables
3. **SYS-001** - Wave progression
4. **SYS-002** - Loot integration
5. **TEST-001** - Verify waves
6. **TEST-002** - Verify rewards
7. **TEST-003** - Verify no god deletion

### Phase 2: Daily Loop (High)
1. **SYS-003** - Daily reset
2. **SYS-004** - First-clear tracking
3. **DATA-003** - First-clear bonuses
4. **UI-001** - Wave indicator
5. **UI-002** - Wave transition
6. **TEST-004** - Save/load
7. **TEST-005** - Daily reset

### Phase 3: Polish & Integration (Medium)
1. **UI-003** - Loot reveal animation
2. **UI-004** - Dungeon screen indicators
3. **SYS-005** - Territory integration
4. **INTEGRATE-001** - Crafting
5. **INTEGRATE-002** - Equipment

### Phase 4: Visual Polish (Low)
1. **UI-005** - Particle effects

---

## Critical Notes

### Bug Verification: Gods NOT Deleted on Defeat
Code review of `CollectionManager.remove_god()` confirms:
- Debug logging added (lines 55-57)
- Only called explicitly, no battle system references
- `BattleCoordinator._handle_battle_defeat()` does NOT touch CollectionManager
- Likely user perception issue or UI filter hiding gods

**Recommendation**: Add debug console output during battle defeat to prove gods remain.

### Wave Data Format Conversion
`dungeon_waves.json` format:
```json
{"type": "fire", "tier": "basic", "name": "Ember Spirit", "level": 10, "count": 2}
```

Must convert to `BattleConfig.enemy_waves` format:
```gdscript
[{"name": "Ember Spirit", "level": 10, "hp": 800, "attack": 150, "defense": 80, "speed": 90}]
```

**Recommendation**: Create `_convert_wave_enemies()` helper in DungeonManager that:
1. Expands `count` into multiple enemy entries
2. Calculates stats from tier/level using formula
3. Returns array compatible with BattleState

### Loot Table ID Resolution
Current `get_loot_table_name()` returns IDs like `elemental_dungeon_beginner`.
LootSystem expects these to exist in `loot_templates`.

**Verified**: Templates exist and match expected naming convention.

---

## Success Metrics

When complete:
- [ ] Fire Sanctum beginner runs 3 waves successfully
- [ ] Victory grants 500+ mana and fire-specific materials
- [ ] Losing a dungeon leaves all gods in collection
- [ ] First clear grants bonus crystals
- [ ] Daily limit prevents 11th run
- [ ] Save/load preserves all progress
- [ ] Wave indicator shows X/3 during battle
- [ ] Wave transitions animate smoothly
- [ ] Loot reveal shows items sequentially

---

<promise>COMPLETE</promise>
