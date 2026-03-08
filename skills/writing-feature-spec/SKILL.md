---
name: writing-feature-spec
description: Creates agent-optimized feature specifications (PRD) with context-layer-aware progressive disclosure. Use when writing product requirements, feature specs, user stories, acceptance criteria, or when starting spec-driven development for a new feature.
---

# Writing Feature Specs

Create feature specifications structured for coding agent context management. Information is distributed across context layers so agents load only what they need.

**Use this skill when** defining what to build and why, writing product requirements, user stories, or acceptance criteria.

**Supporting files:** [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md) for layer mapping details, [EXAMPLES.md](references/EXAMPLES.md) for complete examples.

## Context Layer Distribution

A feature spec's information spans multiple context layers:

```
Layer   What goes here              File location
======================================================================
L1      One-line feature reference  CLAUDE.md / AGENTS.md (constitution)
        "specs/prd-notifications.md - Push notification system"

L2      Code-area constraints       .claude/rules/ or .github/instructions/
        "Notification handlers must use async sender interface"

L3      Spec body (this doc)        specs/prd-{feature}.md
        Requirements, user stories, acceptance criteria

L4      Deep reference              specs/prd-{feature}.md (lower sections)
        Background, research, alternatives, edge case catalog
======================================================================

Loading cost:  L1 = every request    L2 = path match
               L3 = on demand       L4 = explicit read
```

## Template: `specs/prd-{feature-name}.md`

```markdown
---
title: Feature Name
status: draft | review | approved | implementing | done
priority: high | medium | low
depends-on: []
last-updated: YYYY-MM-DD
---

# Feature Name

## TL;DR

[1-3 sentences. Agent reads this to decide whether to load more.
Must answer: What capability? Who benefits? Why now?]

## Requirements

### Functional Requirements

- **FR-1**: [Imperative statement: "The system SHALL..."]
  - Acceptance: [Testable condition]
- **FR-2**: [Imperative statement]
  - Acceptance: [Testable condition]

### Non-Functional Requirements

- **NFR-1**: [Measurable quality attribute]
  - Metric: [Threshold, e.g., "p99 latency < 200ms"]

## User Stories

- As a [role], I want [action], so that [benefit]
  - Given [precondition], when [action], then [expected result]
  - Given [alt precondition], when [action], then [alt result]

## Constraints

- [Technical: e.g., must use existing auth middleware]
- [Business: e.g., must work on mobile viewports >= 375px]

## Non-Goals

- [Explicitly excluded scope item]
- [Another exclusion with reason or link to future spec]

## Open Questions

- [ ] [Unresolved question] (@owner)
- [x] [Resolved question] -> Decision: [answer]

---
<!-- Below this line = L4 (deep reference, loaded only when needed) -->

## Background

[Why this feature exists. Only read when requirements alone
are insufficient to understand intent. Keep under 300 words.]

## Research

[User research, data analysis, competitive analysis that
informed requirements. Agent rarely needs this.]

## Edge Cases

| Case | Expected Behavior | Requirement |
|------|-------------------|-------------|
| [Edge case 1] | [Behavior] | FR-1 |
| [Edge case 2] | [Behavior] | FR-2 |
```

## Writing Guidelines

### TL;DR: The 100-Token Gate

The TL;DR is the most important section. It determines whether the agent loads the rest of the document. It must be:

- **Self-contained**: Understandable without reading anything else
- **Decision-enabling**: Agent can determine relevance from this alone
- **Concrete**: Specific capability, not vague aspiration

```markdown
<!-- BAD: Vague, doesn't help agent decide relevance -->
## TL;DR
This document describes improvements to the notification system.

<!-- GOOD: Specific capability, clear scope, concrete benefit -->
## TL;DR
Real-time push notifications for order status changes (placed,
shipped, delivered). Reduces support ticket volume from users
manually checking order status. FCM for Android, APNs for iOS.
```

### Requirements: Atomic and Testable

