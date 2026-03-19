---
name: planning-wsh-improvements
description: Analyzes a Web Speed Hackathon project, researches each improvement topic in depth, stores research as Agent Skills, and generates executable Claude Code commands for each optimization. Use when starting WSH optimization, creating an optimization roadmap, or generating executable improvement commands.
---

# Planning WSH Improvements

Analyzes a Web Speed Hackathon project, identifies performance bottlenecks, researches each improvement topic in depth, stores findings as reusable Agent Skills, and generates executable Claude Code commands. Every command references the relevant skill and includes mandatory Lighthouse score check followed by VRT verification.

**Use this skill when** starting a WSH competition, creating an optimization plan, or when the user asks to generate improvement commands for a WSH project.

**Supporting files:**
- [COMMAND-TEMPLATE.md](references/COMMAND-TEMPLATE.md) — Template and rules for generated commands
- [IMPROVEMENT-CATALOG.md](references/IMPROVEMENT-CATALOG.md) — Known improvement patterns with priority/impact data
- [RESEARCH-SKILL-TEMPLATE.md](references/RESEARCH-SKILL-TEMPLATE.md) — Template for generated research skills

## Workflow

### Step 1: Analyze the Project

Before generating any plan, gather data:

1. **Read `package.json`** — Identify dependencies, build scripts, framework
2. **Read build config** — `webpack.config.*`, `vite.config.*`, `tsconfig.json`
3. **Read `docs/regulation.md`** or equivalent — Understand VRT and scoring rules
4. **Check server code** — Look for artificial delays, N+1 queries, missing compression
5. **Check bundle size** — Run `npm run build` if needed, inspect output
6. **Scan for known WSH traps** — See [IMPROVEMENT-CATALOG.md](references/IMPROVEMENT-CATALOG.md)
7. **Read VRT config** — `playwright.config.ts` or similar, understand how VRT runs
8. **Run Lighthouse baseline** — Measure and record scores for all scored pages before any changes
9. **Run VRT baseline** — Confirm VRT passes before any changes

### Step 2: Research & Generate Skills

For each identified improvement, conduct deep research and store the knowledge as an Agent Skill.

#### Research Process

For each improvement topic:

1. **Identify knowledge gaps** — What does Claude need to know beyond general knowledge to implement this specific optimization correctly in this project?
2. **Research the topic** using web search, documentation, and codebase analysis:
   - Official documentation for relevant tools/libraries
   - Known pitfalls and edge cases specific to this optimization
   - Compatibility with the project's tech stack (React version, bundler, etc.)
   - VRT implications — what visual changes this optimization might cause
   - Project-specific context — how the codebase uses the relevant code
3. **Synthesize findings** into a focused Agent Skill

#### Skill Generation

Create a skill directory at `.claude/skills/wsh-{topic}/` for each improvement topic. Follow the template in [RESEARCH-SKILL-TEMPLATE.md](references/RESEARCH-SKILL-TEMPLATE.md).

**When to create a skill vs. skip:**
- **Create** when the topic has non-obvious details, pitfalls, or project-specific nuances
- **Create** when the optimization requires understanding of specific APIs, configs, or patterns
- **Skip** when the optimization is trivially simple (e.g., deleting one line)

**Skill naming**: `wsh-{topic}` (e.g., `wsh-avif-conversion`, `wsh-tree-shaking`, `wsh-preact-migration`)

**Skill content should include:**
- Specific techniques and their trade-offs
- Code patterns and examples adapted to this project's stack
- Known pitfalls and how to avoid them
- VRT risk factors and mitigation strategies
- References to official documentation

**Do NOT include in the skill:**
- Generic knowledge Claude already has
- Information that will be in the command itself (specific file paths, line numbers)
- Time-sensitive information

#### Example: Research for Image Optimization

If the project has oversized PNG images:

1. Research: AVIF vs WebP quality/size trade-offs, Sharp API for batch conversion, `<picture>` element with fallbacks, how the project's image pipeline works
2. Generate skill at `.claude/skills/wsh-image-optimization/SKILL.md`:
   - AVIF encoding parameters for best size/quality balance
   - Sharp CLI commands for batch conversion
   - How to update image references in the project's component structure
   - VRT pitfalls: color profile shifts, transparency handling, quality thresholds

### Step 3: Prioritize Improvements

Score each potential improvement:
- **Impact**: Estimated Lighthouse score gain (from IMPROVEMENT-CATALOG.md)
- **Risk**: VRT failure risk (Low / Medium / High)
- **Effort**: Implementation complexity (Small / Medium / Large)

Sort by: Impact (descending) → Risk (ascending) → Effort (ascending)

### Step 4: Generate the Plan Document

