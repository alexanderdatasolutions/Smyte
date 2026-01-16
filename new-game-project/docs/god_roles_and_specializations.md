# God Roles & Specialization System - Complete Design Document

**Version:** 1.0
**Last Updated:** 2026-01-16
**Status:** Design Complete, Ready for Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Role Taxonomy](#role-taxonomy)
3. [Specialization Trees](#specialization-trees)
4. [Progression Requirements](#progression-requirements)
5. [Stat Effects & Bonuses](#stat-effects--bonuses)
6. [Task Efficiency System](#task-efficiency-system)
7. [Data Schemas](#data-schemas)
8. [Implementation Notes](#implementation-notes)

---

## Overview

### Vision

The Role & Specialization System transforms gods from generic combat units into specialized workers with unique strengths. This creates:
- **Meaningful collection choices** - Not all 5-star gods are equally valuable
- **Strategic depth** - Assign the right god to the right task
- **Long-term progression** - Specialization paths unlock over 40 levels
- **Lore integration** - Hephaestus excels at forging, Athena at research

### Core Mechanics

1. **Base Roles** (5 types) - Assigned at level 1, determines baseline bonuses
2. **Specialization Paths** - Unlock at level 20, 30, 40 with branching choices
3. **Task Efficiency** - Role + Specialization + Traits combine for task bonuses
4. **Combat Integration** - Specializations also grant combat abilities

---

## Role Taxonomy

### 1. Fighter Role

**Identity:** Gods of war, battle, and conflict
**Primary Stat:** Attack, Defense
**Best Tasks:** Territory Defense, Monster Hunting, Training Warriors
**Example Gods:** Ares, Thor, Sekhmet, Huitzilopochtli

**Base Bonuses:**
- +15% Attack damage
- +10% Defense
- +20% effectiveness on combat tasks
- -10% effectiveness on crafting tasks

**Lore Fit:** War gods, battle deities, protectors

---

### 2. Gatherer Role

**Identity:** Gods of nature, harvest, and abundance
**Primary Stat:** Resource yield multiplier
**Best Tasks:** Mining, Harvesting, Fishing, Hunting
**Example Gods:** Demeter, Freya, Osiris, Chang'e

**Base Bonuses:**
- +25% resource gathering yield
- +15% gathering task speed
- +10% chance for rare materials
- -10% effectiveness on research tasks

**Lore Fit:** Harvest deities, nature gods, fertility goddesses

---

### 3. Crafter Role

**Identity:** Gods of creation, artifice, and craftsmanship
**Primary Stat:** Crafting quality
**Best Tasks:** Forging, Alchemy, Enchanting, Artifact Creation
**Example Gods:** Hephaestus, Ptah, Svarog, Goibniu

**Base Bonuses:**
- +30% crafting quality (higher tier outputs)
- +20% crafting speed
- +5% chance for masterwork items
- -10% effectiveness on gathering tasks

**Lore Fit:** Smith gods, artisan deities, creators

---

### 4. Scholar Role

**Identity:** Gods of wisdom, knowledge, and magic
**Primary Stat:** Research speed, XP gain
**Best Tasks:** Research, Scouting, Training, Teaching
**Example Gods:** Athena, Thoth, Odin, Saraswati

**Base Bonuses:**
- +40% research speed
- +25% XP gain for all gods in territory
- +15% scouting range
- -15% effectiveness on physical gathering

**Lore Fit:** Wisdom gods, magic deities, knowledge keepers

---

### 5. Support Role

**Identity:** Gods of healing, protection, and leadership
**Primary Stat:** Team buffs
**Best Tasks:** Healing, Buffing, Territory Management, Defense Coordination
**Example Gods:** Hestia, Frigg, Isis, Guanyin

**Base Bonuses:**
- +20% healing effectiveness
- +15% to all allies' task efficiency in same territory
- +10% territory defense rating
- -20% personal gathering/crafting efficiency

**Lore Fit:** Hearth goddesses, healers, protectors, mother figures

---

## Specialization Trees

**Design Philosophy:**
- 3 tiers: Level 20, 30, 40
- 3-4 paths per role
- Each path has 2 options at tier 2, converging to ultimate at tier 3
- Total: ~65 unique specializations

---

### Fighter Specializations

```
FIGHTER (Base)
│
├── BERSERKER PATH (Tier 1 - Level 20)
│   ├── Raging Warrior (Tier 2 - Level 30)
│   │   └── Avatar of Fury (Tier 3 - Level 40)
│   └── Blood Dancer (Tier 2 - Level 30)
│       └── Avatar of Fury (Tier 3 - Level 40)
│
├── GUARDIAN PATH (Tier 1 - Level 20)
│   ├── Shield Master (Tier 2 - Level 30)
│   │   └── Immortal Bulwark (Tier 3 - Level 40)
│   └── Warden (Tier 2 - Level 30)
│       └── Immortal Bulwark (Tier 3 - Level 40)
│
├── TACTICIAN PATH (Tier 1 - Level 20)
│   ├── Battle Commander (Tier 2 - Level 30)
│   │   └── War Incarnate (Tier 3 - Level 40)
│   └── Strategic Genius (Tier 2 - Level 30)
│       └── War Incarnate (Tier 3 - Level 40)
│
└── ASSASSIN PATH (Tier 1 - Level 20)
    ├── Shadow Striker (Tier 2 - Level 30)
    │   └── Death's Hand (Tier 3 - Level 40)
    └── Silent Killer (Tier 2 - Level 30)
        └── Death's Hand (Tier 3 - Level 40)
```

**Fighter Specialization Details:**

| ID | Name | Tier | Requires | Bonuses | Ability Unlocked |
|----|------|------|----------|---------|------------------|
| `fighter_berserker` | Berserker | 1 | Level 20, Fighter | +15% ATK, -5% DEF, +25% crit damage | Rage Strike |
| `fighter_berserker_raging` | Raging Warrior | 2 | Level 30, Berserker | +25% ATK, -10% DEF, +40% crit damage | Unstoppable Rage |
| `fighter_berserker_blood` | Blood Dancer | 2 | Level 30, Berserker | +20% ATK, +5% lifesteal, +30% crit damage | Blood Fury |
| `fighter_berserker_avatar` | Avatar of Fury | 3 | Level 40, (Raging or Blood) | +40% ATK, immune to crowd control | Divine Wrath |
| `fighter_guardian` | Guardian | 1 | Level 20, Fighter | +20% DEF, +15% HP, +10% threat | Protective Stance |
| `fighter_guardian_shield` | Shield Master | 2 | Level 30, Guardian | +30% DEF, +20% HP, +15% block | Aegis Wall |
| `fighter_guardian_warden` | Warden | 2 | Level 30, Guardian | +25% DEF, +25% HP, reflect damage | Iron Will |
| `fighter_guardian_bulwark` | Immortal Bulwark | 3 | Level 40, (Shield or Warden) | +50% DEF, +40% HP, auto-revive once | Unbreakable |
| `fighter_tactician` | Tactician | 1 | Level 20, Fighter | +10% team ATK/DEF, +20% to training tasks | Battle Orders |
| `fighter_tactician_commander` | Battle Commander | 2 | Level 30, Tactician | +15% team stats, +30% training, area buffs | Rally Troops |
| `fighter_tactician_genius` | Strategic Genius | 2 | Level 30, Tactician | +20% team stats, predict enemy moves | Perfect Strategy |
| `fighter_tactician_war` | War Incarnate | 3 | Level 40, (Commander or Genius) | +30% team stats, +50% training, army-wide buffs | Art of War |
| `fighter_assassin` | Assassin | 1 | Level 20, Fighter | +20% crit chance, +30% speed, first strike | Backstab |
| `fighter_assassin_shadow` | Shadow Striker | 2 | Level 30, Assassin | +30% crit chance, invisibility, ignore armor | Shadow Step |
| `fighter_assassin_silent` | Silent Killer | 2 | Level 30, Assassin | +35% crit chance, +50% speed, execute low HP | Death Mark |
| `fighter_assassin_death` | Death's Hand | 3 | Level 40, (Shadow or Silent) | +50% crit chance, guaranteed crit on full HP targets | Instant Death |

---

### Gatherer Specializations

```
GATHERER (Base)
│
├── MINER PATH (Tier 1 - Level 20)
│   ├── Gem Cutter (Tier 2 - Level 30)
│   │   └── Master Jeweler (Tier 3 - Level 40)
│   └── Deep Miner (Tier 2 - Level 30)
│       └── Earth Shaper (Tier 3 - Level 40)
│
├── FISHER PATH (Tier 1 - Level 20)
│   ├── Pearl Diver (Tier 2 - Level 30)
│   │   └── Ocean Master (Tier 3 - Level 40)
│   └── Whale Hunter (Tier 2 - Level 30)
│       └── Sea Sovereign (Tier 3 - Level 40)
│
├── HERBALIST PATH (Tier 1 - Level 20)
│   ├── Botanist (Tier 2 - Level 30)
│   │   └── Grove Keeper (Tier 3 - Level 40)
│   └── Alchemical Harvester (Tier 2 - Level 30)
│       └── Nature's Chosen (Tier 3 - Level 40)
│
└── HUNTER PATH (Tier 1 - Level 20)
    ├── Tracker (Tier 2 - Level 30)
    │   └── Beast Master (Tier 3 - Level 40)
    └── Trapper (Tier 2 - Level 30)
        └── Apex Predator (Tier 3 - Level 40)
```

**Gatherer Specialization Details:**

| ID | Name | Tier | Requires | Bonuses | Task Efficiency |
|----|------|------|----------|---------|-----------------|
| `gatherer_miner` | Miner | 1 | Level 20, Gatherer | +30% ore yield, +15% gem chance | Mining +50% |
| `gatherer_miner_gem` | Gem Cutter | 2 | Level 30, Miner | +50% gem yield, +20% rare gem chance | Mining +70%, Gem Cutting +80% |
| `gatherer_miner_deep` | Deep Miner | 2 | Level 30, Miner | +60% ore yield, unlock deep veins | Mining +90%, Deep Mining +100% |
| `gatherer_miner_jeweler` | Master Jeweler | 3 | Level 40, Gem Cutter | +80% gem yield, +10% legendary gem chance | Gem Cutting +150% |
| `gatherer_miner_shaper` | Earth Shaper | 3 | Level 40, Deep Miner | +100% ore, create mining nodes | Mining +150%, Node Creation |
| `gatherer_fisher` | Fisher | 1 | Level 20, Gatherer | +30% fish yield, +15% rare catch | Fishing +50% |
| `gatherer_fisher_pearl` | Pearl Diver | 2 | Level 30, Fisher | +50% pearl yield, underwater breathing | Fishing +70%, Pearl Diving +80% |
| `gatherer_fisher_whale` | Whale Hunter | 2 | Level 30, Fisher | +60% big fish yield, hunt sea monsters | Fishing +90%, Monster Hunting +50% |
| `gatherer_fisher_ocean` | Ocean Master | 3 | Level 40, Pearl Diver | +80% all aquatic resources | All fishing +150% |
| `gatherer_fisher_sovereign` | Sea Sovereign | 3 | Level 40, Whale Hunter | +100% fish, summon sea creatures | Fishing +150%, Summon Aid |
| `gatherer_herbalist` | Herbalist | 1 | Level 20, Gatherer | +30% herb yield, +15% rare herb | Harvesting +50% |
| `gatherer_herbalist_botanist` | Botanist | 2 | Level 30, Herbalist | +50% herb yield, identify all plants | Harvesting +80%, Plant Lore |
| `gatherer_herbalist_alchemical` | Alchemical Harvester | 2 | Level 30, Herbalist | +40% herb yield, +30% alchemical reagents | Harvesting +70%, Alchemy +30% |
| `gatherer_herbalist_grove` | Grove Keeper | 3 | Level 40, Botanist | +80% herbs, plant growth acceleration | Harvesting +150%, Farming |
| `gatherer_herbalist_nature` | Nature's Chosen | 3 | Level 40, Alchemical | +100% alchemical materials | Harvesting +120%, Alchemy +80% |
| `gatherer_hunter` | Hunter | 1 | Level 20, Gatherer | +30% monster parts, +15% rare drop | Hunting +50% |
| `gatherer_hunter_tracker` | Tracker | 2 | Level 30, Hunter | +50% parts, track any creature | Hunting +80%, Tracking |
| `gatherer_hunter_trapper` | Trapper | 2 | Level 30, Hunter | +60% parts, set monster traps | Hunting +90%, Trap Mastery |
| `gatherer_hunter_beast` | Beast Master | 3 | Level 40, Tracker | +80% parts, tame beasts | Hunting +150%, Taming |
| `gatherer_hunter_apex` | Apex Predator | 3 | Level 40, Trapper | +100% parts, hunt legendary beasts | Hunting +200% |

---

### Crafter Specializations

```
CRAFTER (Base)
│
├── FORGEMASTER PATH (Tier 1 - Level 20)
│   ├── Weaponsmith (Tier 2 - Level 30)
│   │   └── Divine Forger (Tier 3 - Level 40)
│   └── Armorsmith (Tier 2 - Level 30)
│       └── Divine Forger (Tier 3 - Level 40)
│
├── ALCHEMIST PATH (Tier 1 - Level 20)
│   ├── Potion Master (Tier 2 - Level 30)
│   │   └── Transmutation Sage (Tier 3 - Level 40)
│   └── Elixir Brewer (Tier 2 - Level 30)
│       └── Transmutation Sage (Tier 3 - Level 40)
│
├── ENCHANTER PATH (Tier 1 - Level 20)
│   ├── Rune Carver (Tier 2 - Level 30)
│   │   └── Arcane Artificer (Tier 3 - Level 40)
│   └── Gem Enchanter (Tier 2 - Level 30)
│       └── Arcane Artificer (Tier 3 - Level 40)
│
└── ARTIFICER PATH (Tier 1 - Level 20)
    ├── Artifact Smith (Tier 2 - Level 30)
    │   └── Creator's Touch (Tier 3 - Level 40)
    └── Relic Restorer (Tier 2 - Level 30)
        └── Creator's Touch (Tier 3 - Level 40)
```

**Crafter Specialization Details:**

| ID | Name | Tier | Requires | Bonuses | Crafting Boost |
|----|------|------|----------|---------|----------------|
| `crafter_forgemaster` | Forgemaster | 1 | Level 20, Crafter | +30% equipment quality, +10% masterwork | Forging +50% |
| `crafter_forge_weapon` | Weaponsmith | 2 | Level 30, Forgemaster | +50% weapon quality, +20% masterwork | Weapon Forging +100% |
| `crafter_forge_armor` | Armorsmith | 2 | Level 30, Forgemaster | +50% armor quality, +20% masterwork | Armor Forging +100% |
| `crafter_forge_divine` | Divine Forger | 3 | Level 40, (Weapon or Armor) | +100% quality, +30% legendary, craft divines | All Forging +200% |
| `crafter_alchemist` | Alchemist | 1 | Level 20, Crafter | +30% potion power, +15% yield | Alchemy +50% |
| `crafter_alchemist_potion` | Potion Master | 2 | Level 30, Alchemist | +50% potion power, +25% yield | Potion Crafting +100% |
| `crafter_alchemist_elixir` | Elixir Brewer | 2 | Level 30, Alchemist | +60% elixir power, permanent effects | Elixir Crafting +120% |
| `crafter_alchemist_transmute` | Transmutation Sage | 3 | Level 40, (Potion or Elixir) | +100% power, transmute materials | Alchemy +200%, Material Conversion |
| `crafter_enchanter` | Enchanter | 1 | Level 20, Crafter | +30% enchantment power, +10% dual stats | Enchanting +50% |
| `crafter_enchanter_rune` | Rune Carver | 2 | Level 30, Enchanter | +50% rune power, inscribe gear | Rune Crafting +100% |
| `crafter_enchanter_gem` | Gem Enchanter | 2 | Level 30, Enchanter | +60% gem power, combine gems | Gem Enchanting +120% |
| `crafter_enchanter_arcane` | Arcane Artificer | 3 | Level 40, (Rune or Gem) | +100% enchant power, triple stats | Enchanting +200% |
| `crafter_artificer` | Artificer | 1 | Level 20, Crafter | +30% artifact quality, +10% unique | Artifact Creation +50% |
| `crafter_artificer_smith` | Artifact Smith | 2 | Level 30, Artificer | +50% artifact quality, craft uniques | Artifact Creation +100% |
| `crafter_artificer_restorer` | Relic Restorer | 2 | Level 30, Artificer | +40% quality, restore ancient artifacts | Restoration +120% |
| `crafter_artificer_creator` | Creator's Touch | 3 | Level 40, (Smith or Restorer) | +100% quality, create legendary artifacts | Artifact Creation +250% |

---

### Scholar Specializations

```
SCHOLAR (Base)
│
├── RESEARCHER PATH (Tier 1 - Level 20)
│   ├── Tech Specialist (Tier 2 - Level 30)
│   │   └── Omniscient Sage (Tier 3 - Level 40)
│   └── Magic Theorist (Tier 2 - Level 30)
│       └── Omniscient Sage (Tier 3 - Level 40)
│
├── EXPLORER PATH (Tier 1 - Level 20)
│   ├── Cartographer (Tier 2 - Level 30)
│   │   └── World Wanderer (Tier 3 - Level 40)
│   └── Archaeologist (Tier 2 - Level 30)
│       └── World Wanderer (Tier 3 - Level 40)
│
├── MENTOR PATH (Tier 1 - Level 20)
│   ├── Combat Trainer (Tier 2 - Level 30)
│   │   └── Grand Master (Tier 3 - Level 40)
│   └── Skill Instructor (Tier 2 - Level 30)
│       └── Grand Master (Tier 3 - Level 40)
│
└── STRATEGIST PATH (Tier 1 - Level 20)
    ├── War Planner (Tier 2 - Level 30)
    │   └── Tactical Genius (Tier 3 - Level 40)
    └── Economic Planner (Tier 2 - Level 30)
        └── Tactical Genius (Tier 3 - Level 40)
```

**Scholar Specialization Details:**

| ID | Name | Tier | Requires | Bonuses | Research Boost |
|----|------|------|----------|---------|----------------|
| `scholar_researcher` | Researcher | 1 | Level 20, Scholar | +40% research speed, +20% tech unlock chance | Research +60% |
| `scholar_researcher_tech` | Tech Specialist | 2 | Level 30, Researcher | +60% tech research, unlock advanced techs | Tech Research +120% |
| `scholar_researcher_magic` | Magic Theorist | 2 | Level 30, Researcher | +60% magic research, unlock spells | Magic Research +120% |
| `scholar_researcher_sage` | Omniscient Sage | 3 | Level 40, (Tech or Magic) | +100% all research, instant minor research | All Research +200% |
| `scholar_explorer` | Explorer | 1 | Level 20, Scholar | +30% scouting range, +20% discovery chance | Scouting +60% |
| `scholar_explorer_cartographer` | Cartographer | 2 | Level 30, Explorer | +50% scouting, reveal hidden paths | Scouting +100%, Map Making |
| `scholar_explorer_archaeologist` | Archaeologist | 2 | Level 30, Explorer | +40% scouting, +60% artifact discovery | Scouting +80%, Artifact Finding +100% |
| `scholar_explorer_wanderer` | World Wanderer | 3 | Level 40, (Cartographer or Archaeologist) | +100% scouting, fast travel unlocked | Scouting +200%, Teleportation |
| `scholar_mentor` | Mentor | 1 | Level 20, Scholar | +30% XP for all gods in territory | Training +60% |
| `scholar_mentor_combat` | Combat Trainer | 2 | Level 30, Mentor | +50% XP, +20% combat stat gains | Combat Training +120% |
| `scholar_mentor_skill` | Skill Instructor | 2 | Level 30, Mentor | +60% XP, +20% skill gains | Skill Training +140% |
| `scholar_mentor_master` | Grand Master | 3 | Level 40, (Combat or Skill) | +100% XP, passive skill learning | All Training +200% |
| `scholar_strategist` | Strategist | 1 | Level 20, Scholar | +20% territory defense, predict attacks | Defense Planning +60% |
| `scholar_strategist_war` | War Planner | 2 | Level 30, Strategist | +40% defense, optimize army placement | War Planning +120% |
| `scholar_strategist_economic` | Economic Planner | 2 | Level 30, Strategist | +30% all resource production in territory | Economic Planning +100% |
| `scholar_strategist_genius` | Tactical Genius | 3 | Level 40, (War or Economic) | +60% defense, +50% production, perfect strategy | All Planning +200% |

---

### Support Specializations

```
SUPPORT (Base)
│
├── HEALER PATH (Tier 1 - Level 20)
│   ├── Life Cleric (Tier 2 - Level 30)
│   │   └── Divine Vessel (Tier 3 - Level 40)
│   └── Battle Medic (Tier 2 - Level 30)
│       └── Divine Vessel (Tier 3 - Level 40)
│
├── BUFFER PATH (Tier 1 - Level 20)
│   ├── Blessing Priest (Tier 2 - Level 30)
│   │   └── Exalted Herald (Tier 3 - Level 40)
│   └── War Chanter (Tier 2 - Level 30)
│       └── Exalted Herald (Tier 3 - Level 40)
│
├── PROTECTOR PATH (Tier 1 - Level 20)
│   ├── Shield Bearer (Tier 2 - Level 30)
│   │   └── Aegis Incarnate (Tier 3 - Level 40)
│   └── Ward Master (Tier 2 - Level 30)
│       └── Aegis Incarnate (Tier 3 - Level 40)
│
└── LEADER PATH (Tier 1 - Level 20)
    ├── Overseer (Tier 2 - Level 30)
    │   └── Divine Sovereign (Tier 3 - Level 40)
    └── Diplomat (Tier 2 - Level 30)
        └── Divine Sovereign (Tier 3 - Level 40)
```

**Support Specialization Details:**

| ID | Name | Tier | Requires | Bonuses | Support Boost |
|----|------|------|----------|---------|---------------|
| `support_healer` | Healer | 1 | Level 20, Support | +40% healing power, AoE heals | Healing +60% |
| `support_healer_life` | Life Cleric | 2 | Level 30, Healer | +70% healing, remove debuffs | Healing +120%, Cleanse |
| `support_healer_battle` | Battle Medic | 2 | Level 30, Healer | +60% healing, heal on attack | Healing +100%, Combat Healing |
| `support_healer_divine` | Divine Vessel | 3 | Level 40, (Life or Battle) | +120% healing, resurrection | Healing +200%, Revive |
| `support_buffer` | Buffer | 1 | Level 20, Support | +30% buff duration, +20% buff power | Buffing +60% |
| `support_buffer_blessing` | Blessing Priest | 2 | Level 30, Buffer | +50% buff power, mass blessings | Buffing +120%, Mass Buffs |
| `support_buffer_chanter` | War Chanter | 2 | Level 30, Buffer | +60% combat buffs, songs persist | Combat Buffing +150% |
| `support_buffer_herald` | Exalted Herald | 3 | Level 40, (Blessing or Chanter) | +100% buff power, permanent buffs | Buffing +200%, Permanence |
| `support_protector` | Protector | 1 | Level 20, Support | +25% damage reduction to allies | Protection +60% |
| `support_protector_shield` | Shield Bearer | 2 | Level 30, Protector | +40% damage reduction, shield allies | Protection +120%, Shielding |
| `support_protector_ward` | Ward Master | 2 | Level 30, Protector | +50% magic resistance, dispel magic | Protection +100%, Magic Ward |
| `support_protector_aegis` | Aegis Incarnate | 3 | Level 40, (Shield or Ward) | +80% damage reduction, immunity zones | Protection +200%, Sanctuary |
| `support_leader` | Leader | 1 | Level 20, Support | +15% all ally efficiency in territory | Leadership +60% |
| `support_leader_overseer` | Overseer | 2 | Level 30, Leader | +25% ally efficiency, reduce task time | Leadership +120%, Time Reduction |
| `support_leader_diplomat` | Diplomat | 2 | Level 30, Leader | +20% ally efficiency, better trade rates | Leadership +100%, Trade Bonus +50% |
| `support_leader_sovereign` | Divine Sovereign | 3 | Level 40, (Overseer or Diplomat) | +50% ally efficiency, global buffs | Leadership +200%, Global Aura |

---

## Progression Requirements

### Level Requirements

| Tier | Minimum Level | Unlock Method |
|------|---------------|---------------|
| Base Role | 1 | Automatically assigned at creation |
| Tier 1 Specialization | 20 | Choose one path from base role |
| Tier 2 Specialization | 30 | Choose one branch from Tier 1 path |
| Tier 3 Specialization | 40 | Ultimate specialization (usually converges) |

### Resource Requirements

**Tier 1 Specialization (Level 20):**
- 10,000 Gold
- 50 Divine Essence
- Complete 1 role-specific quest

**Tier 2 Specialization (Level 30):**
- 50,000 Gold
- 200 Divine Essence
- 10 Specialization Tomes (craftable or shop)
- Complete 3 specialization quests

**Tier 3 Specialization (Level 40):**
- 200,000 Gold
- 1,000 Divine Essence
- 1 Legendary Specialization Scroll (rare drop or event reward)
- 50 Specialization Tomes
- Complete 10 master-level quests

### Respec System

**Rules:**
- Can respec specialization at any time
- Costs scale with tier (Tier 1: 5k gold, Tier 2: 25k gold, Tier 3: 100k gold)
- Resources spent on original specialization are NOT refunded
- Respec resets to base role, must re-choose path
- First respec per god is free (tutorial allowance)

---

## Stat Effects & Bonuses

### Combat Stat Modifiers

**Base Role Modifiers:**
```
Fighter:  +15% ATK, +10% DEF
Gatherer: +5% HP
Crafter:  +10% HP, +5% DEF
Scholar:  +10% SPD, +15% SP (skill points)
Support:  +15% HP, +10% SPD
```

**Specialization Tier Modifiers:**
- Tier 1: +10% to primary stat
- Tier 2: +20% to primary stat + secondary stat
- Tier 3: +40% to primary stat + secondary + tertiary

**Example: Fighter → Berserker → Raging Warrior → Avatar of Fury**
```
Base Fighter:    +15% ATK, +10% DEF
+ Berserker:     +15% ATK, -5% DEF, +25% Crit Damage
+ Raging Warrior: +25% ATK, -10% DEF, +40% Crit Damage
+ Avatar of Fury: +40% ATK, immune to CC
Final Total:     +95% ATK, -5% DEF, +65% Crit Damage, CC Immunity
```

---

## Task Efficiency System

### Efficiency Formula

```
final_efficiency = base_task_rate
                 * (1 + role_bonus)
                 * (1 + specialization_bonus)
                 * (1 + trait_bonus)
                 * (1 + god_level_bonus)
                 * (1 + territory_bonus)
                 * (1 + equipment_bonus)
```

### Example Calculation

**Task:** Mine Ore (base rate: 10 ore/hour)
**God:** Hephaestus (Level 35, Crafter → Forgemaster → Deep Miner)
**Traits:** Miner (+50% mining)
**Territory:** Mountain (Level 5, +20% mining)
**Equipment:** Mining Pick (+10% mining)

```
Calculation:
base = 10 ore/hour
role = Crafter role gives -10% gathering (not specialized for this)
spec = Deep Miner gives +90% mining
trait = Miner trait gives +50% mining
level = Level 35 gives +35% (1% per level)
territory = Mountain Level 5 gives +20%
equipment = Mining Pick gives +10%

final = 10 * (1 - 0.10) * (1 + 0.90) * (1 + 0.50) * (1 + 0.35) * (1 + 0.20) * (1 + 0.10)
      = 10 * 0.90 * 1.90 * 1.50 * 1.35 * 1.20 * 1.10
      = 10 * 3.71
      = 37.1 ore/hour
```

**Verdict:** Despite being a Crafter (normally -10% gathering), the Deep Miner specialization makes Hephaestus excellent at mining.

---

## Data Schemas

### Role JSON Schema

**File:** `data/roles.json`

```json
{
  "roles": {
    "fighter": {
      "id": "fighter",
      "name": "Fighter",
      "description": "Gods of war, battle, and conflict",
      "icon": "res://assets/icons/role_fighter.png",
      "stat_bonuses": {
        "attack_percent": 0.15,
        "defense_percent": 0.10
      },
      "task_bonuses": {
        "combat": 0.20,
        "defense": 0.20,
        "training": 0.15
      },
      "task_penalties": {
        "crafting": -0.10,
        "research": -0.05
      },
      "specialization_trees": ["berserker", "guardian", "tactician", "assassin"]
    },
    "gatherer": {
      "id": "gatherer",
      "name": "Gatherer",
      "description": "Gods of nature, harvest, and abundance",
      "icon": "res://assets/icons/role_gatherer.png",
      "stat_bonuses": {
        "hp_percent": 0.05
      },
      "task_bonuses": {
        "mining": 0.25,
        "harvesting": 0.25,
        "fishing": 0.25,
        "hunting": 0.25
      },
      "task_penalties": {
        "research": -0.10
      },
      "resource_bonuses": {
        "gather_yield_percent": 0.25,
        "rare_chance_percent": 0.10
      },
      "specialization_trees": ["miner", "fisher", "herbalist", "hunter"]
    },
    "crafter": {
      "id": "crafter",
      "name": "Crafter",
      "description": "Gods of creation, artifice, and craftsmanship",
      "icon": "res://assets/icons/role_crafter.png",
      "stat_bonuses": {
        "hp_percent": 0.10,
        "defense_percent": 0.05
      },
      "task_bonuses": {
        "forging": 0.30,
        "alchemy": 0.30,
        "enchanting": 0.30,
        "artifact_creation": 0.30
      },
      "task_penalties": {
        "gathering": -0.10
      },
      "crafting_bonuses": {
        "quality_percent": 0.30,
        "speed_percent": 0.20,
        "masterwork_chance": 0.05
      },
      "specialization_trees": ["forgemaster", "alchemist", "enchanter", "artificer"]
    },
    "scholar": {
      "id": "scholar",
      "name": "Scholar",
      "description": "Gods of wisdom, knowledge, and magic",
      "icon": "res://assets/icons/role_scholar.png",
      "stat_bonuses": {
        "speed_percent": 0.10,
        "skill_points_percent": 0.15
      },
      "task_bonuses": {
        "research": 0.40,
        "scouting": 0.30,
        "training": 0.25,
        "teaching": 0.35
      },
      "task_penalties": {
        "mining": -0.15,
        "harvesting": -0.15
      },
      "other_bonuses": {
        "xp_gain_percent": 0.25,
        "scouting_range_percent": 0.15
      },
      "specialization_trees": ["researcher", "explorer", "mentor", "strategist"]
    },
    "support": {
      "id": "support",
      "name": "Support",
      "description": "Gods of healing, protection, and leadership",
      "icon": "res://assets/icons/role_support.png",
      "stat_bonuses": {
        "hp_percent": 0.15,
        "speed_percent": 0.10
      },
      "task_bonuses": {
        "healing": 0.40,
        "buffing": 0.35,
        "leadership": 0.30
      },
      "task_penalties": {
        "gathering": -0.20,
        "crafting": -0.20
      },
      "aura_bonuses": {
        "ally_efficiency_percent": 0.15,
        "territory_defense_percent": 0.10
      },
      "specialization_trees": ["healer", "buffer", "protector", "leader"]
    }
  }
}
```

---

### Specialization JSON Schema

**File:** `data/specializations.json`

```json
{
  "specializations": {
    "fighter_berserker": {
      "id": "fighter_berserker",
      "name": "Berserker",
      "tier": 1,
      "role_required": "fighter",
      "level_required": 20,
      "parent_spec": null,
      "children_specs": ["fighter_berserker_raging", "fighter_berserker_blood"],
      "description": "Embrace primal fury and overwhelming offense",
      "icon": "res://assets/icons/spec_berserker.png",
      "costs": {
        "gold": 10000,
        "divine_essence": 50
      },
      "stat_bonuses": {
        "attack_percent": 0.15,
        "defense_percent": -0.05,
        "crit_damage_percent": 0.25
      },
      "ability_unlocked": {
        "id": "rage_strike",
        "name": "Rage Strike",
        "description": "Deal massive damage, scaling with missing HP"
      }
    },
    "gatherer_miner_gem": {
      "id": "gatherer_miner_gem",
      "name": "Gem Cutter",
      "tier": 2,
      "role_required": "gatherer",
      "level_required": 30,
      "parent_spec": "gatherer_miner",
      "children_specs": ["gatherer_miner_jeweler"],
      "description": "Master the art of gem extraction and cutting",
      "icon": "res://assets/icons/spec_gem_cutter.png",
      "costs": {
        "gold": 50000,
        "divine_essence": 200,
        "specialization_tomes": 10
      },
      "stat_bonuses": {
        "hp_percent": 0.10
      },
      "task_bonuses": {
        "mining": 0.70,
        "gem_cutting": 0.80
      },
      "resource_bonuses": {
        "gem_yield_percent": 0.50,
        "rare_gem_chance": 0.20
      },
      "quests_required": 3
    }
  }
}
```

---

### God Definition Update

**File:** `data/gods.json` (fields to add)

```json
{
  "gods": {
    "hephaestus": {
      "id": "hephaestus",
      "name": "Hephaestus",
      "pantheon": "greek",
      "tier": 4,
      "element": "fire",
      "default_role": "crafter",
      "role_affinities": {
        "crafter": 1.5,
        "gatherer": 1.2,
        "fighter": 0.8
      },
      "innate_traits": ["forgemaster", "miner"],
      "base_stats": { "hp": 5000, "attack": 250, "defense": 300, "speed": 80 },
      "skills": ["hammer_strike", "forge_blessing", "volcanic_eruption"]
    },
    "athena": {
      "id": "athena",
      "name": "Athena",
      "pantheon": "greek",
      "tier": 5,
      "element": "light",
      "default_role": "scholar",
      "role_affinities": {
        "scholar": 1.6,
        "fighter": 1.3,
        "support": 1.1
      },
      "innate_traits": ["strategist", "scholar"],
      "base_stats": { "hp": 4500, "attack": 280, "defense": 320, "speed": 110 },
      "skills": ["wisdom_strike", "divine_strategy", "aegis_protection"]
    }
  }
}
```

---

## Implementation Notes

### Critical Godot 4.5 Constraints

1. **Reserved Keywords:** NEVER use `var trait`, `var task`, `var spec` - these are reserved in GDScript
   - Use: `var god_trait`, `var current_task`, `var specialization_data`

2. **Static Factory Pattern:**
   ```gdscript
   # WRONG - will cause error in static methods
   static func create() -> GodRole:
       return GodRole.new()

   # CORRECT - use load().new() pattern
   static func from_dict(data: Dictionary) -> GodRole:
       var script = load("res://scripts/data/GodRole.gd")
       var instance = script.new()
       instance.id = data.get("id", "")
       return instance
   ```

3. **File Size Limits:** Keep all files under 500 lines. Split if needed:
   - `SpecializationManager.gd` might need split into:
     - `SpecializationLoader.gd` (handles JSON loading)
     - `SpecializationValidator.gd` (validates unlock requirements)
     - `SpecializationApplier.gd` (applies bonuses)

### Testing Strategy

**Unit Test Coverage Required:**
- All data classes: from_dict(), to_dict(), validation
- All managers: initialization, queries, bonus calculations
- Edge cases: null inputs, invalid IDs, missing prerequisites
- Save/load: round-trip serialization

**Integration Test Scenarios:**
- God reaches level 20, specializes, gains bonuses
- God with specialization performs task, efficiency calculated correctly
- Specialization tree navigation (parent → child relationships)
- Respec functionality preserves god state

### Performance Considerations

**Optimization Points:**
- Cache specialization bonus calculations (recalculate only on level up or respec)
- Index specializations by role for fast lookup
- Pre-calculate specialization trees at startup (one-time cost)
- Store flattened bonus totals on God instance (avoid repeated tree traversal)

### UI/UX Design Notes

**Specialization Tree Display:**
- Use vertical tree layout (top = base role, bottom = tier 3)
- Locked nodes: grayscale + lock icon
- Available nodes: golden glow + "Available" badge
- Current node: bright highlight + checkmark
- Connection lines: show progression path

**Color Coding:**
- Fighter: Red
- Gatherer: Green
- Crafter: Orange
- Scholar: Blue
- Support: Purple

---

## Total Specialization Count

**Summary:**
- 5 Base Roles
- Fighter: 16 specializations (4 paths × 4 nodes each)
- Gatherer: 20 specializations (4 paths × 5 nodes each)
- Crafter: 16 specializations (4 paths × 4 nodes each)
- Scholar: 16 specializations (4 paths × 4 nodes each)
- Support: 16 specializations (4 paths × 4 nodes each)

**Total Specialization Nodes:** 84 unique specializations

**Total System Size:**
- 5 Roles
- 84 Specializations
- 20 Specialization Trees (4 per role)
- 3 Tiers per tree
- ~250 unique bonuses and abilities

---

## Future Expansion Possibilities

1. **Cross-Class Specializations** (Level 50+): Hybrid paths combining two roles
2. **Pantheon-Specific Specializations**: Unique paths for Greek vs Norse gods
3. **Legendary Specializations**: Ultra-rare paths unlocked by special items
4. **Seasonal Specializations**: Limited-time event specializations
5. **Prestige System**: Reset specializations for permanent bonuses

---

**Document Complete - Ready for Implementation**
