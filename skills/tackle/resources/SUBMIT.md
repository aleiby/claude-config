# Submit Phase

Mark the draft PR as ready for review after gate-submit approval.

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
PR_NUMBER=$(gh pr list --repo <upstream> --head "$FORK_OWNER:$BRANCH" --json number --jq '.[0].number')
```

### 2. Mark Draft as Ready

```bash
gh pr ready $PR_NUMBER --repo <upstream-org>/<upstream-repo>
```

### 3. Verify PR is Ready

```bash
IS_DRAFT=$(gh pr view $PR_NUMBER --repo <upstream> --json isDraft --jq '.isDraft')
if [ "$IS_DRAFT" = "true" ]; then
  echo "ERROR: PR #$PR_NUMBER still in draft - gh pr ready may have failed"
  # Retry or investigate
  exit 1
fi

STATE=$(gh pr view $PR_NUMBER --repo <upstream> --json state --jq '.state')
echo "PR #$PR_NUMBER is $STATE and ready for review"
```

### 4. Capture Final PR URL

```bash
PR_URL=$(gh pr view $PR_NUMBER --repo <upstream-org>/<upstream-repo> --json url --jq '.url')
echo "PR submitted: $PR_URL"
```

## PR Title and Body Reference

If you need to update the PR before marking ready:

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

**IMPORTANT: Never reference local beads issue IDs (gt-xxx, hq-xxx) in upstream PRs.**
Local beads are internal tracking - they mean nothing to upstream maintainers.
Only reference GitHub issue numbers if they exist on the upstream repo.

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

