# Dungeon System - Economy Balance Analysis

## Overview
This document analyzes dungeon energy costs, enemy difficulty, and rewards to ensure proper balance with other game systems (summoning, awakening, crafting, hex territory).

---

## Current Energy System

### Energy Basics
- **Starting Energy**: 80
- **Energy Cap**: 100
- **Regeneration**: NONE (needs implementation)
- **Sources**: Initial grant only

### Energy Costs by Dungeon Type

| Dungeon Type | Beginner | Intermediate | Advanced | Expert | Heroic | Legendary |
|--------------|----------|--------------|----------|--------|--------|-----------|
| Elemental Sanctums | 8 | 10 | 12 | 15 | - | - |
| Special Sanctum (Magic) | 10 | 12 | 15 | 18 | - | - |
| Pantheon Trials | - | - | - | - | 15 | 20 |
| Equipment Dungeons | 8 | 10 | 12 | - | - | - |

**Analysis**: With 80 energy and no regeneration:
- Player can run 10x Beginner dungeons (80 energy)
- Player can run 8x Intermediate dungeons (80 energy)
- Player can run 6x Advanced dungeons (72 energy)
- Player can run 5x Expert dungeons (75 energy)
- Player can run 5x Heroic dungeons (75 energy)
- Player can run 4x Legendary dungeons (80 energy)

**PROBLEM**: No energy regeneration means player is stuck after initial energy is spent!

---

## Enemy Balance Analysis

### Wave Structure
- **Elemental Sanctums (Beginner)**: 3 waves
  - Wave 1: 2x Basic (level 10) + 1x Leader (level 15)
  - Wave 2: 2x Leader (level 15) + 1x Elite (level 20)
  - Wave 3: 1x Boss (level 25) + 2x Leader (level 15)

### Enemy Stats Formula
Based on `DungeonManager._calculate_enemy_stats()`:

```
Base HP = level * 190
Base Attack = level * 3.8
Base Defense = level * 1.9
Base Speed = 60

Tier Multipliers:
- basic: 1.0x
- leader: 1.5x
- elite: 2.5x
- boss: 4.0x
```

### Example: Fire Sanctum Beginner (8 energy)
**Wave 1:**
- 2x Ember Spirit (level 10, basic): HP=1900, ATK=38, DEF=19, SPD=70
- 1x Flame Warden (level 15, leader): HP=4275, ATK=85, DEF=42, SPD=75

**Wave 2:**
- 2x Fire Guardian (level 15, leader): HP=4275, ATK=85, DEF=42, SPD=75
- 1x Lava Golem (level 20, elite): HP=9500, ATK=190, DEF=95, SPD=80

**Wave 3:**
- 1x Inferno Commander (level 25, boss): HP=19000, ATK=380, DEF=190, SPD=85
- 2x Fire Guardian (level 15, leader): HP=4275, ATK=85, DEF=42, SPD=75

**Total Enemy HP**: 50,775
**Total Enemy ATK**: 1,276

### Player Team Comparison
Assuming 2 gods at level 10 (beginner):
- Common god: ~1200 HP, ~80 ATK, ~60 DEF
- Team HP: ~2400
- Team ATK: ~160

**Analysis**: Player team is severely outmatched!
- Enemy HP is 21x higher than player HP
- Enemy ATK is 8x higher than player ATK
- This requires heavy grinding or unbalanced combat mechanics

---

## Current Reward Analysis

### Mana Rewards (Primary Currency)

| Difficulty | Mana (First Clear Bonus) | Mana (Loot Generated) | Total Mana |
|------------|--------------------------|----------------------|------------|
| Beginner | 500 | ~700 | ~1,200 |
| Intermediate | 1,000 | ~1,400 | ~2,400 |
| Advanced | 2,000 | ~3,000 | ~5,000 |
| Expert | 5,000 | ~7,000 | ~12,000 |

### Crystal Rewards (Premium Currency)

| Difficulty | Crystals (First Clear) |
|------------|------------------------|
| Beginner | 50 |
| Intermediate | 75 |
| Advanced | 100 |
| Expert | 150 |

### Material Rewards
**Fire Sanctum Beginner** (example loot):
- fire_powder_low: 8-14
- fire_powder_mid: 3-8
- magic_powder_low: 9-17

---

## Economy Integration Analysis

### 1. Summoning System

**Summon Costs:**
- Common Soul Summon: 1 common_soul
- Mana Summon: 10,000 mana
- Divine Crystal Summon: 100 crystals

**Dungeon Contribution:**
- 1x Beginner dungeon = 1,200 mana (12% of 1 mana summon)
- 8x Beginner dungeons = 9,600 mana (96% of 1 mana summon)
- 1x Expert dungeon (first clear) = 150 crystals (1.5 crystal summons)

