# Research Phase

Bootstrap setup, upstream detection, and context search for related work.

## Section 1: Pre-Flight Checks & Setup

Before starting, verify environment:

```bash
# Check gh CLI is authenticated
gh auth status || echo "ERROR: gh CLI not authenticated. Run: gh auth login"

# Check git remotes exist
git remote -v | grep -q . || echo "ERROR: No git remotes configured"

# Check issue exists
bd show <issue-id> || echo "ERROR: Issue not found"
```

If any check fails, stop and resolve before proceeding.

### First-Time Setup: Install Formula

On first use in a rig, install the tackle formula.

```bash
# Check if installed
bd formula list | grep -q "^tackle " && echo "installed" || echo "not installed"
```

If not installed, copy from skill folder:

```bash
FORMULA_SRC="<skill-dir>/resources/tackle.formula.toml"

# Follow redirect if present to find shared .beads location
if [ -f ".beads/redirect" ]; then
  BEADS_DIR=$(cat .beads/redirect)
  BEADS_DIR=$(cd .beads && cd "$BEADS_DIR" && pwd)
else
  BEADS_DIR=".beads"
fi

FORMULA_DST="$BEADS_DIR/formulas/tackle.formula.toml"

if [ ! -f "$FORMULA_DST" ]; then
  mkdir -p "$BEADS_DIR/formulas"
  cp "$FORMULA_SRC" "$FORMULA_DST"
  echo "Installed tackle formula to $BEADS_DIR/formulas/"

  # Add to .gitignore if not already present
  if ! grep -q "formulas/tackle.formula.toml" "$BEADS_DIR/.gitignore" 2>/dev/null; then
    echo "formulas/tackle.formula.toml" >> "$BEADS_DIR/.gitignore"
  fi
fi
```

## Section 2: Upstream & Branch Detection

**CANONICAL DEFINITIONS** - Other resources reference this section.

### Upstream Detection

Priority: upstream > fork-source > origin

```bash
UPSTREAM_URL=$(git remote -v | grep -E '^upstream\s' | head -1 | awk '{print $2}')
[ -z "$UPSTREAM_URL" ] && UPSTREAM_URL=$(git remote -v | grep -E '^fork-source\s' | head -1 | awk '{print $2}')
[ -z "$UPSTREAM_URL" ] && UPSTREAM_URL=$(git remote -v | grep -E '^origin\s' | head -1 | awk '{print $2}')

# Extract org/repo from URL
# From: https://github.com/org/repo.git or git@github.com:org/repo.git
# To: org/repo
ORG_REPO=$(echo "$UPSTREAM_URL" | sed -E 's#.*github.com[:/]([^/]+/[^/]+)(\.git)?$#\1#')
```

### Default Branch Detection

```bash
DEFAULT_BRANCH=$(git remote show upstream 2>/dev/null | grep 'HEAD branch' | cut -d: -f2 | xargs)
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d: -f2 | xargs)
UPSTREAM_REF="upstream/$DEFAULT_BRANCH"
```

## Section 3: Molecule Management

### Check for Attached Molecule

```bash
gt mol status
```

### Create New Molecule (if none attached)

```bash
# Create the molecule (requires --no-daemon flag)
bd --no-daemon mol pour tackle --var issue=<issue-id>
# Returns: Root issue: gt-mol-xxxxx

# Add formula label for pattern detection in retro phase
bd update <molecule-id> --add-label "formula:tackle"

# Attach molecule (auto-detects your agent bead from cwd)
gt mol attach <molecule-id>

# If "not pinned" error:
#   1. Find your agent bead: bd list --type=agent --title-contains="<your-name>"
#   2. Set to pinned: bd update <agent-bead-id> --status=pinned
#   3. Retry: gt mol attach <molecule-id>
```

### Resume Existing Molecule

```bash
bd --no-daemon mol current  # Show current position
bd ready                    # Find next executable step
```

