---
name: running-isucon-as-an-agent
description: Contest-day operating manual for an LLM agent (alone or with subagents) that must post a valid ISUCON score in 8 hours when the benchmark runs only from a browser portal. Covers a stall-proof harness (no blocking questions, Stop hook, notifications), a scriptable portal bench, spending scarce runs on measured batches, parallel agents isolated by worktree and a deploy lock, host-state ownership, reboot safety and the endgame, plus the strategy loop that picks what to build next (per-host capacity ledger, latency + capacity rating of designs, seesaw rule, rejection and velocity logs, capped big bets). Distilled from a 17-hour supervised run, an 8-hour contest-mode rehearsal and a real 8-hour multi-region contest. Use before an agent runs an ISUCON contest or rehearsal, when writing ISUCON subagent prompts, or when supervising such a session.
version: 3.3.0
---

# Running ISUCON as an Agent

`winning-isucon` says *what* to optimize; `tuning-isucon-linux-and-nginx` holds
the transferable infra levers. This skill covers *how an agent runs the
contest* without wasting the 8 hours. It was distilled from supervising a
Claude Code session with up to four subagents for 17 hours (1,085 → ~2.9M),
then checked against an 8-hour contest-mode rehearsal (2,617 → 1,656,610,
with a pseudo-bench, a 30-minute emulated queue and a supervisor session),
then a real contest (3,023 → 198,146 final, pass, about a third of the
winner; 4 hosts in emulated regions, ~20 parallel subagents).
Raw speed was never the problem. What cost the most:

| Loss | Cause | Fix |
|---|---|---|
| 48 min | blocking multiple-choice question while the human was away | §0 harness |
| hours, 3× | declaring "done" and ending the turn with hours left | §0 harness |
| 15+ min, 14× | four agents queued on one bench; a lock held for whole sweeps | §2, §4 |
| silent | measurements taken on another agent's half-finished build | §4 |
| ~15 min | cloud NIC burst credits ran out; misread as a regression | §2 |
| ~5 min, 3× | `cp -i`/`rm -i` prompts, foreground `until ssh` loops | §3 |
| all day | one validation error code recurred in most runs for 15 h | §2 |
| unbounded | biggest practice levers came from bench source / bench host — absent on contest day | §1 |
| ~2 h | agent could not install its own Stop hook (auto mode); turns ended "waiting for the result" with nothing to wake them | §0 harness |
| 2 FAIL slots | fast app exhausted the bench client's fds, then its ports; only "fixed" by touching the bench host | §1, §2 |
| 0-score slot + host outage | home-made proxy replacement deployed without a soak test | §2 |
| 1 slot | pseudo-bench left on a host that a topology change put on the request path | §4 |
| unknown slots | deploy default turned a tuning off on every partial redeploy | §4 |
| last ~3 h flat | lopsided per-host idle visible for 6+ runs; slots went to big bets instead | §2, §6 |
| last ~2 h flat, rank 8 → 39 (Run 3) | same lopsided-host rule, already in this skill, never enforced: the metrics script was never called by the bench wrapper | §2, §7 |
| the winning topology (Run 3) | rejected on a latency-only rating with a wrong capacity premise and an "8–12 h" estimate; similar features took 10–40 min to code | §7 |
| the best late gain (+15k) arrived ~2 h late (Run 3) | rejected twice on single runs inside a ±5–10 % band | §2, §7 |
| ~85 min, 17 FAILs (Run 3) | unbounded disk cache (3), DB OOM (1), the same FAIL type 4× on one feature | §2, §5 |

## Contest-day assumptions

- The benchmark is enqueued **only from the portal in a browser**; results come
  back through the portal.
- The **queue is congested**: expect minutes per result and few runs per hour.
- The **benchmarker is fast**: bench-side CPU/memory is not your ceiling, so
  tricks that only save the load generator's resources do not pay. Your hosts'
  per-request cost and correctness are what move the score.
- But the bench **client's fds and ephemeral ports are finite** and not yours
  to raise. A fast server whose idle timeouts are wrong makes the client fail
  (`too many open files`, `cannot assign requested address`) → FAIL.
  Open client connections ≈ new-connection rate × server idle timeout; pick
  the timeout from the measured inter-request gap CDF
  ([OBSERVED-BARRIERS.md](references/OBSERVED-BARRIERS.md) A8).

## 0. Before minute 0

### Harness (enforce, do not ask nicely)

Settings, a tested `Stop` hook, and a checklist: [HARNESS-SETUP.md](references/HARNESS-SETUP.md).
The **human installs them before starting the session** — under auto mode the
agent's own write to `.claude/settings.json` is denied (`[Self-Modification]`).
At minute 0 the agent only verifies they are loaded and notifies if not.

