# Analytics Setup Guide

## Overview

Smyte uses Firebase Firestore for analytics with a **flat event structure** optimized for BigQuery/Tableau export.

## Event Structure (BigQuery-Friendly)

Events are stored in `analytics_flat` collection with a **clean flat schema** - no prefixes, all params at top level:

| Field | Type | Description |
|-------|------|-------------|
| `event_name` | string | Event type (e.g., "battle_completed", "summon_performed") |
| `timestamp` | integer | Unix timestamp |
| `date` | string | YYYY-MM-DD (for partitioning) |
| `user_id` | string | User identifier |
| `session_id` | string | Session UUID |
| `platform` | string | OS (Windows, Android, iOS, Web) |
| `*` | various | All event params directly at top level (no prefix) |

### Example Flat Event Document

```json
{
  "event_name": "battle_completed",
  "timestamp": 1739712000,
  "date": "2025-02-16",
  "user_id": "user_abc123",
  "session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "platform": "Windows",
  "victory": true,
  "battle_type": "dungeon",
  "duration": 45.2,
  "team_power": 12500,
  "dungeon_id": "fire_sanctum",
  "difficulty": "advanced"
}
```

## Setting Up BigQuery Export

### Option 1: Firebase Extension (Recommended)

1. Go to Firebase Console → Extensions
2. Install "Stream Firestore to BigQuery" extension
3. Configure:
   - Collection: `analytics_flat`
   - BigQuery dataset: `smyte_analytics`
   - Partitioning: `event_date` (YYYY-MM-DD)

This creates a BigQuery table that auto-syncs with Firestore.

### Option 2: Manual Export

Use `gcloud` CLI for one-time exports:

```bash
gcloud firestore export gs://your-bucket/analytics-export \
  --collection-ids=analytics_flat
```

Then import to BigQuery:

```bash
bq load --source_format=FIRESTORE_EXPORT \
  smyte_analytics.events \
  gs://your-bucket/analytics-export/analytics_flat
```

## Connecting Tableau

### BigQuery Connection

1. In Tableau Desktop → Connect → Google BigQuery
2. Sign in with Google account
3. Select project → `smyte_analytics` dataset → `analytics_flat` table

### Recommended Calculated Fields

```
// Daily Active Users
COUNTD(IF [event_name] = "session_start" THEN [user_id] END)

// Average Session Duration
AVG(IF [event_name] = "session_end" THEN [session_duration_seconds] END)

// Battle Win Rate
SUM(IF [event_name] = "battle_completed" AND [victory] = true THEN 1 ELSE 0 END) /
COUNT(IF [event_name] = "battle_completed" THEN 1 END)

// Summon Legendary Rate
SUM([legendary_count]) / SUM([results_count])
```

## Key Events for Dashboards

### Engagement KPIs
- `session_start` / `session_end` - Session tracking
- `daily_login` - Retention analysis
- `screen_view` - Feature navigation
- `feature_engagement` - Time spent per feature

### Economy KPIs
- `resource_transaction` - All resource changes
- `currency_balance` - Periodic snapshots
- `summon_performed` - Gacha spending
- `equipment_crafted` - Material sinks

### Battle KPIs
- `battle_completed` - Win/loss rates
- `battle_stats` - Detailed combat metrics
- `god_usage` - Character balance data
- `tower_progress` - Progression tracking

### Progression KPIs
- `god_obtained` - Collection growth
- `god_leveled` - Leveling velocity
- `player_progression` - Periodic snapshots
- `achievement_completed` - Milestone tracking

## Event Reference

### battle_stats
Detailed combat data for balance analysis:
```
battle_type, difficulty, victory, turns_taken,
damage_dealt, damage_received, gods_died, enemy_count
```

### god_usage
Per-god performance tracking:
```
god_id, god_tier, god_element, battle_type,
damage_dealt, damage_received, kills, died
```

### player_progression
Periodic player state snapshots:
```
player_level, total_gods, total_power,
total_battles, playtime_hours
```

### funnel_step
Conversion funnel tracking:
```
funnel_name, step_name, step_index
```

## Testing Analytics

In GDScript:
```gdscript
var analytics = SystemRegistry.get_system("FirebaseAnalytics")

# Log a test event
analytics.log_event("test_event", {"test_param": "value"})

# Force flush to Firestore
await analytics.flush_queue()

# Check pending count
print("Pending events: ", analytics.get_pending_event_count())
```

## Firestore Rules

Ensure analytics collection has write access:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /analytics_flat/{eventId} {
      allow write: if request.auth != null;
      allow read: if false; // Server-side only
    }
  }
}
```
