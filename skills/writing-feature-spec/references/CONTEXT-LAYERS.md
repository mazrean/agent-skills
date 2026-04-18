# Feature Spec Context Layer Mapping (Agent Skill Edition)

Detailed guide on distributing feature spec information across context layers when the PRD is an Agent Skill.

## The Four-Layer Model

```
                    Token Cost
Layer   Frequency   Per Request   Purpose
=============================================
L1      Every req   ~20 tokens    Feature discovery (automatic via skill metadata)
L2      Path match  ~100 tokens   Code-area constraints
L3      On demand   ~500 tokens   Implementation reference (SKILL.md body)
L4      Explicit    ~300 tokens   Clarification & context (reference files)
=============================================
```

## L1: Skill Metadata (Automatic)

**What goes here:** The `name` and `description` fields in SKILL.md frontmatter.

**Why:** Claude's skill system automatically loads metadata for all installed skills. The `description` field is used for skill discovery — Claude reads it to decide whether to activate the skill.

**Key advantage over plain files:** No manual constitution entry needed. The skill system handles L1 automatically.

**Format in SKILL.md frontmatter:**
```yaml
---
name: prd-notifications
description: PRD for push notifications on order status changes (FCM/APNs). Use when implementing notification handlers, order status events, or device token management.
---
```

**Token cost:** ~20 tokens per skill (name + description only). The body is NOT loaded until the skill activates.

**When metadata is loaded:** Every request (part of skill index).
**When body is loaded:** Only when Claude determines the skill is relevant.

## L2: Path-Conditional Constraints

**What goes here:** Code-area rules derived from feature requirements that the agent must follow when editing specific files.

**Why:** Some requirements translate directly into coding constraints. Loading these only when the agent touches relevant code saves context.

**Source:** Extract from `references/RULES.md` after spec approval.

**Example extraction from spec:**

Feature spec says:
```markdown
- **FR-3**: Notifications must be delivered asynchronously. The HTTP
  handler must not block on notification delivery.
```

Extracted L2 rule (`.claude/rules/notification-handlers.md`):
```markdown
---
paths:
  - "internal/handler/**/*.go"
---

From skills/prd-notifications/SKILL.md:
- Never send notifications synchronously in HTTP handlers
- Use the async NotificationSender interface
- API response time budget: existing baseline + max 10ms
```

**What NOT to extract:** Requirements that apply during implementation planning (not coding). Those stay in L3 (SKILL.md body).

## L3: SKILL.md Body (Core Content)

**What goes here:** The main spec content loaded when Claude activates the skill.

**Content and ordering (optimized for early-exit reading):**

```
1. TL;DR (100 tokens)
   Claude reads this after activation. Confirms relevance.

2. Requirements (300 tokens)
   Claude reads when implementing. Each FR is a unit of work.

3. User Stories (200 tokens)
   Claude reads when writing tests or understanding user flow.

4. Constraints (100 tokens)
   Claude reads to understand boundaries.

5. Non-Goals (100 tokens)
   Claude reads to avoid scope creep.

6. Open Questions (50 tokens)
   Claude reads when encountering ambiguity.

7. Deep Reference links (~20 tokens)
   Pointers to reference files for L4 content.
```

**Total L3 budget:** ~870 tokens for the core spec. Loaded once when the skill activates.

## L4: Reference Files (Deep Context)

**What goes here:** Supporting context in `references/` directory that Claude loads only when needed.

**Files:**
- `BACKGROUND.md` — Why this feature exists, research data, edge cases
- `RULES.md` — Code-area constraints to extract to L2

**Loading trigger:** Claude loads L4 content when:
- A requirement seems contradictory and needs context
- An edge case arises during implementation
- Claude needs to understand "why" behind a decision
- Code-area constraints need to be set up (RULES.md)

## Decision Flow: Which Layer?

```
Is this information needed for EVERY agent request?
├─ Yes → L1 (skill metadata — automatic)
│        BUT: only name + description, not details
└─ No
   │
   Is this triggered by editing specific files?
   ├─ Yes → L2 (path-conditional rules)
   │        Extract from references/RULES.md to .claude/rules/
   └─ No
      │
      Is this needed to implement the feature?
      ├─ Yes → L3 (SKILL.md body)
      │        Requirements, user stories, constraints
      └─ No → L4 (reference files)
               Background, research, edge cases
```

## Example: Full Layer Distribution

Feature: "Push notifications for order status changes"

### L1 (automatic — SKILL.md frontmatter):
```yaml
name: prd-notifications
description: PRD for push notifications on order status changes (FCM/APNs). Use when implementing notification handlers, order status events, or device token management.
```

### L2 (in .claude/rules/notification-code.md — extracted from RULES.md):
```markdown
---
paths:
  - "internal/notification/**/*.go"
  - "internal/handler/order*.go"
---

Notification constraints (from skills/prd-notifications/SKILL.md):
- Async delivery only; never block HTTP handlers
- Use NotificationSender interface
- All failures must be logged with structured context
- Respect user notification preferences before sending
```

### L3 (in skills/prd-notifications/SKILL.md body):
```markdown
## TL;DR
Real-time push notifications for order status changes...

## Requirements
- FR-1: Send push within 5s of status change
  - Acceptance: Measured over 100 events on test device
- FR-2: Support FCM (Android) and APNs (iOS)
  ...

## User Stories
- As a customer, Given order status changes to "shipped"...

## Constraints
- Must use existing auth middleware
- Must not increase API response time > 10ms

## Non-Goals
- Email notifications (separate spec)
- SMS fallback

## Open Questions
- [ ] Batch rapid status changes? (@product)

## Deep Reference
See [BACKGROUND.md](references/BACKGROUND.md)
See [RULES.md](references/RULES.md)
```

### L4 (in skills/prd-notifications/references/):

**BACKGROUND.md:**
```markdown
## Background
Support tickets show 40% are "where is my order?" questions.
Push notifications would reduce this by an estimated 60%.

## Edge Cases
| Case | Behavior | FR |
|------|----------|-----|
| User disabled notifications | Skip, log event | FR-4 |
| Device token expired | Remove token, log | FR-5 |
```

**RULES.md:**
```markdown
## Constraints
- Async delivery only; never block HTTP handlers
- Use NotificationSender interface

## L2 Extraction Target
Extract to .claude/rules/notification-code.md with paths...
```
