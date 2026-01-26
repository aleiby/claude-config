#!/usr/bin/env bash
# set-vars.sh - Load tackle context variables from bead notes
#
# Usage: source set-vars.sh
#
# Inputs: None (reads from gt hook and bd)
#
# Outputs (exported variables):
#   ISSUE_ID       - The issue bead ID from the hook
#   MOL_ID         - The molecule ID attached to the hook
#   ORG_REPO        - The upstream org/repo (e.g., "steveyegge/beads")
#   DEFAULT_BRANCH  - The default branch (e.g., "main")
#   UPSTREAM_REF    - The full ref (e.g., "upstream/main")
#   UPSTREAM_REMOTE - The git remote name (e.g., "upstream")
#   PR_NUMBER       - The PR number (optional, only after gate-submit)
#
# Notes:
#   - Variables are stored in bead notes by sling-tackle.sh
#   - This is a lightweight read (one bd show call)
#   - Errors if notes are missing (sling-tackle.sh must run first)

set -euo pipefail

# Get IDs from hook
# Capture both stdout and stderr to diagnose failures
HOOK_ERR=$(mktemp)
HOOK_JSON=$(gt hook --json 2>"$HOOK_ERR") || true
HOOK_ERR_MSG=$(cat "$HOOK_ERR")
rm -f "$HOOK_ERR"

# Handle gt hook failures
if [ -z "$HOOK_JSON" ] || [ "$HOOK_JSON" = "{}" ]; then
  echo "ERROR: No issue on hook. Is this a tackle session?"
  if [ -n "$HOOK_ERR_MSG" ]; then
    echo "Details: $HOOK_ERR_MSG"
  fi
  echo ""
  echo "If you switched branches, run: /tackle --resume"
  echo "To check hook status: gt hook"
  exit 1
fi

ISSUE_ID=$(echo "$HOOK_JSON" | jq -r '.bead_id // empty')
MOL_ID=$(echo "$HOOK_JSON" | jq -r '.attached_molecule // empty')

if [ -z "$ISSUE_ID" ]; then
  echo "ERROR: Hook exists but has no bead_id"
  echo "Hook JSON: $HOOK_JSON"
  echo ""
  echo "Try: /tackle --resume"
  exit 1
fi

# Read notes from bead
NOTES=$(bd show "$ISSUE_ID" --json 2>/dev/null | jq -r '.[0].notes // empty')

# Parse variables from notes
ORG_REPO=$(echo "$NOTES" | grep -oP '^upstream: \K.+' || echo "")
DEFAULT_BRANCH=$(echo "$NOTES" | grep -oP '^default_branch: \K.+' || echo "")
UPSTREAM_REF=$(echo "$NOTES" | grep -oP '^upstream_ref: \K.+' || echo "")
UPSTREAM_REMOTE=$(echo "$NOTES" | grep -oP '^upstream_remote: \K.+' || echo "")
PR_NUMBER=$(echo "$NOTES" | grep -oP '^pr_number: \K.+' || echo "")

# Verify required vars are present (PR_NUMBER is optional - only exists after gate-submit)
if [ -z "$ORG_REPO" ] || [ -z "$DEFAULT_BRANCH" ] || [ -z "$UPSTREAM_REF" ] || [ -z "$UPSTREAM_REMOTE" ]; then
  echo "ERROR: Missing tackle context in bead notes for $ISSUE_ID"
  echo "Expected: upstream, default_branch, upstream_ref, upstream_remote"
  echo "Found: $(echo "$NOTES" | head -4)"
  exit 1
fi

# Export all variables (PR_NUMBER may be empty)
export ISSUE_ID MOL_ID ORG_REPO DEFAULT_BRANCH UPSTREAM_REF UPSTREAM_REMOTE PR_NUMBER
