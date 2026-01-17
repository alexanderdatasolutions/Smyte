# Smyte - Dungeon Replayability & Gacha Incentive Design

**Version**: 1.0.0
**Last Updated**: 2026-01-16

---

## Design Philosophy

> **Goal:** Make players WANT to run dungeons repeatedly AND summon better gods to clear higher difficulties faster/safer.

**Core Loop:**
```
Run Dungeon → Get Loot → Enhance Equipment/Level Gods → Run Harder Dungeons → Want Better Gods → Summon → Repeat
```

---

## Table of Contents

1. [Dungeon Types & Purpose](#dungeon-types--purpose)
2. [Difficulty Scaling](#difficulty-scaling)
3. [Loot Tables & Drop Rates](#loot-tables--drop-rates)
4. [Replayability Mechanics](#replayability-mechanics)
5. [Gacha Incentives](#gacha-incentives)
6. [Daily/Weekly Systems](#dailyweekly-systems)
7. [Progression Gates](#progression-gates)
8. [Optimization Strategies](#optimization-strategies)

---

## Dungeon Types & Purpose

### 1. Elemental Sanctums (6 Types)

**Purpose:** Farm awakening materials (element-specific essences)

| Sanctum | Element | Day Available | Key Drop |
|---------|---------|---------------|----------|
| Fire Sanctum | Fire (0) | Monday | Fire Essence (Low/Mid/High) |
| Water Sanctum | Water (1) | Tuesday | Water Essence (Low/Mid/High) |
| Earth Sanctum | Earth (2) | Wednesday | Earth Essence (Low/Mid/High) |
| Lightning Sanctum | Lightning (3) | Thursday | Lightning Essence (Low/Mid/High) |
| Light Sanctum | Light (4) | Friday | Light Essence (Low/Mid/High) |
| Dark Sanctum | Dark (5) | Saturday | Dark Essence (Low/Mid/High) |

**Why Players Farm:**
- Awakening gods requires 20 High + 10 Mid + 5 Low essences (same element)
- Awakened gods get +10 levels, new skills, and stat boost
- **Gacha Hook:** Need specific element gods to awaken → summon for Zeus (Lightning) → farm Thursday dungeon

### 2. Equipment Dungeons (3 Types)

**Purpose:** Farm specific equipment types and crafting materials

| Dungeon | Primary Drop | Always Available |
|---------|--------------|------------------|
| Titan's Forge | Weapons, Armor | ✓ |
| Valhalla's Armory | Helmets, Gloves | ✓ |
| Oracle Sanctum | Boots, Accessories | ✓ |

**Why Players Farm:**
- Need 6 equipment pieces per god (24 gods in collection = 144 pieces needed)
- Looking for perfect main stats + substats
- Enhancement materials (powder, flames, crystals)
- **Gacha Hook:** Better gods deserve better equipment → farm more → want more gods → summon

### 3. Pantheon Trials (8 Pantheons)

**Purpose:** Weekend challenge content with premium rewards

| Trial | Schedule | Reward Focus |
|-------|----------|--------------|
| Greek Trials | Saturday | Divine Essence, Legendary gear |
| Norse Trials | Saturday | Awakening Stones, Skill Books |
| Egyptian Trials | Sunday | Divine Essence, Legendary gear |
| Hindu Trials | Sunday | Awakening Stones, Skill Books |
| Japanese Trials | Rotating weekends | Mixed rewards |
| Celtic Trials | Rotating weekends | Mixed rewards |
| Aztec Trials | Rotating weekends | Mixed rewards |
| Slavic Trials | Rotating weekends | Mixed rewards |

**Why Players Farm:**
- Best loot per energy (15-20 energy cost but huge rewards)
- Time-limited (weekends only)
- Bragging rights (leaderboards)
- **Gacha Hook:** Trials are HARD → need strong teams → summon legendary gods

### 4. Hall of Magic (Special)

**Purpose:** Universal essence farming (any element)

- Always available
- Higher energy cost (10-18 energy)
- Drops all essence types randomly
- Good for "topping off" essence needs

---

## Difficulty Scaling

### Energy Costs

| Difficulty | Energy Cost | Recommended Level |
|------------|-------------|-------------------|
| **Beginner** | 8 | 10-15 |
| **Intermediate** | 10 | 20-30 |
| **Advanced** | 12 | 35-45 |
| **Expert** | 15 | 50+ |
| **Master** | 18 | 60+ (future) |

### Enemy Scaling

**Beginner:**
- 3 waves
- Basic enemies (level 10-15)
- 1 leader or elite as boss

**Intermediate:**
- 3 waves
- Mix of basic + leader enemies (level 20-25)
- Elite as final boss

**Advanced:**
- 3 waves
- Leader + elite enemies (level 35-40)
- Elite boss with higher stats

**Expert:**
- 3 waves
- Elite enemies throughout (level 50-55)
- Boss-tier final enemy with mechanics

**Master (Future):**
- 4 waves
- Multiple bosses
- Phase transitions
- Requires perfect team composition

### Clear Time Targets

| Difficulty | Target Time | Speed Clear | Slow Clear |
|------------|-------------|-------------|------------|
| Beginner | 90s | <60s | >120s |
| Intermediate | 120s | <90s | >180s |
| Advanced | 180s | <120s | >240s |
| Expert | 240s | <180s | >300s |

**Why This Matters:**
- Energy regenerates at 1 per 5 minutes (12/hour, 288/day)
- Faster clears = more runs per day = more loot
- **Gacha Hook:** Better gods clear faster → want to optimize → summon for god with AOE skills

---

## Loot Tables & Drop Rates

### Guaranteed Drops (100% chance)

**Elemental Sanctums:**
| Difficulty | Guaranteed Drops |
|------------|------------------|
| Beginner | 1x Low Essence, 1x Mid Mana, 1x Low Magic Powder |
| Intermediate | 1x Low Essence, 1x Mid Essence, 1x Mid Mana |
| Advanced | 1x Mid Essence, 1x Low Essence, 1x Large Mana |
| Expert | 1x High Essence, 1x Large Mana, 1x Element Soul |

**Equipment Dungeons:**
| Difficulty | Guaranteed Drops |
|------------|------------------|
| Beginner | 1x Equipment (Rare), 1x Common Ore, 1x Mid Mana |
| Intermediate | 1x Equipment (Rare/Epic), 1x Rare Ore, 1x Large Mana |
| Advanced | 1x Equipment (Epic/Legendary), 1x Legendary Ore, 1x Enhancement Powder |

### Rare Drops (RNG-based)

**Elemental Sanctums (Expert Difficulty):**
- Awakening Stone: 30% chance
- Divine Crystals (8-20): 20% chance
- Legendary Ore: 5% chance

**Equipment Dungeons (Advanced Difficulty):**
- Socket Crystal: 25% chance
- Forging Flame: 15% chance
- Divine Crystals (8-20): 30% chance
- Divine Essence: 10% chance

**Pantheon Trials (Legendary Difficulty):**
- Divine Essence: 50% chance
- Legendary Soul: 100% (guaranteed)
- Skill Book: 100% (guaranteed)
- Equipment Drop: 70% chance
- Legendary Ore: 30% chance

### Expected Runs for Key Materials

**To Awaken 1 God (Same Element):**
- Need: 20 High + 10 Mid + 5 Low essences
- Expert runs guarantee: 1 High per run
- Expected runs: ~25-30 runs (accounting for Mid/Low drops)
- Energy cost: 25 * 15 = 375 energy
- Real-time: ~31 hours of energy regen (~1.3 days)

**To Get +15 Equipment Set (6 pieces):**
- Need: ~120,000 mana + enhancement powders
- Advanced dungeon gives: ~3,000 mana + 1 powder per run
- Expected runs for mana: 40 runs
- Expected runs for powders: 20-30 runs
- Energy cost: ~480 energy (~40 hours / 1.7 days)

### Drop Rate Scaling by Account Level

**Early Game Boost (Level 1-20):**
- +50% drop rate on common materials
- +25% equipment drop rate
- Helps new players gear up fast

**Mid Game (Level 21-40):**
- Normal drop rates
- Focus shifts to quality (substats) not quantity

**Late Game (Level 40+):**
- +10% rare drop rate
- +20% divine crystal drop rate
- Rewards veterans with premium currency

---

## Replayability Mechanics

### 1. Substat Hunting (Equipment RNG)

**The Hook:** Equipment can roll any substat combination.

**Example:** Need SPD boots with ATK% and Crit Rate% substats
- Boots drop: 100% chance
- Main stat SPD: 16.7% chance (1/6 main stats)
- Substat 1 ATK%: ~12.5% chance (1/8 substats)
- Substat 2 Crit Rate%: ~12.5% chance
- **Combined Probability:** 0.26% per run

**Result:** Players run hundreds of times for "perfect" gear.

### 2. Enhancement RNG

**The Hook:** Enhancement has failure chance at high levels.

- +10 → +11: 50% success rate
- +11 → +12: 45% success rate
- +12 → +13: 40% success rate
- +13 → +14: 35% success rate
- +14 → +15: 30% success rate

**Average Attempts to +15:**
- From +10: ~7.5 attempts
- Total mana cost: ~180,000 (including failures)
- Total powder cost: 15-20 pieces

**Result:** Always need more enhancement materials → run more dungeons.

### 3. Multiple God Collection

**The Hook:** 24+ gods to collect, each needs:
- 6 equipment pieces (144 total)
- Awakening materials
- Leveling fodder

**Building 1 God:**
- Level 1 → 40: ~1,557,835 XP
- Awakening: ~375 energy (31 hours)
- Equipment: ~480 energy (40 hours)
- **Total:** ~855 energy (~71 hours / 3 days)

**Building Full Team of 4:**
- ~3,420 energy (~285 hours / ~12 days of energy)

**Result:** Always working on next god → always farming.

### 4. Element-Specific Content

**The Hook:** Daily rotation forces specific farming days.

**Example Player:**
- Summons Zeus (Lightning) on Wednesday
- Lightning Sanctum is Thursday
- Must wait 1 day to farm essences
- Creates anticipation and login habit

**Schedule Optimization:**
- Monday: Farm Fire essences for Ares
- Tuesday: Farm Water essences for Poseidon
- Wednesday: Farm Earth essences for Gaia
- Thursday: Farm Lightning essences for Zeus
- Friday: Farm Light essences for Athena
- Saturday: Greek Trials + Dark essences
- Sunday: Egyptian Trials

**Result:** Players log in daily to maximize energy efficiency.

### 5. Progressive Difficulty Unlocks

**The Hook:** Higher difficulties give better rewards per energy.

| Difficulty | Mana/Energy | Essence/Energy | Premium Currency |
|------------|-------------|----------------|------------------|
| Beginner (8E) | 62.5 | 0.125 High equiv | 0.025 crystals |
| Intermediate (10E) | 100 | 0.15 High equiv | 0.03 crystals |
| Advanced (12E) | 125 | 0.2 High equiv | 0.042 crystals |
| Expert (15E) | 200 | 0.33 High equiv | 0.067 crystals |

**Efficiency Difference:**
- Expert is 3.2x more efficient than Beginner
- **BUT** Expert requires level 50+ gods with good gear

**Result:** Players push to unlock harder difficulties → need better gods → summon.

---

## Gacha Incentives

### Why Players Want Better Gods

#### 1. **Clear Speed = More Runs Per Day**

**Scenario:** Player has 150 energy to spend.

**With Bad Gods (Tier 1, level 30, no gear):**
- Can only clear Beginner difficulty
- Takes 180 seconds per run
- 150 energy / 8 per run = 18.75 runs
- Total time: 56.25 minutes
- Loot: Minimal essences, low mana

**With Good Gods (Tier 4, level 40, +12 gear):**
- Can clear Expert difficulty in 120 seconds
- 150 energy / 15 per run = 10 runs
- Total time: 20 minutes
- Loot: 3x more valuable per energy

**Value:** Save 36 minutes AND get better loot.

#### 2. **Element Advantage Matters**

**Summoners War-style Element System:**
- Fire > Earth > Water > Fire
- Light <-> Dark (counter each other)
- Lightning = Neutral

**Damage Bonuses:**
- Advantage: +30% damage, +15% crit rate
- Disadvantage: -30% damage, -15% crit rate

**Example:**
- Lightning Sanctum has Lightning enemies
- Bringing Earth gods = 30% more damage
- Bringing Water gods = 30% less damage

**Result:** Players want full elemental coverage → summon for missing elements.

#### 3. **AOE vs Single Target**

**Wave Clear Efficiency:**

**Single-Target God (e.g., Ares - Tier 1 Fighter):**
- Skill 1: Attacks 1 enemy
- Skill 2: Attacks 1 enemy (2x damage)
- Total wave clear: Kill 1 → Kill 1 → Kill 1 (3 turns)

**AOE God (e.g., Zeus - Tier 4 Fighter/Support):**
- Skill 1: Attacks 1 enemy
- Skill 2: AOE Lightning Strike (hits all 3 enemies)
- Total wave clear: AOE kills all or weakens → cleanup (1.5 turns)

**Time Difference:**
- Single target: 180 seconds
- AOE: 90 seconds (2x faster)

**Result:** Players REALLY want AOE gods for farming → summon for Zeus, Poseidon, etc.

#### 4. **Leader Skills**

**Zeus Leader Skill:** +33% SPD to all allies
**Effect:**
- Team SPD: 200 → 266 (with Zeus leader)
- Turn frequency: +33% more actions
- Clear time: Reduced by ~25%

**Without Zeus:**
- 3 min per run * 10 runs = 30 minutes

**With Zeus Leader:**
- 2.25 min per run * 10 runs = 22.5 minutes

**Value:** Save 7.5 minutes per energy bar.

**Result:** Players want gods with strong leader skills → summon legendary gods.

#### 5. **Skill Cooldown Reduction**

**Low-Tier God (Ares):**
- Skill 2: 4-turn cooldown
- Uses powerful skill every 5 turns (action + 4 turns wait)

**High-Tier God (Zeus):**
- Skill 2: 3-turn cooldown
- Uses powerful skill every 4 turns
- 25% more skill usage over time

**Result:** Better gods = more damage = faster clears → summon.

---

## Daily/Weekly Systems

### Energy Management

**Energy Regeneration:**
- Base: 1 energy per 5 minutes
- Daily: 288 energy regenerated (if never capped)
- Cap: 150 energy storage

**Energy Refresh:**
- Cost: 100 divine crystals (premium currency)
- Grants: +150 energy
- Daily limit: 3 refreshes
- Total possible energy/day: 288 + (3 * 150) = 738 energy

### Daily Missions

**Example Daily Dungeon Missions:**
1. "Complete any dungeon 5 times" → Reward: 50 mana, 5 divine crystals
2. "Complete Expert difficulty 1 time" → Reward: 100 mana, 10 divine crystals
3. "Farm 10 essences" → Reward: 1 awakening stone

**Weekly Missions:**
1. "Complete 50 dungeon runs" → Reward: 500 mana, 100 divine crystals
2. "Complete 5 Pantheon Trials" → Reward: 1 legendary soul, 50 divine crystals
3. "Enhance equipment 20 times" → Reward: 5 enhancement powders, 20 divine crystals

### Weekend Events

**2x Drop Rate Weekends:**
- All dungeons drop 2x essences
- Creates urgency → players spend more energy
- Good for catching up on awakening materials

**Half Energy Weekends:**
- All dungeons cost 50% energy
- Double efficiency → players run more
- Good for farming equipment

---

## Progression Gates

### Dungeon Unlock Requirements

| Dungeon Category | Player Level | Other Requirements |
|------------------|--------------|---------------------|
| Elemental Sanctums | 10 | Tutorial: Awakening Basics |
| Special Sanctums | 15 | None |
| Pantheon Trials | 25 | 3 territories completed |
| Equipment Dungeons | 20 | None |

### Difficulty Unlock Requirements

**Elemental Sanctums:**
- Beginner: Available at unlock (level 10)
- Intermediate: Clear Beginner 3 times
- Advanced: Clear Intermediate 5 times + player level 30
- Expert: Clear Advanced 5 times + player level 45

**Pantheon Trials:**
- Heroic: Player level 25
- Legendary: Player level 40 + clear Heroic 3 times

**Equipment Dungeons:**
- Beginner: Player level 20
- Intermediate: Player level 30
- Advanced: Player level 40

---

## Optimization Strategies

### Farming Efficiency

**Goal:** Maximize loot per hour of playtime.

**Strategy 1: Speed Teams**
- 4 AOE DPS gods
- All with 250+ speed
- Clear Expert in <90 seconds
- 10 runs in 15 minutes

**Strategy 2: Safe Teams**
- 1 Tank, 2 DPS, 1 Healer
- Slower but 100% success rate
- Clear Expert in 180 seconds
- 10 runs in 30 minutes

**Trade-off:**
- Speed team: High gear requirement, occasional failures
- Safe team: Lower gear requirement, never fails

**Gacha Hook:** Want speed team → need multiple strong DPS gods → summon.

### Essence Farming Priority

**New Player:**
1. Farm for first awakening (any god)
2. Use awakened god to farm faster
3. Farm for second awakening
4. Repeat

**Mid-Game Player:**
1. Focus on one element per week
2. Awaken full team of 4 (same element)
3. Use awakened team for territory capture

**Late-Game Player:**
1. Farm essences on daily rotation
2. Stockpile for future summons
3. Always have 20 High essences of each element ready

### Equipment Farming Priority

**Phase 1: Get ANY equipment (all slots filled)**
- Farm Beginner/Intermediate
- Don't care about substats
- Just need +6 to +9 gear for basic stats

**Phase 2: Get GOOD equipment (correct main stats)**
- Farm Advanced
- Target: SPD boots, ATK% gloves, HP% helmets
- Ignore substats for now

**Phase 3: Get PERFECT equipment (main + substats)**
- Farm Expert exclusively
- Looking for: SPD boots with ATK% + Crit Rate% + Crit Damage%
- This is endgame (100+ runs per perfect piece)

**Gacha Hook:**
- Phase 1 → Phase 2: Need better gods to clear Advanced → summon
- Phase 2 → Phase 3: Need better gods to clear Expert → summon

---

## Summary: Why Players Keep Playing

✅ **Short-Term Loop (Daily):**
- Log in → Spend 288 energy → Farm elemental dungeon of the day → Make incremental progress

✅ **Medium-Term Loop (Weekly):**
- Complete daily missions → Get divine crystals → Save for summons → Pull on weekend → Get new god → NEED TO GEAR THEM → Farm dungeons

✅ **Long-Term Loop (Months):**
- Build full collection → Awaken all gods → Optimize equipment → Push for perfect substats → Compete on leaderboards

✅ **Gacha Hooks:**
1. **AOE gods clear faster** → Want Zeus → Summon
2. **Element coverage** → Missing Earth gods → Summon
3. **Leader skills** → Want +33% SPD → Summon for Zeus
4. **Skill cooldowns** → Tier 4 gods have better skills → Summon
5. **Speed tuning** → Need multiple 250+ SPD gods → Summon
6. **New content** → New dungeon requires Light gods → Summon

✅ **Replayability Drivers:**
1. **Substat RNG** → 0.26% for perfect gear → 100+ runs per piece
2. **Enhancement RNG** → 30% success rate at +15 → Always need more materials
3. **24+ gods to build** → 3 days per god → Always working on someone
4. **Daily rotation** → Different dungeon each day → Log in daily
5. **Efficiency gains** → Expert is 3.2x better than Beginner → Push for harder difficulties

---

*This system ensures players always have something to farm, always want better gods, and always have a reason to come back tomorrow.*