**BALANCE ISSUE**: Dungeons don't drop souls directly. Players need 8+ dungeon runs to afford 1 mana summon.

---

### 2. Awakening System

**Awakening Material Requirements** (Athena example):
- light_powder_high: 15
- magic_powder_high: 8
- light_powder_mid: 30
- magic_powder_mid: 15
- light_powder_low: 20
- magic_powder_low: 10

**Dungeon Contribution:**
- Light Sanctum Beginner: ~8-14 light_powder_low per run
- Need 2-3 runs for low tier
- Need 20+ runs for high tier materials (only drop from Expert+)

**BALANCE ISSUE**: High-tier powders only drop from Expert dungeons (15 energy). With 80 energy cap and no regen, player can only run 5 Expert dungeons total.

---

### 3. Crafting System

**Recipe Requirements** (examples):
- Basic Iron Sword: 20 iron_ore, 10 wood, 500 mana
- Steel Greatsword: 15 steel_ingots, 5 rare_herbs, 1 forging_flame, 5,000 mana

**Dungeon Contribution:**
- Equipment dungeons drop: common_ore (iron_ore), rare_ore (mythril_ore), forging_flame
- Titan's Forge Beginner: 5-15 iron_ore per run
- Need 2-3 runs for basic sword materials

**GOOD BALANCE**: Dungeons are primary source of crafting materials. Equipment dungeons align well with crafting needs.

---

### 4. Hex Territory System

**Territory Node Capture Power Required:**
- Tier 1 nodes: 3,000-3,500 capture power
- Tier 2 nodes: Higher (not shown in sample)

**Territory Production** (Copper Vein example):
- 50 copper_ore/day
- 30 stone/day
- 10 iron_ore/day

**Dungeon vs Territory:**
- Territory provides passive resource generation
- Dungeons provide burst resources + combat-exclusive materials (powders, souls)

**GOOD BALANCE**: Dungeons and territories serve different roles. Dungeons are active content for combat materials.

---

## Critical Balance Problems

### Problem 1: NO ENERGY REGENERATION
**Impact**: Game-breaking. Player spends 80 energy and is stuck forever.

**Solutions**:
1. **Energy Regeneration**: 1 energy per 6 minutes (240/day passive)
2. **Daily Reset**: Full energy restore at midnight
3. **Energy Refills**: Allow mana/crystal purchase of energy

**Recommendation**: Implement passive regen (1 per 6 min) + daily reset + refills

---

### Problem 2: Enemy Stats Too High for Beginner Content
**Impact**: New players cannot complete dungeons without heavy grinding.

**Solutions**:
1. **Reduce enemy HP by 50%** for Beginner/Intermediate
2. **Lower tier multipliers**: basic=1.0x, leader=1.3x, elite=2.0x, boss=3.0x
3. **Increase starting god stats**

**Recommendation**: Reduce Beginner enemy HP by 50%, reduce tier multipliers

---

### Problem 3: Insufficient Reward per Energy Spent
**Impact**: 8 energy for 1,200 mana feels expensive when mana summons cost 10,000.

**Solutions**:
1. **Increase mana rewards by 2x-3x**
2. **Add soul drops** to dungeons (common souls from clears)
3. **Reduce summon costs**

**Recommendation**: Increase mana rewards by 2.5x, add soul drops (1-2 common souls per clear)

---

### Problem 4: High-Tier Materials Locked Behind Expert Dungeons
**Impact**: With 80 energy cap and 15 energy cost, players can only run 5 Expert dungeons EVER (until energy regen added).

**Solutions**:
1. **Add high-tier material drops to Advanced dungeons** (lower rates)
2. **Reduce Expert energy cost** to 12 (allows 6 runs)
3. **Implement energy regeneration** (solves long-term)

**Recommendation**: All three solutions combined

---

## Proposed Rebalance

### Energy System Changes
```json
{
  "starting_energy": 80,
  "energy_cap": 100,
  "energy_regen_rate": "1 per 6 minutes",
  "daily_regen_total": 240,
  "refill_costs": {
    "mana_refill_50": 5000,
    "crystal_refill_50": 25,
    "full_refill_100": 50
  }
}
```

### Energy Cost Adjustments
| Dungeon Type | OLD Beginner | NEW Beginner | OLD Expert | NEW Expert |
|--------------|--------------|--------------|------------|------------|
| Elemental | 8 | **6** | 15 | **12** |
| Special | 10 | **8** | 18 | **15** |
| Equipment | 8 | **6** | - | - |
| Pantheon Heroic | 15 | **12** | - | - |
| Pantheon Legendary | 20 | **18** | - | - |