- Deny `AskUserQuestion` in the contest session. Judgment calls become
  "pick the default that maximises a valid score, write it to `NOTES.md`,
  notify, continue". Block only for irreversible or regulation-level calls.
- `Stop` hook re-prompts until the `END:` time in `NOTES.md`. "The bottleneck
  is no longer mine" and "sub-goal done" were the observed stop triggers.
- Pre-approve the contest toolset **and the risky steps the plan needs**
  (cloud-API reboot, service restarts, `iptables`, binary swaps). A subagent's
  experiment stalled mid-way on an automatic permission denial.
- `Notification` hook that reaches the human's phone/desktop.
- **Never end a turn without a waker.** The official run must be a live
  `run_in_background` task (not `cmd &` inside it, not `( … &)` — those exit at
  once and never notify) or a Monitor armed on the next result. "Waiting for
  the result" is the most common stop trigger.

### Policy (ask once, record in `NOTES.md`)

- gray zone: response shaping, certificate replacement, cache headers that
  change client behaviour — allowed?
- risk appetite: maximise even if a run occasionally fails, or stay safe?
- spend limits; what always requires a stop-and-ask.
- how many **big bets** (topology, persistence, language port) may run at
  once, and who may move the freeze time. Run 3 had ~6 big bets, one landed,
  and the freeze moved 4 times.
- alert policy: "only the final run matters" (mid-contest FAILs are fine)
  or "keep a pass on the board"? It changes what a supervisor toasts.
- outward actions (portal questions, organizer contact) always go through
  the human; no agent sends them.
- every technique must serve **any external client** identically (the
  post-contest browser check comes from the internet): no bench-source-IP-only
  paths such as DSR.
- approvals count only when typed by the human **in the driver session** or
  written here before start; approvals relayed by another session or agent are
  denied by the classifier and must not be acted on.

### `NOTES.md` from minute 5

`END:` time, hosts and roles, gray-zone answers, a **ranked backlog**
(problem-specific hypotheses + the generic lever checklist from
`tuning-isucon-linux-and-nginx`), the official score log, open `CODE=` bugs,
and questions answered by default. A backlog that lives only in the human's
head made the driver ask "what next?" through the human three times.
**Write `NOTES.md` (and score logs, reports the human reads) in Japanese**;
commands, code identifiers and log excerpts stay as-is. The human had to ask
for this mid-contest.

### Portal access (first 15 minutes)

Human logs in; the agent captures the enqueue/poll calls with the browser tool
and wraps them as `scripts/portal-bench.sh run|status`
([PORTAL-BENCH.md](references/PORTAL-BENCH.md)). From then on, no human clicks.

## 1. Practice-only affordances

Ask *would this exist 本番?* before relying on anything:

| Practice crutch | Contest-day substitute |
|---|---|
| Reading benchmarker source for scoring/validation | Manual, regulation, `openapi.yaml`, reference app, frontend JS (call order, polling), `CODE=` messages in the portal log |
| `ssh`/`perf` on the bench host; scaling it up | Profile only your hosts; the contest bench is fixed (and fast) |
| A second environment for experiments | Partition the given hosts; synthetic load from a non-request-path host — or, if all hosts serve, from the local machine via a scoped firewall rule logged for cleanup |
| Raising `nofile` / port range on the bench host when the client runs out | Server-side idle timeouts from the gap CDF; documented 429 + `Retry-After` throttling as a flagged kill switch |
| Unlimited 70-second shell benches | Congested portal queue → §2 |
| Self-built bench copies (scores look like new bests) | Only official portal scores go in the score log |
| Replacing the TLS certificate because the practice bench does not verify it | Only if the regulation allows; otherwise tune within the provided cert |
| Shaping responses to the load generator's internals | Only from documented client behaviour; A/B; policy answer first |

Rehearse at least one full practice in contest mode.

## 2. The bench is the scarcest resource

- **One enqueuer.** Only the driver calls `portal-bench.sh`; subagents never
  touch the portal. They hand the driver a commit + expected effect.
- **Build the local judge in hour 1:** oracle-differential `check`, a calibrated
  `load` that enforces the client's limits, a shadow-stack preflight
  ([PSEUDO-BENCH.md](references/PSEUDO-BENCH.md)).
- **Decide locally, confirm officially.** Infra changes (TLS, nginx, kernel,
  NIC) are decided with synthetic load + per-host counters
  (`node-metrics.sh`, see `tuning-isucon-linux-and-nginx`/MEASUREMENT);
  app changes with a local correctness smoke test + profiler. A portal run
  confirms a **batch** of locally-validated changes.
- **Soak gate for replacements.** A home-made replacement of nginx, a proxy or
  a runtime gets an official slot only after a soak test: ≥ one bench duration,
  ≥ bench concurrency, ~2 % client cancellations, long idle connections, RSS
  flat. Respect the adoption threshold you set; build the preflight and an
  auto-revert guard before the first risky swap (B17).
