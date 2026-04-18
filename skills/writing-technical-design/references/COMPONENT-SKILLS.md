# Component Skills: Packaging Research as Agent Skills

Every non-trivial technical component identified during design gets its own Agent Skill. This file specifies **naming, directory layout, templates, and discovery semantics** so the skills are actually loaded when implementation begins.

## Why an Agent Skill (not a doc section)

A section inside `specs/design-{feature}.md` is read once — during planning. A file under `skills/tech-{component}/` is **auto-discovered** whenever the skill's `description` matches the current task. That means the research pays off on every future implementation, review, debug, or refactor that touches the component, not just on the day the design was written.

Trade-off: one more file per component. Acceptable, because the design doc stays under a reasonable size and each skill is independently updatable.

## Naming

```
skills/tech-{component}/SKILL.md
```

- Prefix `tech-` groups all component research digests.
- `{component}` is lowercase, hyphens only, reflects the user-facing name:
  - `tech-redis-streams` (not `tech-redis`)
  - `tech-fcm-android`
  - `tech-apns-ios`
  - `tech-sqlc`
  - `tech-postgres-partial-indexes` — when the *feature*, not the whole product, is the point
- If multiple features share the same component, one skill is enough. Keep a single `tech-{component}` and update it; do not fork.

Name rules (inherited from the Agent Skill spec): lowercase, hyphens, no leading/trailing hyphen, no `--`, max 64 chars.

## Directory Layout

```
skills/tech-{component}/
├── SKILL.md             # Required: ~300 lines max, core digest (L3')
└── references/          # Optional: deep reference (L4')
    ├── API.md           # Full API surface if the SKILL.md subset is not enough
    ├── BENCHMARKS.md    # Measurements collected during research
    └── MIGRATION.md     # Version-upgrade notes, if relevant
```

Keep `SKILL.md` focused on what an agent needs to **write correct code right now**. Anything needed only for review / debugging / migration goes to `references/`.

## SKILL.md Template

```markdown
---
name: tech-{component}
description: {Component} research digest. Use when implementing, reviewing, or debugging code that calls {component} — e.g., files under {path-pattern}, or tasks mentioning {keyword-pattern}.
---

# {Component Name} — Research Digest

## TL;DR

{2-3 sentences. What this component is, how we use it, the single most important trade-off or constraint.}

## Identity

- **Version**: {x.y.z} (verified YYYY-MM-DD)
- **License**: {SPDX id}
- **Docs**: {URL to authoritative reference}
- **Source**: {repo URL}
- **Minimum runtime**: {e.g., Go 1.22+}

## API We Use

The subset we actually call — not the whole library.

```{lang}
// exact signatures, copied from godoc / typedoc / official reference
```

## Operational Notes

- **Throughput**: {number or "not characterized — plan to measure"}
- **Latency**: {number + percentile}
- **Failure modes**: {what breaks, how it surfaces}
- **Retry semantics**: {what the component does vs. what we add}
- **Resource cost**: {memory / connections / file handles}

## Pitfalls

- **{Gotcha}** → {avoidance rule}. *Source: {doc anchor / issue URL}*.
- **{Gotcha}** → {avoidance rule}.

## Integration Pattern

```{lang}
// idiomatic wiring into the project's stack
```

Explain in 1-2 sentences why this shape, not another.

## Alternatives Considered

- **{Alternative}** — rejected because {reason}. (One line each; full rationale lives in the design doc's Alternatives section.)

## Confidence

- **High**: {what we trust fully, and why}
- **Medium**: {what we believe but could not fully verify}
- **Low**: {what we are guessing at; flag for staging verification}

## References

- [references/API.md](references/API.md) — extended API surface
- [references/BENCHMARKS.md](references/BENCHMARKS.md) — measurements
```

## Writing the `description` (Discovery-Critical)

The `description` field decides whether Claude loads this skill on a future task. Two things must be present:

1. **What the component is** — so the reader knows the skill is about `redis-streams`, not `redis` generally.
2. **When to use it** — either a path pattern (`files under internal/notification/sender/`) or a topic pattern (`tasks mentioning push notifications, FCM, or APNs`).

Good:

```yaml
description: Redis Streams research digest (v7.2). Covers XADD, XREADGROUP, XACK, XAUTOCLAIM, idle-pending recovery, and MAXLEN trimming. Use when implementing producers or consumers under internal/notification/consumer/ or any code calling go-redis Stream* methods.
```

Bad:

```yaml
description: Info about Redis.  # Too vague — will not be discovered reliably.
```

Always third-person (the description is injected into the system prompt).

## Progressive Disclosure Policy

- **SKILL.md body**: ≤ ~300 lines. Agent implementation context. Loaded when the skill matches.
- **references/\*.md**: loaded on demand. Use for extended API tables, benchmark CSVs, migration playbooks.
- If SKILL.md grows past 300 lines, move sections to `references/` and replace them with a one-line pointer. The digest is a map, not the territory.

## Keeping Digests Fresh

Every SKILL.md has `Version` and `verified YYYY-MM-DD` in the Identity block. Treat as stale when:

- The component releases a new major version.
- A CVE is issued against the pinned version.
- The `verified` date is more than ~9 months old.
- An implementation agent observes behavior that contradicts the digest.

**Refresh in place** — update the existing skill rather than creating `tech-foo-v2`. Bump the `verified` date and, if behavior changed, add a "Changed since last review" subsection at the top.

## Linking From the Design Doc

The design doc's frontmatter enumerates all component skills:

```yaml
---
title: "Push Notifications - Technical Design"
component-skills:
  - skills/tech-redis-streams/SKILL.md
  - skills/tech-fcm-android/SKILL.md
  - skills/tech-apns-ios/SKILL.md
---
```

The Decision Summary table cites the skill in the `Research` column, and each Component Overview entry has a `Research:` line pointing to its skill. This means reviewers can follow the trail: *design decision → research digest → primary source*.

## Linking From L2 Rules

When extracting L2 coding constraints, cite the component skill so agents can reach the rationale in one hop:

```markdown
<!-- .claude/rules/notification-service.md -->
---
paths:
  - "internal/notification/**/*.go"
---

Notification service patterns:
- Queue via Redis Streams, never send inline in an HTTP handler.
  Research: skills/tech-redis-streams/SKILL.md
- Use firebase-admin-go's Messaging client, not raw HTTP to FCM.
  Research: skills/tech-fcm-android/SKILL.md
```

## Anti-Patterns

- **Writing a digest without a version.** Future agents cannot tell whether the API signatures are still current.
- **Copying the entire official docs.** The digest is the *subset we use*, with pitfalls we identified. A mirror of the docs is worse than a link to the docs.
- **Skipping the Confidence block.** Unstated uncertainty becomes stated certainty the next time someone reads it.
- **One skill per feature instead of per component.** If `feature A` and `feature B` both use Redis Streams, one `tech-redis-streams` skill serves both.
- **Prose where code belongs.** API signatures, integration snippets, and DDL all go in as code, not prose descriptions.
