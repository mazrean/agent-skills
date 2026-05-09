# Grafana MCP — Query Patterns

Concrete agent-side workflows for each query backend exposed by
`grafana/mcp-grafana`. Every pattern assumes you've already resolved a
`datasourceUid` (via `list_datasources` once per session).

## Time formats — universal

Every `start`, `end`, `from`, `to` field accepts:

| Form     | Example                  | Notes                           |
|----------|--------------------------|---------------------------------|
| Relative | `now`, `now-1h`, `now-7d` | Default-friendly, recommended  |
| ISO 8601 | `2026-02-02T19:00:00Z`   | Use when user gave a wall clock|
| Unix-ms  | `"1738519200000"` (str)  | Pass as a string, not number    |

Default span if you have nothing better: `start: "now-1h"`, `end: "now"`.

## Prometheus

### Discovery flow

```
list_datasources()                                              # one-shot
  → pick { uid: "prom-prod", type: "prometheus" }

list_prometheus_metric_names(datasourceUid)                     # if metric unknown
list_prometheus_label_names(datasourceUid, matchers, start, end)
list_prometheus_label_values(datasourceUid, labelName, matchers, start, end)
```

`matchers` accepts series selectors so you can scope discovery, e.g.
`["http_requests_total{job=\"api\"}"]` — far cheaper than dumping every
label value Prometheus has.

### Instant vs range

```
# Instant — current value, no step
query_prometheus(
  datasourceUid: "...",
  query: "sum(rate(http_requests_total[5m]))",
  start: "now",          # optional but allowed
)

# Range — series over time, step required
query_prometheus(
  datasourceUid: "...",
  query: "rate(http_requests_total[5m])",
  start: "now-1h", end: "now",
  step:  "30s",
)
```

Choose **instant** for "what is X right now / over the last 5m" answers.
Choose **range** when the user wants a chart or trend.

Pick `step` so you get **at most a few hundred points per series**:

| Window    | Reasonable step |
|-----------|-----------------|
| 15m       | 5s – 15s        |
| 1h        | 15s – 30s       |
| 6h        | 1m              |
| 24h       | 5m              |
| 7d        | 30m – 1h        |
| 30d       | 2h – 6h         |

### Histograms — use the dedicated tool

```
query_prometheus_histogram(
  datasourceUid: "...",
  metric: "http_request_duration_seconds",
  start: "now-1h", end: "now", step: "30s",
)
```

Returns p50/p90/p95/p99. Cleaner than hand-writing
`histogram_quantile(0.95, sum by (le) (rate(...[5m])))`.

### Common PromQL recipes

```
# Error rate per service
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
  / sum by (service) (rate(http_requests_total[5m]))

# CPU saturation by pod
sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))
  / sum by (pod) (kube_pod_container_resource_limits{resource="cpu"})

# Memory headroom
1 - sum by (instance) (node_memory_MemAvailable_bytes)
    / sum by (instance) (node_memory_MemTotal_bytes)
```

## Loki

### Discovery flow

```
list_datasources()
  → { uid: "loki-prod", type: "loki" }

list_loki_label_names(datasourceUid)                  # ~10 labels typical
list_loki_label_values(datasourceUid, labelName="app")
```

A **stream selector is mandatory** in LogQL. `|= "error"` alone won't run.
Even a search-everything query needs `{job=~".+"} |= "error"` or similar.

### Log queries

```
query_loki_logs(
  datasourceUid: "loki-prod",
  logql: "{app=\"api\", env=\"prod\"} |= \"error\" | logfmt | level=\"error\"",
  queryType: "range",
  start: "now-1h", end: "now",
  limit: 100,
  direction: "backward",      # newest first
)
```

- `limit` defaults to **10**, max **100** unless the server bumped
  `--max-loki-log-limit`. Set it explicitly.
- `direction: "backward"` gives newest-first; `"forward"` gives oldest-first.

### Metric queries (LogQL with aggregation)

```
query_loki_logs(
  datasourceUid: "loki-prod",
  logql: "sum by (level) (count_over_time({app=\"api\"} | logfmt [1m]))",
  queryType: "range",
  start: "now-1h", end: "now",
)
```

Metric queries return float64 series instead of log lines. Same tool, just
LogQL with `rate()`, `count_over_time()`, `sum`, `topk`, etc.

### Volume estimate before pulling lines

```
query_loki_stats(
  datasourceUid: "loki-prod",
  logql: "{app=\"api\", env=\"prod\"}",
  start: "now-24h", end: "now",
)
# → {streams, chunks, entries, bytes}
```

If `entries` is millions, narrow the selector or shorten the range *before*
calling `query_loki_logs`.

