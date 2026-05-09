---
name: using-grafana-mcp
description: Operate the official grafana/mcp-grafana server from an agent. Use when the conversation has Grafana MCP tools available and you need to query Prometheus/Loki/Pyroscope, search or edit dashboards, manage alert rules, or generate Grafana deeplinks. Covers tool selection, parameter conventions (datasource UID, time ranges, limits, query types), and context-saving patterns for dashboard work.
---

# Using Grafana MCP

The official `grafana/mcp-grafana` server exposes Grafana's APIs as MCP tools.
This skill is a **field manual for the agent** — what tools to reach for, in
what order, with which parameters, and how to keep responses small.

**Use this skill when** Grafana MCP tools are available in the session and the
user asks to investigate metrics/logs/profiles, audit dashboards, manage
alerts, or build links into Grafana. Setup and authentication are out of scope
— this only covers operating the server once it's connected.

**Supporting files:**
- [references/TOOL-REFERENCE.md](references/TOOL-REFERENCE.md) — full tool
  catalogue with parameters, RBAC scopes, default-on/off status.
- [references/QUERY-PATTERNS.md](references/QUERY-PATTERNS.md) — Prometheus,
  Loki, Pyroscope query workflows; time-format and limit conventions.
- [references/DASHBOARDS-AND-EDIT.md](references/DASHBOARDS-AND-EDIT.md) —
  dashboard discovery, JSONPath / JSON Patch editing, alerting, deeplinks,
  rendering, Sift / Incident / OnCall.

## Mental model

Grafana MCP is a **thin wrapper over Grafana HTTP APIs**. There is no implicit
state — every call needs the right `datasourceUid`, scope, and time range.
Tools are namespaced by feature area:

| Area          | Common tools                                                        |
|---------------|---------------------------------------------------------------------|
| Discovery     | `list_datasources`, `get_datasource`, `search_dashboards`           |
| Prometheus    | `query_prometheus`, `list_prometheus_metric_names`, `..._label_*`   |
| Loki          | `query_loki_logs`, `query_loki_stats`, `query_loki_patterns`        |
| Dashboards    | `get_dashboard_summary`, `get_dashboard_property`, `patch_dashboard`|
| Alerting      | `alerting_manage_rules`, `alerting_manage_routing`                  |
| Investigations| `find_error_pattern_logs`, `find_slow_requests` (Sift)              |
| Navigation    | `generate_deeplink`, `get_panel_image`                              |

Tools enabled **by default**: dashboards, datasources, prometheus, loki,
pyroscope, alerting, incident, oncall, sift, asserts, navigation, annotations,
folders, search, rendering. Tools **disabled by default**: `admin`,
`clickhouse`, `cloudwatch`, `elasticsearch`, `examples` (`get_query_examples`),
`graphite`, `influxdb`, `snowflake`, `runpanelquery`. If you call a disabled
tool the request fails — fall back to a default-on tool or tell the user the
category needs to be enabled with `--enabled-tools=<name>`.

## The default workflow

For almost any "investigate X" request:

1. **Find the datasource UID first.** Don't guess. Call `list_datasources`
   (filter by `type:` like `prometheus`, `loki`, `pyroscope`) and pick the
   one matching the user's intent. Cache the UID for the rest of the session.
2. **Explore before querying.** For a metric/log unfamiliar to you, call
   `list_prometheus_metric_names` / `list_loki_label_names` /
   `list_*_label_values` to confirm the labels exist. Saves a round of failed
   PromQL/LogQL.
3. **Query with explicit time range.** Always pass `start` and `end`. Use
   relative form (`now-1h`, `now-24h`) unless the user gave concrete times.
4. **Narrow before widening.** Start with a small window and tight selectors;
   if empty, widen. Reverse is expensive on the Grafana side and on context.
5. **Hand back a `generate_deeplink`** so the user can open the same view in
   their browser.

## Time format — works everywhere

All `start` / `end` / `from` / `to` parameters accept three forms:

- Relative: `now`, `now-15m`, `now-1h`, `now-24h`, `now-7d`
- ISO 8601: `2026-02-02T19:00:00Z`
- Unix epoch milliseconds (string): `"1738519200000"`

Mix freely (`start: "now-1h"`, `end: "now"` is the canonical default).

## Querying — the short version

### Prometheus

```
query_prometheus(
  datasourceUid: "prom-prod",
  query:         "rate(http_requests_total{job=\"api\"}[5m])",
  start:         "now-1h",
  end:           "now",
  step:          "30s",     # omit for instant query
)
```

- Pass `step` for a **range** query, omit for an **instant** query.
- For percentiles on histograms use `query_prometheus_histogram` instead of
  hand-rolling `histogram_quantile(...)` — it computes p50/p90/p95/p99 from a
  histogram metric directly.
- Use `list_prometheus_label_values(labelName, matchers)` with selectors like
  `["http_requests_total{job=\"api\"}"]` to find candidate label values
  cheaply.

### Loki

