# Bootstrap Phase

First-time setup, molecule creation, and upstream research cache.

## Pre-Flight Checks

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

## Step 0: First-Time Setup

On first use in a rig, install the tackle formula.

### Check if Formula Installed

```bash
bd formula list | grep -q "^tackle " && echo "installed" || echo "not installed"
```

### Install Formula (if not present)

Copy formula from skill folder to the shared .beads/formulas/ (following redirect if present).

The formula is at `<skill-dir>/resources/tackle.formula.toml` (same directory as this file).
When reading this resource, you know the skill directory - use that path.

```bash
FORMULA_SRC="<skill-dir>/resources/tackle.formula.toml"

# Follow redirect if present to find shared .beads location
if [ -f ".beads/redirect" ]; then
  BEADS_DIR=$(cat .beads/redirect)
  # Resolve relative path
  BEADS_DIR=$(cd .beads && cd "$BEADS_DIR" && pwd)
else
  BEADS_DIR=".beads"
fi

FORMULA_DST="$BEADS_DIR/formulas/tackle.formula.toml"

if [ ! -f "$FORMULA_DST" ]; then
  mkdir -p "$BEADS_DIR/formulas"
  cp "$FORMULA_SRC" "$FORMULA_DST"
  echo "Installed tackle formula to $BEADS_DIR/formulas/"

  # Add to .gitignore if not already present (formula is recreatable)
  if ! grep -q "formulas/tackle.formula.toml" "$BEADS_DIR/.gitignore" 2>/dev/null; then
    echo "formulas/tackle.formula.toml" >> "$BEADS_DIR/.gitignore"
    echo "Added formula to .gitignore"
  fi
fi
```

## Step 1: Create or Resume Molecule

### Check for Attached Molecule

```bash
# Check if you already have a molecule attached
gt mol status
```

### Create New Molecule (if none attached)

```bash
# Create the molecule (requires --no-daemon flag)
bd --no-daemon mol pour tackle --var issue=<issue-id>
# Returns: ✓ Poured mol: created N issues
#          Root issue: gt-mol-xxxxx

# Attach molecule (auto-detects your agent bead from cwd)
gt mol attach <molecule-id>

# If you get "not pinned" error:
#   1. Find your agent bead: bd list --type=agent --title-contains="<your-name>"
#   2. Set to pinned: bd update <agent-bead-id> --status=pinned
#   3. Retry: gt mol attach <molecule-id>
```

This cooks the formula inline and creates step beads automatically.
Use `bd ready` to find next step.

### Resume Existing Molecule

If molecule already attached:
```bash
bd --no-daemon mol current  # Show current position
bd ready                    # Find next executable step
```

## Step 2: Detect Upstream

```bash
# Priority: upstream > fork-source > origin
UPSTREAM=$(git remote -v | grep -E '^upstream\s' | head -1 | awk '{print $2}')
if [ -z "$UPSTREAM" ]; then
  UPSTREAM=$(git remote -v | grep -E '^fork-source\s' | head -1 | awk '{print $2}')
fi
if [ -z "$UPSTREAM" ]; then
  UPSTREAM=$(git remote -v | grep -E '^origin\s' | head -1 | awk '{print $2}')
fi
```

Extract org/repo from URL:
```bash
# From: https://github.com/org/repo.git or git@github.com:org/repo.git
# To: org/repo
ORG_REPO=$(echo "$UPSTREAM" | sed -E 's#.*github.com[:/]([^/]+/[^/]+)(\.git)?$#\1#')
```

## Step 3: Check for Cached Research

Research cache bead IDs are stored in `.beads/config.yaml` for fast lookup.

```bash
# First, check config for cached bead ID (fast path)
CACHE_BEAD=$(yq ".tackle.cache_beads[\"$ORG_REPO\"]" .beads/config.yaml 2>/dev/null)

# Fallback to label search if not in config (slow path)
if [ -z "$CACHE_BEAD" ] || [ "$CACHE_BEAD" = "null" ]; then
  CACHE_BEAD=$(bd list --label=tackle-cache --title-contains="$ORG_REPO" --json | jq -r '.[0].id // empty')
fi

if [ -n "$CACHE_BEAD" ] && [ "$CACHE_BEAD" != "null" ]; then
  # Check freshness from bead's updated_at
  UPDATED=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].updated_at')
  # Compare with 24h threshold...
fi
```

