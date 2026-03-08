# Cross-Agent File Placement Guide

How to place constitution files for different coding agents and multi-agent projects.

## Agent-Specific File Locations

### Claude Code

```
project-root/
├── CLAUDE.md                    # L1: Always loaded (primary)
├── CLAUDE.local.md              # L1: Always loaded (gitignored, personal)
├── .claude/
│   ├── CLAUDE.md                # L1: Alternative location
│   ├── settings.json            # Permissions
│   └── rules/                   # L2: Path-conditional rules
│       ├── api-handlers.md      # paths: ["internal/handler/**"]
│       └── db-repository.md     # paths: ["internal/repository/**"]
└── subdir/
    └── CLAUDE.md                # L2: Loaded when reading files in subdir
```

**Key behaviors:**
- Root CLAUDE.md: loaded every request, re-injected after context compression
- `.claude/rules/*.md`: loaded only when agent reads/edits matching paths
- Subdirectory CLAUDE.md: loaded when agent works in that directory
- `CLAUDE.local.md`: same as CLAUDE.md but gitignored (personal preferences)
- User-level `~/.claude/CLAUDE.md`: loaded for all projects

**Path-conditional rules format:**
```markdown
---
paths:
  - "internal/handler/**/*.go"
  - "internal/api/**/*.go"
---

Rules content here...
```

### Codex CLI (OpenAI)

```
project-root/
├── AGENTS.md                    # L1: Always loaded (primary)
├── AGENTS.override.md           # L1: Overrides AGENTS.md if present
├── subdir/
│   ├── AGENTS.md                # L1-L2: Concatenated by directory depth
│   └── AGENTS.override.md      # Overrides subdir AGENTS.md
└── ~/.codex/
    ├── AGENTS.md                # Global defaults
    └── AGENTS.override.md       # Global overrides
```

**Key behaviors:**
- Built once per session start (not reloaded mid-session)
- Files concatenated root-to-CWD with blank line separators
- Later files (closer to CWD) override earlier guidance
- Total size capped at 32 KiB (`project_doc_max_bytes`)
- `AGENTS.override.md` takes precedence at each level
- No path-conditional mechanism (use subdirectory AGENTS.md instead)

### Copilot CLI (GitHub)

```
project-root/
├── AGENTS.md                    # L1: Primary instructions
├── .github/
│   ├── copilot-instructions.md  # L1: Always loaded (repo-wide)
│   └── instructions/            # L2: Path-conditional
│       ├── api.instructions.md  # applyTo: "internal/handler/**/*.go"
│       └── db.instructions.md   # applyTo: "internal/repository/**/*.go"
└── ~/.copilot/
    └── copilot-instructions.md  # Global personal instructions
```

**Key behaviors:**
- Both `AGENTS.md` and `.github/copilot-instructions.md` are used if both exist
- `.github/instructions/*.instructions.md` with `applyTo` for conditional loading
- `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` env var for additional search directories
- Also reads `CLAUDE.md` and `GEMINI.md` at project root
- Changes take effect on next prompt submission

**Path-conditional format:**
```markdown
---
applyTo: "internal/handler/**/*.go,internal/api/**/*.go"
---

Rules content here...
```

## Multi-Agent Project Setup

For projects where multiple team members use different agents:

### Option 1: Shared File (Recommended)

Create `AGENTS.md` as the primary file (recognized by all three agents):

```
project-root/
├── AGENTS.md                     # Shared: Codex + Copilot + Claude
├── CLAUDE.md                     # Claude-specific additions (if needed)
├── .claude/rules/                # Claude L2 rules
│   └── *.md
└── .github/instructions/         # Copilot L2 rules
    └── *.instructions.md
```

Claude Code reads `AGENTS.md` as a fallback if `CLAUDE.md` doesn't exist. Copilot CLI reads both. Codex CLI reads `AGENTS.md` natively.

### Option 2: Symlink

```bash
# Create AGENTS.md as the source of truth
# Symlink for Claude Code
ln -s AGENTS.md CLAUDE.md
```

### Option 3: Separate Files with Shared Content

```markdown
<!-- CLAUDE.md -->
# Project Constitution
@AGENTS.md
<!-- Claude-specific additions below -->
...

<!-- AGENTS.md -->
# Project Constitution
[Shared content here]
```

Note: `@path` import syntax is Claude Code-specific.

## L2 Rule Equivalence Table

The same area-specific rule in each agent's format:

### Claude Code

```markdown
<!-- .claude/rules/api-handlers.md -->
---
paths:
  - "internal/handler/**/*.go"
---

- Use echo.Context for HTTP handling
- Return errors via echo.NewHTTPError()
```

### Copilot CLI

```markdown
<!-- .github/instructions/api-handlers.instructions.md -->
---
applyTo: "internal/handler/**/*.go"
---

- Use echo.Context for HTTP handling
- Return errors via echo.NewHTTPError()
```

### Codex CLI

```markdown
<!-- internal/handler/AGENTS.md -->
- Use echo.Context for HTTP handling
- Return errors via echo.NewHTTPError()
```

Note: Codex has no glob-based conditional loading. Use subdirectory `AGENTS.md` files instead, which are concatenated when working in that directory.

## Token Budget Comparison

| Agent | L1 Budget | L2 Mechanism | Compression |
|-------|-----------|-------------|-------------|
| Claude Code | ~200 lines recommended | `.claude/rules/` (paths) | Auto at 95%, CLAUDE.md re-injected |
| Codex CLI | 32 KiB hard limit | Subdirectory AGENTS.md | Per-session rebuild |
| Copilot CLI | No documented limit | `.github/instructions/` (applyTo) | Auto at 95% token limit |
