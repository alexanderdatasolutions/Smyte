# Smyte - Stat Balance & Progression Guide

**Version**: 1.0.0
**Last Updated**: 2026-01-16

---

## Table of Contents

1. [Base Stats Overview](#base-stats-overview)
2. [Level Scaling](#level-scaling)
3. [Equipment Contribution](#equipment-contribution)
4. [Final Stat Ranges](#final-stat-ranges)
5. [Damage Calculation](#damage-calculation)
6. [Speed & Turn Order](#speed--turn-order)
7. [Critical Hits & Glancing](#critical-hits--glancing)
8. [Balance Recommendations](#balance-recommendations)

---

## Base Stats Overview

### Core Stats (8 Total)
| Stat | Purpose | Base Range | Growth Priority |
|------|---------|------------|-----------------|
| **HP** | Survivability | 80-120 | HIGH (Tier scaling: +25 to +65/lvl) |
| **Attack** | Damage output | 48-64 | HIGH (Tier scaling: +10 to +25/lvl) |
| **Defense** | Damage mitigation | 68-85 | MEDIUM (Tier scaling: +8 to +18/lvl) |
| **Speed** | Turn frequency | 57-64 | MEDIUM (Tier scaling: +2 to +4/lvl) |
| **Crit Rate** | Critical chance | 15% | STATIC (no level growth) |
| **Crit Damage** | Critical multiplier | 50% | STATIC (equipment only) |
| **Resistance** | Debuff resistance | 15% | STATIC (equipment only) |
| **Accuracy** | Debuff success | 0% | STATIC (equipment only) |

### God Tier Stat Distribution

**Zeus (Tier 4 - Legendary):**
- HP: 120, ATK: 64, DEF: 75, SPD: 60
- Element: Lightning (3)
- Role: Fighter/Support

**Poseidon (Tier 3 - Epic):**
- HP: 108, ATK: 58, DEF: 79, SPD: 57
- Element: Water (1)
- Role: Fighter/Gatherer

**Athena (Tier 2 - Rare):**
- HP: 98, ATK: 48, DEF: 85, SPD: 61
- Element: Light (4)
- Role: Scholar/Fighter (Defensive)

**Ares (Tier 1 - Common):**
- HP: 85, ATK: 54, DEF: 68, SPD: 58
- Element: Fire (0)
- Role: Fighter

---

## Level Scaling

### Per-Level Growth (by Tier)

| Tier | HP/Level | ATK/Level | DEF/Level | SPD/Level | Max Level |
|------|----------|-----------|-----------|-----------|-----------|
| **Tier 1** (Common) | +25 | +10 | +8 | +2 | 40 (50 awakened) |
| **Tier 2** (Rare) | +30 | +12 | +10 | +2 | 40 (50 awakened) |
| **Tier 3** (Epic) | +40 | +15 | +12 | +3 | 40 (50 awakened) |
| **Tier 4** (Legendary) | +50 | +20 | +15 | +3 | 40 (50 awakened) |
| **Tier 5** (Mythic) | +65 | +25 | +18 | +4 | 40 (50 awakened) |

### Level 40 Projections

**Zeus (Tier 4, Legendary) at Level 40:**
```
HP:     120 + (39 * 50)  = 2,070
Attack:  64 + (39 * 20)  =   844
Defense: 75 + (39 * 15)  =   660
Speed:   60 + (39 * 3)   =   177
```

**Ares (Tier 1, Common) at Level 40:**
```
HP:     85 + (39 * 25)  = 1,060
Attack: 54 + (39 * 10)  =   444
Defense: 68 + (39 * 8)  =   380
Speed:  58 + (39 * 2)   =   136
```

**Difference:** Tier 4 god is ~2x stronger than Tier 1 god at same level.

### XP Requirements

Formula: `XP_required = 200 * (1.2^(level-2))`

| Level | XP Required | Cumulative XP |
|-------|-------------|---------------|
| 1→2 | 200 | 200 |
| 2→3 | 240 | 440 |
| 5→6 | 415 | 1,689 |
| 10→11 | 995 | 8,275 |
| 20→21 | 6,232 | 78,543 |
| 39→40 | 79,776 | 1,557,835 |

---

## Equipment Contribution

### Equipment System (6 Slots)
1. **Weapon** - High ATK, SPD substats
2. **Armor** - High DEF, HP substats
3. **Helmet** - Balanced DEF/HP
4. **Gloves** - ATK/Crit Rate
5. **Boots** - SPD primary, any substats
6. **Accessory** - HP/Accuracy/Resistance

### Main Stat Ranges (Level 0 Equipment)

| Slot | Main Stat Options | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|------|-------------------|--------|--------|--------|--------|--------|
| Weapon | ATK | 30 | 45 | 70 | 100 | 150 |
| Armor | DEF | 25 | 40 | 60 | 90 | 135 |
| Helmet | HP | 200 | 300 | 450 | 680 | 1020 |
| Gloves | ATK/Crit Rate | 20/8% | 30/10% | 50/12% | 75/15% | 110/18% |
| Boots | SPD | 15 | 20 | 30 | 45 | 65 |
| Accessory | HP/ACC/RES | varies | varies | varies | varies | varies |

### Enhancement (+0 to +15)

**Main Stat Growth:** +5% per level
- +0 Weapon (100 ATK) → +15 Weapon (175 ATK)
- +0 Armor (90 DEF) → +15 Armor (157.5 DEF)

**Enhancement Costs:**
- Level 1-5: 1,000-5,000 mana per attempt
- Level 6-10: 6,000-10,000 mana per attempt
- Level 11-15: 11,000-15,000 mana per attempt
- Total to +15: ~120,000 mana

**Success Rates:**
- Level 0-9: 100%
- Level 10: 50%
- Level 11: 45%
- Level 12: 40%
- Level 13: 35%
- Level 14: 30%
- Level 15: 25%

### Substats (Random Rolls)

Each equipment piece has 1-4 substats:
- **Common:** 1 substat
- **Rare:** 2 substats
- **Epic:** 3 substats
- **Legendary:** 4 substats
- **Mythic:** 4 substats (higher rolls)

**Substat Types:** ATK, DEF, HP, SPD, Crit Rate, Crit Damage, Accuracy, Resistance

**Substat Roll Ranges (per roll):**
- HP: 100-300
- ATK: 10-30
- DEF: 8-25
- SPD: 3-8
- Crit Rate: 3-8%
- Crit Damage: 4-10%
- Accuracy: 4-10%
- Resistance: 4-10%

### Full Equipment Projection (Level 40 God + Max Gear)

**Zeus at Level 40 with +15 Mythic Equipment:**
```
Base Stats (Level 40):
  HP: 2,070 | ATK: 844 | DEF: 660 | SPD: 177

Equipment Contribution (6 slots, +15, good substats):
  HP: +2,000  (Helmet, Armor, Accessory mains + subs)
  ATK: +500   (Weapon, Gloves + substats)
  DEF: +400   (Armor, Helmet + substats)
  SPD: +80    (Boots + substats)
  Crit Rate: +45% (Gloves main + substats)
  Crit Damage: +80% (Substats only)

Final Stats:
  HP: 4,070
  Attack: 1,344
  Defense: 1,060
  Speed: 257
  Crit Rate: 60%
  Crit Damage: 130%
```

---

## Damage Calculation

### Core Damage Formula (Summoners War-style)

```
raw_damage = attacker.attack * skill_multiplier * (1000 / (1140 + 3.5 * defender.defense))
```

### Defense Mitigation Curve

| Defender DEF | Damage Multiplier | Effective Damage Reduction |
|--------------|-------------------|----------------------------|
| 0 | 0.877x | 12.3% reduction |
| 100 | 0.598x | 40.2% reduction |
| 200 | 0.464x | 53.6% reduction |
| 300 | 0.370x | 63.0% reduction |
| 500 | 0.265x | 73.5% reduction |
| 800 | 0.182x | 81.8% reduction |
| 1000 | 0.147x | 85.3% reduction |

**Key Insight:** Defense has diminishing returns. First 200 DEF reduces damage by ~50%, but next 300 DEF only adds ~15% more reduction.

### Example Damage Calculations

**Zeus (1,344 ATK) vs Ares (380 DEF) with Basic Attack (1.0x multiplier):**
```
raw_damage = 1344 * 1.0 * (1000 / (1140 + 3.5 * 380))
raw_damage = 1344 * 1.0 * (1000 / 2470)
raw_damage = 1344 * 0.405
raw_damage = 544
```

**Zeus (1,344 ATK) vs Zeus (1,060 DEF) with Basic Attack:**
```
raw_damage = 1344 * 1.0 * (1000 / (1140 + 3.5 * 1060))
raw_damage = 1344 * 1.0 * (1000 / 4850)
raw_damage = 1344 * 0.206
raw_damage = 277
```

**With Skill (3.0x multiplier):**
```
raw_damage = 1344 * 3.0 * 0.206 = 831 damage
```

### Final Damage Modifiers

1. **Critical Hit:**
   - Chance: `random(0-100) < crit_rate`
   - Multiplier: `1 + (crit_damage / 100)`
   - Example: 60% crit rate, 130% crit damage → 71.5% chance to deal 2.3x damage

2. **Glancing Hit (15% chance if not critical):**
   - Multiplier: 0.7x (70% of normal)

3. **Variance:**
   - Random multiplier: 0.9x to 1.1x (±10%)

4. **Minimum Damage:** 1 (floor)

---

## Speed & Turn Order

### Turn Bar System

```
turn_bar_advancement = speed * 0.07 per tick
unit_acts_when = turn_bar >= 100.0
after_action = turn_bar resets to 0
```

### Speed Breakpoints

| Speed | Ticks to Act | Actions per 100 Ticks |
|-------|--------------|----------------------|
| 100 | 15 ticks | 6.7 actions |
| 150 | 10 ticks | 10 actions |
| 200 | 7 ticks | 14.3 actions |
| 250 | 6 ticks | 16.7 actions |
| 300 | 5 ticks | 20 actions |

**Key Insight:** Speed has massive impact on action frequency. 200 SPD unit acts ~2x more than 100 SPD unit.

### Speed Tuning for Teams

**Example Team:**
- **DPS God:** 250 SPD (acts first, deals burst damage)
- **Buffer:** 240 SPD (acts second, buffs DPS before enemy turn)
- **Debuffer:** 230 SPD (acts third, applies defense break)
- **Tank:** 180 SPD (acts last, absorbs damage)

**Critical Speed Thresholds:**
- **Outspeed opponent:** Your fastest > Enemy fastest
- **Speed tuning buffer:** +10 SPD per role to guarantee order

---

## Critical Hits & Glancing

### Critical Hit Mechanics

**Base Crit Rate:** 15% (all gods)
**Crit Damage:** 50% bonus (1.5x total)

**With Equipment:**
- Crit Rate: Can reach 85-100% with proper substats
- Crit Damage: Can reach 150-200% with substats

**Critical Hit Priority:**
1. Roll: `random(0-100) < crit_rate`
2. If success: `damage *= (1 + crit_damage/100)`
3. If fail: Check for glancing hit

### Glancing Hit Mechanics

**Chance:** 15% (if not critical)
**Effect:** Damage reduced to 70%

**Example:**
- Normal hit: 544 damage
- Glancing hit: 381 damage (544 * 0.7)

### Expected Damage Calculation

```
expected_damage = base_damage * [
    (crit_rate * crit_multiplier) +           # Critical hits
    ((1 - crit_rate) * 0.85 * 1.0) +          # Normal hits
    ((1 - crit_rate) * 0.15 * 0.7)            # Glancing hits
]
```

**Example with 60% Crit Rate, 130% Crit Damage:**
```
expected = 544 * [
    (0.60 * 2.3) +           # 1.38
    (0.40 * 0.85 * 1.0) +    # 0.34
    (0.40 * 0.15 * 0.7)      # 0.042
]
expected = 544 * 1.762 = 958 average damage
```

---

## Balance Recommendations

### Current State Analysis

✅ **What Works:**
- Tier-based scaling provides clear progression paths
- Defense mitigation curve feels fair (no infinite stacking)
- Speed system creates meaningful turn order decisions
- Equipment system provides substantial power growth

⚠️ **Issues Identified:**

1. **Two Different Level Scaling Systems:**
   - `GodProgressionManager` uses tier-based fixed bonuses ✅ (recommended)
   - `CombatCalculator` uses 10% per level multiplier ❌ (legacy)
   - **Fix:** Remove legacy system, use GodProgressionManager exclusively

2. **Static Crit Rate/Crit Damage/Resistance/Accuracy:**
   - All gods start at 15% crit rate, 50% crit damage
   - No natural growth through leveling
   - **Fix:** Consider adding small per-level growth (+0.5% crit rate/level?)

3. **Speed Scaling Disparity:**
   - Tier 1 gods: +2 SPD/level (39 levels = +78 SPD)
   - Tier 5 gods: +4 SPD/level (39 levels = +156 SPD)
   - **Result:** Tier 5 gods are MUCH faster (2x speed advantage)
   - **Consider:** Balance if speed dominance is too strong

4. **Equipment Not Fully Integrated:**
   - `CombatCalculator` notes equipment stats may not be included in battle calculations
   - **Fix:** Verify `EquipmentStatCalculator` feeds into `BattleUnit` creation

### Proposed Balance Changes

#### Option A: Conservative (Minimal Changes)
- Remove legacy 10% level scaling from `CombatCalculator`
- Verify equipment stats flow into battle calculations
- Leave everything else as-is

#### Option B: Moderate (Add Some Growth)
- All changes from Option A
- Add +0.5% crit rate per level (Level 40 = 34.5% base crit rate)
- Add +1% crit damage per level (Level 40 = 89% base crit damage)
- This makes crit builds more viable without equipment

#### Option C: Aggressive (Major Rebalance)
- All changes from Option B
- Reduce speed scaling disparity:
  - Tier 1: +3 SPD/level (was +2)
  - Tier 5: +5 SPD/level (was +4)
  - Narrows gap from 2x to 1.67x
- Add base accuracy/resistance growth:
  - +0.5% accuracy per level
  - +0.5% resistance per level
  - Makes debuff gameplay more viable early

### Recommended: **Option B (Moderate)**

**Reasoning:**
- Preserves current tier advantage structure
- Adds meaningful crit growth for build diversity
- Doesn't disrupt existing god balance too much
- Equipment remains the primary stat customization method

---

## Summary: Key Numbers to Remember

| Metric | Value |
|--------|-------|
| **Max Level** | 40 (50 awakened) |
| **Level 40 HP Range** | 1,060 (Tier 1) to 2,635 (Tier 5) |
| **Level 40 ATK Range** | 444 (Tier 1) to 1,075 (Tier 5) |
| **With Max Equipment** | ~2x base stats |
| **Damage Formula** | `ATK * Multiplier * (1000 / (1140 + 3.5 * DEF))` |
| **Speed Scaling** | `turn_bar += SPD * 0.07` per tick |
| **Crit Base** | 15% rate, 50% damage |
| **Enhancement Max** | +15 (+75% main stat) |
| **Substats per Item** | 1-4 (rarity-dependent) |

---

*This document serves as the authoritative reference for stat balance and progression in Smyte.*