- **Lopsided hosts first.** If per-host idle is lopsided for 2+ runs, the next
  slot changes only the rebalancing (weights, placement), nothing else.
- **Every official run is fully instrumented**: deployed commit + binary hash,
  per-host counters (`node-metrics.sh start` before enqueue, `stop` after the
  result), `CODE=` counts. One run should answer several questions.
  **The wrapper enforces it**: per-host idle is a required score-log column
  (BENCH-LOOP). In Run 3 this rule existed only as prose. The script was in
  the repo and never called, and two pegged hosts next to two idle ones went
  unseen for 5 hours (B22).
- **Never wait idle on the queue.** While a job is queued, the driver works the
  non-bench backlog. Waiting is a Monitor/background poll, not a foreground loop.
- **Noise.** Identical code varied ±5–12 %. Adopt or reject only when the
  delta exceeds the band or two runs agree (STRATEGY-LOOP §7). With few runs, trust per-host
  counters from the same run more than the score delta; believe a jump only
  after it repeats. A score that decays over consecutive runs on unchanged code
  is a resource budget running out (cloud NIC allowance, CPU credits), not a
  regression.
- **Every cache has a size cap; every run row has min `MemAvailable` and `df`.**
  On an intermittent 5xx, check disk and memory before bisecting code (B29, B30).
- **Correctness first.** Any `CODE=` seen in ≥2 runs is a tracked bug assigned
  now; a pass with errors is a latent fail. One code recurred in most runs for
  15 hours and grew with load.
- Wrapper and log format: [BENCH-LOOP.md](references/BENCH-LOOP.md).

## 3. Shell hygiene

- **First command of the session**, before anything else: `alias | grep -E '^(cp|mv|rm)='; setopt 2>/dev/null | grep -Ei 'clobber|nomatch'`.
  With `-i` aliases, always `command cp -f`, `command rm -f`; use `>|` (and `9>>lock`) under `noclobber`.
- zsh does not word-split `$VAR`: keep multi-step logic in bash script files, use arrays for option lists.
- Per-contest ssh aliases with unique names; check `ssh -G <alias> | grep -i hostname` (old `Host` patterns shadow them).
- A background child of a lock holder inherits the lock fd: `exec 9>&-` in watchdogs/sleepers.
- `ssh -o BatchMode=yes -o ConnectTimeout=10` wrapped in `timeout`; pass `</dev/null` in loops.
- Never `pkill -f <pattern>` when the pattern is in your own command line (kills your shell, exit 144).
- Anything > 60 s runs in the background; a host that fails two probes gets recovery in the
  background (cloud-API reboot) while you keep working. No foreground `until ssh ...; do sleep`.
- After a reboot, wait for a **new** `/proc/sys/kernel/random/boot_id`, not just for ssh to answer.

## 4. Parallel agents

