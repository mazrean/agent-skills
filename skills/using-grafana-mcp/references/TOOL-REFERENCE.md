# Grafana MCP — Tool Reference

Complete catalogue of tools exposed by `grafana/mcp-grafana`. Each entry lists
parameters, defaults, RBAC scope, and whether the tool is enabled by default.

Default-enabled categories: `dashboard`, `datasources`, `prometheus`, `loki`,
`pyroscope`, `alerting`, `incident`, `oncall`, `sift`, `asserts`,
`navigation`, `annotations`, `folder`, `search`, `rendering`.

Default-disabled categories (must be enabled with `--enabled-tools=<name>`):
`admin`, `clickhouse`, `cloudwatch`, `elasticsearch`, `examples`, `graphite`,
`influxdb`, `snowflake`, `runpanelquery`.

Server-wide kill switches: `--disable-write`, `--disable-alerting`,
`--disable-incident`, `--disable-oncall`, `--disable-sift`,
`--disable-asserts`, `--disable-navigation`, `--disable-rendering`.

## Search & discovery

### `search_dashboards`
Find dashboards by query, tag, folder, etc.
- `query` (string, optional) — text search
- `tag` ([]string, optional)
- `type` (string, optional)
- `folderIds` ([]int, optional)
- `starred` (bool, optional)
- `recent` (bool, optional)
- `limit` (int, optional)
- `page` (int, optional)
- RBAC: `dashboards:read`, scope `dashboards:*` or `dashboards:uid:<uid>`

### `search_folders`
- `query` (string, optional)
- RBAC: `folders:read`

### `list_datasources`
Returns every configured datasource. No parameters.
- RBAC: `datasources:read`

### `get_datasource`
- `uid` (string) **or** `name` (string) — one required
- RBAC: `datasources:read`, scope `datasources:uid:<uid>`

## Dashboards

### `get_dashboard_summary`
Compact metadata: title, panel count, panel types, variables. No JSON body.
- `uid` (string, required)
- RBAC: `dashboards:read`

### `get_dashboard_property`
Extract just one slice via JSONPath.
- `uid` (string, required)
- `jsonPath` (string, required) — e.g. `$.title`, `$.panels[*].title`,
  `$.panels[0]`, `$.panels[*].targets[*].expr`, `$.templating.list`,
  `$.annotations.list`, `$.tags`
- RBAC: `dashboards:read`

### `get_dashboard_panel_queries`
Returns each panel's title, query string, datasource UID/type. Best tool for
"what does this dashboard query?".
- `uid` (string, required)
- RBAC: `dashboards:read`

### `get_dashboard_by_uid`
Full dashboard JSON. Avoid unless you genuinely need it — large dashboards
blow up context.
- `uid` (string, required)
- RBAC: `dashboards:read`

### `update_dashboard`
Create or replace a dashboard. Requires the full JSON.
- `dashboard` (object, required)
- RBAC: `dashboards:create`, `dashboards:write`
- Disabled by `--disable-write`

### `patch_dashboard`
Targeted edit via JSON Patch — preferred over `update_dashboard`.
- `uid` (string, required)
- `operations` ([]PatchOperation, required) — each entry has:
  - `op` ("add" | "remove" | "replace")
  - `path` (JSON Pointer, e.g. `/title`, `/panels/0/title`)
  - `value` (any, required for `add` / `replace`)
- RBAC: `dashboards:create`, `dashboards:write`
- Disabled by `--disable-write`

## Folders

### `create_folder`
- `title` (string, required)
- `uid` (string, optional)
- RBAC: `folders:create`
- Disabled by `--disable-write`

## Run panel query (default-disabled)

### `run_panel_query`
Execute the queries baked into a dashboard panel.
- `dashboardUid` (string, required)
- `panelId` (int, required)
- `timeRange` (object, optional)
- `variables` (object, optional)
- Enable with `--enabled-tools=runpanelquery`
- RBAC: `dashboards:read`, `datasources:query`

## Prometheus

### `query_prometheus`
- `datasourceUid` (string, required)
- `query` (string, required) — PromQL expression
- `start` (string, optional) — `now-1h` / ISO 8601 / unix-ms (string)
- `end` (string, optional)
- `step` (string, optional) — e.g. `30s`, `1m`. **Provide for range,
  omit for instant.**
- RBAC: `datasources:query`, scope `datasources:uid:<uid>`

### `query_prometheus_histogram`
Computes p50/p90/p95/p99 from a histogram metric.
- `datasourceUid` (string, required)
- `metric` (string, required) — base name of the histogram
- `start`, `end`, `step` (optional)
- RBAC: `datasources:query`

### `list_prometheus_metric_names`
- `datasourceUid` (string, required)
- RBAC: `datasources:query`

### `list_prometheus_metric_metadata`
- `datasourceUid` (string, required)
- `metric` (string, optional) — filter
- RBAC: `datasources:query`

### `list_prometheus_label_names`
- `datasourceUid` (string, required)
- `matchers` ([]string, optional) — series selectors
- `start`, `end` (optional)
- RBAC: `datasources:query`

