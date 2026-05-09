# Grafana MCP — Dashboards, Alerts, Investigations, Navigation

Operating the **non-query** parts of `grafana/mcp-grafana`. Read-only flows
are safe to fan out. Mutating flows should pause and confirm with the user
before invoking — see [SKILL.md](../SKILL.md) "Write paths".

## Dashboard discovery — pick the lightest tool

Dashboards routinely run hundreds of KB. Read what you need, no more.

| Goal                                       | Call                                       |
|--------------------------------------------|--------------------------------------------|
| Find a dashboard by title / tag / folder   | `search_dashboards`                        |
| One-paragraph description of contents      | `get_dashboard_summary`                    |
| Specific path inside the JSON              | `get_dashboard_property` + JSONPath        |
| All PromQL/LogQL the dashboard runs        | `get_dashboard_panel_queries`              |
| Render preview to share with the user      | `get_panel_image`                          |
| Whole JSON (export, deep rewrite)          | `get_dashboard_by_uid` (last resort)       |

`search_dashboards` accepts `tag`, `folderIds`, `starred`, `recent` — use
them aggressively to keep result sets small.

### JSONPath vocabulary for `get_dashboard_property`

```
$.title                         # dashboard title
$.uid                           # uid (sanity check)
$.tags                          # tags array
$.templating.list               # variables
$.annotations.list              # annotations
$.panels                        # all panels (still big)
$.panels[*].title               # just panel titles
$.panels[3]                     # one panel
$.panels[*].targets             # all queries on every panel
$.panels[*].targets[*].expr     # every PromQL expression
$.panels[*].datasource          # datasource per panel
$.panels[*].fieldConfig.defaults # display settings
```

## Editing dashboards

Two write paths:

### `patch_dashboard` — preferred

JSON Patch operations target one path at a time. Cheaper, safer, doesn't
require reading the dashboard first if you already know the path.

```
patch_dashboard(
  uid: "abc123",
  operations: [
    { op: "replace", path: "/title",            value: "API — prod (v2)" },
    { op: "replace", path: "/panels/3/title",   value: "Error rate (5xx)" },
    { op: "add",     path: "/tags/-",           value: "owner:backend" },
    { op: "remove",  path: "/panels/7" },
  ],
)
```

`path` follows JSON Pointer (RFC 6901) — `/panels/3` not `$.panels[3]`.
`-` after an array means "append".

### `update_dashboard` — full replace

Use when restructuring panels en masse. You must supply the full dashboard
JSON, including `version` (Grafana increments and validates it). Read with
`get_dashboard_by_uid` first.

```
update_dashboard(
  dashboard: <full JSON, with version bumped>,
)
```

Both write tools require `dashboards:write` and are blocked by
`--disable-write`.

### Folders

`create_folder(title, uid?)` for a new folder. There is no first-class
"move dashboard to folder" tool — patch the dashboard's `meta.folderUid`
or use `update_dashboard`.

## Annotations

Annotations are point-in-time markers on dashboards. Useful for marking
deploys, incidents, or relevant events when correlating with metrics.

```
get_annotations(
  dashboardUid: "abc123",       # optional: scope to a dashboard
  panelId:      4,              # optional: scope to a panel
  from: "now-7d", to: "now",
  tags: ["deploy"],
  matchAny: false,              # all tags must match
)

create_annotation(
  dashboardUid: "abc123",
  panelId:      4,
  time:         "2026-05-09T12:00:00Z",
  text:         "Deployed v1.2.3",
  tags:         ["deploy", "service:api"],
)
```

`update_annotation` requires `id` (returned from `get_annotations`).

## Alert rules

`alerting_manage_rules` is **one tool with an `action` parameter**, not
seven. Branch on the action:

```
# List
alerting_manage_rules(action: "list", limit: 200)

# Get one
alerting_manage_rules(action: "get", uid: "rule-uid")

# Get history
alerting_manage_rules(action: "versions", uid: "rule-uid")

# Create / update — pass a rule object
alerting_manage_rules(action: "create", namespace: "...", groupName: "...", rule: {...})
alerting_manage_rules(action: "update", uid: "rule-uid", rule: {...})

# Delete
alerting_manage_rules(action: "delete", uid: "rule-uid")
```

Supports both Grafana-managed rules and datasource-managed rules
(Prometheus, Loki). Default `limit` is 200.

`alerting_manage_routing` covers notification policies, contact points, and
mute timings — same `action`-style branching. Reads only Grafana; write
operations on Prometheus / Mimir / Cortex Alertmanagers go through the same
tool when configured.

Both tools are blocked by `--disable-alerting`.

## Sift investigations

Two patterns: **read existing** investigations, or **create new** ones via
the `find_*` tools.