Preamble to paste into every subagent prompt: [BENCH-LOOP.md](references/BENCH-LOOP.md#subagent-preamble).

- Editing subagents run with `isolation: "worktree"`; the driver merges. No `--amend`/`reset`/`rebase`/force-push.
- **Environment lock** (`flock`) around *deploy + measure*, taken **per run, not per sweep**.
  The holder deploys its own known build inside the lock and logs the deployed hash;
  nobody leaves a WIP build deployed when releasing.
- **The deploy script owns all host state** (binaries, configs, systemd drop-ins, sysctl,
  iptables, grub default) and resets what it did not write. Experiments outside it undo
  themselves in a `trap`. Verify leftovers on the host, not from a subagent's report.
  Its **defaults equal the current best config** (experiments are explicit flags), and its
  deployed-state record is read from the hosts for every toggle (B19).
- **Test workloads never on a serving host.** Every topology change re-checks which hosts
  serve and evicts pseudo-bench / oracle processes from them (B18).
- Worktrees do not isolate the scratchpad: each agent uses its own `mktemp -d`. Hand-off
  requires `git status` clean; the driver builds after every merge. Keep a port registry
  in `NOTES.md`; `ss -ltnp` before adding a listener.
- **Cap agents to the resources.** With one environment, at most one or two agents that need
  it; the rest do read-only work (code reading, profile analysis, preparing branches).
- **Cheap observations first.** Each agent's first report lists what its first measurement
  exposed (idle host, connection churn, allowance drops) before any time-boxed deep dive.
  An hour of kernel/XDP work produced 0 %; the cheap levers were in the last paragraph.
- **Delegating is not waiting.** The driver keeps working while subagents run.
- Give each subagent a deadline and a revert-on-loss rule (the driver did this well at the end).

## 5. Recovery and reboot safety

- Keep ssh and the cloud's recovery agent running (on AWS, disabling `snapd` kills `amazon-ssm-agent`).
- Reboot one host first, then the rest; verify data by hashing a few GET responses before/after.
- Before firewall/sshd/sysctl experiments: second ssh session + timed auto-revert.
- Kernel swaps (e.g. the prebuilt patched kernel in `tuning-isucon-linux-and-nginx`/KERNEL-XDP,
  worth it only when the front host is the bottleneck): one-shot boot (`grub-reboot`), scripted
  cloud-API recovery, never in the last 2 hours, default only after a full reboot test.

## 6. Endgame

- Big-bang changes (language port, persistence redesign) start before T−3h or not at all,
  behind a flag that A/Bs against the current app. At most two at once (STRATEGY-LOOP §9).
- Decide the final procedure by T−3h and write it in `NOTES.md`: the freeze time, a stop
  rule ("final run passes and scores ≥ X → stop; otherwise one more before T−10"), and a
  tagged fallback commit that stays deployable. Final = the **last** run, so never queue a
  run you are not willing to submit.
- T−90 min: freeze features; subagents get a hard deadline to land or revert.
- If every run after the best is lower, re-run the best commit once before declaring a
  "final layout"; the final layout must be A/B'd against it.
- Then: verify on every host that no experiment state remains (a read-only `final-check.sh`:
  pending restarts, replication slots, temporary FW rules, disk, profilers off); full reboot
  test of all hosts at once, then compare row counts and an image/file-store hash with a
  pre-reboot snapshot;
  browser/E2E checks (they create data) **before** the final runs; official runs on the exact
  commit you will submit; logs/profilers off; close temporary firewall rules.
- Report via notes/notifications; the `Stop` hook keeps the session alive until `END:`.

## 7. Strategy loop: what to build next

The bench loop says whether a change won. The strategy loop picks the next
change. Run 3 implemented quickly and lost on this loop. Details and evidence:
[STRATEGY-LOOP.md](references/STRATEGY-LOOP.md).

- **Capacity ledger** per run (idle % and busiest process per host). If hosts
  are lopsided for 2 runs, move work onto the idle host.
- **Rate design options on latency *and* capacity.** Check each capacity premise
  against the ledger.
- **Seesaw rule:** two results where a priority knob moves score from one class
  to another → stop tuning knobs and change the topology.
- **Rejection log** with premises and an "overturned if" line. Re-open the option
  when a premise falls.
- **Velocity log** (dispatched → first commit → tests → first run → decided).
  Estimate by analog and estimate the delta, not the whole. Code took 10–40 min
  and convergence 1.5–4 h. An estimate never vetoes alone: build a 30-min
  flag-off spike and give it one run.
- **Staged plans:** stage 1 gets an official run before the plan is filed.
- **Hours 1–2:** fit a score model from the bench log (count vs quality per
  unit) and measure data locality from the seed data.
- **One subagent owns capacity/topology** and re-reads the rejection log hourly.

## What held (keep doing)

Run 3's final run had 0 errors and passed reboot, E2E and browser checks.
These practices produced that (OBSERVED-BARRIERS §D):
- every experiment behind a flag, default off; the bare deploy is the best config;
- a differential oracle (DB path vs memory paths over a long write sequence)
  for any replicated or in-memory model;
- withdrawing within ~35 min when a measurement refutes a design;
- attributing errors with per-host logs before chasing them (an off-host 503
  was left alone);
- every run recorded in `NOTES.md`, which made the post-mortem possible.

## References

- [HARNESS-SETUP.md](references/HARNESS-SETUP.md) — settings, `Stop` hook (`scripts/contest-stop-hook.sh`), notifications.
- [PORTAL-BENCH.md](references/PORTAL-BENCH.md) — browser-only portal → `scripts/portal-bench.sh`; congested-queue etiquette.
- [BENCH-LOOP.md](references/BENCH-LOOP.md) — environment lock, official-run wrapper, score log, subagent preamble.
- [OBSERVED-BARRIERS.md](references/OBSERVED-BARRIERS.md) — evidence for every rule above, with timings, from three runs, plus what held.
- [PSEUDO-BENCH.md](references/PSEUDO-BENCH.md) — oracle-differential checker, calibrated load generator, shadow-stack preflight, queue emulator, browser check.
- [SUPERVISING.md](references/SUPERVISING.md) — watching a contest agent from a second session: alert rules that paid off vs noise, stall detection, health probes, strategic review.
- [STRATEGY-LOOP.md](references/STRATEGY-LOOP.md) — capacity ledger, two-axis option rating, seesaw rule, rejection and velocity logs, replicates, big-bet caps.
- `tuning-isucon-linux-and-nginx` — transferable nginx/TLS/kernel/NIC levers, prebuilt nginx, measurement without the bench.
- `winning-isucon` — contest strategy; `writing-isucon-arch-subagent-tasks` — worktree-isolated dispatch.
- `designing-isucon-architecture` — topology options, including the multi-region block (region-local commit, audience-based replication).
