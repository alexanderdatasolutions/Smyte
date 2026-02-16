#!/usr/bin/env python3
"""
Smyte Analytics - BigQuery Data Fetcher
Pulls analytics data from BigQuery and outputs JSON for the dashboard.

Usage:
    pip install google-cloud-bigquery
    python fetch_bigquery.py

Set your project ID below or use GOOGLE_CLOUD_PROJECT env var.
"""

import json
import os
from datetime import datetime, timedelta

# pip install google-cloud-bigquery
from google.cloud import bigquery

# ============================================================================
# CONFIGURATION - EDIT THESE
# ============================================================================

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "your-project-id")
DATASET = "analytics_events"  # or "analytics_XXXXXX" for Firebase export
OUTPUT_FILE = "analytics_data.json"

# Date range (last N days)
DAYS_BACK = 30

# ============================================================================
# QUERIES - Customize these for your schema
# ============================================================================

# If using Firebase Analytics BigQuery export (events_* tables)
FIREBASE_QUERY = """
SELECT
    event_name as name,
    event_timestamp / 1000000 as timestamp,
    user_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') as session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'banner_id') as banner_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'summon_type') as summon_type,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'gods_count') as gods_count,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'legendary_count') as legendary_count,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'epic_count') as epic_count,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'battle_type') as battle_type,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'team_power') as team_power,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'enemy_power') as enemy_power,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'old_elo') as old_elo,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'new_elo') as new_elo,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'elo_change') as elo_change,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'league') as league,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'victory') as victory,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'god_id') as god_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'total_xp') as total_xp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'material_count') as material_count,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'achievement_id') as achievement_id
FROM `{project}.{dataset}.events_*`
WHERE _TABLE_SUFFIX BETWEEN
    FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL {days} DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
ORDER BY event_timestamp DESC
LIMIT 10000
"""

# If using custom Firestore export / custom schema
CUSTOM_QUERY = """
SELECT
    name,
    timestamp,
    JSON_EXTRACT_SCALAR(params, '$.user_id') as user_id,
    JSON_EXTRACT_SCALAR(params, '$.session_id') as session_id,
    params
FROM `{project}.{dataset}.analytics_events`
WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {days} DAY)
ORDER BY timestamp DESC
LIMIT 10000
"""

# Raw query - just get everything
RAW_QUERY = """
SELECT *
FROM `{project}.{dataset}.analytics_events`
WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {days} DAY)
ORDER BY timestamp DESC
LIMIT 10000
"""


def fetch_firebase_analytics(client, project, dataset, days):
    """Fetch from Firebase Analytics BigQuery export"""
    query = FIREBASE_QUERY.format(project=project, dataset=dataset, days=days)
    print(f"Running Firebase Analytics query...")

    results = client.query(query).result()
    events = []

    for row in results:
        event = {
            "name": row.name,
            "timestamp": float(row.timestamp) if row.timestamp else 0,
            "params": {
                "user_id": row.user_id,
                "session_id": row.session_id,
            }
        }

        # Add non-null params
        for field in ['banner_id', 'summon_type', 'gods_count', 'legendary_count',
                      'epic_count', 'battle_type', 'team_power', 'enemy_power',
                      'old_elo', 'new_elo', 'elo_change', 'league', 'victory',
                      'god_id', 'total_xp', 'material_count', 'achievement_id']:
            val = getattr(row, field, None)
            if val is not None:
                event["params"][field] = val

        events.append(event)

    return events


def fetch_custom_analytics(client, project, dataset, days):
    """Fetch from custom analytics table"""
    query = CUSTOM_QUERY.format(project=project, dataset=dataset, days=days)
    print(f"Running custom analytics query...")

    results = client.query(query).result()
    events = []

    for row in results:
        event = {
            "name": row.name,
            "timestamp": row.timestamp.timestamp() if row.timestamp else 0,
            "params": json.loads(row.params) if row.params else {}
        }
        events.append(event)

    return events


def fetch_raw(client, project, dataset, days):
    """Fetch raw data - you'll need to adapt the output"""
    query = RAW_QUERY.format(project=project, dataset=dataset, days=days)
    print(f"Running raw query...")

    results = client.query(query).result()
    events = []

    for row in results:
        # Convert row to dict
        event = dict(row.items())
        # Handle datetime serialization
        for k, v in event.items():
            if hasattr(v, 'timestamp'):
                event[k] = v.timestamp()
        events.append(event)

    return events


def list_tables(client, project, dataset):
    """List available tables in the dataset"""
    print(f"\nAvailable tables in {project}.{dataset}:")
    try:
        tables = client.list_tables(f"{project}.{dataset}")
        for table in tables:
            print(f"  - {table.table_id}")
    except Exception as e:
        print(f"  Error listing tables: {e}")


def main():
    print("=" * 60)
    print("Smyte Analytics - BigQuery Data Fetcher")
    print("=" * 60)

    # Initialize client
    client = bigquery.Client(project=PROJECT_ID)
    print(f"Project: {PROJECT_ID}")
    print(f"Dataset: {DATASET}")
    print(f"Days back: {DAYS_BACK}")

    # List available tables
    list_tables(client, PROJECT_ID, DATASET)

    # Try different query methods
    events = None

    # Method 1: Try Firebase Analytics format
    try:
        events = fetch_firebase_analytics(client, PROJECT_ID, DATASET, DAYS_BACK)
        print(f"Fetched {len(events)} events (Firebase format)")
    except Exception as e:
        print(f"Firebase format failed: {e}")

    # Method 2: Try custom format
    if not events:
        try:
            events = fetch_custom_analytics(client, PROJECT_ID, DATASET, DAYS_BACK)
            print(f"Fetched {len(events)} events (custom format)")
        except Exception as e:
            print(f"Custom format failed: {e}")

    # Method 3: Try raw
    if not events:
        try:
            events = fetch_raw(client, PROJECT_ID, DATASET, DAYS_BACK)
            print(f"Fetched {len(events)} events (raw format)")
        except Exception as e:
            print(f"Raw format failed: {e}")

    if events:
        # Write to file
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(events, f, indent=2)
        print(f"\nWrote {len(events)} events to {OUTPUT_FILE}")
        print(f"Open analytics_dashboard.html and load this file!")
    else:
        print("\nNo data fetched. Check your configuration.")
        print("\nTroubleshooting:")
        print("1. Set PROJECT_ID to your GCP project")
        print("2. Set DATASET to your analytics dataset name")
        print("3. Make sure you have BigQuery permissions")
        print("4. Run: gcloud auth application-default login")


if __name__ == "__main__":
    main()
