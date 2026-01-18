---
tags: [moc, gods, progression, leveling, awakening, specialization]
aliases: [God Progression MOC, Leveling Guide, Awakening Guide]
created: 2026-01-18
updated: 2026-01-18
status: complete
type: map-of-content
---

# God Progression - Map of Content

**Purpose**: Complete reference for god leveling, awakening, and specialization systems

**Quick Links**: [[GAME_DESIGN_DOCUMENT]] | [[GameSystems]] | [[STAT_BALANCE_GUIDE]]

---

## God Collection Overview

**Total Gods**: 182 gods across 10 pantheons

| Pantheon | Count | Notable Gods |
|----------|-------|--------------|
| Greek | 25 | Zeus, Hades, Athena, Poseidon, Aphrodite |
| Norse | 22 | Odin, Thor, Loki, Freya, Tyr |
| Egyptian | 20 | Ra, Anubis, Isis, Osiris, Horus |
| Chinese | 18 | Jade Emperor, Guan Yu, Nezha, Sun Wukong |
| Hindu | 16 | Shiva, Vishnu, Brahma, Kali, Ganesha |
| Japanese | 15 | Amaterasu, Susanoo, Tsukuyomi, Inari |
| Celtic | 14 | Dagda, Morrigan, Lugh, Brigid |
| Slavic | 12 | Perun, Veles, Mokosh, Svarog |
| Mesopotamian | 10 | Marduk, Ishtar, Enki, Gilgamesh |
| Other | 30 | Various mythologies |

**God Tiers**:
- Tier 1 (Common): 25 gods, summon_weight 60
- Tier 2 (Rare): 47 gods, summon_weight 30
- Tier 3 (Epic): 32 gods, summon_weight 9
- Tier 4 (Legendary): 8 gods, summon_weight 1
- Tier 5 (Mythic): Future content

**Related Files**:
- `data/gods.json` (182 gods)
- `data/awakened_gods.json` (awakened forms)
- `scripts/systems/collection/CollectionManager.gd` (163 lines)

---

## Leveling System

### XP Formula

```gdscript
# XP required for each level
XP_for_level(n) = 200 * 1.2^(n - 2)  // For n >= 2

# Total XP needed to reach level n
Total_XP(n) = Sum(XP_for_level(i) for i in 2..n)
```

**Examples**:
- Level 2: 200 XP
- Level 3: 240 XP
- Level 5: 346 XP
- Level 10: 1,036 XP
- Level 20: 15,917 XP (cumulative)
- Level 30: 244,231 XP (cumulative)
- Level 40: 3,748,096 XP (cumulative)

### XP Sources

| Source | XP Gain | Notes |
|--------|---------|-------|
| **Enemy Defeat** | 50-500 per enemy | Varies by dungeon difficulty |
| **God Sacrifice** | 100-12,500 per god | Common: 100, Rare: 500, Epic: 2,500, Legendary: 12,500 |
| **Task Completion** | 10-100 per task | Territory assignment rewards |
| **Battle Victory** | 500-5,000 per battle | Bonus XP for first clear |

**Sacrifice System**:
- Feed duplicate gods to main god for XP
- Also grants mana: Common: 1k, Rare: 5k, Epic: 25k, Legendary: 125k
- Efficient way to convert unwanted gods to progress

---

## Stat Scaling

### Level-Based Stat Bonuses

**Stat Increase Per Level** (by Tier):

| Tier | Attack/Lvl | Defense/Lvl | HP/Lvl | Speed/Lvl |
|------|-----------|-----------|--------|----------|
| 1 (Common) | +10 | +8 | +25 | +2 |
| 2 (Rare) | +12 | +10 | +30 | +2 |
| 3 (Epic) | +15 | +12 | +40 | +3 |
| 4 (Legendary) | +20 | +15 | +50 | +3 |
| 5 (Mythic) | +25 | +18 | +65 | +4 |

**Example Progression** (Zeus, Legendary tier):
```
Base Stats (Level 1): 64 ATK, 61 DEF, 120 HP, 61 SPD

Level 10: 64 + (20 × 9) = 244 ATK
Level 20: 64 + (20 × 19) = 444 ATK
Level 40: 64 + (20 × 39) = 844 ATK
Level 50 (Awakened): 64 + (20 × 49) = 1,044 ATK
```

### Stat Scaling Formula

```gdscript
# For HP, Attack, Defense (not Speed)
level_multiplier = 1.0 + (level - 1) * 0.1

final_stat = base_stat * level_multiplier
```