### `list_prometheus_label_values`
- `datasourceUid` (string, required)
- `labelName` (string, required)
- `matchers` ([]string, optional)
- `start`, `end` (optional)
- RBAC: `datasources:query`

## Loki

### `query_loki_logs`
- `datasourceUid` (string, required)
- `logql` (string, required) — must include a stream selector `{...}`
- `queryType` ("instant" | "range", required)
- `start`, `end` (optional)
- `limit` (int, optional) — **default 10, clamped to max 100** (server may
  raise the cap with `--max-loki-log-limit`)
- `direction` ("forward" | "backward", optional)
- RBAC: `datasources:query`

### `query_loki_stats`
Stream/chunks/entries/bytes counts — cheap volume estimate.
- `datasourceUid` (string, required)
- `logql` (string, required) — typically just a stream selector
- `start`, `end` (optional)
- RBAC: `datasources:query`

### `query_loki_patterns`
Detected log patterns with `totalCount` per pattern.
- `datasourceUid` (string, required)
- `logql` (string, required)
- `start`, `end` (optional)
- RBAC: `datasources:query`

### `list_loki_label_names`
- `datasourceUid` (string, required)
- `start`, `end` (optional, defaults to last hour)
- RBAC: `datasources:query`

### `list_loki_label_values`
- `datasourceUid` (string, required)
- `labelName` (string, required)
- `start`, `end` (optional)
- RBAC: `datasources:query`

## Pyroscope

### `list_pyroscope_profile_types`
- `datasourceUid` (string, required)

### `list_pyroscope_label_names`
- `datasourceUid` (string, required)
- `matchers` ([]string, optional)

### `list_pyroscope_label_values`
- `datasourceUid` (string, required)
- `labelName` (string, required)