Create a plan document at `.claude/wsh-plan.md`:

```markdown
# WSH Improvement Plan

Generated: {date}
Baseline VRT: PASS / FAIL
Estimated Total Impact: +{X} pts

## Lighthouse Baseline

| Page | FCP | SI | LCP | TBT | CLS | Score |
|------|-----|-----|-----|-----|-----|-------|
| / | {ms} | {ms} | {ms} | {ms} | {val} | {score} |
| {page} | ... | ... | ... | ... | ... | ... |

Total baseline: {sum} pts

## Improvements (Priority Order)

| # | Command | Skill | Category | Est. Impact | Risk | Effort |
|---|---------|-------|----------|-------------|------|--------|
| 1 | /wsh-001-{name} | wsh-{topic} | Bundle | +{X} pts | Low | Small |
| 2 | /wsh-002-{name} | wsh-{topic} | Image | +{X} pts | Medium | Medium |
| ... | ... | ... | ... | ... | ... | ... |

## Generated Skills

| Skill | Location | Covers |
|-------|----------|--------|
| wsh-{topic} | .claude/skills/wsh-{topic}/ | {brief description} |
| ... | ... | ... |

## Execution Notes

- Run commands in order (highest impact first)
- Each command references its skill for implementation knowledge
- Flow per command: Changes → Build → Lighthouse → VRT → Commit → PR
- Assumes a dedicated improvement branch is already checked out
- If VRT fails, the command will guide you through resolution
- Each successful command produces a PR with Lighthouse results
```

### Step 5: Generate Commands

For each improvement, create a command file at `.claude/commands/wsh-{NNN}-{name}.md`.

**Command naming**: `wsh-{3-digit-number}-{short-name}`
- Number indicates priority order (001 = highest priority)
- Short name describes the optimization

**Every command MUST:**
1. **Reference its skill** — Include a line telling Claude to read the relevant skill for background knowledge
2. **Follow the template** in [COMMAND-TEMPLATE.md](references/COMMAND-TEMPLATE.md)
3. **Have clear scope** — Exactly ONE improvement per command
4. **Include concrete steps** — Specific files, line numbers, changes
5. **Build verification** — Must build successfully
6. **Lighthouse score check** — Measure score impact on affected pages BEFORE VRT
7. **VRT gate** — MUST run VRT and handle results
8. **Commit & PR** — Commit on VRT pass, push, and create a PR with Lighthouse results and VRT status

### Step 6: Verify and Report

After generating all skills and commands:

1. List generated skills: `ls .claude/skills/wsh-*/SKILL.md`
2. List generated commands: `ls .claude/commands/wsh-*.md`
3. Present the plan summary to the user
4. Instruct: "Run `/wsh-001-{name}` to start the first improvement"

## Important Rules

- **Never skip VRT in any generated command** — Non-negotiable
- **Always run Lighthouse before VRT** — Confirm score improvement, then confirm visual integrity
- **Always commit and create PR after VRT passes** — Assumes improvement branch is already checked out
- **One improvement per command** — Atomic and bisectable
- **Research before generating** — Every non-trivial command should have a backing skill
- **Skills contain knowledge, commands contain actions** — Keep this separation clean
- **Commands must be self-contained** — Include all context needed (referencing the skill for background)
- **Include rollback guidance** — If VRT fails, guide revert
- **Reference specific files and line numbers** — No vague instructions
- **Adapt to the project** — Read the actual codebase
- **Check regulation** — Exclude rule-violating optimizations

## Example Output Structure

```
.claude/
├── wsh-plan.md                              # The plan document
├── skills/
│   ├── wsh-production-build/
│   │   └── SKILL.md                         # Research: production mode, source maps, minification
│   ├── wsh-dependency-cleanup/
│   │   ├── SKILL.md                         # Research: bloated deps in this project
│   │   └── references/
│   │       └── REPLACEMENTS.md              # Detailed replacement strategies
│   ├── wsh-image-optimization/
│   │   └── SKILL.md                         # Research: AVIF conversion, lazy loading
│   └── wsh-runtime-css-removal/
│       └── SKILL.md                         # Research: UnoCSS runtime → static CSS
├── commands/
│   ├── wsh-001-production-mode.md           # Command referencing wsh-production-build
│   ├── wsh-002-remove-ffmpeg.md             # Command referencing wsh-dependency-cleanup
│   ├── wsh-003-remove-iconify.md            # Command referencing wsh-dependency-cleanup
│   ├── wsh-004-avif-images.md               # Command referencing wsh-image-optimization
│   └── wsh-005-static-css.md               # Command referencing wsh-runtime-css-removal
```

Note: Multiple commands can reference the same skill (e.g., several dependency removals share one skill).