## Step 4: Refresh Research (if stale or missing)

### Fetch CONTRIBUTING.md

```bash
# Get path and content
CONTRIB_PATH=$(gh api repos/$ORG_REPO/contents/CONTRIBUTING.md --jq '.path' 2>/dev/null || echo "")
if [ -n "$CONTRIB_PATH" ]; then
  # Note: base64 -d works on Linux, base64 -D or base64 --decode on macOS
  CONTRIB_CONTENT=$(gh api repos/$ORG_REPO/contents/CONTRIBUTING.md --jq '.content' | base64 --decode 2>/dev/null || base64 -d)
fi
```

### Fetch Recent PRs (for patterns)

```bash
RECENT_PRS=$(gh pr list --repo $ORG_REPO --state merged --limit 10 --json number,title,additions,deletions)
```

### Fetch Open PRs and Issues

```bash
OPEN_PRS=$(gh pr list --repo $ORG_REPO --state open --json number,title,headRefName)
OPEN_ISSUES=$(gh issue list --repo $ORG_REPO --state open --limit 30 --json number,title,labels)
```

### Distill Guidelines from CONTRIBUTING.md

Parse CONTRIBUTING.md and extract actionable requirements:

```yaml
# Distilled guidelines (store in bead description)
upstream: steveyegge/beads
contributing_path: CONTRIBUTING.md  # Path for reference

guidelines:
  coding_style:
    formatter: gofmt
    linter: go vet

  commits:
    tense: present  # "Add feature" not "Added"
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

# Raw caches (for fuzzy matching in context phase)
open_issues_json: |
  [...]
open_prs_json: |
  [...]
```

### Create or Update Cache Bead

```bash
if [ -z "$CACHE_BEAD" ]; then
  # Create new cache bead
  CACHE_BEAD=$(bd create \
    --title "Upstream research: $ORG_REPO" \
    --type task \
    --label tackle-cache \
    --external-ref "upstream:$ORG_REPO" \
    --description "$RESEARCH_YAML" \
    --json | jq -r '.id')
  echo "Created cache bead: $CACHE_BEAD"

  # IMPORTANT: Store bead ID in config immediately so we can find it later
  # Add to .beads/config.yaml under tackle.cache_beads
  # Example:
  #   tackle:
  #     cache_beads:
  #       steveyegge/gastown: gt-mzbwo
  #       steveyegge/beads: gt-abc123
else
  # Update existing cache bead
  bd update "$CACHE_BEAD" --description "$RESEARCH_YAML"
  echo "Updated cache bead: $CACHE_BEAD"
fi
```

### Store Cache Bead ID in Config

Immediately after creating a cache bead, store its ID in `.beads/config.yaml`:

```yaml
# .beads/config.yaml
tackle:
  cache_beads:
    steveyegge/gastown: gt-mzbwo
    steveyegge/beads: gt-abc123
```

This avoids searching by label on every run. To find the cache bead:
```bash
# Read from config instead of searching
CACHE_BEAD=$(yq '.tackle.cache_beads["steveyegge/gastown"]' .beads/config.yaml)
```

## Step 5: Advance Molecule

Close bootstrap step and advance:

```bash
bd close <bootstrap-step-id> --continue
```

Use `bd ready` to find the context step.

## Force Refresh

When `/tackle --refresh` is used:
1. Find cache bead: `bd list --label=tackle-cache --title-contains="$ORG_REPO"`
2. Re-fetch all upstream data
3. Update cache bead with fresh research

## Output

After bootstrap, report:
```
Upstream: steveyegge/beads
Research cache: hq-abc123 (refreshed 2h ago | refreshed now)
Guidelines: CONTRIBUTING.md at CONTRIBUTING.md
Molecule: hq-xyz789 (step: context)
```

Then proceed to context phase.

## Notes

- **Cache as bead**: Research stored in bead description, findable via `--label=tackle-cache`
- **CONTRIBUTING.md path**: Stored in distilled guidelines for future reference
- **Molecule ID**: Use whatever bd returns - don't assume naming convention
- **Freshness**: Check bead's `updated_at` vs 24h threshold
