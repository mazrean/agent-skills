# Deep Research Methodology

How to investigate each technical component before committing to it in a design doc. The goal is a **verifiable, version-stamped digest** per component, not a blog-post pastiche.

## Principles

1. **Primary sources first.** Official docs, source repos, RFCs, specs. Blog posts and Q&A sites are accepted only as evidence of observed behavior or a specific workaround — never as the sole basis for a design decision.
2. **Version-stamp every claim.** A behavior that was true in `v1.4.0` may have changed by `v2.0.0`. A claim without a version has a hidden expiration date.
3. **Research what you will actually touch.** Do not document the whole library. Document the subset the design relies on, plus its nearest pitfalls.
4. **Record the date.** Include `as of YYYY-MM-DD` in each digest so later readers can judge freshness.
5. **Parallelize.** Components are independent — research them in parallel via Agent subagents.

## Source Priority

```
Tier 1 (trust, cite)        Tier 2 (cross-check)         Tier 3 (evidence only)
=====================================================================================
Official documentation      Release notes / changelogs   Blog posts
Source code / godoc         RFCs / IETF specs            Stack Overflow answers
Maintainer-written READMEs  Vendor advisories            Conference talks
Test suites in the repo     Well-known benchmark suites  Community tutorials
```

When Tier 1 and Tier 3 disagree, trust Tier 1. When Tier 1 is silent on a detail, Tier 3 is acceptable **provided** the digest marks the claim as "observed, not specified."

## Per-Category Research Checklists

### Library / Framework (Go, Node, Python, ...)

- [ ] Latest stable version + release date
- [ ] License (compatible with the project?)
- [ ] Maintenance signal: last release, open-vs-closed issues, active maintainers
- [ ] Minimum supported runtime version (Go `go` directive, Node engines, Python `requires-python`)
- [ ] Public API surface we will call — record *actual* signatures from godoc/typedoc
- [ ] Error model (sentinel errors? typed errors? panics?)
- [ ] Concurrency model (goroutine-safe? thread-safe? re-entrant?)
- [ ] Extension points (interfaces / hooks we plan to implement)
- [ ] Known CVEs in the version range we target
- [ ] Deprecated APIs to avoid
- [ ] Idiomatic setup snippet (what does "hello world" look like in *this* codebase's stack?)

### Database / Storage Engine

- [ ] Server version + the SQL / query feature we rely on (partial indexes, GIN, JSONB ops, window funcs, ...)
- [ ] When that feature was introduced (so L1 tech stack can pin a minimum version)
- [ ] Transaction / isolation behavior for the pattern we use
- [ ] Indexing strategy for the queries in the Data Model section
- [ ] Lock-table or long-query considerations (online DDL? pg_repack? ...)
- [ ] Backup / replication implications
- [ ] Extension dependencies (pgcrypto for `gen_random_uuid()`, etc.)

### Protocol / External Service (FCM, APNs, OAuth, payment, ...)

- [ ] Current protocol version / API version we target
- [ ] Auth model (service account, OAuth2, mTLS, HMAC signing, ...)
- [ ] Rate limits and quotas — actual numbers, not "has rate limits"
- [ ] Retry policy mandated or recommended by the provider
- [ ] Error taxonomy: which errors are retryable? which are permanent?
- [ ] Payload size limits
- [ ] Regional / data-residency constraints (GDPR, SOC2, ...)
- [ ] Deprecation schedule of the endpoint we use

### Infrastructure Primitive (Redis data structure, Kafka topic, ...)

- [ ] Server version + data structure's semantic guarantees (ordering, at-least-once, ...)
- [ ] Memory / disk footprint model
- [ ] Persistence guarantees (AOF, RDB, replication, ...)
- [ ] Failure modes: what happens on node loss, split brain, full disk?
- [ ] Monitoring surface (what metric tells us it is unhealthy?)
- [ ] Capacity planning: back-of-envelope for our load

### Language Feature (Go 1.23 range-over-func, Python 3.12 PEP-695, ...)

- [ ] Version introduced and stability status (experimental? stable?)
- [ ] Behavior differences vs. the prior idiom
- [ ] Tooling support (linter, formatter, IDE)
- [ ] Performance delta if claimed

## Research Tool Playbook

### WebSearch

- Always include the current year in the query (`"redis streams XAUTOCLAIM 2026"`).
- Search for version-specific docs: `site:pkg.go.dev/sideshow/apns2`.
- Use the `allowed_domains` parameter for known-good sources when available.

### WebFetch

- Use it on the **specific** doc page you already located, not on a homepage.
- Give the fetch prompt a concrete extraction goal: "Return the HTTP status codes FCM returns for permanent failures, verbatim from this page." Generic prompts yield generic answers.
- For pages behind auth (GitHub private repos, Confluence), prefer the appropriate MCP tool or `gh api` instead.

### Agent (general-purpose)

Delegate one research subagent per component when they are independent. Launch them in a single message so they run in parallel.

Prompt template for a component-research subagent:

```
Research {component} for use in {feature-area} on {stack}.

Goal: produce a digest suitable for skills/tech-{component}/SKILL.md.
Cover:
1. Current stable version + release date + doc URL.
2. The subset of the API we will call: {list of operations, e.g. "publish to stream, read via consumer group, ack, claim idle pending"}.
3. Operational characteristics relevant to our scale: {throughput, latency, failure modes}.
4. Top 3 pitfalls with concrete avoidance advice.
5. Idiomatic integration snippet for {language / framework}.

Constraints:
- Primary sources only (official docs, source repo). Mark any Tier-3 claim as "observed".
- Version-stamp every claim.
- Return in the skills/tech-{component}/SKILL.md template structure — do not write the file yet.
- Under 600 words in the digest body.
```

### Explore (subagent)

Use when the research is *inside the codebase*: "do we already wire up a Redis client? where?". This prevents re-researching patterns the repo already enforces.

## When to Skip Research

Not every mention of a technology needs its own digest. Skip when:

- The component is already in L1 tech stack and the feature uses it in the ordinary way (no new API surface).
- Usage is trivial glue (a `strings.TrimSpace`, a `context.WithTimeout`).
- An existing `skills/tech-{component}/SKILL.md` is still fresh (verify the `last-updated` frontmatter — treat stale after ~9 months or on a major version bump).

When a digest exists but is stale, **refresh it** — do not fork a second digest.

## Handling Contradictions

If two sources disagree:

1. If one is Tier 1 and the other is Tier 3, trust Tier 1 and move on.
2. If both are Tier 1 (e.g., docs say X, source code does Y), treat it as a blocker and call it out in the digest's "Pitfalls" section. Agents implementing later need to know the documented behavior is not the actual behavior.
3. If the disagreement is about performance / ops characteristics, prefer the one that includes a measurement over the one that does not.

## Recording Uncertainty

Every digest has a Confidence block. Example:

```markdown
## Confidence
- High: version, API signatures, auth model (from official docs).
- Medium: throughput number (from maintainer blog, no independent benchmark).
- Low: behavior under network partition (no primary source found — plan to verify in staging).
```

Do not pretend to know what the sources did not tell you. A clearly marked "Low" is more useful to future agents than a confident but wrong claim.
