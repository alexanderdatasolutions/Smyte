#!/bin/bash
set -euo pipefail

# Usage:
#   ./ralph.sh              # Build mode, unlimited
#   ./ralph.sh 20           # Build mode, max 20 iterations
#   ./ralph.sh plan         # Plan mode, unlimited
#   ./ralph.sh plan 5       # Plan mode, max 5 iterations
#   ./ralph.sh cleanup      # Cleanup plan mode (creates CLEANUP_PLAN.md)
#   ./ralph.sh cleanup 5    # Cleanup plan mode, max 5 iterations
#   ./ralph.sh clean        # Cleanup build mode (executes CLEANUP_PLAN.md)
#   ./ralph.sh clean 50     # Cleanup build mode, max 50 iterations

# Parse arguments
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
COMPLETION_PROMISE="COMPLETE"

if [ "${1:-}" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
    COMPLETION_PROMISE="PLAN_COMPLETE"
elif [ "${1:-}" = "cleanup" ]; then
    MODE="cleanup-plan"
    PROMPT_FILE="PROMPT_cleanup_plan.md"
    MAX_ITERATIONS=${2:-0}
    COMPLETION_PROMISE="PLAN_COMPLETE"
elif [ "${1:-}" = "clean" ]; then
    MODE="cleanup-build"
    PROMPT_FILE="PROMPT_cleanup_build.md"
    MAX_ITERATIONS=${2:-0}
    COMPLETION_PROMISE="COMPLETE"
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS=$1
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
echo "Promise: $COMPLETION_PROMISE"
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

    # Run claude and capture output
    OUTPUT=$(cat "$PROMPT_FILE" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model sonnet \
        --verbose 2>&1) || true

    echo "$OUTPUT"

    # Check for completion promise
    if echo "$OUTPUT" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "COMPLETED after $((ITERATION + 1)) iterations!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    fi

    git push origin "$CURRENT_BRANCH" 2>/dev/null || {
        echo "Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done
