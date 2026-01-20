# Submit Phase

Mark the draft PR as ready for review after approval.

## Pre-Submit Checklist

Before this phase, verify gate-submit was approved (check that it's closed).

**Do not submit without approval.**

## Recover PR Info

If resuming after session handoff, recover the PR info:

```bash
# Option 1: Find PR by branch name (most reliable)
BRANCH=$(git branch --show-current)
FORK_OWNER=$(gh repo view --json owner --jq '.owner.login')
PR_NUMBER=$(gh pr list --repo <upstream> --head "$FORK_OWNER:$BRANCH" --json number --jq '.[0].number')

# Option 2: Check gate-submit step notes (stored during gate approval)
if [ -z "$PR_NUMBER" ]; then
  # Find the gate-submit step from molecule
  GATE_STEP=$(bd --no-daemon mol current --json 2>/dev/null | jq -r '.steps[] | select(.title | contains("Pre-submit")) | .id' | head -1)
  if [ -n "$GATE_STEP" ]; then
    PR_INFO=$(bd show "$GATE_STEP" --json | jq -r '.[0].notes')
    PR_NUMBER=$(echo "$PR_INFO" | grep pr_number | cut -d: -f2 | tr -d ' ')
  fi
fi

# Option 3: Check if PR already marked ready
if [ -n "$PR_NUMBER" ]; then
  IS_DRAFT=$(gh pr view "$PR_NUMBER" --repo <upstream> --json isDraft --jq '.isDraft')
  if [ "$IS_DRAFT" = "false" ]; then
    echo "PR #$PR_NUMBER already marked ready - nothing to do"
    # Skip to record phase
  fi
fi
```

## Mark PR Ready

The draft PR was created during gate-submit. Now we mark it ready for maintainer review.

### 1. Mark Draft as Ready

```bash
# PR_NUMBER recovered above or from context

# Mark the draft PR as ready for review
gh pr ready $PR_NUMBER --repo <upstream-org>/<upstream-repo>

# Verify status
gh pr view $PR_NUMBER --repo <upstream-org>/<upstream-repo> --json state,isDraft
```

### 2. Capture Final PR URL

```bash
PR_URL=$(gh pr view $PR_NUMBER --repo <upstream-org>/<upstream-repo> --json url --jq '.url')
echo "PR submitted: $PR_URL"
```

## PR Title and Body Reference

If you need to update the PR before marking ready, use:

```bash
# Update title
gh pr edit $PR_NUMBER --repo <upstream-org>/<upstream-repo> --title "<new-title>"

# Update body
gh pr edit $PR_NUMBER --repo <upstream-org>/<upstream-repo> --body "<new-body>"
```

### Title Format

From cached `research.yaml`:
```yaml
pull_requests:
  title_format: null  # or specific format
```

Default format: `<type>(<scope>): <description>`

Examples:
- `fix(doctor): correct indentation in database check`
- `feat(sync): add progress indicator`
- `docs(readme): update installation instructions`

### Body Format

Use template if available, otherwise:

```markdown
## Summary

<Brief description of what this PR does>

Fixes <issue-id>

## Changes

- <Change 1>
- <Change 2>

## Test Plan

- [ ] <How to test change 1>
- [ ] <How to test change 2>

## Checklist

- [x] Tests pass
- [x] Linter passes
- [x] Rebased on upstream default branch
- [x] Single concern (isolation verified)
```

## Update Molecule

```yaml
phase: "record"
pr:
  url: "https://github.com/org/repo/pull/123"
  number: 123
  submitted_at: "2026-01-19T12:00:00Z"
```

## Record Phase

After PR submission:

### 1. Update Local Issue

```bash
bd update <issue-id> --status=in_review --notes="PR submitted: $PR_URL"
```

### 2. Record for Learning

Update the issue with PR outcome tracking:
```bash
bd update <issue-id> --notes="PR: $PR_URL, files: 3, lines: 45"
```

The molecule and issue history provide the audit trail for learning.

### 3. Final Output

```
## PR Submitted

Issue:    hq-1234 - Fix doctor indentation
PR:       https://github.com/steveyegge/beads/pull/123
Status:   Awaiting review

Next steps:
- Monitor PR for review comments
- Address feedback if requested
- Once merged, close local issue with: bd close hq-1234

To check PR status:
  gh pr status --repo steveyegge/beads
  gh pr view 123 --repo steveyegge/beads
```

### 4. Advance to Retro

```bash
bd close <record-step-id> --continue
```

Use `bd ready` to find the retro step.

## Error Handling

### Push Fails

```
Error: Failed to push branch

Possible causes:
- No push access to origin
- Branch already exists remotely

Solutions:
- Verify remote: git remote -v
- Force push if needed: git push -f origin <branch>
- Use different branch name
```

### PR Creation Fails

```
Error: Failed to create PR

Possible causes:
- Not authenticated with gh
- PR already exists for this branch
- Target repo doesn't accept PRs

Solutions:
- gh auth login
- Check existing PRs: gh pr list --head <branch>
- Verify repo accepts contributions
```

## Upstream Management Commands

### add-upstream

```bash
/tackle add-upstream steveyegge/gastown
```

1. Create a research cache bead for the new upstream:
   ```bash
   bd create \
     --title "Upstream research: steveyegge/gastown" \
     --type task \
     --label tackle-cache \
     --external-ref "upstream:steveyegge/gastown" \
     --description "# Pending initial research fetch"
   ```

2. Trigger initial research fetch (same as bootstrap refresh)

### list-upstreams

```bash
/tackle list-upstreams
```

Find all cache beads:
```bash
bd list --label=tackle-cache
```

Output:
```
Tracked Upstreams:
  steveyegge/beads     (primary, from git remote)
  steveyegge/gastown   (added manually)

Research cache status:
  hq-abc123 steveyegge/beads:    fresh (updated 2h ago)
  hq-def456 steveyegge/gastown:  stale (updated 26h ago)
```

### remove-upstream

```bash
/tackle remove-upstream steveyegge/gastown
```

1. Find and close the cache bead:
   ```bash
   CACHE_BEAD=$(bd list --label=tackle-cache --title-contains="steveyegge/gastown" --json | jq -r '.[0].id')
   bd close $CACHE_BEAD --reason="Upstream removed from tracking"
   ```
