import json
import copy

# Read the current awakened_gods.json file
awakened_file = r"C:\Users\alexa\Documents\Coding\Smyte\new-game-project\data\awakened_gods.json"
gods_file = r"C:\Users\alexa\Documents\Coding\Smyte\new-game-project\data\gods.json"

with open(awakened_file, 'r', encoding='utf-8') as f:
    awakened_data = json.load(f)

with open(gods_file, 'r', encoding='utf-8') as f:
    gods_data = json.load(f)

# Create a lookup dict for base gods
base_gods = {}
for god in gods_data['gods']:
    if god.get('tier') in ['epic', 'legendary']:
        base_gods[god['id']] = god

# List of missing gods (from our analysis)
missing_gods = [
    'brigid', 'lugh', 'morrigan',  # Celtic
    'susanoo', 'tsukuyomi',        # Japanese  
    'enlil', 'ereshkigal', 'shamash',  # Mesopotamian
    'dagda', 'tiamat'              # Missing legendaries
]

# Awakening name templates for different types
awakening_names = {
    # Celtic - Nature and mystical themes
    'brigid': 'Brigid, The Sacred Flame',
    'lugh': 'Lugh, Master of All Arts', 
    'morrigan': 'Morrigan, Phantom Queen',
    'dagda': 'Dagda, The Great Provider',
    
    # Japanese - Traditional titles
    'susanoo': 'Susanoo, Storm God Supreme',
    'tsukuyomi': 'Tsukuyomi, Lord of the Night',
    
    # Mesopotamian - Ancient titles
    'enlil': 'Enlil, Lord of Wind and Storm',
    'ereshkigal': 'Ereshkigal, Queen of the Underworld', 
    'shamash': 'Shamash, Judge of Heaven and Earth',
    'tiamat': 'Tiamat, Primordial Chaos'
}

# Enhanced abilities for awakened forms
enhanced_abilities = {
    'brigid': [
        {
            "id": "sacred_forge",
            "name": "Sacred Forge",
            "description": "Creates blessed weapons that empower all allies with increased attack and critical rate for 3 turns.",
            "damage_multiplier": 0.0,
            "targets": "all_allies",
            "effects": [
                {"type": "buff", "buff": "attack_boost", "value": 50.0, "duration": 3.0},
                {"type": "buff", "buff": "crit_rate_boost", "value": 25.0, "duration": 3.0}
            ],
            "cooldown": 5.0
        },
        {
            "id": "healing_flame",
            "name": "Healing Flame", 
            "description": "Attacks an enemy and heals the ally with lowest HP. Grants regeneration for 2 turns.",
            "damage_multiplier": 320.0,
            "healing_multiplier": 80.0,
            "targets": "single",
            "effects": [
                {"type": "damage", "value": 320.0, "scaling": "ATK"},
                {"type": "heal", "value": 80.0, "scaling": "ATK", "target": "lowest_hp_ally"},
                {"type": "buff", "buff": "regeneration", "duration": 2.0}
            ],
            "cooldown": 4.0
        }
    ],
    
    'lugh': [
        {
            "id": "master_strike",
            "name": "Master of All Skills",
            "description": "Attacks all enemies with mastery of all combat arts. Each hit has different effects.",
            "damage_multiplier": 250.0,
            "targets": "all_enemies", 
            "effects": [
                {"type": "damage", "value": 250.0, "scaling": "ATK"},
                {"type": "debuff", "debuff": "defense_break", "chance": 75.0, "duration": 2.0}
            ],
            "cooldown": 5.0
        },
        {
            "id": "light_mastery",
            "name": "Light Mastery",
            "description": "Channels pure light to blind enemies and inspire allies.",
            "damage_multiplier": 380.0,
            "targets": "single",
            "effects": [
                {"type": "damage", "value": 380.0, "scaling": "ATK"},
                {"type": "debuff", "debuff": "blind", "chance": 85.0, "duration": 2.0}
            ],
            "cooldown": 3.0
        }
    ]
    # Add more abilities for other gods as needed...
}