**Example** (Zeus HP scaling):
```
Base HP: 120

Level 1: 120 × 1.0 = 120 HP
Level 20: 120 × 2.9 = 348 HP
Level 40: 120 × 4.9 = 588 HP
Level 50: 120 × 5.9 = 708 HP
```

**Note**: Speed does NOT scale with level - remains constant at base value.

---

## Combat Stats

### God Base Stats

Every god has 8 core stats:

| Stat | Purpose | Typical Range |
|------|---------|---------------|
| **HP** | Health points | 80-150 (base) |
| **Attack** | Damage dealt | 45-85 (base) |
| **Defense** | Damage reduction | 40-95 (base) |
| **Speed** | Turn order | 57-61 (base) |
| **Crit Rate** | Critical hit chance | 15% (standard) |
| **Crit Damage** | Critical multiplier | 50% (standard, so 1.5x damage) |
| **Accuracy** | Debuff land rate | 0% (standard) |
| **Resistance** | Debuff resist rate | 0% (standard) |

### Combat Formula

**Damage Calculation** (Summoners War-based):
```gdscript
raw_damage = base_attack * multiplier * (1000 / (1140 + 3.5 * defense))

if critical_hit:
    raw_damage *= (1 + crit_damage / 100)
else if glancing_hit:  # 15% chance
    raw_damage *= 0.7

variance = random(0.9, 1.1)  # ±10%
final_damage = max(1, int(raw_damage * variance))
```

**Example** (Zeus attacking enemy with 100 DEF):
```
Zeus: 244 ATK (Level 10), Skill multiplier: 1.5x

raw_damage = 244 * 1.5 * (1000 / (1140 + 3.5 * 100))
           = 366 * (1000 / 1490)
           = 366 * 0.671
           = 245.5

If critical (50% crit damage):
  = 245.5 * 1.5 = 368.25

With variance (0.9-1.1):
  = 331 to 405 damage
```

**Defense Effectiveness**:
```
0 DEF: 100% damage taken (no reduction)
100 DEF: 73.4% damage taken (26.6% reduction)
200 DEF: 64.7% damage taken (35.3% reduction)
400 DEF: 53.2% damage taken (46.8% reduction)
```

**Related Docs**:
- [[STAT_BALANCE_GUIDE]] - Complete damage formulas and stat scaling (10k+ words)

**Related Files**:
- `scripts/systems/battle/CombatCalculator.gd` (380 lines)

---

## Awakening System

### Awakening Requirements

**Prerequisites**:
- God must reach Level 40 (max non-awakened level)
- God must be at max level

**Materials Needed** (Example: Epic Fire God):
```
Materials:
├─ fire_powder_low: 10
├─ fire_powder_mid: 5
├─ fire_powder_high: 2
├─ magic_powder_high: 1 (universal alternative)
├─ awakening_stone: 1
└─ mana: 50,000
```

**Material Costs by Tier**:

| God Tier | Low Powder | Mid Powder | High Powder | Universal | Stone | Mana |
|----------|-----------|-----------|------------|-----------|-------|------|
| Common | 5 | 2 | 1 | 0 | 1 | 10,000 |
| Rare | 8 | 4 | 2 | 1 | 1 | 25,000 |
| Epic | 10 | 5 | 2 | 1 | 1 | 50,000 |
| Legendary | 15 | 8 | 4 | 2 | 1 | 100,000 |

### Awakening Process

1. **Validation** (`can_awaken_god`)
   - Verify level 40
   - Check no existing awakened form
   - Validate materials available

2. **Material Consumption** (`consume_awakening_materials`)
   - Resources deducted from ResourceManager
   - Atomic transaction (all or nothing)

3. **God Replacement** (`replace_god_with_awakened`)
   - Creates new God instance from `awakened_gods.json`
   - Preserves from original:
     - Level (remains at 40)
     - Experience
     - Ascension level
     - Skill levels
     - Territory station
   - Sets `is_awakened = true`
   - Extends level cap to 50

### Post-Awakening Changes

**Level Cap**: 40 → 50 (10 additional levels)

**Stat Changes** (Example: Athena → Athena, The Strategist):
```
Base HP: 98 → 180 (+82 HP, +83.7%)
Base ATK: 48 → 85 (+37 ATK, +77.1%)
Base DEF: 85 → 95 (+10 DEF, +11.8%)
Base SPD: 61 → 70 (+9 SPD, +14.8%)
```

**New Abilities**:
- Awakened gods gain unique abilities not available to base form
- Enhanced passive abilities
- Leader skill may be upgraded

**Visual Changes**:
- New god portrait
- Enhanced visual effects
- Awakened tag/badge