## Section 4: Cache Management

Research cache bead IDs are stored in `.beads/config.yaml` for fast lookup.

### Check for Cached Research

```bash
# Fast path: Check config for cached bead ID
CACHE_BEAD=$(yq ".tackle.cache_beads[\"$ORG_REPO\"]" .beads/config.yaml 2>/dev/null)

# Fallback: Label search if not in config
if [ -z "$CACHE_BEAD" ] || [ "$CACHE_BEAD" = "null" ]; then
  CACHE_BEAD=$(bd list --label=tackle-cache --title-contains="$ORG_REPO" --json | jq -r '.[0].id // empty')
fi

if [ -n "$CACHE_BEAD" ] && [ "$CACHE_BEAD" != "null" ]; then
  # Check freshness from bead's updated_at
  UPDATED=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].updated_at')
  # Compare with 24h threshold...
fi
```

### Refresh Research (if stale or missing)

#### Fetch CONTRIBUTING.md

```bash
CONTRIB_PATH=$(gh api repos/$ORG_REPO/contents/CONTRIBUTING.md --jq '.path' 2>/dev/null || echo "")
if [ -n "$CONTRIB_PATH" ]; then
  CONTRIB_CONTENT=$(gh api repos/$ORG_REPO/contents/CONTRIBUTING.md --jq '.content' | base64 --decode 2>/dev/null || base64 -d)
fi
```

#### Fetch PRs and Issues

```bash
RECENT_PRS=$(gh pr list --repo $ORG_REPO --state merged --limit 10 --json number,title,additions,deletions)
OPEN_PRS=$(gh pr list --repo $ORG_REPO --state open --json number,title,headRefName)
OPEN_ISSUES=$(gh issue list --repo $ORG_REPO --state open --limit 30 --json number,title,labels)
```

#### Distill Guidelines

Parse CONTRIBUTING.md and extract actionable requirements:

```yaml
upstream: steveyegge/beads
contributing_path: CONTRIBUTING.md

guidelines:
  coding_style:
    formatter: gofmt
    linter: go vet
  commits:
    tense: present
    max_length: 72
    reference_format: "(issue-id)"
  pull_requests:
    required_sections:
      - description
      - test plan
  testing:
    commands:
      - go test ./...
  build:
    command: go build ./...
  critical_rules:
    - "Run tests before submitting"
    - "Keep PRs focused and small"

patterns:
  avg_pr_size: 75
  reviewer: steveyegge

# Raw caches for fuzzy matching
open_issues_json: |
  [...]
open_prs_json: |
  [...]
```

### Create or Update Cache Bead

```bash
if [ -z "$CACHE_BEAD" ]; then
  CACHE_BEAD=$(bd create \
    --title "Upstream research: $ORG_REPO" \
    --type task \
    --label tackle-cache \
    --external-ref "upstream:$ORG_REPO" \
    --description "$RESEARCH_YAML" \
    --json | jq -r '.id')
  echo "Created cache bead: $CACHE_BEAD"

  # Store bead ID in config for fast lookup
  # Add to .beads/config.yaml under tackle.cache_beads
else
  bd update "$CACHE_BEAD" --description "$RESEARCH_YAML"
  echo "Updated cache bead: $CACHE_BEAD"
fi
```

## Section 5: Related Upstream Discovery

Parse the upstream README for dependencies or related projects:

```bash
# Fetch README
README=$(gh api repos/$ORG_REPO/contents/README.md --jq '.content' 2>/dev/null | base64 --decode 2>/dev/null || echo "")

# Look for dependencies/requirements sections
# Parse for github.com links or org/repo patterns
```

Present any related upstreams found for user review (see bootstrap gate in SKILL.md).

## Section 6: Context Search

### Load Issue Details

```bash
bd show <issue-id>
```

Extract: title, description, type, labels/tags.

### Load Research Cache

```bash
RESEARCH=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].description')
```

