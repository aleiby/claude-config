# Retrospective Phase

Reflect on what went wrong with the tackle process and improve the skill for next time.

## Purpose

This step runs **immediately after PR submission** (not after merge). The goal is to capture friction, confusion, and errors encountered during the tackle process while they're fresh.

## Journal Bead

Keep a running journal of tackle process issues in a bead. Track the journal bead ID in config:

```yaml
# .beads/config.yaml
tackle:
  cache_beads:
    steveyegge/gastown: gt-mzbwo
  journal_bead: gt-xxxxx  # Tackle process issues journal
```

### Create Journal (if not exists)

```bash
# Check config for existing journal
JOURNAL_BEAD=$(yq '.tackle.journal_bead' .beads/config.yaml 2>/dev/null)

if [ -z "$JOURNAL_BEAD" ] || [ "$JOURNAL_BEAD" = "null" ]; then
  JOURNAL_BEAD=$(bd create \
    --title "Tackle skill process journal" \
    --type task \
    --label tackle-journal \
    --description "# Tackle Process Issues\n\nLog of friction/errors encountered during tackle runs." \
    --json | jq -r '.id')

  # Store in config (you'll need to edit config.yaml)
  echo "Created journal bead: $JOURNAL_BEAD"
  echo "Add to .beads/config.yaml under tackle.journal_bead"
fi
```

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
- Missing pre-flight checks that would catch problems early
- Environment assumptions that should be verified

These aren't tackle bugs, but adding guidance to tackle could prevent them.

### OUT OF SCOPE (task-specific issues)
- Test failures in the code being submitted
- Upstream codebase quirks or conventions
- Merge conflicts or rebasing issues
- PR review feedback about the code
- Build/CI failures specific to the project
- Complexity of the particular feature/bug

**Rule of thumb**: Could tackle reasonably add guidance/checks to prevent this? If yes, log it. If it's inherent to the specific task, don't.

---

Scan the session for skill issues:

### Errors (highest priority)
- Command failures (wrong flags, missing --no-daemon, etc.)
- Incorrect instructions that had to be figured out
- Missing steps that caused confusion

### Friction (high priority)
- Confusing instructions that required re-reading
- Steps that took multiple attempts
- Missing context that caused wrong assumptions

### Suggestions (lower priority)
- Things that could be clearer
- Missing guidance for edge cases
- Workflow improvements

## Log Entry Format

Append to journal bead notes:

```bash
ENTRY="
## $(date +%Y-%m-%d) - $ISSUE_ID

### Errors
- <error 1>: <what happened, what the fix was>

### Friction
- <point of confusion>: <what would have helped>

### Suggestions
- <improvement idea>
"

bd update "$JOURNAL_BEAD" --notes="$ENTRY"
```

## When to Fix

### Fix Immediately (no journal needed)
Objective errors that will always fail:
- Wrong command flags (`--silent` doesn't exist)
- Missing required flags (`--no-daemon` required but not in instructions)
- Syntax errors in example commands
- Incorrect command names or paths

These are bugs, not patterns. Fix them now.

### Log and Wait for Pattern (2+ occurrences)
Subjective issues that need validation:
- "Instructions were confusing" - might be context-specific
- "Would be nice to have X" - suggestions need confirmation
- "Step took multiple attempts" - might be user error
- Systemic issues that *might* warrant guardrails

Check the journal for patterns before proposing fixes:

```bash
# Read journal
JOURNAL=$(bd show "$JOURNAL_BEAD" --json | jq -r '.[0].notes // .[0].description')

# Count occurrences of similar issues
echo "$JOURNAL" | grep -c "<pattern>"
```

**Rules:**
- 1 occurrence: Log it, wait for pattern
- 2+ occurrences: Propose fix
- 3+ occurrences: Definitely fix

## Proposing Skill Improvements

For persistent problems, propose changes in this format:

```
## Tackle Skill Improvement

Issue: <description of persistent problem>
Occurrences: <N> times in journal
Affected resource: <BOOTSTRAP.md | GATES.md | etc.>

Signal: "<exact error or friction point>"

Current text:
> existing instruction

Proposed text:
> improved instruction

Rationale: <why this helps>
```

Present for review. Only apply with explicit approval.

## Completing Retro

```bash
# Close the retro step
bd close <retro-step-id> --reason "Logged N issues to journal" --continue
```

## Example Session

```
## Tackle Retrospective: gt-mihct

Reviewed tackle process for worktree health check PR.

### Issues Found

1. **ERROR**: Used `--silent` flag (doesn't exist)
   - Should be `-q` or `--quiet`
   - Logged to journal

2. **FRICTION**: Molecule attachment confusion
   - Instructions unclear about "pinned bead" concept
   - Spent 10+ minutes figuring it out
   - Logged to journal (2nd occurrence - now persistent)

3. **FRICTION**: Didn't know PR was already created after handoff
   - No state persisted about draft PR
   - Logged to journal

### Persistent Problems (2+ occurrences)

- Molecule attachment confusion: Proposing clearer instructions

### Journal Updated
Added 3 entries to gt-xxxxx
```

## When to Skip

If the tackle run was smooth with no issues:

```bash
bd close <retro-step-id> --reason "No issues - clean run" --continue
```

Don't log non-issues. The journal is for problems only.
