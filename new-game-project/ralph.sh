#!/bin/bash

# Usage:
#   ./ralph.sh 20                    # Build mode (PROMPT.md)
#   ./ralph.sh cleanup 1             # Cleanup planning (PROMPT_cleanup_plan.md)
#   ./ralph.sh clean 50              # Cleanup execution (PROMPT_cleanup_build.md)
#   ./ralph.sh plan 5                # Planning mode (PROMPT_plan.md)
#   ./ralph.sh audit-plan 1          # Audit planning (PROMPT_audit_plan.md) - creates AUDIT_PLAN.md
#   ./ralph.sh audit 100             # Audit execution (PROMPT_audit_build.md) - fixes all issues

MODE="${1:-build}"
MAX_ITERATIONS="${2:-10}"

# Determine prompt file and completion promise
case "$MODE" in
  cleanup)
    PROMPT_FILE="PROMPT_cleanup_plan.md"
    PROMISE="PLAN_COMPLETE"
    ;;
  clean)
    PROMPT_FILE="PROMPT_cleanup_build.md"
    PROMISE="COMPLETE"
    ;;
  plan)
    PROMPT_FILE="PROMPT_plan.md"
    PROMISE="PLAN_COMPLETE"
    ;;
  audit-plan)
    PROMPT_FILE="PROMPT_audit_plan.md"
    PROMISE="PLAN_COMPLETE"
    ;;
  audit)
    PROMPT_FILE="PROMPT_audit_build.md"
    PROMISE="COMPLETE"
    ;;
  [0-9]*)
    # First arg is a number, use as max iterations for build mode
    MAX_ITERATIONS="$MODE"
    MODE="build"
    PROMPT_FILE="PROMPT.md"
    PROMISE="COMPLETE"
    ;;
  *)
    PROMPT_FILE="PROMPT.md"
    PROMISE="COMPLETE"
    ;;
esac

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: $PROMPT_FILE not found"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode:       $MODE"
echo "Prompt:     $PROMPT_FILE"
echo "Max:        $MAX_ITERATIONS iterations"
echo "Promise:    $PROMISE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for ((i=1; i<=MAX_ITERATIONS; i++)); do
  echo ""
  echo "======================== ITERATION $i ========================"
  echo ""

  # Run claude and capture just the final text output
  result=$(claude -p "$(cat "$PROMPT_FILE")" --dangerously-skip-permissions --output-format text 2>&1) || true

  echo "$result"

  # Check for promise at the END of the output only (last 500 chars)
  tail_result="${result: -500}"
  if [[ "$tail_result" == *"<promise>$PROMISE</promise>"* ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "COMPLETED after $i iterations!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
  fi

  echo ""
  echo "--- End of iteration $i ---"
done

echo ""
echo "Reached max iterations ($MAX_ITERATIONS)"
exit 1
