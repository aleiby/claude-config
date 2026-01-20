# Retrospective Phase

Reflect on what went wrong with the tackle process and improve the skill.

## Purpose

This step runs **immediately after PR submission** (not after merge). Capture friction and errors while fresh.

## What to Log

**IMPORTANT**: Only log issues that tackle could help prevent in future runs.

### IN SCOPE: Tackle skill issues
- Command failures due to wrong flags in instructions
- Missing `--no-daemon` or other required flags
- Confusing workflow steps or unclear instructions
- Missing guidance that applies to ALL tackle runs
- State management issues (handoff, molecule attachment)
- Gate workflow problems

### IN SCOPE: Systemic issues tackle could address
- Working in wrong directory/git clone
- Forgetting to check for existing work before starting
- Common agent mistakes that guardrails could prevent
- Environment assumptions that should be verified

### OUT OF SCOPE (task-specific issues)
- Test failures in the code being submitted
- Upstream codebase quirks or conventions
- Merge conflicts or rebasing issues
- PR review feedback about the code

**Rule of thumb**: Could tackle reasonably add guidance/checks to prevent this? If yes, log it. If it's inherent to the specific task, don't.

## Pattern Detection via Molecule History

Tackle molecules are labeled `formula:tackle` for querying. Use past molecules to detect patterns:

```bash
# Find closed tackle molecules
bd list --all --label "formula:tackle" --json | jq '
  .[] | select(.status == "closed") |
  {id, close_reason, notes}
'
```

Check notes and close_reason fields for recurring issues before proposing fixes.

## When to Fix

### Fix Immediately (no pattern needed)
Objective errors that will always fail:
- Wrong command flags (`--silent` doesn't exist)
- Missing required flags (`--no-daemon` required but not in instructions)
- Syntax errors in example commands
- Incorrect command names or paths

These are bugs, not patterns. Fix them now.

### Note and Check for Patterns (2+ occurrences)
Subjective issues that need validation:
- "Instructions were confusing" - might be context-specific
- "Would be nice to have X" - suggestions need confirmation
- "Step took multiple attempts" - might be user error

**Rules:**
- 1 occurrence: Note in molecule close_reason, wait for pattern
- 2+ occurrences: Propose fix
- 3+ occurrences: Definitely fix

## Recording Issues

When closing the retro step, include any issues in the close_reason:

```bash
bd close <retro-step-id> --reason "$(cat <<'EOF'
Issues found:
- ERROR: Used --silent flag (doesn't exist, should be -q)
- FRICTION: Molecule attachment instructions unclear

Clean areas:
- Gate flow worked smoothly
- Validation steps clear
EOF
)"
```

This becomes queryable history for pattern detection.

## Proposing Skill Improvements

For persistent problems (2+ occurrences across molecules), propose changes:

```
## Tackle Skill Improvement

Issue: <description of persistent problem>
Occurrences: Found in molecules <list>
Affected resource: <RESEARCH.md | IMPLEMENT.md | etc.>

Signal: "<exact error or friction point>"

Current text:
> existing instruction

Proposed text:
> improved instruction

Rationale: <why this helps>
```

Present for review. Only apply with explicit approval.

## Completing Retro

### If the run was smooth

```bash
bd close <retro-step-id> --reason "Clean run - no issues"
```

### If there were issues

```bash
bd close <retro-step-id> --reason "Logged: <brief summary of issues>"
```

## Example

```
## Tackle Retrospective: gt-mol-xxxxx

Reviewed tackle process for worktree health check PR.

### Issues Found

1. **ERROR**: Used `--silent` flag (doesn't exist)
   - Should be `-q` or `--quiet`
   - Fixing immediately in RESEARCH.md

2. **FRICTION**: Molecule attachment confusion
   - Instructions unclear about "pinned bead" concept
   - Checking molecule history for pattern...
   - Found similar note in gt-mol-yyyyy - 2nd occurrence
   - Proposing clearer instructions

### Pattern Check
Queried closed tackle molecules for similar issues.
Found 1 prior occurrence of molecule attachment confusion.

### Actions
- Fixed: --silent -> -q in RESEARCH.md (objective error)
- Proposed: Clearer molecule attachment instructions (2nd occurrence)
```
