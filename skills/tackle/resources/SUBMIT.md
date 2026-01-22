# Submit Phase

Mark the draft PR as ready for review after gate-submit approval.

> **IMPORTANT: Never reference local beads issue IDs (gt-xxx, hq-xxx) in upstream PRs.**
> Local beads are internal tracking - they mean nothing to upstream maintainers.
> Only reference GitHub issue numbers if they exist on the upstream repo.

## Pre-Submit Checklist

Before this phase, verify gate-submit was approved (check that it's closed).

**Do not submit without approval.**

## Mark PR Ready

The draft PR was created during gate-submit (see SKILL.md for idempotent PR check).
Now we mark it ready for maintainer review.

### 1. Get PR Number

PR info should be available from the gate-submit step. If resuming:

```bash
BRANCH=$(git branch --show-current)
FORK_OWNER=$(gh repo view --json owner --jq '.owner.login')
PR_NUMBER=$(gh pr list --repo $ORG_REPO --head "$FORK_OWNER:$BRANCH" --json number --jq '.[0].number')
```

### 2. Mark Draft as Ready

```bash
gh pr ready $PR_NUMBER --repo $ORG_REPO
```

### 3. Verify PR is Ready

```bash
IS_DRAFT=$(gh pr view $PR_NUMBER --repo $ORG_REPO --json isDraft --jq '.isDraft')
if [ "$IS_DRAFT" = "true" ]; then
  echo "ERROR: PR #$PR_NUMBER still in draft - gh pr ready may have failed"
  # Retry or investigate
  exit 1
fi

STATE=$(gh pr view $PR_NUMBER --repo $ORG_REPO --json state --jq '.state')
echo "PR #$PR_NUMBER is $STATE and ready for review"
```

### 4. Capture Final PR URL

```bash
PR_URL=$(gh pr view $PR_NUMBER --repo $ORG_REPO --json url --jq '.url')
echo "PR submitted: $PR_URL"
```

## PR Title and Body Reference

If you need to update the PR before marking ready:

```bash
# Update title
gh pr edit $PR_NUMBER --repo $ORG_REPO --title "<new-title>"

# Update body
gh pr edit $PR_NUMBER --repo $ORG_REPO --body "<new-body>"
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

### What Gets Closed When?

**Molecule vs Issue - they're separate:**

| Thing | When to Close | Why |
|-------|---------------|-----|
| **Molecule** (gt-mol-xxx) | After reflect step | Workflow complete, PR submitted |
| **Issue/task bead** (hq-xxx) | After PR outcome | Work not done until fix is in upstream |

- Closing the molecule does NOT close the issue
- Issue gets `pr-submitted` label and `deferred` status until PR outcome is known
- PR outcomes are checked in step 6 (Check Pending PR Outcomes) on future tackle invocations

This separation allows tracking issues through the full lifecycle, even if PRs need revisions or take time to merge.

### 1. Update Local Issue

**Note:** `--notes` replaces existing notes (doesn't append). Include all info in one update:

```bash
# Count changed files and lines for the record
FILES_CHANGED=$(git diff --stat $UPSTREAM_REF | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+')
LINES_CHANGED=$(git diff --stat $UPSTREAM_REF | tail -1 | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | grep -oE '[0-9]+' | paste -sd+ | bc)

bd update <issue-id> \
  --add-label pr-submitted \
  --status=deferred \
  --notes="PR: $PR_URL
files: $FILES_CHANGED
lines: ~$LINES_CHANGED
submitted: $(date -Iseconds)"
```

The molecule and issue history provide the audit trail for learning.

### 2. Final Output

```
## PR Submitted

Issue:    hq-1234 - Fix doctor indentation
PR:       https://github.com/steveyegge/beads/pull/123
Status:   Awaiting review

To check PR status later:
  gh pr view 123 --repo steveyegge/beads
```

**⚠️ WORKFLOW NOT COMPLETE** - You must still complete the reflect step before you are done.

### 3. Advance to Reflect

```bash
bd close <record-step-id> --continue
```

Use `bd ready` to find the reflect step.

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

### PR Ready Fails

```
Error: gh pr ready failed

Possible causes:
- PR doesn't exist
- Network issue
- Permission denied

Solutions:
- Check PR exists: gh pr view $PR_NUMBER --repo <upstream>
- Retry: gh pr ready $PR_NUMBER --repo <upstream>
```

