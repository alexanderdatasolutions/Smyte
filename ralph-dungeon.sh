#!/bin/bash

# Usage:
#   ./ralph-dungeon.sh plan 5      # Plan mode, max 5 iterations
#   ./ralph-dungeon.sh build 20    # Build mode, max 20 iterations

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <mode> <iterations>"
  echo "  mode: plan or build"
  echo "  iterations: max number of iterations"
  exit 1
fi

MODE=$1
MAX_ITERATIONS=$2

if [ "$MODE" = "plan" ]; then
  PROMPT_FILE="new-game-project/DUNGEON_PROMPT_PLAN.md"
elif [ "$MODE" = "build" ]; then
  PROMPT_FILE="new-game-project/DUNGEON_PROMPT_BUILD.md"
else
  echo "Invalid mode: $MODE (use 'plan' or 'build')"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: $PROMPT_FILE not found"
  exit 1
fi

for ((i=1; i<=$MAX_ITERATIONS; i++)); do
  echo "Iteration $i"
  echo "--------------------------------"

  result=$(claude -p "$(cat $PROMPT_FILE)" --dangerously-skip-permissions --output-format text 2>&1) || true

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "All tasks complete after $i iterations."
    exit 0
  fi

  echo ""
  echo "--- End of iteration $i ---"
  echo ""
done

echo "Reached max iterations ($MAX_ITERATIONS)"
exit 1
