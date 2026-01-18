# Example Plan script
0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn what documentation and cleanup is needed.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand progress so far.
0c. Study the entire codebase with up to 500 parallel Sonnet subagents to understand:
    - Autoloaders in `Scripts/Autoloaders/` (the game's backbone - 24 handlers)
    - JSON configs in `Configs/` (mobs, items, zones, talents, quests, etc.)
    - Enemy scripts in `Scripts/Enemies/`
    - Object scripts in `Scripts/Objects/`
    - UI scripts in `UI/Scripts/` and scenes in `UI/Scenes/`
    - Game scenes in `Scenes/` (Characters, Objects, Screens, Worlds)
    - Signal connections and event flow between handlers
    - Code patterns and architecture
    - Ugly code, duplication, inconsistencies
0d. Study `docs/` (if present) to understand existing documentation.

1. Create a comprehensive analysis using an Opus subagent with ultrathink:

   **Documentation Gaps:**
   - Which Autoloaders lack documentation? (Start here - they're the core)
   - What formulas/calculations are buried in handlers but not explained?
   - How do the JSON configs get loaded and used?
   - What signals connect which handlers?
   - How does combat flow? (DamageHandler, StatsHandler, BuffHandler, MobHandler)
   - How does progression work? (TalentHandler, SpecHandler, QuestHandler)
   - What decisions were made that aren't captured anywhere?
   
   **Code Cleanup Opportunities:**
   - Untyped variables and functions (GDScript 4.x supports static typing!)
   - Duplicated logic across handlers
   - Inconsistent patterns between similar systems
   - Magic numbers without constants
   - Dead code or unused signals
   - Overly complex functions that need refactoring
   - JSON config parsing that could be cleaner

2. Create/update @IMPLEMENTATION_PLAN.md with prioritized tasks. Structure as:

   ## Documentation Tasks
   - [ ] Task (creates `docs/path/to/file.md`)
   
   ## Cleanup Tasks  
   - [ ] Task (affects `Scripts/Autoloaders/SomeHandler.gd` or similar)

   Prioritize tasks that:
   1. Document Autoloaders and their responsibilities first (they're everything)
   2. Document how JSON configs are structured and loaded
   3. Document core game loops (combat, progression, crafting)
   4. Create MOC (Map of Content) pages that link systems together
   5. Fix ugly code that will block understanding
   6. Capture formulas and magic numbers

IMPORTANT: Plan only. Do NOT implement anything. Do NOT create documentation yet. This is gap analysis only.

ULTIMATE GOAL: Create a rich Obsidian knowledge base with interconnected notes AND clean up the GDScript codebase so it's maintainable. Every doc should use `[[wiki-links]]` to connected concepts.


# Example Build
0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn documentation standards.
0b. Study @IMPLEMENTATION_PLAN.md to find your next task.
0c. Study relevant scripts and scenes with Sonnet subagents before making changes:
    - Autoloaders: `Scripts/Autoloaders/`
    - JSON configs: `Configs/`
    - UI: `UI/Scripts/` and `UI/Scenes/`
    - Game scenes: `Scenes/`

1. Choose the most important task from @IMPLEMENTATION_PLAN.md and implement it fully.

   **For Documentation Tasks:**
   - Create atomic notes (one concept per file)
   - Use `[[wiki-links]]` liberally to connect concepts
   - Add frontmatter: tags, aliases, related links
   - Include GDScript snippets with file paths
   - Document formulas in both prose AND code blocks
   - Document signal flows between Autoloaders
   - Document JSON config structure with examples
   - Create MOC pages that serve as hubs
   
   **For Cleanup Tasks:**
   - Search first (don't assume not implemented)
   - Add static types to variables, parameters, and return values
   - Extract magic numbers to constants
   - Refactor incrementally, test by running the game
   - Update related docs if behavior changes
   - Add inline comments explaining "why" for complex logic

2. After implementing, validate your work:
   - Documentation: Check all `[[links]]` point to real files or create stubs
   - Code: Run the project to verify no errors (see @AGENTS.md for commands)

3. Update @IMPLEMENTATION_PLAN.md - mark task complete, note any discoveries.

4. When done: `git add -A` then `git commit` with descriptive message, then `git push`.

99999. Documentation must use Obsidian format: frontmatter, wiki-links, callouts (> [!note]), tags.
999999. Every doc links to at least 2 other docs. Isolated notes are useless.
9999999. Keep @IMPLEMENTATION_PLAN.md current - future loops depend on it.
99999999. When you learn how to run/build/test, update @AGENTS.md (keep it brief).
999999999. Implement completely. No placeholder docs like "TODO: document this".
9999999999. For game formulas, show BOTH the math notation AND the GDScript implementation.
99999999999. Create `docs/MOCs/` index pages that link all related concepts together.
999999999999. Use static typing in ALL GDScript: `var health: int = 100`, `func attack() -> void:`
9999999999999. Document signal flows - who emits, who listens, what data is passed.
99999999999999. For JSON configs, document the schema and show example entries.


# Example loop
#!/bin/bash
set -euo pipefail

# Usage:
#   ./loop.sh              # Build mode, unlimited
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited
#   ./loop.sh plan 5       # Plan mode, max 5 iterations

# Parse arguments
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0

if [ "${1:-}" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$1
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    cat "$PROMPT_FILE" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model sonnet \
        --verbose

    git push origin "$CURRENT_BRANCH" 2>/dev/null || {
        echo "Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done


# Running Ralph Wiggum the Right Way: A Complete Setup Guide


0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn what documentation and cleanup is needed.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand progress so far.
0c. Study the entire codebase with up to 500 parallel Sonnet subagents to understand:
    - Autoloaders in `Scripts/Autoloaders/` (the game's backbone - 24 handlers)
    - JSON configs in `Configs/` (mobs, items, zones, talents, quests, etc.)
    - Enemy scripts in `Scripts/Enemies/`
    - Object scripts in `Scripts/Objects/`
    - UI scripts in `UI/Scripts/` and scenes in `UI/Scenes/`
    - Game scenes in `Scenes/` (Characters, Objects, Screens, Worlds)
    - Signal connections and event flow between handlers
    - Code patterns and architecture
    - Ugly code, duplication, inconsistencies
0d. Study `docs/` (if present) to understand existing documentation.

1. Create a comprehensive analysis using an Opus subagent with ultrathink:

   **Documentation Gaps:**
   - Which Autoloaders lack documentation? (Start here - they're the core)
   - What formulas/calculations are buried in handlers but not explained?
   - How do the JSON configs get loaded and used?
   - What signals connect which handlers?
   - How does combat flow? (DamageHandler, StatsHandler, BuffHandler, MobHandler)
   - How does progression work? (TalentHandler, SpecHandler, QuestHandler)
   - What decisions were made that aren't captured anywhere?
   
   **Code Cleanup Opportunities:**
   - Untyped variables and functions (GDScript 4.x supports static typing!)
   - Duplicated logic across handlers
   - Inconsistent patterns between similar systems
   - Magic numbers without constants
   - Dead code or unused signals
   - Overly complex functions that need refactoring
   - JSON config parsing that could be cleaner

2. Create/update @IMPLEMENTATION_PLAN.md with prioritized tasks. Structure as:

   ## Documentation Tasks
   - [ ] Task (creates `docs/path/to/file.md`)
   
   ## Cleanup Tasks  
   - [ ] Task (affects `Scripts/Autoloaders/SomeHandler.gd` or similar)

   Prioritize tasks that:
   1. Document Autoloaders and their responsibilities first (they're everything)
   2. Document how JSON configs are structured and loaded
   3. Document core game loops (combat, progression, crafting)
   4. Create MOC (Map of Content) pages that link systems together
   5. Fix ugly code that will block understanding
   6. Capture formulas and magic numbers

IMPORTANT: Plan only. Do NOT implement anything. Do NOT create documentation yet. This is gap analysis only.

ULTIMATE GOAL: Create a rich Obsidian knowledge base with interconnected notes AND clean up the GDScript codebase so it's maintainable. Every doc should use `[[wiki-links]]` to connected concepts.

0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn documentation standards.
0b. Study @IMPLEMENTATION_PLAN.md to find your next task.
0c. Study relevant scripts and scenes with Sonnet subagents before making changes:
    - Autoloaders: `Scripts/Autoloaders/`
    - JSON configs: `Configs/`
    - UI: `UI/Scripts/` and `UI/Scenes/`
    - Game scenes: `Scenes/`

1. Choose the most important task from @IMPLEMENTATION_PLAN.md and implement it fully.

   **For Documentation Tasks:**
   - Create atomic notes (one concept per file)
   - Use `[[wiki-links]]` liberally to connect concepts
   - Add frontmatter: tags, aliases, related links
   - Include GDScript snippets with file paths
   - Document formulas in both prose AND code blocks
   - Document signal flows between Autoloaders
   - Document JSON config structure with examples
   - Create MOC pages that serve as hubs
   
   **For Cleanup Tasks:**
   - Search first (don't assume not implemented)
   - Add static types to variables, parameters, and return values
   - Extract magic numbers to constants
   - Refactor incrementally, test by running the game
   - Update related docs if behavior changes
   - Add inline comments explaining "why" for complex logic

2. After implementing, validate your work:
   - Documentation: Check all `[[links]]` point to real files or create stubs
   - Code: Run the project to verify no errors (see @AGENTS.md for commands)

3. Update @IMPLEMENTATION_PLAN.md - mark task complete, note any discoveries.

4. When done: `git add -A` then `git commit` with descriptive message, then `git push`.

99999. Documentation must use Obsidian format: frontmatter, wiki-links, callouts (> [!note]), tags.
999999. Every doc links to at least 2 other docs. Isolated notes are useless.
9999999. Keep @IMPLEMENTATION_PLAN.md current - future loops depend on it.
99999999. When you learn how to run/build/test, update @AGENTS.md (keep it brief).
999999999. Implement completely. No placeholder docs like "TODO: document this".
9999999999. For game formulas, show BOTH the math notation AND the GDScript implementation.
99999999999. Create `docs/MOCs/` index pages that link all related concepts together.
999999999999. Use static typing in ALL GDScript: `var health: int = 100`, `func attack() -> void:`
9999999999999. Document signal flows - who emits, who listens, what data is passed.
99999999999999. For JSON configs, document the schema and show example entries.


#!/bin/bash
set -euo pipefail

# Usage:
#   ./loop.sh              # Build mode, unlimited
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited
#   ./loop.sh plan 5       # Plan mode, max 5 iterations

# Parse arguments
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0

if [ "${1:-}" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$1
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    cat "$PROMPT_FILE" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model sonnet \
        --verbose

    git push origin "$CURRENT_BRANCH" 2>/dev/null || {
        echo "Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done

# Agents Operational Guide

## Build & Run

```bash
# Run project (update path to your Godot 4 executable if needed)
godot --path . --debug

# Run headless
godot --path . --headless --quit
```

## Validation

```bash
# Check for parse errors
godot --path . --check-only --headless

# If using GUT for tests
godot --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Project Structure

```
Idle-Horrors/
├── Configs/              # JSON data files (mobs, items, zones, etc.)
├── Scripts/
│   ├── Autoloaders/      # 24 global singletons (the game's backbone)
│   ├── Enemies/          # Enemy scripts
│   └── Objects/          # Interactable object scripts
├── Scenes/
│   ├── Characters/       # Player, enemies, NPCs
│   ├── Objects/          # World objects
│   ├── Screens/          # Game screens
│   └── Worlds/           # Zone/world scenes
├── UI/
│   ├── Scenes/           # UI .tscn files
│   └── Scripts/          # UI .gd scripts
├── Assets/               # Art, sounds, etc.
└── addons/godotsteam/    # Steam integration
```

## Key Autoloaders

| Autoloader | Purpose |
|------------|---------|
| PlayerData | Player state, inventory, stats |
| StatsHandler | Stat calculations |
| DamageHandler | Combat damage |
| MobHandler | Enemy spawning/management |
| ItemHandler | Item definitions from items_config.json |
| ZoneHandler | Zone loading/transitions |
| QuestHandler | Quest tracking |
| TalentHandler | Talent/skill tree |
| BuffHandler | Buff/debuff system |
| CraftingHandler | Crafting system |
| ShopHandler | Store/shop system |
| SpecHandler | Class/spec system |

## Config Files

All game data in `Configs/*.json`:
- `mobs_config.json` - Enemy definitions
- `items_config.json` - Item data
- `equipment_config.json` - Gear stats
- `zones_config.json` - Zone definitions
- `talent_config.json` - Talent trees
- `quests_config.json` - Quest definitions
- `spec_config.json` - Class specs

## Codebase Patterns

(Ralph will fill this in as it learns)

## Operational Notes

(Ralph will fill this in as it discovers things)

[Full Video Here](https://youtu.be/eAtvoGlpeRU)

⚫⚫⚫⚪⚪ Intermediate Difficulty | ⏱️ 20-30 Minutes Setup Time

This guide walks you through running Ralph Wiggum (or any long-running autonomous agent) safely, efficiently, and cost-effectively. There's a lot of hype about Ralph Wiggum in the AI coding community, and most people are getting it wrong. This guide covers both the official Claude Code plugin method and the original bash loop—and explains why one is significantly better than the other.

> 💡 **Note**: While this guide focuses on Claude Code, the bash loop method works with any CLI agent (Codex, Gemini, OpenCode, etc.) with minimal tweaks.

## Before You Begin

### What You'll Need

* Claude Code installed and configured
* A PRD or detailed plan for what you want to build
* Basic terminal/command line familiarity
* (Optional) Claude for Chrome or Playwright MCP for visual feedback

### What is Ralph Wiggum?

Ralph Wiggum is a way to run Claude Code (or any agent) in a continuous autonomous loop. It solves the common problem of agents finishing too early by forcing them to keep working and checking until the task is truly complete.

**Best used for:**
- Long-running tasks
- Projects where you already know what you want to build
- Tasks that benefit from continuous iteration without manual intervention

**Not ideal for:**
- Exploratory work without clear goals
- Quick one-off tasks
- Situations where you need frequent human input

### Important Notes

* This guide has been tested on macOS
* Always set max iterations to avoid runaway costs
* Sandbox your environment for safety
* The bash loop method is recommended over the Claude plugin for reasons explained below

## Part 1: The Foundation (Same for Both Methods)

Before touching Ralph Wiggum, you need to set up these foundational pieces. This prep work is essential regardless of which method you choose.

### Step 1: Enable Sandboxing

For long-running autonomous tasks, you want isolation without constant permission prompts. Boris Cherney from Anthropic recommends using the sandbox to avoid permission prompts so Claude can cook without being blocked.

Create or edit `.claude/settings.json` in your project. Here's the configuration I used for my project—yours will look different based on what permissions you need:

```json
{
  "env": {
    "XDG_CACHE_HOME": ".cache",
    "npm_config_cache": ".cache/npm",
    "PIP_CACHE_DIR": ".cache/pip"
  },
  "permissions": {
    "allow": [
      "WebFetch(domain:registry.npmjs.org)",
      "WebFetch(domain:github.com)",
      "mcp__playwright__*",
      "mcp__claude-in-chrome__*"
    ],
    "deny": [
      "Bash(sudo *)",
      "Bash(docker *)",
      "Read(./.env)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)"
    ],
    "ask": [
      "Bash(git push:*)"
    ],
    "defaultMode": "acceptEdits"
  },
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "network": {
      "allowLocalBinding": true
    }
  }
}
```

Alternatively, run `/sandbox` in Claude Code to enable sandboxing interactively.

> ⚠️ **Important**: Everyone will set up their sandbox differently. Review the [Claude Code sandbox documentation](https://code.claude.com/docs/en/sandboxing) for full options.

### Step 2: Create Your PRD

Don't waste time and money running Ralph Wiggum on an unfleshed-out idea. Start with a comprehensive PRD.

If you need help creating a PRD, check out my [PRD Creator tutorial](https://www.youtube.com/watch?v=0seaP5YjXVM) and [PRD Creator custom instructions](https://github.com/JeredBlu/custom-instructions/blob/main/prd-creator-3-25.md).

### Step 3: Create plan.md

Based on [Anthropic's effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), structure your plan with tasks that can be marked as passing/failing.

Here's the format Anthropic recommends—each task is JSON with a category, description, steps, and a `passes` field:

```markdown
# Project Plan

## Overview
Brief description of what you're building.

**Reference:** `PRD.md`

---

## Task List

```json
[
  {
    "category": "setup",
    "description": "Initialize project structure and dependencies",
    "steps": [
      "Create project directory structure",
      "Initialize package.json or requirements",
      "Install required dependencies",
      "Verify files load correctly"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Implement main navigation component",
    "steps": [
      "Create Navigation component",
      "Add responsive styling",
      "Implement mobile menu toggle"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Implement hero section with CTA",
    "steps": [
      "Create Hero component",
      "Add headline and subhead",
      "Style CTA button",
      "Center content properly"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify all components render correctly",
    "steps": [
      "Test responsive layouts",
      "Check console for errors",
      "Verify all links work"
    ],
    "passes": false
  }
]
```

---

## Agent Instructions

1. Read `activity.md` first to understand current state
2. Find next task with `"passes": false`
3. Complete all steps for that task
4. Verify in browser
5. Update task to `"passes": true`
6. Log completion in `activity.md`
7. Repeat until all tasks pass

**Important:** Only modify the `passes` field. Do not remove or rewrite tasks.

---

## Completion Criteria
All tasks marked with `"passes": true`
```

### Step 4: Create activity.md

This file logs what the agent accomplishes during each iteration:

```markdown
# Project Build - Activity Log

## Current Status
**Last Updated:** 
**Tasks Completed:** 
**Current Task:** 

---

## Session Log

<!-- Agent will append dated entries here -->
```

## Part 2: The Claude Code Plugin Method

### Installing the Plugin

1. Open Claude Code
2. Run `/plugin`
3. Navigate to **Discover**
4. Search for "Ralph" or scroll to find it
5. Press Enter to install

For more details, see the [official Ralph Wiggum plugin documentation](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md).

### Running with the Plugin

Type `/ralph` and it will auto-complete to show several options. Select the one that says **"Ralph loop"** and press Tab:

```
/ralph → select "Ralph loop"
```

You'll then be prompted for your prompt, max iterations, and completion promise.

**Example Prompt:**

> ⚠️ **Note**: In the video I showed this prompt with line breaks, but Claude didn't like it—send it as one continuous block of text.

```
We are rebuilding the project from scratch in this repo. First read activity.md to see what was recently accomplished. Start the site locally and keep it localhost only. Use either: npm run dev (for Next or Vite) OR python3 -m http.server 8000 --bind 127.0.0.1 (for static HTML). Verify the current behavior in Claude in Chrome by opening the local URL and checking the page loads with no obvious layout issues. Then open plan.md and choose the single highest priority task whose Status is failing. Work on exactly one task: implement the change, run the linter or build check if available (npm run lint, npm run typecheck, or npm run build), and verify in Chrome again. Check the browser console for errors and confirm the change matches the acceptance criteria in plan.md. Append a dated progress entry to activity.md describing what you changed, which commands you ran, and what you verified in Chrome. When the task is confirmed, update that task Status in plan.md from failing to passing. Make one git commit for that task only with a clear single line message. Do not run git init, do not change git remotes, and do not push. Repeat until all tasks are passing. When all tasks are marked passing, output exactly COMPLETE.
```

```
Max Iterations: 20
Completion Promise: COMPLETE
```

### Why the Plugin Has Limitations

The Claude Code plugin runs everything in a **single context window**. This means:

- Context gets bloated over time
- More room for hallucination as context fills
- You may need to manually compact (I had to stop and do this in testing)
- Doesn't truly implement the "fresh loop" concept

The original Ralph Wiggum approach starts a **fresh context window** for each iteration, which is fundamentally better for long-running tasks.

## Part 3: The Bash Loop Method (Recommended)

This method works with Claude Code, Codex CLI, or any CLI agent. Each iteration runs in a fresh context window—this is the key difference.

### Step 1: Set Up Playwright MCP (for Headless Feedback)

Since the bash loop runs headless, use Playwright MCP instead of Claude for Chrome.

Create `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "-y",
        "@playwright/mcp@latest",
        "--headless",
        "--output-dir",
        "."
      ]
    }
  }
}
```

### Step 2: Create PROMPT.md

Create a `PROMPT.md` file in your project root:

```markdown
@plan.md @activity.md

We are rebuilding the project from scratch in this repo.

First read activity.md to see what was recently accomplished.

Start the site locally with python3 -m http.server. If port is taken, try another port.

Open plan.md and choose the single highest priority task where passes is false.

Work on exactly ONE task: implement the change.

After implementing, use Playwright to:
1. Navigate to the local server URL
2. Take a screenshot and save it as screenshots/[task-name].png

Append a dated progress entry to activity.md describing what you changed and the screenshot filename.

Update that task's passes in plan.md from false to true.

Make one git commit for that task only with a clear message.

Do not git init, do not change remotes, do not push.

ONLY WORK ON A SINGLE TASK.

When ALL tasks have passes true, output <promise>COMPLETE</promise>
```

> 💡 **Tip**: The `@plan.md @activity.md` at the top uses Claude Code's file reference syntax to include those files in context.

### Step 3: Create ralph.sh

Create a `ralph.sh` script in your project root. This is the script I've been using—it's not the official way, just my approach:

```bash
#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  echo "Iteration $i"
  echo "--------------------------------"
  
  result=$(claude -p "$(cat PROMPT.md)" --output-format text 2>&1) || true

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "All tasks complete after $i iterations."
    exit 0
  fi
  
  echo ""
  echo "--- End of iteration $i ---"
  echo ""
done

echo "Reached max iterations ($1)"
exit 1
```

### Step 4: Make the Script Executable

```bash
chmod +x ralph.sh
```

### Step 5: Create Screenshots Directory

```bash
mkdir screenshots
```

### Step 6: Run Ralph

```bash
./ralph.sh 20
```

The number (20) is your max iterations. Start with 10-20 for testing.

### Why This Method is Better

Each iteration runs in a **fresh context window**, which means:
- No context bloat
- Reduced hallucination risk
- Cleaner separation between tasks
- Better matches Anthropic's recommended approach for long-running agents

You can watch progress by monitoring:
- `activity.md` for logged updates
- `screenshots/` folder for visual verification
- Git commits for each completed task

## Part 4: Setting Up the Feedback Loop

The feedback loop is crucial—it lets the agent verify its own work. As Boris Cherney recommends: give it a feedback loop.

### Option A: Claude for Chrome (Plugin Method)

To use Claude for Chrome as your feedback loop:

1. Make sure you have Chrome installed
2. Run `/chrome` in Claude Code to enable the Claude for Chrome integration
3. Turn it on when prompted
4. The agent can now open URLs, take screenshots, and check console logs

### Option B: Playwright MCP (Bash Loop Method)

With Playwright configured, the agent can:
- Navigate to URLs headlessly
- Take screenshots (saved to your screenshots folder)
- Check console logs
- Interact with page elements

Screenshots let you visually verify what the agent is doing without watching it live.

## Troubleshooting

### Common Issues

1. **Agent gets stuck / infinite loop**
   - Ensure max iterations is set
   - Check that completion phrase is being output correctly
   - Review plan.md for ambiguous tasks

2. **Context window fills up (plugin method)**
   - Switch to bash loop method
   - Or manually compact and restart

3. **Playwright/Chrome not working**
   - Verify MCP server is configured correctly
   - Check that the local server is actually running
   - Review permissions in sandbox config

4. **Expensive runs**
   - Always set max iterations
   - Use 10-20 iterations for testing
   - Review costs before longer runs

5. **Port already in use**
   - The prompt handles this by telling the agent to try another port

### Best Practices

- **Always sandbox** for long-running autonomous tasks
- **Always set max iterations** - the plugin defaults to unlimited
- **Plan thoroughly** before running Ralph with a PRD and plan.md
- **Use the bash loop** for true iteration separation
- **Give feedback mechanisms** so the agent can verify its work
- **Monitor activity.md** and git commits to track progress

## Key Takeaways

1. **Safety**: Sandbox your environment
2. **Efficiency**: Plan thoroughly with a PRD and plan.md
3. **Cost Control**: Always set max iterations
4. **Validation**: Give the agent visual feedback (Chrome or Playwright)
5. **Method Choice**: Bash loop > Claude plugin for true fresh iterations

## Useful Links

* **Ralph Wiggum Plugin**: [GitHub - Official Plugin](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md)
* **Original Ralph Wiggum**: [ghuntley.com/ralph](https://ghuntley.com/ralph/) by Geoffrey Huntley
* **Anthropic's Long-Running Agents**: [Effective Harnesses Blog Post](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
* **Claude Code Sandbox Docs**: [code.claude.com/docs/en/sandboxing](https://code.claude.com/docs/en/sandboxing)
* **PRD Creator Tutorial**: [YouTube Video](https://www.youtube.com/watch?v=0seaP5YjXVM)
* **PRD Creator Instructions**: [GitHub](https://github.com/JeredBlu/custom-instructions/blob/main/prd-creator-3-25.md)

## Related Resources

* [Boris Cherney's Claude Code Post](https://x.com/bcherny/status/2007179858435281082)
* [My Video on Boris's Approach](https://youtu.be/S_pxMm0Qx7c)
* [Spec-Driven Development Video](https://youtu.be/wKx66sYyyUs)

---

## Contact

For more AI tools and tutorials, follow JeredBlu:
* Book a Call: [JeredBlu on Cal.com](https://cal.com/jeredblu)
* YouTube: [@JeredBlu](https://youtube.com/@JeredBlu)
* Twitter/X: [@JeredBlu](https://twitter.com/JeredBlu)
* Website: [jeredblu.com](https://jeredblu.com)