### Reading

```
list_sift_investigations(limit: 20)
get_sift_investigation(uuid: "...")
get_sift_analysis(investigationUuid: "...", analysisId: "...")
```

### Creating (write — confirm first)

```
find_error_pattern_logs(
  name:   "investigate api errors",
  labels: { app: "api", env: "prod" },
  start: "now-1h", end: "now",
)
# → spawns a Sift investigation looking for elevated patterns in Loki

find_slow_requests(
  name:   "investigate latency",
  labels: { service: "api" },
  start: "now-1h", end: "now",
)
# → spawns a Sift investigation against Tempo traces
```

These are async — the tool returns the investigation UUID; poll
`get_sift_investigation` until the analyses populate.

Disabled by `--disable-sift` (and the write variants by `--disable-write`).

## Incident (Grafana Incident plugin)

```
list_incidents(query?, limit?)
get_incident(id)
create_incident(title, severity, isDrill?, ...)
add_activity_to_incident(incidentId, body, eventTime?)
```

Editor role required for the write paths. Disabled by `--disable-incident`.

## OnCall

Read-only across the board. Use during investigations to see who to
escalate to:

```
list_oncall_schedules() → pick a scheduleId
get_current_oncall_users(scheduleId)
list_alert_groups(state: "firing", limit: 20)
get_alert_group(id)
```

`list_oncall_teams`, `list_oncall_users`, `get_oncall_shift` cover the rest.
Disabled by `--disable-oncall`.

## Asserts

Quick health summary for a named entity. Useful as a starting point when
the user asks "is service X healthy?".

```
get_assertions(
  entityType: "Service",
  entityName: "api",
  start: "now-1h", end: "now",
)
```

Disabled by `--disable-asserts`.

## Navigation — `generate_deeplink`

Always call at the end of a multi-step investigation so the user can pivot
to the Grafana UI with the same query/time/state already loaded.

### Dashboard link

```
generate_deeplink(
  resourceType: "dashboard",
  dashboardUid: "abc123",
  timeRange: { from: "now-1h", to: "now" },
  variables: { service: "api", env: "prod" },
  refresh:   "30s",
)
```

### Panel link

```
generate_deeplink(
  resourceType: "panel",
  dashboardUid: "abc123",
  panelId:      4,
  timeRange:    { from: "now-1h", to: "now" },
)
```

### Explore link

```
generate_deeplink(
  resourceType:  "explore",
  datasourceUid: "prom-prod",
  queries:       ["sum by (status) (rate(http_requests_total[5m]))"],
  timeRange:     { from: "now-1h", to: "now" },
)
```

Multiple queries can be passed for split-panel Explore. No RBAC required —
deeplinks are just URLs.

Disabled by `--disable-navigation`.

## Rendering — `get_panel_image`

Returns a base64-encoded PNG. Useful for sharing a snapshot inline in chat
when the user can't open Grafana.

```
get_panel_image(
  dashboardUid: "abc123",
  panelId:      4,             # omit for full dashboard
  width:        1000,
  height:       500,
  theme:        "dark",
  timeRange:    { from: "now-1h", to: "now" },
  variables:    { service: "api" },
  timeout:      "30s",
)
```

Requires Grafana Image Renderer to be deployed — the tool errors with a
plugin-not-installed message otherwise. Disabled by `--disable-rendering`.

## Admin (default-disabled)

Enable with `--enabled-tools=admin`. Useful for explaining permission
problems back to the user:

```
get_resource_permissions(
  resourceType: "dashboards",
  uid:          "abc123",
)
list_user_roles(userIds: [42])
get_role_assignments(uid: "fixed:dashboards:reader")
```

Don't enable `admin` casually — `list_users_by_org` and friends are
sensitive.

## Mutation safety summary

Pause and confirm before invoking these — they change Grafana state visible
to other users:

| Tool                      | Effect                          |
|---------------------------|---------------------------------|
| `update_dashboard`        | Replaces a dashboard            |
| `patch_dashboard`         | Mutates dashboard fields        |
| `create_folder`           | Adds a folder                   |
| `create_annotation`       | Visible marker on dashboards    |
| `update_annotation`       | Edits an existing marker        |
| `alerting_manage_rules`   | Writes when action ≠ list/get   |
| `alerting_manage_routing` | Writes when action ≠ list/get   |
| `create_incident`         | Real incident (paging risk)     |
| `add_activity_to_incident`| Visible to incident channel     |
| `find_error_pattern_logs` | Creates a Sift investigation    |
| `find_slow_requests`      | Creates a Sift investigation    |

If `--disable-write` is set, these all fail — surface the error and offer
the read-only equivalent.
