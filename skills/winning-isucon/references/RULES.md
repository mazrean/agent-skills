# ISUCON Rules and Regulation

ISUCON regulation varies slightly each year. The most recent (ISUCON14, 2024-12-08) is the canonical reference. Read the year's official regulation as soon as it is published; this document captures the **stable parts** that have held for many editions.

Source: https://isucon.net/archives/58657116.html (ISUCON14 regulation), https://isucon.net/archives/cat_1024995.html (problem explanations index).

## Format

- **Duration**: 8 hours, typically 10:00–18:00 JST on competition day.
- **Team size**: 1–3 people. Solo entry is allowed (and has won — takonomura, ISUCON10).
- **Categories**: General + Student. Student team requires all members to be enrolled, non-employed students.
- **Communication**: Official Discord for announcements, portal site for tech support. Notifications must stay enabled.
- **Cap**: ~1,000 teams per edition.

## Scoring

```
score = sum(endpoint_points × successful_requests) + bonuses − penalties
```

- All requests time out at **10 seconds**. A timeout counts as failure.
- The benchmarker stops the run if too many requests error or the responses become inconsistent. Score for that run becomes 0.
- Public scoreboard typically freezes ~1 hour before the end. Final ranking is decided after the portal closes.
- **Re-test after the competition**: organizers reboot your servers and run the benchmarker again. If your app does not survive a reboot — score becomes 0.

## What You Can Change

The reference implementations are intentionally slow but functionally correct. You may:

- **Modify the application code** in any of the provided languages (Go, Node.js, Ruby, PHP, Rust, Perl typically — varies by year).
- **Switch to a different language** by changing the systemd unit's exec target. The reference for each language is provided in the repo.
- **Modify the database schema**: add indexes, denormalize, change column types, switch from MySQL to SQLite or Postgres or Redis-only — *if* you preserve the API contract.
- **Replace middleware**: swap nginx for envoy, MySQL for MariaDB or Postgres, add Redis/Memcached. The protocol-level guarantee is what matters, not the specific technology.
- **Add caches** in-process or external.
- **Change the topology** of the 2–3 provided instances: dedicated DB, dedicated app, dedicated cache, dedicated log/static.
- **Enqueue work** (job queues, delayed writes) as long as eventual consistency does not violate the spec the benchmarker checks.

## What You Cannot Change

- **URI paths and methods** of the API endpoints. The benchmarker calls them as-is.
- **Response body shape and semantics** as defined in the manual. Even reordering JSON keys can be safe in practice but reordering arrays usually is not.
- **The HTML / static asset content** when the benchmarker validates against a fixed checksum or DOM. Read the year's manual for which assets are checked.
- **The provided media files** (images, videos used by the app). Do not lossy-compress them unless the manual permits it.
- **Initial data**: you may pre-process and cache derived data, but the canonical data the benchmarker seeds with must not be lost.

## Strictly Prohibited

These cause disqualification:

- Sharing problem details with anyone outside your team during the competition.
- Cooperating with another team.
- Communicating with non-team members about ISUCON during the event.
- Attempting to access servers other than your own (no scanning, no port-knocking the org infra).
- Using external compute resources beyond what the regulation grants.

## Practical Implications

- **The benchmarker is the only judge.** If it accepts a response, the response is correct. If it rejects, you are wrong. Do not argue with it; read its source if it ships open (recent years do publish it).
- **Spec violation = 0.** A 100,000-point run that violates the spec at the end of the run scores 0. Validate after every refactor.
- **Reboot test = 0 if it fails.** Keep this in mind for every "clever" optimization (in-memory state without persistence, manual MySQL warmup, etc.).
- **Final-hour freeze** means you cannot watch your rivals' scores in the last stretch — plan accordingly.