**Related Docs**:
- [[god_roles_and_specializations]] - Role system details

**Related Files**:
- `scripts/systems/progression/AwakeningSystem.gd` (189 lines)
- `data/awakened_gods.json` (awakened form definitions)

---

## Specialization System

### Role Foundation (5 Primary Roles)

| Role | Stat Bonuses | Task Bonuses | Task Penalties |
|------|-------------|--------------|----------------|
| **Fighter** | +15% ATK, +10% DEF | Combat +20%, Defense +20%, Training +15% | Crafting -10%, Research -5% |
| **Gatherer** | +5% HP | Mining +25%, Harvesting +25%, Hunting +25% | Research -10% |
| **Crafter** | +10% HP, +5% DEF | Forging +30%, Alchemy +30%, Enchanting +30% | Gathering -10% |
| **Scholar** | +10% SPD, +15% skill_points | Research +40%, Study Lore +40%, Training +25% | Mining -15% |
| **Support** | +15% HP, +10% SPD | Healing +40%, Buffing +35%, Leadership +30% | Gathering -20%, Crafting -20% |

### Specialization Trees (84 Total)

**Structure**: 5 Roles × 4 Paths × 3-4 Tiers = 84 specializations

**Example: Fighter Role Paths**

#### Tier 1 (Unlocks at Level 20)
1. **Berserker** - Offensive focus
   - Cost: 10,000 Gold + 50 Divine Essence
   - Stat Bonuses: +15% ATK, -5% DEF, +25% Crit Damage
   - Unlocks Ability: `rage_strike`
   - Children: Raging Warrior, Blood Dancer

2. **Guardian** - Defensive focus
   - Cost: 10,000 Gold + 50 Divine Essence
   - Stat Bonuses: +20% DEF, +15% HP, -5% SPD
   - Unlocks Ability: `shield_wall`
   - Children: Unbreakable Wall, Retribution Knight

3. **Duelist** - Single-target specialist
   - Cost: 10,000 Gold + 50 Divine Essence
   - Stat Bonuses: +10% ATK, +15% Crit Rate, +10% SPD
   - Unlocks Ability: `precision_strike`
   - Children: Blade Master, Critical Assassin

4. **Commander** - Team support
   - Cost: 10,000 Gold + 50 Divine Essence
   - Stat Bonuses: +5% All Stats (team aura)
   - Unlocks Ability: `battle_cry`
   - Children: War Leader, Tactical Genius

#### Tier 2 (Unlocks at Level 30)
**Raging Warrior** (Berserker → Raging Warrior):
- Cost: 50,000 Gold + 200 Divine Essence + 10 Spec Tomes
- Stat Bonuses: +25% ATK, -10% DEF, +40% Crit Damage
- Unlocks: `unstoppable_rage`
- Enhances: `rage_strike` (+2 levels)
- Child: Avatar of Fury

**Blood Dancer** (Berserker → Blood Dancer):
- Cost: 50,000 Gold + 200 Divine Essence + 10 Spec Tomes
- Stat Bonuses: +20% ATK, +5% Lifesteal, +30% Crit Damage
- Unlocks: `blood_fury`
- Child: Avatar of Fury

#### Tier 3 (Unlocks at Level 40)
**Avatar of Fury** (Raging Warrior/Blood Dancer → Avatar of Fury):
- Cost: 200,000 Gold + 1,000 Divine Essence + 50 Spec Tomes + 1 Legendary Scroll
- Stat Bonuses: +40% ATK, CC Immunity (boolean)
- Unlocks: `divine_wrath`
- Enhances: `rage_strike` (+3), `unstoppable_rage` (+1)

### Specialization Bonus Stacking

**All bonuses from specialization path stack additively**.

**Example** (Full Berserker Path):
```
Tier 1 (Berserker): +15% ATK, -5% DEF, +25% Crit Damage
Tier 2 (Raging Warrior): +25% ATK, -10% DEF, +40% Crit Damage
Tier 3 (Avatar of Fury): +40% ATK, CC Immunity

Total Bonuses:
├─ +80% ATK (15 + 25 + 40)
├─ -15% DEF (-5 + -10)
├─ +65% Crit Damage (25 + 40)
└─ CC Immunity (cannot be stunned/frozen)
```

### Specialization Requirements

**Eligibility Checks**:
- Must be appropriate level for tier (20/30/40)
- Must have primary role assigned
- Must have parent specialization (if Tier 2+)
- Must not have conflicting specialization at tier
- Must have required traits (if any)
- Must not have blocked traits

