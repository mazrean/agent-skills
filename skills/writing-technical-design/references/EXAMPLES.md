# Technical Design Examples

## Example: Notification System Architecture

```markdown
---
title: "Push Notifications - Technical Design"
status: approved
prd: skills/prd-notifications/SKILL.md
component-skills:
  - skills/tech-redis-streams/SKILL.md
  - skills/tech-fcm-android/SKILL.md
  - skills/tech-apns-ios/SKILL.md
  - skills/tech-sqlc/SKILL.md
last-updated: 2026-03-01
---

# Push Notifications - Technical Design

## TL;DR

Event-driven architecture using Redis Streams for async notification
delivery. Order status changes publish events; a background consumer
processes them through FCM/APNs. Chosen for simplicity (Redis already
in stack) over adding a dedicated message broker.

## Decision Summary

| Decision | Choice | Rationale | Research |
|----------|--------|-----------|----------|
| Async mechanism | Redis Streams | Already in infrastructure, XREADGROUP for consumer groups | `skills/tech-redis-streams/` |
| Android push | FCM via firebase-admin-go | Official SDK, reliable delivery | `skills/tech-fcm-android/` |
| iOS push | APNs via sideshow/apns2 | Lightweight, well-maintained | `skills/tech-apns-ios/` |
| Token storage | New device_tokens table | Normalized, supports multi-device | — (no external component) |
| Retry strategy | Exponential backoff, max 3 | Prevents thundering herd on provider outage | `skills/tech-fcm-android/`, `skills/tech-apns-ios/` |
| Template engine | Go text/template | Simple, no external dependency needed | — (stdlib) |

## Component Overview

```text
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Order        │══>  │ Redis Stream     │══>  │ Notification    │
│ Handler      │     │ "notifications"  │     │ Consumer        │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │ Notification    │
                                              │ Sender          │
                                              ├─────────────────┤
                                              │ ┌─────┐ ┌─────┐ │
                                              │ │ FCM │ │APNs │ │
                                              │ └─────┘ └─────┘ │
                                              └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │ PostgreSQL      │
                                              │ (notifications) │
                                              └─────────────────┘
```

### Order Handler (existing, modified)

- **Responsibility**: Publishes status change events to Redis Stream
- **Location**: `internal/handler/order.go`
- **Changes**: Add event publishing after status update
- **Depends on**: Redis client

### Notification Consumer (new)

- **Responsibility**: Reads events from stream, orchestrates delivery
- **Location**: `internal/notification/consumer/`
- **Interface**: `Run(ctx context.Context) error` (blocking, long-lived)
- **Depends on**: NotificationSender, NotificationRepository
- **Research**: `skills/tech-redis-streams/SKILL.md`

### Notification Sender (new)

- **Responsibility**: Delivers notifications via FCM/APNs
- **Location**: `internal/notification/sender/`
- **Interface**: See Interface Contracts below
- **Depends on**: FCM SDK, APNs client, DeviceTokenRepository
- **Research**: `skills/tech-fcm-android/SKILL.md`, `skills/tech-apns-ios/SKILL.md`

### Notification Repository (new)

- **Responsibility**: CRUD for notification records
- **Location**: `internal/notification/repository/`
- **Interface**: sqlc-generated from queries
- **Depends on**: PostgreSQL
- **Research**: `skills/tech-sqlc/SKILL.md`

### Device Token Repository (new)

- **Responsibility**: Manage user device tokens
- **Location**: `internal/notification/device/`
- **Interface**: sqlc-generated from queries
- **Depends on**: PostgreSQL
- **Research**: `skills/tech-sqlc/SKILL.md`

## Interface Contracts

### NotificationSender

```go
package sender

type Sender interface {
    Send(ctx context.Context, userID string, n Notification) error
    SendBatch(ctx context.Context, reqs []SendRequest) []Result
}

type Notification struct {
    Title    string
    Body     string
    Data     map[string]string
    Priority Priority
}

type Priority string

const (
    PriorityHigh   Priority = "high"
    PriorityNormal Priority = "normal"
)

type SendRequest struct {
    UserID       string
    Notification Notification
}

type Result struct {
    UserID string
    Error  error
}
```

### Event Schema (Redis Stream)

```json
{
  "event_id": "string (UUID)",
  "event_type": "order.status_changed",
  "order_id": "string (UUID)",
  "user_id": "string (UUID)",
  "old_status": "string",
  "new_status": "string",
  "changed_at": "string (ISO8601)",
  "metadata": {
    "tracking_number": "string (optional)"
  }
}
```

### Consumer -> Sender Flow

```go
// Pseudocode for consumer processing loop
func (c *Consumer) processEvent(ctx context.Context, event Event) error {
    // 1. Check user preferences
    prefs, err := c.userRepo.GetNotificationPrefs(ctx, event.UserID)
    if err != nil { return err }
    if !prefs.PushEnabled { return nil } // skip silently

    // 2. Render notification from template
    notif, err := c.tmpl.Render(event.EventType, event)
    if err != nil { return err }

    // 3. Send via sender (handles FCM/APNs routing)
    err = c.sender.Send(ctx, event.UserID, notif)

    // 4. Record result
    return c.notifRepo.Create(ctx, ...)
}
```

## Data Model

```sql
-- Device tokens for push notification delivery
CREATE TABLE device_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id),
    token      TEXT NOT NULL,
    platform   TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);