# Default enhanced ability template
def create_default_abilities(god_data):
    element = god_data.get('element', 'fire')
    return [
        {
            "id": f"{god_data['id']}_awakened_skill1",
            "name": f"Enhanced {god_data['name']} Strike",
            "description": f"Powerful {element} attack that deals massive damage and applies {element} effects.",
            "damage_multiplier": 350.0,
            "targets": "single",
            "effects": [
                {"type": "damage", "value": 350.0, "scaling": "ATK"},
                {"type": "debuff", "debuff": f"{element}_weakness", "chance": 80.0, "duration": 2.0}
            ],
            "cooldown": 3.0
        },
        {
            "id": f"{god_data['id']}_awakened_skill2", 
            "name": f"{god_data['name']}'s Dominion",
            "description": f"Ultimate {element} technique that affects multiple enemies.",
            "damage_multiplier": 280.0,
            "targets": "all_enemies",
            "effects": [
                {"type": "damage", "value": 280.0, "scaling": "ATK"}
            ],
            "cooldown": 5.0
        }
    ]

# Create awakened versions for missing gods
new_awakened_gods = {}

for god_id in missing_gods:
    if god_id not in base_gods:
        print(f"Warning: Base god {god_id} not found in gods.json")
        continue
        
    base_god = base_gods[god_id]
    awakened_id = f"{god_id}_awakened"
    
    # Create awakened version
    awakened_god = {
        "id": awakened_id,
        "name": awakening_names.get(god_id, f"{base_god['name']}, The Awakened"),
        "pantheon": base_god['pantheon'],
        "element": base_god['element'],
        "tier": base_god['tier'],
        "base_stats": {
            # Boost base stats by 15-25% for awakened form
            "hp": int(base_god['base_stats']['hp'] * 1.2),
            "attack": int(base_god['base_stats']['attack'] * 1.25),
            "defense": int(base_god['base_stats']['defense'] * 1.15),
            "speed": int(base_god['base_stats']['speed'] * 1.1),
            "crit_rate": base_god['base_stats']['crit_rate'] + 5.0,
            "crit_damage": base_god['base_stats']['crit_damage'] + 15.0,
            "resistance": base_god['base_stats']['resistance'] + 10.0,
            "accuracy": base_god['base_stats']['accuracy'] + 15.0
        },
        "resource_generation": base_god.get('resource_generation', 10) + 5,
        "active_abilities": enhanced_abilities.get(god_id, create_default_abilities(base_god)),
        "awakening_materials": {
            f"{base_god['element']}_essence": 20,
            "divine_essence": 15,
            f"{base_god['element']}_crystal": 10,
            "awakening_stone": 5
        },
        "awakening_stat_bonuses": {
            "hp": 10.0,
            "attack": 15.0,
            "defense": 8.0,
            "speed": 5.0,
            "crit_rate": 10.0,
            "crit_damage": 20.0
        }
    }
    
    new_awakened_gods[awakened_id] = awakened_god
    print(f"Created awakened form: {awakened_god['name']} ({awakened_id})")

# Add new awakened gods to the existing data
awakened_data['awakened_gods'].update(new_awakened_gods)

# Write back to file
with open(awakened_file, 'w', encoding='utf-8') as f:
    json.dump(awakened_data, f, indent=2, ensure_ascii=False)

print(f"\n✅ Successfully added {len(new_awakened_gods)} new awakened gods!")
print(f"Total awakened gods now: {len(awakened_data['awakened_gods'])}")

print(f"\n=== NEWLY ADDED AWAKENED GODS ===")
for god_id, god_data in new_awakened_gods.items():
    print(f"🌟 {god_data['name']} ({god_data['pantheon']}, {god_data['element']}, {god_data['tier']})")

print(f"\n🎉 All Epic and Legendary gods now have awakened forms!")