```
query_loki_logs(
  datasourceUid: "loki-prod",
  logql:         "{app=\"api\"} |= \"error\"",
  start:         "now-1h",
  end:           "now",
  queryType:     "range",   # or "instant"
  limit:         100,       # default 10, max 100
)
```

- **Stream selector is mandatory** — every LogQL query must start with
  `{label="value"}`. Use `list_loki_label_names` and `list_loki_label_values`
  to discover labels first.
- `limit` defaults to **10** and is clamped to **100**. Always bump to 100
  when the user wants "recent errors" or similar; ask for more only if you
  need more (the server can be configured higher with
  `--max-loki-log-limit`).
- For volume/cardinality questions use `query_loki_stats` (returns streams /
  chunks / entries / bytes) — much cheaper than fetching log lines.
- For "what shapes of log lines exist?" use `query_loki_patterns` — returns
  detected patterns with counts.

For more depth (Pyroscope, ClickHouse, CloudWatch, etc.) see
[references/QUERY-PATTERNS.md](references/QUERY-PATTERNS.md).

## Dashboards — never pull the full JSON if you can avoid it

Dashboards can be hundreds of KB of JSON. The full payload poisons context
fast. Default to the **lightest tool that answers the question**:

| You need…                                  | Use                                       |
|--------------------------------------------|-------------------------------------------|
| List of dashboards by name/tag/folder      | `search_dashboards`                       |
| "What does this dashboard contain?"        | `get_dashboard_summary`                   |
| Specific field (title, panels[3], targets) | `get_dashboard_property` (with JSONPath)  |
| The PromQL/LogQL the dashboard runs        | `get_dashboard_panel_queries`             |
| A targeted edit                            | `patch_dashboard` (JSON Patch operations) |
| Full JSON for export / heavy rewrite       | `get_dashboard_by_uid` (last resort)      |
| Visual snapshot for the user               | `get_panel_image` → base64 PNG            |

**Editing rule:** prefer `patch_dashboard` with explicit
`{ op, path, value }` operations over `update_dashboard` with the full JSON.
Patches don't need you to read the dashboard back first.

JSONPath examples for `get_dashboard_property`:

- `$.title`
- `$.panels[*].title`
- `$.panels[0]`
- `$.panels[*].targets[*].expr` — every PromQL expression on the dashboard
- `$.templating.list` — variables
- `$.annotations.list`

For full dashboard / alerting workflows see
[references/DASHBOARDS-AND-EDIT.md](references/DASHBOARDS-AND-EDIT.md).

## Always finish with a deeplink

When the agent has built up a query, call `generate_deeplink` so the user can
inspect the same view in Grafana:

```
generate_deeplink(
  resourceType: "explore",         # or "dashboard" / "panel"
  datasourceUid: "prom-prod",
  queries:       ["rate(http_requests_total[5m])"],
  timeRange:     { from: "now-1h", to: "now" },
)
```

For dashboards/panels pass `dashboardUid` (and `panelId` for the panel
variant) instead. No RBAC required — this only builds a URL.

## Write paths — pause and confirm

These tools mutate Grafana state. Confirm with the user before invoking
unless they've already authorised the specific action:

- `update_dashboard`, `patch_dashboard`, `create_folder`
- `create_annotation`, `update_annotation`
- `alerting_manage_rules` (create/update/delete branches),
  `alerting_manage_routing`
- `create_incident`, `add_activity_to_incident`
- `find_error_pattern_logs`, `find_slow_requests` (these create Sift
  investigations as a side effect)

If the server was started with `--disable-write` these all return errors —
fall back to read-only equivalents and tell the user the server is read-only.

## Context-saving checklist

Grafana payloads are large. Apply in order:

1. Use the **summary / property / patch** variants for dashboards.
2. Filter `search_dashboards` by `tag` or `folderIds` — don't paginate.
3. Set `limit` consciously on `query_loki_logs` (default is only 10 anyway,
   but in stats-style use cases keep it small).
4. For Prometheus, prefer **instant** queries for "current value" questions
   — drop `step`. Range queries with a 30s step over 24h is hundreds of
   points per series.
5. Tighten label selectors before widening the time range.
6. Cache the `datasourceUid` and any UIDs you've already resolved — don't
   re-list every turn.

## Common pitfalls

- **Missing stream selector in LogQL.** `|= "error"` alone is invalid; needs
  `{app="..."} |= "error"`.
- **Calling a disabled-by-default tool.** If you get an unknown-tool error,
  check the disabled-by-default list (admin, clickhouse, cloudwatch,
  elasticsearch, examples, graphite, influxdb, snowflake, runpanelquery).
- **Querying without a UID.** Tools accept the datasource UID, *not* the
  display name. Resolve via `list_datasources` first.
- **Asking for "the last week of logs" without `limit`.** You'll get 10
  lines. Bump `limit` to 100, or use `query_loki_stats` for aggregate counts.
- **Dropping the time range** on alert / annotation / dashboard queries.
  Server-side defaults are short and the user usually means "last hour".
- **Re-fetching a dashboard you already have.** UIDs are stable in a
  session; reuse what you read.
