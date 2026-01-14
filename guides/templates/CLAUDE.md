# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Issue Tracking with Beads

This project uses **bd (beads)** for issue tracking. Run `bd onboard` for a quick introduction.

### Common Commands
- `bd ready` - Show issues ready to work (no blockers)
- `bd show <id>` - View issue details
- `bd update <id> --status in_progress` - Claim work
- `bd close <id>` - Mark complete
- `bd sync` - Sync with git remote

### Best Practices

**See comprehensive guide**: `~/.claude/guides/session-best-practices.md` for detailed explanations of:
- No TODOs in code (use bd issues instead)
- Future Work Gate pattern
- Label conventions
- Code quality principles

### Common Labels

Define your project's common labels here (examples):
- `frontend` - Frontend code
- `backend` - Backend code
- `testing` - Test infrastructure
- `docs` - Documentation

## Session Completion Protocol - MANDATORY

**CRITICAL**: Work is NOT complete until `git push` succeeds.

When ending ANY work session, you MUST complete ALL steps:

### 1. File Issues for Remaining Work
Create issues for anything needing follow-up:
```bash
bd create --title "..." --type task --priority 2
```

### 2. Run Quality Gates
```bash
# Add your project-specific quality gates here
# Examples:
# npm test
# npm run lint
# npm run build
# pytest
# cargo test
```

### 3. Update Issue Status
```bash
# Close completed issues (can close multiple at once)
bd close <id1> <id2> <id3>
```

### 4. PUSH TO REMOTE - MANDATORY
```bash
git pull --rebase
bd sync
git push
git status  # MUST show "up to date with origin"
```

### 5. Verify
- All changes committed: `git status` shows clean working tree
- All changes pushed: `git status` shows "up to date with origin"

### CRITICAL RULES
- **Work is NOT complete until `git push` succeeds**
- **NEVER stop before pushing** - work left locally will be lost
- **NEVER say "ready to push when you are"** - YOU must push
- **If push fails, resolve and retry until it succeeds**

### Why This Matters
- Local-only work is lost if machine fails
- Unpushed work is invisible to collaborators and CI/CD
- Multiple sessions without pushing creates merge conflicts
- Git is only useful when changes are in the remote repository

---

## Project-Specific Instructions

Add your project-specific guidance below:

### Commands

Document your project's build, test, and development commands here.

### Architecture Overview

Describe your project's architecture, key components, and design decisions.

### Code Style

Document coding conventions, patterns, and anti-patterns specific to this project.
