import json
import os

# Path to the awakened gods file
file_path = r"c:\Users\alexa\Documents\Coding\Smyte\new-game-project\data\awakened_gods.json"

# Create backup first
backup_path = file_path + ".backup"
print(f"Creating backup at: {backup_path}")

# Read the original file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Create backup
with open(backup_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Backup created successfully!")

# Replace all instances of _essences_ with _powder_
updated_content = content.replace('_essences_', '_powder_')

# Count how many replacements were made
original_count = content.count('_essences_')
print(f"Found {original_count} instances of '_essences_' to replace")

# Write the updated content back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(updated_content)

print("✅ Successfully updated all awakening materials from '_essences_' to '_powder_'!")
print(f"Updated {original_count} material references")
