# SacrificeSystem.gd Audit Report

## File Overview
- **File Path**: scripts/systems/SacrificeSystem.gd
- **Line Count**: 300 lines
- **Primary Purpose**: God sacrifice system with Summoners War-style XP calculations and level bonuses
- **Architecture Type**: Well-focused utility class with clear single responsibility

## Signal Interface (2 signals)
### Outgoing Signals
1. `sacrifice_completed(target_god, material_gods, xp_gained)` - When sacrifice succeeds
2. `sacrifice_failed(reason)` - When sacrifice fails with error

## Method Inventory (8 methods)
### Core Sacrifice System
- `calculate_sacrifice_experience(material_gods: Array[God], target_god: God)` - Calculate XP from sacrifice
- `perform_sacrifice(target_god: God, material_gods: Array[God], player_data)` - Execute sacrifice
- `validate_sacrifice(target_god: God, material_gods: Array[God])` - Validate sacrifice parameters

### XP Calculation System
- `get_god_base_sacrifice_value(god: God)` - Get base sacrifice value for god
- `get_tier_base_value(tier: God.TierType)` - Get tier-based XP value
- `calculate_levels_gained(target_god: God, xp_gain: int)` - Calculate level ups from XP
- `get_sw_style_xp_requirement(level: int)` - Get XP requirement for level (SW-style scaling)

### UI Support
- `get_sacrifice_preview_text(target_god: God, material_gods: Array[God])` - Generate preview text

## Key Dependencies
### External Dependencies
- **God.gd** - Heavy dependency for god data structure and XP system
- **PlayerData** - For god collection management (remove_god)

### Internal State
- No persistent state (pure utility class)

## Duplicate Code Patterns Identified
### MAJOR OVERLAPS (HIGH PRIORITY):
1. **XP Calculation Overlap with God.gd**:
   - `get_sw_style_xp_requirement()` XP level requirement calculations
   - **Similar XP scaling patterns** in God.gd experience system
   - Level-based progression calculations
   - RECOMMENDATION: Create shared ExperienceCalculator utility

2. **Level Progression Overlap with ProgressionManager.gd**:
   - `calculate_levels_gained()` level calculation logic
   - **Similar level progression patterns** in ProgressionManager
   - RECOMMENDATION: Share level calculation utilities

### MEDIUM OVERLAPS:
3. **Tier-based Value Calculation**:
   - `get_tier_base_value()` tier-to-value mapping
   - **Similar tier value patterns** likely in other systems (summoning costs, etc.)
   - RECOMMENDATION: Create shared TierUtility

4. **God Collection Management**:
   - Direct PlayerData god removal in `perform_sacrifice()`
   - **Similar god management patterns** across managers
   - RECOMMENDATION: Centralize through PlayerData methods

## Architectural Assessment
### POSITIVE ASPECTS:
- **Excellent single responsibility**: Only handles sacrifice logic
- **Clean XP calculation**: Well-structured Summoners War-style scaling
- **Good validation**: Proper error checking and validation
- **UI support**: Preview text generation for user interface
- **Bonus system**: Element and same-god bonuses implemented
- **Pure utility design**: No persistent state, just calculations

### MINOR ISSUES:
- **XP calculation duplication**: Overlaps with God.gd XP system
- **Direct PlayerData manipulation**: Should use PlayerData methods

## Refactoring Recommendations
### IMMEDIATE (High Impact):
1. **Extract shared XP utilities**:
   - Create `ExperienceCalculator` utility for shared XP logic
   - Share `get_sw_style_xp_requirement()` with God.gd
   - **Eliminate duplicate XP calculation patterns**

2. **Extract level progression utilities**:
   - Share level calculation logic with ProgressionManager
   - Create shared `LevelCalculator` utility

### MEDIUM (Maintenance):
3. **Centralize god collection operations**:
   - Use PlayerData methods instead of direct manipulation
   - Consistent god management patterns

4. **Extract tier utilities**:
   - Create shared `TierUtility` for tier-based value calculations
   - Share with other systems that use tier values

## Connectivity Map
### Strongly Connected To:
- **God.gd**: Heavy dependency for XP system and god data
- **PlayerData**: God collection management
- **UI Screens**: SacrificeScreen and SacrificeSelectionScreen

### Moderately Connected To:
- **ProgressionManager**: Level calculation pattern overlap
- **SummonSystem**: Tier value pattern overlap

### Weakly Connected To:
- **GameManager**: Indirect access through PlayerData

### Signal Consumers (Likely):
- **SacrificeScreen**: Sacrifice completion and failure handling
- **NotificationManager**: Sacrifice completion notifications
- **UI components**: Preview display, sacrifice confirmation

## Notes for Cross-Reference
- **XP calculation patterns**: Compare with God.gd for shared XP utilities
- **Level progression patterns**: Compare with ProgressionManager.gd for shared utilities
- **Tier value patterns**: Look for similar tier-based calculations in other systems
- **God management patterns**: Check PlayerData.gd for centralized god operations
- **This is a well-designed class with minimal architectural issues**
