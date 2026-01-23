#!/usr/bin/env bash
# complete-step.sh - Complete current step and claim next
#
# Usage: source complete-step.sh
#
# Inputs (required):
#   STEP_ID - The step ID to close
#   MOL_ID  - The molecule ID to find next step in
#
# Outputs (exported variables):
#   NEXT_STEP - The next step ID (or empty if none available)
#
# Notes:
#   - Closes STEP_ID with --continue flag
#   - Claims next step with fallback to bd list if bd ready returns empty
#   - The assignee update is required because bd mol current filters by assignee

set -euo pipefail

# Verify required variables are set
if [ -z "${STEP_ID:-}" ]; then
  echo "ERROR: STEP_ID must be set before sourcing complete-step.sh"
  exit 1
fi
if [ -z "${MOL_ID:-}" ]; then
  echo "ERROR: MOL_ID must be set before sourcing complete-step.sh"
  exit 1
fi

# Close the current step
bd close "$STEP_ID" --continue

# CRITICAL: Claim next step so bd mol current can find you
# Use gt hook --json first (more reliable due to routing issues with bd commands)
HOOK_JSON=$(gt hook --json 2>/dev/null || echo '{}')
NEXT_STEP=$(echo "$HOOK_JSON" | jq -r '.progress.ready_steps[0] // empty')

# Fallback 1: bd ready --parent (respects dependencies)
if [ -z "$NEXT_STEP" ]; then
  NEXT_STEP=$(bd ready --parent "$MOL_ID" --json 2>/dev/null | jq -r '.[0].id // empty' || echo "")
fi

# Fallback 2: bd list for any open step (handles bd ready filtering issues)
if [ -z "$NEXT_STEP" ]; then
  NEXT_STEP=$(bd list --parent "$MOL_ID" --status=open --json 2>/dev/null | jq -r '.[0].id // empty' || echo "")
fi

if [ -n "$NEXT_STEP" ]; then
  bd update "$NEXT_STEP" --status=in_progress --assignee="${BD_ACTOR:-}"
fi

# Export variable for use by calling script
export NEXT_STEP