### Pattern detection

```
query_loki_patterns(
  datasourceUid: "loki-prod",
  logql: "{app=\"api\"}",
  start: "now-1h", end: "now",
)
# → [{ pattern: "...", totalCount: 12345 }, ...]
```

Use this for "what kinds of log lines does this service emit?" — much
cheaper than streaming logs and clustering yourself.

### Stream selector cheat sheet

```
{app="api"}                                # exact match
{app=~"api|web"}                            # regex match
{app="api", env="prod"}                     # AND
{app="api"} |= "error"                      # contains substring
{app="api"} |~ "5\\d\\d"                    # regex on line
{app="api"} != "healthcheck"                # exclude
{app="api"} | logfmt | duration > 1s        # parse + filter on field
{app="api"} | json | level="error"          # JSON parser
```

## Pyroscope

### Discovery + fetch flow

```
list_datasources() → { uid: "pyro-prod", type: "grafana-pyroscope-datasource" }

list_pyroscope_profile_types(datasourceUid)
# → ["process_cpu:cpu:nanoseconds:cpu:nanoseconds",
#    "memory:alloc_objects:count:space:bytes", ...]

list_pyroscope_label_names(datasourceUid)
list_pyroscope_label_values(datasourceUid, labelName="service_name")

fetch_pyroscope_profile(
  datasourceUid: "pyro-prod",
  profileType:   "process_cpu:cpu:nanoseconds:cpu:nanoseconds",
  matchers:      ["{service_name=\"api\"}"],
  start: "now-1h", end: "now",
)
# → DOT graph string — analyse hotspots, render with graphviz client-side
```

The DOT format is a callgraph — node weight is the metric for that profile
type. Don't pretty-print the whole thing back to the user; surface the
hottest functions.

## ClickHouse / Snowflake / InfluxDB / Elasticsearch / Graphite / CloudWatch

These categories are **disabled by default**. A failed call almost certainly
means the server wasn't started with the right `--enabled-tools=` flag.
Tell the user before retrying — don't loop on errors.

### ClickHouse

```
list_clickhouse_tables(datasourceUid, database)
describe_clickhouse_table(datasourceUid, table)
query_clickhouse(datasourceUid, query)
# Macros available: $__timeFilter, $__fromTime, $__toTime, $__interval
```

### Snowflake

```
list_snowflake_tables(datasourceUid, database?, schema?)
describe_snowflake_table(datasourceUid, table)
query_snowflake(datasourceUid, query)
# Same Grafana macros: $__timeFilter, $__from, $__to, $__interval, ${var}
```

### Elasticsearch / OpenSearch

`query_elasticsearch` accepts either a **Lucene** string (`status:5*`) or
**Query DSL** JSON (`{ "query": { "bool": { ... } } }`). The server
auto-detects from the shape of the input.

### CloudWatch

Three-stage discovery before any query:

```
list_cloudwatch_namespaces(datasourceUid)
list_cloudwatch_metrics(datasourceUid, namespace="AWS/Lambda")
list_cloudwatch_dimensions(datasourceUid, namespace="AWS/Lambda", metric="Errors")

query_cloudwatch(
  datasourceUid, namespace="AWS/Lambda",
  metric="Errors",
  dimensions={ FunctionName: "my-fn" },
  statistics=["Sum"],
  period="60s",
  start: "now-1h", end: "now",
)
```

### Graphite

`query_graphite` takes a render-API style query.
`query_graphite_density` returns a fast cardinality estimate before pulling
data — useful when patterns might match thousands of metrics.

### InfluxDB

`query_influxdb` switches between InfluxQL (v1) and Flux (v2) via the
`dialect` field. If unsure, try the dialect that matches the user's prior
queries; pkg defaults to InfluxQL.

## Trace / log correlation

To answer "show me the logs for this trace ID":

```
query_loki_logs(
  datasourceUid: "loki-prod",
  logql: "{app=\"api\"} |= \"<traceID>\"",
  queryType: "range",
  start: "now-6h", end: "now",
  limit: 100,
)
```

For metric-side correlation, derive a PromQL `sum by (trace_id) (...)` only
if the metric is exemplar-aware; otherwise pivot through Loki/Tempo.

## When things return nothing

1. **Widen the time range.** Many services don't emit until traffic flows.
2. **Drop label filters one at a time** — start with the most specific
   (`pod=`, `instance=`) before dropping `app=`/`job=`.
3. **Run `query_loki_stats`** to confirm whether *any* data is in the
   window. If `entries == 0`, the problem is upstream of LogQL.
4. **Re-check the datasource UID.** Multiple Prometheus datasources is
   common (prod / staging); the user may have meant another one.