-- Notification delivery records
CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id),
    event_id   UUID NOT NULL,
    title      TEXT NOT NULL,
    body       TEXT NOT NULL,
    channel    TEXT NOT NULL CHECK (channel IN ('push')),
    status     TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'failed')),
    sent_at    TIMESTAMPTZ,
    error_msg  TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_pending ON notifications(status, created_at)
    WHERE status = 'pending';
```

### Entity Relationships

```text
User 1──* DeviceToken
User 1──* Order 1──* StatusChangeEvent
StatusChangeEvent 1──* Notification
```

## Open Questions

- [ ] Should we add a dead letter stream for failed notifications
  after max retries? (@backend-lead)
- [x] Consumer group name? -> Decision: "notification-workers"
- [x] Stream MAXLEN? -> Decision: 100000 (auto-trimmed)

---
<!-- Below this line = L4 (deep reference) -->

## Alternatives Considered

### Alternative 1: PostgreSQL LISTEN/NOTIFY

- **Approach**: Use PG notifications instead of Redis Streams
- **Pros**: No additional infrastructure, transactional consistency
- **Cons**: No persistence of events, lost on crash, no consumer groups
- **Rejected because**: Need durable event processing with retry capability

### Alternative 2: Dedicated Message Broker (RabbitMQ/NATS)

- **Approach**: Add a message broker for event-driven processing
- **Pros**: Purpose-built, rich routing, better monitoring
- **Cons**: New infrastructure to maintain, operational overhead
- **Rejected because**: Redis Streams sufficient for current scale (< 1000 events/sec),
  avoids adding infrastructure complexity

### Alternative 3: Synchronous with Goroutine Pool

- **Approach**: Fire-and-forget goroutines in HTTP handler
- **Pros**: Simplest implementation, no queue
- **Cons**: Lost notifications on server restart, no retry, hard to monitor
- **Rejected because**: Violates FR-1 (delivery guarantee) and NFR-2 (reliability)

## Migration Plan

1. Create database tables (rollback: drop tables)
2. Deploy notification consumer as background goroutine in existing server
   (rollback: remove consumer startup)
3. Add event publishing to order handler behind feature flag
   (rollback: disable flag)
4. Enable feature flag in staging, verify end-to-end
   (rollback: disable flag)
5. Enable in production with monitoring alerts
   (rollback: disable flag)

## ADR Log

| Date | Decision | Context | Consequences |
|------|----------|---------|-------------|
| 2026-02-15 | Redis Streams over PG LISTEN/NOTIFY | Need durable events | Depends on Redis availability |
| 2026-02-18 | Separate device_tokens table | Multi-device support | Additional table to maintain |
| 2026-02-20 | Feature flag for rollout | Risk mitigation | Flag cleanup needed after full rollout |
```

## Example: Component Research Skill (`skills/tech-redis-streams/SKILL.md`)

This is what a digest produced by the Deep Research phase looks like. The design doc above references this skill; Claude auto-loads it when editing files under `internal/notification/consumer/` or anywhere that calls `go-redis` Stream methods.

```markdown
---
name: tech-redis-streams
description: Redis Streams research digest (server v7.2, go-redis/v9). Covers XADD, XREADGROUP, XACK, XAUTOCLAIM, idle-pending recovery, MAXLEN trimming, and consumer-group failure modes. Use when implementing or reviewing producers / consumers under internal/notification/consumer/ or any code calling go-redis Stream* methods.
---

# Redis Streams — Research Digest

## TL;DR

Redis Streams provides durable, ordered, at-least-once delivery with
consumer groups via XREADGROUP. For our push-notification pipeline it
replaces a message broker at zero infra cost. Main trade-off: at-least-once
means consumers must be idempotent, and pending entries require periodic
XAUTOCLAIM sweeps to survive consumer crashes.

## Identity

- **Version**: Redis server 7.2.x; go-redis v9.5.x (verified 2026-02-28)
- **License**: Redis is under RSALv2/SSPLv1 (7.4+); 7.2 under BSD. go-redis: BSD-2.
- **Docs**: https://redis.io/docs/latest/develop/data-types/streams/
- **Source**: https://github.com/redis/go-redis
- **Minimum runtime**: Go 1.22+ for go-redis v9.5

## API We Use

```go
// Producer
xadd := rdb.XAdd(ctx, &redis.XAddArgs{
    Stream: "notifications",
    MaxLen: 100_000,   // approximate trim; use `~` semantics
    Approx: true,
    Values: map[string]any{"event": payloadJSON},
})

// Consumer group bootstrap (idempotent)
_ = rdb.XGroupCreateMkStream(ctx, "notifications", "notification-workers", "$").Err()

