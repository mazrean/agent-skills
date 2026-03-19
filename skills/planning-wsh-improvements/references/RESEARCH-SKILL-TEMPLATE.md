# Research Skill Template

Generated research skills store deep knowledge about a specific WSH optimization topic. They are referenced by commands during execution.

## Directory Structure

```
.claude/skills/wsh-{topic}/
├── SKILL.md              # Main skill: overview, techniques, pitfalls
└── references/           # Optional: detailed docs if SKILL.md would exceed 500 lines
    └── {TOPIC}.md
```

## SKILL.md Template

```markdown
---
name: wsh-{topic}
description: {What this optimization covers and when to reference it. Include specific keywords for discoverability.}
---

# WSH: {Topic Title}

{1-2 sentences: what this optimization achieves and why it matters for Lighthouse scores.}

**Use this skill when** executing WSH commands related to {topic}, or when implementing {optimization type} in a performance-critical web app.

## Techniques

### {Technique 1}

{Concise explanation with code example adapted to the project's stack.}

```{language}
// Before
{problematic code pattern}

// After
{optimized code pattern}
```

**Impact**: {Which Lighthouse metrics improve and rough magnitude}

### {Technique 2}
...

## Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| {common mistake} | {what goes wrong} | {how to fix} |
| ... | ... | ... |

## VRT Risks

| Change | Visual Impact | Mitigation |
|--------|-------------|------------|
| {what you change} | {how it might look different} | {how to prevent/fix} |
| ... | ... | ... |

## Project-Specific Notes

{Notes specific to the analyzed WSH project — tech stack details, file structure conventions, relevant config.}
```

## Content Guidelines

### What to Include

- **Non-obvious techniques** — Things Claude wouldn't know without research
- **Specific API details** — Exact function signatures, config options, parameters
- **Compatibility notes** — "This works with React 19 but not 18" type details
- **Measured trade-offs** — "AVIF quality 50 = ~60% size reduction with minimal visual diff"
- **Project-specific context** — How the codebase structures things, naming conventions
- **VRT risk analysis** — Specific to this optimization and this project

### What NOT to Include

- Generic knowledge Claude already has (what React.lazy does, what gzip is, etc.)
- Specific file paths and line numbers (those go in the command, not the skill)
- Step-by-step execution instructions (those go in the command)
- Time-sensitive information

### Skill Size Guidelines

- **SKILL.md body**: Under 500 lines, ideally 100-300 lines
- If a topic needs more detail, split into `references/` files
- Each reference file should cover one subtopic completely

## Naming Conventions

| Topic | Skill Name |
|-------|-----------|
| Production build settings | `wsh-production-build` |
| Removing specific large dependency | `wsh-dependency-cleanup` |
| Image format conversion | `wsh-image-optimization` |
| Font subsetting and loading | `wsh-font-optimization` |
| Server compression and caching | `wsh-server-tuning` |
| Runtime CSS-in-JS removal | `wsh-runtime-css-removal` |
| Code splitting and lazy loading | `wsh-code-splitting` |
| React performance (memo, etc.) | `wsh-react-performance` |
| SSR implementation | `wsh-ssr-implementation` |
| Database query optimization | `wsh-query-optimization` |
| Bundler migration (Webpack→Vite) | `wsh-bundler-migration` |

Multiple commands can share one skill — e.g., removing 3 different bloated dependencies can all reference `wsh-dependency-cleanup`.

## Research Sources

When researching a topic, consult:

1. **Official documentation** — The tool/library's own docs
2. **Web search** — Recent articles, blog posts about the technique
3. **The project codebase** — How the code currently uses the relevant feature
4. **WSH competition context** — Past years' writeups and known patterns
5. **Lighthouse documentation** — How the relevant metric is calculated

Synthesize findings into actionable knowledge, not a link dump.