### `fetch_pyroscope_profile`
Returns DOT-format profile.
- `datasourceUid` (string, required)
- `profileType` (string, required) — e.g. `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
- `matchers` ([]string, optional)
- `start`, `end` (optional)

All Pyroscope tools: `datasources:query`, scope `datasources:uid:<uid>`.

## InfluxDB (default-disabled)

### `query_influxdb`
- `datasourceUid` (string, required)
- `query` (string, required) — InfluxQL or Flux
- `dialect` ("influxql" | "flux", optional)
- Enable with `--enabled-tools=influxdb`

## ClickHouse (default-disabled)

### `list_clickhouse_tables`
- `datasourceUid`, `database` — required

### `describe_clickhouse_table`
- `datasourceUid`, `table` — required

### `query_clickhouse`
- `datasourceUid`, `query` — required. Supports Grafana macros.

Enable with `--enabled-tools=clickhouse`.

## CloudWatch (default-disabled)

### `list_cloudwatch_namespaces`
- `datasourceUid` (required)

### `list_cloudwatch_metrics`
- `datasourceUid`, `namespace` — required

### `list_cloudwatch_dimensions`
- `datasourceUid`, `namespace`, `metric` — required

### `query_cloudwatch`
- `datasourceUid`, `namespace`, `metric` — required
- `start`, `end`, `dimensions`, `statistics`, `period` — optional

Enable with `--enabled-tools=cloudwatch`.

## Elasticsearch / OpenSearch (default-disabled)

### `query_elasticsearch`
- `datasourceUid` (required)
- `query` (required) — Lucene string or Query DSL JSON
- `start`, `end` (optional)
- Returns documents `{index, id, source, score?}`

Enable with `--enabled-tools=elasticsearch`.

## Snowflake (default-disabled)

### `list_snowflake_tables`
- `datasourceUid` (required)
- `database`, `schema` — optional filters

### `describe_snowflake_table`
- `datasourceUid`, `table` — required

### `query_snowflake`
- `datasourceUid`, `query` — required
- Supports Grafana macros: `$__timeFilter`, `$__timeFrom`, `$__timeTo`,
  `$__from`, `$__to`, `$__interval`, `${var}`

Enable with `--enabled-tools=snowflake`.

## Graphite (default-disabled)

### `query_graphite`
- `datasourceUid`, `query` — required

### `list_graphite_metrics`
- `datasourceUid` (required)
- `prefix` (optional)

### `list_graphite_tags`
- `datasourceUid` (required)

### `query_graphite_density`
- `datasourceUid`, `pattern` — required

Enable with `--enabled-tools=graphite`.

## Examples (default-disabled)

### `get_query_examples`
Example queries for a datasource type — useful when teaching the user.
- `datasourceType` (string, required)
- Enable with `--enabled-tools=examples`

## Alerting

### `alerting_manage_rules`
Single tool for list / get / versions / create / update / delete on alert
rules (Grafana-managed and datasource-managed Prometheus/Loki rules).
- `action` ("list" | "get" | "versions" | "create" | "update" | "delete")
- `namespace` (string, optional)
- `groupName` (string, optional)
- `uid` (string, optional)
- `rule` (object, for create/update)
- `limit` (int, optional, default **200**)
- RBAC: `alert.rules:read`, plus `alert.rules:write` for mutations
- Disabled by `--disable-alerting`

### `alerting_manage_routing`
Notification policies, contact points, time intervals (Grafana,
Mimir/Cortex/Prometheus Alertmanagers).
- `action` (string)
- `payload` (object, varies by action)
- RBAC: `alert.notifications:read` / `alert.notifications:write`
- Disabled by `--disable-alerting`

## Annotations

### `get_annotations`
- `dashboardUid` (string, optional)
- `panelId` (int, optional)
- `from`, `to` (string, optional)
- `tags` ([]string, optional)
- `matchAny` (bool, optional)
- RBAC: `annotations:read`

### `create_annotation`
- Standard form: `dashboardUid`, `panelId`, `time`, `timeEnd`, `text`, `tags`
- Graphite form: `what`, `when`, `tags`, `data`
- RBAC: `annotations:write`
- Disabled by `--disable-write`

### `update_annotation`
- `id` (int, required)
- All other fields optional
- RBAC: `annotations:write`
- Disabled by `--disable-write`

### `get_annotation_tags`
- `tag` (string, optional, prefix filter)
- `limit` (int, optional)
- RBAC: `annotations:read`

## Incident (Grafana Incident plugin)

### `list_incidents`
- `query` (string, optional)
- `limit` (int, optional)
- Role: Viewer
- Disabled by `--disable-incident`

### `get_incident`
- `id` (string, required)
- Role: Viewer

### `create_incident`
- `title`, `severity`, `roomPrefix`, `isDrill`, `status`, `attachCaption`,
  `attachUrl`, `labels` — depending on plan/config
- Role: Editor
- Disabled by `--disable-incident` or `--disable-write`

### `add_activity_to_incident`
- `incidentId` (string, required)
- `body` (string, required)
- `eventTime` (string, optional)
- Role: Editor

## OnCall

### `list_oncall_schedules` — no params
### `get_oncall_shift` — `shiftId` required
### `get_current_oncall_users` — `scheduleId` required
### `list_oncall_teams` — no params
### `list_oncall_users` — no params
### `list_alert_groups` — optional `state`, `integrationId`, `labels`,
  `started_at_gte`, `started_at_lte`, `team`, `route`, `name`
### `get_alert_group` — `id` required

All disabled by `--disable-oncall`. Permissions per tool live under the
`grafana-oncall-app.*` plugin namespace.

## Sift (investigations)

### `list_sift_investigations`
- `limit` (int, required)
- Role: Viewer

### `get_sift_investigation`
- `uuid` (string, required)
- Role: Viewer

### `get_sift_analysis`
- `investigationUuid` (string, required)
- `analysisId` (string, required)
- Role: Viewer

### `find_error_pattern_logs`
Creates a Sift investigation looking for elevated Loki error patterns.
- `name` (string, required)
- `labels` (object, required) — Loki stream labels to scope to
- `start`, `end` (optional)
- Role: Editor; disabled by `--disable-write`

### `find_slow_requests`
Creates a Sift investigation against Tempo traces for slow requests.
- `name` (string, required)
- `labels` (object, required)
- `start`, `end` (optional)
- Role: Editor; disabled by `--disable-write`

All disabled by `--disable-sift`.

## Asserts

### `get_assertions`
Assertion summary for an entity (service, node, pod, etc.).
- `entityType` (string, required)
- `entityName` (string, required)
- `start`, `end` (optional)
- Disabled by `--disable-asserts`

## Navigation

### `generate_deeplink`
Builds the canonical Grafana URL for a resource — no auth needed.
- `resourceType` ("dashboard" | "panel" | "explore", required)
- `dashboardUid` (string, optional; required for dashboard/panel)
- `panelId` (int, optional; required for panel)
- `datasourceUid` (string, optional; required for explore)
- `queries` ([]string, optional; for explore)
- `timeRange` ({from, to}, optional)
- `variables` (map, optional) — dashboard variable values
- `refresh` (string, optional) — e.g. `30s`
- Disabled by `--disable-navigation`

## Rendering

### `get_panel_image`
Returns base64-encoded PNG. Requires Grafana Image Renderer to be deployed.
- `dashboardUid` (string, required)
- `panelId` (int, optional; omit for full dashboard)
- `width`, `height` (int, optional)
- `timeRange` ({from, to}, optional)
- `theme` ("light" | "dark", optional)
- `timeout` (string, optional, e.g. `30s`)
- `variables` (map, optional)
- RBAC: `dashboards:read`
- Disabled by `--disable-rendering`

## Admin (default-disabled)

Enable with `--enabled-tools=admin`.

- `list_teams` — no params
- `list_users_by_org` — no params
- `list_all_roles` — `delegatable` (bool, optional)
- `get_role_details` — `uid` required
- `get_role_assignments` — `uid` required
- `list_user_roles` — `userIds` ([]int) required
- `list_team_roles` — `teamIds` ([]int) required
- `get_resource_permissions` — `resourceType`, `uid` required
- `get_resource_description` — `resourceType` required

RBAC: `teams:read` / `users:read` / `roles:read` / `permissions:read`
depending on tool.