// Consumer read
res, err := rdb.XReadGroup(ctx, &redis.XReadGroupArgs{
    Group:    "notification-workers",
    Consumer: consumerID,
    Streams:  []string{"notifications", ">"},
    Count:    16,
    Block:    5 * time.Second,
}).Result()

// Ack after processing
_ = rdb.XAck(ctx, "notifications", "notification-workers", entry.ID).Err()

// Recover entries abandoned by crashed consumers
claimed, _, err := rdb.XAutoClaim(ctx, &redis.XAutoClaimArgs{
    Stream:   "notifications",
    Group:    "notification-workers",
    Consumer: consumerID,
    MinIdle:  60 * time.Second,
    Start:    "0-0",
    Count:    50,
}).Result()
```

## Operational Notes

- **Throughput**: ~1M ops/sec on a single-node 7.2 (Redis official benchmark).
  Our target: <1k events/sec — three orders of magnitude of headroom.
- **Latency**: sub-millisecond XADD/XACK locally; p99 ~2ms across VPC.
- **Failure modes**:
  - Consumer crash → entries stay in PEL (Pending Entries List) until
    XAUTOCLAIM picks them up. Run sweeper every 30s with MinIdle=60s.
  - Redis failover → in-flight XREADGROUP returns with partial data;
    consumer must tolerate duplicate delivery (idempotency key = event_id).
- **Retry semantics**: none built-in. Our consumer increments a delivery
  counter per entry; after 3 attempts it moves the entry to a dead-letter
  stream via XADD + XACK on the original.
- **Resource cost**: ~100 bytes/entry + field overhead. With MaxLen=100k,
  budget ~30 MB steady-state.

## Pitfalls

- **MAXLEN without `~` is O(N).** Always set `Approx: true` (`MAXLEN ~ N`)
  for amortized O(1) trimming. *Source: Redis XADD docs, "Capped streams" section.*
- **`$` on XGroupCreate only reads new messages.** If the stream exists
  and has backlog you want to process, use `"0"` instead of `"$"` on first
  bootstrap. *Source: Redis XGROUP CREATE semantics.*
- **XREADGROUP `>` vs. explicit ID.** `>` reads only never-delivered
  entries. Using an explicit ID re-reads from PEL — useful for recovery,
  but easy to confuse with the normal path.
- **PEL growth under persistent consumer failure.** Monitor
  XPENDING summary; alert when idle PEL > threshold.
- **go-redis v9 renamed several XAdd options.** If porting v8 code,
  `MaxLenApprox` → `MaxLen + Approx: true`.

## Integration Pattern

```go
// internal/notification/consumer/consumer.go
type Consumer struct {
    rdb      redis.UniversalClient
    sender   sender.Sender
    notifRepo NotificationRepository
    id       string // e.g., hostname + pid
}

func (c *Consumer) Run(ctx context.Context) error {
    if err := c.ensureGroup(ctx); err != nil { return err }
    go c.sweepStale(ctx) // XAUTOCLAIM loop
    for {
        if err := ctx.Err(); err != nil { return err }
        if err := c.readOnce(ctx); err != nil {
            slog.Error("stream read failed", "err", err)
            time.Sleep(time.Second) // backoff
        }
    }
}
```

Consumers run as goroutines inside the main server binary. We considered
a separate worker binary; rejected for ops simplicity at current scale.

## Alternatives Considered

- **PostgreSQL LISTEN/NOTIFY** — no durable backlog; events lost on crash.
- **RabbitMQ / NATS** — new infra to operate; overkill at <1k events/sec.
- **Redis Pub/Sub** — fire-and-forget; no persistence; wrong primitive.

## Confidence

- **High**: API signatures, MAXLEN semantics, PEL behavior — all confirmed
  against official docs and go-redis v9.5 source.
- **Medium**: VPC-local p99 latency figure — from a single staging
  measurement, not a sustained benchmark.
- **Low**: behavior under Redis cluster failover — we run single-node in
  prod today; plan to re-verify if we ever move to cluster mode.

## References

- [references/PEL-RECOVERY.md](references/PEL-RECOVERY.md) — sweeper tuning
  and measured recovery times.
- [references/FAILOVER-NOTES.md](references/FAILOVER-NOTES.md) — behavior
  under RDB snapshot + replica promotion.
```

The corresponding L2 rule that extracts the imperative constraints:

```markdown
<!-- .claude/rules/notification-consumer.md -->
---
paths:
  - "internal/notification/consumer/**/*.go"
---

Notification consumer patterns (see skills/tech-redis-streams/):
- Always pass `Approx: true` when setting XAdd MaxLen.
- Use `">"` in XReadGroup for normal path; explicit ID only for PEL recovery.
- Run XAutoClaim sweeper every 30s with MinIdle=60s.
- Treat delivery as at-least-once: consumer handlers must be idempotent
  (key on event_id from the payload).
- After 3 attempts, XAdd to `notifications-dlq` then XAck the original.
```