**Cost Progression**:
```
Tier 1: 10,000 Gold + 50 Divine Essence
Tier 2: 50,000 Gold + 200 Divine Essence + 10 Spec Tomes
Tier 3: 200,000 Gold + 1,000 Divine Essence + 50 Spec Tomes + 1 Legendary Scroll
```

---

## Territory Efficiency

### Task Efficiency Formula

```gdscript
Time = Base_Time / (1 + Role_Bonus + Specialization_Bonus + Equipment_Bonus)
```

**Example** (Combat Task, 1 hour base):
```
Fighter role: 1 / 1.20 = 50 minutes
+ Berserker Tier 1: 1 / 1.50 = 40 minutes
+ Avatar of Fury Tier 3: 1 / (1.30 + bonuses) ≈ 35 minutes
```

### God-to-Node Matching

**Best Efficiency Multipliers**:
```
Final Efficiency = Base Role Bonus × (1 + Specialization Bonus) × (1 + Equipment Bonus)
```

**Example** (Maximum Combat):
```
Role: Fighter (+20%)
Specialization Path: Berserker → Raging Warrior → Avatar of Fury (+30% at Tier 2)
Final: Base × 1.20 × 1.30 = Base × 1.56 (56% total increase)
```

**Example** (Maximum Gathering):
```
Role: Gatherer (+25%)
Specialization: Miner path (+25% task bonus, +25% resource bonus)
Resource bonuses: +25% yield + +10% rare = total gathering boost ≈60%
```

### God Assignment Multipliers

**Production Multipliers**:
- Matching role: +25%
- Tier 1 spec: +50%
- Tier 2 spec: +100%
- Tier 3 spec: +200%
- Awakened god: +30%
- Legendary tier god: +80%
- Element match: +50%
- Connected nodes (2+): +10%, (3+): +20%, (4+): +30%

**Example** (Mine T2 with Tier 2 Miner):
```
Base: 5 mythril_ore/hr
Role (Gatherer): +25% → 6.25/hr
Spec (Tier 2 Miner): +100% → 12.5/hr
Connected (3+ nodes): +20% → 15/hr
Element match (Earth god): +50% → 22.5/hr

Final: 22.5 mythril_ore/hr (4.5x base!)
```

---

## God Optimization Strategies

### Early Game (Level 1-20)

**Priority**: Get first god to Level 20 for Tier 1 specialization
- **Focus**: Farm dungeons for XP
- **Sacrifice**: Feed duplicate gods to main god
- **Equipment**: Craft basic_iron_sword, basic_iron_armor
- **Specialization**: Choose based on desired playstyle (Gatherer for resources, Fighter for combat)

### Mid Game (Level 20-30)

**Priority**: Unlock Tier 2 specialization, build balanced team
- **Focus**: Diversify god roles (1-2 fighters, 2-3 gatherers, 1 crafter, 1 scholar)
- **Territory**: Capture tier 2-3 nodes with matching specializations
- **Equipment**: Craft rare equipment (steel_greatsword, mystic_ring)
- **Awakening Prep**: Stockpile element powders from daily sanctum rotations

### Late Game (Level 30-40)

**Priority**: Prepare for awakening, maximize territory efficiency
- **Focus**: Rush to level 40 on main gods
- **Territory**: Control tier 3-4 nodes, build connected node clusters (+30% bonus)
- **Equipment**: Craft epic equipment (mythril_warblade, crystal_pendant)
- **Awakening**: Farm awakening_stones from Expert dungeons
- **Specialization**: Unlock Tier 3 specs for +200% efficiency

### Endgame (Level 40-50, Awakened)

**Priority**: Min-max awakened gods, dominate tier 5 nodes
- **Focus**: Awaken 6-12 core gods (balanced team)
- **Territory**: Control tier 5 nodes for divine_ore, celestial_essence
- **Equipment**: Enhance to +15 (30% success rate, use blessed_oil)
- **Sockets**: Insert perfect gemstones (tier 4 gems)
- **PvP**: Arena rankings, territory raids

---

## Progression Roadmap

### Level 1-10 (Tutorial Phase)
- ✅ Complete summoning tutorial
- ✅ Reach level 10 on starter god
- ✅ Capture first 3 tier 1 nodes
- ✅ Unlock first dungeon (Fire Sanctum Beginner)
- ✅ Craft first equipment (basic_iron_sword)

### Level 10-20 (Early Progression)
- ✅ Build team of 6+ gods
- ✅ Reach level 20 on main god
- ✅ Unlock first specialization (Tier 1)
- ✅ Capture tier 2 nodes
- ✅ Unlock Intermediate difficulty dungeons

