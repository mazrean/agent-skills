---
name: writing-technical-design
description: Creates agent-optimized technical design documents backed by deep research of every technical component. Each component (library, framework, protocol, service) is investigated via web search / official docs and distilled into its own Agent Skill under skills/tech-{component}/, so future implementation sessions auto-load the relevant knowledge. Use when writing technical designs, architecture docs, defining system components, or making technology choices for spec-driven development.
---

# Writing Technical Design Documents

Create a technical design doc **plus** a set of per-component Agent Skills that capture the deep-research findings used to justify each technology choice. Implementation-time agents then auto-discover only the component skills relevant to the file they are editing.

**Use this skill when** designing how to build a feature, documenting architecture decisions, or making technology choices for spec-driven development.

**Supporting files:**
- [DEEP-RESEARCH.md](references/DEEP-RESEARCH.md) — research methodology, sources, per-category checklists.
- [COMPONENT-SKILLS.md](references/COMPONENT-SKILLS.md) — how to package each researched component as an Agent Skill.
- [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md) — layer mapping details.
- [EXAMPLES.md](references/EXAMPLES.md) — complete design doc + component skill examples.

## Outputs

Running this skill produces **two kinds of artifacts**:

```
specs/design-{feature}.md            # The design doc (L3 core + L4 rationale)
skills/tech-{component-1}/SKILL.md   # Auto-discovered research digest per component
skills/tech-{component-2}/SKILL.md
skills/tech-{component-n}/SKILL.md
```

Each `tech-{component}` skill is a **first-class Agent Skill** — Claude loads it automatically when the implementation task touches that component. The design doc itself stays slim: it points to the component skills instead of inlining their contents.

## Context Layer Distribution

```
Layer   What goes here                       File location
============================================================================
L1      Tech stack summary + feature ref     CLAUDE.md / AGENTS.md (constitution)
        "Go 1.23, Echo v4, PostgreSQL 16, sqlc"
        "specs/design-notifications.md - Notification architecture"

L2      Component-local coding constraints   .claude/rules/ or .github/instructions/
        "Handlers in this dir use async sender interface"

L3      Design body (this doc)               specs/design-{feature}.md
        Decision summary, component overview, interfaces, data model
L3'     Component research digests           skills/tech-{component}/SKILL.md
        Auto-discovered via skill metadata when editing related code

L4      Deep reference                       specs/design-{feature}.md (lower sections)
        Alternatives considered, migration plan, ADR rationale
L4'     Component deep reference             skills/tech-{component}/references/*.md
        API surface, edge cases, benchmark notes
============================================================================
```

## Workflow

```
1. Read the approved feature spec (skills/prd-{feature}/SKILL.md)
2. Draft the Decision Summary: list candidate technologies per decision area
3. DEEP RESEARCH each candidate and each confirmed component
   → see "Deep Research Phase" below
4. Record findings as skills/tech-{component}/SKILL.md (one skill per component)
5. Write the design doc (specs/design-{feature}.md) referencing those skills
6. Extract L2 coding constraints to .claude/rules/
7. Set status: "draft" → review → "approved"
```

## Deep Research Phase

This is the part that distinguishes this skill from a plain "write an architecture doc" prompt. **Do not skip it.** A design that names technologies without verifying their current behavior has an expiry date measured in months.

### Step 1 — Enumerate components to research

From the draft Decision Summary, extract every non-trivial technical element:

- Languages / runtimes (only if a version-specific feature is load-bearing)
- Frameworks and libraries (HTTP, ORM/query builder, template, queue client, ...)
- Databases and storage engines (features, version-specific SQL, index types)
- Protocols / external services (FCM, APNs, OAuth providers, payment gateways)
- Cross-cutting infrastructure (tracing, logging, feature flags)

Skip: generic primitives already covered by L1 tech stack, trivial glue code, anything the team has deep institutional knowledge of.

### Step 2 — Research each component

For each component, answer the checklist in [DEEP-RESEARCH.md](references/DEEP-RESEARCH.md). In short:

1. **Identity & version** — current stable version, release date, support status.
2. **Authoritative docs** — fetch the official reference, not blog posts.
3. **API surface you will actually use** — function/struct names, options, error types.
4. **Operational characteristics** — throughput, latency, memory, failure modes.
5. **Known pitfalls** — deprecated patterns, breaking changes, surprising defaults.
6. **Integration pattern** — idiomatic way to wire it into the stack chosen at L1.
7. **Alternatives rejected** — what else was on the table and why not.

Tool usage:

- Use **WebSearch** to locate current docs and recent release notes (always query with the current year).
- Use **WebFetch** to pull specific pages (official docs, RFCs, godoc, pkg pages) and summarize.
- Use the **Agent** tool (`subagent_type: general-purpose`) to parallelize research across components — launch one agent per component in a single message when they are independent. Instruct each agent to return a structured summary matching the skill template below.
- Prefer primary sources (official docs, source repos, RFCs) over secondary ones (blog posts, Stack Overflow). Blog posts are only acceptable when they describe measured behavior or a bug workaround.
- If a claim depends on version, state the version explicitly. Version-less claims rot.

### Step 3 — Package each component as an Agent Skill

Write one skill per researched component at `skills/tech-{component}/SKILL.md`. The detailed template and naming rules live in [COMPONENT-SKILLS.md](references/COMPONENT-SKILLS.md); minimal shape:

```markdown
---
name: tech-{component}
description: {One sentence on what the component is + when Claude should load it — e.g., "Use when implementing code under internal/notification/sender/ or any FCM/APNs delivery path."}
---

# {Component} — Research Digest

## TL;DR
{2-3 sentences on how we use it here and the single biggest trade-off.}

## Version & Source
- Version: {x.y.z} (as of YYYY-MM-DD)
- Docs: {URL}
- Repo: {URL}

## API We Use
{Code block: the exact functions / types / options we plan to call.}

## Operational Notes
- Throughput / latency expectations
- Failure modes and retry semantics
- Resource costs

## Pitfalls
- {Concrete gotcha} → {how we avoid it}

## Integration Pattern
{Snippet showing how it plugs into our stack.}

## References
- [references/API.md](references/API.md) — extended API surface (L4)
- [references/BENCHMARKS.md](references/BENCHMARKS.md) — measurements, if collected
```

**Why a skill, not a section in the design doc:** the design doc is read once during planning. The component skill is auto-loaded every time an agent edits code in that component's area, so the research pays off on every future implementation session.

## Template: `specs/design-{feature-name}.md`

The design doc itself stays lean. It **links to** the component skills instead of re-stating their contents.

```markdown
---
title: "Feature Name - Technical Design"
status: draft | review | approved | implementing | done
prd: skills/prd-feature-name/SKILL.md
component-skills:
  - skills/tech-redis-streams/SKILL.md
  - skills/tech-fcm-android/SKILL.md
  - skills/tech-apns-ios/SKILL.md
last-updated: YYYY-MM-DD
---

# Feature Name - Technical Design

## TL;DR

[2-3 sentences: Architecture approach and key trade-off.]

## Decision Summary

| Decision | Choice | Rationale | Research |
|----------|--------|-----------|----------|
| Async mechanism | Redis Streams | Already in stack, consumer groups | skills/tech-redis-streams/ |
| Android push   | FCM (firebase-admin-go) | Official SDK | skills/tech-fcm-android/ |
| iOS push       | APNs (sideshow/apns2)   | Lightweight, maintained | skills/tech-apns-ios/ |

## Component Overview

```text
[ASCII diagram: components and data flow]

Arrows: ──> sync  ══> async  ··> optional
```

### [Component Name]

- **Responsibility**: [Single sentence]
- **Location**: `path/to/component/`
- **Interface**: [Key method signatures]
- **Depends on**: [Other components]
- **Research**: `skills/tech-{name}/SKILL.md`

## Interface Contracts

```go
type OrderService interface {
    CreateOrder(ctx context.Context, req CreateOrderRequest) (*Order, error)
    GetOrder(ctx context.Context, id string) (*Order, error)
}
```

## Data Model

```sql
CREATE TABLE orders (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id),
    status     TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','processing','shipped','delivered')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Open Questions

- [ ] [Unresolved technical question] (@owner)

---
<!-- Below this line = L4 (deep reference) -->

## Alternatives Considered

### [Alternative Name]

- **Approach**: [Description]
- **Rejected because**: [Specific reason tied to requirements]
- **Research note**: see `skills/tech-{alternative}/SKILL.md` if a digest was produced

## Migration Plan

1. [Step] (rollback: [how to undo])

## ADR Log

| Date | Decision | Context | Consequences |
|------|----------|---------|--------------|
| YYYY-MM-DD | [What was decided] | [Why] | [Impact] |
```

## Writing Guidelines

### Decision Summary: Always Link to Research

Every non-trivial choice cites the component skill that backs it. Reviewers (and future agents) can follow the link to see *why* this version / library / pattern won, without the design doc bloating.

### Interface Contracts: Write as Code

Agents implement against interface contracts. Use real type definitions, not prose — prose requires interpretation, code is unambiguous.

### Data Model: DDL as Source of Truth

Write data models as executable DDL with CHECK constraints and indexes. Agents use these directly to create migration files.

### ASCII Diagrams

```text
──>  synchronous call
══>  asynchronous (event/queue)
··>  optional/conditional
─X─  blocked/denied
```

## L2 Integration: Extracting Component Rules

After the design is approved, pull the **imperative** constraints (not the rationale) into path-conditional rules:

```markdown
<!-- .claude/rules/notification-service.md -->
---
paths:
  - "internal/notification/**/*.go"
---

Notification service patterns (see specs/design-notifications.md and skills/tech-redis-streams/):
- Use NotificationSender interface for all delivery
- Never call FCM/APNs directly; go through sender abstraction
- Queue notifications via Redis Streams, never send in HTTP handler
```

The L2 rule links back to the component skill so that if the agent needs *why*, one hop reaches the research digest.

## Quality Checklist

```
Technical Design Quality Check:
- [ ] Links to feature spec PRD skill in frontmatter (prd field)
- [ ] component-skills list in frontmatter enumerates every tech-{x} skill produced
- [ ] TL;DR states architecture approach and key trade-off
- [ ] Decision Summary row cites a skills/tech-{x}/ digest for every non-trivial choice
- [ ] Every component has location, responsibility, interface, research link
- [ ] Interface contracts are code, not prose
- [ ] Data model is DDL with constraints
- [ ] ASCII diagram shows component relationships
- [ ] No requirements in this doc (those belong in feature spec)
- [ ] L4 separator between core design and deep reference
- [ ] Component patterns extracted to L2 rules
- [ ] Each tech-{x} skill has: version, authoritative doc URL, API we use, pitfalls
- [ ] Research claims state the version they were verified against
- [ ] File named: specs/design-{feature-name}.md
```

## Detailed Guides

- Research methodology and per-category checklists: [DEEP-RESEARCH.md](references/DEEP-RESEARCH.md)
- Component skill packaging (templates, naming, progressive disclosure): [COMPONENT-SKILLS.md](references/COMPONENT-SKILLS.md)
- Context layer mapping: [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
- Complete design doc + component skill examples: [EXAMPLES.md](references/EXAMPLES.md)