**Rationale**:
- Lower costs allow more runs per day
- With 240 daily regen + 100 cap = 340 energy/day
- Beginner (6 energy): 56 runs/day
- Expert (12 energy): 28 runs/day

### Enemy Stats Rebalance
```gdscript
# NEW formula in DungeonManager._calculate_enemy_stats()
var base_hp = level * 95  # Reduced from 190 (50% reduction)
var base_attack = level * 3.8  # Keep same
var base_defense = level * 1.9  # Keep same
var base_speed = 60

# NEW tier multipliers
var tier_multipliers = {
    "basic": 1.0,
    "leader": 1.3,  # Reduced from 1.5
    "elite": 2.0,   # Reduced from 2.5
    "boss": 3.0     # Reduced from 4.0
}
```

**New Fire Sanctum Beginner Totals**:
- Total HP: ~25,000 (down from 50,775)
- Total ATK: ~640 (down from 1,276)

**Player vs Enemy**: Still challenging but achievable with 2-3 leveled gods

### Reward Increases

**Mana Rewards** (2.5x multiplier):
| Difficulty | OLD Total | NEW Total |
|------------|-----------|-----------|
| Beginner | 1,200 | **3,000** |
| Intermediate | 2,400 | **6,000** |
| Advanced | 5,000 | **12,500** |
| Expert | 12,000 | **30,000** |

**New Drops: Common Souls**:
| Difficulty | Souls Dropped |
|------------|---------------|
| Beginner | 1-2 |
| Intermediate | 2-3 |
| Advanced | 3-5 |
| Expert | 5-8 |
| Heroic | 8-12 |
| Legendary | 12-20 |

**Material Quantity Increases** (+50%):
- fire_powder_low: 12-21 (up from 8-14)
- fire_powder_mid: 5-12 (up from 3-8)
- magic_powder_low: 14-26 (up from 9-17)

### New Reward Value per Energy

**Beginner (6 energy)**:
- 3,000 mana = 500 mana/energy
- 1-2 souls = 0.25 souls/energy
- Materials for awakening

**Expert (12 energy)**:
- 30,000 mana = 2,500 mana/energy
- 5-8 souls = 0.6 souls/energy
- High-tier materials
- First clear: 150 crystals

**Economic Impact**:
- 4x Beginner runs = 12,000 mana (1.2 mana summons)
- 1x Expert run = 30,000 mana (3 mana summons)
- Daily energy (340) allows ~28 Expert runs = 840,000 mana + 168-224 souls

**BALANCE CHECK**: This might be TOO generous. Adjust to 1.5x-2x instead of 2.5x.

---

## Final Recommended Balance

### Energy
- **Starting**: 80
- **Cap**: 100
- **Regen**: 1 per 6 minutes (240/day)
- **Daily Reset**: Yes (full energy at midnight)
- **Refills**: 50 energy for 5,000 mana OR 25 crystals

### Energy Costs (REDUCED)
- Elemental Beginner: 8 → **6**
- Elemental Expert: 15 → **12**
- Pantheon Legendary: 20 → **18**

### Enemy Stats (50% HP REDUCTION)
- Base HP: 190 → **95** per level
- Tier multipliers: Reduce boss from 4.0x to **3.0x**

### Mana Rewards (2X MULTIPLIER, not 2.5x)
- Beginner: 1,200 → **2,400**
- Expert: 12,000 → **24,000**

### Soul Drops (NEW)
- Beginner: 1-2 common souls
- Expert: 4-6 common souls
- Legendary: 10-15 common souls

### Material Quantities (+50%)
- All material drops increased by 50%

---

## Implementation Tasks

1. **ResourceManager**: Add energy regeneration system
2. **DungeonManager**: Update energy costs in dungeons.json
3. **DungeonManager**: Update enemy stat calculation (reduce HP multiplier)
4. **LootSystem**: Add soul drops to loot tables
5. **LootSystem**: Increase material quantities in loot_items.json
6. **DungeonManager**: Increase mana rewards by 2x

---

## Testing Checklist

- [ ] Energy regenerates at 1 per 6 minutes
- [ ] Daily reset restores full energy at midnight
- [ ] Beginner dungeons cost 6 energy
- [ ] Expert dungeons cost 12 energy
- [ ] Fire Sanctum Beginner total enemy HP ~25,000
- [ ] Beginner dungeon rewards ~2,400 mana
- [ ] Expert dungeon rewards ~24,000 mana
- [ ] Beginner dungeons drop 1-2 common souls
- [ ] Material drop quantities increased by 50%
- [ ] Player can afford 1 mana summon after 4 Beginner dungeon runs
- [ ] Player can complete awakening after 15-20 dungeon runs (mixed difficulties)
