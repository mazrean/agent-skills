---
name: creating-agent-skills
description: Creates well-structured Agent Skills following best practices. Use when building new skills for Claude Code, designing skill directory structures, writing SKILL.md files, or improving existing skills with progressive disclosure patterns.
---

# Creating Agent Skills

Agent Skills extend Claude's capabilities with specialized knowledge and workflows. This skill helps you create effective skills that follow best practices.

**Use this skill when** creating new skills, improving existing ones, or designing skill architecture for projects.

**Supporting files:** [SPECIFICATION.md](references/SPECIFICATION.md) for format details, [BEST-PRACTICES.md](references/BEST-PRACTICES.md) for authoring guidelines, [TEMPLATES.md](references/TEMPLATES.md) for starter templates.

## Quick Start

Create a skill directory with SKILL.md:

```
my-skill/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: detailed docs
└── assets/           # Optional: templates, resources
```

## SKILL.md Structure

```yaml
---
name: skill-name          # lowercase, hyphens only, max 64 chars
description: What it does and when to use it.  # max 1024 chars
---

# Skill Title

Brief intro and "Use this skill when..." statement.

## Quick Start
[Most common use case with example]

## Core Features
[Main capabilities organized by task]

## Support Files
[Links to reference files for detailed info]
```

## Naming Conventions

Use **gerund form** (verb + -ing) for clarity:
- `processing-pdfs` (preferred)
- `analyzing-data` (preferred)
- `pdf-processor` (acceptable)

**Rules:**
- Lowercase letters, numbers, hyphens only
- No consecutive hyphens (`--`)
- Cannot start/end with hyphen
- Max 64 characters

## Writing Descriptions

Descriptions drive skill discovery. Include:
1. **What** it does (actions/capabilities)
2. **When** to use it (triggers/contexts)

**Good:**
```yaml
description: Extracts text and tables from PDF files, fills forms, merges documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.
```

**Bad:**
```yaml
description: Helps with PDFs.  # Too vague
```

**Always use third person** (description is injected into system prompt).

## Progressive Disclosure

Keep SKILL.md under 500 lines. Split content strategically:

1. **Metadata** (~100 tokens): Loaded at startup for all skills
2. **SKILL.md body** (<5000 tokens): Loaded when skill activates
3. **Reference files**: Loaded only when needed

```markdown
## Detailed Topics

**Form filling**: See [FORMS.md](references/FORMS.md)
**API reference**: See [REFERENCE.md](references/REFERENCE.md)
**Examples**: See [EXAMPLES.md](references/EXAMPLES.md)
```

## Key Principles

1. **Be concise**: Claude is smart; only add context it doesn't have
2. **Test with all models**: What works for Opus may need detail for Haiku
3. **Use workflows**: Break complex tasks into clear, sequential steps
4. **Include feedback loops**: Validate → fix → repeat for quality
5. **Avoid time-sensitive info**: Use "old patterns" sections instead

## Checklist

Before finalizing a skill:
- [ ] Name uses lowercase/hyphens, matches directory name
- [ ] Description explains what AND when
- [ ] SKILL.md under 500 lines
- [ ] Reference files for detailed content
- [ ] Examples are concrete, not abstract
- [ ] Tested with real usage scenarios

## Resources

- [Agent Skills Specification](https://agentskills.io/specification)
- [Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Example Skills](https://github.com/anthropics/skills)