Each requirement is a unit of implementation. Agents use requirements to:
1. Determine what code to write
2. Generate test cases from acceptance criteria
3. Verify completeness

```markdown
<!-- BAD: Compound, untestable -->
- **FR-1**: Handle notifications properly with good performance

<!-- GOOD: Atomic, testable, with acceptance criterion -->
- **FR-1**: The system SHALL deliver push notifications within 5 seconds
  of an order status change event.
  - Acceptance: Test device receives notification within 5s of
    status update via API call. Measured over 100 consecutive events.
```

### User Stories: Given-When-Then for Test Derivation

Agents directly convert Given-When-Then into test cases. Write them as executable specifications:

```markdown
- As a customer, I want to receive push notifications when my order ships
  - Given I have a confirmed order AND push notifications enabled,
    when the order status changes to "shipped",
    then I receive a notification with title "Order Shipped"
    and body containing the tracking number.
  - Given I have push notifications DISABLED,
    when the order status changes to "shipped",
    then NO notification is sent
    and the event is logged for later retrieval.
```

### Non-Goals: Preventing Agent Scope Creep

Agents will try to "improve" or "complete" features beyond scope. Non-goals are guardrails:

```markdown
## Non-Goals

- Email notification fallback (planned: specs/prd-email-notifications.md)
- Notification preferences UI (Phase 2, not yet specced)
- Rich media notifications (images, action buttons)
- SMS delivery channel
```

### The L4 Separator

Use a horizontal rule (`---`) and HTML comment to signal the boundary between L3 (core spec) and L4 (deep reference):

```markdown
## Open Questions
...

---
<!-- Below this line = L4 (deep reference, loaded only when needed) -->

## Background
...
```

This is a convention for agents: everything above the separator is the actionable spec; everything below is supporting context loaded only when the agent needs clarification.

## L1 Integration: Constitution Reference

After creating the spec, add a one-line reference to the project constitution:

```markdown
<!-- In CLAUDE.md or AGENTS.md, under "Active Specs" -->
## Active Specs

- `specs/prd-notifications.md` - Push notifications for order status
```

This costs ~20 tokens per feature but lets the agent discover relevant specs without searching.

## L2 Integration: Path-Conditional Rules

Extract code-area constraints from the spec into conditional rules:

```markdown
<!-- .claude/rules/notification-handlers.md -->
---
paths:
  - "internal/notification/**/*.go"
---

Notification handler rules (from specs/prd-notifications.md):
- All notifications must go through the NotificationSender interface
- Never send notifications synchronously in HTTP handlers
- Log all notification failures with structured error context
```

This way, when the agent edits notification code, it automatically gets the relevant constraints without loading the full spec.

## Lifecycle

```
1. Create specs/prd-{feature}.md with template
2. Write TL;DR first (forces clarity)
3. Add requirements with acceptance criteria
4. Add user stories in Given-When-Then
5. Define constraints and non-goals
6. Set status: "draft"
7. Add one-line reference to constitution (L1)
8. Review -> set status: "approved"
9. Create technical design (writing-technical-design skill)
10. Extract code-area rules to L2 files
11. During implementation -> set status: "implementing"
12. After completion -> set status: "done"
13. Remove L1 reference from constitution (save tokens)
```

## Quality Checklist

```
Feature Spec Quality Check:
- [ ] TL;DR answers what/who/why in under 3 sentences
- [ ] Every FR has a testable acceptance criterion
- [ ] User stories use Given-When-Then format
- [ ] Non-goals list at least one exclusion
- [ ] No implementation details (those belong in technical design)
- [ ] L4 separator present between core spec and deep reference
- [ ] One-line reference added to constitution (L1)
- [ ] Code-area constraints extracted to L2 rules
- [ ] File named: specs/prd-{feature-name}.md
- [ ] Frontmatter status is accurate
```

## Detailed Guides

**Context layer mapping details**: See [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
**Complete feature spec examples**: See [EXAMPLES.md](references/EXAMPLES.md)
