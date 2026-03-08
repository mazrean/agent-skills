# Technical Design Examples

## Example: Notification System Architecture

```markdown
---
title: "Push Notifications - Technical Design"
status: approved
prd: prd-notifications.md
last-updated: 2026-03-01
---

# Push Notifications - Technical Design

## TL;DR

Event-driven architecture using Redis Streams for async notification
delivery. Order status changes publish events; a background consumer
processes them through FCM/APNs. Chosen for simplicity (Redis already
in stack) over adding a dedicated message broker.

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Async mechanism | Redis Streams | Already in infrastructure, XREADGROUP for consumer groups |
| Android push | FCM via firebase-admin-go | Official SDK, reliable delivery |
| iOS push | APNs via sideshow/apns2 | Lightweight, well-maintained |
| Token storage | New device_tokens table | Normalized, supports multi-device |
| Retry strategy | Exponential backoff, max 3 | Prevents thundering herd on provider outage |
| Template engine | Go text/template | Simple, no external dependency needed |

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

### Notification Sender (new)

- **Responsibility**: Delivers notifications via FCM/APNs
- **Location**: `internal/notification/sender/`
- **Interface**: See Interface Contracts below
- **Depends on**: FCM SDK, APNs client, DeviceTokenRepository

### Notification Repository (new)

- **Responsibility**: CRUD for notification records
- **Location**: `internal/notification/repository/`
- **Interface**: sqlc-generated from queries
- **Depends on**: PostgreSQL

### Device Token Repository (new)

- **Responsibility**: Manage user device tokens
- **Location**: `internal/notification/device/`
- **Interface**: sqlc-generated from queries
- **Depends on**: PostgreSQL

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