Extract:
- `open_issues_json`: for fuzzy issue matching
- `open_prs_json`: for fuzzy PR matching
- `guidelines`: for implementation conventions

### Check Fork Status

```bash
git fetch upstream 2>/dev/null || git fetch origin

# Commits behind upstream
git rev-list --count HEAD..$UPSTREAM_REF

# Recent commits ahead of fork
git log --oneline HEAD..$UPSTREAM_REF | head -20
```

Review commits for fixes related to our issue, changes in files we plan to modify.

### Fuzzy Search for Related Issues

```bash
echo "$RESEARCH" | yq '.open_issues_json' | jq '.[] | select(.title | test("keyword"; "i"))'
```

### Fuzzy Search for Related PRs

```bash
echo "$RESEARCH" | yq '.open_prs_json' | jq '.[] | select(.title | test("keyword"; "i"))'
```

## Section 7: Existing PR Handling

**Critical**: If a highly-relevant open PR exists that would fix our issue:

1. Transition to `existing-pr-check` phase
2. Present decision point

### Presenting Existing PR

When relevant PR found:

```
Found upstream PR #1234 that appears to address this issue:
  Title: Fix doctor indentation
  Status: Open (ready for review)
  Files: cmd/bd/doctor/database.go

What would you like to do?
  - Apply this PR locally and test it
  - Wait for it to merge upstream
  - Proceed with our own implementation
```

Accept natural language responses:
- "apply that PR and test it" / "test it locally" / "try it"
- "wait for it to merge" / "let's wait" / "hold off"
- "I'll implement my own" / "proceed anyway" / "do it myself"

### Apply PR Flow

1. Fetch the PR branch:
   ```bash
   gh pr checkout <number> --repo <upstream>
   ```

2. Run tests (from cached guidelines):
   ```bash
   go test ./...
   ```

3. If tests pass: report success, offer to close local issue
4. If tests fail: report failures, offer to fix or implement fresh

### Wait for Upstream Flow

```bash
bd update <issue-id> --status=blocked --notes="Blocked on upstream PR #1234"
```

Skill pauses. Resume when PR merges.

### Implement Anyway Flow

1. Note the existing PR for reference
2. Continue to plan phase
3. Consider coordinating with existing PR author

## Context Output

Present as **context only**, never suggestions:

```
## Upstream Context for <issue-id>

**Fork Status:**
Your fork is 12 commits behind upstream/main.

**Recent relevant commits:**
- abc1234 (3 days ago): "fix(doctor): improve error messages"
- def5678 (5 days ago): "refactor(cmd): standardize output"

**Related Issues:**
- #1234: "Doctor output formatting" (open) - similar area
- #1230: "CLI improvements" (closed) - may have patterns

**Related PRs:**
- #1235: "Fix doctor indentation" (open, draft)

**Guidelines (from CONTRIBUTING.md):**
- Commit format: present tense, max 72 chars
- Testing: `go test ./...`
- PR requires: description, test plan

This is context to inform your approach.
You are working on YOUR assigned issue: <issue-id>
```

## Never Do This

```
## Recommended Issues  <-- NEVER
- #1234 looks like a good starting point!  <-- NEVER
- Consider working on #1230 first  <-- NEVER
```

## Advancing Steps

After bootstrap:
```bash
bd close <bootstrap-step-id> --continue
```

After context:
```bash
bd close <context-step-id> --continue
```

Use `bd ready` to find the next step.

## Bootstrap Output

After bootstrap completes, report:
```
Upstream: steveyegge/beads
Research cache: hq-abc123 (refreshed 2h ago | refreshed now)
Guidelines: CONTRIBUTING.md found
Molecule: hq-xyz789 (step: context)
```

## Force Refresh

When `/tackle --refresh` is used:
1. Find cache bead via config or label search
2. Re-fetch all upstream data
3. Update cache bead with fresh research
