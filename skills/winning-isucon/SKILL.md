---
name: winning-isucon
description: Optimizes web applications for ISUCON (Iikanji ni Speed Up Contest), a Japanese 8-hour performance tuning competition. Use when participating in ISUCON, practicing past problems (private-isu, isucon-workshop), or aggressively tuning a Go/Node.js/Ruby/PHP web app with MySQL behind nginx. Covers regulation, measurement tools (alp, pt-query-digest, pprof), N+1 elimination, indexing, caching, multi-server topology, and reboot-test pitfalls.
---

# Winning ISUCON

Systematic workflow to maximize the score of an ISUCON benchmark within 8 hours. The competition hands you a deliberately-slow web application (typically Go reference implementation, with Node.js/Ruby/PHP/Rust/Perl alternatives) running on 2–3 cloud instances behind nginx + MySQL. Your job is to tune anything that is not forbidden by the regulation.

**Use this skill when** entering an ISUCON event, drilling on past problems (`private-isu`, `isucon-workshop`, `isucon[N]-qualify` repos), or doing 8-hour-style backend tuning under a benchmarker that fails the run if responses become incorrect.

This skill is for **server-side / full-stack** competitions where the score comes from a benchmark tool. For frontend Lighthouse competitions, see `winning-web-speed-hackathon` instead.

## Scoring Model

Score = sum of (per-endpoint points × successful requests) + bonuses − penalties.

- All requests time out at 10s. The benchmarker stops on too many errors and the run scores 0.
- Application correctness is verified continuously: response shape, HTTP status, business logic. Spec violations → fail.
- Final ranking is decided after the portal closes; **organizers re-run with a server reboot** to confirm. If the app does not survive reboot, the score becomes 0.

Implication: speed is worthless if you break the spec or lose state on reboot. Every optimization must preserve correctness and survive `systemctl restart`.

## Phase 0: Pre-Competition Preparation (before the day)

Time you spend before the competition is "free" — use it.

1. **Practice a recent past problem end-to-end.** Required: `isucon14`, `isucon13`, `isucon12-qualify`, `private-isu`. The full repos are on github.com/isucon.
2. **Pre-prepare your dotfiles, tools, and Makefile templates** in a private GitHub repo. See [INITIAL-SETUP.md](references/INITIAL-SETUP.md).
3. **Decide team roles.** Typical 3-person split: infra (nginx/MySQL/systemd/topology), app-A (codebase reading + N+1), app-B (algorithms + caching).
4. **Read the regulation as soon as it is published.** What can you change, what can you not. See [RULES.md](references/RULES.md).

## Phase 1: First 60 Minutes (Recon, no premature changes)

The first hour is for **understanding and measurement**, not optimization. Resist the urge to "fix something obvious" before you have data.

1. **SSH into all instances**, confirm specs (`nproc`, `free -h`, `df -h`), confirm distro/version.
2. **Get the source under git.** `cd /home/isucon && git init && git add . && git commit -m "initial"` then push to a private repo. Lose this and you lose hours.
3. **Read the manual carefully.** Identify endpoints, sample requests, score formula, banned actions.
4. **Identify the language binary path and systemd unit.** Confirm how to deploy a new build (`systemctl restart isuride-go.service` or similar).
5. **Configure logs for analysis** ([INITIAL-SETUP.md](references/INITIAL-SETUP.md)):
   - nginx: switch to LTSV/JSON access log, log to `/var/log/nginx/access.log`
   - MySQL: enable slow query log with `long_query_time = 0` (log everything for the first run)
6. **Run the benchmarker once** to get a baseline score and collect a full log set.
7. **Profile the baseline** with `alp` + `pt-query-digest` + `pprof`. See [MEASUREMENT.md](references/MEASUREMENT.md).
8. **Decide the bottleneck order** as a team. Write it down. Do not start fixing until you agree.

Common baseline pattern: MySQL is CPU-bound at 90%+, app at 30%, nginx idle. The first move is almost always indexing or N+1.

## Phase 2: High-Yield Optimizations (hours 1–5)

Apply in roughly this order, but always **let the data drive**:

1. **Add MySQL indexes** for slow queries (composite indexes matching WHERE + ORDER BY columns). Verify with `EXPLAIN`. See [OPTIMIZATION-PATTERNS.md](references/OPTIMIZATION-PATTERNS.md).
2. **Eliminate N+1 queries**: convert loop-of-SELECT into a single `IN (...)` SELECT, or `JOIN`, or pre-load via map.
3. **Convert per-row INSERT loops to bulk INSERT** (`INSERT ... VALUES (...), (...), ...`). With `sqlx`, use `NamedExec` on a slice.
4. **Cache invariant or rarely-changing data in memory** (Go `sync.Map`, struct cache). For multi-server, use Redis/Memcached. Master tables (categories, settings) almost always cacheable.
5. **Move static files / images out of the app** into nginx (`try_files`, `expires`).
6. **Tune connection pools** (`SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime`) so you stop opening sockets per request.
7. **Re-measure after every change**. If alp/pprof shifts, re-prioritize.

## Phase 3: Topology and Scale (hours 4–6)

Once one instance saturates CPU, distribute load.

1. **Separate DB to its own instance.** Update `DSN` env var, allow remote connection in `mysqld.cnf`, restart. This alone often doubles the score.
2. **Run app on instance #1 + #2** behind nginx upstream on instance #3, or have nginx on app#1 round-robin to app#2.
3. **Pin one expensive endpoint to a dedicated instance** (e.g. `/login` with bcrypt) if the benchmarker tolerates it.
4. **Watch every box with `top` / Netdata simultaneously** — the bottleneck moves with each topology change.

See [OPTIMIZATION-PATTERNS.md](references/OPTIMIZATION-PATTERNS.md) for `nginx upstream` and DB-split snippets.

## Phase 4: Endgame (last 90 minutes)

This is where teams lose by overreaching. Switch from "improve" to "harden".

1. **Stop adding new features at T−60min.** Only stabilize.
2. **Disable all debug logging and the slow query log** (`long_query_time = 999`, comment out `slow_query_log`). The log I/O alone can cost thousands of points.
3. **Run a reboot test** on staging instance: `sudo reboot`, wait, run benchmark. If it fails, you have ~30 min to fix. See [COMMON-PITFALLS.md](references/COMMON-PITFALLS.md).
4. **Confirm cache warmup is automatic** (run on app startup, not on first request). Cold caches at re-test time = penalty.
5. **Empty unused logs** to free disk: `truncate -s 0 /var/log/nginx/access.log /var/log/mysql/slow.log`.
6. **Lock the repo at T−15min.** Final benchmark. Do not push more.

## Reference Files

- [RULES.md](references/RULES.md) — regulation, scoring, what is and is not allowed.
- [INITIAL-SETUP.md](references/INITIAL-SETUP.md) — Makefile, nginx LTSV log, MySQL slow log, systemd, deploy script.
- [MEASUREMENT.md](references/MEASUREMENT.md) — alp, pt-query-digest, pprof, Netdata. Commands and reading the output.
- [OPTIMIZATION-PATTERNS.md](references/OPTIMIZATION-PATTERNS.md) — index design, N+1 → IN/JOIN, bulk insert, cache, DB split.
- [COMMON-PITFALLS.md](references/COMMON-PITFALLS.md) — reboot fail, spec violation, cache invalidation, log overhead, benchmarker behavior.
- [TOP-TEAM-STRATEGIES.md](references/TOP-TEAM-STRATEGIES.md) — distilled tactics from takonomura, LayerX, and other published participation reports.

## Key Principles

1. **Measure first, change second.** A guess-and-check loop in ISUCON wastes 30 minutes per wrong guess.
2. **One change per benchmark run.** Otherwise you cannot attribute the score delta.
3. **Commit on every green benchmark.** Roll back instantly when you regress — do not debug in place.
4. **Bottleneck moves.** After each big win, re-run alp/pt-query-digest/pprof. The next one is rarely where the last one was.
5. **The reboot test is part of the score.** A 50,000-point run that fails to come up after `reboot` is a 0.
6. **Spec compliance > speed.** A faster wrong answer is still wrong. The benchmarker is the judge.

## Checklist (before final benchmark)

- [ ] All access/slow query logs disabled or at high threshold
- [ ] `pprof` HTTP handler removed or behind a flag
- [ ] App and DB start automatically on reboot (`systemctl is-enabled` for both)
- [ ] In-memory caches warm up on startup, not on first request
- [ ] No hard-coded `localhost` for DB after instance split
- [ ] `git status` clean, last commit pushed
- [ ] One clean benchmark run completed in the last 10 minutes
