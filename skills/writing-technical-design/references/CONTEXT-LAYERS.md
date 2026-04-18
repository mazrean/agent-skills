# Technical Design Context Layer Mapping

Detailed guide on distributing technical design information across context layers.

## Layer Distribution for Design Documents

```
                    Token Cost
Layer   Frequency   Per Request   Purpose
=============================================
L1      Every req   ~30 tokens    Tech stack + feature ref
L2      Path match  ~150 tokens   Component-local patterns
L3      On demand   ~800 tokens   Architecture decisions
L4      Explicit    ~500 tokens   Rationale & alternatives
=============================================
```

## L1: Tech Stack in Constitution

**What goes here:** Technology choices as single lines. The agent needs to know the stack to make consistent decisions.

```markdown
## Tech Stack

- Language: Go 1.23
- HTTP: Echo v4
- Database: PostgreSQL 16 via sqlc
- Queue: Redis Streams
- Frontend: templ + htmx
```

**Plus** a one-line reference to the design doc:
```markdown
## Active Specs

- `specs/design-notifications.md` - Notification architecture
```

**Note:** The PRD is an Agent Skill (`skills/prd-{feature}/SKILL.md`) and is auto-discovered via skill metadata — no L1 entry needed for it. Only the design doc needs a constitution reference.

**Why in L1:** Tech stack choices affect every coding decision. An agent must know "use sqlc, not raw SQL" on every request.

## L2: Component Patterns as Path Rules

**What goes here:** Architecture patterns that apply when editing specific code areas.

**Extraction process:**

1. Read the design doc's Component Overview
2. For each component with clear patterns, create an L2 rule
3. Include only actionable coding constraints, not rationale

**Example extraction:**

Design doc says:
```markdown
### Notification Sender
- **Responsibility**: Delivers push notifications via FCM/APNs
- **Location**: `internal/notification/sender/`
- **Interface**: `Send(ctx, userID, Notification) error`
- **Depends on**: `internal/notification/template/`, FCM SDK
```

Decision Summary says:
```markdown
| Queue | Redis Streams | Already in stack, sufficient throughput |
```

Extracted L2 rule:
```markdown
<!-- .claude/rules/notification-service.md -->
---
paths:
  - "internal/notification/**/*.go"
---

Architecture patterns (specs/design-notifications.md):
- All notifications go through NotificationSender interface
- Never call FCM/APNs SDKs directly outside sender/
- Queue via Redis Streams; never send synchronously
- Use structured logging (slog) for all operations
- Template rendering in template/ package, not in sender/
```

### What to Extract vs. Keep in L3

| Extract to L2 | Keep in L3 |
|----------------|------------|
| "Use interface X" | Interface definition (code) |
| "Never call Y directly" | Why Y is abstracted |
| "Queue via Z" | Queue configuration details |
| "Pattern: repository" | Full component diagram |
| "Log with slog" | Logging strategy rationale |

**Rule of thumb:** L2 rules are **imperative commands** the agent follows while coding. L3 content is **reference material** the agent consults when planning.

## L3: Design Body (Core Content)

**Ordering optimized for agent consumption:**

```
1. TL;DR (100 tokens)
   Architecture approach in 2-3 sentences. Agent decides relevance.

2. Decision Summary Table (200 tokens)
   Technology/pattern choices with one-phrase rationale.
   Agent's PRIMARY reference when starting implementation.

3. Component Overview + Diagram (300 tokens)
   What pieces exist, where they live, how they connect.
   Agent uses Location field to find code.

4. Interface Contracts (300 tokens)
   Actual code: type definitions, function signatures.
   Agent implements directly against these.

5. Data Model (200 tokens)
   DDL with constraints. Agent creates migrations from this.

6. Open Questions (50 tokens)
   Unresolved decisions. Agent checks before asking user.
```

**Total L3 budget:** ~1150 tokens. Loaded once when agent starts working on the feature's architecture.

## L4: Deep Reference

**What goes here:**
- Alternatives considered (why NOT other approaches)
- Migration/rollout plan
- ADR (Architecture Decision Record) log
- Performance analysis
- Security considerations

**When agent loads L4:**
- Questioning a decision from the summary table
- Planning a migration strategy
- Encountering a performance issue
- Security review

## Decision Flow: Which Layer for Design Info?

```
Does the agent need this for ALL coding tasks?
├─ Yes → L1 (tech stack summary)
│        One line per technology choice
└─ No
   │
   Does this constrain how specific code is written?
   ├─ Yes → L2 (component pattern rules)
   │        Imperative coding constraints
   └─ No
      │
      Is this needed to plan/implement the feature?
      ├─ Yes → L3 (design body)
      │        Decisions, components, interfaces, data model
      └─ No → L4 (deep reference)
               Alternatives, migration, ADR rationale
```

## Interface Contracts: The L3 Sweet Spot

Interface contracts are the most valuable L3 content. They bridge design decisions and implementation:

```go
// This is L3 content: the agent implements against this.
// It must be in the design doc, not extracted to L2.
type NotificationSender interface {
    // Send delivers a notification to a single user.
    // Returns ErrUserOptedOut if user disabled notifications.
    // Returns ErrInvalidToken if device token is expired.
    Send(ctx context.Context, userID string, n Notification) error
}

type Notification struct {
    Title    string            // Short title (max 65 chars for APNs)
    Body     string            // Message body (max 256 chars)
    Data     map[string]string // Custom key-value payload
    Priority Priority          // high | normal
}
```

**Why not L2?** Interface definitions are too detailed for path-conditional rules. They're reference material consulted during implementation, not constraints applied while editing.

**Why not L4?** They're the primary implementation specification. The agent needs them to write code, not just for clarification.

## Data Model: DDL as L3 Content

```sql
-- L3: Agent uses this to create migration files
CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id),
    title      TEXT NOT NULL,
    body       TEXT NOT NULL,
    channel    TEXT NOT NULL CHECK (channel IN ('push', 'email')),
    status     TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'failed', 'read')),
    sent_at    TIMESTAMPTZ,
    read_at    TIMESTAMPTZ,
    error_msg  TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Include index strategy: agent needs this for query optimization
CREATE INDEX idx_notifications_user_unread
    ON notifications(user_id, created_at DESC)
    WHERE read_at IS NULL;
```

**L2 derivative:**
```markdown
<!-- .claude/rules/notification-queries.md -->
---
paths:
  - "internal/notification/repository/**/*.go"
---

DB patterns (specs/design-notifications.md):
- Use sqlc-generated code; no hand-written SQL
- Use partial index idx_notifications_user_unread for unread queries
- All queries must accept context for cancellation
```