### Level 20-30 (Mid Progression)
- ✅ Reach level 30 on main god
- ✅ Unlock Tier 2 specialization
- ✅ Capture tier 3 nodes (requires Tier 2 spec)
- ✅ Craft rare equipment
- ✅ Unlock Advanced difficulty dungeons

### Level 30-40 (Late Progression)
- ✅ Reach level 40 on 3+ gods
- ✅ Unlock Tier 3 specialization
- ✅ Capture tier 4 nodes
- ✅ Craft epic equipment
- ✅ Unlock Expert difficulty dungeons
- ✅ Stockpile awakening materials

### Level 40-50 (Endgame)
- ✅ Awaken 6-12 core gods
- ✅ Reach level 50 on awakened gods
- ✅ Capture tier 5 nodes
- ✅ Enhance equipment to +15
- ✅ Complete all pantheon trials
- ✅ Dominate PvP arena

---

## God Ability System

### Ability Types

| Type | Cooldown | Effect |
|------|----------|--------|
| **Basic Attack** | 0 | 1.5x ATK multiplier, single target |
| **Skill 1** | 2-3 | 0.8-1.2x ATK, utility (debuff, heal, buff) |
| **Skill 2** | 3-4 | 1.2-1.8x ATK, AOE or powerful single-target |
| **Ultimate** | 4-5 | 2.0-3.0x ATK, game-changing effect |

### Status Effects (30+ total)

**Buffs**:
- ATK/DEF/SPD Up (1-3 turns, 10-50% boost)
- Shield (absorbs damage, 1-2 turns)
- Immunity (prevents debuffs, 1-2 turns)
- Continuous Heal (HOT, 3 turns)
- Counter Attack (reflects damage, 2 turns)

**Debuffs**:
- ATK/DEF/SPD Down (1-3 turns, 10-50% reduction)
- Stun (skip turn, 1 turn)
- Freeze (skip turn + SPD down, 1-2 turns)
- Burn (DOT, fire damage, 3 turns)
- Poison (DOT, 10% max HP, 3 turns)
- Bleed (DOT, scaling with ATK, 2 turns)
- Silence (can't use skills, 1-2 turns)
- Block Beneficial Effects (can't be buffed, 2 turns)

**Ability Scaling**:
- Most abilities scale with ATK
- Some scale with DEF (tank abilities)
- Some scale with HP (bruiser abilities)
- Some scale with SPD (support abilities)

**Related Files**:
- `data/abilities.json` (100+ abilities)
- `scripts/systems/battle/BattleActionProcessor.gd` (action processing)
- `scripts/systems/battle/StatusEffectManager.gd` (buff/debuff tracking)

---

## Leader Skills

**Purpose**: Passive bonuses when god is set as team leader

**Leader Skill Types**:
1. **Stat Boost** - +15-30% HP/ATK/DEF for all allies
2. **Element Boost** - +30-50% damage for specific element
3. **Pantheon Boost** - +20% all stats for same pantheon
4. **Crit Boost** - +15% Crit Rate for all allies
5. **Speed Boost** - +20% SPD for all allies

**Example** (Zeus Leader Skill):
```
"Thunder God's Authority"
├─ Effect: All allies +30% ATK
├─ Condition: Always active
└─ Best for: Aggressive offense teams
```

**Strategic Use**:
- Choose leader based on team composition
- Element-focused teams: Use element boost leader
- Balanced teams: Use stat boost leader
- Speed teams: Use speed boost leader

---

## Navigation

**Main Documents**:
- [[GAME_DESIGN_DOCUMENT]] - Section 4: God Collection & Progression
- [[STAT_BALANCE_GUIDE]] - Complete stat system (10k+ words)
- [[god_roles_and_specializations]] - Role system details

**Related MOCs**:
- [[GameSystems]] - All game systems overview
- [[ResourceEconomy]] - Awakening materials and economy
- [[TerritoryManagement]] - God assignment and efficiency
- [[CombatMechanics]] - Combat formulas and mechanics

**Related Files**:
- `data/gods.json` (182 gods)
- `data/awakened_gods.json` (awakened forms)
- `data/abilities.json` (100+ abilities)
- `data/roles.json` (5 roles)
- `data/specializations.json` (84 specializations)
- `scripts/systems/progression/GodProgressionManager.gd` (247 lines)
- `scripts/systems/progression/AwakeningSystem.gd` (189 lines)
- `scripts/systems/progression/SpecializationManager.gd` (312 lines)

---

*This Map of Content was created 2026-01-18 to provide complete reference for the god progression system.*
